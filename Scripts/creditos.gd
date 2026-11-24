extends Control

const PROGRESSAO := preload("res://Scripts/progressao.gd")

@onready var video := get_node_or_null("Video") as VideoStreamPlayer
@onready var botao_pular := get_node_or_null("BotaoPular") as Button

var _encerrando := false


func _ready() -> void:
	if video == null:
		return
	video.finished.connect(_voltar_ao_menu)
	botao_pular.pressed.connect(_voltar_ao_menu)
	botao_pular.grab_focus()
	video.play()
	# Se o vídeo não carregar ou não iniciar, não deixa o jogador preso numa tela preta.
	await get_tree().create_timer(1.0).timeout
	if not _encerrando and (video.stream == null or not video.is_playing()):
		push_warning("Créditos: o vídeo não iniciou. Voltando ao menu.")
		_voltar_ao_menu()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_voltar_ao_menu()


func _voltar_ao_menu() -> void:
	if _encerrando:
		return
	_encerrando = true
	if video != null:
		video.stop()
	get_tree().change_scene_to_file(PROGRESSAO.MENU)
