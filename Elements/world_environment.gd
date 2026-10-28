extends WorldEnvironment

func _ready() -> void:
	var env := Environment.new()
	
	# 1. Sky & Background Setup
	env.background_mode = Environment.BG_SKY
	var sky_res := Sky.new()
	sky_res.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky_res
	
	# 2. Ambient Sky Bounce Light
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	
	# 3. Tonemapping (Fixed enum constant)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	
	environment = env   
