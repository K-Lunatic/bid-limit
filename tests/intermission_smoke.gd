extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var scene := load("res://scenes/main_2d.tscn").instantiate() as Node
	root.add_child(scene)
	var network: Node = scene.get("network")
	assert(network.create_host() == OK)
	network.add_bots()
	scene.start_game()
	await process_frame
	await process_frame
	var game: Node = scene.get("game")
	game.set_process(false)
	assert(network.claim_seat(1,0))
	network._update_table_status()
	await process_frame
	assert(game.phase == "auction")
	assert(scene.get("player").get_meta("seat") == 0)
	assert(scene.get("player").position.x == network.SEAT_POSITIONS[0].x)
	scene.set("touch_move",Vector2.RIGHT)
	scene._physics_process(0.0)
	assert(scene.get("player").external_input == Vector2.ZERO)
	Input.action_press("ui_right")
	var seated_x: float = scene.get("player").position.x
	scene.get("player")._physics_process(0.1)
	assert(scene.get("player").position.x == seated_x)
	Input.action_release("ui_right")
	game.close_auction()
	game.emit_state()
	await process_frame
	await process_frame
	assert(game.phase == "appraisal" and game.timer == game.INTERMISSION_SECONDS)
	assert(network.players[1].seat == -1 and not network.players[1].ready)
	assert(scene.get("player").get_meta("seat") == -1)
	assert(game.table_count == 3 and not game.table_ready)
	scene._physics_process(0.0)
	assert(scene.get("player").external_input == Vector2.RIGHT)
	var before: float = network.players[1].position.x
	network.host_step(0.1)
	assert(network.players[1].position.x > before)
	game._process(46.0)
	assert(game.phase == "waiting" and game.cycle == 2)
	assert(network.claim_seat(1,0))
	network._update_table_status()
	assert(game.phase == "auction")
	game.close_auction()
	game.emit_state()
	await process_frame
	await process_frame
	assert(game.phase == "appraisal")
	assert(network.claim_seat(1,0))
	network._update_table_status()
	assert(game.phase == "auction" and game.cycle == 3)
	scene.queue_free()
	await process_frame
	print("Intermission: release, movement, 45s wait, explicit seating and early ready: PASS")
	quit()
