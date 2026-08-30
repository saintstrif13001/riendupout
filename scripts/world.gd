extends Node2D

const PlayerScene := preload("res://scenes/Player.tscn")
const EnemyScene := preload("res://scenes/Enemy.tscn")
const HudScene := preload("res://scenes/Hud.tscn")

const DIR_VEC := {"up":Vector2(0,-1), "down":Vector2(0,1), "left":Vector2(-1,0), "right":Vector2(1,0)}

signal hud_update(d)
signal near_update(text)
signal open_npc(npc)
signal quest_progress()
signal talent_available(tier)

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
var chest_nodes: Array = []
var hud_tick_accum: float = 0.0
var autosave_accum: float = 0.0
var death_zone_id: String = "village"
var hud = null
var canvas_modulate: CanvasModulate = null
var current_zone_light_id: String = ""

const ZONE_LIGHT := {
	"village": Color(1, 1, 1),
	"plaine": Color(1, 1, 1),
	"foret": Color(0.78, 0.86, 0.72),   # sous-bois, lumière tamisée par les frondaisons
	"caverne": Color(0.5, 0.55, 0.68),  # pénombre froide et bleutée des grottes
	"marais": Color(0.72, 0.78, 0.62),  # brume verdâtre et humide
}

func update_zone_lighting(zid: String) -> void:
	if zid == current_zone_light_id: return
	current_zone_light_id = zid
	var target = ZONE_LIGHT.get(zid, Color(1, 1, 1))
	var tw = create_tween()
	tw.tween_property(canvas_modulate, "color", target, 1.2).set_trans(Tween.TRANS_SINE)

func _ready() -> void:
	char_data = GameState.char_data
	is_sim = multiplayer.is_server()
	randomize()
	draw_world()
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.color = Color(1, 1, 1)
	add_child(canvas_modulate)
	spawn_local_player()
	var start_zid = Data.zone_at(player.global_position.x).id
	current_zone_light_id = start_zid
	canvas_modulate.color = ZONE_LIGHT.get(start_zid, Color(1, 1, 1))
	build_npcs()
	build_gather_nodes()
	if char_data.bloodstain: spawn_bloodstain_marker()
	if is_sim:
		build_enemy_spawns()
	if Net.is_online:
		Net.player_left.connect(_on_peer_left)
	hud = HudScene.instantiate()
	add_child(hud)
	hud.bind(self)
	emit_signal("hud_update", make_hud_data())
	var tier = GameState.pending_talent(char_data)
	if not tier.is_empty(): emit_signal("talent_available", tier)

const GROUND_TEXTURES := {
	"caverne": ["res://assets/tiles/ground/gravel_0.png", "res://assets/tiles/ground/gravel_1.png", "res://assets/tiles/ground/gravel_2.png", "res://assets/tiles/ground/gravel_3.png"],
	"marais": ["res://assets/tiles/ground/dirt_0.png", "res://assets/tiles/ground/dirt_1.png", "res://assets/tiles/ground/dirt_2.png", "res://assets/tiles/ground/dirt_3.png"],
	"foret": ["res://assets/tiles/ground/dirt_0.png", "res://assets/tiles/ground/dirt_1.png", "res://assets/tiles/ground/dirt_2.png", "res://assets/tiles/ground/dirt_3.png"],
}

