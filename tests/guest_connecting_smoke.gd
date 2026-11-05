extends SceneTree

const Game = preload("res://scripts/auction_game.gd")

func _init() -> void:
	call_deferred("run_smoke")

func run_smoke() -> void:
	var guest := Game.new()
	guest.set_authoritative(false)
	root.add_child(guest)
	await process_frame
	assert(guest.get("phase") == "connecting")
	assert(guest.get("lot").is_empty())
	assert(guest.get("announcement") == "방장과 경매 상태를 연결하는 중입니다.")
	guest.apply_remote_state({
		"phase": "waiting",
		"lot": {"name": "무명 배지", "option_count": 5},
		"table_count": 1,
		"table_total": 2,
	})
	assert(guest.get("phase") == "waiting")
	assert(guest.get("lot").get("name") == "무명 배지")
	guest.free()
	print("Guest connecting state smoke test: PASS")
	quit()
