extends Node2D

const RUSHER_SCENE := preload("res://scenes/EnemyRusher.tscn")
const TANK_SCENE   := preload("res://scenes/EnemyTank.tscn")
const RANGED_SCENE := preload("res://scenes/EnemyRanged.tscn")
const BOSS_SCENE   := preload("res://scenes/EnemyBoss.tscn")
const MASTER_KEY_SCENE := preload("res://scenes/MasterKey.tscn")
const COIN_SCENE   := preload("res://scenes/Coin.tscn")
const FOOD_SCENE   := preload("res://scenes/Food.tscn")

@onready var hud = $HUD
@onready var locked_door_barrier: StaticBody2D = $Level/LockedDoorBarrier
@onready var locked_door_zone: Area2D = $Level/LockedDoorZone
@onready var combat1_trigger: Area2D = $Level/CombatTrigger1
@onready var combat2_trigger: Area2D = $Level/CombatTrigger2
@onready var stair_trigger: Area2D = $Level/StairTrigger
@onready var boss_trigger: Area2D = $Level/BossTrigger
@onready var exit_door = $Door

# Spawn positions
const PATROL_SPAWNS  := [Vector2(200, 165), Vector2(350, 165), Vector2(450, 165)]
const C1_SPAWNS      := [Vector2(620, 165), Vector2(730, 165), Vector2(830, 165)]
const MASTER_KEY_POS := Vector2(720, 165)
const C2_SPAWNS      := [Vector2(1080, 165), Vector2(1180, 165), Vector2(1300, 165), Vector2(1370, 165)]
const STAIR_SPAWNS   := [Vector2(1460, 165), Vector2(1560, 150)]
const BOSS_POS       := Vector2(1930, 160)

var has_master_key := false
var door_unlocked := false
var combat1_done := false
var combat2_done := false
var stair_done := false
var boss_spawned := false

var patrol_enemies: Array[Node] = []
var combat1_enemies: Array[Node] = []
var combat2_enemies: Array[Node] = []
var stair_enemies: Array[Node] = []
var boss_node: Node = null
var score := 0

func _ready() -> void:
    add_to_group("main")
    get_tree().paused = false
    Engine.time_scale = 1.0

    var lm := get_node_or_null("/root/LevelManagerAuto")
    if lm:
        score = int(lm.get("last_score"))

    var player := get_node_or_null("Player")
    if hud and player:
        hud.init_player(player)
        hud.set_score(score)
        hud.set_key(false)
        if player.has_signal("combo_changed"):
            player.combo_changed.connect(hud._on_combo_changed)

    # Lock exit door, locked door barrier on
    _set_exit_door(false)
    _set_locked_door(true)

    # Connect triggers
    combat1_trigger.body_entered.connect(_on_combat1_trigger)
    combat2_trigger.body_entered.connect(_on_combat2_trigger)
    stair_trigger.body_entered.connect(_on_stair_trigger)
    boss_trigger.body_entered.connect(_on_boss_trigger)
    locked_door_zone.body_entered.connect(_on_locked_door_zone)

    _spawn_patrol_enemies()
    print("✅ Stage3 READY")

func _spawn_patrol_enemies() -> void:
    for pos in PATROL_SPAWNS:
        var e = RUSHER_SCENE.instantiate()
        $Level.add_child(e)
        e.global_position = pos
        e.set("patrol_mode", true)
        e.set("patrol_range", 80.0)
        patrol_enemies.append(e)
        if e.has_signal("died"):
            e.died.connect(func(): _on_patrol_died(e))
        if hud and hud.has_method("track_enemy"):
            hud.track_enemy(e)

func _on_patrol_died(e: Node) -> void:
    add_score(100)
    if e and is_instance_valid(e):
        _drop_loot(e.global_position)
    patrol_enemies.erase(e)

# --- Combat Area 1 ---
func _on_combat1_trigger(body: Node) -> void:
    if not body.is_in_group("player") or combat1_done:
        return
    combat1_trigger.set_deferred("monitoring", false)
    combat1_done = true
    print("⚔️ Combat Area 1!")
    var wave := [RUSHER_SCENE, TANK_SCENE, RANGED_SCENE]
    for i in range(C1_SPAWNS.size()):
        var e = wave[i % wave.size()].instantiate()
        $Level.add_child(e)
        e.global_position = C1_SPAWNS[i]
        combat1_enemies.append(e)
        if e.has_signal("died"):
            e.died.connect(func(): _on_c1_enemy_died(e))
        if hud and hud.has_method("track_enemy"):
            hud.track_enemy(e)

func _on_c1_enemy_died(e: Node) -> void:
    add_score(150)
    if e and is_instance_valid(e):
        _drop_loot(e.global_position)
    combat1_enemies.erase(e)
    if combat1_enemies.size() == 0:
        _spawn_master_key()

func _spawn_master_key() -> void:
    print("🔑 Master Key dropped!")
    var mk = MASTER_KEY_SCENE.instantiate()
    $Level.add_child(mk)
    mk.global_position = MASTER_KEY_POS

# --- Master Key pickup ---
func on_master_key_collected() -> void:
    has_master_key = true
    if hud:
        hud.set_key(true)
    print("🔑 Master Key collected! Door unlocking...")
    locked_door_zone.set_deferred("monitoring", true)

