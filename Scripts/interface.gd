extends Control

const PROGRESSAO := preload("res://Scripts/progressao.gd")

@onready var menu: PanelContainer = $PainelCentral
@onready var ajuda: PanelContainer = $Ajuda
@onready var botao_ajuda: Button = $PainelCentral/VBoxContainer/BotaoAjuda
@onready var botao_voltar: Button = $Ajuda/Conteudo/BotaoVoltar

func _ready() -> void:
	botao_voltar.pressed.connect(_voltar_da_ajuda)

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file(PROGRESSAO.CAMARIM)

func _on_ajuda_pressed() -> void:
	menu.hide()
	ajuda.show()
	botao_voltar.grab_focus()

func _voltar_da_ajuda() -> void:
	ajuda.hide()
	menu.show()
	botao_ajuda.grab_focus()

func _on_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/créditos.tscn")

func _on_button_3_pressed() -> void:
	get_tree().quit()
