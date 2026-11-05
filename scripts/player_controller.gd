class_name BidPlayerController
extends CharacterBody3D

const SockPuppetScript = preload("res://scripts/sock_puppet.gd")
const PLAYER_SPEED := 4.4
const ROOM_RADIUS := 8.0

var peer_id := 0
var is_local := false
var network: Node
var target_position := Vector3.ZERO
var target_yaw := 0.0
var touch_move := Vector2.ZERO
var view_yaw := 0.0
var health_label: Label3D

func setup(id: int, local: bool, session: Node) -> void:
	peer_id = id
	is_local = local
	network = session
	name = "Player_%s" % id
	build_body()

func build_body() -> void:
	var colors := [Color("e15a59"), Color("3b92d0"), Color("d9a841"), Color("7b5ab8")]
	var hairs := [Color("2f7fb7"), Color("5a3929"), Color("dce0e8"), Color("1f2b42")]
	var puppet: Node3D = SockPuppetScript.new()
	puppet.scale = Vector3(0.84, 0.84, 0.84)
	add_child(puppet)
	puppet.call("build", colors[peer_id % colors.size()], hairs[peer_id % hairs.size()])
	health_label = Label3D.new()
	health_label.position = Vector3(0, 3.4, 0)
	health_label.pixel_size = 0.008
	health_label.font_size = 42
	health_label.modulate = Color("ffb0a9")
	add_child(health_label)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.62
	shape.height = 2.25
	collision.shape = shape
	collision.position.y = 1.05
	add_child(collision)

func set_touch_move(move: Vector2) -> void:
	touch_move = move.limit_length(1.0)

func set_view_yaw(yaw: float) -> void:
	view_yaw = yaw

func sync_state(state: Dictionary) -> void:
	var packed_position: Array = state.get("p", [])
	if packed_position.size() != 3:
		return
	target_position = Vector3(packed_position[0], packed_position[1], packed_position[2])
	target_yaw = state.get("y", 0.0)
	health_label.text = "♥ %d%s" % [int(state.get("hp", 3)), "  ◇" if state.get("shield", false) else ""]

func react_to_hit() -> void:
	var puppet := get_child(0)
	puppet.call("play_react")

func _physics_process(delta: float) -> void:
	if is_local:
		if Input.is_physical_key_pressed(KEY_F):
			network.call("request_attack")
		if Input.is_physical_key_pressed(KEY_G):
			network.call("request_defense")
		var move := read_keyboard_move()
		if touch_move.length_squared() > 0.001:
			move = touch_move
		network.call("set_local_input", move, rotation.y)
		# Client prediction keeps movement responsive while the server confirms the authoritative snapshot.
		var prediction := Vector3(move.x, 0, move.y) * PLAYER_SPEED * delta
		global_position += prediction
		global_position.x = clampf(global_position.x, -ROOM_RADIUS, ROOM_RADIUS)
		global_position.z = clampf(global_position.z, -ROOM_RADIUS + 0.5, ROOM_RADIUS)
		if move.length_squared() > 0.001:
			rotation.y = lerp_angle(rotation.y, atan2(move.x, move.y), min(delta * 14.0, 1.0))
		return

	global_position = global_position.lerp(target_position, min(delta * 12.0, 1.0))
	rotation.y = lerp_angle(rotation.y, target_yaw, min(delta * 12.0, 1.0))

func read_keyboard_move() -> Vector2:
	var move := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	return move.limit_length(1.0).rotated(-view_yaw)
