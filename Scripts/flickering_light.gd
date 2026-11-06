extends Light3D

@export var normal_energy: float = 0.8
@export var dim_energy: float = 0.05

@export var minimum_wait: float = 4.0
@export var maximum_wait: float = 9.0

var random := RandomNumberGenerator.new()


func _ready() -> void:
	random.randomize()
	light_energy = normal_energy
	_flicker_loop()


func _flicker_loop() -> void:
	while is_inside_tree():
		# Stay steady between flickering bursts.
		var delay := random.randf_range(
			maxf(minimum_wait, 0.1),
			maxf(maximum_wait, maxf(minimum_wait, 0.1))
		)
		await get_tree().create_timer(delay).timeout

		# Briefly dim and recover a few times.
		var flicker_count := random.randi_range(2, 4)

		for i in range(flicker_count):
			light_energy = dim_energy
			await get_tree().create_timer(
				random.randf_range(0.06, 0.15)
			).timeout

			light_energy = normal_energy
			await get_tree().create_timer(
				random.randf_range(0.08, 0.2)
			).timeout

		light_energy = normal_energy
