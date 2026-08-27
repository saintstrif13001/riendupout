extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")

var sel_race := "humain"
var sel_class := "guerrier"
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
	if GameState.has_save():
		var saved = GameState.load_saved_character()
		if not saved.is_empty():
			var race_name = Data.RACES.get(saved.race, {}).get("name", saved.race)
			var class_name_ = Data.CLASSES.get(saved.get("class"), {}).get("name", saved.get("class"))
			_button("▶ Continuer : %s — %s Nv.%d" % [saved.name, class_name_, saved.level], func():
				GameState.char_data = saved
				show_continue_mode_select())
	_button("Nouveau personnage (Solo)", func(): GameState.mode = "solo"; show_char_create())
	_button("Nouveau personnage (Héberger)", func(): GameState.mode = "host"; show_char_create())
	_button("Nouveau personnage (Rejoindre)", func(): GameState.mode = "join"; show_join_ip())
	if GameState.has_save():
		_button("Supprimer la sauvegarde", func(): GameState.delete_save(); show_main())

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
		var b = Button.new()
		b.text = r.name + "\n" + r.desc
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.custom_minimum_size = Vector2(250, 64)
		b.toggle_mode = true
		b.button_pressed = (rid == sel_race)
		b.pressed.connect(func():
			sel_race = rid
			for c in race_grid.get_children(): c.button_pressed = false
			b.button_pressed = true)
		race_grid.add_child(b)

	_title("Classe", 17)
	var class_grid = GridContainer.new()
	class_grid.columns = 2
	content.add_child(class_grid)
	for cid in Data.CLASSES.keys():
		var c = Data.CLASSES[cid]
		var b = Button.new()
		b.text = c.name + "\n" + c.desc
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.custom_minimum_size = Vector2(250, 64)
		b.toggle_mode = true
		b.button_pressed = (cid == sel_class)
		b.pressed.connect(func():
			sel_class = cid
			for cc in class_grid.get_children(): cc.button_pressed = false
			b.button_pressed = true)
		class_grid.add_child(b)

	_button("Confirmer", _on_char_confirmed)

func _on_char_confirmed() -> void:
	var cname = name_edit.text.strip_edges()
	if cname == "": cname = "Aventurier"
	GameState.char_data = GameState.new_character(cname, sel_race, sel_class)
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
