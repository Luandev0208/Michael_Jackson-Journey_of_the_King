extends SceneTree

const BillieJean := preload("res://Scripts/billie_jean.gd")
const Thriller := preload("res://Scripts/thriller.gd")
const Smooth := preload("res://Scripts/smooth_criminal.gd")
const Guardiao := preload("res://Scripts/guardiao.gd")
const Zumbi := preload("res://Scripts/zumbi.gd")
const Detetive := preload("res://Scripts/detetive.gd")
const ChefeSmooth := preload("res://Scripts/chefe_smooth.gd")
const UltimoEco := preload("res://Scripts/ultimo_eco.gd")
const TheSilence := preload("res://Scripts/the_silence.gd")
const Indicador := preload("res://Scripts/indicador_notas.gd")
const Tentativas := preload("res://Scripts/tentativas.gd")

var _falhas := 0
var _verificacoes := 0


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	seed(1234)
	_testar_tentativas()
	await _testar_controles_e_combate()
	await _testar_billie_jean()
	await _testar_thriller()
	await _testar_smooth_criminal()
	await _testar_ultimo_eco()
	await _testar_reinicio_ultimo_eco()
	print("%d verificações, %d falhas" % [_verificacoes, _falhas])
	quit(1 if _falhas else 0)


func _testar_tentativas() -> void:
	Tentativas.reiniciar()
	Tentativas.registrar_fase("res://Scenes/billie_jean.tscn")
	_verificar(Tentativas.restantes == 3, "Cada fase começa com três tentativas")
	_verificar(Tentativas.consumir() == 2, "A primeira derrota deixa duas tentativas")
	Tentativas.registrar_fase("res://Scenes/billie_jean.tscn")
	_verificar(Tentativas.restantes == 2, "Recarregar a mesma fase mantém as tentativas")
	_verificar(Tentativas.consumir() == 1 and Tentativas.consumir() == 0, "A terceira derrota zera as tentativas")
	_verificar(Tentativas.consumir() == 0, "As tentativas nunca ficam negativas")
	Tentativas.registrar_fase("res://Scenes/thriller.tscn")
	_verificar(Tentativas.restantes == 3, "Uma nova fase começa com três tentativas")
	Tentativas.consumir()
	Tentativas.restaurar()
	_verificar(Tentativas.restantes == 3, "Recomeçar a fase após o Game Over restaura as três tentativas")
	Tentativas.reiniciar()
	_verificar(Tentativas.fase.is_empty() and Tentativas.restantes == 3, "Voltar ao menu zera o sistema")


func _verificar(condicao: bool, mensagem: String) -> void:
	_verificacoes += 1
	if not condicao:
		_falhas += 1
		push_error(mensagem)


func _quadros(quantidade: int) -> void:
	for i in quantidade:
		await physics_frame
	await process_frame


func _esperar(condicao: Callable, limite: int) -> bool:
	for i in limite:
		if condicao.call():
			return true
		await physics_frame
	return condicao.call()


func _comando(acao: StringName) -> void:
	Input.action_press(acao)
	await _quadros(2)
	Input.action_release(acao)


func _entrar(cena: String) -> void:
	if change_scene_to_file("res://Scenes/%s.tscn" % cena) == OK:
		await scene_changed
		await _quadros(4)


func _posicionar_pes(jogador: MichaelJogador, destino: Vector2) -> void:
	jogador.teletransportar(destino - jogador.colisor.position)


func _coletar_notas(jogador: MichaelJogador, total: int) -> void:
	var notas := get_nodes_in_group("notas_musicais")
	_verificar(notas.size() == total, "Quantidade inicial de notas em " + current_scene.name)
	for nota: Area2D in notas:
		var celula := String(nota.name)
		_posicionar_pes(jogador, nota.global_position)
		await _quadros(4)
		_verificar(not is_instance_valid(nota), "Coleta por colisão " + celula)


