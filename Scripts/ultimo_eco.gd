extends Node2D

const FEEDBACK := preload("res://Scripts/feedback_vitoria.gd")
const TENTATIVAS := preload("res://Scripts/tentativas.gd")
const TheSilence := preload("res://Scripts/the_silence.gd")
const NOTAS := preload("res://Scripts/nota_musical.gd")
const PROGRESSAO := preload("res://Scripts/progressao.gd")
const ARENAS: Array[PackedScene] = [
	preload("res://Scenes/ArenasUltimoEco/arena_fase_1.tscn"),
	preload("res://Scenes/ArenasUltimoEco/arena_fase_2.tscn"),
	preload("res://Scenes/ArenasUltimoEco/arena_fase_3.tscn"),
	preload("res://Scenes/ArenasUltimoEco/arena_restaurada.tscn"),
]
const CELULAS_NOTAS: Array[Vector2i] = [Vector2i(12, 12), Vector2i(27, 12), Vector2i(19, 26)]
const TAMANHO_CELULA := 32
const APOIOS := {
	"obelisco": Vector2(30, 18),
	"poste": Vector2(22, 14),
	"lapide": Vector2(28, 14),
	"barricada": Vector2(58, 20),
	"palco": Vector2(60, 26),
	"altar": Vector2(54, 22),
	"relicario": Vector2(24, 16),
}
const TITULOS := ["Apagamento", "Fratura", "Último eco"]
const CORES_FASE := [Color(0.90, 0.77, 0.50), Color(0.40, 0.76, 1.0), Color(0.79, 0.56, 1.0)]

var caminhos := AStarGrid2D.new()
var concluida := false
var restaurada := false
var _pronta := false
var _notas_coletadas := 0
var _pisos: Array[Node2D] = []
var _objetos: Array[Node2D] = []
var _portal := Vector2.ZERO
var _preenchimento := StyleBoxFlat.new()

@onready var atores: Node2D = $Atores
@onready var jogador: MichaelJogador = $Atores/Michael_Player
@onready var chefe: TheSilence = $Atores/TheSilence
@onready var hud = $Interface/HUD
@onready var painel_chefe: PanelContainer = $Interface/Chefe
@onready var barra: ProgressBar = $Interface/Chefe/Conteudo/Vida
@onready var titulo: Label = $Interface/Chefe/Conteudo/Titulo
@onready var instrucao: Label = $Interface/Chefe/Conteudo/Instrucao
@onready var aviso: PanelContainer = $Interface/Aviso
@onready var aviso_texto: Label = $Interface/Aviso/Texto
@onready var final: PanelContainer = $Interface/Final


func _ready() -> void:
	TENTATIVAS.registrar_fase(scene_file_path)
	hud.iniciar(jogador)
	_atualizar_notas()
	for cena in ARENAS:
		var arena := cena.instantiate() as Node2D
		$Cenario.add_child(arena)
		var objetos := arena.get_node("Objetos") as Node2D
		var demonstracao := objetos.get_node_or_null("TheSilence")
		if demonstracao != null:
			objetos.remove_child(demonstracao)
			demonstracao.queue_free()
		objetos.reparent(atores, false)
		_pisos.append(arena)
		_objetos.append(objetos)
	_mostrar_arena(0)
	var piso := _pisos[0].get_node("Piso0") as TileMapLayer
	var celulas: Array[Vector2i] = piso.get_used_cells()
	_montar_colisoes(piso, celulas)
	for celula in CELULAS_NOTAS:
		var nota := NOTAS.criar(celula, piso.to_global(piso.map_to_local(celula)))
		nota.body_entered.connect(_coletar_nota.bind(nota), CONNECT_ONE_SHOT)
		atores.add_child(nota)
	chefe.fase_alterada.connect(_fase_alterada)
	chefe.estado_alterado.connect(_estado_alterado)
	chefe.vida_alterada.connect(func(vida: int) -> void: barra.value = vida)
	chefe.derrotado.connect(_restaurar_arena, CONNECT_ONE_SHOT)
	barra.add_theme_stylebox_override("fill", _preenchimento)
	_fase_alterada(1)
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_montar_navegacao(piso)
	chefe.caminhos = caminhos
	_pronta = true


func _montar_colisoes(piso: TileMapLayer, celulas: Array[Vector2i]) -> void:
	var chao := {}
	for celula in celulas:
		chao[celula] = true
	var limite := StaticBody2D.new()
	$Colisoes.add_child(limite)
	for celula in celulas:
		var centro := piso.to_global(piso.map_to_local(celula))
		for lado: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if chao.has(celula + lado):
				continue
			var direcao := Vector2(lado)
			var tangente := direcao.orthogonal() * (TAMANHO_CELULA * 0.5)
			var borda := centro + direcao * (TAMANHO_CELULA * 0.5)
			var segmento := SegmentShape2D.new()
			segmento.a = borda - tangente
			segmento.b = borda + tangente
			var colisor := CollisionShape2D.new()
			colisor.shape = segmento
			limite.add_child(colisor)
	var suportes := StaticBody2D.new()
	$Colisoes.add_child(suportes)
	for objeto: Node2D in _objetos[0].get_children():
		if objeto.name.begins_with("portal"):
			_portal = objeto.global_position + Vector2(0, 46)
		for prefixo: String in APOIOS:
			if objeto.name.begins_with(prefixo):
				var forma := RectangleShape2D.new()
				forma.size = APOIOS[prefixo]
				var colisor := CollisionShape2D.new()
				colisor.position = objeto.global_position - Vector2(0, forma.size.y * 0.5)
				colisor.shape = forma
				suportes.add_child(colisor)
				break


