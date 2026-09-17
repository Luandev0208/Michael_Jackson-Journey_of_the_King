extends CharacterBody2D

@export var speed: float = 110.0

@onready var sprite: AnimatedSprite2D = $Michael_Sprite

var last_direction := Vector2.DOWN


func _physics_process(delta):

	var direction = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	velocity = direction * speed

	move_and_slide()

	update_animation(direction)


func update_animation(direction: Vector2):

	if direction == Vector2.ZERO:
		play_idle_animation()
		return

	last_direction = direction

	if abs(direction.x) > abs(direction.y):

		if direction.x > 0:
			sprite.play("Direita")
		elif direction.x == 0:
			sprite.play("Parado")
		else:
			sprite.play("Esquerda")
		
	else:

		if direction.y > 0:
			sprite.play("Baixo")
		elif direction.y == 0:
			sprite.play("Parado")
		else:
			sprite.play("Cima")
	
	


func play_idle_animation():

	if abs(last_direction.x) > abs(last_direction.y):

		if last_direction.x > 0:
			sprite.play("Direita")
		else:
			sprite.play("Esquerda")

	else:

		if last_direction.y > 0:
			sprite.play("Baixo")
		else:
			sprite.play("Cima")
	
