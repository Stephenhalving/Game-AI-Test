extends Node2D

const RUSHER_SCENE := preload("res://scenes/EnemyRusher.tscn")
const TANK_SCENE := preload("res://scenes/EnemyTank.tscn")
const EXPLORATION_KEY_SCENE := preload("res://scenes/ExplorationKey.tscn")
const CAR_KEY_SCENE := preload("res://scenes/CarKey.tscn")
const COIN_SCENE := preload("res://scenes/Coin.tscn")
const FOOD_SCENE := preload("res://scenes/Food.tscn")

@onready var hud = $HUD
@onready var bridge_floor: StaticBody2D = $Level/BridgeFloor
@onready var bridge_barrier: StaticBody2D = $Level/BridgeBarrier
@onready var switch_zone: Area2D = $Level/SwitchZone
@onready var mini_trigger: Area2D = $Level/MiniEncounterTrigger

# Spawn point positions (world coords)
const ZONE1_PATROLS := [Vector2(280, 165), Vector2(570, 165)]
const ZONE2_PATROLS := [Vector2(1060, 165), Vector2(1310, 165)]
const MINI_SPAWNS   := [Vector2(1600, 165), Vector2(1700, 165), Vector2(1750, 165)]
const CAR_KEY_POS   := Vector2(1675, 165)
const EXPL_KEY_POS  := Vector2(660, 95)

var has_exploration_key := false
var bridge_activated := false
var mini_encounter_active := false
var mini_enemies: Array[Node] = []
var score := 0

func _ready() -> void:
    add_to_group("main")
    get_tree().paused = false
    Engine.time_scale = 1.0

    var player := get_node_or_null("Player")
    if hud and player:
        hud.init_player(player)
        hud.set_score(score)
        hud.set_key(false)
        if player.has_signal("combo_changed"):
            player.combo_changed.connect(hud._on_combo_changed)

    _set_bridge_state(false)

    switch_zone.body_entered.connect(_on_switch_entered)
    mini_trigger.body_entered.connect(_on_mini_trigger_entered)

    _spawn_exploration_key()
    _spawn_roaming_enemies()
    print("✅ Stage2 READY")

func _spawn_exploration_key() -> void:
    var key = EXPLORATION_KEY_SCENE.instantiate()
    $Level.add_child(key)
    key.global_position = EXPL_KEY_POS
    print("🔑 ExplorationKey spawned at", EXPL_KEY_POS)

func _spawn_roaming_enemies() -> void:
    for pos in ZONE1_PATROLS + ZONE2_PATROLS:
        var e = RUSHER_SCENE.instantiate()
        $Level.add_child(e)
        e.global_position = pos
        e.set("patrol_mode", true)
        e.set("patrol_range", 90.0)
        if e.has_signal("died"):
            e.died.connect(func(): _on_roaming_died(e))
        if hud and hud.has_method("track_enemy"):
            hud.track_enemy(e)

func _on_roaming_died(e: Node) -> void:
    add_score(100)
    if e and is_instance_valid(e):
        _drop_loot(e.global_position)

func _on_switch_entered(body: Node) -> void:
    if not body.is_in_group("player"):
        return
    if bridge_activated or not has_exploration_key:
        if not has_exploration_key:
            print("🔒 Switch: need Exploration Key first")
        return
    bridge_activated = true
    has_exploration_key = false
    if hud:
        hud.set_key(false)
    _set_bridge_state(true)
    switch_zone.set_deferred("monitoring", false)
    print("🌉 Bridge repaired!")

func _set_bridge_state(active: bool) -> void:
    var bf_col: CollisionShape2D = bridge_floor.get_node_or_null("CollisionShape2D")
    if bf_col:
        bf_col.set_deferred("disabled", not active)
    bridge_floor.visible = active

    var bb_col: CollisionShape2D = bridge_barrier.get_node_or_null("CollisionShape2D")
    if bb_col:
        bb_col.set_deferred("disabled", active)
    bridge_barrier.visible = not active

func _on_mini_trigger_entered(body: Node) -> void:
    if not body.is_in_group("player"):
        return
    if mini_encounter_active:
        return
    mini_trigger.set_deferred("monitoring", false)
    mini_encounter_active = true
    _start_mini_encounter()

func _start_mini_encounter() -> void:
    print("⚔️ Mini-encounter START!")
    var scenes := [RUSHER_SCENE, TANK_SCENE, RUSHER_SCENE]
    var i := 0
    for pos in MINI_SPAWNS:
        var e = scenes[i % scenes.size()].instantiate()
        $Level.add_child(e)
        e.global_position = pos
        mini_enemies.append(e)
        if e.has_signal("died"):
            e.died.connect(func(): _on_mini_enemy_died(e))
        if hud and hud.has_method("track_enemy"):
            hud.track_enemy(e)
        i += 1

func _on_mini_enemy_died(e: Node) -> void:
    add_score(150)
    if e and is_instance_valid(e):
        _drop_loot(e.global_position)
    mini_enemies.erase(e)
    if mini_enemies.size() == 0:
        _finish_mini_encounter()

func _finish_mini_encounter() -> void:
    print("✅ Mini-encounter complete! Spawning Car Key...")
    add_score(200)
    var ck = CAR_KEY_SCENE.instantiate()
    $Level.add_child(ck)
    ck.global_position = CAR_KEY_POS

func on_exploration_key_collected() -> void:
    has_exploration_key = true
    if hud:
        hud.set_key(true)
    print("🔑 Exploration Key collected!")

func on_car_key_collected() -> void:
    print("🚗 Car Key! Stage 2 complete!")
    add_score(500)
    var lm := get_node_or_null("/root/LevelManagerAuto")
    if lm:
        lm.set("last_score", score)
        lm.set("has_car_key", true)
        await get_tree().create_timer(0.8).timeout
        lm.call_deferred("next_level")
    else:
        get_tree().change_scene_to_file("res://scenes/Stage3.tscn")

func on_player_died() -> void:
    print("💀 Player died in Stage 2")
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
