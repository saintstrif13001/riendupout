extends SceneTree
# Outil de capture d'écran + tests fonctionnels hors-ligne pour vérification par l'agent.
# Usage: godot --rendering-driver opengl3 --path <proj> -s scripts/tools/capture.gd --
#        <scene_res_path> <out_png_path> [wait_frames] [zone_id] [test_combat|test_quest]

var frame_count := 0
var wait_frames := 20
var out_path := "user://screenshot.png"
var scene_path := "res://scenes/Main.tscn"
var stage := 0
var inst = null
var test_mode := ""
var zone_id := ""

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	scene_path = args[0] if args.size() > 0 else "res://scenes/Main.tscn"
	out_path = args[1] if args.size() > 1 else "user://screenshot.png"
	wait_frames = int(args[2]) if args.size() > 2 else 20
	zone_id = args[3] if args.size() > 3 else ""
	if zone_id == "none": zone_id = ""
	test_mode = args[4] if args.size() > 4 else ""
	root.size = Vector2i(1152, 648)

func _process(delta: float) -> bool:
	if stage == 0:
		stage = 1
		if scene_path == "res://scenes/World.tscn":
			var gs = root.get_node("/root/GameState")
			gs.mode = "solo"
			gs.char_data = gs.new_character("Testeur", "humain", "guerrier")
		if test_mode == "test_continue_menu":
			var gs2 = root.get_node("/root/GameState")
			gs2.char_data = gs2.new_character("SauvegardeTest", "elfe", "mage")
			gs2.char_data.level = 9
			gs2.save_character()
			print("TEST_PRESAVE has_save=%s" % gs2.has_save())
		var packed: PackedScene = load(scene_path)
		inst = packed.instantiate()
		root.add_child(inst)
		if zone_id != "" and "player" in inst:
			var data = root.get_node("/root/Data")
			if data.ZONES.has(zone_id):
				var z = data.ZONES[zone_id]
				inst.player.global_position = Vector2(z.x0 + 300, data.WORLD_HEIGHT/2.0)
				var cam = inst.player.get_node_or_null("Camera2D")
				if cam: cam.reset_smoothing()
		return false

	if stage == 1:
		frame_count += 1
		if frame_count < 10:
			return false
		stage = 2
		return false

	if stage == 2:
		stage = 3
		if test_mode == "test_combat":
			_run_combat_test()
		elif test_mode == "test_quest":
			_run_quest_test()
		elif test_mode == "test_bounty":
			_run_bounty_test()
		elif test_mode == "test_save":
			_run_save_test()
		elif test_mode == "test_talent":
			_run_talent_test()
		elif test_mode == "test_reputation":
			_run_reputation_test()
		elif test_mode == "test_skills":
			_run_skills_test()
		elif test_mode == "show_wolf":
			inst.spawn_enemy({"x": inst.player.global_position.x + 60, "y": inst.player.global_position.y, "type_id": "loup", "respawn_at": 0.0})
		elif test_mode == "test_continue_menu":
			_run_continue_menu_test()
		elif test_mode == "show_travel_ui":
			inst.char_data.unlocked_zones = ["village","plaine","foret","caverne","marais"]
			var hud4 = inst.get_node("Hud")
			hud4.render_travel()
			hud4.travel_overlay.visible = true
		elif test_mode == "debug_roof":
			var tex = load("res://assets/buildings/roof_tan.png")
			print("TEX_RESULT valid=%s width=%s height=%s" % [tex != null, tex.get_width() if tex else "n/a", tex.get_height() if tex else "n/a"])
		elif test_mode == "test_souls":
			_run_souls_test()
		elif test_mode == "test_respec":
			_run_respec_test()
		elif test_mode == "test_race_quests":
			_run_race_quest_test()
		elif test_mode == "test_travel":
			_run_travel_test()
		elif test_mode == "test_boss_phase":
			_run_boss_phase_test()
		elif test_mode == "test_death":
			_run_death_test()
		elif test_mode == "show_alpha":
			inst.spawn_enemy({"x": inst.player.global_position.x + 60, "y": inst.player.global_position.y, "type_id": "loup_alpha", "respawn_at": 0.0})
		elif test_mode == "show_kobold":
			inst.spawn_enemy({"x": inst.player.global_position.x + 60, "y": inst.player.global_position.y, "type_id": "kobold", "respawn_at": 0.0})
		elif test_mode == "test_data_integrity":
			_run_data_integrity_test()
		elif test_mode == "test_equip":
			var hud2 = inst.get_node("Hud")
			inst.char_data.inventory["armure_plates"] = 1
			hud2.equip_item("armure_plates")
			print("TEST_RESULT armor_equipped=%s legs_modulate=%s equip_label=%s"
				% [inst.char_data.equipment.armor, inst.player.legs_sprite.modulate, inst.player.equip_label.text])
		elif test_mode == "show_inventory_search":
			var hud3 = inst.get_node("Hud")
			inst.char_data.inventory = {"minerai":5,"bois":2,"epee_fer":1,"potion_vie":3}
			hud3.inv_search_text = "epee"
			hud3.render_inventory()
			hud3.inventory_overlay.visible = true
		elif test_mode == "show_inventory_full":
			var hud5 = inst.get_node("Hud")
			inst.char_data.inventory = {"minerai":5,"bois":3,"herbe":2,"os":1,"epee_fer":1,"armure_cuir":1,"potion_vie":3,"potion_mana":2}
			inst.char_data.equipment = {"weapon":"epee_fer","armor":"armure_cuir"}
			hud5.render_inventory()
			hud5.inventory_overlay.visible = true
		elif test_mode == "test_fx":
			inst.basic_attack()
			inst.use_skill(0)
			print("TEST_RESULT fx_ran_no_error=true")
		elif test_mode == "show_talent_ui":
			var gs2 = root.get_node("/root/GameState")
			inst.char_data.level = 5
			var tier2 = gs2.pending_talent(inst.char_data)
			inst.emit_signal("talent_available", tier2)
		return false

	frame_count += 1
	if frame_count < wait_frames + 10:
		return false

	var img = root.get_texture().get_image()
	var err = img.save_png(out_path)
	print("SAVE_RESULT:%d PATH:%s" % [err, out_path])
	if test_mode != "":
		print("TEST_DONE:%s" % test_mode)
	return true

