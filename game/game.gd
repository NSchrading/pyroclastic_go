extends Node2D

@export var jumper: CharacterBody2D
@export var wall_timer: Timer
@export var falling_block_small: PackedScene
@export var falling_block_medium: PackedScene
@export var falling_block_tall_small: PackedScene
@export var falling_column: PackedScene
@export var falling_staircase: PackedScene
@export var scroll: PackedScene
@export var lava: Area2D
@export var background_rect: ColorRect

@export var min_height: float = 0.0  # Height at bottom of game
@export var max_height: float = 1000.0 # Height at top of game
@export var bottom_color: Color = Color.from_rgba8(228, 104, 50, 255)
@export var top_color: Color = Color.from_rgba8(78, 173, 245, 255)

@export var trigger_spawn_screen_percent: float = 0.55 # Spawn when top block below this % from screen top
@export var player_horizontal_reach: float = 200.0
@export var spawn_y_offset: float = 64

@onready var ash_particles = $AshLayer/GPUParticles2D
@onready var parallax_canvas = $ParallaxCanvasLayer
@onready var volcano_smoke = $ParallaxCanvasLayer/VolcanoBackground/VolcanoSmoke
@onready var volcano_lava = $ParallaxCanvasLayer/VolcanoBackground/VolcanoLava
@onready var lava_flow_animation = $ParallaxCanvasLayer/VolcanoBackground/Control/LavaFlow/AnimationPlayer
@onready var cloud_sprite = $ParallaxCanvasLayer/CloudBackground/Sprite2D
@onready var cinematic_camera = $CinematicCamera2D
@onready var cinematic_animation = $CinematicCamera2D/CinematicAnimationPlayer
@onready var cloud_olympus = $CloudOlympus
@onready var background_canvas = $CanvasLayer
@onready var scroll_spawn_timer = $SpawnTimer

# localized random number generator to ensure consistent block generation on seeds
var game_rng = RandomNumberGenerator.new()

var first_game = true
var screen_size: Vector2
var most_recently_spawned_block = null
var recorded_block_index = 0
var random_block_vals = []
var random_block_pos = []
var start_time = null

signal show_loading_screen(bool)
signal update_loading_progress(float)

func _ready() -> void:
	print("game ready called")
	game_rng.seed = GameGlobals.game_seed.hash()

	GameGlobals.game_tick = 0.0
	Recorder.new_block_data.clear()
	recorded_block_index = 0
	screen_size = get_viewport().get_visible_rect().size
	most_recently_spawned_block = null

	print("First game: " + str(first_game))
	if first_game:
		start_intro_cutscene()
	else:
		ash_particles.emitting = true
		volcano_smoke.emitting = true
		volcano_lava.emitting = true
		lava_flow_animation.play("lava_flow")
		scroll_spawn_timer.start()


func set_all_processing(paused: bool):
	set_physics_process(paused)
	set_process(paused)
	jumper.set_physics_process(paused)
	jumper.set_process(paused)
	lava.set_physics_process(paused)
	lava.set_process(paused)

	
func start_intro_cutscene():
	set_all_processing(false)

	# For platforms like web that are really slow at compiling particles on first load
	lava.lava_particles.position.y = 300
	lava.lava_particles.emitting = true
	await get_tree().process_frame
	update_loading_progress.emit(5.0)
	ash_particles.emitting = true
	await get_tree().process_frame
	update_loading_progress.emit(40.0)
	volcano_smoke.emitting = true
	await get_tree().process_frame
	update_loading_progress.emit(60.0)
	volcano_lava.emitting = true
	await get_tree().process_frame
	update_loading_progress.emit(90.0)
	jumper.dust_particles.restart()
	await get_tree().process_frame
	update_loading_progress.emit(100.0)
	
	var prewarm_frames_to_wait = 20
	for i in range(prewarm_frames_to_wait):
		await get_tree().process_frame
	
	lava.lava_particles.position.y = 688

	show_loading_screen.emit(false)
	
	cinematic_camera.make_current()
	cinematic_animation.play("erupt_animation")
	
	var scroll_node = scroll.instantiate()
	add_child(scroll_node)
	scroll_node.position.x = 219.0
	scroll_node.position.y = -110.0
	scroll_node.move_random = false
	scroll_node.set_text("Get jumping!\n                                     Love, Zeus")
	scroll_node.set_effect(false)
	await cinematic_animation.animation_finished
	
	# make sure the game starts ticking now, when the game is actually playing
	# this ensures new game ghosts are replayed at the right time
	GameGlobals.game_tick = 0.0

	jumper.camera.make_current()
	cinematic_camera.queue_free()
	ash_particles.emitting = true
	lava_flow_animation.play("lava_flow")
	scroll_spawn_timer.start()
	set_all_processing(true)
	


func _process(_delta):
	var current_h: float = jumper.current_height
	var t = remap(current_h, min_height, max_height, 0.0, 1.0)
	t = clampf(t, 0.0, 1.0)
	var target_color = bottom_color.lerp(top_color, t)
	background_rect.color = target_color
	ash_particles.amount_ratio = 1.0 - t
	cloud_sprite.self_modulate.a = lerpf(0.0, 0.78, t)
	
	if current_h >= 976.0 and not cloud_olympus.visible:
		cloud_olympus.position.y = jumper.position.y - 380.0
		cloud_olympus.visible = true
		cloud_olympus.monitoring = true
	
	if should_spawn():
		spawn_block_wave()


func _physics_process(delta: float) -> void:
	GameGlobals.game_tick += delta
	

