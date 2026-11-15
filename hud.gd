extends CanvasLayer

signal dialogue_finished
signal progress_changed

static var music_fade_in = false
static var intro_played = false

const UI_SCALE = 3
const TOTAL_MEMORIES = 3
const CHARS_PER_SEC = 40.0

const HEART_FULL = preload("res://sprites/ui/heart_full.png")
const HEART_HALF = preload("res://sprites/ui/heart_half.png")
const HEART_EMPTY = preload("res://sprites/ui/heart_empty.png")
const FONT = preload("res://fonts/lazyfox.ttf")
const PANEL = preload("res://sprites/ui/dialog_panel.png")
const PIXEL_BUTTON = preload("res://pixel_button.gd")

const MENU_SCENE = "res://menu.tscn"

const BLESSINGS = {
	"resistance": ["Resistance", "Blessing: you take 25% less damage", "Take 25% less damage"],
	"speed": ["Speed", "Blessing: you move 25% faster", "Move 25% faster"],
}

signal blessing_chosen(blessing)

const ENDING_LINES = [
	"He rushes through the maze, his memories guiding him",
	"Alone he stood in this prison.",
	"Alone he left.",
	"Thanks for playing Lost Reminiscence.",
]

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
var notice_queue = []
var defeated_bosses = []
var collected_memories = []
var stay_paused = false
var dying = false
var death_overlay
var bounce_button
var hover_tween
var pause_menu
var resume_button
var boss_bar
var boss_label
var boss_fill
var boss_tween
var intro_layer
var intro_text
var in_intro = false

const INTRO_LINES = [ ## holy aura speech
	"Darkness.",
	"No name. No past. Only cold stone beneath you.",
	"Your memories lie scattered through this maze, glowing like embers.",
	"Gather them, and you will remember who you are.",
	"But something guards the way. A Vampire waits in the halls ahead.",
	"Defeat it. Find yourself.",
]

func _ready():
	add_to_group("hud")
	get_viewport().size_changed.connect(_fit)
	_fit()
	notice.modulate.a = 0.0
	dialogue.hide()
	_build_death_ui()
	_build_boss_bar()
	_build_pause_menu()
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

func _build_pause_menu():
	pause_menu = Control.new()
	pause_menu.visible = false
	root.add_child(pause_menu)
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim = ColorRect.new()
	dim.color = Color(0.041, 0.019, 0.03, 0.65)
	pause_menu.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_menu.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title = Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", preload("res://fonts/lazyfox.ttf"))
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", Color(0.995, 0.796, 0.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.12, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	box.add_child(title)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	box.add_child(spacer)

	resume_button = _pause_button(box, "Resume", _resume)
	_pause_button(box, "Restart", _restart)
	_pause_button(box, "Main Menu", _main_menu)

func _pause_button(parent, label, action):
	var button = PIXEL_BUTTON.new()
	button.text = label
	button.custom_minimum_size = Vector2(96, 26) ## gahhh "how do you centre a div?"
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	button.hovered.connect(_menu_blip)
	parent.add_child(button)
	return button
func _menu_blip():
	blip.pitch_scale = 1.3
	blip.play()
func _toggle_pause():
	if pause_menu.visible:
		_resume()
	elif not get_tree().paused and not dying:
		get_tree().paused = true
		pause_menu.show()
		resume_button.grab_focus()
func _resume():
	pause_menu.hide()
	get_tree().paused = false

func _restart():
	get_tree().paused = false
	get_tree().reload_current_scene()
func _main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
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
	notice_queue.clear()
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
	if not intro_played:
		intro_played = true
		await _play_intro()
	show_notice("Walk towards the first memory", 4.0)

func _play_intro():
	in_intro = true
	get_tree().paused = true
	intro_layer = ColorRect.new()
	intro_layer.color = Color(0.02, 0.01, 0.02, 1.0)
	root.add_child(intro_layer)
	intro_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_text = Label.new()
	intro_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_text.add_theme_font_override("font", preload("res://fonts/lazyfox.ttf"))
	intro_text.add_theme_font_size_override("font_size", 8)
	intro_text.add_theme_color_override("font_color", Color(0.93, 0.9, 0.85))
	intro_layer.add_child(intro_text)
	intro_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_text.offset_left = 60
	intro_text.offset_right = -60
	for line in INTRO_LINES:
		intro_text.text = line
		intro_text.modulate.a = 0.0
		var t = create_tween()
		t.tween_property(intro_text, "modulate:a", 1.0, 0.8)
		t.tween_interval(2.0)
		t.tween_property(intro_text, "modulate:a", 0.0, 0.6)
		await t.finished
	intro_text.hide()
	var out = create_tween()
	out.tween_property(intro_layer, "modulate:a", 0.0, 1.0)
	await out.finished
	intro_layer.queue_free()
	in_intro = false
	get_tree().paused = false

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
	notice_queue.append([message, seconds])
	if notice_queue.size() == 1:
		_next_notice()

