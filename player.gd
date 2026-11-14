extends CharacterBody2D

const SPEED = 60.0

@onready var anim = $AnimatedSprite2D
@onready var steps = $Footsteps

func _physics_process(_delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED
	move_and_slide()

	if direction != Vector2.ZERO:
		anim.play("default")
		if not steps.playing:
			steps.play()
	else:
		steps.stop()

	if direction.x != 0:
		anim.flip_h = direction.x < 0
