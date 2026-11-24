extends Node2D

const TENTATIVAS := preload("res://Scripts/tentativas.gd")
const PROGRESSAO := preload("res://Scripts/progressao.gd")
const NOTA_MUSICAL := preload("res://Scripts/nota_musical.gd")
const DETETIVE := preload("res://Scenes/detetive.tscn")
const TIPO := preload("res://Scripts/detetive.gd").Tipo
const Barreira := preload("res://Scripts/barreira_memoria.gd")
const HALO_POSTE := preload("res://Assets/BillieJean/halo_poste.png")

const CELULA := 32
const REGIOES := [
	{
		"nome": "Rua esquecida",
		"ponto": "Relogio",
		"inicio": 1360,
		"barreira": 1088,
		"pisos": Rect2i(12, 35, 7, 2),
		"cota": 6,
		"guia": "Acenda os pisos junto ao relógio, no fim da rua à esquerda.",
		"detetives": [Vector2i(27, 38), Vector2i(17, 37)],
		"tipos": [TIPO.COMUM, TIPO.COMUM],
	},
	{
		"nome": "Avenida apagada",
		"ponto": "Jukebox",
		"inicio": 1088,
		"barreira": 720,
		"pisos": Rect2i(38, 23, 2, 10),
		"cota": 8,
		"guia": "Acenda os pisos da calçada direita para restaurar a jukebox.",
		"detetives": [Vector2i(35, 30), Vector2i(31, 26)],
		"tipos": [TIPO.COMUM, TIPO.RAPIDO],
	},
	{
		"nome": "Praça da memória",
		"ponto": "Fonte",
		"inicio": 720,
		"barreira": 352,
		"pisos": Rect2i(29, 17, 5, 5),
		"cota": 11,
		"guia": "Acenda o mosaico da praça e derrote o detetive especial para restaurar a fonte.",
		"detetives": [Vector2i(34, 19), Vector2i(31, 16)],
		"tipos": [TIPO.COMUM, TIPO.ESPECIAL],
	},
]
const NOTAS: Array[Vector2i] = [
	Vector2i(19, 43), Vector2i(49, 41), Vector2i(7, 36),
	Vector2i(24, 31), Vector2i(55, 31), Vector2i(14, 25),
	Vector2i(39, 20), Vector2i(25, 15), Vector2i(38, 12),
]

var caminhos := AStarGrid2D.new()
var concluida := false

var _pisos_acesos: Dictionary[Vector2i, Vector2i] = {}
var _barreiras: Array[Barreira] = []
var _restauradas := [false, false, false]
var _regiao := 0
var _pisos_da_regiao := 0
var _detetives_restantes := 0
var _encontro_iniciado := false
var _inicio_pronto := false
var _notas_coletadas := 0
var _avanco := ""
var _tempo_avanco := 0.0
var _espera_spawn := 0.0

@onready var chao: TileMapLayer = $Chao
@onready var pisos: TileMapLayer = $PisosLuminosos
@onready var atores: Node2D = $Atores
@onready var jogador: MichaelJogador = $Atores/Michael_Player
@onready var pes: CollisionShape2D = $Atores/Michael_Player/Michael_Colisor
@onready var espelho: StaticBody2D = $Atores/Espelho
@onready var hud = $Interface/HUD
@onready var titulo: Label = $Interface/Objetivo/Conteudo/Regiao
@onready var detalhe: Label = $Interface/Objetivo/Conteudo/Detalhe
@onready var aviso_espelho: PanelContainer = $Interface/Espelho


func _ready() -> void:
	TENTATIVAS.registrar_fase(scene_file_path)
	hud.iniciar(jogador)
	NOTA_MUSICAL.instalar_indicador(self)
	_atualizar_notas()
	var mapa := chao.get_used_rect()
	var camera: Camera2D = jogador.get_node("Camera2D")
	camera.limit_right = mapa.end.x * CELULA
	camera.limit_bottom = mapa.end.y * CELULA
	camera.position.y = -56.0
	camera.reset_smoothing()
	camera.force_update_scroll()
	for celula in pisos.get_used_cells():
		var atlas := pisos.get_cell_atlas_coords(celula)
		if atlas.x == 0:
			var cor := 1 if celula.x < 31 else 2
			if celula.y >= 35 and celula.x >= 31:
				cor = 3
			atlas.x = cor
		_pisos_acesos[celula] = atlas
		pisos.set_cell(celula, 0, Vector2i(0, atlas.y))

	for celula in NOTAS:
		var nota := NOTA_MUSICAL.criar(celula, chao.map_to_local(celula))
		nota.body_entered.connect(_coletar_nota.bind(nota), CONNECT_ONE_SHOT)
		atores.add_child(nota)
	espelho.modulate = Color(0.59, 0.53, 0.68)
	_atualizar_objetivo()
	await get_tree().physics_frame
	_montar_navegacao(mapa)
	for regiao in REGIOES:
		var barreira := Barreira.new()
		barreira.position.y = regiao.barreira
		barreira.montar(camera.limit_right)
		add_child(barreira)
		_barreiras.append(barreira)
	_gerar_detetive(TIPO.RAPIDO, chao.map_to_local(Vector2i(7, 39)))
	_gerar_detetive(TIPO.COMUM, chao.map_to_local(Vector2i(52, 31)))
	_inicio_pronto = true


