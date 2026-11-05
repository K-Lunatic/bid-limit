class_name BidNetworkSession
extends Node

signal snapshot_received(snapshot: Dictionary)
signal latency_updated(milliseconds: int)
signal network_error(message: String)
signal signal_session(remote_peer_id: int, type: String, sdp: String)
signal signal_candidate(remote_peer_id: int, mid: String, index: int, sdp: String)
signal attack_resolved(attacker_id: int, target_id: int, remaining_hp: int)

const SNAPSHOT_HZ := 20.0
const INPUT_HZ := 30.0
const PLAYER_SPEED := 4.4
const ROOM_RADIUS := 8.0
const MAX_PLAYERS := 4
const BOT_ID_BASE := 100

var local_peer_id := 0
var host_peer_id := 1
var players: Dictionary = {}
var connections: Dictionary = {}
var mesh_peer: WebRTCMultiplayerPeer
var latest_snapshot: Dictionary = {}
var local_move := Vector2.ZERO
var local_yaw := 0.0
var input_timer := 0.0
var snapshot_timer := 0.0
var ping_timer := 0.0
var input_sequence := 0
var ping_nonce := 0
var ping_started_at: Dictionary = {}
var attack_cooldowns: Dictionary = {}

func is_host() -> bool:
	return local_peer_id == host_peer_id

func create_host() -> Error:
	return create_mesh(1)

func join_mesh(peer_id: int) -> Error:
	if peer_id < 2:
		return ERR_INVALID_PARAMETER
	return create_mesh(peer_id)

func create_mesh(peer_id: int) -> Error:
	mesh_peer = WebRTCMultiplayerPeer.new()
	var result := mesh_peer.create_mesh(peer_id)
	if result != OK:
		network_error.emit("P2P 메시를 만들지 못했습니다: %s" % result)
		return result
	local_peer_id = peer_id
	host_peer_id = 1
	set_multiplayer_authority(host_peer_id)
	get_tree().get_multiplayer().multiplayer_peer = mesh_peer
	get_tree().get_multiplayer().peer_disconnected.connect(handle_peer_disconnect)
	if is_host():
		players[local_peer_id] = initial_player_state(0)
		fill_empty_seats_with_bots()
		emit_snapshot()
	return OK

func fill_empty_seats_with_bots() -> void:
	var bot_index := 0
	while players.size() < MAX_PLAYERS:
		var bot_id := BOT_ID_BASE + bot_index
		bot_index += 1
		if players.has(bot_id):
			continue
		var bot_state := initial_player_state(players.size())
		bot_state["bot"] = true
		bot_state["phase"] = float(bot_index) * 1.9
		players[bot_id] = bot_state

func emit_snapshot() -> void:
	latest_snapshot = serialize_snapshot()
	snapshot_received.emit(latest_snapshot)

# The signaling service forwards only these SDP/ICE messages. It never receives game state.
func prepare_peer(remote_peer_id: int, initiator: bool) -> Error:
	if connections.has(remote_peer_id):
		return OK
	var connection := WebRTCPeerConnection.new()
	var result := connection.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]})
	if result != OK:
		network_error.emit("WebRTC 연결을 초기화하지 못했습니다: %s" % result)
		return result
	connection.session_description_created.connect(on_session_description.bind(remote_peer_id))
	connection.ice_candidate_created.connect(on_ice_candidate.bind(remote_peer_id))
	result = mesh_peer.add_peer(connection, remote_peer_id)
	if result != OK:
		return result
	connections[remote_peer_id] = connection
	if initiator:
		connection.create_offer()
	return OK

func receive_signal_session(remote_peer_id: int, type: String, sdp: String) -> void:
	if not connections.has(remote_peer_id):
		prepare_peer(remote_peer_id, false)
	var connection: WebRTCPeerConnection = connections.get(remote_peer_id)
	if connection == null:
		return
	connection.set_remote_description(type, sdp)

func receive_signal_candidate(remote_peer_id: int, mid: String, index: int, sdp: String) -> void:
	var connection: WebRTCPeerConnection = connections.get(remote_peer_id)
	if connection != null:
		connection.add_ice_candidate(mid, index, sdp)

func set_local_input(move: Vector2, yaw: float) -> void:
	local_move = move.limit_length(1.0)
	local_yaw = yaw

func request_attack() -> void:
	if local_peer_id == 0:
		return
	if is_host():
		resolve_attack(local_peer_id)
	else:
		rpc_id(host_peer_id, "submit_attack")

