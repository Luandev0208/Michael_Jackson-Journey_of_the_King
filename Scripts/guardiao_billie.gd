extends "res://Scripts/detetive.gd"

signal vida_alterada(restante: int)
signal postura_alterada(mensagem: String)

enum Estado { POSICIONAR, AVISO, INTERVALO, ABERTURA }

const NOME := "Guardião do Espelho — Billie Jean"
const VIDA_MAXIMA := 9
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


func _ready() -> void:
	configurar(Tipo.ESPECIAL, true)
	vida = VIDA_MAXIMA
	resistencia_empurrao = 0.0
	super._ready()
	_sprite.self_modulate = Color(1.0, 0.89, 0.64)
	_cone.z_index = 1
	_cone.hide()
	add_child(_cone)
	var dono := alvo.get_parent() as MichaelJogador
	dono.esquiva_perfeita.connect(_ao_esquivar)


func _mover(delta: float) -> void:
	velocity = Vector2.ZERO
	aviso_restante -= delta
	match estado:
		Estado.POSICIONAR:
			if aviso_restante <= 0.0 and global_position.distance_to(alvo.global_position) <= 83.0 and _linha_livre_ate_alvo() and _reservar_inicio_ataque():
				_flashes = 2 if vida <= 4 else 1
				_esquiva = false
				_preparar_flash(0.78)
			else:
				_seguir(alvo.global_position, 69.0, delta)
		Estado.AVISO:
			_cone.color.a = 0.43 if aviso_restante < 0.17 else 0.22
			if aviso_restante <= 0.0:
				_disparar_flash()
		Estado.INTERVALO:
			if aviso_restante <= 0.0 and _reservar_inicio_ataque():
				_preparar_flash(0.59)
		Estado.ABERTURA:
			if aviso_restante <= 0.0:
				estado = Estado.POSICIONAR
				aviso_restante = 0.52
				postura_alterada.emit("Aguarde o próximo flash")


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
	_cone.hide()
	_animar("attack", 0.0, true)
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
	estado = Estado.ABERTURA
	aviso_restante = 2.02 if _esquiva else 1.56
	_animar("idle", aviso_restante, true)
	postura_alterada.emit("Câmera recarregando · contra-ataque")


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
	if antes > 4 and vida > 0 and vida <= 4:
		AudioManager.tocar(&"chefe_etapa", global_position)
		postura_alterada.emit("A câmera se arma para disparos duplos")


func atordoar(_tempo: float) -> void:
	pass


func _atacar_por_contato(_delta: float) -> void:
	pass


func _atualizar_animacao(movimento: Vector2) -> void:
	if estado == Estado.POSICIONAR:
		super._atualizar_animacao(movimento)
