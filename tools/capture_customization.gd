extends SceneTree
func _init() -> void: call_deferred("capture")
func capture() -> void:
	var scene := load("res://scenes/main_2d.tscn").instantiate() as Node
	root.add_child(scene)
	var lobby: Node
	for child in scene.get_children():
		if child is BidLobbyUI: lobby = child
	for combination in 12:
		var hair_style := combination/4
		var accessory := combination%4
		lobby.profile["hair_style"] = hair_style
		lobby.profile["accessory"] = accessory
		lobby.show_customization()
		await process_frame
		await physics_frame
		await RenderingServer.frame_post_draw
		var preview: SubViewportContainer
		for child in lobby.content.get_children():
			if child is HBoxContainer and child.get_child_count() > 0 and child.get_child(0) is SubViewportContainer:
				preview = child.get_child(0)
		assert(preview != null)
		var viewport := preview.get_child(0) as SubViewport
		var pixels := viewport.get_texture().get_image()
		var used := pixels.get_used_rect()
		assert(used.position.x > 0 and used.position.y > 0 and used.end.x < pixels.get_width() and used.end.y < pixels.get_height(), "Preview clipped at accessory %d: %s" % [accessory,used])
		assert(pixels.save_png("/private/tmp/bid-customization-pixels-%d-%d.png" % [hair_style,accessory]) == OK)
		assert(root.get_texture().get_image().save_png("/private/tmp/bid-customization-%d-%d.png" % [hair_style,accessory]) == OK)
	print("Native customization capture: 3 hairstyles x 4 accessories, no clipping")
	scene.queue_free()
	await process_frame
	quit()
