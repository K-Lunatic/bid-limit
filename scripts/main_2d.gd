extends Node2D

const HallScript = preload("res://scripts/auction_hall_2d.gd")
const PuppetScript = preload("res://scripts/sock_puppet_2d.gd")
const PuppetScene = preload("res://scenes/sock_puppet.tscn")
const AuctionGameScript = preload("res://scripts/auction_game.gd")
const AuctionUIScript = preload("res://scripts/auction_ui.gd")
const PixelFXScript = preload("res://scripts/pixel_fx_2d.gd")
const PixelfxSpriteScript = preload("res://scripts/pixelfx_sprite_2d.gd")
const NetworkScript = preload("res://scripts/network_session_2d.gd")
const SignalingScript = preload("res://scripts/signaling_client.gd")
const LobbyScript = preload("res://scripts/lobby_ui.gd")
const TouchScript = preload("res://scripts/touch_controls.gd")
const TetherScript = preload("res://scripts/tether_link_2d.gd")
const AuctionLotScript = preload("res://scripts/auction_lot_2d.gd")
const LotMonitorScript = preload("res://scripts/lot_monitor_2d.gd")
const VoiceScript = preload("res://scripts/voice_chat.gd")
const ArtLayout = preload("res://scripts/art_layout.gd")
const Identity = preload("res://scripts/bidder_identity.gd")
const SacredHandScript = preload("res://scripts/sacred_hand_2d.gd")
const CardTheftFXScript = preload("res://scripts/card_theft_fx_2d.gd")
const ButtonCoinFXScript = preload("res://scripts/button_coin_fx_2d.gd")

var camera: Camera2D
var hall: Node2D
var player: Node2D
var game: Node
var fx: Node2D
var network: Node
var signaling: Node
var voice: Node
var touch: Node
var actors: Dictionary = {}
var pending_snapshot: Dictionary = {}
var touch_move := Vector2.ZERO
var move_destination := 0.0
var has_move_destination := false
var look_pan := 0.0
var started := false
var auction_sync_timer := 0.0
var latest_auction_state: Dictionary = {}
var last_animation_announcement := ""
var last_card_play_sequence := -1
var lot_item: Node2D
var lot_link: Node2D
var lot_monitor: Node2D
var returning_to_title := false
var auction_ui: CanvasLayer
var appraiser: Node2D
var appraiser_line := ""
var auctioneer: Node2D

func _ready() -> void:
	$World.hide()
	$World.process_mode = Node.PROCESS_MODE_DISABLED
	ThemeDB.fallback_font = preload("res://assets/fonts/NotoSansKR.ttf")
	network = NetworkScript.new()
	add_child(network)
	var seats: Array = []
	for marker in $World/Seats.get_children(): seats.append(marker.global_position)
	network.set("seat_positions",seats)
	network.host_disconnected.connect(_on_host_disconnected)
	network.kicked.connect(_on_kicked)
	network.attack_resolved.connect(_on_attack_resolved)
	network.chat_received.connect(_on_chat_received)
	network.card_jam_requested.connect(func(target_id: int) -> void:
		if game != null:
			game.call("jam_player", target_id))
	network.table_status_changed.connect(_on_table_status)
	signaling = SignalingScript.new()
	add_child(signaling)
	network.snapshot_received.connect(_on_snapshot)
	network.signal_session.connect(func(remote_id: int, type: String, sdp: String) -> void:
		signaling.call("send_signal", remote_id, {"type": type, "sdp": sdp})
	)
	network.signal_candidate.connect(func(remote_id: int, mid: String, index: int, sdp: String) -> void:
		signaling.call("send_signal", remote_id, {"type": "candidate", "mid": mid, "index": index, "sdp": sdp})
	)
	signaling.signal_received.connect(_on_signal)
	voice = VoiceScript.new()
	add_child(voice)
	voice.signal_requested.connect(func(peer_id: int, message: Dictionary) -> void:
		signaling.call("send_signal", peer_id, message)
	)
	var lobby: CanvasLayer = $TitleUI
	lobby.started.connect(start_game)
	lobby.leave_requested.connect(_return_to_title)
	lobby.call("setup", signaling, network)

