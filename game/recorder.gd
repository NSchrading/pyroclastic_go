extends Node


var current_data: Array = []
var past_data: Array = []

var new_block_data: Array = []
var past_block_data: Array = []


func clear_all_data():
	current_data.clear()
	past_data.clear()
	new_block_data.clear()
	past_block_data.clear()