func _testar_controles_e_combate() -> void:
	print("Controles e combate")
	var arena := Node2D.new()
	root.add_child(arena)
	var jogador := preload("res://Scenes/michael.tscn").instantiate() as MichaelJogador
	jogador.position = Vector2(320, 180)
	arena.add_child(jogador)
	jogador.textura_chapeu = preload("res://Assets/Michael/Animacoes/Efeitos/chapeu_em_voo_preto.png")
	jogador.figurino_sem_chapeu = preload("res://Assets/Michael/Animacoes/BillieJean/michael_terno_escuro_sem_chapeu.tres")
	jogador.get_node("Camera2D").enabled = false
	var inicio := jogador.position
	Input.action_press(&"Direita")
	await _quadros(12)
	Input.action_release(&"Direita")
	_verificar(jogador.position.x > inicio.x + 12.0, "Movimento por input")
	var antes_dash := jogador.position
	Input.action_press(&"Direita")
	await _comando(&"Dash")
	Input.action_release(&"Direita")
	await _quadros(14)
	_verificar(jogador.position.x > antes_dash.x + 50.0 and jogador.tempo_dash() > 0.0, "Dash e recarga")
	var antes_moonwalk := jogador.position
	await _comando(&"Moonwalk")
	var esquivas: Array[int] = []
	jogador.esquiva_perfeita.connect(func() -> void: esquivas.append(1))
	jogador.receber_dano(true)
	jogador.receber_dano(true)
	_verificar(esquivas.size() == 1 and jogador.vida == 4, "Esquiva perfeita emite uma vez e protege")
	await _quadros(24)
	_verificar(jogador.position.x < antes_moonwalk.x - 50.0, "Moonwalk recua")

	var zumbi := preload("res://Scenes/zumbi.tscn").instantiate() as Zumbi
	zumbi.configurar_tipo(Zumbi.Tipo.LENTO)
	zumbi.ia_ativa = false
	arena.add_child(zumbi)
	var derrotas: Array[int] = []
	zumbi.derrotado.connect(func() -> void: derrotas.append(1))
	for golpe in 3:
		zumbi.global_position = jogador.colisor.global_position + jogador.direcao_da_mira() * 32.0
		await _quadros(3)
		await _comando(&"Chute")
		_verificar(zumbi.vida == [3, 2, 0][golpe], "Combo real: vida após chute %d" % (golpe + 1))
		await _quadros(24)
	if zumbi.vida > 0:
		zumbi.receber_dano(zumbi.vida)
	_verificar(derrotas.size() == 1, "Sinal de derrota único, emitido no golpe final")
	if is_instance_valid(zumbi):
		var ultimo_local := zumbi.global_position
		zumbi.receber_dano(1)
		await _quadros(4)
		_verificar(zumbi.global_position == ultimo_local and zumbi.collision_layer == 0 and not zumbi.contato.monitoring, "Corpo derrotado imóvel, sem colisão nem ataque")
	await _quadros(150)
	_verificar(not is_instance_valid(zumbi), "Corpo removido após animação")

	var alvos: Array[Zumbi] = []
	for tipo in [Zumbi.Tipo.COMUM, Zumbi.Tipo.LENTO, Zumbi.Tipo.RAPIDO]:
		var alvo := preload("res://Scenes/zumbi.tscn").instantiate() as Zumbi
		alvo.configurar_tipo(tipo)
		alvo.ia_ativa = false
		alvo.position = jogador.colisor.global_position + jogador.direcao_da_mira() * (45.0 + alvos.size() * 32.0)
		arena.add_child(alvo)
		alvos.append(alvo)
	await _quadros(4)
	await _comando(&"Chapeu")
	var chapeu: Chapeu = jogador._chapeu
	_verificar(is_instance_valid(chapeu), "Arremesso cria projétil")
	if is_instance_valid(chapeu):
		_verificar(chapeu.visual.position.y < -30.0 and chapeu.alcance.shape.radius == 10.0, "Altura visual de saída e raio preservado")
		_verificar(chapeu.visual.scale == Vector2(2, 2), "Escala do chapéu em voo")
		_verificar(await _esperar(func() -> bool: return chapeu.retornando, 60), "Chapéu inicia o retorno")
		_verificar(jogador._quadros_atuais() == jogador.figurino_sem_chapeu and not jogador.sprite.animation.begins_with("Arremesso"), "Michael usa estado sem chapéu durante o voo")
		_verificar(not is_instance_valid(alvos[2]) or alvos[2].vida <= 0, "Chapéu derrota alvo rápido na ida")
		_verificar(await _esperar(func() -> bool: return not is_instance_valid(jogador._chapeu), 85), "Chapéu volta para Michael")
	_verificar(alvos[0].vida == 1 and alvos[1].vida == 3, "Dano reduzido acumula entre ida e volta")
	await _quadros(55)
	_verificar(jogador._quadros_atuais() == jogador._figurino, "Michael retoma o figurino com chapéu após a volta")
	await _testar_fotografos(arena, jogador)
	arena.queue_free()
	await _quadros(4)


