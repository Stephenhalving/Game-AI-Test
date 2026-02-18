extends Area2D

func _ready() -> void:
    monitoring = true
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if body.name != "Player":
        return
    # Player.gd tiene hp y max_hp
    body.hp = min(body.max_hp, body.hp + 3)
    queue_free()
