extends Node2D

const GAME_SCENE = "res://main.tscn"
const VIEW_POSITION = Vector2(-540, -30)

@onready var world = $World
@onready var camera = $Camera2D
@onready var ui = $UI
@onready var root = $UI/Root
@onready var play_button = $UI/Root/Buttons/Play
@onready var quit_button = $UI/Root/Buttons/Quit
@onready var fade = $UI/Root/Fade
@onready var blip = $UI/Blip

var leaving = false
var intro_tween

func _ready():
	_load_dungeon()
	get_viewport().size_changed.connect(_fit)
	_fit()
	play_button.pressed.connect(_play)
	quit_button.pressed.connect(_quit)
	for button in [play_button, quit_button]:
		button.hovered.connect(_hover_sound)
	camera.position = VIEW_POSITION
	fade.modulate.a = 1.0
	intro_tween = create_tween()
	intro_tween.tween_property(fade, "modulate:a", 0.0, 0.8)
	play_button.grab_focus.call_deferred()

func _load_dungeon():
	var level = load(GAME_SCENE).instantiate()
	for child in level.get_children():
		if child is TileMapLayer:
			level.remove_child(child)
			child.owner = null
			world.add_child(child)
	level.free()

func _fit():
	var screen_scale = get_viewport().get_final_transform().get_scale().x
	var pixel_scale = max(1.0, round(screen_scale * 3))
	var layer_scale = pixel_scale / screen_scale
	ui.scale = Vector2(layer_scale, layer_scale)
	root.size = get_viewport().get_visible_rect().size / layer_scale

func _hover_sound():
	blip.pitch_scale = 1.3
	blip.play()

func _play():
	if leaving:
		return
	leaving = true
	preload("res://hud.gd").intro_played = false
	if intro_tween:
		intro_tween.kill()
	var out = create_tween()
	out.tween_property(fade, "modulate:a", 1.0, 0.5)
	await out.finished
	$UI/Root/Buttons.hide()


	ResourceLoader.load_threaded_request(GAME_SCENE)
	var elapsed = 0.0
	var shown = 0.0
	while true:
		var delta = get_process_delta_time()
		elapsed += delta
		var progress = []
		var status = ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			get_tree().change_scene_to_file(GAME_SCENE)
			return
		var target = min(progress[0], elapsed / 0)
		shown = move_toward(shown, target, delta * 2.0)
		if status == ResourceLoader.THREAD_LOAD_LOADED and shown >= 1.0:
			break
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(GAME_SCENE))

func _quit():
	get_tree().quit()