func _run_combat_test() -> void:
	print("TEST_START:combat")
	var e = inst.spawn_enemy({"x": inst.player.global_position.x + 40, "y": inst.player.global_position.y, "type_id": "slime_vert", "respawn_at": 0.0})
	print("TEST_ENEMY_SPAWNED uid=%s hp=%s maxhp=%s" % [e.uid, e.hp, e.max_hp])
	var start_xp = inst.char_data.xp
	var hits = 0
	while not e.dead and hits < 30:
		var dmg = inst.roll_damage(inst.player.stats.atk, 1.0, 0.0)
		inst.deal_damage_to_enemy(e, dmg)
		hits += 1
	print("TEST_RESULT hits=%d enemy_dead=%s hp_left=%s player_xp_before=%s player_xp_after=%s player_level=%s inventory=%s"
		% [hits, e.dead, e.hp, start_xp, inst.char_data.xp, inst.char_data.level, JSON.stringify(inst.char_data.inventory)])

func _run_quest_test() -> void:
	print("TEST_START:quest")
	var data = root.get_node("/root/Data")
	print("TEST_QUESTS_BEFORE active=%s completed=%s" % [inst.char_data.quests_active, inst.char_data.quests_completed])
	# simule l'acceptation de q_intro puis complétion en parlant au bon PNJ
	inst.char_data.quests_active["q_intro"] = 0
	inst.update_quest_progress("talk", "garde")
	print("TEST_QUESTS_AFTER_TALK active=%s" % [inst.char_data.quests_active])
	var q = data.get_quest("q_intro")
	var done = inst.char_data.quests_active.get("q_intro", 0) >= q.obj.count
	print("TEST_RESULT quest_ready_to_turn_in=%s" % [done])

