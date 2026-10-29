extends CanvasLayer

@export var next_word_label: RichTextLabel
@export var current_word_label: RichTextLabel
@export var player: CharacterBody3D

@export_group("Timed Word Queue")
@export var timer_grace_seconds: float = 2.0
@export var phase_seconds: float = 20.0
@export_range(1, 6) var maximum_words: int = 4
@export var initial_word_seconds: float = 10.0
@export var minimum_word_seconds: float = 4.0
@export var initial_spawn_seconds: float = 6.0
@export var minimum_spawn_seconds: float = 1.5

signal score_changed(new_score: int)
signal wpm_changed(new_wpm: int)
signal game_over_triggered(final_score: int, highest_wpm: int, avg_wpm: int, accuracy: float)
# Reserved for a later monster penalty; expiration currently only removes the word.
signal word_expired(word: String)

class QueuedWord:
	extends RefCounted
	var text: String
	var age: float = 0.0
	var duration: float
	var card: Control
	var visual: Control
	var label: RichTextLabel
	var track: ColorRect
	var fill: ColorRect
	var error_flash: float = 0.0

var easy_words = ["poste", "barya", "kapit", "dulas", "hawak", "bilis", "talon", "tangkad", "panalo", "punongkahoy"]
var medium_words = ["kawayan", "grasa", "panatag", "pagsisikap", "premyo", "abot", "taas", "pawis"]
var hard_words = ["palosebo", "madulas", "tradisyon", "piyesta", "kampyeon", "pagsubok"]

var current_word: String = ""
var next_word: String = ""
var typed_text: String = ""
var is_active: bool = false
var score: int = 0
var time_elapsed: float = 0.0
var total_chars_typed: int = 0
var total_keystrokes: int = 0
var highest_wpm: int = 0
var current_wpm: int = 0
var word_queue: Array[QueuedWord] = []
var spawn_elapsed: float = 0.0
var queue_row: HBoxContainer
var queue_root: Control
var word_font: Font

func _ready() -> void:
	visible = false
	word_font = load("res://Assets/font/BARABARA-final.otf") as Font
	# Keep existing exported references compatible with the saved scene.
	if current_word_label:
		current_word_label.hide()
	if next_word_label:
		next_word_label.hide()
	queue_root = Control.new()
	queue_root.name = "TimedWordQueue"
	queue_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(queue_root)
	queue_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_row = HBoxContainer.new()
	queue_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	queue_row.add_theme_constant_override("separation", 12)
	queue_root.add_child(queue_row)
	get_viewport().size_changed.connect(_layout_queue)
	_layout_queue()

func get_phase() -> int:
	return int(time_elapsed / maxf(phase_seconds, 1.0))

func get_queue_capacity() -> int:
	return mini(1 + get_phase(), maximum_words)

func get_word_duration() -> float:
	return maxf(minimum_word_seconds, initial_word_seconds - get_phase() * 1.25)

func get_spawn_interval() -> float:
	return maxf(minimum_spawn_seconds, initial_spawn_seconds - get_phase() * 0.65)

func _process(delta: float) -> void:
	if not is_active:
		return
	var previous_phase := get_phase()
	time_elapsed += delta
	if get_phase() != previous_phase:
		_layout_queue()
	if time_elapsed > 1.0:
		current_wpm = int((total_chars_typed / 5.0) / (time_elapsed / 60.0))
		highest_wpm = maxi(highest_wpm, current_wpm)
		wpm_changed.emit(current_wpm)

	# Every card ages independently, including words waiting behind the first.
	for index in range(word_queue.size() - 1, -1, -1):
		var entry := word_queue[index]
		entry.age += delta
		entry.error_flash = maxf(0.0, entry.error_flash - delta)
		if entry.age >= timer_grace_seconds + entry.duration:
			var expired_text := entry.text
			_remove_word(index)
			word_expired.emit(expired_text)
			if not is_active:
				return

	spawn_elapsed += delta
	if word_queue.is_empty():
		_spawn_word()
		spawn_elapsed = 0.0
	elif spawn_elapsed >= get_spawn_interval():
		spawn_elapsed = 0.0
		if word_queue.size() < get_queue_capacity():
			_spawn_word()
	_refresh_cards()

func start_typing_minigame() -> void:
	_clear_queue()
	visible = true
	is_active = true
	score = 0
	time_elapsed = 0.0
	spawn_elapsed = 0.0
	total_chars_typed = 0
	total_keystrokes = 0
	highest_wpm = 0
	current_wpm = 0
	typed_text = ""
	score_changed.emit(0)
	wpm_changed.emit(0)
	_spawn_word()
	_layout_queue()
	update_ui()

func stop_typing_minigame() -> void:
	if not is_active:
		return
	is_active = false
	var accuracy: float = 0.0
	if total_keystrokes > 0:
		accuracy = float(total_chars_typed) / total_keystrokes * 100.0
	visible = false
	_clear_queue()
	game_over_triggered.emit(score, highest_wpm, current_wpm, accuracy)

func get_random_word() -> String:
	var pool: Array = easy_words.duplicate()
	if get_phase() >= 1:
		pool.append_array(medium_words)
	if get_phase() >= 2:
		pool.append_array(hard_words)
	return pool.pick_random()

