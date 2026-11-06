extends CanvasLayer

const LeaderboardStore = preload("res://Scripts/leaderboard_store.gd")
const LeaderboardView = preload("res://Scripts/leaderboard_view.gd")

@export var score_label: Label
@export var highest_wpm_label: Label
@export var average_wpm_label: Label
@export var accuracy_label: Label

var record_path: String = "user://release_high_scores_v1.cfg"
var best_score: int = 0
var best_player: String = ""
var last_player_name: String = ""
var pending_score: int = 0
var awaiting_name: bool = false
var pending_peak_wpm: int = 0
var pending_average_wpm: int = 0
var pending_accuracy: float = 0.0
var pending_correct_characters: int = 0
var leaderboard_view: CanvasLayer
var record_label: Label
var failure_label: Label
var name_form: VBoxContainer
var name_prompt: Label
var name_input: LineEdit
var save_button: Button
var status_label: Label
var restart_button: Button
var results_column: VBoxContainer
var locked_player: Node
var previous_player_mode: Node.ProcessMode
var restart_scene: PackedScene
var name_prompt_generation: int = 0
var overview_camera: Camera3D
var previous_camera: Camera3D
var overview_hud: Node
var hud_was_visible: bool = false

func _ready() -> void:
	_cache_restart_scene()
	visible = false
	results_column = $VBoxContainer
	restart_button = $VBoxContainer/RestartBTN
	_build_results_ui()
	_load_record()
	_update_record_label()
	get_viewport().size_changed.connect(_layout_results)
	_layout_results()

func _cache_restart_scene() -> void:
	# Pin the already loaded map while its original PackedScene is still cached.
	# Otherwise retry reparses the large text scene after its resource is released.
	var scene := get_parent()
	while scene != null and scene.scene_file_path.is_empty():
		scene = scene.get_parent()
	if scene == null:
		scene = get_tree().current_scene
	if scene != null and not scene.scene_file_path.is_empty():
		restart_scene = ResourceLoader.load(scene.scene_file_path) as PackedScene

func _build_results_ui() -> void:
	var screen := Control.new()
	screen.name = "ResultsScreen"
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := $ColorRect as ColorRect
	background.color = Color(0.01, 0.015, 0.025, 0.55)
	background.reparent(screen)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24.0
	scroll.offset_top = 24.0
	scroll.offset_right = -24.0
	scroll.offset_bottom = -24.0
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	results_column.reparent(center)
	results_column.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	results_column.layout_mode = 2
	results_column.add_theme_constant_override("separation", 12)
	results_column.add_theme_font_size_override("font_size", 20)
	var title := results_column.get_node("TitleLabel") as Label
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	record_label = Label.new()
	record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	record_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	results_column.add_child(record_label)
	results_column.move_child(record_label, 1)
	failure_label = Label.new()
	failure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	failure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	failure_label.add_theme_font_size_override("font_size", 18)
	failure_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	results_column.add_child(failure_label)
	results_column.move_child(failure_label, 1)
	name_form = VBoxContainer.new()
	name_form.add_theme_constant_override("separation", 8)
	results_column.add_child(name_form)
	name_prompt = Label.new()
	name_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_form.add_child(name_prompt)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Your name"
	name_input.max_length = 24
	name_input.custom_minimum_size.y = 44.0
	name_input.text_submitted.connect(func(_text: String): _save_player_name())
	name_form.add_child(name_input)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	name_form.add_child(buttons)
	save_button = Button.new()
	save_button.text = "Save Name"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.custom_minimum_size.y = 44.0
	save_button.pressed.connect(_save_player_name)
	buttons.add_child(save_button)
	var skip := Button.new()
	skip.text = "Skip"
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(_skip_name)
	buttons.add_child(skip)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	results_column.add_child(status_label)
	var records_button := Button.new()
	records_button.text = "Leaderboards / Last 20 Attempts"
	records_button.custom_minimum_size.y = 44.0
	records_button.pressed.connect(_open_leaderboards)
	results_column.add_child(records_button)
	results_column.move_child(restart_button, results_column.get_child_count() - 1)
	restart_button.text = "Play Again"
	restart_button.custom_minimum_size.y = 44.0

