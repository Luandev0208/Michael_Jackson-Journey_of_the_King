extends CanvasLayer

const PROGRESSAO := preload("res://Scripts/progressao.gd")
const TEMA := preload("res://Assets/tema_menu.tres")
const CENA_INIMIGO := preload("res://Scenes/inimigo.tscn")

var _painel: PanelContainer
var _status: Label
var _invencivel: CheckButton
var _ia: CheckButton
var _velocidade: SpinBox
var _teleporte_final: Button
var _teleporte_central: Button
var _teleporte_praca: Button
var _restaurar_pontos: Button
var _completar_testes: Button
var _nota: Button
var _concluir: Button
var _fases: Dictionary
var _pausa_anterior := false
var _ia_ativa := true
var _jogador: MichaelJogador
var _fase: Node

func _ready() -> void:
	if not _permitido():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	set_process(false)
	get_tree().node_added.connect(_ao_adicionar_no)
	_fases = PROGRESSAO.fases_disponiveis()
	_criar_painel()

func _permitido() -> bool:
	return OS.is_debug_build() and OS.has_feature("editor")

func _input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	if evento.keycode != KEY_F1 and evento.physical_keycode != KEY_F1:
		return
	if not is_instance_valid(_painel):
		return
	if _painel.visible:
		_fechar()
	else:
		_fase = get_tree().current_scene
		_jogador = get_tree().get_first_node_in_group("jogador") as MichaelJogador
		if not is_instance_valid(_jogador):
			return
		_abrir()
	get_viewport().set_input_as_handled()

func _abrir() -> void:
	_pausa_anterior = get_tree().paused
	get_tree().paused = true
	_invencivel.set_pressed_no_signal(_jogador.invencivel_dev)
	_ia.set_pressed_no_signal(_ia_ativa)
	_velocidade.set_value_no_signal(_jogador.velocidade_movimento)
	_teleporte_final.disabled = not _fase.has_method("dev_posicao_final")
	_teleporte_central.visible = _fase.has_method("dev_posicao_central")
	_teleporte_praca.visible = _fase.has_method("dev_posicao_regiao_3")
	_restaurar_pontos.visible = _fase.has_method("dev_restaurar_pontos")
	_completar_testes.visible = _fase.has_method("dev_completar_objetivos")
	_nota.disabled = not _fase.has_method("dev_coletar_nota")
	_concluir.disabled = not _fase.has_method("concluir") or (_fase.has_method("dev_espelho_liberado") and not _fase.dev_espelho_liberado())
	_painel.show()
	set_process(true)
	_process(0.0)

func _fechar() -> void:
	_painel.hide()
	get_tree().paused = _pausa_anterior
	set_process(false)

func _process(_delta: float) -> void:
	if not is_instance_valid(_jogador):
		_fechar()
		return
	var progresso := "Notas —"
	if _fase.has_method("dev_progresso"):
		progresso = _fase.dev_progresso()
	var nome: String = str(_fase.name)
	for rotulo: String in _fases:
		if _fases[rotulo] == _fase.scene_file_path:
			nome = rotulo
			break
	var posicao := Vector2i(_jogador.global_position.round())
	_status.text = "%s  ·  %d FPS  ·  Posição %d, %d\nVida %d/%d  ·  Inimigos %d  ·  %s  ·  Invencível %s" % [
		nome, Engine.get_frames_per_second(), posicao.x, posicao.y, _jogador.vida,
		MichaelJogador.VIDA_MAXIMA, _inimigos().size(), progresso,
		"sim" if _jogador.invencivel_dev else "não",
	]

