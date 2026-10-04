extends Control

@export var next_word_label: RichTextLabel
@export var current_word_label: RichTextLabel
@export var player: CharacterBody3D

signal score_changed(new_score: int)
signal wpm_changed(new_wpm: int) # --- NEW SIGNAL ---

var easy_words = ["poste", "barya", "kapit", "dulas", "hawak", "bilis", "talon", "tangkad", "panalo", "punongkahoy"]
var medium_words = ["kawayan", "grasa", "panatag", "pagsisikap", "premyo", "abot", "taas", "pawis"]
var hard_words = ["palosebo", "madulas", "tradisyon", "piyesta", "kampyeon", "pagsubok"]

var current_word: String = ""
var next_word: String = ""
var typed_text: String = ""
var is_active: bool = false
var score: int = 0 

# --- NEW: WPM Tracking Variables ---
var time_elapsed: float = 0.0
var total_chars_typed: int = 0

func _ready():
	visible = false

# --- NEW: Continuous WPM Calculation ---
func _process(delta: float) -> void:
	if not is_active:
		return
		
	time_elapsed += delta
	
	# Wait 1 second before calculating to avoid wild numbers at the very start
	if time_elapsed > 1.0:
		var standard_words = total_chars_typed / 5.0
		var minutes = time_elapsed / 60.0
		var current_wpm = int(standard_words / minutes)
		
		# Send the live WPM to the HUD every frame
		wpm_changed.emit(current_wpm)

func start_typing_minigame():
	visible = true
	is_active = true
	
	score = 0
	score_changed.emit(score)
	
	# Reset WPM stats on start
	time_elapsed = 0.0
	total_chars_typed = 0
	wpm_changed.emit(0)
	
	current_word = get_random_word()
	next_word = get_random_word()
	
	typed_text = ""
	update_ui()

func stop_typing_minigame():
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

		var typed_char = char(event.unicode).to_lower()
		
		if current_word.begins_with(typed_text + typed_char):
			typed_text += typed_char
			total_chars_typed += 1 # --- NEW: Count successful keystrokes ---
			update_ui()
			
			if player and player.has_method("climb_step"):
				player.climb_step() 
			
			if typed_text == current_word:
				on_word_completed()

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
