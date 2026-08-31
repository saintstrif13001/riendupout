extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")

var sel_race := "humain"
var sel_class := "guerrier"
var sel_hair_color := "#3f2a1a"
const HAIR_COLORS := [
	{"name": "Brun", "hex": "#3f2a1a"},
	{"name": "Noir", "hex": "#1a1a1a"},
	{"name": "Blond", "hex": "#c9a227"},
	{"name": "Roux", "hex": "#a34a1f"},
	{"name": "Blanc", "hex": "#d8d8d8"},
	{"name": "Bleu", "hex": "#3a6ea5"},
	{"name": "Vert", "hex": "#4a8a4a"},
	{"name": "Rose", "hex": "#c96aa8"},
]
var name_edit: LineEdit
var content: VBoxContainer
var status_label: Label
var ip_edit: LineEdit

func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.065, 0.045)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vign = ColorRect.new()
	vign.color = Color(0,0,0,0.25)
	vign.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vign)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	center.add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 640)
	panel.add_child(scroll)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.custom_minimum_size = Vector2(540, 0)
	scroll.add_child(content)

	show_main()

func _clear() -> void:
	for c in content.get_children(): c.queue_free()

func _title(text: String, size := 26) -> void:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", UiTheme.title_font())
	if size >= 24:
		l.add_theme_color_override("font_color", UiTheme.gold())
	content.add_child(l)

func _sub(text: String) -> void:
	var l = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.6,0.6,0.66))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(l)

