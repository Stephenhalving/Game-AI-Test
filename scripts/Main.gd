extends Node2D

const LevelConfig = preload("res://scripts/LevelConfig.gd")
const RUSHER_SCENE := preload("res://scenes/EnemyRusher.tscn")
const TANK_SCENE := preload("res://scenes/EnemyTank.tscn")
const RANGED_SCENE := preload("res://scenes/EnemyRanged.tscn")

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

@onready var hud := $HUD
@onready var door := get_node_or_null("Door")

# --- ARENA GATE (Scott Pilgrim loop) ---
const ENEMY_RUSHER := preload("res://scenes/EnemyRusher.tscn")
const ENEMY_TANK := preload("res://scenes/EnemyTank.tscn")
const ENEMY_RANGED := preload("res://scenes/EnemyRanged.tscn")

@onready var arena_trigger: Area2D = get_node_or_null("Level/ArenaTrigger")
@onready var door_node: Node = get_node_or_null("Door")

var arena_active: bool = false
var arena_cleared: bool = false
var arena_wave_left: int = 0

func _ready() -> void:
    print("🧱 Main._ready() ENTER")
    print("🧱 arena_trigger=", arena_trigger)
    print("🧱 arena_trigger_path=", arena_trigger.get_path() if arena_trigger else "NULL")
    add_to_group("main")

    # --- Level config (F7.2) ---
    get_tree().paused = false
    Engine.time_scale = 1.0
    print("✅ Main READY paused=", get_tree().paused, " time_scale=", Engine.time_scale)
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
    cfg = LevelConfig.get_level(level_id)
    max_enemies = int(cfg.get("max_enemies", max_enemies))

    # resto igual...


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

    if DisplayServer.get_name() == "headless":
        print("🧪 HEADLESS: forcing arena start for test")
        _start_arena()

func _spawn_to_max() -> void:
    _cleanup_dead()
    while enemies.size() < max_enemies:
        var scene := _pick_enemy_scene()
        var e: Node = scene.instantiate()
        add_child(e)
        e.name = "Enemy_%d" % Time.get_ticks_msec()
        e.global_position = Vector2(320 + enemies.size() * 34, 120)
        enemies.append(e)
        if e.has_signal("died"):
            e.died.connect(_on_enemy_died.bind(e))

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
    has_key = true
    if hud and hud.has_method("set_key"):
        hud.set_key(true)
    if door:
        door.open()

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
    else:
        if not has_key:
            var k = KEY_SCENE.instantiate()
            add_child(k)
            k.global_position = pos

func _on_enemy_died(e: Node) -> void:
    add_score(100)
    if e and is_instance_valid(e):
        call_deferred("_drop_loot", e.global_position)
    if enemies.has(e):
        enemies.erase(e)
    wave += 1
    _spawn_to_max()

func on_level_complete() -> void:
    add_score(250)
    print("✅ STAGE CLEAR +250")
    await get_tree().create_timer(0.6).timeout

    var lm := get_node_or_null("/root/LevelManagerAuto")
    if lm:
        lm.call_deferred("next_level")
    else:
        # fallback (por si autoload no existe)
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
    if arena_active or arena_cleared:
        return
    if body == null:
        return
    if not body.is_in_group("player"):
        return    
    # solo el Player activa
    if body.name != "Player":
        return

    print("🟨 ArenaTrigger ENTER -> START ARENA")
    _start_arena()

func _spawn_arena_wave() -> void:
    var spawn_y := 170.0
    var spawns := [
        Vector2(320.0, spawn_y),
        Vector2(370.0, spawn_y),
        Vector2(420.0, spawn_y),
    ]
    var pool := [ENEMY_RUSHER, ENEMY_TANK, ENEMY_RANGED]

    for i in range(spawns.size()):
        var scene = pool[i % pool.size()]
        var e = scene.instantiate()
        add_child(e)
        e.global_position = spawns[i]

        arena_wave_left += 1
        if e.has_signal("died"):
            e.died.connect(_on_arena_enemy_died)

func _on_arena_enemy_died() -> void:
    arena_wave_left -= 1
    print("🟥 ARENA LEFT=", arena_wave_left)

    if arena_wave_left <= 0:
        arena_active = false
        arena_cleared = true
        print("🟩 ARENA CLEARED")

        _set_door_exit_enabled(true)

        # feedback opcional si ya existe en tu Main.gd
        if has_method("spawn_floating_text"):
            spawn_floating_text(Vector2(360, 90), "GO!")

func _start_arena() -> void:
    arena_active = true
    arena_cleared = false

    arena_wave_left = 3
    print("🟧 ARENA START enemies=", arena_wave_left)

    if door_node and door_node.has_method("set_locked"):
        door_node.call("set_locked", true)

    var player := get_node_or_null("Player")
    var base_pos := Vector2(300, 160)
    if player:
        base_pos = player.global_position

    for i in range(arena_wave_left):
        var scene_to_spawn: PackedScene = ENEMY_RUSHER
        if i == 1:
            scene_to_spawn = ENEMY_RANGED
        elif i == 2:
            scene_to_spawn = ENEMY_TANK

        var e := scene_to_spawn.instantiate()
        add_child(e)
        e.global_position = base_pos + Vector2(120 + i * 30, 0)
        e.add_to_group("arena_enemy")

func _set_door_exit_enabled(enabled: bool) -> void:
    if door_node == null:
        return

    var exit_area: Area2D = door_node.get_node_or_null("ExitArea")
    if exit_area:
        exit_area.set_deferred("monitoring", enabled)