func _run_bounty_test() -> void:
	print("TEST_START:bounty")
	var data = root.get_node("/root/Data")
	inst.char_data.bounty = data.random_bounty(inst.char_data.level)
	var b = inst.char_data.bounty
	print("TEST_BOUNTY_GENERATED target=%s count=%d reward_gold=%d reward_xp=%d" % [b.target, b.count, b.reward_gold, b.reward_xp])
	var gold_before = inst.char_data.gold
	for i in range(b.count):
		var e = inst.spawn_enemy({"x": inst.player.global_position.x + 40, "y": inst.player.global_position.y, "type_id": b.target, "respawn_at": 0.0})
		var tries = 0
		while not e.dead and tries < 30:
			e.take_damage(9999)
			tries += 1
		inst.grant_kill_rewards(inst.player, e, false)
	print("TEST_RESULT bounty_progress=%d/%d gold_before=%d gold_after=%d bounty_cleared=%s"
		% [inst.char_data.bounty.progress if inst.char_data.bounty else -1, b.count, gold_before, inst.char_data.gold, inst.char_data.bounty == null])

func _run_save_test() -> void:
	print("TEST_START:save")
	var gs = root.get_node("/root/GameState")
	gs.delete_save()
	inst.char_data.level = 7
	inst.char_data.gold = 555
	inst.char_data.quests_completed = ["q_intro", "q_slime1"]
	inst.char_data.inventory = {"minerai": 3, "epee_fer": 1}
	inst.player.global_position = Vector2(3333, 444)
	inst.save_now()
	print("TEST_SAVE_FILE_EXISTS=%s" % gs.has_save())
	var loaded = gs.load_saved_character()
	print("TEST_RESULT level=%d gold=%d quests=%s inv=%s last_x=%s last_y=%s hp_field=%s"
		% [loaded.get("level"), loaded.get("gold"), loaded.get("quests_completed"), JSON.stringify(loaded.get("inventory")), loaded.get("last_x"), loaded.get("last_y"), loaded.get("hp")])

func _find_button_with_text(node: Node, needle: String) -> Button:
	if node is Button and needle in node.text: return node
	for c in node.get_children():
		var r = _find_button_with_text(c, needle)
		if r: return r
	return null

func _run_continue_menu_test() -> void:
	print("TEST_START:continue_menu")
	var btn = _find_button_with_text(inst, "Continuer")
	print("TEST_CONTINUE_BUTTON_FOUND=%s text=%s" % [btn != null, btn.text if btn else ""])
	if btn:
		btn.pressed.emit()
		print("TEST_AFTER_CLICK mode_screen_shown=%s" % [_find_button_with_text(inst, "Solo") != null])
		var gs = root.get_node("/root/GameState")
		print("TEST_RESULT loaded_char_name=%s loaded_level=%s" % [gs.char_data.get("name"), gs.char_data.get("level")])

