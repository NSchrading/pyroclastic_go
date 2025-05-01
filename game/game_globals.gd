extends Node

const characters = 'bcdfghjklmnpqrstvwxz'

var game_tick: float = 0.0
var game_seed: String = generate_random_seed()
var input_name: String = "mouse and keyboard"


func generate_random_seed() -> String:
	return characters[randi() % len(characters)] + characters[randi() % len(characters)] + characters[randi() % len(characters)] + characters[randi() % len(characters)] + characters[randi() % len(characters)]
