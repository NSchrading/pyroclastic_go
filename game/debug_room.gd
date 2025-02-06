extends Node2D

@onready var column = $SubViewportContainer/SubViewport/Column


func _on_timer_timeout() -> void:
	print("debug timer queue free")
	column.queue_free()
