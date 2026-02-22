extends CanvasLayer

@onready var player_hp: ProgressBar = $UI/PlayerHP
@onready var enemy_hp: ProgressBar = $UI/EnemyHP
@onready var score_label: Label = $UI/ScoreLabel
@onready var combo_label: Label = $UI/ComboLabel
@onready var key_label: Label = $UI/KeyLabel

var _score: int = 0
var _combo_text: String = "-"
var _has_key: bool = false

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

# --- Score / Combo / Key (already event-driven) ---

func set_score(v: int) -> void:
    _score = v
    if score_label:
        score_label.text = "SCORE: %d" % _score

func set_combo(text: String) -> void:
    _combo_text = text
    if combo_label:
        combo_label.text = "COMBO: %s" % _combo_text

func set_key(v: bool) -> void:
    _has_key = v
    if key_label:
        key_label.text = "KEY: %s" % ("YES" if _has_key else "NO")
