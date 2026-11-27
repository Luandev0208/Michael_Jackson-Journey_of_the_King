extends "res://Scripts/inimigo_perseguidor.gd"

const FIGURINOS := {
	"comum": preload("res://Assets/SmoothCriminal/Inimigos/CapangaComum/spriteframes.tres"),
	"agil": preload("res://Assets/SmoothCriminal/Inimigos/CapangaAgil/spriteframes.tres"),
	"seguranca": preload("res://Assets/SmoothCriminal/Inimigos/Seguranca/spriteframes.tres"),
}

var _tipo := "comum"
var _repeticao := 0
var _ultima_pressao := -100
var _guarda_ate := -1
var _proxima_guarda := -1
var _segundo_golpe := false


func configurar(tipo: String) -> void:
	_tipo = tipo
	velocidade_perseguicao = 84.0
	raio_deteccao = 170.0
	raio_abandono = 245.0
	_alcance_posto = 272.0
	$Visual.sprite_frames = FIGURINOS[tipo]
	match tipo:
		"agil":
			vida = 2
			multiplicador_chapeu = 1.0
			velocidade_perseguicao = 102.0
			preparacao_contato = 0.32
			recarga_contato = 1.25
			velocidade_investida = 218.0
			varia_investida = true
		"seguranca":
			vida = 5
			velocidade_perseguicao = 70.0
			preparacao_contato = 0.56
			recarga_contato = 1.35
			_ajustar_raio_contato(24.0)
			resistencia_empurrao = 0.28
			armadura_contra_chapeu = true
		_:
			vida = 3
			preparacao_contato = 0.34


func _destino_perseguicao(distancia: float) -> Vector2:
	if _tipo == "seguranca" or distancia <= 58.0:
		return alvo.global_position
	return _flanquear(48.0 if _tipo == "agil" else 30.0)


func ouvir_alarme(origem: Vector2) -> void:
	if vida <= 0 or _posto.distance_to(origem) > _alcance_posto:
		return
	if global_position.distance_to(origem) <= raio_abandono:
		perseguindo = true
		_recalcular = 0.0


func empurrar(impulso: Vector2) -> void:
	super.empurrar(impulso * resistencia_empurrao)


func _recarga_depois_do_golpe() -> float:
	if _tipo == "comum":
		_segundo_golpe = not _segundo_golpe
		return 0.46 if _segundo_golpe else 1.2
	return super._recarga_depois_do_golpe()


func receber_dano(dano: int, impulso := Vector2.ZERO, fonte := &"chute") -> void:
	var quadro := Engine.get_physics_frames()
	# O segurança só guarda ataques comuns de frente. Costas, chapéu e giro
	# continuam disponíveis, e o intervalo impede defesa consecutiva infinita.
	if _tipo == "seguranca" and fonte == &"chute" and is_instance_valid(alvo) and dano == 1:
		var sentido := global_position.direction_to(alvo.global_position)
		var frente := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}
		if sentido.dot(frente.get(_direcao_visual, Vector2.DOWN)) > 0.4:
			if quadro < _guarda_ate:
				return
			_repeticao = _repeticao + 1 if quadro - _ultima_pressao <= 44 else 1
			_ultima_pressao = quadro
			if _repeticao >= 2 and quadro >= _proxima_guarda:
				_guarda_ate = quadro + 22
				_proxima_guarda = quadro + 135
				_repeticao = 0
				_animar("prepare", 0.37, true)
				_aviso_preparacao()
				return
	super.receber_dano(dano, impulso, fonte)