func _montar_navegacao(mapa: Rect2i) -> void:
	caminhos.region = mapa
	caminhos.cell_size = Vector2(CELULA, CELULA)
	caminhos.offset = caminhos.cell_size * 0.5
	caminhos.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	caminhos.update()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(20, 20)
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.collision_mask = 1
	var espaco := get_world_2d().direct_space_state
	for celula in chao.get_used_cells():
		consulta.transform.origin = chao.map_to_local(celula)
		caminhos.set_point_solid(celula, not espaco.intersect_shape(consulta, 1).is_empty())


func _physics_process(delta: float) -> void:
	if not _inicio_pronto or concluida or jogador.vida <= 0:
		return
	hud.atualizar_recargas(jogador)
	if _tempo_avanco > 0.0:
		_tempo_avanco -= delta
		if _tempo_avanco <= 0.0:
			_atualizar_objetivo()

	var celula := pisos.local_to_map(pes.global_position)
	_acender_piso(celula)
	if _regiao < REGIOES.size():
		var regiao: Dictionary = REGIOES[_regiao]
		_espera_spawn -= delta
		if not _encontro_iniciado and pes.global_position.y <= regiao.inicio and _espera_spawn <= 0.0:
			_tentar_iniciar_encontro()
		_verificar_passagem()
	aviso_espelho.visible = pes.global_position.distance_to(espelho.global_position + Vector2(0, 20)) <= 54.0
	if aviso_espelho.visible:
		$Interface/Espelho/Texto.text = "E — Interagir com o espelho" if dev_espelho_liberado() else "A memória ainda está apagada"
		if Input.is_action_just_pressed("Interagir"):
			concluir()


func _acender_piso(celula: Vector2i) -> void:
	if not _pisos_acesos.has(celula) or pisos.get_cell_atlas_coords(celula).x != 0:
		return
	pisos.set_cell(celula, 0, _pisos_acesos[celula])
	if _regiao < REGIOES.size() and REGIOES[_regiao].pisos.has_point(celula):
		_pisos_da_regiao += 1
		_atualizar_objetivo()


func _tentar_iniciar_encontro() -> void:
	var regiao: Dictionary = REGIOES[_regiao]
	var vagas: Array[Vector2] = []
	for ancora: Vector2i in regiao.detetives:
		var vaga := _achar_vaga(ancora, vagas)
		if vaga == Vector2.INF:
			# Um corpo pode ocupar a vaga neste quadro. Tenta de novo sem avançar o encontro.
			_espera_spawn = 0.3
			return
		vagas.append(vaga)

	_encontro_iniciado = true
	_detetives_restantes = vagas.size()
	for i in vagas.size():
		var detetive := _gerar_detetive(regiao.tipos[i], vagas[i], true)
		detetive.derrotado.connect(_ao_derrotar_detetive)
	_atualizar_objetivo()


func _achar_vaga(ancora: Vector2i, reservadas: Array[Vector2]) -> Vector2:
	var forma := CircleShape2D.new()
	forma.radius = 13.0
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.collision_mask = 7
	var espaco := get_world_2d().direct_space_state
	for raio in range(4):
		for y in range(-raio, raio + 1):
			for x in range(-raio, raio + 1):
				var celula := ancora + Vector2i(x, y)
				if not caminhos.is_in_boundsv(celula) or caminhos.is_point_solid(celula):
					continue
				var ponto := chao.map_to_local(celula)
				if ponto.y < REGIOES[_regiao].barreira + CELULA or ponto.y > REGIOES[_regiao].inicio + CELULA:
					continue
				if reservadas.has(ponto):
					continue
				consulta.transform.origin = ponto
				if espaco.intersect_shape(consulta, 1).is_empty():
					return ponto
	return Vector2.INF


func _gerar_detetive(tipo: int, posicao: Vector2, obrigatoria := false) -> Inimigo:
	var detetive = DETETIVE.instantiate()
	detetive.position = posicao
	detetive.configurar(tipo, obrigatoria)
	detetive.alvo = pes
	detetive.caminhos = caminhos
	detetive.atraso_aparicao = 0.42
	atores.add_child(detetive)
	return detetive


func _ao_derrotar_detetive() -> void:
	_detetives_restantes -= 1
	_atualizar_objetivo()


func _verificar_passagem() -> void:
	if _encontro_iniciado and _detetives_restantes == 0 and _pisos_da_regiao >= REGIOES[_regiao].cota:
		_liberar_passagem()


