extends Node2D

const FEEDBACK := preload("res://Scripts/feedback_vitoria.gd")
const TENTATIVAS := preload("res://Scripts/tentativas.gd")
const NOTAS: Array[Vector2i] = [
	Vector2i(24, 54), Vector2i(18, 58), Vector2i(36, 54),
	Vector2i(27, 51), Vector2i(9, 46), Vector2i(41, 46), Vector2i(24, 40),
	Vector2i(16, 37), Vector2i(37, 39), Vector2i(24, 29),
	Vector2i(9, 24), Vector2i(38, 20), Vector2i(24, 16), Vector2i(28, 13),
]
const CURAS_FIXAS: Array[Vector2i] = [Vector2i(24, 42), Vector2i(24, 23)]
const CENA_CURA := preload("res://Scenes/cura_thriller.tscn")
const NOTA_MUSICAL := preload("res://Scripts/nota_musical.gd")
const MARCO_CENTRAL := Vector2i(24, 45)

const Sepultura := preload("res://Scripts/sepultura_corrompida.gd")
const PROGRESSAO := preload("res://Scripts/progressao.gd")
const TAMANHO := 32
const ALCANCE_ESPELHO := 57.0
const CAMADA_CENARIO := 1

var caminhos := AStarGrid2D.new()
var pontuacao: int:
	get:
		return _notas_coletadas * 100

var _notas_coletadas := 0
var _meta_notas := NOTA_MUSICAL.minimo_para_avancar(NOTAS.size())
var concluida := false

@onready var piso: TileMapLayer = $Piso
@onready var muros: TileMapLayer = $Muros
@onready var atores: Node2D = $Atores
@onready var jogador: MichaelJogador = $Atores/Michael_Player
@onready var pes: CollisionShape2D = $Atores/Michael_Player/Michael_Colisor
@onready var encontros: Node = $Encontros
@onready var batalhas: Node = $Batalhas
@onready var espelho: StaticBody2D = $Atores/Espelho
@onready var hud = $Interface/HUD
@onready var contador: Label = $Interface/HUD/Conteudo/Notas
@onready var vidas: Label = $Interface/HUD/Conteudo/Vidas
@onready var coracoes: HBoxContainer = $Interface/HUD/Conteudo/Vidas/Coracoes
@onready var curas: Node2D = $Atores/Curas
@onready var moonwalk: Label = $Interface/HUD/Conteudo/Moonwalk
@onready var dash: Label = $Interface/HUD/Conteudo/Dash
@onready var texto_aviso: Label = $Interface/Aviso/Texto
@onready var aviso_batalha: Label = $Interface/Batalha/Texto
@onready var aviso: PanelContainer = $Interface/Aviso
@onready var conclusao: PanelContainer = $Interface/Conclusao
@onready var resultado: Label = $Interface/Conclusao/Conteudo/Resultado

func _ready() -> void:
	TENTATIVAS.registrar_fase(scene_file_path)
	hud.iniciar(jogador)
	NOTA_MUSICAL.instalar_indicador(self)
	_atualizar_pontos()
	for celula in NOTAS:
		_adicionar_nota(celula)
	for celula in CURAS_FIXAS:
		adicionar_cura(piso.map_to_local(celula))

	var camera: Camera2D = jogador.get_node("Camera2D")
	var mapa := piso.get_used_rect()
	camera.limit_right = mapa.end.x * TAMANHO
	camera.limit_bottom = mapa.end.y * TAMANHO
	camera.position.y = -60.0
	camera.reset_smoothing()
	camera.force_update_scroll()
	piso.update_internals()
	muros.update_internals()
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_montar_navegacao(mapa)
	batalhas.iniciar(self, aviso_batalha)
	encontros.iniciar(self, camera)
	for celula in [Vector2i(11, 46), Vector2i(38, 23)]:
		var sepultura := Sepultura.new()
		sepultura.position = piso.map_to_local(celula)
		sepultura.iniciar(self)
		atores.add_child(sepultura)

