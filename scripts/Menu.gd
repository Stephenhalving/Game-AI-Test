extends Control

@onready var start_btn: Button = $VBox/StartBtn

func _ready() -> void:
    print("✅ MENU READY (Menu.gd)")

    # foco para ENTER
    start_btn.focus_mode = Control.FOCUS_ALL
    start_btn.grab_focus()

    # Evitar doble conexión (por si también existe en Menu.tscn)
    if start_btn.pressed.is_connected(_on_start_btn_pressed):
        start_btn.pressed.disconnect(_on_start_btn_pressed)

    start_btn.pressed.connect(_on_start_btn_pressed)

func _unhandled_input(event: InputEvent) -> void:
    # Fallback: ENTER arranca el juego aunque el botón no reciba click/focus
    if event.is_action_pressed("ui_accept"):
        _on_start_btn_pressed()

func _on_start_btn_pressed() -> void:
    print("▶️ START GAME (Menu)")

    # ✅ Force physics to run (safe)
    get_tree().paused = false
    Engine.time_scale = 1.0

    var lm := get_node_or_null("/root/LevelManagerAuto")
    if lm:
        lm.call_deferred("start_game")
    else:
        get_tree().change_scene_to_file("res://scenes/Main.tscn")