func draw_world() -> void:
	var zones_node = $Zones
	seed(777)
	for key in Data.ZONES.keys():
		var z = Data.ZONES[key]
		var w = z.x1 - z.x0
		var rect = ColorRect.new()
		rect.color = z.bg
		rect.position = Vector2(z.x0, 0)
		rect.size = Vector2(w, Data.WORLD_HEIGHT)
		rect.z_index = -10
		zones_node.add_child(rect)
		if GROUND_TEXTURES.has(key):
			_build_ground_mosaic(z)
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
	# décor : arbres + bosquets, densité plus élevée et variée, y compris au village
	var tree_tex = load("res://assets/tiles/small_tree.png")
	seed(1234)
	for i in range(420):
		var x = randi_range(60, int(Data.WORLD_WIDTH) - 60)
		var y = randi_range(120, int(Data.WORLD_HEIGHT) - 60)
		var z = Data.zone_at(x)
		if z.safe and randf() > 0.45:
			continue
		if z.id == "caverne":
			continue # pas d'arbres sous terre — remplacés par des rochers plus bas
		var spr = Sprite2D.new()
		spr.texture = tree_tex
		spr.position = Vector2(x, y)
		var is_bush = randf() < 0.35
		spr.scale = Vector2.ONE * (randf_range(0.7, 1.1) if is_bush else randf_range(1.6, 2.6))
		if is_bush:
			spr.modulate = Color(0.75, 0.95, 0.65)
		spr.z_index = int(y)
		$Decor.add_child(spr)
	# rochers dans la caverne (formes procédurales, pas des arbres déguisés)
	var cav = Data.ZONES.caverne
	for i in range(70):
		var x = randi_range(int(cav.x0) + 60, int(cav.x1) - 60)
		var y = randi_range(120, int(Data.WORLD_HEIGHT) - 60)
		_spawn_rock(x, y)
	# petites touffes d'herbe (points de couleur) pour casser l'uniformité du fond
	for i in range(260):
		var x = randi_range(20, int(Data.WORLD_WIDTH) - 20)
		var y = randi_range(90, int(Data.WORLD_HEIGHT) - 20)
		var tuft = ColorRect.new()
		var shade = randf_range(-0.08, 0.1)
		var base = Data.zone_at(x).bg
		tuft.color = Color(clamp(base.r+shade,0,1), clamp(base.g+shade+0.05,0,1), clamp(base.b+shade,0,1), 0.55)
		tuft.size = Vector2(randf_range(10,26), randf_range(6,12))
		tuft.position = Vector2(x, y)
		tuft.z_index = -8
		$Decor.add_child(tuft)

	build_village_structures()
	build_props()

func build_village_structures() -> void:
	# Bâtiments : murs procéduraux + vrai sprite de toit (tuiles LPC) pour une silhouette
	# bien plus lisible que le triangle plat d'avant.
	var roof_tan = load("res://assets/buildings/roof_tan.png")
	var roof_brown = load("res://assets/buildings/roof_brown.png")
	# Chaque maison est alignée avec le PNJ qui "y habite" (forge = Grondar, etc.)
	# pour que le village ait une disposition lisible au lieu de bâtiments épars.
	var houses = [
		{"x":600, "y":530, "w":100, "h":75, "wall":Color(0.7,0.62,0.48), "roof":roof_brown}, # forge (Grondar, 600,600)
		{"x":700, "y":230, "w":90, "h":70, "wall":Color(0.75,0.65,0.5), "roof":roof_tan}, # alchimiste (Yvenne, 700,300)
		{"x":500, "y":680, "w":100, "h":75, "wall":Color(0.72,0.63,0.47), "roof":roof_tan}, # échoppe (Bosk, 500,750)
		{"x":400, "y":330, "w":80, "h":60, "wall":Color(0.76,0.66,0.5), "roof":roof_brown}, # cabane de l'Ancien (400,400)
		{"x":800, "y":430, "w":85, "h":65, "wall":Color(0.65,0.6,0.6), "roof":roof_brown}, # salle d'armes (Thoric, 800,500)
	]
	for h in houses:
		# ombre portée douce sous la maison
		var shadow = ColorRect.new()
		shadow.color = Color(0,0,0,0.18)
		shadow.size = Vector2(h.w + 16, h.h * 0.35)
		shadow.position = Vector2(h.x - h.w/2.0 - 8, h.y + h.h/2.0 - h.h*0.12)
		shadow.z_index = int(h.y) - 2
		$Decor.add_child(shadow)
		# contour légèrement plus sombre derrière le mur pour donner du relief
		var outline = ColorRect.new()
		outline.color = h.wall.darkened(0.35)
		outline.size = Vector2(h.w + 4, h.h + 4)
		outline.position = Vector2(h.x - h.w/2.0 - 2, h.y - h.h/2.0 - 2)
		outline.z_index = int(h.y) - 1
		$Decor.add_child(outline)
		var wall = ColorRect.new()
		wall.color = h.wall
		wall.size = Vector2(h.w, h.h)
		wall.position = Vector2(h.x - h.w/2.0, h.y - h.h/2.0)
		wall.z_index = int(h.y)
		$Decor.add_child(wall)
		# Collision solide pour que le joueur ne traverse pas visuellement le mur.
		var body = StaticBody2D.new()
		body.position = Vector2(h.x, h.y)
		var shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(h.w, h.h)
		shape.shape = rect_shape
		body.add_child(shape)
		$Decor.add_child(body)
		# bande d'ombre en bas du mur (donne un peu de volume)
		var wall_shade = ColorRect.new()
		wall_shade.color = h.wall.darkened(0.2)
		wall_shade.size = Vector2(h.w, h.h * 0.22)
		wall_shade.position = Vector2(h.x - h.w/2.0, h.y + h.h/2.0 - h.h*0.22)
		wall_shade.z_index = int(h.y) + 1
		$Decor.add_child(wall_shade)
		var roof = Sprite2D.new()
		roof.texture = h.roof
		var roof_scale = (h.w + 26) / float(h.roof.get_width())
		roof.scale = Vector2(roof_scale, roof_scale)
		roof.position = Vector2(h.x, h.y - h.h/2.0 - (h.roof.get_height() * roof_scale) * 0.42)
		roof.z_index = int(h.y) + 2
		$Decor.add_child(roof)
		var door = ColorRect.new()
		door.color = Color(0.28, 0.18, 0.1)
		door.size = Vector2(18, 28)
		door.position = Vector2(h.x - 9, h.y + h.h/2.0 - 28)
		door.z_index = int(h.y) + 3
		$Decor.add_child(door)
	# Puits central comme point de repère
	var well_base = ColorRect.new()
	well_base.color = Color(0.5, 0.5, 0.52)
	well_base.size = Vector2(40, 40)
	well_base.position = Vector2(700 - 20, 480 - 20)
	well_base.z_index = 470
	$Decor.add_child(well_base)

