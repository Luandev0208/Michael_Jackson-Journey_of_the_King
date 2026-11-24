extends CanvasLayer

# Tela de derrota ligada à história: "Eco fragmentado" enquanto há tentativas,
# "Memória apagada" (Game Over) quando acabam.

const PROGRESSAO := preload("res://Scripts/progressao.gd")
const TEMA := preload("res://Assets/tema_menu.tres")
const MAXIMO := 3

var restantes := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	get_tree().paused = true
	var game_over := restantes <= 0

	var fundo := ColorRect.new()
	fundo.color = Color(0.04, 0.02, 0.07, 0.86)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.theme = TEMA
	fundo.add_child(centro)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 8)
	centro.add_child(lista)

	var titulo := Label.new()
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
	contagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contagem.text = "Tentativas restantes:  %d / %d" % [restantes, MAXIMO]
	contagem.add_theme_color_override("font_color", Color(1.0, 0.79, 0.49))
	lista.add_child(contagem)

	var primeiro := _botao(lista, "Recomeçar fase" if game_over else "Tentar novamente", _recomecar if game_over else _tentar_novamente)
	_botao(lista, "Menu principal", _menu)

	fundo.modulate.a = 0.0
	create_tween().tween_property(fundo, "modulate:a", 1.0, 0.45)
	primeiro.grab_focus()


func _botao(pai: Control, texto: String, acao: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.custom_minimum_size = Vector2(190.0, 26.0)
	botao.pressed.connect(acao)
	pai.add_child(botao)
	return botao


func _tentar_novamente() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _recomecar() -> void:
	# Game Over: a fase recomeça com três tentativas novas.
	var TENTATIVAS = load("res://Scripts/tentativas.gd")
	TENTATIVAS.restaurar()
	_tentar_novamente()


func _menu() -> void:
	var TENTATIVAS = load("res://Scripts/tentativas.gd")
	TENTATIVAS.reiniciar()
	get_tree().paused = false
	get_tree().change_scene_to_file(PROGRESSAO.MENU)
