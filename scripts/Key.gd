extends Area2D

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body)

func _on_body(body: Node) -> void:
	if body.name != "Player":
		return

	var main := get_tree().current_scene
	if main and main.has_method("on_key_collected"):
		main.on_key_collected()

	queue_free()
