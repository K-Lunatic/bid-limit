@tool
class_name AuctionHallLayer2D
extends Node2D

const HALL_ART = preload("res://assets/maps/auction-hall-cozy-v2.png")
const DecorationLayout = preload("res://scripts/hall_decoration_layout.gd")
var decorations: Array[Dictionary] = []
var prop_atlas: Texture2D
const ArtLayout = preload("res://scripts/art_layout.gd")
@export var layer_kind := 0
@export var decoration_seed := 811
@export var seat_markers: Array[NodePath] = []
var pixel_art: ImageTexture
var seat_occupants: Dictionary = {}

func _ready() -> void:
	configure(layer_kind,decoration_seed)

func configure(kind: int, seed_value: int) -> void:
	layer_kind = kind
	if layer_kind == 0:
		var depth := ShaderMaterial.new()
		depth.shader = preload("res://shaders/hall_depth.gdshader")
		depth.set_shader_parameter("room_light", ArtLayout.ROOM_AMBIENT)
		material = depth
		var pixels := HALL_ART.get_image()
		pixels.resize(maxi(1, pixels.get_width() / ArtLayout.BACKGROUND_SOURCE_DIVISOR), maxi(1, pixels.get_height() / ArtLayout.BACKGROUND_SOURCE_DIVISOR), Image.INTERPOLATE_NEAREST)
		pixel_art = ImageTexture.create_from_image(pixels)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if layer_kind == 2:
		prop_atlas = load("res://assets/maps/props/hall-props-cozy-v2.png")
		decorations = DecorationLayout.build(seed_value)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		modulate = ArtLayout.ROOM_AMBIENT
	queue_redraw()

func set_seat_occupants(value: Dictionary) -> void:
	seat_occupants = value.duplicate(true)
	queue_redraw()

func _draw() -> void:
	if layer_kind == 0:
		draw_rect(Rect2(0, -100, ArtLayout.WORLD_WIDTH, 820), Color("120f1b"))
		var source_height := float(pixel_art.get_height())
		var source_width := float(pixel_art.get_width())
		var left_width := source_width * 0.338
		var center_width := source_width * 0.368
		var shop_width := source_width - left_width - center_width
		var world_scale := ArtLayout.BACKGROUND_WORLD_SCALE
		var height := source_height * world_scale
		var y := 520.0 - height * 0.76
		var wall_width := left_width * world_scale
		for x in range(0, int(ArtLayout.WORLD_WIDTH), int(wall_width)):
			draw_texture_rect_region(pixel_art, Rect2(float(x), y, wall_width, height), Rect2(0, 0, left_width, source_height))
		draw_texture_rect_region(pixel_art, Rect2(120.0, y, wall_width, height), Rect2(0, 0, left_width, source_height))
		draw_texture_rect_region(pixel_art, Rect2(1450.0 - center_width * world_scale * 0.5, y, center_width * world_scale, height), Rect2(left_width, 0, center_width, source_height))
		draw_texture_rect_region(pixel_art, Rect2(2510.0, y, shop_width * world_scale, height), Rect2(left_width + center_width, 0, shop_width, source_height))
	elif layer_kind == 1:
		# Keep the walkable carpet and the furniture anchors separate from the background art.
		draw_rect(Rect2(1110, 500, 680, 55), Color(0.48, 0.16, 0.22, 0.55))
		draw_rect(Rect2(1110, 500, 680, 55), Color("d7af74"), false, 3.0)
		for index in 4:
			var point: Vector2 = ArtLayout.SEAT_POSITIONS[index]
			if index < seat_markers.size() and get_node_or_null(seat_markers[index]) != null:
				point = to_local(get_node(seat_markers[index]).global_position)
			var x := point.x
			var occupied := seat_occupants.has(index)
			draw_auction_chair(point, occupied, index + 1)
		draw_appraisal_station()
		draw_button_shop()

	elif layer_kind == 2 and prop_atlas != null:
		for prop in decorations:
			var source := Rect2(Vector2(float(prop.cell[0]),float(prop.cell[1])) * 96.0,Vector2(96,96))
			var anchor := Vector2(float(prop.anchor[0]),float(prop.anchor[1]))
			var destination := Rect2(prop.position-anchor*ArtLayout.ACTOR_DRAW_SCALE,Vector2(96,96)*ArtLayout.ACTOR_DRAW_SCALE)
			draw_texture_rect_region(prop_atlas,destination,source)

