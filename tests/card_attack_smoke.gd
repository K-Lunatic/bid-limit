extends SceneTree

const Game = preload("res://scripts/auction_game.gd")

func _init() -> void:
	var game := Game.new()
	game.reset_cards()
	game.start_lot()
	game.active_player_ids = [1, 100, 101, 102]
	game.phase = "auction"
	game.turn_id = 1
	game.hands[1] = [game.card_definition("attack")]
	game.hands[100] = [game.card_definition("bid"), game.card_definition("shield")]
	game.set_player_identity(1, "양말대장", 2)
	game.play_card_indices([0], 1)
	var public_play: Dictionary = game.state().last_play
	assert(public_play.player_name == "양말대장" and public_play.weapon == 2)
	assert(public_play.cards[0].id == "attack")
	var client := Game.new()
	client.set_authoritative(false)
	client.apply_remote_state({"last_play": public_play})
	assert(client.state().last_play == public_play)
	client.free()
	assert(game.turn_id == 1 and game.card_blocked.has(100))
	assert(not game.place_bid(100))
	assert(game.pass_turn(1) and game.turn_id == 100)
	game.play_card_indices([0], 100)
	assert(game.card_blocked.has(100) and game.hands[100].size() == 3)
	game.play_card_indices([1], 100)
	assert(not game.card_blocked.has(100) and game.turn_id == 100)
	assert(game.energy_by_player[100] == 2)
	assert(game.pass_turn(100) and game.turn_id == 101)
	game.card_blocked.append(101)
	game.pass_turn(101)
	assert(not game.card_blocked.has(101))
	game.phase = "waiting"
	var money: int = game.cash[1]
	var reserved: int = game.reserves[1].size()
	for index in 4:
		assert(game.buy_market_pack(1))
		var offer: Array = game.market_offers[1].duplicate()
		assert(offer.size() == 3 and offer[0] != offer[1] and offer[1] != offer[2] and offer[0] != offer[2])
		assert(game.buy_market_card(1, str(offer[0])))
	assert(game.cash[1] == money - 280 and game.reserves[1].size() == reserved + 4)
	assert(not game.buy_market_card(1, "invalid"))
	game.phase = "auction"
	assert(not game.buy_market_card(1, "bid"))
	var steal_game := Game.new()
	steal_game.reset_cards()
	steal_game.start_lot()
	steal_game.active_player_ids = [1, 100]
	steal_game.phase = "auction"
	steal_game.turn_id = 1
	steal_game.hands[1] = [steal_game.card_definition("steal")]
	steal_game.hands[100] = [steal_game.card_definition("bid")]
	steal_game.play_card_indices([0], 1)
	assert(steal_game.hands[100].is_empty() and steal_game.hands[1].size() == 1)
	assert(int(steal_game.state().last_play.target_id) == 100)
	assert(str(steal_game.state().last_play.stolen_card_id) == "bid")
	steal_game.free()
	var random_game := Game.new()
	random_game.reset_cards()
	random_game.start_lot()
	random_game.hands[1] = []
	var random_card_id: String = random_game.draw_random_card_for(1)
	assert(not random_card_id.is_empty() and random_game.hands[1][0].id == random_card_id and random_card_id != "gacha")
	random_game.call("_apply_card_effect", {"id": "luck"}, 1)
	assert(random_game.announcement.contains("동전"))
	random_game.free()
	game.free()
	print("Card attack and defense: PASS")
	quit()
