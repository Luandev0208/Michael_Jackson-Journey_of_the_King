extends Node

const Zumbi := preload("res://Scripts/zumbi.gd")
const CENA_ZUMBI := preload("res://Scenes/zumbi.tscn")
const LIMITE_VIVOS := 8
const DISTANCIA_MINIMA := 104.0
const DISTANCIA_ATIVACAO := 352.0
const DISTANCIA_REMOCAO := 450.0
const INTERVALO := 0.85

# O terceiro valor de cada célula identifica a variante do encontro.
const ENCONTROS := [
	[Vector3i(24, 55, Zumbi.Tipo.COMUM), Vector3i(20, 56, Zumbi.Tipo.COMUM), Vector3i(27, 55, Zumbi.Tipo.COMUM),
	 Vector3i(16, 55, Zumbi.Tipo.LENTO), Vector3i(31, 54, Zumbi.Tipo.COMUM)],
	[Vector3i(26, 50, Zumbi.Tipo.COMUM), Vector3i(24, 47, Zumbi.Tipo.COMUM), Vector3i(11, 47, Zumbi.Tipo.RAPIDO),
	 Vector3i(15, 49, Zumbi.Tipo.LENTO), Vector3i(34, 44, Zumbi.Tipo.COMUM), Vector3i(37, 52, Zumbi.Tipo.LENTO),
	 Vector3i(12, 41, Zumbi.Tipo.COMUM), Vector3i(24, 39, Zumbi.Tipo.RAPIDO)],
	[Vector3i(24, 29, Zumbi.Tipo.COMUM), Vector3i(17, 27, Zumbi.Tipo.LENTO), Vector3i(11, 26, Zumbi.Tipo.RAPIDO),
	 Vector3i(34, 28, Zumbi.Tipo.COMUM), Vector3i(38, 25, Zumbi.Tipo.LENTO), Vector3i(24, 24, Zumbi.Tipo.COMUM),
	 Vector3i(38, 19, Zumbi.Tipo.RAPIDO), Vector3i(11, 18, Zumbi.Tipo.COMUM), Vector3i(20, 17, Zumbi.Tipo.LENTO),
	 Vector3i(28, 16, Zumbi.Tipo.RAPIDO), Vector3i(24, 15, Zumbi.Tipo.COMUM)],
]

@export_range(0.0, 1.0, 0.01) var chance_drop_cura := 0.12

var gerados := 0
var _regioes_com_drop: Dictionary[int, bool] = {}
var setor := 0
var _pendentes: Array = ENCONTROS.duplicate(true)
var _intervalo := 0.0
var _fase: Node2D
var _camera: Camera2D
var _forma := CircleShape2D.new()

func iniciar(fase: Node2D, camera: Camera2D) -> void:
	_fase = fase
	_camera = camera
	_forma.radius = 10.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_fase) or _fase.concluida or _fase.batalhas.ativa:
		return
	var celula: Vector2i = _fase.piso.local_to_map(_fase.pes.global_position)
	if setor < 2 and celula.y <= 33:
		setor = 2
	elif setor == 0 and celula.y <= 50:
		setor = 1

	_intervalo = maxf(0.0, _intervalo - delta)
	if _intervalo > 0.0:
		return
	var vivos := get_tree().get_nodes_in_group("inimigos")
	# As regiões mais recentes têm prioridade. Posições inseguras ficam pendentes.
	for regiao in range(setor, -1, -1):
		for encontro: Vector3i in _pendentes[regiao]:
			var local := Vector2i(encontro.x, encontro.y)
			if not _local_seguro(local, DISTANCIA_ATIVACAO):
				continue
			if vivos.size() >= LIMITE_VIVOS:
				_liberar_vaga(vivos)
				return
			var zumbi := _criar_zumbi(local, encontro.z, regiao)
			if encontro.z == Zumbi.Tipo.COMUM:
				zumbi.derrotado.connect(_sortear_cura.bind(zumbi, regiao), CONNECT_ONE_SHOT)
			_pendentes[regiao].erase(encontro)
			gerados += 1
			_intervalo = INTERVALO
			return

func _sortear_cura(zumbi: Inimigo, regiao: int) -> void:
	if _regioes_com_drop.has(regiao) or randf() >= chance_drop_cura:
		return
	if _fase.adicionar_cura(zumbi.global_position):
		_regioes_com_drop[regiao] = true

func _liberar_vaga(vivos: Array[Node]) -> void:
	var tela := _camera.get_viewport_rect().size / _camera.zoom
	var visivel := Rect2(_camera.get_screen_center_position() - tela * 0.5, tela).grow(32.0)
	for zumbi: Inimigo in vivos:
		if zumbi.has_meta("obrigatorio") or int(zumbi.get_meta("regiao", setor)) >= setor:
			continue
		if zumbi.global_position.distance_to(_fase.pes.global_position) < DISTANCIA_REMOCAO:
			continue
		if visivel.has_point(zumbi.global_position):
			continue
		zumbi.queue_free()
		# Usa a vaga apenas no próximo ciclo, após o nó sair da árvore.
		_intervalo = 0.12
		return

func _local_seguro(celula: Vector2i, limite: float) -> bool:
	if not _fase.caminhos.region.has_point(celula) or _fase.caminhos.is_point_solid(celula):
		return false
	var posicao: Vector2 = _fase.piso.map_to_local(celula)
	var distancia: float = posicao.distance_to(_fase.pes.global_position)
	if distancia < DISTANCIA_MINIMA or distancia > limite:
		return false
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = _forma
	consulta.collision_mask = 7
	consulta.transform = Transform2D(0.0, posicao)
	return _fase.get_world_2d().direct_space_state.intersect_shape(consulta, 1).is_empty()

func _criar_zumbi(celula: Vector2i, tipo: Zumbi.Tipo, regiao: int) -> Inimigo:
	var zumbi := CENA_ZUMBI.instantiate()
	zumbi.position = _fase.piso.map_to_local(celula)
	zumbi.alvo = _fase.pes
	zumbi.caminhos = _fase.caminhos
	zumbi.atraso_aparicao = 0.7
	zumbi.set_meta("regiao", regiao)
	zumbi.configurar_tipo(tipo)
	_fase.atores.add_child(zumbi)
	return zumbi

func gerar_onda_teste() -> void:
	var vagas := mini(3, LIMITE_VIVOS - get_tree().get_nodes_in_group("inimigos").size())
	var centro: Vector2i = _fase.piso.local_to_map(_fase.pes.global_position)
	for deslocamento in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4),
			Vector2i(3, 3), Vector2i(-3, 3), Vector2i(3, -3), Vector2i(-3, -3)]:
		if vagas <= 0:
			break
		var celula: Vector2i = centro + deslocamento
		if _local_seguro(celula, 176.0):
			_criar_zumbi(celula, Zumbi.Tipo.COMUM, setor)
			vagas -= 1
func gerar_da_sepultura(origem: Vector2i) -> bool:
	if _fase.batalhas.ativa or get_tree().get_nodes_in_group("inimigos").size() >= LIMITE_VIVOS:
		return false
	for deslocamento in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3),
			Vector2i(3, 2), Vector2i(-3, 2), Vector2i(3, -2), Vector2i(-3, -2)]:
		var celula: Vector2i = origem + deslocamento
		if _local_seguro(celula, 230.0) and _fase.batalhas.mesma_regiao(celula, origem):
			_criar_zumbi(celula, Zumbi.Tipo.COMUM, setor)
			return true
	return false