func should_spawn() -> bool:
	
	# we have never spawned a block
	if !most_recently_spawned_block:
		return true
	
	var screen_top_y = jumper.camera.get_screen_center_position().y - (screen_size.y / 2.0)
	var trigger_y = screen_top_y + screen_size.y * (1.0 - trigger_spawn_screen_percent)

	var highest_y = most_recently_spawned_block.global_position.y
	var trigger_reached = highest_y > trigger_y
	
	# we have recorded blocks left and it's time to spawn one
	if recorded_block_index < len(Recorder.past_block_data) and Recorder.past_block_data[recorded_block_index][1] <= GameGlobals.game_tick:
		return true
	# we have recorded blocks left, and it's not technically time to play it back, but the jumper has reached the trigger point early. Spawn it anyway
	elif recorded_block_index < len(Recorder.past_block_data) and trigger_reached:
		return true
	# we have recorded blocks left and it's not time to spawn one
	elif recorded_block_index < len(Recorder.past_block_data) and Recorder.past_block_data[recorded_block_index][1] > GameGlobals.game_tick:
		return false
	
	# we don't have recorded blocks left and we've spawned before - check if the spawned block has reached the trigger point
	return trigger_reached


func spawn_block_wave():
	var random_block_type = game_rng.randi() % 5
	var block_scene = null
	var should_flip = false
	match random_block_type:
		0:
			block_scene = falling_block_small
		1:
			block_scene = falling_block_medium
		2:
			block_scene = falling_block_tall_small
		3:
			block_scene = falling_column
		4:
			block_scene = falling_staircase
			should_flip = game_rng.randi() % 2 == 0
		_:
			print("oh no!")
			
	var block = block_scene.instantiate()
	if should_flip:
		block.scale.x = -1
		
	# now we can calculate x pos based on the sprite size
	var block_size = block.sprite.texture.get_size() * abs(block.sprite.global_scale)
	
	# calculate y pos and set it first because we don't want to initially spawn the block in lava
	var block_pos_y = null
	if recorded_block_index < len(Recorder.past_block_data):
		print('spawning from recording')
		var recorded_block_pos_y = Recorder.past_block_data[recorded_block_index][0]
		# make sure we don't spawn the block too low if the jumper is doing well and has gotten higher than the previous jumper did
		var normal_spawn_y = jumper.camera.get_screen_center_position().y - (screen_size.y / 2.0) - spawn_y_offset
		var recent_block_y_offset = INF
		if most_recently_spawned_block:
			# and also try to make sure we don't accidentally spawn into another block
			recent_block_y_offset = most_recently_spawned_block.global_position.y - block_size.y - 32
		block_pos_y = min(recorded_block_pos_y, normal_spawn_y, recent_block_y_offset)
		recorded_block_index += 1
	else:
		print('spawning new block')
		block_pos_y = jumper.camera.get_screen_center_position().y - (screen_size.y / 2.0) - spawn_y_offset
		Recorder.new_block_data.append([block_pos_y, GameGlobals.game_tick])
	
	block.global_position.y = block_pos_y

	var spawn_margin_x = (block_size.x / 2.0) + 16.0
	
	var min_play_area_x = get_viewport().get_visible_rect().position.x + spawn_margin_x
	var max_play_area_x = get_viewport().get_visible_rect().end.x - spawn_margin_x

	var random_block_pos_x = null
	if most_recently_spawned_block:
		var prev_block_pos_x = most_recently_spawned_block.global_position.x
		var new_range = null
		
		var half_screen_size = get_viewport().get_visible_rect().size.x / 2.0

		if prev_block_pos_x == min_play_area_x:
			new_range = game_rng.randf_range(40.0, half_screen_size)
		elif prev_block_pos_x == max_play_area_x:
			new_range = game_rng.randf_range(-1 * half_screen_size, -40.0)
		else:
			new_range = game_rng.randf_range(-1 * half_screen_size, half_screen_size)
		var potential_new_x = prev_block_pos_x + new_range
		var clamped_new_x = clampf(potential_new_x, min_play_area_x, max_play_area_x)
		random_block_pos_x = clamped_new_x
	else:
		random_block_pos_x = game_rng.randf_range(min_play_area_x, max_play_area_x)

	block.global_position.x = random_block_pos_x
	add_child(block)
	most_recently_spawned_block = block


func _spawn_scroll():
	print('spawning scroll')
	var viewport_size = get_viewport().get_visible_rect().size
	var scroll_node = scroll.instantiate()
	add_child(scroll_node)
	# don't use game_rng because scrolls come in at different times relative to when blocks spawn
	scroll_node.position.x = randi_range(16, viewport_size.x)
	var camera_pos = jumper.camera.get_screen_center_position()
	scroll_node.position.y = camera_pos.y - (viewport_size.y / 2.0)


func _on_spawn_timer_timeout() -> void:
	_spawn_scroll()


func _on_lava_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		jumper.state = jumper.States.BURNT
	else:
		body.enter_lava()


func _on_cloud_olympus_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		ash_particles.emitting = false
		volcano_smoke.emitting = false
		volcano_lava.emitting = false
		
		jumper.animation_player.play("fade")
		var scroll_node = scroll.instantiate()
		scroll_node.visible = false
		add_child(scroll_node)
		scroll_node.set_text("Well done. You have recovered our knowledge and earned your place on Olympus!")
		scroll_node.set_effect(false)
		jumper.scroll_read.emit(scroll_node)
		
		set_all_processing(false)
		
		await get_tree().create_timer(6.0).timeout
		jumper.game_over.emit(1000.0, GameGlobals.game_tick)