func _testar_fotografos(arena: Node2D, jogador: MichaelJogador) -> void:
	jogador.invencivel_dev = true
	var fotografos: Array[Detetive] = []
	for lado in [-1, 1]:
		var fotografo := preload("res://Scenes/detetive.tscn").instantiate() as Detetive
		fotografo.configurar(Detetive.Tipo.ESPECIAL, false)
		# Mantém os dois dentro da área de contato no mesmo quadro.
		fotografo.velocidade_patrulha = 0.0
		fotografo.position = jogador.colisor.global_position + Vector2(lado * 17, 0)
		arena.add_child(fotografo)
		fotografos.append(fotografo)
	var primeiro := fotografos[0]
	var segundo := fotografos[1]
	var iniciou := await _esperar(func() -> bool: return primeiro._preparacao_restante > 0.0, 30)
	_verificar(iniciou and primeiro.has_node("AvisoFotografico"), "Fotógrafo avisa no início da preparação")
	_verificar(segundo._preparacao_restante < 0.0, "Fotógrafos não iniciam juntos")
	primeiro.receber_dano(1, Vector2.RIGHT * 85.0, &"chapeu")
	_verificar(primeiro._preparacao_restante > 0.0 and primeiro._empurrao == Vector2.ZERO, "Armadura mantém o ataque diante do chapéu")
	var inicio := Engine.get_physics_frames()
	var segundo_iniciou := await _esperar(func() -> bool: return segundo._preparacao_restante > 0.0, 35)
	_verificar(segundo_iniciou and Engine.get_physics_frames() - inicio >= 23, "Preparações separadas por 0,40 s")
	primeiro.receber_dano(2, Vector2.RIGHT * 225.0, &"chute")
	_verificar(primeiro._preparacao_restante < 0.0 and is_equal_approx(primeiro._atordoamento, 0.55), "Armadura mantém atordoamento do golpe final mesmo com empurrão reduzido")


func _alcance_dos_pisos(fase: BillieJean, origem: Vector2i) -> Dictionary:
	var alcancados := {origem: true}
	var fila: Array[Vector2i] = [origem]
	var indice := 0
	while indice < fila.size():
		var celula := fila[indice]
		indice += 1
		var ponto := fase.pisos.map_to_local(celula)
		var transformacao := Transform2D(0.0, ponto - fase.pes.position)
		for direcao in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var vizinha := celula + (direcao as Vector2i)
			if alcancados.has(vizinha) or fase.chao.get_cell_source_id(vizinha) == -1:
				continue
			var deslocamento := fase.pisos.map_to_local(vizinha) - ponto
			if not fase.jogador.test_move(transformacao, deslocamento):
				alcancados[vizinha] = true
				fila.append(vizinha)
	return alcancados


func _ponto_no_piso(fase: BillieJean, celula: Vector2i, alcancados: Dictionary) -> Vector2:
	var centro := fase.pisos.map_to_local(celula)
	if alcancados.has(celula):
		return centro
	# Um pedestal pode cobrir o centro sem impedir a entrada na borda do piso.
	for y in range(-1, 2):
		for x in range(-1, 2):
			var vizinha := celula + Vector2i(x, y)
			if not alcancados.has(vizinha):
				continue
			var origem := fase.pisos.map_to_local(vizinha)
			var inicio := Transform2D(0.0, origem - fase.pes.position)
			for offset_y in [-10, 0, 10]:
				for offset_x in [-10, 0, 10]:
					var alvo := centro + Vector2(offset_x, offset_y)
					if not fase.jogador.test_move(inicio, alvo - origem):
						return alvo
	return Vector2.INF


func _testar_indicador(indicador: Indicador, jogador: MichaelJogador) -> void:
	var notas := get_nodes_in_group("notas_musicais")
	var tela := root.get_visible_rect()
	var tela_para_mundo := root.get_canvas_transform().affine_inverse()
	var centro := tela.get_center()
	var posicoes: Array[Vector2] = []
	for nota: Area2D in notas:
		posicoes.append(nota.global_position)
		nota.global_position = tela_para_mundo * centro
	_verificar(indicador._avisos_visiveis().is_empty(), "Notas dentro da tela não geram setas")
	var fora := Vector2(tela.end.x + 12.0, centro.y)
	var fora_do_mapa: Vector2 = tela_para_mundo * fora
	_verificar(jogador.global_position.distance_to(fora_do_mapa) < Indicador.RAIO_AVISO, "Cenário de teste posiciona nota fora da tela dentro do raio")
	notas[0].global_position = fora_do_mapa
	var avisos := indicador._avisos_visiveis()
	_verificar(avisos.size() == 1 and (avisos[0].ponto as Vector2).is_equal_approx(fora), "Indicador aponta para a nota viva fora da tela")
	notas[0].remove_from_group("notas_musicais")
	_verificar(indicador._avisos_visiveis().is_empty(), "Indicador ignora nota removida do grupo de coleta")
	notas[0].add_to_group("notas_musicais")
	for indice in notas.size():
		notas[indice].global_position = posicoes[indice]


