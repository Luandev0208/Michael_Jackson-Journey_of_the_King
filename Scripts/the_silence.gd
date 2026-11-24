extends "res://Scripts/inimigo_perseguidor.gd"

signal fase_alterada(etapa: int)
signal vida_alterada(restante: int)
signal estado_alterado(estado: Estado)

enum Estado { ESPERA, BUSCA, AVISO, IMPACTO, INVESTIDA, VULNERAVEL, TRANSICAO, DERROTA }
enum Ataque { ONDA, FENDA, INVESTIDA }

const VIDA_MAXIMA := 15
const FIGURINOS: Array[SpriteFrames] = [
	preload("res://the_silence/boss/the_silence_fase_1.tres"),
	preload("res://the_silence/boss/the_silence_fase_2.tres"),
	preload("res://the_silence/boss/the_silence_fase_3.tres"),
]
const EFEITOS := preload("res://the_silence/efeitos/the_silence_efeitos.tres")
const RAIO_ONDA := 90.0
const RAIO_FENDA := 46.0
const ALCANCE_INVESTIDA := 176.0
const VELOCIDADE_INVESTIDA := 300.0
const LARGURA_INVESTIDA := 24.0

var fase := 1
var estado := Estado.ESPERA
var _jogador: MichaelJogador
var _ataque := Ataque.ONDA
var _tempo := 0.0
var _centro := Vector2.ZERO
var _direcao := Vector2.DOWN
var _distancia_restante := 0.0
var _acertou := false
var _esquivou := false
var _aplicando_ataque := false
var _alternar := false
var _aviso: Node2D


func _ready() -> void:
	super._ready()
	vida = VIDA_MAXIMA
	multiplicador_chapeu = 1.0
	_jogador = alvo.get_parent() as MichaelJogador
	_jogador.esquiva_perfeita.connect(_ao_esquivar)
	_sprite.animation_finished.connect(_ao_fim_animacao)


func ativar() -> void:
	_buscar(0.9)


func _physics_process(delta: float) -> void:
	if estado == Estado.ESPERA or estado == Estado.DERROTA or not ia_ativa or _jogador.vida <= 0:
		return
	_tempo -= delta
	match estado:
		Estado.BUSCA:
			var distancia := global_position.distance_to(alvo.global_position)
			if _tempo <= 0.0 and distancia <= 250.0 and _reservar_inicio_ataque():
				_preparar_ataque()
			elif distancia > 42.0:
				var origem := global_position
				_seguir(alvo.global_position, 42.0 + fase * 8.0, delta)
				var movimento := global_position - origem
				_olhar_para(movimento)
				_animar("move" if movimento.length_squared() > 0.01 else "idle")
			else:
				_animar("idle")
		Estado.AVISO:
			if _tempo <= 0.0:
				_executar_ataque()
		Estado.IMPACTO:
			if _tempo <= 0.0:
				_vulneravel()
		Estado.INVESTIDA:
			_investir(delta)
		Estado.VULNERAVEL, Estado.TRANSICAO:
			if _tempo <= 0.0:
				_buscar(1.1)


func _mudar_estado(novo: Estado) -> void:
	estado = novo
	estado_alterado.emit(estado)


func _buscar(atraso: float) -> void:
	_tempo = atraso
	_recalcular = 0.0
	_animar("idle")
	_mudar_estado(Estado.BUSCA)


func _preparar_ataque() -> void:
	_esquivou = false
	_acertou = false
	_direcao = global_position.direction_to(alvo.global_position)
	if _direcao.is_zero_approx():
		_direcao = Vector2.DOWN
	_olhar_para(_direcao)
	_tempo = [0.0, 1.0, 0.9, 0.75][fase]
	match fase:
		1:
			_ataque = Ataque.ONDA
		2:
			_ataque = Ataque.FENDA
		3:
			_ataque = Ataque.FENDA if _alternar else Ataque.INVESTIDA
			_alternar = not _alternar
	_animar("prepare", _tempo, true)
	if _ataque == Ataque.INVESTIDA:
		_aviso = Polygon2D.new()
		_aviso.polygon = PackedVector2Array([
			Vector2(0, -LARGURA_INVESTIDA), Vector2(ALCANCE_INVESTIDA, -LARGURA_INVESTIDA),
			Vector2(ALCANCE_INVESTIDA, LARGURA_INVESTIDA), Vector2(0, LARGURA_INVESTIDA),
		])
		_aviso.color = Color(0.94, 0.32, 0.55, 0.55)
		_aviso.z_index = 1
		get_parent().add_child(_aviso)
		_aviso.global_position = global_position
		_aviso.global_rotation = _direcao.angle()
	else:
		_centro = global_position if _ataque == Ataque.ONDA else alvo.global_position
		_aviso = _mostrar_area(_centro, _raio(), &"aviso_circular")
	_mudar_estado(Estado.AVISO)


