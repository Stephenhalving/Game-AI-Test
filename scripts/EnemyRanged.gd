extends "res://scripts/EnemyBase.gd"

const BULLET_SCENE := preload("res://scenes/Bullet.tscn")

@export var ranged_speed: float  = 90.0
@export var shoot_range: float   = 240.0
@export var kite_range: float    = 130.0
@export var shoot_cooldown: float = 1.0

var shoot_cd: float = 0.0


func _ready() -> void:
	char_type = "ranged"
	speed     = ranged_speed
	hp_max    = 3
	hp        = hp_max
	super._ready()


func _physics_process(delta: float) -> void:
	shoot_cd = max(0.0, shoot_cd - delta)
	super._physics_process(delta)


func _process_ai(_delta: float) -> void:
	if player == null:
		return

	var dx:  float = player.global_position.x - global_position.x
	var adx: float = absf(dx)
	direction = -1.0 if dx < 0.0 else 1.0

	# Y chase — siempre sigue al player en profundidad
	var dy := player.global_position.y - global_position.y
	velocity.y = signf(dy) * speed * 0.55 if absf(dy) > 3.0 else 0.0

	# Muy cerca: se aleja
	if adx < kite_range:
		velocity.x = -direction * speed
		return

	# En rango de disparo: se detiene y dispara
	if adx <= shoot_range:
		velocity.x = 0.0
		if shoot_cd <= 0.0:
			_shoot()
		return

	# Lejos: se acerca
	if adx <= chase_range:
		velocity.x = direction * speed
	else:
		velocity.x = 0.0


func _shoot() -> void:
	shoot_cd = shoot_cooldown
	var b = BULLET_SCENE.instantiate()
	get_parent().add_child(b)
	b.global_position = global_position + Vector2(18.0 * direction, -6.0)

	if b.has_method("set_dir"):
		b.set_dir(direction)
	elif b.get("dir") != null:
		b.set("dir", direction)
	elif b.get("direction") != null:
		b.set("direction", direction)
