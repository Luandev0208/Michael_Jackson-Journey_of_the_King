extends "res://Scripts/zumbi.gd"

# Guardião do Espelho: chefe em três fases, com ataques anunciados.
#  Fase 1: avanço em linha reta com aviso no chão.
#  Fase 2 (70% da vida): enfurece, chama reforços e usa onda de choque em anel.
#  Fase 3 (38% da vida): ataques mais rápidos e janelas de vulnerabilidade longas.
# Depois de cada ataque especial ele fica exausto: nesse momento recebe mais dano
# do chute e o chapéu rende o dano completo. Esquivar na hora certa estica a janela.
# O primeiro ataque de cada fase abre a guarda.

signal vida_alterada(restante: int, maximo: int)
signal reforcos_pedidos(quantidade: int)
signal fase_alterada(fase: int)

enum Acao { NORMAL, RUGIDO, AVISO_CARGA, CARGA, AVISO_ONDA, EXAUSTO, AVISO_VARREDURA }

const VIDA_MAXIMA := 23
const LIMITE_FASE_2 := 0.70
const LIMITE_FASE_3 := 0.38
const RAIO_ONDA := 76.0
const VELOCIDADE_CARGA := 225.0
const DURACAO_CARGA := 0.55
const RAIO_CARGA := 25.0
const INTERVALOS_ESPECIAL := [3.15, 2.70, 2.10]
const ALCANCE_VARREDURA := 59.0
const ARCO_VARREDURA := deg_to_rad(57.0)

var fase := 1
var _acao := Acao.NORMAL
var _tempo_acao := 0.0
var _tempo_especial := 0.45
var _direcao_carga := Vector2.DOWN
var _acertou := false
var _esquivado := false
var _aplicando_ataque_especial := false
var _usar_onda := false
var _ondas_pendentes := 0
var _especial_concluido := false
var _ciclo_especial := 0
var _indicador: Node2D
var _barra: Control
var _jogador: MichaelJogador


func _ready() -> void:
	configurar_tipo(Tipo.GUARDIAO)
	vida = VIDA_MAXIMA
	velocidade_perseguicao = 52.0
	preparacao_contato = 0.36
	recarga_contato = 1.25
	super._ready()
	_criar_barra()
	if is_instance_valid(alvo):
		_jogador = alvo.get_parent() as MichaelJogador
		if _jogador != null:
			_jogador.esquiva_perfeita.connect(_ao_esquivar)
	vida_alterada.emit(vida, VIDA_MAXIMA)


func _process(_delta: float) -> void:
	if is_instance_valid(_barra):
		_barra.queue_redraw()


func _physics_process(delta: float) -> void:
	if vida <= 0 or not ia_ativa:
		return
	if atraso_aparicao > 0.0 or not is_instance_valid(_jogador):
		super._physics_process(delta)
		return
	_tempo_acao = maxf(0.0, _tempo_acao - delta)
	match _acao:
		Acao.NORMAL:
			_tempo_especial -= delta
			if _tempo_especial <= 0.0 and _preparacao_restante < 0.0:
				_iniciar_especial()
			if _acao == Acao.NORMAL:
				super._physics_process(delta)
		Acao.RUGIDO:
			_parado(delta)
			if _tempo_acao <= 0.0:
				_terminar_acao()
		Acao.AVISO_CARGA:
			_parado(delta)
			_atualizar_aviso_carga()
			if _tempo_acao <= 0.0:
				_acao = Acao.CARGA
				_tempo_acao = DURACAO_CARGA
				AudioManager.tocar(&"chefe_investida", global_position)
				_animar("corrida", DURACAO_CARGA, true)
				_acertou = false
				_limpar_indicador()
		Acao.CARGA:
			_carregar()
		Acao.AVISO_ONDA:
			_parado(delta)
			_atualizar_aviso_onda()
			if _tempo_acao <= 0.0:
				_disparar_onda()
		Acao.AVISO_VARREDURA:
			_parado(delta)
			if is_instance_valid(_indicador):
				_indicador.modulate.a = lerpf(0.45, 1.0, 1.0 - clampf(_tempo_acao / 0.76, 0.0, 1.0))
			if _tempo_acao <= 0.0:
				_varrer()
		Acao.EXAUSTO:
			_parado(delta)
			visual.modulate = Color(0.62, 0.78, 1.0) if _tempo_impacto <= 0.0 else visual.modulate
			if _tempo_acao <= 0.0:
				_terminar_acao()


func _parado(delta: float) -> void:
	ia_ativa = false
	super._physics_process(delta)
	ia_ativa = true


