extends SceneTree

const Puppet = preload("res://scripts/sock_puppet_2d.gd")

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var stage := Node2D.new()
	root.add_child(stage)
	for row in 4:
		for frame in 8:
			var puppet := Puppet.new()
			puppet.setup("", Color("d95b68"), Color("35a7d7"), false, 0, 0, 1 + row % 2)
			stage.add_child(puppet)
			puppet.set_physics_process(false)
			puppet.position = Vector2(frame * 160 + 80, row * 180 + 122)
			var sprite: AnimatedSprite2D = puppet.pixel_sprite
			sprite.sprite_frames.add_animation("qa")
			for index in 8:
				sprite.sprite_frames.add_frame("qa", load("res://assets/sprites/sock_puppet/cozy_v3/frames/%02d.png" % index))
			sprite.animation = "qa"
			sprite.stop()
			sprite.frame = frame
			sprite.position = Vector2(0,-54)
			sprite.scale = Vector2(-1 if row >= 2 else 1, 1)
			puppet.parts.position = sprite.position
			puppet.parts.scale = sprite.scale
			puppet.parts.call("set_source_frame", frame)
			puppet.card_arc.hide()
			var label := Label.new()
			label.text = "%02d %s %s" % [frame, "안경" if row % 2 == 0 else "모자", "←" if row >= 2 else "→"]
			label.position = Vector2(frame*160+10,row*180+4)
			label.add_theme_font_size_override("font_size", 14)
			stage.add_child(label)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-accessories-32.png") == OK)
	print("Accessory capture: 8 frames x 2 accessories x 2 directions")
	stage.queue_free()
	await process_frame
	quit()
