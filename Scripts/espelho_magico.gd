class_name EspelhoMagico
extends Node2D

const COR := Color(0.69, 0.63, 1.0)
const DURACAO := 1.90

var intensidade := 0.0
var _tempo := 0.0


static func instalar(fase: Node2D, centro: Vector2) -> EspelhoMagico:
	var efeito := EspelhoMagico.new()
	efeito.name = "EnergiaDoEspelho"
	efeito.z_index = 3
	fase.add_child(efeito)
	efeito.global_position = centro
	return efeito


func _process(delta: float) -> void:
	_tempo += delta
	queue_redraw()


func _draw() -> void:
	var pulso := (1.0 + sin(_tempo * 3.2)) * 0.5
	for i in 5:
		var raio := Vector2(23.0 + i * 5.0, 35.0 + i * 6.0)
		var cor := COR
		cor.a = (0.014 + 0.013 * pulso + intensidade * 0.042) * (1.0 - i * 0.13)
		var pontos := PackedVector2Array()
		for passo in 16:
			pontos.append((Vector2.RIGHT.rotated(TAU * passo / 16.0) * raio).round())
		draw_colored_polygon(pontos, cor)
	for i in 10 + int(intensidade * 16.0):
		var fase := fposmod(_tempo * (0.31 + intensidade * 0.27) + i * 0.381966, 1.0)
		var x := sin(i * 2.4 + fase * 2.2) * (12.0 + (i % 6) * 4.0)
		var y := 34.0 - fase * 78.0
		var cor := COR.lerp(Color(1.0, 0.86, 0.60), float(i % 3) / 3.0)
		cor.a = sin(fase * PI) * (0.36 + intensidade * 0.53)
		var tamanho := 2.0 if i % 4 == 0 else 1.0
		draw_rect(Rect2(Vector2(x, y).round(), Vector2.ONE * tamanho), cor)


func atravessar(jogador: MichaelJogador, apoio: Vector2, destino: Callable, ao_falhar := Callable()) -> void:
	if jogador.atravessando_espelho:
		return
	jogador.iniciar_travessia(jogador.colisor.global_position.direction_to(apoio))
	var arvore := get_tree()
	var origem := jogador.global_position
	var base := apoio - jogador.colisor.position
	var camada := CanvasLayer.new()
	camada.name = "TransicaoDeEspelho"
	camada.layer = 76
	arvore.root.add_child(camada)
	var cortina := ColorRect.new()
	cortina.color = Color(0.025, 0.018, 0.044, 0.0)
	cortina.mouse_filter = Control.MOUSE_FILTER_STOP
	camada.add_child(cortina)
	cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var andar := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	andar.tween_property(jogador, "global_position", base, 0.48)
	andar.parallel().tween_property(self, "intensidade", 0.62, 0.48)
	andar.tween_callback(jogador.iniciar_travessia.bind(Vector2.UP))
	andar.tween_callback(func(): AudioManager.tocar(&"portal"))
	andar.tween_property(jogador, "global_position", base.lerp(global_position, 0.77), 0.90)
	andar.parallel().tween_property(self, "intensidade", 1.0, 0.64)
	andar.parallel().tween_property(jogador.sprite, "modulate:a", 0.0, 0.75).set_delay(0.14)
	andar.tween_property(cortina, "color:a", 1.0, DURACAO - 1.38)
	await andar.finished
	var revelar := camada.create_tween()
	revelar.pause()
	revelar.tween_property(cortina, "color:a", 0.0, 0.40)
	revelar.tween_callback(camada.queue_free)
	var erro: Error = destino.call()
	if erro == OK:
		arvore.scene_changed.connect(revelar.play, CONNECT_ONE_SHOT)
	else:
		jogador.global_position = origem
		jogador.sprite.modulate.a = 1.0
		jogador.atravessando_espelho = false
		intensidade = 0.0
		push_error("Falha ao atravessar o espelho: %s" % error_string(erro))
		if ao_falhar.is_valid():
			ao_falhar.call()
		revelar.play()
