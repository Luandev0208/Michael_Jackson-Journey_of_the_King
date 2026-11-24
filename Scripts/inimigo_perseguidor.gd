extends Inimigo

@export var raio_deteccao := 130.0
@export var raio_abandono := 190.0
@export var velocidade_perseguicao := 58.0
@export var distancia_contato := 21.0

var _alcance_posto := 224.0

var alvo: Node2D
var caminhos: AStarGrid2D
var perseguindo := false
var _posto := Vector2.ZERO
var _retornando := false
var _recalcular := 0.0
var _rota := PackedVector2Array()
var _passo := 0

func _ready() -> void:
	super._ready()
	_posto = global_position
	if atraso_aparicao > 0.0:
		visual.modulate.a = 0.3


func _mover(delta: float) -> void:
	if not is_instance_valid(alvo) or caminhos == null:
		super._mover(delta)
		return

	var distancia := global_position.distance_to(alvo.global_position)
	var perto_do_posto := _posto.distance_to(alvo.global_position) < _alcance_posto
	var buscar := distancia < (raio_abandono if perseguindo else raio_deteccao)
	if buscar and perto_do_posto and not perseguindo and not has_meta("obrigatorio"):
		var raio := PhysicsRayQueryParameters2D.create(global_position, alvo.global_position, 1)
		buscar = get_world_2d().direct_space_state.intersect_ray(raio).is_empty()

	if buscar and perto_do_posto:
		if not perseguindo:
			_recalcular = 0.0
		perseguindo = true
		_retornando = false
		if distancia <= distancia_contato and contato.overlaps_body(alvo.get_parent()):
			# Segura o alcance do ataque e abre espaço se Michael encostar.
			velocity = Vector2.ZERO
			if distancia < distancia_contato - 3.0:
				var recuo := global_position - alvo.global_position
				if recuo.is_zero_approx():
					recuo = Vector2.RIGHT
				velocity = recuo.normalized() * velocidade_patrulha
				move_and_slide()
			return
		_seguir(_destino_perseguicao(distancia), velocidade_perseguicao, delta)
	elif perseguindo or _retornando:
		if perseguindo:
			_recalcular = 0.0
		perseguindo = false
		_retornando = global_position.distance_to(_posto) > 3.0
		if _retornando:
			_seguir(_posto, velocidade_patrulha, delta)
		else:
			velocity = Vector2.ZERO
	else:
		super._mover(delta)

# Ponto para onde o inimigo caminha. Subclasses podem flanquear em vez de ir direto.
func _destino_perseguicao(_distancia: float) -> Vector2:
	return alvo.global_position

func _flanquear(largura: float) -> Vector2:
	var sentido := global_position.direction_to(alvo.global_position)
	var lado := 1.0 if get_instance_id() % 2 == 0 else -1.0
	var desvio := sentido.orthogonal() * lado * largura
	for variante: Vector2 in [desvio, -desvio]:
		var ponto := alvo.global_position + variante
		var celula := Vector2i((ponto / caminhos.cell_size).floor())
		if caminhos.region.has_point(celula) and not caminhos.is_point_solid(celula):
			return ponto
	return alvo.global_position


func _seguir(destino: Vector2, rapidez: float, delta: float) -> void:
	_recalcular -= delta
	if _recalcular <= 0.0:
		_recalcular = 0.22
		var origem := Vector2i((global_position / caminhos.cell_size).floor())
		var final := Vector2i((destino / caminhos.cell_size).floor())
		_rota = PackedVector2Array()
		_passo = 1
		if caminhos.region.has_point(origem) and caminhos.region.has_point(final):
			_rota = caminhos.get_point_path(origem, final, true)
			if _rota.size() > 1 and test_move(global_transform, _rota[1] - global_position):
				_passo = 0

	var proximo := destino
	while _passo < _rota.size() and global_position.distance_to(_rota[_passo]) < 2.0:
		_passo += 1
	if _passo < _rota.size():
		proximo = _rota[_passo]
	elif global_position.distance_to(destino) >= caminhos.cell_size.x * 1.5:
		velocity = Vector2.ZERO
		return

	velocity = (proximo - global_position).limit_length(rapidez * delta) / delta
	if move_and_slide():
		_recalcular = 0.0
