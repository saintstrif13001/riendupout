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
	test_mode = args[4] if args.size() > 4 else ""
	root.size = Vector2i(1152, 648)

func _process(delta: float) -> bool:
	if stage == 0:
		stage = 1
		if scene_path == "res://scenes/World.tscn":
			var gs = root.get_node("/root/GameState")
			gs.mode = "solo"
			gs.char_data = gs.new_character("Testeur", "humain", "guerrier")
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
