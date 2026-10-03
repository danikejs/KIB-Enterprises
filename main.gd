extends Node2D
## Fluxo das telas, configurações e ligações entre regras, desenho e áudio.
const Rules = preload("res://scripts/match_rules.gd")
const Arena = preload("res://scripts/arena.gd")
const Sound = preload("res://scripts/sound.gd")
const MINT := Color("c8cfaa")
const WHITE := Color("f5e9ce")
const MUTED := Color("c9c1ac")
const DARK := Color("1d302a")
const PANEL := Color(0.09, 0.14, 0.13, 0.90)
const ORANGE := Color("eebc82")

const BODY_FONT = preload("res://assets/fonts/pixel.ttf")
const TITLE_FONT = preload("res://assets/fonts/pixel.ttf")
const SCORE_FONT = preload("res://assets/fonts/pixel.ttf")

var rules: Node
var arena: Node2D
var sound: Node
var ui: Control
var screen: String = "menu"
var tournament: bool = true
var stage_index: int = 0
var settings := {"difficulty": 1, "mouse": false, "points": 7, "volume": 0.6, "best": 0}
var score_label: Label
var sets_label: Label
var rally_label: Label
var charge_label: Label
var notice_label: Label
var serve_label: Label
var charge_bar: ProgressBar
var notice_time: float = 0

func _ready() -> void:
	setup_inputs()
	load_settings()
	rules = $RegrasDaPartida
	arena = $Arena2D
	arena.rules = rules
	sound = $Audio
	sound.set_volume(float(settings.volume))
	ui = $Interface/Telas
	rules.impact.connect(arena.on_impact)
	rules.impact.connect(func(_position: Vector2, kind: String): sound.play("wall" if kind == "bounce" else kind))
	rules.feedback.connect(show_notice)
	rules.scored.connect(func(_won: bool): sound.play("point"))
	rules.match_finished.connect(finish_match)
	show_menu()

func setup_inputs() -> void:
	var bindings := {"move_up": [KEY_A, KEY_LEFT], "move_down": [KEY_D, KEY_RIGHT], "swing": [KEY_SPACE], "special": [KEY_SHIFT], "spin_up": [KEY_Q], "spin_down": [KEY_E], "pause": [KEY_ESCAPE]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		for key in settings:
			settings[key] = config.get_value("game", key, settings[key])
	settings.difficulty = clampi(int(settings.difficulty), 0, 2)
	settings.best = clampi(int(settings.best), 0, 4)
	settings.volume = clampf(float(settings.volume), 0, 1)
	if not int(settings.points) in [5, 7, 11]:
		settings.points = 7

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("game", key, settings[key])
	config.save("user://settings.cfg")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if screen == "game":
			show_pause()
		elif screen == "pause":
			resume_game()
		elif screen in ["help", "options", "credits", "map", "result"]:
			show_menu()
		get_viewport().set_input_as_handled()
	elif screen == "game":
		if event.is_action_pressed("swing"):
			rules.swing()
		elif event.is_action_pressed("special"):
			rules.arm_special()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "game" and is_instance_valid(rules):
		show_pause()

func _process(delta: float) -> void:
	if screen != "game" or not is_instance_valid(score_label):
		return
	score_label.text = "%02d  :  %02d" % [rules.points[0], rules.points[1]]
	sets_label.text = "SETS  %d — %d   /   MELHOR DE 3" % [rules.sets[0], rules.sets[1]]
	rally_label.text = "TROCA  %02d       PERFEITOS  %02d" % [rules.rally, rules.total_perfect]
	charge_bar.value = rules.charge
	if rules.special_armed:
		charge_label.text = "INCÊNDIO ARMADO • PRÓXIMO GOLPE"
	elif rules.charge >= 100:
		charge_label.text = "INCÊNDIO PRONTO  [SHIFT]"
	else:
		charge_label.text = "BOLA DE INCÊNDIO   %d%%" % int(rules.charge)
	charge_label.modulate = ORANGE if rules.special_armed else WHITE
	serve_label.text = "PREPARE-SE\n%d" % maxi(1, int(ceil(rules.serve_left))) if rules.serving else ""
	notice_time = maxf(0, notice_time - delta)
	if notice_time <= 0:
		notice_label.text = ""

func clear_ui(next_screen: String, backdrop: String = "backdrop") -> void:
	screen = next_screen
	arena.display_mode = backdrop
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()

func box(rect: Rect2, color: Color = PANEL, border: Color = Color("53614f")) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style(color, border))
	ui.add_child(panel)
	return panel

