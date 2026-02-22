extends CharacterBody2D

signal hp_changed(new_hp: int, hp_max: int)
signal combo_changed(step: int)

@export var speed := 170.0
@export var max_hp := 10
var hp := 10

var facing := 1.0
var invuln := 0.0
var hurt_timer := 0.0
var hurt_knock_x := 0.0

var last_action := "IDLE"
var anim_lock := 0.0

# --- STATE ---
enum State { IDLE, RUN, JUMP, ATK, HEAVY, HURT, KO }
var state: int = State.IDLE

@export var accel := 1200.0
@export var friction := 1400.0

# Belt scroller depth movement
@export var floor_y_min: float = 148.0
@export var floor_y_max: float = 212.0
@export var visual_jump_height: float = 55.0
var is_jumping: bool = false

var action_timer := 0.0

var combo_step := 0
var combo_timer := 0.0
var combo_window := 0.35

var attack_cooldown := 0.0
var current_damage := 1
var current_knock := 260.0
var current_lift := 0.0
var last_attack_heavy := false

# evita multi-hit por misma ventana
var attack_consumed := false

@onready var attack_area: Area2D = $AttackArea
@onready var cam: Camera2D        = $Camera2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var wall_left: RayCast2D  = $WallRayLeft
@onready var wall_right: RayCast2D = $WallRayRight
@onready var hurt_area: Area2D     = $HurtArea

var sprite: Sprite2D = null


func _ready() -> void:
	add_to_group("player")
	print("✅ Player READY")
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	attack_area.monitoring = false
	if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
		attack_area.body_entered.connect(_on_attack_area_body_entered)

	sprite = get_node_or_null("Visual/Sprite2D")
	if sprite:
		sprite.texture = _sg_tex("player_idle")

	if anim:
		anim.play("idle")


func _physics_process(delta: float) -> void:
	if Engine.get_physics_frames() % 30 == 0:
		if DisplayServer.get_name() != "headless":
			print("🟦 Player tick pos=", global_position, " vel=", velocity)

	# --- INPUT ---
	var dir   := Input.get_axis("move_left",  "move_right")
	var move_y := Input.get_axis("move_up",   "move_down")
	if DisplayServer.get_name() == "headless":
		dir = 1.0

	var pressed_jump   := Input.is_action_just_pressed("jump")
	var pressed_attack := Input.is_action_just_pressed("attack")
	var pressed_heavy  := Input.is_action_just_pressed("heavy")

	# --- TIMERS ---
	action_timer   = max(0.0, action_timer   - delta)
	attack_cooldown = max(0.0, attack_cooldown - delta)
	combo_timer    = max(0.0, combo_timer    - delta)
	invuln         = max(0.0, invuln         - delta)
	hurt_timer     = max(0.0, hurt_timer     - delta)
	anim_lock      = max(0.0, anim_lock      - delta)

	# --- COMBO EXPIRY ---
	if combo_step > 0 and combo_timer <= 0.0:
		combo_step = 0
		combo_changed.emit(0)

	if dir < -0.01:
		facing = -1.0
	elif dir > 0.01:
		facing = 1.0

	# --- CONTROL GATE ---
	var can_control := (hurt_timer <= 0.0) and \
		(state != State.ATK) and (state != State.HEAVY) and (state != State.KO)

	# heavy (K)
	if pressed_heavy and attack_cooldown <= 0.0 and can_control:
		_do_heavy_attack()

	# combo normal (J)
	if pressed_attack and attack_cooldown <= 0.0 and can_control:
		_do_combo_attack()

	# salto visual (Space)
	if pressed_jump and not is_jumping and can_control:
		_do_visual_jump()

	# --- HORIZONTAL MOVEMENT ---
	if can_control:
		if abs(dir) > 0.01:
			velocity.x = move_toward(velocity.x, dir * speed, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
		if state == State.HURT:
			velocity.x = hurt_knock_x

	# --- DEPTH (Y) MOVEMENT — bloqueado solo en KO ---
	if state != State.KO:
		velocity.y = move_y * speed * 0.55
	else:
		velocity.y = 0.0

	# --- salir de ATK/HEAVY cuando termina el lock ---
	if anim_lock <= 0.0 and (state == State.ATK or state == State.HEAVY):
		state = State.IDLE

	# --- estados base ---
	if state != State.HURT and state != State.KO \
			and state != State.ATK and state != State.HEAVY:
		if is_jumping:
			state = State.JUMP
		elif abs(velocity.x) > 5.0:
			state = State.RUN
		else:
			state = State.IDLE

	# --- animación básica ---
	if can_control and anim_lock <= 0.0:
		if abs(velocity.x) > 1.0 and not is_jumping:
			if anim and anim.current_animation != "run":
				anim.play("run")
		else:
			if anim and anim.current_animation != "idle":
				anim.play("idle")

	move_and_slide()

	# Belt scroller: clamp Y, z-index
	position.y = clamp(position.y, floor_y_min, floor_y_max)
	z_index = int(global_position.y)

	# Actualizar sprite
	_update_sprite()

	# Blink invuln — sobre nodo Visual
	var visual_node := get_node_or_null("Visual")
	if visual_node:
		visual_node.visible = \
			(int(Time.get_ticks_msec() / 80) % 2 == 0) or (invuln <= 0.0)


# ── Visual jump (sin cambiar posición real) ──────────────────────────────────
func _do_visual_jump() -> void:
	is_jumping = true
	invuln = max(invuln, 0.30)
	var visual := get_node_or_null("Visual")
	if visual:
		var tw := create_tween()
		tw.tween_property(visual, "position:y", -visual_jump_height, 0.22) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(visual, "position:y", 0.0, 0.18) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func(): is_jumping = false)
	else:
		await get_tree().create_timer(0.40).timeout
		is_jumping = false


