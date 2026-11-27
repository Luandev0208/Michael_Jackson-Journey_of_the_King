extends "res://Scripts/inimigo_perseguidor.gd"

enum Tipo { COMUM, LENTO, RAPIDO, GUARDIAO }

const FIGURINOS := [
	preload("res://Assets/Inimigos/Thriller/ZumbiComum/spriteframes.tres"),
	preload("res://Assets/Inimigos/Thriller/ZumbiResistente/spriteframes.tres"),
	preload("res://Assets/Inimigos/Thriller/ZumbiRapido/spriteframes.tres"),
	preload("res://Assets/Inimigos/Thriller/Guardiao/spriteframes.tres"),
]

var _tipo := Tipo.COMUM

func configurar_tipo(tipo: Tipo) -> void:
	_tipo = tipo
	match tipo:
		Tipo.GUARDIAO:
			vida = 5
			velocidade_perseguicao = 55.0
			preparacao_contato = 0.32
			recarga_contato = 1.10
			armadura_contra_chapeu = true
			resistencia_empurrao = 0.5
		Tipo.LENTO:
			# Resistente: o chapéu não o interrompe e quase não o empurra. Pede chutes.
			vida = 5
			velocidade_patrulha = 23.0
			velocidade_perseguicao = 53.0
			preparacao_contato = 0.58
			recarga_contato = 1.36
			_ajustar_raio_contato(24.0)
			armadura_contra_chapeu = true
			resistencia_empurrao = 0.42
		Tipo.RAPIDO:
			vida = 2
			velocidade_patrulha = 37.0
			velocidade_perseguicao = 96.0
			preparacao_contato = 0.29
			multiplicador_chapeu = 1.0
			velocidade_investida = 211.0
			varia_investida = true
			recarga_contato = 1.05
		Tipo.COMUM:
			vida = 3
			raio_abandono = 220.0
			_alcance_posto = 250.0
			velocidade_perseguicao = 77.0
			preparacao_contato = 0.32
			recarga_contato = 0.80


func _destino_perseguicao(distancia: float) -> Vector2:
	if _tipo == Tipo.RAPIDO and distancia > 74.0:
		return _flanquear(28.0)
	return super._destino_perseguicao(distancia)

func marcar_obrigatorio() -> void:
	_alcance_posto = 420.0
	raio_deteccao = 318.0
	raio_abandono = 360.0
	var marca := Polygon2D.new()
	marca.position.y = -68.0
	marca.color = Color(0.90, 0.61, 1.0)
	marca.polygon = PackedVector2Array([0, -5, 5, 0, 0, 5, -5, 0])
	add_child(marca)
	derrotado.connect(marca.hide, CONNECT_ONE_SHOT)

func reancorar(local: Vector2) -> void:
	global_position = local
	_posto = local
	_origem = local.x
	_rota.clear()
	_recalcular = 0.0
	atraso_aparicao = 0.55

func _ready() -> void:
	_sprite.sprite_frames = FIGURINOS[_tipo]
	_sprite.play(&"idle_down")
	super._ready()
	# A ameaça ocupa o atraso de aparição que o encontro já tinha.
	if _tipo == Tipo.GUARDIAO and atraso_aparicao > 0.0 and is_instance_valid(alvo):
		_olhar_para(alvo.global_position - global_position)
		_animar("threat", atraso_aparicao)