func start_game() -> void:
	if network.get("host_lost"): return
	if started:
		return
	started = true
	get_viewport().gui_release_focus()
	$World.show()
	$World.process_mode = Node.PROCESS_MODE_INHERIT
	hall = $World/AuctionHall
	appraiser = $World/Appraiser
	auctioneer = $World/Auctioneer
	camera = $World/GameCamera
	camera.enabled = true
	game = AuctionGameScript.new()
	game.set("authoritative", bool(network.call("is_host")))
	game.set("local_player_id", int(network.get("local_peer_id")))
	var starting_players: Array[int] = []
	var starting_bots: Array[int] = []
	for raw_id in network.get("players"):
		var player_id := int(raw_id)
		starting_players.append(player_id)
		if bool(network.get("players")[raw_id].get("bot", false)):
			starting_bots.append(player_id)
	if starting_players.is_empty():
		starting_players.append(int(network.get("local_peer_id")))
	game.set("active_player_ids", starting_players)
	game.set("active_bot_ids", starting_bots)
	add_child(game)
	for player_id in starting_players:
		game.call("register_player", player_id)
	fx = PixelFXScript.new()
	fx.z_index = 8
	add_child(fx)
	lot_item = $World/LotItem
	lot_item.call("setup",lot_item.global_position)
	lot_monitor = $World/LotMonitor
	lot_link = TetherScript.new()
	lot_link.z_index = 4
	lot_link.visible = false
	add_child(lot_link)
	game.changed.connect(func(state: Dictionary) -> void:
		if network.call("is_host") and str(latest_auction_state.get("phase","")) == "auction" and str(state.get("phase")) == "appraisal":
			network.call_deferred("release_table")
		network.set("auction_active", str(state.get("phase", "waiting")) == "auction")
		react_to_auction_state(state)
		latest_auction_state = state
		if network.call("is_host") and auction_sync_timer <= 0.0:
			auction_sync_timer = 0.1
			network.call("broadcast_auction_state", state)
	)
	game.action_requested.connect(func(action: String) -> void:
		network.call("request_auction_action", action)
	)
	network.auction_action_requested.connect(_on_auction_action)
	network.auction_state_received.connect(func(state: Dictionary) -> void:
		if not network.get("host_lost"): game.call("apply_remote_state", state))
	game.defense_card_requested.connect(func(player_id: int) -> void:
		network.call("arm_shield", player_id)
		if player != null and player_id == int(network.get("local_peer_id")):
			spawn_pixelfx("impacts/shield-block", player.position + Vector2(0, -90))
	)
	auction_ui = AuctionUIScript.new()
	add_child(auction_ui)
	auction_ui.call("setup", game)
	auction_ui.chat_requested.connect(func(message: String) -> void: network.call("send_chat", message))
	auction_ui.voice_requested.connect(func() -> void: voice.call("toggle"))
	auction_ui.voice_gain_requested.connect(func(delta: float) -> void:
		var gain: float = float(voice.call("adjust_mic_gain", delta))
		auction_ui.call("set_voice_gain", gain)
	)
	auction_ui.voice_peer_mute_requested.connect(func(peer_id: int) -> void:
		var muted: bool = bool(voice.call("toggle_peer_mute", peer_id))
		auction_ui.call("set_peer_mute", peer_id, muted)
	)
	auction_ui.voice_peer_volume_requested.connect(func(peer_id: int, delta: float) -> void:
		var volume: float = float(voice.call("adjust_peer_volume", peer_id, delta))
		auction_ui.call("set_peer_volume", peer_id, volume)
	)
	auction_ui.vote_kick_requested.connect(func(peer_id: int) -> void: network.call("request_vote_kick", peer_id))
	voice.status_changed.connect(func(status: String) -> void: auction_ui.call("set_voice_status", status))
	auction_ui.market_requested.connect(func(card_id: String) -> void: network.call("request_auction_action", "market:" + card_id))
	auction_ui.travel_requested.connect(func(destination: float) -> void:
		move_destination = destination
		has_move_destination = true)
	auction_ui.jump_requested.connect(func() -> void: network.call("request_jump"))
	auction_ui.return_to_title_requested.connect(_return_to_title)
	auction_ui.defense_requested.connect(func() -> void: game.call("request_card", "shield"))
	touch = TouchScript.new()
	add_child(touch)
	touch.move_changed.connect(_on_touch_move)
	touch.look_changed.connect(_on_touch_look)
	touch.destination_tapped.connect(_on_destination_tapped)
	if not pending_snapshot.is_empty():
		_on_snapshot(pending_snapshot)
	network.call("emit_snapshot")
	if player != null:
		camera.position.x = 1450.0

