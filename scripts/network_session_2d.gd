class_name BidNetworkSession2D
extends Node

const ArtLayout = preload("res://scripts/art_layout.gd")
const Identity = preload("res://scripts/bidder_identity.gd")

signal snapshot_received(snapshot: Dictionary)
signal network_error(message: String)
signal signal_session(remote_peer_id: int, type: String, sdp: String)
signal signal_candidate(remote_peer_id: int, mid: String, index: int, sdp: String)
signal attack_resolved(attacker_id: int, target_id: int, remaining_hp: int)
signal auction_action_requested(action: String, sender_id: int)
signal auction_state_received(state: Dictionary)
signal table_status_changed(ready: bool, count: int, total: int)
signal host_disconnected
signal kicked
signal room_started
signal chat_received(sender_id: int, message: String)
signal card_jam_requested(target_id: int)
signal integrity_alert(player_id: int, reason: String)

const SNAPSHOT_HZ := 20.0
const INPUT_HZ := 30.0
const MAX_PLAYERS := 4
const MAX_AUCTION_ACTION_LENGTH := 64
const SPEED := 330.0
const SEAT_POSITIONS := ArtLayout.SEAT_POSITIONS
var seat_positions: Array = SEAT_POSITIONS.duplicate()
var local_peer_id := 0
var host_peer_id := 1
var players: Dictionary = {}
var connections: Dictionary = {}
var pending_candidates: Dictionary = {}
var remote_descriptions: Dictionary = {}
var mesh_peer: WebRTCMultiplayerPeer
var move := Vector2.ZERO
var input_timer := 0.0
var snapshot_timer := 0.0
var attack_cooldowns: Dictionary = {}
var chat_last_sent: Dictionary = {}
var local_profile := {"sock": "e15a67", "hair": "35a7d7", "hair_style": 0, "accessory": 0, "nickname": "양말", "weapon": 0}
var table_ready := false
var last_table_count := -1
var last_table_total := -1
var auction_active := false
var room_has_started := false
var host_lost := false
var heard_host := false
var host_silence := 0.0
const HOST_SILENCE_LIMIT := 8.0
var start_requested := false
var start_fill_empty_seats := false
var start_wait_notified := false
var suspicious_players: Dictionary = {}
var local_suspicious_players: Dictionary = {}
var integrity_reports: Dictionary = {}
var kick_votes: Dictionary = {}

func create_host() -> Error:
	return create_mesh(1)

func join_mesh(peer_id: int) -> Error:
	var result := create_mesh(peer_id)
	if result == OK and peer_id != host_peer_id:
		result = prepare_peer(host_peer_id, false)
	return result

func create_mesh(peer_id: int) -> Error:
	mesh_peer = WebRTCMultiplayerPeer.new()
	var result := mesh_peer.create_mesh(peer_id)
	if result != OK:
		network_error.emit("2D P2P 메시를 만들지 못했습니다.")
		return result
	local_peer_id = peer_id
	room_has_started = false
	host_lost = false
	heard_host = false
	host_silence = 0.0
	players.clear()
	suspicious_players.clear()
	local_suspicious_players.clear()
	integrity_reports.clear()
	kick_votes.clear()
	get_tree().get_multiplayer().multiplayer_peer = mesh_peer
	get_tree().get_multiplayer().peer_disconnected.connect(handle_disconnect)
	if is_host():
		players[1] = initial_state(Vector2(1110, 520))
		emit_snapshot()
	return OK

func set_local_profile(profile: Dictionary) -> void:
	local_profile = clean_profile(profile)
	if players.has(local_peer_id):
		players[local_peer_id]["profile"] = local_profile.duplicate()

func clean_profile(profile: Dictionary) -> Dictionary:
	var nickname := str(profile.get("nickname", "양말")).strip_edges().replace("\n", " ").replace("\r", " ").left(12)
	if nickname.is_empty():
		nickname = "양말"
	var sock := str(profile.get("sock", "e15a67"))
	var hair := str(profile.get("hair", "35a7d7"))
	if sock.length() != 6 or not sock.is_valid_hex_number(false): sock = "e15a67"
	if hair.length() != 6 or not hair.is_valid_hex_number(false): hair = "35a7d7"
	return {
		"sock": sock,
		"hair": hair,
		"hair_style": clampi(int(profile.get("hair_style", 0)), 0, 2),
		"accessory": clampi(int(profile.get("accessory", 0)), 0, 3),
		"nickname": nickname,
		"weapon": clampi(int(profile.get("weapon", 0)), 0, 2),
	}

