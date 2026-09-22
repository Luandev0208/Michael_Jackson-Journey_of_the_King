extends CharacterBody2D

const SPEED = 80.0
@onready var sprite = $Michael_Sprite
func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO
	
	if Input.is_action_pressed("Esquerda"):
		velocity.x = -1 * SPEED
	if Input.is_action_pressed("Direita"):
		velocity.x = 1 * SPEED
	if Input.is_action_pressed("Cima"):
		velocity.y = -1 * SPEED
	if Input.is_action_pressed("Baixo"):
		velocity.y = 1 * SPEED
	move_and_slide()
	
	if velocity.x < 0:
		sprite.play("Direita")
	elif velocity.x > 0:
		sprite.play("Esquerda")
	else:
		sprite.play("Parado")
		
	if velocity.y < 0:
		sprite.play("Cima")
	elif velocity.x > 0:
		sprite.play("Baixo")
	else:
		sprite.play("Parado")