func _physics_process(_delta: float) -> void:
	if not started or network == null:
		return
	var keyboard_axis := 0.0
	if not get_viewport().gui_get_focus_owner() is LineEdit:
		keyboard_axis = float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A))
	if absf(keyboard_axis) > 0.01 or touch_move.length_squared() > 0.001:
		has_move_destination = false
	var input_vector := touch_move if touch_move.length_squared() > 0.001 else Vector2(keyboard_axis, 0)
	if has_move_destination and player != null:
		var remaining := move_destination - player.position.x
		if absf(remaining) <= 12.0:
			has_move_destination = false
		else:
			input_vector.x = clampf(remaining / 60.0, -1.0, 1.0)
	if player != null and int(player.get_meta("seat",-1)) >= 0:
		input_vector = Vector2.ZERO
		has_move_destination = false
	network.call("set_local_input", input_vector)
	if player != null:
		player.call("set_external_input", input_vector)

func _process(delta: float) -> void:
	auction_sync_timer = maxf(0.0, auction_sync_timer - delta)
	if started and network.call("is_host") and auction_sync_timer <= 0.0 and not latest_auction_state.is_empty():
		auction_sync_timer = 0.1
		network.call("broadcast_auction_state", latest_auction_state)
	if player != null and camera != null:
		if auction_ui != null:
			var near_merchant := player.position.x >= 2500.0
			if near_merchant and not bool(auction_ui.get("market_near")):
				get_node("World/Merchant").call("say","행동표 봉투는 70보풀! 세 장 중 하나 골라요.")
			auction_ui.call("set_market_access", near_merchant)
			if appraiser != null:
				var nearby := player.position.x <= ArtLayout.APPRAISAL_MAX_X
				auction_ui.call("set_appraisal_access",nearby,get_viewport().get_canvas_transform()*appraiser.position)
				if nearby and str(latest_auction_state.get("phase")) == "appraisal":
					var items: Array = latest_auction_state.get("inventory",[])
					var line := "오늘은 물품 한 개만 매입해요." if bool(latest_auction_state.get("sold",false)) else "물품을 가져오면 감정가로 매입해 드려요."
					if not items.is_empty() and not bool(latest_auction_state.get("sold",false)):
						var item: Dictionary = items[clampi(int(auction_ui.get("sale_index")),0,items.size()-1)]
						line = "%s! 감정가 %d보풀입니다." % [str(item.name),int(item.get("appraisal",0))]
					if line != appraiser_line:
						appraiser_line = line
						appraiser.call("say",line)
						appraiser.call("play_action", "talk", 0.92)
				elif nearby:
					var phase := str(latest_auction_state.get("phase", "waiting"))
					var line := "의자에 앉으면 경매 준비를 시작해요." if phase in ["waiting", "connecting"] else "옵션은 중앙 CRT에서 확인해요. 차례를 기다려 주세요."
					if line != appraiser_line:
						appraiser_line = line
						appraiser.call("say", line)
						appraiser.call("play_action", "talk", 0.82)
				elif not nearby: appraiser_line = ""
			auction_ui.call("set_chat_anchor", get_viewport().get_canvas_transform() * player.position)
		look_pan = move_toward(look_pan, 0.0, delta * 180.0)
		var at_auction := absf(player.position.x - 1450.0) < 550.0
		# Frame all four seats and the auctioneer, including their overhead cards.
		camera.zoom = Vector2.ONE * ArtLayout.CAMERA_ZOOM
		camera.position.y = 340.0 if at_auction else ArtLayout.CAMERA_START.y
		var half_view_width := get_viewport_rect().size.x / (2.0 * camera.zoom.x)
		var focus_x := 1450.0 if absf(player.position.x - 1450.0) < 550.0 else player.position.x
		camera.position.x = clampf(focus_x + look_pan, half_view_width, 3200.0 - half_view_width)

func _unhandled_input(event: InputEvent) -> void:
	if not started:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _try_seat_at_screen(event.position):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		network.call("request_jump")