func is_host() -> bool:
	return local_peer_id == host_peer_id

func fill_bots() -> void:
	for index in 3:
		if players.size() >= MAX_PLAYERS:
			break
		var id := 100 + index
		if players.has(id):
			continue
		var free_seat := -1
		for seat in [1, 2, 3, 0]:
			if not players.values().any(func(member: Dictionary) -> bool: return int(member.get("seat", -1)) == seat):
				free_seat = seat
				break
		if free_seat < 0:
			break
		var state := initial_state(seat_positions[free_seat])
		state["bot"] = true
		state["seat"] = free_seat
		state["ready"] = true
		state["profile"] = [
			{"sock": "e15a67", "hair": "e4ad5d", "hair_style": 0, "accessory": 1},
			{"sock": "9a6ac0", "hair": "35a7d7", "hair_style": 1, "accessory": 2},
			{"sock": "5f9ed1", "hair": "e4ad5d", "hair_style": 2, "accessory": 3},
		][index]
		state["profile"]["nickname"] = Identity.bot_name(id)
		state["phase"] = float(index) * 1.8
		players[id] = state
	emit_snapshot()

func add_bots() -> void:
	if is_host():
		fill_bots()

func start_room(fill_empty_seats := false) -> bool:
	if not is_host() or room_has_started:
		return false
	start_requested = true
	start_fill_empty_seats = fill_empty_seats
	start_wait_notified = false
	_try_start_room()
	return true

func _try_start_room() -> void:
	if not is_host() or not start_requested or room_has_started:
		return
	for id in players:
		if int(id) != local_peer_id and not bool(players[id].get("bot", false)) and not multiplayer.get_peers().has(int(id)):
			if not start_wait_notified:
				start_wait_notified = true
				network_error.emit("참가자를 연결하는 중입니다. 연결되면 자동으로 시작합니다.")
			return
	start_requested = false
	start_wait_notified = false
	if start_fill_empty_seats:
		fill_bots()
	room_has_started = true
	room_started.emit()
	rpc("receive_room_started")

@rpc("authority", "call_remote", "reliable")
func receive_room_started() -> void:
	if room_has_started or host_lost:
		return
	room_has_started = true
	room_started.emit()

func _remove_one_bot() -> void:
	for id in [102, 101, 100]:
		if players.has(id):
			players.erase(id)
			return

func prepare_peer(remote_id: int, initiator: bool) -> Error:
	if remote_id <= 0 or remote_id == local_peer_id:
		return ERR_INVALID_PARAMETER
	if connections.has(remote_id):
		return OK
	if is_host() and not players.has(remote_id) and players.size() >= MAX_PLAYERS:
		if not players.values().any(func(member: Dictionary) -> bool: return bool(member.get("bot", false))):
			return ERR_OUT_OF_MEMORY
	var connection := WebRTCPeerConnection.new()
	var result := connection.initialize({"iceServers": _ice_servers()})
	if result != OK:
		return result
	connection.session_description_created.connect(on_session_description.bind(remote_id))
	connection.ice_candidate_created.connect(on_ice_candidate.bind(remote_id))
	result = mesh_peer.add_peer(connection, remote_id)
	if result != OK:
		return result
	connections[remote_id] = connection
	if is_host() and remote_id > 1:
		_remove_one_bot()
		players[remote_id] = initial_state(Vector2(1210 + (remote_id - 1) * 90, 520))
		emit_snapshot()
	if initiator:
		connection.create_offer()
	return OK

func _ice_servers() -> Array[Dictionary]:
	var servers: Array[Dictionary] = [{"urls": ["stun:stun.l.google.com:19302"]}]
	var turn_url := str(ProjectSettings.get_setting("bid_network/turn_url", ""))
	if not turn_url.is_empty():
		servers.append({
			"urls": [turn_url],
			"username": str(ProjectSettings.get_setting("bid_network/turn_username", "")),
			"credential": str(ProjectSettings.get_setting("bid_network/turn_credential", "")),
		})
	return servers

func receive_signal_session(remote_id: int, type: String, sdp: String) -> void:
	if not connections.has(remote_id):
		prepare_peer(remote_id, false)
	var connection: WebRTCPeerConnection = connections.get(remote_id)
	if connection == null:
		return
	if connection.set_remote_description(type, sdp) != OK:
		network_error.emit("상대 연결 정보를 적용하지 못했습니다.")
		return
	remote_descriptions[remote_id] = true
	for candidate in pending_candidates.get(remote_id, []):
		connection.add_ice_candidate(candidate[0], candidate[1], candidate[2])
	pending_candidates.erase(remote_id)

