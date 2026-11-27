extends Inimigo

@export var raio_deteccao := 130.0
@export var raio_abandono := 190.0
@export var velocidade_perseguicao := 58.0
@export var distancia_contato := 21.0

const DURACAO_INVESTIDA := 0.34
const ALCANCE_IMPACTO := 20.0

var velocidade_investida := 0.0
var varia_investida := false
var _proxima_e_finta := true
var _tempo_finta := 0.0
var _alcance_posto := 224.0
var _preparando_investida := false
var _investindo := false
var _tempo_investida := 0.0
var _direcao_investida := Vector2.ZERO
var _trilha_investida: Line2D

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

	if _tempo_finta > 0.0:
		_tempo_finta -= delta
		var lado := -1.0 if get_instance_id() % 2 != 0 else 1.0
		move_and_collide(_direcao_investida.orthogonal() * lado * 67.0 * delta)
		if _tempo_finta <= 0.0:
			_anunciar_investida()
		return
	if _preparando_investida or _investindo:
		_executar_investida(delta)
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
		if velocidade_investida > 0.0 and _tempo_contato <= 0.0 and distancia >= 33.0 and distancia <= 68.0:
			if _linha_livre_ate_alvo() and _reservar_inicio_ataque():
				_preparar_investida()
				return
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


func _linha_livre_ate_alvo() -> bool:
	var raio := PhysicsRayQueryParameters2D.create(global_position, alvo.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(raio).is_empty()


func _preparar_investida() -> void:
	if varia_investida:
		_proxima_e_finta = not _proxima_e_finta
		if not _proxima_e_finta:
			_tempo_finta = 0.22
			_direcao_investida = global_position.direction_to(alvo.global_position)
			_olhar_para(_direcao_investida)
			_animar("finta", _tempo_finta, true)
			return
	_anunciar_investida()


func _anunciar_investida() -> void:
	_preparando_investida = true
	_tempo_investida = 0.43
	_direcao_investida = global_position.direction_to(alvo.global_position)
	_preparacao_restante = -1.0
	velocity = Vector2.ZERO
	_olhar_para(_direcao_investida)
	_animar("prepare", _tempo_investida, true)
	_trilha_investida = Line2D.new()
	var percurso := _direcao_investida * velocidade_investida * DURACAO_INVESTIDA
	var parede := KinematicCollision2D.new()
	if test_move(global_transform, percurso, parede):
		percurso = parede.get_travel()
	_trilha_investida.points = PackedVector2Array([Vector2.ZERO, percurso])
	_trilha_investida.width = ALCANCE_IMPACTO * 2.0
	_trilha_investida.default_color = Color(1.0, 0.59, 0.37, 0.38)
	_trilha_investida.z_index = 1
	add_child(_trilha_investida)
	AudioManager.tocar(&"ataque_inimigo", global_position)


func _executar_investida(delta: float) -> void:
	_tempo_investida -= delta
	if _preparando_investida:
		if _tempo_investida <= 0.0:
			_preparando_investida = false
			_investindo = true
			_tempo_investida = DURACAO_INVESTIDA
			_trilha_investida.queue_free()
			_animar("corrida", _tempo_investida, true)
		return
	var parede := move_and_collide(_direcao_investida * velocidade_investida * delta)
	var atingiu := global_position.distance_to(alvo.global_position) < ALCANCE_IMPACTO and _linha_livre_ate_alvo()
	if atingiu:
		alvo.get_parent().receber_dano(true)
	if parede or atingiu or _tempo_investida <= 0.0:
		_investindo = false
		_tempo_contato = recarga_contato
		_atordoamento = 0.34
		_animar("retomada", _atordoamento, true)
		_recalcular = 0.0


func _atacar_por_contato(delta: float) -> void:
	if not _preparando_investida and not _investindo and _tempo_finta <= 0.0:
		super._atacar_por_contato(delta)


func _atualizar_animacao(movimento: Vector2) -> void:
	if not _preparando_investida and not _investindo and _tempo_finta <= 0.0:
		super._atualizar_animacao(movimento)


func atordoar(tempo: float) -> void:
	_interromper_investida()
	super.atordoar(tempo)


func _derrotar() -> void:
	_interromper_investida()
	super._derrotar()


func _interromper_investida() -> void:
	_preparando_investida = false
	_investindo = false
	_tempo_finta = 0.0
	if is_instance_valid(_trilha_investida):
		_trilha_investida.queue_free()


func _ajustar_raio_contato(raio: float) -> void:
	var alcance: CollisionShape2D = $Contato/Alcance
	var forma := CircleShape2D.new()
	forma.radius = raio
	alcance.shape = forma
	distancia_contato = raio + 5.0


func _aviso_preparacao() -> void:
	if distancia_contato < 28.0:
		return
	var contorno := Line2D.new()
	contorno.width = 2.0
	contorno.closed = true
	contorno.default_color = Color(1.0, 0.62, 0.32, 0.42)
	contorno.z_index = 1
	for i in 20:
		contorno.add_point((Vector2.RIGHT.rotated(TAU * i / 20.0) * distancia_contato).round())
	add_child(contorno)
	AudioManager.tocar(&"ataque_inimigo", global_position)
	var aviso := contorno.create_tween()
	aviso.tween_property(contorno, "default_color:a", 0.84, preparacao_contato)
	aviso.tween_callback(contorno.queue_free)


# Ponto para onde o inimigo caminha. Subclasses podem flanquear em vez de ir direto.
func _destino_perseguicao(_distancia: float) -> Vector2:
	return alvo.global_position

func _flanquear(largura: float) -> Vector2:
	var sentido := global_position.direction_to(alvo.global_position)
	var lado := 1.0 if get_instance_id() % 2 == 0 else -1.0
	var desvio := sentido.orthogonal() * lado * largura
	var aliados := get_tree().get_nodes_in_group(&"inimigos")
	var melhor := alvo.global_position
	var melhor_pressao := INF
	for variante: Vector2 in [desvio, -desvio]:
		var ponto := alvo.global_position + variante
		var celula := Vector2i((ponto / caminhos.cell_size).floor())
		if not caminhos.region.has_point(celula) or caminhos.is_point_solid(celula):
			continue
		var pressao := 0.0
		for aliado in aliados:
			if aliado != self and aliado.get_parent() == get_parent():
				pressao += maxf(0.0, 55.0 - ponto.distance_to(aliado.global_position))
		if pressao < melhor_pressao:
			melhor_pressao = pressao
			melhor = ponto
	return melhor


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
