extends Node

const characters = 'bcdfghjklmnpqrstvwxz'

var game_tick: float = 0.0
var game_seed: String = characters[randi() % len(characters)] + characters[randi() % len(characters)] + characters[randi() % len(characters)] + characters[randi() % len(characters)] + characters[randi() % len(characters)]
var input_name: String = "mouse and keyboard"
