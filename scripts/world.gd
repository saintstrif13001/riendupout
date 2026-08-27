extends Node2D

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const HudScene := preload("res://scenes/Hud.tscn")

const DIR_VEC := {"up":Vector2(0,-1), "down":Vector2(0,1), "left":Vector2(-1,0), "right":Vector2(1,0)}

signal hud_update(d)
signal near_update(text)
signal open_npc(npc)
signal quest_progress()

var player: Player
var remote_players: Dictionary = {} # peer_id -> Player
var enemies: Dictionary = {} # uid -> Enemy
var enemy_spawns: Array = [] # {x,y,type_id,respawn_at,timer}
var next_enemy_uid: int = 1
var is_sim: bool = true
var char_data: Dictionary
var near_target = null # {type:"gather"/"npc", ref}
var respawn_at: float = -1.0
var net_send_accum: float = 0.0
var net_enemy_accum: float = 0.0
var npc_nodes: Array = []
var gather_nodes: Array = []

func _ready() -> void:
	char_data = GameState.char_data
	is_sim = multiplayer.is_server()
	randomize()
	draw_world()
	spawn_local_player()
	build_npcs()
	build_gather_nodes()
	if is_sim:
		build_enemy_spawns()
	if Net.is_online:
		Net.player_left.connect(_on_peer_left)
	var hud = HudScene.instantiate()
	add_child(hud)
	hud.bind(self)
	emit_signal("hud_update", make_hud_data())

func draw_world() -> void:
	var zones_node = $Zones
	for key in Data.ZONES.keys():
		var z = Data.ZONES[key]
		var w = z.x1 - z.x0
		var rect = ColorRect.new()
		rect.color = z.bg
		rect.position = Vector2(z.x0, 0)
		rect.size = Vector2(w, Data.WORLD_HEIGHT)
		rect.z_index = -10
		zones_node.add_child(rect)
		var label = Label.new()
		label.text = z.name
		label.position = Vector2(z.x0 + 40, 20)
		label.add_theme_font_size_override("font_size", 22)
		label.z_index = -9
		zones_node.add_child(label)
		if not z.safe:
			var lvl = Label.new()
			lvl.text = "Niv. %d-%d" % [z.lvl[0], z.lvl[1]]
			lvl.position = Vector2(z.x0 + 40, 50)
			lvl.z_index = -9
			zones_node.add_child(lvl)
	# décor
	var tree_tex = load("res://assets/tiles/small_tree.png")
	seed(1234)
	for i in range(140):
		var x = randi_range(60, int(Data.WORLD_WIDTH) - 60)
		var y = randi_range(120, int(Data.WORLD_HEIGHT) - 60)
		var z = Data.zone_at(x)
		if z.safe and randf() > 0.15:
			continue
		var spr = Sprite2D.new()
		spr.texture = tree_tex
		spr.position = Vector2(x, y)
		spr.scale = Vector2.ONE * randf_range(1.4, 2.2)
		spr.z_index = int(y)
		$Decor.add_child(spr)

func get_zone_spawn(zone_id: String) -> Vector2:
	var z = Data.ZONES[zone_id]
	return Vector2(z.x0 + 200, Data.WORLD_HEIGHT / 2.0)

func spawn_local_player() -> void:
	player = PlayerScene.instantiate()
	$Players.add_child(player)
	player.setup(char_data, true, multiplayer.get_unique_id())
	player.global_position = get_zone_spawn("village")
	var cam = Camera2D.new()
	cam.zoom = Vector2(1.6, 1.6)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(Data.WORLD_WIDTH)
	cam.limit_bottom = int(Data.WORLD_HEIGHT)
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()

