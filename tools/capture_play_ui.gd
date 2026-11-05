extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene := load("res://scenes/main_2d.tscn").instantiate() as Node
	root.add_child(scene)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-title.png") == OK)
	var lobby: Node
	for child in scene.get_children():
		if child is BidLobbyUI:
			lobby = child
	lobby.call("start_host")
	assert(not scene.get("started"))
	assert(scene.get("network").get("players").size() == 1)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-lobby.png") == OK)
	scene.get("network").call("add_bots")
	scene.get("network").call("start_room")
	await process_frame
	await process_frame
	scene.get("player").call("say", "이 물건… 정말 진품 맞아요?")
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-play.png") == OK)
	scene.get("auction_ui").get("deck_builder").call("toggle")
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-deck.png") == OK)
	scene.get("auction_ui").get("deck_builder").call("toggle")
	var ui: Node = scene.get("auction_ui")
	var player: Node2D = scene.get("player")
	var home := player.position
	player.position = Vector2(2700,520)
	scene.get("network").get("players")[1]["position"] = player.position
	scene.get("camera").position.x = 2740
	scene.get("camera").reset_smoothing()
	ui.call("set_market_access",true)
	ui.call("open_market")
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-market-sealed.png") == OK)
	ui.set_process(false)
	ui.get("market_buy").pressed.emit()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-market-opening-start.png") == OK)
	ui.call("_process",0.3)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-market-opening-mid.png") == OK)
	ui.call("_process",0.5)
	ui.get("market_products")[0].pressed.emit()
	ui.set_process(true)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-market.png") == OK)
	ui.call("set_market_access",false)
	player.position = home
	scene.get("network").get("players")[1]["position"] = home
	scene.get("camera").position.x = 1450
	scene.get("camera").reset_smoothing()
	scene.get("network").call("claim_seat", 1, 0)
	scene.get("network").call("_update_table_status")
	await process_frame
	await RenderingServer.frame_post_draw
	assert(scene.get("game").get("phase") == "auction")
	await create_timer(0.7).timeout
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-auction.png") == OK)
	var fan: Control = scene.get("auction_ui").get("card_fan")
	fan.set_process(false)
	fan.set("incoming",{})
	fan.set("preview_index",0)
	fan.queue_redraw()
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-card-hover.png") == OK)
	var origin: Vector2 = fan.call("_card_transform",0,fan.get("cards").size()).origin
	fan.call("_begin_drag",origin)
	fan.call("_move_drag",Vector2(170,108))
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-card-drag.png") == OK)
	fan.set("drag_index",-1)
	fan.set("dragging",false)
	var game: Node = scene.get("game")
	game.set("turn_id",1)
	game.get("hands")[1] = [game.call("card_definition","attack"),game.call("card_definition","rumor"),game.call("card_definition","bid")]
	game.call("_sync_local_hand")
	ui.call("render_state",game.call("state"))
	ui.call("play_dropped_card",0)
	ui.call("play_dropped_card",1)
	fan.set("incoming",{})
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-staged-cards.png") == OK)
	game.set_process(false)
	ui.call("submit_selected")
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-submitted.png") == OK)
	ui.call("_process",2.6)
	ui.call("render_state",game.call("state"))
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-submitted-cleared.png") == OK)
	scene.get("network").get("players")[1]["seat"] = -1
	player.set_meta("seat",-1)
	player.position = Vector2(2130,520)
	scene.get("network").get("players")[1]["position"] = player.position
	scene.get("camera").position = Vector2(2130,350)
	scene.get("camera").reset_smoothing()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-hall-props.png") == OK)
	game.set("cycle",5)
	game.call("finish_match")
	player.position = home
	scene.get("network").get("players")[1]["position"] = home
	scene.get("camera").position = Vector2(1450,340)
	scene.get("camera").reset_smoothing()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-results.png") == OK)
	game.set("phase","appraisal")
	game.get("sold_this_cycle").erase(1)
	game.get("inventories")[1] = [{"name":"수상한 왕관","paid":100,"appraisal":180}]
	game.call("emit_state")
	player.position = Vector2(520,520)
	scene.get("network").get("players")[1]["seat"] = -1
	scene.get("network").get("players")[1]["position"] = player.position
	scene.get("camera").position = Vector2(457,350)
	scene.get("camera").reset_smoothing()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-appraiser.png") == OK)
	scene.call("_on_auction_action","sell:0",1)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-native-appraiser-sold.png") == OK)
	print("Native lobby + play capture: PASS")
	scene.queue_free()
	await process_frame
	quit()
