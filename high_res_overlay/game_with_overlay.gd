# Made with Godot: https://godotengine.org/license/
# This game uses Godot Engine, available under the following license:
#
# Copyright (c) 2014-present Godot Engine contributors.
# Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

extends Node2D

@export var game: Node2D
@export var viewport_container: SubViewportContainer
@export var viewport: SubViewport
@export var canvas_layer: CanvasLayer

const game_scene_path = preload("res://game/game.tscn")
const main_menu_scene = preload("res://main_menu/main_menu.tscn")
var main_menu_instance = null
const ghost_scene = preload("res://game/ghost.tscn")
const ghost_text = preload("res://game/ghost_text.tscn")
const loading_screen_scene = preload("res://high_res_overlay/loading_screen.tscn")
var loading_screen_instance = null

@onready var progress_tracker = $CanvasLayer/ProgressTracker
@onready var scroll_container = $CanvasLayer/ScrollPanel
@onready var scroll_text_control = $CanvasLayer/ScrollPanel/ControlToResizeText
@onready var scroll_label = $CanvasLayer/ScrollPanel/ControlToResizeText/ScrollText
@onready var scroll_animation_player = $CanvasLayer/ScrollPanel/ControlToResizeText/ScrollText/AnimationPlayer

const BASE_GAME_RESOLUTION = Vector2i(640, 360) # The base size of the game
const BASE_UI_RESOLUTION = Vector2(1920, 1080) # The standard scaled up size for high res UI
const CHARS_TO_TRANSLATE = ["c", "d", "f", "g", "j", "l", "p", "q", "r", "s", "u", "v", "y"]
const SAVE_DATA_PATH = "user://jumper_data.tres"
const NOMINAL_SCROLL_WIDTH = 80.0
const NOMINAL_SCROLL_HEIGHT = 14.0
const NOMINAL_SCROLL_SCALE = 10.0
# arbitarily chosen
const MAX_GHOSTS = 20

var first_game = true
var attempts_on_seed = 0
var reading_scroll = false
var ghost_text_labels = []
var translation_effect = null

# scroll text is determined here rather than in scroll node so we can have game-dependent
# scroll text order
var next_note = ""
var scroll_wisdom = [
	"Do not refrain from questioning things",
	"There are atoms and the void",
	"logistikon: spirit of reason",
	"thymoeides: spirit of anger and other spirited emotions",
	"epithymetikon: spirit of desire",
	"Make the best use of what is in your power, and take the rest as it happens",
	"Make haste slowly",
	"If one does not know to which port one is sailing, no wind is favorable",
	"What's taking so long?\n                                         Best, Zeus",
	"You were supposed to be at the Olympian meeting by 8am\n                                     -- Ares",
	"You'll get a little boost when you read these\n                     Your pal, Hermes",
	"Neither water nor any other of the elements - a substance different from them - is infinite",
	"Destruction happens according to necessity. In conformity with the ordinance of Time",
	"Retry and meet your thymoeides",
	"Minima naturalia: the smallest parts into which a body may still retain its essential character",
	"Lava slowly decays blocks",
	"Thymoeides' colors correspond to the heights they achieved in life",
	"Things that are scarce are not absolutely more pleasant than those which are abundant",
	"Grow old always learning many things",
	"Know thyself",
	"A fish starts to stink from the head",
	"From a bad crow, a bad egg",
	"Live hidden",
	"The least bad choice is the best",
	"A bad neighbor is a calamity as much as a good one is a great advantage",
	"There is learning in suffering",
	"Along with Athena, move also your hand",
	"What is the strangest thing to see? An aged tyrant",
	"A sweet thing tasted too often is no longer sweet.",
	"Naught without labor",
	"Dwell on the beauty of life. Watch the stars, and see yourself running with them",
	"If it is not right do not do it; if it is not true do not say it",
	"To bear this worthily is good fortune",
	"Love your nature and what it demands of you",
]


func _ready() -> void:
	print("main ready called")
	# custom RichTextEffect for scroll text
	translation_effect = TranslationEffect.new()
	scroll_label.install_effect(translation_effect)
	open_menu()
	
	# initial load of title text particle effects to avoid stuttering upon first emission
	show_loading_screen(true)
	main_menu_instance.title_text_animation.stop()
	main_menu_instance.title_text_particles.emitting = true
	for i in range(3):
		await get_tree().process_frame
	main_menu_instance.title_text_particles.restart()
	show_loading_screen(false)
	main_menu_instance.title_text_animation.play("fun_text")