func style(color: Color, border: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(0)
	result.border_width_bottom = 1
	return result

func text(value: String, rect: Rect2, size: int = 20, color: Color = WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", maxi(14, size))
	label.add_theme_font_override("font", TITLE_FONT if size >= 34 else BODY_FONT)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.05, 0.035, 0.55))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value
	ui.add_child(label)
	label.size = rect.size
	return label

func button(value: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 16)
	node.add_theme_font_override("font", BODY_FONT)
	node.add_theme_color_override("font_color", DARK if primary else WHITE)
	node.add_theme_color_override("font_focus_color", DARK if primary else WHITE)
	node.add_theme_color_override("font_hover_color", DARK if primary else MINT)
	node.add_theme_color_override("font_pressed_color", DARK if primary else MINT)
	node.add_theme_stylebox_override("normal", style(MINT if primary else PANEL, MINT if primary else Color("617366")))
	node.add_theme_stylebox_override("hover", style(MINT.lightened(0.2) if primary else Color("394d40"), MINT))
	node.add_theme_stylebox_override("pressed", style(MINT.darkened(0.12) if primary else Color("49624c"), MINT))
	var focus := style(Color(0, 0, 0, 0), WHITE)
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus", focus)
	node.pressed.connect(func(): sound.play("click"); callback.call())
	ui.add_child(node)
	return node

func heading(kicker: String, title: String, subtitle: String) -> void:
	text(kicker, Rect2(72, 46, 1040, 24), 14, MINT)
	text(title, Rect2(72, 100, 1110, 74), 36)
	text(subtitle, Rect2(72, 180, 1100, 44), 19, MUTED)

func show_menu() -> void:
	rules.running = false
	rules.paused = false
	clear_ui("menu", "menu")
	box(Rect2(78, 112, 330, 495), Color(0.055, 0.10, 0.075, 0.90), Color("68755e"))
	text("PING PONG", Rect2(104, 138, 286, 60), 46, WHITE)
	text("Praça do Entardecer", Rect2(105, 201, 282, 28), 18, MUTED)
	button("JOGAR TORNEIO   →", Rect2(104, 266, 278, 42), func(): start_run(true), true).grab_focus()
	button("PARTIDA RÁPIDA", Rect2(104, 319, 278, 38), func(): start_run(false))
	button("COMO JOGAR", Rect2(104, 369, 278, 38), show_help)
	button("OPÇÕES", Rect2(104, 419, 278, 38), show_options)
	button("CRÉDITOS", Rect2(104, 469, 278, 38), show_credits)
	button("SAIR", Rect2(104, 519, 278, 38), func(): get_tree().quit())
	text("Melhor campanha: %d / 4" % int(settings.best), Rect2(104, 568, 278, 22), 16, MUTED)

func start_run(is_tournament: bool) -> void:
	tournament = is_tournament
	stage_index = 0
	rules.new_run()
	rules.points_to_win = int(settings.points)
	rules.difficulty = int(settings.difficulty)
	rules.mouse_mode = bool(settings.mouse)
	if tournament:
		show_map()
	else:
		start_stage()

