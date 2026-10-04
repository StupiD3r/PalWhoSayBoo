extends CanvasLayer

@export var score_label: Label
@export var highest_wpm_label: Label
@export var average_wpm_label: Label
@export var accuracy_label: Label

func _ready() -> void:
	visible = false

# Inside game_over_ui.gd:

func show_stats(final_score: int, peak_wpm: int, avg_wpm: int, accuracy: float) -> void:
	score_label.text = "Total Score: " + str(final_score)
	highest_wpm_label.text = "Highest WPM: " + str(peak_wpm)
	average_wpm_label.text = "Average WPM: " + str(avg_wpm)
	accuracy_label.text = "Accuracy: %.1f%%" % accuracy 
	
	# --- NEW: Unlock the mouse so the player can click the button ---
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 
	visible = true

# --- NEW: Connect your Button's "pressed" signal to this function! ---
func _on_restart_button_pressed() -> void:
	# This instantly reloads the entire level from scratch
	get_tree().reload_current_scene()

func hide_stats() -> void:
	visible = false
