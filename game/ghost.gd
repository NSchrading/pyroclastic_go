extends Node2D

@onready var sprite = $Sprite2D
@onready var delete_layer = $DeleteLayer
@onready var fade_animation = $AnimationPlayer
@onready var collision_area = $Area2D

@export var ghost_number = 0
@export var max_height = 0

var change_index = 0

const LAST_WORDS = [
	"Thank yoooooou ...",
	"May the gods bless you",
	"Ahhhhhhhh",
	"Freedom at last!",
	"Hm, I kind of liked it here...",
	"Ungrateful fatherland, you won't even have my bones",
	"Do not disturb my circles!",
	"All compounded things are subject to vanish. Strive with earnestness.",
	"Now, farewell, and remember all my words!",
	"I come, I come, why dost thou call for me?",
	"It is a cold bath you give me.",
	"Death twitches my ear. 'Live,' he says. I am coming.",
	"Have I played the part well? Then applaud, as I exit.",
	"Fortune favors the bold. Make for where Pomponianus is.",
	"O my poor soul, whither art thou going?",
	"The die has been cast",
	"Death is no different from life",
	"You will certainly not ascend Olympus!",
	"Hippocleides doesn't care.",
]


func _ready() -> void:
	change_index = 0


func _physics_process(_delta: float) -> void:
	if ghost_number < len(Recorder.past_data):
		
		var positions = Recorder.past_data[ghost_number]["positions"]
		
		if change_index >= len(positions):
			return

		var time = positions[change_index][1]
		
		if GameGlobals.game_tick >= time:
			self.position = positions[change_index][0]
			change_index += 1

	
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.max_height > (max_height / 2.0):
		delete_layer.visible = true
		body.can_delete_ghost(self)


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		delete_layer.visible = false
		body.cannot_delete_ghost(self)
		

func get_last_words() -> String:
	return LAST_WORDS.pick_random()


func fade_out():
	set_physics_process(false)
	delete_layer.visible = false
	collision_area.monitoring = false
	fade_animation.play("fade")
	await fade_animation.animation_finished
	queue_free()
