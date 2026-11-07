extends Light3D

@export var normal_energy: float = 0.8
@export var dim_energy: float = 0.02

@export var minimum_wait: float = 0.15
@export var maximum_wait: float = 0.7

var random := RandomNumberGenerator.new()


func _ready() -> void:
	random.randomize()
	light_energy = normal_energy
	_flicker_loop()


func _flicker_loop() -> void:
	while is_inside_tree():
		var shortest_wait := maxf(minimum_wait, 0.01)
		var longest_wait := maxf(maximum_wait, shortest_wait)

		await get_tree().create_timer(
			random.randf_range(shortest_wait, longest_wait)
		).timeout

		var flicker_count := random.randi_range(3, 8)

		for _i in range(flicker_count):
			# Almost go out.
			light_energy = random.randf_range(
				0.0, maxf(dim_energy, 0.0)
			)

			await get_tree().create_timer(
				random.randf_range(0.02, 0.08)
			).timeout

			# Recover unevenly.
			light_energy = normal_energy * random.randf_range(
				0.65, 1.0
			)

			await get_tree().create_timer(
				random.randf_range(0.02, 0.07)
			).timeout

		# Occasionally fail completely for a moment.
		if random.randf() < 0.25:
			light_energy = 0.0

			await get_tree().create_timer(
				random.randf_range(0.15, 0.35)
			).timeout

		light_energy = normal_energy