func _restaurar_ponto(indice: int) -> void:
	if _restauradas[indice]:
		return
	_restauradas[indice] = true
	var ponto := atores.get_node(NodePath(REGIOES[indice].ponto))
	ponto.get_node("Apagado").hide()
	ponto.get_node("Restaurado").show()
	var brilho: Sprite2D = ponto.get_node("Brilho")
	brilho.show()
	brilho.modulate.a = 0.0
	brilho.create_tween().tween_property(brilho, "modulate:a", 0.68, 0.6)
	var inicio := float(REGIOES[indice - 1].barreira) if indice > 0 else INF
	var fim := float(REGIOES[indice].barreira) if indice < REGIOES.size() - 1 else 0.0
	for ator in atores.get_children():
		if not ator.has_node("Aceso") or ator.position.y > inicio or ator.position.y <= fim:
			continue
		ator.get_node("Apagado").hide()
		ator.get_node("Aceso").show()
		if not ator.name.begins_with("poste_"):
			continue
		var halo := Sprite2D.new()
		halo.texture = HALO_POSTE
		halo.position.y = -65.0
		halo.modulate.a = 0.38
		halo.z_index = 1
		ator.add_child(halo)


func _liberar_passagem() -> void:
	_restaurar_ponto(_regiao)
	_barreiras[_regiao].dissipar()
	_regiao += 1
	_encontro_iniciado = false
	_detetives_restantes = 0
	_pisos_da_regiao = 0
	_espera_spawn = 0.0
	_avanco = "Memória restaurada · Passagem liberada"
	_tempo_avanco = 2.6
	if dev_espelho_liberado():
		espelho.modulate = Color.WHITE
	else:
		for celula: Vector2i in _pisos_acesos:
			if REGIOES[_regiao].pisos.has_point(celula) and pisos.get_cell_atlas_coords(celula).x > 0:
				_pisos_da_regiao += 1
	_atualizar_objetivo()


func _atualizar_objetivo() -> void:
	if dev_espelho_liberado():
		titulo.text = "Memória restaurada · 3/3"
		detalhe.text = "O espelho está aberto. Siga ao norte."
		return
	var regiao: Dictionary = REGIOES[_regiao]
	titulo.text = "%s · %d/3" % [regiao.nome, _regiao]
	var progresso := "Pisos %d/%d" % [mini(_pisos_da_regiao, regiao.cota), regiao.cota]
	if _encontro_iniciado:
		progresso += "   ·   Detetives restantes %d" % _detetives_restantes
	detalhe.text = "%s\n%s" % [_avanco if _tempo_avanco > 0.0 else regiao.guia, progresso]


func _coletar_nota(_corpo: Node2D, nota: Area2D) -> void:
	if concluida or nota.is_queued_for_deletion():
		return
	nota.coletar()
	_notas_coletadas += 1
	_atualizar_notas()
	hud.destacar_pontos()


func _atualizar_notas() -> void:
	hud.atualizar_pontos(_notas_coletadas, NOTAS.size(), _notas_coletadas * 100)


func concluir() -> void:
	if concluida or jogador.vida <= 0 or not dev_espelho_liberado():
		return
	concluida = true
	get_tree().change_scene_to_file(PROGRESSAO.THRILLER)


func dev_espelho_liberado() -> bool:
	return _regiao == REGIOES.size()


func indicador_notas_suprimido() -> bool:
	# Durante a perseguição o indicador some para não competir com os detetives.
	return concluida or jogador.vida <= 0 or (_encontro_iniciado and _detetives_restantes > 0)


func dev_posicao_central() -> Vector2:
	return Vector2(992, 1032)


func dev_posicao_regiao_3() -> Vector2:
	return Vector2(992, 674)


func dev_posicao_final() -> Vector2:
	return espelho.global_position + Vector2(0, 32)


func dev_restaurar_pontos() -> void:
	for celula: Vector2i in _pisos_acesos:
		_acender_piso(celula)
	for indice in REGIOES.size():
		_restaurar_ponto(indice)


func dev_completar_objetivos() -> void:
	if not _inicio_pronto:
		return
	for detetive: Inimigo in get_tree().get_nodes_in_group("inimigos"):
		if detetive.has_meta("obrigatorio") and detetive.vida > 0:
			detetive.receber_dano(detetive.vida)
	dev_restaurar_pontos()
	while not dev_espelho_liberado():
		_liberar_passagem()


func dev_gerar_onda() -> void:
	if not _inicio_pronto or get_tree().get_node_count_in_group("inimigos") >= 8:
		return
	var celula := chao.local_to_map(jogador.global_position)
	var consulta := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 13.0
	consulta.shape = forma
	consulta.collision_mask = 7
	for deslocamento in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3)]:
		var vaga: Vector2i = celula + deslocamento
		if caminhos.is_in_boundsv(vaga) and not caminhos.is_point_solid(vaga):
			consulta.transform.origin = chao.map_to_local(vaga)
			if get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty():
				_gerar_detetive(TIPO.COMUM, consulta.transform.origin)
				return


func dev_coletar_nota() -> void:
	for nota in atores.get_children():
		if nota is Area2D and nota.name.begins_with("Nota_") and not nota.is_queued_for_deletion():
			_coletar_nota(jogador, nota)
			return


func dev_progresso() -> String:
	return "Memórias %d/3  ·  Notas %d/%d" % [_restauradas.count(true), _notas_coletadas, NOTAS.size()]
