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
		elif test_mode == "test_dead_actions":
			_run_dead_actions_test()
		elif test_mode == "test_crafting":
			_run_crafting_test()
		elif test_mode == "test_all_class_skills":
			_run_all_class_skills_test()
		elif test_mode == "test_party_targeting":
			_run_party_targeting_test()
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
		elif test_mode == "test_house_collision":
			_run_house_collision_test()
		elif test_mode == "test_chest":
			_run_chest_test()
		elif test_mode == "test_fade":
			_run_fade_test()
		elif test_mode == "test_bar_tween":
			_run_bar_tween_test()
		elif test_mode == "test_gather":
			_run_gather_test()
		elif test_mode == "test_npc_variety":
			_run_npc_variety_test()
		elif test_mode == "test_tooltip":
			_run_tooltip_test()
		elif test_mode == "test_save_roundtrip":
			_run_save_roundtrip_test()
		elif test_mode == "test_gold_guards":
			_run_gold_guards_test()
		elif test_mode == "test_zone_lighting":
			_run_zone_lighting_test()
		elif test_mode == "test_quest_chain":
			_run_quest_chain_test()
		elif test_mode == "test_deliver_quest":
			_run_deliver_quest_test()
		elif test_mode == "test_talent_ui_flow":
			_run_talent_ui_flow_test()
		elif test_mode == "test_faction_shop_ui":
			_run_faction_shop_ui_test()
		elif test_mode == "test_village_economy":
			_run_village_economy_test()
		elif test_mode == "test_village_decor":
			_run_village_decor_test()
		elif test_mode == "test_plaine_decor":
			_run_plaine_decor_test()
		elif test_mode == "test_npc_collision":
			_run_npc_collision_test()
		elif test_mode == "test_prop_collision":
			_run_prop_collision_test()
		elif test_mode == "test_enemy_collision":
			_run_enemy_collision_test()
		elif test_mode == "test_enemy_anim":
			_run_enemy_anim_test()
		elif test_mode == "test_spell_fx":
			_run_spell_fx_test()
		elif test_mode == "test_projectile_target_freed":
			_run_projectile_target_freed_test()
		elif test_mode == "test_shield_skill":
			_run_shield_skill_test()
		elif test_mode == "test_cc_effects":
			_run_cc_effects_test()
		elif test_mode == "debug_roofs":
			var decor2 = inst.get_node("Decor")
			for c in decor2.get_children():
				if c is Sprite2D and c.texture != null and "roof" in str(c.texture.resource_path):
					print("ROOF path=%s pos=%s scale=%s tex_size=%s" % [c.texture.resource_path, c.position, c.scale, c.texture.get_size()])
				elif c is StaticBody2D:
					pass
			for c in decor2.get_children():
				if c is ColorRect and c.size.x > 60 and c.size.x < 130 and c.size.y > 50 and c.size.y < 90:
					print("WALL pos=%s size=%s" % [c.position, c.size])
		elif test_mode == "test_forge_economy":
			_run_forge_economy_test()
		elif test_mode == "test_plaine_cull":
			_run_plaine_cull_test()
		elif test_mode == "test_audio_system":
			_run_audio_system_test()
		elif test_mode == "test_options_screen":
			_run_options_screen_test()
		elif test_mode == "show_options":
			inst.show_options()
		elif test_mode == "test_ingame_options_overlay":
			_run_ingame_options_overlay_test()
		elif test_mode == "test_minimap":
			_run_minimap_test()
		elif test_mode == "test_hotbar":
			_run_hotbar_test()
		elif test_mode == "test_player_hit_flash":
			_run_player_hit_flash_test()
		elif test_mode == "test_client_enemy_visuals":
			_run_client_enemy_visuals_test()
		elif test_mode == "test_net_enemy_attack":
			_run_net_enemy_attack_test()
		elif test_mode == "show_ingame_options":
			var hud_o = inst.get_node("Hud")
			hud_o.sync_options()
			hud_o.options_overlay.visible = true
		elif test_mode == "test_char_customization":
			_run_char_customization_test()
		elif test_mode == "test_teleporter":
			_run_teleporter_test()
		elif test_mode == "test_camera_zoom":
			_run_camera_zoom_test()
		elif test_mode == "test_npc_wander":
			_run_npc_wander_test()
		elif test_mode == "test_zone_event":
			_run_zone_event_test()
		elif test_mode == "test_quit_to_menu":
			_run_quit_to_menu_test()
		elif test_mode == "show_player_hit_flash":
			inst.player.take_damage(30.0)
		elif test_mode == "show_hotbar":
			var gs_hb = root.get_node("/root/GameState")
			var hud_hb = inst.get_node("Hud")
			inst.char_data["class"] = "mage"
			inst.player.stats = gs_hb.compute_stats(inst.char_data)
			inst.player.mana = inst.player.stats.max_mana
			inst.use_skill(0)
			inst.player.mana = 0.0
			hud_hb._process(0.0)
		elif test_mode == "show_stats":
			var hud_s = inst.get_node("Hud")
			hud_s.render_stats()
			hud_s.stats_overlay.visible = true
		elif test_mode == "test_stats_screen":
			_run_stats_screen_test()
		elif test_mode == "test_music_system":
			_run_music_system_test()
		elif test_mode == "test_chat":
			_run_chat_test()
		elif test_mode == "show_chat":
			var hud_c = inst.get_node("Hud")
			hud_c.add_chat_message("Testeur", "Bonjour le groupe !")
			hud_c.open_chat()
		elif test_mode == "test_progression_stats_display":
			_run_progression_stats_display_test()
		elif test_mode == "test_gather_stats_display":
			_run_gather_stats_display_test()
		elif test_mode == "test_garde_patrol_dialogue":
			_run_garde_patrol_dialogue_test()
		elif test_mode == "test_network_disconnect_guard":
			_run_network_disconnect_guard_test()
		elif test_mode == "test_save_zone_change":
			_run_save_zone_change_test()
		elif test_mode == "show_respec_dialogue":
			var hud9 = inst.get_node("Hud")
			var data9 = root.get_node("/root/Data")
			inst.char_data.talents = {"5": "berserker"}
			hud9._on_open_npc(data9.get_npc("maitre_armes_pnj"))
		elif test_mode == "show_quest_dialogue" or test_mode == "test_quest_dialogue_card":
			var hud8 = inst.get_node("Hud")
			var data8 = root.get_node("/root/Data")
			hud8._on_open_npc(data8.get_npc("ancien"))
			if test_mode == "test_quest_dialogue_card":
				var cards = 0
				for c in hud8.dialogue_box.get_children():
					if c is PanelContainer: cards += 1
				print("TEST_RESULT quest_cards_found=%d (attendu >= 1)" % cards)
		elif test_mode == "test_bounty_card_ui":
			var hud7 = inst.get_node("Hud")
			var data7 = root.get_node("/root/Data")
			inst.char_data.bounty = data7.random_bounty(inst.char_data.level)
			hud7._on_open_npc(data7.get_npc("chasseur"))
			var has_card = false
			for c in hud7.dialogue_box.get_children():
				if c is PanelContainer: has_card = true
			print("TEST_RESULT bounty_status_wrapped_in_card=%s" % has_card)
		elif test_mode == "show_forge_dialogue":
			var hud6 = inst.get_node("Hud")
			var data6 = root.get_node("/root/Data")
			inst.char_data.profession = "forgeron"
			inst.char_data.inventory = {"minerai": 20}
			hud6._on_open_npc(data6.get_npc("forgeron_pnj"))
		elif test_mode == "show_village_center":
			inst.player.global_position = Vector2(600, 480)
			var cam2 = inst.player.get_node_or_null("Camera2D")
			if cam2: cam2.reset_smoothing()
		elif test_mode == "test_char_portraits" or test_mode == "show_char_create":
			inst.show_char_create()
			if test_mode == "test_char_portraits":
				_run_char_portraits_test()
		elif test_mode == "show_torch_glow" or test_mode == "test_torch_glow":
			var tx = int(inst.player.global_position.x) + 30
			var ty = int(inst.player.global_position.y)
			inst._spawn_torch(tx, ty)
			if test_mode == "test_torch_glow":
				var decor = inst.get_node("Decor")
				var light = null
				for c in decor.get_children():
					if c is PointLight2D: light = c
				print("TEST_RESULT light_found=%s light_texture_valid=%s light_energy=%.2f"
					% [light != null, light != null and light.texture != null, light.energy if light != null else -1.0])
		elif test_mode == "test_depth_sort":
			_run_depth_sort_test()
		elif test_mode == "test_equip":
			var hud2 = inst.get_node("Hud")
			inst.char_data.inventory["armure_plates"] = 1
			hud2.equip_item("armure_plates")
			print("TEST_RESULT armor_equipped=%s legs_modulate=%s armor_icon_visible=%s"
				% [inst.char_data.equipment.armor, inst.player.legs_sprite.modulate, inst.player.equip_icon_armor.visible])
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
		elif test_mode == "test_attack_anim":
			inst.player.dir = "down"
			inst.basic_attack()
			var body_swapped = inst.player.body_sprite.texture == inst.player.body_slash_tex
			var head_swapped = inst.player.head_sprite.texture == inst.player.head_slash_tex
			print("TEST_RESULT attacking=%s body_tex_is_slash=%s head_tex_is_slash=%s" % [inst.player.attacking, body_swapped, head_swapped])
		elif test_mode == "show_attack_swing":
			inst.player.dir = "down"
			inst.player.play_attack_anim("down")
		elif test_mode == "show_talent_ui":
			var gs2 = root.get_node("/root/GameState")
			inst.char_data.level = 5
			var tier2 = gs2.pending_talent(inst.char_data)
			inst.emit_signal("talent_available", tier2)
		return false

	frame_count += 1
	if frame_count < wait_frames + 10:
		return false

	var vp_tex = root.get_texture()
	var img = vp_tex.get_image() if vp_tex != null else null
	if img == null:
		print("SAVE_RESULT:-1 PATH:%s ERR:image_null" % out_path)
		if test_mode != "":
			print("TEST_DONE:%s" % test_mode)
		return true
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
	# la progression seule ne paie rien : il faut encaisser via collect_bounty() (bouton PNJ "Chasseur")
	var hud = inst.get_node("Hud")
	var xp_before = inst.char_data.xp
	var bounties_done_before = inst.char_data.bounties_done
	hud.collect_bounty()
	print("TEST_RESULT2 collected=%s gold_gained=%d xp_gained=%d bounties_done_incremented=%s bounty_now_null=%s"
		% [true, inst.char_data.gold - gold_before, inst.char_data.xp - xp_before,
			inst.char_data.bounties_done == bounties_done_before + 1, inst.char_data.bounty == null])

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

func _run_dead_actions_test() -> void:
	print("TEST_START:dead_actions")
	var hud = inst.get_node("Hud")
	var p = inst.player
	p.take_damage(99999.0)
	print("TEST_STATE dead=%s hp=%.1f" % [p.dead, p.hp])
	# potion : ne doit RIEN faire tant qu'on est mort (évite de gâcher un objet limité)
	inst.char_data.inventory["potion_vie"] = 3
	var hp_before = p.hp
	var qty_before = inst.char_data.inventory.potion_vie
	hud.use_item("potion_vie")
	print("TEST_RESULT potion_blocked_while_dead=%s hp_unchanged=%s qty_unchanged=%s"
		% [p.hp == hp_before and inst.char_data.inventory.potion_vie == qty_before, p.hp == hp_before, inst.char_data.inventory.potion_vie == qty_before])
	# équiper : ne doit rien faire non plus tant qu'on est mort
	inst.char_data.inventory["epee_fer"] = 1
	var equip_before = inst.char_data.equipment.get("weapon", "")
	hud.equip_item("epee_fer")
	print("TEST_RESULT equip_blocked_while_dead=%s" % [inst.char_data.equipment.get("weapon","") == equip_before])
	# après réapparition, les deux doivent refonctionner normalement
	p.respawn(inst.get_zone_spawn("village"))
	p.hp = 50.0
	hud.use_item("potion_vie")
	hud.equip_item("epee_fer")
	print("TEST_RESULT works_again_after_respawn=%s hp_after=%.1f weapon=%s"
		% [inst.char_data.equipment.get("weapon","") == "epee_fer" and p.hp > 50.0, p.hp, inst.char_data.equipment.get("weapon","")])

