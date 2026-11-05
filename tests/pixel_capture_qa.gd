extends SceneTree

const ArtLayout = preload("res://scripts/art_layout.gd")
const BODY_DIR := "res://assets/sprites/sock_puppet/cozy_v3/frames/"

func _init() -> void:
	var ok := true
	var capture_sheet := Image.create(96 * 4 * 8, 128 * 4, false, Image.FORMAT_RGBA8)
	print("Pixel capture QA anchors: baseline_y=%d head=%s eyes=%s mouth=%s carry=%s" % [
		ArtLayout.BODY_BASELINE_PIXEL_Y,
		ArtLayout.HEAD_ANCHOR_PIXEL,
		ArtLayout.EYE_ANCHOR_PIXEL,
		ArtLayout.MOUTH_ANCHOR_PIXEL,
		ArtLayout.CARRY_ANCHOR_PIXEL,
	])
	for frame_index in 8:
		var path := ProjectSettings.globalize_path(BODY_DIR + "%02d.png" % frame_index)
		var image := Image.load_from_file(path)
		if image == null or image.get_size() != ArtLayout.PIXEL_FRAME_SIZE:
			push_error("frame %02d is not exactly 96x128" % frame_index)
			ok = false
			continue
		var used := image.get_used_rect()
		var bottom := used.position.y + used.size.y
		if bottom != ArtLayout.BODY_BASELINE_PIXEL_Y:
			push_error("frame %02d baseline drift: y=%d" % [frame_index, bottom])
			ok = false
		if used.size.x > 72 or used.position.x < 12 or used.position.x + used.size.x > 84:
			push_error("frame %02d silhouette bounds drift: %s" % [frame_index, used])
			ok = false
		for corner in [Vector2i(0, 0), Vector2i(95, 0), Vector2i(0, 127), Vector2i(95, 127)]:
			if image.get_pixelv(corner).a > 0.0:
				push_error("frame %02d opaque corner: %s" % [frame_index, corner])
				ok = false
		var enlarged := image.duplicate()
		enlarged.resize(96 * 4, 128 * 4, Image.INTERPOLATE_NEAREST)
		capture_sheet.blit_rect(enlarged, Rect2i(Vector2i.ZERO, enlarged.get_size()), Vector2i(frame_index * 96 * 4, 0))
		_mark_anchors(capture_sheet, frame_index * 96 * 4)
		print("capture %02d used=%s bottom=%d" % [frame_index, used, bottom])
	if not _anchors_fit_canvas():
		push_error("pixel anchors leave the 96x128 canvas")
		ok = false
	if not ok:
		quit(1)
		return
	capture_sheet.save_png("/private/tmp/bid-pixel-capture-qa.png")
	print("Pixel capture sheet: /private/tmp/bid-pixel-capture-qa.png")
	print("Pixel capture QA: PASS")
	quit()

func _mark_anchors(sheet: Image, x_offset: int) -> void:
	for anchor in [ArtLayout.HEAD_ANCHOR_PIXEL, ArtLayout.EYE_ANCHOR_PIXEL, ArtLayout.MOUTH_ANCHOR_PIXEL, ArtLayout.CARRY_ANCHOR_PIXEL]:
		var center := Vector2i(x_offset + anchor.x * 4, anchor.y * 4)
		for step in 8:
			if center.x + step < sheet.get_width():
				sheet.set_pixel(center.x + step, center.y, Color(1.0, 0.25, 0.25, 0.8))
			if center.x - step >= x_offset:
				sheet.set_pixel(center.x - step, center.y, Color(1.0, 0.25, 0.25, 0.8))
			if center.y + step < sheet.get_height():
				sheet.set_pixel(center.x, center.y + step, Color(1.0, 0.25, 0.25, 0.8))
			if center.y - step >= 0:
				sheet.set_pixel(center.x, center.y - step, Color(1.0, 0.25, 0.25, 0.8))

func _anchors_fit_canvas() -> bool:
	for anchor in [ArtLayout.HEAD_ANCHOR_PIXEL, ArtLayout.EYE_ANCHOR_PIXEL, ArtLayout.MOUTH_ANCHOR_PIXEL, ArtLayout.CARRY_ANCHOR_PIXEL]:
		if anchor.x < 0 or anchor.x >= ArtLayout.PIXEL_FRAME_SIZE.x or anchor.y < 0 or anchor.y >= ArtLayout.PIXEL_FRAME_SIZE.y:
			return false
	return true
