extends SceneTree

const Session = preload("res://scripts/network_session_2d.gd")

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var session := Session.new()
	root.add_child(session)
	assert(session.create_host() == OK)
	assert(session.players.size() == 1)
	var starts: Array = []
	session.room_started.connect(func() -> void: starts.append(true))
	session.players[2] = session.initial_state(Vector2(1300, 520))
	assert(session.start_room(true))
	assert(not session.room_has_started and starts.is_empty())
	assert(session.players.size() == 2)
	session.handle_disconnect(2)
	assert(session.start_room(true))
	assert(session.players.size() == 4 and starts.size() == 1)
	assert(not session.start_room(true))
	session.receive_room_started()
	assert(starts.size() == 1)
	assert(session.serialize_snapshot().room_started)
	var seats: Array = []
	for member in session.players.values():
		if member.bot:
			assert(not seats.has(member.seat))
			seats.append(member.seat)
	assert(seats.size() == 3)
	session.free()
	print("Lobby start, connecting guard, AI seats, idempotency: PASS")
	quit()
