class_name BidWeapon
extends Node3D

var bob_phase := 0.0

func build(kind: String = "baton") -> void:
	var handle := CylinderMesh.new()
	handle.top_radius = 0.055
	handle.bottom_radius = 0.065
	handle.height = 0.72
	handle.radial_segments = 12
	add_mesh(handle, Color("2a2428"), Vector3(0, 0.34, 0), Vector3.ONE)

	var head := CylinderMesh.new()
	head.top_radius = 0.13 if kind == "gavel" else 0.08
	head.bottom_radius = 0.13 if kind == "gavel" else 0.08
	head.height = 0.32 if kind == "gavel" else 0.52
	head.radial_segments = 12
	var head_node := add_mesh(head, Color("c99a5f") if kind == "gavel" else Color("d7d5cc"), Vector3(0, 0.72, 0), Vector3.ONE)
	head_node.rotation_degrees.z = 90.0 if kind == "gavel" else 0.0

func set_attack_pose(active: bool) -> void:
	rotation_degrees.x = -58.0 if active else 0.0

func _process(delta: float) -> void:
	bob_phase += delta
	position.y = sin(bob_phase * 2.0) * 0.025

func add_mesh(mesh: PrimitiveMesh, color: Color, at: Vector3, scale_factor: Vector3) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.12
	material.roughness = 0.64
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.scale = scale_factor
	add_child(instance)
	return instance
