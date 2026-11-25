class_name Inimigo
extends CharacterBody2D

signal derrotado

@export var distancia_patrulha := 28.0
@export var velocidade_patrulha := 25.0
@export var preparacao_contato := 0.0
@export var recarga_contato := 0.75
# Resistências por tipo de golpe. O chapéu atinge de longe, mas rende menos que o chute.
@export var multiplicador_chapeu := 0.67
@export var resistencia_empurrao := 1.0
# Com armadura, o inimigo não tem o ataque interrompido pelo chapéu (só pelo chute).
@export var armadura_contra_chapeu := false

# Evita que vários inimigos comecem o ataque ao mesmo tempo: dá tempo de reagir a cada um.
const INTERVALO_ENTRE_ATAQUES := 0.40
static var _proximo_quadro_de_ataque := 0

var vida := 2
var ia_ativa := true
var atraso_aparicao := 0.0
var _origem := 0.0
var _lado := 1.0
var _empurrao := Vector2.ZERO
var _tempo_impacto := 0.0
var _tempo_contato := 0.0
var _preparacao_restante := -1.0
var _direcao_visual := "down"
var _animando_ataque := false
var _dano_fracionado := 0.0
var _atordoamento := 0.0

@onready var visual: Node2D = $Visual
@onready var contato: Area2D = $Contato
@onready var _sprite := visual as AnimatedSprite2D

func _ready() -> void:
	_origem = global_position.x

func _physics_process(delta: float) -> void:
	if vida <= 0:
		return

	_tempo_contato = maxf(0.0, _tempo_contato - delta)
	_atordoamento = maxf(0.0, _atordoamento - delta)
	_tempo_impacto = maxf(0.0, _tempo_impacto - delta)
	visual.modulate = Color(1.0, 0.35, 0.35) if _tempo_impacto > 0.0 else Color.WHITE
	if atraso_aparicao > 0.0:
		atraso_aparicao = maxf(0.0, atraso_aparicao - delta)
		visual.modulate.a = clampf(1.0 - atraso_aparicao, 0.3, 1.0)
		return
	var posicao_anterior := global_position
	if not _empurrao.is_zero_approx():
		velocity = _empurrao
		_empurrao = _empurrao.move_toward(Vector2.ZERO, 680.0 * delta)
		move_and_slide()
	elif _atordoamento > 0.0:
		velocity = Vector2.ZERO
	elif ia_ativa:
		_mover(delta)
	else:
		velocity = Vector2.ZERO

	if ia_ativa and _tempo_contato <= 0.0 and _atordoamento <= 0.0:
		_atacar_por_contato(delta)
	else:
		_preparacao_restante = -1.0
	_atualizar_animacao(global_position - posicao_anterior)

func _atacar_por_contato(delta: float) -> void:
	for jogador in contato.get_overlapping_bodies():
		if not jogador.has_method("receber_dano"):
			continue
		var colisor: Node2D = jogador.get_node("Michael_Colisor")
		var raio := PhysicsRayQueryParameters2D.create(global_position, colisor.global_position, 1)
		raio.hit_from_inside = true
		if not get_world_2d().direct_space_state.intersect_ray(raio).is_empty():
			continue
		var iniciando := _preparacao_restante < 0.0
		if iniciando:
			if not _reservar_inicio_ataque():
				return
			_preparacao_restante = preparacao_contato
			_animando_ataque = false
		_preparacao_restante -= delta
		_olhar_para(colisor.global_position - global_position)
		if iniciando and _preparacao_restante > 0.0:
			_aviso_preparacao()
		if _preparacao_restante > 0.0:
			visual.modulate = Color(1.0, 0.71, 0.47)
			_animar("prepare", _preparacao_restante + delta, iniciando)
			return
		_tempo_contato = recarga_contato
		_preparacao_restante = -1.0
		_animando_ataque = _animar("attack", 0.0, true)
		_efeito_ataque()
		AudioManager.tocar(&"ataque_inimigo", global_position)
		jogador.receber_dano(true)
		return
	_preparacao_restante = -1.0

func _reservar_inicio_ataque() -> bool:
	var quadro := Engine.get_physics_frames()
	if quadro < _proximo_quadro_de_ataque:
		return false
	_proximo_quadro_de_ataque = quadro + ceili(INTERVALO_ENTRE_ATAQUES * Engine.physics_ticks_per_second)
	return true

func _mover(_delta: float) -> void:
	if (global_position.x - _origem) * _lado >= distancia_patrulha:
		_lado *= -1
	velocity = Vector2(_lado * velocidade_patrulha, 0)
	if move_and_slide():
		_lado *= -1

func _olhar_para(direcao: Vector2) -> void:
	if direcao.is_zero_approx():
		return
	if absf(direcao.x) > absf(direcao.y):
		_direcao_visual = "left" if direcao.x < 0.0 else "right"
	else:
		_direcao_visual = "up" if direcao.y < 0.0 else "down"

func _animar(estado: String, duracao := 0.0, reiniciar := false) -> bool:
	if _sprite == null:
		return false
	var nome := StringName(estado if estado == "death" else estado + "_" + _direcao_visual)
	if not _sprite.sprite_frames.has_animation(nome):
		return false
	if reiniciar:
		_sprite.stop()
	elif _sprite.animation == nome:
		return true
	var velocidade := 1.0
	if duracao > 0.0:
		var quadros := _sprite.sprite_frames
		velocidade = quadros.get_frame_count(nome) / (quadros.get_animation_speed(nome) * duracao)
	_sprite.play(nome, velocidade)
	return true

