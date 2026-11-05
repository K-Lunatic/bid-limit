class_name AuctionHall
extends Node3D

const SockPuppetScript = preload("res://scripts/sock_puppet.gd")
const AuctionSurfaceShader = preload("res://shaders/auction_surface.gdshader")

const WALNUT := Color("2c211d")
const WOOD := Color("5b3926")
const VELVET := Color("641f31")
const BRASS := Color("cfa35d")
const PLASTER := Color("d7cbbb")
const INK := Color("17131e")
const MARKET := Color("38204d")

var decor_noise := FastNoiseLite.new()

func build() -> void:
	decor_noise.seed = 101
	decor_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	decor_noise.frequency = 0.23
	add_floor_plan()
	add_saleroom_shell()
	add_noise_composed_details()
	add_rostrum_and_lot()
	add_bidder_floor()
	add_chandelier_and_lights()
	add_black_market()
	add_mending_room()
	add_weapon_locker()
	add_skywell()
	add_sign("THE LAST HAND EXCHANGE", Vector3(0, 7.75, -10.15), 1.08, Color("f3dfb8"))
	add_sign("LOT 101  /  THE LAST HAND", Vector3(0, 5.98, -9.8), 0.42, Color("d9bb83"))

func add_floor_plan() -> void:
	# Main public saleroom plus two staff-only wings.
	add_block("MainFloor", Vector3(0, -0.22, -0.4), Vector3(19.0, 0.4, 23.0), Color("332722"))
	add_block("CentralRunner", Vector3(0, 0.02, -0.8), Vector3(2.25, 0.08, 15.4), VELVET)
	add_block("MarketFloor", Vector3(11.8, -0.22, 1.35), Vector3(5.6, 0.4, 7.2), Color("21192b"))
	add_block("MendingFloor", Vector3(-11.8, -0.22, 1.35), Vector3(5.6, 0.4, 7.2), INK)
	for z in [-6.4, -2.4, 1.6, 5.6]:
		add_rug_mark(Vector3(0, 0.08, z))

func add_saleroom_shell() -> void:
	add_block("BackWall", Vector3(0, 4.2, -11.55), Vector3(19.0, 8.4, 0.42), PLASTER.darkened(0.28))
	add_block("LeftWall", Vector3(-9.5, 4.2, -3.0), Vector3(0.42, 8.4, 17.1), PLASTER.darkened(0.35))
	add_block("RightWall", Vector3(9.5, 4.2, -5.2), Vector3(0.42, 8.4, 12.7), PLASTER.darkened(0.35))
	add_block("StageWall", Vector3(0, 4.25, -10.95), Vector3(11.0, 7.8, 0.32), Color("233047"))
	for x in [-8.2, -5.6, 5.6, 8.2]:
		add_pillar(Vector3(x, 3.8, -8.9), PLASTER.darkened(0.18))
		add_pillar(Vector3(x, 3.8, 6.9), PLASTER.darkened(0.18))
	add_curtain(Vector3(-4.55, 4.55, -10.55), 2.1)
	add_curtain(Vector3(4.55, 4.55, -10.55), 2.1)
	add_arch(Vector3(9.6, 3.25, 1.4), MARKET.lightened(0.1))
	add_arch(Vector3(-9.6, 3.25, 1.4), Color("442a33"))

