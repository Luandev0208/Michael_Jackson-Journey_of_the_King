extends RefCounted

const DIRECOES := ["up", "down", "left", "right"]
static var _cache: Dictionary[int, SpriteFrames] = {}


static func ampliar(original: SpriteFrames) -> SpriteFrames:
	if original == null:
		return null
	var id := original.get_instance_id()
	if _cache.has(id):
		return _cache[id]
	var quadros := original.duplicate() as SpriteFrames
	for d: String in DIRECOES:
		_montar(quadros, "finta_" + d, d, [["idle", 0], ["walk", 1], ["walk", 3], ["prepare", 0]])
		_montar(quadros, "corrida_" + d, d, [["prepare", 1], ["attack", 0], ["attack", 1], ["attack", 2], ["walk", 2]])
		_montar(quadros, "retomada_" + d, d, [["attack", 3], ["prepare", 0], ["idle", 0]])
		_montar(quadros, "pesado_" + d, d, [["attack", 1], ["attack", 1], ["attack", 2], ["attack", 3], ["prepare", 0]])
	_cache[id] = quadros
	return quadros


static func _montar(quadros: SpriteFrames, novo: String, direcao: String, poses: Array) -> void:
	var texturas: Array[Texture2D] = []
	for pose: Array in poses:
		var fonte: String = pose[0] + "_" + direcao
		if quadros.has_animation(fonte) and quadros.get_frame_count(fonte) > 0:
			texturas.append(quadros.get_frame_texture(fonte, mini(pose[1], quadros.get_frame_count(fonte) - 1)))
	if texturas.size() >= 2:
		quadros.add_animation(novo)
		quadros.set_animation_speed(novo, 14.0)
		quadros.set_animation_loop(novo, false)
		for textura in texturas:
			quadros.add_frame(novo, textura)