func receive_signal_candidate(remote_id: int, mid: String, index: int, sdp: String) -> void:
	var connection: WebRTCPeerConnection = connections.get(remote_id)
	if connection != null and remote_descriptions.has(remote_id):
		connection.add_ice_candidate(mid, index, sdp)
	else:
		var pending: Array = pending_candidates.get(remote_id, [])
		if pending.size() < 64:
			pending.append([mid, index, sdp])
			pending_candidates[remote_id] = pending

func set_local_input(value: Vector2) -> void:
	move = value.limit_length(1.0)
	if is_host() and players.has(local_peer_id):
		players[local_peer_id]["move"] = move

func request_attack() -> void:
	if local_peer_id == 0:
		return
	if is_host():
		resolve_attack(local_peer_id)
	elif multiplayer.get_peers().has(host_peer_id):
		rpc_id(host_peer_id, "submit_attack")

func send_chat(message: String) -> void:
	if local_peer_id == 0:
		return
	if is_host():
		_relay_chat(local_peer_id, message)
	elif multiplayer.get_peers().has(host_peer_id):
		rpc_id(host_peer_id, "submit_chat", message.left(40))

@rpc("any_peer", "call_remote", "reliable")
func submit_chat(message: String) -> void:
	if is_host():
		_relay_chat(multiplayer.get_remote_sender_id(), message)

func _relay_chat(sender_id: int, message: String) -> void:
	var clean := message.strip_edges().replace("\n", " ").replace("\r", " ").left(40)
	var now := Time.get_ticks_msec()
	if not players.has(sender_id) or clean.is_empty() or now - int(chat_last_sent.get(sender_id, -1000)) < 600:
		return
	chat_last_sent[sender_id] = now
	chat_received.emit(sender_id, clean)
	rpc("receive_chat", sender_id, clean)

@rpc("authority", "call_remote", "reliable")
func receive_chat(sender_id: int, message: String) -> void:
	chat_received.emit(sender_id, message.left(40))

func report_suspicious(target_id: int, reason: String) -> void:
	if target_id <= 0 or target_id == local_peer_id or not players.has(target_id):
		return
	local_suspicious_players[target_id] = reason.left(40)
	integrity_alert.emit(target_id, reason.left(40))
	if is_host():
		_record_integrity_report(local_peer_id, target_id, reason)
	elif multiplayer.get_peers().has(host_peer_id):
		rpc_id(host_peer_id, "submit_integrity_report", target_id, reason.left(40))

@rpc("any_peer", "call_remote", "reliable")
func submit_integrity_report(target_id: int, reason: String) -> void:
	if is_host():
		_record_integrity_report(multiplayer.get_remote_sender_id(), target_id, reason)

func _record_integrity_report(reporter_id: int, target_id: int, reason: String) -> void:
	if not players.has(reporter_id) or not players.has(target_id) or reporter_id == target_id:
		return
	var reports: Dictionary = integrity_reports.get(target_id, {})
	reports[reporter_id] = reason.left(40)
	integrity_reports[target_id] = reports
	suspicious_players[target_id] = true
	integrity_alert.emit(target_id, reason.left(40))
	emit_snapshot()

func request_vote_kick(target_id: int) -> void:
	if target_id <= 1 or target_id == local_peer_id or not players.has(target_id) or bool(players[target_id].get("bot", false)):
		return
	if is_host():
		_record_kick_vote(local_peer_id, target_id)
	elif multiplayer.get_peers().has(host_peer_id):
		rpc_id(host_peer_id, "submit_kick_vote", target_id)

@rpc("any_peer", "call_remote", "reliable")
func submit_kick_vote(target_id: int) -> void:
	if is_host():
		_record_kick_vote(multiplayer.get_remote_sender_id(), target_id)

func _record_kick_vote(voter_id: int, target_id: int) -> void:
	if target_id <= 1 or voter_id == target_id or not players.has(voter_id) or not players.has(target_id) or bool(players[target_id].get("bot", false)):
		return
	var votes: Dictionary = kick_votes.get(target_id, {})
	votes[voter_id] = true
	kick_votes[target_id] = votes
	if votes.size() >= _kick_threshold():
		_kick_player(target_id)
	else:
		emit_snapshot()

