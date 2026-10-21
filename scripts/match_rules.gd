extends Node
## Simulação em coordenadas lógicas: X = profundidade; Y = deslocamento lateral.
## A câmera transforma profundidade em vertical e lateral em horizontal.
signal feedback(text: String, kind: String)
signal impact(position: Vector2, kind: String)
signal scored(player_won: bool)
signal match_finished(player_won: bool)

const FIELD := Rect2(92, 178, 1096, 408)
const PLAYER_X := 132.0
const CPU_X := 1148.0
const RADIUS := 9.0
const PADDLE_WIDTH := 14.0
const OPPONENTS := [
	{"name": "MURALHA", "style": "DEFENSIVO", "speed": 275.0, "reaction": 0.19, "error": 47.0, "height": 96.0, "color": "84b8ff", "description": "Trocas longas. Encontre o ângulo."},
	{"name": "FAÍSCA", "style": "AGRESSIVO", "speed": 320.0, "reaction": 0.16, "error": 37.0, "height": 80.0, "color": "ffb775", "description": "Ataques rápidos. Prepare o contra-ataque."},
	{"name": "VÉRTICE", "style": "TÉCNICO", "speed": 340.0, "reaction": 0.13, "error": 29.0, "height": 84.0, "color": "c5a0ff", "description": "Bolas com efeito. Leia a trajetória."},
	{"name": "CAOS", "style": "IMPREVISÍVEL", "speed": 360.0, "reaction": 0.12, "error": 32.0, "height": 82.0, "color": "ff8197", "description": "Ritmo variável. Confie no seu timing."}
]
const UPGRADES := [
	{"name": "Defesa", "tag": "SEGURAR A TROCA"},
	{"name": "Efeito", "tag": "ABRIR ÂNGULOS"},
	{"name": "Ataque", "tag": "ACELERAR A BOLA"}
]
const BUILD_STEPS := [
	[
		{"name": "Raquete firme", "gain": "Área de contato +14 unidades.", "cost": "Movimento 5% mais lento."},
		{"name": "Sangue frio", "gain": "Janela do perfeito +20 ms.", "cost": "Bônus de velocidade do perfeito: 8%, em vez de 10%."},
		{"name": "Contra-ataque", "gain": "Perfeito: +25% de velocidade e 30 de carga.", "cost": "Exige 3 escolhas em Defesa; mantém o movimento reduzido."}
	],
	[
		{"name": "Giro de pulso", "gain": "Intensidade do efeito +45%.", "cost": "Janela do perfeito -10 ms."},
		{"name": "Passo cruzado", "gain": "Efeito gerado pelo movimento +80%.", "cost": "Movimento 5% mais lento."},
		{"name": "Incêndio curvo", "gain": "O especial mantém 100% do efeito, em vez de 40%.", "cost": "Carga por rebatida -2; exige 3 escolhas em Efeito."}
	],
	[
		{"name": "Bola pesada", "gain": "Especial: +45% de velocidade, em vez de 32%.", "cost": "Carga por rebatida -2."},
		{"name": "Na risca", "gain": "Perfeito: +20% de velocidade, em vez de 10%.", "cost": "Janela do perfeito -15 ms."},
		{"name": "Segunda chama", "gain": "Após o especial, a barra mantém 20 de carga.", "cost": "Exige 3 escolhas em Ataque; mantém a janela reduzida."}
	]
]
@export var points_to_win: int = 7
@export var max_ball_speed: float = 1200.0
@export var player_speed: float = 460.0
var difficulty: int = 1
var mouse_mode: bool = false
var stage: int = 0
var running: bool = false
var paused: bool = false
var serving: bool = true
var serve_left: float = 1.4
var serve_direction: float = 1.0
var clock: float = 0.0
var ball := Vector2(640, 382)
var velocity := Vector2.ZERO
var player_y: float = 382.0
var cpu_y: float = 382.0
var player_height: float = 90.0
var player_motion: float = 0.0
var lateral_velocity: float = 0.0
var cpu_target: float = 382.0
var cpu_reaction: float = 0.0
var ball_spin: float = 0.0
var points: Array[int] = [0, 0]
var sets: Array[int] = [0, 0]
var charge: float = 35.0
var special_armed: bool = false
var fireball: bool = false
var last_hitter_player: bool = true
var bounce_done: bool = false
var timing_window: float = 0.100
var spin_multiplier: float = 1.0
var charge_gain: float = 12.0
var last_swing: float = -10.0
var last_contact: float = -10.0
var contact_rewarded: bool = false
var total_perfect: int = 0
var total_points: int = 0
var rally: int = 0
var best_rally: int = 0
var upgrades: Array[String] = []
var build_ranks: Array[int] = [0, 0, 0]
var base_player_speed: float = 460.0
var perfect_multiplier: float = 1.10
var perfect_charge: float = 18.0
var special_multiplier: float = 1.32
var special_spin: float = 0.4
var special_refund: float = 0.0
var movement_spin: float = 1.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	base_player_speed = player_speed

