# Shared fighter logic (movement, attacks, health, bounce back, special).
# Characters are scenes that use a thin script extending this one and set the
# tuning exports below, plus provide these animations on their AnimatedSprite2D:
# idle, running, jump, crouch, attack, special, damaged (and optionally death).
extends CharacterBody2D

signal health_changed(health: int, max_health: int)
signal bounced_back
signal died

const SPEED = 300.0
const JUMP_VELOCITY = -490.0   # apex ~120px: high enough to clear the other player's ~100px body
const GRAVITY = 980.0
const HIT_INVULN = 0.6          # brief invulnerability after a hit, so one player can't stun-lock the other
const HIT_STUN = 0.35           # how long a hit freezes the victim (matches the hit animation)
const MAX_ACTION_TIME = 1.5     # safety: an attack can never last longer than this
const ATTACK_DAMAGE = 10
const SPECIAL_DAMAGE = 25


# Bounce back: the comeback mechanic.
const BOUNCE_THRESHOLD = 0.25     # triggers once, when health drops below 25%
const BOUNCE_HEAL = 30
const BOUNCE_DAMAGE_MULT = 1.5
const BOUNCE_DURATION = 8.0

# Per-player keys. The actions are created at runtime as p1_left, p2_attack, etc.
const CONTROLS = {
	1: {"left": KEY_A, "right": KEY_D, "jump": KEY_W, "crouch": KEY_S, "attack": KEY_F, "special": KEY_G},
	2: {"left": KEY_LEFT, "right": KEY_RIGHT, "jump": KEY_UP, "crouch": KEY_DOWN, "attack": KEY_PERIOD, "special": KEY_SLASH},
}

@export var player_id: int = 1
@export var max_health: int = 100

# Per-character tuning (defaults are Heitachi's).
@export var damaged_anim_speed: float = 24.0   # hit-stun length: frames / speed seconds (~0.33s)
@export var special_anim_speed: float = 8.0     # special length: frames / speed seconds
@export var special_hit_frame: int = 5          # special hitbox is only live from this frame on

var health: int
var current_damage: int = 0   # read by attack_area2.gd when a hitbox touches the other player
var facing: int = 1

var bounce_used: bool = false
var special_used: bool = false
var boost_time_left: float = 0.0
var invuln_time_left: float = 0.0
var stun_time_left: float = 0.0
var action_time_left: float = 0.0

var is_attacking: bool = false
var is_crouching: bool = false
var is_damaged: bool = false
var is_special_attacking: bool = false
var is_dead: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var special_area: Area2D = $SpecialArea


func _ready() -> void:
	add_to_group("fighters")
	health = max_health

	# Players live on layer 2 and collide with the world (layer 1) and with each other (layer 2),
	# so you have to jump over the other player. The hitboxes only look for layer 2.
	collision_layer = 2
	collision_mask = 3
	for area in [attack_area, special_area]:
		area.collision_layer = 0
		area.collision_mask = 2

	_setup_input()

	# One-shot animations must not loop, or animation_finished never fires.
	for anim in ["attack", "special", "damaged", "death"]:
		if sprite.sprite_frames.has_animation(anim):
			sprite.sprite_frames.set_animation_loop(anim, false)
	sprite.sprite_frames.set_animation_speed("damaged", damaged_anim_speed)
	sprite.sprite_frames.set_animation_speed("special", special_anim_speed)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)

	facing = 1 if player_id == 1 else -1
	_apply_facing()
	_play("idle")


func _setup_input() -> void:
	var keys: Dictionary = CONTROLS[player_id]
	for action in keys:
		var action_name := _a(action)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var event := InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action_name, event)


func _a(action: String) -> String:
	return "p%d_%s" % [player_id, action]


# --- queries the HUD uses -------------------------------------------------

func is_boosted() -> bool:
	return boost_time_left > 0.0


# The special can be used once per match, while below 25% health or during the bounce-back boost.
func can_use_special() -> bool:
	if special_used or is_dead:
		return false
	return is_boosted() or float(health) < max_health * BOUNCE_THRESHOLD