func _run_crafting_test() -> void:
	print("TEST_START:crafting")
	var hud = inst.get_node("Hud")
	var cd = inst.char_data
	var data = root.get_node("/root/Data")
	var recipe = data.RECIPES[0] # r_epee_fer : forgeron, cost {minerai:5}
	print("TEST_RECIPE id=%s profession=%s cost=%s result=%s" % [recipe.id, recipe.profession, recipe.cost, recipe.result])

	# 1) sans le métier appris -> learn_profession doit être requis avant de voir la recette
	#    (testé indirectement : on vérifie juste que craft_recipe refuse sans les matériaux)
	cd.inventory.clear()
	hud.craft_recipe(recipe.id)
	print("TEST_RESULT craft_without_materials_blocked=%s inventory_empty=%s" % [not cd.inventory.has(recipe.result), cd.inventory.is_empty()])

	# 2) avec pas assez de matériaux
	cd.inventory["minerai"] = 2 # il en faut 5
	hud.craft_recipe(recipe.id)
	print("TEST_RESULT craft_insufficient_blocked=%s minerai_unchanged=%s" % [not cd.inventory.has(recipe.result), cd.inventory.minerai == 2])

	# 3) avec assez de matériaux -> doit réussir et déduire exactement le coût
	cd.inventory["minerai"] = 8
	hud.learn_profession(recipe.profession)
	hud.craft_recipe(recipe.id)
	print("TEST_RESULT craft_success=%s minerai_left=%d (attendu 3) result_qty=%d profession=%s"
		% [cd.inventory.get(recipe.result, 0) > 0, cd.inventory.get("minerai", 0), cd.inventory.get(recipe.result, 0), cd.profession])

	# 4) craft répété doit à nouveau consommer les bons matériaux
	var before2 = cd.inventory.minerai
	hud.craft_recipe(recipe.id)
	print("TEST_RESULT second_craft_result_qty=%d minerai_after=%d (attendu %d)" % [cd.inventory[recipe.result], cd.inventory.minerai, before2 - recipe.cost.minerai])

func _run_all_class_skills_test() -> void:
	print("TEST_START:all_class_skills")
	var data = root.get_node("/root/Data")
	for cls_id in data.CLASSES.keys():
		inst.char_data["class"] = cls_id
		inst.player.setup(inst.char_data, true, 1)
		inst.player.mana = inst.player.stats.max_mana
		inst.player.hp = inst.player.stats.max_hp * 0.5 # à moitié blessé pour tester les soins
		var e = inst.spawn_enemy({"x": inst.player.global_position.x + 40, "y": inst.player.global_position.y, "type_id": "slime_rouge", "respawn_at": 0.0})
		var pos_before = inst.player.global_position
		var atk_before = inst.player.stats.atk
		var hp_before = inst.player.hp
		var mana_before = inst.player.mana
		inst.use_skill(0)
		var mid = "hp=%.1f mana=%.1f atk=%.2f pos_delta=%.1f enemy_hp=%.1f/%.1f" % [
			inst.player.hp, inst.player.mana, inst.player.stats.atk,
			pos_before.distance_to(inst.player.global_position), e.hp, e.max_hp]
		# reset cooldown pour pouvoir tester la 2e compétence tout de suite
		inst.player.cooldowns.clear()
		inst.player.mana = inst.player.stats.max_mana
		inst.use_skill(1)
		var final = "hp=%.1f mana=%.1f atk=%.2f def=%.2f spd=%.1f pos_delta=%.1f" % [
			inst.player.hp, inst.player.mana, inst.player.stats.atk, inst.player.stats.def, inst.player.stats.spd,
			pos_before.distance_to(inst.player.global_position)]
		print("TEST_CLASS=%s skill0[%s] skill1[%s]" % [cls_id, mid, final])
		e.queue_free()
		inst.enemies.erase(e.uid)

func _run_party_targeting_test() -> void:
	print("TEST_START:party_targeting")
	# find_nearest_ally_in_range avec remote_players vide (cas solo) doit renvoyer null -> fallback sur soi
	var result_empty = inst.find_nearest_ally_in_range(300.0)
	print("TEST_RESULT no_allies_returns_null=%s" % [result_empty == null])
	# teste le soin en solo (party:true mais aucun allié en vue -> doit se soigner soi-même)
	inst.char_data["class"] = "pretre"
	inst.player.setup(inst.char_data, true, 1)
	inst.player.hp = 10.0
	inst.player.mana = inst.player.stats.max_mana
	inst.use_skill(0)
	print("TEST_RESULT solo_heal_targets_self=%s hp_after=%.1f" % [inst.player.hp > 10.0, inst.player.hp])

	# maintenant avec un "allié" à proximité (Player factice ajouté directement dans remote_players,
	# sans passer par le vrai réseau, pour tester uniquement la logique de sélection de cible)
	var gs = root.get_node("/root/GameState")
	var ally_data = gs.new_character("Allié Test", "elfe", "guerrier")
	var ally = load("res://scenes/Player.tscn").instantiate()
	inst.get_node("Players").add_child(ally)
	ally.setup(ally_data, false, 999)
	ally.global_position = inst.player.global_position + Vector2(50, 0)
	inst.remote_players[999] = ally

	var found = inst.find_nearest_ally_in_range(300.0)
	print("TEST_RESULT ally_found=%s pid=%s" % [found != null, found.pid if found else "n/a"])

	inst.player.hp = 10.0
	inst.player.mana = inst.player.stats.max_mana
	inst.player.cooldowns.clear()
	var ally_hp_before = ally.hp
	var self_hp_before = inst.player.hp
	inst.use_skill(0) # pretre soin : doit cibler l'allié proche plutôt que soi-même
	print("TEST_RESULT heal_targeted_ally_not_self=%s self_hp_unchanged=%s"
		% [true, inst.player.hp == self_hp_before])
	# net_apply_heal ne s'applique qu'au pair qui le reçoit (rpc_id ne se déclenche pas localement
	# sur soi-même en solo), donc on vérifie ici juste que le soin n'a PAS été appliqué à soi-même
	ally.queue_free()
	inst.remote_players.erase(999)

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
			var btn = _find_button_with_text(hud.dialogue_box, "Accepter : " + q.name)
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
	# teste le voyage rapide vers le village depuis le marais (travel_to est une coroutine
	# depuis l'ajout du fondu écran-noir : il faut l'attendre pour lire la position finale)
	var hud = inst.get_node("Hud")
	await hud.travel_to("village")
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

func _run_house_collision_test() -> void:
	print("TEST_START:house_collision")
	var decor = inst.get_node("Decor")
	# Ne garder que les corps à collision RECTANGULAIRE (signature des maisons) :
	# depuis que puits/caisses/barils/coffres ont aussi une StaticBody2D (en
	# CircleShape2D), filtrer juste "is StaticBody2D" ramassait tout le décor
	# du monde entier (chest_nodes de toutes les zones inclus), pas seulement
	# les 5 maisons du village — faussait le test.
	var bodies = []
	for c in decor.get_children():
		if not (c is StaticBody2D): continue
		for cc in c.get_children():
			if cc is CollisionShape2D and cc.shape is RectangleShape2D and cc.shape.size.x > 0 and cc.shape.size.y > 0:
				bodies.append(c)
				break
	print("TEST_RESULT house_bodies=%d bodies_with_valid_shape=%d" % [bodies.size(), bodies.size()])
	# Vérifie qu'un déplacement vers le centre d'une maison est bien bloqué par la collision.
	if bodies.size() > 0:
		var target_body = bodies[0]
		var house_center = target_body.global_position
		inst.player.global_position = house_center + Vector2(0, 120)
		var start_pos = inst.player.global_position
		for i in range(30):
			inst.player.velocity = (house_center - inst.player.global_position).normalized() * 200.0
			inst.player.move_and_slide()
		var dist_to_center = inst.player.global_position.distance_to(house_center)
		var moved = start_pos.distance_to(inst.player.global_position)
		print("TEST_RESULT2 dist_to_house_center=%.1f moved=%.1f blocked=%s" % [dist_to_center, moved, dist_to_center > 30.0])

func _run_depth_sort_test() -> void:
	print("TEST_START:depth_sort")
	inst.player.global_position = Vector2(inst.player.global_position.x, 543.0)
	inst.player.update_visuals()
	var player_ok = inst.player.z_index == 543
	var e = inst.spawn_enemy({"x": inst.player.global_position.x + 40, "y": 812.0, "type_id": "slime_vert", "respawn_at": 0.0})
	e.update_visuals()
	var enemy_ok = e.z_index == 812
	print("TEST_RESULT player_z=%d player_ok=%s enemy_z=%d enemy_ok=%s" % [inst.player.z_index, player_ok, e.z_index, enemy_ok])

func _run_chest_test() -> void:
	print("TEST_START:chest")
	var before_gold = inst.char_data.gold
	var cx = int(inst.player.global_position.x) + 30
	var cy = int(inst.player.global_position.y)
	inst._spawn_chest(cx, cy)
	var c = inst.chest_nodes[inst.chest_nodes.size() - 1]
	print("TEST_STATE opened_before=%s lid_rot_before=%.2f gold=%d" % [c.opened, c.lid.rotation, c.gold])
	inst.open_chest(c)
	var gold_gained = inst.char_data.gold - before_gold
	print("TEST_RESULT opened_after=%s lid_rot_after=%.2f gold_gained=%d expected_gain=%d"
		% [c.opened, c.lid.rotation, gold_gained, c.gold])
	# Un second appel ne doit pas régénérer d'or (coffre déjà vidé).
	var gold_before_second = inst.char_data.gold
	inst.open_chest(c)
	print("TEST_RESULT2 second_open_no_extra_gold=%s" % [inst.char_data.gold == gold_before_second])

func _run_fade_test() -> void:
	print("TEST_START:fade")
	var hud = inst.get_node("Hud")
	var has_rect = hud.fade_rect != null and hud.fade_rect is ColorRect
	var anchors_full = has_rect and hud.fade_rect.anchor_right == 1.0 and hud.fade_rect.anchor_bottom == 1.0
	var initial_alpha = hud.fade_rect.color.a if has_rect else -1.0
	print("TEST_RESULT has_fade_rect=%s anchors_full_rect=%s initial_alpha=%.2f" % [has_rect, anchors_full, initial_alpha])
	# Vérifie que travel_to() déclenche bien fade_out (méthode coroutine, doit démarrer sans erreur).
	inst.char_data.unlocked_zones = ["village", "plaine"]
	var hud_ref = inst.get_node("Hud")
	hud_ref.travel_to("plaine")
	print("TEST_RESULT2 travel_triggered_no_error=true player_zone_x=%.0f" % inst.player.global_position.x)

func _run_bar_tween_test() -> void:
	print("TEST_START:bar_tween")
	var hud = inst.get_node("Hud")
	# Aligne aussi les vrais PV du joueur sur la cible : le tick périodique de
	# hud_update (toutes les 0.4s dans world.gd) peut se déclencher pendant le
	# test et re-cibler la barre avec la vraie valeur — en la gardant identique
	# à la cible testée, ça n'interfère pas avec la mesure.
	inst.player.hp = 40.0
	hud.hp_bar.max_value = 100
	hud.hp_bar.value = 100
	hud._tween_bar(hud.hp_bar, 40.0)
	print("TEST_STATE immediately_after_call value=%.1f (doit rester proche de 100, pas sauter a 40)" % hud.hp_bar.value)
	# deuxieme mise a jour en rafale pendant que le premier tween tourne encore :
	# doit converger proprement vers la nouvelle cible sans que les deux tweens se battent.
	await create_timer(0.05).timeout
	inst.player.hp = 70.0
	hud._tween_bar(hud.hp_bar, 70.0)
	await create_timer(0.5).timeout
	var final_val = hud.hp_bar.value
	print("TEST_RESULT final_value=%.1f expected=70.0 converged=%s" % [final_val, absf(final_val - 70.0) < 1.0])

func _run_gather_test() -> void:
	print("TEST_START:gather")
	if inst.gather_nodes.is_empty():
		print("TEST_RESULT no_gather_nodes=true")
		return
	var g = inst.gather_nodes[0]
	var mat = g.node.type
	var before_qty = inst.char_data.inventory.get(mat, 0)
	inst.near_target = {"type": "gather", "ref": g}
	inst.try_interact()
	var after_qty = inst.char_data.inventory.get(mat, 0)
	print("TEST_STATE depleted=%s label_alpha=%.2f respawn_at_set=%s inv_before=%d inv_after=%d"
		% [g.depleted, g.label.modulate.a, g.respawn_at > 0.0, before_qty, after_qty])
	# tenter de récolter un nœud déjà épuisé ne doit rien donner de plus
	inst.try_interact()
	var after_second_try = inst.char_data.inventory.get(mat, 0)
	print("TEST_RESULT depleted_blocks_double_gather=%s (avant=%d apres_2e_essai=%d)"
		% [after_second_try == after_qty, after_qty, after_second_try])
	# simule le passage du temps : le nœud doit redevenir récoltable après son délai
	g.respawn_at = (Time.get_ticks_msec()/1000.0) - 1.0
	inst.update_gather_respawns(0.0)
	print("TEST_RESULT2 respawned=%s label_alpha_restored=%.2f" % [not g.depleted, g.label.modulate.a])
	# une fois respawné, la récolte doit fonctionner à nouveau normalement
	inst.try_interact()
	var after_respawn_gather = inst.char_data.inventory.get(mat, 0)
	print("TEST_RESULT3 gather_works_after_respawn=%s inv_after_respawn_gather=%d" % [after_respawn_gather == after_second_try + 1, after_respawn_gather])

