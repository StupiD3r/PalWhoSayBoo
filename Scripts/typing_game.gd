extends CanvasLayer

@export var next_word_label: RichTextLabel
@export var current_word_label: RichTextLabel
@export var player: CharacterBody3D

@export_group("Timed Word Queue")
@export var timer_grace_seconds: float = 2.0
@export var phase_seconds: float = 12.0
@export_range(1, 3) var maximum_words: int = 3
@export var initial_word_seconds: float = 10.0
@export var minimum_word_seconds: float = 4.0
@export var initial_spawn_seconds: float = 6.0
@export var minimum_spawn_seconds: float = 1.5

@export_group("Long Typing Challenges")
@export var minimum_words_before_challenge: int = 6
@export var maximum_words_before_challenge: int = 10
@export var sentence_minimum_seconds: float = 25.0
@export var challenge_seconds_per_character: float = 0.65

@export_group("Missed Word Risk")
@export_range(1, 95) var initial_miss_elimination_percent: int = 5
@export_range(1, 20) var miss_risk_increase_percent: int = 2

@export_group("Feedback")
@export var juice_enabled: bool = true
@export_range(0.0, 1.0) var juice_strength: float = 0.7
@export var wpm_indicator_threshold: int = 30
@export var wpm_heartbeat_seconds: float = 0.45

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
	var challenge_kind: String = ""
	var type_pop: float = 0.0
	var miss_pop: float = 0.0