func _run_souls_test() -> void:
	print("TEST_START:souls")
	var p = inst.player
	var hp_before = p.hp
	# un slime_vert (le monstre le plus faible du jeu) doit faire mal
	var applied1 = p.take_damage(inst.get_node("/root/Data").MONSTER_TYPES.slime_vert.atk)
	print("TEST_HIT_SLIME hp_before=%.1f applied=%.1f hp_after=%.1f pct_of_maxhp=%.1f%%"
		% [hp_before, applied1, p.hp, applied1/p.stats.max_hp*100.0])
	# un boss doit faire très mal (test avec zombie_ancien, le boss le plus fort)
	p.hp = p.stats.max_hp
	var boss_atk = inst.get_node("/root/Data").MONSTER_TYPES.zombie_ancien.atk
	var applied2 = p.take_damage(boss_atk)
	print("TEST_HIT_BOSS boss_atk=%.0f applied=%.1f pct_of_maxhp=%.1f%%" % [boss_atk, applied2, applied2/p.stats.max_hp*100.0])

	# test tache de sang : mort -> perte de la moitié de l'or, marqueur créé
	inst.char_data.gold = 100
	p.hp = 1
	p.take_damage(9999.0)
	inst.on_player_died()
	print("TEST_DEATH_GOLD gold_after=%d bloodstain=%s" % [inst.char_data.gold, inst.char_data.bloodstain])
	# récupération
	var gold_before_reclaim = inst.char_data.gold
	inst.reclaim_bloodstain()
	print("TEST_RECLAIM gold_before=%d gold_after=%d bloodstain_cleared=%s" % [gold_before_reclaim, inst.char_data.gold, inst.char_data.bloodstain == null])

	# test cooldown de potion
	inst.char_data.inventory["potion_vie"] = 5
	p.hp = 10
	var hud = inst.get_node("Hud")
	hud.use_item("potion_vie")
	var hp_after_1st = p.hp
	hud.use_item("potion_vie") # doit être bloqué par le cooldown
	print("TEST_POTION_CD hp_after_1st_use=%.1f hp_after_2nd_immediate=%.1f (doit être identique) inv_left=%d"
		% [hp_after_1st, p.hp, inst.char_data.inventory.potion_vie])

func _run_respec_test() -> void:
	print("TEST_START:respec")
	var hud = inst.get_node("Hud")
	var gs = root.get_node("/root/GameState")
	inst.char_data.level = 5
	inst.char_data.talents["5"] = "berserker"
	inst.player.stats = gs.compute_stats(inst.char_data)
	var atk_with_talent = inst.player.stats.atk
	inst.char_data.gold = 200
	var gold_before = inst.char_data.gold
	hud.respec_talents(50)
	print("TEST_RESULT talents_after=%s gold_before=%d gold_after=%d atk_with_talent=%.2f atk_after_respec=%.2f pending_now=%s"
		% [inst.char_data.talents, gold_before, inst.char_data.gold, atk_with_talent, inst.player.stats.atk, gs.pending_talent(inst.char_data).get("level")])
	# vérifie qu'on ne peut pas respec sans assez d'or
	inst.char_data.gold = 10
	inst.char_data.talents["5"] = "berserker"
	var gold_locked = inst.char_data.gold
	hud.respec_talents(50)
	print("TEST_RESULT2 blocked_when_poor=%s (gold inchangé=%s)" % [inst.char_data.talents.has("5"), inst.char_data.gold == gold_locked])

func _run_race_quest_test() -> void:
	print("TEST_START:race_quests")
	var data = root.get_node("/root/Data")
	var hud = inst.get_node("Hud")
	for race in ["humain", "elfe", "nain", "orc", "ratkin", "golem"]:
		inst.char_data.race = race
		inst.char_data.quests_active = {}
		inst.char_data.quests_completed = []
		for c in hud.dialogue_box.get_children(): hud.dialogue_box.remove_child(c); c.free() # nettoyage immédiat (queue_free() est différé, fausserait le test suivant dans la même frame)
		hud.current_npc = data.get_npc("ancien")
		hud.render_npc_dialogue()
		var visible_race_quest_names = []
		for qid in ["q_race_humain","q_race_elfe","q_race_nain","q_race_orc","q_race_ratkin","q_race_golem"]:
			var q = data.get_quest(qid)
			var btn = _find_button_with_text(hud.dialogue_box, "Accepter: " + q.name)
			if btn: visible_race_quest_names.append(qid)
		print("TEST_RACE=%s hud_shows=%s" % [race, visible_race_quest_names])

