@tool

extends PanelContainer
class_name TableRow

@export var seed_val: String = ""
@export var high_score_val: String = ""
@export var time_val: String = ""
@export var style_normal: StyleBox
@export var style_focus: StyleBox

@onready var seed_node: Label = $TableRow/SeedLabel
@onready var high_score_node: Label = $TableRow/HighScoreLabel
@onready var time_node: Label = $TableRow/TimeLabel


func _ready():
	set_row(seed_val, high_score_val, time_val)
	add_theme_stylebox_override("panel", style_normal)


func set_row(seed_label: String, high_score: String, time: String) -> void:
	seed_node.set_text(seed_label)
	high_score_node.set_text(high_score)
	time_node.set_text(time)


func _on_focus_entered():
	add_theme_stylebox_override("panel", style_focus)


func _on_focus_exited():
	add_theme_stylebox_override("panel", style_normal)