func build_npcs() -> void:
	for npc in Data.NPCS:
		var node = Node2D.new()
		node.position = Vector2(npc.x, npc.y)
		var spr = Sprite2D.new()
		spr.texture = load("res://assets/sprites/player/body_walk.png")
		spr.region_enabled = true
		spr.region_rect = Rect2(2*64, 2*64, 64, 64)
		spr.modulate = npc.tint
		node.add_child(spr)
		var label = Label.new()
		label.text = npc.name
		label.position = Vector2(-50, -54)
		label.size = Vector2(100, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
		node.add_child(label)
		var icon = Label.new()
		icon.text = "!" if npc.role != "shop" and npc.role != "profession" else ("$" if npc.role == "shop" else "*")
		icon.position = Vector2(-8, -72)
		icon.add_theme_font_size_override("font_size", 18)
		node.add_child(icon)
		$NPCs.add_child(node)
		npc_nodes.append({"npc": npc, "node": node})

func build_gather_nodes() -> void:
	for n in Data.GATHER_NODES:
		var label = Label.new()
		label.text = {"bois":"B","minerai":"M","herbe":"H"}[n.type]
		label.position = Vector2(n.x - 10, n.y - 14)
		label.add_theme_font_size_override("font_size", 20)
		$GatherNodes.add_child(label)
		gather_nodes.append({"node": n, "label": label, "depleted": false, "respawn_at": 0.0})

func build_enemy_spawns() -> void:
	var by_zone := {}
	for tid in Data.MONSTER_TYPES.keys():
		var m = Data.MONSTER_TYPES[tid]
		if not by_zone.has(m.zone): by_zone[m.zone] = []
		by_zone[m.zone].append(tid)
	for zone_id in by_zone.keys():
		var z = Data.ZONES[zone_id]
		var types = by_zone[zone_id].filter(func(t): return not Data.MONSTER_TYPES[t].get("boss", false))
		for i in range(14):
			var x = randi_range(int(z.x0) + 80, int(z.x1) - 80)
			var y = randi_range(120, int(Data.WORLD_HEIGHT) - 60)
			var tid = types[i % types.size()]
			var sd = {"x": x, "y": y, "type_id": tid, "respawn_at": 0.0}
			enemy_spawns.append(sd)
			spawn_enemy(sd)
		for t in by_zone[zone_id]:
			if Data.MONSTER_TYPES[t].get("boss", false):
				var sd = {"x": z.x1 - 200, "y": Data.WORLD_HEIGHT/2.0, "type_id": t, "respawn_at": 0.0, "is_boss": true}
				enemy_spawns.append(sd)
				spawn_enemy(sd)

func spawn_enemy(sd: Dictionary) -> Enemy:
	var uid = "e%d" % next_enemy_uid
	next_enemy_uid += 1
	var e = EnemyScene.instantiate()
	$Enemies.add_child(e)
	var zone = Data.MONSTER_TYPES[sd.type_id].zone
	var lvl = randi_range(Data.ZONES[zone].lvl[0], Data.ZONES[zone].lvl[1])
	e.setup(sd.type_id, uid, lvl)
	e.global_position = Vector2(sd.x, sd.y)
	e.spawn_pos = Vector2(sd.x, sd.y)
	e.set_meta("spawn_def", sd)
	enemies[uid] = e
	return e

# ---------------- Boucle ----------------
func _physics_process(delta: float) -> void:
	if player.dead:
		handle_respawn(delta)
		return
	handle_movement(delta)
	player.update_visuals()
	update_near_interactable()
	update_gather_respawns(delta)

	if is_sim:
		update_enemies(delta)

	for pid in remote_players.keys():
		remote_players[pid].update_visuals()

	if Net.is_online:
		network_tick(delta)

func handle_movement(delta: float) -> void:
	var vx := 0.0
	var vy := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): vy = -1
	elif Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): vy = 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): vx = -1
	elif Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): vx = 1

	var moving = vx != 0 or vy != 0
	if moving:
		var v = Vector2(vx, vy).normalized() * player.stats.spd
		player.velocity = v
		var new_dir = player.dir
		if abs(vx) > abs(vy): new_dir = "right" if vx > 0 else "left"
		elif vy != 0: new_dir = "down" if vy > 0 else "up"
		player.set_anim(new_dir, true)
	else:
		player.velocity = Vector2.ZERO
		player.set_anim(player.dir, false)
	player.move_and_slide()
	player.global_position.x = clamp(player.global_position.x, 20, Data.WORLD_WIDTH - 20)
	player.global_position.y = clamp(player.global_position.y, 90, Data.WORLD_HEIGHT - 20)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if player.dead: return
	match event.physical_keycode:
		KEY_SPACE: basic_attack()
		KEY_Q: use_skill(0)
		KEY_E: use_skill(1)
		KEY_F: try_interact()

