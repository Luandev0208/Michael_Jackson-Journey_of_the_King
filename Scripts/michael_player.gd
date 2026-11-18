extends CharacterBody2D

const VELOCIDADE := 80.0
const CENA_CHAPEU := preload("res://Scenes/chapeu.tscn")
const CAMADA_CENARIO := 1
const CAMADA_INIMIGO := 4

@export var recarga_chute := 0.45
@export var duracao_moonwalk := 0.25
@export var recarga_moonwalk := 1.5
@export var velocidade_moonwalk := 220.0

var vida := 3
var frente := Vector2.DOWN
var _animacao: StringName = &"Baixo"
var _tempo_chute := 0.0
var _tempo_moonwalk := 0.0
var _tempo_recarga := 0.0
var _tempo_protecao := 0.0
var _chapeu: Chapeu
var _forma_chute := RectangleShape2D.new()

@onready var sprite: AnimatedSprite2D = $Michael_Sprite
@onready var colisor: CollisionShape2D = $Michael_Colisor
@onready var efeito_chute: Polygon2D = $EfeitoChute

func _ready() -> void:
	_forma_chute.size = Vector2(28, 24)

func _physics_process(delta: float) -> void:
	_tempo_chute = maxf(0.0, _tempo_chute - delta)
	_tempo_recarga = maxf(0.0, _tempo_recarga - delta)
	_tempo_protecao = maxf(0.0, _tempo_protecao - delta)

	if _tempo_moonwalk > 0.0:
		_deslizar(delta)
	else:
		var direcao := Input.get_vector("Esquerda", "Direita", "Cima", "Baixo")
		if Input.is_action_just_pressed("Moonwalk") and _tempo_recarga <= 0.0:
			_tempo_recarga = recarga_moonwalk
			_tempo_moonwalk = duracao_moonwalk
			sprite.stop()
			sprite.play_backwards(_animacao)
			_deslizar(delta)
		else:
			if not direcao.is_zero_approx():
				_virar(direcao)
			_andar(direcao)
			if Input.is_action_just_pressed("Chute") and _tempo_chute <= 0.0:
				_chutar()
			if Input.is_action_just_pressed("Chapeu") and not is_instance_valid(_chapeu):
				_arremessar()

	sprite.modulate = Color.WHITE
	if _tempo_moonwalk > 0.0:
		sprite.modulate = Color(0.55, 0.86, 1.0)
	elif _tempo_protecao > 0.0:
		sprite.modulate = Color(1.0, 0.5, 0.5)

func _andar(direcao: Vector2) -> void:
	velocity = direcao * VELOCIDADE
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
	_tempo_moonwalk = maxf(0.0, _tempo_moonwalk - delta)
	if _tempo_moonwalk <= 0.0001:
		_tempo_moonwalk = 0.0
		sprite.stop()

func _chutar() -> void:
	_tempo_chute = recarga_chute
	var origem := colisor.global_position
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = _forma_chute
	consulta.transform = Transform2D(frente.angle(), origem + frente * 20.0)
	consulta.collision_mask = CAMADA_INIMIGO
	var espaco := get_world_2d().direct_space_state
	var atingidos := {}
	for resultado in espaco.intersect_shape(consulta):
		var inimigo := resultado.collider as Inimigo
		if inimigo == null or atingidos.has(inimigo):
			continue
		if frente.dot(inimigo.global_position - origem) <= 0.0:
			continue
		var raio := PhysicsRayQueryParameters2D.create(origem, inimigo.global_position, CAMADA_CENARIO)
		if espaco.intersect_ray(raio).is_empty():
			atingidos[inimigo] = true
			inimigo.receber_dano(1, frente * 115.0)

	# A parte visual pode ser substituída por uma animação de chute.
	efeito_chute.global_transform = consulta.transform
	efeito_chute.modulate.a = 1.0
	efeito_chute.show()
	var efeito := create_tween()
	efeito.tween_property(efeito_chute, "modulate:a", 0.0, 0.16)
	efeito.tween_callback(efeito_chute.hide)

func _arremessar() -> void:
	_chapeu = CENA_CHAPEU.instantiate() as Chapeu
	get_parent().add_child(_chapeu)
	_chapeu.iniciar(colisor, frente)

func receber_dano() -> void:
	if _tempo_moonwalk > 0.0 or _tempo_protecao > 0.0 or vida <= 0:
		return
	vida -= 1
	_tempo_protecao = 0.65
	if vida == 0:
		get_tree().call_deferred("reload_current_scene")
