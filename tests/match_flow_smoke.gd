extends SceneTree
const Game = preload("res://scripts/auction_game.gd")
func _init() -> void:
	var completed := 0
	for seed_value in 30:
		var game := Game.new()
		game.reset_cards()
		game.rng.seed = seed_value
		game.active_player_ids = [1,100,101,102]
		game.active_bot_ids = [1,100,101,102]
		game.start_lot()
		game.set_table_status(true,4,4)
		var ticks := 0
		while game.phase != "finished" and ticks < 12000:
			game._process(0.25)
			ticks += 1
			for id in game.active_player_ids:
				assert(int(game.cash.get(id,0)) >= 0)
				assert(game.hands.get(id,[]).size() <= game.MAX_HAND_SIZE)
			assert(game.turn_id == -1 or game.active_player_ids.has(game.turn_id))
		assert(game.phase == "finished", "Match stalled, seed=%d phase=%s turn=%d" % [seed_value,game.phase,game.turn_id])
		assert(game.cycle == game.LOTS_PER_MATCH)
		assert(game.final_scores.size() == 4)
		completed += 1
		game.free()
	print("30 four-player automated matches: 5 lots, finish, hand cap and nonnegative cash: PASS (%d)" % completed)
	quit()
