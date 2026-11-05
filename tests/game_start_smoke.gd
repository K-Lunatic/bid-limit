extends SceneTree

func _init() -> void:
	call_deferred("run_smoke")

func run_smoke() -> void:
	var scene: Node = load("res://scenes/main_2d.tscn").instantiate()
	root.add_child(scene)
	assert(ThemeDB.fallback_font.has_char(0xAC00))
	var network: Node = scene.get("network")
	if network.call("create_host") != OK:
		printerr("Cannot initialize host")
		quit(1)
		return
	scene.call("start_game")
	await process_frame
	await process_frame
	assert(scene.get("player") != null)
	assert(scene.get("actors").size() == 1)
	assert(scene.get("game").call("state")["hand"].size() == 4)
	assert(not scene.get("player").get("card_arc").visible)
	var ui: Node
	for child in scene.get_children():
		if child is BidAuctionUI:
			ui = child
	assert(ui != null)
	assert(ui.get("return_button").visible)
	assert(not ui.get("chat_composer").visible)
	assert(not ui.get("detail_label").visible)
	ui.call("open_chat")
	assert(ui.get("chat_composer").visible)
	var spoken: Array = []
	ui.chat_requested.connect(func(message: String) -> void: spoken.append(message))
	ui.call("_send_chat", "말풍선 테스트")
	assert(spoken == ["말풍선 테스트"] and not ui.get("chat_composer").visible)
	var game: Node = scene.get("game")
	ui.call("set_market_access", true)
	assert(not ui.get("market_panel").visible)
	ui.call("open_market")
	assert(ui.get("market_panel").visible)
	ui.call("set_market_access", false)
	assert(not ui.get("market_panel").visible)
	game.set("phase", "appraisal")
	ui.call("set_appraisal_access",true)
	game.get("inventories")[1] = [{"name": "첫 물품", "paid": 20, "appraisal": 30}, {"name": "둘째 물품", "paid": 40, "appraisal": 60}]
	ui.call("render_state", game.call("state"))
	ui.call("shift_sale_selection", 1)
	assert(ui.get("sale_index") == 1)
	assert(ui.get("sale_label").text.contains("둘째 물품"))
	game.call("request_sell", 1)
	assert(game.get("inventories")[1].size() == 1)
	assert(game.get("inventories")[1][0]["name"] == "첫 물품")
	print("Game start smoke test: PASS")
	quit()