func _kick_threshold() -> int:
	var humans := 0
	for state in players.values():
		if not bool(state.get("bot", false)): humans += 1
	var eligible := maxi(1, humans - 1)
	return maxi(1, int(floor(float(eligible) / 2.0)) + 1)

func _kick_player(target_id: int) -> void:
	if not is_host() or target_id <= 1 or not players.has(target_id):
		return
	rpc_id(target_id, "receive_kicked")
	call_deferred("_disconnect_kicked", target_id)

func _disconnect_kicked(target_id: int) -> void:
	if mesh_peer != null:
		mesh_peer.disconnect_peer(target_id)
	handle_disconnect(target_id)

@rpc("authority", "call_remote", "reliable")
func receive_kicked() -> void:
	kicked.emit()
	host_lost = true
	move = Vector2.ZERO

func _validate_public_auction_state(state: Dictionary) -> void:
	if is_host():
		return
	var invalid := false
	for value in (state.get("cash", {}) as Dictionary).values():
		if int(value) < 0 or int(value) > 100000:
			invalid = true
	for value in (state.get("debt", {}) as Dictionary).values():
		if int(value) < 0 or int(value) > 100000:
			invalid = true
	if int(state.get("bid", 0)) < 0 or int(state.get("cycle", 0)) < 0 or int(state.get("cycle", 0)) > 5:
		invalid = true
	if invalid:
		report_suspicious(host_peer_id, "경매 상태 불일치")

func request_jump() -> void:
	if local_peer_id == 0:
		return
	if is_host():
		start_jump(local_peer_id)
	elif multiplayer.get_peers().has(host_peer_id):
		rpc_id(host_peer_id, "submit_jump")

func start_jump(player_id: int) -> void:
	if not is_host() or not players.has(player_id) or float(players[player_id].get("jump_time", -1.0)) >= 0.0:
		return
	players[player_id]["jump_time"] = 0.0

func arm_shield(player_id: int) -> void:
	if not is_host() or not players.has(player_id):
		return
	players[player_id]["shield"] = true

func seat_at_world_position(position: Vector2) -> int:
	for index in seat_positions.size():
		if position.distance_to(seat_positions[index]) <= 62.0:
			return index
	return -1

func request_seat(seat_index: int) -> void:
	if local_peer_id == 0 or seat_index < 0 or seat_index >= seat_positions.size():
		return
	if is_host():
		claim_seat(local_peer_id, seat_index)
	elif multiplayer.get_peers().has(host_peer_id):
		rpc_id(host_peer_id, "submit_seat", seat_index)

@rpc("any_peer", "call_remote", "reliable")
func submit_seat(seat_index: int) -> void:
	if is_host():
		claim_seat(multiplayer.get_remote_sender_id(), seat_index)

func release_table() -> void:
	if not is_host(): return
	for id in players:
		if bool(players[id].get("bot",false)): continue
		players[id]["seat"] = -1
		players[id]["ready"] = false
		players[id]["move"] = Vector2.ZERO
	_update_table_status()
	emit_snapshot()

func claim_seat(player_id: int, seat_index: int) -> bool:
	if not is_host() or auction_active or not players.has(player_id) or seat_index < 0 or seat_index >= seat_positions.size():
		return false
	for other_id in players:
		if other_id != player_id and int(players[other_id].get("seat", -1)) == seat_index:
			return false
	var state: Dictionary = players[player_id]
	state["seat"] = seat_index
	state["ready"] = true
	state["move"] = Vector2.ZERO
	state["position"] = seat_positions[seat_index]
	players[player_id] = state
	emit_snapshot()
	return true

func request_auction_action(action: String) -> void:
	if host_lost: return
	if local_peer_id == 0 or not is_valid_auction_action(action):
		return
	if is_host():
		auction_action_requested.emit(action, local_peer_id)
	elif multiplayer.get_peers().has(host_peer_id):
		rpc_id(host_peer_id, "submit_auction_action", action)

