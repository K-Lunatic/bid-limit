extends SceneTree

const PuppetScript = preload("res://scripts/sock_puppet_2d.gd")

func _init() -> void:
	var puppet := PuppetScript.new()
	get_root().add_child(puppet)
	call_deferred("_verify", puppet)

func _verify(puppet: Node) -> void:
	await process_frame
	var ok := bool(puppet.get("using_body_only"))
	var parts := puppet.get("parts") as Node
	ok = ok and parts != null and bool(parts.get("integrated_base"))
	if not ok:
		push_error("body-only base and accessory layer were not composed")
		quit(1)
		return
	print("Composite parts wiring: PASS (body-only base + accessory overlay)")
	quit()