func _run_travel_test() -> void:
	print("TEST_START:travel")
	var data = root.get_node("/root/Data")
	print("TEST_INITIAL unlocked=%s" % [inst.char_data.unlocked_zones])
	# simule le joueur qui se déplace dans marais (comme le ferait _physics_process en jeu réel)
	inst.player.global_position = Vector2(data.ZONES.marais.x0 + 300, data.WORLD_HEIGHT/2.0)
	var zid = data.zone_at(inst.player.global_position.x).id
	inst.death_zone_id = zid
	if not inst.char_data.unlocked_zones.has(zid): inst.char_data.unlocked_zones.append(zid)
	print("TEST_AFTER_VISIT zone=%s unlocked=%s" % [zid, inst.char_data.unlocked_zones])
	# simule une mort dans le marais -> doit réapparaître à l'entrée du marais, pas au village
	inst.player.take_damage(99999.0)
	inst.respawn_at = -1.0
	inst.handle_respawn(0.0) # 1er appel: démarre le minuteur de 3s
	# force le minuteur à être expiré pour déclencher la réapparition immédiatement
	inst.respawn_at = 0.0
	inst.handle_respawn(0.0)
	var expected = inst.get_zone_spawn("marais")
	print("TEST_RESULT respawn_pos=%s expected_marais_spawn=%s village_spawn=%s dead=%s"
		% [inst.player.global_position, expected, inst.get_zone_spawn("village"), inst.player.dead])
	# teste le voyage rapide vers le village depuis le marais
	var hud = inst.get_node("Hud")
	hud.travel_to("village")
	print("TEST_RESULT2 pos_after_travel=%s expected_village=%s" % [inst.player.global_position, inst.get_zone_spawn("village")])

func _run_boss_phase_test() -> void:
	print("TEST_START:boss_phase")
	var boss = inst.spawn_enemy({"x": inst.player.global_position.x + 50, "y": inst.player.global_position.y, "type_id": "zombie_ancien", "respawn_at": 0.0})
	var before_count = inst.enemies.size()
	print("TEST_BOSS_SPAWNED hp=%.0f max_hp=%.0f enemies_before=%d" % [boss.hp, boss.max_hp, before_count])
	# fait tomber le boss à 60% (au-dessus du 1er seuil à 66%... on vise juste sous 66%)
	boss.take_damage(boss.max_hp * 0.35)
	var after_phase1 = inst.enemies.size()
	print("TEST_AFTER_PHASE1 hp=%.0f enemies=%d (devrait avoir +3 zombies invoqués)" % [boss.hp, after_phase1])
	boss.take_damage(boss.max_hp * 0.34)
	var after_phase2 = inst.enemies.size()
	print("TEST_RESULT hp=%.0f enemies=%d (devrait avoir +2 zombies pourrissants de plus) triggered=%s"
		% [boss.hp, after_phase2, boss.triggered_phases.keys()])

func _run_death_test() -> void:
	print("TEST_START:death")
	var p = inst.player
	print("TEST_BEFORE dead=%s hp=%.1f" % [p.dead, p.hp])
	var applied = p.take_damage(99999.0)
	print("TEST_AFTER_LETHAL_HIT dead=%s hp=%.1f applied=%.1f" % [p.dead, p.hp, applied])
	# un coup supplémentaire pendant que mort ne doit rien faire (déjà géré par take_damage's early-return)
	var applied2 = p.take_damage(50.0)
	print("TEST_HIT_WHILE_DEAD applied=%.1f (doit être 0)" % applied2)
	var village_spawn = inst.get_zone_spawn("village")
	p.respawn(village_spawn)
	print("TEST_RESULT after_respawn dead=%s hp=%.1f max_hp=%.1f pos=%s expected_pos=%s"
		% [p.dead, p.hp, p.stats.max_hp, p.global_position, village_spawn])

