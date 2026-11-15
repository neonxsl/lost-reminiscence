extends AnimatedSprite2D

@onready var anim: AnimatedSprite2D = $Torch1

func _ready() -> void:
	play("default")