func add_noise_composed_details() -> void:
	# A fixed seed makes the architecture reproducible while breaking the toy-like repetition.
	for index in 18:
		var sample: float = decor_noise.get_noise_2d(float(index) * 1.7, 4.0)
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var z: float = -7.4 + float(index / 2) * 1.55
		var x: float = side * (8.72 - abs(sample) * 0.34)
		var height: float = 0.56 + abs(sample) * 0.95
		add_box_mesh(Vector3(0.42, height, 0.58), PLASTER.darkened(0.17 + abs(sample) * 0.12), Vector3(x, height * 0.5, z))
		if index % 3 == 0:
			add_sconce(Vector3(x - side * 0.24, height + 0.34, z))
	for index in 6:
		var sample: float = decor_noise.get_noise_2d(float(index), 18.0)
		var plinth_x: float = -6.9 + float(index) * 2.75
		var plinth_z: float = 6.45 + sample * 0.38
		add_box_mesh(Vector3(0.72, 0.55 + abs(sample) * 0.24, 0.72), WALNUT.lightened(abs(sample) * 0.12), Vector3(plinth_x, 0.34, plinth_z))
		add_thread_spool(Vector3(plinth_x, 0.82, plinth_z), BRASS.lightened(abs(sample) * 0.12))

func add_rostrum_and_lot() -> void:
	# A real saleroom focal point: raised auctioneer, visible lot, and bid boards.
	add_block("Rostrum", Vector3(0, 0.72, -8.65), Vector3(10.6, 1.45, 3.9), VELVET)
	add_block("OakRostrum", Vector3(0, 1.86, -7.85), Vector3(1.9, 1.35, 0.9), WALNUT)
	add_block("LotPlinth", Vector3(0, 1.58, -9.35), Vector3(2.4, 0.72, 1.28), BRASS.darkened(0.35))
	add_lot_object(Vector3(0, 2.38, -9.35))
	add_bid_screen(Vector3(-3.8, 4.25, -10.66), "LOT 101\nLINT 240")
	add_bid_screen(Vector3(3.8, 4.25, -10.66), "NEXT BID\n+20 LINT")
	add_last_hand_relic()

	var auctioneer: Node3D = SockPuppetScript.new()
	auctioneer.position = Vector3(0, 2.42, -7.72)
	auctioneer.scale = Vector3(0.78, 0.78, 0.78)
	add_child(auctioneer)
	auctioneer.call("build", Color("ae3d40"), Color("e4b33d"), "gavel")
	add_sign("AUCTIONEER", Vector3(0, 3.72, -7.22), 0.28, Color("f4dfb6"))

func add_bidder_floor() -> void:
	# Two blocks of numbered bidder tables leave a readable central aisle for free movement.
	var rows := [-4.35, -1.15, 2.05, 5.2]
	for row_index in rows.size():
		for side in [-1.0, 1.0]:
			var x: float = float(side) * 3.25
			var z: float = rows[row_index]
			add_bidder_table(Vector3(x, 0.05, z), int(row_index * 2 + (0 if side < 0 else 1) + 1))
	add_phone_desk(Vector3(7.25, 0.05, -3.7))
	add_catalogue_stand(Vector3(-7.15, 0.05, -3.7))

func add_bidder_table(at: Vector3, number: int) -> void:
	add_box_mesh(Vector3(1.8, 0.1, 1.05), Color("704b35"), at + Vector3(0, 0.82, 0))
	add_box_mesh(Vector3(0.16, 0.78, 0.16), WALNUT, at + Vector3(-0.68, 0.39, -0.3))
	add_box_mesh(Vector3(0.16, 0.78, 0.16), WALNUT, at + Vector3(0.68, 0.39, -0.3))
	add_box_mesh(Vector3(0.16, 0.78, 0.16), WALNUT, at + Vector3(-0.68, 0.39, 0.3))
	add_box_mesh(Vector3(0.16, 0.78, 0.16), WALNUT, at + Vector3(0.68, 0.39, 0.3))
	add_box_mesh(Vector3(1.28, 0.16, 0.92), Color("3c4050"), at + Vector3(0, 0.55, 0.92))
	add_sign("%02d" % number, at + Vector3(0, 1.15, 0.55), 0.3, Color("f5d18b"))

func add_phone_desk(at: Vector3) -> void:
	add_box_mesh(Vector3(1.8, 0.98, 0.85), Color("263047"), at + Vector3(0, 0.49, 0))
	add_sign("PHONE BIDS", at + Vector3(0, 1.2, 0.5), 0.27, Color("bcd6e8"))
	for x in [-0.45, 0.45]:
		add_thread_spool(at + Vector3(x, 1.05, 0.0), Color("9dd6d0"))

