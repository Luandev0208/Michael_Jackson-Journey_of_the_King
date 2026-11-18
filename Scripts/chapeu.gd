class_name Chapeu
extends CharacterBody2D

@export var velocidade := 250.0
@export var distancia_maxima := 135.0
@export var dano := 1

var retornando := false
var _alvo: Node2D
var _direcao := Vector2.ZERO
var _distancia := 0.0
var _atingidos := {}

@onready var visual: Node2D = $Visual
@onready var alcance: ShapeCast2D = $Alcance

func iniciar(alvo: Node2D, direcao: Vector2) -> void:
	_alvo = alvo
	_direcao = direcao
	global_position = alvo.global_position

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_alvo):
		queue_free()
		return

	visual.rotation += TAU * 2.5 * delta
	var origem := global_position
	var limite := velocidade * delta
	if retornando:
		# O retorno busca Michael mesmo se ele mudar de lado de um obstáculo.
		global_position = origem.move_toward(_alvo.global_position, limite * 1.35)
		if global_position.is_equal_approx(_alvo.global_position):
			queue_free()
	else:
		var colisao := move_and_collide(_direcao * minf(limite, distancia_maxima - _distancia))
		_distancia += origem.distance_to(global_position)
		retornando = colisao != null or _distancia >= distancia_maxima - 0.001

	var destino := global_position
	alcance.global_position = origem
	alcance.target_position = destino - origem
	alcance.force_shapecast_update()
	for indice in alcance.get_collision_count():
		var inimigo := alcance.get_collider(indice) as Inimigo
		if inimigo == null or _atingidos.has(inimigo.get_instance_id()):
			continue
		_atingidos[inimigo.get_instance_id()] = true
		inimigo.receber_dano(dano)
	alcance.position = Vector2.ZERO
