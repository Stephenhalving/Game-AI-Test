extends CharacterBody2D

signal died

@export var speed: float = 90.0
@export var gravity: float = 1200.0

@export var hp_max: int = 3
@export var hp: int = 3

@export var chase_range: float = 260.0
@export var attack_range: float = 34.0
@export var attack_cooldown: float = 0.9

var direction := -1.0
var atk_cd := 0.0

@onready var attack_area: Area2D = $AttackArea
@onready var player: Node = get_parent().get_node_or_null("Player")

func _ready() -> void:
    hp = hp_max
    attack_area.monitoring = false
    if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
        attack_area.body_entered.connect(_on_attack_area_body_entered)

func _physics_process(delta: float) -> void:
    atk_cd = max(0.0, atk_cd - delta)

    velocity.y += gravity * delta

    if player == null:
        player = get_parent().get_node_or_null("Player")

    if player:
        var dx: float = player.global_position.x - global_position.x
        var dist: float = abs(dx)
        direction = 1.0 if dx > 0.0 else -1.0

        if dist <= chase_range:
            velocity.x = direction * speed
        else:
            velocity.x = 0.0

        if dist <= attack_range and atk_cd <= 0.0:
            _do_attack()

    move_and_slide()

func _do_attack() -> void:
    atk_cd = attack_cooldown
    attack_area.position.x = 18.0 * direction
    attack_area.set_deferred("monitoring", true)
    await get_tree().create_timer(0.10).timeout
    attack_area.set_deferred("monitoring", false)

func _on_attack_area_body_entered(body: Node) -> void:
    if body.has_method("take_damage"):
        body.take_damage(direction, 1, 420.0)

func take_hit(from_dir: float, knock: float = 260.0, dmg: int = 1, lift: float = 0.0) -> void:
    hp -= dmg
    if hp <= 0:
        # IMPORTANT: deferir señal y free fuera de la query de física
        call_deferred("_die_deferred")

func _die_deferred() -> void:
    emit_signal("died")
    queue_free()