# ── Sprite update ─────────────────────────────────────────────────────────────
func _update_sprite() -> void:
	if not sprite:
		return
	var state_name := "idle"
	match state:
		State.RUN:                  state_name = "walk"
		State.ATK, State.HEAVY:     state_name = "attack"
		State.HURT, State.KO:       state_name = "hurt"
		State.JUMP:                 state_name = "idle"
	sprite.texture = _sg_tex("player_" + state_name)
	sprite.flip_h  = (facing < 0)


# ── Ataques ───────────────────────────────────────────────────────────────────
func _do_heavy_attack() -> void:
	state = State.HEAVY
	anim_lock = 0.26
	last_attack_heavy = true
	combo_step  = 0
	combo_timer = 0.0
	current_damage = 2
	current_knock  = 420.0
	current_lift   = 420.0

	if anim and anim.has_animation("heavy"):
		anim.play("heavy")

	_set_action("HEAVY", 0.26)
	attack_cooldown = 0.22
	_do_attack_window()


func _do_combo_attack() -> void:
	state = State.ATK
	anim_lock = 0.18
	last_attack_heavy = false

	if combo_timer <= 0.0:
		combo_step = 1
	else:
		combo_step += 1
		if combo_step > 3:
			combo_step = 1

	if anim:
		if combo_step == 1 and anim.has_animation("atk1"):
			anim.play("atk1")
		elif combo_step == 2 and anim.has_animation("atk2"):
			anim.play("atk2")
		elif combo_step == 3 and anim.has_animation("atk3"):
			anim.play("atk3")
		elif anim.has_animation("attack"):
			anim.play("attack")

	combo_changed.emit(combo_step)

	if combo_step == 1:
		current_damage = 1
		current_knock  = 220.0
		current_lift   = 0.0
		_set_action("ATK1", 0.18)
	elif combo_step == 2:
		current_damage = 1
		current_knock  = 260.0
		current_lift   = 0.0
		_set_action("ATK2", 0.18)
	else:
		current_damage = 2
		current_knock  = 360.0
		current_lift   = 180.0
		_set_action("ATK3", 0.22)

	attack_cooldown = 0.12
	combo_timer = combo_window
	_do_attack_window()


func _do_attack_window() -> void:
	attack_consumed = false
	attack_area.position.x = 18.0 * facing
	attack_area.set_deferred("monitoring", true)

	await get_tree().physics_frame

	var bodies: Array[Node2D] = attack_area.get_overlapping_bodies()
	for b in bodies:
		if attack_consumed:
			break
		_on_attack_area_body_entered(b)

	await get_tree().create_timer(0.10).timeout
	attack_area.set_deferred("monitoring", false)


func _on_attack_area_body_entered(body: Node) -> void:
	if body == self:
		return
	if body.has_method("take_hit") and not attack_consumed:
		attack_consumed = true
		body.take_hit(facing, current_knock, current_damage, current_lift)

		var main: Node = get_tree().current_scene
		if main and main.has_method("hitstop"):
			if last_attack_heavy:
				main.hitstop(0.09, 0.04)
			else:
				main.hitstop(0.05, 0.08)

		if last_attack_heavy and has_method("_shake_cam"):
			_shake_cam(4.0, 0.11)


func take_damage(from_dir: float, dmg: int = 1, knock: float = 180.0) -> void:
	if invuln > 0.0:
		return
	hp -= dmg
	hp_changed.emit(hp, max_hp)
	invuln    = 0.8
	hurt_timer = 0.10
	hurt_knock_x = knock * from_dir
	_set_action("HURT", 0.25)
	if hp <= 0:
		hp = 0
		state = State.KO
		_set_action("KO", 1.0)

		var main := get_tree().current_scene
		if main and main.has_method("on_player_died"):
			main.call_deferred("on_player_died")
		else:
			get_tree().reload_current_scene()
		return


func _set_action(name: String, seconds: float) -> void:
	last_action  = name
	action_timer = seconds


# --- SpriteGen helper (acceso seguro por ruta de nodo) ---
func _sg_tex(key: String) -> ImageTexture:
	var sg := get_node_or_null("/root/SpriteGen")
	if sg == null or not sg.has_method("get_texture"):
		return null
	return sg.call("get_texture", key) as ImageTexture


# --- Camera shake helper ---
func _shake_cam(intensity: float = 3.0, duration: float = 0.10) -> void:
	if not cam:
		return
	var base: Vector2 = cam.position
	var steps := 6
	var step_t := duration / float(steps)
	if step_t < 0.01:
		step_t = 0.01
	for _i in range(steps):
		cam.position = base + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		await get_tree().create_timer(step_t).timeout
	cam.position = base
