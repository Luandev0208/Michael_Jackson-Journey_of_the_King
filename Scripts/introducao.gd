extends Node2D

const PROGRESSAO := preload("res://Scripts/progressao.gd")
const Camarim := preload("res://Scripts/camarim.gd")
const CENAS: Array[PackedScene] = [
	preload("res://Scenes/camarim.tscn"),
	preload("res://Scenes/billie_jean.tscn"),
	preload("res://Scenes/thriller.tscn"),
	preload("res://Scenes/smooth_criminal.tscn"),
]
const FIGURINO := preload("res://Assets/Michael/Variantes/michael_terno_claro_sem_chapeu_spriteframes.tres")
const THE_SILENCE := preload("res://Assets/UltimoEco/Boss/the_silence_fase_3.tres")
const EFEITOS := preload("res://Assets/UltimoEco/Efeitos/the_silence_efeitos.tres")
const DETETIVE := preload("res://Assets/Inimigos/BillieJean/DetetiveComum/spriteframes.tres")
const ZUMBI := preload("res://Assets/Inimigos/Thriller/ZumbiComum/spriteframes.tres")
const CAPANGA := preload("res://Assets/SmoothCriminal/Inimigos/CapangaComum/spriteframes.tres")
const HOLOFOTE := preload("res://Assets/SmoothCriminal/Holofotes/ligado.png")
const CONE := preload("res://Assets/SmoothCriminal/Holofotes/cone_dourado.png")
const DURACAO := 39.5

var _palcos: Array[Node2D] = []
var _sequencia: Tween
var _movimento: Tween
var _texto: Tween
var _fade: Tween
var _michael: AnimatedSprite2D
var _aposento: PointLight2D
var _luz_espelho: PointLight2D
var _silencio: AnimatedSprite2D
var _detetive: AnimatedSprite2D
var _zumbis: Array[AnimatedSprite2D] = []
var _capanga: AnimatedSprite2D
var _cone: Sprite2D
var _sombra: AnimatedSprite2D
var _encerrando := false

@onready var camera: Camera2D = $Camera2D
@onready var ambiente: CanvasModulate = $Ambiente
@onready var reflexo: ColorRect = $Reflexo
@onready var legenda: Label = $Interface/Legenda
@onready var memoria: Label = $Interface/Memoria
@onready var titulo: VBoxContainer = $Interface/Titulo
@onready var escuro: ColorRect = $Interface/Escuro
@onready var botao_pular: Button = $Interface/Pular


func _ready() -> void:
	for cena in CENAS:
		var palco := _copiar_cenario(cena)
		palco.hide()
		$Cenarios.add_child(palco)
		_palcos.append(palco)
	_montar_camarim()
	_montar_memorias()
	botao_pular.pressed.connect(_finalizar)
	_iniciar_sequencia()


# Lê apenas os nós visuais do PackedScene. Nenhum script, colisor, jogador
# controlável ou encontro é instanciado para os planos das memórias.
func _copiar_cenario(cena: PackedScene) -> Node2D:
	var estado := cena.get_state()
	var palco := Node2D.new()
	var visuais := {NodePath("."): palco}
	for i in range(1, estado.get_node_count()):
		var pai := visuais.get(estado.get_node_path(i, true)) as Node2D
		if pai == null:
			continue
		var visual: Node2D
		match estado.get_node_type(i):
			&"TileMapLayer":
				visual = TileMapLayer.new()
			&"Sprite2D":
				visual = Sprite2D.new()
			&"Node2D", &"StaticBody2D":
				visual = Node2D.new()
			_:
				continue
		visual.name = estado.get_node_name(i)
		for j in estado.get_node_property_count(i):
			var propriedade := estado.get_node_property_name(i, j)
			if propriedade != &"script" and propriedade in visual:
				visual.set(propriedade, estado.get_node_property_value(i, j))
		if visual is TileMapLayer:
			visual.collision_enabled = false
			visual.navigation_enabled = false
		pai.add_child(visual)
		visuais[estado.get_node_path(i)] = visual
	return palco


func _montar_camarim() -> void:
	var sala := _palcos[0]
	Camarim.montar_cenario(sala.get_node("Piso"), sala.get_node("Paredes"))
	_michael = _ator(sala.get_node("Moveis"), FIGURINO, Vector2(320, 271), &"Cima")
	_michael.stop()
	_michael.offset = Vector2(0, -8.5)

	_silencio = _ator(sala, THE_SILENCE, Vector2(320, 137), &"idle_down")
	_silencio.centered = false
	_silencio.offset = Vector2(-32, -56)
	_silencio.scale = Vector2(1.65, 1.65)
	_silencio.z_index = 5
	_silencio.modulate = Color(0.68, 0.60, 0.83, 0.0)
	_silencio.hide()
	_sombra = _ator(sala, EFEITOS, Vector2(320, 100), &"nevoa")
	_sombra.scale = Vector2(0.80, 1.35)
	_sombra.z_index = 4
	_sombra.modulate = Color(0.39, 0.35, 0.57, 0.0)
	_sombra.hide()
	_aposento = _luz(sala, Vector2(498, 160), Color(1.0, 0.59, 0.33), 2.8, 0.62)
	_luz_espelho = _luz(sala, Vector2(320, 108), Color(0.64, 0.55, 1.0), 2.0, 0.18)


