extends Area2D

# Nota musical coletável: pixel art gerada no código, flutuação discreta,
# brilho que cresce com a proximidade do jogador e feedback ao coletar.

const CAMADA_JOGADOR := 2
const PONTOS := 100
const RAIO_COLETA := 10.0
const RAIO_NITIDO := 70.0
const RAIO_PROXIMIDADE := 190.0
const ALTURA_BASE := -15.0
const ESCALA_ICONE := 2.0

# o = contorno, g = ouro, d = ouro escuro (sombra), h = brilho.
const LINHAS := [
	"................",
	"................",
	".........ooo....",
	"........ohhho...",
	"........ohggho..",
	"........ohgdgho.",
	"........ohdohdo.",
	"........ohdooho.",
	"........ohdooho.",
	"........ohdooho.",
	"........ohdohdo.",
	"....ooooohdooo..",
	"..oohhhhohdo....",
	".ohhgggghgdo....",
	"ohghhggggddo....",
	"ohghggggdoo.....",
	"ohgggggddo......",
	".ohddddoo.......",
	"..ooooo.........",
	"................",
]
const PALETA := {
	"o": Color(0.14, 0.07, 0.23),
	"g": Color(1.0, 0.80, 0.30),
	"d": Color(0.84, 0.52, 0.16),
	"h": Color(1.0, 0.93, 0.65),
}

static var _textura_nota: ImageTexture
static var _textura_brilho: ImageTexture
static var _textura_sombra: ImageTexture

var _tempo := 0.0
var _fase_flutuacao := 0.0
var _coletada := false
var _jogador: Node2D
var _icone: Sprite2D
var _brilho: Sprite2D


func _init() -> void:
	collision_layer = 0
	collision_mask = CAMADA_JOGADOR
	monitorable = false
	var colisor := CollisionShape2D.new()
	var forma := CircleShape2D.new()
	forma.radius = RAIO_COLETA
	colisor.shape = forma
	add_child(colisor)


func _ready() -> void:
	add_to_group("notas_musicais")
	_fase_flutuacao = randf() * TAU
	var sombra := Sprite2D.new()
	sombra.texture = _obter_sombra()
	sombra.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sombra.position = Vector2(0.0, 3.0)
	add_child(sombra)
	_brilho = Sprite2D.new()
	_brilho.texture = _obter_brilho()
	_brilho.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_brilho.position = Vector2(0.0, ALTURA_BASE + 1.0)
	_brilho.modulate.a = 0.3
	add_child(_brilho)
	_icone = Sprite2D.new()
	_icone.texture = _obter_nota()
	_icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icone.scale = Vector2(ESCALA_ICONE, ESCALA_ICONE)
	_icone.position = Vector2(0.0, ALTURA_BASE)
	add_child(_icone)


func _process(delta: float) -> void:
	if _coletada:
		return
	_tempo += delta
	# A flutuação anda em passos de 1 pixel para manter a pixel art nítida.
	_icone.position.y = ALTURA_BASE + roundf(sin(_tempo * 2.4 + _fase_flutuacao) * 2.0)
	if not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("jogador") as Node2D
	var intensidade := 0.0
	if is_instance_valid(_jogador):
		var distancia := global_position.distance_to(_jogador.global_position)
		intensidade = clampf(1.0 - (distancia - RAIO_NITIDO) / (RAIO_PROXIMIDADE - RAIO_NITIDO), 0.0, 1.0)
	var pulso := 0.5 + 0.5 * sin(_tempo * 3.1 + _fase_flutuacao)
	_brilho.modulate.a = lerpf(0.30, 0.95, intensidade) * (0.75 + 0.25 * pulso)
	var ampliacao := roundf(intensidade * pulso * 2.0) * 0.125
	_brilho.scale = Vector2.ONE * (1.0 + ampliacao)


func coletar() -> void:
	if _coletada:
		return
	_coletada = true
	AudioManager.tocar(&"nota_coletada", global_position)
	_efeito_coleta()
	queue_free()


