extends Node2D

const PROGRESSAO := preload("res://Scripts/progressao.gd")
const Camarim := preload("res://Scripts/camarim.gd")
const ARENA := preload("res://Scenes/ArenasUltimoEco/arena_restaurada.tscn")
const BILLIE := preload("res://Scenes/billie_jean.tscn")
const THRILLER := preload("res://Scenes/thriller.tscn")
const SMOOTH := preload("res://Scenes/smooth_criminal.tscn")
const CAMARIM := preload("res://Scenes/camarim.tscn")
const FIGURINO_FINAL := preload("res://Assets/Michael/Animacoes/SmoothCriminal/michael_terno_claro_com_chapeu.tres")
const FIGURINO_CAMARIM := preload("res://Assets/Michael/Variantes/michael_terno_claro_sem_chapeu_spriteframes.tres")
const SILENCIO := preload("res://Assets/UltimoEco/Boss/the_silence_fase_3.tres")
const EFEITOS := preload("res://Assets/UltimoEco/Efeitos/the_silence_efeitos.tres")
const HOLOFOTE := preload("res://Assets/SmoothCriminal/Holofotes/ligado.png")
const CONE := preload("res://Assets/SmoothCriminal/Holofotes/cone_dourado.png")
const DURACAO := 46.0
const OURO := Color(1.0, 0.69, 0.36)

var notas_coletadas := 0
var total_notas := 0

var _em_exibicao := true
var _sequencia: Tween
var _plano: Tween
var _transicao: Tween
var _texto: Tween
var _cartelas: Tween
var _palco: Node2D
var _luz_radial: GradientTexture2D

@onready var camera: Camera2D = $Camera2D
@onready var ambiente: CanvasModulate = $Ambiente
@onready var cartela: Label = $Interface/Memoria
@onready var legenda: Label = $Interface/Legenda
@onready var escuro: ColorRect = $Interface/Escuro
@onready var titulo: VBoxContainer = $Interface/Titulo
@onready var conclusao: CenterContainer = $Interface/Conclusao
@onready var creditos: Button = $Interface/Conclusao/Painel/Conteudo/Creditos


func _ready() -> void:
	var gradiente := Gradient.new()
	gradiente.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	_luz_radial = GradientTexture2D.new()
	_luz_radial.width = 128
	_luz_radial.height = 128
	_luz_radial.gradient = gradiente
	_luz_radial.fill = GradientTexture2D.FILL_RADIAL
	_luz_radial.fill_from = Vector2(0.5, 0.5)
	_luz_radial.fill_to = Vector2(1, 0.5)

	var momentos := [
		[0.0, _ultimo_silencio],
		[1.1, _legendar.bind("O silêncio finalmente se desfez.")],
		[4.2, _legendar.bind("E as memórias começaram a voltar.")],
		[8.0, _fechar_plano],
		[8.75, _billie_jean],
		[14.10, _fechar_plano],
		[14.85, _thriller],
		[20.20, _fechar_plano],
		[20.95, _smooth_criminal],
		[27.15, _fechar_plano],
		[27.90, _camarim],
		[31.80, _legendar.bind("Elas continuam vivendo em cada lembrança.")],
		[35.70, _ultima_nota],
		[38.25, _titulo_final],
		[42.0, _legendar.bind("Enquanto houver quem se lembre, a música nunca desaparecerá.")],
		[44.85, _escurecer.bind(1.0, 1.15)],
		[DURACAO, _mostrar_conclusao],
	]
	_sequencia = create_tween()
	var anterior := 0.0
	for momento in momentos:
		var instante := float(momento[0])
		_sequencia.tween_interval(instante - anterior)
		_sequencia.tween_callback(momento[1])
		anterior = instante


# Usa o estado serializado das cenas para copiar só a arte e suas transformações.
# As fases, os corpos de física e seus scripts nunca entram na árvore.
func _copiar_cenario(cena: PackedScene) -> Node2D:
	var estado := cena.get_state()
	var palco := Node2D.new()
	var visuais := {NodePath("."): palco}
	for i in range(1, estado.get_node_count()):
		var pai := visuais.get(estado.get_node_path(i, true)) as Node2D
		if pai == null:
			continue
		var no: Node2D
		match estado.get_node_type(i):
			&"TileMapLayer":
				no = TileMapLayer.new()
			&"Sprite2D":
				no = Sprite2D.new()
			&"Polygon2D":
				no = Polygon2D.new()
			&"Node2D", &"StaticBody2D":
				no = Node2D.new()
			_:
				continue
		no.name = estado.get_node_name(i)
		for j in estado.get_node_property_count(i):
			var propriedade := estado.get_node_property_name(i, j)
			if propriedade != &"script" and propriedade in no:
				no.set(propriedade, estado.get_node_property_value(i, j))
		if no is TileMapLayer:
			no.collision_enabled = false
			no.navigation_enabled = false
		pai.add_child(no)
		visuais[estado.get_node_path(i)] = no
	return palco


