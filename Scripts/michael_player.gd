class_name MichaelJogador
extends CharacterBody2D

signal esquiva_perfeita
signal vida_alterada(restantes: int)

const VIDA_MAXIMA := 4
const CENA_CHAPEU := preload("res://Scenes/chapeu.tscn")
const Pausa := preload("res://Scripts/pausa.gd")
const CAMADA_CENARIO := 1
const CAMADA_INIMIGO := 4

# Velocidade com a qual os quadros de caminhada foram desenhados.
const VELOCIDADE_BASE_ANIMACAO := 80.0

@export var velocidade_movimento := 94.0
@export var protecao_apos_dano := 0.85

@export_group("Figurino")
@export var figurino_sem_chapeu: SpriteFrames
@export var textura_chapeu: Texture2D

@export_group("Chute")
@export var alcance_chute := 48.0
@export_range(1.0, 89.0) var semiabertura_chute := 52.0
@export var duracao_chute := 0.10
@export var recarga_chute := 0.38
@export var empurrao_chute := 150.0
@export var janela_combo := 0.9
@export var dano_golpe_final := 2
@export var multiplicador_alcance_final := 1.20
@export var multiplicador_empurrao_final := 1.5

@export_group("Moonwalk")
@export var velocidade_moonwalk := 300.0
@export var duracao_moonwalk := 0.25
@export var invulnerabilidade_moonwalk := 0.30
@export var recarga_moonwalk := 1.5
@export var janela_esquiva_perfeita := 0.15
@export var recarga_apos_esquiva_perfeita := 0.35
@export var raio_onda_moonwalk := 24.0
@export var empurrao_onda_moonwalk := 140.0

@export_group("Dash")
@export var velocidade_dash := 400.0
@export var duracao_dash := 0.18
@export var recarga_dash := 1.2

var vida := VIDA_MAXIMA
var posicao_inicial := Vector2.ZERO
var invencivel_dev := false
var frente := Vector2.DOWN
var _animacao: StringName = &"Baixo"
var _tempo_chute := 0.0
var _janela_chute := 0.0
var _direcao_chute := Vector2.DOWN
var _atingidos_chute: Dictionary[int, bool] = {}
var _passo_combo := 0
var _tempo_combo := 0.0
var _golpe_final := false
var _protecao_esquiva := 0.0
var _janela_perfeita := 0.0
var _brilho_esquiva := 0.0
var _forma_moonwalk := CircleShape2D.new()
var _empurrados_moonwalk: Dictionary[int, bool] = {}
var _ultima_sombra := Vector2.ZERO
var _tempo_moonwalk := 0.0
var _tempo_dash := 0.0
var _recarga_dash := 0.0
var _direcao_dash := Vector2.ZERO
var _tempo_mira := 0.0
var _tempo_recarga := 0.0
var _tempo_protecao := 0.0
var _chapeu: Chapeu
var _forma_chute := CircleShape2D.new()
var _acao_visual := false
var _recuperacao_pendente := false
var _tremor: Tween

@onready var sprite: AnimatedSprite2D = $Michael_Sprite
@onready var colisor: CollisionShape2D = $Michael_Colisor
@onready var efeito_chute: Polygon2D = $EfeitoChute
@onready var _figurino: SpriteFrames = sprite.sprite_frames
@onready var _camera: Camera2D = $Camera2D
@onready var _offset_camera := _camera.offset

func _ready() -> void:
	posicao_inicial = global_position
	sprite.animation_finished.connect(_ao_terminar_animacao)
	add_child(Pausa.new())