func _efeito_coleta() -> void:
	var raiz := get_parent()
	if raiz == null:
		return
	var centro := global_position + Vector2(0.0, ALTURA_BASE)

	var anel := Line2D.new()
	anel.width = 2.0
	anel.default_color = Color(1.0, 0.88, 0.45, 0.9)
	anel.z_index = 5
	for i in range(21):
		anel.add_point(Vector2.from_angle(TAU * float(i) / 20.0) * 9.0)
	raiz.add_child(anel)
	anel.global_position = centro
	var expansao := anel.create_tween().set_parallel()
	expansao.tween_property(anel, "scale", Vector2(2.6, 2.6), 0.34)
	expansao.tween_property(anel, "modulate:a", 0.0, 0.34)
	expansao.chain().tween_callback(anel.queue_free)

	for i in range(8):
		var faisca := Polygon2D.new()
		faisca.polygon = PackedVector2Array([Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 1.5), Vector2(-1.5, 1.5)])
		faisca.color = Color(1.0, 0.93, 0.65) if i % 2 == 0 else Color(1.0, 0.78, 0.28)
		faisca.z_index = 6
		raiz.add_child(faisca)
		faisca.global_position = centro
		var sentido := Vector2.from_angle(TAU * (float(i) + 0.5) / 8.0)
		var voo := faisca.create_tween().set_parallel()
		voo.tween_property(faisca, "global_position", centro + sentido * randf_range(20.0, 32.0), 0.38)
		voo.tween_property(faisca, "modulate:a", 0.0, 0.38)
		voo.chain().tween_callback(faisca.queue_free)

	var texto := Label.new()
	texto.text = "+%d" % PONTOS
	texto.add_theme_font_size_override("font_size", 12)
	texto.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
	texto.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.23))
	texto.add_theme_constant_override("outline_size", 4)
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.z_index = 7
	raiz.add_child(texto)
	texto.global_position = centro + Vector2(-14.0, -30.0)
	var subida := texto.create_tween().set_parallel()
	subida.tween_property(texto, "global_position:y", texto.global_position.y - 16.0, 0.75)
	subida.tween_property(texto, "modulate:a", 0.0, 0.35).set_delay(0.4)
	subida.chain().tween_callback(texto.queue_free)


static func _obter_nota() -> ImageTexture:
	if _textura_nota == null:
		var imagem := Image.create(16, 20, false, Image.FORMAT_RGBA8)
		imagem.fill(Color(0.0, 0.0, 0.0, 0.0))
		for y in range(LINHAS.size()):
			var linha: String = LINHAS[y]
			for x in range(linha.length()):
				var letra := linha.substr(x, 1)
				if PALETA.has(letra):
					imagem.set_pixel(x, y, PALETA[letra])
		_textura_nota = ImageTexture.create_from_image(imagem)
	return _textura_nota


static func _obter_brilho() -> ImageTexture:
	# Anéis concêntricos em degraus, sem suavização, para combinar com a pixel art.
	if _textura_brilho == null:
		var lado := 44
		var imagem := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
		imagem.fill(Color(0.0, 0.0, 0.0, 0.0))
		var centro := Vector2(lado, lado) * 0.5
		for y in range(lado):
			for x in range(lado):
				var distancia := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(centro)
				var alfa := 0.0
				if distancia < 9.0:
					alfa = 0.34
				elif distancia < 15.0:
					alfa = 0.20
				elif distancia < 21.0:
					alfa = 0.09
				if alfa > 0.0:
					imagem.set_pixel(x, y, Color(1.0, 0.86, 0.45, alfa))
		_textura_brilho = ImageTexture.create_from_image(imagem)
	return _textura_brilho


static func _obter_sombra() -> ImageTexture:
	if _textura_sombra == null:
		var imagem := Image.create(16, 6, false, Image.FORMAT_RGBA8)
		imagem.fill(Color(0.0, 0.0, 0.0, 0.0))
		for y in range(6):
			for x in range(16):
				var dx := (float(x) + 0.5 - 8.0) / 7.5
				var dy := (float(y) + 0.5 - 3.0) / 2.6
				if dx * dx + dy * dy <= 1.0:
					imagem.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.30))
		_textura_sombra = ImageTexture.create_from_image(imagem)
	return _textura_sombra