# ---------------- Combat ----------------
func find_enemies_in_range(range_px: float) -> Array:
	var list := []
	for uid in enemies.keys():
		var e: Enemy = enemies[uid]
		if e.dead: continue
		var d = player.global_position.distance_to(e.global_position)
		if d <= range_px: list.append({"e": e, "d": d})
	list.sort_custom(func(a,b): return a.d < b.d)
	return list

func basic_attack() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now < player.cooldowns.get("basic", 0.0): return
	player.cooldowns["basic"] = now + 0.5
	var cls = Data.CLASSES[char_data["class"]]
	var range_px = 210.0 if (cls.role == "dps_range" or cls.role == "dps_zone") else 55.0
	flash_attack_fx(range_px)
	var targets = find_enemies_in_range(range_px)
	if targets.is_empty(): return
	var dmg = roll_damage(player.stats.atk, 1.0, 0.0)
	deal_damage_to_enemy(targets[0].e, dmg)

func use_skill(idx: int) -> void:
	var cls = Data.CLASSES[char_data["class"]]
	if idx >= cls.skills.size(): return
	var skill = cls.skills[idx]
	var now = Time.get_ticks_msec() / 1000.0
	var cd_key = "skill%d" % idx
	if now < player.cooldowns.get(cd_key, 0.0): return
	if player.mana < skill.cost:
		float_text(player.global_position + Vector2(0,-50), "Pas assez de mana", Color(0.4,0.67,1))
		return
	player.cooldowns[cd_key] = now + skill.cd
	player.mana -= skill.cost

	if skill.has("heal"):
		player.heal(skill.heal)
		float_text(player.global_position + Vector2(0,-50), "+%d PV" % skill.heal, Color(0.4,1,0.53))
	if skill.has("buff"):
		var b = skill.buff
		player.stats.atk += b.get("atk", 0)
		player.stats.def += b.get("def", 0)
		player.stats.spd += b.get("spd", 0)
		get_tree().create_timer(b.duration).timeout.connect(func():
			player.stats.atk -= b.get("atk", 0)
			player.stats.def -= b.get("def", 0)
			player.stats.spd -= b.get("spd", 0))
		float_text(player.global_position + Vector2(0,-50), skill.name + " !", Color(1,0.88,0.4))
	if skill.has("dash"):
		var v = DIR_VEC[player.dir] * skill.dash
		player.global_position.x = clamp(player.global_position.x + v.x, 20, Data.WORLD_WIDTH-20)
		player.global_position.y = clamp(player.global_position.y + v.y, 90, Data.WORLD_HEIGHT-20)
		player.invuln_until = now + skill.invuln
	if skill.has("dmg_mult"):
		var range_px = skill.get("range", 60.0)
		flash_attack_fx(range_px)
		var targets = find_enemies_in_range(range_px)
		var hits = targets if skill.get("aoe", false) else (targets.slice(0,1) if targets.size() > 0 else [])
		for t in hits:
			var dmg = roll_damage(player.stats.atk, skill.dmg_mult, skill.get("crit_bonus", 0.0))
			deal_damage_to_enemy(t.e, dmg)