func _iniciar_especial() -> void:
	var distancia := global_position.distance_to(alvo.global_position)
	var onda := fase >= 2 and distancia < RAIO_ONDA + 18.0 and (_usar_onda or distancia < 52.0)
	var varredura := distancia < ALCANCE_VARREDURA + 5.0 and _ciclo_especial % 3 == 1 and _especial_concluido and _linha_livre_ate_alvo()
	if fase >= 2 and not _especial_concluido and not onda:
		_tempo_especial = 0.25
		return
	if not onda and distancia > VELOCIDADE_CARGA * DURACAO_CARGA + RAIO_CARGA:
		_tempo_especial = 0.6
		return
	if not _reservar_inicio_ataque():
		return
	_ciclo_especial += 1
	AudioManager.tocar(&"chefe_aviso", global_position)
	_usar_onda = not _usar_onda
	if varredura:
		_preparar_varredura()
	elif onda:
		_acao = Acao.AVISO_ONDA
		_tempo_acao = 0.95 if fase == 2 else 0.80
		_ondas_pendentes = 2 if fase == 3 else 1
		_criar_indicador_onda()
		_animar("prepare", _tempo_acao, true)
	else:
		_acao = Acao.AVISO_CARGA
		_tempo_acao = 0.85 if fase == 1 else (0.70 if fase == 2 else 0.60)
		_criar_indicador_carga()
		_atualizar_aviso_carga()
		_animar("threat", _tempo_acao, true)
	_preparacao_restante = -1.0
	_esquivado = false


func _preparar_varredura() -> void:
	_acao = Acao.AVISO_VARREDURA
	_tempo_acao = 0.76
	_direcao_carga = global_position.direction_to(alvo.global_position)
	if _direcao_carga.is_zero_approx():
		_direcao_carga = Vector2.DOWN
	_olhar_para(_direcao_carga)
	_animar("prepare", _tempo_acao, true)
	_limpar_indicador()
	var leque := Polygon2D.new()
	var forma := PackedVector2Array([Vector2.ZERO])
	for i in 15:
		forma.append(_direcao_carga.rotated(lerpf(-ARCO_VARREDURA, ARCO_VARREDURA, i / 14.0)) * ALCANCE_VARREDURA)
	leque.polygon = forma
	leque.color = Color(1.0, 0.47, 0.25, 0.36)
	leque.z_index = 1
	add_child(leque)
	_indicador = leque


func _varrer() -> void:
	var desvio := alvo.global_position - global_position
	if desvio.length() <= ALCANCE_VARREDURA and (desvio.length() < 7.0 or desvio.normalized().dot(_direcao_carga) >= cos(ARCO_VARREDURA)):
		_tentar_acertar_jogador()
	AudioManager.tocar(&"chefe_golpe", global_position)
	_entrar_exausto(_duracao_exausto(1.48))
	_animar("pesado", 0.25, true)


func _terminar_acao() -> void:
	_acao = Acao.NORMAL
	multiplicador_chapeu = 0.67
	_tempo_especial = INTERVALOS_ESPECIAL[fase - 1] if _especial_concluido else 0.30
	visual.modulate = Color.WHITE


func _entrar_exausto(duracao: float) -> void:
	_acao = Acao.EXAUSTO
	_especial_concluido = true
	_tempo_acao = duracao
	_limpar_indicador()
	# Janela de vulnerabilidade: o chapéu rende o dano completo.
	multiplicador_chapeu = 1.0
	_animar("idle", 0.0, true)
	_mostrar_estrelas(duracao)


func _duracao_exausto(base: float) -> float:
	var extra := 0.0 if fase < 3 else 0.32
	return base * 0.92 + extra + (1.25 if _esquivado else 0.0)


# ----- Avanço -----

func _criar_indicador_carga() -> void:
	_limpar_indicador()
	var faixa := Line2D.new()
	faixa.width = RAIO_CARGA * 2.0
	faixa.default_color = Color(1.0, 0.22, 0.22, 0.30)
	faixa.z_index = 1
	faixa.add_point(Vector2.ZERO)
	faixa.add_point(Vector2.DOWN * VELOCIDADE_CARGA * DURACAO_CARGA)
	add_child(faixa)
	_indicador = faixa
	_direcao_carga = global_position.direction_to(alvo.global_position)


func _atualizar_aviso_carga() -> void:
	# Acompanha Michael no começo e trava a direção nos últimos 0.30 s: tempo justo para reagir.
	if _tempo_acao > 0.30:
		_direcao_carga = global_position.direction_to(alvo.global_position)
	_olhar_para(_direcao_carga)
	if is_instance_valid(_indicador):
		var percurso := _direcao_carga * VELOCIDADE_CARGA * DURACAO_CARGA
		var colisao := KinematicCollision2D.new()
		if test_move(global_transform, percurso, colisao):
			percurso = colisao.get_travel()
		(_indicador as Line2D).set_point_position(1, percurso)
		var travado := _tempo_acao <= 0.30
		(_indicador as Line2D).default_color = Color(1.0, 0.15, 0.15, 0.70 if travado else 0.30)