func _testar_billie_jean() -> void:
	print("Billie Jean")
	await _entrar("billie_jean")
	var fase := current_scene as BillieJean
	var jogador := fase.jogador
	jogador.invencivel_dev = true
	var indicador: Indicador
	for no in fase.get_children():
		if no is Indicador:
			indicador = no
	_verificar(indicador != null and indicador.get_index() < fase.get_node("Interface").get_index(), "Indicador sob a interface por ordem de desenho")
	_verificar(not fase.indicador_notas_suprimido(), "Indicador habilitado fora do encontro")
	_testar_indicador(indicador, jogador)
	_verificar(fase.pisos.get_cell_source_id(Vector2i(13, 35)) == -1 and fase.pisos.get_cell_source_id(Vector2i(14, 35)) == -1, "Somente os dois pisos sob o relógio saíram do mapa")
	var origem := fase.pisos.local_to_map(fase.pes.global_position)
	for indice in BillieJean.REGIOES.size():
		var regiao: Dictionary = BillieJean.REGIOES[indice]
		var alcancados := _alcance_dos_pisos(fase, origem)
		var livres := 0
		for celula: Vector2i in fase.pisos.get_used_cells():
			if not regiao.pisos.has_point(celula):
				continue
			var ponto := _ponto_no_piso(fase, celula, alcancados)
			_verificar(ponto != Vector2.INF, "Piso alcançável por colisão a partir da região anterior %s" % str(celula))
			if ponto == Vector2.INF:
				continue
			if alcancados.has(celula):
				origem = celula
			livres += 1
			_posicionar_pes(jogador, ponto)
			await _quadros(3)
			_verificar(fase.pisos.get_cell_atlas_coords(celula).x > 0, "Piso aceso por contato %s" % str(celula))
		_verificar(livres == [12, 20, 25][indice], "Pisos alcançáveis, região %d (%d)" % [indice + 1, livres])
		_verificar(fase._detetives_restantes == 2 and indicador._avisos_visiveis().is_empty(), "Encontro bloqueia passagem e suprime indicador")
		for inimigo: Inimigo in get_nodes_in_group("inimigos"):
			if inimigo.has_meta("obrigatorio"):
				inimigo.receber_dano(inimigo.vida)
		await _quadros(4)
		_verificar(fase._regiao == indice + 1, "Cota e derrotas liberam região %d" % (indice + 1))

	# Os pisos e os inimigos mantêm a progressão mesmo ao recolher as notas depois.
	await _coletar_notas(jogador, BillieJean.NOTAS.size())
	_verificar(fase._notas_coletadas == 9, "Billie Jean registrou nove notas")
	_testar_menu_dev(jogador)
	_posicionar_pes(jogador, fase.espelho.global_position + Vector2(0, 32))
	await _quadros(3)
	await _comando(&"Interagir")
	_verificar(await _esperar(func() -> bool: return current_scene is Thriller, 20), "Espelho leva de Billie Jean a Thriller")


func _testar_menu_dev(jogador: MichaelJogador) -> void:
	var menu := root.get_node("MenuDev")
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_F1
	tecla.pressed = true
	root.push_input(tecla, true)
	_verificar(paused and menu._painel.visible, "F1 abre menu e pausa")
	if paused:
		menu._velocidade.value = 110
		_verificar(jogador.velocidade_movimento == 110.0, "Controle de velocidade do F1")
		var inimigos := get_nodes_in_group("inimigos")
		menu._eliminar_inimigos()
		_verificar(not inimigos.is_empty() and get_nodes_in_group("inimigos").is_empty(), "F1 derrota inimigos pela rotina real")
	root.push_input(tecla, true)
	_verificar(not paused, "F1 fecha menu e retoma")