func _button(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	content.add_child(b)
	return b

# ---------------- Écrans ----------------
func show_main() -> void:
	_clear()
	_title("Rien du Pout Online")
	_sub("Une aventure coopérative jusqu'à 4 joueurs. Val-Repos t'attend...")
	# Il n'existait qu'UN seul fichier de sauvegarde : creer un nouveau
	# personnage ecrasait definitivement le precedent, sans avertissement.
	# Les emplacements sont maintenant listes directement ici — un plein se
	# reprend, un vide cree un personnage a cet emplacement.
	_title("Emplacements de sauvegarde", 18)
	for slot in range(1, GameState.SAVE_SLOTS + 1):
		var s = GameState.slot_summary(slot)
		if s.is_empty():
			_button("Emplacement %d — Vide (nouveau personnage)" % slot, func(): _pick_slot_new(slot))
		else:
			var where = " · %s" % s.zone if s.zone != "" else ""
			_button("▶ Emplacement %d — %s, %s Nv.%d%s" % [slot, s.name, s.class_name, s.level, where],
				func(): _pick_slot_continue(slot))
	if GameState.any_save_exists():
		_button("Supprimer une sauvegarde", show_delete_slots)
	_button("Options", show_options)

func _pick_slot_new(slot: int) -> void:
	GameState.current_slot = slot
	show_new_mode_select()

func _pick_slot_continue(slot: int) -> void:
	GameState.current_slot = slot
	GameState.char_data = GameState.load_saved_character(slot)
	show_continue_mode_select()

func show_new_mode_select() -> void:
	_clear()
	_button("< Retour", show_main)
	_title("Nouveau personnage")
	_sub("Emplacement %d — Comment veux-tu jouer ?" % GameState.current_slot)
	_button("Solo", func(): GameState.mode = "solo"; show_char_create())
	_button("Héberger (coop)", func(): GameState.mode = "host"; show_char_create())
	_button("Rejoindre", func(): GameState.mode = "join"; show_join_ip())

func show_delete_slots() -> void:
	_clear()
	_button("< Retour", show_main)
	_title("Supprimer une sauvegarde", 22)
	_sub("Attention : cette action est définitive.")
	for slot in range(1, GameState.SAVE_SLOTS + 1):
		var s = GameState.slot_summary(slot)
		if s.is_empty(): continue
		_button("Supprimer l'emplacement %d — %s Nv.%d" % [slot, s.name, s.level], func():
			GameState.delete_save(slot)
			# Plus rien a supprimer : inutile de rester sur un ecran vide.
			if GameState.any_save_exists(): show_delete_slots()
			else: show_main())

func show_options() -> void:
	_clear()
	_button("< Retour", show_main)
	_title("Options", 22)
	_sub("Volume général")
	_volume_row(Audio.master_volume, Audio.set_master_volume)
	_sub("Volume musique")
	_volume_row(Audio.music_volume, Audio.set_music_volume)

func _volume_row(current: float, setter: Callable) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = current
	slider.custom_minimum_size = Vector2(380, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var pct_lbl = Label.new()
	pct_lbl.text = "%d%%" % round(current * 100)
	pct_lbl.custom_minimum_size = Vector2(50, 0)
	row.add_child(pct_lbl)
	slider.value_changed.connect(func(v):
		setter.call(v)
		pct_lbl.text = "%d%%" % round(v * 100))

func show_continue_mode_select() -> void:
	_clear()
	_button("< Retour", show_main)
	_title("Continuer l'aventure")
	_sub("%s — Comment veux-tu jouer ?" % GameState.char_data.name)
	_button("Solo", func(): GameState.mode = "solo"; launch_world())
	_button("Héberger (coop)", func(): GameState.mode = "host"; do_host())
	_button("Rejoindre", func(): GameState.mode = "join"; show_join_ip_continue())

func show_join_ip_continue() -> void:
	_clear()
	_button("< Retour", show_continue_mode_select)
	_title("Rejoindre une partie")
	_sub("Demande l'adresse IP locale de l'hôte.")
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "192.168.1.23"
	ip_edit.custom_minimum_size = Vector2(0, 36)
	content.add_child(ip_edit)
	status_label = Label.new()
	content.add_child(status_label)
	_button("Continuer", func():
		var ip = ip_edit.text.strip_edges()
		if ip == "":
			status_label.text = "Adresse IP invalide."
			return
		GameState.join_ip = ip
		GameState.mode = "join"
		do_join())

func show_join_ip() -> void:
	_clear()
	_button("< Retour", show_main)
	_title("Rejoindre une partie")
	_sub("Demande l'adresse IP locale de l'hôte (ex: 192.168.1.23). Vous devez être sur le même réseau.")
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "192.168.1.23"
	ip_edit.custom_minimum_size = Vector2(0, 36)
	content.add_child(ip_edit)
	status_label = Label.new()
	content.add_child(status_label)
	_button("Continuer", func():
		var ip = ip_edit.text.strip_edges()
		if ip == "":
			status_label.text = "Adresse IP invalide."
			return
		GameState.join_ip = ip
		show_char_create())

func show_char_create() -> void:
	_clear()
	_button("< Retour", show_main)
	_title("Création du personnage")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Nom de ton personnage"
	name_edit.custom_minimum_size = Vector2(0, 36)
	content.add_child(name_edit)

	_title("Race", 17)
	var race_grid = GridContainer.new()
	race_grid.columns = 2
	content.add_child(race_grid)
	for rid in Data.RACES.keys():
		var r = Data.RACES[rid]
		var row = HBoxContainer.new()
		row.add_child(_make_portrait(r.tint))
		var b = Button.new()
		b.text = r.name + "\n" + r.desc
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.custom_minimum_size = Vector2(210, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = (rid == sel_race)
		b.pressed.connect(func():
			sel_race = rid
			for c in race_grid.get_children(): c.get_node("Button").button_pressed = false
			b.button_pressed = true)
		b.name = "Button"
		row.add_child(b)
		race_grid.add_child(row)

	_title("Classe", 17)
	var class_grid = GridContainer.new()
	class_grid.columns = 2
	content.add_child(class_grid)
	for cid in Data.CLASSES.keys():
		var c = Data.CLASSES[cid]
		var row2 = HBoxContainer.new()
		row2.add_child(_make_portrait(c.color))
		var b = Button.new()
		b.text = c.name + "\n" + c.desc
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.custom_minimum_size = Vector2(210, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = (cid == sel_class)
		b.pressed.connect(func():
			sel_class = cid
			for cc in class_grid.get_children(): cc.get_node("Button").button_pressed = false
			b.button_pressed = true)
		b.name = "Button"
		row2.add_child(b)
		class_grid.add_child(row2)

	_title("Couleur de cheveux", 17)
	var hair_row = HBoxContainer.new()
	hair_row.add_theme_constant_override("separation", 8)
	content.add_child(hair_row)
	for hc in HAIR_COLORS:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(38, 38)
		btn.toggle_mode = true
		btn.button_pressed = (hc.hex == sel_hair_color)
		btn.tooltip_text = hc.name
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(hc.hex)
		sb.set_corner_radius_all(6)
		sb.border_color = Color(1, 1, 1, 0.5)
		sb.set_border_width_all(2)
		var sb_pressed = sb.duplicate()
		sb_pressed.border_color = Color(1, 0.9, 0.3, 1)
		sb_pressed.set_border_width_all(3)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb_pressed)
		btn.add_theme_stylebox_override("hover_pressed", sb_pressed)
		btn.pressed.connect(func():
			sel_hair_color = hc.hex
			for cc in hair_row.get_children(): cc.button_pressed = false
			btn.button_pressed = true)
		hair_row.add_child(btn)

	_button("Confirmer", _on_char_confirmed)

var _portrait_body_tex: Texture2D = null
var _portrait_head_tex: Texture2D = null

# Portrait composite (jambes+corps+tête, teinté) pour chaque race/classe au lieu
# d'une liste de boutons purement textuels — donne un vrai visage à chaque choix.
func _make_portrait(tint: Color) -> Control:
	if _portrait_body_tex == null:
		_portrait_body_tex = load("res://assets/sprites/player/body_walk.png")
		_portrait_head_tex = load("res://assets/sprites/player/head_walk.png")
	var frame = Rect2(2 * 64, 2 * 64, 64, 64) # pose idle, face caméra
	var wrap = Control.new()
	wrap.custom_minimum_size = Vector2(48, 48)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.25)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(bg)
	var body = TextureRect.new()
	var body_atlas = AtlasTexture.new()
	body_atlas.atlas = _portrait_body_tex
	body_atlas.region = frame
	body.texture = body_atlas
	body.modulate = tint
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	wrap.add_child(body)
	var head = TextureRect.new()
	var head_atlas = AtlasTexture.new()
	head_atlas.atlas = _portrait_head_tex
	head_atlas.region = frame
	head.texture = head_atlas
	head.modulate = tint
	head.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	wrap.add_child(head)
	return wrap

func _on_char_confirmed() -> void:
	var cname = name_edit.text.strip_edges()
	if cname == "": cname = "Aventurier"
	GameState.char_data = GameState.new_character(cname, sel_race, sel_class, sel_hair_color)
	match GameState.mode:
		"solo": launch_world()
		"host": do_host()
		"join": do_join()

func do_host() -> void:
	_clear()
	_title("Ouverture du salon...")
	var ip = Net.host_game()
	if ip == "":
		_sub("Erreur : impossible d'ouvrir le port réseau.")
		return
	GameState.roster = {}
	Net.player_joined.connect(_on_lobby_player_joined)
	Net.player_left.connect(_on_lobby_player_left)
	render_host_lobby(ip)

func render_host_lobby(ip: String) -> void:
	_clear()
	_title("Salon hébergé")
	_sub("Donne cette adresse IP à tes coéquipiers (max 3), sur le même réseau local :")
	var ip_label = Label.new()
	ip_label.text = ip
	ip_label.add_theme_font_size_override("font_size", 28)
	ip_label.add_theme_color_override("font_color", Color(1,0.88,0.4))
	content.add_child(ip_label)
	_title("Joueurs connectés (%d/3)" % GameState.roster.size(), 15)
	for pid in GameState.roster.keys():
		var cd = GameState.roster[pid]
		var l = Label.new()
		l.text = "%s — %s / %s" % [cd.name, Data.RACES[cd.race].name, Data.CLASSES[cd["class"]].name]
		content.add_child(l)
	_button("Lancer la partie", func():
		rpc("lobby_start")
		launch_world())

func _on_lobby_player_joined(pid: int) -> void:
	pass # on attend le message lobby_hello du client pour connaître son perso

func _on_lobby_player_left(pid: int) -> void:
	GameState.roster.erase(pid)
	if GameState.mode == "host": render_host_lobby(Net.get_local_ip())

func do_join() -> void:
	_clear()
	_title("Connexion...")
	_sub("Connexion à " + GameState.join_ip + "...")
	Net.connected_ok.connect(_on_join_connected, CONNECT_ONE_SHOT)
	Net.connect_failed.connect(_on_join_failed, CONNECT_ONE_SHOT)
	Net.join_game(GameState.join_ip)

func _on_join_connected() -> void:
	rpc_id(1, "lobby_hello", GameState.char_data)
	render_join_lobby()

func _on_join_failed() -> void:
	_clear()
	_title("Échec de connexion")
	_sub("Impossible de rejoindre " + GameState.join_ip + ". Vérifie l'adresse IP et le réseau.")
	_button("< Retour", show_main)

func render_join_lobby() -> void:
	_clear()
	_title("Dans le salon")
	_sub("En attente que l'hôte lance la partie...")
	for pid in GameState.roster.keys():
		var cd = GameState.roster[pid]
		var l = Label.new()
		l.text = "%s — %s / %s" % [cd.name, Data.RACES[cd.race].name, Data.CLASSES[cd["class"]].name]
		content.add_child(l)

@rpc("any_peer", "reliable")
func lobby_hello(cd: Dictionary) -> void:
	if not multiplayer.is_server(): return
	var sender = multiplayer.get_remote_sender_id()
	GameState.roster[sender] = cd
	rpc("lobby_roster", GameState.roster)
	render_host_lobby(Net.get_local_ip())

@rpc("authority", "reliable")
func lobby_roster(roster: Dictionary) -> void:
	GameState.roster = roster
	if GameState.mode == "join": render_join_lobby()

@rpc("authority", "reliable")
func lobby_start() -> void:
	launch_world()

func launch_world() -> void:
	get_tree().change_scene_to_file("res://scenes/World.tscn")
