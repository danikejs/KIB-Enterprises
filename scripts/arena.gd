extends Node2D
## Câmera de cima. A simulação usa eixos de profundidade/lateral próprios.
const Rules = preload("res://scripts/match_rules.gd")
const PARK = preload("res://assets/art/park.png")
const PLAYERS = preload("res://assets/art/players.png")
const TABLE := Rect2(496, 198, 288, 336)
const PLAY_AREA := Rect2(496, 144, 288, 444)
const BG := Color("19251d")
const MINT := Color("a8dbc1")
const WHITE := Color("fff4d5")
var pixel_players: ImageTexture
var rules: Node
var display_mode: String = "menu"
var elapsed: float = 0.0
var trails: Array[Vector2] = []
var sparks: Array[Dictionary] = []
var sample: float = 0.0
var player_swing: float = 0.0
var cpu_swing: float = 0.0
var previous_player: float = 382.0
var previous_cpu: float = 382.0
var player_step: int = 0
var cpu_step: int = 0
var player_stride: float = 0.0
var cpu_stride: float = 0.0

static func court_to_screen(point: Vector2) -> Vector2:
	return Vector2(PLAY_AREA.position.x + (point.y - Rules.FIELD.position.y) / Rules.FIELD.size.y * PLAY_AREA.size.x,
		PLAY_AREA.end.y - (point.x - Rules.FIELD.position.x) / Rules.FIELD.size.x * PLAY_AREA.size.y)

static func screen_x_to_lateral(x: float) -> float:
	return Rules.FIELD.position.y + (x - PLAY_AREA.position.x) / PLAY_AREA.size.x * Rules.FIELD.size.y

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Grade nativa fixa: cada pose tem 32 x 48 pixels; desenhada em escala inteira 3x.
	var atlas_image := PLAYERS.get_image()
	atlas_image.resize(128, 96, Image.INTERPOLATE_NEAREST)
	pixel_players = ImageTexture.create_from_image(atlas_image)

func _process(delta: float) -> void:
	elapsed += delta
	if rules != null and not rules.paused:
		player_swing = maxf(0, player_swing - delta)
		cpu_swing = maxf(0, cpu_swing - delta)
		var player_distance: float = absf(rules.player_y - previous_player)
		var cpu_distance: float = absf(rules.cpu_y - previous_cpu)
		player_stride += player_distance
		cpu_stride += cpu_distance
		player_step = (1 + int(player_stride / 24.0) % 2) if player_distance > 0.05 else 0
		cpu_step = (1 + int(cpu_stride / 24.0) % 2) if cpu_distance > 0.05 else 0
		previous_player = rules.player_y
		previous_cpu = rules.cpu_y
		for i in range(sparks.size() - 1, -1, -1):
			sparks[i].life -= delta
			if sparks[i].life <= 0:
				sparks.remove_at(i)
		if rules.running and not rules.serving:
			sample += delta
			if sample >= 0.018:
				sample = 0
				trails.append(rules.ball)
				if trails.size() > 8:
					trails.pop_front()
		else:
			trails.clear()
	queue_redraw()

func on_impact(where: Vector2, kind: String) -> void:
	var duration := 0.30 if kind in ["hit", "bounce"] else 0.55
	sparks.append({"position": where, "kind": kind, "life": duration, "duration": duration})
	if kind in ["hit", "special", "perfect"]:
		if where.x < 640:
			player_swing = 0.24
		else:
			cpu_swing = 0.24

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), BG)
	draw_texture_rect(PARK, Rect2(0, 0, 1280, 720), false)
	if display_mode == "game" and rules != null:
		draw_game()
	elif display_mode == "menu":
		draw_demo()
	else:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.045, 0.08, 0.055, 0.84))
	# Folhas pequenas nas laterais; o centro da mesa permanece limpo.
	if display_mode in ["game", "menu"]:
		for i in range(9):
			var x := 120.0 + fmod(i * 157.0 + sin(elapsed * 0.28 + i) * 12, 1070)
			var y := fmod(i * 89.0 + elapsed * (6 + i % 3), 710)
			if x < 430 or x > 850:
				draw_rect(Rect2(Vector2(x, y).snapped(Vector2(2, 2)), Vector2(4, 2)), Color("c5b85d"))

func draw_table(rect: Rect2) -> void:
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	var mid := rect.get_center()
	# Sombra, estrutura e pés aparecem sob o tampo.
	draw_rect(Rect2(left + 12, top + 17, rect.size.x + 10, rect.size.y + 26), Color(0.08, 0.12, 0.12, 0.32))
	for x in [left + 20, right - 27]:
		draw_rect(Rect2(x, bottom - 14, 8, 40), Color("334444"))
		draw_rect(Rect2(x - 2, bottom + 23, 12, 5), Color("20332f"))
	draw_rect(Rect2(left + 27, bottom + 7, rect.size.x - 52, 6), Color("556861"))
	draw_rect(Rect2(left - 3, top - 3, rect.size.x + 6, rect.size.y + 12), Color("293b3d"))
	draw_rect(rect, Color("287f93"))
	draw_rect(Rect2(left, top, rect.size.x, rect.size.y / 2), Color("24778c"))
	draw_rect(rect.grow(-3), Color("cee0c3"), false, 2)
	draw_line(Vector2(mid.x, top + 4), Vector2(mid.x, bottom - 4), Color("81b5b3"), 2)
	# Desgaste discreto do tampo, com pixels retos.
	for i in range(10):
		var px := left + 18 + fmod(i * 73, rect.size.x - 36)
		var py := top + 17 + fmod(i * 47, rect.size.y - 30)
		draw_rect(Rect2(px, py, 4 + i % 3, 2), Color(0.45, 0.75, 0.73, 0.16))
	# Rede horizontal elevada com malha e postes laterais.
	draw_rect(Rect2(left - 8, mid.y - 4, rect.size.x + 16, 5), Color(0.05, 0.12, 0.14, 0.35))
	draw_rect(Rect2(left - 4, mid.y - 14, rect.size.x + 8, 14), Color("9bbfc0"))
	for x in range(int(left), int(right), 6):
		for y in range(int(mid.y - 12), int(mid.y - 2), 5):
			draw_rect(Rect2(x, y, 3, 3), Color("3c7e91"))
	draw_line(Vector2(left - 6, mid.y - 15), Vector2(right + 6, mid.y - 15), Color("e3e6c8"), 3)
	for x in [left - 8, right + 4]:
		draw_rect(Rect2(x, mid.y - 16, 4, 21), Color("c6cbb5"))