func _run_data_integrity_test() -> void:
	print("TEST_START:data_integrity")
	var data = root.get_node("/root/Data")
	var errors = []
	var npc_ids = {}
	for n in data.NPCS: npc_ids[n.id] = true
	var quest_ids = {}
	for q in data.QUESTS: quest_ids[q.id] = true

	for q in data.QUESTS:
		if not npc_ids.has(q.giver): errors.append("quest %s: giver PNJ inconnu '%s'" % [q.id, q.giver])
		for r in q.requires:
			if not quest_ids.has(r): errors.append("quest %s: requires quête inconnue '%s'" % [q.id, r])
		var obj = q.obj
		if obj.type in ["kill","boss"]:
			var targets = obj.target if obj.target is Array else [obj.target]
			for t in targets:
				if not data.MONSTER_TYPES.has(t): errors.append("quest %s: monstre inconnu '%s'" % [q.id, t])
		elif obj.type == "gather":
			if not data.ITEMS.has(obj.target): errors.append("quest %s: item de récolte inconnu '%s'" % [q.id, obj.target])
		elif obj.type == "gather_drop":
			if not data.ITEMS.has(obj.target): errors.append("quest %s: item drop inconnu '%s'" % [q.id, obj.target])
		elif obj.type == "talk":
			if not npc_ids.has(obj.target): errors.append("quest %s: talk cible PNJ inconnu '%s'" % [q.id, obj.target])
		elif obj.type == "deliver":
			if not npc_ids.has(obj.target): errors.append("quest %s: deliver cible PNJ inconnu '%s'" % [q.id, obj.target])
			if not data.ITEMS.has(obj.item): errors.append("quest %s: deliver item inconnu '%s'" % [q.id, obj.item])
		for it in q.reward.get("items", []):
			if not data.ITEMS.has(it): errors.append("quest %s: reward item inconnu '%s'" % [q.id, it])
		var fac = data.QUEST_FACTION.get(q.id, "")
		if fac != "" and not data.FACTIONS.has(fac): errors.append("quest %s: faction inconnue '%s'" % [q.id, fac])
		if not data.QUEST_FACTION.has(q.id): errors.append("quest %s: aucune faction assignée (QUEST_FACTION)" % q.id)

	for r in data.RECIPES:
		if not data.ITEMS.has(r.result): errors.append("recipe %s: résultat inconnu '%s'" % [r.id, r.result])
		for k in r.cost.keys():
			if not data.ITEMS.has(k): errors.append("recipe %s: coût inconnu '%s'" % [r.id, k])
		if not data.PROFESSIONS.has(r.profession): errors.append("recipe %s: métier inconnu '%s'" % [r.id, r.profession])

	for n in data.GATHER_NODES:
		if not data.ITEMS.has(n.type): errors.append("gather_node type inconnu '%s'" % n.type)

	for tid in data.MONSTER_TYPES.keys():
		var m = data.MONSTER_TYPES[tid]
		if not data.ZONES.has(m.zone): errors.append("monster %s: zone inconnue '%s'" % [tid, m.zone])
		var tex_path = "res://assets/sprites/enemies/%s.png" % m.sprite
		if not FileAccess.file_exists(tex_path): errors.append("monster %s: fichier sprite manquant '%s'" % [tid, tex_path])
		for drop in m.get("loot", []):
			if not data.ITEMS.has(drop.id): errors.append("monster %s: loot inconnu '%s'" % [tid, drop.id])

	for cid in data.CLASSES.keys():
		if not data.TALENTS.has(cid): errors.append("classe %s: aucun talent défini" % cid)

	# vérifie qu'aucune quête n'est orpheline (chaîne de prérequis atteignable depuis une quête de départ)
	var reachable = {}
	var changed = true
	for q in data.QUESTS:
		if q.requires.is_empty(): reachable[q.id] = true
	while changed:
		changed = false
		for q in data.QUESTS:
			if reachable.has(q.id): continue
			var ok = true
			for r in q.requires:
				if not reachable.has(r): ok = false; break
			if ok: reachable[q.id] = true; changed = true
	for q in data.QUESTS:
		if not reachable.has(q.id): errors.append("quest %s: INATTEIGNABLE (dépendance circulaire ou cassée)" % q.id)

	print("TEST_RESULT total_quests=%d total_errors=%d" % [data.QUESTS.size(), errors.size()])
	for e in errors:
		print("  ERROR: " + e)
	print("TEST_DONE:data_integrity")