func _physics_process(delta: float) -> void:
	if vida <= 0:
		return
	_tempo_chute = maxf(0.0, _tempo_chute - delta)
	_tempo_recarga = maxf(0.0, _tempo_recarga - delta)
	_tempo_protecao = maxf(0.0, _tempo_protecao - delta)
	_protecao_esquiva = maxf(0.0, _protecao_esquiva - delta)
	_janela_perfeita = maxf(0.0, _janela_perfeita - delta)
	_brilho_esquiva = maxf(0.0, _brilho_esquiva - delta)
	_tempo_combo = maxf(0.0, _tempo_combo - delta)
	if _tempo_combo <= 0.0:
		_passo_combo = 0
	_recarga_dash = maxf(0.0, _recarga_dash - delta)
	_tempo_mira = maxf(0.0, _tempo_mira - delta)

	if _tempo_moonwalk > 0.0:
		_deslizar(delta)
	elif _tempo_dash > 0.0:
		_avancar_dash(delta)
	else:
		var direcao := Input.get_vector("Esquerda", "Direita", "Cima", "Baixo")
		if Input.is_action_just_pressed("Moonwalk") and _tempo_recarga <= 0.0:
			_tempo_recarga = recarga_moonwalk
			_tempo_moonwalk = duracao_moonwalk
			_protecao_esquiva = invulnerabilidade_moonwalk
			_janela_perfeita = minf(janela_esquiva_perfeita, invulnerabilidade_moonwalk)
			_forma_moonwalk.radius = raio_onda_moonwalk
			_empurrados_moonwalk.clear()
			_cancelar_ataque()
			_ultima_sombra = global_position
			_levantar_poeira()
			if not _tocar_acao("Moonwalk", _quadros_atuais(), duracao_moonwalk):
				sprite.stop()
				sprite.play(_animacao, -2.0, true)
			_deslizar(delta)
		elif Input.is_action_just_pressed("Dash") and _recarga_dash <= 0.0 and _protecao_esquiva <= 0.0 and not direcao.is_zero_approx():
			_tempo_dash = duracao_dash
			_recarga_dash = recarga_dash
			_direcao_dash = direcao
			_cancelar_ataque()
			_ultima_sombra = global_position
			_virar(direcao)
			_levantar_poeira()
			if not _tocar_acao("Dash", _quadros_atuais(), duracao_dash):
				sprite.play(_animacao, 1.6)
			_avancar_dash(delta)
		else:
			if _tempo_mira <= 0.0 and not direcao.is_zero_approx():
				_virar(direcao)
			if Input.is_action_just_pressed("Chute") and _tempo_chute <= 0.0:
				_chutar()
			if Input.is_action_just_pressed("Chapeu") and not is_instance_valid(_chapeu):
				_arremessar()
			_andar(direcao)

	_atualizar_chute(delta)
	sprite.modulate = Color.WHITE
	if _brilho_esquiva > 0.0:
		sprite.modulate = Color(0.73, 0.96, 1.0)
	elif _tempo_moonwalk > 0.0:
		sprite.modulate = Color(0.55, 0.86, 1.0)
	elif _tempo_protecao > 0.0:
		sprite.modulate = Color(1.0, 0.5, 0.5)

func direcao_da_mira() -> Vector2:
	var vetor := get_global_mouse_position() - global_position
	return frente if vetor.is_zero_approx() else vetor.normalized()

func _cancelar_ataque() -> void:
	_janela_chute = 0.0
	_tempo_mira = 0.0
	efeito_chute.hide()

func _avancar_dash(delta: float) -> void:
	# Limita o último passo à duração restante, inclusive com outro tickrate.
	velocity = _direcao_dash * velocidade_dash * minf(1.0, _tempo_dash / delta)
	move_and_slide()
	_rastro(Color(1.0, 0.82, 0.55, 0.26))
	_tempo_dash = maxf(0.0, _tempo_dash - delta)
	if _tempo_dash <= 0.0:
		sprite.stop()

func tempo_dash() -> float:
	return _recarga_dash

func _andar(direcao: Vector2) -> void:
	velocity = direcao * velocidade_movimento
	move_and_slide()
	if _acao_visual and sprite.is_playing():
		return
	_acao_visual = false
	if _recuperacao_pendente:
		_recuperacao_pendente = false
		if _tocar_acao("Recuperar", _figurino):
			return

	var quadros := _quadros_atuais()
	if not direcao.is_zero_approx() and get_real_velocity().length_squared() > 1.0:
		_usar_quadros(quadros)
		# A caminhada acompanha a velocidade para Michael não parecer deslizar.
		sprite.play(_animacao, clampf(velocidade_movimento / VELOCIDADE_BASE_ANIMACAO, 0.5, 2.0))
	else:
		var em_voo := StringName("EmVoo_" + String(_animacao))
		var parado := StringName("Parado_" + String(_animacao))
		if is_instance_valid(_chapeu) and _figurino.has_animation(em_voo):
			_usar_quadros(_figurino)
			sprite.animation = em_voo
		elif quadros.has_animation(parado):
			_usar_quadros(quadros)
			sprite.animation = parado
		elif not direcao.is_zero_approx() or _animacao != &"Baixo" or sprite.animation != &"Parado":
			_usar_quadros(quadros)
			sprite.animation = _animacao
		sprite.stop()

