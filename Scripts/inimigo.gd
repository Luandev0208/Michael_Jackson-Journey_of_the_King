class_name Inimigo
extends CharacterBody2D

signal derrotado

@export var distancia_patrulha := 28.0
@export var velocidade_patrulha := 25.0
@export var preparacao_contato := 0.0
@export var recarga_contato := 0.75

var vida := 2
var ia_ativa := true
var atraso_aparicao := 0.0
var _origem := 0.0
var _lado := 1.0
var _empurrao := Vector2.ZERO
var _tempo_impacto := 0.0
var _tempo_contato := 0.0
var _preparacao_restante := -1.0

@onready var visual: Node2D = $Visual
@onready var contato: Area2D = $Contato

func _ready() -> void:
	_origem = global_position.x

func _physics_process(delta: float) -> void:
	if vida <= 0:
		return

	_tempo_contato = maxf(0.0, _tempo_contato - delta)
	_tempo_impacto = maxf(0.0, _tempo_impacto - delta)
	visual.modulate = Color(1.0, 0.35, 0.35) if _tempo_impacto > 0.0 else Color.WHITE
	if atraso_aparicao > 0.0:
		atraso_aparicao = maxf(0.0, atraso_aparicao - delta)
		visual.modulate.a = clampf(1.0 - atraso_aparicao, 0.3, 1.0)
		return
	if not _empurrao.is_zero_approx():
		velocity = _empurrao
		_empurrao = _empurrao.move_toward(Vector2.ZERO, 680.0 * delta)
		move_and_slide()
	elif ia_ativa:
		_mover(delta)
	else:
		velocity = Vector2.ZERO

	if ia_ativa and _tempo_contato <= 0.0:
		_atacar_por_contato(delta)
	else:
		_preparacao_restante = -1.0

func _atacar_por_contato(delta: float) -> void:
	for jogador in contato.get_overlapping_bodies():
		if not jogador.has_method("receber_dano"):
			continue
		var colisor: Node2D = jogador.get_node("Michael_Colisor")
		var raio := PhysicsRayQueryParameters2D.create(global_position, colisor.global_position, 1)
		raio.hit_from_inside = true
		if not get_world_2d().direct_space_state.intersect_ray(raio).is_empty():
			continue
		if _preparacao_restante < 0.0:
			_preparacao_restante = preparacao_contato
		_preparacao_restante -= delta
		if _preparacao_restante > 0.0:
			visual.modulate = Color(1.0, 0.71, 0.47)
			return
		_tempo_contato = recarga_contato
		_preparacao_restante = -1.0
		jogador.receber_dano()
		return
	_preparacao_restante = -1.0

func _mover(_delta: float) -> void:
	if (global_position.x - _origem) * _lado >= distancia_patrulha:
		_lado *= -1
	velocity = Vector2(_lado * velocidade_patrulha, 0)
	if move_and_slide():
		_lado *= -1

func receber_dano(dano: int, empurrao := Vector2.ZERO) -> void:
	if vida <= 0:
		return
	vida -= dano
	_empurrao = empurrao
	_tempo_impacto = 0.18
	_preparacao_restante = -1.0
	_tempo_contato = maxf(_tempo_contato, _tempo_impacto)
	_mostrar_impacto()
	if vida <= 0:
		derrotado.emit()
		queue_free()


func _mostrar_impacto() -> void:
	var faisca := Polygon2D.new()
	faisca.polygon = PackedVector2Array([-7, 0, -2, -2, 0, -8, 2, -2, 7, 0, 2, 2, 0, 8, -2, 2])
	faisca.color = Color(1.0, 0.88, 0.60)
	faisca.z_index = 4
	get_parent().add_child(faisca)
	faisca.global_position = global_position + Vector2(0, -20)
	var efeito := faisca.create_tween().set_parallel()
	efeito.tween_property(faisca, "position:y", faisca.position.y - 8.0, 0.18)
	efeito.tween_property(faisca, "modulate:a", 0.0, 0.18)
	efeito.chain().tween_callback(faisca.queue_free)