func build_props() -> void:
	# Coffres et torches dans les zones dangereuses, pour l'ambiance et un peu de loot passif.
	seed(4321)
	for key in Data.ZONES.keys():
		var z = Data.ZONES[key]
		if z.safe: continue
		var count = int((z.x1 - z.x0) / 260.0)
		for i in range(count):
			var x = randi_range(int(z.x0) + 100, int(z.x1) - 100)
			var y = randi_range(120, int(Data.WORLD_HEIGHT) - 60)
			if randf() < 0.4:
				_spawn_torch(x, y)
			else:
				_spawn_chest(x, y)

func _spawn_torch(x: int, y: int) -> void:
	var pole = ColorRect.new()
	pole.color = Color(0.3, 0.2, 0.12)
	pole.size = Vector2(4, 20)
	pole.position = Vector2(x - 2, y - 10)
	pole.z_index = int(y)
	$Decor.add_child(pole)
	var flame = ColorRect.new()
	flame.color = Color(1.0, 0.55, 0.15)
	flame.size = Vector2(8, 10)
	flame.position = Vector2(x - 4, y - 20)
	flame.z_index = int(y) + 1
	$Decor.add_child(flame)
	# Scintillement : la flamme pulse en taille/teinte pour paraître vivante.
	var flicker = create_tween().set_loops()
	flicker.tween_property(flame, "scale", Vector2(1.25, 1.4), 0.18).set_trans(Tween.TRANS_SINE).set_delay(randf() * 0.5)
	flicker.tween_property(flame, "scale", Vector2(0.9, 0.85), 0.22).set_trans(Tween.TRANS_SINE)
	flame.pivot_offset = flame.size / 2.0
	# Halo lumineux autour de la torche pour éclairer la zone alentour.
	var glow = PointLight2D.new()
	glow.texture = _radial_light_texture()
	glow.position = Vector2(x, y - 16)
	glow.color = Color(1.0, 0.65, 0.25)
	glow.energy = 1.1
	glow.texture_scale = 2.2
	glow.z_index = int(y) + 2
	$Decor.add_child(glow)
	var glow_pulse = create_tween().set_loops()
	glow_pulse.tween_property(glow, "energy", 1.4, 0.3).set_trans(Tween.TRANS_SINE).set_delay(randf() * 0.5)
	glow_pulse.tween_property(glow, "energy", 0.9, 0.35).set_trans(Tween.TRANS_SINE)

