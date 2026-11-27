extends "res://Scripts/detetive.gd"

signal vida_alterada(restante: int)
signal postura_alterada(mensagem: String)

enum Estado { POSICIONAR, AVISO, INTERVALO, ABERTURA, FINTA, AVISO_CORRIDA, CORRIDA }

const NOME := "Guardião do Espelho — Billie Jean"
const VIDA_MAXIMA := 15
const LIMITE_DUPLO := 8
const COMPRIMENTO_CORRIDA := 104.0
const VELOCIDADE_CORRIDA := 239.0
const ALCANCE_FLASH := 92.0
const ARCO := 48.0
const COS_ARCO := cos(deg_to_rad(ARCO))

var estado := Estado.POSICIONAR
var aviso_restante := 0.46
var _direcao_flash := Vector2.DOWN
var _flashes := 0
var _esquiva := false
var _durante_flash := false
var _cone := Polygon2D.new()
var _rota_corrida := Line2D.new()
var _ciclo := 0
var _lado_finta := 1.0
var _corrida_restante := 0.0
var _atingiu_corrida := false


func _ready() -> void:
	configurar(Tipo.ESPECIAL, true)
	vida = VIDA_MAXIMA
	resistencia_empurrao = 0.0
	super._ready()
	_sprite.self_modulate = Color(1.0, 0.89, 0.64)
	_cone.z_index = 1
	_cone.hide()
	add_child(_cone)
	_rota_corrida.width = 27.0
	_rota_corrida.default_color = Color(1.0, 0.52, 0.27, 0.55)
	_rota_corrida.z_index = 2
	add_child(_rota_corrida)
	var dono := alvo.get_parent() as MichaelJogador
	dono.esquiva_perfeita.connect(_ao_esquivar)


func _mover(delta: float) -> void:
	velocity = Vector2.ZERO
	aviso_restante -= delta
	match estado:
		Estado.POSICIONAR:
			var distancia := global_position.distance_to(alvo.global_position)
			if aviso_restante <= 0.0 and distancia <= 87.0 and _linha_livre_ate_alvo() and _reservar_inicio_ataque():
				_ciclo += 1
				_flashes = 2 if vida <= LIMITE_DUPLO else 1
				_esquiva = false
				if _ciclo % 3 == 2:
					estado = Estado.FINTA
					aviso_restante = 0.34
					_direcao_flash = global_position.direction_to(alvo.global_position)
					_lado_finta *= -1
					postura_alterada.emit("Finta lateral · espere a faixa")
					_animar("walk", aviso_restante, true)
				else:
					_preparar_flash(0.82)
			else:
				_seguir(alvo.global_position, 69.0, delta)
		Estado.AVISO:
			_cone.color.a = 0.43 if aviso_restante < 0.17 else 0.22
			if aviso_restante <= 0.0:
				_disparar_flash()
		Estado.INTERVALO:
			if aviso_restante <= 0.0 and _reservar_inicio_ataque():
				_preparar_flash(0.59)
		Estado.FINTA:
			move_and_collide(_direcao_flash.orthogonal() * _lado_finta * 82.0 * delta)
			if aviso_restante <= 0.0:
				_preparar_corrida()
		Estado.AVISO_CORRIDA:
			if aviso_restante <= 0.0:
				_rota_corrida.clear_points()
				estado = Estado.CORRIDA
				_corrida_restante = COMPRIMENTO_CORRIDA
				_atingiu_corrida = false
				_animar("attack", 0.44, true)
				AudioManager.tocar(&"chefe_investida", global_position)
		Estado.CORRIDA:
			_correr(delta)
		Estado.ABERTURA:
			if aviso_restante <= 0.0:
				estado = Estado.POSICIONAR
				aviso_restante = 0.57
				postura_alterada.emit("O guardião fechou a guarda")


func _preparar_flash(duracao: float) -> void:
	estado = Estado.AVISO
	aviso_restante = duracao
	_direcao_flash = global_position.direction_to(alvo.global_position)
	if _direcao_flash.is_zero_approx():
		_direcao_flash = Vector2.DOWN
	_olhar_para(_direcao_flash)
	_animar("prepare", duracao, true)
	var forma := PackedVector2Array([Vector2.ZERO])
	for i in range(13):
		var angulo := deg_to_rad(lerpf(-ARCO, ARCO, i / 12.0))
		forma.append(_direcao_flash.rotated(angulo) * ALCANCE_FLASH)
	_cone.polygon = forma
	_cone.color = Color(1.0, 0.72, 0.24, 0.22)
	_cone.show()
	AudioManager.tocar(&"chefe_aviso", global_position)
	postura_alterada.emit("Flash à vista · saia do feixe")


