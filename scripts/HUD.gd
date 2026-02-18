extends CanvasLayer

@onready var ui: Control = $UI
@onready var player_hp: ProgressBar = $UI/PlayerHP
@onready var enemy_hp: ProgressBar = $UI/EnemyHP
@onready var score_label: Label = $UI/ScoreLabel
@onready var combo_label: Label = $UI/ComboLabel
@onready var key_label: Label = $UI/KeyLabel

var _score: int = 0
var _combo_text: String = "-"
var _has_key: bool = false

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

func _process(_delta: float) -> void:
    var main := get_tree().current_scene
    if main == null:
        return

    # PLAYER HP
    var player := main.get_node_or_null("Player")
    if player and player_hp:
        var hp = player.get("hp")
        var mx = player.get("max_hp")
        if typeof(hp) != TYPE_NIL and typeof(mx) != TYPE_NIL:
            player_hp.max_value = float(mx)
            player_hp.value = float(hp)

    # ENEMY HP (elige enemigo más cercano con hp/hp_max)
    if enemy_hp:
        var best = null
        var best_d = 1e18

        for c in main.get_children():
            if c == null:
                continue
            # Filtrar por tener variables hp y hp_max
            var ehp = c.get("hp")
            var emx = c.get("hp_max")
            if typeof(ehp) == TYPE_NIL or typeof(emx) == TYPE_NIL:
                continue
            # distancia al player (si existe)
            var d = 0.0
            if player and "global_position" in c:
                d = player.global_position.distance_squared_to(c.global_position)
            if d < best_d:
                best_d = d
                best = c

        if best != null:
            var ehp2 = int(best.get("hp"))
            var emx2 = int(best.get("hp_max"))
            enemy_hp.max_value = float(emx2)
            enemy_hp.value = float(ehp2)
        else:
            # si no hay enemigos, vaciamos la barra
            enemy_hp.value = 0
