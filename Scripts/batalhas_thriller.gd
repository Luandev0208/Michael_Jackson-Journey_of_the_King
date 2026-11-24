extends Node

const FEEDBACK := preload("res://Scripts/feedback_vitoria.gd")
const Zumbi := preload("res://Scripts/zumbi.gd")
const CENA_ZUMBI := preload("res://Scenes/zumbi.tscn")
const CENA_GUARDIAO := preload("res://Scenes/guardiao.tscn")
const LINHAS: Array[int] = [52, 34, 15]
const NOMES := ["Portão do cemitério", "Alameda dos túmulos", "Guardião do espelho"]
const ONDAS := [
	[[Zumbi.Tipo.COMUM, Zumbi.Tipo.COMUM]],
	[[Zumbi.Tipo.COMUM, Zumbi.Tipo.RAPIDO], [Zumbi.Tipo.LENTO, Zumbi.Tipo.RAPIDO, Zumbi.Tipo.COMUM]],
	[[Zumbi.Tipo.COMUM, Zumbi.Tipo.RAPIDO, Zumbi.Tipo.LENTO], [Zumbi.Tipo.GUARDIAO]],
]
const DISTANCIA_GATILHO := 218.0

var etapa := 0
var ativa := false
var onda := 0
var _fase: Node2D
var _barreiras: Array[StaticBody2D] = []
var _bases: Array[PackedInt32Array] = []
var _pendentes: Array = []
var _vivos: Dictionary[int, Inimigo] = {}
var _parados: Dictionary[int, float] = {}
var _espera := 0.0
var _mensagem := 0.0
var _aviso: Label
var _painel: Control

func iniciar(fase: Node2D, aviso: Label) -> void:
	_fase = fase
	_aviso = aviso
	_painel = aviso.get_parent()
	_aviso.show()
	_proteger_limites()
	for linha in LINHAS:
		var anteriores := PackedInt32Array()
		for x in range(_fase.caminhos.region.end.x):
			var celula := Vector2i(x, linha)
			if not _fase.caminhos.is_point_solid(celula):
				anteriores.append(x)
				_fase.caminhos.set_point_solid(celula)
		_bases.append(anteriores)
		_barreiras.append(_criar_barreira(linha))
	_painel.hide()

func _criar_barreira(linha: int) -> StaticBody2D:
	var barreira := StaticBody2D.new()
	barreira.position = Vector2(768, linha * 32 + 16)
	var colisor := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	# A colisão estende a cortina para além das cercas e dos limites laterais do mapa.
	forma.size = Vector2(4096, 16)
	colisor.shape = forma
	barreira.add_child(colisor)
	var cortina := Polygon2D.new()
	cortina.z_index = 3
	cortina.polygon = PackedVector2Array([-768, -9, 768, -9, 768, 9, -768, 9])
	cortina.color = Color(0.46, 0.14, 0.72, 0.78)
	barreira.add_child(cortina)
	var risco := Line2D.new()
	risco.z_index = 4
	risco.width = 2.0
	risco.default_color = Color(0.92, 0.67, 1.0)
	for x in range(-768, 769, 16):
		risco.add_point(Vector2(x, 3 if x % 32 == 0 else -3))
	barreira.add_child(risco)
	add_child(barreira)
	return barreira

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_fase) or _fase.concluida:
		return
	_mensagem = maxf(0.0, _mensagem - delta)
	if etapa >= LINHAS.size():
		_painel.visible = _mensagem > 0.0
		return
	var y_barreira := _barreiras[etapa].position.y
	var distancia: float = _fase.pes.global_position.y - y_barreira
	if not ativa:
		if distancia >= 0.0 and distancia <= DISTANCIA_GATILHO:
			ativa = true
			onda = 0
			_iniciar_onda(0.4)
		elif _mensagem <= 0.0:
			_painel.hide()
		return
	_painel.show()
	_aviso.text = "%s · Onda %d/%d\nDerrote os zumbis desta passagem" % [NOMES[etapa], onda + 1, ONDAS[etapa].size()]
	_espera = maxf(0.0, _espera - delta)
	if _espera <= 0.0 and not _pendentes.is_empty() and distancia >= 0.0 and distancia <= DISTANCIA_GATILHO + 32.0:
		var local := _local_de_aparicao()
		if local != Vector2i(-1, -1):
			_criar_inimigo(local, _pendentes.pop_front())
			_espera = 0.32
		else:
			_espera = 0.20
	if _pendentes.is_empty() and _vivos.is_empty():
		if onda + 1 < ONDAS[etapa].size():
			onda += 1
			_iniciar_onda(0.75)
		else:
			_liberar()
	elif distancia >= 0.0 and distancia <= DISTANCIA_GATILHO:
		_recuperar_inimigos_presos(delta)

func _iniciar_onda(atraso: float) -> void:
	_pendentes = ONDAS[etapa][onda].duplicate()
	_espera = atraso

