extends "res://Scripts/inimigo_perseguidor.gd"

enum Tipo { COMUM, LENTO, RAPIDO, GUARDIAO }

var _tom := Color.WHITE

func configurar_tipo(tipo: Tipo) -> void:
	match tipo:
		Tipo.GUARDIAO:
			vida = 5
			velocidade_perseguicao = 55.0
			preparacao_contato = 0.32
			recarga_contato = 1.10
			_tom = Color(1.0, 0.55, 0.86)
		Tipo.LENTO:
			vida = 3
			velocidade_patrulha = 23.0
			velocidade_perseguicao = 43.0
			_tom = Color(0.79, 0.82, 1.0)
		Tipo.RAPIDO:
			vida = 1
			velocidade_patrulha = 37.0
			velocidade_perseguicao = 68.0
			_tom = Color(1.0, 0.81, 0.73)

func marcar_obrigatorio() -> void:
	_alcance_posto = 420.0
	raio_deteccao = 318.0
	raio_abandono = 360.0
	if vida < 5:
		_tom = _tom.lerp(Color(0.89, 0.63, 1.0), 0.45)
	var marca := Polygon2D.new()
	marca.position.y = -29.0
	marca.color = Color(0.90, 0.61, 1.0)
	marca.polygon = PackedVector2Array([0, -5, 5, 0, 0, 5, -5, 0])
	add_child(marca)

func reancorar(local: Vector2) -> void:
	global_position = local
	_posto = local
	_origem = local.x
	_rota.clear()
	_recalcular = 0.0
	atraso_aparicao = 0.55

func _ready() -> void:
	super._ready()
	modulate = _tom
