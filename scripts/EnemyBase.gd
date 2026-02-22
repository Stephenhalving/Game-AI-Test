extends CharacterBody2D
class_name EnemyBase

signal died
signal hp_changed(new_hp: int, hp_max: int)

@export var speed: float = 90.0
@export var gravity: float = 1200.0

@export var hp_max: int = 3
@export var hp: int = 3

@export var chase_range: float = 260.0
@export var attack_range: float = 34.0
@export var attack_cooldown: float = 0.9

# --- Crowd control (Scott Pilgrim feel) ---
@export var crowd_separation_radius: float = 22.0
@export var crowd_separation_strength: float = 55.0

# max enemigos que pueden intentar atacar al mismo tiempo (por escena)
@export var max_attackers_at_once: int = 1

# movimiento / combate base
var direction: float = -1.0
var atk_cd: float = 0.0
var hitstun: float = 0.0
var knock_x: float = 0.0

# estados F5.2.1
var stun_timer: float = 0.0
var down_timer: float = 0.0
var getup_timer: float = 0.0
var invuln_timer: float = 0.0
var was_down: bool = false

# knockdown SOLO heavy
var pending_knockdown: bool = false

# F5.2.2 juggle
const MAX_AIR_HITS := 3
var air_hits: int = 0
var juggle_immunity: float = 0.0

# F5.3 tech control
var tech_cd: float = 0.0

# Patrol
@export var patrol_mode: bool = false
@export var patrol_range: float = 80.0
var _patrol_origin: Vector2 = Vector2.ZERO
var _patrol_initialized: bool = false
var _patrol_dir: float = 1.0

@onready var attack_area: Area2D = $AttackArea
var player: Node2D = null

func _ready() -> void:
    add_to_group("enemies")
    hp = hp_max
    attack_area.monitoring = false
    if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
        attack_area.body_entered.connect(_on_attack_area_body_entered)
    _patrol_origin = global_position

func _physics_process(delta: float) -> void:
    atk_cd = max(0.0, atk_cd - delta)

    # timers
    hitstun = max(0.0, hitstun - delta)
    stun_timer = max(0.0, stun_timer - delta)
    down_timer = max(0.0, down_timer - delta)
    getup_timer = max(0.0, getup_timer - delta)
    invuln_timer = max(0.0, invuln_timer - delta)
    juggle_immunity = max(0.0, juggle_immunity - delta)
    tech_cd = max(0.0, tech_cd - delta)

    velocity.y += gravity * delta

    if player == null:
        player = _find_player()

    # TECH: random AI recovery from knockdown (15% chance per ~0.5s window)
    if tech_cd <= 0.0 and randf() < 0.008:
        if down_timer > 0.35:
            down_timer = min(down_timer, 0.10)
            invuln_timer = max(invuln_timer, 0.22)
            tech_cd = 0.60
        elif getup_timer > 0.0:
            getup_timer = min(getup_timer, 0.14)
            invuln_timer = max(invuln_timer, 0.22)
            tech_cd = 0.60


    # transición DOWN -> GETUP
    if was_down and down_timer <= 0.0:
        was_down = false
        getup_timer = 0.28
        invuln_timer = 0.28
        attack_area.set_deferred("monitoring", false)

    # estados (prioridad)
    if down_timer > 0.0:
        velocity.x = 0.0
        attack_area.set_deferred("monitoring", false)
    elif getup_timer > 0.0:
        velocity.x = 0.0
        attack_area.set_deferred("monitoring", false)
    elif stun_timer > 0.0:
        velocity.x = knock_x
        attack_area.set_deferred("monitoring", false)
    elif hitstun > 0.0:
        velocity.x = knock_x
    else:
        var in_range := player != null and absf(player.global_position.x - global_position.x) <= chase_range
        if patrol_mode and not in_range:
            _process_patrol(delta)
        else:
            _process_ai(delta)

    # F5.3 blink (i-frames visibles)
    if invuln_timer > 0.0:
        visible = (int(Time.get_ticks_msec() / 80.0) % 2) == 0
    else:
        visible = true

    _apply_crowd_separation(delta)

    move_and_slide()
    _apply_knockdown_landing()

func _process_ai(_delta: float) -> void:
    pass

func _process_patrol(_delta: float) -> void:
    if not _patrol_initialized:
        _patrol_origin = global_position
        _patrol_initialized = true

    var dist := global_position.x - _patrol_origin.x
    if dist >= patrol_range:
        _patrol_dir = -1.0
    elif dist <= -patrol_range:
        _patrol_dir = 1.0

    direction = _patrol_dir
    velocity.x = _patrol_dir * speed * 0.45

