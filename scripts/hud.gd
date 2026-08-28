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
	_build_hint()
	_build_dialogue_overlay()
	_build_inventory_overlay()
	_build_talent_overlay()
	_build_travel_overlay()

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
	help.text = "ZQSD/Flèches: bouger · Espace: attaque · Q/E: compétences · F: interagir · I: inventaire · M: voyage rapide"
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
		var card = VBoxContainer.new()
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

func render_travel() -> void:
	var cd = world.char_data
	_clear_box(travel_box)
	_add_title(travel_box, "Voyage Rapide", 20)
	for zid in cd.unlocked_zones:
		var z = Data.ZONES[zid]
		_add_button(travel_box, z.name, func(): travel_to(zid))
	_add_button(travel_box, "Fermer (M)", func(): travel_overlay.visible = false)

func travel_to(zone_id: String) -> void:
	var spawn = world.get_zone_spawn(zone_id)
	world.player.global_position = spawn
	world.save_now()
	travel_overlay.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_I:
		if inventory_overlay.visible: close_all()
		else: render_inventory(); inventory_overlay.visible = true
	elif event.physical_keycode == KEY_M:
		if travel_overlay.visible: travel_overlay.visible = false
		else: render_travel(); travel_overlay.visible = true
	elif event.physical_keycode == KEY_ESCAPE:
		close_all()
		travel_overlay.visible = false

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
		_add_title(dialogue_box, "Objets de faction", 14)
		for key in ["cape_heros", "arc_rangers", "robe_cercle"]:
			var it = Data.ITEMS[key]
			var req = it.rep_req
			var have_rep = cd.reputation.get(req.faction, 0)
			var unlocked = have_rep >= req.min
			var label = "%s — %d or (réputation %s requise: %s)" % [it.name, it.price, Data.FACTIONS[req.faction].name, Data.rep_tier_name(req.min)]
			var btn = _add_button(dialogue_box, label, func(): buy_faction_item(key))
			btn.disabled = not unlocked

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
			dialogue_box.add_child(doneLbl)
			_add_button(dialogue_box, "Demander une prime", func(): request_bounty())
		elif b.progress >= b.count:
			var lbl = Label.new()
			lbl.text = "Prime terminée : %s (%d/%d) !" % [b.target_name, b.progress, b.count]
			dialogue_box.add_child(lbl)
			_add_button(dialogue_box, "Encaisser : %d or, %d XP" % [b.reward_gold, b.reward_xp], func(): collect_bounty())
		else:
			var lbl = Label.new()
			lbl.text = "Prime en cours : élimine %d %s (%d/%d)" % [b.count, b.target_name, b.progress, b.count]
			dialogue_box.add_child(lbl)
			var rew = Label.new()
			rew.text = "Récompense : %d or, %d XP" % [b.reward_gold, b.reward_xp]
			dialogue_box.add_child(rew)

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
	world.emit_signal("hud_update", world.make_hud_data())
	world.save_now()
	_render_quests()
	render_npc_dialogue()

func buy_item(key: String) -> void:
	var cd = world.char_data
	if cd.gold < 15: return
	cd.gold -= 15
	cd.inventory[key] = cd.inventory.get(key, 0) + 1
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
		_add_title(inventory_box, "Réputations", 15)
		for fid in Data.FACTIONS.keys():
			var rep = cd.reputation.get(fid, 0)
			var lbl2 = Label.new()
			lbl2.text = "%s : %d (%s)" % [Data.FACTIONS[fid].name, rep, Data.rep_tier_name(rep)]
			inventory_box.add_child(lbl2)

		_add_title(inventory_box, "Equipement", 15)
		for slot in ["weapon", "armor"]:
			var item_id = cd.equipment.get(slot, "")
			var lbl = Label.new()
			var slot_name = "Arme" if slot == "weapon" else "Armure"
			lbl.text = slot_name + ": " + (Data.ITEMS[item_id].name if item_id != "" else "Aucun")
			inventory_box.add_child(lbl)

	var equipable = []
	for id in cd.inventory.keys():
		if cd.inventory[id] > 0 and (Data.ITEMS[id].type == "weapon" or Data.ITEMS[id].type == "armor") and matches.call(id):
			equipable.append(id)
	if not equipable.is_empty():
		_add_title(inventory_box, "A equiper", 15)
		for id in equipable:
			_add_button(inventory_box, Data.ITEMS[id].name, func(): equip_item(id))

	var consumables = []
	for id in cd.inventory.keys():
		if cd.inventory[id] > 0 and Data.ITEMS[id].type == "consumable" and matches.call(id):
			consumables.append(id)
	if not consumables.is_empty():
		_add_title(inventory_box, "Consommables", 15)
		for id in consumables:
			_add_button(inventory_box, "%s x%d" % [Data.ITEMS[id].name, cd.inventory[id]], func(): use_item(id))

	var mats = []
	for id in cd.inventory.keys():
		if cd.inventory[id] > 0 and (Data.ITEMS[id].type == "mat" or Data.ITEMS[id].type == "quest") and matches.call(id):
			mats.append(id)
	_add_title(inventory_box, "Materiaux", 15)
	if mats.is_empty():
		var l = Label.new(); l.text = "(vide)" if filter == "" else "(aucun résultat)"; inventory_box.add_child(l)
	for id in mats:
		var l = Label.new()
		l.text = "%s x%d" % [Data.ITEMS[id].name, cd.inventory[id]]
		inventory_box.add_child(l)

	if equipable.is_empty() and consumables.is_empty() and mats.is_empty() and filter != "":
		var none = Label.new(); none.text = "Aucun objet ne correspond à \"%s\"." % filter
		inventory_box.add_child(none)

	_add_button(inventory_box, "Fermer (I)", func(): close_all())

func equip_item(id: String) -> void:
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
	world.emit_signal("hud_update", world.make_hud_data())
	render_inventory()
