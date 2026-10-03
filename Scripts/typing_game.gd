extends Control

# --- Updated to two labels! ---
@export var next_word_label: RichTextLabel     # The smaller, faded word on top
@export var current_word_label: RichTextLabel  # The big, green/white word on bottom
@export var player: CharacterBody3D

# Original word lists
var easy_words = ["poste", "barya", "kapit", "dulas", "hawak", "bilis", "talon", "tangkad", "panalo", "punongkahoy"]
var medium_words = ["kawayan", "grasa", "panatag", "pagsisikap", "premyo", "abot", "taas", "pawis"]
var hard_words = ["palosebo", "madulas", "tradisyon", "piyesta", "kampyeon", "pagsubok"]

# --- State tracking variables ---
var active_word_pool: Array = []   # Combined list that gets shuffled
var current_word_index: int = 0    # Our progress through the shuffled pool
var current_word: String = ""
var typed_text: String = ""
var is_active: bool = false

# Optional signal for your main scene to know when the list is complete
signal climb_completed

func _ready():
	visible = false

func start_typing_minigame():
	visible = true
	is_active = true
	
	# Prepare and shuffle the pool once when the game starts
	prepare_word_pool()
	
	# Load the first words
	load_words_at_current_index()

func stop_typing_minigame():
	visible = false
	is_active = false
	typed_text = ""
	active_word_pool.clear()
	current_word_index = 0
	
	# Clear the UI for next time
	if next_word_label: next_word_label.text = ""
	if current_word_label: current_word_label.text = ""

# Combine pools and randomize order once per climb
func prepare_word_pool():
	# Combine easy, medium, and maybe a few hard words
	active_word_pool = easy_words + medium_words + hard_words.slice(0, 3)
	active_word_pool.shuffle()
	current_word_index = 0

# Function to load both the current and next word based on the index
func load_words_at_current_index():
	typed_text = ""
	
	# 1. End Condition: Are we out of words?
	if current_word_index >= active_word_pool.size():
		# This condition is handled at the end of load_words_at_current_index call from on_word_completed
		return

	# 2. Get and set the Current Word (bottom, prominent line)
	current_word = active_word_pool[current_word_index]
	update_ui() # This handles BBCode formatting for current word

	# 3. Get and set the Next Word (top, faded line)
	if next_word_label:
		# Check if a 'next' word even exists
		if current_word_index + 1 < active_word_pool.size():
			var next_w = active_word_pool[current_word_index + 1]
			# Set a simple BBCode color to make it faded/gray and center it
			next_word_label.text = "[center][color=gray]" + next_w + "[/color][/center]"
		else:
			# If you're on the last word, the 'next' spot should be blank
			next_word_label.text = ""

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
			
			# --- TRIGGER MOVEMENT AND ANIMATION PER KEYSTROKE ---
			if player and player.has_method("climb_step"):
				player.climb_step() 
			
			if typed_text == current_word:
				on_word_completed()

func update_ui():
	# Use new variable name and add BBCode centering [center] tags
	if current_word_label:
		# Standard BBCode for green correct/white remaining text, wrapped in center
		current_word_label.text = "[center][color=green]" + typed_text + "[/color]" + current_word.substr(typed_text.length()) + "[/center]"

func on_word_completed():
	print("Word Completed!")
	
	# Increment the index to advance the list
	current_word_index += 1
	
	# Check if the whole list is complete *after* finishing the final word
	if current_word_index >= active_word_pool.size():
		# Final text condition
		if current_word_label: 
			# Use gold, bold, wavy text to announce finish!
			current_word_label.text = "[center][color=gold][b][wave]FINISH![/wave][/b][/color][/center]"
		if next_word_label: next_word_label.text = ""
		
		# Prevent further typing, wait, and auto-close
		is_active = false
		print("List Complete! Closing minigame.")
		climb_completed.emit() # Signal for other scripts
		
		await get_tree().create_timer(1.2).timeout
		stop_typing_minigame()
	else:
		# List not done, load the next set
		load_words_at_current_index()
