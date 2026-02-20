extends Node2D

const LevelConfigScript = preload("res://scripts/LevelConfig.gd")
const RUSHER_SCENE := preload("res://scenes/EnemyRusher.tscn")
const TANK_SCENE := preload("res://scenes/EnemyTank.tscn")
const RANGED_SCENE := preload("res://scenes/EnemyRanged.tscn")
const ARENA_SPAWN_MIN_X := 40.0
const ARENA_SPAWN_MAX_X := 480.0
const ARENA_SPAWN_MIN_Y := 110.0
const ARENA_SPAWN_MAX_Y := 190.0

const COIN_SCENE := preload("res://scenes/Coin.tscn")
const FOOD_SCENE := preload("res://scenes/Food.tscn")
const KEY_SCENE := preload("res://scenes/Key.tscn")

@export var max_enemies := 3

var enemies: Array[Node] = []
var score := 0
var wave := 0
var has_key := false
var level_id: int = 1
var cfg: Dictionary = {}
var arena_active := false
var arena_starting := false
var arena_cleared := false
var arena_wave_index := 0
var arena_total_waves := 3
var arena_wave_left := 0
var arena_waiting_next_wave := false
var _headless_timer: Timer = null
var arena_spawn_points: Array = []
var arena_enemies: Array[Node] = []
@export var headless_autoplay: bool = false
@export var debug_force_arena_start: bool = false
@onready var hud := $HUD
@onready var door := get_node_or_null("Door")

# --- ARENA GATE (Scott Pilgrim loop) ---
const ENEMY_RUSHER := preload("res://scenes/EnemyRusher.tscn")
const ENEMY_TANK := preload("res://scenes/EnemyTank.tscn")
const ENEMY_RANGED := preload("res://scenes/EnemyRanged.tscn")

@onready var arena_trigger: Area2D = get_node_or_null("Level/ArenaTrigger")
@onready var door_node: Node = get_node_or_null("Door")

func _ready() -> void:
    var is_headless := DisplayServer.get_name() == "headless"
    var run_headless_test := is_headless and (OS.get_environment("TQ_HEADLESS_TEST") == "1")
    
    if not is_headless:
        print("🧱 Main._ready() ENTER")
        print("🧱 arena_trigger=", arena_trigger)
        print("🧱 arena_trigger_path=", str(arena_trigger.get_path()) if arena_trigger else "NULL")
        print("✅ Main READY paused=", get_tree().paused, " time_scale=", Engine.time_scale)    
    add_to_group("main")

    if not is_headless and debug_force_arena_start:
        print("🧪 DEBUG: forcing arena start (editor run)")
        call_deferred("_start_arena")

    # --- Level config (F7.2) ---
    get_tree().paused = false
    Engine.time_scale = 1.0
    var lm := get_node_or_null("/root/LevelManagerAuto")
    
    if lm != null:
        level_id = int(lm.get("current_level"))
    else:
        level_id = 1
        
    # --- ArenaTrigger hook ---
    if arena_trigger and not arena_trigger.body_entered.is_connected(_on_arena_trigger_body_entered):
        arena_trigger.body_entered.connect(_on_arena_trigger_body_entered)
        print("🟩 ArenaTrigger CONNECTED OK -> ", arena_trigger.get_path())
    else:
        print("🟥 ArenaTrigger missing or already connected: ", arena_trigger)

    # OJO: esto requiere que exista LevelConfig.gd y class_name LevelConfig
    cfg = LevelConfigScript.get_level(level_id)
    max_enemies = int(cfg.get("max_enemies", max_enemies))

    arena_spawn_points = []
    var level := get_node_or_null("Level")
    if level:
        var nodes := level.find_children("*", "Node2D", true, false)
        for n in nodes:
            if n.is_in_group("arena_spawn"):
                arena_spawn_points.append(n)
    print("🧭 arena_spawn_points=", arena_spawn_points.size())

    var g = get_node_or_null("Ground")
    var gy := "NONE"
    if g:
        gy = str(g.position.y)

    randomize()
    if hud and hud.has_method("set_score"):
        hud.set_score(score)
    if hud and hud.has_method("set_key"):
        hud.set_key(false)

    _spawn_to_max()

    if run_headless_test:
        print("🧪 HEADLESS: forcing arena start for test")
        call_deferred("_headless_test_run")
        return

    if DisplayServer.get_name() != "headless":
        call_deferred("_start_arena")

