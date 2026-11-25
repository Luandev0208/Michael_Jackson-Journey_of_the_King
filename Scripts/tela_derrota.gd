extends CanvasLayer

# Tela de derrota ligada à história: "Eco fragmentado" enquanto há tentativas,
# "Memória apagada" (Game Over) quando acabam.

const PROGRESSAO := preload("res://Scripts/progressao.gd")
const TEMA := preload("res://Assets/tema_menu.tres")

var restantes := 0
var _pausa_anterior := false
var _saindo := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_pausa_anterior = get_tree().paused
	get_tree().paused = true
	var game_over := restantes <= 0
	AudioManager.tocar(&"game_over" if game_over else &"derrota")

	var fundo := ColorRect.new()
	fundo.name = "Fundo"
	fundo.color = Color(0.04, 0.02, 0.07, 0.86)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.theme = TEMA
	fundo.add_child(centro)
	var lista := VBoxContainer.new()
	lista.name = "Opcoes"
	lista.add_theme_constant_override("separation", 8)
	centro.add_child(lista)

	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.text = "GAME OVER — MEMÓRIA APAGADA" if game_over else "ECO FRAGMENTADO"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.36, 0.36) if game_over else Color(0.82, 0.62, 1.0))
	lista.add_child(titulo)

	var frase := Label.new()
	frase.text = "The Silence apagou esta lembrança.\nMas a música ainda pode voltar." if game_over else "A memória está se desfazendo..."
	frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frase.add_theme_font_size_override("font_size", 13)
	frase.add_theme_color_override("font_color", Color(0.92, 0.86, 0.95))
	lista.add_child(frase)

	var contagem := Label.new()
	contagem.name = "Tentativas"
	contagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tentativas := load("res://Scripts/tentativas.gd") as Script
	contagem.text = "Tentativas restantes:  %d / %d" % [restantes, tentativas.MAXIMO]
	contagem.add_theme_color_override("font_color", Color(1.0, 0.79, 0.49))
	lista.add_child(contagem)

	var primeiro := _botao(lista, "Continuar", "Recomeçar fase" if game_over else "Tentar novamente", _tentar_novamente)
	_botao(lista, "Menu", "Menu principal", _menu)

	fundo.modulate.a = 0.0
	create_tween().tween_property(fundo, "modulate:a", 1.0, 0.45)
	primeiro.grab_focus()


func _exit_tree() -> void:
	get_tree().paused = _pausa_anterior


func _botao(pai: Control, nome: String, texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.name = nome
	botao.text = texto
	botao.custom_minimum_size = Vector2(190.0, 26.0)
	botao.pressed.connect(acao)
	pai.add_child(botao)
	return botao


func _tentar_novamente() -> void:
	if _saindo:
		return
	_saindo = true
	var zerou := restantes <= 0
	if get_tree().reload_current_scene() != OK:
		_saindo = false
		return
	if zerou:
		var tentativas := load("res://Scripts/tentativas.gd") as Script
		tentativas.restaurar()


func _menu() -> void:
	if _saindo:
		return
	_saindo = true
	if get_tree().change_scene_to_file(PROGRESSAO.MENU) != OK:
		_saindo = false
