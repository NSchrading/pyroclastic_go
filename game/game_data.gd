extends Resource
class_name GameData

@export var high_score_data = {}


func update_score(new_score: int, new_time: float, global_seed: String) -> bool:
	var high_score_data_for_seed = high_score_data.get_or_add(global_seed, {"high_score": 0, "time": 0})
	var high_score = high_score_data_for_seed["high_score"]
	# new better score
	if new_score > high_score:
		high_score_data_for_seed["high_score"] = new_score
		high_score_data_for_seed["time"] = new_time
		return true
	# same score, better time
	elif new_score == high_score and high_score_data_for_seed["time"] > new_time:
		high_score_data_for_seed["time"] = new_time
		return true
	return false