func _headless_test_run() -> void:
    print("🧪 HEADLESS: _headless_test_run() ENTER")

    # limpiar enemigos legacy para test determinístico
    for e in enemies:
        if e and is_instance_valid(e):
            e.queue_free()
    enemies.clear()
    await get_tree().process_frame

    _start_arena()

    # esperar arranque real de la primera wave (evita que el test termine antes)
    var boot_t := 0.0
    while boot_t < 3.0 and arena_wave_index == 0:
        await _wait(0.05)
        boot_t += 0.05

    print("🧪 HEADLESS BOOT:",
        " boot_waited=", boot_t,
        " wave_index=", arena_wave_index,
        " wave_left=", arena_wave_left,
        " spawned=", arena_enemies.size()
    )

    # correr waves hasta que termine (con safety)
    var safety := 0
    while arena_active and safety < 10:
        safety += 1

        # esperar a que spawnee completa la wave actual (spawn escalonado)
        var t := 0.0
        while t < 5.0 and (arena_wave_left <= 0 or arena_enemies.size() < arena_wave_left):
            await _wait(0.1)
            t += 0.1

        print("🧪 HEADLESS WAVE READY:",
            " wave_index=", arena_wave_index,
            " expected=", arena_wave_left,
            " spawned=", arena_enemies.size(),
            " waited=", t
        )

        # simular matar a todos los de esta wave
        for e2 in arena_enemies:
            if e2 and is_instance_valid(e2):
                if e2.has_signal("died"):
                    e2.emit_signal("died")
                e2.queue_free()
        arena_enemies.clear()

        # dejar que procese callbacks y spawnee siguiente
        await _wait(1.8)

        if not arena_active:
            break

    print("🧪 HEADLESS FINAL:",
        " arena_active=", arena_active,
        " arena_cleared=", arena_cleared,
        " wave_index=", arena_wave_index,
        " wave_left=", arena_wave_left,
        " has_key=", has_key
    )

    print("🧪 HEADLESS: quitting")
    call_deferred("_headless_quit")
    return

func _lock_door(locked: bool) -> void:
    if door_node == null:
        push_warning("Door node not found. Skipping lock/unlock.")
        return

    # Preferir API explícita del Door.gd
    if door_node.has_method("set_locked"):
        door_node.call("set_locked", locked)
        return

    if locked:
        if door_node.has_method("close"):
            door_node.call("close")
            return
    else:
        if door_node.has_method("open"):
            door_node.call("open")
            return

    # Fallback: si Door.gd usa una propiedad, intentamos estas comunes
    if door_node.has_method("_update_state_deferred"):
        if door_node.has_method("set"):
            door_node.set("locked", locked)
            door_node.set("is_open", not locked)
        door_node.call("_update_state_deferred")

func _start_arena() -> void:
    print("🟩 _start_arena() CALLED spawn_points=", arena_spawn_points.size())
    print("🧪 DEBUG: prechecks arena_starting=", arena_starting, " arena_active=", arena_active, " arena_cleared=", arena_cleared)

    # anti doble-disparo (trigger puede entrar 2 veces)
    if arena_starting:
        print("🟥 _start_arena blocked: arena_starting")
        return
    arena_starting = true

    if arena_active or arena_cleared:
        print("🧪 DEBUG: returning because arena_active/cleared -> active=", arena_active, " cleared=", arena_cleared)
        arena_starting = false
        return

    print("🧪 DEBUG: about to clear legacy enemies. enemies.size=", enemies.size())

    # limpiar enemigos legacy antes de arrancar la arena
    for e in enemies:
        if e and is_instance_valid(e):
            e.queue_free()
    enemies.clear()
    await get_tree().create_timer(0.01, true).timeout
    print("🧪 DEBUG: cleared legacy enemies OK. now setting arena_active true")
    arena_active = true
    arena_starting = false

    arena_waiting_next_wave = false
    arena_wave_left = 0

    # refrescar spawn points (por orden de carga / groups)
    arena_spawn_points = get_tree().get_nodes_in_group("arena_spawn")
    print("🧭 arena_spawn_points(start_arena)=", arena_spawn_points.size())
    for n in arena_spawn_points:
        print("🧭 spawn:", n.name)

    arena_cleared = false
    arena_wave_index = 0
    arena_total_waves = 3 # por ahora fijo

    _lock_door(true)
    print("🧪 DEBUG: calling _spawn_next_wave() now. arena_active=", arena_active, " wave_index=", arena_wave_index)
    _spawn_next_wave()