func add_catalogue_stand(at: Vector3) -> void:
	add_box_mesh(Vector3(1.8, 0.98, 0.85), Color("47302e"), at + Vector3(0, 0.49, 0))
	add_sign("APPRAISAL", at + Vector3(0, 1.2, 0.5), 0.27, Color("d9b5a2"))
	add_action_cards(at + Vector3(0, 1.05, 0.0))

func add_chandelier_and_lights() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 1.35
	ring.outer_radius = 1.62
	ring.rings = 20
	ring.ring_segments = 10
	var chandelier := add_mesh(ring, BRASS, Vector3(0, 6.35, -1.5), Vector3.ONE)
	chandelier.rotation_degrees.x = 90.0
	for x in [-3.8, 0.0, 3.8]:
		add_spotlight(Vector3(x, 7.1, -5.6), Color("ffd7a1"), Vector3(-62, 0, 0), 14.0)
	for x in [-6.9, 6.9]:
		add_sconce(Vector3(x, 4.0, -7.9))
		add_sconce(Vector3(x, 4.0, 4.5))

func add_black_market() -> void:
	add_block("MarketBack", Vector3(12.0, 3.0, 4.55), Vector3(5.2, 6.0, 0.35), MARKET)
	add_block("MarketCounter", Vector3(12.0, 1.1, 0.2), Vector3(4.2, 1.65, 0.92), Color("2b183a"))
	add_box_mesh(Vector3(4.9, 0.28, 3.9), MARKET, Vector3(12.0, 5.45, 1.4))
	add_action_cards(Vector3(11.2, 2.0, -0.05))
	add_thread_spool(Vector3(12.85, 2.02, -0.05), Color("ffa85e"))
	add_thread_spool(Vector3(13.55, 2.02, -0.05), Color("65c9c6"))
	add_sign("LOOSE END", Vector3(12.0, 4.75, 4.28), 0.72, Color("d9a6ff"))
	add_sign("CARDS · THREAD · FAVOURS", Vector3(12.0, 4.26, 4.25), 0.22, Color("a893bd"))
	for x in [10.15, 13.85]:
		add_crate(Vector3(x, 0.42, 2.85))
		add_crate(Vector3(x, 1.0, 2.85))
	var dealer: Node3D = SockPuppetScript.new()
	dealer.position = Vector3(12.0, 0.05, 1.75)
	dealer.rotation_degrees.y = 180.0
	dealer.scale = Vector3(0.78, 0.78, 0.78)
	add_child(dealer)
	dealer.call("build", Color("252936"), Color("b6b5bd"), "baton", true)

func add_mending_room() -> void:
	add_block("MendingBack", Vector3(-12.0, 3.0, 4.55), Vector3(5.2, 6.0, 0.35), Color("38232c"))
	add_block("MendingTable", Vector3(-12.0, 1.1, 0.2), Vector3(4.2, 1.65, 0.92), Color("3a2a31"))
	add_box_mesh(Vector3(4.9, 0.28, 3.9), Color("2e2028"), Vector3(-12.0, 5.45, 1.4))
	add_sign("MENDING ROOM", Vector3(-12.0, 4.75, 4.28), 0.62, Color("e26363"))
	add_sign("DEBT COLLECTION", Vector3(-12.0, 4.26, 4.25), 0.22, Color("a57a7f"))
	for x in [-13.5, -12.0, -10.5]:
		add_thread_spool(Vector3(x, 2.02, -0.05), Color("c85262"))
	var keeper: Node3D = SockPuppetScript.new()
	keeper.position = Vector3(-12.0, 0.05, 1.75)
	keeper.rotation_degrees.y = 180.0
	keeper.scale = Vector3(0.82, 0.82, 0.82)
	add_child(keeper)
	keeper.call("build", Color("171b23"), Color("292d36"), "baton", true)

