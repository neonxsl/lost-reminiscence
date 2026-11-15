extends Area2D

@export_multiline var dialogue_text = ""
@export var grants = ""
@export var grants_notice = ""
@export var offer_blessing = false

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
	if hud:
		hud.memory_found(name)
	var blessing = ""
	if offer_blessing and hud and body.has_method("unlock"):
		blessing = await hud.choose_blessing()
		body.unlock(blessing)
	if grants == "ending" and hud:
		hud.play_ending()
	elif grants != "" and body.has_method("unlock"):
		body.unlock(grants)
		if hud and grants_notice != "":
			hud.show_notice(grants_notice, 3.5)
	if blessing != "" and hud:
		hud.show_notice(hud.BLESSINGS[blessing][1], 3.5)
	queue_free()
