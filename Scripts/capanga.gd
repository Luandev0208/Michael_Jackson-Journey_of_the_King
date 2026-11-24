extends "res://Scripts/inimigo_perseguidor.gd"

const FIGURINOS := {
	"comum": preload("res://Assets/SmoothCriminal/Inimigos/CapangaComum/spriteframes.tres"),
	"agil": preload("res://Assets/SmoothCriminal/Inimigos/CapangaAgil/spriteframes.tres"),
	"seguranca": preload("res://Assets/SmoothCriminal/Inimigos/Seguranca/spriteframes.tres"),
}

func configurar(tipo: String) -> void:
	$Visual.sprite_frames = FIGURINOS[tipo]
	match tipo:
		"agil":
			vida = 1
			multiplicador_chapeu = 1.0
			velocidade_perseguicao = 89.0
			preparacao_contato = 0.36
			recarga_contato = 1.25
		"seguranca":
			vida = 4
			velocidade_perseguicao = 56.0
			preparacao_contato = 0.48
			recarga_contato = 1.35
			resistencia_empurrao = 0.28
			armadura_contra_chapeu = true


func ouvir_alarme(origem: Vector2) -> void:
	if vida <= 0 or _posto.distance_to(origem) > _alcance_posto:
		return
	if global_position.distance_to(origem) <= raio_abandono:
		perseguindo = true
		_recalcular = 0.0


func empurrar(impulso: Vector2) -> void:
	super.empurrar(impulso * resistencia_empurrao)
