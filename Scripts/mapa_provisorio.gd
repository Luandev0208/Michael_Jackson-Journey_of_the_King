extends TileMapLayer

# Mapa provisório maior que a tela (640x360)
# Tiles: 0=grama, 1=caminho, 2=obstáculo/parede
# Tamanho: 50x30 tiles de 16x16 = 800x480 pixels

const LARGURA := 50
const ALTURA := 30

func _ready() -> void:
	_gerar_mapa()

func _gerar_mapa() -> void:
	# Preenche o fundo com grama (tile 0)
	for x in range(LARGURA):
		for y in range(ALTURA):
			set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

	# Caminhos horizontais com tile 1
	for x in range(LARGURA):
		set_cell(Vector2i(x, 14), 0, Vector2i(1, 0))
		set_cell(Vector2i(x, 15), 0, Vector2i(1, 0))

	# Caminho vertical central
	for y in range(ALTURA):
		set_cell(Vector2i(24, y), 0, Vector2i(1, 0))
		set_cell(Vector2i(25, y), 0, Vector2i(1, 0))

	# Bordas com paredes (tile 2)
	for x in range(LARGURA):
		set_cell(Vector2i(x, 0), 0, Vector2i(2, 0))
		set_cell(Vector2i(x, ALTURA - 1), 0, Vector2i(2, 0))
	for y in range(ALTURA):
		set_cell(Vector2i(0, y), 0, Vector2i(2, 0))
		set_cell(Vector2i(LARGURA - 1, y), 0, Vector2i(2, 0))