func _testar_thriller() -> void:
	print("Thriller")
	if not current_scene is Thriller:
		await _entrar("thriller")
	await _quadros(4)
	var fase := current_scene as Thriller
	var jogador := fase.jogador
	var batalhas = fase.batalhas
	jogador.invencivel_dev = true
	_verificar(not batalhas.espelho_liberado(), "Espelho começa bloqueado")
	for etapa in 3:
		_posicionar_pes(jogador, Vector2(784, (batalhas.LINHAS[etapa] + 3) * 32 + 16))
		await _quadros(4)
		_verificar(batalhas.ativa and fase.indicador_notas_suprimido(), "Ondas ativas e indicador oculto")
		for onda in batalhas.ONDAS[etapa].size():
			var vivos_esperados: int = batalhas.ONDAS[etapa][onda].size()
			var apareceu := await _esperar(func() -> bool: return batalhas.onda == onda and batalhas._vivos.size() == vivos_esperados, 240)
			_verificar(apareceu, "Thriller cria onda %d/%d" % [etapa + 1, onda + 1])
			if not apareceu:
				break
			if etapa == 2 and onda == 1:
				var chefe := batalhas._vivos.values()[0] as Guardiao
				await _testar_guardiao(chefe, fase)
			else:
				for inimigo: Inimigo in batalhas._vivos.values():
					inimigo.receber_dano(inimigo.vida)
		_verificar(await _esperar(func() -> bool: return batalhas.etapa > etapa, 60), "Barreira %d dissipa com a onda inteira derrotada" % (etapa + 1))
	_verificar(batalhas.espelho_liberado(), "Espelho liberado após chefe e reforços")
	await _coletar_notas(jogador, Thriller.NOTAS.size())
	_verificar(fase.pontuacao == Thriller.NOTAS.size() * 100, "Thriller pontua todas as notas")
	var cura: Area2D = fase.curas.get_child(0)
	jogador.vida = 3
	_posicionar_pes(jogador, cura.global_position)
	await _quadros(5)
	_verificar(jogador.vida == 4 and not is_instance_valid(cura), "Cura de Thriller por colisão")
	_posicionar_pes(jogador, fase.dev_posicao_final())
	await _quadros(3)
	await _comando(&"Interagir")
	_verificar(fase.concluida and fase.conclusao.visible, "Interação com espelho conclui Thriller")
	fase.conclusao.get_node("Conteudo/Voltar").pressed.emit()
	await _quadros(4)
	_verificar(current_scene is Smooth, "Botão de Thriller abre Smooth Criminal")


func _testar_guardiao(chefe: Guardiao, fase: Thriller) -> void:
	var jogador := fase.jogador
	_verificar(chefe.vida == 16 and chefe.fase == 1, "Guardião começa na fase 1 com 16 PV")
	await _quadros(48)
	for prefixo in ["idle_", "walk_", "threat_"]:
		for direcao in ["up", "down", "left", "right"]:
			_verificar(chefe._sprite.sprite_frames.has_animation(prefixo + direcao), "Animação do Guardião " + prefixo + direcao)
	_verificar(chefe._barra.visible, "Barra de vida do Guardião ativa")
	var hud: Control = fase.hud
	var aviso_batalha: Control = fase.get_node("Interface/Batalha")
	_verificar(hud.get_rect().end.y < 250.0 and aviso_batalha.get_rect().end.y < 250.0, "HUD e aviso de batalha ficam acima da barra do Guardião")
	var destino := fase.piso.map_to_local(Vector2i(24, 19))
	chefe.reancorar(destino)
	chefe.atraso_aparicao = 0.0
	_posicionar_pes(jogador, destino + Vector2(0, 68))
	chefe._tempo_especial = 0.0
	var iniciou := await _esperar(func() -> bool: return chefe._acao == Guardiao.Acao.AVISO_CARGA, 90)
	_verificar(iniciou and chefe._indicador is Line2D, "Fase 1 anuncia avanço com faixa")
	if iniciou:
		await _esperar(func() -> bool: return chefe._tempo_acao <= 0.25, 60)
		var direcao := chefe._direcao_carga
		_posicionar_pes(jogador, destino + Vector2(40, 68))
		await _quadros(4)
		_verificar(chefe._direcao_carga.is_equal_approx(direcao), "Direção da carga trava no aviso")
		_verificar(await _esperar(func() -> bool: return chefe._acao == Guardiao.Acao.EXAUSTO, 100), "Avanço termina em exaustão")
	if chefe._acao == Guardiao.Acao.EXAUSTO:
		chefe.receber_dano(1, Vector2.ZERO, &"chapeu")
		chefe.receber_dano(1, Vector2.ZERO, &"chute")
		_verificar(chefe.vida == 13, "Exaustão: chapéu inteiro e chute recebe +1")
	chefe.receber_dano(chefe.vida - 9, Vector2.ZERO, &"chapeu")
	_verificar(chefe.fase == 2 and chefe.vida == 9, "Limiar de 60% ativa fase 2")
	var batalhas = fase.batalhas
	_verificar(await _esperar(func() -> bool: return batalhas._vivos.size() == 3, 160), "Fase 2 gera dois reforços")
	_derrotar_reforcos(fase, chefe)
	_verificar(await _esperar(func() -> bool: return chefe._acao == Guardiao.Acao.NORMAL, 90), "Rugido termina")
	chefe.reancorar(destino)
	chefe.atraso_aparicao = 0.0
	_posicionar_pes(jogador, destino + Vector2(0, 46))
	chefe._tempo_especial = 0.0
	iniciou = await _esperar(func() -> bool: return chefe._acao == Guardiao.Acao.AVISO_ONDA, 100)
	_verificar(iniciou and is_instance_valid(chefe._indicador), "Fase 2 anuncia onda em anel")
	if iniciou:
		await _esperar(func() -> bool: return chefe._tempo_acao <= 0.08, 90)
		jogador.invencivel_dev = false
		jogador.frente = Vector2.LEFT
		await _comando(&"Moonwalk")
		_verificar(await _esperar(func() -> bool: return chefe._acao == Guardiao.Acao.EXAUSTO, 30), "Onda termina em exaustão")
		_verificar(jogador.vida == 4 and chefe._tempo_acao > 2.0, "Esquiva perfeita da onda preserva vida e estende exaustão")
		jogador.invencivel_dev = true
	chefe.receber_dano(chefe.vida - 4, Vector2.ZERO, &"chapeu")
	_verificar(chefe.fase == 3 and chefe.vida <= 4, "Limiar de 30% ativa fase 3")
	_verificar(await _esperar(func() -> bool: return batalhas._vivos.size() == 2, 160), "Fase 3 gera um reforço")
	await _testar_carga_contra_parede(chefe, fase, destino)
	chefe.receber_dano(chefe.vida)
	await _quadros(4)
	_verificar(not chefe._barra.visible and not batalhas.espelho_liberado(), "Barra some e reforço vivo ainda bloqueia espelho")
	_derrotar_reforcos(fase, chefe)


