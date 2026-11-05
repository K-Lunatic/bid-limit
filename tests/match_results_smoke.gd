extends SceneTree
const Game = preload("res://scripts/auction_game.gd")
const UI = preload("res://scripts/auction_ui.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.reset_cards()
	game.start_lot()
	game.active_player_ids = [1,100,101,102]
	game.cash = {1:400,100:500,101:300,102:10}
	game.inventories[1] = [{"appraisal":200}]
	game.debt_by_player[1] = 100
	game.player_names[1] = "결산테스트"
	assert(game.state().final_standings.is_empty())
	game.finish_match()
	var rows: Array = game.state().final_standings
	assert(rows.size() == 4 and rows[0].score == 500 and rows[1].score == 500)
	assert(rows[0].rank == 1 and rows[1].rank == 1 and rows[2].rank == 3)
	assert(game.announcement.contains("공동 우승"))
	for row in rows: assert(int(row.score) == int(row.cash)+int(row.goods)-int(row.debt))
	var client := Game.new()
	client.set_authoritative(false)
	client.apply_remote_state(game.state())
	assert(client.state().final_standings == rows)
	var ui := UI.new()
	root.add_child(ui)
	ui.setup(game)
	assert(ui.result_panel.visible and ui.result_grid.get_child_count() == 25)
	assert(not ui.card_fan.visible)
	game.phase = "waiting"
	ui.render_state(game.state())
	assert(not ui.result_panel.visible)
	client.free()
	ui.queue_free()
	game.queue_free()
	await process_frame
	print("Results: net assets, tied rank, nickname, guest snapshot, result UI and cleanup: PASS")
	quit()