func draw_auction_chair(point: Vector2, occupied: bool, seat_number: int) -> void:
	# Seat marker is the cushion centre, so the character and chair share one floor anchor.
	var wood := Color("6d3e3c")
	var wood_light := Color("b76d4e")
	var cushion := Color("7c3f55") if occupied else Color("3e765d")
	draw_rect(Rect2(point.x - 29, point.y - 50, 58, 31), wood)
	draw_rect(Rect2(point.x - 24, point.y - 45, 48, 23), wood_light)
	draw_rect(Rect2(point.x - 23, point.y - 43, 46, 18), cushion)
	draw_rect(Rect2(point.x - 29, point.y - 20, 58, 7), wood)
	draw_rect(Rect2(point.x - 22, point.y - 13, 7, 15), wood)
	draw_rect(Rect2(point.x + 15, point.y - 13, 7, 15), wood)
	draw_rect(Rect2(point.x - 32, point.y - 53, 64, 3), Color("e4ae68"))
	draw_rect(Rect2(point.x - 7, point.y - 39, 14, 5), Color("f4c477") if not occupied else Color("f3a37c"))
	if not occupied:
		draw_string(ThemeDB.fallback_font, point + Vector2(-30, 19), "앉기", HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color("b7f2c5"))
	else:
		draw_string(ThemeDB.fallback_font, point + Vector2(-30, 19), "사용 중", HORIZONTAL_ALIGNMENT_CENTER, 60, 9, Color("ffb7a5"))
	draw_string(ThemeDB.fallback_font, point + Vector2(-8, -56), "%d" % seat_number, HORIZONTAL_ALIGNMENT_CENTER, 16, 8, Color("ffe6ba"))

func draw_appraisal_station() -> void:
	var anchor := Vector2(320, 520)
	draw_rect(Rect2(anchor.x - 105, anchor.y - 37, 210, 10), Color("4b2e3d"))
	draw_rect(Rect2(anchor.x - 95, anchor.y - 27, 190, 29), Color("9f6049"))
	draw_rect(Rect2(anchor.x - 86, anchor.y - 20, 172, 18), Color("d08a5d"))
	draw_rect(Rect2(anchor.x - 91, anchor.y - 49, 182, 11), Color("35535a"))
	draw_string(ThemeDB.fallback_font, Vector2(anchor.x - 86, anchor.y - 41), "감 정 소 · BOBBIN", HORIZONTAL_ALIGNMENT_CENTER, 172, 8, Color("f8d79e"))
	# A readable scale and magnifier make the appraiser's job visible in-world.
	draw_line(anchor + Vector2(-38, -62), anchor + Vector2(-38, -48), Color("f0c478"), 2.0)
	draw_line(anchor + Vector2(-53, -61), anchor + Vector2(-23, -61), Color("f0c478"), 2.0)
	draw_line(anchor + Vector2(-50, -61), anchor + Vector2(-57, -51), Color("f0c478"), 2.0)
	draw_line(anchor + Vector2(-26, -61), anchor + Vector2(-19, -51), Color("f0c478"), 2.0)
	draw_circle(anchor + Vector2(42, -53), 11, Color("8ed0c0"), false, 3.0)
	draw_line(anchor + Vector2(50, -45), anchor + Vector2(61, -35), Color("8ed0c0"), 3.0)
	draw_string(ThemeDB.fallback_font, anchor + Vector2(-100, 32), "가져오면 감정 · 한 사이클 한 개 매입", HORIZONTAL_ALIGNMENT_CENTER, 200, 9, Color("ffe3ac"))

func draw_button_shop() -> void:
	var anchor := Vector2(2750, 520)
	draw_rect(Rect2(anchor.x - 128, anchor.y - 45, 256, 13), Color("382847"))
	draw_rect(Rect2(anchor.x - 119, anchor.y - 32, 238, 34), Color("81516d"))
	draw_rect(Rect2(anchor.x - 110, anchor.y - 27, 220, 21), Color("c27b68"))
	draw_string(ThemeDB.fallback_font, Vector2(anchor.x - 110, anchor.y - 12), "단추상점 · 행동표 봉투", HORIZONTAL_ALIGNMENT_CENTER, 220, 9, Color("fff0c7"))
	for index in 3:
		var box := Rect2(anchor.x - 86 + index * 43, anchor.y - 1, 32, 18)
		draw_rect(box, Color("e1ad71"))
		draw_circle(box.position + Vector2(16, 9), 5, Color("f6d893"))
		draw_circle(box.position + Vector2(16, 9), 2, Color("6a4550"))
	draw_string(ThemeDB.fallback_font, anchor + Vector2(-126, 28), "70보풀 → 세 장 공개 → 한 장 보관", HORIZONTAL_ALIGNMENT_CENTER, 252, 9, Color("f5d4ff"))
