extends CharacterBody2D

@export var debug_text: RichTextLabel
@export var camera: Camera2D

@onready var top_crush_detector = $TopCrushDetector
@onready var bottom_crush_detector = $BottomCrushDetector
@onready var sprite = $Sprite2D
@onready var dust_particles: GPUParticles2D = $DustPuff
@onready var player_default_collision_shape: CollisionShape2D = $DefaultCollision
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const SPRITE_HEIGHT = 64.0 # pixels
const PLAYER_HEIGHT = 6.0 # simulate player as 6 feet tall
const HORIZONTAL_SPEED = 350.0
const HORIZONTAL_MOVEMENT_DECAY = 100.0
const DOUBLE_JUMP_VELOCITY = -450.0
const WALL_JUMP_VERTICAL_FORCE = -600.0
const WALL_JUMP_HORIZONTAL_FORCE = 350.0
const WALL_JUMP_HORIZONTAL_DECAY = 40.0
const SLIDE_DOWN_SPEED = 40.0
const MAX_JUMP_VELOCITY = -800.0

signal game_over(max_height: int, time_to_max_height: float)
signal scroll_read(scroll: Sprite2D)
signal ghost_last_words(text: String, pos)

var wall_jump_force_x = 0.0
var last_collision_normal = Vector2.ZERO
var prev_position = 0.0
var prev_velocity = 0.0
var last_wall_collision = null

var gravity_mult = 2.0
var jump_velocity = -600.0
var has_double_jump_energy = true

enum States {ON_FLOOR, FALLING, ON_WALL, CRUSHED, BURNT, JUMP_START, JUMP_ASCENT, JUMP_SQUEEZE, DEAD}
var state: States = States.ON_FLOOR: set = set_state
const INTERNAL_TRANSITIONS_ALLOWED = [States.JUMP_ASCENT, States.ON_WALL]

var initial_height = 0.0
var current_height = 0.0
var max_height = 0.0
var time_to_max_height = 0.0
var num_souls_released = 0
var num_scrolls_read = 0
var cloak_color = Color(0.682, 0.149, 0.11, 1.0)

var input_lock_timer = 0.0
const INPUT_LOCK_DURATION = 0.1

var time_since_last_record: float = 0.0
const RECORD_INTERVAL_S: float = 0.5

var deleteable_ghosts: Array = []


func _ready() -> void:
	Recorder.current_data.clear()
	gravity_mult = 2.0
	# do an initial slide down to get the character grounded on the floor
	velocity += get_gravity() * gravity_mult
	move_and_slide()
	
	initial_height = position.y
	jump_velocity = -600.0
	has_double_jump_energy = true
	num_souls_released = 0
	num_scrolls_read = 0
	animation_player.play("RESET")
	player_default_collision_shape.position = Vector2(0.5, 2.0)
	player_default_collision_shape.scale = Vector2(1.0, 1.0)
	player_default_collision_shape.disabled = false
	sprite.play("idle")


func set_state(new_state: int) -> void:
	var previous_state = state

	# states without internal transitions allowed
	if new_state == previous_state and new_state not in INTERNAL_TRANSITIONS_ALLOWED:
		return
	# dead is a terminal state
	if state == States.DEAD:
		return

	state = new_state
	
	# enter state conditions
	if state == States.ON_FLOOR:
		has_double_jump_energy = true
		Recorder.current_data.append([global_transform.get_origin(), GameGlobals.game_tick])
		sprite.play("land")
		dust_particles.restart()
	elif state == States.FALLING:
		Recorder.current_data.append([global_transform.get_origin(), GameGlobals.game_tick])
		sprite.play("in_air")
	elif state == States.ON_WALL:
		var wall_collisions = get_wall_collisions()
		# the falling conditions in physics_process should prevent going to ON_WALL without a wall collision
		# but just in case
		if len(wall_collisions) > 0:
			sprite.play("on_wall")
			last_wall_collision = wall_collisions[0]
			var collided_object = last_wall_collision.get_collider()
			last_collision_normal = last_wall_collision.get_normal()
			if collided_object is FallingBlock:
				var attached_block = collided_object
				if attached_block.is_falling():
					velocity.y = attached_block.FALL_SPEED
				else:
					velocity.y = 0.0
				velocity.y += SLIDE_DOWN_SPEED  # Slide down slowly
			has_double_jump_energy = true
	elif state == States.CRUSHED:
		Recorder.current_data.append([global_transform.get_origin(), GameGlobals.game_tick])
		sprite.play("crush")
	elif state == States.BURNT:
		Recorder.current_data.append([global_transform.get_origin(), GameGlobals.game_tick])
		animation_player.play("burn")
		print("burnt")
	elif state == States.DEAD:
		Recorder.current_data.append([global_transform.get_origin(), GameGlobals.game_tick])
		print("dead")
		await get_tree().create_timer(1.0).timeout
		print('emitting game over')
		game_over.emit(max_height, time_to_max_height)
	elif state == States.JUMP_START:
		Recorder.current_data.append([global_transform.get_origin(), GameGlobals.game_tick])
		sprite.play("land")
		dust_particles.restart()
	elif state == States.JUMP_ASCENT:
		Recorder.current_data.append([global_transform.get_origin(), GameGlobals.game_tick])
		sprite.play("jump")
		
		if previous_state == States.ON_WALL:
			velocity.y = WALL_JUMP_VERTICAL_FORCE
			velocity.x = last_collision_normal.x * WALL_JUMP_HORIZONTAL_FORCE
			input_lock_timer = INPUT_LOCK_DURATION
		elif previous_state == States.FALLING:
			velocity.y = DOUBLE_JUMP_VELOCITY
			has_double_jump_energy = false
		elif previous_state == States.JUMP_ASCENT:
			velocity.y = clampf(velocity.y + DOUBLE_JUMP_VELOCITY, jump_velocity, velocity.y)
			has_double_jump_energy = false
		else:
			velocity.y = jump_velocity
	elif state == States.JUMP_SQUEEZE:
		player_default_collision_shape.scale.x = 0.2
		velocity.y = jump_velocity
		Recorder.current_data.append([global_transform.get_origin(), GameGlobals.game_tick])
		sprite.play("land")
	
	# exit state conditions
	# revert back to regular scale whenever exiting JUMP_SQUEEZE
	if previous_state == States.JUMP_SQUEEZE:
		player_default_collision_shape.scale.x = 1.0


