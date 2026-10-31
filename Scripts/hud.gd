extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var wpm_label: Label = $WPMLabel # --- NEW LABEL ---

func _ready() -> void:
	# TypingUI owns the right-side WPM display; keep only one visible copy.
	wpm_label.hide()
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_label.position = Vector2(24.0, 16.0)
	score_label.size = Vector2(260.0, 70.0)
	score_label.add_theme_font_override("font", load("res://Assets/font/BARABARA-final.otf"))
	score_label.add_theme_font_size_override("font_size", 22)
	score_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.8))
	score_label.add_theme_constant_override("outline_size", 3)
	score_label.text = "SCORE: 0"
	hide()

func update_score(new_score: int) -> void:
	if score_label:
		show()
		score_label.text = "SCORE: " + str(new_score)

# --- NEW FUNCTION ---
func update_wpm(new_wpm: int) -> void:
	if wpm_label:
		wpm_label.text = "WPM: " + str(new_wpm)
