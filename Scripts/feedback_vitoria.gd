extends RefCounted

# Faixa curta de conquista (clarão opcional + título + subtítulo). Fica abaixo das
# telas de pausa/derrota e acima do jogo, na região central, longe do HUD.

static func faixa(cena: Node, titulo: String, subtitulo := "", cor := Color(1.0, 0.86, 0.5), clarao := 0.0, duracao := 2.6) -> void:
	if cena == null or not cena.is_inside_tree():
		return
	var camada := CanvasLayer.new()
	camada.layer = 70
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	cena.add_child(camada)

	if clarao > 0.0:
		var luz := ColorRect.new()
		luz.color = Color(1.0, 0.97, 0.88, clarao)
		luz.set_anchors_preset(Control.PRESET_FULL_RECT)
		luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		camada.add_child(luz)
		var apagar := luz.create_tween()
		apagar.tween_property(luz, "color:a", 0.0, 0.9)

	var caixa := VBoxContainer.new()
	caixa.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caixa.offset_top = 128.0
	caixa.offset_left = -240.0
	caixa.offset_right = 240.0
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_theme_constant_override("separation", 2)
	camada.add_child(caixa)
	for par in [[titulo, 18, cor], [subtitulo, 12, Color(0.95, 0.9, 0.98)]]:
		if (par[0] as String).is_empty():
			continue
		var texto := Label.new()
		texto.text = par[0]
		texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		texto.add_theme_font_size_override("font_size", par[1])
		texto.add_theme_color_override("font_color", par[2])
		texto.add_theme_color_override("font_outline_color", Color(0.14, 0.07, 0.23))
		texto.add_theme_constant_override("outline_size", 5)
		texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caixa.add_child(texto)

	caixa.modulate.a = 0.0
	var animacao := caixa.create_tween()
	animacao.tween_property(caixa, "modulate:a", 1.0, 0.30)
	animacao.tween_interval(duracao)
	animacao.tween_property(caixa, "modulate:a", 0.0, 0.50)
	animacao.tween_callback(camada.queue_free)