func check_seed(seed_val: String):
	main_menu_instance.seed_submit_button.disabled = (len(seed_val) != 5) or seed_val == GameGlobals.game_seed


func set_seed(seed_val: String):
	print('set seed called with ' + seed_val)

	if (len(seed_val) != 5):
		main_menu_instance.random_seed_input.text = GameGlobals.game_seed
		return

	print("changing seed to " + seed_val)
	GameGlobals.game_seed = seed_val
	main_menu_instance.random_seed_input.text = GameGlobals.game_seed
	main_menu_instance.retry_button.visible = false
	main_menu_instance.seed_submit_button.disabled = true
	

func set_seed_from_button():
	main_menu_instance.on_screen_keyboard.hide_keyboard()
	set_seed(main_menu_instance.random_seed_input.text)


func _input(event: InputEvent) -> void:
	
	if event is InputEventFromWindow:
		GameGlobals.input_name = "mouse and keyboard"
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var joypads = Input.get_connected_joypads()
		if len(joypads) > 0:
			GameGlobals.input_name = Input.get_joy_name(joypads[0])
	
	if event.is_action_pressed("menu"):
		# Check if the menu is already open
		if main_menu_instance == null:
			open_menu()
		elif main_menu_instance.resume_button.visible:
			close_menu()


func open_menu() -> void:
	if main_menu_instance:
		print('not opening duplicate menu')
		return
	get_tree().paused = true

	main_menu_instance = main_menu_scene.instantiate()
	progress_tracker.visible = false
	scroll_container.visible = false
	canvas_layer.add_child(main_menu_instance)

	var game_data = load_game_data()
	for game_seed in game_data.high_score_data.keys():
		var high_score_data_for_seed = game_data.high_score_data[game_seed]
		main_menu_instance.score_table.add_row(game_seed, str(high_score_data_for_seed["high_score"]), str(high_score_data_for_seed["time"]))

	main_menu_instance.new_game_button.pressed.connect(new_game)
	
	main_menu_instance.retry_button.pressed.connect(retry_game)
	main_menu_instance.retry_button.visible = attempts_on_seed > 0

	main_menu_instance.resume_button.pressed.connect(close_menu)
	main_menu_instance.resume_button.visible = game != null

	main_menu_instance.quit_button.pressed.connect(quit_game)
	main_menu_instance.quit_button.visible = OS.get_name() != "Web"
	
	main_menu_instance.random_seed_input.text_submitted.connect(set_seed)
	main_menu_instance.random_seed_input.text_changed.connect(check_seed)
	main_menu_instance.seed_submit_button.pressed.connect(set_seed_from_button)
	
	# always refresh the text of the seed input box
	main_menu_instance.random_seed_input.text = GameGlobals.game_seed
	
	main_menu_instance.score_table.delete_row.connect(delete_seed_data)


func new_game() -> void:
	print("new_game called")
	Recorder.clear_all_data()
	attempts_on_seed = 0
	set_seed(GameGlobals.game_seed)
	start_game()
		

func retry_game() -> void:
	print('retry game called')
	if game and len(Recorder.past_data) < MAX_GHOSTS:
		print('saving past data')
		Recorder.past_data.append({"positions": Recorder.current_data.duplicate(), "max_height": game.jumper.max_height})
		Recorder.past_block_data += Recorder.new_block_data
	set_seed(GameGlobals.game_seed)
	start_game()
		

func start_game() -> void:
	print("start_game called")
	_load_game_scene()
	game.jumper.scroll_read.connect(_set_scroll_text)
	game.jumper.ghost_last_words.connect(_set_ghost_text)
	reading_scroll = false
	attempts_on_seed += 1
	close_menu()
	if game:
		save_score(game.jumper.max_height, game.jumper.time_to_max_height)


func close_menu() -> void:
	print('closing menu')
	main_menu_instance.queue_free()
	main_menu_instance = null
	progress_tracker.visible = true
	get_tree().paused = false


func load_game_data() -> GameData:
	if ResourceLoader.exists(SAVE_DATA_PATH):
		var loaded_resource = ResourceLoader.load(SAVE_DATA_PATH)
		if loaded_resource is GameData:
			return loaded_resource
		else:
			push_error("Loaded resource is not a GameData!")
			return GameData.new()
	else:
		var new_game_data = GameData.new()
		save_game_data(new_game_data)
		return new_game_data
		

func save_game_data(game_data: GameData) -> void:
	var error = ResourceSaver.save(game_data, SAVE_DATA_PATH)
	if error != OK:
		push_error("Failed to save: ", error)
	else:
		print("Game saved successfully!")


