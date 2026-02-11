extends Area2D

@export var speed := 260
var dir := 1

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	position.x += speed * dir * delta

func _on_body(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(dir, 1, 320)
	queue_free()
