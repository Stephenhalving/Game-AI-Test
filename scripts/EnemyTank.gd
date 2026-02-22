extends "res://scripts/EnemyBase.gd"

@export var tank_speed: float = 80.0

func _ready() -> void:
	char_type       = "tank"
	speed           = tank_speed
	hp_max          = 6
	hp              = hp_max
	attack_cooldown = 1.15
	super._ready()


func _process_ai(_delta: float) -> void:
	if player == null:
		return

	# Y chase (profundidad)
	var dy := player.global_position.y - global_position.y
	velocity.y = signf(dy) * speed * 0.55 if absf(dy) > 3.0 else 0.0

	var dx: float = player.global_position.x - global_position.x
	direction = -1.0 if dx < 0.0 else 1.0

	if absf(dx) <= attack_range + 8.0:
		velocity.x = 0.0
		if atk_cd <= 0.0:
			_do_attack()
		return

	if absf(dx) <= chase_range:
		velocity.x = direction * speed
	else:
		velocity.x = 0.0