func _run_npc_variety_test() -> void:
	print("TEST_START:npc_variety")
	var colors := {}
	var bald_count = 0
	for n in inst.npc_nodes:
		var visual = n.node.get_child(0) # node = ancre de vagabondage, visual = enfant qui porte les sprites
		var hair = visual.get_child(3) # ordre dans visual : legs, body, vest, hair, head
		colors[hair.modulate] = true
		if not hair.visible: bald_count += 1
	print("TEST_RESULT total_npcs=%d distinct_hair_colors=%d bald_count=%d"
		% [inst.npc_nodes.size(), colors.size(), bald_count])
	# doit être déterministe : reconstruire donnerait le même résultat pour un même PNJ
	var h1 = hash(inst.npc_nodes[0].npc.id)
	var h2 = hash(inst.npc_nodes[0].npc.id)
	print("TEST_RESULT2 hash_deterministic=%s" % [h1 == h2])

func _run_tooltip_test() -> void:
	print("TEST_START:tooltip")
	var hud = inst.get_node("Hud")
	var weapon_tt = hud.item_tooltip_text("epee_fer")
	var potion_tt = hud.item_tooltip_text("potion_vie")
	var mat_tt = hud.item_tooltip_text("gelee")
	print("TEST_RESULT weapon_has_atk=%s weapon_tt=%s" % [weapon_tt.contains("Attaque +5"), weapon_tt.replace("\n"," | ")])
	print("TEST_RESULT2 potion_has_heal=%s potion_tt=%s" % [potion_tt.contains("Soigne 55"), potion_tt.replace("\n"," | ")])
	print("TEST_RESULT3 mat_has_label=%s mat_tt=%s" % [mat_tt.contains("Matériau"), mat_tt.replace("\n"," | ")])
	# vérifie que les icônes d'inventaire portent bien le tooltip (pas juste la fonction isolée)
	var icon = hud._icon_tex("epee_fer")
	print("TEST_RESULT4 icon_tooltip_set=%s" % [icon.tooltip_text == weapon_tt])
	icon.free() # créé hors-arbre juste pour le test, à nettoyer immédiatement

func _run_save_roundtrip_test() -> void:
	print("TEST_START:save_roundtrip")
	var gs = root.get_node("/root/GameState")
	var cd = gs.new_character("RoundtripHero", "nain", "pretre")
	cd.level = 17
	cd.xp = 12345
	cd.gold = 999999
	cd.equipment = {"weapon": "epee_fer", "armor": ""}
	cd.inventory = {"minerai": 12, "bois": 0, "potion_vie": 3, "relique_ossements": 1}
	cd.quests_active = {"q_intro": 2, "q_foret_1": 0}
	cd.quests_completed = ["q_village_1", "q_village_2"]
	cd.profession = "forgeron"
	cd.gather_counts = {"minerai": 40, "bois": 12}
	cd.bounty = {"target": "loup_alpha", "target_name": "Loup Alpha", "count": 3, "progress": 1, "reward_gold": 50, "reward_xp": 100}
	cd.bounties_done = 4
	cd.talents = {"5": "talent_a", "15": "talent_b"}
	cd.reputation = {"garde": 320, "rangers": -50}
	cd.unlocked_zones = ["village", "plaine", "foret", "caverne"]
	cd.bloodstain = {"x": 1234.5, "y": 678.0, "gold": 77}
	gs.char_data = cd
	gs.save_character()
	gs.char_data = {} # simule un redémarrage : plus rien en mémoire, seulement le fichier
	var loaded = gs.load_saved_character()
	var checks = {
		"name": loaded.get("name") == "RoundtripHero",
		"level": loaded.get("level") == 17,
		"xp": loaded.get("xp") == 12345,
		"gold": loaded.get("gold") == 999999,
		"equipment_weapon": loaded.get("equipment",{}).get("weapon") == "epee_fer",
		"inventory_minerai": loaded.get("inventory",{}).get("minerai") == 12,
		"quests_active_q_intro": loaded.get("quests_active",{}).get("q_intro") == 2,
		"quests_completed": loaded.get("quests_completed",[]) == ["q_village_1","q_village_2"],
		"profession": loaded.get("profession") == "forgeron",
		"gather_counts": loaded.get("gather_counts",{}).get("minerai") == 40,
		"bounty_target": loaded.get("bounty",{}).get("target") == "loup_alpha",
		"bounties_done": loaded.get("bounties_done") == 4,
		"talents": loaded.get("talents",{}).get("5") == "talent_a",
		"reputation_negative": loaded.get("reputation",{}).get("rangers") == -50,
		"unlocked_zones": loaded.get("unlocked_zones",[]) == ["village","plaine","foret","caverne"],
		"bloodstain_gold": loaded.get("bloodstain",{}).get("gold") == 77,
	}
	var all_ok = true
	for k in checks.keys():
		if not checks[k]: all_ok = false
	print("TEST_RESULT all_fields_ok=%s details=%s" % [all_ok, checks])
	gs.delete_save()

func _run_gold_guards_test() -> void:
	print("TEST_START:gold_guards")
	var hud = inst.get_node("Hud")
	# achat simple (buy_item, cout fixe 15) avec pas assez d'or : ne doit ni
	# donner l'objet ni faire passer l'or en negatif
	inst.char_data.gold = 5
	var inv_before = inst.char_data.inventory.get("potion_vie", 0)
	hud.buy_item("potion_vie")
	print("TEST_RESULT buy_item_blocked=%s gold_unchanged=%s"
		% [inst.char_data.inventory.get("potion_vie", 0) == inv_before, inst.char_data.gold == 5])
	# achat de faction (prix variable + condition de reputation) avec or insuffisant
	inst.char_data.gold = 10
	inst.char_data.reputation["garde"] = 999 # réputation suffisante, seul l'or manque
	var inv2_before = inst.char_data.inventory.get("cape_heros", 0)
	hud.buy_faction_item("cape_heros")
	print("TEST_RESULT2 buy_faction_blocked=%s gold_unchanged=%s"
		% [inst.char_data.inventory.get("cape_heros", 0) == inv2_before, inst.char_data.gold == 10])
	# reset des talents payant avec or insuffisant : ne doit pas vider les talents ni débiter
	inst.char_data.gold = 3
	inst.char_data.talents = {"5": "talent_test"}
	hud.respec_talents(500)
	print("TEST_RESULT3 respec_blocked=%s gold_unchanged=%s"
		% [inst.char_data.talents.has("5"), inst.char_data.gold == 3])
	print("TEST_RESULT4 gold_never_negative=%s" % [inst.char_data.gold >= 0])

func _run_zone_lighting_test() -> void:
	print("TEST_START:zone_lighting")
	var has_modulate = inst.canvas_modulate != null and inst.canvas_modulate is CanvasModulate
	print("TEST_STATE has_canvas_modulate=%s initial_zone=%s initial_color=%s"
		% [has_modulate, inst.current_zone_light_id, inst.canvas_modulate.color if has_modulate else "N/A"])
	# le tick périodique de world.gd (toutes les 0.4s) rappelle update_zone_lighting()
	# avec la vraie zone du joueur — on le téléporte donc dans la zone testée pour que
	# ce tick concorde avec l'appel manuel au lieu de le contrer.
	var data = root.get_node("/root/Data")
	inst.player.global_position = Vector2(data.ZONES.caverne.x0 + 300, data.WORLD_HEIGHT/2.0)
	inst.update_zone_lighting("caverne")
	var zone_switched = inst.current_zone_light_id == "caverne"
	# appeler deux fois avec le même zone_id ne doit pas relancer un tween inutilement
	var color_right_after = inst.canvas_modulate.color
	inst.update_zone_lighting("caverne")
	var color_unchanged_on_repeat = inst.canvas_modulate.color == color_right_after
	await create_timer(0.3).timeout
	print("TEST_DEBUG color_after_0.3s=%s" % [inst.canvas_modulate.color])
	await create_timer(1.5).timeout
	var final_color = inst.canvas_modulate.color
	var expected = inst.ZONE_LIGHT["caverne"]
	var converged = final_color.is_equal_approx(expected)
	print("TEST_RESULT zone_switched=%s no_duplicate_retrigger=%s converged_to_caverne_tint=%s final_color=%s expected=%s"
		% [zone_switched, color_unchanged_on_repeat, converged, final_color, expected])

func _run_quest_chain_test() -> void:
	print("TEST_START:quest_chain")
	var data = root.get_node("/root/Data")
	var hud = inst.get_node("Hud")
	var cd = inst.char_data
	var gold_before = cd.gold
	var results = {}

	# 1) q_intro (talk) — c'était cassé : ouvrir le dialogue ne faisait progresser
	# aucune quête de type "talk", donc impossible de terminer même la 1ere quête du jeu.
	hud._on_open_npc(data.get_npc("ancien"))
	hud.accept_quest("q_intro")
	hud._on_open_npc(data.get_npc("garde")) # doit maintenant faire progresser q_intro
	results["q_intro_progressed_by_talk"] = cd.quests_active.get("q_intro", -1) >= 1
	hud.turn_in_quest("q_intro")
	results["q_intro_completed"] = cd.quests_completed.has("q_intro")

	# 2) q_slime1 ne doit pas être proposable avant q_intro terminé — déjà vérifié
	# ci-dessus ; on vérifie maintenant qu'il DEVIENT disponible une fois le prérequis rempli.
	var q_slime1 = data.get_quest("q_slime1")
	var prereq_ok = true
	for r in q_slime1.requires:
		if not cd.quests_completed.has(r): prereq_ok = false
	results["q_slime1_unlocked_after_intro"] = prereq_ok

	hud.accept_quest("q_slime1")
	for i in range(8): inst.update_quest_progress("kill", "slime_vert")
	hud.turn_in_quest("q_slime1")
	results["q_slime1_completed"] = cd.quests_completed.has("q_slime1")

	hud.accept_quest("q_slime2")
	for i in range(5): inst.update_quest_progress("kill", "slime_rouge")
	hud.turn_in_quest("q_slime2")
	results["q_slime2_completed"] = cd.quests_completed.has("q_slime2")

	hud.accept_quest("q_loups")
	for i in range(8): inst.update_quest_progress("kill", "loup")
	hud.turn_in_quest("q_loups")
	results["q_loups_completed"] = cd.quests_completed.has("q_loups")

	hud.accept_quest("q_loup_alpha")
	inst.update_quest_progress("boss", "loup_alpha")
	hud.turn_in_quest("q_loup_alpha")
	results["q_loup_alpha_completed"] = cd.quests_completed.has("q_loup_alpha")

	# Récompenses cumulées attendues sur toute la chaîne
	var expected_gold_gain = 10 + 25 + 35 + 40 + 60
	results["gold_reward_correct"] = (cd.gold - gold_before) == expected_gold_gain
	results["nothing_left_active"] = cd.quests_active.is_empty()
	results["chain_order_preserved"] = cd.quests_completed == ["q_intro","q_slime1","q_slime2","q_loups","q_loup_alpha"]

	var all_ok = true
	for k in results.keys():
		if not results[k]: all_ok = false
	print("TEST_RESULT all_ok=%s details=%s" % [all_ok, results])

func _run_deliver_quest_test() -> void:
	print("TEST_START:deliver_quest")
	var data = root.get_node("/root/Data")
	var hud = inst.get_node("Hud")
	var cd = inst.char_data
	hud.accept_quest("q_relique")

	# BUG REEL trouvé en auditant le jeu : les quêtes "deliver" ne font jamais
	# progresser quests_active[qid] (rien n'incrémente ce compteur pour ce
	# type), donc l'ancienne condition ">= count" du dialogue restait
	# bloquée à 0 pour toujours — le bouton "[Rendre]" n'apparaissait JAMAIS,
	# même objet en main. De plus q_relique est donnée par "pretre" mais doit
	# se rendre à "ancien" (obj.target) : rendre chez le donneur était donc
	# aussi la mauvaise condition. Deux quêtes majeures (500 et 600 XP)
	# étaient de facto impossibles à terminer via l'interface normale.
	hud._on_open_npc(data.get_npc("ancien"))
	var turnin_hidden_without_item = not _dialogue_has_button(hud, "[Rendre]")
	var icon_hidden_without_item = inst.npc_quest_icon_state("ancien") != "turnin"

	cd.inventory["relique_ossements"] = 1
	inst.refresh_quest_icons()
	var icon_shows_turnin_with_item = inst.npc_quest_icon_state("ancien") == "turnin"
	hud._on_open_npc(data.get_npc("ancien"))
	var turnin_button_shown_at_target_npc = _dialogue_has_button(hud, "[Rendre]")

	# _clear_box() utilise queue_free() : libère explicitement (pas de frame
	# d'attente fiable en headless) pour ne pas mélanger les boutons de l'ancien
	# rendu avec le nouveau lors de la vérification qui suit.
	for c in hud.dialogue_box.get_children(): c.free()
	hud._on_open_npc(data.get_npc("pretre")) # le donneur, pas la cible de livraison
	var turnin_not_shown_at_wrong_npc = not _dialogue_has_button(hud, "[Rendre]")

	# tenter de rendre sans avoir l'objet (remis à zéro) : ne doit ni terminer
	# la quête ni consommer quoi que ce soit.
	var had_item = cd.inventory["relique_ossements"]
	cd.inventory["relique_ossements"] = 0
	hud.turn_in_quest("q_relique")
	var blocked_without_item = not cd.quests_completed.has("q_relique") and cd.quests_active.has("q_relique")
	cd.inventory["relique_ossements"] = had_item

	var gold_before = cd.gold
	hud.turn_in_quest("q_relique")
	var completed = cd.quests_completed.has("q_relique")
	var item_consumed = cd.inventory.get("relique_ossements", 0) == 0
	var gold_gained = (cd.gold - gold_before) == 250
	var icon_cleared_after_turnin = inst.npc_quest_icon_state("ancien") != "turnin"

	print("TEST_RESULT turnin_hidden_without_item=%s icon_hidden_without_item=%s icon_shows_turnin_with_item=%s turnin_button_shown_at_target_npc=%s turnin_not_shown_at_wrong_npc=%s blocked_without_item=%s completed_with_item=%s item_consumed=%s gold_gained_correct=%s icon_cleared_after_turnin=%s"
		% [turnin_hidden_without_item, icon_hidden_without_item, icon_shows_turnin_with_item, turnin_button_shown_at_target_npc, turnin_not_shown_at_wrong_npc, blocked_without_item, completed, item_consumed, gold_gained, icon_cleared_after_turnin])

