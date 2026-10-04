extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var wpm_label: Label = $WPMLabel # --- NEW LABEL ---

func update_score(new_score: int) -> void:
	if score_label:
		score_label.text = "Score: " + str(new_score)

# --- NEW FUNCTION ---
func update_wpm(new_wpm: int) -> void:
	if wpm_label:
		wpm_label.text = "WPM: " + str(new_wpm)
