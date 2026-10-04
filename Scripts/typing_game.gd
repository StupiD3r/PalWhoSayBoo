extends Control

@export var next_word_label: RichTextLabel
@export var current_word_label: RichTextLabel
@export var player: CharacterBody3D

signal score_changed(new_score: int)
signal wpm_changed(new_wpm: int)
signal game_over_triggered(final_score: int, highest_wpm: int, avg_wpm: int, accuracy: float) # --- NEW ---

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
		
		# --- NEW: Track Highest WPM ---
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
	# --- NEW: Final Math Calculations ---
	var accuracy: float = 0.0
	if total_keystrokes > 0:
		accuracy = (float(total_chars_typed) / float(total_keystrokes)) * 100.0
		
	# Broadcast the final stats to the Game Over screen!
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

		# Track ALL keystrokes for real-time accuracy
		total_keystrokes += 1

		var typed_char = char(event.unicode).to_lower()
		
		if current_word.begins_with(typed_text + typed_char):
			typed_text += typed_char
			total_chars_typed += 1 # Track correct keystrokes
			update_ui()
			
			if player and player.has_method("climb_step"):
				player.climb_step() 
			
			if typed_text == current_word:
				on_word_completed()
		
		# --- REAL-TIME ELIMINATION CHECK ---
		# Wait until the player has typed 20 letters to give them a brief grace period
		if total_keystrokes >= 20:
			var live_accuracy = (float(total_chars_typed) / float(total_keystrokes)) * 100.0
			
			if live_accuracy < 95.0:
				trigger_elimination()

# --- NEW FUNCTION ---
func trigger_elimination():
	if player and player.has_method("force_dismount"):
		player.force_dismount(true) # True triggers the fall logic!
		
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
