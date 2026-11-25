extends "res://Scripts/capanga.gd"

signal vida_alterada(restante: int)
signal etapa_alterada(etapa: int)

enum Estado { BUSCA, AVISO, INVESTIDA, INTERVALO, RECUPERACAO }

const ARTE := preload("res://Assets/SmoothCriminal/Inimigos/Chefe/spriteframes.tres")
const NOME := "Guardião do Espelho — Smooth Criminal"
const VIDA_MAXIMA := 15
const VELOCIDADE_INVESTIDA := 310.0
const ALCANCE_INVESTIDA := 126.0
const ALCANCE_GOLPE := 38.0
const RAIO_INVESTIDA := 25.0
const VELOCIDADES_BUSCA := [73.0, 84.0, 101.0]

var etapa := 1
var em_combate := false
var _estado := Estado.BUSCA
var _tempo := 0.0
var _direcao_golpe := Vector2.DOWN
var _distancia_restante := 0.0
var _atingiu := false
var _golpe_correndo := false
var _alternar_investida := true
var _encadear := false
var _primeiro_golpe_concluido := false
var _alcance_corrida := 0.0
var _velocidade_corrida := 0.0
var _aviso := Line2D.new()


func _ready() -> void:
	super._ready()
	vida = VIDA_MAXIMA
	resistencia_empurrao = 0.0
	armadura_contra_chapeu = true
	_sprite.sprite_frames = ARTE
	_aviso.z_index = 1
	_aviso.width = 5.0
	_aviso.default_color = Color(1.0, 0.63, 0.32, 0.8)
	add_child(_aviso)
	_animar("idle")


func ativar() -> void:
	em_combate = true


func receber_dano(dano: int, empurrao := Vector2.ZERO, fonte := &"chute") -> void:
	if not em_combate or vida <= 0 or not _primeiro_golpe_concluido:
		return
	if _estado != Estado.RECUPERACAO and fonte == &"chute" and dano == 1:
		return
	multiplicador_chapeu = 1.0 if _estado == Estado.RECUPERACAO else 0.45
	super.receber_dano(dano, empurrao, fonte)
	vida_alterada.emit(maxi(vida, 0))
	if vida <= 0:
		_aviso.clear_points()
		return
	var nova_etapa := 3 if vida <= 5 else (2 if vida <= 10 else 1)
	if nova_etapa != etapa:
		etapa = nova_etapa
		_primeiro_golpe_concluido = false
		_recuperar(0.8)
		AudioManager.tocar(&"chefe_etapa", global_position)
		etapa_alterada.emit(etapa)


func _mover(delta: float) -> void:
	if not em_combate:
		return
	_tempo -= delta
	match _estado:
		Estado.BUSCA:
			var distancia := global_position.distance_to(alvo.global_position)
			var investida := etapa == 3 or (etapa == 2 and _alternar_investida)
			var alcance := (94.0 if etapa == 3 else 66.0) if investida else 29.0
			if distancia <= alcance and _caminho_livre(alvo.global_position):
				_preparar_golpe(investida)
			else:
				_seguir(alvo.global_position, VELOCIDADES_BUSCA[etapa - 1], delta)
		Estado.AVISO:
			if _tempo <= 0.0:
				_aviso.clear_points()
				if _golpe_correndo:
					_estado = Estado.INVESTIDA
					AudioManager.tocar(&"chefe_investida", global_position)
					_distancia_restante = _alcance_corrida
					_atingiu = false
					_animar("special", _alcance_corrida / _velocidade_corrida, true)
				else:
					AudioManager.tocar(&"chefe_golpe", global_position)
					_acertar_se_proximo(ALCANCE_GOLPE, 0.42)
					_finalizar_golpe(1.18)
		Estado.INVESTIDA:
			var passo := minf(_velocidade_corrida * delta, _distancia_restante)
			_distancia_restante -= passo
			var colisao := move_and_collide(_direcao_golpe * passo)
			if not _atingiu:
				_atingiu = _acertar_se_proximo(RAIO_INVESTIDA, -1.0)
			if colisao or _distancia_restante <= 0.0:
				_finalizar_golpe(1.36)
		Estado.INTERVALO:
			if _tempo <= 0.0:
				_preparar_golpe(false, true)
		Estado.RECUPERACAO:
			if _tempo <= 0.0:
				_estado = Estado.BUSCA
				_recalcular = 0.0