func _abrir_plano(cena: PackedScene, nome: String, centro: Vector2, zoom: float, tom: Color) -> void:
	_parar_plano()
	_palco = _copiar_cenario(cena)
	$Cenarios.add_child(_palco)
	cartela.text = nome
	ambiente.color = tom
	camera.position = centro
	camera.zoom = Vector2.ONE * zoom
	camera.force_update_scroll()
	_plano = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_escurecer(0.0, 0.8)


func _parar_plano() -> void:
	if _plano != null:
		_plano.kill()
	if is_instance_valid(_palco):
		_palco.hide()
		_palco.queue_free()


func _mover_camera(ate: Vector2, zoom: float, tempo: float) -> void:
	_plano.tween_property(camera, "position", ate, tempo)
	_plano.tween_property(camera, "zoom", Vector2.ONE * zoom, tempo)


func _luz(posicao: Vector2, cor: Color, raio: float, energia := 0.0) -> PointLight2D:
	var luz := PointLight2D.new()
	luz.texture = _luz_radial
	luz.texture_scale = raio
	luz.energy = energia
	luz.color = cor
	luz.position = posicao
	_palco.add_child(luz)
	return luz


func _ator(pai: Node2D, quadros: SpriteFrames, posicao: Vector2, escala: float, profundidade: int) -> AnimatedSprite2D:
	var ator := AnimatedSprite2D.new()
	ator.sprite_frames = quadros
	ator.position = posicao
	ator.scale = Vector2.ONE * escala
	ator.z_index = profundidade
	pai.add_child(ator)
	return ator


func _particulas(centro: Vector2, extensao: Vector2, quantidade: int) -> CPUParticles2D:
	var pontos := CPUParticles2D.new()
	pontos.position = centro
	pontos.z_index = 6
	pontos.amount = quantidade
	pontos.lifetime = 2.8
	pontos.preprocess = 1.2
	pontos.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pontos.emission_rect_extents = extensao
	pontos.direction = Vector2.UP
	pontos.spread = 44.0
	pontos.gravity = Vector2(0, -1.5)
	pontos.initial_velocity_min = 6.0
	pontos.initial_velocity_max = 24.0
	pontos.scale_amount_min = 1.0
	pontos.scale_amount_max = 2.8
	pontos.color_ramp = Gradient.new()
	pontos.color_ramp.offsets = PackedFloat32Array([0.0, 0.26, 0.67, 1.0])
	pontos.color_ramp.colors = PackedColorArray([
		Color(1, 0.67, 0.38, 0), Color(1, 0.90, 0.66), OURO, Color(1, 0.69, 0.36, 0),
	])
	_palco.add_child(pontos)
	return pontos


func _ultimo_silencio() -> void:
	AudioManager.tocar(&"final_dissolucao")
	_abrir_plano(ARENA, "O ÚLTIMO ECO", Vector2(640, 219), 1.10, Color(0.61, 0.50, 0.72))
	_mover_camera(Vector2(640, 171), 1.40, 8.4)
	var objetos := _palco.get_node("Objetos") as Node2D
	var michael := _ator(objetos, FIGURINO_FINAL, Vector2(580, 272), 2.0, 2)
	michael.offset.y = -8.5
	michael.animation = &"Cima"
	_plano.tween_callback(michael.play.bind(&"Cima")).set_delay(3.1)
	_plano.tween_property(michael, "position", Vector2(640, 184), 3.5).set_delay(3.1)
	_plano.tween_property(michael, "modulate:a", 0.0, 1.25).set_delay(5.6)
	var vestigio := _ator(objetos, SILENCIO, Vector2(729, 265), 1.8, 2)
	vestigio.offset.y = -24
	vestigio.modulate = Color(0.76, 0.62, 0.93, 0.72)
	vestigio.play(&"death", 0.56)
	_plano.tween_property(vestigio, "modulate:a", 0.0, 2.35)
	var fragmentos := _ator(_palco, EFEITOS, Vector2(729, 225), 1.5, 3)
	fragmentos.play(&"fragmentos_memoria", 0.45)
	fragmentos.animation_finished.connect(fragmentos.hide, CONNECT_ONE_SHOT)
	_particulas(Vector2(643, 241), Vector2(164, 62), 52)
	var portal := _luz(Vector2(640, 138), OURO, 2.05, 0.20)
	_plano.tween_property(portal, "energy", 1.10, 4.8)
	_plano.tween_property(ambiente, "color", Color(0.86, 0.78, 0.81), 4.8)


