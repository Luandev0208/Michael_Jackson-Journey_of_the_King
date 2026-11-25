extends "res://Scripts/inimigo_perseguidor.gd"

const FIGURINOS := {
	"comum": preload("res://Assets/SmoothCriminal/Inimigos/CapangaComum/spriteframes.tres"),
	"agil": preload("res://Assets/SmoothCriminal/Inimigos/CapangaAgil/spriteframes.tres"),
	"seguranca": preload("res://Assets/SmoothCriminal/Inimigos/Seguranca/spriteframes.tres"),
}

var _tipo := "comum"


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
