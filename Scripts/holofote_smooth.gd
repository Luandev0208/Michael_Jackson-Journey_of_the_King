extends Node2D

const LIGADO := preload("res://Assets/SmoothCriminal/Holofotes/ligado.png")
const APAGADO := preload("res://Assets/SmoothCriminal/Holofotes/apagado.png")
const ALERTA := preload("res://Assets/SmoothCriminal/Holofotes/alerta.png")
const DOURADO := preload("res://Assets/SmoothCriminal/Holofotes/cone_dourado.png")
const AZUL := preload("res://Assets/SmoothCriminal/Holofotes/cone_azul.png")
const VERMELHO := preload("res://Assets/SmoothCriminal/Holofotes/cone_alerta.png")

const PIVO := Vector2(64, 8)
const LENTE := Vector2(0, -47)
const PROFUNDIDADE := 176.0
const SEMILARGURA := 57.0
const RAIOS := 24
const TEMPO_DETECCAO := 0.40

@export var direcao_graus := 0.0
@export var oscilacao_graus := 0.0
@export var comeca_ligado := true
@export var azul := false

var acumulo := 0.0
var ativo := false
var _tempo := 0.0
var _tempo_cone := 0.0
var _angulo := 0.0
var _cone := Polygon2D.new()
var _corpo := Sprite2D.new()


func _ready() -> void:
	_cone.position = LENTE
	add_child(_cone)
	_corpo.centered = false
	_corpo.position = Vector2(-32, -62)
	_corpo.z_index = 1
	add_child(_corpo)
	ligar(comeca_ligado)


func ligar(ligado: bool) -> void:
	ativo = ligado
	acumulo = 0.0
	_tempo_cone = 0.0
	_cone.visible = false
	_atualizar_arte()


func observar(pes: Vector2, delta: float) -> float:
	if not ativo:
		return 0.0

	_tempo += delta
	_angulo = deg_to_rad(direcao_graus + sin(_tempo * 1.15) * oscilacao_graus)
	var deslocamento := (pes - to_global(LENTE)).rotated(-_angulo)
	var dentro := deslocamento.y > 0.0 and deslocamento.y < PROFUNDIDADE
	dentro = dentro and absf(deslocamento.x) < 3.0 + deslocamento.y * SEMILARGURA / PROFUNDIDADE
	var visivel := dentro and _obstaculo(pes).is_empty()
	acumulo = move_toward(acumulo, 1.0 if visivel else 0.0, delta / (TEMPO_DETECCAO if visivel else 0.22))
	_atualizar_arte()

	_tempo_cone -= delta
	if _tempo_cone <= 0.0:
		_tempo_cone = 0.055
		_recortar_cone()
	return acumulo


func _atualizar_arte() -> void:
	var em_alerta := acumulo >= 1.0
	_corpo.texture = (ALERTA if em_alerta else LIGADO) if ativo else APAGADO
	_cone.texture = VERMELHO if em_alerta else (AZUL if azul else DOURADO)


func _obstaculo(destino: Vector2) -> Dictionary:
	var raio := PhysicsRayQueryParameters2D.create(to_global(LENTE), destino, 1)
	raio.hit_from_inside = true
	return get_world_2d().direct_space_state.intersect_ray(raio)


func _recortar_cone() -> void:
	var vertices := PackedVector2Array([Vector2.ZERO])
	var coordenadas := PackedVector2Array([PIVO])
	for i in range(RAIOS + 1):
		var borda := Vector2(lerpf(-SEMILARGURA, SEMILARGURA, float(i) / RAIOS), PROFUNDIDADE)
		var ponta := to_global(LENTE + borda.rotated(_angulo))
		var impacto := _obstaculo(ponta)
		if not impacto.is_empty():
			ponta = impacto.position
		var local := to_local(ponta) - LENTE
		vertices.append(local)
		coordenadas.append(PIVO + local.rotated(-_angulo))
	_cone.polygon = vertices
	_cone.uv = coordenadas
	_cone.visible = true