func opponent() -> Dictionary:
	return OPPONENTS[stage]

func new_run() -> void:
	stage = 0
	timing_window = 0.100
	spin_multiplier = 1.0
	charge_gain = 12.0
	charge = 35.0
	total_perfect = 0
	total_points = 0
	best_rally = 0
	upgrades.clear()
	build_ranks = [0, 0, 0]
	player_speed = base_player_speed
	player_height = 90.0
	perfect_multiplier = 1.10
	perfect_charge = 18.0
	special_multiplier = 1.32
	special_spin = 0.4
	special_refund = 0.0
	movement_spin = 1.0
	running = false
	paused = false
	points = [0, 0]
	sets = [0, 0]

func begin_match(index: int = 0) -> void:
	stage = clampi(index, 0, 3)
	points = [0, 0]
	sets = [0, 0]
	lateral_velocity = 0.0
	player_motion = 0.0
	player_y = FIELD.get_center().y
	cpu_y = player_y
	cpu_target = cpu_y
	cpu_reaction = 0.0
	clock = 0.0
	serve_direction = 1.0
	running = true
	paused = false
	special_armed = false
	reset_rally(1.4)

func reset_rally(delay: float = 1.0) -> void:
	ball = FIELD.get_center()
	velocity = Vector2.ZERO
	ball_spin = 0.0
	serving = true
	serve_left = delay
	fireball = false
	bounce_done = false
	last_hitter_player = serve_direction > 0
	last_contact = -10.0
	last_swing = -10.0
	contact_rewarded = false
	rally = 0

func _physics_process(delta: float) -> void:
	if not running or paused:
		return
	clock += delta
	move_player(delta)
	move_cpu(delta)
	if serving:
		ball = Vector2(PLAYER_X + 27, player_y) if serve_direction > 0 else Vector2(CPU_X - 27, cpu_y)
		serve_left -= delta
		if serve_left <= 0:
			serving = false
			var aim := FIELD.get_center().y + rng.randf_range(-75, 75)
			velocity = Vector2(serve_direction * 980.0, aim - ball.y).normalized() * (500.0 + stage * 30.0)
		return
	# Subpassos evitam atravessar a raquete quando o frame demora.
	var steps := maxi(1, int(ceil(velocity.length() * delta / 6.0)))
	for _i in range(steps):
		advance_ball(delta / steps)
		if serving or not running:
			break

static func screen_x_to_lateral(x: float) -> float:
	return FIELD.position.y + (x - 496.0) / 288.0 * FIELD.size.y

func move_player(delta: float) -> void:
	var previous := player_y
	var target_velocity: float = 0.0
	if mouse_mode:
		var distance := screen_x_to_lateral(get_viewport().get_mouse_position().x) - player_y
		target_velocity = clampf(distance * 18.0, -player_speed, player_speed)
	else:
		target_velocity = Input.get_axis("move_up", "move_down") * player_speed
	# Arranque curto; freio mais forte para evitar deslizar após soltar a tecla.
	var acceleration := 7000.0 if is_zero_approx(target_velocity) else 5000.0
	lateral_velocity = move_toward(lateral_velocity, target_velocity, acceleration * delta)
	player_y += lateral_velocity * delta
	player_y = clampf(player_y, FIELD.position.y + player_height / 2, FIELD.end.y - player_height / 2)
	player_motion = (player_y - previous) / maxf(delta, 0.0001)
	if is_zero_approx(player_motion):
		lateral_velocity = 0.0