func _preparar_golpe(investida: bool, complemento := false) -> void:
	if not _reservar_inicio_ataque():
		return
	AudioManager.tocar(&"chefe_aviso", global_position)
	if etapa == 2 and not complemento:
		_alternar_investida = not _alternar_investida
	_encadear = not complemento and investida and etapa >= 2
	_golpe_correndo = investida
	_alcance_corrida = ALCANCE_INVESTIDA if etapa == 3 else 82.0
	_velocidade_corrida = VELOCIDADE_INVESTIDA if etapa == 3 else 240.0
	_estado = Estado.AVISO
	_tempo = 0.54 if investida else (0.59 if complemento else 0.53)
	_direcao_golpe = global_position.direction_to(alvo.global_position)
	_olhar_para(_direcao_golpe)
	_animar("threat" if _golpe_correndo else "prepare", _tempo, true)
	_aviso.width = RAIO_INVESTIDA * 2.0 if _golpe_correndo else 8.0
	_aviso.default_color.a = 0.42 if _golpe_correndo else 0.8
	var comprimento := _alcance_corrida if _golpe_correndo else ALCANCE_GOLPE
	var origem := global_position
	var parede := _raio(origem + _direcao_golpe * comprimento)
	var ponta := _direcao_golpe * comprimento if parede.is_empty() else to_local(parede.position)
	_aviso.points = PackedVector2Array([Vector2.ZERO, ponta])


func _finalizar_golpe(duracao: float) -> void:
	if _encadear and global_position.distance_to(alvo.global_position) <= 73.0 and _caminho_livre(alvo.global_position):
		_estado = Estado.INTERVALO
		_tempo = 0.29
		_encadear = false
		_animar("prepare", _tempo, true)
	else:
		_primeiro_golpe_concluido = true
		_recuperar(duracao)


func _recuperar(duracao: float, animacao := "recover") -> void:
	_encadear = false
	_aviso.clear_points()
	_estado = Estado.RECUPERACAO
	_tempo = duracao
	velocity = Vector2.ZERO
	_animar(animacao, duracao, true)


func _acertar_se_proximo(alcance: float, frente: float) -> bool:
	var distancia := alvo.global_position - global_position
	if distancia.length() > alcance or _direcao_golpe.dot(distancia.normalized()) < frente:
		return false
	if not _caminho_livre(alvo.global_position):
		return false
	_efeito_ataque()
	alvo.get_parent().receber_dano(true)
	return true


func _raio(destino: Vector2) -> Dictionary:
	var raio := PhysicsRayQueryParameters2D.create(global_position, destino, 1)
	return get_world_2d().direct_space_state.intersect_ray(raio)


func _caminho_livre(destino: Vector2) -> bool:
	return _raio(destino).is_empty()


func _atacar_por_contato(_delta: float) -> void:
	pass


func atordoar(tempo: float) -> void:
	if _estado == Estado.BUSCA:
		super.atordoar(tempo * 0.45)


func _atualizar_animacao(movimento: Vector2) -> void:
	if _estado == Estado.BUSCA:
		super._atualizar_animacao(movimento)
	elif _tempo_impacto <= 0.0 and String(_sprite.animation).begins_with("hurt_"):
		match _estado:
			Estado.AVISO:
				_olhar_para(_direcao_golpe)
				_animar("threat" if _golpe_correndo else "prepare", maxf(_tempo, 0.01), true)
			Estado.INVESTIDA:
				_olhar_para(_direcao_golpe)
				_animar("special", maxf(_distancia_restante / _velocidade_corrida, 0.01), true)
			Estado.RECUPERACAO:
				_animar("recover", maxf(_tempo, 0.01), true)
