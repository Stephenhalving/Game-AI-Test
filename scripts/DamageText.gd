extends Label

@export var lifetime: float = 0.6
@export var rise_speed: float = 55.0

var t: float = 0.0

func _ready() -> void:
    set_process(true)

func _process(delta: float) -> void:
    t += delta
    position.y -= rise_speed * delta
    modulate.a = 1.0 - (t / lifetime)
    if t >= lifetime:
        queue_free()
