extends Control

@export var word_label: RichTextLabel
@export var player: CharacterBody3D

var easy_words = ["pole", "coin", "grip", "slip", "grab", "fast", "jump", "high", "win", "tree"]
var medium_words = ["bamboo", "grease", "steady", "effort", "prize", "reach", "height", "sweat"]
var hard_words = ["palosebo", "slippery", "tradition", "festival", "champion", "challenge"]

var current_word = ""
var typed_text = ""
var is_active = false

func _ready():
	visible = false

func start_typing_minigame():
	visible = true
	is_active = true
	get_new_word()

func stop_typing_minigame():
	visible = false
	is_active = false
	typed_text = ""

func get_new_word():
	var word_pool = easy_words + medium_words
	current_word = word_pool.pick_random()
	typed_text = ""
	update_ui()

func _unhandled_input(event: InputEvent):
	if not is_active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Ignore Spacebar so it cleanly passes to player dismount logic
		if event.keycode == KEY_SPACE:
			return

		var typed_char = char(event.unicode).to_lower()
		
		# Check if typed character matches the next required letter
		if current_word.begins_with(typed_text + typed_char):
			typed_text += typed_char
			update_ui()
			
			if typed_text == current_word:
				on_word_completed()

func update_ui():
	if word_label:
		# Set formatted BBCode text
		word_label.text = "[color=green]" + typed_text + "[/color]" + current_word.substr(typed_text.length())

func on_word_completed():
	print("Word Completed!")
	if player and player.is_climbing:
		player.global_position.y += 1.0 # Move character up on success
	
	get_new_word()
