extends CanvasLayer

const UiTheme = preload("res://scripts/ui_theme.gd")

var world # référence à World.gd (typage lâche pour éviter les dépendances circulaires)

var hp_bar: ProgressBar
var mana_bar: ProgressBar
var xp_bar: ProgressBar
var lvl_label: Label
var zone_label: Label
var gold_label: Label
var quest_label: Label
var hint_panel: PanelContainer
var hint_label: Label
var dialogue_overlay: Control
var dialogue_box: VBoxContainer
var inventory_overlay: Control
var inventory_box: VBoxContainer
var talent_overlay: Control
var talent_box: VBoxContainer
var travel_overlay: Control
var travel_box: VBoxContainer
var options_overlay: Control
var options_slider: HSlider
var options_pct_label: Label
var options_music_slider: HSlider
var options_music_pct_label: Label
var minimap: Control
var stats_overlay: Control
var stats_box: VBoxContainer
var chat_overlay: Control
var chat_log_box: VBoxContainer
var chat_input: LineEdit
var chat_messages: Array = []
const CHAT_MAX_MESSAGES := 8
var fade_rect: ColorRect

func bind(w) -> void:
	world = w
	world.hud_update.connect(_on_hud_update)
	world.near_update.connect(_on_near_update)
	world.open_npc.connect(_on_open_npc)
	world.quest_progress.connect(_render_quests)
	world.talent_available.connect(_on_talent_available)
	_render_quests()

func _ready() -> void:
	layer = 10
	_build_bars()
	_build_minimap()
	_build_hint()
	_build_dialogue_overlay()
	_build_inventory_overlay()
	_build_talent_overlay()
	_build_travel_overlay()
	_build_options_overlay()
	_build_stats_overlay()
	_build_chat()
	_build_fade_overlay()

func _build_fade_overlay() -> void:
	# Écran noir plein cadre pour adoucir les changements de zone et la mort,
	# au lieu d'un cut instantané.
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)

func fade_out(duration: float = 0.35) -> void:
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, duration)
	await tw.finished

func fade_in(duration: float = 0.35) -> void:
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, duration)
	await tw.finished

func _build_bars() -> void:
	var root = Control.new()
	root.theme = UiTheme.build()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var topleft = VBoxContainer.new()
	topleft.position = Vector2(16, 12)
	topleft.custom_minimum_size = Vector2(220, 0)
	root.add_child(topleft)

	hp_bar = _make_stat_bar(Color(0.85,0.25,0.22), Vector2(200, 16))
	topleft.add_child(hp_bar)

	mana_bar = _make_stat_bar(Color(0.25,0.5,0.85), Vector2(200, 12))
	topleft.add_child(mana_bar)

	xp_bar = _make_stat_bar(Color(0.85,0.78,0.22), Vector2(200, 6))
	topleft.add_child(xp_bar)

	lvl_label = Label.new()
	lvl_label.add_theme_color_override("font_color", Color(1,0.88,0.4))
	topleft.add_child(lvl_label)

	zone_label = Label.new()
	zone_label.add_theme_font_size_override("font_size", 18)
	zone_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	zone_label.position = Vector2(-100, 12)
	root.add_child(zone_label)

	gold_label = Label.new()
	gold_label.add_theme_color_override("font_color", Color(1,0.88,0.4))
	gold_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gold_label.position = Vector2(-140, 12)
	root.add_child(gold_label)

	quest_label = Label.new()
	quest_label.add_theme_font_size_override("font_size", 13)
	quest_label.add_theme_color_override("font_color", Color(0.63,0.82,1))
	quest_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quest_label.position = Vector2(-260, 60)
	quest_label.custom_minimum_size = Vector2(250, 0)
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(quest_label)

	var help = Label.new()
	help.text = "ZQSD/Flèches: bouger · Espace: attaque · Q/E: compétences · F: interagir · I: inventaire · C: stats · M: voyage rapide · O: options · Entrée: discuter"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(1,1,1,0.6))
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(16, -24)
	root.add_child(help)

func _build_minimap() -> void:
	# Le monde etait navigable a l'aveugle : aucune vue d'ensemble des zones,
	# aucun moyen de voir ou se trouvent les autres joueurs du groupe.
	minimap = Control.new()
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	minimap.custom_minimum_size = Vector2(220, 22)
	minimap.position = Vector2(-236, -24)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	add_child(minimap)

func _draw_minimap() -> void:
	if world == null or world.player == null: return
	var w = minimap.size.x
	var h = minimap.size.y
	var total = Data.WORLD_WIDTH
	for zid in Data.ZONES.keys():
		var z = Data.ZONES[zid]
		var x0 = (z.x0 / total) * w
		var x1 = (z.x1 / total) * w
		var col = z.bg.lightened(0.1) if zid == world.death_zone_id else z.bg.darkened(0.25)
		minimap.draw_rect(Rect2(x0, 0, max(1.0, x1 - x0), h), col)
	minimap.draw_rect(Rect2(0, 0, w, h), Color(0.9, 0.85, 0.6, 0.6), false, 1.0)
	for pid in world.remote_players.keys():
		var rp = world.remote_players[pid]
		if rp == null or not is_instance_valid(rp): continue
		var rx = clampf(rp.global_position.x / total, 0.0, 1.0) * w
		minimap.draw_circle(Vector2(rx, h * 0.5), 3.0, Color(0.4, 0.75, 1.0))
	var px = clampf(world.player.global_position.x / total, 0.0, 1.0) * w
	minimap.draw_line(Vector2(px, 0), Vector2(px, h), Color(1, 0.92, 0.5), 2.0)
	minimap.draw_circle(Vector2(px, h * 0.5), 3.5, Color(1, 1, 0.85))