@export var damage: int = 1
@export var knockback: float = 420.0

func _on_attack_area_body_entered(body: Node) -> void:
    if body == null:
        return
    if not body.is_in_group("player"):
        return

    # Player.gd actual espera (from_dir, dmg, knock)
    if body.has_method("take_damage"):
        body.call("take_damage", direction, damage, knockback)

func _do_attack() -> void:
    if not _can_attack_now():
        return

    set_meta("is_attacking", true)

    atk_cd = attack_cooldown
    attack_area.position.x = 18.0 * direction
    attack_area.set_deferred("monitoring", true)

    await get_tree().create_timer(0.10, true).timeout
    attack_area.set_deferred("monitoring", false)

    # pequeño hold para evitar multi-hits simultáneos
    await get_tree().create_timer(0.05, true).timeout
    set_meta("is_attacking", false)

func take_hit(from_dir: float, knock: float = 260.0, dmg: int = 1, lift: float = 0.0) -> void:
    if invuln_timer > 0.0:
        return

    hp -= dmg
    hp_changed.emit(hp, hp_max)

    # daño floating text si existe
    var main := get_tree().current_scene
    if main and main.has_method("spawn_damage_text"):
        main.spawn_damage_text(global_position, dmg)

    _flash()

    # juggle counter
    if not is_on_floor():
        air_hits += 1
    else:
        air_hits = 0

    # si excede hits en aire, cortamos lift por un rato (anti infinito)
    if air_hits >= MAX_AIR_HITS:
        juggle_immunity = 0.6
        lift = 0.0
        pending_knockdown = false

    # knock horizontal
    knock_x = knock * from_dir * 0.55
    velocity.x = knock_x

    # stun/hitstun base
    hitstun = 0.10
    stun_timer = 0.06
    if dmg >= 2:
        hitstun = 0.12
        stun_timer = 0.10

    # heavy/launcher (solo si no hay juggle immunity)
    if lift > 0.0 and juggle_immunity <= 0.0:
        pending_knockdown = true
        hitstun = 0.18
        stun_timer = 0.12
        velocity.y = -lift

    if hp <= 0:
        call_deferred("_die")

func _apply_knockdown_landing() -> void:
    if is_on_floor():
        # reseteo de juggle al tocar piso
        air_hits = 0

    # knockdown SOLO si venía de heavy
    if pending_knockdown and is_on_floor():
        pending_knockdown = false
        down_timer = 0.60
        was_down = true
        attack_area.set_deferred("monitoring", false)

func _die() -> void:
    emit_signal("died")
    queue_free()

func _flash() -> void:
    var old := modulate
    modulate = Color(1, 1, 1, 1)
    await get_tree().create_timer(0.05).timeout
    modulate = old

func _apply_crowd_separation(delta: float) -> void:
    var push_x := 0.0

    # Separar de otros enemigos
    var nodes := get_tree().get_nodes_in_group("enemies")
    for n in nodes:
        if n == self or not (n is Node2D):
            continue
        var other := n as Node2D
        var dx := global_position.x - other.global_position.x
        var adx := absf(dx)
        if adx > 0.001 and adx < crowd_separation_radius:
            push_x += signf(dx) * (crowd_separation_radius - adx)

    # BUG FIX: separar del player — evita que el enemigo quede parado encima
    if player and is_instance_valid(player):
        var pdx := global_position.x - player.global_position.x
        var adx_p := absf(pdx)
        var sep := 24.0
        if adx_p < sep:
            var push_dir := signf(pdx)
            # Si están en el mismo x exacto: usar ID para no empujar todos al mismo lado
            if adx_p < 0.8:
                push_dir = 1.0 if (int(get_instance_id()) % 2 == 0) else -1.0
            push_x += push_dir * (sep - adx_p + 4.0) * 2.2

    if push_x != 0.0:
        velocity.x += push_x * crowd_separation_strength * delta

func _count_attackers() -> int:
    var nodes := get_tree().get_nodes_in_group("enemies")
    var c := 0
    for n in nodes:
        if n != null and is_instance_valid(n) and n.has_meta("is_attacking") and bool(n.get_meta("is_attacking")):
            c += 1
    return c

func _can_attack_now() -> bool:
    if max_attackers_at_once <= 0:
        return true
    return _count_attackers() < max_attackers_at_once

func _find_player() -> Node2D:
    var nodes := get_tree().get_nodes_in_group("player")
    if nodes.size() > 0 and nodes[0] is Node2D:
        return nodes[0]
    var p := get_parent()
    if p:
        var n = p.get_node_or_null("Player")
        if n and n is Node2D:
            return n
    return null
