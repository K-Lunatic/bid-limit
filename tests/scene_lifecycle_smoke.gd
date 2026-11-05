extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for index in 5:
		var scene := load("res://scenes/main_2d.tscn").instantiate() as Node
		root.add_child(scene)
		var network: Node = scene.get("network")
		assert(network.create_host() == OK)
		scene.start_game()
		await process_frame
		await process_frame
		scene.queue_free()
		await process_frame
		await process_frame
		var orphan_count := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		assert(orphan_count == baseline, "Orphans grew at cycle %d: %d -> %d" % [index,baseline,orphan_count])
	print("Five full scene lifecycles, no orphan node growth: PASS")
	quit()
