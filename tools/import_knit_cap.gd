extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var source := Image.load_from_file(args[0])
	assert(source != null)
	source.convert(Image.FORMAT_RGBA8)
	var crop := source.get_used_rect()
	assert(crop.has_area())
	var sprite := source.get_region(crop)
	sprite.resize(46,26,Image.INTERPOLATE_NEAREST)
	var runtime := Image.create(48,28,false,Image.FORMAT_RGBA8)
	runtime.fill(Color.TRANSPARENT)
	for y in 26:
		for x in 46:
			var color := sprite.get_pixel(x,y)
			color.a = 1.0 if color.a >= 0.5 else 0.0
			runtime.set_pixel(x+1,y+1,color)
	assert(runtime.save_png("res://assets/sprites/sock_puppet/accessories/knit-cap-v1.png") == OK)
	print("Knit cap: 48x28, nearest, binary native alpha, transparent gutter: PASS")
	quit()
