extends SceneTree
const Game = preload("res://scripts/auction_game.gd")
const Network = preload("res://scripts/network_session_2d.gd")
func _init() -> void:
	var game := Game.new()
	game.reset_cards()
	game.active_player_ids = [1]
	game.phase = "waiting"
	game.cash[1] = 7000
	var active_before: int = game.decks[1].size() + game.hands[1].size()
	assert(game.market_offers[1].is_empty())
	assert(not game.buy_market_card(1,"bid"))
	for index in 30:
		assert(game.buy_market_pack(1))
		assert(not game.buy_market_pack(1))
		var offer: Array = game.market_offers[1].duplicate()
		assert(offer.size() == 3)
		assert(game.buy_market_card(1, str(offer[0])))
	assert(game.reserves[1].size() == 30)
	assert(game.cash[1] == 4900)
	assert(game.decks[1].size() + game.hands[1].size() == active_before)
	game.cash[1] = 69
	var offer: Array = game.market_offers[1].duplicate()
	assert(not game.buy_market_pack(1))
	assert(game.market_offers[1] == offer)
	var client := Game.new()
	client.set_authoritative(false)
	client.apply_remote_state({"market_offer": offer})
	assert(client.state().market_offer == offer)
	var net := Network.new()
	var public_state: Dictionary = net.make_public_auction_state(game.state())
	assert(not public_state.has("market_offer") and not public_state.has("market_offers"))
	net.free()
	client.free()
	game.free()
	print("Random market offers, unlimited collection and privacy: PASS")
	quit()