func _spawn_next_wave():
    var is_headless := DisplayServer.get_name() == "headless"
    print("🧪 DEBUG: ENTER _spawn_next_wave(). headless=", is_headless, " arena_active=", arena_active, " wave_index(before)=", arena_wave_index)

    # Delays: en headless = 0 para test determinístico
    if not is_headless:
        get_tree().paused = true
        await get_tree().create_timer(0.12, true).timeout
        get_tree().paused = false
        await get_tree().create_timer(0.35, true).timeout
    else:
        await get_tree().process_frame

    arena_wave_index += 1
    print("🧪 DEBUG: wave_index incremented ->", arena_wave_index)

    if arena_wave_index > arena_total_waves:
        _finish_arena()
        return

    var plan := _build_wave_plan(arena_wave_index)
    arena_wave_left = plan.size()
    print("🧪 DEBUG: plan size=", arena_wave_left)

    # Spawn escalonado: en headless, sin waits
    for enemy_scene_path in plan:
        _spawn_enemy_from_path(enemy_scene_path)
        if not is_headless:
            await get_tree().create_timer(0.35).timeout

func _build_wave_plan(wave_num: int) -> Array:
    var rusher := "res://scenes/EnemyRusher.tscn"
    var tank := "res://scenes/EnemyTank.tscn"
    var ranged := "res://scenes/EnemyRanged.tscn"

    var plan: Array = []
    var allow_tank := wave_num >= 2
    var max_tanks := 1 if allow_tank else 0
    var max_ranged := 1  # evita spam de balas para demo

    var tanks := 0
    var rangeds := 0

    # Probabilidades (climax en wave 3)
    var p_rusher := 60
    var p_ranged := 25
    var p_tank := 15
    if wave_num == 1:
        p_rusher = 75
        p_ranged = 25
        p_tank = 0
    elif wave_num == 3:
        p_rusher = 55
        p_ranged = 20
        p_tank = 25  # climax: más chance de tank

    while plan.size() < 3:
        var roll := randi() % 100

        if roll < p_rusher:
            plan.append(rusher)
        elif roll < (p_rusher + p_ranged):
            if rangeds < max_ranged:
                plan.append(ranged)
                rangeds += 1
            else:
                plan.append(rusher)
        else:
            if allow_tank and tanks < max_tanks:
                plan.append(tank)
                tanks += 1
            else:
                plan.append(rusher)

    return plan

func _spawn_enemy_from_path(scene_path: String):
    var packed := load(scene_path)
    if packed == null:
        push_error("Enemy scene not found: %s" % scene_path)
        return

    var enemy: Node = packed.instantiate()

    var level := get_node_or_null("Level")
    if level:
        level.add_child(enemy)
    else:
        add_child(enemy)

    arena_enemies.append(enemy)

    # asegurar que se vea por encima del fondo si hace falta
    if enemy is CanvasItem:
        (enemy as CanvasItem).z_index = 20

    var sp2: Node2D = _pick_arena_spawn_point()
    var pos: Vector2 = sp2.global_position if sp2 != null else Vector2.ZERO

    if enemy is Node2D:
        var n := enemy as Node2D

        # "entrada" estilo brawler: spawn desplazado y tween al punto
        var offset := Vector2.ZERO
        var nm := String(sp2.name) if sp2 != null else ""

        if nm.find("Left") != -1:
            offset = Vector2(-80, 0)
        elif nm.find("Right") != -1:
            offset = Vector2(80, 0)
        elif nm.find("Top") != -1:
            offset = Vector2(0, -60)    

        pos.x = clamp(pos.x, ARENA_SPAWN_MIN_X, ARENA_SPAWN_MAX_X)
        pos.y = clamp(pos.y, ARENA_SPAWN_MIN_Y, ARENA_SPAWN_MAX_Y)

        var start_pos := pos + offset
        start_pos.x = clamp(start_pos.x, ARENA_SPAWN_MIN_X, ARENA_SPAWN_MAX_X)
        start_pos.y = clamp(start_pos.y, ARENA_SPAWN_MIN_Y, ARENA_SPAWN_MAX_Y)

        n.global_position = start_pos
        create_tween().tween_property(n, "global_position", pos, 0.28)

    # connect died (arena)
    if enemy.has_signal("died"):
        if not enemy.died.is_connected(_on_arena_enemy_died):
            enemy.died.connect(_on_arena_enemy_died)

