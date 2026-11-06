extends CanvasLayer

signal closed
const Store = preload("res://Scripts/leaderboard_store.gd")
var record_path: String = Store.DEFAULT_PATH
var tabs: TabContainer
var score_table: Tree
var wpm_table: Tree
var recent_table: Tree

# --- Deletion UI Variables ---
var delete_dialog: ConfirmationDialog
var player_to_delete: String = ""

func _ready() -> void:
	layer = 30
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.025, 0.97)
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# --- Setup the Confirmation Dialog ---
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.get_ok_button().text = "Delete"
	delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(delete_dialog)
	# ------------------------------------------

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
	note.text = "Personal best per name. Right-click or press Delete on a player to remove them."
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
	
	# --- Detect Mouse Clicks on the table ---
	table.item_mouse_selected.connect(_on_item_mouse_selected.bind(table))
	
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

# --- Right Click Detection Logic ---
func _on_item_mouse_selected(position: Vector2, mouse_button_index: int, table: Tree) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var item := table.get_item_at_position(position)
		if item == null: 
			return
			
		var p_name = item.get_text(1)
		# Don't try to delete empty placeholders
		if p_name == "No records yet" or p_name == "Anonymous" or p_name.is_empty():
			return
			
		player_to_delete = p_name
		delete_dialog.title = "Delete Player"
		delete_dialog.dialog_text = "Are you sure you want to completely delete '" + p_name + "' from the leaderboards?"
		delete_dialog.popup_centered()

# --- Execute Deletion ---
func _on_delete_confirmed() -> void:
	if player_to_delete.is_empty():
		return
		
	var store := Store.new()
	store.save_path = record_path
	store.delete_player(player_to_delete)
	player_to_delete = ""
	
	# Instantly refresh the UI to show the player is gone
	refresh()

func _input(event: InputEvent) -> void:
	# 1. Close menu logic
	if event.is_action_pressed("ui_cancel") or (InputMap.has_action("interact") and event.is_action_pressed("interact")):
		get_viewport().set_input_as_handled()
		close_view()
		return
		
	# 2. Delete key logic
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_DELETE:
		var focused_control = get_viewport().gui_get_focus_owner()
		
		# Check if the player is currently clicking/focused on one of our data tables
		if focused_control is Tree:
			var selected_item = focused_control.get_selected()
			if selected_item != null:
				var p_name = selected_item.get_text(1)
				
				# Make sure we don't try to delete empty placeholder text
				if p_name != "No records yet" and p_name != "Anonymous" and not p_name.is_empty():
					player_to_delete = p_name
					delete_dialog.title = "Delete Player"
					delete_dialog.dialog_text = "Are you sure you want to completely delete '" + p_name + "' from the leaderboards?"
					delete_dialog.popup_centered()
					get_viewport().set_input_as_handled()

# THIS WAS THE MISSING FUNCTION!
func close_view() -> void:
	closed.emit()
	queue_free()
