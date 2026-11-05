extends SceneTree
const Puppet = preload("res://scripts/sock_puppet_2d.gd")
func _init() -> void: call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(288,1024)
	root.content_scale_size = Vector2i(288,1024)
	var stage := Node2D.new()
	root.add_child(stage)
	var colors := [Color("35a7d7"),Color("e4ad5d"),Color("ae78c8")]
	for row in 8:
		for index in 3:
			var puppet := Puppet.new()
			puppet.setup("",Color("e15a67"),Color("35a7d7"))
			stage.add_child(puppet)
			puppet.set_physics_process(false)
			puppet.position = Vector2(48+index*96,64+row*128)
			puppet.set_accessory(0,0)
			puppet.set_hair_color(colors[index])
			assert(puppet.parts.accessory == 0 and puppet.parts.hair_style == 0)
			puppet.pixel_sprite.sprite_frames.add_animation("qa")
			puppet.pixel_sprite.sprite_frames.add_frame("qa",load("res://assets/sprites/sock_puppet/cozy_v3/frames/%02d.png" % row))
			puppet.pixel_sprite.animation = "qa"
			puppet.pixel_sprite.stop()
			puppet.pixel_sprite.position = Vector2.ZERO
			puppet.pixel_sprite.scale = Vector2.ONE
			puppet.parts.position = Vector2.ZERO
			puppet.parts.scale = Vector2.ONE
			puppet.parts.set_source_frame(row)
			puppet.card_arc.hide()
			assert(puppet.pixel_sprite.material.get_shader_parameter("hair_tint") == colors[index])
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	assert(pixels.save_png("/private/tmp/bid-hair-colors.png") == OK)
	var changed_hair := 0
	var checked_body := 0
	for row in 8:
		var source: Image = load("res://assets/sprites/sock_puppet/cozy_v3/frames/%02d.png" % row).get_image()
		for y in 128:
			for x in 96:
				var original := source.get_pixel(x,y)
				var first := pixels.get_pixel(x,y+row*128)
				var second := pixels.get_pixel(x+96,y+row*128)
				if original.a < 0.99 and first != second: changed_hair += 1
				elif original.a >= 0.99:
					assert(first == second, "Hair recolor altered non-hair pixel at frame %d: %d,%d" % [row,x,y])
					checked_body += 1
	assert(changed_hair > 100 and checked_body > 100)
	print("Native hair mask GPU QA: changed hair=%d, unchanged body/face=%d: PASS" % [changed_hair,checked_body])
	stage.queue_free()
	await process_frame
	quit()
