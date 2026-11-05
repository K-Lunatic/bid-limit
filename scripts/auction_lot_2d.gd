@tool
class_name AuctionLot2D
extends Node2D

const ArtLayout = preload("res://scripts/art_layout.gd")

var carrier: Node2D
var home_position := Vector2.ZERO
var bob_time := 0.0
var art_id := "badge"
var lot_name := "감정품"

func _ready() -> void:
	home_position = global_position
	if Engine.is_editor_hint(): set_process(false)

func setup(at: Vector2) -> void:
	home_position = at
	global_position = at
	z_index = 4
	queue_redraw()

func set_lot(value: Dictionary) -> void:
	lot_name = str(value.get("name", "감정품"))
	art_id = str(value.get("art_id", "badge"))
	queue_redraw()

func attach_to(target: Node2D) -> void:
	carrier = target
	visible = true

func release_to_stage() -> void:
	carrier = null
	global_position = home_position
	visible = true

func _process(delta: float) -> void:
	bob_time += delta
	if is_instance_valid(carrier):
		var direction := int(carrier.get("facing"))
		var destination := carrier.global_position + Vector2(ArtLayout.LOT_CARRY_OFFSET.x * direction, ArtLayout.LOT_CARRY_OFFSET.y + sin(bob_time * 3.0) * 3.0)
		global_position = global_position.lerp(destination, 1.0 - exp(-delta * 7.0))
		rotation = sin(bob_time * 2.0) * 0.08
	else:
		global_position = home_position + Vector2(0, sin(bob_time * 2.0) * 3.0)
	queue_redraw()

func _draw() -> void:
	_draw_scaled_ellipse(Vector2(0, 20), Vector2(24, 7), Color(0.02, 0.02, 0.05, 0.28))
	match art_id:
		"bottle": _draw_bottle()
		"badge": _draw_badge()
		"puppet": _draw_puppet()
		"trunk": _draw_trunk()
		"teacup": _draw_teacup()
		"mask": _draw_mask()
		"spool": _draw_spool()
		"clock": _draw_clock()
		"letter": _draw_letter()
		"frame": _draw_frame()
		_: _draw_badge()
	draw_string(ThemeDB.fallback_font, Vector2(-52, 39), lot_name.left(12), HORIZONTAL_ALIGNMENT_CENTER, 104, 7, Color("fff0c2"))

