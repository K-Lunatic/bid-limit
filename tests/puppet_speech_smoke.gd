extends SceneTree
const Puppet = preload("res://scripts/sock_puppet_2d.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	for authored in [false,true]:
		var puppet: Node = load("res://scenes/sock_puppet.tscn").instantiate() if authored else Puppet.new()
		root.add_child(puppet)
		puppet.set_physics_process(false)
		puppet._physics_process(0)
		assert(puppet.current_animation == "waiting")
		assert(puppet.pixel_sprite.sprite_frames.get_frame_count("waiting") >= 1)
		puppet.say("안녕하세요")
		puppet._physics_process(0.1)
		assert(puppet.current_animation == "talk")
		puppet.play_action("bid",0.58)
		puppet._physics_process(0.1)
		assert(puppet.current_animation == "bid")
		puppet._physics_process(0.6)
		assert(puppet.current_animation == "talk")
		puppet._physics_process(6)
		assert(puppet.current_animation == "waiting")
		for style in 3:
			puppet.set_accessory(style,0)
			assert(puppet.parts.hair_sprite.texture == puppet.parts.HAIRSTYLES[style])
		puppet.queue_free()
		await process_frame
	print("Authored and dynamic puppets: closed idle, speech only talk, actions complete and 3 hair silhouettes: PASS")
	quit()