func _next_notice():
	if notice_queue.is_empty():
		return
	var item = notice_queue[0]
	notice.text = item[0]
	if notice_tween:
		notice_tween.kill()
	notice_tween = create_tween()
	notice_tween.tween_property(notice, "modulate:a", 1.0, 0.3)
	notice_tween.tween_interval(item[1])
	notice_tween.tween_property(notice, "modulate:a", 0.0, 0.6)
	notice_tween.tween_callback(_notice_done)

func _notice_done():
	if not notice_queue.is_empty():
		notice_queue.pop_front()
	_next_notice()

func memory_found(id = ""):
	memories_found += 1
	collected_memories.append(id)
	show_notice("%d/%d memories found" % [memories_found, TOTAL_MEMORIES])
	progress_changed.emit.call_deferred()

func play_ending():
	get_tree().paused = true
	in_intro = true
	await get_tree().create_timer(2.5).timeout
	var music = _music()
	if music:
		create_tween().tween_property(music, "volume_db", -40.0, 2.0)
	var backdrop = ColorRect.new()
	backdrop.color = Color(0.02, 0.01, 0.02)
	backdrop.modulate.a = 0.0
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fade = create_tween()
	fade.tween_property(backdrop, "modulate:a", 1.0, 1.5)
	await fade.finished
	var label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", preload("res://fonts/lazyfox.ttf"))
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.93, 0.9, 0.85))
	backdrop.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 60
	label.offset_right = -60
	for i in ENDING_LINES.size():
		label.text = ENDING_LINES[i]
		label.modulate.a = 0.0
		var t = create_tween()
		t.tween_property(label, "modulate:a", 1.0, 0.8)
		if i < ENDING_LINES.size() - 1:
			t.tween_interval(2.0)
			t.tween_property(label, "modulate:a", 0.0, 0.6)
		await t.finished
	in_intro = false
	var button = PIXEL_BUTTON.new()
	button.text = "Main Menu"
	button.custom_minimum_size = Vector2(96, 26)
	button.pressed.connect(_main_menu)
	button.hovered.connect(_menu_blip)
	backdrop.add_child(button)
	button.position = Vector2((root.size.x - 96) / 2, root.size.y / 2 + 24)
	button.grab_focus()

## no one will ever see this ... :DDDDD

func choose_blessing():
	get_tree().paused = true
	var screen = Control.new()
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim = ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.03, 0.7)
	screen.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title = _ui_label("Choose a blessing", Color(0.98, 0.8, 0.24))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.12))
	title.add_theme_constant_override("outline_size", 4)
	screen.add_child(title)
	title.position = Vector2(0, root.size.y / 2 - 44)
	title.size = Vector2(root.size.x, 10)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	screen.add_child(row)
	var first: Control = null
	for key in BLESSINGS:
		var column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		row.add_child(column)
		var button = PIXEL_BUTTON.new()
		button.text = BLESSINGS[key][0]
		button.custom_minimum_size = Vector2(96, 26)
		button.pressed.connect(func(): blessing_chosen.emit(key))
		button.hovered.connect(_menu_blip)
		column.add_child(button)
		var info = _ui_label(BLESSINGS[key][2], Color(0.85, 0.8, 0.72))
		column.add_child(info)
		if first == null:
			first = button
	row.position = Vector2((root.size.x - 208) / 2, root.size.y / 2 - 26)
	first.grab_focus()
	var choice = await blessing_chosen
	screen.queue_free()
	get_tree().paused = false
	return choice

func _ui_label(text_value, color):
	var label = Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", preload("res://fonts/lazyfox.ttf"))
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	return label

func boss_defeated(boss_name):
	defeated_bosses.append(boss_name)
	progress_changed.emit()

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
	if in_intro:
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not dialogue.visible:
		get_viewport().set_input_as_handled()
		_toggle_pause()
		return
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
