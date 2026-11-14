extends CharacterBody2D

const SPEED = 60.0
const ATTACK_DAMAGE = 1
const ATTACK_COOLDOWN = 0.4
const ATTACK_REACH = 12.0
const SWING_TIME = 0.15

signal health_changed(health, max_health)

@onready var anim = $AnimatedSprite2D
@onready var steps = $Footsteps

var max_health = 3
var health = 3
var invincible = false
var facing = Vector2.RIGHT
var attack_timer = 0.0
var attack_area
var slash

func _ready():
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	anim.play("default")
	_setup_attack_input()
	_setup_attack()

func _setup_attack_input():
	if InputMap.has_action("attack"):
		return
	InputMap.add_action("attack")
	var key = InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	InputMap.action_add_event("attack", key)
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", click)

func _setup_attack():
	attack_area = Area2D.new()
	attack_area.collision_layer = 0
	attack_area.collision_mask = 2
	var shape = CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 10.0
	attack_area.add_child(shape)
	add_child(attack_area)

	slash = Sprite2D.new()
	slash.texture = preload("res://sprites/fx/slash.png")
	slash.centered = false
	slash.offset = Vector2(3, -15)
	slash.z_index = 1
	slash.visible = false
	add_child(slash)

func _physics_process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED
	move_and_slide()

	if direction != Vector2.ZERO:
		facing = direction.normalized()
		if not steps.playing:
			steps.play()
	else:
		steps.stop()

	if direction.x != 0:
		anim.flip_h = direction.x < 0

	attack_timer = max(attack_timer - delta, 0.0)
	attack_area.position = facing * ATTACK_REACH
	if Input.is_action_just_pressed("attack") and attack_timer == 0.0:
		_attack()

func _attack():
	attack_timer = ATTACK_COOLDOWN
	slash.rotation = facing.angle()
	slash.modulate.a = 1.0
	slash.visible = true
	var swing = create_tween()
	swing.tween_property(slash, "modulate:a", 0.0, SWING_TIME)
	swing.tween_callback(slash.hide)
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("hurt"):
			body.hurt(ATTACK_DAMAGE, global_position)

func take_damage(amount):
	if invincible:
		return false
	health -= amount
	health_changed.emit(health, max_health)
	if health <= 0:
		get_tree().call_deferred("reload_current_scene")
		return true
	invincible = true
	var tween = create_tween()
	for i in 4:
		tween.tween_property(anim, "modulate", Color(1, 0.3, 0.3), 0.125)
		tween.tween_property(anim, "modulate", Color.WHITE, 0.125)
	tween.finished.connect(func(): invincible = false)
	return true
