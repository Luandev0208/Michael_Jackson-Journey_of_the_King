extends "res://Scripts/inimigo_perseguidor.gd"

enum Tipo { COMUM, RAPIDO, ESPECIAL }

const FIGURINOS := [
	preload("res://Assets/Inimigos/BillieJean/DetetiveComum/spriteframes.tres"),
	preload("res://Assets/Inimigos/BillieJean/DetetiveRapido/spriteframes.tres"),
	preload("res://Assets/Inimigos/BillieJean/DetetiveEspecial/spriteframes.tres"),
]
const FLASH := preload("res://Assets/Inimigos/BillieJean/Efeitos/flash_branco.png")
const FLASH_ESPECIAL := preload("res://Assets/Inimigos/BillieJean/Efeitos/flash_especial.png")
const PARTICULAS := preload("res://Assets/Inimigos/BillieJean/Efeitos/particulas.png")
const POSICAO_FLASH := {
	"down": Vector2(0, -25),
	"up": Vector2(0, -44),
	"left": Vector2(-18, -30),
	"right": Vector2(18, -30),
}

var _tipo := Tipo.COMUM


func configurar(tipo: Tipo, obrigatorio: bool) -> void:
	_tipo = tipo
	match tipo:
		Tipo.RAPIDO:
			vida = 1
			velocidade_perseguicao = 70.0
			multiplicador_chapeu = 1.0
		Tipo.ESPECIAL:
			# Fotógrafo: flash longo e visível, resiste ao chapéu e pede chutes.
			vida = 4
			velocidade_perseguicao = 48.0
			preparacao_contato = 0.46
			recarga_contato = 1.25
			armadura_contra_chapeu = true
			resistencia_empurrao = 0.6
		Tipo.COMUM:
			velocidade_perseguicao = 60.0
			preparacao_contato = 0.28
	if obrigatorio:
		# O perseguidor do encontro segue Michael mesmo se ele recuar pela rua.
		set_meta("obrigatorio", true)
		raio_deteccao = 2600.0
		raio_abandono = 2700.0
		_alcance_posto = 2700.0


func _ready() -> void:
	_sprite.sprite_frames = FIGURINOS[_tipo]
	_sprite.play(&"idle_down")
	super._ready()


# Flanqueio: detetives comuns e rápidos contornam Michael pelo lado em vez de
# se enfileirarem atrás dele; o fotógrafo mantém a aproximação direta.
func _destino_perseguicao(distancia: float) -> Vector2:
	if _tipo == Tipo.ESPECIAL or distancia < 64.0:
		return alvo.global_position
	var lado := 1.0 if get_instance_id() % 2 == 0 else -1.0
	var direcao := (alvo.global_position - global_position).normalized()
	var desvio := Vector2(-direcao.y, direcao.x) * lado * minf(distancia - 40.0, 34.0)
	for variante: Vector2 in [desvio, -desvio]:
		var ponto: Vector2 = alvo.global_position + variante
		var celula := Vector2i((ponto / caminhos.cell_size).floor())
		if caminhos.region.has_point(celula) and not caminhos.is_point_solid(celula):
			return ponto
	return alvo.global_position


# Aviso visual antes do flash: um brilho que cresce sobre a câmera.
func _aviso_preparacao() -> void:
	var aviso := Polygon2D.new()
	aviso.name = "AvisoFotografico"
	aviso.polygon = PackedVector2Array([Vector2(0, -6), Vector2(2, -2), Vector2(6, 0), Vector2(2, 2), Vector2(0, 6), Vector2(-2, 2), Vector2(-6, 0), Vector2(-2, -2)])
	aviso.color = Color(1.0, 0.95, 0.6, 0.0)
	aviso.z_index = 3
	add_child(aviso)
	aviso.position = (POSICAO_FLASH[_direcao_visual] as Vector2)
	var tempo := maxf(preparacao_contato, 0.1)
	var efeito := aviso.create_tween().set_parallel()
	efeito.tween_property(aviso, "color:a", 0.95, tempo)
	efeito.tween_property(aviso, "scale", Vector2(1.8, 1.8), tempo)
	efeito.chain().tween_callback(aviso.queue_free)


func _efeito_ataque() -> void:
	# O segundo quadro mostra a câmera levantada no instante do disparo.
	_sprite.set_frame_and_progress(1, 0.0)
	var flash := Sprite2D.new()
	flash.name = "FlashFotografico"
	flash.texture = FLASH_ESPECIAL if _tipo == Tipo.ESPECIAL else FLASH
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.modulate.a = 0.8
	flash.scale = Vector2(0.5, 0.5)
	flash.z_index = 3
	get_parent().add_child(flash)
	flash.global_position = global_position + (POSICAO_FLASH[_direcao_visual] as Vector2)

	var particulas := Sprite2D.new()
	particulas.texture = PARTICULAS
	flash.add_child(particulas)
	var efeito := flash.create_tween().set_parallel()
	efeito.tween_property(flash, "modulate:a", 0.0, 0.16)
	efeito.tween_property(particulas, "scale", Vector2(1.7, 1.7), 0.16)
	efeito.chain().tween_callback(flash.queue_free)