func save_score(new_score: int, new_time: float) -> void:
	var game_data: GameData
	if ResourceLoader.exists(SAVE_DATA_PATH):
		game_data = ResourceLoader.load(SAVE_DATA_PATH)
	else:
		game_data = GameData.new()

	var score_changed = game_data.update_score(new_score, new_time, GameGlobals.game_seed)

	if score_changed:
		save_game_data(game_data)


func quit_game() -> void:
	if game:
		save_score(game.jumper.max_height, game.jumper.time_to_max_height)
	get_tree().quit()
	
	
func _load_game_scene() -> void:
	for child in viewport.get_children():
		child.queue_free()

	game = null
	var game_instance = game_scene_path.instantiate()
	if first_game:
		show_loading_screen(true)
	game_instance.first_game = first_game
	first_game = false
	viewport.add_child(game_instance)
	game = game_instance
	game.show_loading_screen.connect(show_loading_screen)
	game.update_loading_progress.connect(update_loading_progress)
	game.jumper.game_over.connect(_on_game_over)
	_spawn_ghosts()


func _spawn_ghosts():
	for i in range(len(Recorder.past_data)):
		var ghost = ghost_scene.instantiate()
		ghost.ghost_number = i
		ghost.max_height = Recorder.past_data[i]["max_height"]
		
		var cloak_color = null;
		if ghost.max_height < 100.0:
			cloak_color = Color(0.447, 0.447, 0.447)
		elif ghost.max_height < 200.0:
			cloak_color = Color(0.714, 0.298, 0.212)
		elif ghost.max_height < 300.0:
			cloak_color = Color(0.89, 0.396, 0.018)
		elif ghost.max_height < 400.0:
			cloak_color = Color(0.882, 0.831, 0.2)
		elif ghost.max_height < 500.0:
			cloak_color = Color(0.129, 0.278, 0.043)
		elif ghost.max_height < 600.0:
			cloak_color = Color(0.0, 0.271, 0.294)
		elif ghost.max_height < 700.0:
			cloak_color = Color(0.0, 0.123, 0.37)
		elif ghost.max_height < 800.0:
			cloak_color = Color(0.022, 0.0, 0.65)
		else:
			cloak_color = Color(0.212, 0.0, 0.49)
		game.add_child(ghost)
		ghost.sprite.get_material().set_shader_parameter("cloak_color", cloak_color)


func _on_game_over(max_height: int, time_to_max_height: float) -> void:
	print("game over called")
	if game:
		game.set_all_processing(false)
	save_score(max_height, time_to_max_height)
	open_menu()


func _process(_delta: float) -> void:
	# This function handles window resize and node repositioning. I couldn't figure out the right
	# combination of stretch mode and aspect project settings to keep the game pixel-perfect
	# while allowing automatic resizing of the high-res ui, so I do it manually here. 
	var window_size = get_window().size
	var resolution_ratio = window_size / BASE_GAME_RESOLUTION
	if resolution_ratio == Vector2i(0, 0):
		resolution_ratio = Vector2(0.5, 0.5)
		
	# scale and reposition the viewport containing the main game
	if viewport_container.scale.x != resolution_ratio.x:
		viewport_container.scale = resolution_ratio
	var viewport_size = Vector2i(Vector2(BASE_GAME_RESOLUTION) * Vector2(resolution_ratio))
	viewport_container.position = (window_size / 2) - (viewport_size / 2)
	
	var ui_ratio = Vector2(window_size) / BASE_UI_RESOLUTION

	# scale main menu and text
	if main_menu_instance != null:
		main_menu_instance.menu_container.size = window_size
		var title_text_ratio = min(ui_ratio.x, 1.0)
		main_menu_instance.title_text.add_theme_font_size_override("normal_font_size", 46.0 * title_text_ratio)
		
	# scale loading screen
	if loading_screen_instance != null:
		loading_screen_instance.get_node("PanelContainer").size = window_size

	if game:
		# update progress tracker
		progress_tracker.height_tracker.clear()
		progress_tracker.height_tracker.append_text(str(game.jumper.max_height) + " ft\n")
		progress_tracker.container.size.y = window_size.y
		var lava_height_ft = round(floor((game.lava.lava_sprite.scale.y - (game.jumper.initial_height + game.jumper.SPRITE_HEIGHT))) * (game.jumper.PLAYER_HEIGHT / game.jumper.SPRITE_HEIGHT))
		progress_tracker.set_progress(game.jumper.current_height, game.jumper.max_height, lava_height_ft)
		progress_tracker.timer_text.clear()
		progress_tracker.timer_text.append_text(str(snappedf(GameGlobals.game_tick, 0.01)) + " s")

		# size and position visible scrolls appropriately
		if scroll_container.scale != NOMINAL_SCROLL_SCALE * ui_ratio:
			scroll_container.scale = NOMINAL_SCROLL_SCALE * ui_ratio

		# center the scroll but slightly offset it higher so it doesn't cover the player too much
		var scroll_size = scroll_container.scale * Vector2(NOMINAL_SCROLL_WIDTH, scroll_container.size.y + 10.0)
		scroll_container.position = (window_size / 2.0) - (scroll_size / 2.0)

		# scale and reposition ghost text if they are talking
		if len(ghost_text_labels) > 0:
			for ghost_text_label in ghost_text_labels.duplicate():
				if is_instance_valid(ghost_text_label):
					# recalculate screen position of label, because camera may have moved
					var target_world_pos = ghost_text_label.target_world_pos
					var screen_pos = world_to_screen_coords(target_world_pos)
					ghost_text_label.global_position = screen_pos
					ghost_text_label.scale = ui_ratio
				else:
					ghost_text_labels.erase(ghost_text_label)


