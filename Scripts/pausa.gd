extends CanvasLayer

const PROGRESSAO := preload("res://Scripts/progressao.gd")
const TEMA := preload("res://Assets/tema_menu.tres")

var _painel := PanelContainer.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	add_child(_painel)
	_painel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_painel.offset_left = -106
	_painel.offset_right = 106
	_painel.offset_top = -62
	_painel.offset_bottom = 62
	_painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_painel.theme = TEMA
	var lista := VBoxContainer.new()
	_painel.add_child(lista)
	var titulo := Label.new()
	titulo.text = "Pausa"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lista.add_child(titulo)
	var retomar := Button.new()
	retomar.text = "Retomar"
	retomar.pressed.connect(_retomar)
	lista.add_child(retomar)
	var sair := Button.new()
	sair.text = "Menu principal"
	sair.pressed.connect(_sair)
	lista.add_child(sair)
	_painel.hide()

func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("ui_cancel") or evento.is_echo():
		return
	var menu_dev := get_node_or_null("/root/MenuDev/PainelDev") as Control
	if menu_dev != null and menu_dev.visible:
		return
	var jogador := get_parent() as MichaelJogador
	if jogador.vida <= 0 or (not jogador.can_process() and not _painel.visible):
		return
	if _painel.visible:
		_retomar()
	else:
		get_tree().paused = true
		_painel.show()
	get_viewport().set_input_as_handled()

func _retomar() -> void:
	_painel.hide()
	get_tree().paused = false

func _sair() -> void:
	_retomar()
	get_tree().change_scene_to_file(PROGRESSAO.MENU)
