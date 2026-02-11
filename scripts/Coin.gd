extends Area2D

func _ready() -> void:
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return
	var main := get_tree().current_scene
	if main and main.has_method("add_score"):
		main.add_score(25)
	queue_free()
