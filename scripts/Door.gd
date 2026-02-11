extends StaticBody2D

@export var is_open: bool = false
@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var exit_area: Area2D = $ExitArea

func _ready() -> void:
	exit_area.body_entered.connect(_on_exit_body_entered)
	_update_state_deferred()

func open() -> void:
	is_open = true
	_update_state_deferred()

func _update_state_deferred() -> void:
	# Evita "flushing queries"
	collider.set_deferred("disabled", is_open)
	# Trigger solo cuando esté abierta
	exit_area.set_deferred("monitoring", is_open)
	# feedback visual
	self.set_deferred("modulate", Color(0.5, 1, 0.5, 1) if is_open else Color(1, 0.5, 0.5, 1))

func _on_exit_body_entered(body: Node) -> void:
	if not is_open:
		return

	if body.name == "Player":
		# evita doble trigger
		exit_area.set_deferred("monitoring", false)
		print("🚪 EXIT -> LEVEL COMPLETE")
		var main := get_tree().current_scene
		if main and main.has_method("on_level_complete"):
			main.call_deferred("on_level_complete")
