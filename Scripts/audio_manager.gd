extends Node2D

signal volumes_alterados

const Catalogo := preload("res://Scripts/catalogo_audio.gd")
const PROGRESSAO := preload("res://Scripts/progressao.gd")
const Perfil := preload("res://Scripts/perfil_musical.gd")
const ROTAS_MUSICA: Array[StringName] = [&"MusicA", &"MusicB"]
const PASTAS_ALTERNATIVAS := ["user://musicas/", "res://Assets/Audio/Alternativas/"]
const CAMINHO_PREFERENCIAS := "user://audio.cfg"
const CANAIS: Array[StringName] = [&"Master", &"Music", &"SFX", &"Ambient"]
const VOLUME_PADRAO := 1.0
const TRANSICAO := 0.65
const PISO_DB := -80.0
const VOZES_2D := 12
const VOZES_1D := 8
const LIMITE_POR_EVENTO := 2
const INTERVALO_EFEITO := 0.055


class Camada:
	var vozes: Array[AudioStreamPlayer] = []
	var atual: AudioStreamPlayer
	var faixa: AudioStream
	var transicao: Tween


var _musica := Camada.new()
var _ambiente := Camada.new()
var _efeitos: Array[AudioStreamPlayer] = []
var _espaciais: Array[AudioStreamPlayer2D] = []
var _recursos: Dictionary[String, AudioStream] = {}
var _ultimas_variantes: Dictionary[StringName, String] = {}
var _ultimo_toque: Dictionary[StringName, float] = {}
var _volumes: Dictionary[StringName, float] = {}
var _relogio := 0.0
var _salvar_em := -1.0
var _pausado := false
var _aleatorio := RandomNumberGenerator.new()
var _perfis: Dictionary[StringName, Perfil] = {}
var _tempo_recuo_musical := 0.0
var _latencia_saida := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_latencia_saida = AudioServer.get_output_latency()
	for rota: StringName in ROTAS_MUSICA:
		_perfis[rota] = Perfil.new(rota)
	for camada in [_musica, _ambiente]:
		for i in 2:
			var voz := AudioStreamPlayer.new()
			camada.vozes.append(voz)
			add_child(voz)
			voz.finished.connect(_repetir.bind(camada, voz))
	for i in VOZES_1D:
		var voz := AudioStreamPlayer.new()
		_efeitos.append(voz)
		add_child(voz)
	for i in VOZES_2D:
		var voz := AudioStreamPlayer2D.new()
		voz.max_distance = 440.0
		_espaciais.append(voz)
		add_child(voz)
	_carregar_volumes()
	get_tree().scene_changed.connect(_mudar_cena)
	get_tree().node_added.connect(_observar_interface)
	_mudar_cena.call_deferred()


func _process(delta: float) -> void:
	_relogio += delta
	if _salvar_em >= 0.0:
		_salvar_em -= delta
		if _salvar_em <= 0.0:
			_salvar_volumes()
	var pausado := get_tree().paused
	if _pausado != pausado:
		_pausado = pausado
		for camada in [_musica, _ambiente]:
			for voz in camada.vozes:
				voz.stream_paused = pausado
		for voz in _espaciais:
			voz.stream_paused = pausado
		for voz in _efeitos:
			if voz.bus != &"UI":
				voz.stream_paused = pausado
	if not pausado:
		_tempo_recuo_musical = maxf(0.0, _tempo_recuo_musical - delta)
		for perfil: Perfil in _perfis.values():
			perfil.atualizar(delta, _tempo_recuo_musical > 0.0)


func _exit_tree() -> void:
	if _salvar_em >= 0.0:
		_salvar_volumes()


func volume(canal: StringName) -> float:
	return _volumes.get(canal, VOLUME_PADRAO)


func definir_volume(canal: StringName, valor: float) -> void:
	if canal not in CANAIS or not is_finite(valor):
		return
	valor = clampf(valor, 0.0, 1.0)
	if is_equal_approx(volume(canal), valor):
		return
	_aplicar_volume(canal, valor)
	_salvar_em = 0.25
	volumes_alterados.emit()