# --- Locked Door ---
func _on_locked_door_zone(body: Node) -> void:
    if not body.is_in_group("player"):
        return
    if not has_master_key:
        return
    if door_unlocked:
        return
    door_unlocked = true
    has_master_key = false
    if hud:
        hud.set_key(false)
    _set_locked_door(false)
    locked_door_zone.set_deferred("monitoring", false)
    print("🚪 Locked Door open!")

func _set_locked_door(locked: bool) -> void:
    var col: CollisionShape2D = locked_door_barrier.get_node_or_null("CollisionShape2D")
    if col:
        col.set_deferred("disabled", not locked)
    locked_door_barrier.visible = locked

# --- Combat Area 2 ---
func _on_combat2_trigger(body: Node) -> void:
    if not body.is_in_group("player") or combat2_done:
        return
    combat2_trigger.set_deferred("monitoring", false)
    combat2_done = true
    print("⚔️ Combat Area 2!")
    var wave := [RUSHER_SCENE, TANK_SCENE, RANGED_SCENE, RUSHER_SCENE]
    for i in range(C2_SPAWNS.size()):
        var e = wave[i % wave.size()].instantiate()
        $Level.add_child(e)
        e.global_position = C2_SPAWNS[i]
        combat2_enemies.append(e)
        if e.has_signal("died"):
            e.died.connect(func(): _on_c2_enemy_died(e))
        if hud and hud.has_method("track_enemy"):
            hud.track_enemy(e)

func _on_c2_enemy_died(e: Node) -> void:
    add_score(150)
    if e and is_instance_valid(e):
        _drop_loot(e.global_position)
    combat2_enemies.erase(e)

# --- Staircase enemies ---
func _on_stair_trigger(body: Node) -> void:
    if not body.is_in_group("player") or stair_done:
        return
    stair_trigger.set_deferred("monitoring", false)
    stair_done = true
    print("🪜 Staircase enemies!")
    var wave := [TANK_SCENE, RANGED_SCENE]
    for i in range(STAIR_SPAWNS.size()):
        var e = wave[i % wave.size()].instantiate()
        $Level.add_child(e)
        e.global_position = STAIR_SPAWNS[i]
        stair_enemies.append(e)
        if e.has_signal("died"):
            e.died.connect(func(): _on_stair_died(e))
        if hud and hud.has_method("track_enemy"):
            hud.track_enemy(e)

func _on_stair_died(e: Node) -> void:
    add_score(200)
    if e and is_instance_valid(e):
        _drop_loot(e.global_position)
    stair_enemies.erase(e)

# --- Boss ---
func _on_boss_trigger(body: Node) -> void:
    if not body.is_in_group("player") or boss_spawned:
        return
    boss_trigger.set_deferred("monitoring", false)
    boss_spawned = true
    _spawn_boss()

func _spawn_boss() -> void:
    print("👑 BOSS SPAWNED!")
    var b = BOSS_SCENE.instantiate()
    $Level.add_child(b)
    b.global_position = BOSS_POS
    boss_node = b
    if b.has_signal("boss_died"):
        b.boss_died.connect(_on_boss_died)
    if hud and hud.has_method("track_enemy"):
        hud.track_enemy(b)

func _on_boss_died() -> void:
    print("🏆 BOSS DEFEATED!")
    add_score(1000)
    boss_node = null
    await get_tree().create_timer(1.2).timeout
    _victory()

func _victory() -> void:
    _set_exit_door(true)
    add_score(500)
    var lm := get_node_or_null("/root/LevelManagerAuto")
    if lm:
        lm.set("last_score", score)
        await get_tree().create_timer(1.0).timeout
        lm.call_deferred("win_game")
    else:
        get_tree().change_scene_to_file("res://scenes/WinScreen.tscn")

func _set_exit_door(open: bool) -> void:
    if exit_door and exit_door.has_method("set_locked"):
        exit_door.call("set_locked", not open)

# --- Common methods ---
func on_player_died() -> void:
    print("💀 Player died in Stage 3")
    get_tree().paused = false
    Engine.time_scale = 1.0
    var lm := get_node_or_null("/root/LevelManagerAuto")
    if lm:
        lm.set("last_score", score)
        await get_tree().create_timer(0.8, true).timeout
        lm.call_deferred("game_over")
    else:
        await get_tree().create_timer(0.8).timeout
        get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func add_score(v: int) -> void:
    score += v
    if hud and hud.has_method("set_score"):
        hud.set_score(score)

func hitstop(duration: float, freeze_scale: float = 0.05) -> void:
    Engine.time_scale = freeze_scale
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0

func spawn_damage_text(pos: Vector2, amount: int) -> void:
    if ResourceLoader.exists("res://scenes/DamageText.tscn"):
        var dt = preload("res://scenes/DamageText.tscn").instantiate()
        add_child(dt)
        dt.global_position = pos
        if dt.has_method("set_amount"):
            dt.set_amount(amount)
        elif dt.has_method("set_text"):
            dt.set_text(str(amount))
    else:
        print("DMG:", amount)

func spawn_floating_text(pos: Vector2, text: String) -> void:
    var n := int(text) if text.is_valid_int() else 0
    if n != 0:
        spawn_damage_text(pos, n)
    else:
        print("FLOAT:", text)

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
