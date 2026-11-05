class_name SockPuppet
extends Node3D

const BidWeaponScript = preload("res://scripts/weapon.gd")
const FabricShader = preload("res://shaders/fabric_sock.gdshader")

var cloth: Node3D
var head: Node3D
var jaw: Node3D
var weapon_orbit: Node3D
var idle_time := 0.0

func build(sock_color: Color, hair_color: Color, weapon_kind: String = "baton", suit := false) -> void:
	# The whole character is one floating sock. There are no arms or legs.
	cloth = Node3D.new()
	cloth.name = "FloatingSockCloth"
	add_child(cloth)
	add_wrinkled_sock(sock_color)
	add_folded_mouth(sock_color)
	add_button_eyes()
	add_yarn_hair(hair_color)
	if suit:
		add_tailored_wrap()
	add_floating_weapon(weapon_kind, sock_color)

func _process(delta: float) -> void:
	idle_time += delta
	cloth.position.y = 0.16 + sin(idle_time * 1.65) * 0.10
	cloth.rotation_degrees.z = sin(idle_time * 1.05) * 3.4
	cloth.rotation_degrees.y = sin(idle_time * 0.72) * 7.0
	head.rotation_degrees.z = sin(idle_time * 2.1) * 2.6
	jaw.rotation_degrees.x = -7.0 - max(0.0, sin(idle_time * 2.75)) * 12.0
	weapon_orbit.rotation_degrees.y = idle_time * 30.0

func play_react() -> void:
	jaw.rotation_degrees.x = -40.0
	weapon_orbit.rotation_degrees.z = -24.0

func add_wrinkled_sock(sock_color: Color) -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.78
	body.height = 2.7
	body.radial_segments = 20
	body.rings = 12
	var body_node := add_mesh(body, sock_color, cloth, Vector3(0, 1.38, 0), Vector3(1.0, 1.0, 0.86))
	body_node.name = "OnePieceSock"

	# Thick ribbing at the wrist and uneven soft wrinkles along the body.
	for index in 7:
		var fold := TorusMesh.new()
		fold.inner_radius = 0.67 + (index % 2) * 0.025
		fold.outer_radius = 0.75 + (index % 2) * 0.025
		fold.rings = 16
		fold.ring_segments = 8
		var y := 0.34 + index * 0.25
		var fold_node := add_mesh(fold, sock_color.darkened(0.1 + (index % 2) * 0.035), cloth, Vector3(sin(index * 1.7) * 0.03, y, 0), Vector3(1.0, 0.68, 0.86))
		fold_node.rotation_degrees.x = 90.0
	for y in [0.14, 0.3, 0.47]:
		var cuff := TorusMesh.new()
		cuff.inner_radius = 0.71
		cuff.outer_radius = 0.82
		cuff.rings = 18
		cuff.ring_segments = 8
		var cuff_node := add_mesh(cuff, sock_color.lightened(0.15), cloth, Vector3(0, y, 0), Vector3(1.0, 0.8, 0.88))
		cuff_node.rotation_degrees.x = 90.0

func add_folded_mouth(sock_color: Color) -> void:
	head = Node3D.new()
	head.name = "FingerSupportedHead"
	head.position = Vector3(0, 2.48, 0.08)
	cloth.add_child(head)

	var upper := SphereMesh.new()
	upper.radius = 0.84
	upper.height = 0.7
	upper.radial_segments = 20
	upper.rings = 10
	add_mesh(upper, sock_color, head, Vector3(0, 0.12, 0.12), Vector3(1.12, 0.72, 0.9))

	var cavity := SphereMesh.new()
	cavity.radius = 0.48
	cavity.height = 0.2
	add_mesh(cavity, Color("28171c"), head, Vector3(0, -0.14, 0.77), Vector3(1.4, 0.46, 1.0))

	jaw = Node3D.new()
	jaw.name = "ThumbDrivenJaw"
	jaw.position = Vector3(0, -0.12, 0.1)
	head.add_child(jaw)
	var lower := SphereMesh.new()
	lower.radius = 0.74
	lower.height = 0.4
	lower.radial_segments = 20
	lower.rings = 10
	add_mesh(lower, sock_color.darkened(0.08), jaw, Vector3(0, -0.16, 0.44), Vector3(1.12, 0.58, 0.82))

	# The hand inside the sock is visible as fingertips above the mouth and a thumb in the lower fold.
	var hand_color := Color("d9a98c")
	for x in [-0.32, -0.11, 0.11, 0.32]:
		var finger := CapsuleMesh.new()
		finger.radius = 0.07
		finger.height = 0.35
		finger.radial_segments = 10
		add_mesh(finger, hand_color, head, Vector3(x, -0.035, 0.82), Vector3.ONE)
	var thumb := CapsuleMesh.new()
	thumb.radius = 0.1
	thumb.height = 0.48
	thumb.radial_segments = 10
	var thumb_node := add_mesh(thumb, hand_color, jaw, Vector3(0.3, -0.12, 0.72), Vector3.ONE)
	thumb_node.rotation_degrees.z = -32.0