var _radial_light_tex: Texture2D = null
func _radial_light_texture() -> Texture2D:
	# Godot n'a pas de texture radiale native ; on en génère une petite au premier appel.
	if _radial_light_tex != null: return _radial_light_tex
	var size = 64
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	for px in range(size):
		for py in range(size):
			var d = Vector2(px, py).distance_to(center) / (size / 2.0)
			var a = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(px, py, Color(1, 1, 1, a * a))
	_radial_light_tex = ImageTexture.create_from_image(img)
	return _radial_light_tex

func _spawn_rock(x: int, y: int) -> void:
	var rock = Polygon2D.new()
	var w = randf_range(16, 34)
	var h = w * randf_range(0.55, 0.75)
	var shade = randf_range(0.32, 0.5)
	rock.color = Color(shade, shade * 0.94, shade * 0.9)
	rock.polygon = PackedVector2Array([
		Vector2(-w/2, h/3), Vector2(-w/3, -h/2), Vector2(w/4, -h/2.3),
		Vector2(w/2, 0), Vector2(w/3, h/2), Vector2(-w/4, h/2.2)
	])
	rock.position = Vector2(x, y)
	rock.z_index = int(y)
	$Decor.add_child(rock)

func _spawn_chest(x: int, y: int) -> void:
	var base = ColorRect.new()
	base.color = Color(0.42, 0.28, 0.14)
	base.size = Vector2(22, 16)
	base.position = Vector2(x - 11, y - 8)
	base.z_index = int(y)
	$Decor.add_child(base)
	var lid = ColorRect.new()
	lid.color = Color(0.55, 0.4, 0.2)
	lid.size = Vector2(22, 5)
	lid.position = Vector2(x - 11, y - 12)
	lid.pivot_offset = Vector2(0, 5) # charnière côté arrière : la couvercle bascule vers le haut
	lid.z_index = int(y) + 1
	$Decor.add_child(lid)
	var gold = randi_range(5, 20)
	chest_nodes.append({"x": x, "y": y, "lid": lid, "base": base, "opened": false, "gold": gold})

