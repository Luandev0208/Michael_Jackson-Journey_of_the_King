class_name Chapeu
extends CharacterBody2D

signal recolhido

const MAX_PONTOS_RASTRO := 8
const PASSO_RASTRO_QUADRADO := 9.0 * 9.0

@export var velocidade := 270.0
@export var distancia_maxima := 160.0
@export var multiplicador_retorno := 1.55
@export var dano := 1
@export var empurrao := 85.0
# Michael é desenhado com escala 2; o chapéu lançado precisa seguir a mesma proporção.
# É só visual: as hitboxes (Alcance e colisor) não mudam.
@export var escala_visual := 2.0
@export var altura_cabeca := 27.0
@export var distancia_pouso := 52.0

var retornando := false
var _alvo: Node2D
var _direcao := Vector2.ZERO
var _distancia := 0.0
var _inicio_da_volta := true
var _altura_base := -16.0
var _tempo_decolagem := 0.0

@onready var visual: Node2D = $Visual
@onready var alcance: ShapeCast2D = $Alcance
@onready var rastro: Line2D = $Rastro

func iniciar(alvo: Node2D, direcao: Vector2, textura: Texture2D = null) -> void:
	_alvo = alvo
	_direcao = direcao
	global_position = alvo.global_position
	_altura_base = visual.position.y
	visual.position.y = _altura_base - altura_cabeca
	rastro.add_point(rastro.to_local(visual.global_position))
	if textura != null:
		for parte: CanvasItem in visual.get_children():
			parte.hide()
		var arte := Sprite2D.new()
		arte.texture = textura
		arte.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		arte.scale = Vector2(escala_visual, escala_visual)
		visual.add_child(arte)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_alvo):
		queue_free()
		return

	visual.rotation += TAU * 2.5 * delta
	_atualizar_altura(delta)
	var origem := global_position
	var limite := velocidade * delta
	var voltou := false
	if retornando:
		if _inicio_da_volta:
			# O passo que toca a parede ainda pertence à ida.
			alcance.clear_exceptions()
			_inicio_da_volta = false
		# O retorno busca Michael mesmo se ele mudar de lado de um obstáculo.
		global_position = origem.move_toward(_alvo.global_position, limite * multiplicador_retorno)
		voltou = global_position.is_equal_approx(_alvo.global_position)
	else:
		var colisao := move_and_collide(_direcao * minf(limite, distancia_maxima - _distancia))
		_distancia += origem.distance_to(global_position)
		retornando = colisao != null or _distancia >= distancia_maxima - 0.001

	var destino := global_position
	_atualizar_rastro()
	alcance.global_position = origem
	alcance.target_position = destino - origem
	alcance.force_shapecast_update()
	for indice in alcance.get_collision_count():
		var inimigo := alcance.get_collider(indice) as CollisionObject2D
		if inimigo == null or not inimigo.has_method("receber_dano") or inimigo.vida <= 0:
			continue
		var raio := PhysicsRayQueryParameters2D.create(origem, inimigo.global_position, collision_mask)
		raio.hit_from_inside = true
		if not get_world_2d().direct_space_state.intersect_ray(raio).is_empty():
			continue
		alcance.add_exception(inimigo)
		var sentido := origem.direction_to(destino)
		if sentido.is_zero_approx():
			sentido = origem.direction_to(inimigo.global_position)
		inimigo.receber_dano(dano, sentido * empurrao)
	alcance.position = Vector2.ZERO
	if voltou:
		queue_free()
		recolhido.emit()

func _atualizar_altura(delta: float) -> void:
	# Sai da cabeça de Michael, voa na altura normal e volta a subir ao pousar nele.
	var alvo_altura := _altura_base
	if retornando and is_instance_valid(_alvo):
		var falta := global_position.distance_to(_alvo.global_position)
		var pouso := clampf(1.0 - falta / distancia_pouso, 0.0, 1.0)
		alvo_altura = lerpf(_altura_base, _altura_base - altura_cabeca, pouso)
	visual.position.y = move_toward(visual.position.y, alvo_altura, altura_cabeca * 6.0 * delta)

func _atualizar_rastro() -> void:
	var atual := rastro.to_local(visual.global_position)
	if rastro.get_point_position(rastro.get_point_count() - 1).distance_squared_to(atual) < PASSO_RASTRO_QUADRADO:
		return
	rastro.add_point(atual)
	if rastro.get_point_count() > MAX_PONTOS_RASTRO:
		rastro.remove_point(0)