func _local_de_aparicao() -> Vector2i:
	var jogador: MichaelJogador = _fase.jogador
	var origem := jogador.colisor.global_position
	var piso: TileMapLayer = _fase.piso
	var caminhos: AStarGrid2D = _fase.caminhos
	var perto := piso.local_to_map(origem)
	var raiz := Vector2i(-1, -1)
	var melhor_distancia := INF
	for y in range(perto.y - 2, perto.y + 3):
		for x in range(perto.x - 2, perto.x + 3):
			var celula := Vector2i(x, y)
			if not caminhos.region.has_point(celula) or caminhos.is_point_solid(celula) or y <= LINHAS[etapa]:
				continue
			var deslocamento := piso.map_to_local(celula) - origem
			var distancia := deslocamento.length_squared()
			if distancia < melhor_distancia and not jogador.test_move(jogador.global_transform, deslocamento):
				raiz = celula
				melhor_distancia = distancia
	if raiz.x < 0:
		return raiz

	var forma := CircleShape2D.new()
	forma.radius = 11.0
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = forma
	consulta.collision_mask = 7
	var espaco := jogador.get_world_2d().direct_space_state
	# Prefere a frente da passagem e expande a busca se houver obstáculos ou inimigos.
	for raio in range(3, 8):
		for y in range(perto.y - raio, perto.y + raio + 1):
			for x in range(perto.x - raio, perto.x + raio + 1):
				var celula := Vector2i(x, y)
				if maxi(absi(x - perto.x), absi(y - perto.y)) != raio or y <= LINHAS[etapa]:
					continue
				if not caminhos.region.has_point(celula) or caminhos.is_point_solid(celula):
					continue
				var posicao := piso.map_to_local(celula)
				if posicao.distance_to(origem) < 72.0:
					continue
				consulta.transform = Transform2D(0.0, posicao)
				if espaco.intersect_shape(consulta, 1).is_empty() and not caminhos.get_id_path(raiz, celula).is_empty():
					return celula
	return Vector2i(-1, -1)

func _criar_inimigo(local: Vector2i, tipo: Zumbi.Tipo) -> void:
	var cena := CENA_GUARDIAO if tipo == Zumbi.Tipo.GUARDIAO else CENA_ZUMBI
	var zumbi = cena.instantiate()  # sem tipo estático: o Guardião tem sinais próprios
	zumbi.position = _fase.piso.map_to_local(local)
	zumbi.alvo = _fase.pes
	zumbi.caminhos = _fase.caminhos
	zumbi.atraso_aparicao = 0.75
	zumbi.set_meta("obrigatorio", true)
	zumbi.configurar_tipo(tipo)
	zumbi.marcar_obrigatorio()
	var id := zumbi.get_instance_id()
	_vivos[id] = zumbi
	zumbi.derrotado.connect(_registrar_derrota.bind(id), CONNECT_ONE_SHOT)
	zumbi.tree_exiting.connect(_repor_se_necessario.bind(id, tipo), CONNECT_ONE_SHOT)
	if tipo == Zumbi.Tipo.GUARDIAO:
		zumbi.reforcos_pedidos.connect(_chamar_reforcos)
	_fase.atores.add_child(zumbi)

# Reforços do chefe: poucos e sempre dos tipos mais leves, para não sufocar o jogador.
func _chamar_reforcos(quantidade: int) -> void:
	var tipos := [Zumbi.Tipo.COMUM, Zumbi.Tipo.RAPIDO]
	for i in range(quantidade):
		_pendentes.append(tipos[i % tipos.size()])

func _registrar_derrota(id: int) -> void:
	_vivos.erase(id)
	_parados.erase(id)

func _repor_se_necessario(id: int, tipo: Zumbi.Tipo) -> void:
	# Saída da árvore sem morte nunca conta como vitória.
	if _vivos.erase(id):
		_parados.erase(id)
		_pendentes.append(tipo)

func _recuperar_inimigos_presos(delta: float) -> void:
	for id in _vivos:
		var zumbi := _vivos[id]
		if not zumbi.ia_ativa or zumbi.atraso_aparicao > 0.0 or zumbi.get_real_velocity().length_squared() > 4.0 or zumbi.global_position.distance_to(_fase.pes.global_position) < 55.0:
			_parados.erase(id)
			continue
		_parados[id] = float(_parados.get(id, 0.0)) + delta
		if _parados[id] < 5.0:
			continue
		var local := _local_de_aparicao()
		if local != Vector2i(-1, -1):
			zumbi.reancorar(_fase.piso.map_to_local(local))
			_parados.erase(id)

func _liberar() -> void:
	var barreira := _barreiras[etapa]
	barreira.get_child(0).set_deferred("disabled", true)
	for x in _bases[etapa]:
		_fase.caminhos.set_point_solid(Vector2i(x, LINHAS[etapa]), false)
	var dissipar := create_tween()
	dissipar.tween_property(barreira, "modulate:a", 0.0, 0.48)
	dissipar.tween_callback(barreira.queue_free)
	etapa += 1
	ativa = false
	_mensagem = 2.5
	_aviso.text = "Espelho liberado" if espelho_liberado() else "Combate concluído · Passagem liberada"
	FEEDBACK.faixa(_fase, "ESPELHO LIBERADO" if espelho_liberado() else "PASSAGEM LIBERADA", "Guardião derrotado" if espelho_liberado() else "", Color(0.82, 0.62, 1.0), 0.18 if espelho_liberado() else 0.0, 1.8)
	_painel.show()
	if not espelho_liberado():
		_fase.jogador.recuperar_uma_vida()

func espelho_liberado() -> bool:
	return etapa == LINHAS.size()

func mesma_regiao(a: Vector2i, b: Vector2i) -> bool:
	for linha in LINHAS:
		if (a.y <= linha) != (b.y <= linha):
			return false
	return true

func _proteger_limites() -> void:
	var corpo := StaticBody2D.new()
	var largura: float = _fase.caminhos.region.size.x * 32.0
	var altura: float = _fase.caminhos.region.size.y * 32.0
	for par in [[Vector2.RIGHT, 0.0], [Vector2.LEFT, -largura], [Vector2.DOWN, 0.0], [Vector2.UP, -altura]]:
		var colisor := CollisionShape2D.new()
		var limite := WorldBoundaryShape2D.new()
		limite.normal = par[0]
		limite.distance = par[1]
		colisor.shape = limite
		corpo.add_child(colisor)
	add_child(corpo)
