extends CharacterBody2D

const SPEED = 60.0

signal health_changed(health, max_health)

@onready var anim = $AnimatedSprite2D
@onready var steps = $Footsteps

var max_health = 3
var health = 3
var invincible = false

func _ready():
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	anim.play("default")

func _physics_process(_delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED
	move_and_slide()

	if direction != Vector2.ZERO:
		if not steps.playing:
			steps.play()
	else:
		steps.stop()

	if direction.x != 0:
		anim.flip_h = direction.x < 0

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