func add_weapon_locker() -> void:
	add_box_mesh(Vector3(2.5, 3.5, 0.55), Color("263141"), Vector3(7.55, 1.75, 6.1))
	add_sign("WRIST LOCKER", Vector3(7.55, 3.65, 5.78), 0.36, Color("c5d3e7"))
	add_sign("SEALED WHEN THE BELL RINGS", Vector3(7.55, 3.26, 5.77), 0.18, Color("8792a3"))
	for x in [6.9, 7.55, 8.2]:
		add_weapon_display(Vector3(x, 1.6, 5.74))

func add_skywell() -> void:
	# The Last Hand descends here when a player loses all LINT.
	var rim := TorusMesh.new()
	rim.inner_radius = 1.6
	rim.outer_radius = 1.95
	rim.rings = 20
	rim.ring_segments = 12
	var rim_node := add_mesh(rim, Color("80607a"), Vector3(0, 7.62, 2.25), Vector3.ONE)
	rim_node.rotation_degrees.x = 90.0
	add_sign("SKYWELL / DEBT COLLECTION", Vector3(0, 6.6, 3.7), 0.24, Color("c58b8b"))

func add_last_hand_relic() -> void:
	add_glass_box("LastHandCase", Vector3(0, 4.75, -10.25), Vector3(4.8, 3.0, 0.48), Color(0.62, 0.8, 0.92, 0.18))
	add_box_mesh(Vector3(3.85, 0.28, 0.6), BRASS.darkened(0.35), Vector3(0, 3.32, -10.1))
	add_box_mesh(Vector3(1.12, 1.12, 0.28), Color("d9c4a1"), Vector3(0, 4.42, -10.02))
	for x in [-0.62, -0.3, 0.0, 0.3, 0.62]:
		var finger := CylinderMesh.new()
		finger.top_radius = 0.11
		finger.bottom_radius = 0.14
		finger.height = 1.02 if abs(x) < 0.5 else 0.76
		finger.radial_segments = 10
		var finger_node := add_mesh(finger, Color("d9c4a1"), Vector3(x, 5.36, -10.0), Vector3.ONE)
		finger_node.rotation_degrees.z = x * -8.0