func _disparar_flash() -> void:
	_cone.color = Color(1.0, 0.94, 0.69, 0.46)
	create_tween().tween_property(_cone, "color:a", 0.0, 0.16)
	_animar("attack", 0.23, true)
	_efeito_ataque()
	AudioManager.tocar(&"chefe_golpe", global_position)
	var desvio := alvo.global_position - global_position
	if desvio.length() <= ALCANCE_FLASH and (_direcao_flash.dot(desvio.normalized()) >= COS_ARCO or desvio.length() < 8.0) and _linha_livre_ate_alvo():
		_durante_flash = true
		alvo.get_parent().receber_dano(true)
		_durante_flash = false
	_flashes -= 1
	if _flashes > 0:
		estado = Estado.INTERVALO
		aviso_restante = 0.30
		postura_alterada.emit("Prepare-se para outro flash")
		return
	_abrir_guarda("Câmera recarregando · contra-ataque")


func _preparar_corrida() -> void:
	estado = Estado.AVISO_CORRIDA
	aviso_restante = 0.69
	_direcao_flash = global_position.direction_to(alvo.global_position)
	if _direcao_flash.is_zero_approx():
		_direcao_flash = Vector2.DOWN
	_olhar_para(_direcao_flash)
	_animar("prepare", aviso_restante, true)
	var movimento := _direcao_flash * COMPRIMENTO_CORRIDA
	var parede := KinematicCollision2D.new()
	if test_move(global_transform, movimento, parede):
		movimento = parede.get_travel()
	_rota_corrida.points = PackedVector2Array([Vector2.ZERO, movimento])
	AudioManager.tocar(&"chefe_aviso", global_position)
	postura_alterada.emit("Investida · desvie da faixa")


func _correr(delta: float) -> void:
	var passo := minf(_corrida_restante, VELOCIDADE_CORRIDA * delta)
	var parou := move_and_collide(_direcao_flash * passo)
	_corrida_restante -= passo
	if not _atingiu_corrida and global_position.distance_to(alvo.global_position) <= 22.0 and _linha_livre_ate_alvo():
		_atingiu_corrida = true
		_durante_flash = true
		alvo.get_parent().receber_dano(true)
		_durante_flash = false
	if parou != null or _corrida_restante <= 0.0:
		if vida <= LIMITE_DUPLO:
			_flashes = 1
			estado = Estado.INTERVALO
			aviso_restante = 0.34
			postura_alterada.emit("A câmera vai disparar após a corrida")
		else:
			_abrir_guarda("O guardião perdeu o equilíbrio")


func _abrir_guarda(mensagem: String) -> void:
	estado = Estado.ABERTURA
	aviso_restante = 1.95 if _esquiva else 1.33
	var retorno := create_tween()
	retorno.tween_interval(0.19)
	retorno.tween_callback(func():
		if vida > 0 and estado == Estado.ABERTURA and _tempo_impacto <= 0.0:
			_animar("retomada", 0.35, true))
	postura_alterada.emit(mensagem)


func _ao_esquivar() -> void:
	if _durante_flash:
		_esquiva = true


func receber_dano(dano: int, _impulso := Vector2.ZERO, fonte := &"chute") -> void:
	if estado != Estado.ABERTURA or vida <= 0:
		return
	var antes := vida
	multiplicador_chapeu = 1.0
	super.receber_dano(dano, Vector2.ZERO, fonte)
	vida_alterada.emit(maxi(0, vida))
	if antes > LIMITE_DUPLO and vida > 0 and vida <= LIMITE_DUPLO:
		AudioManager.tocar(&"chefe_etapa", global_position)
		postura_alterada.emit("A câmera se arma para disparos duplos")


func atordoar(_tempo: float) -> void:
	pass


func _atacar_por_contato(_delta: float) -> void:
	pass


func _atualizar_animacao(movimento: Vector2) -> void:
	if estado == Estado.POSICIONAR:
		super._atualizar_animacao(movimento)