func _testar_carga_contra_parede(chefe: Guardiao, fase: Thriller, destino: Vector2) -> void:
	await _esperar(func() -> bool: return chefe._acao == Guardiao.Acao.NORMAL, 90)
	chefe.reancorar(destino)
	chefe.atraso_aparicao = 0.0
	_posicionar_pes(fase.jogador, destino + Vector2(90, 0))
	var parede := StaticBody2D.new()
	parede.position = destino + Vector2(46, 0)
	var colisor := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(12, 46)
	colisor.shape = forma
	parede.add_child(colisor)
	fase.add_child(parede)
	await _quadros(3)
	chefe._usar_onda = false
	chefe._tempo_especial = 0.0
	var iniciou := await _esperar(func() -> bool: return chefe._acao == Guardiao.Acao.AVISO_CARGA, 90)
	_verificar(iniciou and chefe._tempo_acao <= 0.60, "Fase 3 acelera aviso de carga")
	var exausto := await _esperar(func() -> bool: return chefe._acao == Guardiao.Acao.EXAUSTO, 100)
	_verificar(exausto and chefe._tempo_acao > 1.9 and chefe.global_position.x < parede.position.x, "Parede para a carga e amplia a exaustão da fase 3")
	parede.queue_free()


func _derrotar_reforcos(fase: Thriller, chefe: Guardiao) -> void:
	for inimigo: Inimigo in fase.batalhas._vivos.values():
		if inimigo != chefe:
			inimigo.receber_dano(inimigo.vida)


