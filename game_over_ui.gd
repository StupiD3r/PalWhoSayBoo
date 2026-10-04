extends CanvasLayer

@export var score_label: Label
@export var highest_wpm_label: Label
@export var average_wpm_label: Label
@export var accuracy_label: Label

func _ready() -> void:
	visible = false

# This function receives the final math and displays it
func show_stats(final_score: int, peak_wpm: int, avg_wpm: int, accuracy: float) -> void:
	score_label.text = "Total Score: " + str(final_score)
	highest_wpm_label.text = "Highest WPM: " + str(peak_wpm)
	average_wpm_label.text = "Average WPM: " + str(avg_wpm)
	
	# %.1f formats the decimal to 1 place (e.g., 95.5%)
	accuracy_label.text = "Accuracy: %.1f%%" % accuracy 
	
	visible = true

func hide_stats() -> void:
	visible = false
