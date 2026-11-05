extends SceneTree

func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/npc/sacred-hand-master-v1.png"))
	assert(image != null)
	assert(image.get_pixel(0,0).a == 0.0, "NPC master must have true alpha")
	var sprite := image.get_region(image.get_used_rect())
	sprite.resize(96,128,Image.INTERPOLATE_NEAREST)
	assert(sprite.save_png(ProjectSettings.globalize_path("res://assets/npc/sacred-hand-v1.png")) == OK)
	print("Sacred hand: native alpha, 96x128 nearest import PASS")
	quit()