func _make_stat_bar(color: Color, size: Vector2) -> ProgressBar:
	# Barre avec coins arrondis + bordure sombre + reflet brillant en haut,
	# au lieu d'un simple ColorRect plat.
	var bar = ProgressBar.new()
	bar.max_value = 100; bar.value = 100
	bar.custom_minimum_size = size
	bar.show_percentage = false
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	fill.border_color = color.darkened(0.4)
	fill.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	var shine = ColorRect.new()
	shine.color = Color(1, 1, 1, 0.22)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.position = Vector2(2, 1)
	shine.size = Vector2(size.x - 4, max(2.0, size.y * 0.35))
	bar.add_child(shine)
	return bar

func _build_hint() -> void:
	hint_panel = PanelContainer.new()
	hint_panel.theme = UiTheme.build()
	hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_panel.position = Vector2(-100, -50)
	hint_panel.visible = false
	add_child(hint_panel)
	hint_label = Label.new()
	hint_panel.add_child(hint_label)

func _build_dialogue_overlay() -> void:
	dialogue_overlay = Control.new()
	dialogue_overlay.theme = UiTheme.build()
	dialogue_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_overlay.visible = false
	var bg = ColorRect.new()
	bg.color = Color(0,0,0,0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_overlay.add_child(bg)
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 0)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 500)
	dialogue_box = VBoxContainer.new()
	dialogue_box.add_theme_constant_override("separation", 8)
	scroll.add_child(dialogue_box)
	panel.add_child(scroll)
	dialogue_overlay.add_child(panel)
	add_child(dialogue_overlay)

func _build_inventory_overlay() -> void:
	inventory_overlay = Control.new()
	inventory_overlay.theme = UiTheme.build()
	inventory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.visible = false
	var bg = ColorRect.new()
	bg.color = Color(0,0,0,0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.add_child(bg)
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 0)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 500)
	inventory_box = VBoxContainer.new()
	inventory_box.add_theme_constant_override("separation", 8)
	scroll.add_child(inventory_box)
	panel.add_child(scroll)
	inventory_overlay.add_child(panel)
	add_child(inventory_overlay)

