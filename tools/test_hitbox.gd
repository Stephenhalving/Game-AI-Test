extends SceneTree

func _initialize() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	if main_scene == null:
		print("FAIL: can't load res://scenes/Main.tscn")
		quit()
		return

	var main: Node = main_scene.instantiate()
	root.add_child(main)

	await process_frame
	await physics_frame

	var player: Node = main.get_node_or_null("Player")
	if player == null:
		print("FAIL: no Player node in Main")
		quit()
		return

	var attack_area: Area2D = player.get_node_or_null("AttackArea") as Area2D
	if attack_area == null:
		print("FAIL: no Player/AttackArea")
		quit()
		return

	attack_area.monitoring = true
	await physics_frame

	var bodies: Array[Node2D] = attack_area.get_overlapping_bodies()
	print("TEST_HITBOX bodies=", bodies.size())
	for b: Node2D in bodies:
		print(" - ", b.name, " class=", b.get_class(), " has_take_hit=", b.has_method("take_hit"))

	attack_area.monitoring = false
	quit()
