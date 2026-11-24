extends Node2D

const PROGRESSAO := preload("res://Scripts/progressao.gd")
const TAMANHO_SALA := Vector2i(20, 14)
const ALCANCE_ESPELHO := 52.0

var _espelho_revelado := false

@onready var jogador: CharacterBody2D = $Moveis/Michael_Player
@onready var frente_do_espelho: Marker2D = $FrenteDoEspelho
@onready var mensagem: PanelContainer = $Interface/Mensagem
@onready var texto: Label = $Interface/Mensagem/Texto

func _ready() -> void:
	var piso: TileMapLayer = $Piso
	montar_cenario(piso, $Paredes)
	var camera: Camera2D = jogador.get_node("Camera2D")
	var limites := TAMANHO_SALA * piso.tile_set.tile_size
	camera.limit_right = limites.x
	camera.limit_bottom = limites.y
	camera.position.y = -125.0
	camera.reset_smoothing()
	_revelar_sala()


static func montar_cenario(piso: TileMapLayer, paredes: TileMapLayer) -> void:
	for y in range(TAMANHO_SALA.y):
		for x in range(TAMANHO_SALA.x):
			var celula := Vector2i(x, y)
			if y < 4:
				paredes.set_cell(celula, 0, Vector2i(y, 1))
			elif x == 0 or x == TAMANHO_SALA.x - 1:
				paredes.set_cell(celula, 0, Vector2i(6 if x == 0 else 8, 1))
			else:
				piso.set_cell(celula, 0, Vector2i(0, 0))


func _revelar_sala() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 2
	add_child(camada)
	var escuro := ColorRect.new()
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	escuro.color = Color(0.026, 0.018, 0.039)
	camada.add_child(escuro)
	escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var animacao := camada.create_tween()
	animacao.tween_property(escuro, "color:a", 0.0, 0.52)
	animacao.tween_callback(camada.queue_free)


func _physics_process(_delta: float) -> void:
	var pes := jogador.global_position + Vector2(0, 12)
	mensagem.visible = pes.distance_to(frente_do_espelho.global_position) <= ALCANCE_ESPELHO
	if not mensagem.visible:
		return

	if Input.is_action_just_pressed("Interagir"):
		if _espelho_revelado:
			get_tree().change_scene_to_file(PROGRESSAO.BILLIE_JEAN)
			return
		_espelho_revelado = true

	texto.text = "E — Interagir"
	if _espelho_revelado:
		texto.text = "As lembranças de Michael estão desaparecendo.\nE — Atravessar"

func dev_posicao_final() -> Vector2:
	return frente_do_espelho.global_position + Vector2(0, 10)
