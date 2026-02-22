extends Node2D

const RUSHER_SCENE := preload("res://scenes/EnemyRusher.tscn")
const TANK_SCENE := preload("res://scenes/EnemyTank.tscn")
const RANGED_SCENE := preload("res://scenes/EnemyRanged.tscn")
const EXPLORATION_KEY_SCENE := preload("res://scenes/ExplorationKey.tscn")
const CAR_KEY_SCENE := preload("res://scenes/CarKey.tscn")
const COIN_SCENE := preload("res://scenes/Coin.tscn")
const FOOD_SCENE := preload("res://scenes/Food.tscn")

@onready var hud = $HUD
@onready var bridge_floor: StaticBody2D = $Level/BridgeFloor
@onready var bridge_barrier: StaticBody2D = $Level/BridgeBarrier
@onready var switch_zone: Area2D = $Level/SwitchZone
@onready var enc_trigger1: Area2D = $Level/EncounterTrigger1
@onready var mini_trigger: Area2D = $Level/MiniEncounterTrigger
@onready var enc_trigger2: Area2D = $Level/EncounterTrigger2

# --- Spawn positions (expanded ~4800px world) ---
const ZONE1_PATROLS := [Vector2(200, 165), Vector2(400, 165), Vector2(580, 165)]
const ZONE2_PATROLS := [Vector2(1050, 165), Vector2(1280, 165), Vector2(1450, 165)]
const ZONE3_PATROLS := [Vector2(2600, 165), Vector2(2850, 165), Vector2(3050, 165)]

const EXPL_KEY_POS   := Vector2(660, 92)

const ENC1_SPAWNS    := [Vector2(1650, 165), Vector2(1760, 165), Vector2(1870, 165)]
const MINI_SPAWNS    := [Vector2(2250, 165), Vector2(2360, 165), Vector2(2470, 165), Vector2(2560, 165)]
const ENC2_SPAWNS    := [Vector2(3200, 165), Vector2(3320, 165), Vector2(3440, 165), Vector2(3560, 165), Vector2(3680, 165)]
const CAR_KEY_POS    := Vector2(4200, 165)

var has_exploration_key := false
var bridge_activated := false
var enc1_done := false
var mini_encounter_active := false
var enc2_done := false

var roaming_enemies: Array[Node] = []
var enc1_enemies: Array[Node] = []
var mini_enemies: Array[Node] = []
var enc2_enemies: Array[Node] = []
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
	enc_trigger1.body_entered.connect(_on_enc1_trigger)
	mini_trigger.body_entered.connect(_on_mini_trigger_entered)
	enc_trigger2.body_entered.connect(_on_enc2_trigger)

	_spawn_exploration_key()
	_spawn_roaming_enemies()
	print("✅ Stage2 READY (expanded)")

# ─── Exploration Key ──────────────────────────────────────────────────────────
func _spawn_exploration_key() -> void:
	var key = EXPLORATION_KEY_SCENE.instantiate()
	$Level.add_child(key)
	key.global_position = EXPL_KEY_POS
	print("🔑 ExplorationKey spawned at", EXPL_KEY_POS)

func on_exploration_key_collected() -> void:
	has_exploration_key = true
	if hud:
		hud.set_key(true)
	print("🔑 Exploration Key collected!")

# ─── Roaming patrols ─────────────────────────────────────────────────────────
func _spawn_roaming_enemies() -> void:
	var all_patrols := ZONE1_PATROLS + ZONE2_PATROLS + ZONE3_PATROLS
	for pos in all_patrols:
		var e = RUSHER_SCENE.instantiate()
		$Level.add_child(e)
		e.global_position = pos
		e.set("patrol_mode", true)
		e.set("patrol_range", 95.0)
		roaming_enemies.append(e)
		if e.has_signal("died"):
			e.died.connect(func(): _on_roaming_died(e))
		if hud and hud.has_method("track_enemy"):
			hud.track_enemy(e)

func _on_roaming_died(e: Node) -> void:
	add_score(100)
	if e and is_instance_valid(e):
		_drop_loot(e.global_position)
	roaming_enemies.erase(e)

# ─── Bridge switch ────────────────────────────────────────────────────────────
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

# ─── Encounter 1 (zona post-puente) ─────────────────────────────────────────
func _on_enc1_trigger(body: Node) -> void:
	if not body.is_in_group("player") or enc1_done:
		return
	enc_trigger1.set_deferred("monitoring", false)
	enc1_done = true
	print("⚔️ Encounter 1 START!")
	var wave := [RUSHER_SCENE, TANK_SCENE, RUSHER_SCENE]
	for i in range(ENC1_SPAWNS.size()):
		var e = wave[i % wave.size()].instantiate()
		$Level.add_child(e)
		e.global_position = ENC1_SPAWNS[i]
		enc1_enemies.append(e)
		if e.has_signal("died"):
			e.died.connect(func(): _on_enc1_died(e))
		if hud and hud.has_method("track_enemy"):
			hud.track_enemy(e)

func _on_enc1_died(e: Node) -> void:
	add_score(120)
	if e and is_instance_valid(e):
		_drop_loot(e.global_position)
	enc1_enemies.erase(e)

# ─── Mini-encounter (zona central) ──────────────────────────────────────────
func _on_mini_trigger_entered(body: Node) -> void:
	if not body.is_in_group("player") or mini_encounter_active:
		return
	mini_trigger.set_deferred("monitoring", false)
	mini_encounter_active = true
	_start_mini_encounter()

func _start_mini_encounter() -> void:
	print("⚔️ Mini-encounter START!")
	var wave := [RUSHER_SCENE, TANK_SCENE, RANGED_SCENE, RUSHER_SCENE]
	for i in range(MINI_SPAWNS.size()):
		var e = wave[i % wave.size()].instantiate()
		$Level.add_child(e)
		e.global_position = MINI_SPAWNS[i]
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
	print("✅ Mini-encounter complete!")
	add_score(250)

# ─── Encounter 2 (zona final antes del auto) ─────────────────────────────────
func _on_enc2_trigger(body: Node) -> void:
	if not body.is_in_group("player") or enc2_done:
		return
	enc_trigger2.set_deferred("monitoring", false)
	enc2_done = true
	print("⚔️ Encounter 2 START!")
	var wave := [TANK_SCENE, RANGED_SCENE, RUSHER_SCENE, TANK_SCENE, RANGED_SCENE]
	for i in range(ENC2_SPAWNS.size()):
		var e = wave[i % wave.size()].instantiate()
		$Level.add_child(e)
		e.global_position = ENC2_SPAWNS[i]
		enc2_enemies.append(e)
		if e.has_signal("died"):
			e.died.connect(func(): _on_enc2_died(e))
		if hud and hud.has_method("track_enemy"):
			hud.track_enemy(e)

func _on_enc2_died(e: Node) -> void:
	add_score(180)
	if e and is_instance_valid(e):
		_drop_loot(e.global_position)
	enc2_enemies.erase(e)
	if enc2_enemies.size() == 0:
		_spawn_car_key()

func _spawn_car_key() -> void:
	print("🚗 Car Key dropped!")
	add_score(300)
	var ck = CAR_KEY_SCENE.instantiate()
	$Level.add_child(ck)
	ck.global_position = CAR_KEY_POS

# ─── Car Key pickup → Stage 3 ─────────────────────────────────────────────────
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

# ─── Player died ──────────────────────────────────────────────────────────────
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

# ─── Helpers ─────────────────────────────────────────────────────────────────
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