func move_cpu(delta: float) -> void:
	var data := opponent()
	var factor: float = [0.78, 1.0, 1.2][difficulty]
	cpu_reaction -= delta
	if cpu_reaction <= 0:
		cpu_reaction = float(data.reaction) / factor
		cpu_target = FIELD.get_center().y
		if velocity.x > 0:
			cpu_target = ball.y + rng.randf_range(-float(data.error), float(data.error)) / factor
	cpu_y = move_toward(cpu_y, cpu_target, float(data.speed) * factor * delta)
	var half := float(data.height) / 2
	cpu_y = clampf(cpu_y, FIELD.position.y + half, FIELD.end.y - half)

func advance_ball(delta: float) -> void:
	var previous := ball
	var speed := velocity.length()
	velocity.y += ball_spin * delta
	velocity = velocity.normalized() * speed
	if absf(velocity.x) < speed * 0.48:
		velocity.x = signf(velocity.x) * speed * 0.48
		velocity = velocity.normalized() * speed
	ball_spin = move_toward(ball_spin, 0, 36.0 * delta)
	ball += velocity * delta
	# Laterais são fora da mesa: o último rebatedor perde o ponto.
	if ball.y < FIELD.position.y + RADIUS or ball.y > FIELD.end.y - RADIUS:
		award_point(not last_hitter_player)
		return
	var progress := (ball.x - PLAYER_X) / (CPU_X - PLAYER_X)
	if velocity.x < 0:
		progress = 1.0 - progress
	if progress >= 0.72 and not bounce_done:
		bounce_done = true
		impact.emit(ball, "bounce")
	var left_face := PLAYER_X + PADDLE_WIDTH / 2 + RADIUS
	var right_face := CPU_X - PADDLE_WIDTH / 2 - RADIUS
	if velocity.x < 0 and previous.x >= left_face and ball.x <= left_face:
		if absf(ball.y - player_y) <= player_height / 2 + RADIUS:
			ball.x = left_face
			hit_paddle(true)
	elif velocity.x > 0 and previous.x <= right_face and ball.x >= right_face:
		if absf(ball.y - cpu_y) <= float(opponent().height) / 2 + RADIUS:
			ball.x = right_face
			hit_paddle(false)
	if ball.x < FIELD.position.x - RADIUS:
		award_point(false)
	elif ball.x > FIELD.end.x + RADIUS:
		award_point(true)

func hit_paddle(is_player: bool) -> void:
	var paddle_y := player_y if is_player else cpu_y
	var half := player_height / 2 if is_player else float(opponent().height) / 2
	var offset := clampf((ball.y - paddle_y) / half, -1, 1)
	var speed := minf(velocity.length() * 1.06 + 8, max_ball_speed)
	var aim := FIELD.get_center().y + offset * 152.0
	if not is_player:
		match stage:
			0: aim = FIELD.get_center().y + rng.randf_range(-90, 90)
			1:
				speed = minf(speed * 1.07, max_ball_speed)
				aim = FIELD.get_center().y + (135.0 if player_y < FIELD.get_center().y else -135.0)
			2: aim = FIELD.get_center().y + rng.randf_range(-118, 118)
			3: aim = FIELD.get_center().y + rng.randf_range(-154, 154)
	var direction := 1.0 if is_player else -1.0
	velocity = Vector2(direction * (CPU_X - PLAYER_X), aim - ball.y).normalized() * speed
	last_hitter_player = is_player
	bounce_done = false
	ball_spin = 0.0
	fireball = false
	rally += 1
	best_rally = maxi(best_rally, rally)
	if is_player:
		charge = minf(100, charge + charge_gain)
		var spin_input := Input.get_axis("spin_up", "spin_down")
		ball_spin = (spin_input * 30.0 + player_motion * 0.025 * movement_spin) * spin_multiplier
		last_contact = clock
		contact_rewarded = false
		if clock - last_swing <= timing_window:
			perfect_hit()
		last_swing = -10
		if special_armed:
			special_armed = false
			charge = special_refund
			fireball = true
			velocity = (velocity * special_multiplier).limit_length(max_ball_speed)
			ball_spin *= special_spin
			feedback.emit("BOLA DE INCÊNDIO", "special")
			impact.emit(ball, "special")
	elif stage >= 2:
		ball_spin = rng.randf_range(-26, 26)
	impact.emit(ball, "hit")