func _atualizar_animacao(movimento: Vector2) -> void:
	if _sprite == null or _tempo_impacto > 0.0 or _preparacao_restante > 0.0:
		return
	if _animando_ataque and _sprite.is_playing():
		return
	_animando_ataque = false
	var andando := movimento.length_squared() > 0.01
	if andando:
		_olhar_para(movimento)
	_animar("walk" if andando else "idle")

func _efeito_ataque() -> void:
	pass

# Gancho para o aviso visual do início do ataque (usado pelos inimigos especiais).
func _aviso_preparacao() -> void:
	pass

# Respiro depois de um golpe forte: o inimigo fica atordoado e sem atacar.
func atordoar(tempo: float) -> void:
	if vida > 0:
		_atordoamento = maxf(_atordoamento, tempo)
		_preparacao_restante = -1.0
		_tempo_contato = maxf(_tempo_contato, tempo)

func empurrar(impulso: Vector2) -> void:
	if vida > 0:
		_empurrao = impulso

func receber_dano(dano: int, empurrao := Vector2.ZERO, fonte := &"chute") -> void:
	if vida <= 0:
		return
	var do_chapeu := fonte == &"chapeu"
	if do_chapeu:
		# O chapéu rende menos: o dano fracionado acumula até virar pontos de vida.
		_dano_fracionado += float(dano) * multiplicador_chapeu
		dano = int(_dano_fracionado)
		_dano_fracionado -= float(dano)
	var golpe_final := empurrao.length() > 190.0
	empurrao *= resistencia_empurrao
	vida -= dano
	var interrompe := not (do_chapeu and armadura_contra_chapeu)
	if interrompe:
		_empurrao = empurrao
		_preparacao_restante = -1.0
		_tempo_contato = maxf(_tempo_contato, 0.18)
	_tempo_impacto = 0.18
	_mostrar_impacto()
	if vida <= 0:
		_derrotar()
	else:
		if interrompe and not do_chapeu:
			# O chute quebra o ritmo do inimigo; o golpe final dá mais respiro.
			atordoar(0.55 if golpe_final else 0.30)
		if interrompe or (_preparacao_restante < 0.0 and not _animando_ataque):
			_animando_ataque = false
			_olhar_para(-empurrao)
			_animar("hurt", _tempo_impacto, true)

func _derrotar() -> void:
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	contato.set_deferred("monitoring", false)
	remove_from_group("inimigos")
	visual.modulate = Color.WHITE
	_efeito_derrota()
	var duracao := 0.0
	if _animar("death", 0.0, true):
		duracao = _duracao_animacao(&"death")
	# O corpo fica visível até o fim da animação, dissolve e só então sai da cena.
	# O tempo é calculado aqui e não depende do sinal da animação.
	var saida := create_tween()
	saida.tween_interval(duracao + 0.25)
	saida.tween_property(visual, "modulate:a", 0.0, 0.40)
	saida.tween_callback(queue_free)
	# Barreiras, vagas de spawn e recompensas contam a derrota no golpe final.
	derrotado.emit()

func _duracao_animacao(nome: StringName) -> float:
	var quadros := _sprite.sprite_frames
	var total := 0.0
	for indice in quadros.get_frame_count(nome):
		total += quadros.get_frame_duration(nome, indice)
	return total / maxf(quadros.get_animation_speed(nome), 0.01)

func _efeito_derrota() -> void:
	# Clarão no golpe final, anel de impacto e fagulhas: o jogador percebe a vitória na hora.
	visual.modulate = Color(2.4, 2.4, 2.4)
	create_tween().tween_property(visual, "modulate", Color.WHITE, 0.16)
	var cena := get_parent()
	if cena == null:
		return
	var centro := global_position + Vector2(0.0, -18.0)
	var anel := Line2D.new()
	anel.width = 2.0
	anel.default_color = Color(1.0, 0.94, 0.75, 0.95)
	anel.z_index = 4
	for i in range(17):
		anel.add_point(Vector2.from_angle(TAU * float(i) / 16.0) * 8.0)
	cena.add_child(anel)
	anel.global_position = centro
	var expansao := anel.create_tween().set_parallel()
	expansao.tween_property(anel, "scale", Vector2(3.2, 3.2), 0.30)
	expansao.tween_property(anel, "modulate:a", 0.0, 0.30)
	expansao.chain().tween_callback(anel.queue_free)
	for i in range(6):
		var faisca := Polygon2D.new()
		faisca.polygon = PackedVector2Array([Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 1.5), Vector2(-1.5, 1.5)])
		faisca.color = Color(1.0, 0.92, 0.65) if i % 2 == 0 else Color(0.75, 0.55, 1.0)
		faisca.z_index = 4
		cena.add_child(faisca)
		faisca.global_position = centro
		var sentido := Vector2.from_angle(TAU * (float(i) + 0.5) / 6.0)
		var voo := faisca.create_tween().set_parallel()
		voo.tween_property(faisca, "global_position", centro + sentido * randf_range(16.0, 28.0), 0.34)
		voo.tween_property(faisca, "modulate:a", 0.0, 0.34)
		voo.chain().tween_callback(faisca.queue_free)


func _mostrar_impacto() -> void:
	AudioManager.tocar(&"impacto", global_position)
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