# --- main loop -------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if boost_time_left > 0.0:
		boost_time_left = maxf(boost_time_left - delta, 0.0)
	invuln_time_left = maxf(invuln_time_left - delta, 0.0)
	# Timers guarantee a player is never stuck stunned or mid-attack, even if an animation signal is missed.
	if stun_time_left > 0.0:
		stun_time_left -= delta
		if stun_time_left <= 0.0 and not is_dead:
			is_damaged = false
	if action_time_left > 0.0:
		action_time_left -= delta
		if action_time_left <= 0.0 and (is_attacking or is_special_attacking):
			_end_attack()
	_update_tint()

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if is_dead:
		velocity.x = 0
		move_and_slide()
		return

	if is_attacking or is_special_attacking or is_damaged:
		velocity.x = 0
	else:
		is_crouching = Input.is_action_pressed(_a("crouch")) and is_on_floor()

		if Input.is_action_just_pressed(_a("jump")) and is_on_floor() and not is_crouching:
			velocity.y = JUMP_VELOCITY

		if Input.is_action_just_pressed(_a("attack")):
			_start_attack(false)
		elif Input.is_action_just_pressed(_a("special")):
			# Locked / already used / in the air: nothing happens.
			if is_on_floor() and can_use_special():
				special_used = true
				_start_attack(true)

		if is_attacking or is_special_attacking:
			velocity.x = 0
		else:
			var direction := Input.get_axis(_a("left"), _a("right"))
			if direction != 0 and not is_crouching:
				velocity.x = direction * SPEED
				facing = 1 if direction > 0 else -1
				_apply_facing()
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_update_animation()


func _apply_facing() -> void:
	sprite.flip_h = facing < 0
	attack_area.scale.x = facing   # hitboxes sit in front of the player
	special_area.scale.x = facing


func _update_tint() -> void:
	var color := Color.WHITE
	if is_boosted():
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 10.0)
		color = Color(1.0, 1.0 - 0.55 * k, 1.0 - 0.55 * k)   # pulsing red
	if invuln_time_left > 0.0 and not is_dead and int(Time.get_ticks_msec() / 70.0) % 2 == 0:
		color.a = 0.5   # blink while invulnerable after a hit
	sprite.modulate = color


# --- attacking -------------------------------------------------------------

func _start_attack(special: bool) -> void:
	is_crouching = false
	action_time_left = MAX_ACTION_TIME
	var base := SPECIAL_DAMAGE if special else ATTACK_DAMAGE
	current_damage = int(base * (BOUNCE_DAMAGE_MULT if is_boosted() else 1.0))
	if special:
		is_special_attacking = true
		_play("special", true)   # its hitbox is switched on later, in _on_frame_changed
	else:
		is_attacking = true
		_play("attack", true)
		attack_area.set_deferred("monitoring", true)


func _end_attack() -> void:
	is_attacking = false
	is_special_attacking = false
	attack_area.set_deferred("monitoring", false)
	special_area.set_deferred("monitoring", false)


# --- health ----------------------------------------------------------------

func take_damage(amount: int) -> void:
	if is_dead or invuln_time_left > 0.0:
		return
	invuln_time_left = HIT_INVULN
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_end_attack()   # being hit cancels whatever move was in progress
	if health == 0:
		is_dead = true
		boost_time_left = 0.0
		_play("death" if sprite.sprite_frames.has_animation("death") else "damaged", true)
		died.emit()
		return
	is_damaged = true
	stun_time_left = HIT_STUN
	_play("damaged", true)
	if not bounce_used and float(health) < max_health * BOUNCE_THRESHOLD:
		_bounce_back()


func _bounce_back() -> void:
	bounce_used = true
	health = mini(health + BOUNCE_HEAL, max_health)
	boost_time_left = BOUNCE_DURATION
	health_changed.emit(health, max_health)
	bounced_back.emit()


# --- animation -------------------------------------------------------------

func _update_animation() -> void:
	# Attack / damaged / death animations are started where they happen.
	if is_dead or is_damaged or is_attacking or is_special_attacking:
		return
	var anim := "idle"
	if is_crouching:
		anim = "crouch"
	elif not is_on_floor():
		anim = "jump"
	elif absf(velocity.x) > 1.0:
		anim = "running"
	if sprite.animation != anim or not sprite.is_playing():
		_play(anim)


func _play(anim_name: String, restart: bool = false) -> void:
	if not sprite.sprite_frames.has_animation(anim_name):
		return
	if restart:
		sprite.stop()
		sprite.frame = 0
	sprite.play(anim_name)


func _on_frame_changed() -> void:
	if is_special_attacking:
		special_area.set_deferred("monitoring", sprite.frame >= special_hit_frame)


func _on_animation_finished() -> void:
	match sprite.animation:
		"attack", "special":
			_end_attack()
		"damaged":
			if not is_dead:
				is_damaged = false