func request_defense() -> void:
	if local_peer_id == 0:
		return
	if is_host():
		apply_defense(local_peer_id)
	else:
		rpc_id(host_peer_id, "submit_defense")

func _physics_process(delta: float) -> void:
	for remote_peer_id in connections:
		var connection: WebRTCPeerConnection = connections[remote_peer_id]
		connection.poll()
	if local_peer_id == 0:
		return
	if is_host():
		host_step(delta)
		snapshot_timer += delta
		if snapshot_timer >= 1.0 / SNAPSHOT_HZ:
			snapshot_timer = 0.0
			latest_snapshot = serialize_snapshot()
			rpc("receive_snapshot", latest_snapshot)
		return
	input_timer += delta
	if input_timer >= 1.0 / INPUT_HZ:
		input_timer = 0.0
		input_sequence += 1
		rpc_id(host_peer_id, "submit_input", local_move, local_yaw, input_sequence)
	ping_timer += delta
	if ping_timer >= 1.0:
		ping_timer = 0.0
		ping_nonce += 1
		ping_started_at[ping_nonce] = Time.get_ticks_msec()
		rpc_id(host_peer_id, "ping", ping_nonce)

func host_step(delta: float) -> void:
	update_bots()
	var host_state: Dictionary = players.get(local_peer_id, initial_player_state(players.size()))
	host_state["move"] = local_move
	host_state["yaw"] = local_yaw
	players[local_peer_id] = host_state
	for peer_id in players:
		var state: Dictionary = players[peer_id]
		attack_cooldowns[peer_id] = maxf(0.0, attack_cooldowns.get(peer_id, 0.0) - delta)
		state["stun"] = maxf(0.0, state.get("stun", 0.0) - delta)
		var direction := Vector3(state.get("move", Vector2.ZERO).x, 0, state.get("move", Vector2.ZERO).y)
		if state["stun"] > 0.0:
			direction = Vector3.ZERO
		if direction.length_squared() > 1.0:
			direction = direction.normalized()
		var position: Vector3 = state.get("position", Vector3.ZERO)
		position += direction * PLAYER_SPEED * delta
		position.x = clampf(position.x, -ROOM_RADIUS, ROOM_RADIUS)
		position.z = clampf(position.z, -ROOM_RADIUS + 0.5, ROOM_RADIUS)
		state["position"] = position
		players[peer_id] = state

func update_bots() -> void:
	var now := Time.get_ticks_msec() * 0.001
	for peer_id in players:
		var state: Dictionary = players[peer_id]
		if not state.get("bot", false):
			continue
		var phase: float = state.get("phase", 0.0)
		var move := Vector2(sin(now * 0.72 + phase), cos(now * 0.56 + phase * 1.7))
		state["move"] = move.normalized() * 0.32
		state["yaw"] = atan2(move.x, move.y)
		players[peer_id] = state

func serialize_snapshot() -> Dictionary:
	var snapshot := {}
	for peer_id in players:
		var state: Dictionary = players[peer_id]
		var position: Vector3 = state["position"]
		snapshot[str(peer_id)] = {"p": [position.x, position.y, position.z], "y": state["yaw"], "bot": state.get("bot", false), "hp": state.get("hp", 3), "stun": state.get("stun", 0.0), "shield": state.get("shield", false)}
	return snapshot

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(move: Vector2, yaw: float, _sequence: int) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender):
		if human_player_count() >= MAX_PLAYERS:
			return
		remove_one_bot()
		players[sender] = initial_player_state(players.size())
	var state: Dictionary = players[sender]
	state["move"] = move.limit_length(1.0)
	state["yaw"] = yaw
	players[sender] = state