func _testar_smooth_criminal() -> void:
	print("Smooth Criminal")
	if not current_scene is Smooth:
		await _entrar("smooth_criminal")
	var fase := current_scene as Smooth
	var jogador := fase.jogador
	jogador.invencivel_dev = true
	await _coletar_notas(jogador, Smooth.NOTAS.size())
	_verificar(fase.pontuacao == 900, "Smooth Criminal pontua 9 notas")
	_posicionar_pes(jogador, fase.jukebox.global_position + Vector2(0, 30))
	await _comando(&"Interagir")
	_verificar(fase.objetivo == Smooth.Objetivo.ACESSO_VIP, "Smooth Criminal liga energia")
	_posicionar_pes(jogador, Smooth.POSICAO_VIP)
	await _comando(&"Interagir")
	_verificar(fase.objetivo == Smooth.Objetivo.SEGURANCA and fase.portao_vip.get_node("Base").disabled, "Interação abre colisão VIP")
	var seguranca: Inimigo = fase.atores.get_node("SegurancaVIP")
	seguranca.receber_dano(seguranca.vida, Vector2.ZERO, &"chute")
	await _quadros(4)
	_verificar(fase.objetivo == Smooth.Objetivo.PALCO and fase.portao_palco.get_node("Base").disabled, "Segurança abre colisão do palco")
	_posicionar_pes(jogador, Vector2(768, 300))
	await _quadros(4)
	var chefe: ChefeSmooth
	for inimigo: Inimigo in get_nodes_in_group("inimigos"):
		if inimigo is ChefeSmooth:
			chefe = inimigo
	_verificar(chefe != null and fase.painel_chefe.visible, "Palco inicia o chefe de Smooth Criminal")
	if chefe == null:
		return
	chefe.receber_dano(1, Vector2.ZERO, &"chapeu")
	chefe.receber_dano(1, Vector2.ZERO, &"chapeu")
	_verificar(chefe.vida == 13, "Chefe de Smooth Criminal aceita dano fracionado do chapéu")
	chefe.receber_dano(4, Vector2.ZERO, &"chute")
	_verificar(chefe.etapa == 2 and fase.atores.has_node("ReforcoOeste"), "Fase 2 e reforços de Smooth Criminal")
	chefe.receber_dano(5, Vector2.ZERO, &"chute")
	_verificar(chefe.etapa == 3 and fase.vida_chefe.value == 4, "Fase 3 e HUD de Smooth Criminal")
	chefe.receber_dano(4, Vector2.ZERO, &"chute")
	_verificar(fase.objetivo == Smooth.Objetivo.ESPELHO and not fase.painel_chefe.visible, "Derrota libera espelho em Smooth Criminal")
	_posicionar_pes(jogador, Smooth.FRENTE_ESPELHO)
	await _comando(&"Interagir")
	_verificar(fase.concluida and fase.conclusao.visible, "Espelho conclui Smooth Criminal")
	fase.conclusao.get_node("Conteudo/Voltar").pressed.emit()
	await _quadros(4)
	_verificar(current_scene is UltimoEco, "Smooth Criminal abre O Último Eco")