func _billie_jean() -> void:
	_abrir_plano(BILLIE, "BILLIE JEAN", Vector2(480, 1175), 1.14, Color(0.47, 0.51, 0.68))
	_mover_camera(Vector2(530, 1151), 1.31, 6.0)
	var pisos := _palco.get_node("PisosLuminosos") as TileMapLayer
	# A luz percorre os pisos visíveis na direção do movimento da câmera.
	for celula in pisos.get_used_cells():
		if not Rect2i(6, 31, 20, 11).has_point(celula):
			continue
		var atlas := pisos.get_cell_atlas_coords(celula)
		pisos.set_cell(celula, 0, Vector2i(0, atlas.y))
		atlas.x = maxi(atlas.x, 1)
		_plano.tween_callback(pisos.set_cell.bind(celula, 0, atlas)).set_delay(0.65 + (celula.x - 6) * 0.16)
	var relogio := _palco.get_node("Atores/Relogio")
	relogio.get_node("Apagado").hide()
	relogio.get_node("Restaurado").show()
	var luz := _luz(Vector2(536, 1136), OURO, 2.2)
	_plano.tween_property(luz, "energy", 0.9, 2.5).set_delay(1.0)
	_plano.tween_property(ambiente, "color", Color(0.86, 0.82, 0.94), 3.6)
	_legendar("As luzes voltaram a iluminar o caminho.")


func _thriller() -> void:
	_abrir_plano(THRILLER, "THRILLER", Vector2(787, 1397), 1.29, Color(0.58, 0.69, 0.82))
	_mover_camera(Vector2(774, 1452), 1.14, 5.9)
	var luar := _luz(Vector2(765, 1400), Color(0.52, 0.72, 1.0), 3.8, 0.36)
	var lanterna := _luz(Vector2(884, 1484), OURO, 1.65, 0.13)
	_plano.tween_property(luar, "energy", 0.75, 3.5)
	_plano.tween_property(lanterna, "energy", 0.65, 2.7).set_delay(1.4)
	_particulas(Vector2(773, 1455), Vector2(165, 77), 14).modulate.a = 0.42
	_legendar("Até as sombras encontraram descanso.")


func _smooth_criminal() -> void:
	_abrir_plano(SMOOTH, "SMOOTH CRIMINAL", Vector2(795, 552), 1.08, Color(0.45, 0.36, 0.52))
	_palco.get_node("Catracas").hide()
	_mover_camera(Vector2(911, 635), 1.25, 6.85)
	var lampadas := [Vector2(822, 534), Vector2(934, 659), Vector2(1083, 525)]
	for i in lampadas.size():
		var luz := _luz(lampadas[i], OURO, 2.0)
		_plano.tween_property(luz, "energy", 0.82, 1.4).set_delay(0.38 + i * 0.95)
	var corpo := Sprite2D.new()
	corpo.texture = HOLOFOTE
	corpo.position = Vector2(992, 549)
	corpo.z_index = 2
	corpo.modulate.a = 0.0
	_palco.add_child(corpo)
	var feixe := Sprite2D.new()
	feixe.texture = CONE
	feixe.centered = false
	feixe.offset = Vector2(-64, -8)
	feixe.position = corpo.position + Vector2(0, -19)
	feixe.rotation_degrees = 35.0
	feixe.modulate.a = 0.0
	_palco.add_child(feixe)
	_plano.tween_property(corpo, "modulate:a", 1.0, 1.1).set_delay(1.6)
	_plano.tween_property(feixe, "modulate:a", 0.71, 1.9).set_delay(1.6)
	_plano.tween_property(feixe, "rotation_degrees", 51.0, 5.0).set_delay(1.6)
	_plano.tween_property(ambiente, "color", Color(0.89, 0.77, 0.82), 4.2)
	_legendar("E a música voltou a preencher o silêncio.")


func _camarim() -> void:
	_abrir_plano(CAMARIM, "CAMARIM", Vector2(320, 178), 1.18, Color(0.80, 0.71, 0.82))
	Camarim.montar_cenario(_palco.get_node("Piso"), _palco.get_node("Paredes"))
	_mover_camera(Vector2(320, 154), 1.36, 7.75)
	var michael := _ator(_palco.get_node("Moveis"), FIGURINO_CAMARIM, Vector2(320, 265), 2.0, 0)
	michael.offset.y = -8.5
	michael.play(&"Cima")
	_plano.tween_property(michael, "position:y", 224.0, 2.5)
	_plano.tween_callback(michael.pause).set_delay(2.5)
	var reflexo := _ator(_palco, FIGURINO_CAMARIM, Vector2(320, 133), 1.25, 2)
	reflexo.name = "ReflexoMichael"
	reflexo.animation = &"Parado"
	reflexo.modulate = Color(0.78, 0.70, 1.0, 0.0)
	_plano.tween_property(reflexo, "modulate:a", 0.66, 2.2).set_delay(0.78)
	_luz(Vector2(520, 145), OURO, 2.65, 0.61)
	var espelho := _luz(Vector2(320, 121), Color(0.72, 0.64, 1.0), 1.65, 0.28)
	_plano.tween_property(espelho, "energy", 0.67, 4.9)
	_legendar("Algumas histórias nunca terminam.")


