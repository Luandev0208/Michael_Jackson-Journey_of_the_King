extends PanelContainer

const TENTATIVAS := preload("res://Scripts/tentativas.gd")
const CORACAO := preload("res://Assets/Thriller/coracao.png")
const VERDE_META := Color(0.60, 0.96, 0.71)

@export var titulo := ""

var _efeito_pontuacao: Tween
var _cor_contador := Color.WHITE

@onready var tentativas: Label = $Conteudo/Cabecalho/Tentativas
@onready var contador: Label = $Conteudo/Notas
@onready var vidas: Label = $Conteudo/Vidas
@onready var coracoes: HBoxContainer = $Conteudo/Vidas/Coracoes
@onready var moonwalk: Label = $Conteudo/Moonwalk
@onready var dash: Label = $Conteudo/Dash


func _ready() -> void:
	$Conteudo/Cabecalho/Titulo.text = titulo


func iniciar(jogador: MichaelJogador) -> void:
	for i in MichaelJogador.VIDA_MAXIMA:
		var icone := TextureRect.new()
		icone.texture = CORACAO
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coracoes.add_child(icone)
	tentativas.visible = TENTATIVAS.ativa_em(get_parent().get_parent())
	if tentativas.visible:
		jogador.tentativas_alteradas.connect(_atualizar_tentativas)
		_atualizar_tentativas(TENTATIVAS.restantes)
	jogador.vida_alterada.connect(_atualizar_vidas)
	_atualizar_vidas(jogador.vida)


func _atualizar_tentativas(restantes: int) -> void:
	tentativas.text = "Tentativas %d/%d" % [restantes, TENTATIVAS.MAXIMO]


func atualizar_pontos(coletadas: int, total: int, pontos: int, meta := 0) -> void:
	if meta <= 0:
		contador.text = "Notas  %d/%d     Pontos  %d" % [coletadas, total, pontos]
		return
	var atingiu_meta := coletadas >= meta
	_cor_contador = VERDE_META if atingiu_meta else Color.WHITE
	var estado_meta := " · Meta atingida" if atingiu_meta else " (meta)"
	contador.text = "Notas  %d/%d%s  ·  %d pts" % [coletadas, meta, estado_meta, pontos]
	contador.modulate = _cor_contador


func destacar_pontos() -> void:
	if _efeito_pontuacao != null:
		_efeito_pontuacao.kill()
	contador.modulate = Color(1.0, 0.76, 0.32) if _cor_contador == Color.WHITE else _cor_contador.lerp(Color.WHITE, 0.35)
	_efeito_pontuacao = create_tween()
	_efeito_pontuacao.tween_property(contador, "modulate", _cor_contador, 0.55)


func _atualizar_vidas(restantes: int) -> void:
	vidas.text = "Vidas  %d/%d" % [restantes, MichaelJogador.VIDA_MAXIMA]
	for i in coracoes.get_child_count():
		var icone: TextureRect = coracoes.get_child(i)
		icone.modulate = Color.WHITE if i < restantes else Color(0.50, 0.43, 0.53, 0.48)


func atualizar_recargas(jogador: MichaelJogador) -> void:
	var recarga_dash := jogador.tempo_dash()
	dash.text = "Dash  ·  %.1f s" % (ceilf(recarga_dash * 10.0) / 10.0) if recarga_dash > 0.0 else "Dash  ·  Pronto"
	var restante := jogador.tempo_moonwalk()
	if jogador.em_moonwalk():
		moonwalk.text = "Moonwalk  ·  Esquiva"
		moonwalk.modulate = Color(0.64, 0.90, 1.0)
	elif restante > 0.0:
		moonwalk.text = "Moonwalk  ·  %.1f s" % (ceilf(restante * 10.0) / 10.0)
		moonwalk.modulate = Color(0.72, 0.75, 0.79)
	else:
		moonwalk.text = "Moonwalk  ·  Pronto"
		moonwalk.modulate = Color(1.0, 0.86, 0.62)