func _process(_delta: float) -> void:
	var current_state = States.keys()[state]
	current_height = round(floor(-1 * (position.y - initial_height)) * (PLAYER_HEIGHT / SPRITE_HEIGHT))
	if current_height > max_height:
		max_height = current_height
		time_to_max_height = GameGlobals.game_tick
	#debug_text.clear()
	#debug_text.append_text(current_state + "\n" + str(has_double_jump_energy))
	#debug_text.append_text(str(Engine.get_frames_per_second()))


func _physics_process(delta: float) -> void:
	# Handle the timed action
	time_since_last_record += delta
	if time_since_last_record >= RECORD_INTERVAL_S:
		time_since_last_record -= RECORD_INTERVAL_S
		Recorder.current_data.append([global_transform.get_origin(), GameGlobals.game_tick])
	
	if input_lock_timer > 0.0:
		input_lock_timer -= delta
		
	if len(deleteable_ghosts) > 0 and Input.is_action_just_pressed("delete_ghost"):
		delete_ghost()
		
	if num_souls_released > 0 and Input.is_action_just_pressed("shrink"):
		shrink()

	if state == States.CRUSHED:
		return
		
	elif state == States.BURNT:
		sprite.stop()
		return

	var viewport_size = get_viewport().get_visible_rect().size
	var direction = 0.0
	if input_lock_timer <= 0.0:
		direction = Input.get_axis("move_left", "move_right")
	
	var wall_collisions = get_wall_collisions()
	

	velocity += get_gravity() * gravity_mult * delta

	# FALLING CONDITIONS
	if state == States.JUMP_ASCENT and velocity.y > 0.0:
		state = States.FALLING
	elif state == States.ON_FLOOR and not is_on_floor():
		state = States.FALLING
	elif state == States.ON_WALL and len(wall_collisions) == 0 and not is_on_floor():
		state = States.FALLING
	elif state in [States.FALLING, States.ON_WALL] and is_on_floor():
		state = States.ON_FLOOR

	# JUMP CONDITIONS.
	elif state == States.ON_FLOOR and Input.is_action_just_pressed("jump"):
		# this will start an animation and when that animation ends, it will trigger transition to JUMP_ASCENT
		state = States.JUMP_START
	elif len(wall_collisions) == 2 and Input.is_action_just_pressed("jump"):
		state = States.JUMP_SQUEEZE
	elif state == States.JUMP_SQUEEZE and velocity.y > 0.0:
		wall_collisions = get_wall_collisions()
		if len(wall_collisions) == 0:
			state = States.FALLING
		if len(wall_collisions) >= 1:
			state = States.ON_WALL
	elif state == States.ON_WALL and Input.is_action_just_released("jump"):
		state = States.JUMP_ASCENT
	elif state == States.ON_WALL and Input.is_action_pressed("jump"):
		state = States.ON_WALL
	elif state in [States.FALLING, States.JUMP_ASCENT] and has_double_jump_energy and Input.is_action_just_pressed("jump"):
		state = States.JUMP_ASCENT
	elif state != States.ON_WALL and len(wall_collisions) == 1 and Input.is_action_pressed("jump") and not is_on_floor():
		state = States.ON_WALL

	# Get the input direction and handle the movement/deceleration.
	elif direction:
		if state == States.ON_FLOOR:
			Recorder.current_data.append([global_transform.get_origin(), GameGlobals.game_tick])
			sprite.play("walk")
		velocity.x = direction * HORIZONTAL_SPEED

		var need_flip = sign(velocity.x) == -1
		sprite.flip_h = need_flip
		$RampCheck.scale.x = sign(velocity.x)
		if need_flip:
			$AutoSeparation.position.x = -8
		else:
			$AutoSeparation.position.x = 8
		if velocity.y >= 0.0:
			var on_block_ramp = $RampCheck/RampRay.is_colliding() and not $RampCheck/WallRay.is_colliding() and $RampCheck/RampRay.get_collider() is FallingBlock
			if on_block_ramp:
				var collider = $RampCheck/RampRay.get_collider()
				$AutoSeparation.shape.length = collider.stair_step_size
			$AutoSeparation.disabled = not on_block_ramp
			
	else:
		if state == States.ON_FLOOR:
			sprite.play("idle")
			velocity.x = move_toward(velocity.x, 0, HORIZONTAL_SPEED)
		else:
			velocity.x = move_toward(velocity.x, 0, WALL_JUMP_HORIZONTAL_DECAY)
		$AutoSeparation.disabled = true

	move_and_slide()

	if is_on_ceiling():
		# allow player to move out from under the falling rock
		velocity.y += 1
		move_and_slide()
	
	if state in [States.FALLING, States.JUMP_ASCENT]:
		Recorder.current_data.append([global_transform.get_origin(), GameGlobals.game_tick])

	# wrap position if you go beyond the screen limits
	position.x = wrapf(position.x, 0.0, viewport_size.x)

	var top_objects = top_crush_detector.get_overlapping_bodies()
	var bottom_objects = bottom_crush_detector.get_overlapping_bodies()

	if top_objects.size() > 0 and bottom_objects.size() > 0:
		check_if_crushed(top_objects, bottom_objects)