func _draw_scaled_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(radius.x / radius.y, 1.0))
	draw_circle(Vector2.ZERO, radius.y, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_bottle() -> void:
	draw_rect(Rect2(-11, -18, 22, 35), Color("4b7880"))
	draw_rect(Rect2(-7, -26, 14, 10), Color("76aeb0"))
	draw_rect(Rect2(-6, -30, 12, 5), Color("b8794e"))
	draw_rect(Rect2(-9, -4, 18, 12), Color("e8c276"))
	draw_rect(Rect2(-5, -1, 10, 3), Color("b84f56"))
	draw_rect(Rect2(-7, -15, 4, 12), Color("b9e0c4"))

func _draw_badge() -> void:
	draw_circle(Vector2.ZERO, 20, Color("6b4058"))
	draw_circle(Vector2.ZERO, 16, Color("e6ad58"))
	draw_circle(Vector2.ZERO, 11, Color("91c5bd"))
	draw_circle(Vector2(-4, -2), 2, Color("5c4650"))
	draw_circle(Vector2(4, -2), 2, Color("5c4650"))
	draw_circle(Vector2(-4, 5), 2, Color("5c4650"))
	draw_circle(Vector2(4, 5), 2, Color("5c4650"))

func _draw_puppet() -> void:
	var body := PackedVector2Array([Vector2(-18, 17), Vector2(-21, -12), Vector2(-13, -25), Vector2(0, -29), Vector2(13, -25), Vector2(21, -12), Vector2(18, 17)])
	draw_colored_polygon(body, Color("d95b68"))
	draw_polyline(body + PackedVector2Array([body[0]]), Color("6b3d4b"), 3.0)
	draw_circle(Vector2(-7, -13), 4, Color("f4e2bd"))
	draw_circle(Vector2(7, -13), 4, Color("f4e2bd"))
	draw_circle(Vector2(-7, -13), 1.5, Color("58455a"))
	draw_circle(Vector2(7, -13), 1.5, Color("58455a"))
	draw_arc(Vector2(0, -1), 8, 0.1, PI - 0.1, 8, Color("5b3042"), 3)
	draw_rect(Rect2(-18, 12, 36, 6), Color("e8c276"))

func _draw_trunk() -> void:
	draw_rect(Rect2(-23, -13, 46, 29), Color("6f433d"))
	draw_rect(Rect2(-20, -10, 40, 22), Color("a25f46"))
	draw_rect(Rect2(-18, -7, 36, 4), Color("d09559"))
	draw_rect(Rect2(-19, 11, 38, 4), Color("4a3340"))
	draw_rect(Rect2(-3, -4, 6, 11), Color("f0c769"))
	draw_rect(Rect2(-25, -18, 50, 5), Color("e0a05b"))

func _draw_teacup() -> void:
	draw_rect(Rect2(-17, -10, 30, 23), Color("c56a62"))
	draw_rect(Rect2(-13, -6, 22, 17), Color("f1c987"))
	draw_circle(Vector2(14, 0), 9, Color("c56a62"), false, 4)
	_draw_scaled_ellipse(Vector2(-2, -10), Vector2(17, 5), Color("8fc8c1"))
	draw_circle(Vector2(-5, -10), 3, Color("fff0c2"))

func _draw_mask() -> void:
	var mask := PackedVector2Array([Vector2(-22, -12), Vector2(-13, -25), Vector2(13, -25), Vector2(22, -12), Vector2(17, 13), Vector2(0, 23), Vector2(-17, 13)])
	draw_colored_polygon(mask, Color("8fc8c1"))
	draw_polyline(mask + PackedVector2Array([mask[0]]), Color("4e686e"), 3.0)
	draw_circle(Vector2(-8, -7), 5, Color("332c3c"))
	draw_circle(Vector2(8, -7), 5, Color("332c3c"))
	draw_line(Vector2(-4, 9), Vector2(4, 9), Color("d8ad67"), 3)

func _draw_spool() -> void:
	draw_rect(Rect2(-13, -20, 26, 40), Color("d95b68"))
	draw_rect(Rect2(-18, -19, 36, 7), Color("e6ad58"))
	draw_rect(Rect2(-18, 12, 36, 7), Color("e6ad58"))
	draw_rect(Rect2(-8, -12, 16, 24), Color("8fc8c1"))
	draw_line(Vector2(-8, -4), Vector2(8, -4), Color("f1d798"), 2)
	draw_line(Vector2(-8, 4), Vector2(8, 4), Color("f1d798"), 2)

func _draw_clock() -> void:
	draw_circle(Vector2.ZERO, 20, Color("6b4058"))
	draw_circle(Vector2.ZERO, 16, Color("e8c276"))
	draw_circle(Vector2.ZERO, 12, Color("d9efe0"))
	draw_line(Vector2.ZERO, Vector2(-1, -8), Color("493d4a"), 2)
	draw_line(Vector2.ZERO, Vector2(7, 4), Color("493d4a"), 2)
	draw_circle(Vector2.ZERO, 2, Color("b84f56"))

func _draw_letter() -> void:
	draw_rect(Rect2(-23, -16, 46, 32), Color("f2d7a4"))
	draw_line(Vector2(-22, -14), Vector2(0, 2), Color("b84f56"), 3)
	draw_line(Vector2(22, -14), Vector2(0, 2), Color("b84f56"), 3)
	draw_rect(Rect2(-8, 7, 16, 3), Color("6b4058"))
	draw_circle(Vector2(0, 1), 4, Color("e6ad58"))

func _draw_frame() -> void:
	draw_rect(Rect2(-22, -25, 44, 48), Color("6f433d"))
	draw_rect(Rect2(-17, -20, 34, 38), Color("e6ad58"))
	draw_rect(Rect2(-13, -16, 26, 30), Color("8fc8c1"))
	draw_circle(Vector2(0, -1), 10, Color("d95b68"))
	draw_circle(Vector2(-4, -4), 2, Color("f4e2bd"))
	draw_circle(Vector2(4, -4), 2, Color("f4e2bd"))
