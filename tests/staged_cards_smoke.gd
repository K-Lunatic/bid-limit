extends SceneTree
const Game = preload("res://scripts/auction_game.gd")
const UI = preload("res://scripts/auction_ui.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.reset_cards()
	game.start_lot()
	game.active_player_ids = [1,100]
	game.phase = "auction"
	game.turn_id = 1
	game.hands[1] = [game.card_definition("attack"),game.card_definition("rumor"),game.card_definition("bid")]
	game.energy_by_player[1] = 3
	game.call("_sync_local_hand")
	var ui := UI.new()
	root.add_child(ui)
	ui.setup(game)
	ui.render_state(game.state())
	ui.play_dropped_card(0)
	ui.play_dropped_card(1)
	assert(ui.selected_indices == [1])
	assert(game.turn_id == 1 and game.hands[1].size() == 3)
	assert(ui.submit_button.text.contains("카드 1장"))
	ui.submit_selected()
	assert(game.last_play.cards.size() == 1)
	assert(game.energy_by_player[1] == 2 and game.turn_id == 1)
	assert(ui.selected_indices.is_empty())
	assert(ui.played_panel.visible)
	ui.play_dropped_card(0)
	ui.submit_selected()
	assert(game.last_play.cards.size() == 1 and game.energy_by_player[1] == 1 and game.turn_id == 1)
	assert(game.pass_turn(1) and game.turn_id == 100)
	ui._process(2.6)
	ui.render_state(game.state())
	assert(not ui.played_panel.visible and not ui.played_background.visible)
	ui.render_state(game.state())
	assert(not ui.played_panel.visible)
	assert(ui.guide_label.text.contains(game.bidder_name(100)))
	game.last_play.sequence += 1
	ui.render_state(game.state())
	assert(ui.played_panel.visible)
	game.phase = "appraisal"
	ui.render_state(game.state())
	assert(not ui.played_panel.visible)
	var guest := Game.new()
	guest.set_authoritative(false)
	guest.apply_remote_state({"turn_name":"보풀왕 (AI)"})
	assert(guest.state().turn_name == "보풀왕 (AI)")
	guest.free()
	ui.queue_free()
	game.queue_free()
	await process_frame
	print("One-card action chain, explicit pass handoff: PASS")
	quit()
