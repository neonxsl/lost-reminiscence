extends CharacterBody2D

@export var speed = 35.0
@export var chase_range = 80.0

@onready var anim = $AnimatedSprite2D
@onready var hitbox = $Hitbox

var rest_time = 0.0

func _ready():
	collision_layer = 2
	collision_mask = 1
	hitbox.collision_mask = 4

func _physics_process(delta):
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	rest_time = max(rest_time - delta, 0.0)
	var to_player = player.global_position - global_position
	if rest_time > 0.0:
		velocity = Vector2.ZERO
	elif to_player.length() <= chase_range:
		velocity = to_player.normalized() * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if velocity.x != 0:
		anim.flip_h = velocity.x < 0

	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.take_damage(1):
			rest_time = 1.5