func _spawn_to_max() -> void:
    # No spawnear enemigos generales durante arena
    if arena_active:
        return
    _spawn_to_max_legacy()

func _spawn_to_max_legacy() -> void:
    _cleanup_dead()
    while enemies.size() < max_enemies:
        var scene := _pick_enemy_scene()
        var e: Node = scene.instantiate()

        var level2 := get_node_or_null("Level")
        if level2:
            level2.add_child(e)
        else:
            add_child(e)

        if e is CanvasItem:
            (e as CanvasItem).z_index = 20

        e.name = "Enemy_%d" % Time.get_ticks_msec()
        e.global_position = Vector2(320 + enemies.size() * 34, 120)
        enemies.append(e)
        if e.has_signal("died"):
            e.died.connect(func(): _on_enemy_died(e))

func _cleanup_dead() -> void:
    var alive: Array[Node] = []
    for e in enemies:
        if e and is_instance_valid(e):
            alive.append(e)
    enemies = alive

func _pick_enemy_scene() -> PackedScene:
    var r := randf()
    if r < 0.4:
        return RUSHER_SCENE
    elif r < 0.7:
        return TANK_SCENE
    else:
        return RANGED_SCENE

func add_score(v: int) -> void:
    score += v
    if hud and hud.has_method("set_score"):
        hud.set_score(score)

func on_key_collected() -> void:
    if arena_active:
        return
    has_key = true
    if hud and hud.has_method("set_key"):
        hud.set_key(true)

func _drop_loot(pos: Vector2) -> void:
    var r := randf()
    if r < 0.5:
        var c = COIN_SCENE.instantiate()
        add_child(c)
        c.global_position = pos
    elif r < 0.75:
        var f = FOOD_SCENE.instantiate()
        add_child(f)
        f.global_position = pos
    
func _on_enemy_died(e: Node) -> void:
    add_score(100)
    if e and is_instance_valid(e):
        call_deferred("_drop_loot", e.global_position)
    if enemies.has(e):
        enemies.erase(e)

    # Durante arena no usamos el loop de spawn general
    if arena_active:
        return

    wave += 1
    _spawn_to_max_legacy()

func _pick_arena_spawn_point() -> Node2D:
    if arena_spawn_points.size() <= 0:
        return null
    var sp: Node = arena_spawn_points[randi() % arena_spawn_points.size()]
    return sp as Node2D

func _pick_arena_spawn_position() -> Vector2:
    var sp: Node2D = _pick_arena_spawn_point()
    if sp != null:
        return sp.global_position
    return Vector2.ZERO

func on_level_complete() -> void:
    if DisplayServer.get_name() == "headless":
        return

    add_score(250)
    print("✅ STAGE CLEAR +250")
    await get_tree().create_timer(0.6).timeout

    var lm := get_node_or_null("/root/LevelManagerAuto")
    if lm:
        lm.call_deferred("next_level")
    else:
        # fallback (por si autoload no existe)
        get_tree().reload_current_scene()

func on_player_died() -> void:
    print("🔁 RESTARTING SCENE...")
    await get_tree().create_timer(0.8).timeout
    get_tree().reload_current_scene()

# --- Floating damage text (reusable) ---
func spawn_damage_text(pos: Vector2, amount: int) -> void:
    # Si existe un nodo/escena DamageText, lo instancia. Si no, usa texto flotante simple.
    if ResourceLoader.exists("res://scenes/DamageText.tscn"):
        var dt = preload("res://scenes/DamageText.tscn").instantiate()
        add_child(dt)
        dt.global_position = pos
        if dt.has_method("set_amount"):
            dt.set_amount(amount)
        elif dt.has_method("set_text"):
            dt.set_text(str(amount))
    else:
        # fallback: usa spawn_floating_text si está
        if has_method("spawn_floating_text"):
            spawn_floating_text(pos, str(amount))
        else:
            print("DMG:", amount)

