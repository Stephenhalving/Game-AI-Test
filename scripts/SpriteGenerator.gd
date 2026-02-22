extends Node

# --- SpriteGenerator (autoload: SpriteGen) ---
# Genera ImageTexture en runtime para cada personaje/estado.

var _cache: Dictionary = {}


func get_texture(key: String) -> ImageTexture:
	if _cache.has(key):
		return _cache[key] as ImageTexture
	var parts := key.split("_")
	if parts.size() < 2:
		return null
	var char_type: String = parts[0]
	var state: String     = parts[1]
	var tex: ImageTexture = _generate(char_type, state)
	_cache[key] = tex
	return tex


# ── tamaño en px para cada tipo ──────────────────────────────────────────────
func _get_char_size(char_type: String) -> Vector2i:
	match char_type:
		"player": return Vector2i(24, 40)
		"rusher": return Vector2i(20, 32)
		"tank":   return Vector2i(26, 36)
		"ranged": return Vector2i(18, 30)
		"boss":   return Vector2i(32, 48)
	return Vector2i(20, 32)


# ── color base por tipo ───────────────────────────────────────────────────────
func _get_base_color(char_type: String) -> Color:
	match char_type:
		"player": return Color(0.2,  0.65, 1.0)
		"rusher": return Color(1.0,  0.50, 0.1)
		"tank":   return Color(0.55, 0.15, 0.75)
		"ranged": return Color(0.1,  0.85, 0.35)
		"boss":   return Color(0.45, 0.0,  0.55)
	return Color.WHITE


# ── generación de imagen ──────────────────────────────────────────────────────
func _generate(char_type: String, state: String) -> ImageTexture:
	var size: Vector2i = _get_char_size(char_type)
	var base: Color    = _get_base_color(char_type)

	# Tinte por estado
	var body_color: Color = base
	match state:
		"walk":   body_color = base.lightened(0.10)
		"attack": body_color = base.lightened(0.28)
		"hurt":   body_color = Color(base.r * 0.5 + 0.5, base.g * 0.35, base.b * 0.35)

	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	# Región cuerpo (62 % inferior)
	var body_top: int = int(float(size.y) * 0.38)
	for y in range(body_top, size.y):
		for x in range(size.x):
			img.set_pixel(x, y, body_color)

	# Región cabeza con margen lateral
	var head_color: Color = Color(
		clampf(body_color.r + 0.18, 0.0, 1.0),
		clampf(body_color.g + 0.12, 0.0, 1.0),
		clampf(body_color.b + 0.12, 0.0, 1.0)
	)
	var hm: int = maxi(1, int(float(size.x) * 0.18))
	for y in range(0, body_top):
		for x in range(hm, size.x - hm):
			img.set_pixel(x, y, head_color)

	# Contorno negro 1 px
	var outline: Color = Color(0.0, 0.0, 0.0, 1.0)
	# borde superior cabeza
	for x in range(hm, size.x - hm):
		img.set_pixel(x, 0, outline)
	# lados cabeza
	for y in range(0, body_top):
		img.set_pixel(hm,             y, outline)
		img.set_pixel(size.x - hm - 1, y, outline)
	# lados cuerpo
	for y in range(body_top, size.y):
		img.set_pixel(0,          y, outline)
		img.set_pixel(size.x - 1, y, outline)
	# base y separación cuello
	for x in range(size.x):
		img.set_pixel(x, size.y - 1, outline)
		img.set_pixel(x, body_top,   outline)

	# Indicador de ataque: punto amarillo en cabeza
	if state == "attack":
		var cx: int    = size.x / 2
		var cy: int    = body_top / 2
		var dot: Color = Color(1.0, 1.0, 0.0, 1.0)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var px: int = cx + dx
				var py: int = cy + dy
				if px >= 0 and px < size.x and py >= 0 and py < size.y:
					img.set_pixel(px, py, dot)

	return ImageTexture.create_from_image(img)
