extends RefCounted

const CAMADA_JOGADOR := 2


static func criar(celula: Vector2i, posicao: Vector2) -> Area2D:
	var nota := Area2D.new()
	nota.name = "Nota_%d_%d" % [celula.x, celula.y]
	nota.position = posicao
	nota.collision_layer = 0
	nota.collision_mask = CAMADA_JOGADOR
	nota.monitorable = false
	var colisor := CollisionShape2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 10.0
	colisor.shape = forma
	nota.add_child(colisor)
	var brilho := Polygon2D.new()
	brilho.polygon = PackedVector2Array([Vector2(0, -13), Vector2(12, 0),
		Vector2(0, 13), Vector2(-12, 0)])
	brilho.color = Color(0.38, 0.28, 0.53, 0.85)
	nota.add_child(brilho)
	var simbolo := Label.new()
	simbolo.text = "♪"
	simbolo.add_theme_font_size_override("font_size", 20)
	simbolo.add_theme_color_override("font_color", Color(1.0, 0.86, 0.54))
	simbolo.position = Vector2(-7, -15)
	simbolo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nota.add_child(simbolo)
	return nota
