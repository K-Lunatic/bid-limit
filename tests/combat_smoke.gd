extends SceneTree

const NetworkScript = preload("res://scripts/network_session.gd")

func _init() -> void:
	call_deferred("run_smoke")

func run_smoke() -> void:
	var session: Node = NetworkScript.new()
	root.add_child(session)
	var result: Error = session.call("create_host")
	if result != OK:
		print("Combat smoke test: SKIP (WebRTC unavailable in headless runtime: %s)" % result)
		quit()
		return
	session.players[1]["position"] = Vector3(0, 0, 0)
	session.players[100]["position"] = Vector3(1, 0, 0)
	session.call("resolve_attack", 1)
	assert(session.players[100]["hp"] == 2)
	session.call("apply_defense", 100)
	session.attack_cooldowns[1] = 0.0
	session.call("resolve_attack", 1)
	assert(session.players[100]["hp"] == 2)
	print("Combat smoke test: PASS")
	quit()
