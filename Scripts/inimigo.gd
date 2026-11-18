class_name Inimigo
extends CharacterBody2D

@export var distancia_patrulha := 28.0
@export var velocidade_patrulha := 25.0

var vida := 2
var _origem := 0.0
var _lado := 1.0
var _empurrao := Vector2.ZERO
var _tempo_impacto := 0.0

@onready var visual: Node2D = $Visual
@onready var contato: Area2D = $Contato

func _ready() -> void:
	_origem = global_position.x

func _physics_process(delta: float) -> void:
	if vida <= 0:
		return

	_tempo_impacto = maxf(0.0, _tempo_impacto - delta)
	visual.modulate = Color(1.0, 0.35, 0.35) if _tempo_impacto > 0.0 else Color.WHITE
	if not _empurrao.is_zero_approx():
		velocity = _empurrao
		_empurrao = _empurrao.move_toward(Vector2.ZERO, 680.0 * delta)
		move_and_slide()
	else:
		if (global_position.x - _origem) * _lado >= distancia_patrulha:
			_lado *= -1
		velocity = Vector2(_lado * velocidade_patrulha, 0)
		if move_and_slide():
			_lado *= -1

	for jogador in contato.get_overlapping_bodies():
		if jogador.has_method("receber_dano"):
			jogador.receber_dano()

func receber_dano(dano: int, empurrao := Vector2.ZERO) -> void:
	if vida <= 0:
		return
	vida -= dano
	_empurrao = empurrao
	_tempo_impacto = 0.18
	if vida <= 0:
		queue_free()
