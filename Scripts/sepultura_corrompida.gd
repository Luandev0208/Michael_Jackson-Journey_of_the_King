extends StaticBody2D

const ARTE := preload("res://Assets/Thriller/objetos/tumulo_laje.png")
var vida := 3
var _restantes := 2
var _tempo := 2.0
var _fase: Node2D
var _arte := Sprite2D.new()

func iniciar(fase: Node2D) -> void:
	_fase = fase
	collision_layer = 4
	collision_mask = 0
	var alvo := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(30, 19)
	alvo.shape = forma
	add_child(alvo)
	_arte.texture = ARTE
	_arte.position.y = -27.0
	_arte.modulate = Color(0.82, 0.50, 1.0)
	add_child(_arte)
	var brilho := Polygon2D.new()
	brilho.polygon = PackedVector2Array([-16, 3, -11, -6, 16, -6, 20, 4, 0, 11])
	brilho.color = Color(0.74, 0.27, 1.0, 0.65)
	add_child(brilho)

func _physics_process(delta: float) -> void:
	if vida <= 0 or _restantes == 0 or not is_instance_valid(_fase):
		return
	if global_position.distance_to(_fase.pes.global_position) > 216.0 or _fase.batalhas.ativa:
		return
	_tempo -= delta
	if _tempo > 0.0:
		return
	if _fase.encontros.gerar_da_sepultura(_fase.piso.local_to_map(global_position)):
		_restantes -= 1
		_tempo = 4.0
	else:
		_tempo = 0.75

func receber_dano(dano: int, _empurrao := Vector2.ZERO, _fonte := &"chute") -> void:
	if vida <= 0:
		return
	vida -= dano
	AudioManager.tocar(&"impacto", global_position)
	_arte.modulate = Color(1.0, 0.81, 1.0)
	var efeito := create_tween()
	if vida <= 0:
		collision_layer = 0
		efeito.tween_property(self, "modulate:a", 0.0, 0.55)
		efeito.tween_callback(queue_free)
	else:
		efeito.tween_property(_arte, "modulate", Color(0.82, 0.50, 1.0), 0.20)
