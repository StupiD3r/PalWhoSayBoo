extends CanvasLayer

signal closed
const Store = preload("res://Scripts/leaderboard_store.gd")
var record_path: String = Store.DEFAULT_PATH
var tabs: TabContainer
var score_table: Tree
var wpm_table: Tree
var recent_table: Tree

func _ready() -> void:
	layer = 30
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.025, 0.97)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "LOCAL LEADERBOARDS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	column.add_child(heading)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	score_table = _add_table("Top 10 Scores", ["Rank", "Player", "Score"])
	wpm_table = _add_table("Top 10 WPM", ["Rank", "Player", "Peak WPM"])
	recent_table = _add_table("Last 20 Attempts", ["Run", "Player", "Score", "WPM"])
	var note := Label.new()
	note.text = "Personal best per name. WPM qualifies after 20 correct characters."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)
	var close := Button.new()
	close.text = "Close (E / Esc)"
	close.custom_minimum_size.y = 44
	close.pressed.connect(close_view)
	column.add_child(close)
	refresh()
	close.grab_focus.call_deferred()

func _add_table(title: String, headers: Array) -> Tree:
	var table := Tree.new()
	table.name = title
	table.columns = headers.size()
	table.hide_root = true
	table.column_titles_visible = true
	table.add_theme_font_size_override("font_size", 18)
	table.add_theme_constant_override("v_separation", 4)
	for index in range(headers.size()):
		table.set_column_title(index, headers[index])
		table.set_column_expand(index, index == 1)
		table.set_column_custom_minimum_width(index, 55 if index == 0 else (150 if index == 1 else 80))
	tabs.add_child(table)
	return table

func refresh() -> void:
	var store := Store.new()
	store.save_path = record_path
	var data := store.load_data()
	_fill(score_table, data.scores, "score")
	_fill(wpm_table, data.wpm, "peak_wpm")
	_fill(recent_table, data.recent, "recent")

func _fill(table: Tree, rows: Array, metric: String) -> void:
	table.clear()
	var root := table.create_item()
	if rows.is_empty():
		var empty := table.create_item(root)
		empty.set_text(1, "No records yet")
		return
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var item := table.create_item(root)
		item.set_text(0, str(index + 1))
		item.set_text(1, row.name)
		item.set_text(2, str(row.score if metric == "recent" else row[metric]))
		if metric == "recent":
			item.set_text(3, str(row.peak_wpm))
			var date := Time.get_datetime_string_from_unix_time(int(row.get("at", 0)))
			item.set_tooltip_text(1, date + " UTC | Newest attempts first")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (InputMap.has_action("interact") and event.is_action_pressed("interact")):
		get_viewport().set_input_as_handled()
		close_view()

func close_view() -> void:
	closed.emit()
	queue_free()
