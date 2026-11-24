extends Node2D

const FEEDBACK := preload("res://Scripts/feedback_vitoria.gd")
const TENTATIVAS := preload("res://Scripts/tentativas.gd")
const CAPANGA := preload("res://Scenes/capanga.tscn")
const CHEFE := preload("res://Scenes/chefe_smooth.tscn")
const CURA := preload("res://Scenes/cura_thriller.tscn")
const NOTA_MUSICAL := preload("res://Scripts/nota_musical.gd")
const PROGRESSAO := preload("res://Scripts/progressao.gd")
const Holofote := preload("res://Scripts/holofote_smooth.gd")

enum Objetivo { ENERGIA, ACESSO_VIP, SEGURANCA, PALCO, CHEFE, ESPELHO }

const NOTAS: Array[Vector2i] = [
	Vector2i(26, 33), Vector2i(21, 29), Vector2i(6, 20), Vector2i(15, 14),
	Vector2i(25, 25), Vector2i(44, 17), Vector2i(40, 25), Vector2i(9, 8), Vector2i(39, 6),
]
const CURAS: Array[Vector2i] = [Vector2i(44, 22), Vector2i(17, 14)]
const CASA_CHEFE := Vector2(768, 276)
const POSICAO_VIP := Vector2(1018, 672)
const FRENTE_ESPELHO := Vector2(768, 156)
const ALCANCE_INTERACAO := 54.0
const LIMITE_PALCO := Rect2(128, 128, 1280, 202)

var caminhos := AStarGrid2D.new()
var objetivo := Objetivo.ENERGIA
var concluida := false
var pontuacao := 0
var _notas_coletadas := 0
var _alarme := 0.0
var _progresso_luz := 0.0
var _estagio_chefe := 1
var _guarda_vencido := false
var _marcador := Line2D.new()

@onready var piso: TileMapLayer = $Piso
@onready var atores: Node2D = $Atores
@onready var jogador: MichaelJogador = $Atores/Michael_Player
@onready var pes: CollisionShape2D = $Atores/Michael_Player/Michael_Colisor
@onready var portao_vip: StaticBody2D = $Catracas/VIP
@onready var portao_palco: StaticBody2D = $Catracas/Palco
@onready var hud = $Interface/HUD
@onready var painel_chefe: PanelContainer = $Interface/Chefe
@onready var nome_chefe: Label = $Interface/Chefe/Conteudo/Nome
@onready var vida_chefe: ProgressBar = $Interface/Chefe/Conteudo/Vida
@onready var vigia: Label = $Interface/Missao/Conteudo/Vigilancia
@onready var missao: Label = $Interface/Missao/Conteudo/Objetivo
@onready var interacao: PanelContainer = $Interface/Interacao
@onready var texto_interacao: Label = $Interface/Interacao/Conteudo/Texto
@onready var conclusao: PanelContainer = $Interface/Conclusao
@onready var jukebox: StaticBody2D = $Atores/Jukebox


func _ready() -> void:
	set_physics_process(false)
	TENTATIVAS.registrar_fase(scene_file_path)
	hud.iniciar(jogador)
	_atualizar_notas()
	_marcador.points = PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0), Vector2(0, -5)])
	_marcador.width = 2.0
	_marcador.default_color = Color(1.0, 0.76, 0.38)
	_marcador.z_index = 3
	add_child(_marcador)
	_marcador.global_position = jukebox.global_position + Vector2(0, -65)
	var camera := jogador.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()

	# Aguarda os corpos estáticos entrarem no espaço antes de consultar colisões.
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_montar_navegacao()
	for celula in NOTAS:
		var nota := NOTA_MUSICAL.criar(celula, piso.map_to_local(celula))
		nota.set_meta("celula", celula)
		nota.body_entered.connect(_coletar_nota.bind(nota), CONNECT_ONE_SHOT)
		atores.add_child(nota)
	for celula in CURAS:
		var cura := CURA.instantiate() as Area2D
		cura.position = piso.map_to_local(celula)
		atores.add_child(cura)
	_criar_capanga("comum", Vector2(848, 988), "CapangaEntrada")
	_criar_capanga("comum", Vector2(544, 608), "CapangaSalao")
	_criar_capanga("agil", Vector2(834, 704), "VigiaSalao")
	_criar_capanga("agil", Vector2(1400, 552), "VigiaVIP")
	var seguranca := _criar_capanga("seguranca", Vector2(1270, 650), "SegurancaVIP")
	seguranca.derrotado.connect(_derrotar_seguranca)
	set_physics_process(true)


