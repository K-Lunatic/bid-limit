extends SceneTree

const Auction = preload("res://scripts/auction_game.gd")

func _init() -> void:
	call_deferred("run_smoke")

func run_smoke() -> void:
	var game: Node = Auction.new()
	root.add_child(game)
	game.set("active_player_ids", [1])
	game.set("phase", "waiting")
	game.set("cash", {1: 0})
	game.call("register_player", 1)
	assert(game.call("borrow_loan", 1))
	assert(game.get("cash")[1] == 150)
	assert(game.get("locked_energy")[1] == 1)
	assert(game.get("debt_by_player")[1] == 180)
	assert(game.call("borrow_loan", 1))
	assert(game.get("locked_energy")[1] == 2)
	game.get("cash")[1] = 1000
	assert(game.call("repay_loan", 1))
	assert(game.get("debt_by_player")[1] == 0 and game.get("locked_energy")[1] == 0)
	assert(game.get("energy_by_player")[1] == 3)
	game.get("cash")[1] = 100
	assert(game.call("play_roulette", 1, 20))
	assert(game.get("roulette_used")[1])
	assert(game.get("cash")[1] >= 0)
	assert(not game.call("play_roulette", 1, 20))
	print("Finance systems smoke test: PASS")
	quit()
