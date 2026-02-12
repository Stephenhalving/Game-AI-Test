extends SceneTree

func _initialize() -> void:
    print("🧪 SMOKE TEST START")

    var main_scene: PackedScene = load("res://scenes/Main.tscn")
    if main_scene == null:
        push_error("Main.tscn no carga")
        quit(1)
        return

    var main = main_scene.instantiate()
    root.add_child(main)

    # Activar autoplay headless si existe
    if main.has_variable("headless_autoplay"):
        main.headless_autoplay = true

    await create_timer(0.5).timeout

    print("✅ SMOKE OK: Main instanciado")
    quit(0)
