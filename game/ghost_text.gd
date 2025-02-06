extends RichTextLabel

@onready var ghost_text_animation = $AnimationPlayer
var target_world_pos = 0.0

func show_text(ghost_text, screen_pos, world_pos):
	target_world_pos = world_pos
	text = ghost_text
	global_position = screen_pos
	visible = true
	ghost_text_animation.play("speak")
	await ghost_text_animation.animation_finished
	queue_free()