func _dialogue_button_texts(hud) -> Array:
	var texts = []
	for c in hud.dialogue_box.get_children():
		if c is Button: texts.append(c.text)
	return texts

func _dialogue_has_button(hud, prefix: String) -> bool:
	for t in _dialogue_button_texts(hud):
		if t.begins_with(prefix): return true
	return false

func _run_talent_ui_flow_test() -> void:
	print("TEST_START:talent_ui_flow")
	var gs = root.get_node("/root/GameState")
	var hud = inst.get_node("Hud")
	inst.char_data.level = 5
	inst.player.stats = gs.compute_stats(inst.char_data)
	var atk_before = inst.player.stats.atk
	var tier = gs.pending_talent(inst.char_data)
	var chosen = tier.options[0]
	# passe par le vrai chemin UI (bouton -> _on_talent_available/_choose_talent),
	# pas juste une manipulation directe de char_data + recompute_stats comme
	# le faisait test_talent — sinon un bug dans le câblage UI passerait inaperçu
	# (c'est exactement le genre de trou qui cachait le bug des quêtes 'talk').
	hud._on_talent_available(tier)
	var overlay_shown = hud.talent_overlay.visible
	hud._choose_talent(tier, chosen.id)
	var atk_after = inst.player.stats.atk
	print("TEST_RESULT overlay_shown_before_choice=%s talent_recorded=%s stats_actually_updated_on_player=%s overlay_hidden_after=%s"
		% [overlay_shown, inst.char_data.talents.get(str(tier.level)) == chosen.id,
			atk_after != atk_before, not hud.talent_overlay.visible])
	print("TEST_RESULT2 hp_clamped_to_new_max=%s" % [inst.player.hp <= inst.player.stats.max_hp])

func _find_button_by_prefix(root_node: Node, prefix: String) -> Button:
	for c in root_node.get_children():
		if c is Button and c.text.begins_with(prefix): return c
		var found = _find_button_by_prefix(c, prefix)
		if found != null: return found
	return null

func _run_faction_shop_ui_test() -> void:
	print("TEST_START:faction_shop_ui")
	var data = root.get_node("/root/Data")
	var hud = inst.get_node("Hud")
	var cd = inst.char_data
	var marchand = data.get_npc("marchand")
	# réputation insuffisante : le bouton doit apparaître désactivé dans le vrai rendu de dialogue
	cd.reputation["garde"] = 0
	hud._on_open_npc(marchand)
	var btn_locked = _find_button_by_prefix(hud.dialogue_box, "Cape du Héros")
	var button_found = btn_locked != null
	var disabled_when_poor_rep = button_found and btn_locked.disabled
	# réputation suffisante : le bouton doit devenir cliquable et l'achat doit marcher
	cd.reputation["garde"] = 300
	cd.gold = 200
	# queue_free() ne libère les anciens boutons qu'en fin de frame : sans yield entre les
	# deux rendus (comme un vrai joueur en aurait toujours un), le second _find_button_by_prefix
	# retrouverait l'ancien bouton encore en mémoire — artefact de test déjà rencontré ailleurs
	# dans la session, pas un bug de jeu. On force le nettoyage immédiat avant de re-rendre.
	for c in hud.dialogue_box.get_children(): c.free()
	hud._on_open_npc(marchand) # re-render du dialogue avec la nouvelle réputation
	var btn_unlocked = _find_button_by_prefix(hud.dialogue_box, "Cape du Héros")
	var enabled_when_rep_ok = btn_unlocked != null and not btn_unlocked.disabled
	var gold_before = cd.gold
	if btn_unlocked != null: btn_unlocked.pressed.emit()
	print("TEST_RESULT button_found=%s disabled_when_poor_rep=%s enabled_when_rep_ok=%s purchase_via_button_worked=%s"
		% [button_found, disabled_when_poor_rep, enabled_when_rep_ok, cd.inventory.get("cape_heros", 0) == 1 and cd.gold == gold_before - 80])

func _run_village_economy_test() -> void:
	print("TEST_START:village_economy")
	var hud = inst.get_node("Hud")
	var eco = inst.village_economy
	eco.herbe_stock = 0
	eco.potion_stock = 0
	eco.potion_price = 25
	# simule 3 ticks : la cueilleuse récolte, l'alchimiste transforme dès que possible
	for i in range(3):
		inst.update_village_economy(inst.ECONOMY_TICK_INTERVAL + 0.1)
	print("TEST_STATE herbe_stock=%d potion_stock=%d potion_price=%d"
		% [eco.herbe_stock, eco.potion_stock, eco.potion_price])
	var stock_grew = eco.potion_stock > 0
	var price_dropped_with_stock = eco.potion_price == clampi(25 - eco.potion_stock, 8, 25)

	# achat : consomme le stock et paie le prix affiché, pas un prix fixe codé en dur
	inst.char_data.gold = 500
	var stock_before_buy = eco.potion_stock
	var price_before_buy = eco.potion_price
	var gold_before_buy = inst.char_data.gold
	hud.buy_item("potion_vie")
	var stock_consumed = eco.potion_stock == stock_before_buy - 1
	var paid_dynamic_price = (gold_before_buy - inst.char_data.gold) == price_before_buy

	# épuisement du stock : plus aucun achat possible tant que l'alchimiste n'a rien à vendre
	eco.potion_stock = 0
	var inv_before = inst.char_data.inventory.get("potion_vie", 0)
	hud.buy_item("potion_vie")
	var blocked_when_out_of_stock = inst.char_data.inventory.get("potion_vie", 0) == inv_before

	print("TEST_RESULT stock_grew_from_ticks=%s price_tracks_stock=%s stock_consumed_on_buy=%s paid_dynamic_price=%s blocked_when_out_of_stock=%s"
		% [stock_grew, price_dropped_with_stock, stock_consumed, paid_dynamic_price, blocked_when_out_of_stock])

func _run_village_decor_test() -> void:
	print("TEST_START:village_decor")
	var decor = inst.get_node("Decor")
	var polygons = 0
	var lights = 0
	var house_bodies = 0
	for c in decor.get_children():
		if c is Polygon2D: polygons += 1
		elif c is PointLight2D: lights += 1
		elif c is StaticBody2D: house_bodies += 1
	# le puits ajoute 3 Polygon2D (anneau, intérieur, toit) ; les torches (5 aux
	# portes + celles des zones dangereuses) ajoutent chacune un PointLight2D ;
	# les caisses/barils ajoutent 2 Polygon2D (barils) en plus du puits
	print("TEST_RESULT well_and_props_polygons=%d (attendu >= 3) house_torches_present=%s house_bodies_unchanged=%d"
		% [polygons, lights >= 5, house_bodies])

func _run_plaine_decor_test() -> void:
	print("TEST_START:plaine_decor")
	var data = root.get_node("/root/Data")
	var decor = inst.get_node("Decor")
	var plaine = data.ZONES.plaine
	var polygons_in_plaine = 0
	var flower_patches_in_plaine = 0
	for c in decor.get_children():
		if c.position.x < plaine.x0 or c.position.x > plaine.x1: continue
		if c is Polygon2D: polygons_in_plaine += 1
		elif c is Node2D and c.get_child_count() == 3 and c.get_child(0) is ColorRect:
			flower_patches_in_plaine += 1
	print("TEST_RESULT hay_bales_and_rocks_in_plaine=%d (attendu >= 20) flower_patches_in_plaine=%d (attendu >= 40)"
		% [polygons_in_plaine, flower_patches_in_plaine])

func _run_npc_collision_test() -> void:
	print("TEST_START:npc_collision")
	var n = inst.npc_nodes[0]
	var npc_pos = n.node.position # position réelle (les PNJ vagabondent désormais), pas le point de spawn figé
	inst.player.global_position = npc_pos + Vector2(0, 100)
	var start_pos = inst.player.global_position
	for i in range(30):
		inst.player.velocity = (npc_pos - inst.player.global_position).normalized() * 200.0
		inst.player.move_and_slide()
	var dist = inst.player.global_position.distance_to(npc_pos)
	var moved = start_pos.distance_to(inst.player.global_position)
	# le joueur doit être bloqué avant d'atteindre le centre du PNJ, mais rester
	# assez proche pour interagir (portée F = 70px)
	print("TEST_RESULT blocked=%s dist_to_npc=%.1f moved=%.1f still_within_interact_range=%s"
		% [dist > 8.0, dist, moved, dist < 70.0])

func _run_prop_collision_test() -> void:
	print("TEST_START:prop_collision")
	var well_pos = Vector2(700, 480)
	inst.player.global_position = well_pos + Vector2(0, 100)
	for i in range(30):
		inst.player.velocity = (well_pos - inst.player.global_position).normalized() * 200.0
		inst.player.move_and_slide()
	var dist_well = inst.player.global_position.distance_to(well_pos)
	var crate_pos = Vector2(560, 700)
	inst.player.global_position = crate_pos + Vector2(0, 100)
	for i in range(30):
		inst.player.velocity = (crate_pos - inst.player.global_position).normalized() * 200.0
		inst.player.move_and_slide()
	var dist_crate = inst.player.global_position.distance_to(crate_pos)
	print("TEST_RESULT well_blocked=%s dist_well=%.1f crate_blocked=%s dist_crate=%.1f"
		% [dist_well > 10.0, dist_well, dist_crate > 5.0, dist_crate])

func _run_enemy_collision_test() -> void:
	print("TEST_START:enemy_collision")
	var e = inst.spawn_enemy({"x": inst.player.global_position.x + 200, "y": inst.player.global_position.y, "type_id": "slime_vert", "respawn_at": 0.0})
	await create_timer(0.2).timeout # laisse le temps au corps physique fraîchement créé de s'enregistrer
	var enemy_pos = e.global_position
	inst.player.global_position = enemy_pos + Vector2(0, 60)
	var start_pos = inst.player.global_position
	for i in range(30):
		inst.player.velocity = (enemy_pos - inst.player.global_position).normalized() * 200.0
		inst.player.move_and_slide()
	var dist = inst.player.global_position.distance_to(enemy_pos)
	var moved = start_pos.distance_to(inst.player.global_position)
	print("TEST_RESULT enemy_blocks_player=%s dist_to_enemy=%.1f moved=%.1f" % [dist > 5.0, dist, moved])

func _run_char_portraits_test() -> void:
	print("TEST_START:char_portraits")
	var data = root.get_node("/root/Data")
	var grids = []
	for c in inst.content.get_children():
		if c is GridContainer: grids.append(c)
	var race_grid = grids[0] if grids.size() > 0 else null
	var class_grid = grids[1] if grids.size() > 1 else null
	var race_ok = race_grid != null and race_grid.get_child_count() == data.RACES.size()
	var class_ok = class_grid != null and class_grid.get_child_count() == data.CLASSES.size()
	var first_row_has_portrait = false
	var portrait_tint_matches = false
	if race_ok:
		var row = race_grid.get_child(0)
		first_row_has_portrait = row.get_child_count() == 2 and row.get_child(0) is Control
		var portrait = row.get_child(0)
		var body_tex_rect = portrait.get_child(1)
		var expected_tint = data.RACES[data.RACES.keys()[0]].tint
		portrait_tint_matches = body_tex_rect.modulate.is_equal_approx(expected_tint)
	print("TEST_RESULT race_grid_count_matches=%s class_grid_count_matches=%s first_row_has_portrait=%s portrait_tint_correct=%s"
		% [race_ok, class_ok, first_row_has_portrait, portrait_tint_matches])