func add_button_eyes() -> void:
	for x in [-0.34, 0.34]:
		var eye := SphereMesh.new()
		eye.radius = 0.2
		eye.height = 0.12
		var eye_node := add_mesh(eye, Color("f3eee2"), head, Vector3(x, 0.33, 0.72), Vector3.ONE)
		var pupil := SphereMesh.new()
		pupil.radius = 0.065
		pupil.height = 0.06
		add_mesh(pupil, Color("27334b"), eye_node, Vector3(0, 0, 0.11), Vector3.ONE)

func add_yarn_hair(hair_color: Color) -> void:
	for x in [-0.56, -0.34, -0.12, 0.12, 0.34, 0.56]:
		var yarn := CylinderMesh.new()
		yarn.top_radius = 0.04
		yarn.bottom_radius = 0.055
		yarn.height = 0.66
		yarn.radial_segments = 8
		var strand := add_mesh(yarn, hair_color, head, Vector3(x, 0.83 - abs(x) * 0.28, 0.06), Vector3.ONE)
		strand.rotation_degrees.z = x * -28.0

func add_tailored_wrap() -> void:
	# A suit is stitched around the sock, not a rigid jacket or separate limbs.
	for y in [1.08, 1.38, 1.68]:
		var band := TorusMesh.new()
		band.inner_radius = 0.7
		band.outer_radius = 0.8
		band.rings = 16
		band.ring_segments = 8
		var band_node := add_mesh(band, Color("171b24"), cloth, Vector3(0, y, 0), Vector3(1.0, 0.85, 0.88))
		band_node.rotation_degrees.x = 90.0
	var tie := BoxMesh.new()
	tie.size = Vector3(0.14, 0.48, 0.04)
	add_mesh(tie, Color("d9d2c6"), cloth, Vector3(0, 1.56, 0.76), Vector3.ONE)

func add_floating_weapon(weapon_kind: String, sock_color: Color) -> void:
	weapon_orbit = Node3D.new()
	weapon_orbit.name = "FloatingWeaponOrbit"
	weapon_orbit.position = Vector3(0, 1.45, 0)
	cloth.add_child(weapon_orbit)
	var weapon: Node3D = BidWeaponScript.new()
	weapon.position = Vector3(1.18, 0.25, 0.18)
	weapon_orbit.add_child(weapon)
	weapon.call("build", weapon_kind)
	# A loose yarn tether makes the floating weapon feel stitched to the puppet.
	var tether := CylinderMesh.new()
	tether.top_radius = 0.025
	tether.bottom_radius = 0.025
	tether.height = 1.18
	tether.radial_segments = 8
	var tether_node := add_mesh(tether, sock_color.lightened(0.18), weapon_orbit, Vector3(0.58, 0.14, 0.08), Vector3.ONE)
	tether_node.rotation_degrees.z = 78.0

func add_mesh(mesh: PrimitiveMesh, color: Color, parent: Node3D, at: Vector3, scale_factor: Vector3) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = FabricShader
	material.set_shader_parameter("dye", color)
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.scale = scale_factor
	parent.add_child(instance)
	return instance
