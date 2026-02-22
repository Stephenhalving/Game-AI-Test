extends Control

@onready var score_label: Label = $VBox/ScoreLabel
@onready var menu_btn: Button = $VBox/MenuBtn

func _ready() -> void:
    get_tree().paused = false
    Engine.time_scale = 1.0

    var lm := get_node_or_null("/root/LevelManagerAuto")
    if lm:
        score_label.text = "SCORE FINAL: %d" % int(lm.get("last_score"))
    else:
        score_label.text = "SCORE FINAL: 0"

    menu_btn.grab_focus()
    menu_btn.pressed.connect(_on_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_accept"):
        _on_menu_pressed()

func _on_menu_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/Menu.tscn")
