extends SceneTree
const Network = preload("res://scripts/network_session_2d.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	var network := Network.new()
	root.add_child(network)
	network.local_peer_id = 2
	var events := []
	network.host_disconnected.connect(func() -> void: events.append(true))
	network._physics_process(9.0)
	assert(not network.host_lost)
	network.receive_snapshot({})
	network._physics_process(7.0)
	assert(not network.host_lost)
	network.receive_snapshot({})
	assert(network.host_silence == 0)
	network._physics_process(7.0)
	assert(not network.host_lost)
	network._physics_process(1.1)
	assert(network.host_lost and events.size() == 1)
	network.handle_disconnect(1)
	assert(events.size() == 1)
	network.receive_room_started()
	assert(not network.room_has_started)
	network.queue_free()
	await process_frame
	print("Host silence: first contact, refresh, 8s loss, idempotence, late start blocked: PASS")
	quit()
