class_name BidCardFace
extends Control

const ART = preload("res://assets/cards/auction-card-art-cozy-v3.png")
const ART_INDEX := {"bid":0,"inspect":1,"publish":6,"shield":2,"draw":3,"steal":4,"raise":5,"rumor":9,"attack":8,"luck":7,"gacha":10}
const COLORS := {"입찰":Color("b77a30"),"정보":Color("367d78"),"방어":Color("647b48"),"방해":Color("ad5149"),"보충":Color("466f91"),"변수":Color("85618c")}
const FRAME := Rect2(-20,-28,40,56)
var card: Dictionary = {}
var back := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)

func set_card(value: Dictionary) -> void:
	card = value.duplicate(true)
	queue_redraw()

static func art_region(id: String) -> Rect2:
	var index := int(ART_INDEX.get(id,7))
	var cell := Vector2(ART.get_width()/4.0,ART.get_height()/3.0)
	return Rect2(Vector2((index%4)*cell.x+8,floori(index/4.0)*cell.y+8),cell-Vector2(16,16))

static func paint(canvas: CanvasItem, value: Dictionary, is_back := false, affordable := true) -> void:
	var ink := Color("493d38")
	var paper := Color("f4e6c8")
	canvas.draw_rect(FRAME.grow(1),Color("342d30"))
	canvas.draw_rect(FRAME,paper)
	canvas.draw_rect(FRAME.grow(-1),Color("c4a97c"),false,1)
	for y in range(-23,26,5):
		canvas.draw_line(Vector2(-18,y),Vector2(-18,y+1),Color("aa8c66"))
		canvas.draw_line(Vector2(18,y),Vector2(18,y+1),Color("aa8c66"))
	if is_back:
		canvas.draw_rect(Rect2(-16,-24,32,48),Color("426b6b"))
		canvas.draw_rect(Rect2(-14,-22,28,44),Color("c6b389"),false,1)
		canvas.draw_circle(Vector2.ZERO,8,Color("e6c48a"))
		for point in [Vector2(-2,-2),Vector2(2,-2),Vector2(-2,2),Vector2(2,2)]:
			canvas.draw_rect(Rect2(point-Vector2.ONE,Vector2(2,2)),Color("735b48"))
		canvas.draw_string(ThemeDB.fallback_font,Vector2(-12,19),"행동표",HORIZONTAL_ALIGNMENT_CENTER,24,6,paper)
		return
	var kind := str(value.get("kind","변수"))
	var color: Color = COLORS.get(kind,COLORS["변수"])
	canvas.draw_rect(Rect2(-16,-25,32,9),color)
	canvas.draw_string(ThemeDB.fallback_font,Vector2(-14,-18),str(value.get("label",value.get("name","카드"))),HORIZONTAL_ALIGNMENT_LEFT,22,5,Color("fff6de"))
	# The same spool badge always means thread cost, including a free zero.
	canvas.draw_rect(Rect2(9,-27,10,11),Color("4d4540"))
	canvas.draw_rect(Rect2(10,-26,8,9),paper)
	canvas.draw_line(Vector2(10,-24),Vector2(17,-24),color)
	canvas.draw_string(ThemeDB.fallback_font,Vector2(10,-17),str(value.get("cost",0)),HORIZONTAL_ALIGNMENT_CENTER,8,7,ink)
	canvas.draw_texture_rect_region(ART,Rect2(-16,-14,32,24),art_region(str(value.get("id",""))))
	if not affordable:
		canvas.draw_rect(Rect2(-16,3,32,7),Color("ad5149"))
		canvas.draw_string(ThemeDB.fallback_font,Vector2(-15,9),"실밥 부족",HORIZONTAL_ALIGNMENT_CENTER,30,5,Color("fff6de"))
	canvas.draw_rect(Rect2(-16,11,32,6),color)
	canvas.draw_string(ThemeDB.fallback_font,Vector2(-15,16),kind,HORIZONTAL_ALIGNMENT_CENTER,30,5,Color("fff6de"))
	canvas.draw_string(ThemeDB.fallback_font,Vector2(-16,24),str(value.get("summary","효과 확인")),HORIZONTAL_ALIGNMENT_CENTER,32,5,ink)

func _draw() -> void:
	if card.is_empty() and not back: return
	var factor := minf(size.x/42.0,size.y/58.0)
	draw_set_transform(size*0.5,0,Vector2.ONE*factor)
	paint(self,card,back)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