func _montar_navegacao() -> void:
	caminhos.region = Rect2i(0, 0, 48, 36)
	caminhos.cell_size = Vector2(32, 32)
	caminhos.offset = caminhos.cell_size * 0.5
	caminhos.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	caminhos.update()
	var base := RectangleShape2D.new()
	base.size = Vector2(22, 22)
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = base
	consulta.collision_mask = 1
	consulta.exclude = [portao_vip.get_rid(), portao_palco.get_rid()]
	var espaco := get_world_2d().direct_space_state
	for y in range(36):
		for x in range(48):
			var celula := Vector2i(x, y)
			consulta.transform = Transform2D(0.0, piso.map_to_local(celula))
			var solida := piso.get_cell_source_id(celula) == -1 or not espaco.intersect_shape(consulta, 1).is_empty()
			caminhos.set_point_solid(celula, solida)
	_atualizar_portao(portao_vip, false)
	_atualizar_portao(portao_palco, false)


func _atualizar_portao(portao: StaticBody2D, aberto: bool) -> void:
	var base := portao.get_node("Base") as CollisionShape2D
	var tamanho := (base.shape as RectangleShape2D).size
	var primeira := piso.local_to_map(portao.position - tamanho / 2.0)
	var ultima := piso.local_to_map(portao.position + tamanho / 2.0 - Vector2.ONE)
	for y in range(primeira.y, ultima.y + 1):
		for x in range(primeira.x, ultima.x + 1):
			caminhos.set_point_solid(Vector2i(x, y), not aberto)
	portao.visible = not aberto
	base.set_deferred("disabled", aberto)


func _criar_capanga(tipo: String, posicao: Vector2, nome: String) -> Inimigo:
	var capanga := CAPANGA.instantiate()
	capanga.name = nome
	capanga.configurar(tipo)
	capanga.alvo = pes
	capanga.caminhos = caminhos
	capanga.position = posicao
	atores.add_child(capanga)
	return capanga


func _physics_process(delta: float) -> void:
	if concluida or jogador.vida <= 0:
		return
	hud.atualizar_recargas(jogador)
	_atualizar_vigilancia(delta)
	if objetivo == Objetivo.PALCO and LIMITE_PALCO.has_point(pes.global_position):
		_comecar_chefe()
	_atualizar_interacao()


func _atualizar_vigilancia(delta: float) -> void:
	var novo := 0.0
	for holofote: Holofote in $Holofotes.get_children():
		novo = maxf(novo, holofote.observar(pes.global_position, delta))
	if novo >= 1.0 and _progresso_luz < 1.0:
		_alarme = 2.5
		for inimigo in get_tree().get_nodes_in_group("inimigos"):
			if inimigo.has_method("ouvir_alarme"):
				inimigo.ouvir_alarme(pes.global_position)
	_progresso_luz = novo
	_alarme = maxf(0.0, _alarme - delta)
	if novo >= 1.0 or _alarme > 0.0:
		vigia.text = "Vigilância · detectado"
		vigia.modulate = Color(1.0, 0.55, 0.5)
	elif novo > 0.0:
		vigia.text = "Vigilância · observado"
		vigia.modulate = Color(1.0, 0.84, 0.55)
	else:
		vigia.text = "Vigilância · área segura"
		vigia.modulate = Color(0.76, 0.88, 0.95)


func _atualizar_interacao() -> void:
	var mensagem := ""
	var pode_interagir := false
	match objetivo:
		Objetivo.ENERGIA:
			if pes.global_position.distance_to(jukebox.global_position) <= ALCANCE_INTERACAO:
				mensagem = "E — Restaurar energia"
				pode_interagir = true
			elif pes.global_position.distance_to(POSICAO_VIP) <= ALCANCE_INTERACAO:
				mensagem = "O acesso VIP está sem energia"
		Objetivo.ACESSO_VIP:
			if pes.global_position.distance_to(POSICAO_VIP) <= ALCANCE_INTERACAO:
				mensagem = "E — Abrir acesso VIP"
				pode_interagir = true
		Objetivo.ESPELHO:
			if pes.global_position.distance_to(FRENTE_ESPELHO) <= ALCANCE_INTERACAO:
				mensagem = "E — Recuperar a memória"
				pode_interagir = true
	interacao.visible = not mensagem.is_empty()
	texto_interacao.text = mensagem
	if not pode_interagir or not Input.is_action_just_pressed("Interagir"):
		return
	match objetivo:
		Objetivo.ENERGIA:
			objetivo = Objetivo.ACESSO_VIP
			$Holofotes/Salao.ligar(true)
			$Holofotes/VIP.ligar(true)
			missao.text = "Energia ligada. Abra o acesso VIP"
			_marcador.global_position = POSICAO_VIP + Vector2(35, -12)
		Objetivo.ACESSO_VIP:
			_atualizar_portao(portao_vip, true)
			_marcador.hide()
			if _guarda_vencido:
				_abrir_palco()
			else:
				objetivo = Objetivo.SEGURANCA
				missao.text = "Derrote a segurança do VIP"
		Objetivo.ESPELHO:
			concluir()


