extends VBoxContainer

signal voltar_solicitado

const Catalogo := preload("res://Scripts/catalogo_audio.gd")
const CATEGORIAS := [
	"Todos", "Passos", "Habilidades e combate", "Chefes", "Progressão",
	"Interface", "Ambientes", "Cutscenes",
]

var _arquivos: Array[Dictionary] = []
var _lista := ItemList.new()
var _detalhes := Label.new()
var _categoria := OptionButton.new()
var _voz := AudioStreamPlayer.new()
var _ouvir: Button
var _parar: Button


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var cabecalho := HBoxContainer.new()
	add_child(cabecalho)
	var titulo := Label.new()
	titulo.text = "Prévia de áudio"
	titulo.add_theme_font_size_override("font_size", 17)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecalho.add_child(titulo)
	_botao(cabecalho, "Voltar", func(): voltar_solicitado.emit())
	_categoria.set_meta("sem_som_interface", true)
	add_child(_categoria)
	for nome: String in CATEGORIAS:
		_categoria.add_item(nome)
	_categoria.item_selected.connect(_filtrar)
	_lista.custom_minimum_size.y = 136.0
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.item_selected.connect(_selecionar)
	_lista.item_activated.connect(_reproduzir)
	add_child(_lista)
	_detalhes.add_theme_font_size_override("font_size", 12)
	add_child(_detalhes)
	var acoes := HBoxContainer.new()
	add_child(acoes)
	_ouvir = _botao(acoes, "Ouvir selecionado", _ouvir_selecionado)
	_parar = _botao(acoes, "Parar", _parar_audio)
	add_child(_voz)
	_voz.finished.connect(_parar_audio)
	_montar_catalogo()
	_filtrar(0)


func abrir() -> void:
	show()
	_lista.grab_focus()


func fechar() -> void:
	_parar_audio()
	hide()


func _montar_catalogo() -> void:
	for evento: StringName in Catalogo.EFEITOS:
		var grupo := "Habilidades e combate"
		if evento.begins_with("passo_"):
			grupo = "Passos"
		elif evento.begins_with("chefe_"):
			grupo = "Chefes"
		elif evento in [&"nota_coletada", &"cura", &"portal", &"restauracao", &"vitoria"]:
			grupo = "Progressão"
		for arquivo: String in Catalogo.EFEITOS[evento]:
			_incluir("SFX/" + arquivo, &"SFX", grupo)
	for evento: StringName in Catalogo.INTERFACE:
		for arquivo: String in Catalogo.INTERFACE[evento]:
			_incluir("UI/" + arquivo, &"UI", "Interface")
	for evento: StringName in Catalogo.CINEMATICAS:
		for arquivo: String in Catalogo.CINEMATICAS[evento]:
			_incluir("Cinematics/" + arquivo, &"Cinematics", "Cutscenes")
	for arquivo: String in Catalogo.AMBIENTES.values():
		_incluir(arquivo, &"Ambient", "Ambientes")
	_arquivos.sort_custom(func(a: Dictionary, b: Dictionary): return a.arquivo < b.arquivo)


func _incluir(arquivo: String, canal: StringName, categoria: String) -> void:
	if ResourceLoader.exists(Catalogo.PASTA + arquivo, "AudioStream"):
		_arquivos.append({"arquivo": arquivo, "canal": canal, "categoria": categoria})


func _filtrar(indice: int) -> void:
	_parar_audio()
	_lista.clear()
	for entrada: Dictionary in _arquivos:
		if indice != 0 and entrada.categoria != CATEGORIAS[indice]:
			continue
		var item := _lista.add_item(entrada.arquivo)
		_lista.set_item_metadata(item, entrada)
	_ouvir.disabled = _lista.item_count == 0
	if _ouvir.disabled:
		_detalhes.text = "Nenhum arquivo importado nesta categoria."
	else:
		_lista.select(0)
		_selecionar(0)


func _selecionar(indice: int) -> void:
	_parar_audio()
	var entrada: Dictionary = _lista.get_item_metadata(indice)
	_detalhes.text = "%s  ·  Canal %s" % [entrada.categoria, entrada.canal]


func _ouvir_selecionado() -> void:
	var selecionados := _lista.get_selected_items()
	if not selecionados.is_empty():
		_reproduzir(selecionados[0])


func _reproduzir(indice: int) -> void:
	_parar_audio()
	var entrada: Dictionary = _lista.get_item_metadata(indice)
	var som := load(Catalogo.PASTA + entrada.arquivo) as AudioStream
	if som == null:
		_detalhes.text = "Não foi possível carregar " + entrada.arquivo
		return
	if entrada.canal == &"Ambient" and som is AudioStreamOggVorbis:
		som = som.duplicate() as AudioStreamOggVorbis
		som.set("loop", true)
	_voz.bus = entrada.canal
	_voz.stream = som
	_voz.play()
	_parar.disabled = false
	_detalhes.text = ("Em loop  ·  " if entrada.canal == &"Ambient" else "Reproduzindo  ·  ") + entrada.arquivo


func _parar_audio() -> void:
	_voz.stop()
	_voz.stream = null
	_parar.disabled = true
	if not _lista.get_selected_items().is_empty():
		var entrada: Dictionary = _lista.get_item_metadata(_lista.get_selected_items()[0])
		_detalhes.text = "%s  ·  Canal %s" % [entrada.categoria, entrada.canal]


func _botao(pai: Node, texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.set_meta("sem_som_interface", true)
	botao.pressed.connect(acao)
	pai.add_child(botao)
	return botao
