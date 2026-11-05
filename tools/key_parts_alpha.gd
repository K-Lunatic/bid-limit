extends SceneTree

const SOURCE_DIR := "res://assets/sprites/sock_puppet/parts/v1/"
const OUTPUT_DIR := "res://assets/sprites/sock_puppet/parts/v2/"
const PARTS := [
	"mouth_closed", "mouth_open", "mouth_wide", "eyes_buttons", "hair_blue",
	"glasses_round", "cap_red", "badge_gold"
]

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for part_id in PARTS:
		var source := load(SOURCE_DIR + part_id + ".png") as Texture2D
		if source == null:
			push_error("missing source: %s" % part_id)
			continue
		var image := source.get_image()
		for y in image.get_height():
			for x in image.get_width():
				var pixel := image.get_pixel(x, y)
				if pixel.r < 0.035 and pixel.g < 0.035 and pixel.b < 0.035:
					pixel.a = 0.0
					image.set_pixel(x, y, pixel)
		var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + part_id + ".png")
		image.save_png(output_path)
		print("wrote %s used=%s" % [part_id, image.get_used_rect()])
	print("Pixel alpha key: PASS")
	quit()