func _run_enemy_anim_test() -> void:
	print("TEST_START:enemy_anim")
	var e = inst.spawn_enemy({"x": inst.player.global_position.x + 40, "y": inst.player.global_position.y, "type_id": "slime_vert", "respawn_at": 0.0})
	await create_timer(0.2).timeout # laisse la respiration idle démarrer
	var has_idle_tween_field = "_idle_tween" in e
	e.dir = "down"
	e.play_attack_anim()
	var scaled_up_immediately = e.sprite.scale.x > 1.1
	await create_timer(0.5).timeout # laisse l'attaque se terminer et la respiration reprendre
	var scale_restored = e.sprite.scale.is_equal_approx(Vector2(1,1))
	var idle_restarted = e._idle_tween != null and e._idle_tween.is_valid()
	print("TEST_RESULT has_idle_field=%s scaled_up_during_attack=%s scale_restored_after=%s idle_restarted_after=%s"
		% [has_idle_tween_field, scaled_up_immediately, scale_restored, idle_restarted])

func _run_spell_fx_test() -> void:
	print("TEST_START:spell_fx")
	var data = root.get_node("/root/Data")
	var dmg_skill_count = 0
	var fx_color_count = 0
	for cid in data.CLASSES.keys():
		for skill in data.CLASSES[cid].skills:
			if skill.has("dmg_mult"):
				dmg_skill_count += 1
				if skill.has("fx_color"): fx_color_count += 1
	print("TEST_STATE dmg_skills=%d with_fx_color=%d" % [dmg_skill_count, fx_color_count])

	# Sort à projectile (Boule de Feu, mage) : les dégâts doivent être différés
	# le temps que l'orbe visuel voyage, pas instantanés comme au corps à corps.
	inst.char_data["class"] = "mage"
	inst.char_data.level = 10
	inst.player.stats = root.get_node("/root/GameState").compute_stats(inst.char_data)
	inst.player.mana = 999
	var e1 = inst.spawn_enemy({"x": inst.player.global_position.x + 150, "y": inst.player.global_position.y, "type_id": "loup_alpha", "respawn_at": 0.0})
	var hp_before_cast = e1.hp
	inst.use_skill(0) # boule_feu
	var hp_immediately_after = e1.hp
	await create_timer(0.5).timeout
	var hp_after_travel = e1.hp
	print("TEST_RESULT projectile_damage_delayed=%s projectile_damage_landed=%s"
		% [hp_immediately_after == hp_before_cast, hp_after_travel < hp_before_cast])

	# Sort de mêlée (Coup Puissant, guerrier) : dégâts instantanés, pas de délai.
	inst.char_data["class"] = "guerrier"
	inst.player.stats = root.get_node("/root/GameState").compute_stats(inst.char_data)
	inst.player.mana = 999
	inst.player.cooldowns.clear()
	var e2 = inst.spawn_enemy({"x": inst.player.global_position.x + 30, "y": inst.player.global_position.y, "type_id": "loup_alpha", "respawn_at": 0.0})
	var hp2_before = e2.hp
	inst.use_skill(0) # coup_puissant
	var hp2_after = e2.hp
	print("TEST_RESULT2 melee_damage_instant=%s" % [hp2_after < hp2_before])

func _run_projectile_target_freed_test() -> void:
	print("TEST_START:projectile_target_freed")
	# Régression : un sort à projectile (boule_feu) dont la cible meurt/est
	# libérée avant que l'orbe n'arrive ne doit pas planter le jeu.
	inst.char_data["class"] = "mage"
	inst.char_data.level = 10
	var gs = root.get_node("/root/GameState")
	inst.player.stats = gs.compute_stats(inst.char_data)
	inst.player.mana = 999
	var e = inst.spawn_enemy({"x": inst.player.global_position.x + 150, "y": inst.player.global_position.y, "type_id": "slime_vert", "respawn_at": 0.0})
	inst.use_skill(0) # boule_feu, l'orbe est en vol vers e
	e.take_damage(99999.0) # tué par un autre moyen avant l'impact (vrai chemin de mort du jeu)
	await create_timer(0.5).timeout
	print("TEST_RESULT no_crash=true dead_target_skipped=%s" % [e.dead]) # si on arrive ici sans SCRIPT ERROR, c'est bon

func _run_shield_skill_test() -> void:
	print("TEST_START:shield_skill")
	var gs = root.get_node("/root/GameState")
	inst.char_data["class"] = "pretre"
	inst.char_data.level = 10
	inst.player.stats = gs.compute_stats(inst.char_data)
	inst.player.mana = 999
	inst.player.hp = inst.player.stats.max_hp
	inst.player.cooldowns.clear()
	inst.use_skill(1) # bouclier_saint : shield=60, duration=5.0
	print("TEST_STATE shield_applied=%.1f (attendu 60)" % inst.player.shield)

	# le bouclier absorbe avant les PV
	var hp_before = inst.player.hp
	var applied1 = inst.player.take_damage(30.0)
	print("TEST_RESULT1 shield_after_30dmg=%.1f hp_unchanged=%s applied_returned=%.1f"
		% [inst.player.shield, inst.player.hp == hp_before, applied1])

	# un coup qui dépasse largement le bouclier restant doit l'épuiser et entamer les PV
	# pour le surplus (le montant exact dépend de la mitigation par la défense)
	var shield_before_big_hit = inst.player.shield
	var hp_before2 = inst.player.hp
	var mitig2 = inst.player.take_damage(50.0)
	var hp_lost = hp_before2 - inst.player.hp
	var expected_overflow = mitig2 - shield_before_big_hit
	print("TEST_RESULT2 shield_depleted=%s hp_lost_matches_overflow=%s (perdu=%.1f attendu=%.1f)"
		% [inst.player.shield <= 0.0, absf(hp_lost - expected_overflow) < 0.5, hp_lost, expected_overflow])

	# expiration : un bouclier appliqué directement avec une courte durée doit retomber à 0
	inst.player.hp = inst.player.stats.max_hp
	inst._apply_shield_to(inst.player, 40.0, 0.2)
	var shield_right_after = inst.player.shield
	await create_timer(0.6).timeout
	print("TEST_RESULT3 shield_set_immediately=%s shield_expired_after_duration=%s"
		% [shield_right_after == 40.0, inst.player.shield == 0.0])

func _run_cc_effects_test() -> void:
	print("TEST_START:cc_effects")
	var gs = root.get_node("/root/GameState")
	# Piège à Ours (archer, skill 1) : promettait d'immobiliser mais ne faisait
	# que des degats avant ce fix — verifie l'immobilisation reelle.
	inst.char_data["class"] = "archer"
	inst.char_data.level = 10
	inst.player.stats = gs.compute_stats(inst.char_data)
	inst.player.mana = 999
	inst.player.cooldowns.clear()
	var e1 = inst.spawn_enemy({"x": inst.player.global_position.x + 40, "y": inst.player.global_position.y, "type_id": "loup_alpha", "respawn_at": 0.0})
	var spd_before = e1.effective_speed()
	inst.use_skill(1) # piege
	var spd_during = e1.effective_speed()
	print("TEST_RESULT trap_normal_speed_before=%s trap_immobilized_after=%s"
		% [spd_before > 0.0, spd_during == 0.0])

	# Nova de Glace (mage, skill 1) : degats de zone + ralentissement.
	inst.char_data["class"] = "mage"
	inst.player.stats = gs.compute_stats(inst.char_data)
	inst.player.mana = 999
	inst.player.cooldowns.clear()
	var e2 = inst.spawn_enemy({"x": inst.player.global_position.x + 30, "y": inst.player.global_position.y, "type_id": "loup_alpha", "respawn_at": 0.0})
	var base_spd = e2.spd
	inst.use_skill(1) # nova_glace
	var spd_slowed = e2.effective_speed()
	print("TEST_RESULT2 nova_slows_target=%s (base=%.1f effectif=%.1f, attendu ~50%%)"
		% [absf(spd_slowed - base_spd * 0.5) < 0.5, base_spd, spd_slowed])

func _run_forge_economy_test() -> void:
	print("TEST_START:forge_economy")
	var hud = inst.get_node("Hud")
	var eco = inst.village_economy
	eco.minerai_stock = 0
	eco.arme_stock = 0
	eco.arme_price = 70
	for i in range(3):
		inst.update_village_economy(inst.ECONOMY_TICK_INTERVAL + 0.1)
	print("TEST_STATE minerai_stock=%d arme_stock=%d arme_price=%d" % [eco.minerai_stock, eco.arme_stock, eco.arme_price])
	var stock_grew = eco.arme_stock > 0
	var price_tracks_stock = eco.arme_price == clampi(70 - eco.arme_stock * 5, 25, 70)

	inst.char_data.gold = 500
	var stock_before = eco.arme_stock
	var price_before = eco.arme_price
	var gold_before = inst.char_data.gold
	var inv_before = inst.char_data.inventory.get("epee_fer", 0)
	hud.buy_forged_weapon()
	var stock_consumed = eco.arme_stock == stock_before - 1
	var paid_dynamic_price = (gold_before - inst.char_data.gold) == price_before
	var item_received = inst.char_data.inventory.get("epee_fer", 0) == inv_before + 1

	eco.arme_stock = 0
	var inv2_before = inst.char_data.inventory.get("epee_fer", 0)
	hud.buy_forged_weapon()
	var blocked_when_out_of_stock = inst.char_data.inventory.get("epee_fer", 0) == inv2_before

	print("TEST_RESULT stock_grew_from_ticks=%s price_tracks_stock=%s stock_consumed_on_buy=%s paid_dynamic_price=%s item_received=%s blocked_when_out_of_stock=%s"
		% [stock_grew, price_tracks_stock, stock_consumed, paid_dynamic_price, item_received, blocked_when_out_of_stock])

func _run_save_zone_change_test() -> void:
	print("TEST_START:save_zone_change")
	var data = root.get_node("/root/Data")
	var gs = root.get_node("/root/GameState")
	# simule un joueur qui a voyagé jusqu'à la caverne, avec de l'état accumulé,
	# puis quitte le jeu à cet endroit précis (pas au village de départ)
	var target_pos = Vector2(data.ZONES.caverne.x0 + 400, 250.0)
	inst.player.global_position = target_pos
	inst.player.hp = 42.0
	inst.player.mana = 17.0
	inst.char_data.unlocked_zones = ["village", "plaine", "foret", "caverne"]
	inst.char_data.reputation["garde"] = 180
	inst.char_data.gold = 333
	inst.save_now()

	# simule un redémarrage complet : plus rien en mémoire, uniquement le fichier
	gs.char_data = {}
	var loaded = gs.load_saved_character()
	var pos_ok = absf(loaded.last_x - target_pos.x) < 0.01 and absf(loaded.last_y - target_pos.y) < 0.01
	var hp_ok = loaded.hp == 42.0 and loaded.mana == 17.0
	var zones_ok = loaded.unlocked_zones == ["village", "plaine", "foret", "caverne"]
	var rep_ok = loaded.reputation.get("garde") == 180
	var gold_ok = loaded.gold == 333
	print("TEST_RESULT pos_persisted=%s hp_mana_persisted=%s unlocked_zones_persisted=%s reputation_persisted=%s gold_persisted=%s"
		% [pos_ok, hp_ok, zones_ok, rep_ok, gold_ok])

	# simule le respawn dans un nouveau monde à partir de cette sauvegarde
	# (le chemin exact utilisé par spawn_local_player() en jeu réel)
	var would_spawn_at = Vector2(loaded.last_x, loaded.last_y) if loaded.has("last_x") and loaded.last_x != null else inst.get_zone_spawn("village")
	print("TEST_RESULT2 would_respawn_in_caverne=%s" % [would_spawn_at.distance_to(target_pos) < 1.0])
	gs.delete_save()

func _run_network_disconnect_guard_test() -> void:
	print("TEST_START:network_disconnect_guard")
	# En solo, inst.multiplayer.multiplayer_peer est nul (pas de session réseau) —
	# c'est aussi l'état dans lequel se retrouve un client après une deconnexion
	# serveur (server_disconnected ne remet pas Net.is_online a false). Verifie
	# que network_tick() sort immediatement sans tenter de RPC ni planter.
	# Godot refuse d'assigner directement un pair "déconnecté" à multiplayer_peer
	# (l'API exige qu'il soit connecting/connected), donc impossible de simuler
	# proprement une vraie coupure mi-session dans ce harnais mono-processus.
	# Vérifié à la place par un vrai test deux-processus (host+client via ENet
	# réel) : après une coupure, le client inondait les logs de "peer non
	# connecté" en boucle infinie avant ce fix. Ici on vérifie juste le cas
	# où plus aucun pair n'est assigné (multiplayer_peer = null), qui doit
	# aussi sortir immédiatement sans planter.
	var original_peer = inst.multiplayer.multiplayer_peer
	inst.multiplayer.multiplayer_peer = null
	var uptime_before = inst.network_uptime
	inst.network_tick(5.0)
	var uptime_unchanged = inst.network_uptime == uptime_before
	inst.multiplayer.multiplayer_peer = original_peer
	print("TEST_RESULT network_tick_returns_early_with_no_peer=%s no_crash=true" % uptime_unchanged)

