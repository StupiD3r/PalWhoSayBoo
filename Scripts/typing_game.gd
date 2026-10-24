extends Control

@export var next_word_label: RichTextLabel
@export var current_word_label: RichTextLabel
@export var player: CharacterBody3D

signal score_changed(new_score: int)
signal wpm_changed(new_wpm: int)
signal game_over_triggered(final_score: int, highest_wpm: int, avg_wpm: int, accuracy: float)

var easy_words = ["poste", "barya", "kapit", "dulas", "hawak", "bilis", "talon", "tangkad", "panalo", "punongkahoy"]
var medium_words = ["kawayan", "grasa", "panatag", "pagsisikap", "premyo", "abot", "taas", "pawis"]
var hard_words = ["palosebo", "madulas", "tradisyon", "piyesta", "kampyeon", "pagsubok"]

var current_word: String = ""
var next_word: String = ""
var typed_text: String = ""
var is_active: bool = false
var score: int = 0 

# --- Stat Tracking Variables ---
var time_elapsed: float = 0.0
var total_chars_typed: int = 0 # Correct keystrokes
var total_keystrokes: int = 0  # ALL keystrokes (for accuracy)
var highest_wpm: int = 0
var current_wpm: int = 0

# --- Juice Tween References ---
var pop_tween: Tween
var shake_tween: Tween

func _ready():
	visible = false

func _process(delta: float) -> void:
	if not is_active:
		return
		
	time_elapsed += delta
	
	if time_elapsed > 1.0:
		var standard_words = total_chars_typed / 5.0
		var minutes = time_elapsed / 60.0
		current_wpm = int(standard_words / minutes)
		
		if current_wpm > highest_wpm:
			highest_wpm = current_wpm
			
		wpm_changed.emit(current_wpm)

func start_typing_minigame():
	visible = true
	is_active = true
	
	score = 0
	time_elapsed = 0.0
	total_chars_typed = 0
	total_keystrokes = 0
	highest_wpm = 0
	current_wpm = 0
	
	score_changed.emit(score)
	wpm_changed.emit(0)
	
	current_word = get_random_word()
	next_word = get_random_word()
	
	typed_text = ""
	update_ui()

func stop_typing_minigame():
	var accuracy: float = 0.0
	if total_keystrokes > 0:
		accuracy = (float(total_chars_typed) / float(total_keystrokes)) * 100.0
		
	game_over_triggered.emit(score, highest_wpm, current_wpm, accuracy)

	visible = false
	is_active = false
	typed_text = ""
	if next_word_label: next_word_label.text = ""
	if current_word_label: current_word_label.text = ""

func get_random_word() -> String:
	var all_words = easy_words + medium_words + hard_words
	return all_words.pick_random()

func _unhandled_input(event: InputEvent):
	if not is_active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			return

		if event.unicode == 0:
			return

		total_keystrokes += 1
		var typed_char = char(event.unicode).to_lower()
		
		# --- CORRECT KEYSTROKE ---
		if current_word.begins_with(typed_text + typed_char):
			typed_text += typed_char
			total_chars_typed += 1
			update_ui()
			
			# Trigger player climb step + pass current WPM for audio pitch scaling
			if player and player.has_method("climb_step"):
				player.climb_step(current_wpm)
			
			# Trigger UI label pop juice
			animate_correct_type()
			
			if typed_text == current_word:
				on_word_completed()
				
		# --- MISTYPE / ERROR ---
		else:
			# Trigger player camera jitter & error juice
			if player and player.has_method("on_typing_error"):
				player.on_typing_error()
				
			# Trigger UI label error flash & shake
			animate_error_type()
		
		# --- REAL-TIME ELIMINATION CHECK ---
		if total_keystrokes >= 20:
			var live_accuracy = (float(total_chars_typed) / float(total_keystrokes)) * 100.0
			if live_accuracy < 80.0:
				trigger_elimination()

func trigger_elimination():
	if player and player.has_method("force_dismount"):
		player.force_dismount(true)
		
	stop_typing_minigame()

func update_ui():
	if current_word_label:
		current_word_label.text = "[center][color=green]" + typed_text + "[/color]" + current_word.substr(typed_text.length()) + "[/center]"
		
	if next_word_label:
		next_word_label.text = "[center][color=gray]" + next_word + "[/color][/center]"

func on_word_completed():
	var points_earned = current_word.length() * 10
	score += points_earned
	score_changed.emit(score)
	
	current_word = next_word
	next_word = get_random_word()
	
	typed_text = ""
	update_ui()

# --- UI JUICE ANIMATIONS ---

func animate_correct_type():
	if not current_word_label: return
	
	current_word_label.pivot_offset = current_word_label.size / 2.0
	
	if pop_tween and pop_tween.is_valid():
		pop_tween.kill()
		
	pop_tween = create_tween()
	current_word_label.scale = Vector2(1.15, 1.15)
	pop_tween.tween_property(current_word_label, "scale", Vector2(1.0, 1.0), 0.1)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

func animate_error_type():
	if not current_word_label: return
	
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
		
	shake_tween = create_tween().set_parallel(true)
	
	# Flash label red briefly
	current_word_label.modulate = Color.RED
	shake_tween.tween_property(current_word_label, "modulate", Color.WHITE, 0.2)
	
	# Horizontal jitter shake
	var orig_x = current_word_label.position.x
	current_word_label.position.x = orig_x + 8.0
	shake_tween.tween_property(current_word_label, "position:x", orig_x, 0.15)\
		.set_trans(Tween.TRANS_SPRING)