func _build_talent_overlay() -> void:
	talent_overlay = Control.new()
	talent_overlay.theme = UiTheme.build()
	talent_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	talent_overlay.visible = false
	var bg = ColorRect.new()
	bg.color = Color(0,0,0,0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	talent_overlay.add_child(bg)
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(480, 0)
	talent_box = VBoxContainer.new()
	talent_box.add_theme_constant_override("separation", 10)
	panel.add_child(talent_box)
	talent_overlay.add_child(panel)
	add_child(talent_overlay)

func _on_talent_available(tier: Dictionary) -> void:
	_clear_box(talent_box)
	_add_title(talent_box, "Spécialisation — Niveau %d" % tier.level, 20)
	var sub = Label.new()
	sub.text = "Choisis une voie pour ton personnage (définitif) :"
	talent_box.add_child(sub)
	for opt in tier.options:
		var b = _add_button(talent_box, "%s\n%s" % [opt.name, opt.desc], func(): _choose_talent(tier, opt.id))
		b.custom_minimum_size = Vector2(0, 60)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
	talent_overlay.visible = true

func _choose_talent(tier: Dictionary, opt_id: String) -> void:
	var cd = world.char_data
	cd.talents[str(tier.level)] = opt_id
	world.player.stats = GameState.compute_stats(cd)
	world.player.hp = min(world.player.hp, world.player.stats.max_hp)
	world.player.mana = min(world.player.mana, world.player.stats.max_mana)
	world.emit_signal("hud_update", world.make_hud_data())
	world.save_now()
	talent_overlay.visible = false
	var next_tier = GameState.pending_talent(cd)
	if not next_tier.is_empty(): _on_talent_available(next_tier)

func _build_travel_overlay() -> void:
	travel_overlay = Control.new()
	travel_overlay.theme = UiTheme.build()
	travel_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	travel_overlay.visible = false
	var bg = ColorRect.new()
	bg.color = Color(0,0,0,0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	travel_overlay.add_child(bg)
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 0)
	travel_box = VBoxContainer.new()
	travel_box.add_theme_constant_override("separation", 8)
	panel.add_child(travel_box)
	travel_overlay.add_child(panel)
	add_child(travel_overlay)

func _build_options_overlay() -> void:
	options_overlay = Control.new()
	options_overlay.theme = UiTheme.build()
	options_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_overlay.visible = false
	var bg = ColorRect.new()
	bg.color = Color(0,0,0,0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_overlay.add_child(bg)
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 0)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title = Label.new()
	title.text = "Options"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var sub = Label.new()
	sub.text = "Volume général (touche O pour ouvrir/fermer)"
	box.add_child(sub)
	var vol_row = _build_volume_row(box, Audio.master_volume, Audio.set_master_volume, "VolumeSlider")
	options_slider = vol_row[0]
	options_pct_label = vol_row[1]

	var sub2 = Label.new()
	sub2.text = "Volume musique"
	box.add_child(sub2)
	var music_row = _build_volume_row(box, Audio.music_volume, Audio.set_music_volume, "MusicVolumeSlider")
	options_music_slider = music_row[0]
	options_music_pct_label = music_row[1]

	options_overlay.add_child(panel)
	add_child(options_overlay)

func _build_volume_row(box: VBoxContainer, current: float, setter: Callable, slider_name: String) -> Array:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = current
	slider.custom_minimum_size = Vector2(300, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.name = slider_name
	row.add_child(slider)
	var pct_lbl = Label.new()
	pct_lbl.text = "%d%%" % round(current * 100)
	pct_lbl.custom_minimum_size = Vector2(50, 0)
	row.add_child(pct_lbl)
	slider.value_changed.connect(func(v):
		setter.call(v)
		pct_lbl.text = "%d%%" % round(v * 100))
	return [slider, pct_lbl]

func sync_options() -> void:
	options_slider.value = Audio.master_volume
	options_pct_label.text = "%d%%" % round(Audio.master_volume * 100)
	options_music_slider.value = Audio.music_volume
	options_music_pct_label.text = "%d%%" % round(Audio.music_volume * 100)

func _build_stats_overlay() -> void:
	# Le joueur n'avait aucun moyen de voir ses stats numeriques (ATK/DEF/etc.) :
	# l'inventaire montrait le nom des objets equipes mais jamais leur effet chiffre.
	stats_overlay = Control.new()
	stats_overlay.theme = UiTheme.build()
	stats_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_overlay.visible = false
	var bg = ColorRect.new()
	bg.color = Color(0,0,0,0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_overlay.add_child(bg)
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 0)
	stats_box = VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 6)
	panel.add_child(stats_box)
	stats_overlay.add_child(panel)
	add_child(stats_overlay)

func render_stats() -> void:
	var cd = world.char_data
	var p = world.player
	_clear_box(stats_box)
	_add_title(stats_box, "%s - Niveau %d" % [cd.name, cd.level], 20)
	var sub = Label.new()
	sub.text = "%s %s" % [Data.RACES[cd.race].name, Data.CLASSES[cd["class"]].name]
	stats_box.add_child(sub)

	var vitals = Label.new()
	vitals.text = "PV : %d / %d      Mana : %d / %d" % [round(p.hp), p.stats.max_hp, round(p.mana), p.stats.max_mana]
	_wrap_card(stats_box, vitals)

	var combat = Label.new()
	combat.text = "Attaque : %d      Défense : %d      Vitesse : %d" % [round(p.stats.atk), round(p.stats.def), round(p.stats.spd)]
	_wrap_card(stats_box, combat)

	_add_title(stats_box, "Equipement", 15)
	var any_equipped = false
	for slot in ["weapon", "armor"]:
		var item_id = cd.equipment.get(slot, "")
		if item_id == "" or item_id == null: continue
		any_equipped = true
		_add_item_row(stats_box, item_id, Data.ITEMS[item_id].name, null)
	if not any_equipped:
		var none_lbl = Label.new()
		none_lbl.text = "Aucun objet équipé — les bonus d'attaque/défense ci-dessus sont les valeurs de base."
		none_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		stats_box.add_child(none_lbl)

	_add_button(stats_box, "Fermer (C)", func(): stats_overlay.visible = false)

func _build_chat() -> void:
	# C'est un jeu coop jusqu'à 4 joueurs et il n'existait aucun moyen de
	# communiquer en jeu (ni chat, ni pings). Journal discret en bas à gauche
	# (au-dessus de l'aide clavier) + une ligne de saisie ouverte avec Entrée.
	chat_overlay = VBoxContainer.new()
	chat_overlay.theme = UiTheme.build()
	chat_overlay.add_theme_constant_override("separation", 1)
	chat_overlay.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_overlay.grow_vertical = Control.GROW_DIRECTION_BEGIN # s'étend vers le haut quand des messages s'ajoutent
	chat_overlay.position = Vector2(16, -70)
	chat_overlay.custom_minimum_size = Vector2(340, 0)
	chat_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chat_overlay)

	chat_log_box = VBoxContainer.new()
	chat_log_box.add_theme_constant_override("separation", 1)
	chat_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_overlay.add_child(chat_log_box)

	chat_input = LineEdit.new()
	chat_input.visible = false
	chat_input.custom_minimum_size = Vector2(340, 28)
	chat_input.placeholder_text = "Message... (Entrée: envoyer, Échap: annuler)"
	chat_input.max_length = 140
	chat_overlay.add_child(chat_input)
	chat_input.text_submitted.connect(_on_chat_submitted)
	chat_input.gui_input.connect(_on_chat_gui_input)

func is_chat_focused() -> bool:
	return chat_input.visible and chat_input.has_focus()

func open_chat() -> void:
	chat_input.text = ""
	chat_input.visible = true
	chat_input.grab_focus()

func _on_chat_submitted(text: String) -> void:
	world.send_chat_message(text)
	chat_input.text = ""
	chat_input.visible = false

func _on_chat_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		chat_input.text = ""
		chat_input.visible = false
		get_viewport().set_input_as_handled()

