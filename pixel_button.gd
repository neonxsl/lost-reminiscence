extends Button

const FONT = preload("res://fonts/lazyfox.ttf")
const PANEL = preload("res://sprites/ui/dialog_panel.png")
const GOLD = Color(0.98, 0.8, 0.24)

signal hovered

var hover_tween

func _ready():
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", 8)
	add_theme_color_override("font_color", GOLD)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_focus_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", GOLD)
	add_theme_color_override("font_hover_pressed_color", GOLD)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["normal", "hover", "pressed"]:
		var box = StyleBoxTexture.new()
		box.texture = PANEL
		box.set_texture_margin_all(12)
		box.set_content_margin_all(10)
		if state == "hover":
			box.modulate_color = Color(1.25, 1.2, 1.1)
		elif state == "pressed":
			box.modulate_color = Color(0.8, 0.8, 0.8)
		add_theme_stylebox_override(state, box)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(grab_focus)
	focus_entered.connect(_highlight.bind(true))
	focus_exited.connect(_highlight.bind(false))

func _highlight(on):
	pivot_offset = size / 2
	modulate = Color(1.2, 1.2, 1.2, 1.0) if on else Color.WHITE
	if hover_tween:
		hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", Vector2(1.08, 1.08) if on else Vector2.ONE, 0.08)
	if on:
		hovered.emit()
