extends StaticBody2D

@export var required_boss = "Vampire"
@export var required_memory = "Memory2"
@export var locked_message = "Sealed. Defeat the Vampire and recover your first memory."
@export var open_message = "The passage to the west has opened..." ## dragon of the west holy atla reference

@onready var spikes = $Spikes.get_children()
@onready var shape = $CollisionShape2D
@onready var warn = $Warn
@onready var rumble = $Rumble

var opened = false
var warn_cooldown = 0.0
var hud

func _ready():
	collision_layer = 1
	collision_mask = 0
	warn.collision_layer = 0
	warn.collision_mask = 4
	warn.body_entered.connect(_on_warn)
	for spike in spikes:
		spike.play("up")
	_connect_hud.call_deferred()
	_draw_below_player.call_deferred()

func _draw_below_player():
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get_parent() == get_parent() and player.get_index() < get_index():
		get_parent().move_child(self, player.get_index())

func _connect_hud():
	hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.progress_changed.connect(_check)

func _process(delta):
	warn_cooldown = max(warn_cooldown - delta, 0.0)

func _check():
	if opened:
		return
	if required_boss in hud.defeated_bosses and required_memory in hud.collected_memories:
		_open()

func _open():
	opened = true
	shape.set_deferred("disabled", true)
	for spike in spikes:
		spike.play("lower")
	rumble.play()
	get_tree().create_timer(1.2).timeout.connect(rumble.stop)
	_shake_camera()
	hud.show_notice(open_message, 4.0)

func _shake_camera():
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return
	var shake = camera.create_tween()
	for i in 10:
		shake.tween_property(camera, "offset", Vector2(randf_range(-2, 2), randf_range(-2, 2)), 0.04)
	shake.tween_property(camera, "offset", Vector2.ZERO, 0.04)

func _on_warn(body):
	if opened or warn_cooldown > 0.0 or not body.is_in_group("player") or hud == null:
		return
	warn_cooldown = 4.0
	hud.show_notice(locked_message, 2.5)
