extends RefCounted

const NEUTRO := Vector2(1.0, 0.0)
const ETAPAS_ECO := [Vector2(0.37, -3.3), Vector2(0.66, -1.7), NEUTRO]
const CORTE_MINIMO := 1450.0
const CORTE_MAXIMO := 19600.0
const TEMPO_AJUSTE := 0.24

var _indice: int
var _filtro := AudioEffectLowPassFilter.new()
var _ganho := AudioEffectAmplify.new()
var _estado := NEUTRO
var _alvo := NEUTRO
var _recuo_db := 0.0


func _init(canal: StringName) -> void:
	_indice = AudioServer.get_bus_index(canal)
	_filtro.db = AudioEffectFilter.FILTER_12DB
	_filtro.resonance = 0.5
	AudioServer.add_bus_effect(_indice, _filtro)
	AudioServer.add_bus_effect(_indice, _ganho)
	_aplicar()


static func memoria(clareza: float) -> Vector2:
	var parte := clampf(clareza, 0.0, 1.0)
	return Vector2(parte, lerpf(-1.2, 0.0, parte))


static func eco(etapa: int) -> Vector2:
	return ETAPAS_ECO[clampi(etapa - 1, 0, ETAPAS_ECO.size() - 1)]


func definir(estado: Vector2, imediato := false) -> void:
	_alvo = estado
	if imediato:
		_estado = estado
		_recuo_db = 0.0
		_aplicar()


func atualizar(delta: float, recuar := false) -> void:
	var destino_db := -3.5 if recuar else 0.0
	if _estado == _alvo and is_equal_approx(_recuo_db, destino_db):
		return
	_estado = _estado.lerp(_alvo, 1.0 - exp(-delta / TEMPO_AJUSTE))
	if _estado.distance_to(_alvo) < 0.008:
		_estado = _alvo
	var ajuste := 0.045 if recuar else 0.20
	_recuo_db = lerpf(_recuo_db, destino_db, 1.0 - exp(-delta / ajuste))
	if absf(_recuo_db - destino_db) < 0.01:
		_recuo_db = destino_db
	_aplicar()


func _aplicar() -> void:
	_filtro.cutoff_hz = CORTE_MINIMO * pow(CORTE_MAXIMO / CORTE_MINIMO, _estado.x)
	var filtrado := _estado.x < 0.998
	if AudioServer.is_bus_effect_enabled(_indice, 0) != filtrado:
		AudioServer.set_bus_effect_enabled(_indice, 0, filtrado)
	_ganho.volume_db = _estado.y + _recuo_db