func add_chat_message(sender_name: String, text: String) -> void:
	chat_messages.append({"sender": sender_name, "text": text})
	if chat_messages.size() > CHAT_MAX_MESSAGES:
		chat_messages.pop_front()
	_clear_box(chat_log_box)
	for m in chat_messages:
		var l = Label.new()
		l.text = "%s: %s" % [m.sender, m.text]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		chat_log_box.add_child(l)

func render_travel() -> void:
	var cd = world.char_data
	_clear_box(travel_box)
	_add_title(travel_box, "Voyage Rapide", 20)
	for zid in cd.unlocked_zones:
		var z = Data.ZONES[zid]
		_add_button(travel_box, z.name, func(): travel_to(zid))
	_add_button(travel_box, "Fermer (M)", func(): travel_overlay.visible = false)

func travel_to(zone_id: String) -> void:
	travel_overlay.visible = false
	var spawn = world.get_zone_spawn(zone_id)
	await fade_out()
	world.player.global_position = spawn
	world.save_now()
	await fade_in()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_I:
		if inventory_overlay.visible: close_all()
		else: render_inventory(); inventory_overlay.visible = true
	elif event.physical_keycode == KEY_M:
		if travel_overlay.visible: travel_overlay.visible = false
		else: render_travel(); travel_overlay.visible = true
	elif event.physical_keycode == KEY_O:
		if options_overlay.visible: options_overlay.visible = false
		else: sync_options(); options_overlay.visible = true
	elif event.physical_keycode == KEY_C:
		if stats_overlay.visible: stats_overlay.visible = false
		else: render_stats(); stats_overlay.visible = true
	elif event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
		open_chat()
	elif event.physical_keycode == KEY_ESCAPE:
		close_all()
		travel_overlay.visible = false
		options_overlay.visible = false
		stats_overlay.visible = false

func close_all() -> void:
	dialogue_overlay.visible = false
	inventory_overlay.visible = false

func _on_hud_update(d: Dictionary) -> void:
	hp_bar.max_value = d.max_hp
	_tween_bar(hp_bar, d.hp)
	mana_bar.max_value = d.max_mana
	_tween_bar(mana_bar, d.mana)
	xp_bar.max_value = d.xp_needed
	_tween_bar(xp_bar, d.xp)
	lvl_label.text = "Niveau %d" % d.level
	zone_label.text = d.zone
	gold_label.text = "Or: %d" % d.gold
	minimap.queue_redraw()

var _bar_tweens: Dictionary = {} # ProgressBar -> Tween en cours

func _tween_bar(bar: ProgressBar, target: float) -> void:
	# Anime la barre vers sa nouvelle valeur au lieu d'un saut instantané —
	# rend les dégâts/soins beaucoup plus lisibles visuellement. On tue le
	# tween précédent d'abord pour éviter que deux tweens se battent sur la
	# même valeur quand plusieurs mises à jour arrivent en rafale (combat).
	if _bar_tweens.has(bar) and _bar_tweens[bar] != null and _bar_tweens[bar].is_valid():
		_bar_tweens[bar].kill()
	var tw = create_tween()
	tw.tween_property(bar, "value", target, 0.25).set_trans(Tween.TRANS_SINE)
	_bar_tweens[bar] = tw

func _on_near_update(text: String) -> void:
	if text == "":
		hint_panel.visible = false
	else:
		hint_label.text = "F — " + text
		hint_panel.visible = true

func _render_quests() -> void:
	var cd = world.char_data
	var lines = ["Quetes actives:"]
	if cd.quests_active.is_empty():
		lines.append("(aucune - parle aux PNJ)")
	for qid in cd.quests_active.keys():
		var q = Data.get_quest(qid)
		if q.is_empty(): continue
		var prog = cd.quests_active[qid]
		var mark = "[OK] " if prog >= q.obj.count else "- "
		lines.append(mark + q.name + "  " + str(prog) + "/" + str(q.obj.count))
	quest_label.text = "\n".join(lines)

func _clear_box(box: VBoxContainer) -> void:
	for c in box.get_children(): c.queue_free()

func _add_title(box, text: String, size := 20) -> void:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", UiTheme.title_font())
	l.add_theme_color_override("font_color", UiTheme.gold())
	box.add_child(l)

func _add_button(box, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(func(): Audio.play("ui_click", -10.0); cb.call())
	box.add_child(b)
	return b

# Enveloppe n'importe quel contenu (texte de prime, options de talent...) dans
# la même carte bordée que les lignes d'objets, pour une apparence cohérente
# sur tous les panneaux au lieu d'un simple empilement de Label nus.
func _wrap_card(box, content: Control) -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _item_card_style())
	card.add_child(content)
	box.add_child(card)
	return card

func _icon_tex(item_id: String) -> TextureRect:
	var t = TextureRect.new()
	t.texture = load(Data.ICON_PATH + Data.ITEMS[item_id].icon)
	t.custom_minimum_size = Vector2(28, 28)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	t.tooltip_text = item_tooltip_text(item_id)
	return t