func roll_damage(atk: float, mult: float, extra_crit: float) -> float:
	var race = Data.RACES[char_data.race]
	var crit_chance = 0.08 + extra_crit + race.get("crit_bonus", 0.0)
	var dmg = atk * mult * randf_range(0.85, 1.15)
	if randf() < crit_chance: dmg *= 1.8
	return dmg

func flash_attack_fx(range_px: float) -> void:
	pass # (retour visuel simplifié pour l'instant — les nombres de dégâts flottants suffisent)

func deal_damage_to_enemy(e: Enemy, dmg: float) -> void:
	if is_sim:
		var applied = e.take_damage(dmg)
		float_text(e.global_position + Vector2(0,-40), "-%d" % int(round(applied)), Color(1,1,1))
		if e.dead: on_enemy_killed(e, multiplayer.get_unique_id())
	else:
		rpc_id(1, "net_attack_request", e.uid, dmg)
		float_text(e.global_position + Vector2(0,-40), "-%d" % int(round(dmg)), Color(1,1,1,0.6))

@rpc("any_peer", "reliable")
func net_attack_request(uid: String, dmg: float) -> void:
	if not is_sim: return
	if not enemies.has(uid): return
	var e: Enemy = enemies[uid]
	if e.dead: return
	var sender = multiplayer.get_remote_sender_id()
	e.take_damage(dmg)
	if e.dead: on_enemy_killed(e, sender)

func on_enemy_killed(e: Enemy, killer_id: int) -> void:
	if killer_id == multiplayer.get_unique_id():
		grant_kill_rewards(player, e, false)
	elif is_sim:
		rpc("net_xp_grant", e.uid)
	if Net.is_online:
		rpc("net_enemy_died", e.uid)
	var sd = e.get_meta("spawn_def", null)
	var respawn_delay = 120.0 if e.mdef.get("boss", false) else 20.0
	var uid = e.uid
	get_tree().create_timer(respawn_delay).timeout.connect(func():
		enemies.erase(uid)
		e.queue_free()
		if sd != null and is_sim: spawn_enemy(sd))

@rpc("authority", "reliable")
func net_enemy_died(uid: String) -> void:
	if enemies.has(uid) and not enemies[uid].dead:
		enemies[uid].die()

@rpc("authority", "reliable")
func net_xp_grant(uid: String) -> void:
	if not enemies.has(uid): return
	var e: Enemy = enemies[uid]
	var d = player.global_position.distance_to(e.global_position)
	if d < 400:
		grant_kill_rewards(player, e, true)

func grant_kill_rewards(p: Player, e: Enemy, partial: bool) -> void:
	var xp_amount = int(e.mdef.xp * 0.5) if partial else e.mdef.xp
	var res = p.gain_xp(xp_amount)
	float_text(p.global_position + Vector2(0,-60), "+%d XP" % res.amount, Color(1,0.88,0.4))
	if res.leveled:
		float_text(p.global_position + Vector2(0,-80), "NIVEAU %d !" % p.char_data.level, Color(1,0.4,1))
	if not partial:
		for drop in e.mdef.get("loot", []):
			if randf() < drop.chance:
				p.char_data.inventory[drop.id] = p.char_data.inventory.get(drop.id, 0) + 1
				float_text(p.global_position + Vector2(0,-20), "+1 " + Data.ITEMS[drop.id].name, Color(0.75,1,0.75))
				register_drop_for_quests(drop.id)
	update_quest_progress("kill", e.type_id)
	if e.mdef.get("boss", false): update_quest_progress("boss", e.type_id)
	emit_signal("hud_update", make_hud_data())