func _montar_navegacao(mapa: Rect2i) -> void:
	caminhos.region = mapa
	caminhos.cell_size = Vector2(TAMANHO, TAMANHO)
	caminhos.offset = caminhos.cell_size * 0.5
	caminhos.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	caminhos.update()
	var passagem := RectangleShape2D.new()
	passagem.size = Vector2(32, 32)
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = passagem
	consulta.collision_mask = CAMADA_CENARIO
	var espaco := get_world_2d().direct_space_state
	for y in range(mapa.position.y, mapa.end.y):
		for x in range(mapa.position.x, mapa.end.x):
			var celula := Vector2i(x, y)
			# Exclui a margem externa aos muros da navegação e das ondas.
			var exterior := x <= 2 or x >= 45 or y <= 3 or y >= 61
			consulta.transform = Transform2D(0.0, piso.map_to_local(celula))
			caminhos.set_point_solid(celula, exterior or not espaco.intersect_shape(consulta, 1).is_empty())

func adicionar_cura(posicao: Vector2) -> bool:
	if concluida:
		return false
	for item: Area2D in curas.get_children():
		if not item.is_queued_for_deletion() and item.global_position.distance_squared_to(posicao) < 18.0 * 18.0:
			return false
	var cura := CENA_CURA.instantiate() as Area2D
	cura.position = curas.to_local(posicao)
	curas.add_child(cura)
	return true

func _adicionar_nota(celula: Vector2i) -> void:
	var nota := NOTA_MUSICAL.criar(celula, piso.map_to_local(celula))
	nota.body_entered.connect(_coletar_nota.bind(nota), CONNECT_ONE_SHOT)
	atores.add_child(nota)


func _coletar_nota(_corpo: Node2D, nota: Area2D) -> void:
	if concluida or nota.is_queued_for_deletion():
		return
	nota.coletar()
	_notas_coletadas += 1
	_atualizar_pontos()
	hud.destacar_pontos()

func _atualizar_pontos() -> void:
	hud.atualizar_pontos(_notas_coletadas, NOTAS.size(), pontuacao, _meta_notas)


func _physics_process(_delta: float) -> void:
	if concluida or jogador.vida <= 0:
		return
	hud.atualizar_recargas(jogador)
	var frente_do_espelho := espelho.global_position + Vector2(0, 60)
	aviso.visible = pes.global_position.distance_to(frente_do_espelho) <= ALCANCE_ESPELHO
	if aviso.visible:
		var pendencia := "" if batalhas.espelho_liberado() else "Derrote os zumbis das passagens."
		texto_aviso.text = NOTA_MUSICAL.aviso_espelho(_meta_notas - _notas_coletadas, pendencia)
	if aviso.visible and Input.is_action_just_pressed("Interagir"):
		concluir()


func concluir() -> void:
	if concluida or jogador.vida <= 0 or not dev_espelho_liberado():
		return
	concluida = true
	FEEDBACK.encerrar(self)
	atores.process_mode = Node.PROCESS_MODE_DISABLED
	aviso.hide()
	resultado.text = "Memória restaurada. O cemitério voltou à vida.\nNotas  %d/%d     Pontos  %d" % [_notas_coletadas, NOTAS.size(), pontuacao]
	var botao: Button = conclusao.get_node("Conteudo/Voltar")
	if ResourceLoader.exists(PROGRESSAO.SMOOTH_CRIMINAL, "PackedScene"):
		botao.text = "Continuar"
	conclusao.show()
	botao.grab_focus()

func _avancar() -> void:
	var destino := PROGRESSAO.MENU
	if ResourceLoader.exists(PROGRESSAO.SMOOTH_CRIMINAL, "PackedScene"):
		destino = PROGRESSAO.SMOOTH_CRIMINAL
	AudioManager.tocar(&"portal")
	get_tree().change_scene_to_file(destino)

func dev_posicao_final() -> Vector2:
	return espelho.global_position + Vector2(0, 64)

func dev_posicao_central() -> Vector2:
	return piso.map_to_local(MARCO_CENTRAL) - Vector2(0, 10)

func dev_gerar_onda() -> void:
	if not concluida:
		encontros.gerar_onda_teste()

func dev_espelho_liberado() -> bool:
	return batalhas.espelho_liberado() and _notas_coletadas >= _meta_notas

func indicador_notas_suprimido() -> bool:
	# Durante as ondas obrigatórias o indicador some para não poluir a tela.
	return concluida or jogador.vida <= 0 or batalhas.ativa

func dev_progresso() -> String:
	return "Notas %d/%d (meta)  ·  Pontos %d" % [_notas_coletadas, _meta_notas, pontuacao]

func dev_coletar_nota() -> void:
	for nota in atores.get_children():
		if nota.is_in_group("notas_musicais") and not nota.is_queued_for_deletion():
			_coletar_nota(jogador, nota)
			return
