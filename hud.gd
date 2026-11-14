extends CanvasLayer

signal dialogue_finished

const UI_SCALE = 3
const TOTAL_MEMORIES = 3
const CHARS_PER_SEC = 40.0

const HEART_FULL = preload("res://sprites/ui/heart_full.png")
const HEART_HALF = preload("res://sprites/ui/heart_half.png")
const HEART_EMPTY = preload("res://sprites/ui/heart_empty.png")

@onready var root = $Root
@onready var hearts = $Root/Hearts
@onready var notice = $Root/Notice
@onready var dialogue = $Root/Dialogue
@onready var speaker = $Root/Dialogue/Speaker
@onready var text = $Root/Dialogue/Text
@onready var next_hint = $Root/Dialogue/Next
@onready var blip = $Blip

var memories_found = 0
var lines = []
var line_index = 0
var typing = false
var char_timer = 0.0
var notice_tween

func _ready():
	add_to_group("hud")
	get_viewport().size_changed.connect(_fit)
	_fit()
	notice.modulate.a = 0.0
	dialogue.hide()
	_connect_player.call_deferred()

func _fit():
	var screen_scale = get_viewport().get_final_transform().get_scale().x
	var pixel_scale = max(1.0, round(screen_scale * UI_SCALE))
	var layer_scale = pixel_scale / screen_scale
	scale = Vector2(layer_scale, layer_scale)
	root.size = get_viewport().get_visible_rect().size / layer_scale

func _connect_player():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_update_hearts)
		_update_hearts(player.health, player.max_health)
	show_notice("Walk towards the first memory", 4.0)

func _update_hearts(health, max_health):
	for child in hearts.get_children():
		child.queue_free()
	for i in max_health:
		var heart = TextureRect.new()
		if health >= i + 1:
			heart.texture = HEART_FULL
		elif health > i:
			heart.texture = HEART_HALF
		else:
			heart.texture = HEART_EMPTY
		hearts.add_child(heart)

func show_notice(message, seconds = 3.0):
	notice.text = message
	if notice_tween:
		notice_tween.kill()
	notice_tween = create_tween()
	notice_tween.tween_property(notice, "modulate:a", 1.0, 0.3)
	notice_tween.tween_interval(seconds)
	notice_tween.tween_property(notice, "modulate:a", 0.0, 0.6)

func memory_found():
	memories_found += 1
	show_notice("%d/%d memories found" % [memories_found, TOTAL_MEMORIES])

func play_dialogue(new_lines):
	lines = new_lines
	line_index = 0
	get_tree().paused = true
	dialogue.show()
	_show_line()
	await dialogue_finished

func _show_line():
	var line = lines[line_index]
	speaker.text = line[0]
	speaker.visible = line[0] != ""
	text.text = line[1]
	text.visible_characters = 0
	char_timer = 0.0
	typing = true
	next_hint.hide()

func _finish_line():
	text.visible_characters = -1
	typing = false
	next_hint.show()

func _process(delta):
	if not typing:
		return
	char_timer += delta * CHARS_PER_SEC
	var shown = int(char_timer)
	if shown > text.visible_characters:
		if shown % 3 == 0 and text.text[min(shown, text.text.length()) - 1] != " ":
			blip.pitch_scale = randf_range(0.95, 1.05)
			blip.play()
		text.visible_characters = shown
	if shown >= text.text.length():
		_finish_line()

func _unhandled_input(event):
	if not dialogue.visible:
		return
	var pressed = event.is_action_pressed("ui_accept")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if typing:
		_finish_line()
		return
	line_index += 1
	if line_index < lines.size():
		_show_line()
	else:
		dialogue.hide()
		get_tree().paused = false
		dialogue_finished.emit()
