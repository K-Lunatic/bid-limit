class_name PixelFX2D
extends Node2D

var particles: Array[Dictionary] = []
var receipts: Array[Dictionary] = []

func show_amount(amount: int, at: Vector2) -> void:
	receipts.append({"amount":amount,"position":at,"life":1.4})
	queue_redraw()

func burst(at: Vector2, color: Color, kind := "bid") -> void:
	var count := 10 if kind == "hit" else 14
	for index in count:
		var angle := TAU * float(index) / float(count) + randf_range(-0.16, 0.16)
		particles.append({"position": at, "velocity": Vector2(cos(angle), sin(angle)) * randf_range(55.0, 130.0), "life": randf_range(0.35, 0.7), "max_life": 0.7, "color": color, "size": 2.0 if kind == "hit" else 3.0})
	queue_redraw()

func _process(delta: float) -> void:
	for receipt in receipts:
		receipt.life -= delta
		receipt.position.y -= 28.0*delta
	receipts = receipts.filter(func(receipt: Dictionary) -> bool: return receipt.life > 0.0)
	for particle in particles:
		particle.position += particle.velocity * delta
		particle.velocity *= exp(-delta * 2.4)
		particle.velocity.y += 85.0 * delta
		particle.life -= delta
	particles = particles.filter(func(particle: Dictionary) -> bool: return particle.life > 0.0)
	queue_redraw()

func _draw() -> void:
	for receipt in receipts:
		draw_string(ThemeDB.fallback_font,receipt.position.round(),"+%d 보풀" % int(receipt.amount),HORIZONTAL_ALIGNMENT_LEFT,180,20,Color(1.0,0.85,0.38,minf(1.0,receipt.life*3.0)))
	for particle in particles:
		var alpha: float = clampf(particle.life / particle.max_life, 0.0, 1.0)
		var color: Color = particle.color
		color.a = alpha
		var position: Vector2 = particle.position
		var size: float = particle.size
		draw_rect(Rect2(position - Vector2(size, size), Vector2(size * 2.0, size * 2.0)), color)