func broadcast_auction_state(state: Dictionary) -> void:
	if is_host():
		var public_state: Dictionary = make_public_auction_state(state)
		var private_hands: Dictionary = state.get("hands", {})
		var private_energies: Dictionary = state.get("energies", {})
		var private_hints: Dictionary = state.get("private_hints_by_player", {})
		var inventories: Dictionary = state.get("inventories", {})
		var sold_players: Array = state.get("sold_players", [])
		for peer_id in connections:
			var remote_id := int(peer_id)
			if remote_id <= 1 or not private_hands.has(remote_id) or not multiplayer.get_peers().has(remote_id):
				continue
			var private_state: Dictionary = public_state.duplicate(true)
			private_state["hand"] = private_hands[remote_id]
			private_state["energy"] = int(private_energies.get(remote_id, 3))
			private_state["private_hints"] = private_hints.get(remote_id, [])
			private_state["inventory"] = inventories.get(remote_id, [])
			private_state["sold"] = sold_players.has(remote_id)
			private_state["market_offer"] = state.get("market_offers", {}).get(remote_id, [])
			private_state["deck_view"] = state.get("deck_views", {}).get(remote_id, [])
			private_state["pile_counts"] = state.get("all_pile_counts", {}).get(remote_id, {"draw":0,"discard":0})
			rpc_id(remote_id, "receive_auction_state", private_state)

func make_public_auction_state(state: Dictionary) -> Dictionary:
	var public_state: Dictionary = state.duplicate(true)
	public_state.erase("hands")
	public_state.erase("energies")
	public_state.erase("private_hints_by_player")
	public_state.erase("inventories")
	public_state.erase("market_offers")
	public_state.erase("market_offer")
	public_state.erase("deck_views")
	public_state.erase("deck_view")
	public_state.erase("pile_counts")
	public_state.erase("all_pile_counts")
	public_state["inventory"] = []
	public_state["private_hints"] = []
	var public_lot: Dictionary = public_state.get("lot", {}).duplicate(true)
	public_lot.erase("value")
	public_lot.erase("hints")
	public_lot.erase("options")
	public_state["lot"] = public_lot
	public_state["hand"] = []
	public_state["energy"] = 0
	return public_state

func _physics_process(delta: float) -> void:
	for connection in connections.values():
		connection.poll()
	if local_peer_id == 0:
		return
	if is_host():
		host_step(delta)
		_try_start_room()
		_update_table_status()
		snapshot_timer += delta
		if snapshot_timer >= 1.0 / SNAPSHOT_HZ:
			snapshot_timer = 0.0
			var snapshot := serialize_snapshot()
			snapshot_received.emit(snapshot)
			rpc("receive_snapshot", snapshot)
	else:
		if host_lost: return
		if heard_host:
			host_silence += delta
			if host_silence >= HOST_SILENCE_LIMIT:
				handle_disconnect(host_peer_id)
				return
		if multiplayer.get_peers().has(host_peer_id):
			input_timer += delta
			if input_timer >= 1.0 / INPUT_HZ:
				input_timer = 0.0
				rpc_id(host_peer_id, "submit_input", move, local_profile)

func host_step(delta: float) -> void:
	for id in players:
		var state: Dictionary = players[id]
		attack_cooldowns[id] = maxf(0.0, attack_cooldowns.get(id, 0.0) - delta)
		if state.get("bot", false):
			state["move"] = Vector2.ZERO
		var seat_index := int(state.get("seat", -1))
		if seat_index >= 0 and seat_index < seat_positions.size():
			state["move"] = Vector2.ZERO
			state["position"] = seat_positions[seat_index]
		else:
			var state_move: Vector2 = state.get("move", Vector2.ZERO)
			if absf(state_move.x) > 0.05:
				state["facing"] = 1 if state_move.x > 0 else -1
			state["position"] = state.get("position", Vector2.ZERO) + Vector2(state_move.x, 0.0) * SPEED * delta
			state["position"].x = clampf(state["position"].x, 90.0, 3030.0)
		var jump_time := float(state.get("jump_time", -1.0))
		if jump_time >= 0.0:
			jump_time += delta
			if jump_time >= 0.7:
				jump_time = -1.0
		state["jump_time"] = jump_time
		state["position"].y = 520.0 - (sin(jump_time / 0.7 * PI) * 65.0 if jump_time >= 0.0 else 0.0)
		state["ready"] = seat_index >= 0 and seat_index < seat_positions.size()
		players[id] = state

func _update_table_status() -> void:
	var count := 0
	for state in players.values():
		if state.get("ready", false):
			count += 1
	var next_ready := count == players.size() and players.size() > 0
	if next_ready != table_ready or count != last_table_count or players.size() != last_table_total:
		table_ready = next_ready
		last_table_count = count
		last_table_total = players.size()
		table_status_changed.emit(table_ready, count, players.size())

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_input(value: Vector2, profile: Dictionary = {}) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if players.has(sender):
		if value.length() > 1.05:
			_record_integrity_report(local_peer_id, sender, "이동 입력 범위 초과")
			return
		players[sender]["move"] = value.limit_length(1.0)
		if not profile.is_empty():
			players[sender]["profile"] = clean_profile(profile)

