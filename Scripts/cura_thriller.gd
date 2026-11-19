extends Area2D

func _physics_process(_delta: float) -> void:
	if is_queued_for_deletion():
		return
	for corpo in get_overlapping_bodies():
		var jogador := corpo as MichaelJogador
		if jogador != null and jogador.recuperar_uma_vida():
			queue_free()
			return