func _on_attack_resolved(_attacker_id: int, target_id: int, _remaining_hp: int) -> void:
	if actors.has(target_id):
		var target: Node2D = actors[target_id]
		target.call("react", "퍽!")
		spawn_pixelfx("impacts/hit-spark", target.position + Vector2(0, -90))

func _on_chat_received(sender_id: int, message: String) -> void:
	if actors.has(sender_id):
		actors[sender_id].call("say", message)
	if voice != null:
		voice.call("speak_chat", message)

func _on_touch_move(value: Vector2) -> void:
	touch_move = value

func _on_host_disconnected() -> void:
	_show_connection_lost("방장과 연결이 끊겼습니다. 방을 나가 다시 참가해 주세요.")

func _on_kicked() -> void:
	_show_connection_lost("추방 투표로 방에서 퇴장되었습니다.")

func _show_connection_lost(message: String) -> void:
	if voice != null: voice.call("stop")
	if game != null:
		game.set("phase","disconnected")
		game.set("turn_id",-1)
		game.set("announcement",message)
		game.call("emit_state")
	if player != null:
		player.set("is_player",false)
		player.call("set_external_input",Vector2.ZERO)
	for child in get_children():
		if child is BidLobbyUI: child.call("show_connection_lost",message)

func _return_to_title() -> void:
	if returning_to_title:
		return
	returning_to_title = true
	if str(signaling.get("room_id")).is_empty():
		get_tree().reload_current_scene()
		return
	var leave_request := HTTPRequest.new()
	leave_request.timeout = 3.0
	add_child(leave_request)
	leave_request.request_completed.connect(func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		get_tree().reload_current_scene()
	)
	var room_id := str(signaling.get("room_id"))
	var peer_id := int(signaling.get("peer_id"))
	var path := "/rooms/%s/leave?peer=%d" % [room_id, peer_id]
	if OS.has_feature("web"):
		path = "/rooms?room=%s&action=leave&peer=%d" % [room_id, peer_id]
	var url := "%s%s" % [signaling.get("base_url"), path]
	var error := leave_request.request(url, PackedStringArray(["x-room-token: %s" % signaling.get("room_token")]), HTTPClient.METHOD_POST, "")
	if error != OK:
		get_tree().reload_current_scene()

func _on_touch_look(delta: Vector2) -> void:
	look_pan += delta.x * 1.25

func _on_destination_tapped(screen_position: Vector2) -> void:
	if player == null:
		return
	if _try_seat_at_screen(screen_position):
		return
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	move_destination = clampf(world_position.x, 90.0, 3030.0)
	has_move_destination = true

func _try_seat_at_screen(screen_position: Vector2) -> bool:
	if network == null or camera == null:
		return false
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var seat_index := int(network.call("seat_at_world_position", world_position))
	if seat_index < 0:
		return false
	network.call("request_seat", seat_index)
	return true

func _on_table_status(ready: bool, count: int, total: int) -> void:
	if game != null:
		game.call("set_table_status", ready, count, total)

func _on_signal(message: Dictionary) -> void:
	var kind := str(message.get("type", ""))
	var sender := int(message.get("from", 0))
	if kind.begins_with("voice-"):
		if voice != null:
			voice.call("receive_signal", sender, message)
		return
	match kind:
		"peer_join":
			var joined_id := int(message.get("peerId", sender))
			network.call("prepare_peer", joined_id, true)
			if game != null and network.call("is_host"):
				game.call("register_player", joined_id)
		"offer", "answer":
			network.call("receive_signal_session", sender, kind, str(message.get("sdp", "")))
		"candidate":
			network.call("receive_signal_candidate", sender, str(message.get("mid", "")), int(message.get("index", 0)), str(message.get("sdp", "")))
		"peer_leave":
			var departed_id := int(message.get("peerId", sender))
			network.call("handle_disconnect", departed_id)
			if network.call("is_host"):
				network.call("emit_snapshot")
			if actors.has(departed_id):
				actors[departed_id].queue_free()
				actors.erase(departed_id)

