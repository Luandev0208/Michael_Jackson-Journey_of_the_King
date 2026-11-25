extends PanelContainer

signal fechar_solicitado

@onready var _grade: GridContainer = $Conteudo/Volumes


func _ready() -> void:
	for canal: StringName in AudioManager.CANAIS:
		var controle := _grade.get_node(String(canal)) as HSlider
		controle.value_changed.connect(_alterar.bind(canal))
	AudioManager.volumes_alterados.connect(_atualizar)
	_atualizar()


func abrir() -> void:
	_atualizar()
	show()
	_grade.get_node("Master").grab_focus()


func _atualizar() -> void:
	for canal: StringName in AudioManager.CANAIS:
		var controle := _grade.get_node(String(canal)) as HSlider
		var leitura := _grade.get_node(String(canal) + "Valor") as Label
		var percentual := roundi(AudioManager.volume(canal) * 100.0)
		controle.set_value_no_signal(percentual)
		leitura.text = "%d%%" % percentual


func _alterar(percentual: float, canal: StringName) -> void:
	AudioManager.definir_volume(canal, percentual / 100.0)


func _restaurar() -> void:
	AudioManager.restaurar_padroes()


func _voltar() -> void:
	fechar_solicitado.emit()