func _montar_memorias() -> void:
	var rua := _palcos[1]
	_detetive = _ator(rua.get_node("Atores"), DETETIVE, Vector2(568, 1200), &"walk_left")
	_detetive.offset.y = -14.0
	_luz(rua, Vector2(540, 1135), Color(1.0, 0.58, 0.23), 2.2, 0.55)

	var cemiterio := _palcos[2]
	for posicao in [Vector2(734, 1475), Vector2(845, 1435)]:
		var zumbi := _ator(cemiterio.get_node("Atores"), ZUMBI, posicao, &"walk_down")
		zumbi.offset.y = -14.0
		_zumbis.append(zumbi)
	_luz(cemiterio, Vector2(780, 1395), Color(0.39, 0.67, 1.0), 3.3, 0.75)

	var clube := _palcos[3]
	_capanga = _ator(clube.get_node("Atores"), CAPANGA, Vector2(1009, 776), &"walk_left")
	_capanga.offset.y = -14.0
	var vigia := Sprite2D.new()
	vigia.texture = HOLOFOTE
	vigia.position = Vector2(838, 711)
	clube.add_child(vigia)
	_cone = Sprite2D.new()
	_cone.texture = CONE
	_cone.centered = false
	_cone.offset = Vector2(-64, -8)
	_cone.position = vigia.position
	_cone.modulate.a = 0.55
	_cone.z_index = 2
	clube.add_child(_cone)
	_luz(clube, Vector2(927, 748), Color(1.0, 0.69, 0.37), 2.8, 0.60)


func _ator(pai: Node2D, quadros: SpriteFrames, posicao: Vector2, animacao: StringName) -> AnimatedSprite2D:
	var ator := AnimatedSprite2D.new()
	ator.sprite_frames = quadros
	ator.position = posicao
	ator.scale = Vector2(2, 2)
	ator.play(animacao)
	pai.add_child(ator)
	return ator


