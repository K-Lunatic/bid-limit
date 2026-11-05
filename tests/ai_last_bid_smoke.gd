extends SceneTree
const Game = preload("res://scripts/auction_game.gd")
func _init() -> void:
	var game := Game.new()
	game.reset_cards()
	game.start_lot()
	game.phase = "auction"
	game.auction_started = true
	game.active_player_ids = [1,100]
	game.active_bot_ids = [100]
	game.leader = 1
	game.bid = 20
	game.turn_id = -1
	game.hammer = 1
	game.timer = 2.0
	game.bot_cooldown = 1.2
	game.bot_bias[100] = 10000
	game.hands[100] = [game.card_definition("bid")]
	game._process(1.0)
	assert(game.turn_id == -1 and game.bid == 20)
	game._process(0.3)
	assert(game.leader == 100 and game.bid == 40 and game.hammer == 0)
	assert(game.turn_id == 1)
	game.leader = 1
	game.turn_id = -1
	game.hands[100] = [game.card_definition("bid")]
	game.folded = [100]
	assert(not game._try_bot_last_bid())
	game.folded.clear()
	game.cash[100] = 59
	assert(not game._try_bot_last_bid())
	game.cash[100] = 60
	game.bot_bias[100] = -10000
	assert(not game._try_bot_last_bid())
	game.bot_bias[100] = 10000
	game.card_blocked.append(100)
	assert(not game._try_bot_last_bid())
	game.card_blocked.clear()
	game.hands[100] = []
	assert(not game._try_bot_last_bid())
	game.free()
	print("AI last bid delay, valuation, fold, cash, card and block: PASS")
	quit()