func actor(x: float, top: float, row: int, frame: int) -> void:
	var size := Vector2(96, 144)
	var cell := Vector2(32, 48)
	var source := Rect2(Vector2(frame, row) * cell, cell)
	var dest := Rect2(Vector2(x - size.x / 2, top).snapped(Vector2(2, 2)), size)
	var feet := Vector2(x, top + 129)
	_draw_polygon_ellipse(feet, Vector2(24, 5), Color(0.14, 0.17, 0.10, 0.24))
	draw_texture_rect_region(pixel_players, dest, source)

func _draw_polygon_ellipse(center: Vector2, scale_factor: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(16):
		points.append((center + Vector2(cos(i * TAU / 16), sin(i * TAU / 16)) * scale_factor).snapped(Vector2(1, 1)))
	draw_colored_polygon(points, color)

func draw_game() -> void:
	var player_pos := court_to_screen(Vector2(Rules.PLAYER_X, rules.player_y))
	var cpu_pos := court_to_screen(Vector2(Rules.CPU_X, rules.cpu_y))
	actor(cpu_pos.x, 80, 1, 3 if cpu_swing > 0 else cpu_step)
	draw_table(TABLE)
	actor(player_pos.x, 496, 0, 3 if player_swing > 0 else player_step)
	# Marcas de alcance discretas mostram onde receber a bola.
	var reach: float = rules.player_height / Rules.FIELD.size.y * PLAY_AREA.size.x
	draw_line(Vector2(player_pos.x - reach / 2, 538), Vector2(player_pos.x + reach / 2, 538), Color(MINT, 0.8), 2)
	if rules.special_armed:
		_draw_polygon_ellipse(Vector2(player_pos.x, 618), Vector2(30, 7), Color(0.94, 0.64, 0.28, 0.35))
	var color := Color("ffc267") if rules.fireball else WHITE
	var ball_pos := court_to_screen(rules.ball)
	var progress: float = (rules.ball.x - Rules.PLAYER_X) / (Rules.CPU_X - Rules.PLAYER_X)
	if rules.velocity.x < 0:
		progress = 1.0 - progress
	var height := 3.0 if rules.serving else 3.0 + absf(sin(progress / 0.72 * PI)) * 11.0
	_draw_polygon_ellipse(ball_pos + Vector2(4, 5), Vector2(5, 2.5), Color(0.04, 0.13, 0.12, 0.35))
	for i in range(trails.size()):
		var ratio := float(i + 1) / (trails.size() + 1)
		var p := court_to_screen(trails[i]) - Vector2(0, height)
		var width := 2 + ratio * 3
		draw_rect(Rect2(p.snapped(Vector2(2, 2)), Vector2(width, width)), Color(color, ratio * 0.45))
	var airborne := (ball_pos - Vector2(0, height)).snapped(Vector2(1, 1))
	draw_rect(Rect2(airborne - Vector2(4, 3), Vector2(8, 6)), color)
	draw_rect(Rect2(airborne - Vector2(3, 4), Vector2(6, 8)), color)
	draw_rect(Rect2(airborne + Vector2(-2, -3), Vector2(3, 2)), Color.WHITE)
	for spark in sparks:
		var fraction := float(spark.life) / float(spark.duration)
		var p := court_to_screen(spark.position)
		var radius := 4 + (1 - fraction) * 16
		var effect_color := MINT if spark.kind == "perfect" else color
		if spark.kind == "bounce":
			_draw_polygon_ellipse(p, Vector2(radius * 0.7, radius * 0.2), Color(effect_color, fraction * 0.35))
		else:
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2((p + direction * radius).snapped(Vector2(2, 2)), Vector2(3, 3)), Color(effect_color, fraction))

func draw_demo() -> void:
	var rect := Rect2(748, 234, 264, 304)
	var t := elapsed * 1.2
	var cpu_x := 880 + sin(t) * 64
	var player_x := 880 + sin(t + 1.2) * 64
	actor(cpu_x, 110, 1, 1 if sin(t) < 0 else 2)
	draw_table(rect)
	actor(player_x, 510, 0, 3 if sin(t * 2) > 0.85 else 0)
	var p := Vector2(880 + sin(t) * 70, 368 + sin(t * 1.4) * 138)
	_draw_polygon_ellipse(p + Vector2(3, 4), Vector2(4, 2), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(p - Vector2(3, 12), Vector2(6, 6)), WHITE)