func _quadros_atuais() -> SpriteFrames:
	if figurino_sem_chapeu != null and (is_instance_valid(_chapeu) or _recuperacao_pendente):
		return figurino_sem_chapeu
	return _figurino

func _usar_quadros(quadros: SpriteFrames) -> void:
	if sprite.sprite_frames != quadros:
		sprite.sprite_frames = quadros

func _tocar_acao(prefixo: String, quadros: SpriteFrames, duracao := 0.0, inicio := 0) -> bool:
	var nome := StringName(prefixo + "_" + String(_animacao))
	if not quadros.has_animation(nome):
		return false
	inicio = mini(inicio, quadros.get_frame_count(nome) - 1)
	var velocidade := 1.0
	if duracao > 0.0:
		var unidades := 0.0
		for quadro in range(inicio, quadros.get_frame_count(nome)):
			unidades += quadros.get_frame_duration(nome, quadro)
		velocidade = unidades / (quadros.get_animation_speed(nome) * duracao)
	_usar_quadros(quadros)
	sprite.stop()
	sprite.play(nome, velocidade)
	sprite.set_frame_and_progress(inicio, 0.0)
	_acao_visual = true
	return true

func _virar(direcao: Vector2) -> void:
	if absf(direcao.y) > absf(direcao.x):
		frente = Vector2(0, signf(direcao.y))
		_animacao = &"Cima" if frente.y < 0.0 else &"Baixo"
	else:
		frente = Vector2(signf(direcao.x), 0)
		_animacao = &"Esquerda" if frente.x < 0.0 else &"Direita"

func _deslizar(delta: float) -> void:
	velocity = -frente * velocidade_moonwalk
	move_and_slide()
	_rastro(Color(0.44, 0.76, 1.0, 0.30))
	_empurrar_no_moonwalk()
	_tempo_moonwalk = maxf(0.0, _tempo_moonwalk - delta)
	if _tempo_moonwalk <= 0.0001:
		_tempo_moonwalk = 0.0
		sprite.stop()

func _rastro(tom: Color) -> void:
	if global_position.distance_squared_to(_ultima_sombra) < 12.0 * 12.0:
		return
	_ultima_sombra = global_position
	var sombra := Sprite2D.new()
	sombra.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	sombra.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sombra.modulate = tom
	get_parent().add_child(sombra)
	sombra.global_transform = sprite.global_transform
	var transicao := sombra.create_tween()
	transicao.tween_property(sombra, "modulate:a", 0.0, 0.18)
	transicao.tween_callback(sombra.queue_free)

func _chutar() -> void:
	_passo_combo += 1
	_golpe_final = _passo_combo == 3
	_tempo_combo = 0.0 if _golpe_final else janela_combo
	if _golpe_final:
		_passo_combo = 0
	_tempo_chute = recarga_chute * (1.2 if _golpe_final else 1.0)
	_janela_chute = duracao_chute * (1.35 if _golpe_final else 1.0)
	_direcao_chute = direcao_da_mira()
	_tempo_mira = _janela_chute
	_virar(_direcao_chute)
	# O golpe final começa na pose de impacto, no mesmo passo que ativa o arco.
	_tocar_acao("Chute", _quadros_atuais(), _janela_chute * 1.5, 2 if _golpe_final else 1)
	_atingidos_chute.clear()
	_forma_chute.radius = alcance_chute * (multiplicador_alcance_final if _golpe_final else 1.0)
	var arco := PackedVector2Array([Vector2.ZERO])
	for segmento in range(13):
		var angulo := deg_to_rad(lerpf(-semiabertura_chute, semiabertura_chute, float(segmento) / 12.0))
		arco.append(Vector2.from_angle(angulo) * _forma_chute.radius)
	efeito_chute.polygon = arco
	efeito_chute.color = Color(1.0, 0.53, 0.29, 0.32) if _golpe_final else Color(1.0, 0.74, 0.38, 0.20)
	efeito_chute.show()