func restaurar_padroes() -> void:
	for canal in CANAIS:
		_aplicar_volume(canal, VOLUME_PADRAO)
	_salvar_volumes()
	volumes_alterados.emit()


func _carregar_volumes() -> void:
	var config := ConfigFile.new()
	config.load(CAMINHO_PREFERENCIAS)
	for canal in CANAIS:
		var valor: Variant = config.get_value("volume", String(canal), VOLUME_PADRAO)
		if not (valor is float or valor is int) or not is_finite(float(valor)):
			valor = VOLUME_PADRAO
		_aplicar_volume(canal, clampf(float(valor), 0.0, 1.0))


func _aplicar_volume(canal: StringName, valor: float) -> void:
	_volumes[canal] = valor
	var indice := AudioServer.get_bus_index(canal)
	AudioServer.set_bus_volume_db(indice, _decibeis(valor))
	AudioServer.set_bus_mute(indice, valor <= 0.0)


func _salvar_volumes() -> void:
	_salvar_em = -1.0
	var config := ConfigFile.new()
	for canal in CANAIS:
		config.set_value("volume", String(canal), volume(canal))
	var erro := config.save(CAMINHO_PREFERENCIAS)
	if erro != OK:
		push_warning("Não foi possível salvar as preferências de áudio: %s" % error_string(erro))


func _mudar_cena() -> void:
	var cena := get_tree().current_scene
	if cena == null:
		return
	if cena.tree_exiting.is_connected(_limpar_cena):
		return
	cena.tree_exiting.connect(_limpar_cena, CONNECT_ONE_SHOT)
	var caminho := cena.scene_file_path
	if caminho == PROGRESSAO.CREDITOS:
		preparar_creditos()
		return
	var trilha: String = Catalogo.TRILHAS.get(caminho, "")
	var canal := &"Cinematics" if trilha.begins_with("Cinematics/") else &"Music"
	var estado := Perfil.NEUTRO
	if caminho in Catalogo.MEMORIAS:
		estado = Perfil.memoria(0.0)
	elif caminho == PROGRESSAO.ULTIMO_ECO:
		estado = Perfil.eco(1)
	_trocar_faixa(_musica, _carregar_trilha(caminho, trilha), canal, TRANSICAO, estado)
	_trocar_faixa(_ambiente, _carregar(Catalogo.AMBIENTES.get(caminho, "")), &"Ambient", TRANSICAO)


func atualizar_clareza(cena: Node, coletadas: int, meta: int) -> void:
	if _cena_musical_atual(cena) and cena.scene_file_path in Catalogo.MEMORIAS and meta > 0:
		_atualizar_perfil_atual(Perfil.memoria(float(coletadas) / float(meta)))


func atualizar_intensidade(cena: Node, etapa: int) -> void:
	if _cena_musical_atual(cena) and cena.scene_file_path == PROGRESSAO.ULTIMO_ECO:
		_atualizar_perfil_atual(Perfil.eco(etapa))


func _cena_musical_atual(cena: Node) -> bool:
	return cena == get_tree().current_scene and cena.tree_exiting.is_connected(_limpar_cena)


func _atualizar_perfil_atual(estado: Vector2) -> void:
	if _musica.atual != null and _perfis.has(_musica.atual.bus):
		_perfis[_musica.atual.bus].definir(estado)


func encerrar_trilha_cinematica(cena: Node) -> void:
	if cena != get_tree().current_scene:
		return
	if _musica.atual != null and _musica.atual.bus == &"Cinematics":
		_trocar_faixa(_musica, null, &"Cinematics", 0.22)
	for voz in _efeitos:
		if voz.bus == &"Cinematics":
			voz.stop()


func tempo_cinematica() -> float:
	var voz := _musica.atual
	if DisplayServer.get_name() == "headless" or voz == null or voz.bus != &"Cinematics" or not voz.playing:
		return -1.0
	return maxf(0.0, voz.get_playback_position() + AudioServer.get_time_since_last_mix() - _latencia_saida)


