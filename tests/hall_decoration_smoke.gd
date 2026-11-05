extends SceneTree
const Layout = preload("res://scripts/hall_decoration_layout.gd")
func _init() -> void:
	var first := Layout.build(811)
	assert(first == Layout.build(811))
	assert(first.size() == 5)
	var signatures := {}
	for seed_value in 25:
		var layout := Layout.build(seed_value)
		signatures[JSON.stringify(layout)] = true
		for prop in layout:
			assert(prop.position.x >= 90 and prop.position.x <= 3030)
			assert(not (prop.position.x + 70 > 1110 and prop.position.x - 70 < 1790))
			assert(not (prop.position.x + 70 > 2510))
			assert(prop.cell[0] in [0,1] and prop.cell[1] in [0,1])
	assert(signatures.size() > 1)
	print("Perlin decoration: deterministic, variable seeds, clear stage and shop: PASS")
	quit()
