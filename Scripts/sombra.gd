extends "res://Scripts/inimigo_perseguidor.gd"

enum Tipo { COMUM, VELOZ, GUARDIAO }

const ANIMACAO_FPS := 6.0

var _tipo := Tipo.COMUM
var _direcao := 0
var _quadro := 0.0

@onready var _arte: Sprite2D = $Visual


func configurar(tipo: Tipo, obrigatoria: bool) -> void:
	_tipo = tipo
	match tipo:
		Tipo.VELOZ:
			vida = 1
			velocidade_perseguicao = 66.0
		Tipo.GUARDIAO:
			vida = 4
			velocidade_perseguicao = 48.0
			preparacao_contato = 0.42
			recarga_contato = 1.25
	if obrigatoria:
		# Uma sombra de encontro pode seguir Michael pela rua, inclusive se ele recuar.
		set_meta("obrigatorio", true)
		raio_deteccao = 2600.0
		raio_abandono = 2700.0
		_alcance_posto = 2700.0


func _ready() -> void:
	super._ready()
	_arte.frame_coords = Vector2i(0, int(_tipo) * 4)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var movimento := get_position_delta()
	if ia_ativa and movimento.length_squared() > 0.01:
		if absf(movimento.x) > absf(movimento.y):
			_direcao = 2 if movimento.x < 0.0 else 3
		else:
			_direcao = 1 if movimento.y < 0.0 else 0
		_quadro = fposmod(_quadro + delta * ANIMACAO_FPS, 4.0)
	else:
		_quadro = 0.0
	_arte.frame_coords = Vector2i(int(_quadro), int(_tipo) * 4 + _direcao)
