class_name MichaelJogador
extends CharacterBody2D

signal vida_alterada(restantes: int)

const VIDA_MAXIMA := 3
const CENA_CHAPEU := preload("res://Scenes/chapeu.tscn")
const CAMADA_CENARIO := 1
const CAMADA_INIMIGO := 4

@export var velocidade_movimento := 80.0
@export var protecao_apos_dano := 0.85

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
var _tempo_recarga := 0.0
var _tempo_protecao := 0.0
var _chapeu: Chapeu
var _forma_chute := CircleShape2D.new()

@onready var sprite: AnimatedSprite2D = $Michael_Sprite
@onready var colisor: CollisionShape2D = $Michael_Colisor
@onready var efeito_chute: Polygon2D = $EfeitoChute

func _ready() -> void:
	posicao_inicial = global_position


func _physics_process(delta: float) -> void:
	_tempo_chute = maxf(0.0, _tempo_chute - delta)
	_tempo_recarga = maxf(0.0, _tempo_recarga - delta)
	_tempo_protecao = maxf(0.0, _tempo_protecao - delta)
	_protecao_esquiva = maxf(0.0, _protecao_esquiva - delta)

	if _tempo_moonwalk > 0.0:
		_deslizar(delta)
	else:
		var direcao := Input.get_vector("Esquerda", "Direita", "Cima", "Baixo")
		if Input.is_action_just_pressed("Moonwalk") and _tempo_recarga <= 0.0:
			_tempo_recarga = recarga_moonwalk
			_tempo_moonwalk = duracao_moonwalk
			_protecao_esquiva = invulnerabilidade_moonwalk
			_janela_chute = 0.0
			efeito_chute.hide()
			_ultima_sombra = global_position
			sprite.stop()
			sprite.play(_animacao, -2.0, true)
			_deslizar(delta)
		else:
			if not direcao.is_zero_approx():
				_virar(direcao)
			_andar(direcao)
			if Input.is_action_just_pressed("Chute") and _tempo_chute <= 0.0:
				_chutar()
			if Input.is_action_just_pressed("Chapeu") and not is_instance_valid(_chapeu):
				_arremessar()

	_atualizar_chute(delta)
	sprite.modulate = Color.WHITE
	if _tempo_moonwalk > 0.0:
		sprite.modulate = Color(0.55, 0.86, 1.0)
	elif _tempo_protecao > 0.0:
		sprite.modulate = Color(1.0, 0.5, 0.5)

func _andar(direcao: Vector2) -> void:
	velocity = direcao * velocidade_movimento
	move_and_slide()
	if not direcao.is_zero_approx() and get_real_velocity().length_squared() > 1.0:
		sprite.play(_animacao)
	else:
		if not direcao.is_zero_approx():
			sprite.animation = _animacao
		sprite.stop()

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
	if global_position.distance_squared_to(_ultima_sombra) >= 12.0 * 12.0:
		_criar_sombra()
		_ultima_sombra = global_position
	_tempo_moonwalk = maxf(0.0, _tempo_moonwalk - delta)
	if _tempo_moonwalk <= 0.0001:
		_tempo_moonwalk = 0.0
		sprite.stop()

func _criar_sombra() -> void:
	var sombra := Sprite2D.new()
	sombra.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	sombra.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sombra.modulate = Color(0.44, 0.76, 1.0, 0.30)
	get_parent().add_child(sombra)
	sombra.global_transform = sprite.global_transform
	var transicao := sombra.create_tween()
	transicao.tween_property(sombra, "modulate:a", 0.0, 0.18)
	transicao.tween_callback(sombra.queue_free)

func _chutar() -> void:
	_tempo_chute = recarga_chute
	_janela_chute = duracao_chute
	_direcao_chute = frente
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
		var inimigo := resultado.collider as Inimigo
		if inimigo == null or inimigo.vida <= 0 or _atingidos_chute.has(inimigo.get_instance_id()):
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
	get_parent().add_child(_chapeu)
	_chapeu.iniciar(colisor, frente)

func receber_dano() -> void:
	if invencivel_dev or _protecao_esquiva > 0.0 or _tempo_protecao > 0.0 or vida <= 0:
		return
	_tempo_protecao = protecao_apos_dano
	vida -= 1
	vida_alterada.emit(vida)
	if vida == 0:
		get_tree().call_deferred("reload_current_scene")

func restaurar_vida() -> void:
	vida = VIDA_MAXIMA
	vida_alterada.emit(vida)

func restaurar_recargas() -> void:
	_tempo_chute = 0.0
	_tempo_recarga = 0.0

func teletransportar(destino: Vector2) -> void:
	global_position = destino
	velocity = Vector2.ZERO
	_tempo_moonwalk = 0.0
	_protecao_esquiva = 0.0
	_janela_chute = 0.0
	efeito_chute.hide()
	var camera: Camera2D = $Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