func update_enemies(delta: float) -> void:
	for uid in enemies.keys():
		var e: Enemy = enemies[uid]
		if e.dead: continue
		var target: Player = player
		var best_d = e.global_position.distance_to(player.global_position)
		for pid in remote_players.keys():
			var rp: Player = remote_players[pid]
			if rp.dead: continue
			var d = e.global_position.distance_to(rp.global_position)
			if d < best_d: best_d = d; target = rp
		var aggro_range = 260.0 if e.mdef.get("boss", false) else 150.0
		if best_d < aggro_range and not target.dead:
			var diff = target.global_position - e.global_position
			if best_d > 34:
				var v = diff.normalized() * e.spd
				e.velocity = v
				e.move_and_slide()
				e.set_anim("right" if diff.x>0 else "left" if abs(diff.x)>abs(diff.y) else ("down" if diff.y>0 else "up"), true)
			else:
				e.velocity = Vector2.ZERO
				var now = Time.get_ticks_msec()/1000.0
				if now > e.last_attack + 1.0:
					e.last_attack = now
					if target == player:
						var applied = player.take_damage(e.atk)
						if applied > 0:
							float_text(player.global_position + Vector2(0,-20), "-%d" % int(round(applied)), Color(1,0.4,0.4))
						emit_signal("hud_update", make_hud_data())
						if player.dead:
							float_text(player.global_position + Vector2(0,-40), "K.O.", Color(1,0.13,0.13))
		else:
			e.velocity = Vector2.ZERO
			e.set_anim(e.dir, false)
		e.update_visuals()

func handle_respawn(delta: float) -> void:
	if respawn_at < 0:
		respawn_at = Time.get_ticks_msec()/1000.0 + 3.0
		float_text(player.global_position + Vector2(0,-40), "Réapparition...", Color(1,1,1))
	if Time.get_ticks_msec()/1000.0 > respawn_at:
		respawn_at = -1.0
		player.respawn(get_zone_spawn("village"))
		emit_signal("hud_update", make_hud_data())

# ---------------- Récolte & PNJ ----------------
func update_near_interactable() -> void:
	var nearest = null
	var best_d = 70.0
	for g in gather_nodes:
		if g.depleted: continue
		var d = player.global_position.distance_to(Vector2(g.node.x, g.node.y))
		if d < best_d: best_d = d; nearest = {"type":"gather", "ref": g}
	for n in npc_nodes:
		var d = player.global_position.distance_to(Vector2(n.npc.x, n.npc.y))
		if d < best_d: best_d = d; nearest = {"type":"npc", "ref": n}
	near_target = nearest
	if nearest == null:
		emit_signal("near_update", "")
	elif nearest.type == "npc":
		emit_signal("near_update", nearest.ref.npc.name)
	else:
		emit_signal("near_update", "Récolter")

func update_gather_respawns(delta: float) -> void:
	var now = Time.get_ticks_msec()/1000.0
	for g in gather_nodes:
		if g.depleted and now > g.respawn_at:
			g.depleted = false
			g.label.modulate.a = 1.0

func try_interact() -> void:
	if near_target == null: return
	if near_target.type == "gather":
		var g = near_target.ref
		if g.depleted: return
		g.depleted = true
		g.respawn_at = Time.get_ticks_msec()/1000.0 + 15.0
		g.label.modulate.a = 0.25
		var mat = g.node.type
		char_data.inventory[mat] = char_data.inventory.get(mat, 0) + 1
		float_text(Vector2(g.node.x, g.node.y - 20), "+1 " + Data.ITEMS[mat].name, Color(0.75,1,0.75))
		char_data.gather_counts[mat] = char_data.gather_counts.get(mat, 0) + 1
		update_quest_progress("gather", mat)
		emit_signal("hud_update", make_hud_data())
	elif near_target.type == "npc":
		emit_signal("open_npc", near_target.ref.npc)