# Construit une infobulle lisible (stats/effet) pour un objet, affichée au
# survol grâce au système de tooltip natif de Godot.
func item_tooltip_text(item_id: String) -> String:
	var it = Data.ITEMS.get(item_id, {})
	if it.is_empty(): return item_id
	var lines = [it.name]
	if it.has("bonus"):
		for stat in ["atk","def","hp","mana","spd"]:
			var v = it.bonus.get(stat, 0)
			if v != 0:
				var label = {"atk":"Attaque","def":"Défense","hp":"Vie","mana":"Mana","spd":"Vitesse"}[stat]
				lines.append("%s %s%d" % [label, "+" if v > 0 else "", v])
	if it.has("heal"):
		lines.append("Soigne %d PV" % it.heal)
	if it.get("type","") == "mat":
		lines.append("Matériau de fabrication")
	if it.get("type","") == "quest":
		lines.append("Objet de quête")
	if it.has("price"):
		lines.append("Prix : %d or" % it.price)
	return "\n".join(lines)

# Carte translucente utilisée derrière chaque ligne d'objet (inventaire,
# boutiques, artisanat) pour que la liste se lise comme des "slots" distincts
# au lieu d'un empilement plat de texte sans séparation visuelle.
func _item_card_style() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.03, 0.4)
	sb.border_color = Color(0.55, 0.45, 0.25, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb

# Ligne d'objet avec icône, utilisée dans l'inventaire et les boutiques.
# Si cb est fourni, toute la ligne est cliquable (bouton) ; sinon c'est un simple affichage.
func _add_item_row(box, item_id: String, label_text: String, cb) -> Control:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _item_card_style())
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_icon_tex(item_id))
	card.add_child(row)
	box.add_child(card)
	if cb == null:
		var l = Label.new()
		l.text = label_text
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		return row
	else:
		var b = Button.new()
		b.text = label_text
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.tooltip_text = item_tooltip_text(item_id)
		b.pressed.connect(func(): Audio.play("ui_click", -10.0); cb.call())
		row.add_child(b)
		return b

# ---------------- Dialogue PNJ ----------------
var current_npc: Dictionary = {}

func _on_open_npc(npc: Dictionary) -> void:
	current_npc = npc
	# Sans ça, les quêtes de type "talk" (dont q_intro, la toute première quête)
	# ne pouvaient jamais être complétées : parler au PNJ n'incrémentait rien.
	world.update_quest_progress("talk", npc.id)
	Audio.play("dialogue_open", -6.0)
	render_npc_dialogue()
	dialogue_overlay.visible = true