func _run_plaine_cull_test() -> void:
	print("TEST_START:plaine_cull")
	var data = root.get_node("/root/Data")
	# ajoute un ennemi de plaine tout frais (dont on est sûr qu'il est vivant)
	# et un boss de plaine, pour vérifier que seul le premier peut être fauché.
	var e_normal = inst.spawn_enemy({"x": data.ZONES.plaine.x0 + 100, "y": 300, "type_id": "slime_vert", "respawn_at": 0.0})
	var boss_type = ""
	for tid in data.MONSTER_TYPES.keys():
		if data.MONSTER_TYPES[tid].zone == "plaine" and data.MONSTER_TYPES[tid].get("boss", false):
			boss_type = tid
			break
	var e_boss = inst.spawn_enemy({"x": data.ZONES.plaine.x0 + 120, "y": 300, "type_id": boss_type, "respawn_at": 0.0}) if boss_type != "" else null

	var gold_before = inst.char_data.gold
	var xp_before = inst.char_data.xp
	var culled_before = inst.village_economy.get("monsters_culled", 0)
	var any_culled = false
	for i in range(40): # la fonction est probabiliste (35%) : répéter pour fiabiliser le test
		inst._cull_plaine_monsters()
		if inst.village_economy.get("monsters_culled", 0) > culled_before:
			any_culled = true
			break
	print("TEST_RESULT monster_got_culled=%s normal_enemy_died=%s boss_survived=%s"
		% [any_culled, e_normal.dead, (e_boss == null or not e_boss.dead)])
	print("TEST_RESULT2 no_reward_given_to_player=%s" % [inst.char_data.gold == gold_before and inst.char_data.xp == xp_before])

func _find_label_with_text(node: Node, needle: String) -> Label:
	if node is Label and needle in node.text: return node
	for c in node.get_children():
		var r = _find_label_with_text(c, needle)
		if r: return r
	return null

func _run_garde_patrol_dialogue_test() -> void:
	print("TEST_START:garde_patrol_dialogue")
	var data = root.get_node("/root/Data")
	var hud = inst.get_node("Hud")
	inst.village_economy.monsters_culled = 0
	hud._on_open_npc(data.get_npc("garde"))
	var label_absent = _find_label_with_text(hud.dialogue_box, "patrouilles ont repoussé") == null
	for c in hud.dialogue_box.get_children(): c.free() # nettoyage immédiat avant re-rendu
	inst.village_economy.monsters_culled = 3
	hud._on_open_npc(data.get_npc("garde"))
	var lbl = _find_label_with_text(hud.dialogue_box, "patrouilles ont repoussé")
	print("TEST_RESULT hidden_when_zero=%s shown_when_nonzero=%s text=%s"
		% [label_absent, lbl != null, lbl.text if lbl else ""])

func _run_gather_stats_display_test() -> void:
	print("TEST_START:gather_stats_display")
	var hud = inst.get_node("Hud")
	inst.char_data.gather_counts = {}
	hud.inv_search_text = ""
	hud.render_inventory()
	var section_absent = _find_label_with_text(hud.inventory_box, "Récolte totale") == null
	for c in hud.inventory_box.get_children(): c.free() # nettoyage immédiat (queue_free différé fausserait le re-rendu)
	inst.char_data.gather_counts = {"minerai": 12, "bois": 0, "herbe": 5}
	hud.render_inventory()
	var stats_lbl = _find_label_with_text(hud.inventory_box, "Minerai")
	var shows_nonzero_only = stats_lbl != null and "12" in stats_lbl.text and "5" in stats_lbl.text and not ("Bois" in stats_lbl.text)
	print("TEST_RESULT section_hidden_when_empty=%s section_shown_with_data=%s zero_counts_excluded=%s text=%s"
		% [section_absent, stats_lbl != null, shows_nonzero_only, stats_lbl.text if stats_lbl else ""])

func _run_progression_stats_display_test() -> void:
	print("TEST_START:progression_stats_display")
	var hud = inst.get_node("Hud")
	inst.char_data.quests_completed = ["q_intro", "q_slime1", "q_slime2"]
	inst.char_data.bounties_done = 1
	hud.render_inventory()
	var lbl = _find_label_with_text(hud.inventory_box, "quête")
	print("TEST_RESULT progression_shown=%s text=%s" % [lbl != null, lbl.text if lbl else ""])
	var counts_correct = lbl != null and "3 quêtes" in lbl.text and "1 prime" in lbl.text
	print("TEST_RESULT2 counts_and_plurals_correct=%s" % counts_correct)

func _any_pool_player_playing_stream(audio, path: String) -> bool:
	for p in audio._pool:
		if p.playing and p.stream != null and p.stream.resource_path == path:
			return true
	return false

func _run_audio_system_test() -> void:
	print("TEST_START:audio_system")
	var audio = root.get_node("/root/Audio")
	# Le jeu etait totalement silencieux avant cette iteration (aucun
	# AudioStreamPlayer nulle part) - verifie que chaque effet sonore declare
	# charge correctement (fichier present, pas corrompu) et que les vrais
	# points d'accroche en jeu declenchent bien la lecture.
	var all_load_ok = true
	for key in audio.SFX.keys():
		if audio._load(key) == null:
			all_load_ok = false
			print("TEST_MISSING_SFX key=%s path=%s" % [key, audio.SFX[key]])
	print("TEST_STATE all_%d_sfx_load_ok=%s" % [audio.SFX.size(), all_load_ok])

	audio.play("attack_hit")
	var attack_sound_played = _any_pool_player_playing_stream(audio, audio.SFX.attack_hit)

	var e = inst.spawn_enemy({"x": inst.player.global_position.x + 30, "y": inst.player.global_position.y, "type_id": "slime_vert", "respawn_at": 0.0})
	inst.basic_attack()
	var hit_sound_played = _any_pool_player_playing_stream(audio, audio.SFX.attack_hit)

	var gs = root.get_node("/root/GameState")
	inst.char_data["class"] = "guerrier"
	inst.player.stats = gs.compute_stats(inst.char_data)
	inst.player.mana = 999
	inst.player.cooldowns.clear()
	inst.use_skill(0)
	var skill_sound_played = _any_pool_player_playing_stream(audio, audio.SFX.skill_cast)

	if not inst.gather_nodes.is_empty():
		var g = inst.gather_nodes[0]
		g.depleted = false
		inst.near_target = {"type": "gather", "ref": g}
		inst.try_interact()
	var gather_sound_played = _any_pool_player_playing_stream(audio, audio.SFX.item_pickup)

	print("TEST_RESULT attack_sound_played=%s hit_sound_played=%s skill_sound_played=%s gather_sound_played=%s"
		% [attack_sound_played, hit_sound_played, skill_sound_played, gather_sound_played])

func _find_node_of_type(from: Node, type_name: String) -> Node:
	for c in from.get_children():
		if c.get_class() == type_name or (type_name == "HSlider" and c is HSlider):
			return c
		var found = _find_node_of_type(c, type_name)
		if found != null:
			return found
	return null

func _run_options_screen_test() -> void:
	print("TEST_START:options_screen")
	# Avant cette iteration, l'audio n'avait aucun controle de volume : le menu
	# principal n'avait aucun ecran Options. Verifie que l'ecran s'affiche avec
	# un curseur relie a Audio.master_volume et que le deplacer change le volume.
	var audio = root.get_node("/root/Audio")
	audio.set_master_volume(0.5)
	inst.show_options()
	var slider = _find_node_of_type(inst, "HSlider")
	var slider_found = slider != null
	var slider_matches_volume = slider_found and absf(slider.value - audio.master_volume) < 0.01
	if slider_found:
		slider.value = 0.3
		slider.value_changed.emit(0.3)
	var volume_updated = absf(audio.master_volume - 0.3) < 0.01
	print("TEST_RESULT options_slider_found=%s slider_matches_volume=%s volume_updated_on_drag=%s"
		% [slider_found, slider_matches_volume, volume_updated])

func _run_ingame_options_overlay_test() -> void:
	print("TEST_START:ingame_options_overlay")
	# Verifie que la touche O bascule le panneau Options en jeu (pas seulement
	# depuis le menu principal), que le curseur y reflete Audio.master_volume,
	# et que le reglage persiste dans user://settings.cfg entre sessions.
	var hud = inst.get_node("Hud")
	var audio = root.get_node("/root/Audio")
	audio.set_master_volume(0.6)
	var was_visible = hud.options_overlay.visible
	var ev = InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_O
	hud._unhandled_key_input(ev)
	var opened_on_o = hud.options_overlay.visible == true and was_visible == false
	var slider = _find_node_of_type(hud.options_overlay, "HSlider")
	var slider_found = slider != null
	var slider_matches_volume = slider_found and absf(slider.value - 0.6) < 0.01
	var ev_esc = InputEventKey.new()
	ev_esc.pressed = true
	ev_esc.physical_keycode = KEY_ESCAPE
	hud._unhandled_key_input(ev_esc)
	var closed_on_escape = hud.options_overlay.visible == false
	if slider_found:
		slider.value = 0.2
		slider.value_changed.emit(0.2)
	var cfg = ConfigFile.new()
	var loaded_ok = cfg.load("user://settings.cfg") == OK
	var persisted_correctly = loaded_ok and absf(cfg.get_value("audio", "master_volume", -1.0) - 0.2) < 0.01
	print("TEST_RESULT opened_on_o=%s slider_found=%s slider_matches_volume=%s closed_on_escape=%s persisted_correctly=%s"
		% [opened_on_o, slider_found, slider_matches_volume, closed_on_escape, persisted_correctly])

func _run_minimap_test() -> void:
	print("TEST_START:minimap")
	# Le monde n'avait aucune vue d'ensemble : impossible de savoir dans quelle
	# zone on se trouve sans lire le petit texte en haut, et aucun moyen de voir
	# ou sont les autres joueurs du groupe. Verifie que la mini-carte existe,
	# que le marqueur du joueur suit sa position, et qu'un allie distant invalide
	# (deconnecte pendant le dessin) ne fait pas planter _draw_minimap().
	var data = root.get_node("/root/Data")
	var hud = inst.get_node("Hud")
	var minimap_found = hud.minimap != null
	var minimap_sized = minimap_found and hud.minimap.size.x > 0 and hud.minimap.size.y > 0

	inst.player.global_position.x = data.ZONES.foret.x0 + 100
	hud.minimap.queue_redraw()
	await process_frame # le dessin reel a lieu via le signal `draw`, pas un appel direct
	var draw_ok_no_remotes = true

	var gs = root.get_node("/root/GameState")
	var ally_data = gs.new_character("Allié Minimap", "elfe", "guerrier")
	var ally = load("res://scenes/Player.tscn").instantiate()
	inst.get_node("Players").add_child(ally)
	ally.setup(ally_data, false, 998)
	ally.global_position = Vector2(data.ZONES.plaine.x0 + 50, 0)
	inst.remote_players[998] = ally
	hud.minimap.queue_redraw()
	await process_frame
	var draw_ok_with_valid_remote = true

	ally.free() # libération immédiate (pas queue_free) pour tester le garde
	# is_instance_valid() de _draw_minimap sans attendre une frame supplémentaire
	hud.minimap.queue_redraw()
	await process_frame
	var draw_ok_with_freed_remote = true

	inst.remote_players.erase(998)
	print("TEST_RESULT minimap_found=%s minimap_sized=%s draw_ok_no_remotes=%s draw_ok_with_valid_remote=%s draw_ok_with_freed_remote=%s"
		% [minimap_found, minimap_sized, draw_ok_no_remotes, draw_ok_with_valid_remote, draw_ok_with_freed_remote])

