extends Control

@export var player_progress: ProgressBar
@export var max_height_progress: ProgressBar
@export var lava_progress: ProgressBar
@export var height_tracker: RichTextLabel
@export var container: PanelContainer
@export var timer_text: RichTextLabel

func set_progress(player_current_height, player_max_height, lava_height):
	player_progress.value = player_current_height
	max_height_progress.value = player_max_height
	lava_progress.value = lava_height
	
	var container_height = max_height_progress.size.y
	var max_height_percent = max_height_progress.value / max_height_progress.max_value
	height_tracker.position.y = container_height - (max_height_percent * container_height) - 12
