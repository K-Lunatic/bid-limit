extends SceneTree

const Auction = preload("res://scripts/auction_game.gd")

func card_count(game: Node, player_id: int, card_id: String) -> int:
	var total := 0
	for pile_name in ["decks", "hands", "discards"]:
		for card in game.get(pile_name).get(player_id, []):
			if card.get("id", "") == card_id:
				total += 1
	return total

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game: Node = Auction.new()
	root.add_child(game)
	game.set("active_player_ids", [1, 100])
	game.set("active_bot_ids", [100])
	game.call("set_table_status", true, 2, 2)
	game.set("bot_interrupt_cooldown", 100.0)
	assert(game.get("timer") == 25.0)
	game.call("_process", 16.0)
	assert(game.get("turn_id") == 1 and game.get("timer") == 9.0)
	game.get("hands")[1] = [game.call("card_definition", "inspect")]
	game.get("hands")[100] = [game.call("card_definition", "bid")]
	assert(not game.call("place_bid", 1))
	assert(game.get("bid") == 0)
	assert(game.call("place_bid", 100))
	assert(game.get("bid") == 20 and game.get("leader") == 100 and game.get("turn_id") == 1)
	game.get("hands")[1] = [game.call("card_definition", "bid")]
	assert(game.call("place_bid", 1))
	assert(game.get("bid") == 40)
	assert(game.get("hands")[1].is_empty())
	assert(game.get("turn_id") == 100)
	var interrupt_game: Node = Auction.new()
	root.add_child(interrupt_game)
	interrupt_game.set("active_player_ids", [1, 100, 101])
	interrupt_game.set("active_bot_ids", [])
	interrupt_game.call("set_table_status", true, 3, 3)
	interrupt_game.set("phase", "auction")
	interrupt_game.set("auction_started", true)
	interrupt_game.set("turn_id", 1)
	interrupt_game.get("hands")[100] = [interrupt_game.call("card_definition", "bid")]
	assert(interrupt_game.call("place_bid", 100))
	assert(interrupt_game.get("leader") == 100 and interrupt_game.get("turn_id") == 101)
	assert(interrupt_game.call("state").get("leader_name", "") == interrupt_game.call("bidder_name", 100))
	var before_cash: int = game.get("cash")[1]
	game.call("buy_hint_for", 1)
	assert(game.get("cash")[1] == before_cash)
	assert(game.get("private_hint_indices")[1].size() == 1)
	assert(game.call("pass_turn", 100))
	assert(game.get("turn_id") == -1)
	for i in 3:
		game.call("_process", 2.1)
	assert(game.get("phase") == "appraisal")
	game.call("_process", 46.0)
	assert(game.get("phase") == "auction")
	assert(game.get("hands")[1].size() == 5)
	assert(game.get("energy_by_player")[1] == 3)
	game.get("hands")[1] = [game.call("card_definition", "publish")]
	game.call("submit_hand", [0], 1)
	assert(game.call("state")["hints"].size() == 2)
	assert(game.get("turn_id") == 1)
	var cash_before: Dictionary = game.get("cash").duplicate()
	var bias_before: int = game.get("bot_bias")[100]
	game.call("_apply_card_effect", {"id": "rumor"}, 1)
	assert(game.get("cash") == cash_before)
	assert(absi(int(game.get("bot_bias")[100]) - bias_before) == 35)
	assert(absi(int(game.get("public_rumor_shift"))) == 35)
	var draw_game: Node = Auction.new()
	root.add_child(draw_game)
	draw_game.set("active_player_ids", [1, 100])
	draw_game.call("set_table_status", true, 2, 2)
	draw_game.get("hands")[1] = [draw_game.call("card_definition", "draw")]
	draw_game.get("decks")[1] = [draw_game.call("card_definition", "bid"), draw_game.call("card_definition", "shield"), draw_game.call("card_definition", "inspect")]
	draw_game.call("submit_hand", [0], 1)
	assert(draw_game.get("hands")[1].size() == 2)
	assert(draw_game.get("decks")[1].size() == 1)
	assert(draw_game.get("energy_by_player")[1] == 2)
	var bot_game: Node = Auction.new()
	root.add_child(bot_game)
	bot_game.set("active_player_ids", [100, 1])
	bot_game.set("active_bot_ids", [100])
	bot_game.call("set_table_status", true, 2, 2)
	bot_game.get("hands")[100] = [bot_game.call("card_definition", "draw")]
	bot_game.get("decks")[100] = [bot_game.call("card_definition", "bid"), bot_game.call("card_definition", "shield")]
	bot_game.call("make_bot_bid")
	assert(bot_game.get("turn_id") == 100)
	assert(bot_game.get("hands")[100].size() == 2)
	assert(bot_game.get("energy_by_player")[100] == 2)
	var tactic_game: Node = Auction.new()
	root.add_child(tactic_game)
	tactic_game.set("active_player_ids", [100, 1])
	tactic_game.set("active_bot_ids", [100])
	tactic_game.set("bot_strategy", {100: 0})
	tactic_game.call("set_table_status", true, 2, 2)
	tactic_game.get("hands")[100] = [tactic_game.call("card_definition", "inspect")]
	tactic_game.get("private_hint_indices")[100] = []
	tactic_game.call("make_bot_bid")
	assert(tactic_game.get("last_play").cards[0].id == "inspect")
	assert(tactic_game.get("turn_id") == 100)
	var leave_game: Node = Auction.new()
	root.add_child(leave_game)
	leave_game.set("active_player_ids", [1, 100, 101])
	leave_game.call("set_table_status", true, 3, 3)
	leave_game.get("hands")[1] = [leave_game.call("card_definition", "bid")]
	assert(leave_game.call("place_bid", 1))
	assert(leave_game.get("turn_id") == 100)
	leave_game.call("set_active_players", [1, 101])
	assert(leave_game.get("turn_id") == 101)
	leave_game.call("set_active_players", [101])
	assert(leave_game.get("leader") == -1)
	assert(leave_game.get("bid") == 0)
	var flow_game: Node = Auction.new()
	root.add_child(flow_game)
	flow_game.set("active_player_ids", [1, 100])
	flow_game.set("active_bot_ids", [])
	flow_game.call("set_table_status", true, 2, 2)
	flow_game.get("hands")[1] = [flow_game.call("card_definition", "publish")]
	flow_game.call("submit_hand", [0], 1)
	assert(flow_game.get("public_pressure") == 1 and flow_game.get("turn_id") == 1)
	assert(flow_game.call("pass_turn", 1))
	flow_game.call("close_auction")
	assert(flow_game.get("round_route") == "rejected")
	flow_game.call("start_lot")
	assert(flow_game.get("hint_level") == 3)
	var deck_game: Node = Auction.new()
	root.add_child(deck_game)
	assert(card_count(deck_game, 100, "bid") == card_count(deck_game, 101, "bid"))
	deck_game.set("bot_strategy", {100: 0})
	deck_game.set("bot_fortune", {100: 80})
	deck_game.set("cycle", 1)
	var inspect_before := card_count(deck_game, 100, "inspect")
	deck_game.call("start_lot")
	assert(card_count(deck_game, 100, "inspect") == inspect_before)
	print("Turn auction test: PASS")
	quit()
