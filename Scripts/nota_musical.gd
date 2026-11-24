extends RefCounted

const NOTA_VISUAL := preload("res://Scripts/nota_visual.gd")
const INDICADOR := preload("res://Scripts/indicador_notas.gd")


static func criar(celula: Vector2i, posicao: Vector2) -> Area2D:
	var nota: Area2D = NOTA_VISUAL.new()
	nota.name = "Nota_%d_%d" % [celula.x, celula.y]
	nota.position = posicao
	return nota


# Instala o indicador de proximidade abaixo da interface, para nunca cobrir o HUD.
static func instalar_indicador(fase: Node) -> void:
	var indicador := CanvasLayer.new()
	indicador.set_script(INDICADOR)
	fase.add_child(indicador)
	var interface := fase.get_node_or_null("Interface")
	if interface != null:
		fase.move_child(indicador, interface.get_index())
