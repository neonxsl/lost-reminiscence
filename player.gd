extends CharacterBody2D

const SPEED = 80.0

@onready var anim = $AnimatedSprite2D

func _physics_process(_delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED
	move_and_slide()

	if direction != Vector2.ZERO:
		anim.play("default")

	if direction.x != 0:
		anim.flip_h = direction.x < 0
