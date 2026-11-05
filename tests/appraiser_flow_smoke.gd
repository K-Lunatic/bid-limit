extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var scene := load("res://scenes/main_2d.tscn").instantiate() as Node
	root.add_child(scene)
	var network: Node = scene.get("network")
	assert(network.create_host() == OK)
	scene.start_game()
	await process_frame
	await process_frame
	var game: Node = scene.get("game")
	game.set_process(false)
	game.leader = 1
	game.phase = "appraisal"
	game.sold_this_cycle = []
	game.emit_state()
	await process_frame
	assert(scene.get("lot_item").visible)
	game.sold_this_cycle = [1]
	game.emit_state()
	await process_frame
	assert(not scene.get("lot_item").visible)
	game.sold_this_cycle = []
	game.phase = "auction"
	game.emit_state()
	await process_frame
	assert(scene.get("lot_item").visible)
	game.phase = "appraisal"
	game.inventories[1] = [{"name":"가짜 왕관","paid":100,"appraisal":180}]
	game.emit_state()
	var ui: Node = scene.get("auction_ui")
	assert(not ui.sell_button.visible)
	scene._on_auction_action("sell:0",1)
	assert(game.inventories[1].size() == 1)
	scene.get("player").position = Vector2(520,520)
	network.players[1].position = Vector2(520,520)
	scene._process(0.0)
	assert(ui.sell_button.visible and ui.sell_button.text.contains("180"))
	assert(scene.get("appraiser").speech.contains("180"))
	assert(not ui.sale_label.visible)
	var before: int = game.cash[1]
	scene._on_auction_action("sell:0",1)
	assert(game.inventories[1].is_empty() and game.cash[1] == before+180)
	assert(scene.get("fx").receipts.size() == 1 and scene.get("fx").receipts[0].amount == 180)
	scene.react_to_auction_state(game.state())
	assert(scene.get("fx").receipts.size() == 1)
	scene.get("fx")._process(1.5)
	assert(scene.get("fx").receipts.is_empty())
	scene._process(0.0)
	assert(not ui.sell_button.visible)
	assert(scene.get("appraiser").speech.contains("한 개"))
	var target := []
	ui.travel_requested.connect(func(x: float) -> void: target.append(x))
	ui.exploration_controls.get_child(0).pressed.emit()
	assert(target == [520.0] and scene.get("has_move_destination"))
	scene.queue_free()
	await process_frame
	print("Appraiser NPC: nearby price speech, remote sale rejection, payout, cycle limit and travel: PASS")
	quit()
