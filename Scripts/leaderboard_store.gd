extends RefCounted

const DEFAULT_PATH := "user://pal_who_say_boo_high_score.cfg"
const MINIMUM_WPM_CHARACTERS := 20
var save_path: String = DEFAULT_PATH

func clean_name(value: String) -> String:
	return value.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(24)

func load_data() -> Dictionary:
	var data := {"scores": [], "wpm": [], "recent": [], "last_name": ""}
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return data
	data.scores = _valid_rows(config.get_value("leaderboards", "scores", []), 10)
	data.wpm = _valid_rows(config.get_value("leaderboards", "wpm", []), 10)
	data.recent = _valid_rows(config.get_value("leaderboards", "recent", []), 20)
	var last_name: Variant = config.get_value("player", "last_name", "")
	if last_name is String:
		data.last_name = clean_name(last_name)
	# Preserve the existing champion; old saves do not contain WPM or history.
	if not config.has_section_key("leaderboards", "scores"):
		var name: Variant = config.get_value("record", "name", "")
		var score: Variant = config.get_value("record", "score", 0)
		if name is String and score is int and not clean_name(name).is_empty():
			data.scores.append({"name": clean_name(name), "score": maxi(0, score), "peak_wpm": 0, "avg_wpm": 0, "accuracy": 0.0, "correct_chars": 0, "at": 0.0, "ranked": true})
	return data

func _valid_rows(value: Variant, limit: int) -> Array:
	var rows: Array = []
	if value is not Array:
		return rows
	for item in value:
		if item is not Dictionary or item.get("name") is not String:
			continue
		if item.get("score") is not int or item.get("peak_wpm", 0) is not int:
			continue
		var row: Dictionary = item.duplicate(true)
		row.name = clean_name(row.name)
		row.score = maxi(0, row.score)
		row.peak_wpm = maxi(0, row.get("peak_wpm", 0))
		rows.append(row)
		if rows.size() >= limit:
			break
	return rows

func record_attempt(player_name: String, score: int, peak_wpm: int, average_wpm: int, accuracy: float, correct_characters: int, ranked: bool = true) -> Error:
	var data := load_data()
	var name := clean_name(player_name)
	var is_named := ranked and not name.is_empty()
	var attempt := {"name": name if is_named else "Anonymous", "score": maxi(0, score), "peak_wpm": maxi(0, peak_wpm), "avg_wpm": maxi(0, average_wpm), "accuracy": clampf(accuracy, 0.0, 100.0), "correct_chars": maxi(0, correct_characters), "at": Time.get_unix_time_from_system(), "ranked": is_named}
	data.recent.push_front(attempt.duplicate(true))
	data.recent = data.recent.slice(0, 20)
	if is_named:
		data.scores = _rank(data.scores, attempt, "score")
		if correct_characters >= MINIMUM_WPM_CHARACTERS and peak_wpm > 0:
			data.wpm = _rank(data.wpm, attempt, "peak_wpm")
		data.last_name = name
	var config := ConfigFile.new()
	config.set_value("leaderboards", "version", 1)
	config.set_value("leaderboards", "scores", data.scores)
	config.set_value("leaderboards", "wpm", data.wpm)
	config.set_value("leaderboards", "recent", data.recent)
	config.set_value("player", "last_name", data.last_name)
	# Keep compatibility with the results screen's existing champion display.
	if not data.scores.is_empty():
		config.set_value("record", "name", data.scores[0].name)
		config.set_value("record", "score", data.scores[0].score)
	return config.save(save_path)

func _rank(existing: Array, attempt: Dictionary, metric: String) -> Array:
	var rows: Array = existing.duplicate(true)
	var matching := -1
	for index in range(rows.size()):
		if str(rows[index].name).to_lower() == str(attempt.name).to_lower():
			matching = index
			break
	if matching >= 0:
		if int(attempt[metric]) <= int(rows[matching][metric]):
			return rows
		rows.remove_at(matching)
	rows.append(attempt.duplicate(true))
	rows.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a[metric]) == int(b[metric]):
			return str(a.name).nocasecmp_to(str(b.name)) < 0
		return int(a[metric]) > int(b[metric])
	)
	return rows.slice(0, 10)