func _montar_navegacao(piso: TileMapLayer) -> void:
	caminhos.region = Rect2i(0, 0, 41, 33)
	caminhos.cell_size = Vector2.ONE * TAMANHO_CELULA
	caminhos.offset = caminhos.cell_size * 0.5
	caminhos.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	caminhos.update()
	var forma := CircleShape2D.new()
	forma.radius = 14.0
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.collision_mask = 1
	var espaco := get_world_2d().direct_space_state
	for y in caminhos.region.end.y:
		for x in caminhos.region.end.x:
			var celula := Vector2i(x, y)
			var ponto := caminhos.get_point_position(celula)
			var no_piso := piso.get_cell_source_id(piso.local_to_map(piso.to_local(ponto))) != -1
			consulta.transform.origin = ponto
			caminhos.set_point_solid(celula, not no_piso or not espaco.intersect_shape(consulta, 1).is_empty())


func _mostrar_arena(indice: int) -> void:
	for i in _pisos.size():
		_pisos[i].visible = i == indice
		_objetos[i].visible = i == indice


func _physics_process(_delta: float) -> void:
	if not _pronta or concluida or jogador.vida <= 0:
		return
	hud.atualizar_recargas(jogador)
	if restaurada:
		var perto := jogador.colisor.global_position.distance_to(_portal) <= 56.0
		aviso.visible = perto
		if perto and Input.is_action_just_pressed("Interagir"):
			concluir()
	elif chefe.estado == TheSilence.Estado.ESPERA and Input.is_action_just_pressed("Interagir"):
		aviso.hide()
		painel_chefe.show()
		chefe.ativar()


func _fase_alterada(etapa: int) -> void:
	_mostrar_arena(etapa - 1)
	titulo.text = "The Silence  ·  %d/3 — %s" % [etapa, TITULOS[etapa - 1]]
	titulo.modulate = CORES_FASE[etapa - 1]
	_preenchimento.bg_color = CORES_FASE[etapa - 1]
	if etapa > 1:
		jogador.recuperar_uma_vida()
		chefe._mostrar_efeito(&"fragmentos_memoria", chefe.global_position, 65.0)


func _estado_alterado(estado: TheSilence.Estado) -> void:
	instrucao.modulate = Color.WHITE
	match estado:
		TheSilence.Estado.AVISO:
			match chefe._ataque:
				TheSilence.Ataque.ONDA:
					instrucao.text = "Onda · saia do círculo"
				TheSilence.Ataque.FENDA:
					instrucao.text = "Fenda · saia da marca"
				TheSilence.Ataque.INVESTIDA:
					instrucao.text = "Investida · desvie para o lado"
		TheSilence.Estado.VULNERAVEL:
			instrucao.text = "Vulnerável · ataque agora"
			instrucao.modulate = Color(0.64, 1.0, 0.85)
		TheSilence.Estado.TRANSICAO:
			instrucao.text = "Memória recuperada"
		_:
			instrucao.text = "Aguarde a abertura"


func _coletar_nota(_corpo: Node2D, nota: Area2D) -> void:
	if concluida or nota.is_queued_for_deletion():
		return
	nota.coletar()
	_notas_coletadas += 1
	_atualizar_notas()
	hud.destacar_pontos()


func _atualizar_notas() -> void:
	hud.atualizar_pontos(_notas_coletadas, CELULAS_NOTAS.size(), _notas_coletadas * 100)


func _restaurar_arena() -> void:
	restaurada = true
	FEEDBACK.faixa(self, "O SILÊNCIO FOI DERROTADO", "A arena foi restaurada · A música voltou", Color(1.0, 0.9, 0.55), 0.16, 3.6)
	jogador._tremer_camera(1.4)
	_mostrar_arena(3)
	painel_chefe.hide()
	chefe._mostrar_efeito(&"onda_restauracao", chefe.global_position, 128.0)
	chefe._mostrar_efeito(&"restauracao_particulas", chefe.global_position, 100.0)
	aviso_texto.text = "E — Atravessar o portal restaurado"


func dev_espelho_liberado() -> bool:
	return restaurada


func dev_posicao_final() -> Vector2:
	return _portal


func concluir() -> void:
	if concluida or not restaurada or jogador.vida <= 0:
		return
	concluida = true
	FEEDBACK.encerrar(self)
	jogador.process_mode = Node.PROCESS_MODE_DISABLED
	aviso.hide()
	final.get_node("Conteudo/Pontos").text = "Notas  %d/%d    Pontos  %d" % [_notas_coletadas, CELULAS_NOTAS.size(), _notas_coletadas * 100]
	final.show()
	final.get_node("Conteudo/Voltar").grab_focus()


func _voltar() -> void:
	get_tree().change_scene_to_file(PROGRESSAO.MENU)
