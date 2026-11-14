extends CanvasLayer

signal dialogue_finished

static var music_fade_in = false

const UI_SCALE = 3
const TOTAL_MEMORIES = 3
const CHARS_PER_SEC = 40.0

const HEART_FULL = preload("res://sprites/ui/heart_full.png")
const HEART_HALF = preload("res://sprites/ui/heart_half.png")
const HEART_EMPTY = preload("res://sprites/ui/heart_empty.png")
const FONT = preload("res://fonts/lazyfox.ttf")
const PANEL = preload("res://sprites/ui/dialog_panel.png")

const DEATH_LINES = [
	["", "Everything fades to black..."],
	["", "The memories you gathered slip through your fingers."],
	["???", "Falling was never the end of you."],
	["???", "Get up. Bounce back."],
]

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
var stay_paused = false
var dying = false
var death_overlay
var bounce_button
var hover_tween
var boss_bar
var boss_label
var boss_fill
var boss_tween

func _ready():
	add_to_group("hud")
	get_viewport().size_changed.connect(_fit)
	_fit()
	notice.modulate.a = 0.0
	dialogue.hide()
	_build_death_ui()
	_build_boss_bar()
	_connect_player.call_deferred()
	_fade_music_in.call_deferred()

func _music():
	for node in get_tree().current_scene.get_children():
		if (node is AudioStreamPlayer or node is AudioStreamPlayer2D) and node.autoplay:
			return node
	return null

func _fade_music_in():
	if not music_fade_in:
		return
	music_fade_in = false
	var music = _music()
	if music == null:
		return
	var target = music.volume_db
	music.volume_db = -40.0
	create_tween().tween_property(music, "volume_db", target, 1.5)

func _build_boss_bar():
	boss_bar = Control.new()
	boss_bar.visible = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_bar)
	root.move_child(boss_bar, death_overlay.get_index())
	boss_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	boss_bar.offset_left = -61
	boss_bar.offset_right = 61
	boss_bar.offset_top = -28
	boss_bar.offset_bottom = -8

	boss_label = Label.new()
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER ## is this how u centre a div lol
	boss_label.add_theme_font_override("font", preload("res://fonts/lazyfox.ttf"))
	boss_label.add_theme_font_size_override("font_size", 8)
	boss_label.add_theme_color_override("font_color", Color(0.995, 0.796, 0.0, 1.0))
	boss_label.add_theme_color_override("font_outline_color", Color(0.103, 0.08, 0.113, 1.0))
	boss_label.add_theme_constant_override("outline_size", 4)
	boss_label.size = Vector2(122, 10)
	boss_bar.add_child(boss_label)

	var frame = ColorRect.new()
	frame.color = Color(0.988, 0.8, 0.0, 1.0)
	frame.position = Vector2(0, 12)
	frame.size = Vector2(122, 8)
	boss_bar.add_child(frame)
	var back = ColorRect.new()
	back.color = Color(0.172, 0.119, 0.093, 1.0)
	back.position = Vector2(1, 1)
	back.size = Vector2(120, 6)
	frame.add_child(back)
	boss_fill = ColorRect.new()
	boss_fill.color = Color(0.843, 0.311, 0.209, 1.0)
	boss_fill.size = Vector2(120, 6)
	back.add_child(boss_fill)

func show_boss(boss_name, health, max_health):
	boss_label.text = boss_name
	update_boss(health, max_health)
	if boss_tween:
		boss_tween.kill()
	boss_bar.modulate.a = 0.0
	boss_bar.show()
	boss_tween = create_tween()
	boss_tween.tween_property(boss_bar, "modulate:a", 1.0, 0.4)

func update_boss(health, max_health):
	boss_fill.size.x = round(120.0 * health / max_health)

func hide_boss():
	if boss_tween:
		boss_tween.kill()
	boss_tween = create_tween()
	boss_tween.tween_interval(0.4)
	boss_tween.tween_property(boss_bar, "modulate:a", 0.0, 0.6)
	boss_tween.tween_callback(boss_bar.hide)

func _build_death_ui():
	death_overlay = ColorRect.new()
	death_overlay.color = Color(0.04, 0.02, 0.03)
	death_overlay.modulate.a = 0.0
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(death_overlay)
	root.move_child(death_overlay, dialogue.get_index())
	death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	bounce_button = Button.new()
	bounce_button.text = "Bounce Back"
	bounce_button.add_theme_font_override("font", FONT)
	bounce_button.add_theme_font_size_override("font_size", 8)
	bounce_button.add_theme_color_override("font_color", Color(0.98, 0.8, 0.24))
	bounce_button.add_theme_color_override("font_hover_color", Color.WHITE)
	bounce_button.add_theme_color_override("font_focus_color", Color(0.98, 0.8, 0.24))
	bounce_button.add_theme_color_override("font_pressed_color", Color(0.98, 0.8, 0.24))
	bounce_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["normal", "hover", "pressed"]:
		var box = StyleBoxTexture.new()
		box.texture = PANEL
		box.set_texture_margin_all(12)
		box.set_content_margin_all(10)
		if state == "hover":
			box.modulate_color = Color(1.25, 1.2, 1.1)
		elif state == "pressed":
			box.modulate_color = Color(0.8, 0.8, 0.8)
		bounce_button.add_theme_stylebox_override(state, box)
	bounce_button.custom_minimum_size = Vector2(96, 30)
	bounce_button.visible = false
	bounce_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bounce_button.pressed.connect(_bounce_back)
	bounce_button.mouse_entered.connect(_hover_button.bind(true))
	bounce_button.mouse_exited.connect(_hover_button.bind(false))
	root.add_child(bounce_button)
	bounce_button.set_anchors_preset(Control.PRESET_CENTER)
	bounce_button.position = (root.size - bounce_button.custom_minimum_size) / 2

func _hover_button(on):
	bounce_button.pivot_offset = bounce_button.size / 2
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween()
	var target = Vector2(1.08, 1.08) if on else Vector2.ONE
	hover_tween.tween_property(bounce_button, "scale", target, 0.08)
	if on:
		blip.pitch_scale = 1.3
		blip.play()

func player_died():
	if dying:
		return
	dying = true
	get_tree().paused = true
	if notice_tween:
		notice_tween.kill()
	notice.modulate.a = 0.0
	if boss_tween:
		boss_tween.kill()
	boss_bar.hide() ## this bug fixed yayadhahsdyhasydayhsdyh
	var music = _music()
	if music:
		create_tween().tween_property(music, "volume_db", -40.0, 1.2)
	var fade = create_tween()
	fade.tween_property(death_overlay, "modulate:a", 0.8, 0.8)
	await fade.finished
	await play_dialogue(DEATH_LINES, true)
	bounce_button.position = (root.size - bounce_button.size) / 2
	bounce_button.show()
	bounce_button.grab_focus()

func _bounce_back():
	music_fade_in = true
	get_tree().paused = false
	get_tree().reload_current_scene()

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

func play_dialogue(new_lines, keep_paused = false):
	lines = new_lines
	stay_paused = keep_paused
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
		if not stay_paused:
			get_tree().paused = false
		dialogue_finished.emit()