# ---------------- Quêtes ----------------
func update_quest_progress(kind: String, target_id) -> void:
	for qid in char_data.quests_active.keys():
		var q = Data.get_quest(qid)
		if q.is_empty(): continue
		var obj = q.obj
		if obj.type != kind: continue
		var hit = false
		if obj.target is Array: hit = obj.target.has(target_id)
		else: hit = obj.target == target_id
		if hit:
			char_data.quests_active[qid] = min(obj.count, char_data.quests_active[qid] + 1)
			float_text(player.global_position + Vector2(0,-70), "%s %d/%d" % [q.name, char_data.quests_active[qid], obj.count], Color(0.63,0.82,1))
			emit_signal("quest_progress")

func register_drop_for_quests(item_id: String) -> void:
	for qid in char_data.quests_active.keys():
		var q = Data.get_quest(qid)
		if q.is_empty(): continue
		if q.obj.type == "gather_drop" and q.obj.target == item_id:
			char_data.quests_active[qid] = min(q.obj.count, char_data.quests_active[qid] + 1)
			emit_signal("quest_progress")

# ---------------- Réseau ----------------
func network_tick(delta: float) -> void:
	net_send_accum += delta
	if net_send_accum > 0.066:
		net_send_accum = 0.0
		rpc("net_pos", player.global_position.x, player.global_position.y, player.dir, player.velocity.length() > 5.0, player.hp, player.stats.max_hp)
	if is_sim:
		net_enemy_accum += delta
		if net_enemy_accum > 0.2:
			net_enemy_accum = 0.0
			var snap := []
			for uid in enemies.keys():
				var e: Enemy = enemies[uid]
				snap.append({"uid": uid, "type_id": e.type_id, "x": e.global_position.x, "y": e.global_position.y, "hp": e.hp, "max_hp": e.max_hp, "dead": e.dead, "dir": e.dir})
			rpc("net_enemy_snapshot", snap)

@rpc("any_peer", "unreliable")
func net_pos(x: float, y: float, pdir: String, moving: bool, hp: float, max_hp: float) -> void:
	var sender = multiplayer.get_remote_sender_id()
	var p = ensure_remote_player(sender)
	p.global_position = Vector2(x, y)
	p.set_anim(pdir, moving)
	p.hp = hp
	p.stats.max_hp = max_hp

@rpc("authority", "unreliable")
func net_enemy_snapshot(snap: Array) -> void:
	if is_sim: return
	for s in snap:
		var e: Enemy = enemies.get(s.uid, null)
		if e == null:
			e = EnemyScene.instantiate()
			$Enemies.add_child(e)
			e.setup(s.type_id, s.uid, 1)
			enemies[s.uid] = e
		e.global_position = Vector2(s.x, s.y)
		e.hp = s.hp; e.max_hp = s.max_hp
		e.set_anim(s.dir, false)
		e.update_visuals()
		if s.dead and not e.dead: e.die()

func ensure_remote_player(pid: int) -> Player:
	if remote_players.has(pid): return remote_players[pid]
	var cd = GameState.roster.get(pid, {"name":"Joueur","race":"humain","class":"guerrier","level":1, "equipment":{}})
	var p = PlayerScene.instantiate()
	$Players.add_child(p)
	p.setup(cd, false, pid)
	p.global_position = get_zone_spawn("village")
	remote_players[pid] = p
	return p

func _on_peer_left(pid: int) -> void:
	if remote_players.has(pid):
		remote_players[pid].queue_free()
		remote_players.erase(pid)

# ---------------- Utilitaires ----------------
func float_text(pos: Vector2, text: String, color: Color) -> void:
	var l = Label.new()
	l.text = text
	l.position = pos
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 14)
	l.z_index = 100
	add_child(l)
	var tw = create_tween()
	tw.tween_property(l, "position:y", pos.y - 30, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)

func make_hud_data() -> Dictionary:
	return {
		"hp": player.hp, "max_hp": player.stats.max_hp,
		"mana": player.mana, "max_mana": player.stats.max_mana,
		"level": char_data.level, "xp": char_data.xp, "xp_needed": Data.xp_for_level(char_data.level),
		"gold": char_data.gold, "zone": Data.zone_at(player.global_position.x).name,
	}
