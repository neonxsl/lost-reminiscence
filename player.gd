extends CharacterBody2D

const SPEED = 60.0
const ATTACK_DAMAGE = 1
const ATTACK_COOLDOWN = 0.4
const ATTACK_REACH = 12.0
const SWING_TIME = 0.15
const AWAKENED_TEXTURE = preload("res://sprites/player/priest_awakened.png")
const HURT_SOUND = preload("res://audio/hurt.mp3")
const ATTACK_SOUND = preload("res://audio/attack.mp3")

signal health_changed(health, max_health)

@onready var anim = $AnimatedSprite2D
@onready var steps = $Footsteps

var max_health = 3
var health = 3.0
var damage_multiplier = 1.0
var speed_multiplier = 1.0
var invincible = false
var facing = Vector2.RIGHT
var attack_timer = 0.0
var attack_area
var slash
var can_dash = false
var dashing = false
var dash_timer = 0.0
var dash_cooldown = 0.0
var dash_direction = Vector2.RIGHT
var dash_hit = []
var ghost_timer = 0.0
var normal_frames
var grace_timer = 0.0
var hurt_sound
var attack_sound
var dash_frames

func _ready():
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	anim.play("default")
	normal_frames = anim.sprite_frames
	dash_frames = SpriteFrames.new()
	dash_frames.add_frame("default", AWAKENED_TEXTURE)
	_setup_attack_input()
	_setup_attack()
	hurt_sound = AudioStreamPlayer.new()
	hurt_sound.stream = HURT_SOUND
	hurt_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hurt_sound)
	attack_sound = AudioStreamPlayer.new()
	attack_sound.stream = ATTACK_SOUND
	add_child(attack_sound)

func _setup_attack_input():
	for pair in [["ui_up", KEY_W], ["ui_left", KEY_A], ["ui_down", KEY_S], ["ui_right", KEY_D]]:
		var key = InputEventKey.new()
		key.physical_keycode = pair[1]
		if not InputMap.action_has_event(pair[0], key):
			InputMap.action_add_event(pair[0], key)
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var q = InputEventKey.new()
		q.physical_keycode = KEY_Q
		InputMap.action_add_event("dash", q)
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

func unlock(ability):
	if ability == "dash":
		can_dash = true
	elif ability == "resistance":
		damage_multiplier = 1.0 - 0.25
	elif ability == "speed":
		speed_multiplier = 1.0 + 0.25

func _physics_process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	dash_cooldown = max(dash_cooldown - delta, 0.0)
	grace_timer = max(grace_timer - delta, 0.0)
	anim.self_modulate.a = 0.6 if grace_timer > 0.0 else 1.0
	if can_dash and not dashing and dash_cooldown == 0.0 and Input.is_action_just_pressed("dash"):
		_start_dash(direction)
	if dashing:
		_dash_step(delta)
		return
	velocity = direction * SPEED * speed_multiplier
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
	attack_sound.pitch_scale = randf_range(0.95, 1.05)
	attack_sound.play()
	slash.rotation = facing.angle()
	slash.modulate.a = 1.0
	slash.visible = true
	var swing = create_tween()
	swing.tween_property(slash, "modulate:a", 0.0, SWING_TIME)
	swing.tween_callback(slash.hide)
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("hurt"):
			body.hurt(ATTACK_DAMAGE, global_position)
			grace_timer = 0.5

func _start_dash(direction):
	dashing = true
	dash_timer = .18
	dash_direction = direction.normalized() if direction != Vector2.ZERO else facing
	dash_hit = []
	ghost_timer = 0.0
	steps.stop()
	if dash_direction.x != 0:
		anim.flip_h = dash_direction.x < 0
	anim.sprite_frames = dash_frames
	anim.offset = Vector2(4, 0)
	anim.play("default")

func _dash_step(delta):
	velocity = dash_direction * 220
	move_and_slide()
	attack_area.position = Vector2.ZERO
	for body in attack_area.get_overlapping_bodies():
		if body.has_method("hurt") and not body in dash_hit:
			dash_hit.append(body)
			body.hurt(1, global_position)
	ghost_timer -= delta
	if ghost_timer <= 0.0:
		ghost_timer = 0.03
	dash_timer -= delta
	if dash_timer <= 0.0:
		dashing = false
		dash_cooldown = 0.6
		grace_timer = 0.5
		anim.sprite_frames = normal_frames
		anim.offset = Vector2.ZERO
		anim.play("default")



func take_damage(amount):
	if invincible or dashing or grace_timer > 0.0:
		return false
	health -= amount * damage_multiplier
	health_changed.emit(health, max_health)
	hurt_sound.play()
	if health <= 0.001:
		invincible = true
		steps.stop()
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.player_died.call_deferred()
		else:
			get_tree().call_deferred("reload_current_scene")
		return true
	invincible = true
	var tween = create_tween()
	for i in 4:
		tween.tween_property(anim, "modulate", Color(1, 0.3, 0.3), 0.125)
		tween.tween_property(anim, "modulate", Color.WHITE, 0.125)
	tween.finished.connect(func(): invincible = false)
	return true
