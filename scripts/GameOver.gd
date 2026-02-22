extends Control

@onready var score_label: Label = $VBox/ScoreLabel
@onready var retry_btn: Button = $VBox/RetryBtn
@onready var menu_btn: Button = $VBox/MenuBtn

func _ready() -> void:
    get_tree().paused = false
    Engine.time_scale = 1.0

    var lm := get_node_or_null("/root/LevelManagerAuto")
    if lm:
        score_label.text = "SCORE: %d" % int(lm.get("last_score"))

    retry_btn.grab_focus()
    retry_btn.pressed.connect(_on_retry_pressed)
    menu_btn.pressed.connect(_on_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        _on_retry_pressed()

func _on_retry_pressed() -> void:
    var lm := get_node_or_null("/root/LevelManagerAuto")
    if lm:
        lm.call_deferred("start_game")
    else:
        get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_menu_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/Menu.tscn")
