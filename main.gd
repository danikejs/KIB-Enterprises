extends Node2D
## Fluxo das telas, configurações e ligações entre regras, desenho e áudio.
const Rules = preload("res://scripts/match_rules.gd")
const Arena = preload("res://scripts/arena.gd")
const Sound = preload("res://scripts/sound.gd")
const MINT := Color("d6bc82")
const WHITE := Color("fff4d5")
const MUTED := Color("c9c1ac")
const DARK := Color("1d302a")
const PANEL := Color("172924")
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
var settings := {"difficulty": 0, "mouse": false, "points": 5, "volume": 0.6, "best": 0}
var score_label: Label
var rival_score_label: Label
var build_label: Label
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
	if int(config.get_value("game", "defaults_version", 0)) < 1:
		settings.difficulty = 0
		settings.points = 5
		save_settings()
	settings.difficulty = clampi(int(settings.difficulty), 0, 2)
	settings.best = clampi(int(settings.best), 0, 4)
	settings.volume = clampf(float(settings.volume), 0, 1)
	if not int(settings.points) in [5, 7, 11]:
		settings.points = 5

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("game", key, settings[key])
	config.set_value("game", "defaults_version", 1)
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
	score_label.text = "%02d" % rules.points[0]
	rival_score_label.text = "%02d" % rules.points[1]
	build_label.text = rules.build_summary()
	sets_label.text = "SET ÚNICO · ATÉ %d" % rules.points_to_win
	rally_label.text = "TROCA %02d  ·  PERFEITOS %02d" % [rules.rally, rules.total_perfect]
	charge_bar.value = rules.charge
	if rules.special_armed:
		charge_label.text = "INCÊNDIO ARMADO"
	elif rules.charge >= 100:
		charge_label.text = "INCÊNDIO PRONTO [SHIFT]"
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
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_color_override("font_outline_color", Color("18231e"))
	label.add_theme_constant_override("outline_size", 0)
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
	node.text = "  " + value.replace("   →", "")
	node.position = rect.position
	node.size = rect.size
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 22)
	node.add_theme_font_override("font", BODY_FONT)
	node.add_theme_color_override("font_color", MINT if primary else WHITE)
	node.add_theme_color_override("font_hover_color", DARK)
	node.add_theme_color_override("font_focus_color", DARK)
	node.add_theme_color_override("font_pressed_color", DARK)
	node.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var selected := StyleBoxFlat.new()
	selected.bg_color = WHITE
	selected.border_color = MINT
	selected.border_width_left = 4
	node.add_theme_stylebox_override("hover", selected)
	node.add_theme_stylebox_override("focus", selected)
	node.add_theme_stylebox_override("pressed", selected)
	node.pressed.connect(func(): sound.play("click"); callback.call())
	ui.add_child(node)
	return node

func heading(kicker: String, title: String, subtitle: String) -> void:
	text(kicker, Rect2(76, 38, 1100, 24), 15, MINT)
	text(title, Rect2(72, 76, 1120, 62), 40)
	text(subtitle, Rect2(76, 150, 1100, 56), 19, MUTED)