func show_map() -> void:
	clear_ui("map")
	heading("TABELA DE JOGOS", "Quem está na mesa?", "Ganhe dois sets para avançar. Entre partidas, escolha uma melhoria.")
	for i in range(4):
		var data: Dictionary = Rules.OPPONENTS[i]
		var y := 252 + i * 82
		var active := i == stage_index
		box(Rect2(72, y, 734, 72), Color("3a4d40") if active else PANEL, MINT if active else Color("536451"))
		text("%02d" % (i + 1), Rect2(91, y + 10, 70, 48), 30, MINT if active else MUTED)
		text(str(data.name), Rect2(173, y + 7, 274, 29), 21)
		text(str(data.style), Rect2(173, y + 39, 274, 20), 12, MUTED)
		var status := "VENCEU" if i < stage_index else ("SUA VEZ" if active else "NA FILA")
		text(status, Rect2(537, y + 20, 239, 30), 14, MINT if active else MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	text("PRÓXIMO JOGO", Rect2(856, 266, 336, 25), 12, MINT)
	text(str(Rules.OPPONENTS[stage_index].name), Rect2(851, 313, 340, 57), 34)
	text(str(Rules.OPPONENTS[stage_index].description), Rect2(856, 386, 330, 80), 21, WHITE)
	button("ENTRAR NA ARENA   →", Rect2(851, 510, 340, 57), start_stage, true).grab_focus()
	text("Melhorias: " + (", ".join(rules.upgrades) if not rules.upgrades.is_empty() else "nenhuma ainda"), Rect2(72, 598, 1112, 42), 14, MUTED)
	button("MENU", Rect2(72, 652, 128, 36), show_menu)

func start_stage() -> void:
	rules.begin_match(stage_index)
	arena.trails.clear()
	arena.sparks.clear()
	show_hud()

func show_hud() -> void:
	clear_ui("game", "game")
	box(Rect2(350, 22, 580, 77), Color(0.055, 0.10, 0.075, 0.90))
	text("", Rect2(54, 32, 300, 28), 16, MINT)
	var mode := "CIRCUITO  %02d / 04" % (stage_index + 1) if tournament else "PARTIDA RÁPIDA"
	text(mode, Rect2(54, 32, 280, 24), 16, WHITE)
	text("HUGO", Rect2(366, 42, 128, 30), 16, MINT, HORIZONTAL_ALIGNMENT_RIGHT)
	score_label = text("00  :  00", Rect2(500, 29, 280, 48), 35, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	score_label.add_theme_font_override("font", SCORE_FONT)
	text(str(rules.opponent().name), Rect2(786, 42, 136, 30), 16, WHITE)
	sets_label = text("", Rect2(470, 76, 340, 18), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	button("PAUSA [ESC]", Rect2(1090, 38, 136, 40), show_pause)
	notice_label = text("", Rect2(342, 651, 596, 26), 16, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	serve_label = text("", Rect2(500, 350, 280, 80), 24, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	box(Rect2(40, 600, 304, 65), Color(0.055, 0.10, 0.075, 0.90))
	charge_label = text("", Rect2(56, 605, 275, 28), 11)
	charge_bar = ProgressBar.new()
	charge_bar.show_percentage = false
	charge_bar.add_theme_stylebox_override("background", style(Color("465443"), Color("465443")))
	charge_bar.add_theme_stylebox_override("fill", style(MINT, MINT))
	ui.add_child(charge_bar)
	charge_bar.position = Vector2(58, 645)
	charge_bar.size = Vector2(267, 6)
	box(Rect2(936, 600, 304, 65), Color(0.055, 0.10, 0.075, 0.90))
	rally_label = text("", Rect2(952, 605, 274, 28), 12)
	text("SET: %d PONTOS • VANTAGEM DE 2" % rules.points_to_win, Rect2(952, 637, 274, 18), 10, MUTED)
	box(Rect2(0, 682, 1280, 38), Color(0.055, 0.09, 0.065, 0.93), Color.TRANSPARENT)
	var move_hint := "MOUSE: MOVER" if rules.mouse_mode else "A / D ou ← / →: MOVER"
	text(move_hint + "     •     ESPAÇO: TIMING     •     Q / E: EFEITO     •     SHIFT: ESPECIAL", Rect2(40, 689, 1200, 23), 12, WHITE, HORIZONTAL_ALIGNMENT_CENTER)

func show_notice(value: String, kind: String) -> void:
	if screen == "game" and is_instance_valid(notice_label):
		notice_label.text = value
		notice_label.modulate = ORANGE if kind == "special" else MINT
		notice_time = 1.1

func show_pause() -> void:
	if screen != "game":
		return
	rules.paused = true
	clear_ui("pause", "game")
	box(Rect2(0, 0, 1280, 720), Color(0.025, 0.05, 0.075, 0.88), Color.TRANSPARENT)
	box(Rect2(407, 155, 466, 410))
	text("A MESA FICA RESERVADA", Rect2(440, 180, 400, 30), 13, MINT, HORIZONTAL_ALIGNMENT_CENTER)
	text("Pausa", Rect2(440, 225, 400, 72), 50, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	button("CONTINUAR", Rect2(455, 326, 370, 54), resume_game, true).grab_focus()
	button("REINICIAR PARTIDA", Rect2(455, 396, 370, 48), start_stage)
	button("VOLTAR AO MENU", Rect2(455, 458, 370, 48), show_menu)

func resume_game() -> void:
	rules.paused = false
	show_hud()

func finish_match(won: bool) -> void:
	if won and tournament:
		settings.best = maxi(int(settings.best), stage_index + 1)
		save_settings()
		if stage_index < 3:
			show_upgrades()
			return
	show_result(won)

func show_upgrades() -> void:
	clear_ui("upgrade")
	heading("PARTIDA VENCIDA", "Antes do próximo jogo", "Escolha uma melhoria. Ela vale até o fim deste torneio.")
	for i in range(3):
		var data: Dictionary = Rules.UPGRADES[i]
		var x := 72 + 382 * i
		box(Rect2(x, 258, 350, 290), PANEL, Color("617366"))
		box(Rect2(x + 24, 322, 302, 2), MINT, Color.TRANSPARENT)
		text(str(data.symbol) + " / " + str(data.tag), Rect2(x + 24, 280, 310, 30), 13, MINT)
		text(str(data.name), Rect2(x + 24, 338, 310, 46), 26, WHITE)
		text(str(data.description), Rect2(x + 24, 390, 304, 65), 18, MUTED)
		var choose := button("ESCOLHER   →", Rect2(x + 24, 474, 302, 48), func(): choose_upgrade(i), true)
		if i == 0:
			choose.grab_focus()
	text("Seu próximo rival está esperando. A derrota encerra o torneio.", Rect2(72, 602, 1100, 40), 16, MUTED)

func choose_upgrade(index: int) -> void:
	rules.apply_upgrade(index)
	stage_index += 1
	show_map()

func show_result(won: bool) -> void:
	clear_ui("result")
	var title := "A taça é do Hugo!" if won and tournament else ("Vitória!" if won else "Fim de jogo.")
	heading("FIM DO TORNEIO" if tournament else "FIM DE PARTIDA", title, "Confira os números da sua campanha.")
	var values := [str(rules.total_points), str(rules.total_perfect), str(rules.best_rally)]
	var names := ["Pontos marcados", "Rebatidas perfeitas", "Maior troca"]
	box(Rect2(72, 257, 1114, 210), PANEL, Color("617366"))
	text("SÚMULA DA PARTIDA", Rect2(96, 271, 1000, 24), 12, MINT)
	for i in range(3):
		var y := 305 + i * 49
		text(names[i], Rect2(97, y, 800, 38), 22, WHITE)
		var number := text(values[i], Rect2(1010, y, 148, 38), 26, WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		number.add_theme_font_override("font", SCORE_FONT)
		box(Rect2(98, y + 41, 1059, 1), Color("617366"), Color.TRANSPARENT)
	button("JOGAR NOVAMENTE", Rect2(72, 514, 312, 58), func(): start_run(tournament), true).grab_focus()
	button("MENU INICIAL", Rect2(404, 514, 270, 58), show_menu)

func show_help() -> void:
	clear_ui("help")
	heading("CONTROLES", "Como jogar", "Você joga embaixo da mesa. Mova-se para os lados e devolva a bola ao rival no topo.")
	var entries := [
		["01  MOVIMENTO", "A / D ou setas esquerda/direita para mover. Para usar o mouse, selecione-o em Opções."],
		["02  TIMING", "A bola rebate no contato. Aperte Espaço até 100 ms antes ou depois para acelerar e ganhar carga."],
		["03  EFEITO", "Segure Q ou E ao rebater para curvar a bola para a esquerda ou direita. O movimento também dá efeito."],
		["04  BOLA ESPECIAL", "Rebatidas carregam a barra. Com 100%, aperte Shift: o próximo contato lança a Bola de Incêndio. Shift novamente cancela."],
		["05  REGRAS", "Vença 2 sets, com vantagem de 2 e limite de meta + 8. Bola para fora da lateral: ponto do rival do último rebatedor."],
		["06  TORNEIO", "Vença quatro rivais. Entre vitórias, escolha uma melhoria. Perder encerra a corrida e reinicia as melhorias."]
	]
	for i in range(6):
		var x := 72 + (i % 2) * 578
		var y := 252 + (i / 2 as int) * 116
		box(Rect2(x, y + 99, 538, 1), Color("65716d"), Color.TRANSPARENT)
		text(entries[i][0], Rect2(x + 18, y + 8, 516, 28), 14, MINT)
		text(entries[i][1], Rect2(x + 18, y + 36, 516, 58), 15, MUTED)
	button("VOLTAR", Rect2(72, 636, 190, 48), show_menu).grab_focus()

func choice(items: Array, selected: int, position: Vector2, changed: Callable) -> OptionButton:
	var node := OptionButton.new()
	node.position = position
	node.size = Vector2(430, 48)
	node.add_theme_font_size_override("font_size", 19)
	node.add_theme_font_override("font", BODY_FONT)
	node.add_theme_stylebox_override("normal", style(PANEL, Color("476171")))
	node.add_theme_stylebox_override("hover", style(Color("394d40"), MINT))
	for value in items:
		node.add_item(str(value))
	node.select(selected)
	node.item_selected.connect(changed)
	ui.add_child(node)
	return node

func show_options() -> void:
	clear_ui("options")
	heading("AJUSTES", "Opções", "As configurações ficam salvas neste computador.")
	text("DIFICULDADE", Rect2(72, 254, 450, 32), 14, MINT)
	choice(["Tranquilo", "Normal", "Desafio"], int(settings.difficulty), Vector2(72, 296), func(i: int): settings.difficulty = i; save_settings())
	text("CONTROLE DA RAQUETE", Rect2(672, 254, 470, 32), 14, MINT)
	choice(["Teclado — A/D ou ←/→", "Mouse — movimento horizontal"], 1 if settings.mouse else 0, Vector2(672, 296), func(i: int): settings.mouse = i == 1; save_settings())
	text("PONTOS POR SET", Rect2(72, 380, 450, 32), 14, MINT)
	choice(["5 pontos", "7 pontos", "11 pontos"], [5, 7, 11].find(int(settings.points)), Vector2(72, 422), func(i: int): settings.points = [5, 7, 11][i]; save_settings())
	text("VOLUME GERAL", Rect2(672, 380, 470, 32), 14, MINT)
	var slider := HSlider.new()
	slider.position = Vector2(672, 429)
	slider.size = Vector2(430, 36)
	slider.max_value = 1
	slider.step = 0.01
	slider.value = float(settings.volume)
	slider.value_changed.connect(func(value: float): settings.volume = value; sound.set_volume(value); save_settings())
	ui.add_child(slider)
	text("F11 alterna entre janela e tela cheia.", Rect2(72, 520, 950, 40), 17, MUTED)
	button("VOLTAR", Rect2(72, 620, 190, 52), show_menu).grab_focus()

func show_credits() -> void:
	clear_ui("credits")
	heading("PROJETO", "Ping Pong — Torneio da Praça", "Um jogo de tênis de mesa com Hugo e os rivais da praça.")
	box(Rect2(72, 266, 1128, 262))
	text("DESIGN E EQUIPE", Rect2(98, 288, 1000, 32), 15, MINT)
	text("Nome do estúdio e integrantes: a definir pela equipe.", Rect2(98, 329, 1040, 38), 23)
	text("ARTE E ÁUDIO DO PROTÓTIPO", Rect2(98, 393, 1000, 30), 15, MINT)
	text("Cenário e sprites originais gerados com IA; mesa desenhada no motor. Trilha sintetizada original.\nImplementação assistida por IA. Motor: Godot 4.4.1, sob licença MIT.", Rect2(98, 438, 1020, 65), 18, MUTED)
	button("VOLTAR", Rect2(72, 602, 190, 52), show_menu).grab_focus()