func _layout_results() -> void:
	results_column.custom_minimum_size.x = clampf(get_viewport().get_visible_rect().size.x - 72.0, 220.0, 520.0)

func show_stats(final_score: int, peak_wpm: int, avg_wpm: int, accuracy: float) -> void:
	score_label.text = "Total Score: " + str(final_score)
	highest_wpm_label.text = "Highest WPM: " + str(peak_wpm)
	average_wpm_label.text = "Average WPM: " + str(avg_wpm)
	accuracy_label.text = "Accuracy: %.1f%%" % accuracy
	_load_record()
	_update_record_label()
	pending_score = maxi(0, final_score)
	pending_peak_wpm = peak_wpm
	pending_average_wpm = avg_wpm
	pending_accuracy = accuracy
	pending_correct_characters = 0
	var typing := get_parent().get_node_or_null("TypingUI")
	failure_label.text = "Your run has ended."
	if typing and typing.get("failure_reason") is String:
		var reason: String = typing.get("failure_reason")
		if not reason.is_empty():
			failure_label.text = reason
	if typing and typing.get("total_chars_typed") is int:
		pending_correct_characters = typing.get("total_chars_typed")
	awaiting_name = true
	name_prompt.text = "NEW HIGH SCORE! Enter your name." if best_player.is_empty() or pending_score > best_score else "Enter your name for this run."
	name_input.clear()
	name_input.editable = false
	name_prompt_generation += 1
	name_form.show()
	status_label.hide()
	restart_button.disabled = true
	_lock_player()
	_show_map_overview()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_focus_name_after_release(name_prompt_generation)

func _focus_name_after_release(generation: int) -> void:
	var earliest := Time.get_ticks_msec() + 200
	# Let the fatal typing event finish and held gameplay keys come up first.
	await get_tree().process_frame
	while Input.is_anything_pressed() or Time.get_ticks_msec() < earliest:
		if generation != name_prompt_generation or not visible or not awaiting_name:
			return
		await get_tree().process_frame
	if generation == name_prompt_generation and visible and awaiting_name:
		name_input.editable = true
		name_input.grab_focus()

func _clean_name(value: String) -> String:
	return value.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(24)

func _load_record() -> void:
	best_score = 0
	best_player = ""
	last_player_name = ""
	var config := ConfigFile.new()
	if config.load(record_path) != OK:
		return
	var stored_score: Variant = config.get_value("record", "score", 0)
	var stored_name: Variant = config.get_value("record", "name", "")
	var stored_last_name: Variant = config.get_value("player", "last_name", "")
	if stored_score is int and stored_name is String:
		best_score = maxi(0, stored_score)
		best_player = _clean_name(stored_name)
	if stored_last_name is String:
		last_player_name = _clean_name(stored_last_name)

func _save_player_name() -> void:
	if not awaiting_name:
		return
	var entered_name := _clean_name(name_input.text)
	if entered_name.is_empty():
		status_label.text = "Please enter a name, or choose Skip."
		status_label.show()
		name_input.grab_focus()
		return
	# Re-read before saving so an existing higher record is never replaced.
	_load_record()
	var new_record := best_player.is_empty() or pending_score > best_score
	var store := LeaderboardStore.new()
	store.save_path = record_path
	if store.record_attempt(entered_name, pending_score, pending_peak_wpm, pending_average_wpm, pending_accuracy, pending_correct_characters) != OK:
		status_label.text = "Could not save the record. Try again, or choose Skip."
		status_label.show()
		return
	_load_record()
	_update_record_label()
	awaiting_name = false
	name_form.hide()
	status_label.text = "New record saved!" if new_record else "Thanks, " + entered_name + "! The highest score stays unbeaten."
	status_label.show()
	restart_button.disabled = false
	restart_button.grab_focus()

