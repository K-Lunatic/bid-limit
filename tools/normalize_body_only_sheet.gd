extends SceneTree

const ArtLayout = preload("res://scripts/art_layout.gd")
const SOURCE := "res://assets/sprites/sock_puppet/body_only/body-only-master-sheet-v1.png"
const OUTPUT_DIR := "res://assets/sprites/sock_puppet/body_only/frames/"
const FRAME_SIZE := ArtLayout.PIXEL_FRAME_SIZE
const TARGET_BOTTOM := ArtLayout.BODY_BASELINE_PIXEL_Y

func _init() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if image == null:
		push_error("missing body-only source")
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for frame_index in 8:
		var left := int(round(float(frame_index) * image.get_width() / 8.0))
		var right := int(round(float(frame_index + 1) * image.get_width() / 8.0))
		var region := image.get_region(Rect2i(left, 0, right - left, image.get_height()))
		_key_black(region)
		var used := region.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			push_error("empty body frame %d" % frame_index)
			quit(1)
			return
		var cropped := region.get_region(used)
		var scale := minf(72.0 / float(cropped.get_width()), 100.0 / float(cropped.get_height()))
		var target_size := Vector2i(maxi(1, round(cropped.get_width() * scale)), maxi(1, round(cropped.get_height() * scale)))
		cropped.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
		var frame := Image.create(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
		var dst := Vector2i((FRAME_SIZE.x - target_size.x) / 2, TARGET_BOTTOM - target_size.y)
		frame.blit_rect(cropped, Rect2i(Vector2i.ZERO, target_size), dst)
		frame.save_png(ProjectSettings.globalize_path(OUTPUT_DIR + "%02d.png" % frame_index))
		print("body frame %02d source=%s output=%s" % [frame_index, used, Rect2i(dst, target_size)])
	print("Body-only normalization: PASS")
	quit()

func _key_black(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.r < 0.035 and pixel.g < 0.035 and pixel.b < 0.035:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
