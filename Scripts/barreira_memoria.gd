extends StaticBody2D

const ALTURA := 12.0

var _largura: float


func montar(largura: float) -> void:
	_largura = largura
	collision_mask = 0
	z_index = 1
	var forma := RectangleShape2D.new()
	forma.size = Vector2(largura, ALTURA)
	var colisor := CollisionShape2D.new()
	colisor.shape = forma
	colisor.position.x = largura * 0.5
	add_child(colisor)


func _draw() -> void:
	draw_rect(Rect2(0, -12, _largura, 24), Color(0.43, 0.16, 0.66, 0.24))
	draw_rect(Rect2(0, -4, _largura, 8), Color(0.28, 0.10, 0.42, 0.92))
	for x in range(0, int(_largura), 32):
		draw_polyline(PackedVector2Array([
			Vector2(x, 5), Vector2(x + 16, -5), Vector2(x + 32, 5),
		]), Color(0.80, 0.49, 0.99, 0.90), 2.0)
	draw_line(Vector2(0, 10), Vector2(_largura, 10), Color(0.62, 0.32, 0.86, 0.62))


func dissipar() -> void:
	set_deferred("collision_layer", 0)
	var efeito := create_tween()
	efeito.tween_property(self, "modulate", Color(1.0, 0.86, 0.53, 0.0), 0.48)
	efeito.tween_callback(queue_free)