func avancar_cinematica(sequencia: Tween, delta: float) -> void:
	if sequencia == null or not sequencia.is_valid():
		return
	var tempo := tempo_cinematica()
	# O relógio de áudio prevalece quando há trilha. Sem ela, o roteiro usa o delta.
	var passo := delta if tempo < 0.0 else maxf(0.0, tempo - sequencia.get_total_elapsed_time())
	sequencia.custom_step(passo)


func _limpar_cena() -> void:
	for voz in _espaciais:
		voz.stop()
	for voz in _efeitos:
		var evento: StringName = voz.get_meta("evento", &"")
		if evento not in [&"ui_clique", &"portal"]:
			voz.stop()
	_ultimo_toque.clear()
	_tempo_recuo_musical = 0.0


func preparar_creditos() -> void:
	_trocar_faixa(_musica, null, &"Music", 0.0)
	_trocar_faixa(_ambiente, null, &"Ambient", 0.0)
	for voz in _efeitos:
		voz.stop()
	for voz in _espaciais:
		voz.stop()


func _carregar_trilha(cena: String, original: String) -> AudioStream:
	if cena in Catalogo.MEMORIAS:
		for pasta: String in PASTAS_ALTERNATIVAS:
			var caminho := pasta + original.get_file()
			if not FileAccess.file_exists(caminho):
				continue
			if _recursos.has(caminho):
				return _recursos[caminho]
			var arquivo := FileAccess.open(caminho, FileAccess.READ)
			if arquivo == null or arquivo.get_buffer(4).get_string_from_ascii() != "OggS":
				continue
			arquivo.close()
			var alternativa := AudioStreamOggVorbis.load_from_file(caminho)
			if alternativa != null and alternativa.get_length() > 0.0:
				_recursos[caminho] = alternativa
				return alternativa
	return _carregar(original)


func _carregar(caminho: String) -> AudioStream:
	if caminho.is_empty():
		return null
	if _recursos.has(caminho):
		return _recursos[caminho]
	var absoluto := Catalogo.PASTA + caminho
	if not ResourceLoader.exists(absoluto, "AudioStream"):
		return null
	var som := ResourceLoader.load(absoluto, "AudioStream") as AudioStream
	if som != null:
		_recursos[caminho] = som
	return som


func _trocar_faixa(camada: Camada, faixa: AudioStream, canal: StringName, duracao: float, estado := Perfil.NEUTRO) -> void:
	if duracao <= 0.0:
		if camada.transicao != null:
			camada.transicao.kill()
		camada.atual = null
		camada.faixa = null
		for voz in camada.vozes:
			_liberar_faixa(voz)
		return
	if faixa == camada.faixa and (faixa == null or (camada.atual.playing and camada.atual.bus == _rota(camada.atual, canal))):
		if canal == &"Music" and faixa != null:
			_perfis[camada.atual.bus].definir(estado)
		return
	if camada.transicao != null:
		camada.transicao.kill()
	var anterior := camada.atual
	camada.faixa = faixa
	camada.atual = null
	if faixa != null:
		# Se a trilha ainda está saindo, reaproveita sua voz quando o destino volta a ser o mesmo.
		for voz in camada.vozes:
			if voz.playing and voz.get_meta("faixa", null) == faixa and voz.bus == _rota(voz, canal):
				camada.atual = voz
				if canal == &"Music":
					_perfis[voz.bus].definir(estado)
				break
		if camada.atual == null:
			var voz := camada.vozes[1] if anterior == camada.vozes[0] else camada.vozes[0]
			if anterior == null and camada.vozes[0].playing:
				voz = camada.vozes[1]
			voz.stop()
			voz.bus = _rota(voz, canal)
			if canal == &"Music":
				_perfis[voz.bus].definir(estado, true)
			voz.volume_db = PISO_DB
			voz.stream = faixa if canal == &"Cinematics" else _para_loop(faixa)
			voz.set_meta("faixa", faixa)
			voz.play()
			voz.stream_paused = get_tree().paused
			camada.atual = voz
	camada.transicao = create_tween().set_parallel()
	camada.transicao.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	for voz in camada.vozes:
		if not voz.playing:
			continue
		var ganho := 1.0 if voz == camada.atual else 0.0
		camada.transicao.tween_method(_aplicar_ganho.bind(voz), db_to_linear(voz.volume_db), ganho, duracao)
	camada.transicao.chain().tween_callback(_limpar_faixas.bind(camada))