func _ultima_nota() -> void:
	AudioManager.tocar(&"final_nota")
	_legendar("")
	cartela.text = ""
	_plano.kill()
	_plano = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mover_camera(Vector2(320, 186), 1.01, 8.75)
	_plano.tween_property(_palco.get_node("ReflexoMichael"), "modulate:a", 0.0, 1.7)
	var nota := Polygon2D.new()
	nota.position = Vector2(320, 175)
	nota.z_index = 6
	nota.polygon = PackedVector2Array([Vector2(0, -16), Vector2(14, 0), Vector2(0, 16), Vector2(-14, 0)])
	nota.color = Color(0.39, 0.27, 0.56, 0.92)
	nota.modulate.a = 0.0
	_palco.add_child(nota)
	var simbolo := Label.new()
	simbolo.position = Vector2(-7, -16)
	simbolo.text = "♪"
	simbolo.add_theme_font_size_override("font_size", 21)
	simbolo.add_theme_color_override("font_color", Color(1.0, 0.88, 0.56))
	nota.add_child(simbolo)
	var brilho := _luz(Vector2(320, 142), OURO, 0.92)
	_plano.tween_property(nota, "modulate:a", 1.0, 1.4)
	_plano.tween_property(nota, "position:y", 110.0, 4.5)
	_plano.tween_property(brilho, "energy", 0.72, 2.3)
	_particulas(Vector2(320, 150), Vector2(39, 21), 23)


func _fechar_plano() -> void:
	_legendar("")
	_escurecer(1.0, 0.75)


func _titulo_final() -> void:
	titulo.modulate.a = 0.0
	titulo.show()
	_cartelas = create_tween().set_parallel()
	_cartelas.tween_property(titulo, "modulate:a", 1.0, 1.0)
	_cartelas.tween_property(titulo.get_node("Fim"), "modulate:a", 1.0, 0.6).set_delay(2.65)
	_cartelas.tween_property(titulo, "modulate:a", 0.0, 1.12).set_delay(6.6)
	_escurecer(0.56, 4.5)


func _legendar(frase: String) -> void:
	if _texto != null:
		_texto.kill()
	_texto = create_tween()
	_texto.tween_property(legenda, "modulate:a", 0.0, 0.20)
	_texto.tween_callback(legenda.set_text.bind(frase))
	_texto.tween_property(legenda, "modulate:a", 1.0, 0.38)


func _escurecer(opacidade: float, tempo: float) -> void:
	if _transicao != null:
		_transicao.kill()
	_transicao = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transicao.tween_property(escuro, "color:a", opacidade, tempo)


func _input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed:
		return
	var enter: Array[Key] = [KEY_ENTER, KEY_KP_ENTER]
	if evento.keycode not in enter and evento.physical_keycode not in enter:
		return
	if _em_exibicao or evento.echo:
		get_viewport().set_input_as_handled()
	if _em_exibicao and not evento.echo:
		_mostrar_conclusao()


func _mostrar_conclusao() -> void:
	if not _em_exibicao:
		return
	_em_exibicao = false
	_sequencia.kill()
	_parar_plano()
	if _texto != null:
		_texto.kill()
	if _transicao != null:
		_transicao.kill()
	if _cartelas != null:
		_cartelas.kill()
	for no: CanvasItem in [$Interface/Pular, titulo, legenda, cartela, $Interface/Topo, $Interface/Rodape]:
		no.hide()
	escuro.color.a = 1.0
	var pontos := conclusao.get_node("Painel/Conteudo/Pontos") as Label
	if total_notas > 0:
		pontos.text = "Notas  %d/%d    Pontos  %d" % [notas_coletadas, total_notas, notas_coletadas * 100]
		pontos.show()
	conclusao.show()
	creditos.grab_focus()


func _ver_creditos() -> void:
	_prosseguir(PROGRESSAO.CREDITOS)


func _voltar_ao_menu() -> void:
	_prosseguir(PROGRESSAO.MENU)


func _prosseguir(destino: String) -> void:
	var erro := get_tree().change_scene_to_file(destino)
	if erro != OK:
		push_error("Não foi possível abrir %s: %s" % [destino, error_string(erro)])
