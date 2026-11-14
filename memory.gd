extends Area2D

@export_multiline var dialogue_text = ""

@onready var sprite = $Sprite2D

var taken = false

func _ready():
	collision_mask = 4
	body_entered.connect(_on_body_entered)
	var pulse = create_tween().set_loops()
	pulse.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(sprite, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	var bob = create_tween().set_loops()
	bob.tween_property(sprite, "position:y", -2.0, 1.1).set_trans(Tween.TRANS_SINE)
	bob.tween_property(sprite, "position:y", 2.0, 1.1).set_trans(Tween.TRANS_SINE)

func _parse_lines():
	var lines = []
	for raw in dialogue_text.split("\n", false):
		var parts = raw.split(": ", true, 1)
		if parts.size() == 2:
			lines.append([parts[0], parts[1]])
		else:
			lines.append(["", raw])
	return lines

func _on_body_entered(body):
	if taken or not body.is_in_group("player"):
		return
	taken = true
	set_deferred("monitoring", false)
	hide()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		await hud.play_dialogue(_parse_lines())
		hud.memory_found()
	queue_free()