func check_if_crushed(top_objects, bottom_objects):
	# floor is never falling
	var bottom_block_falling = false
	# bottom is a block (we're on a falling block)
	if bottom_objects[0] is FallingBlock:
		bottom_block_falling = bottom_objects[0].state == bottom_objects[0].States.FALLING
	var top_block_falling = top_objects[0].state == top_objects[0].States.FALLING

	print("top falling: " + str(top_block_falling) + "(" + str(top_objects[0]) + ")")
	print("bottom falling: " + str(bottom_block_falling) + "(" + str(bottom_objects[0]) + ")")
	
	if not bottom_block_falling and top_block_falling:
		state = States.CRUSHED


func is_on_floor_test():
	var collision = move_and_collide(Vector2.DOWN, true)
	if collision:
		return true
	else:
		return false


func get_wall_collisions():
	var collisions = []
	var left_collision = move_and_collide(Vector2.LEFT * 2, true)
	var right_collision = move_and_collide(Vector2.RIGHT * 2, true)

	if left_collision != null:
		collisions.append(left_collision)
	if right_collision != null:
		collisions.append(right_collision)
	return collisions


func can_delete_ghost(ghost):
	deleteable_ghosts.append(ghost)


func cannot_delete_ghost(ghost):
	deleteable_ghosts.erase(ghost)


func delete_ghost():
	print("deleting ghost")
	var ghost = deleteable_ghosts.pop_back()
	num_souls_released += 1
	var last_words = ghost.get_last_words()
	ghost_last_words.emit(last_words, ghost.global_position)
	ghost.fade_out()


func apply_scroll_effect(scroll):
	print('emitting scroll read')
	num_scrolls_read += 1
	scroll_read.emit(scroll)
	if scroll.scroll_effect:
		gravity_mult = 1.0
		jump_velocity = max(jump_velocity - 10.0, MAX_JUMP_VELOCITY)


func remove_scroll_effect(scroll):
	gravity_mult = 2.0


func shrink():
	num_souls_released -= 1
	scale = Vector2(0.5, 0.5)
	await get_tree().create_timer(3.0).timeout
	scale = Vector2(1.0, 1.0)


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "burn":
		state = States.DEAD


func _on_sprite_2d_animation_finished() -> void:
	if state == States.CRUSHED:
		state = States.DEAD
	elif state == States.JUMP_START:
		state = States.JUMP_ASCENT


func set_cloak_color(color: Color) -> void:
	cloak_color = color
	sprite.get_material().set_shader_parameter("cloak_color", cloak_color)
