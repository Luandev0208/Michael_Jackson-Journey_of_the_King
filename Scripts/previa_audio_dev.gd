extends VBoxContainer

signal voltar_solicitado

const Catalogo := preload("res://Scripts/catalogo_audio.gd")
const PROGRESSAO := preload("res://Scripts/progressao.gd")
const Perfil := preload("res://Scripts/perfil_musical.gd")
const CANAL_PREVIA := &"MusicPreview"
const CATEGORIAS := [
	"Todos", "Passos", "Habilidades e combate", "Chefes", "Progressão",
	"Interface", "Ambientes", "Cutscenes", "Trilhas",
]

var _arquivos: Array[Dictionary] = []
var _lista := ItemList.new()
var _detalhes := Label.new()
var _categoria := OptionButton.new()
var _voz := AudioStreamPlayer.new()
var _ajuste := HBoxContainer.new()
var _titulo_ajuste := Label.new()
var _controle := HSlider.new()
var _valor := Label.new()
var _perfil: Perfil
var _modo := ""
var _indice := -1
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
	add_child(_ajuste)
	_ajuste.add_child(_titulo_ajuste)
	_controle.step = 1.0
	_controle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controle.value_changed.connect(_atualizar_ajuste)
	_ajuste.add_child(_controle)
	_valor.custom_minimum_size.x = 42.0
	_valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ajuste.add_child(_valor)
	var acoes := HBoxContainer.new()
	add_child(acoes)
	_ouvir = _botao(acoes, "Ouvir selecionado", _ouvir_selecionado)
	_parar = _botao(acoes, "Parar", _parar_audio)
	add_child(_voz)
	_perfil = Perfil.new(CANAL_PREVIA)
	_voz.finished.connect(_parar_audio)
	_montar_catalogo()
	_filtrar(0)


func _process(delta: float) -> void:
	if _voz.playing and _voz.bus == CANAL_PREVIA:
		_perfil.atualizar(delta)


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
	for cena: String in Catalogo.TRILHAS:
		var arquivo: String = Catalogo.TRILHAS[cena]
		var canal := &"Cinematics" if arquivo.begins_with("Cinematics/") else &"Music"
		_incluir(arquivo, canal, "Trilhas", cena)
	_arquivos.sort_custom(func(a: Dictionary, b: Dictionary): return a.arquivo < b.arquivo)


func _incluir(arquivo: String, canal: StringName, categoria: String, cena := "") -> void:
	if ResourceLoader.exists(Catalogo.PASTA + arquivo, "AudioStream"):
		_arquivos.append({"arquivo": arquivo, "canal": canal, "categoria": categoria, "cena": cena})


func _filtrar(indice: int) -> void:
	_parar_audio()
	_lista.clear()
	_indice = -1
	for entrada: Dictionary in _arquivos:
		if indice != 0 and entrada.categoria != CATEGORIAS[indice]:
			continue
		var item := _lista.add_item(entrada.arquivo)
		_lista.set_item_metadata(item, entrada)
	_ouvir.disabled = _lista.item_count == 0
	if _ouvir.disabled:
		_detalhes.text = "Nenhum arquivo importado nesta categoria."
		_ajuste.hide()
	else:
		_lista.select(0)
		_selecionar(0)


func _selecionar(indice: int) -> void:
	_parar_audio()
	_indice = indice
	var entrada: Dictionary = _lista.get_item_metadata(indice)
	_detalhes.text = "%s  ·  Canal %s" % [entrada.categoria, entrada.canal]
	if entrada.cena in Catalogo.MEMORIAS:
		_titulo_ajuste.text = "Clareza"
		_modo = "memoria"
		_controle.min_value = 0.0
		_controle.max_value = 100.0
	elif entrada.cena == PROGRESSAO.ULTIMO_ECO:
		_titulo_ajuste.text = "Etapa de The Silence"
		_modo = "eco"
		_controle.min_value = 1.0
		_controle.max_value = 3.0
	else:
		_modo = ""
	_ajuste.visible = not _modo.is_empty()
	if _ajuste.visible:
		_controle.set_value_no_signal(_controle.min_value)
		_atualizar_ajuste(_controle.value)


func _atualizar_ajuste(valor: float) -> void:
	if _modo.is_empty():
		return
	_valor.text = "%d%%" % int(valor) if _modo == "memoria" else str(int(valor))
	_perfil.definir(_estado_previa(), not _voz.playing)


func _estado_previa() -> Vector2:
	if _modo == "memoria":
		return Perfil.memoria(_controle.value / 100.0)
	if _modo == "eco":
		return Perfil.eco(int(_controle.value))
	return Perfil.NEUTRO


func _ouvir_selecionado() -> void:
	var selecionados := _lista.get_selected_items()
	if not selecionados.is_empty():
		_reproduzir(selecionados[0])


func _reproduzir(indice: int) -> void:
	if _indice != indice:
		_selecionar(indice)
	else:
		_parar_audio()
	var entrada: Dictionary = _lista.get_item_metadata(indice)
	var som := load(Catalogo.PASTA + entrada.arquivo) as AudioStream
	if som == null:
		_detalhes.text = "Não foi possível carregar " + entrada.arquivo
		return
	var repetir: bool = entrada.canal in [&"Ambient", &"Music"]
	if repetir and som is AudioStreamOggVorbis:
		som = som.duplicate() as AudioStreamOggVorbis
		som.set("loop", true)
	_voz.bus = entrada.canal if _modo.is_empty() else CANAL_PREVIA
	if _voz.bus == CANAL_PREVIA:
		_perfil.definir(_estado_previa(), true)
	_voz.stream = som
	_voz.play()
	_parar.disabled = false
	_detalhes.text = ("Em loop  ·  " if repetir else "Reproduzindo  ·  ") + entrada.arquivo


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