func _atualizar_chute(delta: float) -> void:
	if _janela_chute <= 0.0:
		efeito_chute.hide()
		return
	_janela_chute = maxf(0.0, _janela_chute - delta)
	var origem := colisor.global_position
	efeito_chute.global_transform = Transform2D(_direcao_chute.angle(), origem)
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = _forma_chute
	consulta.transform = Transform2D(0.0, origem)
	consulta.collision_mask = CAMADA_INIMIGO
	var espaco := get_world_2d().direct_space_state
	var limite_angular := cos(deg_to_rad(semiabertura_chute))
	for resultado in espaco.intersect_shape(consulta):
		var inimigo := resultado.collider as CollisionObject2D
		if inimigo == null or not inimigo.has_method("receber_dano") or inimigo.vida <= 0 or _atingidos_chute.has(inimigo.get_instance_id()):
			continue
		var deslocamento := inimigo.global_position - origem
		if deslocamento.length_squared() > _forma_chute.radius * _forma_chute.radius:
			continue
		var sentido := _direcao_chute if deslocamento.is_zero_approx() else deslocamento.normalized()
		if sentido.dot(_direcao_chute) < limite_angular:
			continue
		var raio := PhysicsRayQueryParameters2D.create(origem, inimigo.global_position, CAMADA_CENARIO)
		if espaco.intersect_ray(raio).is_empty():
			if _golpe_final and _atingidos_chute.is_empty():
				_tremer_camera(2.0)
			_atingidos_chute[inimigo.get_instance_id()] = true
			var empurrao := empurrao_chute * (multiplicador_empurrao_final if _golpe_final else 1.0)
			inimigo.receber_dano(dano_golpe_final if _golpe_final else 1, sentido * empurrao, &"chute")
			efeito_chute.color = Color(1.0, 0.60, 0.31, 0.48) if _golpe_final else Color(1.0, 0.79, 0.42, 0.36)

func _empurrar_no_moonwalk() -> void:
	var origem := colisor.global_position
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = _forma_moonwalk
	consulta.transform = Transform2D(0.0, origem)
	consulta.collision_mask = CAMADA_INIMIGO
	var espaco := get_world_2d().direct_space_state
	for resultado in espaco.intersect_shape(consulta):
		var inimigo := resultado.collider as Inimigo
		if inimigo == null or inimigo.vida <= 0 or _empurrados_moonwalk.has(inimigo.get_instance_id()):
			continue
		var raio := PhysicsRayQueryParameters2D.create(origem, inimigo.global_position, CAMADA_CENARIO)
		if not espaco.intersect_ray(raio).is_empty():
			continue
		_empurrados_moonwalk[inimigo.get_instance_id()] = true
		var sentido := origem.direction_to(inimigo.global_position)
		inimigo.empurrar((frente if sentido.is_zero_approx() else sentido) * empurrao_onda_moonwalk)

func _levantar_poeira() -> void:
	var poeira := CPUParticles2D.new()
	poeira.emitting = false
	poeira.amount = 4
	poeira.one_shot = true
	poeira.lifetime = 0.25
	poeira.explosiveness = 1.0
	poeira.direction = Vector2.UP
	poeira.spread = 65.0
	poeira.initial_velocity_min = 12.0
	poeira.initial_velocity_max = 32.0
	poeira.gravity = Vector2(0.0, 32.0)
	poeira.scale_amount_min = 1.5
	poeira.scale_amount_max = 2.5
	poeira.color = Color(0.84, 0.79, 0.72, 0.49)
	poeira.finished.connect(poeira.queue_free, CONNECT_ONE_SHOT)
	get_parent().add_child(poeira)
	poeira.global_position = colisor.global_position
	poeira.emitting = true

