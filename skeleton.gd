extends CharacterBody2D

@export var speed = 35.0
@export var chase_range = 80.0
@export var max_health = 3
@export var knockback_strength = 140.0

@onready var anim = $AnimatedSprite2D
@onready var hitbox = $Hitbox

var rest_time = 0.0
var health
var knockback = Vector2.ZERO
var dead = false

func _ready():
	collision_layer = 2
	collision_mask = 1
	hitbox.collision_mask = 4
	health = max_health

func hurt(amount, from_position):
	if dead:
		return
	health -= amount
	knockback = (global_position - from_position).normalized() * knockback_strength
	rest_time = max(rest_time, 0.4)
	var flash = create_tween()
	flash.tween_property(anim, "self_modulate", Color(1, 0.4, 0.4), 0.05)
	flash.tween_property(anim, "self_modulate", Color.WHITE, 0.15)
	if health <= 0:
		_die()

func _die():
	dead = true
	collision_layer = 0
	hitbox.set_deferred("monitoring", false)
	var fade = create_tween()
	fade.tween_property(anim, "modulate:a", 0.0, 0.3)
	fade.tween_callback(queue_free)

func _physics_process(delta):
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	knockback = knockback.move_toward(Vector2.ZERO, 600.0 * delta)
	if dead:
		velocity = knockback
		move_and_slide()
		return

	rest_time = max(rest_time - delta, 0.0)
	var to_player = player.global_position - global_position
	if knockback.length() > 5.0:
		velocity = knockback
	elif rest_time > 0.0:
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