func _carregar() -> void:
	_empurrao = Vector2.ZERO
	velocity = _direcao_carga * VELOCIDADE_CARGA
	_olhar_para(_direcao_carga)
	visual.modulate = Color(1.0, 0.71, 0.47)
	var bateu := move_and_slide() and get_slide_collision_count() > 0
	if not _acertou and global_position.distance_to(alvo.global_position) <= RAIO_CARGA:
		_acertou = _tentar_acertar_jogador()
	if bateu or _tempo_acao <= 0.0 or _esquivado:
		velocity = Vector2.ZERO
		visual.modulate = Color.WHITE
		# Errar o golpe e bater na parede deixa o chefe exposto por mais tempo.
		var base := 1.6 if (bateu or _esquivado) else 1.1
		_entrar_exausto(_duracao_exausto(base))
		if bateu:
			_chacoalhar()


# ----- Onda de choque -----

func _criar_indicador_onda() -> void:
	_limpar_indicador()
	var raiz := Node2D.new()
	raiz.z_index = 1
	var contorno := Line2D.new()
	contorno.width = 2.0
	contorno.default_color = Color(1.0, 0.25, 0.25, 0.55)
	var miolo := Line2D.new()
	miolo.width = 2.0
	miolo.default_color = Color(1.0, 0.8, 0.5, 0.85)
	for i in range(33):
		var ponto := Vector2.from_angle(TAU * float(i) / 32.0)
		contorno.add_point(ponto * RAIO_ONDA)
		miolo.add_point(ponto * RAIO_ONDA)
	raiz.add_child(contorno)
	raiz.add_child(miolo)
	miolo.scale = Vector2(0.1, 0.1)
	add_child(raiz)
	_indicador = raiz


func _atualizar_aviso_onda() -> void:
	if not is_instance_valid(_indicador):
		return
	var total := 0.95 if fase == 2 else 0.80
	var progresso := clampf(1.0 - _tempo_acao / total, 0.0, 1.0)
	_indicador.get_child(1).scale = Vector2.ONE * maxf(progresso, 0.1)


func _disparar_onda() -> void:
	AudioManager.tocar(&"chefe_onda", global_position)
	_limpar_indicador()
	var centro := global_position
	var anel := Line2D.new()
	anel.width = 3.0
	anel.default_color = Color(1.0, 0.7, 0.9, 0.95)
	anel.z_index = 4
	for i in range(33):
		anel.add_point(Vector2.from_angle(TAU * float(i) / 32.0) * RAIO_ONDA)
	get_parent().add_child(anel)
	anel.global_position = centro
	var expansao := anel.create_tween().set_parallel()
	expansao.tween_property(anel, "scale", Vector2(1.25, 1.25), 0.25)
	expansao.tween_property(anel, "modulate:a", 0.0, 0.25)
	expansao.chain().tween_callback(anel.queue_free)
	_chacoalhar()
	if alvo.global_position.distance_to(centro) <= RAIO_ONDA:
		_tentar_acertar_jogador()
	_ondas_pendentes -= 1
	if _ondas_pendentes > 0:
		_tempo_acao = 0.78
		AudioManager.tocar(&"chefe_aviso", global_position)
		_criar_indicador_onda()
		return
	_entrar_exausto(_duracao_exausto(1.4))
	_animar("pesado", 0.25, true)


func _tentar_acertar_jogador() -> bool:
	var raio := PhysicsRayQueryParameters2D.create(global_position, alvo.global_position, 1)
	if not get_world_2d().direct_space_state.intersect_ray(raio).is_empty():
		return false
	_aplicando_ataque_especial = true
	_jogador.receber_dano(true)
	_aplicando_ataque_especial = false
	return true


func _ao_esquivar() -> void:
	if _aplicando_ataque_especial:
		_esquivado = true


func _atualizar_animacao(movimento: Vector2) -> void:
	if _acao == Acao.NORMAL:
		super._atualizar_animacao(movimento)


func _chacoalhar() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var base := camera.offset
	var tremor := create_tween()
	for i in range(4):
		tremor.tween_property(camera, "offset", base + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)), 0.04)
	tremor.tween_property(camera, "offset", base, 0.04)


# ----- Dano, fases e derrota -----

