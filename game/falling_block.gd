extends AnimatableBody2D

class_name FallingBlock

@export var stair_step_size: float
@export var health_points: float
@export var sprite: Sprite2D


enum States {FALLING, STOPPED}
var state: States = States.FALLING

var viewport_size = 0.0
var lava_timer = 0.0
var in_lava = false

const LAVA_DAMAGE_TICK = 1.0
const FALL_SPEED = 200.0


func _ready() -> void:
	viewport_size = get_viewport().get_visible_rect().size


func _process(delta: float) -> void:
	if is_instance_valid(self) and global_position.y > viewport_size.y:
		queue_free()
	if in_lava:
		lava_timer += delta
		if lava_timer >= LAVA_DAMAGE_TICK:
			lava_timer = 0.0
			health_points = clampf(health_points - 1.0, 0.0, 99999)
		if health_points <= 0.0:
			queue_free()


func _physics_process(delta: float) -> void:
	if state == States.FALLING:
		var collision = move_and_collide(FALL_SPEED * Vector2.DOWN * delta)
		if collision:
			# collision normal points up, so we're hitting something below us
			if collision.get_normal().y < 0:
				state = States.STOPPED
	elif state == States.STOPPED:
		var test_collision = move_and_collide(FALL_SPEED * Vector2.DOWN * delta, true)
		# if no collision at all, we should fall
		if not test_collision:
			state = States.FALLING
		# also even if there is a collision, we should still fall if the collision is on the sides or top
		elif test_collision:
			# move_and_collide only gives us one collision, and calling it multiple times may return different collisions
			# so we call it twice and try to determine if any of the collisions are a floor
			var test_collision2 = move_and_collide(FALL_SPEED * Vector2.DOWN * delta, true)
			if test_collision == test_collision2 and not test_collision.get_normal().y < 0:	
				state = States.FALLING


func enter_lava() -> void:
	sprite.self_modulate = Color(1.0, 0.5, 0.5, 1.0)
	in_lava = true


func is_falling() -> bool:
	return state == States.FALLING