func render_npc_dialogue() -> void:
	if current_npc.is_empty(): return
	var npc = current_npc
	var cd = world.char_data
	_clear_box(dialogue_box)
	_add_title(dialogue_box, npc.name)

	var to_turnin = []
	for qid in cd.quests_active.keys():
		var q = Data.get_quest(qid)
		if not q.is_empty() and q.giver == npc.id and cd.quests_active[qid] >= q.obj.count:
			to_turnin.append(qid)
	var available = []
	for q in Data.QUESTS:
		if q.giver != npc.id: continue
		if cd.quests_active.has(q.id) or cd.quests_completed.has(q.id): continue
		var ok = true
		for r in q.requires:
			if not cd.quests_completed.has(r): ok = false; break
		if q.has("race_req") and cd.race != q.race_req: ok = false
		if ok: available.append(q)

	if not to_turnin.is_empty():
		_add_title(dialogue_box, "Quetes terminees", 15)
		for qid in to_turnin:
			var q = Data.get_quest(qid)
			_add_button(dialogue_box, "[Rendre] " + q.name, func(): turn_in_quest(qid))

	if not available.is_empty():
		_add_title(dialogue_box, "Quetes disponibles", 15)
		for q in available:
			var qbox = VBoxContainer.new()
			var title = Label.new()
			title.text = q.name
			title.add_theme_color_override("font_color", Color(1,0.88,0.4))
			qbox.add_child(title)
			var desc = Label.new()
			desc.text = q.desc + "\nRécompense : %d XP, %d or" % [q.reward.xp, q.reward.get("gold", 0)]
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD
			qbox.add_child(desc)
			_wrap_card(dialogue_box, qbox)
			_add_button(dialogue_box, "Accepter : " + q.name, func(): accept_quest(q.id))

	if to_turnin.is_empty() and available.is_empty():
		var has_active = false
		for qid in cd.quests_active.keys():
			var q = Data.get_quest(qid)
			if not q.is_empty() and q.giver == npc.id: has_active = true
		var msg = Label.new()
		msg.text = "\"Reviens me voir plus tard.\"" if has_active else "\"Je n'ai rien pour toi.\""
		_wrap_card(dialogue_box, msg)

	if npc.id == "garde":
		var culled = world.village_economy.get("monsters_culled", 0)
		if culled > 0:
			var patrol_lbl = Label.new()
			patrol_lbl.text = "\"Mes patrouilles ont repoussé %d monstre%s de la plaine ces derniers temps.\"" % [culled, "s" if culled > 1 else ""]
			patrol_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			patrol_lbl.add_theme_color_override("font_color", Color(0.7,0.8,1))
			_wrap_card(dialogue_box, patrol_lbl)

	if npc.role == "shop":
		var eco = world.village_economy
		_add_title(dialogue_box, "Boutique", 15)
		var stock_lbl = Label.new()
		stock_lbl.text = "Yvenne a %d potions en stock (prix ajusté selon la demande)." % eco.potion_stock
		stock_lbl.add_theme_font_size_override("font_size", 12)
		stock_lbl.add_theme_color_override("font_color", Color(0.7,0.7,0.7))
		dialogue_box.add_child(stock_lbl)
		for key in ["potion_vie", "potion_mana"]:
			var it = Data.ITEMS[key]
			var btn = _add_item_row(dialogue_box, key, "%s - %d or" % [it.name, eco.potion_price], func(): buy_item(key))
			btn.disabled = eco.potion_stock <= 0
		_add_title(dialogue_box, "Objets de faction", 14)
		for key in ["cape_heros", "arc_rangers", "robe_cercle"]:
			var it = Data.ITEMS[key]
			var req = it.rep_req
			var have_rep = cd.reputation.get(req.faction, 0)
			var unlocked = have_rep >= req.min
			var label = "%s — %d or (réputation %s requise: %s)" % [it.name, it.price, Data.FACTIONS[req.faction].name, Data.rep_tier_name(req.min)]
			var btn = _add_item_row(dialogue_box, key, label, func(): buy_faction_item(key))
			btn.disabled = not unlocked

	if npc.id == "forgeron_pnj":
		var eco2 = world.village_economy
		_add_title(dialogue_box, "Armurerie", 14)
		var arme_lbl = Label.new()
		arme_lbl.text = "Grondar a %d épées de fer en stock (prix ajusté selon la demande)." % eco2.arme_stock
		arme_lbl.add_theme_font_size_override("font_size", 12)
		arme_lbl.add_theme_color_override("font_color", Color(0.7,0.7,0.7))
		dialogue_box.add_child(arme_lbl)
		var arme_btn = _add_item_row(dialogue_box, "epee_fer", "Épée de Fer - %d or" % eco2.arme_price, func(): buy_forged_weapon())
		arme_btn.disabled = eco2.arme_stock <= 0

	if npc.role == "profession":
		var prof = Data.PROFESSIONS[npc.profession]
		_add_title(dialogue_box, "Metier: " + prof.name, 15)
		if cd.profession != npc.profession:
			_add_button(dialogue_box, "Apprendre " + prof.name, func(): learn_profession(npc.profession))
		else:
			for r in Data.RECIPES:
				if r.profession != npc.profession: continue
				var cost_str = []
				var has = true
				for k in r.cost.keys():
					cost_str.append(str(r.cost[k]) + " " + Data.ITEMS[k].name)
					if cd.inventory.get(k, 0) < r.cost[k]: has = false
				var label = "%s — Coût : %s" % [r.name, ", ".join(cost_str)]
				var btn = _add_item_row(dialogue_box, r.result, label, func(): craft_recipe(r.id))
				btn.disabled = not has

	if npc.role == "respec":
		_add_title(dialogue_box, "Maître d'Armes", 15)
		var n_talents = cd.talents.size()
		if n_talents == 0:
			var lbl = Label.new(); lbl.text = "\"Tu n'as encore choisi aucune spécialisation.\""
			dialogue_box.add_child(lbl)
		else:
			var cost = 50 * n_talents
			var lbl2 = Label.new()
			lbl2.text = "Réinitialise tes %d spécialisation(s) choisie(s) pour les re-choisir au prochain palier de niveau." % n_talents
			lbl2.autowrap_mode = TextServer.AUTOWRAP_WORD
			dialogue_box.add_child(lbl2)
			var btn = _add_button(dialogue_box, "Réinitialiser — %d or" % cost, func(): respec_talents(cost))
			btn.disabled = cd.gold < cost

	if npc.role == "bounty":
		_add_title(dialogue_box, "Chasse aux Primes", 15)
		var b = cd.bounty
		if b == null:
			var doneLbl = Label.new()
			doneLbl.text = "Primes complétées : %d" % cd.bounties_done
			_wrap_card(dialogue_box, doneLbl)
			_add_button(dialogue_box, "Demander une prime", func(): request_bounty())
		elif b.progress >= b.count:
			var lbl = Label.new()
			lbl.text = "Prime terminée : %s (%d/%d) !" % [b.target_name, b.progress, b.count]
			_wrap_card(dialogue_box, lbl)
			_add_button(dialogue_box, "Encaisser : %d or, %d XP" % [b.reward_gold, b.reward_xp], func(): collect_bounty())
		else:
			var box2 = VBoxContainer.new()
			var lbl = Label.new()
			lbl.text = "Prime en cours : élimine %d %s (%d/%d)" % [b.count, b.target_name, b.progress, b.count]
			box2.add_child(lbl)
			var rew = Label.new()
			rew.text = "Récompense : %d or, %d XP" % [b.reward_gold, b.reward_xp]
			box2.add_child(rew)
			_wrap_card(dialogue_box, box2)

	_add_button(dialogue_box, "Fermer (ESC)", func(): close_all())

func accept_quest(qid: String) -> void:
	world.char_data.quests_active[qid] = 0
	close_all()
	_render_quests()