func _derrotar_seguranca() -> void:
	_guarda_vencido = true
	if objetivo == Objetivo.SEGURANCA:
		_abrir_palco()


func _abrir_palco() -> void:
	objetivo = Objetivo.PALCO
	_atualizar_portao(portao_palco, true)
	missao.text = "Palco liberado pela escadaria"
	_marcador.global_position = portao_palco.global_position
	_marcador.show()


func _comecar_chefe() -> void:
	objetivo = Objetivo.CHEFE
	_atualizar_portao(portao_palco, false)
	_marcador.hide()
	missao.text = "Derrote o líder dos capangas"
	var chefe := CHEFE.instantiate()
	chefe.position = CASA_CHEFE
	chefe.alvo = pes
	chefe.caminhos = caminhos
	atores.add_child(chefe)
	chefe.vida_alterada.connect(_atualizar_vida_chefe)
	chefe.etapa_alterada.connect(_atualizar_etapa_chefe)
	chefe.derrotado.connect(_derrotar_chefe)
	vida_chefe.max_value = chefe.vida
	vida_chefe.value = chefe.vida
	painel_chefe.show()
	chefe.ativar()


func _atualizar_vida_chefe(restante: int) -> void:
	vida_chefe.value = restante


func _atualizar_etapa_chefe(etapa: int) -> void:
	var ativar_reforcos := _estagio_chefe < 2 and etapa >= 2
	_estagio_chefe = etapa
	if ativar_reforcos:
		$Holofotes/PalcoOeste.ligar(true)
		$Holofotes/PalcoLeste.ligar(true)
		_criar_capanga("agil", Vector2(560, 288), "ReforcoOeste")
		_criar_capanga("comum", Vector2(1010, 296), "ReforcoLeste")
	nome_chefe.text = "Líder · holofotes e reforços" if etapa == 2 else "Líder · investidas"


func _derrotar_chefe() -> void:
	FEEDBACK.faixa(self, "CHEFE DERROTADO", "O caminho até o espelho está livre", Color(1.0, 0.86, 0.5), 0.30)
	objetivo = Objetivo.ESPELHO
	_atualizar_portao(portao_palco, true)
	$Holofotes/PalcoOeste.ligar(false)
	$Holofotes/PalcoLeste.ligar(false)
	painel_chefe.hide()
	missao.text = "Líder derrotado. Alcance o espelho"
	_marcador.global_position = FRENTE_ESPELHO + Vector2(0, -20)
	_marcador.show()


func _coletar_nota(_corpo: Node2D, nota: Area2D) -> void:
	if concluida:
		return
	nota.coletar()
	_notas_coletadas += 1
	pontuacao = _notas_coletadas * 100
	_atualizar_notas()
	hud.destacar_pontos()


func _atualizar_notas() -> void:
	hud.atualizar_pontos(_notas_coletadas, NOTAS.size(), pontuacao)


func concluir() -> void:
	if concluida or jogador.vida <= 0 or objetivo != Objetivo.ESPELHO:
		return
	concluida = true
	FEEDBACK.encerrar(self)
	atores.process_mode = Node.PROCESS_MODE_DISABLED
	interacao.hide()
	conclusao.show()
	$Interface/Conclusao/Conteudo/Resultado.text = "Smooth Criminal · Memória restaurada\nNotas %d/%d    Pontos %d" % [_notas_coletadas, NOTAS.size(), pontuacao]
	$Interface/Conclusao/Conteudo/Voltar.grab_focus()


func _avancar() -> void:
	get_tree().change_scene_to_file(PROGRESSAO.ULTIMO_ECO)


func dev_posicao_central() -> Vector2:
	return Vector2(744, 657)


func dev_posicao_regiao_3() -> Vector2:
	return Vector2(1185, 606)


func dev_posicao_final() -> Vector2:
	return FRENTE_ESPELHO - Vector2(0, 10)


func dev_espelho_liberado() -> bool:
	return objetivo == Objetivo.ESPELHO


func dev_progresso() -> String:
	return "%s · Notas %d/%d" % [missao.text, _notas_coletadas, NOTAS.size()]


func dev_coletar_nota() -> void:
	for no in atores.get_children():
		if no is Area2D and no.has_meta("celula") and not no.is_queued_for_deletion():
			_coletar_nota(jogador, no)
			return