func animate_translation_effect(duration: float, original_text: String):
	translation_effect.current_alpha = 1.0
	
	# First, mark words that will be translated with the [translation] effect and fade them out
	var modified_text = ""
	for char in original_text:
		if char.to_lower() in CHARS_TO_TRANSLATE:
			modified_text += "[translation]" + char + "[/translation]"
		else:
			modified_text += char
	
	scroll_label.text = "[color=%s]" % TranslationEffect.DEFAULT_COLOR + modified_text + "[/color]"

	var tween = create_tween()
	tween.tween_property(translation_effect, "current_alpha", 0.0, duration * 0.3)
	await tween.finished
	
	# Next, 'translate' the greek script to english alphabetical equivalents by converting to the
	# bold font, changing the color slightly, and fading in
	modified_text = ""
	for char in original_text:
		if char.to_lower() in CHARS_TO_TRANSLATE:
			modified_text += "[translation color=%s][b]" % TranslationEffect.TRANSLATED_COLOR + char.to_upper() + "[/b][/translation]"
		else:
			modified_text += char

	scroll_label.text = "[color=%s]" % TranslationEffect.DEFAULT_COLOR + modified_text + "[/color]"

	tween = create_tween()
	tween.tween_property(translation_effect, "current_alpha", 1.0, duration * 0.7)
	
	# modify min size because the new font has different scales
	# note: I tried a lot of things to make the scroll size change appropriately but the only thing
	# that works is starting and stopping the fade_out animation. Just leaving it for now, because
	# it's not a big deal, just a slightly annoying visual bug where the scroll size changes when
	# the animation starts
	var h = scroll_label.get_content_height() / NOMINAL_SCROLL_SCALE
	scroll_text_control.custom_minimum_size.y = h

	await tween.finished


func _set_scroll_text(scroll: Sprite2D):
	# game end text, make sure to display it
	if 'well done' in scroll.scroll_text.to_lower():
		scroll_animation_player.stop()
		scroll_container.visible = false
		scroll_animation_player.play("RESET")
	# otherwise don't show the scroll if we're already reading another
	elif reading_scroll:
		return
	reading_scroll = true
	print('showing scroll')
	scroll_label.clear()
	
	# we calculate the scroll text only when a scroll is actually read by a player
	# so that order-dependent scrolls are always displayed properly
	# unless text is already set (in which case it's the first scroll we read in the
	# intro cut scene or the ending scroll)
	if scroll.scroll_text == "":
		scroll.set_text(_get_scroll_text())
	
	var text_to_display = scroll.scroll_text

	# P39 font doesn't have punctuation or good numbers so change to the bold font
	text_to_display = text_to_display.replace("'", "[b]'[/b]")
	text_to_display = text_to_display.replace(" ", "[b] [/b]")
	text_to_display = text_to_display.replace(",", "[b],[/b]")
	text_to_display = text_to_display.replace("!", "[b]![/b]")
	text_to_display = text_to_display.replace("-", "[b]-[/b]")
	text_to_display = text_to_display.replace(".", "[b].[/b]")
	text_to_display = text_to_display.replace("(", "[b]([/b]")
	text_to_display = text_to_display.replace(")", "[b])[/b]")
	text_to_display = text_to_display.replace("?", "[b]?[/b]")
	text_to_display = text_to_display.replace(";", "[b];[/b]")
	text_to_display = text_to_display.replace("8", "[b]8[/b]")
	scroll_label.append_text("[color=%s]" % TranslationEffect.DEFAULT_COLOR + text_to_display + "[/color]")

	await get_tree().process_frame
	var h = scroll_label.get_content_height() / NOMINAL_SCROLL_SCALE
	if h > 0:
		scroll_text_control.custom_minimum_size.y = h
		scroll_container.visible = true
		scroll_animation_player.play("fade_in")
		
		# make zeus' name appear slightly later just for laughs
		if "Zeus" in scroll.scroll_text:
			scroll_label.visible_ratio = 0.8

		await scroll_animation_player.animation_finished
		await get_tree().create_timer(0.5).timeout

		if "Zeus" in scroll.scroll_text:
			scroll_label.visible_ratio = 1.0
			await get_tree().create_timer(0.5).timeout
		
		await animate_translation_effect(3.5, String(text_to_display))

		scroll_animation_player.play("fade_out")
		await scroll_animation_player.animation_finished
		scroll_container.visible = false
		reading_scroll = false


