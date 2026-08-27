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

func bind(w) -> void:
	world = w
	world.hud_update.connect(_on_hud_update)
	world.near_update.connect(_on_near_update)
	world.open_npc.connect(_on_open_npc)
	world.quest_progress.connect(_render_quests)
	_render_quests()

func _ready() -> void:
	layer = 10
	_build_bars()
	_build_hint()
	_build_dialogue_overlay()
	_build_inventory_overlay()

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

	hp_bar = ProgressBar.new()
	hp_bar.max_value = 100; hp_bar.value = 100
	hp_bar.custom_minimum_size = Vector2(200, 16)
	hp_bar.show_percentage = false
	var hp_style = StyleBoxFlat.new(); hp_style.bg_color = Color(0.82,0.23,0.23)
	hp_bar.add_theme_stylebox_override("fill", hp_style)
	topleft.add_child(hp_bar)

	mana_bar = ProgressBar.new()
	mana_bar.max_value = 100; mana_bar.value = 100
	mana_bar.custom_minimum_size = Vector2(200, 12)
	mana_bar.show_percentage = false
	var mana_style = StyleBoxFlat.new(); mana_style.bg_color = Color(0.23,0.48,0.82)
	mana_bar.add_theme_stylebox_override("fill", mana_style)
	topleft.add_child(mana_bar)

	xp_bar = ProgressBar.new()
	xp_bar.max_value = 100; xp_bar.value = 0
	xp_bar.custom_minimum_size = Vector2(200, 6)
	xp_bar.show_percentage = false
	var xp_style = StyleBoxFlat.new(); xp_style.bg_color = Color(0.82,0.78,0.23)
	xp_bar.add_theme_stylebox_override("fill", xp_style)
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
	help.text = "ZQSD/Flèches: bouger · Espace: attaque · Q/E: compétences · F: interagir · I: inventaire"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(1,1,1,0.6))
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(16, -24)
	root.add_child(help)

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

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_I:
		if inventory_overlay.visible: close_all()
		else: render_inventory(); inventory_overlay.visible = true
	elif event.physical_keycode == KEY_ESCAPE:
		close_all()

func close_all() -> void:
	dialogue_overlay.visible = false
	inventory_overlay.visible = false

func _on_hud_update(d: Dictionary) -> void:
	hp_bar.max_value = d.max_hp; hp_bar.value = d.hp
	mana_bar.max_value = d.max_mana; mana_bar.value = d.mana
	xp_bar.max_value = d.xp_needed; xp_bar.value = d.xp
	lvl_label.text = "Niveau %d" % d.level
	zone_label.text = d.zone
	gold_label.text = "Or: %d" % d.gold

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
	box.add_child(l)

func _add_button(box, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 36)
	b.pressed.connect(cb)
	box.add_child(b)
	return b

# ---------------- Dialogue PNJ ----------------
var current_npc: Dictionary = {}

func _on_open_npc(npc: Dictionary) -> void:
	current_npc = npc
	render_npc_dialogue()
	dialogue_overlay.visible = true

func render_npc_dialogue() -> void:
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
		if ok: available.append(q)

	if not to_turnin.is_empty():
		_add_title(dialogue_box, "Quetes terminees", 15)
		for qid in to_turnin:
			var q = Data.get_quest(qid)
			_add_button(dialogue_box, "[Rendre] " + q.name, func(): turn_in_quest(qid))

	if not available.is_empty():
		_add_title(dialogue_box, "Quetes disponibles", 15)
		for q in available:
			var desc = Label.new()
			desc.text = q.desc + "\nRecompense: %d XP, %d or" % [q.reward.xp, q.reward.get("gold", 0)]
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD
			dialogue_box.add_child(desc)
			_add_button(dialogue_box, "Accepter: " + q.name, func(): accept_quest(q.id))

	if to_turnin.is_empty() and available.is_empty():
		var has_active = false
		for qid in cd.quests_active.keys():
			var q = Data.get_quest(qid)
			if not q.is_empty() and q.giver == npc.id: has_active = true
		var msg = Label.new()
		msg.text = "\"Reviens me voir plus tard.\"" if has_active else "\"Je n'ai rien pour toi.\""
		dialogue_box.add_child(msg)

	if npc.role == "shop":
		_add_title(dialogue_box, "Boutique", 15)
		for key in ["potion_vie", "potion_mana"]:
			var it = Data.ITEMS[key]
			_add_button(dialogue_box, it.name + " - 15 or", func(): buy_item(key))

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
				var lbl = Label.new()
				lbl.text = r.name + " -- Cout: " + ", ".join(cost_str)
				dialogue_box.add_child(lbl)
				var btn = _add_button(dialogue_box, "Fabriquer " + r.name, func(): craft_recipe(r.id))
				btn.disabled = not has

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
	world.float_text(world.player.global_position + Vector2(0,-60), "Quete terminee: " + q.name, Color(1,0.88,0.4))
	world.emit_signal("hud_update", world.make_hud_data())
	_render_quests()
	render_npc_dialogue()