func swing() -> void:
	if not running or paused or serving:
		return
	last_swing = clock
	if clock - last_contact <= timing_window and not contact_rewarded and velocity.x > 0:
		perfect_hit()

func perfect_hit() -> void:
	if contact_rewarded:
		return
	contact_rewarded = true
	total_perfect += 1
	charge = minf(100, charge + perfect_charge)
	velocity = (velocity * perfect_multiplier).limit_length(max_ball_speed)
	feedback.emit("TIMING PERFEITO", "perfect")
	impact.emit(ball, "perfect")

func arm_special() -> void:
	if not running or paused:
		return
	if special_armed:
		special_armed = false
		feedback.emit("ESPECIAL CANCELADO", "info")
	elif charge >= 100:
		special_armed = true
		feedback.emit("ESPECIAL ARMADO • PRÓXIMA REBATIDA", "special")
	else:
		feedback.emit("REBATIDAS CARREGAM O ESPECIAL", "info")

func award_point(player_won: bool) -> void:
	var winner := 0 if player_won else 1
	var loser := 1 - winner
	points[winner] += 1
	if player_won:
		total_points += 1
	charge = minf(100, charge + 8)
	scored.emit(player_won)
	serve_direction = -1.0 if player_won else 1.0
	var cap := points_to_win + 8
	var won_set := (points[winner] >= points_to_win and points[winner] - points[loser] >= 2) or points[winner] >= cap
	if won_set:
		sets[winner] += 1
		if sets[winner] >= 1:
			running = false
			velocity = Vector2.ZERO
			match_finished.emit(player_won)
			return
		points = [0, 0]
		feedback.emit("SET SEU!" if player_won else "SET DO ADVERSÁRIO", "point")
		reset_rally(2.0)
	else:
		feedback.emit("PONTO SEU!" if player_won else "PONTO DO ADVERSÁRIO", "point")
		reset_rally(1.15)

func upgrade_offer(index: int) -> Dictionary:
	var rank := mini(build_ranks[index], 2)
	var offer: Dictionary = BUILD_STEPS[index][rank].duplicate()
	offer["path"] = UPGRADES[index].name
	offer["rank"] = rank + 1
	return offer

func build_summary() -> String:
	var parts: Array[String] = []
	for i in range(3):
		if build_ranks[i] > 0:
			parts.append("%s %s" % [UPGRADES[i].name, ["", "I", "II", "III"][build_ranks[i]]])
	return "Sem melhorias" if parts.is_empty() else " / ".join(parts)

func apply_upgrade(index: int) -> void:
	if index < 0 or index > 2 or upgrades.size() >= 3 or build_ranks[index] >= 3:
		return
	var offer := upgrade_offer(index)
	build_ranks[index] += 1
	match index:
		0:
			match build_ranks[0]:
				1:
					player_height += 14.0
					player_speed *= 0.95
				2:
					timing_window += 0.020
					perfect_multiplier = 1.08
				3:
					perfect_multiplier = 1.25
					perfect_charge = 30.0
		1:
			match build_ranks[1]:
				1:
					spin_multiplier *= 1.45
					timing_window -= 0.010
				2:
					movement_spin = 1.8
					player_speed *= 0.95
				3:
					special_spin = 1.0
					charge_gain -= 2.0
		2:
			match build_ranks[2]:
				1:
					special_multiplier = 1.45
					charge_gain -= 2.0
				2:
					perfect_multiplier = 1.20
					timing_window -= 0.015
				3:
					special_refund = 20.0
	upgrades.append(str(offer.name))