func _tremer_camera(forca: float) -> void:
	_encerrar_tremor()
	_tremor = create_tween()
	_tremor.tween_property(_camera, "offset", _offset_camera + Vector2(1.0, -0.5) * forca, 0.035)
	_tremor.tween_property(_camera, "offset", _offset_camera + Vector2(-0.65, 0.25) * forca, 0.035)
	_tremor.tween_property(_camera, "offset", _offset_camera, 0.065)

func _encerrar_tremor() -> void:
	if _tremor != null and _tremor.is_valid():
		_tremor.kill()
	_camera.offset = _offset_camera

func tempo_moonwalk() -> float:
	return _tempo_recarga

func em_moonwalk() -> bool:
	return _tempo_moonwalk > 0.0

func _arremessar() -> void:
	_chapeu = CENA_CHAPEU.instantiate() as Chapeu
	_chapeu.recolhido.connect(_recolher_chapeu)
	get_parent().add_child(_chapeu)
	var mira := direcao_da_mira()
	_virar(mira)
	_tempo_mira = maxf(_tempo_mira, 0.15)
	_recuperacao_pendente = false
	# O quadro de soltura já não tem chapéu. O projétil sai no mesmo instante.
	_tocar_acao("Arremesso", _figurino, 0.0, 2)
	_chapeu.iniciar(colisor, mira, textura_chapeu)

func _recolher_chapeu() -> void:
	_chapeu = null
	_recuperacao_pendente = vida > 0

func receber_dano(ataque_confirmado := false) -> void:
	if invencivel_dev or _tempo_protecao > 0.0 or vida <= 0:
		return
	if _protecao_esquiva > 0.0:
		if ataque_confirmado and _janela_perfeita > 0.0:
			_janela_perfeita = 0.0
			_brilho_esquiva = 0.25
			_tempo_recarga = minf(_tempo_recarga, recarga_apos_esquiva_perfeita)
			_recarga_dash = 0.0
			_tremer_camera(1.0)
			esquiva_perfeita.emit()
		return
	_tempo_protecao = protecao_apos_dano
	vida -= 1
	vida_alterada.emit(vida)
	if vida == 0:
		velocity = Vector2.ZERO
		_tempo_dash = 0.0
		_tempo_moonwalk = 0.0
		_acao_visual = false
		_recuperacao_pendente = false
		_passo_combo = 0
		_tempo_combo = 0.0
		_encerrar_tremor()
		_cancelar_ataque()
		if is_instance_valid(_chapeu):
			_chapeu.queue_free()
		if _figurino.has_animation(&"Morte"):
			_usar_quadros(_figurino)
			sprite.stop()
			sprite.modulate = Color.WHITE
			sprite.play(&"Morte")
		else:
			_reiniciar_derrota()
	elif _tempo_dash <= 0.0:
		_tocar_acao("Dano", _quadros_atuais())

func _ao_terminar_animacao() -> void:
	if sprite.animation == &"Morte":
		_reiniciar_derrota()

func _reiniciar_derrota() -> void:
	var cena := get_tree().current_scene
	if vida == 0 and cena != null and cena.is_ancestor_of(self):
		get_tree().call_deferred("reload_current_scene")

func recuperar_uma_vida() -> bool:
	if vida <= 0 or vida >= VIDA_MAXIMA:
		return false
	vida += 1
	vida_alterada.emit(vida)
	return true

func restaurar_vida() -> void:
	vida = VIDA_MAXIMA
	vida_alterada.emit(vida)

func restaurar_recargas() -> void:
	_recarga_dash = 0.0
	_tempo_chute = 0.0
	_tempo_recarga = 0.0

func teletransportar(destino: Vector2) -> void:
	global_position = destino
	velocity = Vector2.ZERO
	_tempo_moonwalk = 0.0
	_tempo_dash = 0.0
	_protecao_esquiva = 0.0
	_janela_perfeita = 0.0
	_brilho_esquiva = 0.0
	_passo_combo = 0
	_tempo_combo = 0.0
	_acao_visual = false
	_cancelar_ataque()
	_encerrar_tremor()
	_camera.reset_smoothing()
	_camera.force_update_scroll()
