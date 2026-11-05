extends SceneTree
const Game = preload("res://scripts/auction_game.gd")
func _init() -> void:
	var game := Game.new()
	game.reset_cards()
	game.start_lot()
	game.active_player_ids = [1,100,101]
	game.active_bot_ids = []
	game.phase = "auction"
	game.auction_started = true
	game.turn_id = 1
	for id in game.active_player_ids:
		game.hands[id] = [game.card_definition("bid"),game.card_definition("bid")]
	assert(game.place_bid(1))
	assert(game.place_bid(101))
	assert(game.turn_id == 1 and game.bid == 40 and game.leader == 101)
	assert(game.pass_turn(1))
	assert(game.pass_turn(100))
	game._process(2.1)
	assert(game.hammer == 1)
	assert(game.place_bid(1))
	assert(game.hammer == 0 and game.bid == 60 and game.leader == 1)
	assert(not game.place_bid(1))
	assert(not game.place_bid(999))
	game.card_blocked.append(100)
	assert(not game.place_bid(100))
	game.card_blocked.clear()
	assert(game.place_bid(100))
	assert(game.hammer == 0 and game.bid == 80 and game.leader == 100)
	assert(game.pass_turn(101))
	assert(game.pass_turn(1))
	assert(game.turn_id == -1)
	for index in 3: game._process(2.1)
	assert(game.phase == "appraisal")
	assert(not game.place_bid(100))
	game.free()
	print("Interrupt bidding, hammer rebid, block, pass and close validation: PASS")
	quit()
