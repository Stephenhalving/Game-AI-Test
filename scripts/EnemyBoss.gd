extends "res://scripts/EnemyBase.gd"

signal boss_died

@export var boss_speed_p1: float = 85.0
@export var boss_speed_p2: float = 140.0

var phase: int = 1
var is_charging: bool = false
var charge_timer: float = 0.0
var charge_dir: float = 1.0
var charge_cooldown: float = 0.0

func _ready() -> void:
    hp_max = 20
    hp = 20
    speed = boss_speed_p1
    attack_cooldown = 0.75
    attack_range = 52.0
    chase_range = 400.0
    damage = 3
    knockback = 480.0
    crowd_separation_radius = 0.0
    max_attackers_at_once = 0
    super._ready()

func _physics_process(delta: float) -> void:
    charge_cooldown = max(0.0, charge_cooldown - delta)
    super._physics_process(delta)

func _process_ai(delta: float) -> void:
    if phase == 1 and hp <= hp_max / 2:
        _enter_phase2()

    if player == null:
        return

    if is_charging:
        velocity.x = charge_dir * boss_speed_p2 * 1.9
        return

    var dx := player.global_position.x - global_position.x
    var adx := absf(dx)
    direction = -1.0 if dx < 0.0 else 1.0

    if adx <= attack_range:
        velocity.x = 0.0
        if atk_cd <= 0.0:
            _do_attack()
        return

    velocity.x = direction * speed

    if phase == 2 and charge_cooldown <= 0.0 and adx > attack_range * 2.5 and atk_cd <= 0.0:
        _do_charge()

func _enter_phase2() -> void:
    phase = 2
    speed = boss_speed_p2
    attack_cooldown = 0.5
    print("🔥 BOSS PHASE 2!")
    _flash_phase()

func _do_charge() -> void:
    if is_charging:
        return
    is_charging = true
    charge_dir = direction
    charge_cooldown = 2.2
    atk_cd = 0.5

    attack_area.position.x = 22.0 * charge_dir
    attack_area.set_deferred("monitoring", true)
    _do_charge_timed()

func _do_charge_timed() -> void:
    await get_tree().create_timer(0.38).timeout
    attack_area.set_deferred("monitoring", false)
    is_charging = false

func _flash_phase() -> void:
    for _i in range(4):
        modulate = Color(2.2, 0.3, 0.3, 1.0)
        await get_tree().create_timer(0.10).timeout
        modulate = Color(1.0, 1.0, 1.0, 1.0)
        await get_tree().create_timer(0.08).timeout

func _die() -> void:
    emit_signal("boss_died")
    emit_signal("died")
    queue_free()
