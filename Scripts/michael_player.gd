class_name MichaelJogador
extends CharacterBody2D

signal vida_alterada(restantes: int)

const VIDA_MAXIMA := 4
const CENA_CHAPEU := preload("res://Scenes/chapeu.tscn")
const Pausa := preload("res://Scripts/pausa.gd")
const CAMADA_CENARIO := 1
const CAMADA_INIMIGO := 4

@export var velocidade_movimento := 80.0
@export var protecao_apos_dano := 0.85

@export_group("Figurino")
@export var figurino_sem_chapeu: SpriteFrames
@export var textura_chapeu: Texture2D

@export_group("Chute")
@export var alcance_chute := 48.0
@export_range(1.0, 89.0) var semiabertura_chute := 52.0
@export var duracao_chute := 0.10
@export var recarga_chute := 0.45
@export var empurrao_chute := 130.0

@export_group("Moonwalk")
@export var velocidade_moonwalk := 300.0
@export var duracao_moonwalk := 0.25
@export var invulnerabilidade_moonwalk := 0.30
@export var recarga_moonwalk := 1.5

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
var _protecao_esquiva := 0.0
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

@onready var sprite: AnimatedSprite2D = $Michael_Sprite
@onready var colisor: CollisionShape2D = $Michael_Colisor
@onready var efeito_chute: Polygon2D = $EfeitoChute
@onready var _figurino: SpriteFrames = sprite.sprite_frames

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
			_cancelar_ataque()
			_ultima_sombra = global_position
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
	if _tempo_moonwalk > 0.0:
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
		sprite.play(_animacao)
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
	_tempo_chute = recarga_chute
	_janela_chute = duracao_chute
	_direcao_chute = direcao_da_mira()
	_tempo_mira = duracao_chute
	_virar(_direcao_chute)
	# A pose de impacto cai dentro da janela de acerto já usada pelo combate.
	_tocar_acao("Chute", _quadros_atuais(), duracao_chute * 1.5, 1)
	_atingidos_chute.clear()
	_forma_chute.radius = alcance_chute
	var arco := PackedVector2Array([Vector2.ZERO])
	for segmento in range(13):
		var angulo := deg_to_rad(lerpf(-semiabertura_chute, semiabertura_chute, float(segmento) / 12.0))
		arco.append(Vector2.from_angle(angulo) * alcance_chute)
	efeito_chute.polygon = arco
	efeito_chute.color = Color(1.0, 0.74, 0.38, 0.20)
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
		if deslocamento.length_squared() > alcance_chute * alcance_chute:
			continue
		var sentido := _direcao_chute if deslocamento.is_zero_approx() else deslocamento.normalized()
		if sentido.dot(_direcao_chute) < limite_angular:
			continue
		var raio := PhysicsRayQueryParameters2D.create(origem, inimigo.global_position, CAMADA_CENARIO)
		if espaco.intersect_ray(raio).is_empty():
			_atingidos_chute[inimigo.get_instance_id()] = true
			inimigo.receber_dano(1, sentido * empurrao_chute)
			efeito_chute.color = Color(1.0, 0.79, 0.42, 0.36)

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

func receber_dano() -> void:
	if invencivel_dev or _protecao_esquiva > 0.0 or _tempo_protecao > 0.0 or vida <= 0:
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
	_acao_visual = false
	_cancelar_ataque()
	var camera: Camera2D = $Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