@rpc("any_peer", "call_remote", "reliable")
func submit_attack() -> void:
	if is_host():
		resolve_attack(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func submit_defense() -> void:
	if is_host():
		apply_defense(multiplayer.get_remote_sender_id())

func apply_defense(player_id: int) -> void:
	if not players.has(player_id):
		return
	var state: Dictionary = players[player_id]
	state["shield"] = true
	players[player_id] = state

func resolve_attack(attacker_id: int) -> void:
	if not players.has(attacker_id) or attack_cooldowns.get(attacker_id, 0.0) > 0.0:
		return
	var attacker: Dictionary = players[attacker_id]
	var attacker_position: Vector3 = attacker.get("position", Vector3.ZERO)
	var target_id := -1
	var closest_distance := 2.35
	for candidate_id in players:
		if candidate_id == attacker_id:
			continue
		var candidate_position: Vector3 = players[candidate_id].get("position", Vector3.ZERO)
		var distance := attacker_position.distance_to(candidate_position)
		if distance < closest_distance:
			closest_distance = distance
			target_id = candidate_id
	attack_cooldowns[attacker_id] = 0.8
	if target_id == -1:
		return
	var target: Dictionary = players[target_id]
	if target.get("shield", false):
		target["shield"] = false
		players[target_id] = target
		attack_resolved.emit(attacker_id, target_id, target["hp"])
		rpc("receive_attack", attacker_id, target_id, target["hp"])
		return
	target["hp"] = max(0, int(target.get("hp", 3)) - 1)
	target["stun"] = 0.55
	players[target_id] = target
	attack_resolved.emit(attacker_id, target_id, target["hp"])
	rpc("receive_attack", attacker_id, target_id, target["hp"])

@rpc("authority", "call_remote", "reliable")
func receive_attack(attacker_id: int, target_id: int, remaining_hp: int) -> void:
	attack_resolved.emit(attacker_id, target_id, remaining_hp)

func human_player_count() -> int:
	var count := 0
	for peer_id in players:
		if not players[peer_id].get("bot", false):
			count += 1
	return count

func remove_one_bot() -> void:
	for peer_id in players:
		if players[peer_id].get("bot", false):
			players.erase(peer_id)
			return

@rpc("authority", "call_remote", "unreliable_ordered", 1)
func receive_snapshot(snapshot: Dictionary) -> void:
	latest_snapshot = snapshot
	snapshot_received.emit(snapshot)

@rpc("any_peer", "call_remote", "reliable")
func ping(nonce: int) -> void:
	if is_host():
		rpc_id(multiplayer.get_remote_sender_id(), "pong", nonce)

@rpc("authority", "call_remote", "reliable")
func pong(nonce: int) -> void:
	var started_at: int = ping_started_at.get(nonce, 0)
	if started_at > 0:
		ping_started_at.erase(nonce)
		latency_updated.emit(Time.get_ticks_msec() - started_at)

func handle_peer_disconnect(peer_id: int) -> void:
	players.erase(peer_id)
	connections.erase(peer_id)
	if peer_id == host_peer_id:
		elect_new_host()

func elect_new_host() -> void:
	var candidates := [local_peer_id]
	for peer_id in connections:
		candidates.append(peer_id)
	candidates.sort()
	host_peer_id = candidates[0]
	set_multiplayer_authority(host_peer_id)
	if is_host():
		players = unpack_snapshot(latest_snapshot)
		if not players.has(local_peer_id):
			players[local_peer_id] = initial_player_state(players.size())
		fill_empty_seats_with_bots()

func unpack_snapshot(snapshot: Dictionary) -> Dictionary:
	var restored := {}
	for peer_key in snapshot:
		var packed: Dictionary = snapshot[peer_key]
		var position: Array = packed.get("p", [])
		if position.size() == 3:
			restored[int(peer_key)] = {"position": Vector3(position[0], position[1], position[2]), "move": Vector2.ZERO, "yaw": packed.get("y", 0.0), "bot": packed.get("bot", false), "hp": packed.get("hp", 3), "stun": packed.get("stun", 0.0), "shield": packed.get("shield", false)}
	return restored

func initial_player_state(index: int) -> Dictionary:
	var spawns := [Vector3(-3.4, 0, 3.2), Vector3(0, 0, 3.8), Vector3(3.4, 0, 3.2), Vector3(-5.5, 0, 1.6)]
	return {"position": spawns[index % spawns.size()], "move": Vector2.ZERO, "yaw": 0.0, "hp": 3, "stun": 0.0, "shield": false}

func on_session_description(type: String, sdp: String, remote_peer_id: int) -> void:
	var connection: WebRTCPeerConnection = connections.get(remote_peer_id)
	if connection == null or connection.set_local_description(type, sdp) != OK:
		network_error.emit("로컬 연결 정보를 적용하지 못했습니다.")
		return
	signal_session.emit(remote_peer_id, type, sdp)

func on_ice_candidate(mid: String, index: int, sdp: String, remote_peer_id: int) -> void:
	signal_candidate.emit(remote_peer_id, mid, index, sdp)
