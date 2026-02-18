extends EnemyBase

@export var rusher_speed: float = 150.0

func _ready() -> void:
    speed = rusher_speed
    hp_max = 2
    hp = hp_max
    super._ready()

func _process_ai(_delta: float) -> void:
    if player == null:
        return

    var dx: float = player.global_position.x - global_position.x
    direction = -1.0 if dx < 0.0 else 1.0

    # Si está en rango de ataque: pega
    if absf(dx) <= attack_range:
        velocity.x = 0.0
        if atk_cd <= 0.0:
            _do_attack()
        return

    # Si está dentro del rango de persecución: corre hacia el player
    if absf(dx) <= chase_range:
        velocity.x = direction * speed
    else:
        velocity.x = 0.0