func _on_snapshot(snapshot: Dictionary) -> void:
	if network.get("host_lost"): return
	if not started:
		pending_snapshot = snapshot
		return
	if snapshot.has("table_ready"):
		_on_table_status(bool(snapshot.get("table_ready", false)), int(snapshot.get("table_count", 0)), int(snapshot.get("table_total", 0)))
	var player_snapshot: Dictionary = snapshot.get("players", snapshot)
	if voice != null:
		voice.call("configure", int(network.get("local_peer_id")), player_snapshot.keys())
	if auction_ui != null:
		var suspicious: Array = snapshot.get("suspicious", []).duplicate()
		for suspicious_id in network.get("local_suspicious_players").keys():
			if not suspicious.has(suspicious_id): suspicious.append(suspicious_id)
		auction_ui.call("set_voice_peers", player_snapshot, suspicious, snapshot.get("kick_votes", {}))
	if hall != null:
		hall.call("set_seat_occupants", player_snapshot)
	var active_bots: Array = []
	for key in player_snapshot:
		if bool(player_snapshot[key].get("bot", false)):
			active_bots.append(int(key))
	if game != null and network.call("is_host"):
		game.set("active_bot_ids", active_bots)
		var active_players: Array = []
		for key in player_snapshot:
			active_players.append(int(key))
			game.call("register_player", int(key))
		game.call("set_active_players", active_players)
	for id in actors.keys():
		if not player_snapshot.has(str(id)) and not player_snapshot.has(id):
			actors[id].queue_free()
			actors.erase(id)
	for key in player_snapshot:
		var id := int(key)
		var state: Dictionary = player_snapshot[key]
		if not actors.has(id):
			_spawn_actor(id, state)
		var actor: Node2D = actors[id]
		var network_facing := int(state.get("facing", 1))
		if network_facing != int(actor.get("facing")):
			actor.call("turn_to", network_facing)
		actor.set("facing", network_facing)
		actor.set("remote_moving", bool(state.get("moving", false)))
		var profile: Dictionary = state.get("profile", {})
		if game != null and network.call("is_host"):
			var display_name := Identity.bot_name(id) if bool(state.get("bot", false)) else str(profile.get("nickname", "양말"))
			game.call("set_player_identity", id, display_name, int(profile.get("weapon", 0)))
		if not profile.is_empty() and actor.get_meta("profile", {}) != profile:
			if not bool(state.get("bot", false)):
				actor.set("puppet_name", str(profile.get("nickname", "양말")))
			actor.call("set_sock_color", Color.html("#" + str(profile.get("sock", "e15a67"))))
			var hair := Color.html("#" + str(profile.get("hair", "35a7d7")))
			actor.call("set_hair_color", hair)
			actor.call("set_accessory", int(profile.get("hair_style", 0)), int(profile.get("accessory", 0)))
			actor.set_meta("profile", profile.duplicate(true))
		actor.set_meta("seat",int(state.get("seat",-1)))
		var point: Array = state.get("p", [1210.0, 520.0])
		var target := Vector2(float(point[0]), float(point[1]))
		if id != network.get("local_peer_id"):
			actor.position = actor.position.lerp(target, 0.45)
		elif int(state.get("seat",-1)) >= 0:
			actor.position = target
		else:
			actor.position.y = target.y
		var hp := int(state.get("hp", 3))
		if int(actor.get_meta("hp", hp)) > hp:
			actor.call("react", "아야!")
		actor.set_meta("hp", hp)
	if actors.has(network.get("local_peer_id")):
		player = actors[network.get("local_peer_id")]

func _spawn_actor(id: int, state: Dictionary) -> void:
	var is_local := id == int(network.get("local_peer_id"))
	var style: int = 0 if is_local else abs(id) % 3
	var actor: Node2D = PuppetScene.instantiate()
	var profile: Dictionary = state.get("profile", {})
	var sock_color := Color("e15a67")
	var hair_color := Color("35a7d7")
	if not profile.is_empty():
		sock_color = Color("#" + str(profile.get("sock", "e15a67")))
		hair_color = Color("#" + str(profile.get("hair", "35a7d7")))
	var hair_style := int(profile.get("hair_style", style))
	var accessory_style := int(profile.get("accessory", style + 1))
	var actor_name := Identity.bot_name(id) if bool(state.get("bot", false)) else str(profile.get("nickname", "양말"))
	actor.call("setup", actor_name, sock_color, hair_color, is_local, style, hair_style, accessory_style)
	var point: Array = state.get("p", [1210.0, 520.0])
	actor.position = Vector2(float(point[0]), float(point[1]))
	actor.z_index = 1
	actor.set_meta("hp", int(state.get("hp", 3)))
	add_child(actor)
	actor.call("set_card_count", 4 if not is_local else 0)
	actors[id] = actor
	if not latest_auction_state.is_empty():
		react_to_auction_state(latest_auction_state)
	if is_local:
		actor.connect("strike_landed", on_strike_landed)