func _run_skills_test() -> void:
	print("TEST_START:skills")
	var e = inst.spawn_enemy({"x": inst.player.global_position.x + 30, "y": inst.player.global_position.y, "type_id": "slime_rouge", "respawn_at": 0.0})
	var mana_before = inst.player.mana
	var atk_before = inst.player.stats.atk
	var def_before = inst.player.stats.def
	inst.use_skill(0) # Coup Puissant (dmg)
	print("TEST_SKILL0 mana_before=%.1f mana_after=%.1f enemy_hp=%.1f/%.1f cooldown_set=%s"
		% [mana_before, inst.player.mana, e.hp, e.max_hp, inst.player.cooldowns.has("skill0")])
	inst.player.mana = inst.player.stats.max_mana # assure assez de mana pour tester le buff isolément
	inst.use_skill(1) # Cri de Guerre (buff)
	print("TEST_SKILL1 atk_before=%.2f atk_after=%.2f def_before=%.2f def_after=%.2f mana_after=%.1f"
		% [atk_before, inst.player.stats.atk, def_before, inst.player.stats.def, inst.player.mana])
	# re-tente immédiatement : doit être bloqué par le cooldown (aucun changement de mana)
	var mana_before_cd = inst.player.mana
	inst.use_skill(0)
	print("TEST_COOLDOWN_BLOCKS_REUSE mana_unchanged=%s" % [inst.player.mana == mana_before_cd])

func _run_reputation_test() -> void:
	print("TEST_START:reputation")
	var hud = inst.get_node("Hud")
	var cd = inst.char_data
	cd.quests_active["q_intro"] = 1 # obj count for q_intro is 1 (talk)
	hud.turn_in_quest("q_intro")
	var rep = cd.reputation.get("garde", 0)
	print("TEST_RESULT rep_after_q_intro=%d quests_completed=%s gold=%d" % [rep, cd.quests_completed, cd.gold])
	# teste l'achat d'un objet de faction avant/après avoir le rang requis
	cd.gold = 200
	var before_buy = cd.inventory.get("cape_heros", 0)
	hud.buy_faction_item("cape_heros")
	var after_buy_locked = cd.inventory.get("cape_heros", 0)
	cd.reputation["garde"] = 300
	hud.buy_faction_item("cape_heros")
	var after_buy_unlocked = cd.inventory.get("cape_heros", 0)
	print("TEST_RESULT buy_locked=%d buy_unlocked=%d gold_after=%d" % [after_buy_locked, after_buy_unlocked, cd.gold])

func _run_talent_test() -> void:
	print("TEST_START:talent")
	var gs = root.get_node("/root/GameState")
	var data = root.get_node("/root/Data")
	var atk_before = inst.player.stats.atk
	inst.char_data.level = 5
	inst.player.stats = gs.compute_stats(inst.char_data)
	var tier = gs.pending_talent(inst.char_data)
	print("TEST_TIER level=%s options=%s" % [tier.get("level"), tier.options.map(func(o): return o.id)])
	var chosen = tier.options[0]
	inst.char_data.talents[str(tier.level)] = chosen.id
	inst.player.stats = gs.compute_stats(inst.char_data)
	var atk_after = inst.player.stats.atk
	var still_pending = gs.pending_talent(inst.char_data)
	print("TEST_RESULT chosen=%s atk_before=%.2f atk_after=%.2f still_pending=%s"
		% [chosen.id, atk_before, atk_after, still_pending.get("level")])
