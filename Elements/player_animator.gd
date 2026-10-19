extends Node

@export var animation_player: AnimationPlayer

func update_ground_animation(horizontal_speed: float, is_on_floor: bool, is_running: bool) -> void:
	if not animation_player: return
	
	var blend_time = 0.2
	if not is_on_floor:
		if animation_player.current_animation != "custom/jumping" and animation_player.has_animation("custom/jumping"):
			animation_player.play("custom/jumping", blend_time)
	elif horizontal_speed > 0.1:
		if is_running:
			if animation_player.current_animation != "custom/running" and animation_player.has_animation("custom/running"):
				animation_player.play("custom/running", blend_time)
		else:
			if animation_player.current_animation != "mixamo_com" and animation_player.has_animation("mixamo_com"):
				animation_player.play("mixamo_com", blend_time)
	else:
		if animation_player.current_animation != "custom/idle2" and animation_player.has_animation("custom/idle2"):
			animation_player.play("custom/idle2", blend_time)

func play_getting_up() -> float:
	if animation_player and animation_player.has_animation("custom/gettingup"):
		var anim = animation_player.get_animation("custom/gettingup")
		anim.loop_mode = Animation.LOOP_NONE
		animation_player.play("custom/gettingup")
		return anim.length
	return 0.0

func play_idle() -> void:
	if animation_player and animation_player.has_animation("custom/idle2"):
		animation_player.play("custom/idle2", 0.5)

func prepare_climb() -> void:
	if animation_player and animation_player.has_animation("custom/climbing"):
		animation_player.play("custom/climbing", 0.0)
		animation_player.seek(0.0, true)
		animation_player.pause()

func step_climb() -> void:
	if not animation_player: return
	if animation_player.assigned_animation != "custom/climbing":
		animation_player.play("custom/climbing")
	if not animation_player.is_playing():
		animation_player.play()

func pause() -> void:
	if animation_player:
		animation_player.pause()