func _luz(pai: Node2D, posicao: Vector2, cor: Color, tamanho: float, intensidade: float) -> PointLight2D:
	var gradiente := Gradient.new()
	gradiente.colors = PackedColorArray([Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	var textura := GradientTexture2D.new()
	textura.width = 128
	textura.height = 128
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	var luz := PointLight2D.new()
	luz.texture = textura
	luz.texture_scale = tamanho
	luz.energy = intensidade
	luz.color = cor
	luz.position = posicao
	pai.add_child(luz)
	return luz


func _process(delta: float) -> void:
	AudioManager.avancar_cinematica(_sequencia, delta)


func _iniciar_sequencia() -> void:
	_sequencia = create_tween()
	_sequencia.pause()
	var anterior := 0.0
	var planos := [
		[0.0, _abertura],
		[1.4, _legendar.bind("Cada música conta uma história.")],
		[4.6, _legendar.bind("E cada história guarda uma memória.")],
		[6.9, _oscilar_luzes],
		[8.3, _ameaca],
		[11.8, _legendar.bind("The Silence\nQuando a última memória desaparecer, restará apenas o silêncio.")],
		[15.9, _escurecer.bind(1.0, 0.45)],
		[16.35, _billie_jean],
		[19.55, _escurecer.bind(1.0, 0.42)],
		[19.97, _thriller],
		[23.30, _escurecer.bind(1.0, 0.42)],
		[23.72, _smooth_criminal],
		[27.10, _escurecer.bind(1.0, 0.50)],
		[27.60, _jornada],
		[31.65, _legendar.bind("Uma última jornada está prestes a começar.")],
		[34.4, _mostrar_titulo],
		[38.65, _despedir],
		[DURACAO, _finalizar],
	]
	for plano in planos:
		_sequencia.tween_interval(float(plano[0]) - anterior)
		_sequencia.tween_callback(plano[1])
		anterior = plano[0]


func _plano(indice: int, de: Vector2, ate: Vector2, zoom_de: float, zoom_ate: float, tempo: float) -> void:
	for i in _palcos.size():
		_palcos[i].visible = i == indice
	reflexo.visible = indice == 0
	if _movimento != null and _movimento.is_valid():
		_movimento.kill()
	camera.position = de
	camera.zoom = Vector2.ONE * zoom_de
	camera.force_update_scroll()
	_movimento = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_movimento.tween_property(camera, "position", ate, tempo)
	_movimento.tween_property(camera, "zoom", Vector2.ONE * zoom_ate, tempo)


func _abertura() -> void:
	_plano(0, Vector2(320, 182), Vector2(320, 160), 1.02, 1.16, 7.1)
	ambiente.color = Color(0.77, 0.69, 0.73)
	_escurecer(0.0, 1.9)


func _oscilar_luzes() -> void:
	var luzes := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	luzes.tween_property(_aposento, "energy", 0.24, 0.31)
	luzes.tween_property(_aposento, "energy", 0.52, 0.40)
	luzes.tween_property(_aposento, "energy", 0.15, 0.68)


func _ameaca() -> void:
	AudioManager.tocar(&"intro_ameaca")
	_plano(0, camera.position, Vector2(320, 132), camera.zoom.x, 1.58, 6.5)
	_silencio.show()
	_silencio.play(&"idle_down")
	_sombra.show()
	_sombra.play(&"nevoa")
	var chegada := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	chegada.tween_property(_silencio, "modulate:a", 0.96, 2.0)
	chegada.tween_property(_sombra, "modulate:a", 0.42, 1.75)
	chegada.tween_property(_luz_espelho, "energy", 0.38, 2.0)
	chegada.tween_property(ambiente, "color", Color(0.57, 0.53, 0.73), 2.4)
	chegada.tween_property(reflexo.material, "shader_parameter/intensidade", 0.92, 2.1)
	_legendar("Mas uma presença está apagando essas lembranças...")


func _billie_jean() -> void:
	_plano(1, Vector2(473, 1105), Vector2(514, 1136), 1.22, 1.32, 3.6)
	ambiente.color = Color(0.56, 0.62, 0.87)
	memoria.text = "BILLIE JEAN"
	_movimento.tween_property(_detetive, "position:x", 512.0, 3.4)
	_movimento.tween_property(ambiente, "color", Color(0.43, 0.46, 0.71), 3.4)
	_escurecer(0.0, 0.48)
	_legendar("As luzes estão desaparecendo.")


func _thriller() -> void:
	_plano(2, Vector2(788, 1415), Vector2(762, 1450), 1.41, 1.32, 3.75)
	ambiente.color = Color(0.54, 0.70, 0.82)
	memoria.text = "THRILLER"
	for zumbi in _zumbis:
		_movimento.tween_property(zumbi, "position:y", zumbi.position.y + 32.0, 3.4)
	_escurecer(0.0, 0.50)
	_legendar("As sombras estão despertando.")


func _smooth_criminal() -> void:
	_plano(3, Vector2(884, 735), Vector2(938, 753), 1.20, 1.38, 3.85)
	ambiente.color = Color(0.73, 0.62, 0.59)
	memoria.text = "SMOOTH CRIMINAL"
	_cone.rotation = deg_to_rad(-21.0)
	_movimento.tween_property(_cone, "rotation", deg_to_rad(22.0), 3.65)
	_movimento.tween_property(_capanga, "position:x", 944.0, 3.65)
	_escurecer(0.0, 0.50)
	_legendar("E a música está sendo esquecida.")


func _jornada() -> void:
	_plano(0, Vector2(320, 163), Vector2(320, 155), 1.12, 1.26, 6.8)
	_restaurar_ambiente()
	memoria.text = ""
	_silencio.hide()
	_sombra.hide()
	_michael.play(&"Cima")
	_movimento.tween_property(_michael, "position:y", 223.0, 3.5)
	_movimento.tween_callback(_michael.stop).set_delay(3.53)
	_movimento.tween_property(_luz_espelho, "energy", 0.84, 3.9)
	_movimento.tween_property(reflexo.material, "shader_parameter/intensidade", 0.96, 3.9)
	_escurecer(0.0, 0.85)
	_legendar("Para salvar suas memórias, Michael precisará reviver cada uma delas.")


func _restaurar_ambiente() -> void:
	ambiente.color = Color(0.69, 0.65, 0.78)
	_luz_espelho.color = Color(0.78, 0.70, 1.0)
	reflexo.material.set_shader_parameter("restaurado", true)
	reflexo.material.set_shader_parameter("intensidade", 0.38)


func _mostrar_titulo() -> void:
	_legendar("")
	titulo.show()
	create_tween().tween_property(titulo, "modulate:a", 1.0, 1.0)
	_escurecer(0.52, 0.95)


func _despedir() -> void:
	create_tween().tween_property(titulo, "modulate:a", 0.0, 0.70)
	_escurecer(1.0, 0.85)


func _legendar(frase: String) -> void:
	if _texto != null and _texto.is_valid():
		_texto.kill()
	_texto = create_tween()
	if not legenda.text.is_empty():
		_texto.tween_property(legenda, "modulate:a", 0.0, 0.21)
	_texto.tween_callback(legenda.set_text.bind(frase))
	_texto.tween_property(legenda, "modulate:a", 1.0, 0.39)


func _escurecer(opacidade: float, tempo: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(escuro, "color:a", opacidade, tempo)


func _input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.keycode in [KEY_ENTER, KEY_KP_ENTER] or evento.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			_finalizar()


func _finalizar() -> void:
	if _encerrando:
		return
	_encerrando = true
	var erro := get_tree().change_scene_to_file(PROGRESSAO.CAMARIM)
	if erro != OK:
		_encerrando = false
		push_error("Não foi possível abrir o Camarim: %s" % error_string(erro))
