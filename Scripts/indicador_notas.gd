extends CanvasLayer

# Setas discretas na borda da tela apontando para notas ainda não coletadas.
# Só aparecem para notas fora da tela e relativamente perto. Quando restam
# poucas notas, a mais próxima passa a ser indicada de qualquer distância.

# Zona segura em coordenadas lógicas (640x360), abaixo do HUD e acima do aviso inferior.
const ZONA := Rect2(26.0, 128.0, 588.0, 158.0)
const RAIO_AVISO := 560.0
const RAIO_FORTE := 320.0
const MAX_SETAS := 2
const ULTIMAS_NOTAS := 2
const COR_SETA := Color(1.0, 0.82, 0.32)
const COR_CONTORNO := Color(0.14, 0.07, 0.23)

var _tempo := 0.0
var _desenho: Control


func _ready() -> void:
	layer = 1
	_desenho = Control.new()
	_desenho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desenho.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desenho.draw.connect(_desenhar)
	add_child(_desenho)


func _process(delta: float) -> void:
	_tempo += delta
	_desenho.queue_redraw()


func _desenhar() -> void:
	var fase := get_parent()
	var jogador := get_tree().get_first_node_in_group("jogador") as Node2D
	if jogador == null:
		return
	if fase.has_method("indicador_notas_suprimido") and fase.indicador_notas_suprimido():
		return
	var viva: Array[Node2D] = []
	for no in get_tree().get_nodes_in_group("notas_musicais"):
		var nota := no as Node2D
		if nota != null and not nota.is_queued_for_deletion():
			viva.append(nota)
	if viva.is_empty():
		return

	var tela := get_viewport().get_visible_rect().grow(-10.0)
	var transformacao := get_viewport().get_canvas_transform()
	var fora: Array[Dictionary] = []
	for nota in viva:
		var ponto := transformacao * nota.global_position
		if tela.has_point(ponto):
			continue
		fora.append({"distancia": jogador.global_position.distance_to(nota.global_position), "ponto": ponto})
	fora.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distancia < b.distancia)

	var ultimas := viva.size() <= ULTIMAS_NOTAS
	var mostradas := 0
	for item in fora:
		if mostradas >= MAX_SETAS:
			break
		var distancia: float = item.distancia
		if distancia > RAIO_AVISO and not (ultimas and mostradas == 0):
			continue
		var forca := 1.0 if distancia <= RAIO_FORTE else clampf(1.0 - (distancia - RAIO_FORTE) / (RAIO_AVISO - RAIO_FORTE), 0.0, 1.0)
		_desenhar_seta(item.ponto, lerpf(0.40, 1.0, forca))
		mostradas += 1


func _desenhar_seta(alvo: Vector2, opacidade: float) -> void:
	var centro := ZONA.get_center()
	var direcao := alvo - centro
	if direcao.is_zero_approx():
		return
	var escala := minf(ZONA.size.x * 0.5 / maxf(absf(direcao.x), 0.001), ZONA.size.y * 0.5 / maxf(absf(direcao.y), 0.001))
	var u := direcao.normalized()
	var v := Vector2(-u.y, u.x)
	var posicao := centro + direcao * escala + u * (1.5 * sin(_tempo * 5.0))
	var pulso := 0.8 + 0.2 * sin(_tempo * 4.0)
	var contorno := PackedVector2Array([
		posicao + u * 11.0, posicao - u * 6.0 + v * 8.5,
		posicao - u * 2.0, posicao - u * 6.0 - v * 8.5,
	])
	var corpo := PackedVector2Array([
		posicao + u * 8.0, posicao - u * 4.0 + v * 6.0,
		posicao - u * 1.0, posicao - u * 4.0 - v * 6.0,
	])
	var alfa := opacidade * pulso
	_desenho.draw_colored_polygon(contorno, Color(COR_CONTORNO.r, COR_CONTORNO.g, COR_CONTORNO.b, alfa))
	_desenho.draw_colored_polygon(corpo, Color(COR_SETA.r, COR_SETA.g, COR_SETA.b, alfa))