func _on_auction_action(action: String, sender_id: int) -> void:
	if not network.call("is_host") or game == null:
		return
	game.call("register_player", sender_id)
	match action:
		"bid": game.call("place_bid", sender_id)
		"fold": game.call("fold_player", sender_id)
		"pass": game.call("pass_turn", sender_id)
		"hint": game.call("buy_hint_for", sender_id)
		"inspect": game.call("play_card_id", "inspect", sender_id)
		_: 
			if action.begins_with("deck:"):
				var parts := action.split(":")
				if parts.size() == 3 and parts[1] in ["add","remove"]:
					game.call("change_deck_card", sender_id, parts[2], parts[1] == "add")
			elif action.begins_with("market:"):
				var peer_state: Dictionary = network.get("players").get(sender_id, {})
				var peer_position: Vector2 = peer_state.get("position", Vector2.ZERO)
				if peer_position.x >= 2500.0:
					var market_action := action.trim_prefix("market:")
					if market_action == "pack":
						game.call("buy_market_pack", sender_id)
					elif market_action == "loan":
						game.call("borrow_loan", sender_id)
					elif market_action == "repay":
						game.call("repay_loan", sender_id)
					elif market_action.begins_with("roulette:"):
						game.call("play_roulette", sender_id, int(market_action.trim_prefix("roulette:")))
					else:
						game.call("buy_market_card", sender_id, market_action)
			elif action.begins_with("sell:"):
				var peer_position: Vector2 = network.get("players").get(sender_id,{}).get("position",Vector2(9999,0))
				if peer_position.x <= ArtLayout.APPRAISAL_MAX_X:
					game.call("sell_item", sender_id, int(action.trim_prefix("sell:")))
			elif action.begins_with("card:"):
				game.call("play_card_id", action.trim_prefix("card:"), sender_id)
			elif action.begins_with("hand:"):
				game.call("play_card", int(action.trim_prefix("hand:")), sender_id)
			elif action.begins_with("submit:"):
				var selected: Array[int] = []
				for raw_index in action.trim_prefix("submit:").split(","):
					if not raw_index.is_empty():
						selected.append(int(raw_index))
				game.call("submit_hand", selected, sender_id)

func on_strike_landed() -> void:
	if player == null:
		return
	var direction := int(player.get("facing"))
	fx.call("burst", player.position + Vector2(70 * direction, -95), Color("f2d06b"), "hit")
	spawn_pixelfx("impacts/hit-spark", player.position + Vector2(80 * direction, -95))