func _spawn_word() -> void:
	var entry := QueuedWord.new()
	entry.text = get_random_word()
	entry.duration = get_word_duration()
	entry.card = Control.new()
	entry.card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_row.add_child(entry.card)
	entry.visual = Control.new()
	entry.visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.card.add_child(entry.visual)
	entry.label = RichTextLabel.new()
	entry.label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.label.bbcode_enabled = true
	entry.label.scroll_active = false
	entry.label.add_theme_font_override("normal_font", word_font)
	entry.visual.add_child(entry.label)
	entry.track = ColorRect.new()
	entry.track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.track.color = Color(1.0, 1.0, 1.0, 0.15)
	entry.visual.add_child(entry.track)
	entry.fill = ColorRect.new()
	entry.fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.track.add_child(entry.fill)
	word_queue.append(entry)
	_layout_queue()
	update_ui()

func _layout_queue() -> void:
	if not is_instance_valid(queue_row):
		return
	var available_width := maxf(120.0, get_viewport().get_visible_rect().size.x - 48.0)
	queue_row.position = Vector2(24.0, 40.0)
	queue_row.size = Vector2(available_width, 200.0)
	var capacity := get_queue_capacity()
	var card_width := minf(260.0, (available_width - (capacity - 1) * 12.0) / capacity)
	for entry in word_queue:
		entry.card.custom_minimum_size = Vector2(card_width, 200.0)
		entry.visual.size = Vector2(card_width, 200.0)
		entry.visual.pivot_offset = entry.visual.size * 0.5
		entry.label.position = Vector2(12.0, 4.0)
		entry.label.size = Vector2(card_width - 24.0, 156.0)
		var text_width := word_font.get_string_size(entry.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
		var font_size := mini(32, int(32.0 * (card_width - 36.0) / maxf(text_width * 1.08, 1.0)))
		entry.label.add_theme_font_size_override("normal_font_size", maxi(10, font_size))
		entry.track.position = Vector2(16.0, 160.0)
		entry.track.size = Vector2(card_width - 32.0, 4.0)
	_refresh_cards()

func _refresh_cards() -> void:
	for index in range(word_queue.size()):
		var entry := word_queue[index]
		var lifetime := maxf(0.01, timer_grace_seconds + entry.duration)
		var progress := clampf(entry.age / lifetime, 0.0, 1.0)
		entry.visual.scale = Vector2.ONE * lerpf(0.85, 1.08, progress)
		var remaining := clampf(1.0 - maxf(0.0, entry.age - timer_grace_seconds) / maxf(entry.duration, 0.01), 0.0, 1.0)
		entry.fill.size = Vector2(entry.track.size.x * remaining, 4.0)
		if entry.age < timer_grace_seconds:
			entry.fill.color = Color(0.55, 0.75, 1.0)
		elif remaining > 0.5:
			entry.fill.color = Color(0.4, 0.95, 0.6)
		elif remaining > 0.25:
			entry.fill.color = Color(1.0, 0.8, 0.25)
		else:
			entry.fill.color = Color(1.0, 0.25, 0.3)
		entry.visual.modulate = Color(1.0, 0.3, 0.3) if entry.error_flash > 0.0 else Color(1.0, 1.0, 1.0, 1.0 if index == 0 else 0.65)

func update_ui() -> void:
	current_word = word_queue[0].text if not word_queue.is_empty() else ""
	next_word = word_queue[1].text if word_queue.size() > 1 else ""
	for index in range(word_queue.size()):
		var entry := word_queue[index]
		if index == 0:
			entry.label.text = "[center]\n[color=#80f5a0]" + typed_text.to_upper() + "[/color]" + entry.text.substr(typed_text.length()).to_upper() + "[/center]"
		else:
			entry.label.text = "[center]\n" + entry.text.to_upper() + "[/center]"
	_refresh_cards()

func _remove_word(index: int) -> void:
	var entry := word_queue[index]
	queue_row.remove_child(entry.card)
	entry.card.queue_free()
	word_queue.remove_at(index)
	if index == 0:
		typed_text = ""
	update_ui()

func _clear_queue() -> void:
	for entry in word_queue:
		queue_row.remove_child(entry.card)
		entry.card.queue_free()
	word_queue.clear()
	typed_text = ""
	current_word = ""
	next_word = ""

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or word_queue.is_empty():
		return
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE or event.unicode < 32 or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	total_keystrokes += 1
	var typed_char := char(event.unicode).to_lower()
	if current_word.begins_with(typed_text + typed_char):
		typed_text += typed_char
		total_chars_typed += 1
		update_ui()
		if player and player.has_method("climb_step"):
			player.climb_step()
		if typed_text == current_word:
			on_word_completed()
	else:
		if player and player.has_method("on_typing_error"):
			player.on_typing_error()
		word_queue[0].error_flash = 0.2
		_refresh_cards()
	if total_keystrokes >= 20 and float(total_chars_typed) / total_keystrokes < 0.8:
		trigger_elimination()

func on_word_completed() -> void:
	score += current_word.length() * 10
	score_changed.emit(score)
	_remove_word(0)
	if word_queue.is_empty():
		_spawn_word()
		spawn_elapsed = 0.0

func trigger_elimination() -> void:
	if not is_active:
		return
	if player and player.has_method("force_dismount"):
		player.force_dismount(true)
	stop_typing_minigame()