func turn_in_quest(qid: String) -> void:
	var q = Data.get_quest(qid)
	var cd = world.char_data
	if q.obj.type == "deliver":
		var item = q.obj.item
		if cd.inventory.get(item, 0) < q.obj.count: return
		cd.inventory[item] -= q.obj.count
	cd.quests_active.erase(qid)
	cd.quests_completed.append(qid)
	cd.gold += q.reward.get("gold", 0)
	var res = world.player.gain_xp(q.reward.xp)
	for it in q.reward.get("items", []):
		cd.inventory[it] = cd.inventory.get(it, 0) + 1
	var faction = Data.QUEST_FACTION.get(qid, "")
	if faction != "":
		var rep_gain = max(5, int(q.reward.xp / 10.0))
		cd.reputation[faction] = cd.reputation.get(faction, 0) + rep_gain
		world.float_text(world.player.global_position + Vector2(0,-100), "+%d réputation (%s)" % [rep_gain, Data.FACTIONS[faction].name], Color(0.6,0.85,1))
	world.float_text(world.player.global_position + Vector2(0,-60), "Quete terminee: " + q.name, Color(1,0.88,0.4))
	Audio.play("quest_complete")
	if res.leveled: Audio.play("level_up", -2.0)
	world.emit_signal("hud_update", world.make_hud_data())
	world.save_now()
	_render_quests()
	render_npc_dialogue()

func buy_item(key: String) -> void:
	var cd = world.char_data
	var eco = world.village_economy
	if eco.potion_stock <= 0: return # l'alchimiste n'a plus rien à vendre pour l'instant
	if cd.gold < eco.potion_price: return
	cd.gold -= eco.potion_price
	eco.potion_stock -= 1
	eco.potion_price = clampi(25 - eco.potion_stock, 8, 25)
	cd.inventory[key] = cd.inventory.get(key, 0) + 1
	Audio.play("gold_pickup", -8.0)
	world.emit_signal("hud_update", world.make_hud_data())
	render_npc_dialogue()

func buy_forged_weapon() -> void:
	var cd = world.char_data
	var eco = world.village_economy
	if eco.arme_stock <= 0: return # Grondar n'a plus rien en stock pour l'instant
	if cd.gold < eco.arme_price: return
	cd.gold -= eco.arme_price
	eco.arme_stock -= 1
	eco.arme_price = clampi(70 - eco.arme_stock * 5, 25, 70)
	cd.inventory["epee_fer"] = cd.inventory.get("epee_fer", 0) + 1
	Audio.play("gold_pickup", -8.0)
	world.emit_signal("hud_update", world.make_hud_data())
	render_npc_dialogue()

func buy_faction_item(key: String) -> void:
	var cd = world.char_data
	var it = Data.ITEMS[key]
	var req = it.rep_req
	if cd.reputation.get(req.faction, 0) < req.min: return
	if cd.gold < it.price: return
	cd.gold -= it.price
	cd.inventory[key] = cd.inventory.get(key, 0) + 1
	Audio.play("gold_pickup", -8.0)
	world.emit_signal("hud_update", world.make_hud_data())
	world.save_now()
	render_npc_dialogue()

func learn_profession(pid: String) -> void:
	world.char_data.profession = pid
	render_npc_dialogue()

func respec_talents(cost: int) -> void:
	var cd = world.char_data
	if cd.gold < cost: return
	cd.gold -= cost
	cd.talents = {}
	world.player.stats = GameState.compute_stats(cd)
	world.player.hp = min(world.player.hp, world.player.stats.max_hp)
	world.player.mana = min(world.player.mana, world.player.stats.max_mana)
	world.emit_signal("hud_update", world.make_hud_data())
	world.save_now()
	render_npc_dialogue()
	var tier = GameState.pending_talent(cd)
	if not tier.is_empty(): _on_talent_available(tier)

func request_bounty() -> void:
	var cd = world.char_data
	var data = get_node("/root/Data")
	cd.bounty = data.random_bounty(cd.level)
	render_npc_dialogue()

func collect_bounty() -> void:
	var cd = world.char_data
	var b = cd.bounty
	if b == null or b.progress < b.count: return
	cd.gold += b.reward_gold
	world.player.gain_xp(b.reward_xp)
	cd.bounties_done += 1
	cd.bounty = null
	world.float_text(world.player.global_position + Vector2(0,-60), "Prime encaissée !", Color(1,0.75,0.3))
	world.emit_signal("hud_update", world.make_hud_data())
	world.save_now()
	render_npc_dialogue()

func craft_recipe(rid: String) -> void:
	var cd = world.char_data
	var r = null
	for x in Data.RECIPES:
		if x.id == rid: r = x; break
	if r == null: return
	for k in r.cost.keys():
		if cd.inventory.get(k, 0) < r.cost[k]: return
	for k in r.cost.keys(): cd.inventory[k] -= r.cost[k]
	cd.inventory[r.result] = cd.inventory.get(r.result, 0) + 1
	render_npc_dialogue()

# ---------------- Inventaire ----------------
var inv_search_text := ""

const ACCENT_MAP := {
	"à":"a","â":"a","ä":"a","á":"a", "é":"e","è":"e","ê":"e","ë":"e",
	"î":"i","ï":"i", "ô":"o","ö":"o", "ù":"u","û":"u","ü":"u", "ç":"c",
}
func _normalize_search(s: String) -> String:
	s = s.strip_edges().to_lower()
	var out = ""
	for c in s:
		out += ACCENT_MAP.get(c, c)
	return out

