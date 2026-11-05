extends SceneTree
const Game = preload("res://scripts/auction_game.gd")
func counts(game: Node,id: int) -> Dictionary:
	var result := {"active":0,"owned":0,"bid":0}
	for entry in game.deck_view(id):
		result.active += int(entry.active)
		result.owned += int(entry.active)+int(entry.reserve)
		if entry.id == "bid": result.bid = int(entry.active)
	return result
func _init() -> void:
	for strategy in 3:
		var game := Game.new()
		game.reset_cards()
		game.start_lot()
		game.active_player_ids = [1,100]
		game.active_bot_ids = [100]
		game.bot_strategy[100] = strategy
		game.phase = "appraisal"
		var before := counts(game,100)
		assert(game.buy_market_pack(100))
		game.market_offers[100] = ["inspect","rumor","steal"]
		assert(game._shop_for_bot(100))
		var after := counts(game,100)
		assert(game.cash[100] == 430)
		assert(after.active == before.active+1 and after.owned == before.owned+1)
		var chosen: String = ["inspect","rumor","steal"][strategy]
		var found := false
		for entry in game.deck_view(100):
			if entry.id == chosen: found = int(entry.active) == 2
		assert(found)
		for purchase in 10:
			game.cash[100] = 500
			assert(game._shop_for_bot(100))
			assert(game.cash[100] == 430)
			assert(counts(game,100).active <= 15 and counts(game,100).bid >= 2)
		game.cash[100] = 159
		assert(not game._shop_for_bot(100))
		assert(not game._shop_for_bot(1))
		game.phase = "auction"
		assert(not game._shop_for_bot(100))
		game.free()
	print("AI paid packs, archetype choice, owned card conservation, 15 cap, bid reserve, cash floor: PASS")
	quit()