func open_chest(c: Dictionary) -> void:
	if c.opened: return
	c.opened = true
	var tw = create_tween()
	tw.tween_property(c.lid, "rotation", -1.1, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.lid.color = Color(0.3, 0.22, 0.12) # intérieur du coffre, plus sombre une fois ouvert
	char_data.gold += c.gold
	float_text(Vector2(c.x, c.y - 24), "+%d or" % c.gold, Color(1.0, 0.85, 0.3))
	emit_signal("hud_update", make_hud_data())

func _build_ground_mosaic(z: Dictionary) -> void:
	var paths = GROUND_TEXTURES[z.id]
	var texs = []
	for p in paths: texs.append(load(p))
	var chunk_w = 256
	var chunk_h = 256
	var x = z.x0
	while x < z.x1:
		var y = 0
		while y < Data.WORLD_HEIGHT:
			var tr = TextureRect.new()
			tr.texture = texs[randi() % texs.size()]
			tr.stretch_mode = TextureRect.STRETCH_TILE
			tr.position = Vector2(x, y)
			tr.size = Vector2(min(chunk_w, z.x1 - x), min(chunk_h, Data.WORLD_HEIGHT - y))
			tr.modulate = Color(0.8, 0.8, 0.8, 0.85)
			tr.z_index = -10
			$Zones.add_child(tr)
			y += chunk_h
		x += chunk_w

func get_zone_spawn(zone_id: String) -> Vector2:
	var z = Data.ZONES[zone_id]
	return Vector2(z.x0 + 200, Data.WORLD_HEIGHT / 2.0)

func spawn_local_player() -> void:
	player = PlayerScene.instantiate()
	$Players.add_child(player)
	player.setup(char_data, true, multiplayer.get_unique_id())
	if char_data.has("last_x") and char_data.last_x != null:
		player.global_position = Vector2(char_data.last_x, char_data.last_y)
	else:
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

const NPC_HAIR_COLORS := [
	Color(0.25, 0.16, 0.1),  # brun
	Color(0.07, 0.06, 0.06), # noir
	Color(0.55, 0.4, 0.15),  # blond fonce
	Color(0.78, 0.65, 0.3),  # blond
	Color(0.4, 0.12, 0.06),  # roux
	Color(0.6, 0.6, 0.63),   # gris
]

func build_npcs() -> void:
	var npc_body_tex = load("res://assets/sprites/player/body_walk.png")
	var npc_head_tex = load("res://assets/sprites/player/head_walk.png")
	var npc_legs_tex = load("res://assets/sprites/player/legs_walk.png")
	var npc_hair_tex = load("res://assets/sprites/player/hair_walk.png")
	var vest_texs = [
		load("res://assets/sprites/player/vest_tan_walk.png"),
		load("res://assets/sprites/player/vest_navy_walk.png"),
		load("res://assets/sprites/player/vest_maroon_walk.png"),
		load("res://assets/sprites/player/vest_forest_walk.png"),
	]
	var region = Rect2(2*64, 2*64, 64, 64)
	var idx = 0
	for npc in Data.NPCS:
		var node = Node2D.new()
		node.position = Vector2(npc.x, npc.y)
		node.z_index = int(npc.y) # sinon le PNJ reste toujours derrière les maisons (z_index en centaines)
		var legs = Sprite2D.new()
		legs.texture = npc_legs_tex
		legs.region_enabled = true; legs.region_rect = region
		legs.z_index = 0
		node.add_child(legs)
		var spr = Sprite2D.new()
		spr.texture = npc_body_tex
		spr.region_enabled = true
		spr.region_rect = region
		spr.modulate = npc.tint
		spr.z_index = 1
		node.add_child(spr)
		var vest = Sprite2D.new()
		vest.texture = vest_texs[idx % vest_texs.size()]
		vest.region_enabled = true; vest.region_rect = region
		vest.z_index = 2
		node.add_child(vest)
		# Coiffure et calvitie déterminées par hash de l'id du PNJ (stable d'une
		# partie à l'autre) plutôt que la même chevelure brune pour tout le monde.
		var h = hash(npc.id)
		var is_bald = (h % 5) == 0 # ~20%
		var hair = Sprite2D.new()
		hair.texture = npc_hair_tex
		hair.region_enabled = true; hair.region_rect = region
		hair.modulate = NPC_HAIR_COLORS[h % NPC_HAIR_COLORS.size()]
		hair.visible = not is_bald
		hair.z_index = 3
		node.add_child(hair)
		var head = Sprite2D.new()
		head.texture = npc_head_tex
		head.region_enabled = true
		head.region_rect = region
		head.modulate = npc.tint
		head.z_index = 3
		node.add_child(head)
		idx += 1
		# petite animation d'idle (respiration) pour que les PNJ ne soient pas figés
		var tw = create_tween().set_loops()
		tw.tween_property(node, "position:y", npc.y - 2.0, 1.1).set_trans(Tween.TRANS_SINE).set_delay(randf()*1.0)
		tw.tween_property(node, "position:y", npc.y, 1.1).set_trans(Tween.TRANS_SINE)
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
	if is_sim and e.mdef.has("phases"):
		e.phase_triggered.connect(func(phase): _on_boss_phase(e, phase))
	return e

func _on_boss_phase(boss: Enemy, phase: Dictionary) -> void:
	float_text(boss.global_position + Vector2(0,-70), "%s invoque des renforts !" % boss.mdef.name, Color(1,0.4,0.2))
	for i in range(phase.get("count", 1)):
		var ang = randf() * TAU
		var offset = Vector2(cos(ang), sin(ang)) * 70.0
		var sd = {"x": boss.global_position.x + offset.x, "y": boss.global_position.y + offset.y, "type_id": phase.summon, "respawn_at": 0.0}
		var add = spawn_enemy(sd)
		add.set_meta("spawn_def", null) # les renforts ne réapparaissent pas après leur mort

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

	hud_tick_accum += delta
	if hud_tick_accum > 0.4:
		hud_tick_accum = 0.0
		emit_signal("hud_update", make_hud_data())
		var zid = Data.zone_at(player.global_position.x).id
		death_zone_id = zid
		update_zone_lighting(zid)
		if not char_data.unlocked_zones.has(zid):
			char_data.unlocked_zones.append(zid)
			float_text(player.global_position + Vector2(0,-90), "Zone découverte : voyage rapide débloqué", Color(0.7,1,0.85))

	autosave_accum += delta
	if autosave_accum > 20.0:
		autosave_accum = 0.0
		save_now()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player != null:
		save_now()

func save_now() -> void:
	char_data.last_x = player.global_position.x
	char_data.last_y = player.global_position.y
	char_data.hp = player.hp
	char_data.mana = player.mana
	GameState.save_character()

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
	player.play_attack_anim(player.dir)
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
		var heal_range = skill.get("range", 180.0)
		var ally = find_nearest_ally_in_range(heal_range) if skill.get("party", false) else null
		if ally != null:
			rpc_id(ally.pid, "net_apply_heal", skill.heal)
			float_text(ally.p.global_position + Vector2(0,-50), "+%d PV" % skill.heal, Color(0.4,1,0.53))
			float_text(player.global_position + Vector2(0,-50), "Soin envoyé à %s" % ally.p.char_data.name, Color(0.6,0.85,1))
		else:
			player.heal(skill.heal)
			float_text(player.global_position + Vector2(0,-50), "+%d PV" % skill.heal, Color(0.4,1,0.53))
	if skill.has("buff"):
		var b = skill.buff
		_apply_buff_to(player, b)
		float_text(player.global_position + Vector2(0,-50), skill.name + " !", Color(1,0.88,0.4))
		if skill.get("party", false):
			var buff_range = skill.get("range", 0.0)
			if buff_range <= 0: buff_range = 220.0 # 0 = "portée illimitée locale" -> zone raisonnable autour du lanceur
			for pid in remote_players.keys():
				var rp: Player = remote_players[pid]
				if rp.dead: continue
				if player.global_position.distance_to(rp.global_position) <= buff_range:
					rpc_id(pid, "net_apply_buff", b)
					float_text(rp.global_position + Vector2(0,-50), skill.name + " !", Color(1,0.88,0.4))
	if skill.has("dash"):
		var v = DIR_VEC[player.dir] * skill.dash
		player.global_position.x = clamp(player.global_position.x + v.x, 20, Data.WORLD_WIDTH-20)
		player.global_position.y = clamp(player.global_position.y + v.y, 90, Data.WORLD_HEIGHT-20)
		player.invuln_until = now + skill.invuln
	if skill.has("dmg_mult"):
		var range_px = skill.get("range", 60.0)
		flash_attack_fx(range_px)
		if not skill.get("projectile", false): player.play_attack_anim(player.dir)
		var targets = find_enemies_in_range(range_px)
		var hits = targets if skill.get("aoe", false) else (targets.slice(0,1) if targets.size() > 0 else [])
		for t in hits:
			var dmg = roll_damage(player.stats.atk, skill.dmg_mult, skill.get("crit_bonus", 0.0))
			deal_damage_to_enemy(t.e, dmg)

func find_nearest_ally_in_range(range_px: float):
	var best = null
	var best_d = range_px
	for pid in remote_players.keys():
		var rp: Player = remote_players[pid]
		if rp.dead: continue
		var d = player.global_position.distance_to(rp.global_position)
		if d <= best_d:
			best_d = d
			best = {"pid": pid, "p": rp}
	return best

func _apply_buff_to(p: Player, b: Dictionary) -> void:
	p.stats.atk += b.get("atk", 0)
	p.stats.def += b.get("def", 0)
	p.stats.spd += b.get("spd", 0)
	get_tree().create_timer(b.duration).timeout.connect(func():
		if not is_instance_valid(p): return
		p.stats.atk -= b.get("atk", 0)
		p.stats.def -= b.get("def", 0)
		p.stats.spd -= b.get("spd", 0))

@rpc("any_peer", "reliable")
func net_apply_heal(amount: float) -> void:
	player.heal(amount)
	float_text(player.global_position + Vector2(0,-50), "+%d PV (soin reçu)" % amount, Color(0.4,1,0.53))
	emit_signal("hud_update", make_hud_data())

@rpc("any_peer", "reliable")
func net_apply_buff(b: Dictionary) -> void:
	_apply_buff_to(player, b)
	emit_signal("hud_update", make_hud_data())

func roll_damage(atk: float, mult: float, extra_crit: float) -> float:
	var race = Data.RACES[char_data.race]
	var crit_chance = 0.08 + extra_crit + race.get("crit_bonus", 0.0)
	var dmg = atk * mult * randf_range(0.85, 1.15)
	if randf() < crit_chance: dmg *= 1.8
	return dmg

func flash_attack_fx(range_px: float) -> void:
	# Anneau qui s'étend rapidement depuis le joueur pour matérialiser la portée de l'attaque.
	var ring = Node2D.new()
	ring.position = player.global_position
	ring.z_index = 60
	add_child(ring)
	var mat = CanvasItemMaterial.new()
	var pts = PackedVector2Array()
	var segs = 20
	for i in range(segs + 1):
		var a = i * TAU / segs
		pts.append(Vector2(cos(a), sin(a)) * 6.0)
	var line = Line2D.new()
	line.points = pts
	line.width = 2.0
	line.default_color = Color(1, 1, 1, 0.8)
	ring.add_child(line)
	var tw = create_tween()
	tw.tween_method(func(r): line.points = _ring_points(r), 6.0, range_px, 0.18)
	tw.parallel().tween_property(line, "default_color:a", 0.0, 0.18)
	tw.tween_callback(ring.queue_free)

func _ring_points(radius: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var segs = 20
	for i in range(segs + 1):
		var a = i * TAU / segs
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

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
		if p == player:
			save_now()
			var tier = GameState.pending_talent(p.char_data)
			if not tier.is_empty(): emit_signal("talent_available", tier)
	if not partial:
		for drop in e.mdef.get("loot", []):
			if randf() < drop.chance:
				p.char_data.inventory[drop.id] = p.char_data.inventory.get(drop.id, 0) + 1
				float_text(p.global_position + Vector2(0,-20), "+1 " + Data.ITEMS[drop.id].name, Color(0.75,1,0.75))
				register_drop_for_quests(drop.id)
	update_quest_progress("kill", e.type_id)
	if e.mdef.get("boss", false): update_quest_progress("boss", e.type_id)
	if p.char_data.bounty != null and p.char_data.bounty.target == e.type_id and p == player:
		p.char_data.bounty.progress = min(p.char_data.bounty.count, p.char_data.bounty.progress + 1)
		float_text(p.global_position + Vector2(0,-90), "Prime: %d/%d" % [p.char_data.bounty.progress, p.char_data.bounty.count], Color(1,0.75,0.3))
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
							on_player_died()
							if hud: hud.fade_out(0.5)
		else:
			e.velocity = Vector2.ZERO
			e.set_anim(e.dir, false)
		e.update_visuals()

var bloodstain_node: Node2D = null

func on_player_died() -> void:
	# Mécanique "tache de sang" : la mort a un coût. La moitié de l'or est perdue et
	# laissée sur place, récupérable une seule fois. Si le joueur meurt à nouveau avant
	# de la récupérer, cet or est perdu pour de bon (seule la tache la plus récente compte).
	if bloodstain_node and is_instance_valid(bloodstain_node):
		bloodstain_node.queue_free()
		bloodstain_node = null
	var lost = int(char_data.gold / 2.0)
	if lost > 0:
		char_data.gold -= lost
		char_data.bloodstain = {"x": player.global_position.x, "y": player.global_position.y, "gold": lost}
		spawn_bloodstain_marker()
		float_text(player.global_position + Vector2(0,-60), "-%d or (tache de sang)" % lost, Color(0.7,0.15,0.15))
	save_now()

func spawn_bloodstain_marker() -> void:
	if not char_data.bloodstain: return
	var b = char_data.bloodstain
	bloodstain_node = Node2D.new()
	bloodstain_node.position = Vector2(b.x, b.y)
	bloodstain_node.z_index = 5
	var stain = ColorRect.new()
	stain.color = Color(0.4, 0.05, 0.08, 0.75)
	stain.size = Vector2(28, 20)
	stain.position = Vector2(-14, -6)
	bloodstain_node.add_child(stain)
	var label = Label.new()
	label.text = "💀"
	label.add_theme_font_size_override("font_size", 16)
	label.position = Vector2(-8, -30)
	bloodstain_node.add_child(label)
	$Decor.add_child(bloodstain_node)

func reclaim_bloodstain() -> void:
	if not char_data.bloodstain: return
	char_data.gold += char_data.bloodstain.gold
	float_text(player.global_position + Vector2(0,-40), "+%d or récupéré" % char_data.bloodstain.gold, Color(1,0.88,0.4))
	char_data.bloodstain = null
	if bloodstain_node and is_instance_valid(bloodstain_node):
		bloodstain_node.queue_free()
		bloodstain_node = null
	emit_signal("hud_update", make_hud_data())
	save_now()

func handle_respawn(delta: float) -> void:
	if respawn_at < 0:
		respawn_at = Time.get_ticks_msec()/1000.0 + 3.0
		float_text(player.global_position + Vector2(0,-40), "Réapparition...", Color(1,1,1))
	if Time.get_ticks_msec()/1000.0 > respawn_at:
		respawn_at = -1.0
		# Réapparaît à l'entrée de la zone où le joueur est mort (pas toujours au village),
		# pour éviter d'avoir à retraverser toute la carte après une mort en zone avancée.
		player.respawn(get_zone_spawn(death_zone_id))
		emit_signal("hud_update", make_hud_data())
		if hud: hud.fade_in(0.5)

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
	for c in chest_nodes:
		if c.opened: continue
		var d = player.global_position.distance_to(Vector2(c.x, c.y))
		if d < best_d: best_d = d; nearest = {"type":"chest", "ref": c}
	if char_data.bloodstain:
		var b = char_data.bloodstain
		var d = player.global_position.distance_to(Vector2(b.x, b.y))
		if d < best_d: best_d = d; nearest = {"type":"bloodstain", "ref": null}
	near_target = nearest
	if nearest == null:
		emit_signal("near_update", "")
	elif nearest.type == "bloodstain":
		emit_signal("near_update", "Récupérer %d or" % char_data.bloodstain.gold)
	elif nearest.type == "npc":
		emit_signal("near_update", nearest.ref.npc.name)
	elif nearest.type == "chest":
		emit_signal("near_update", "Ouvrir le coffre")
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
	elif near_target.type == "chest":
		open_chest(near_target.ref)
	elif near_target.type == "bloodstain":
		reclaim_bloodstain()

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
const NETWORK_GRACE_PERIOD := 2.0 # laisse le temps à tous les pairs de charger World.tscn
# avant d'émettre le moindre RPC — sinon un pair encore en chargement peut se faire déconnecter
# (Godot ferme la connexion si un RPC cible un nœud "World" qui n'existe pas encore chez lui).
var network_uptime: float = 0.0

func network_tick(delta: float) -> void:
	network_uptime += delta
	if network_uptime < NETWORK_GRACE_PERIOD: return
	net_send_accum += delta
	if net_send_accum > 0.066:
		net_send_accum = 0.0
		rpc("net_pos", player.global_position.x, player.global_position.y, player.dir, player.velocity.length() > 5.0, player.hp, player.stats.max_hp)
	if is_sim:
		net_enemy_accum += delta
		if net_enemy_accum > 0.2:
			net_enemy_accum = 0.0
			# On ne diffuse que les ennemis proches d'au moins un joueur : évite d'envoyer
			# tout le monde (potentiellement 60+ ennemis) dans un seul paquet UDP au-delà
			# du MTU, ce qui cause des pertes de paquets voire des déconnexions.
			var relevance_range = 1400.0
			var player_positions = [player.global_position]
			for pid in remote_players.keys():
				player_positions.append(remote_players[pid].global_position)
			var snap := []
			for uid in enemies.keys():
				var e: Enemy = enemies[uid]
				var near = false
				for pp in player_positions:
					if e.global_position.distance_to(pp) < relevance_range: near = true; break
				if not near: continue
				snap.append({"uid": uid, "type_id": e.type_id, "x": e.global_position.x, "y": e.global_position.y, "hp": e.hp, "max_hp": e.max_hp, "dead": e.dead, "dir": e.dir})
			if not snap.is_empty():
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