func render_inventory() -> void:
	var cd = world.char_data
	_clear_box(inventory_box)
	_add_title(inventory_box, "Inventaire - " + cd.name)

	var search = LineEdit.new()
	search.placeholder_text = "Rechercher un objet..."
	search.text = inv_search_text
	search.custom_minimum_size = Vector2(0, 32)
	search.text_changed.connect(func(t): inv_search_text = t; render_inventory())
	inventory_box.add_child(search)
	search.grab_focus()
	search.caret_column = inv_search_text.length()

	var filter = _normalize_search(inv_search_text)
	var matches = func(id): return filter == "" or _normalize_search(Data.ITEMS[id].name).contains(filter)

	if filter == "":
		_add_title(inventory_box, "Progression", 15)
		var prog_lbl = Label.new()
		prog_lbl.text = "%d quête%s terminée%s · %d prime%s complétée%s" % [
			cd.quests_completed.size(), "s" if cd.quests_completed.size() > 1 else "",
			"s" if cd.quests_completed.size() > 1 else "",
			cd.bounties_done, "s" if cd.bounties_done > 1 else "", "s" if cd.bounties_done > 1 else "",
		]
		inventory_box.add_child(prog_lbl)

		_add_title(inventory_box, "Réputations", 15)
		for fid in Data.FACTIONS.keys():
			var rep = cd.reputation.get(fid, 0)
			var lbl2 = Label.new()
			lbl2.text = "%s : %d (%s)" % [Data.FACTIONS[fid].name, rep, Data.rep_tier_name(rep)]
			inventory_box.add_child(lbl2)

		if not cd.gather_counts.is_empty():
			_add_title(inventory_box, "Récolte totale", 15)
			var stats_lbl = Label.new()
			var parts = []
			for mat in cd.gather_counts.keys():
				if cd.gather_counts[mat] > 0:
					parts.append("%d %s" % [cd.gather_counts[mat], Data.ITEMS[mat].name])
			stats_lbl.text = ", ".join(parts) if not parts.is_empty() else "(rien récolté pour l'instant)"
			stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			inventory_box.add_child(stats_lbl)

		_add_title(inventory_box, "Equipement", 15)
		for slot in ["weapon", "armor"]:
			var item_id = cd.equipment.get(slot, "")
			var slot_name = "Arme" if slot == "weapon" else "Armure"
			if item_id != "":
				_add_item_row(inventory_box, item_id, slot_name + ": " + Data.ITEMS[item_id].name, null)
			else:
				var lbl = Label.new(); lbl.text = slot_name + ": Aucun"; inventory_box.add_child(lbl)

	var equipable = []
	for id in cd.inventory.keys():
		if cd.inventory[id] > 0 and (Data.ITEMS[id].type == "weapon" or Data.ITEMS[id].type == "armor") and matches.call(id):
			equipable.append(id)
	if not equipable.is_empty():
		_add_title(inventory_box, "A equiper", 15)
		for id in equipable:
			_add_item_row(inventory_box, id, Data.ITEMS[id].name, func(): equip_item(id))

	var consumables = []
	for id in cd.inventory.keys():
		if cd.inventory[id] > 0 and Data.ITEMS[id].type == "consumable" and matches.call(id):
			consumables.append(id)
	if not consumables.is_empty():
		_add_title(inventory_box, "Consommables", 15)
		for id in consumables:
			_add_item_row(inventory_box, id, "%s x%d" % [Data.ITEMS[id].name, cd.inventory[id]], func(): use_item(id))

	var mats = []
	for id in cd.inventory.keys():
		if cd.inventory[id] > 0 and (Data.ITEMS[id].type == "mat" or Data.ITEMS[id].type == "quest") and matches.call(id):
			mats.append(id)
	_add_title(inventory_box, "Materiaux", 15)
	if mats.is_empty():
		var l = Label.new(); l.text = "(vide)" if filter == "" else "(aucun résultat)"; inventory_box.add_child(l)
	for id in mats:
		_add_item_row(inventory_box, id, "%s x%d" % [Data.ITEMS[id].name, cd.inventory[id]], null)

	if equipable.is_empty() and consumables.is_empty() and mats.is_empty() and filter != "":
		var none = Label.new(); none.text = "Aucun objet ne correspond à \"%s\"." % filter
		inventory_box.add_child(none)

	_add_button(inventory_box, "Fermer (I)", func(): close_all())

func equip_item(id: String) -> void:
	if world.player.dead: return
	var cd = world.char_data
	var it = Data.ITEMS[id]
	var slot = "weapon" if it.type == "weapon" else "armor"
	cd.equipment[slot] = id
	world.player.stats = GameState.compute_stats(cd)
	world.player.update_equipment_visual()
	world.emit_signal("hud_update", world.make_hud_data())
	world.save_now()
	render_inventory()

func use_item(id: String) -> void:
	if world.player.dead:
		world.float_text(world.player.global_position + Vector2(0,-50), "Impossible : tu es K.O.", Color(0.9,0.3,0.3))
		return
	var cd = world.char_data
	if cd.inventory.get(id, 0) <= 0: return
	var it = Data.ITEMS[id]
	var now = Time.get_ticks_msec() / 1000.0
	if it.has("use_cd"):
		if now < world.player.cooldowns.get("item_" + id, 0.0):
			world.float_text(world.player.global_position + Vector2(0,-50), "Pas encore prêt...", Color(0.6,0.6,0.9))
			return
		world.player.cooldowns["item_" + id] = now + it.use_cd
	cd.inventory[id] -= 1
	if it.has("heal"): world.player.heal(it.heal)
	if it.has("mana"): world.player.mana = min(world.player.stats.max_mana, world.player.mana + it.mana)
	Audio.play("potion_drink")
	world.emit_signal("hud_update", world.make_hud_data())
	render_inventory()