func get_proper_input_indicator(action_type: String) -> String:
	# super basic controller handling
	var input_name = GameGlobals.input_name.to_lower()
	
	if 'mouse' in input_name:
		match action_type:
			"<delete_ghost>": 
				return "f"
			"<shrink>":
				return "x"
	
	if 'xbox' in input_name:
		match action_type:
			"<delete_ghost>": 
				return "(x)"
			"<shrink>":
				return "(y)"
				
	if 'nintendo' in input_name:
		match action_type:
			"<delete_ghost>": 
				return "(y)"
			"<shrink>":
				return "(x)"
				
	if 'ps2' in input_name or 'ps3' in input_name or 'ps4' in input_name or 'ps5' in input_name or 'playstation' in input_name:
		match action_type:
			"<delete_ghost>": 
				return "square"
			"<shrink>":
				return "triangle"
				
	match action_type:
		"<delete_ghost>": 
			return "left action button"
		"<shrink>":
			return "top action button"
		_:
			return "unknown action (file bug report)"


func _get_scroll_text():
	var text = ""
	if next_note != "":
		text = next_note
		next_note = ""
	else:
		text = scroll_wisdom.pick_random()
		# order dependent notes
		if '8am' in text:
			next_note = "Per my last message, you should be at this meeting by now\n                         -- Ares; cc Zeus"
			scroll_wisdom.erase(text)
		elif 'thymoeides' in text:
			next_note = "At half their achieved height, press <delete_ghost> to free the thymoeides"
			scroll_wisdom.erase(text)
		elif '<delete_ghost>' in text:
			next_note = "Once a soul is freed, press <shrink> to achieve minima naturalia"
			scroll_wisdom.erase(text)

	text = text.replace("<delete_ghost>", get_proper_input_indicator("<delete_ghost>"))
	text = text.replace("<shrink>", get_proper_input_indicator("<shrink>"))
	return text


func world_to_screen_coords(world_pos):
	# convert 2d game world coordinates to the overall high-res screen coordinates
	var world_to_subviewport_transform: Transform2D = viewport.get_canvas_transform()
	var subviewport_pos: Vector2 = world_to_subviewport_transform * world_pos
	var display_to_screen_transform: Transform2D = viewport_container.get_global_transform_with_canvas()
	return display_to_screen_transform * subviewport_pos
	

func _set_ghost_text(text, pos):
	var screen_position = world_to_screen_coords(pos)
	
	var ghost_text_node = ghost_text.instantiate()
	add_child(ghost_text_node)
	ghost_text_labels.append(ghost_text_node)
	ghost_text_node.show_text(text, screen_position, pos)


func delete_seed_data(seed: String):
	print('deleting seed ' + seed)
	var game_data = load_game_data()
	game_data.high_score_data.erase(seed)
	save_game_data(game_data)


func show_loading_screen(display: bool):
	if display and not is_instance_valid(loading_screen_instance):
		print('showing loading screen')
		loading_screen_instance = loading_screen_scene.instantiate()
		canvas_layer.add_child(loading_screen_instance)
	elif not display and is_instance_valid(loading_screen_instance):
		print('deleting loading screen')
		loading_screen_instance.queue_free()


func update_loading_progress(val: float):
	if is_instance_valid(loading_screen_instance):
		loading_screen_instance.progress_bar.value = val
