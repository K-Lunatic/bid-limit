extends Node3D

const AuctionHallScript = preload("res://scripts/auction_hall.gd")
const NetworkSessionScript = preload("res://scripts/network_session.gd")
const PlayerControllerScript = preload("res://scripts/player_controller.gd")
const AuctionGameScript = preload("res://scripts/auction_game.gd")
const AuctionUIScript = preload("res://scripts/auction_ui.gd")
const SignalingClientScript = preload("res://scripts/signaling_client.gd")
const LobbyUIScript = preload("res://scripts/lobby_ui.gd")
const TouchControlsScript = preload("res://scripts/touch_controls.gd")

@onready var camera: Camera3D = $Camera3D

var network: Node
var player_nodes: Dictionary = {}
var view_yaw := 0.0
var view_pitch := 0.0
var touch_move := Vector2.ZERO

func _ready() -> void:
	var hall: Node3D = AuctionHallScript.new()
	add_child(hall)
	hall.call("build")
	# The first view frames the rostrum, catalogue floor, and the two side wings.
	camera.look_at(Vector3(0, 2.0, -4.5))
	network = NetworkSessionScript.new()
	add_child(network)
	network.connect("snapshot_received", sync_players)
	network.connect("network_error", func(message: String) -> void: push_warning(message))
	network.connect("attack_resolved", show_attack)
	var signaling: Node = SignalingClientScript.new()
	add_child(signaling)
	network.connect("signal_session", func(peer_id: int, type: String, sdp: String) -> void: signaling.call("send_signal", peer_id, {"type": "session", "sdp_type": type, "sdp": sdp}))
	network.connect("signal_candidate", func(peer_id: int, mid: String, index: int, sdp: String) -> void: signaling.call("send_signal", peer_id, {"type": "candidate", "mid": mid, "index": index, "sdp": sdp}))
	signaling.connect("signal_received", handle_signal)
	var cli_session := configure_network(OS.get_cmdline_user_args())
	var auction_game: Node = AuctionGameScript.new()
	add_child(auction_game)
	var auction_ui: CanvasLayer = AuctionUIScript.new()
	add_child(auction_ui)
	auction_ui.call("setup", auction_game)
	auction_game.connect("defense_card_requested", func(_player_id: int) -> void: network.call("request_defense"))
	auction_ui.connect("defense_requested", func() -> void: network.call("request_defense"))
	auction_ui.connect("attack_requested", func() -> void: network.call("request_attack"))
	if not cli_session:
		var lobby: CanvasLayer = LobbyUIScript.new()
		add_child(lobby)
		lobby.call("setup", signaling, network)
	var touch_controls: CanvasLayer = TouchControlsScript.new()
	add_child(touch_controls)
	touch_controls.connect("move_changed", func(move: Vector2) -> void: touch_move = move)
	touch_controls.connect("look_changed", rotate_view)

func _process(_delta: float) -> void:
	var local_peer_id: int = network.get("local_peer_id")
	if local_peer_id == 0 or not player_nodes.has(local_peer_id):
		return
	var player: Node3D = player_nodes[local_peer_id]
	player.call("set_touch_move", touch_move)
	player.call("set_view_yaw", view_yaw)
	var offset := Vector3(sin(view_yaw) * 7.4, 5.0 + view_pitch * 3.2, cos(view_yaw) * 7.4)
	camera.global_position = player.global_position + offset
	camera.look_at(player.global_position + Vector3(0, 1.35, 0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotate_view(event.relative)

func rotate_view(delta: Vector2) -> void:
	view_yaw -= delta.x * 0.012
	view_pitch = clampf(view_pitch - delta.y * 0.009, -0.72, 0.58)
	if "--capture-map" in OS.get_cmdline_user_args():
		capture_map_preview()

func capture_map_preview() -> void:
	await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("/private/tmp/bid-map-preview.png")
	else:
		push_warning("Headless renderer cannot capture the map preview.")
	get_tree().quit()

func configure_network(args: PackedStringArray) -> bool:
	if "--host" in args:
		network.call("create_host")
		return true
	for arg in args:
		if arg.begins_with("--peer="):
			network.call("join_mesh", int(arg.trim_prefix("--peer=")))
			return true
	return false

func handle_signal(message: Dictionary) -> void:
	var type := str(message.get("type", ""))
	var remote_peer_id := int(message.get("from", message.get("peerId", 0)))
	if type == "peer_join":
		network.call("prepare_peer", remote_peer_id, true)
	elif type == "session":
		network.call("receive_signal_session", remote_peer_id, str(message.get("sdp_type", "")), str(message.get("sdp", "")))
	elif type == "candidate":
		network.call("receive_signal_candidate", remote_peer_id, str(message.get("mid", "")), int(message.get("index", 0)), str(message.get("sdp", "")))

func sync_players(snapshot: Dictionary) -> void:
	for peer_key in snapshot:
		var peer_id := int(peer_key)
		if not player_nodes.has(peer_id):
			spawn_player(peer_id)
		player_nodes[peer_id].call("sync_state", snapshot[peer_key])

func spawn_player(peer_id: int) -> void:
	var player: Node3D = PlayerControllerScript.new()
	var local_peer_id: int = network.get("local_peer_id")
	player.call("setup", peer_id, peer_id == local_peer_id, network)
	add_child(player)
	player_nodes[peer_id] = player

func show_attack(attacker_id: int, target_id: int, _remaining_hp: int) -> void:
	if player_nodes.has(attacker_id):
		player_nodes[attacker_id].call("react_to_hit")
	if player_nodes.has(target_id):
		player_nodes[target_id].call("react_to_hit")