func _testar_ultimo_eco() -> void:
	print("O Último Eco")
	if not current_scene is UltimoEco:
		await _entrar("ultimo_eco")
	var fase := current_scene as UltimoEco
	var jogador := fase.jogador
	var chefe := fase.chefe
	_verificar(fase._pronta and chefe.estado == TheSilence.Estado.ESPERA, "Arena pronta, confronto começa com interação")
	_verificar(not fase.dev_espelho_liberado(), "Portal final bloqueado no início")
	_testar_colisoes_finais(fase)
	await _coletar_notas(jogador, 3)
	_verificar(fase._notas_coletadas == 3, "Três notas adicionam 300 pontos")
	_posicionar_pes(jogador, chefe.global_position + Vector2(0, 55))
	await _comando(&"Interagir")
	_verificar(fase.painel_chefe.visible and chefe.estado != TheSilence.Estado.ESPERA, "Interação inicia o confronto e mostra a barra")
	chefe.receber_dano(15, Vector2.ZERO, &"chute")
	_verificar(chefe.vida == 15, "Chefe invulnerável fora da abertura mesmo com golpe letal")
	var avisou := await _esperar(func() -> bool: return chefe.estado == TheSilence.Estado.AVISO, 140)
	_verificar(avisou and chefe._ataque == TheSilence.Ataque.ONDA and chefe._aviso is Line2D, "Apagamento anuncia onda")
	if avisou:
		await _esperar(func() -> bool: return chefe._tempo <= 0.07, 85)
		jogador.frente = Vector2.RIGHT
		await _comando(&"Moonwalk")
	_verificar(await _esperar(func() -> bool: return chefe.estado == TheSilence.Estado.VULNERAVEL, 80), "Após onda, chefe fica vulnerável")
	_verificar(jogador.vida == 4 and chefe._tempo > 2.8, "Moonwalk evita onda e prolonga janela")
	chefe.receber_dano(1, Vector2.ZERO, &"chapeu")
	_verificar(chefe.vida == 14 and fase.barra.value == 14.0, "Chapéu atinge na janela e atualiza barra")
	chefe.receber_dano(4, Vector2.ZERO, &"chute")
	_verificar(chefe.fase == 2 and chefe.estado == TheSilence.Estado.TRANSICAO, "Dez PV iniciam Fratura")
	_verificar(fase._pisos[1].visible and fase._objetos[1].visible and not fase._pisos[0].visible, "Fratura troca piso e objetos")

	avisou = await _esperar(func() -> bool: return chefe.estado == TheSilence.Estado.AVISO, 190)
	_verificar(avisou and chefe._ataque == TheSilence.Ataque.FENDA, "Fratura marca fenda nas coordenadas do jogador")
	var fenda := chefe._centro
	Input.action_press(&"Direita")
	await _comando(&"Dash")
	Input.action_release(&"Direita")
	await _quadros(14)
	_verificar(chefe._centro == fenda, "Fenda permanece na posição anunciada")
	_verificar(await _esperar(func() -> bool: return chefe.estado == TheSilence.Estado.VULNERAVEL, 90), "Fenda abre janela de ataque")
	_verificar(jogador.vida == 4 and jogador.colisor.global_position.distance_to(fenda) > TheSilence.RAIO_FENDA, "Dash sai da área anunciada e evita a fenda")
	chefe.receber_dano(5, Vector2.ZERO, &"chute")
	_verificar(chefe.fase == 3 and fase._pisos[2].visible and not fase._objetos[1].visible, "Cinco PV ativam arena de Último eco")

	_posicionar_pes(jogador, chefe.global_position + Vector2(0, 55))
	avisou = await _esperar(func() -> bool: return chefe.estado == TheSilence.Estado.AVISO, 190)
	_verificar(avisou and chefe._ataque == TheSilence.Ataque.INVESTIDA and chefe._aviso is Polygon2D, "Último eco sinaliza investida")
	_verificar(await _esperar(func() -> bool: return chefe.estado == TheSilence.Estado.INVESTIDA, 90), "Investida começa após aviso")
	_verificar(await _esperar(func() -> bool: return chefe.estado == TheSilence.Estado.VULNERAVEL, 100), "Investida termina e expõe chefe")
	_verificar(jogador.vida == 3, "Investida acerta uma vez em linha reta")
	chefe.receber_dano(5, Vector2.ZERO, &"chute")
	_verificar(fase.restaurada and fase._pisos[3].visible and fase._objetos[3].visible and not fase.painel_chefe.visible, "Derrota restaura arena, objetos e portal")
	await _quadros(150)
	_verificar(not is_instance_valid(chefe), "The Silence desaparece após dissolução")
	_posicionar_pes(jogador, fase.dev_posicao_final())
	await _quadros(4)
	await _comando(&"Interagir")
	_verificar(fase.concluida and fase.final.visible, "Portal restaurado abre desfecho")
	fase.final.get_node("Conteudo/Voltar").pressed.emit()
	await _quadros(4)
	_verificar(current_scene.scene_file_path == "res://Scenes/interface.tscn", "Desfecho retorna ao menu")


func _testar_colisoes_finais(fase: UltimoEco) -> void:
	var jogador := fase.jogador
	var piso: TileMapLayer = fase._pisos[0].get_node("Piso0")
	var celula := Vector2i(8, 2)
	var centro := piso.to_global(piso.map_to_local(celula))
	var inicio := Transform2D(0.0, centro - jogador.colisor.position)
	_verificar(jogador.test_move(inicio, Vector2.UP * 32.0), "Colisão física impede entrada no vazio")
	var altar: Node2D = fase._objetos[0].get_node("altar18")
	inicio.origin = altar.global_position + Vector2(0, 30) - jogador.colisor.position
	_verificar(jogador.test_move(inicio, Vector2.UP * 40.0), "Apoio do altar bloqueia passagem")
	var origem := Vector2i((jogador.colisor.global_position / 32.0).floor())
	var portal := Vector2i((fase.dev_posicao_final() / 32.0).floor())
	_verificar(not fase.caminhos.get_id_path(origem, portal).is_empty(), "Rota navegável do ponto de entrada ao portal")
	_verificar(fase._pisos[0].get_node("Piso0").get_used_cells().size() == 892, "Todos os tiles-base da arena são carregados")


func _testar_reinicio_ultimo_eco() -> void:
	await _entrar("ultimo_eco")
	var fase := current_scene as UltimoEco
	var id_fase := fase.get_instance_id()
	await _comando(&"Interagir")
	fase.jogador.vida = 1
	fase.jogador.receber_dano()
	_verificar(await _esperar(func() -> bool: return current_scene is UltimoEco and current_scene.get_instance_id() != id_fase, 150), "Derrota do jogador reinicia a fase final")
	_verificar(current_scene is UltimoEco and current_scene.jogador.vida == 4 and current_scene.chefe.estado == TheSilence.Estado.ESPERA, "Reinício restaura o jogador e o chefe volta à espera")