func _skip_name() -> void:
	if not awaiting_name:
		return
	var store := LeaderboardStore.new()
	store.save_path = record_path
	var error := store.record_attempt("", pending_score, pending_peak_wpm, pending_average_wpm, pending_accuracy, pending_correct_characters, false)
	awaiting_name = false
	name_form.hide()
	status_label.text = "Attempt recorded as Anonymous. Ranked records are unchanged." if error == OK else "Could not save this attempt. Ranked records are unchanged."
	status_label.show()
	restart_button.disabled = false
	restart_button.grab_focus()

func _update_record_label() -> void:
	record_label.text = "HIGHEST SCORE\n" + best_player + " — " + str(best_score) if not best_player.is_empty() else "HIGHEST SCORE\nNo record yet"

func _lock_player() -> void:
	if is_instance_valid(locked_player):
		return
	locked_player = get_parent().get_node_or_null("Player")
	if locked_player:
		previous_player_mode = locked_player.process_mode
		locked_player.process_mode = Node.PROCESS_MODE_DISABLED
		var audio := locked_player.get_node_or_null("PlayerAudio")
		if audio and audio.has_method("stop_walk_step"):
			audio.stop_walk_step()

func _unlock_player() -> void:
	if is_instance_valid(locked_player):
		locked_player.process_mode = previous_player_mode
	locked_player = null

func _on_restart_button_pressed() -> void:
	if awaiting_name or restart_button.disabled:
		return
	restart_button.disabled = true
	Engine.set_meta("pal_who_say_boo_retry_wake", true)
	var error := get_tree().change_scene_to_packed(restart_scene) if restart_scene != null else get_tree().reload_current_scene()
	if error != OK:
		Engine.remove_meta("pal_who_say_boo_retry_wake")
		restart_button.disabled = false
		status_label.text = "Could not restart the game. Please try again."
		status_label.show()

func hide_stats() -> void:
	visible = false
	_close_map_overview()
	_unlock_player()

func _show_map_overview() -> void:
	if is_instance_valid(overview_camera):
		overview_camera.make_current()
		return
	var map := get_parent()
	var house := map.get_node_or_null("House") as Node3D
	var pole := map.get_node_or_null("Bamboo/BambooPole") as Node3D
	if house == null or pole == null:
		return
	previous_camera = get_viewport().get_camera_3d()
	var center := (house.global_position + pole.global_position) * 0.5
	var span := maxf(house.global_position.distance_to(pole.global_position), 80.0)
	center.y = maxf(house.global_position.y, pole.global_position.y) + 12.0
	overview_camera = Camera3D.new()
	overview_camera.name = "ResultsMapOverview"
	# Own it with the UI so retry and scene changes clean it up automatically.
	add_child(overview_camera)
	overview_camera.fov = 65.0
	overview_camera.far = maxf(2000.0, span * 5.0)
	if is_instance_valid(previous_camera):
		overview_camera.environment = previous_camera.environment
		overview_camera.attributes = previous_camera.attributes
		overview_camera.cull_mask = previous_camera.cull_mask
	overview_camera.global_position = center + Vector3(-0.55, 0.75, 0.75) * span
	overview_camera.look_at(center, Vector3.UP)
	overview_camera.make_current()
	overview_hud = map.get_node_or_null("HUD")
	if overview_hud != null and overview_hud.has_method("hide"):
		hud_was_visible = bool(overview_hud.get("visible"))
		overview_hud.hide()

func _close_map_overview() -> void:
	if is_instance_valid(previous_camera):
		previous_camera.make_current()
	previous_camera = null
	if is_instance_valid(overview_camera):
		overview_camera.queue_free()
	overview_camera = null
	if is_instance_valid(overview_hud):
		overview_hud.set("visible", hud_was_visible)
	overview_hud = null

func _open_leaderboards() -> void:
	if is_instance_valid(leaderboard_view):
		return
	leaderboard_view = LeaderboardView.new()
	leaderboard_view.record_path = record_path
	leaderboard_view.closed.connect(func():
		leaderboard_view = null
		if awaiting_name:
			name_input.grab_focus.call_deferred()
		else:
			restart_button.grab_focus.call_deferred()
	)
	add_child(leaderboard_view)