func react_to_auction_state(state: Dictionary) -> void:
	if auctioneer != null:
		auctioneer.call("set_auction_state", state)
	if lot_monitor != null:
		var lot: Dictionary = state.get("lot", {})
		lot_monitor.call("set_options", int(lot.get("option_count", 0)), state.get("hints", []))
		if lot_item != null:
			lot_item.call("set_lot", lot)
	if player != null:
		var hand_state: Array = state.get("hand", [])
		player.call("set_card_count", hand_state.size())
	var hand_counts: Dictionary = state.get("hand_counts", {})
	for actor_id in actors:
		actors[actor_id].set("is_current_turn", str(state.get("phase")) == "auction" and int(state.get("turn_id",-1)) == int(actor_id))
		actors[actor_id].queue_redraw()
		var count_value = hand_counts.get(str(actor_id), hand_counts.get(actor_id, 0))
		actors[actor_id].call("set_card_count", int(count_value))
	var phase := str(state.get("phase", "waiting"))
	var winner_id := int(state.get("leader", -1))
	var sold_players: Array = state.get("sold_players", [])
	if lot_item != null and lot_link != null:
		if phase == "appraisal" and actors.has(winner_id) and not sold_players.has(winner_id):
			lot_item.visible = true
			var winner: Node2D = actors[winner_id]
			lot_item.call("attach_to", winner)
			lot_link.call("bind", winner, lot_item, Vector2(0, -72), Vector2.ZERO)
			lot_link.visible = true
		elif phase == "appraisal" and sold_players.has(winner_id):
			# The item leaves the scene once the appraisal shop buys it.
			lot_item.call("release_to_stage")
			lot_item.visible = false
			lot_link.visible = false
		else:
			lot_item.visible = true
			lot_item.call("release_to_stage")
			lot_link.visible = false
	var announcement_text := str(state.get("announcement", ""))
	var last_play: Dictionary = state.get("last_play", {})
	var play_sequence := int(last_play.get("sequence", -1))
	if play_sequence >= 0 and play_sequence != last_card_play_sequence:
		last_card_play_sequence = play_sequence
		var played_cards: Array = last_play.get("cards", [])
		var played_by := int(last_play.get("player_id", -1))
		if not played_cards.is_empty() and actors.has(played_by):
			var card_id := str(played_cards[0].get("id", ""))
			var action := "steal" if card_id == "steal" else ("coin" if card_id == "luck" else ("attack" if card_id in ["attack", "raise"] else ("bid" if card_id == "bid" else "talk")))
			actors[played_by].call("play_action", action, 0.72)
			actors[played_by].call("say", str(played_cards[0].get("label", "카드")) + "!")
			var burst_color := Color("ef8b79") if action == "attack" else Color("f2d06b")
			fx.call("burst", actors[played_by].position + Vector2(0, -92), burst_color, "bid" if action == "bid" else "hit")
			if action == "coin":
				var coin_fx: Node2D = ButtonCoinFXScript.new()
				coin_fx.z_index = 8
				add_child(coin_fx)
				coin_fx.call("setup", actors[played_by].position + Vector2(0, -116))
				spawn_pixelfx("ui/spell", actors[played_by].position + Vector2(0, -92))
			elif action == "steal":
				var target_id := int(last_play.get("target_id", -1))
				if actors.has(target_id):
					actors[target_id].call("react", "어? 내 카드!")
					var theft_fx: Node2D = CardTheftFXScript.new()
					theft_fx.z_index = 8
					add_child(theft_fx)
					theft_fx.call("setup", actors[target_id].position + Vector2(0, -118), actors[played_by].position + Vector2(0, -118), "훔침")
				spawn_pixelfx("pickups/collect-burst", actors[played_by].position + Vector2(0, -92))
			elif action == "attack":
				spawn_pixelfx("impacts/hit-spark", actors[played_by].position + Vector2(0, -92))
			else:
				spawn_pixelfx("ui/spell", actors[played_by].position + Vector2(0, -92))
	if announcement_text != last_animation_announcement and announcement_text.contains("입찰"):
		var bidder_id := int(state.get("leader", -1))
		if actors.has(bidder_id):
			actors[bidder_id].call("play_action", "bid", 0.58)
		fx.call("burst", Vector2(1450, 260), Color("f2d06b"), "bid")
		spawn_pixelfx("pickups/collect-burst", Vector2(1450, 260))
	elif announcement_text != last_animation_announcement and announcement_text.contains("낙찰"):
		if actors.has(winner_id):
			actors[winner_id].call("play_action", "victory", 0.82)
		fx.call("burst", Vector2(1450, 260), Color("a6e5cf"), "bid")
		spawn_pixelfx("pickups/collect-burst", Vector2(1450, 260))
	elif announcement_text != last_animation_announcement and announcement_text.contains("물품 판매!"):
		if appraiser != null:
			appraiser.call("play_action","bid",0.6)
			spawn_pixelfx("pickups/collect-burst",appraiser.position+Vector2(0,-90))
			var history: Array = state.get("decision_history",[])
			if not history.is_empty() and str(history.back().get("decision")) == "sell":
				fx.call("show_amount",int(history.back().get("detail",0)),appraiser.position+Vector2(-140,-90))
	last_animation_announcement = announcement_text

func spawn_pixelfx(effect_id: String, at: Vector2) -> void:
	var effect: Node2D = PixelfxSpriteScript.new()
	effect.z_index = 8
	add_child(effect)
	effect.call("play_effect", effect_id, at)
