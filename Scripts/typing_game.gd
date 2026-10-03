extends Control

@export var next_word_label: RichTextLabel
@export var current_word_label: RichTextLabel
@export var player: CharacterBody3D

# --- NEW: Signal to broadcast the score to the HUD ---
signal score_changed(new_score: int)

var easy_words = ["poste", "barya", "kapit", "dulas", "hawak", "bilis", "talon", "tangkad", "panalo", "punongkahoy"]
var medium_words = ["kawayan", "grasa", "panatag", "pagsisikap", "premyo", "abot", "taas", "pawis"]
var hard_words = ["palosebo", "madulas", "tradisyon", "piyesta", "kampyeon", "pagsubok"]

var current_word: String = ""
var next_word: String = ""
var typed_text: String = ""
var is_active: bool = false
var score: int = 0 

func _ready():
	visible = false

func start_typing_minigame():
	visible = true
	is_active = true
	
	# Reset score when starting and tell the HUD
	score = 0
	score_changed.emit(score)
	
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
	# Calculate new score
	var points_earned = current_word.length() * 10
	score += points_earned
	
	# --- NEW: Broadcast the updated score ---
	score_changed.emit(score)
	
	current_word = next_word
	next_word = get_random_word()
	
	typed_text = ""
	update_ui()