# Alias por compatibilidad
func spawn_floating_text(pos: Vector2, text: String) -> void:
    # Si te mandan string, intenta parsear número; sino lo imprime como texto
    var n := int(text) if text.is_valid_int() else 0
    if n != 0:
        spawn_damage_text(pos, n)
    else:
        print("FLOAT:", text)

func _on_arena_trigger_body_entered(body: Node) -> void:
    print("🟨 ArenaTrigger ENTER -> body=", body, " name=", body.name)

    if arena_active or arena_cleared:
        print("🟥 blocked: arena_active or cleared")
        return

    if body == null:
        print("🟥 blocked: body null")
        return

    if not body.is_in_group("player"):
        print("🟥 blocked: body not in group 'player'")
        return

    print("🟩 ArenaTrigger OK -> START ARENA")
    _start_arena()

func _spawn_arena_wave_legacy() -> void:
    print("🧪 _spawn_arena_wave() ENTER")

    var spawn_y := 170.0
    var spawns := [
        Vector2(320.0, spawn_y),
        Vector2(370.0, spawn_y),
        Vector2(420.0, spawn_y),
    ]
    var pool: Array[PackedScene] = [ENEMY_RUSHER, ENEMY_TANK, ENEMY_RANGED]

    for i in range(spawns.size()):
        var scene: PackedScene = pool[i % pool.size()]
        var e: Node2D = scene.instantiate()
        add_child(e)
        e.global_position = spawns[i]

        # contar vivos de arena
        arena_wave_left += 1

        # registrar también para respawn general
        enemies.append(e)

        # marcar como enemigo de arena (opcional)
        e.add_to_group("arena_enemy")

        print("🧪 spawned arena enemy #", i, " wave_left=", arena_wave_left)

        if e.has_signal("died"):
            # 1) contador de arena
            e.died.connect(_on_arena_enemy_died)

        # spawn escalonado (Scott Pilgrim feel)
        await get_tree().create_timer(0.35).timeout

func _on_arena_enemy_died(_arg = null) -> void:
    arena_wave_left -= 1

    if arena_wave_left <= 0:
        if arena_waiting_next_wave:
            return
        arena_waiting_next_wave = true

        await get_tree().create_timer(1.25).timeout

        arena_waiting_next_wave = false
        _spawn_next_wave()

func _finish_arena():
    print("🧪 DEBUG: _finish_arena() called. wave_index=", arena_wave_index, " wave_left=", arena_wave_left)

    arena_active = false
    arena_cleared = true

    # ✅ dar llave SOLO al finalizar la arena
    _grant_arena_key()

    _lock_door(false)

func _grant_arena_key() -> void:
    if has_key:
        return
    has_key = true
    if hud and hud.has_method("set_key"):
        hud.set_key(true)

func _start_arena_legacy():
    arena_active = true
    arena_cleared = false
    arena_wave_left = 0
    
    # LEGACY: no usar en el sistema nuevo (se mantiene por referencia)
    print("🧪 _start_arena() -> calling _spawn_arena_wave()")
    _spawn_arena_wave_legacy()

    if door_node and door_node.has_method("set_locked"):
        door_node.call("set_locked", true)    

func _set_door_exit_enabled(enabled: bool) -> void:
    if door_node == null:
        return

    var exit_area: Area2D = door_node.get_node_or_null("ExitArea")
    if exit_area:
        exit_area.set_deferred("monitoring", enabled)

func _headless_quit() -> void:
    if _headless_timer and is_instance_valid(_headless_timer):
        _headless_timer.queue_free()
        _headless_timer = null

    get_tree().quit()

func _headless_get_timer() -> Timer:
    if _headless_timer and is_instance_valid(_headless_timer):
        return _headless_timer
    var t := Timer.new()
    t.one_shot = true
    add_child(t)
    _headless_timer = t
    return t

func _wait(seconds: float) -> void:
    if DisplayServer.get_name() == "headless":
        var t := _headless_get_timer()
        t.stop()
        t.wait_time = seconds
        t.start()
        await t.timeout
    else:
        await get_tree().create_timer(seconds).timeout