func receber_dano(dano: int, empurrao := Vector2.ZERO, fonte := &"chute") -> void:
	if vida <= 0 or not _especial_concluido:
		return
	if _acao != Acao.EXAUSTO and fonte == &"chute":
		var de_frente := global_position.direction_to(alvo.global_position).dot(_direcao_carga) > 0.40
		if dano == 1 or (de_frente and _acao in [Acao.AVISO_CARGA, Acao.CARGA, Acao.AVISO_VARREDURA]):
			return
	match _acao:
		Acao.EXAUSTO:
			if fonte == &"chute" and dano > 1:
				dano += 1
		Acao.NORMAL:
			pass
		_:
			# Durante os ataques ele tem super armadura: o golpe fere, mas não o desvia.
			empurrao = Vector2.ZERO
	super.receber_dano(dano, empurrao, fonte)
	vida_alterada.emit(maxi(vida, 0), VIDA_MAXIMA)
	if vida <= 0:
		return
	var proporcao := float(vida) / float(VIDA_MAXIMA)
	if fase == 1 and proporcao <= LIMITE_FASE_2:
		_mudar_fase(2)
	elif fase == 2 and proporcao <= LIMITE_FASE_3:
		_mudar_fase(3)


func atordoar(tempo: float) -> void:
	# O atordoamento comum só vale quando ele está livre; os ataques têm super armadura.
	if _acao == Acao.NORMAL:
		super.atordoar(tempo * 0.6)


func _mudar_fase(nova: int) -> void:
	fase = nova
	_limpar_indicador()
	_acao = Acao.RUGIDO
	_especial_concluido = false
	_usar_onda = true
	multiplicador_chapeu = 0.67
	_tempo_acao = 1.0
	velocidade_perseguicao = 52.0 + 10.0 * float(nova - 1)
	recarga_contato = 1.25 - 0.15 * float(nova - 1)
	_animar("threat", 1.0, true)
	_chacoalhar()
	AudioManager.tocar(&"chefe_etapa", global_position)
	fase_alterada.emit(nova)
	if nova == 2:
		reforcos_pedidos.emit(2)
	elif nova == 3:
		reforcos_pedidos.emit(1)


func _derrotar() -> void:
	_limpar_indicador()
	if is_instance_valid(_barra):
		_barra.hide()
	super._derrotar()


func _limpar_indicador() -> void:
	if is_instance_valid(_indicador):
		_indicador.queue_free()
	_indicador = null


func _mostrar_estrelas(duracao: float) -> void:
	var estrela := Polygon2D.new()
	estrela.polygon = PackedVector2Array([Vector2(0, -5), Vector2(1.5, -1.5), Vector2(5, 0), Vector2(1.5, 1.5), Vector2(0, 5), Vector2(-1.5, 1.5), Vector2(-5, 0), Vector2(-1.5, -1.5)])
	estrela.color = Color(0.7, 0.9, 1.0)
	estrela.position = Vector2(0, -72)
	estrela.z_index = 4
	add_child(estrela)
	var giro := estrela.create_tween()
	giro.tween_property(estrela, "scale", Vector2(1.4, 1.4), duracao * 0.5)
	giro.tween_property(estrela, "scale", Vector2(1.0, 1.0), duracao * 0.5)
	giro.tween_callback(estrela.queue_free)


# ----- Barra de vida do chefe -----

func _criar_barra() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 1
	add_child(camada)
	_barra = Control.new()
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barra.draw.connect(_desenhar_barra)
	camada.add_child(_barra)
	vida_alterada.connect(func(_a: int, _b: int) -> void: _barra.queue_redraw())
	fase_alterada.connect(func(_f: int) -> void: _barra.queue_redraw())


func _desenhar_barra() -> void:
	if vida <= 0 or atraso_aparicao > 0.0:
		return
	var caixa := Rect2(170.0, 262.0, 300.0, 12.0)
	_barra.draw_rect(caixa.grow(2.0), Color(0.14, 0.07, 0.23, 0.92))
	var cheia := clampf(float(vida) / float(VIDA_MAXIMA), 0.0, 1.0)
	var cor := Color(0.78, 0.45, 1.0) if fase == 1 else (Color(1.0, 0.55, 0.30) if fase == 2 else Color(1.0, 0.28, 0.28))
	_barra.draw_rect(Rect2(caixa.position, Vector2(caixa.size.x * cheia, caixa.size.y)), cor)
	for marca in [LIMITE_FASE_2, LIMITE_FASE_3]:
		_barra.draw_rect(Rect2(caixa.position.x + caixa.size.x * marca - 1.0, caixa.position.y, 2.0, caixa.size.y), Color(0.14, 0.07, 0.23))
	var fonte := ThemeDB.fallback_font
	var titulo := "Guardião do Espelho — Thriller"
	var tom := Color(0.95, 0.88, 1.0)
	if _acao == Acao.EXAUSTO:
		titulo += "  ·  VULNERÁVEL"
		tom = Color(0.73, 0.94, 1.0)
	elif not _especial_concluido:
		titulo += "  ·  AGUARDE A ABERTURA"
	_barra.draw_string(fonte, Vector2(caixa.position.x, caixa.position.y - 5.0), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, tom)