func buy_item(key: String) -> void:
	var cd = world.char_data
	if cd.gold < 15: return
	cd.gold -= 15
	cd.inventory[key] = cd.inventory.get(key, 0) + 1
	world.emit_signal("hud_update", world.make_hud_data())
	render_npc_dialogue()

func learn_profession(pid: String) -> void:
	world.char_data.profession = pid
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
func render_inventory() -> void:
	var cd = world.char_data
	_clear_box(inventory_box)
	_add_title(inventory_box, "Inventaire - " + cd.name)

	_add_title(inventory_box, "Equipement", 15)
	for slot in ["weapon", "armor"]:
		var item_id = cd.equipment.get(slot, "")
		var lbl = Label.new()
		var slot_name = "Arme" if slot == "weapon" else "Armure"
		lbl.text = slot_name + ": " + (Data.ITEMS[item_id].name if item_id != "" else "Aucun")
		inventory_box.add_child(lbl)

	var equipable = []
	for id in cd.inventory.keys():
		if cd.inventory[id] > 0 and (Data.ITEMS[id].type == "weapon" or Data.ITEMS[id].type == "armor"):
			equipable.append(id)
	if not equipable.is_empty():
		_add_title(inventory_box, "A equiper", 15)
		for id in equipable:
			_add_button(inventory_box, Data.ITEMS[id].name, func(): equip_item(id))

	var consumables = []
	for id in cd.inventory.keys():
		if cd.inventory[id] > 0 and Data.ITEMS[id].type == "consumable":
			consumables.append(id)
	if not consumables.is_empty():
		_add_title(inventory_box, "Consommables", 15)
		for id in consumables:
			_add_button(inventory_box, "%s x%d" % [Data.ITEMS[id].name, cd.inventory[id]], func(): use_item(id))

	_add_title(inventory_box, "Materiaux", 15)
	var mats = []
	for id in cd.inventory.keys():
		if cd.inventory[id] > 0 and (Data.ITEMS[id].type == "mat" or Data.ITEMS[id].type == "quest"):
			mats.append(id)
	if mats.is_empty():
		var l = Label.new(); l.text = "(vide)"; inventory_box.add_child(l)
	for id in mats:
		var l = Label.new()
		l.text = "%s x%d" % [Data.ITEMS[id].name, cd.inventory[id]]
		inventory_box.add_child(l)

	_add_button(inventory_box, "Fermer (I)", func(): close_all())

func equip_item(id: String) -> void:
	var cd = world.char_data
	var it = Data.ITEMS[id]
	var slot = "weapon" if it.type == "weapon" else "armor"
	cd.equipment[slot] = id
	world.player.stats = GameState.compute_stats(cd)
	world.emit_signal("hud_update", world.make_hud_data())
	render_inventory()

func use_item(id: String) -> void:
	var cd = world.char_data
	if cd.inventory.get(id, 0) <= 0: return
	cd.inventory[id] -= 1
	var it = Data.ITEMS[id]
	if it.has("heal"): world.player.heal(it.heal)
	if it.has("mana"): world.player.mana = min(world.player.stats.max_mana, world.player.mana + it.mana)
	world.emit_signal("hud_update", world.make_hud_data())
	render_inventory()
