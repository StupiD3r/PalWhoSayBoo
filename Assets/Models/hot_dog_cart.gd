extends Node3D
## Procedural, self-contained hot-dog cart prop. Front/customer side faces -Z.

const CART_W := 3.35
const CART_D := 1.42
const BODY_H := 1.24

func _ready() -> void:
	_build_cart()

func _mat(color: Color, roughness := 0.82, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _make_paint_texture() -> ImageTexture:
	# Mottled, chipped enamel with long rust drips and a dirty lower edge.
	var image := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 846213
	for y in range(128):
		for x in range(256):
			var edge_dirt := clampf((float(y) / 127.0 - 0.72) * 0.46, 0.0, 0.20)
			var noise := rng.randf_range(-0.075, 0.075)
			var shade := clampf(0.73 - edge_dirt + noise, 0.0, 1.0)
			image.set_pixel(x, y, Color(shade * 0.99, shade * 0.97, shade * 0.91, 1.0))
	# Narrow uneven oxide runs, with darker centers and translucent rust edges.
	for streak in range(38):
		var sx := rng.randi_range(2, 253)
		var sy := rng.randi_range(0, 76)
		var run := rng.randi_range(12, 68)
		var width := rng.randi_range(1, 3)
		for dy in range(run):
			var yy := sy + dy
			if yy >= 128:
				break
			var xx := clampi(sx + int(sin(float(dy) * 0.17) * 1.2), 0, 255)
			for dx in range(-width, width + 1):
				var px := clampi(xx + dx, 0, 255)
				var old := image.get_pixel(px, yy)
				var oxide := Color(0.36, 0.22, 0.14, 1.0) if abs(dx) == 0 else Color(0.52, 0.34, 0.22, 1.0)
				image.set_pixel(px, yy, old.lerp(oxide, 0.68 if dx == 0 else 0.34))
	# Fine paint chips and soot smudges.
	for chip in range(210):
		var cx := rng.randi_range(0, 255)
		var cy := rng.randi_range(0, 127)
		var old := image.get_pixel(cx, cy)
		image.set_pixel(cx, cy, old.lerp(Color(0.35, 0.29, 0.23), rng.randf_range(0.25, 0.7)))
	return ImageTexture.create_from_image(image)

func _box(label: String, size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.material_override = mat
	parent.add_child(n)
	return n

func _cyl(label: String, radius: float, height: float, pos: Vector3, mat: Material, parent: Node = self, radial := 24) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial
	mesh.rings = 1
	n.mesh = mesh
	n.position = pos
	n.material_override = mat
	parent.add_child(n)
	return n

func _rod(label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var n := _cyl(label, radius, a.distance_to(b), (a + b) * 0.5, mat)
	n.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return n

func _build_cart() -> void:
	var enamel := _mat(Color("b9b5a9"))
	enamel.albedo_texture = _make_paint_texture()
	var topmetal := _mat(Color("777b78"), 0.48, 0.48)
	var rust := _mat(Color("76513a"), 0.9, 0.05)
	var black := _mat(Color("242321"), 0.96)
	var rubber := _mat(Color("171716"), 0.98)
	var cream := _mat(Color("f2e4c9"), 0.92)
	var red := _mat(Color("b8423b"), 0.62)
	var mustard := _mat(Color("d1ae36"), 0.7)
	var steel := _mat(Color("a6aaa4"), 0.38, 0.72)
	var dirty := _mat(Color("8d8170"), 0.95)

	# Box body, with a thin oxidized frame and separate work surface.
	_box("Enamel cart body", Vector3(CART_W, BODY_H, CART_D), Vector3(0, 1.10, 0), enamel)
	_box("Front lower rust seam", Vector3(CART_W + 0.035, 0.055, 0.035), Vector3(0, 0.49, -CART_D * 0.5 - 0.013), rust)
	_box("Front top trim", Vector3(CART_W + 0.04, 0.045, 0.045), Vector3(0, 1.70, -CART_D * 0.5 - 0.012), steel)
	_box("Countertop", Vector3(CART_W + 0.08, 0.095, CART_D + 0.08), Vector3(0, 1.76, 0), topmetal)
	# Scratched/rusty corner guards and rivets.
	for x in [-CART_W * 0.5 + 0.035, CART_W * 0.5 - 0.035]:
		_box("Rusty corner strip", Vector3(0.055, BODY_H, 0.045), Vector3(x, 1.10, -CART_D * 0.5 - 0.025), rust)
		for y in [0.58, 1.57]:
			var rivet := _cyl("Front panel rivet", 0.025, 0.016, Vector3(x, y, -CART_D * 0.5 - 0.052), steel, self, 12)
			rivet.rotation.x = PI * 0.5
	# Rear and customer-facing panel inset seams.
	_box("Front panel inset", Vector3(CART_W - 0.16, 1.02, 0.018), Vector3(0, 1.09, -CART_D * 0.5 - 0.012), dirty)
	_box("Front enamel face", Vector3(CART_W - 0.19, 0.99, 0.022), Vector3(0, 1.10, -CART_D * 0.5 - 0.027), enamel)
	# Small irregular brown flecks and vertical runs give the old enamel its worn finish.
	var stain := _mat(Color("897966"), 1.0)
	for i in range(24):
		var px := -1.48 + fposmod(float(i) * 0.619, 2.96)
		var py := 0.64 + fposmod(float(i) * 0.373, 0.88)
		var mark := _box("Enamel stain", Vector3(0.018 + fposmod(float(i) * 0.07, 0.045), 0.025 + fposmod(float(i) * 0.11, 0.13), 0.008), Vector3(px, py, -CART_D * 0.5 - 0.044), stain)
		mark.rotation.z = fposmod(float(i) * 1.7, 0.35) - 0.17

	# Single exposed wheel on the visible side: tire, steel rim, hub and lug bolts.
	var wheel_x := -0.82
	var wheel_y := 0.58
	var tire := _cyl("Worn rubber tire", 0.48, 0.24, Vector3(wheel_x, wheel_y, -0.79), rubber, self, 12)
	tire.rotation.x = PI * 0.5
	var rim := _cyl("Steel wheel rim", 0.315, 0.255, Vector3(wheel_x, wheel_y, -0.81), steel, self, 12)
	rim.rotation.x = PI * 0.5
	var dish := _cyl("Dark rim dish", 0.235, 0.26, Vector3(wheel_x, wheel_y, -0.825), dirty, self, 12)
	dish.rotation.x = PI * 0.5
	var hub := _cyl("Wheel hub", 0.105, 0.28, Vector3(wheel_x, wheel_y, -0.84), steel, self, 10)
	hub.rotation.x = PI * 0.5
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var lug := _cyl("Rim lug", 0.027, 0.275, Vector3(wheel_x + cos(a) * 0.18, wheel_y + sin(a) * 0.18, -0.85), cream, self, 10)
		lug.rotation.x = PI * 0.5
	# Matching wheel on the opposite side, visible in the reverse reference view.
	var far_tire := _cyl("Opposite worn rubber tire", 0.48, 0.24, Vector3(0.82, wheel_y, 0.79), rubber, self, 12)
	far_tire.rotation.x = PI * 0.5
	var far_rim := _cyl("Opposite steel wheel rim", 0.315, 0.255, Vector3(0.82, wheel_y, 0.81), steel, self, 12)
	far_rim.rotation.x = PI * 0.5
	var far_dish := _cyl("Opposite rim dish", 0.23, 0.26, Vector3(0.82, wheel_y, 0.825), dirty, self, 12)
	far_dish.rotation.x = PI * 0.5
	var far_hub := _cyl("Opposite wheel hub", 0.105, 0.28, Vector3(0.82, wheel_y, 0.84), steel, self, 10)
	far_hub.rotation.x = PI * 0.5
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var lug := _cyl("Opposite rim lug", 0.027, 0.275, Vector3(0.82 + cos(a) * 0.18, wheel_y + sin(a) * 0.18, 0.85), cream, self, 8)
		lug.rotation.x = PI * 0.5
	# Axle and shadowed wheel well.
	var axle := _cyl("Wheel axle", 0.09, 1.7, Vector3(wheel_x, wheel_y, 0), black, self, 16)
	axle.rotation.x = PI * 0.5
	# Reverse side: plain stained service panel, narrow access door, pull,
	# and two shallow framed storage drawers matching the reference image.
	_box("Reverse lower rust seam", Vector3(CART_W + 0.035, 0.055, 0.035), Vector3(0, 0.49, CART_D * 0.5 + 0.013), rust)
	_box("Reverse upper trim", Vector3(CART_W + 0.04, 0.045, 0.045), Vector3(0, 1.70, CART_D * 0.5 + 0.012), steel)
	_box("Reverse enamel face", Vector3(CART_W - 0.19, 0.99, 0.022), Vector3(0, 1.10, CART_D * 0.5 + 0.027), enamel)
	# Access door toward the hitch end with a slim dark pull handle.
	_box("Service door seam", Vector3(0.62, 0.91, 0.022), Vector3(1.08, 1.09, CART_D * 0.5 + 0.045), rust)
	_box("Service door panel", Vector3(0.57, 0.86, 0.024), Vector3(1.08, 1.09, CART_D * 0.5 + 0.06), enamel)
	_box("Service door pull", Vector3(0.055, 0.28, 0.045), Vector3(0.88, 1.12, CART_D * 0.5 + 0.09), dirty)
	_box("Door pull grip", Vector3(0.035, 0.19, 0.035), Vector3(0.86, 1.12, CART_D * 0.5 + 0.12), steel)
	# Two narrow storage trays/drawer faces beneath the serving edge.
	for y in [1.37, 1.03]:
		_box("Drawer rust border", Vector3(1.02, 0.27, 0.035), Vector3(-0.12, y, CART_D * 0.5 + 0.045), rust)
		_box("Drawer face", Vector3(0.96, 0.22, 0.04), Vector3(-0.12, y, CART_D * 0.5 + 0.065), enamel)
		_box("Drawer pull plate", Vector3(0.24, 0.07, 0.025), Vector3(-0.12, y, CART_D * 0.5 + 0.09), dirty)
		_box("Drawer pull grip", Vector3(0.14, 0.025, 0.04), Vector3(-0.12, y - 0.015, CART_D * 0.5 + 0.12), steel)
	
	# Towbar projects from the right side of the cart in the reference view.
	_rod("Towbar left rail", Vector3(1.48, 0.60, -0.38), Vector3(2.70, 0.46, -0.11), 0.065, rust)
	_rod("Towbar right rail", Vector3(1.48, 0.60, 0.37), Vector3(2.70, 0.46, 0.11), 0.065, rust)
	_rod("Towbar cross brace", Vector3(1.66, 0.57, -0.28), Vector3(1.66, 0.57, 0.28), 0.045, steel)
	var coupler := _cyl("Hitch coupler", 0.11, 0.30, Vector3(2.72, 0.46, 0), steel, self, 8)
	coupler.rotation.z = PI * 0.5
	var jack := _cyl("Drop jack post", 0.045, 0.46, Vector3(2.38, 0.25, 0), steel, self, 12)
	_box("Jack foot", Vector3(0.24, 0.045, 0.20), Vector3(2.38, 0.025, 0), steel)
	_cyl("Jack crank knob", 0.09, 0.13, Vector3(2.38, 0.74, 0), dirty, self, 6)

	# Tall square canopy supports and broad, shallow striped awning.
	var polemat := _mat(Color("343632"), 0.72, 0.2)
	for x in [-1.28, 1.28]:
		_rod("Canopy upright", Vector3(x, 1.80, 0.48), Vector3(x, 3.65, 0.48), 0.045, polemat)
		_box("Upright mounting plate", Vector3(0.14, 0.10, 0.13), Vector3(x, 1.84, 0.48), steel)
	_box("Awning underside", Vector3(3.75, 0.075, 2.05), Vector3(0, 3.66, 0), cream)
	_box("Awning front valance", Vector3(3.75, 0.22, 0.07), Vector3(0, 3.52, -1.00), cream)
	var awning_red := _mat(Color("bd8850"), 0.8)
	# Narrow faded orange stripes across the roof and down the front valance.
	for i in range(15):
		var x := -1.76 + float(i) * 0.25
		_box("Faded canopy stripe", Vector3(0.105, 0.018, 2.02), Vector3(x, 3.707, 0), awning_red)
		_box("Valance stripe", Vector3(0.105, 0.20, 0.018), Vector3(x, 3.52, -1.043), awning_red)
	# Back edge fascia, visible as a little hanging fabric edge.
	_box("Awning rear valance", Vector3(3.75, 0.14, 0.06), Vector3(0, 3.57, 1.00), cream)

	# Side branding: raised, blocky HOT DOG letters on the visible panel.
	_add_text("HOT\nDOG", Vector3(0.61, 1.20, -0.755), 0.46, Color("874b3d"), true)
	# Bun and sausage icon, facing the customer side.
	var bun := _cyl("Illustrated bun", 0.20, 0.83, Vector3(-0.91, 1.35, -0.77), _mat(Color("c69b63")), self, 20)
	bun.rotation.z = PI * 0.5
	bun.rotation.x = PI * 0.5
	var sausage := _cyl("Illustrated sausage", 0.105, 0.89, Vector3(-0.91, 1.51, -0.79), _mat(Color("a95846")), self, 20)
	sausage.rotation.z = PI * 0.5
	sausage.rotation.x = PI * 0.5
	# Mustard stripe on top as a thin yellow squiggle made of connected dashes.
	for i in range(5):
		var dash := _box("Mustard on hotdog", Vector3(0.16, 0.025, 0.018), Vector3(-1.23 + i * 0.16, 1.59 + sin(i * 1.3) * 0.035, -0.91), mustard)
		dash.rotation.z = -0.12

	# Countertop equipment: large dark oval griddle, guard, condiment bottles,
	# small paper trays, and paired lidded ingredient wells.
	var griddle := _cyl("Hot dog roller base", 0.50, 0.12, Vector3(-0.75, 1.89, 0.10), black, self, 12)
	griddle.scale = Vector3(1.35, 1.0, 0.74)
	_box("Griddle backsplash", Vector3(1.20, 0.40, 0.08), Vector3(-0.75, 2.12, 0.38), black)
	_box("Griddle side end", Vector3(0.08, 0.29, 0.47), Vector3(-1.34, 2.03, 0.14), steel)
	_box("Griddle control strip", Vector3(1.02, 0.12, 0.035), Vector3(-0.75, 1.94, 0.44), dirty)
	for i in range(5):
		var knob := _cyl("Faceted griddle control", 0.045, 0.055, Vector3(-1.12 + i * 0.18, 1.96, 0.475), black, self, 6)
		knob.rotation.x = PI * 0.5
	for i in range(5):
		var roller := _cyl("Grill roller", 0.045, 0.88, Vector3(-0.76, 2.00, -0.19 + i * 0.14), steel, self, 8)
		roller.rotation.z = PI * 0.5
	# Condiment bottles with tapered-looking shoulders and pointed caps.
	for item in [[0.42, mustard], [0.72, red]]:
		var bx: float = item[0]
		var bm: Material = item[1]
		_cyl("Squeeze bottle", 0.085, 0.40, Vector3(bx, 2.01, -0.22), bm, self, 16)
		_cyl("Bottle neck", 0.047, 0.10, Vector3(bx, 2.26, -0.22), bm, self, 14)
		_cyl("Bottle nozzle", 0.015, 0.12, Vector3(bx, 2.37, -0.22), bm, self, 12)
	# Two brown paper hotdog trays near the griddle.
	for x in [-0.28, 0.18]:
		_box("Paper food tray", Vector3(0.40, 0.08, 0.28), Vector3(x, 1.88, -0.45), _mat(Color("b28b53")))
		_box("Tray rim", Vector3(0.42, 0.025, 0.30), Vector3(x, 1.93, -0.45), cream)
	# Pair of stainless recessed ingredient lids at the right end.
	for x in [1.00, 1.55]:
		_box("Ingredient well dark inset", Vector3(0.46, 0.03, 0.55), Vector3(x, 1.825, 0.12), black)
		_box("Ingredient lid", Vector3(0.48, 0.035, 0.58), Vector3(x, 1.85, 0.12), steel)
		_box("Lid handle", Vector3(0.11, 0.035, 0.055), Vector3(x, 1.89, 0.12), dirty)

func _add_text(value: String, pos: Vector3, size: float, color: Color, outline := false) -> void:
	var label := Label3D.new()
	label.name = "Cart sign"
	label.text = value
	label.font_size = int(size * 100)
	label.pixel_size = 0.0055
	label.modulate = color
	label.position = pos
	label.rotation.y = PI
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.line_spacing = -22
	if outline:
		label.outline_size = 1
		label.outline_modulate = Color("d8d0bd")
	add_child(label)