func _criar_painel() -> void:
	_painel = PanelContainer.new()
	_painel.name = "PainelDev"
	add_child(_painel)
	_painel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_painel.offset_left = -304.0
	_painel.offset_right = 304.0
	_painel.offset_top = -168.0
	_painel.offset_bottom = 168.0
	_painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_painel.theme = TEMA
	var corpo := VBoxContainer.new()
	_painel.add_child(corpo)
	corpo.add_theme_constant_override("separation", 8)
	var cabecalho := HBoxContainer.new()
	corpo.add_child(cabecalho)
	var titulo := _rotulo(cabecalho, "Ferramentas de desenvolvimento", 17)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_botao(cabecalho, "Fechar  ·  F1", _fechar)
	_status = _rotulo(corpo, "", 12)
	var colunas := HBoxContainer.new()
	colunas.add_theme_constant_override("separation", 12)
	corpo.add_child(colunas)

	var navegacao := _coluna(colunas, "Navegação")
	for nome: String in _fases:
		_botao(navegacao, nome, _mudar_cena.bind(_fases[nome]))
	_botao(navegacao, "Reiniciar a cena", _reiniciar)
	_botao(navegacao, "Menu principal", _mudar_cena.bind(PROGRESSAO.MENU))

	var personagem := _coluna(colunas, "Michael")
	_invencivel = _check(personagem, "Invencibilidade", _definir_invencibilidade)
	_botao(personagem, "Recuperar vidas", func(): _jogador.restaurar_vida())
	_botao(personagem, "Restaurar recargas", func(): _jogador.restaurar_recargas())
	_botao(personagem, "Ir para o início", _ir_para_inicio)
	_teleporte_central = _botao(personagem, "Ir à região central", _ir_para_centro)
	_teleporte_praca = _botao(personagem, "Ir à região 3", _ir_para_praca)
	_teleporte_final = _botao(personagem, "Ir ao espelho / final", _ir_para_final)
	var linha := HBoxContainer.new()
	personagem.add_child(linha)
	_rotulo(linha, "Velocidade", 12)
	_velocidade = SpinBox.new()
	_velocidade.min_value = 20.0
	_velocidade.max_value = 240.0
	_velocidade.step = 5.0
	_velocidade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_velocidade.add_theme_font_size_override("font_size", 12)
	linha.add_child(_velocidade)
	_velocidade.value_changed.connect(func(valor: float): _jogador.velocidade_movimento = valor)

	var testes := _coluna(colunas, "Inimigos")
	_botao(testes, "Gerar até 3 inimigos", _gerar_onda)
	_botao(testes, "Eliminar inimigos", _eliminar_inimigos)
	_ia = _check(testes, "IA ativa", _definir_ia)
	_rotulo(testes, "Progressão", 14)
	_nota = _botao(testes, "Coletar uma nota", func(): _fase.dev_coletar_nota())
	_restaurar_pontos = _botao(testes, "Restaurar pontos", func(): _fase.dev_restaurar_pontos())
	_completar_testes = _botao(testes, "Completar objetivos de teste", _completar_objetivos_teste)
	_concluir = _botao(testes, "Concluir objetivo", _concluir_objetivo)
	_painel.hide()

func _coluna(pai: HBoxContainer, titulo: String) -> VBoxContainer:
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 4)
	pai.add_child(coluna)
	_rotulo(coluna, titulo, 14)
	return coluna

func _rotulo(pai: Container, texto: String, tamanho: int) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", tamanho)
	pai.add_child(rotulo)
	return rotulo

func _botao(pai: Container, texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size.y = 24.0
	botao.add_theme_font_size_override("font_size", 12)
	pai.add_child(botao)
	botao.pressed.connect(acao)
	return botao

func _check(pai: Container, texto: String, acao: Callable) -> CheckButton:
	var botao := CheckButton.new()
	botao.text = texto
	botao.add_theme_font_size_override("font_size", 12)
	pai.add_child(botao)
	botao.toggled.connect(acao)
	return botao

func _mudar_cena(cena: String) -> void:
	if ResourceLoader.exists(cena, "PackedScene"):
		_fechar()
		get_tree().change_scene_to_file(cena)

func _reiniciar() -> void:
	_fechar()
	get_tree().reload_current_scene()

func _ir_para_inicio() -> void:
	_jogador.teletransportar(_jogador.posicao_inicial)
	_fechar()

func _ir_para_centro() -> void:
	_jogador.teletransportar(_fase.dev_posicao_central())
	_fechar()

func _ir_para_praca() -> void:
	_jogador.teletransportar(_fase.dev_posicao_regiao_3())
	_fechar()

func _ir_para_final() -> void:
	_jogador.teletransportar(_fase.dev_posicao_final())
	_fechar()

func _completar_objetivos_teste() -> void:
	_fase.dev_completar_objetivos()
	_concluir.disabled = not _fase.dev_espelho_liberado()

func _concluir_objetivo() -> void:
	_fechar()
	_fase.concluir()

func _definir_invencibilidade(ativa: bool) -> void:
	_jogador.invencivel_dev = ativa

func _inimigos() -> Array[Node]:
	return get_tree().get_nodes_in_group("inimigos")

func _ao_adicionar_no(no: Node) -> void:
	if no is Inimigo:
		no.ia_ativa = _ia_ativa

func _definir_ia(ativa: bool) -> void:
	_ia_ativa = ativa
	for inimigo: Inimigo in _inimigos():
		inimigo.ia_ativa = ativa

func _eliminar_inimigos() -> void:
	for inimigo: Inimigo in _inimigos():
		inimigo.receber_dano(inimigo.vida)

func _gerar_onda() -> void:
	if _fase.has_method("dev_gerar_onda"):
		_fase.dev_gerar_onda()
		return
	var camera := _jogador.get_node("Camera2D") as Camera2D
	var limites := Rect2(Vector2(camera.limit_left, camera.limit_top),
		Vector2(camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top)).grow(-12)
	var forma := CircleShape2D.new()
	forma.radius = 10.0
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.collision_mask = 7
	var vagas := mini(3, 11 - _inimigos().size())
	for i in 8:
		if vagas <= 0:
			break
		var posicao := _jogador.global_position + Vector2.RIGHT.rotated(i * TAU / 8.0) * 112.0
		if not limites.has_point(posicao):
			continue
		consulta.transform = Transform2D(0.0, posicao)
		if not _jogador.get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty():
			continue
		var inimigo := CENA_INIMIGO.instantiate() as Inimigo
		var pai := _jogador.get_parent()
		inimigo.position = pai.to_local(posicao)
		pai.add_child(inimigo)
		vagas -= 1