func menu_button(value: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var item := button(value, rect, callback, primary)
	item.text = value
	item.alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size", 22)
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color("b9573f") if primary else Color(0, 0, 0, 0)
	idle.border_color = Color("773e30") if primary else Color(0, 0, 0, 0)
	idle.border_width_bottom = 4 if primary else 0
	item.add_theme_stylebox_override("normal", idle)
	item.add_theme_color_override("font_color", WHITE)
	return item

func show_menu() -> void:
	rules.running = false
	rules.paused = false
	clear_ui("menu", "menu")
	box(Rect2(0, 0, 1280, 720), Color(0.035, 0.06, 0.045, 0.28), Color.TRANSPARENT)
	var title := text("PING NA PRAÇA", Rect2(140, 70, 1000, 108), 72, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_outline_color", Color("172924"))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_constant_override("shadow_offset_y", 5)
	text("TÊNIS DE MESA", Rect2(340, 184, 600, 30), 18, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	box(Rect2(440, 248, 400, 368), Color(0.065, 0.12, 0.095, 0.96), Color.TRANSPARENT)
	menu_button("JOGAR TORNEIO", Rect2(464, 276, 352, 52), func(): start_run(true), true).grab_focus()
	menu_button("PARTIDA RÁPIDA", Rect2(464, 344, 352, 44), func(): start_run(false))
	menu_button("COMO JOGAR", Rect2(464, 402, 352, 44), show_help)
	menu_button("OPÇÕES", Rect2(464, 460, 352, 44), show_options)
	menu_button("CRÉDITOS", Rect2(464, 544, 168, 40), show_credits)
	menu_button("SAIR", Rect2(648, 544, 168, 40), func(): get_tree().quit())
	var record := text("MELHOR TORNEIO  %d / 4" % int(settings.best), Rect2(390, 650, 500, 28), 17, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	record.add_theme_color_override("font_outline_color", DARK)
	record.add_theme_constant_override("outline_size", 4)

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
	heading("", "Torneio da praça", "Vença um set para avançar. Uma derrota encerra o torneio.")
	for i in range(4):
		var data: Dictionary = Rules.OPPONENTS[i]
		var y := 246 + i * 78
		var active := i == stage_index
		text("%02d" % (i + 1), Rect2(82, y, 72, 54), 32, MINT if active else MUTED)
		text(str(data.name), Rect2(174, y, 340, 36), 27, MINT if active else WHITE)
		text(str(data.style), Rect2(176, y + 38, 340, 26), 16, MUTED)
		text("VENCEU" if i < stage_index else ("PRÓXIMO" if active else ""), Rect2(546, y + 10, 170, 32), 18, MINT)
	text(str(Rules.OPPONENTS[stage_index].name), Rect2(816, 260, 380, 60), 38, MINT)
	text(str(Rules.OPPONENTS[stage_index].description), Rect2(820, 336, 360, 100), 24)
	button("Jogar", Rect2(816, 470, 330, 52), start_stage, true).grab_focus()
	text("Build: " + rules.build_summary(), Rect2(82, 588, 1100, 42), 18, MUTED)
	button("Voltar", Rect2(82, 648, 220, 42), show_menu)

func start_stage() -> void:
	rules.begin_match(stage_index)
	arena.trails.clear()
	arena.sparks.clear()
	show_hud()

func show_hud() -> void:
	clear_ui("game", "game")
	box(Rect2(412, 14, 456, 80), PANEL, Color.TRANSPARENT)
	box(Rect2(548, 23, 72, 48), WHITE, Color.TRANSPARENT)
	box(Rect2(660, 23, 72, 48), WHITE, Color.TRANSPARENT)
	text("HUGO", Rect2(426, 30, 112, 30), 18, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	text(str(rules.opponent().name), Rect2(740, 30, 118, 30), 18, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	score_label = text("00", Rect2(548, 24, 72, 44), 36, DARK, HORIZONTAL_ALIGNMENT_CENTER)
	rival_score_label = text("00", Rect2(660, 24, 72, 44), 36, DARK, HORIZONTAL_ALIGNMENT_CENTER)
	text(":", Rect2(624, 26, 32, 40), 28, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sets_label = text("", Rect2(520, 73, 240, 18), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box(Rect2(24, 22, 202, 36), PANEL, Color.TRANSPARENT)
	text("TORNEIO  %d / 4" % (stage_index + 1) if tournament else "PARTIDA RÁPIDA", Rect2(38, 27, 180, 26), 17)
	box(Rect2(1128, 22, 128, 36), PANEL, Color.TRANSPARENT)
	button("Pausa", Rect2(1132, 22, 120, 36), show_pause)
	serve_label = text("", Rect2(496, 324, 288, 108), 34, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	serve_label.add_theme_color_override("font_outline_color", DARK)
	serve_label.add_theme_constant_override("outline_size", 6)
	notice_label = text("", Rect2(360, 650, 560, 34), 23, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	notice_label.add_theme_color_override("font_outline_color", DARK)
	notice_label.add_theme_constant_override("outline_size", 5)
	box(Rect2(24, 614, 292, 70), PANEL, Color.TRANSPARENT)
	charge_label = text("", Rect2(40, 622, 264, 24), 16)
	charge_bar = ProgressBar.new()
	charge_bar.show_percentage = false
	charge_bar.add_theme_stylebox_override("background", style(Color("3c4c41"), Color.TRANSPARENT))
	charge_bar.add_theme_stylebox_override("fill", style(MINT, Color.TRANSPARENT))
	ui.add_child(charge_bar)
	charge_bar.position = Vector2(40, 660)
	charge_bar.size = Vector2(258, 7)
	box(Rect2(942, 614, 314, 70), PANEL, Color.TRANSPARENT)
	build_label = text(rules.build_summary(), Rect2(956, 624, 286, 24), 16, MINT)
	rally_label = text("", Rect2(956, 657, 286, 20), 14, MUTED)

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
	box(Rect2(0, 0, 1280, 720), Color(0.06, 0.09, 0.07, 0.78), Color.TRANSPARENT)
	text("PAUSA", Rect2(420, 156, 440, 90), 56, WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	text(rules.build_summary(), Rect2(350, 264, 580, 36), 22, MINT, HORIZONTAL_ALIGNMENT_CENTER)
	button("Continuar", Rect2(464, 328, 354, 52), resume_game, true).grab_focus()
	button("Reiniciar partida", Rect2(464, 396, 354, 52), start_stage)
	button("Voltar ao menu", Rect2(464, 464, 354, 52), show_menu)

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
	heading("ENTRE PARTIDAS", "Monte seu estilo", "Escolha um caminho. Repetir evolui a build; misturar combina os efeitos.")
	for i in range(3):
		var data: Dictionary = rules.upgrade_offer(i)
		var y := 226 + i * 118
		text("%s · NÍVEL %d" % [str(data.path).to_upper(), int(data.rank)], Rect2(84, y, 330, 22), 15, MINT)
		var choose := button(str(data.name), Rect2(80, y + 30, 350, 48), func(): choose_upgrade(i), true)
		text(str(data.gain), Rect2(474, y + 2, 708, 38), 22)
		text(str(data.cost), Rect2(474, y + 44, 708, 44), 18, MUTED)
		if i == 0:
			choose.grab_focus()
	text("BUILD ATUAL   " + rules.build_summary(), Rect2(84, 610, 1100, 30), 18, MINT)
	text("Até 3 escolhas por torneio. As melhorias terminam junto com a tentativa.", Rect2(84, 656, 1100, 26), 16, MUTED)

func choose_upgrade(index: int) -> void:
	rules.apply_upgrade(index)
	stage_index += 1
	show_map()

func show_result(won: bool) -> void:
	clear_ui("result")
	var title := "Torneio vencido!" if won and tournament else ("Vitória!" if won else "Fim de jogo")
	heading("", title, "")
	var values := [str(rules.total_points), str(rules.total_perfect), str(rules.best_rally)]
	var names := ["Pontos marcados", "Rebatidas perfeitas", "Maior troca"]
	for i in range(3):
		var y := 250 + i * 76
		text(names[i], Rect2(82, y, 660, 48), 28)
		text(values[i], Rect2(790, y, 220, 48), 38, MINT, HORIZONTAL_ALIGNMENT_RIGHT)
	button("Jogar novamente", Rect2(82, 534, 400, 54), func(): start_run(tournament), true).grab_focus()
	button("Menu inicial", Rect2(82, 602, 400, 54), show_menu)

func show_help() -> void:
	clear_ui("help")
	heading("CONTROLES", "Como jogar", "Você joga na parte inferior da tela. Mova-se para os lados para alcançar a bola.")
	var entries := [
		["01  MOVIMENTO", "A / D ou setas esquerda/direita para mover. Para usar o mouse, selecione-o em Opções."],
		["02  TIMING", "A bola rebate no contato. Aperte Espaço até 100 ms antes ou depois para acelerar e ganhar carga."],
		["03  EFEITO", "Segure Q ou E ao rebater para curvar a bola para a esquerda ou direita. O movimento também dá efeito."],
		["04  BOLA ESPECIAL", "Rebatidas carregam a barra. Com 100%, aperte Shift: o próximo contato lança a Bola de Incêndio. Shift novamente cancela."],
		["05  REGRAS", "Vença 1 set, com vantagem de 2 e limite de meta + 8. Bola para fora da lateral: ponto do rival do último rebatedor."],
		["06  TORNEIO", "Vença quatro rivais. Entre vitórias, evolua Defesa, Efeito ou Ataque. Cada escolha tem um custo. A build dura um torneio."]
	]
	for i in range(6):
		var x := 72 + (i % 2) * 578
		var y := 252 + (i / 2 as int) * 116
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
	heading("PROJETO", "Ping na Praça", "Um jogo de tênis de mesa com Hugo e os rivais da praça.")
	text("DESENVOLVIDO POR", Rect2(98, 288, 1000, 30), 15, MINT)
	text("KIB Enterprises", Rect2(98, 327, 1040, 46), 32)
	text("ARTE E ÁUDIO DO PROTÓTIPO", Rect2(98, 393, 1000, 30), 15, MINT)
	text("Cenário e sprites originais gerados com IA; mesa desenhada no motor. Trilha sintetizada original.\nImplementação assistida por IA. Motor: Godot 4.4.1, sob licença MIT.", Rect2(98, 438, 1020, 65), 18, MUTED)
	button("VOLTAR", Rect2(72, 602, 190, 52), show_menu).grab_focus()
