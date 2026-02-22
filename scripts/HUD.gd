extends CanvasLayer

@onready var player_hp: ProgressBar = $UI/PlayerHP
@onready var enemy_hp: ProgressBar = $UI/EnemyHP
@onready var score_label: Label = $UI/ScoreLabel
@onready var combo_label: Label = $UI/ComboLabel
@onready var key_label: Label = $UI/KeyLabel

var _score: int = 0
var _has_key: bool = false

const COMBO_COLORS := [
    Color(1.0, 1.0, 1.0),   # x1 — blanco
    Color(1.0, 0.85, 0.2),  # x2 — amarillo
    Color(1.0, 0.4,  0.1),  # x3 — naranja fuerte
]
const COMBO_TEXTS := ["x1", "x2", "x3 !"]

# --- Player HP (signal-driven) ---

func init_player(p: Node) -> void:
    if p == null:
        return
    if p.has_signal("hp_changed") and not p.hp_changed.is_connected(_on_player_hp_changed):
        p.hp_changed.connect(_on_player_hp_changed)
    # set initial bar values
    var hp = p.get("hp")
    var mx = p.get("max_hp")
    if typeof(hp) != TYPE_NIL and typeof(mx) != TYPE_NIL and player_hp:
        player_hp.max_value = float(mx)
        player_hp.value = float(hp)

func _on_player_hp_changed(new_hp: int, hp_max: int) -> void:
    if player_hp:
        player_hp.max_value = float(hp_max)
        player_hp.value = float(new_hp)

# --- Enemy HP (signal-driven, tracks last-hit enemy) ---

func track_enemy(enemy: Node) -> void:
    if enemy == null:
        return
    if enemy.has_signal("hp_changed") and not enemy.hp_changed.is_connected(_on_enemy_hp_changed):
        enemy.hp_changed.connect(_on_enemy_hp_changed)
    # show current HP immediately
    var hp = enemy.get("hp")
    var mx = enemy.get("hp_max")
    if typeof(hp) != TYPE_NIL and typeof(mx) != TYPE_NIL and enemy_hp:
        enemy_hp.max_value = float(mx)
        enemy_hp.value = float(hp)

func clear_enemy_hp() -> void:
    if enemy_hp:
        enemy_hp.value = 0

func _on_enemy_hp_changed(new_hp: int, hp_max: int) -> void:
    if enemy_hp:
        enemy_hp.max_value = float(hp_max)
        enemy_hp.value = float(new_hp)

# --- Combo (signal-driven, animated) ---

func _ready() -> void:
    if combo_label:
        combo_label.modulate.a = 0.0
        combo_label.text = ""

func _on_combo_changed(step: int) -> void:
    if not combo_label:
        return
    if step <= 0:
        var tw := create_tween()
        tw.tween_property(combo_label, "modulate:a", 0.0, 0.25)
        return
    var idx := clampi(step - 1, 0, COMBO_TEXTS.size() - 1)
    combo_label.text = COMBO_TEXTS[idx]
    var base: Color = COMBO_COLORS[idx]
    # flash bright then settle to base color
    combo_label.modulate = Color(base.r * 2.2, base.g * 2.2, base.b * 2.2, 1.0)
    var tw := create_tween()
    tw.tween_property(combo_label, "modulate", base, 0.14)

# --- Score / Key (already event-driven) ---

func set_score(v: int) -> void:
    _score = v
    if score_label:
        score_label.text = "SCORE: %d" % _score

func set_key(v: bool) -> void:
    _has_key = v
    if key_label:
        key_label.text = "KEY: %s" % ("YES" if _has_key else "NO")
