extends Node2D

const PROGRESSAO := preload("res://Scripts/progressao.gd")
const ESPELHO := preload("res://Scripts/espelho_magico.gd")
const FEEDBACK := preload("res://Scripts/feedback_vitoria.gd")
const TAMANHO_SALA := Vector2i(20, 14)
const ALCANCE_ESPELHO := 52.0

var _energia: Node2D

@onready var jogador: MichaelJogador = $Moveis/Michael_Player
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
	_energia = ESPELHO.instalar(self, $Moveis/espelho_magico.global_position - Vector2(0, 59))
	FEEDBACK.faixa(self, "Algo se move no espelho", "Atravesse-o para seguir as memórias.", Color(0.87, 0.75, 1.0), 0.0, 4.8)
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
	if jogador.atravessando_espelho:
		return
	var apoio := frente_do_espelho.global_position
	var distancia := jogador.colisor.global_position.distance_to(apoio)
	_energia.intensidade = 0.25 * (1.0 - clampf(distancia / 115.0, 0.0, 1.0))
	mensagem.visible = distancia <= ALCANCE_ESPELHO
	texto.text = "[E] Entrar no espelho"
	if mensagem.visible and Input.is_action_just_pressed("Interagir"):
		mensagem.hide()
		FEEDBACK.encerrar(self)
		_energia.atravessar(jogador, apoio, get_tree().change_scene_to_file.bind(PROGRESSAO.BILLIE_JEAN))
