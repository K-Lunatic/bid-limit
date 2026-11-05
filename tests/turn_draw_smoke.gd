extends SceneTree

const Game = preload("res://scripts/auction_game.gd")

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var game := Game.new()
	root.add_child(game)
	game.active_player_ids = [1,100]
	game.begin_auction()
	assert(game.hands[1].size() == 5)
	game.hands[100] = []
	game.decks[100] = []
	game.discards[100] = [game.card_definition("inspect"),game.card_definition("shield")]
	game.advance_turn(1)
	assert(game.turn_id == 100 and game.hands[100].size() == 1)
	assert(game.decks[100].size() == 1 and game.discards[100].is_empty())
	game.advance_turn(100)
	assert(game.hands[1].size() == 5)
	assert(game.bot_cooldown == 4.0)
	game.free()
	print("Turn draw, reshuffle and five-card limit: PASS")
	quit()