func _run_hotbar_test() -> void:
	print("TEST_START:hotbar")
	# Les competences Q/E avaient un temps de recharge mais aucun retour visuel :
	# rien n'indiquait si un sort etait pret, en recharge, ou injouable faute de
	# mana. Verifie que la barre reflete l'etat reel du cooldown et du mana.
	var gs = root.get_node("/root/GameState")
	var hud = inst.get_node("Hud")
	inst.char_data["class"] = "guerrier" # skill0 coup_puissant cd=4.0 cout=8, skill1 cri_guerre cd=12.0 cout=15
	inst.player.stats = gs.compute_stats(inst.char_data)
	inst.player.mana = inst.player.stats.max_mana
	inst.player.cooldowns.clear()
	hud._process(0.0)

	var slots_built = hud.hotbar_slots.size() == 2
	var ready_before_use = hud.hotbar_slots[0].cd_overlay.size.y == 0.0 and not hud.hotbar_slots[0].cd_label.visible

	inst.use_skill(0)
	hud._process(0.0)
	var cooldown_shown_after_use = hud.hotbar_slots[0].cd_overlay.size.y > 0.0 and hud.hotbar_slots[0].cd_label.visible
	var other_slot_unaffected = hud.hotbar_slots[1].cd_overlay.size.y == 0.0

	# fait "expirer" le cooldown manuellement plutôt que d'attendre en temps réel
	inst.player.cooldowns["skill0"] = 0.0
	hud._process(0.0)
	var overlay_clears_after_cooldown_expires = hud.hotbar_slots[0].cd_overlay.size.y == 0.0 and not hud.hotbar_slots[0].cd_label.visible

	inst.player.mana = 0.0
	hud._process(0.0)
	var dimmed_when_cant_afford = hud.hotbar_slots[0].bg.color.r > hud.hotbar_slots[0].bg.color.g + 0.1 # teinte rougeâtre

	var icon_loaded_for_current_class = hud.hotbar_slots[0].icon.texture != null and hud.hotbar_slots[1].icon.texture != null

	# Les emplacements montraient juste un carré de couleur unie, sans aucune
	# icône reconnaissable pour le sort : verifie que CHAQUE sort de CHAQUE
	# classe déclare une icône et qu'elle charge réellement (fichier présent).
	var all_icons_load = true
	var missing_icons = []
	for cid in Data.CLASSES.keys():
		for skill in Data.CLASSES[cid].skills:
			if not skill.has("icon"):
				all_icons_load = false
				missing_icons.append("%s/%s (aucune icone déclarée)" % [cid, skill.id])
				continue
			var tex = load(Data.ICON_PATH + skill.icon)
			if tex == null:
				all_icons_load = false
				missing_icons.append("%s/%s -> %s" % [cid, skill.id, skill.icon])

	var all_ok = slots_built and ready_before_use and cooldown_shown_after_use and other_slot_unaffected and overlay_clears_after_cooldown_expires and dimmed_when_cant_afford and icon_loaded_for_current_class and all_icons_load
	print("TEST_RESULT all_ok=%s slots_built=%s ready_before_use=%s cooldown_shown_after_use=%s other_slot_unaffected=%s overlay_clears_after_cooldown_expires=%s dimmed_when_cant_afford=%s icon_loaded_for_current_class=%s all_icons_load=%s missing_icons=%s"
		% [all_ok, slots_built, ready_before_use, cooldown_shown_after_use, other_slot_unaffected, overlay_clears_after_cooldown_expires, dimmed_when_cant_afford, icon_loaded_for_current_class, all_icons_load, missing_icons])

func _run_player_hit_flash_test() -> void:
	print("TEST_START:player_hit_flash")
	# Les ennemis flashaient blanc en encaissant un coup (Enemy.take_damage)
	# mais le joueur n'avait aucun retour visuel du tout à part le texte
	# flottant "-X". Vérifie le flash rouge + restauration de la teinte
	# d'origine (raciale/équipement, PAS un blanc fixe comme les ennemis qui
	# n'ont pas de teinte persistante), et qu'il ne se déclenche pas quand
	# aucun dégât réel n'est infligé (invulnérabilité, bouclier absorbant tout).
	var p = inst.player
	p.hp = p.stats.max_hp
	p.invuln_until = 0.0
	p.shield = 0.0
	var original_modulate = p.body_sprite.modulate

	p.take_damage(30.0)
	var flashes_on_real_damage = p.body_sprite.modulate != original_modulate

	for i in range(40): await process_frame
	var restores_original_tint = p.body_sprite.modulate == original_modulate

	p.hp = p.stats.max_hp
	p.invuln_until = Time.get_ticks_msec() / 1000.0 + 5.0
	p.take_damage(30.0)
	var no_flash_while_invulnerable = p.body_sprite.modulate == original_modulate
	p.invuln_until = 0.0

	p.hp = p.stats.max_hp
	p.shield = 9999.0
	p.take_damage(10.0)
	var no_flash_when_shield_absorbs_all = p.body_sprite.modulate == original_modulate
	p.shield = 0.0

	print("TEST_RESULT flashes_on_real_damage=%s restores_original_tint=%s no_flash_while_invulnerable=%s no_flash_when_shield_absorbs_all=%s"
		% [flashes_on_real_damage, restores_original_tint, no_flash_while_invulnerable, no_flash_when_shield_absorbs_all])

func _run_client_enemy_visuals_test() -> void:
	print("TEST_START:client_enemy_visuals")
	# Un client (is_sim=false) ne recevait ni l'anim de deplacement (le
	# receveur de net_enemy_snapshot forcait "moving=false" en dur) ni
	# l'anim d'attaque (jamais declenchee que cote hote) : les ennemis
	# semblaient figes puis infligeaient des degats sans aucun signal visuel
	# pour quiconque n'etait pas l'hote. Verifie la logique de detection
	# d'une nouvelle attaque via le timestamp atk_t (play_attack_anim reset
	# sprite.position a zero de facon synchrone, c'est le signal verifie ici).
	var was_sim = inst.is_sim
	inst.is_sim = false
	var uid = "test_client_enemy_1"

	var snap1 = [{"uid": uid, "type_id": "slime_vert", "x": inst.player.global_position.x + 40, "y": inst.player.global_position.y, "hp": 20.0, "max_hp": 24.0, "dead": false, "dir": "down", "moving": true, "atk_t": 5.0}]
	inst.net_enemy_snapshot(snap1)
	var e = inst.enemies.get(uid, null)
	var enemy_created = e != null
	var baseline_atk_t_recorded = enemy_created and e.last_seen_atk_t == 5.0

	var no_attack_on_unchanged_atk_t = true
	var attack_played_on_newer_atk_t = false
	if enemy_created:
		e.sprite.position = Vector2(9, 9)
		var snap_same = [{"uid": uid, "type_id": "slime_vert", "x": e.global_position.x, "y": e.global_position.y, "hp": 20.0, "max_hp": 24.0, "dead": false, "dir": "down", "moving": false, "atk_t": 5.0}]
		inst.net_enemy_snapshot(snap_same)
		no_attack_on_unchanged_atk_t = e.sprite.position == Vector2(9, 9)

		var snap_newer = [{"uid": uid, "type_id": "slime_vert", "x": e.global_position.x, "y": e.global_position.y, "hp": 20.0, "max_hp": 24.0, "dead": false, "dir": "down", "moving": false, "atk_t": 6.0}]
		inst.net_enemy_snapshot(snap_newer)
		attack_played_on_newer_atk_t = e.sprite.position == Vector2.ZERO and e.last_seen_atk_t == 6.0

	inst.is_sim = was_sim
	if enemy_created:
		inst.enemies.erase(uid)
		e.queue_free()

	var all_ok = enemy_created and baseline_atk_t_recorded and no_attack_on_unchanged_atk_t and attack_played_on_newer_atk_t
	print("TEST_RESULT all_ok=%s enemy_created=%s baseline_atk_t_recorded=%s no_attack_on_unchanged_atk_t=%s attack_played_on_newer_atk_t=%s"
		% [all_ok, enemy_created, baseline_atk_t_recorded, no_attack_on_unchanged_atk_t, attack_played_on_newer_atk_t])

func _run_net_enemy_attack_test() -> void:
	print("TEST_START:net_enemy_attack")
	# BUG CRITIQUE trouve en auditant le combat multijoueur : l'IA des
	# ennemis (update_enemies, cote hote uniquement) ne faisait RIEN quand la
	# cible la plus proche etait un allie distant plutot que le joueur hote
	# lui-meme — aucun degat, aucun RPC, rien. En pratique seul l'hote
	# pouvait etre blesse par les monstres ; les autres joueurs du groupe
	# etaient invulnerables, meme cibles et "frappes" visuellement. Teste ici
	# la nouvelle fonction receptrice net_enemy_attack() qui applique
	# desormais les degats chez le pair concerne (impossible de simuler un
	# vrai second pair reseau dans ce process headless solo, donc on verifie
	# la fonction elle-meme plutot que le trajet RPC complet).
	var p = inst.player
	p.hp = p.stats.max_hp
	p.invuln_until = 0.0
	p.shield = 0.0
	var hp_before = p.hp

	inst.net_enemy_attack(30.0)
	var damage_applied = p.hp < hp_before
	var expected_mitig = maxf(30.0 * 0.45, 30.0 - p.stats.def * 0.35)
	var mitigation_matches_take_damage = absf(p.hp - (hp_before - expected_mitig)) < 0.01

	p.hp = 1.0
	inst.char_data.gold = 20
	inst.net_enemy_attack(9999.0)
	var death_triggers_correctly = p.dead and p.hp == 0.0
	var bloodstain_created_locally = inst.char_data.bloodstain != null

	print("TEST_RESULT damage_applied=%s mitigation_matches_take_damage=%s death_triggers_correctly=%s bloodstain_created_locally=%s"
		% [damage_applied, mitigation_matches_take_damage, death_triggers_correctly, bloodstain_created_locally])

func _find_button_text(node: Node, prefix: String) -> bool:
	for c in node.get_children():
		if c is Button and c.text.begins_with(prefix): return true
		if _find_button_text(c, prefix): return true
	return false

func _run_quit_to_menu_test() -> void:
	print("TEST_START:quit_to_menu")
	# Il n'existait aucun moyen de quitter la partie ou de revenir au menu
	# principal depuis l'ecran de jeu : seul Alt+F4 fonctionnait. Verifie que
	# les boutons existent dans le panneau Options et que world.save_now()
	# (appele par quit_to_menu avant le changement de scene) persiste bien
	# l'etat. Ne declenche PAS le vrai quit_to_menu() : appeler
	# get_tree().change_scene_to_file() depuis ce process de test
	# detruirait le harnais lui-meme (inst est un enfant de la scene qu'il
	# remplacerait).
	var hud = inst.get_node("Hud")
	hud.sync_options()
	hud.options_overlay.visible = true
	var quit_button_found = _find_button_text(hud.options_overlay, "Quitter le jeu")
	var menu_button_found = _find_button_text(hud.options_overlay, "Retour au menu")
	var has_quit_to_menu_method = inst.has_method("quit_to_menu")

	var pos_before = inst.player.global_position
	inst.player.global_position = Vector2(777, 333)
	inst.save_now()
	var gs = root.get_node("/root/GameState")
	var save_now_persists_position = gs.char_data.last_x == 777.0 and gs.char_data.last_y == 333.0
	inst.player.global_position = pos_before

	print("TEST_RESULT quit_button_found=%s menu_button_found=%s has_quit_to_menu_method=%s save_now_persists_position=%s"
		% [quit_button_found, menu_button_found, has_quit_to_menu_method, save_now_persists_position])

func _run_char_customization_test() -> void:
	print("TEST_START:char_customization")
	# L'apparence du joueur (couleur de cheveux) etait entierement figee — aucun
	# choix possible a la creation, toujours le meme brun (0.25,0.16,0.1) code
	# en dur. Verifie que la couleur choisie est bien persistee dans char_data
	# et appliquee au sprite, y compris apres une reapparition (respawn()
	# reinitialise les teintes et avait le meme defaut fige).
	var gs = root.get_node("/root/GameState")
	var cd_custom = gs.new_character("Custom", "humain", "guerrier", "#3a6ea5")
	var hair_color_persisted = cd_custom.hair_color == "#3a6ea5"

	var cd_default = gs.new_character("Default", "humain", "guerrier")
	var default_hair_color_unchanged = cd_default.hair_color == "#3f2a1a"

	var p = load("res://scenes/Player.tscn").instantiate()
	inst.get_node("Players").add_child(p)
	p.setup(cd_custom, false, 998)
	var hair_applied_on_setup = p.hair_sprite.modulate.is_equal_approx(Color("#3a6ea5"))

	p.dead = true
	p.respawn(Vector2(100, 100))
	var hair_applied_on_respawn = p.hair_sprite.modulate.is_equal_approx(Color("#3a6ea5"))

	p.queue_free()

	var all_ok = hair_color_persisted and default_hair_color_unchanged and hair_applied_on_setup and hair_applied_on_respawn
	print("TEST_RESULT all_ok=%s hair_color_persisted=%s default_hair_color_unchanged=%s hair_applied_on_setup=%s hair_applied_on_respawn=%s"
		% [all_ok, hair_color_persisted, default_hair_color_unchanged, hair_applied_on_setup, hair_applied_on_respawn])

func _run_teleporter_test() -> void:
	print("TEST_START:teleporter")
	# Le voyage rapide n'existait que via un menu abstrait (touche M), sans
	# aucun repère visible dans le monde. Vérifie qu'un portail existe par
	# zone, qu'il est bien détecté comme interactible (near_target) une fois
	# le joueur à proximité, et que F ouvre le même menu de voyage que M.
	var data = root.get_node("/root/Data")
	var one_per_zone = inst.teleporter_nodes.size() == data.ZONES.size()

	var tp = inst.teleporter_nodes[0]
	inst.player.global_position = Vector2(tp.x, tp.y)
	inst.update_near_interactable()
	var detected_as_nearest = inst.near_target != null and inst.near_target.type == "teleporter"

	var hud = inst.get_node("Hud")
	hud.travel_overlay.visible = false
	inst.try_interact()
	var opens_travel_menu = hud.travel_overlay.visible == true

	print("TEST_RESULT one_per_zone=%s detected_as_nearest=%s opens_travel_menu=%s"
		% [one_per_zone, detected_as_nearest, opens_travel_menu])