func _raio() -> float:
	return RAIO_ONDA if _ataque == Ataque.ONDA else RAIO_FENDA


func _executar_ataque() -> void:
	_limpar_aviso()
	_animar("attack", 0.35, true)
	if _ataque == Ataque.INVESTIDA:
		_distancia_restante = ALCANCE_INVESTIDA
		_mudar_estado(Estado.INVESTIDA)
		return
	var efeito := &"onda_silencio" if _ataque == Ataque.ONDA else &"fenda_energia"
	_mostrar_efeito(efeito, _centro, _raio())
	if alvo.global_position.distance_to(_centro) <= _raio():
		_tentar_acertar(_centro)
	_tempo = 0.35
	_mudar_estado(Estado.IMPACTO)


func _investir(delta: float) -> void:
	var passo := minf(_distancia_restante, VELOCIDADE_INVESTIDA * delta)
	_distancia_restante -= passo
	var colisao := move_and_collide(_direcao * passo)
	if not _acertou and global_position.distance_to(alvo.global_position) <= LARGURA_INVESTIDA:
		_acertou = _tentar_acertar(global_position)
	if colisao != null or _distancia_restante <= 0.0 or _esquivou:
		_vulneravel()


func _tentar_acertar(origem: Vector2) -> bool:
	if not origem.is_equal_approx(alvo.global_position):
		var raio := PhysicsRayQueryParameters2D.create(origem, alvo.global_position, 1)
		if not get_world_2d().direct_space_state.intersect_ray(raio).is_empty():
			return false
	_aplicando_ataque = true
	_jogador.receber_dano(true)
	_aplicando_ataque = false
	return true


func _ao_esquivar() -> void:
	if _aplicando_ataque:
		_esquivou = true


func _vulneravel() -> void:
	_tempo = 2.55 + (0.75 if _esquivou else 0.0)
	_animar("vulnerable", 0.0, true)
	_mudar_estado(Estado.VULNERAVEL)


func receber_dano(dano: int, _empurrao := Vector2.ZERO, fonte := &"chute") -> void:
	if estado != Estado.VULNERAVEL:
		return
	_aplicar_dano(dano, fonte)


func dev_eliminar() -> void:
	if vida > 0:
		_aplicar_dano(vida, &"chute")


func _aplicar_dano(dano: int, fonte: StringName) -> void:
	super.receber_dano(dano, Vector2.ZERO, fonte)
	vida_alterada.emit(maxi(vida, 0))
	if vida <= 0:
		return
	var nova_fase := 3 if vida <= 5 else (2 if vida <= 10 else 1)
	if nova_fase > fase:
		fase = nova_fase
		_sprite.sprite_frames = FIGURINOS[fase - 1]
		_animar("phase_change", 1.1, true)
		_tempo = 1.1
		_mudar_estado(Estado.TRANSICAO)
		fase_alterada.emit(fase)


func _ao_fim_animacao() -> void:
	if estado == Estado.VULNERAVEL and _sprite.animation.begins_with("hurt_"):
		_animar("vulnerable", 0.0, true)


func _derrotar() -> void:
	_limpar_aviso()
	_mudar_estado(Estado.DERROTA)
	super._derrotar()


func _limpar_aviso() -> void:
	if is_instance_valid(_aviso):
		_aviso.queue_free()
	_aviso = null


func _mostrar_area(centro: Vector2, raio: float, animacao: StringName) -> Node2D:
	var contorno := Line2D.new()
	contorno.width = 2.0
	contorno.default_color = Color(1.0, 0.43, 0.52, 0.88)
	contorno.z_index = 1
	for i in 33:
		contorno.add_point(Vector2.from_angle(TAU * i / 32.0) * raio)
	get_parent().add_child(contorno)
	contorno.global_position = centro
	var efeito := AnimatedSprite2D.new()
	efeito.sprite_frames = EFEITOS
	efeito.scale = Vector2.ONE * (raio / 64.0)
	contorno.add_child(efeito)
	efeito.play(animacao)
	return contorno


func _mostrar_efeito(animacao: StringName, centro: Vector2, raio: float) -> void:
	var efeito := AnimatedSprite2D.new()
	efeito.sprite_frames = EFEITOS
	efeito.z_index = 3
	efeito.scale = Vector2.ONE * (raio / 64.0)
	get_parent().add_child(efeito)
	efeito.global_position = centro
	efeito.animation_finished.connect(efeito.queue_free, CONNECT_ONE_SHOT)
	efeito.play(animacao)