func _rota(voz: AudioStreamPlayer, canal: StringName) -> StringName:
	if canal == &"Music":
		return ROTAS_MUSICA[_musica.vozes.find(voz)]
	return canal


func _para_loop(faixa: AudioStream) -> AudioStream:
	if faixa is AudioStreamOggVorbis or faixa is AudioStreamMP3:
		var copia := faixa.duplicate() as AudioStream
		copia.set("loop", true)
		return copia
	return faixa


func _repetir(camada: Camada, voz: AudioStreamPlayer) -> void:
	if voz == camada.atual and camada.faixa != null and voz.bus != &"Cinematics":
		voz.play()


func _limpar_faixas(camada: Camada) -> void:
	for voz in camada.vozes:
		if voz != camada.atual:
			_liberar_faixa(voz)


func _liberar_faixa(voz: AudioStreamPlayer) -> void:
	voz.stop()
	voz.stream = null
	if voz.has_meta("faixa"):
		voz.remove_meta("faixa")


func _aplicar_ganho(ganho: float, voz: AudioStreamPlayer) -> void:
	voz.volume_db = _decibeis(ganho)


func _decibeis(ganho: float) -> float:
	return maxf(PISO_DB, linear_to_db(maxf(0.0001, ganho)))


func tocar_passo(posicao: Vector2) -> void:
	var material := Catalogo.superficie(get_tree().current_scene, posicao)
	tocar(StringName("passo_" + material), posicao)


func tocar(evento: StringName, posicao := Vector2.INF) -> bool:
	var canal := Catalogo.canal(evento)
	if get_tree().paused and canal != &"UI":
		return false
	if _relogio - _ultimo_toque.get(evento, -1.0) < INTERVALO_EFEITO:
		return false
	var tocando := 0
	for voz in _efeitos:
		if voz.playing and voz.get_meta("evento", &"") == evento:
			tocando += 1
	for voz in _espaciais:
		if voz.playing and voz.get_meta("evento", &"") == evento:
			tocando += 1
	if tocando >= LIMITE_POR_EVENTO:
		return false

	var vozes: Array = _espaciais if posicao.is_finite() and canal == &"SFX" else _efeitos
	for voz in vozes:
		if not voz.playing:
			var faixa := _sortear(evento, canal)
			if faixa == null:
				return false
			voz.set_meta("evento", evento)
			voz.bus = canal
			voz.stream = faixa
			voz.stream_paused = false
			voz.pitch_scale = _aleatorio.randf_range(0.96, 1.04) if canal == &"SFX" else 1.0
			if voz is AudioStreamPlayer2D:
				voz.global_position = posicao
			voz.play()
			_ultimo_toque[evento] = _relogio
			if evento == &"chefe_aviso":
				_tempo_recuo_musical = 0.28
			return true
	return false


func _sortear(evento: StringName, canal: StringName) -> AudioStream:
	var disponiveis: Dictionary[String, AudioStream] = {}
	for arquivo: String in Catalogo.arquivos(evento):
		var som := _carregar("%s/%s" % [canal, arquivo])
		if som != null:
			disponiveis[arquivo] = som
	if disponiveis.is_empty():
		return null
	if disponiveis.size() > 1:
		disponiveis.erase(_ultimas_variantes.get(evento, ""))
	var nomes := disponiveis.keys()
	var escolhido: String = nomes[_aleatorio.randi_range(0, nomes.size() - 1)]
	_ultimas_variantes[evento] = escolhido
	return disponiveis[escolhido]


func _observar_interface(no: Node) -> void:
	if no is BaseButton and not no.pressed.is_connected(_clique):
		no.pressed.connect(_clique)


func _clique() -> void:
	tocar(&"ui_clique")
