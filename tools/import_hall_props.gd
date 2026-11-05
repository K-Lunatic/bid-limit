extends SceneTree
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var source := Image.load_from_file(args[0])
	assert(source != null and source.has_mipmaps() == false)
	source.convert(Image.FORMAT_RGBA8)
	var atlas := Image.create(192,192,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var cell := Vector2i(source.get_width()/2,source.get_height()/2)
	for row in 2:
		for column in 2:
			var sprite := source.get_region(Rect2i(Vector2i(column,row)*cell,cell))
			sprite.resize(96,96,Image.INTERPOLATE_NEAREST)
			var opaque := 0
			var transparent := 0
			for y in 96:
				for x in 96:
					var alpha := sprite.get_pixel(x,y).a
					if alpha > 0.5: opaque += 1
					if alpha < 0.01: transparent += 1
			assert(opaque > 200 and transparent > 1000, "Invalid prop alpha or empty cell")
			atlas.blit_rect(sprite,Rect2i(0,0,96,96),Vector2i(column,row)*96)
	assert(atlas.save_png("res://assets/maps/props/hall-props-v1.png") == OK)
	print("Hall props: 4 cells, 96px nearest, native alpha: PASS")
	quit()
