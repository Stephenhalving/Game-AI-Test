extends Node
class_name LevelConfig

# Config por nivel (por ahora Level 1 y 2 iguales).
static func get_level(level: int) -> Dictionary:
    var base := {
        "max_enemies": 3,
        "spawn_origin": Vector2(320, 120),
        "spawn_spacing_x": 34.0,
        "enemy_weights": { "rusher": 0.4, "tank": 0.3, "ranged": 0.3 },
        "key_drop_chance": 0.25, # chance de llave cuando dropea loot
        "loot_coin_chance": 0.50,
        "loot_food_chance": 0.25,
    }
    # Si más adelante querés variar el Level 2:
    if level == 2:
        base["max_enemies"] = 3
    return base


