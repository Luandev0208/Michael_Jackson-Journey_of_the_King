extends "res://Scripts/capanga.gd"

signal vida_alterada(restante: int)
signal etapa_alterada(etapa: int)

enum Estado { BUSCA, AVISO, INVESTIDA, RECUPERACAO }

const ARTE := preload("res://Assets/SmoothCriminal/Inimigos/Chefe/spriteframes.tres")
const VIDA_MAXIMA := 14
const VELOCIDADE_INVESTIDA := 310.0
const ALCANCE_INVESTIDA := 106.0
const ALCANCE_GOLPE := 38.0

var etapa := 1
var em_combate := false
var _estado := Estado.BUSCA
var _tempo := 0.0
var _direcao_golpe := Vector2.DOWN
var _distancia_restante := 0.0
var _atingiu := false
var _aviso := Line2D.new()


func _ready() -> void:
	super._ready()
	vida = VIDA_MAXIMA
	_resposta_empurrao = 0.0
	_sprite.sprite_frames = ARTE
	_aviso.z_index = 1
	_aviso.width = 5.0
	_aviso.default_color = Color(1.0, 0.63, 0.32, 0.8)
	add_child(_aviso)
	_animar("idle")


func ativar() -> void:
	em_combate = true


func receber_dano(dano: int, empurrao := Vector2.ZERO, fonte := &"chute") -> void:
	if not em_combate or vida <= 0:
		return
	super.receber_dano(dano, empurrao, fonte)
	vida_alterada.emit(maxi(vida, 0))
	if vida <= 0:
		_aviso.clear_points()
		return
	var nova_etapa := 3 if vida <= 4 else (2 if vida <= 9 else 1)
	if nova_etapa != etapa:
		etapa = nova_etapa
		_recuperar(0.8)
		etapa_alterada.emit(etapa)


func _mover(delta: float) -> void:
	if not em_combate:
		return
	_tempo -= delta
	match _estado:
		Estado.BUSCA:
			var distancia := global_position.distance_to(alvo.global_position)
			var alcance := 29.0 if etapa < 3 else 94.0
			if distancia <= alcance and _caminho_livre(alvo.global_position):
				_preparar_golpe()
			else:
				_seguir(alvo.global_position, 73.0 if etapa < 3 else 97.0, delta)
		Estado.AVISO:
			if _tempo <= 0.0:
				_aviso.clear_points()
				if etapa < 3:
					_acertar_se_proximo(ALCANCE_GOLPE, 0.42)
					_recuperar(0.76, "attack")
				else:
					_estado = Estado.INVESTIDA
					_distancia_restante = ALCANCE_INVESTIDA
					_atingiu = false
					_animar("special", ALCANCE_INVESTIDA / VELOCIDADE_INVESTIDA, true)
		Estado.INVESTIDA:
			var passo := minf(VELOCIDADE_INVESTIDA * delta, _distancia_restante)
			_distancia_restante -= passo
			var colisao := move_and_collide(_direcao_golpe * passo)
			if not _atingiu:
				_atingiu = _acertar_se_proximo(25.0, -1.0)
			if colisao or _distancia_restante <= 0.0:
				_recuperar(0.86)
		Estado.RECUPERACAO:
			if _tempo <= 0.0:
				_estado = Estado.BUSCA
				_recalcular = 0.0


func _preparar_golpe() -> void:
	_estado = Estado.AVISO
	_tempo = 0.53 if etapa < 3 else 0.46
	_direcao_golpe = global_position.direction_to(alvo.global_position)
	_olhar_para(_direcao_golpe)
	_animar("prepare" if etapa < 3 else "threat", _tempo, true)
	var comprimento := ALCANCE_GOLPE if etapa < 3 else ALCANCE_INVESTIDA
	var origem := global_position
	var parede := _raio(origem + _direcao_golpe * comprimento)
	var ponta := _direcao_golpe * comprimento if parede.is_empty() else to_local(parede.position)
	_aviso.points = PackedVector2Array([Vector2.ZERO, ponta])


func _recuperar(duracao: float, animacao := "recover") -> void:
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


func _atualizar_animacao(movimento: Vector2) -> void:
	if _estado == Estado.BUSCA:
		super._atualizar_animacao(movimento)
	elif _tempo_impacto <= 0.0 and String(_sprite.animation).begins_with("hurt_"):
		match _estado:
			Estado.AVISO:
				_animar("prepare" if etapa < 3 else "threat", maxf(_tempo, 0.01), true)
			Estado.INVESTIDA:
				_animar("special", maxf(_distancia_restante / VELOCIDADE_INVESTIDA, 0.01), true)
			Estado.RECUPERACAO:
				_animar("recover", maxf(_tempo, 0.01), true)
