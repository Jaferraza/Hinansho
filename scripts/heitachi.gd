extends CharacterBody2D

signal health_changed(health: int, max_health: int)
signal died

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const GRAVITY = 980.0
const ATTACK_DAMAGE = 10
const SPECIAL_DAMAGE = 25
const DAMAGED_ANIM_SPEED = 12.0  # the hit-stun animation is 8 frames, 3 fps was ~2.7s of stun

# Per-player keys. The actions are created at runtime as p1_left, p2_attack, etc.
const CONTROLS = {
	1: {"left": KEY_A, "right": KEY_D, "jump": KEY_W, "crouch": KEY_S, "attack": KEY_F, "special": KEY_G},
	2: {"left": KEY_LEFT, "right": KEY_RIGHT, "jump": KEY_UP, "crouch": KEY_DOWN, "attack": KEY_PERIOD, "special": KEY_SLASH},
}

@export var player_id: int = 1
@export var max_health: int = 100

var health: int
var current_damage: int = 0  # read by attack_area2.gd when the hitbox touches the other player
var facing: int = 1

var is_attacking: bool = false
var is_crouching: bool = false
var is_damaged: bool = false
var is_special_attacking: bool = false
var is_dead: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var health_bar = $HealthBarContainer/healthbar


func _ready() -> void:
	add_to_group("fighters")
	health = max_health

	# Players live on layer 2 and only collide with the world (layer 1), so they can't
	# push each other around. The hitbox only looks for layer 2 (the other player).
	collision_layer = 2
	collision_mask = 1
	attack_area.collision_layer = 0
	attack_area.collision_mask = 2

	_setup_input()

	# One-shot animations must not loop, or animation_finished never fires.
	for anim in ["attack", "special", "damaged"]:
		if sprite.sprite_frames.has_animation(anim):
			sprite.sprite_frames.set_animation_loop(anim, false)
	if sprite.sprite_frames.has_animation("damaged"):
		sprite.sprite_frames.set_animation_speed("damaged", DAMAGED_ANIM_SPEED)
	sprite.animation_finished.connect(_on_animation_finished)

	facing = 1 if player_id == 1 else -1
	_apply_facing()
	health_bar.set_health_bar(health, max_health)
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


func _physics_process(delta: float) -> void:
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
	attack_area.scale.x = facing  # hitbox sits in front of the player


func _start_attack(special: bool) -> void:
	is_crouching = false
	if special:
		is_special_attacking = true
		current_damage = SPECIAL_DAMAGE
		_play("special", true)
	else:
		is_attacking = true
		current_damage = ATTACK_DAMAGE
		_play("attack", true)
	attack_area.set_deferred("monitoring", true)


func _end_attack() -> void:
	is_attacking = false
	is_special_attacking = false
	attack_area.set_deferred("monitoring", false)


func take_damage(amount: int) -> void:
	if is_dead:
		return
	health = maxi(health - amount, 0)
	health_bar.set_health_bar(health, max_health)
	health_changed.emit(health, max_health)
	_end_attack()  # being hit cancels whatever move was in progress
	if health == 0:
		is_dead = true
		_play("damaged", true)
		died.emit()
	else:
		is_damaged = true
		_play("damaged", true)


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


func _on_animation_finished() -> void:
	match sprite.animation:
		"attack", "special":
			_end_attack()
		"damaged":
			if not is_dead:
				is_damaged = false