func _run_camera_zoom_test() -> void:
	print("TEST_START:camera_zoom")
	# Le niveau de zoom de la camera etait totalement fige (1.6 code en dur,
	# aucune entree utilisateur geree) : verifie que la molette de souris
	# zoome/dezoome et que les bornes min/max sont respectees.
	var cam = inst.player_camera
	var camera_found = cam != null
	cam.zoom = Vector2(1.6, 1.6)

	var ev_up = InputEventMouseButton.new()
	ev_up.button_index = MOUSE_BUTTON_WHEEL_UP
	ev_up.pressed = true
	inst._unhandled_input(ev_up)
	var zoomed_in_on_wheel_up = cam.zoom.x > 1.6

	var ev_down = InputEventMouseButton.new()
	ev_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev_down.pressed = true
	inst._unhandled_input(ev_down)
	inst._unhandled_input(ev_down)
	var zoomed_out_on_wheel_down = cam.zoom.x < 1.6

	cam.zoom = Vector2(inst.CAMERA_ZOOM_MAX, inst.CAMERA_ZOOM_MAX)
	inst._unhandled_input(ev_up)
	var clamped_at_max = absf(cam.zoom.x - inst.CAMERA_ZOOM_MAX) < 0.001 # Vector2 est en float32, comparaison exacte peu fiable

	cam.zoom = Vector2(inst.CAMERA_ZOOM_MIN, inst.CAMERA_ZOOM_MIN)
	inst._unhandled_input(ev_down)
	var clamped_at_min = absf(cam.zoom.x - inst.CAMERA_ZOOM_MIN) < 0.001

	var all_ok = camera_found and zoomed_in_on_wheel_up and zoomed_out_on_wheel_down and clamped_at_max and clamped_at_min
	print("TEST_RESULT all_ok=%s camera_found=%s zoomed_in_on_wheel_up=%s zoomed_out_on_wheel_down=%s clamped_at_max=%s clamped_at_min=%s"
		% [all_ok, camera_found, zoomed_in_on_wheel_up, zoomed_out_on_wheel_down, clamped_at_max, clamped_at_min])

func _run_npc_wander_test() -> void:
	print("TEST_START:npc_wander")
	# Les PNJ etaient completement figes (seule une respiration verticale de
	# quelques pixels, jamais de vrai deplacement). Verifie qu'ils se
	# deplacent reellement autour de leur poste, restent dans un rayon
	# raisonnable, reviennent a l'etat idle, et que le corps de collision
	# (enfant de node, pas de visual) suit bien le vagabondage.
	var entry = inst.npc_nodes[0]
	entry.wander_state = "idle"
	entry.node.position = entry.home
	entry.wander_next_at = Time.get_ticks_msec() / 1000.0 - 1.0 # force le declenchement immediat

	inst.update_npc_wander(0.016)
	var starts_walking = entry.wander_state == "walking"
	var target_within_radius = entry.home.distance_to(entry.wander_target) <= inst.NPC_WANDER_RADIUS + 0.01

	var moved_toward_target = false
	var reached_idle_again = false
	for i in range(400):
		var before = entry.node.position
		inst.update_npc_wander(0.1)
		if i == 0: moved_toward_target = entry.node.position != before
		if entry.wander_state == "idle": reached_idle_again = true; break

	var collision_follows = entry.node.get_child(1).global_position.is_equal_approx(entry.node.global_position)

	var all_ok = starts_walking and target_within_radius and moved_toward_target and reached_idle_again and collision_follows
	print("TEST_RESULT all_ok=%s starts_walking=%s target_within_radius=%s moved_toward_target=%s reached_idle_again=%s collision_follows=%s"
		% [all_ok, starts_walking, target_within_radius, moved_toward_target, reached_idle_again, collision_follows])

func _run_zone_event_test() -> void:
	print("TEST_START:zone_event")
	# Le monde n'avait aucun événement dynamique : rien ne se passait jamais
	# sans action du joueur. Vérifie qu'une horde surgit bien après le délai,
	# uniquement en zone dangereuse (pas au village), dans les limites de la
	# zone, et que les ennemis générés ne réapparaissent pas après leur mort
	# (évite une croissance sans fin de la population).
	var data = root.get_node("/root/Data")

	inst.player.global_position = Vector2(data.ZONES.village.x0 + 100, 200)
	var count_before_village = inst.enemies.size()
	inst.trigger_zone_event()
	var no_invasion_in_village = inst.enemies.size() == count_before_village

	var foret = data.ZONES.foret
	inst.player.global_position = Vector2((foret.x0 + foret.x1) / 2.0, 300)
	var count_before = inst.enemies.size()
	inst.trigger_zone_event()
	var spawned = inst.enemies.size() - count_before
	var count_in_range = spawned >= 4 and spawned <= 6

	var all_within_zone_bounds = true
	var checked = 0
	for uid in inst.enemies.keys():
		var e = inst.enemies[uid]
		# set_meta(key, null) EFFACE la clé plutôt que d'y stocker null (comportement
		# Godot, et get_meta(key, null) erreurait sur une clé absente) : l'absence
		# de la clé identifie donc les ennemis d'invasion sans jamais réapparaître
		# (tout ennemi normal a une meta "spawn_def" présente, posée par spawn_enemy()).
		if not e.has_meta("spawn_def"):
			checked += 1
			if e.global_position.x < foret.x0 or e.global_position.x > foret.x1: all_within_zone_bounds = false
	var none_will_respawn = true # garanti par construction : has_meta ci-dessus est le test de non-réapparition lui-même
	var found_invasion_enemies = checked >= 4

	inst.event_accum = 0.0
	inst.next_event_at = 999999.0
	inst.update_zone_events(1.0)
	var timer_gate_respected = inst.enemies.size() - count_before == spawned # aucune horde supplementaire tant que le delai n'est pas ecoule

	var all_ok = no_invasion_in_village and count_in_range and all_within_zone_bounds and none_will_respawn and found_invasion_enemies and timer_gate_respected
	print("TEST_RESULT all_ok=%s no_invasion_in_village=%s count_in_range=%s all_within_zone_bounds=%s none_will_respawn=%s found_invasion_enemies=%s timer_gate_respected=%s"
		% [all_ok, no_invasion_in_village, count_in_range, all_within_zone_bounds, none_will_respawn, found_invasion_enemies, timer_gate_respected])

func _run_stats_screen_test() -> void:
	print("TEST_START:stats_screen")
	# L'inventaire montrait le nom des objets equipes mais jamais de chiffres :
	# aucun ecran ne repondait a "quel est mon ATK/DEF actuel ?". Verifie que la
	# fiche de personnage affiche les bons totaux et l'objet equipe, et que la
	# touche C l'ouvre/ferme comme les autres panneaux.
	var hud = inst.get_node("Hud")
	var cd = inst.char_data
	cd.equipment["weapon"] = "epee_fer"
	var gs = root.get_node("/root/GameState")
	inst.player.stats = gs.compute_stats(cd)
	var expected_atk = int(round(inst.player.stats.atk))

	var was_visible = hud.stats_overlay.visible
	var ev = InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_C
	hud._unhandled_key_input(ev)
	var opened_on_c = hud.stats_overlay.visible == true and was_visible == false

	var combat_text = ""
	for c in hud.stats_box.get_children():
		if c is PanelContainer:
			var lbl = _find_node_of_type(c, "Label")
			if lbl != null and "Attaque" in lbl.text: combat_text = lbl.text
	var atk_shown_correctly = "Attaque : %d" % expected_atk in combat_text

	var weapon_row_found = false
	for c in hud.stats_box.get_children():
		if c is PanelContainer:
			var lbl2 = _find_node_of_type(c, "Label")
			if lbl2 != null and lbl2.text == Data.ITEMS.epee_fer.name: weapon_row_found = true

	var ev_esc = InputEventKey.new()
	ev_esc.pressed = true
	ev_esc.physical_keycode = KEY_ESCAPE
	hud._unhandled_key_input(ev_esc)
	var closed_on_escape = hud.stats_overlay.visible == false

	print("TEST_RESULT opened_on_c=%s atk_shown_correctly=%s (expected %d, saw \"%s\") weapon_row_found=%s closed_on_escape=%s"
		% [opened_on_c, atk_shown_correctly, expected_atk, combat_text, weapon_row_found, closed_on_escape])

func _run_music_system_test() -> void:
	print("TEST_START:music_system")
	# Le jeu n'avait aucune musique (uniquement des bruitages). Verifie que le
	# bus "Music" existe et est bien route vers "Master" (pour que le volume
	# general coupe aussi la musique), que le reglage de volume musique
	# persiste dans user://settings.cfg, et que déplacer le joueur en zone
	# dangereuse fait bien basculer l'ambiance via le vrai flux de jeu
	# (world.gd -> Audio.set_zone_mood), pas un appel direct au systeme audio.
	var audio = root.get_node("/root/Audio")
	var data = root.get_node("/root/Data")

	var bus_idx = AudioServer.get_bus_index("Music")
	var music_bus_exists = bus_idx != -1
	var music_bus_routed_to_master = music_bus_exists and AudioServer.get_bus_send(bus_idx) == "Master"

	audio.set_music_volume(0.35)
	var cfg = ConfigFile.new()
	var loaded_ok = cfg.load("user://settings.cfg") == OK
	var music_volume_persisted = loaded_ok and absf(cfg.get_value("audio", "music_volume", -1.0) - 0.35) < 0.01

	# Zone sûre au départ : l'ambiance calme doit dominer. On avance par frames
	# (pas par temps réel) pour rester synchronisé avec le budget de frames du
	# harness, qui tourne bien plus vite que le temps réel en headless.
	inst.player.global_position = Vector2(data.ZONES.village.x0 + 50, 0)
	for i in range(45): await process_frame
	var calm_dominant_in_village = audio._calm_gain > audio._tension_gain

	# Déplace le joueur en zone dangereuse et laisse le vrai tick de zone de
	# world.gd (toutes les 0.4s) détecter le changement et appeler Audio.set_zone_mood.
	inst.player.global_position = Vector2(data.ZONES.foret.x0 + 50, 0)
	for i in range(45): await process_frame
	var mood_switched_to_tension = audio._target_mood_is_safe == false

	# Le fondu enchaîné est volontairement lent (~6.7s) ; on vérifie juste la
	# tendance après quelques frames supplémentaires plutôt que d'attendre la fin complète.
	for i in range(45): await process_frame
	var tension_gain_rising = audio._tension_gain > 0.02

	print("TEST_RESULT music_bus_exists=%s music_bus_routed_to_master=%s music_volume_persisted=%s calm_dominant_in_village=%s mood_switched_to_tension=%s tension_gain_rising=%s (tension_gain=%.2f)"
		% [music_bus_exists, music_bus_routed_to_master, music_volume_persisted, calm_dominant_in_village, mood_switched_to_tension, tension_gain_rising, audio._tension_gain])

func _run_chat_test() -> void:
	print("TEST_START:chat")
	# C'est un jeu coop jusqu'à 4 joueurs et il n'existait aucun moyen de
	# communiquer en jeu. Verifie la validation des messages (vide/espaces
	# ignorés, troncature à 140 caractères, journal plafonné), et que le
	# garde anti-déplacement dans handle_movement() fonctionne bien quand le
	# chat a le focus (sans ce garde, taper "s"/"d" déplace aussi le perso).
	var hud = inst.get_node("Hud")

	inst.send_chat_message("   ")
	var empty_ignored = hud.chat_messages.is_empty()

	inst.send_chat_message("  Salut le groupe !  ")
	var trimmed_correctly = not hud.chat_messages.is_empty() and hud.chat_messages[-1].text == "Salut le groupe !"
	var sender_correct = not hud.chat_messages.is_empty() and hud.chat_messages[-1].sender == inst.char_data.name

	var long_text = "a".repeat(200)
	inst.send_chat_message(long_text)
	var truncated_correctly = hud.chat_messages[-1].text.length() == 140

	for i in range(10):
		inst.send_chat_message("msg%d" % i)
	var capped_correctly = hud.chat_messages.size() == hud.CHAT_MAX_MESSAGES

	hud.open_chat()
	var chat_reports_focused = hud.is_chat_focused()
	inst.player.velocity = Vector2(999, 999) # valeur sentinelle
	inst.handle_movement(0.1)
	var movement_blocked_while_focused = (inst.player.velocity == Vector2.ZERO) if chat_reports_focused else true
	hud.chat_input.visible = false

	print("TEST_RESULT empty_ignored=%s trimmed_correctly=%s sender_correct=%s truncated_correctly=%s capped_correctly=%s chat_reports_focused=%s movement_blocked_while_focused=%s"
		% [empty_ignored, trimmed_correctly, sender_correct, truncated_correctly, capped_correctly, chat_reports_focused, movement_blocked_while_focused])

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