func add_lot_object(at: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.42
	mesh.height = 0.82
	var relic := add_mesh(mesh, Color("9ee1da"), at, Vector3.ONE)
	relic.rotation_degrees = Vector3(10, 26, 0)
	var halo := TorusMesh.new()
	halo.inner_radius = 0.42
	halo.outer_radius = 0.49
	halo.rings = 16
	halo.ring_segments = 10
	var halo_node := add_mesh(halo, BRASS, at + Vector3(0, 0.18, 0), Vector3.ONE)
	halo_node.rotation_degrees.x = 90.0

func add_bid_screen(at: Vector3, text: String) -> void:
	add_box_mesh(Vector3(2.8, 1.62, 0.12), Color("111925"), at)
	add_sign(text, at + Vector3(0, 0, 0.1), 0.36, Color("b8d9dc"))

func add_curtain(at: Vector3, width: float) -> void:
	add_box_mesh(Vector3(width, 4.6, 0.18), VELVET, at)
	add_box_mesh(Vector3(width + 0.18, 0.18, 0.32), BRASS, at + Vector3(0, 2.35, 0))

func add_arch(at: Vector3, color: Color) -> void:
	add_box_mesh(Vector3(0.35, 5.1, 0.65), color, at + Vector3(-1.85, 0, 0))
	add_box_mesh(Vector3(0.35, 5.1, 0.65), color, at + Vector3(1.85, 0, 0))
	add_box_mesh(Vector3(4.05, 0.35, 0.65), color, at + Vector3(0, 2.4, 0))

func add_action_cards(at: Vector3) -> void:
	var colors := [Color("70b8e8"), Color("e1ac5f"), Color("ca6f95"), Color("94c779")]
	for index in colors.size():
		add_box_mesh(Vector3(0.42, 0.05, 0.66), colors[index], at + Vector3((index - 1.5) * 0.42, 0, 0))

func add_thread_spool(at: Vector3, thread_color: Color) -> void:
	var spool := CylinderMesh.new()
	spool.top_radius = 0.2
	spool.bottom_radius = 0.2
	spool.height = 0.36
	spool.radial_segments = 14
	var spool_node := add_mesh(spool, Color("d6bd91"), at, Vector3.ONE)
	spool_node.rotation_degrees.z = 90.0
	var thread := CylinderMesh.new()
	thread.top_radius = 0.145
	thread.bottom_radius = 0.145
	thread.height = 0.42
	thread.radial_segments = 14
	var thread_node := add_mesh(thread, thread_color, at, Vector3.ONE)
	thread_node.rotation_degrees.z = 90.0

func add_weapon_display(at: Vector3) -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.04
	shaft.bottom_radius = 0.06
	shaft.height = 0.9
	shaft.radial_segments = 10
	var weapon := add_mesh(shaft, Color("c5c4c0"), at, Vector3.ONE)
	weapon.rotation_degrees.z = 28.0
	add_box_mesh(Vector3(0.16, 0.28, 0.11), Color("7c5353"), at + Vector3(-0.18, -0.31, 0))

func add_rug_mark(at: Vector3) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.24
	ring.outer_radius = 0.3
	ring.rings = 12
	ring.ring_segments = 8
	var mark := add_mesh(ring, BRASS.darkened(0.15), at, Vector3.ONE)
	mark.rotation_degrees.x = 90.0

func add_pillar(at: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.26
	mesh.bottom_radius = 0.32
	mesh.height = 7.6
	mesh.radial_segments = 16
	add_mesh(mesh, color, at, Vector3.ONE)

func add_sconce(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color("f5c77e")
	light.light_energy = 1.8
	light.omni_range = 5.2
	add_child(light)
	var bulb := SphereMesh.new()
	bulb.radius = 0.12
	bulb.height = 0.24
	add_mesh(bulb, Color("ffdc8c"), at, Vector3.ONE)

func add_spotlight(at: Vector3, color: Color, rotation: Vector3, range: float) -> void:
	var light := SpotLight3D.new()
	light.position = at
	light.rotation_degrees = rotation
	light.light_color = color
	light.light_energy = 5.2
	light.spot_range = range
	light.spot_angle = 32.0
	light.shadow_enabled = true
	add_child(light)

func add_crate(at: Vector3) -> void:
	add_box_mesh(Vector3(0.86, 0.55, 0.8), Color("725138"), at)

func add_sign(text: String, at: Vector3, font_size: float, color: Color) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.position = at
	sign.font_size = int(64 * font_size)
	sign.outline_size = 6
	sign.modulate = color
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.pixel_size = 0.006
	add_child(sign)

func add_block(label: String, at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	body.add_child(mesh_instance(mesh, color))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func add_box_mesh(size: Vector3, color: Color, at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return add_mesh(mesh, color, at, Vector3.ONE)

func add_glass_box(label: String, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.16
	material.metallic = 0.16
	mesh.material = material
	var glass := MeshInstance3D.new()
	glass.name = label
	glass.mesh = mesh
	glass.position = at
	add_child(glass)

func add_mesh(mesh: PrimitiveMesh, color: Color, at: Vector3, scale_factor: Vector3) -> MeshInstance3D:
	var node := mesh_instance(mesh, color)
	node.position = at
	node.scale = scale_factor
	add_child(node)
	return node

func mesh_instance(mesh: PrimitiveMesh, color: Color) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = AuctionSurfaceShader
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("accent_color", color.lightened(0.18))
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return node
