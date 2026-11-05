extends SceneTree

const Game = preload("res://scripts/auction_game.gd")
const Network = preload("res://scripts/network_session_2d.gd")

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game := Game.new()
	root.add_child(game)
	assert(not game.change_deck_card(1,"gacha",true))
	assert(game.change_deck_card(1,"inspect",false))
	assert(game.reserves[1].size() == 1)
	assert(game.change_deck_card(1,"inspect",true))
	assert(game.reserves[1].is_empty())
	assert(not game.change_deck_card(1,"inspect",true))
	assert(game.change_deck_card(1,"bid",false))
	assert(game.change_deck_card(1,"bid",false))
	assert(not game.change_deck_card(1,"bid",false))
	assert(game.change_deck_card(1,"inspect",false))
	assert(game.change_deck_card(1,"draw",false))
	assert(not game.change_deck_card(1,"shield",false))
	var owned := 0
	var active := 0
	for card in game.deck_view(1):
		owned += int(card.active) + int(card.reserve)
		active += int(card.active)
	assert(owned == 12 and active == 8)
	game.begin_auction()
	assert(game.hands[1].size() == 5)
	assert(not game.change_deck_card(1,"inspect",true))
	assert(game.dirty_decks.is_empty())
	var network := Network.new()
	var public := network.make_public_auction_state(game.state())
	assert(not public.has("deck_views") and not public.has("deck_view"))
	var guest := Game.new()
	guest.authoritative = false
	guest.apply_remote_state({"deck_view":game.deck_view(1),"phase":"waiting"})
	assert(guest.state().deck_view == game.deck_view(1))
	guest.free()
	network.free()
	game.free()
	print("Deck ownership, 8..15 bound, bid minimum, shuffle and privacy: PASS")
	quit()
