extends SceneTree

func _init() -> void:
	for frame in 8:
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/sock_puppet/body_only/frames/%02d.png" % frame))
		var visited := {}
		var components: Array = []
		for y in range(15, 65):
			for x in range(40, 90):
				var start := Vector2i(x, y)
				if visited.has(start) or not gold(image.get_pixelv(start)):
					continue
				var points: Array[Vector2i] = [start]
				visited[start] = true
				var total := Vector2.ZERO
				var count := 0
				while count < points.size():
					var point := points[count]
					total += Vector2(point)
					count += 1
					for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var neighbor: Vector2i = point + offset
						if neighbor.x < 40 or neighbor.x >= 90 or neighbor.y < 15 or neighbor.y >= 65 or visited.has(neighbor):
							continue
						if gold(image.get_pixelv(neighbor)):
							visited[neighbor] = true
							points.append(neighbor)
				if count >= 4:
					components.append({"area": count, "center": total / count})
		print("frame %02d: %s" % [frame, components])
	quit()

func gold(pixel: Color) -> bool:
	return pixel.a > 0.5 and pixel.r > 0.5 and pixel.g > 0.3 and pixel.r > pixel.g * 1.12 and pixel.b < pixel.g * 0.60
