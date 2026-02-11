extends SceneTree

func _initialize() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = main_scene.instantiate()
	root.add_child(main)

	# Esperar 1 frame para que Main _ready() spawnee enemigos
	await process_frame
	await physics_frame

	var player: Node2D = main.get_node("Player") as Node2D
	var attack_area: Area2D = player.get_node("AttackArea") as Area2D

	# Buscar cualquier enemigo: nodo con método take_hit y distinto al player
	var enemies: Array[Node2D] = []
	for c in main.get_children():
		if c == player:
			continue
		if c is Node2D and c.has_method("take_hit"):
			enemies.append(c)

	print("ENEMIES_FOUND=", enemies.size())
	for e in enemies:
		print(" - ", e.name, " class=", e.get_class(), " layer=", e.collision_layer if e is CollisionObject2D else "?")

	if enemies.size() == 0:
		print("❌ No enemies found in Main children.")
		quit()
		return

	var enemy: Node2D = enemies[0]

	# Forzar positions para overlap
	player.global_position = Vector2(300, 120)
	enemy.global_position = Vector2(318, 120)
	attack_area.position = Vector2(18, 0)

	print("PLAYER=", player.global_position, " ENEMY=", enemy.global_position)
	print("AttackArea layer=", attack_area.collision_layer, " mask=", attack_area.collision_mask)

	attack_area.monitoring = true
	await physics_frame

	var raw := attack_area.get_overlapping_bodies()
	print("OVERLAPS size=", raw.size())
	for b in raw:
		print(" - ", b.name, " class=", b.get_class())

	quit()
