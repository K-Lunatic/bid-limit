extends SceneTree

var scene: Node
var session: Node
var role := 0
var elapsed := 0.0
var movement_time := 0.0
var sent_chat := false
var sent_at := 0
var echo_ms := -1
var messages := {}
var snapshots := 0
var reported := false
var loss_reported := false
var deck_stage := 0
var market_stage := 0
var market_bought := 0
var market_card := ""
var market_cash := 0
var market_setup := false
var reserve_baseline := -1
var private_states := 0
var intermission_seated := false
var sale_requested := false
var close_requested := false

func _init() -> void:
	call_deferred("boot")

func boot() -> void:
	var settings: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--e2e="):
			settings = JSON.parse_string(arg.trim_prefix("--e2e="))
	if settings.is_empty():
		push_error("multiplayer_peer.gd는 multiplayer_e2e.mjs에서 --e2e 설정과 함께 실행해야 합니다.")
		quit(2)
		return
	role = int(settings.get("peerId", 0))
	if role <= 0:
		push_error("--e2e 설정에 유효한 peerId가 없습니다.")
		quit(2)
		return
	scene = load("res://scenes/main_2d.tscn").instantiate()
	root.add_child(scene)
	var signaling: Node = scene.get("signaling")
	signaling.set("room_id", str(settings.get("roomId", "")))
	signaling.set("peer_id", role)
	signaling.set("room_token", str(settings.get("token", "")))
	session = scene.get("network")
	session.auction_state_received.connect(func(state: Dictionary) -> void:
		assert(not state.has("market_offers"))
		assert(state.get("market_offer",[]).size() in [0,3])
		private_states += 1)
	session.snapshot_received.connect(func(_snapshot: Dictionary) -> void: snapshots += 1)
	session.chat_received.connect(func(sender: int, message: String) -> void:
		messages[sender] = message
		if sender == role:
			echo_ms = Time.get_ticks_msec() - sent_at)
	var lobby: Node
	for child in scene.get_children():
		if child is BidLobbyUI:
			lobby = child
	lobby.profile["nickname"] = "검증%d" % role
	if role == 1:
		lobby.start_host()
	else:
		lobby.start_join(role)

func _process(delta: float) -> bool:
	elapsed += delta
	if session == null: return false
	if reported:
		if role != 1 and session.get("host_lost") and not loss_reported:
			assert(scene.get("game").get("phase") == "disconnected")
			assert(not scene.get("player").get("is_player"))
			assert(not scene.get("auction_ui").get("card_fan").visible)
			assert(scene.get("auction_ui").get("return_button").visible)
			loss_reported = true
			print("BID_E2E_HOST_LOST role=%d phase=disconnected cards=hidden exit=visible" % role)
		return false
	if elapsed > 25.0:
		printerr("BID_E2E_FAIL role=%d peers=%s snapshots=%d started=%s messages=%s market=%d bought=%d deck=%d" % [role, session.multiplayer.get_peers(), snapshots, scene.get("started"), messages.keys(), market_stage, market_bought, deck_stage])
		quit(1)
		return false
	if session.multiplayer.get_peers().size() != 3:
		return false
	if role == 1 and not session.get("room_has_started"):
		if session.get("players").size() == 4:
			session.call("start_room", false)
	if not scene.get("started") or scene.get("player") == null:
		return false
	if not sent_chat:
		sent_chat = true
		sent_at = Time.get_ticks_msec()
		session.call("send_chat", "연결 확인 %d" % role)
	var game: Node = scene.get("game")
	var state: Dictionary = game.call("state")
	if not market_setup:
		market_setup = true
		scene.get("player").position = Vector2(2700,520)
		if role == 1:
			for id in session.get("players"):
				session.get("players")[id]["position"] = Vector2(2700,520)
			session.call("emit_snapshot")
	if market_bought < 2:
		if scene.get("player").position.x < 2500: return false
		var offer: Array = state.get("market_offer",[])
		if market_stage == 0:
			assert(offer.is_empty())
			market_cash = int(state.get("cash",{}).get(role,0))
			session.call("request_auction_action","market:pack")
			market_stage = 1
		elif market_stage == 1 and offer.size() == 3:
			assert(int(state.get("cash",{}).get(role,0)) == market_cash - 70)
			session.call("request_auction_action","market:" + str(offer[0]))
			market_stage = 2
		elif market_stage == 2 and offer.is_empty():
			var reserve_count := 0
			for entry in state.get("deck_view",[]): reserve_count += int(entry.reserve)
			market_bought += 1
			assert(reserve_count == market_bought)
			market_stage = 0
		return false
	var deck_view: Array = state.get("deck_view",[])
	if deck_view.is_empty(): return false
	var bid_reserve := 0
	for entry in deck_view:
		if entry.id == "bid": bid_reserve = int(entry.reserve)
	if reserve_baseline < 0: reserve_baseline = bid_reserve
	if deck_stage == 0:
		game.call("request_deck_change","bid",false)
		deck_stage = 1
	elif deck_stage == 1 and bid_reserve == reserve_baseline + 1:
		game.call("request_deck_change","bid",true)
		deck_stage = 2
	elif deck_stage == 2 and bid_reserve == reserve_baseline:
		deck_stage = 3
		session.call("request_seat", role-1)
	if str(state.get("phase")) == "appraisal" and not intermission_seated:
		if int(scene.get("player").get_meta("seat",-1)) != -1: return false
		scene.get("player").position = Vector2(520,520)
		if not sale_requested:
			if state.get("inventory",[]).is_empty(): return false
			sale_requested = true
			session.call("request_auction_action","sell:0")
			return false
		if not bool(state.get("sold",false)): return false
		assert(int(state.get("cash",{}).get(role,0)) == 540)
		intermission_seated = true
		session.call("request_seat",role-1)
	if role == 1 and not close_requested and str(state.get("phase")) == "auction" and messages.size() == 4:
		close_requested = true
		game.call("close_auction")
		for id in [1,2,3,4]:
			game.get("inventories")[id] = [{"name":"판매 검증 물품","paid":100,"appraisal":180}]
			session.get("players")[id]["position"] = Vector2(520,520)
		game.call("emit_state")
		return false
	if messages.size() == 4 and str(state.get("phase")) == "auction" and int(state.get("table_count")) == 4 and int(state.get("cycle",0)) == 2:
		var roster: Dictionary = scene.get("actors")
		if roster.size() != 4 or state.get("hand", []).size() < 4 or state.get("hand", []).size() > 5:
			return false
		for id in [1,2,3,4]:
			if not roster.has(id) or str(roster[id].get("puppet_name")) != "검증%d" % id:
				return false
		assert(role == 1 or private_states > 0)
		assert(intermission_seated)
		assert(int(state.get("cash",{}).get(role,0)) == 540)
		reported = true
		print("BID_E2E_PASS role=%d peers=3 actors=4 hand=4..5 table=4 chat=4 deck_edit=ok market=2 private_offers=ok intermission=ok appraisal_sale=180 echo_ms=%d snapshots=%d" % [role, echo_ms, snapshots])
	return false
