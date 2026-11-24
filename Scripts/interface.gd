extends Control

const PROGRESSAO := preload("res://Scripts/progressao.gd")
const TENTATIVAS := preload("res://Scripts/tentativas.gd")
const CENA_CREDITOS := "res://Scenes/creditos.tscn"

@onready var menu: PanelContainer = $PainelCentral
@onready var ajuda: PanelContainer = $Ajuda
@onready var botao_ajuda: Button = $PainelCentral/VBoxContainer/BotaoAjuda
@onready var botao_voltar: Button = $Ajuda/Conteudo/BotaoVoltar

var _aviso_creditos: ConfirmationDialog

func _ready() -> void:
	TENTATIVAS.reiniciar()
	botao_voltar.pressed.connect(_voltar_da_ajuda)
	_aviso_creditos = ConfirmationDialog.new()
	_aviso_creditos.title = "Créditos"
	_aviso_creditos.dialog_text = "Os créditos são exibidos automaticamente depois que você termina o jogo.\n\nQuer assistir aos créditos agora?"
	_aviso_creditos.ok_button_text = "Assistir agora"
	_aviso_creditos.cancel_button_text = "Voltar"
	_aviso_creditos.confirmed.connect(_assistir_creditos)
	add_child(_aviso_creditos)

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file(PROGRESSAO.INTRODUCAO)

func _on_ajuda_pressed() -> void:
	menu.hide()
	ajuda.show()
	botao_voltar.grab_focus()

func _voltar_da_ajuda() -> void:
	ajuda.hide()
	menu.show()
	botao_ajuda.grab_focus()

func _on_button_2_pressed() -> void:
	_aviso_creditos.popup_centered()

func _assistir_creditos() -> void:
	get_tree().change_scene_to_file(CENA_CREDITOS)

func _on_button_3_pressed() -> void:
	get_tree().quit()