@rpc("any_peer", "call_remote", "reliable")
func submit_attack() -> void:
	if is_host():
		resolve_attack(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func submit_jump() -> void:
	if is_host():
		start_jump(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "reliable")
func submit_auction_action(action: String) -> void:
	if is_host() and is_valid_auction_action(action):
		auction_action_requested.emit(action, multiplayer.get_remote_sender_id())

func is_valid_auction_action(action: String) -> bool:
	if action.length() == 0 or action.length() > MAX_AUCTION_ACTION_LENGTH:
		return false
	if action in ["bid", "fold", "pass", "hint", "inspect"]:
		return true
	for prefix in ["market:", "sell:", "card:", "hand:", "submit:", "deck:"]:
		if action.begins_with(prefix) and not action.trim_prefix(prefix).is_empty():
			return true
	return false

func resolve_attack(attacker_id: int) -> void:
	# Older clients may still send this RPC; free-roam weapon attacks are retired.
	return

@rpc("authority", "call_remote", "reliable")
func receive_attack(attacker_id: int, target_id: int, hp: int) -> void:
	attack_resolved.emit(attacker_id, target_id, hp)

@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(snapshot: Dictionary) -> void:
	if host_lost: return
	heard_host = true
	host_silence = 0.0
	snapshot_received.emit(snapshot)
	if bool(snapshot.get("room_started", false)) and not room_has_started:
		receive_room_started()

@rpc("authority", "call_remote", "reliable")
func receive_auction_state(state: Dictionary) -> void:
	_validate_public_auction_state(state)
	auction_state_received.emit(state)

func serialize_snapshot() -> Dictionary:
	var connected_count := multiplayer.get_peers().size() + 1 if is_host() else 0
	var snapshot := {"players": {}, "room_started": room_has_started, "table_ready": table_ready, "table_count": 0, "table_total": players.size(), "connected_count": connected_count, "suspicious": suspicious_players.keys(), "kick_votes": _public_kick_votes()}
	var count := 0
	for id in players:
		var state: Dictionary = players[id]
		var position: Vector2 = state["position"]
		if state.get("ready", false):
			count += 1
		snapshot["players"][str(id)] = {"p": [position.x, position.y], "facing": state.get("facing", 1), "moving": absf(Vector2(state.get("move", Vector2.ZERO)).x) > 0.05, "bot": state.get("bot", false), "seat": state.get("seat", -1), "ready": state.get("ready", false), "hp": state.get("hp", 3), "shield": state.get("shield", false), "profile": state.get("profile", {})}
	snapshot["table_count"] = count
	return snapshot

func _public_kick_votes() -> Dictionary:
	var result: Dictionary = {}
	for target_id in kick_votes:
		result[str(target_id)] = (kick_votes[target_id] as Dictionary).size()
	return result

func emit_snapshot() -> void:
	snapshot_received.emit(serialize_snapshot())

func initial_state(position: Vector2) -> Dictionary:
	return {"position": position, "move": Vector2.ZERO, "facing": 1, "hp": 3, "shield": false, "bot": false, "ready": false, "seat": -1, "profile": local_profile.duplicate()}

func handle_disconnect(id: int) -> void:
	if id == host_peer_id and not is_host() and not host_lost:
		host_lost = true
		move = Vector2.ZERO
		host_disconnected.emit()
	players.erase(id)
	suspicious_players.erase(id)
	local_suspicious_players.erase(id)
	for target_id in integrity_reports.keys():
		(integrity_reports[target_id] as Dictionary).erase(id)
	kick_votes.erase(id)
	for votes in kick_votes.values():
		(votes as Dictionary).erase(id)
	connections.erase(id)
	pending_candidates.erase(id)
	remote_descriptions.erase(id)
	if is_host():
		_update_table_status()
		emit_snapshot()

func on_session_description(type: String, sdp: String, remote_id: int) -> void:
	var connection: WebRTCPeerConnection = connections.get(remote_id)
	if connection == null or connection.set_local_description(type, sdp) != OK:
		network_error.emit("로컬 연결 정보를 적용하지 못했습니다.")
		return
	signal_session.emit(remote_id, type, sdp)

func on_ice_candidate(mid: String, index: int, sdp: String, remote_id: int) -> void:
	signal_candidate.emit(remote_id, mid, index, sdp)