# Effects live outside the word layout so they cannot push the queue around.
class FeedbackOverlay:
	extends Control
	var sparks: Array[Dictionary] = []
	var effects: Array[Control] = []
	var motions: Array[Tween] = []

	func _process(delta: float) -> void:
		var had_sparks := not sparks.is_empty()
		for index in range(sparks.size() - 1, -1, -1):
			var spark: Dictionary = sparks[index]
			spark["age"] += delta
			if spark["age"] >= spark["life"]:
				sparks.remove_at(index)
				continue
			spark["position"] += spark["velocity"] * delta
			spark["velocity"] += Vector2(0.0, 100.0) * delta
		if had_sparks:
			queue_redraw()

	func _draw() -> void:
		for spark in sparks:
			var fraction: float = 1.0 - spark["age"] / spark["life"]
			var tint: Color = spark["color"]
			tint.a *= fraction
			draw_circle(spark["position"], spark["radius"] * fraction, tint)

	func burst(origin: Vector2, tint: Color, amount: int) -> void:
		for index in range(amount):
			if sparks.size() >= 80:
				break
			var angle := randf_range(-PI, 0.0)
			sparks.append({"position": origin, "velocity": Vector2(cos(angle), sin(angle)) * randf_range(35.0, 95.0), "age": 0.0, "life": randf_range(0.3, 0.55), "color": tint, "radius": randf_range(1.5, 3.0)})

	func float_text(message: String, origin: Vector2, tint: Color, font: Font, large: bool = false) -> void:
		var popup := Label.new()
		popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.text = message
		popup.add_theme_font_override("font", font)
		popup.add_theme_font_size_override("font_size", 22 if large else 18)
		popup.add_theme_color_override("font_color", tint)
		popup.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.8))
		popup.add_theme_constant_override("outline_size", 3)
		add_child(popup)
		popup.position = origin - popup.get_minimum_size() * Vector2(0.5, 0.0)
		effects.append(popup)
		var motion := create_tween().set_parallel(true)
		motions.append(motion)
		motion.tween_property(popup, "position:y", popup.position.y - 30.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		motion.tween_property(popup, "modulate:a", 0.0, 0.35).set_delay(0.3)
		motion.chain().tween_callback(func():
			effects.erase(popup)
			motions.erase(motion)
			popup.queue_free()
		)

	func clear_effects() -> void:
		for motion in motions:
			if motion.is_valid():
				motion.kill()
		motions.clear()
		for effect in effects:
			if is_instance_valid(effect):
				effect.queue_free()
		effects.clear()
		sparks.clear()
		queue_redraw()

	func pop_completed_word(source: RichTextLabel, full_text: String, start: int, end: int, font: Font, strength: float) -> void:
		var ghost := source.duplicate() as RichTextLabel
		ghost.name = "CompletedWordPop"
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.modulate = Color.WHITE
		ghost.set_meta("completed_text", full_text.substr(start, end - start))
		# Transparent surrounding text preserves the sentence's exact layout.
		ghost.text = "[center]\n[color=#00000000]" + full_text.left(start).to_upper() + "[/color][color=#80f5a0]" + full_text.substr(start, end - start).to_upper() + "[/color][color=#00000000]" + full_text.substr(end).to_upper() + "[/color][/center]"
		add_child(ghost)
		ghost.size = source.size
		var font_size := source.get_theme_font_size("normal_font_size")
		var parsed := "\n" + full_text.to_upper()
		var line := source.get_character_line(start + 1)
		var line_range := source.get_line_range(line)
		var prefix := parsed.substr(line_range.x, maxi(0, start + 1 - line_range.x))
		var prefix_width := font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var word_width := font.get_string_size(full_text.substr(start, end - start).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		ghost.pivot_offset = Vector2((source.size.x - source.get_line_width(line)) * 0.5 + prefix_width + word_width * 0.5, source.get_line_offset(line) + source.get_line_height(line) * 0.5)
		var origin := get_global_transform().affine_inverse() * source.global_position
		ghost.scale = source.get_global_transform().get_scale() / get_global_transform().get_scale()
		ghost.position = origin + ghost.pivot_offset * (ghost.scale - Vector2.ONE)
		effects.append(ghost)
		var motion := create_tween().set_parallel(true)
		motions.append(motion)
		motion.tween_property(ghost, "scale", ghost.scale * (1.0 + 0.4 * strength), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		motion.tween_property(ghost, "modulate:a", 0.0, 0.28).set_delay(0.1)
		motion.chain().tween_callback(func():
			effects.erase(ghost)
			motions.erase(motion)
			ghost.queue_free()
		)

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
var preview_label: RichTextLabel
var pending_word: String = ""
var challenge_active: bool = false
var challenge_pending: bool = false
var completed_regular_words: int = 0
var words_until_challenge: int = 0
var feedback: FeedbackOverlay
var typing_streak: int = 0
var streak_label: RichTextLabel
var streak_pop_clock: float = 1.0
var missed_word_count: int = 0
var miss_elimination_percent: int = 5
var miss_rng := RandomNumberGenerator.new()
var wpm_indicator: RichTextLabel
var wpm_indicator_opacity: float = 0.0
var wpm_heartbeat_clock: float = 1.0
var previous_indicator_wpm: int = 0
var wpm_base_scale: float = 1.0
var challenge_sentences: Array[String] = [
	"Iniibig ko ang Pilipinas, aking lupang sinilangan",
	"I am a Filipino and i am for peace",
	"bayang magiliw perlas ng silanganan",
	"ikulong na yan, mga kurakot",
	"mga kababayan, punitin ang cedula",
]

func _ready() -> void:
	visible = false
	miss_rng.randomize()
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
	preview_label = RichTextLabel.new()
	preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_label.bbcode_enabled = true
	preview_label.scroll_active = false
	preview_label.add_theme_font_override("normal_font", word_font)
	preview_label.add_theme_font_size_override("normal_font_size", 18)
	preview_label.modulate = Color(0.75, 0.85, 1.0)
	queue_root.add_child(preview_label)
	streak_label = RichTextLabel.new()
	streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak_label.bbcode_enabled = true
	streak_label.scroll_active = false
	streak_label.add_theme_font_override("normal_font", word_font)
	streak_label.add_theme_font_size_override("normal_font_size", 24)
	queue_root.add_child(streak_label)
	_update_streak_ui()
	wpm_indicator = RichTextLabel.new()
	wpm_indicator.name = "BreathingWPM"
	wpm_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wpm_indicator.bbcode_enabled = true
	wpm_indicator.scroll_active = false
	wpm_indicator.add_theme_font_override("normal_font", word_font)
	wpm_indicator.add_theme_font_size_override("normal_font_size", 22)
	wpm_indicator.hide()
	queue_root.add_child(wpm_indicator)
	queue_row = HBoxContainer.new()
	queue_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	queue_row.add_theme_constant_override("separation", 12)
	queue_root.add_child(queue_row)
	feedback = FeedbackOverlay.new()
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_root.add_child(feedback)
	feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_layout_queue)
	_layout_queue()

func get_phase() -> int:
	return int(time_elapsed / maxf(phase_seconds, 1.0))

func get_queue_capacity() -> int:
	return mini(1 + get_phase(), clampi(maximum_words, 1, 3))

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
		spawn_elapsed = get_spawn_interval()
	if time_elapsed > 1.0:
		current_wpm = int((total_chars_typed / 5.0) / (time_elapsed / 60.0))
		highest_wpm = maxi(highest_wpm, current_wpm)
		wpm_changed.emit(current_wpm)
	_update_wpm_indicator(delta)
	_update_streak_animation(delta)

	# Every card ages independently, including words waiting behind the first.
	for index in range(word_queue.size() - 1, -1, -1):
		var entry := word_queue[index]
		entry.age += delta
		entry.error_flash = maxf(0.0, entry.error_flash - delta)
		entry.type_pop = maxf(0.0, entry.type_pop - delta * 8.0)
		entry.miss_pop = maxf(0.0, entry.miss_pop - delta * 6.0)
		var grace := timer_grace_seconds if not entry.challenge_kind.is_empty() else 0.0
		if entry.age >= grace + entry.duration:
			var expired_text := entry.text
			var was_challenge := not entry.challenge_kind.is_empty()
			_play_expiration_feedback(entry)
			_set_typing_streak(0)
			_remove_word(index)
			word_expired.emit(expired_text)
			if not is_active:
				return
			_apply_missed_word_risk()
			if not is_active:
				return
			if was_challenge:
				_finish_challenge()
				return

	if challenge_active:
		_refresh_cards()
		return
	if challenge_pending:
		# Finish or expire the existing queue before starting a challenge.
		if word_queue.is_empty():
			_begin_challenge()
		else:
			_refresh_cards()
		return

	spawn_elapsed += delta
	if word_queue.is_empty():
		_spawn_word()
	if spawn_elapsed >= get_spawn_interval():
		spawn_elapsed = 0.0
		# Refill a wave together so fast typing cannot suppress the queue.
		while word_queue.size() < get_queue_capacity():
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
	missed_word_count = 0
	miss_elimination_percent = clampi(initial_miss_elimination_percent, 1, 95)
	_reset_wpm_indicator()
	typed_text = ""
	challenge_active = false
	challenge_pending = false
	completed_regular_words = 0
	_schedule_challenge()
	_set_space_typing(false)
	_set_typing_streak(0)
	score_changed.emit(0)
	wpm_changed.emit(0)
	_spawn_word()
	_layout_queue()
	update_ui()

func stop_typing_minigame() -> void:
	if not is_active:
		return
	is_active = false
	_reset_wpm_indicator()
	_set_typing_streak(0)
	challenge_active = false
	challenge_pending = false
	_set_space_typing(false)
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

func _spawn_word(challenge_text: String = "", challenge_duration: float = 0.0, kind: String = "") -> void:
	var entry := QueuedWord.new()
	entry.challenge_kind = kind
	if kind.is_empty():
		entry.text = pending_word if not pending_word.is_empty() else get_random_word()
		pending_word = get_random_word()
		entry.duration = get_word_duration()
	else:
		entry.text = challenge_text
		entry.duration = challenge_duration
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
	preview_label.position = Vector2(24.0, 0.0)
	preview_label.size = Vector2(available_width, 80.0)
	var viewport_size := get_viewport().get_visible_rect().size
	streak_label.size = Vector2(300.0, 100.0)
	streak_label.position = Vector2((viewport_size.x - 300.0) * 0.5, maxf(240.0, viewport_size.y - 130.0))
	streak_label.pivot_offset = streak_label.size * 0.5
	wpm_indicator.size = Vector2(180.0, 90.0)
	wpm_indicator.position = Vector2(viewport_size.x - 204.0, 0.0)
	wpm_indicator.pivot_offset = wpm_indicator.size * 0.5
	queue_row.position = Vector2(24.0, 70.0)
	queue_row.size = Vector2(available_width, 200.0)
	var capacity := get_queue_capacity()
	var card_width := minf(260.0, (available_width - (capacity - 1) * 12.0) / capacity)
	for entry in word_queue:
		var is_challenge := not entry.challenge_kind.is_empty()
		var width := minf(900.0, available_width * 0.9) if is_challenge else card_width
		var height := 320.0 if is_challenge else 200.0
		entry.card.custom_minimum_size = Vector2(width, height)
		entry.visual.size = Vector2(width, height)
		entry.visual.pivot_offset = entry.visual.size * 0.5
		entry.label.position = Vector2(12.0, 4.0)
		entry.label.size = Vector2(width - 24.0, height - 44.0)
		var base_size := 24 if is_challenge else 32
		var text_width: float = 0.0
		for line in entry.text.split("\n"):
			text_width = maxf(text_width, word_font.get_string_size(line.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, base_size).x)
		var font_size := mini(base_size, int(base_size * (width - 36.0) / maxf(text_width * 1.08, 1.0)))
		entry.label.add_theme_font_size_override("normal_font_size", maxi(10, font_size))
		entry.track.position = Vector2(16.0, height - 40.0)
		entry.track.size = Vector2(width - 32.0, 4.0)
	_refresh_cards()

func _refresh_cards() -> void:
	for index in range(word_queue.size()):
		var entry := word_queue[index]
		# Follow the shaped text instead of the card's old fixed-height box.
		var font_size := entry.label.get_theme_font_size("normal_font_size")
		var text_bottom := entry.label.position.y + entry.label.get_content_height() - word_font.get_descent(font_size)
		entry.track.position.y = maxf(24.0, text_bottom + 6.0)
		entry.visual.size.y = entry.track.position.y + 16.0
		entry.visual.pivot_offset = entry.visual.size * 0.5
		entry.card.custom_minimum_size.y = entry.visual.size.y + 8.0
		var grace := timer_grace_seconds if not entry.challenge_kind.is_empty() else 0.0
		var lifetime := maxf(0.01, grace + entry.duration)
		var progress := clampf(entry.age / lifetime, 0.0, 1.0)
		entry.visual.scale = Vector2.ONE * lerpf(0.85, 1.08, progress)
		var strength := juice_strength if juice_enabled else 0.0
		entry.visual.scale *= 1.0 + entry.type_pop * 0.045 * strength
		# Shake only the label locally; its base position never changes.
		entry.label.position.x = 12.0 + sin(entry.miss_pop * 28.0) * entry.miss_pop * 3.0 * strength
		entry.visual.modulate.a = lerpf(0.2, 1.0, clampf(entry.age / 0.18, 0.0, 1.0)) if juice_enabled else 1.0
		var remaining := clampf(1.0 - maxf(0.0, entry.age - grace) / maxf(entry.duration, 0.01), 0.0, 1.0)
		entry.fill.size = Vector2(entry.track.size.x * remaining, 4.0)
		if entry.age < grace:
			entry.fill.color = Color(0.55, 0.75, 1.0)
		elif remaining > 0.5:
			entry.fill.color = Color(0.4, 0.95, 0.6)
		elif remaining > 0.25:
			entry.fill.color = Color(1.0, 0.8, 0.25)
		else:
			entry.fill.color = Color(1.0, 0.25, 0.3)
		var urgency := (0.75 + 0.25 * sin(entry.age * 12.0)) if juice_enabled and remaining <= 0.25 else 1.0
		entry.fill.modulate.a = urgency
		var reveal := entry.visual.modulate.a
		entry.visual.modulate = Color(1.0, 0.3, 0.3, reveal) if entry.error_flash > 0.0 else Color(1.0, 1.0, 1.0, reveal * (1.0 if index == 0 else 0.65))

func update_ui() -> void:
	current_word = word_queue[0].text.replace("\n", " ").to_lower() if not word_queue.is_empty() else ""
	next_word = word_queue[1].text if word_queue.size() > 1 else pending_word
	preview_label.text = "[center]\nNEXT: " + next_word.to_upper() + "[/center]" if not next_word.is_empty() else ""
	if challenge_active and not word_queue.is_empty():
		preview_label.text = "[center]\n" + word_queue[0].challenge_kind + " CHALLENGE[/center]"
	elif challenge_pending:
		preview_label.text = "[center]\nCHALLENGE UP NEXT[/center]"
	for index in range(word_queue.size()):
		var entry := word_queue[index]
		if index == 0:
			entry.label.text = "[center]\n[color=#80f5a0]" + entry.text.left(typed_text.length()).to_upper() + "[/color]" + entry.text.substr(typed_text.length()).to_upper() + "[/center]"
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
	if is_instance_valid(feedback):
		feedback.clear_effects()
	for entry in word_queue:
		queue_row.remove_child(entry.card)
		entry.card.queue_free()
	word_queue.clear()
	typed_text = ""
	current_word = ""
	next_word = ""
	pending_word = ""
	preview_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if not is_active or word_queue.is_empty():
		return
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if (event.keycode == KEY_SPACE or event.unicode == 32) and not challenge_active:
		return
	if event.unicode < 32 or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	total_keystrokes += 1
	var typed_char := char(event.unicode).to_lower()
	if current_word.begins_with(typed_text + typed_char):
		_set_typing_streak(typing_streak + 1)
		word_queue[0].type_pop = 1.0
		typed_text += typed_char
		total_chars_typed += 1
		update_ui()
		if challenge_active and typed_char != " ":
			var end := typed_text.length()
			if end == current_word.length() or current_word.substr(end, 1) == " ":
				var start := current_word.left(end).rfind(" ") + 1
				_play_completed_word_pop(word_queue[0], start, end)
		if player and player.has_method("climb_step"):
			player.climb_step()
		if typed_text == current_word:
			on_word_completed()
	else:
		_set_typing_streak(0)
		if player and player.has_method("on_typing_error"):
			player.on_typing_error()
		word_queue[0].error_flash = 0.2
		word_queue[0].miss_pop = 1.0
		_refresh_cards()
	if total_keystrokes >= 20 and float(total_chars_typed) / total_keystrokes < 0.8:
		trigger_elimination()

func on_word_completed() -> void:
	var was_challenge := challenge_active
	if not was_challenge:
		_play_completed_word_pop(word_queue[0], 0, current_word.length())
	var points := current_word.length() * 10
	_play_completion_feedback(word_queue[0], points)
	score += points
	score_changed.emit(score)
	_remove_word(0)
	if was_challenge:
		if player:
			var audio := player.get_node_or_null("PlayerAudio")
			if audio and audio.has_method("play_sentence_complete"):
				audio.play_sentence_complete()
		_finish_challenge()
		return
	if player:
		var audio := player.get_node_or_null("PlayerAudio")
		if audio and audio.has_method("play_word_complete"):
			audio.play_word_complete()
	completed_regular_words += 1
	if completed_regular_words >= words_until_challenge:
		challenge_pending = true
	if challenge_pending and word_queue.is_empty():
		_begin_challenge()
	elif word_queue.is_empty():
		_spawn_word()
	else:
		update_ui()

func _schedule_challenge() -> void:
	var minimum := maxi(1, minimum_words_before_challenge)
	words_until_challenge = randi_range(minimum, maxi(minimum, maximum_words_before_challenge))

func _set_space_typing(enabled: bool) -> void:
	if player:
		player.set("typing_uses_space", enabled)

func _begin_challenge() -> void:
	challenge_pending = false
	challenge_active = true
	_set_space_typing(true)
	var text: String = challenge_sentences.pick_random()
	var duration := maxf(sentence_minimum_seconds, text.length() * challenge_seconds_per_character)
	_spawn_word(text, duration, "SENTENCE")
	if juice_enabled:
		feedback.float_text("READY", Vector2(get_viewport().get_visible_rect().size.x * 0.5, 210.0), Color(1.0, 0.8, 0.35), word_font, true)

func _finish_challenge() -> void:
	challenge_active = false
	challenge_pending = false
	_set_space_typing(false)
	completed_regular_words = 0
	_schedule_challenge()
	spawn_elapsed = 0.0
	_spawn_word()

func trigger_elimination() -> void:
	if not is_active:
		return
	if player and player.has_method("force_dismount"):
		player.force_dismount(true)
	stop_typing_minigame()

func _apply_missed_word_risk() -> void:
	# Roll the current chance first; the increase applies to the next miss.
	var chance := miss_elimination_percent
	missed_word_count += 1
	miss_elimination_percent = mini(95, chance + miss_risk_increase_percent)
	if _roll_miss_elimination(chance):
		trigger_elimination()

func _roll_miss_elimination(chance_percent: int) -> bool:
	return miss_rng.randi_range(1, 100) <= chance_percent

func _feedback_origin(entry: QueuedWord) -> Vector2:
	var point := entry.track.global_position + entry.track.size * Vector2(0.5, 0.0) * entry.visual.scale
	return feedback.get_global_transform().affine_inverse() * point

func _play_completed_word_pop(entry: QueuedWord, start: int, end: int) -> void:
	if juice_enabled and juice_strength > 0.0:
		feedback.pop_completed_word(entry.label, entry.text, start, end, word_font, juice_strength)

func _play_completion_feedback(entry: QueuedWord, points: int) -> void:
	if not juice_enabled:
		return
	var origin := _feedback_origin(entry)
	var tint := Color(1.0, 0.8, 0.35) if not entry.challenge_kind.is_empty() else Color(0.5, 1.0, 0.7)
	feedback.burst(origin, tint, int(lerpf(6.0, 16.0, juice_strength)))
	feedback.float_text("+" + str(points), origin + Vector2(0.0, 12.0), tint, word_font)

func _play_expiration_feedback(entry: QueuedWord) -> void:
	if not juice_enabled:
		return
	var origin := _feedback_origin(entry)
	feedback.burst(origin, Color(1.0, 0.35, 0.3), 5)
	feedback.float_text("TIME UP", origin, Color(1.0, 0.45, 0.4), word_font)

func _set_typing_streak(value: int) -> void:
	if value > typing_streak:
		streak_pop_clock = 0.0
	elif value == 0:
		streak_pop_clock = 1.0
		streak_label.scale = Vector2.ONE
	typing_streak = maxi(0, value)
	# Set pitch before climb_step() plays the existing keystroke sound.
	if player:
		var audio := player.get_node_or_null("PlayerAudio")
		if audio and audio.has_method("set_typing_streak"):
			audio.set_typing_streak(typing_streak)
		if typing_streak > 0 and typing_streak % 10 == 0 and audio and audio.has_method("play_combo"):
			audio.play_combo(typing_streak)
	_update_streak_ui()
	if juice_enabled and typing_streak > 0 and typing_streak % 10 == 0:
		var origin := streak_label.position + Vector2(streak_label.size.x * 0.5, -8.0)
		feedback.float_text(str(typing_streak) + " STREAK", origin, Color(1.0, 0.85, 0.4), word_font)

func _update_streak_ui() -> void:
	if not is_instance_valid(streak_label):
		return
	streak_label.visible = is_active
	streak_label.text = "[center]\n[color=#ffda66]STREAK " + str(typing_streak) + "[/color][/center]"

func _update_streak_animation(delta: float) -> void:
	streak_pop_clock = minf(1.0, streak_pop_clock + delta / 0.28)
	var strength := juice_strength if juice_enabled else 0.0
	var pop := sin(PI * streak_pop_clock)
	streak_label.scale = Vector2.ONE * (1.0 + pop * 0.4 * strength)

func _update_wpm_indicator(delta: float) -> void:
	var target := 1.0 if is_active else 0.0
	wpm_indicator_opacity = move_toward(wpm_indicator_opacity, target, delta * 5.0)
	wpm_indicator.visible = wpm_indicator_opacity > 0.0
	if not wpm_indicator.visible:
		wpm_heartbeat_clock = 1.0
		previous_indicator_wpm = current_wpm
		wpm_base_scale = 1.0
		return
	if current_wpm > previous_indicator_wpm:
		wpm_heartbeat_clock = 0.0
	elif current_wpm < previous_indicator_wpm:
		wpm_heartbeat_clock = 1.0
	previous_indicator_wpm = current_wpm
	wpm_heartbeat_clock += delta / maxf(0.2, wpm_heartbeat_seconds)
	var strength := juice_strength if juice_enabled and current_wpm >= wpm_indicator_threshold else 0.0
	var speed_growth := clampf(float(current_wpm - wpm_indicator_threshold) / 90.0, 0.0, 1.0)
	var target_scale := 1.0 + speed_growth * 0.4 * strength
	# Larger sustained WPM means a larger resting indicator; losses ease down.
	var response := 9.0 if target_scale > wpm_base_scale else 2.0
	wpm_base_scale = lerpf(wpm_base_scale, target_scale, 1.0 - exp(-response * delta))
	if strength == 0.0:
		wpm_base_scale = 1.0
	# A strong beat followed by a smaller second beat, then a clean settle.
	var pulse := 0.0
	if wpm_heartbeat_clock < 1.0:
		pulse = exp(-pow((wpm_heartbeat_clock - 0.18) / 0.13, 2.0)) * 0.32
		pulse += exp(-pow((wpm_heartbeat_clock - 0.52) / 0.17, 2.0)) * 0.14
	wpm_indicator.scale = Vector2.ONE * (wpm_base_scale + pulse * strength)
	wpm_indicator.modulate = Color(0.65 + pulse * strength * 0.35, 1.0, 0.82, wpm_indicator_opacity)
	wpm_indicator.text = "[center]\n" + str(current_wpm) + " WPM[/center]"

func _reset_wpm_indicator() -> void:
	wpm_indicator_opacity = 0.0
	wpm_heartbeat_clock = 1.0
	previous_indicator_wpm = 0
	wpm_base_scale = 1.0
	if is_instance_valid(wpm_indicator):
		wpm_indicator.hide()
		wpm_indicator.scale = Vector2.ONE
