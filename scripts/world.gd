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
var teleporter_nodes: Array = []
var player_camera: Camera2D = null
const CAMERA_ZOOM_MIN := 0.9
const CAMERA_ZOOM_MAX := 2.6
const CAMERA_ZOOM_STEP := 0.15
const NPC_WANDER_RADIUS := 45.0
const NPC_WANDER_SPEED := 26.0
var event_accum: float = 0.0
var next_event_at: float = 0.0
const ZONE_EVENT_INTERVAL_MIN := 90.0
const ZONE_EVENT_INTERVAL_MAX := 180.0
var economy_tick_accum: float = 0.0
# Économie villageoise simulée : une cueilleuse récolte des herbes, l'alchimiste
# les transforme en potions en arrière-plan, et le prix en boutique varie selon
# le stock disponible (offre/demande simple). Rend le village un peu "vivant"
# même quand le joueur n'interagit avec personne. Première version volontairement
# simple — le maillon "un guerrier réduit la population de monstres pour les
# cueilleurs" n'est pas encore simulé (le joueur en tient déjà ce rôle en jeu réel).
var village_economy := {
	"herbe_stock": 12, "potion_stock": 6, "potion_price": 15,
	"minerai_stock": 10, "arme_stock": 3, "arme_price": 40,
	"monsters_culled": 0,
}
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

const ECONOMY_TICK_INTERVAL := 12.0

func update_village_economy(delta: float) -> void:
	economy_tick_accum += delta
	if economy_tick_accum < ECONOMY_TICK_INTERVAL: return
	economy_tick_accum = 0.0
	var e = village_economy
	e.herbe_stock += randi_range(1, 3) # la cueilleuse ramène sa récolte
	while e.herbe_stock >= 4 and e.potion_stock < 20:
		e.herbe_stock -= 4
		e.potion_stock += 1 # l'alchimiste transforme les herbes en potions
	e.potion_price = clampi(25 - e.potion_stock, 8, 25) # plus de stock = moins cher
	e.minerai_stock += randi_range(1, 2) # un mineur ramène du minerai
	while e.minerai_stock >= 6 and e.arme_stock < 10:
		e.minerai_stock -= 6
		e.arme_stock += 1 # Grondar forge une arme de plus
	e.arme_price = clampi(70 - e.arme_stock * 5, 25, 70) # plus de stock = moins cher
	_cull_plaine_monsters()

# Dernier maillon de l'économie vivante : Garde Ren patrouille la plaine et
# abat de temps en temps un monstre, réduisant la pression sur les cueilleurs
# qui y récoltent (le lien "un guerrier réduit la population de monstres pour
# les cueilleurs" mentionné à l'origine, laissé de côté dans les premières
# versions car le joueur tenait déjà ce rôle en jeu réel).
func _cull_plaine_monsters() -> void:
	if not is_sim: return
	if randf() > 0.35: return # patrouille pas systématique, sinon la plaine se viderait trop vite
	var candidates = []
	for uid in enemies.keys():
		var e = enemies[uid]
		if not is_instance_valid(e) or e.dead or e.mdef.get("boss", false): continue
		if e.mdef.zone != "plaine": continue
		candidates.append(e)
	if candidates.is_empty(): return
	var target = candidates[randi() % candidates.size()]
	var pos = target.global_position
	target.die()
	village_economy.monsters_culled = village_economy.get("monsters_culled", 0) + 1
	on_enemy_killed(target, 0) # killer_id 0 : personne ne touche l'xp/le loot, juste le respawn programmé
	if player.global_position.distance_to(pos) < 500.0:
		float_text(pos + Vector2(0, -30), "Garde Ren a repoussé un monstre", Color(0.6, 0.8, 1.0))

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
	next_event_at = randf_range(ZONE_EVENT_INTERVAL_MIN, ZONE_EVENT_INTERVAL_MAX)
	draw_world()
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.color = Color(1, 1, 1)
	add_child(canvas_modulate)
	spawn_local_player()
	var start_zid = Data.zone_at(player.global_position.x, player.global_position.y).id
	current_zone_light_id = start_zid
	canvas_modulate.color = ZONE_LIGHT.get(start_zid, Color(1, 1, 1))
	build_npcs()
	refresh_quest_icons()
	build_teleporters()
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

## Densité d'arbres par zone, en arbres pour 1M px² — proportionnelle à la
## surface plutôt qu'un total fixe, pour que l'ambiance d'une zone ne dépende
## pas de la taille du monde (cf. draw_world() et test_decor_density).
## La forêt est de très loin la plus dense : c'est une FORÊT, elle avait
## exactement la même densité que la plaine et le marais auparavant.
const TREE_DENSITY := {
	"village": 22.0, # clairsemé : c'est un village aménagé, pas un bois
	"plaine": 30.0,  # prairie, bosquets épars
	"foret": 85.0,   # sous-bois dense
	"caverne": 0.0,  # sous terre : rochers à la place
	"marais": 34.0,  # arbres humides et bosquets
}
const WILDS_TREE_DENSITY := 12.0 # coins non revendiqués entre les bras de la croix
## Ennemis pour 1M px². Valeur choisie pour laisser la population TOTALE
## quasi inchangee (56 -> 58) : il s'agit de corriger la repartition inegale
## introduite par la carte en croix, pas de rééquilibrer la difficulté.
const ENEMY_DENSITY := 6.0

## Combat : les attaques ennemies etaient instantanees et donc inevitables.
## L'ennemi s'arme maintenant pendant ENEMY_WINDUP (fenetre d'esquive), reste
## immobile pendant ce temps, puis ne touche que si la cible est encore dans
## ENEMY_STRIKE_RANGE. Il approche jusqu'a 34px : la portee de frappe est un
## peu plus large, donc il faut vraiment reculer, pas juste bouger d'un pixel.
## A 150-195 px/s, 0.45s laissent 67-88px de recul : l'esquive est faisable
## mais demande de reagir.
const ENEMY_WINDUP := 0.45
const ENEMY_STRIKE_RANGE := 48.0
const ENEMY_ATTACK_COOLDOWN := 1.0

## Archetypes de comportement. TOUS les ennemis du jeu faisaient exactement la
## meme chose : foncer sur la cible et taper au corps a corps. Aucun n'avait
## d'identite au-dela de ses statistiques, si bien qu'une zone se jouait
## comme une autre. Chaque archetype se contente de parametrer le systeme
## d'armement existant + une regle de deplacement, plutot que d'ajouter une
## IA paralelle.
##   windup   : duree d'armement (fenetre d'esquive)
##   reach    : portee au moment de la frappe
##   approach : distance a laquelle il cesse d'avancer
##   cooldown : delai entre deux attaques
const ENEMY_BEHAVIOR := {
	# Referentiel : la brute de base, lisible et sans surprise.
	"melee": {"windup": 0.45, "reach": 48.0, "approach": 34.0, "cooldown": 1.0},
	# Lourd et lent a armer, mais frappe fort et de plus loin : tres
	# telegraphie, donc esquivable si on regarde — punitif sinon.
	"bruiser": {"windup": 0.85, "reach": 72.0, "approach": 40.0, "cooldown": 1.7, "dmg_mult": 1.3},
	# Loups : piquent, frappent, puis DECROCHENT avant de revenir. Armement
	# court (peu de temps pour reagir) compense par les temps de retrait.
	"charger": {"windup": 0.30, "reach": 52.0, "approach": 34.0, "cooldown": 1.5, "retreat": 0.9, "standoff": 150.0},
	# Gobelins : fuient sous un seuil de vie. Il faut les achever ou les
	# laisser partir, au lieu de rester plante a echanger des coups.
	"skittish": {"windup": 0.45, "reach": 48.0, "approach": 34.0, "cooldown": 1.0, "flee_below": 0.35},
	# Squelettes : gardent leurs distances et tirent un projectile. Force a
	# fermer la distance au lieu d'attendre que l'ennemi vienne a soi.
	"ranged": {"windup": 0.70, "reach": 260.0, "approach": 180.0, "cooldown": 2.1, "projectile": true},
}

func enemy_behavior(e: Enemy) -> Dictionary:
	# behavior_override permet a une phase de boss de CHANGER son style de
	# combat en cours d'affrontement (voir _on_boss_phase) : il faut alors
	# reapprendre le rythme au lieu de repeter la meme parade.
	var key = e.behavior_override if e.behavior_override != "" else e.mdef.get("behavior", "melee")
	return ENEMY_BEHAVIOR.get(key, ENEMY_BEHAVIOR["melee"])
const TUFT_DENSITY := 24.0       # touffes d'herbe pour 1M px², tout le monde confondu

## Teinte du sol par zone : la forêt réutilise la texture de terre du marais,
## mais teintée en vert pour évoquer un sous-bois — sans cette teinte, elle
## rendait un sol brun identique au marais, donnant à la « Forêt de Sylvombre »
## l'aspect d'un terrain nu (aucune texture d'herbe n'existe dans les assets).
const GROUND_TINT := {
	"foret": Color(0.62, 0.85, 0.55, 0.75),
	"marais": Color(0.78, 0.82, 0.62, 0.85),
}
const GROUND_TINT_DEFAULT := Color(0.8, 0.8, 0.8, 0.85)

const GROUND_TEXTURES := {
	"caverne": ["res://assets/tiles/ground/gravel_0.png", "res://assets/tiles/ground/gravel_1.png", "res://assets/tiles/ground/gravel_2.png", "res://assets/tiles/ground/gravel_3.png"],
	"marais": ["res://assets/tiles/ground/dirt_0.png", "res://assets/tiles/ground/dirt_1.png", "res://assets/tiles/ground/dirt_2.png", "res://assets/tiles/ground/dirt_3.png"],
	"foret": ["res://assets/tiles/ground/dirt_0.png", "res://assets/tiles/ground/dirt_1.png", "res://assets/tiles/ground/dirt_2.png", "res://assets/tiles/ground/dirt_3.png"],
}

func draw_world() -> void:
	var zones_node = $Zones
	seed(777)
	# Fond neutre sous tout le monde : les quatre zones sauvages rayonnent en
	# croix depuis le village (voir Data.ZONES) et ne couvrent donc plus tout
	# le rectangle englobant — les coins entre les bras de la croix ("Terres
	# Sauvages", Data.VOID_ZONE) doivent avoir une couleur de sol plutôt que
	# d'afficher le fond de scène brut.
	var base_rect = ColorRect.new()
	base_rect.color = Data.VOID_ZONE.bg
	base_rect.position = Vector2.ZERO
	base_rect.size = Vector2(Data.WORLD_WIDTH, Data.WORLD_HEIGHT)
	base_rect.z_index = -11
	zones_node.add_child(base_rect)
	for key in Data.ZONES.keys():
		var z = Data.ZONES[key]
		var rect = ColorRect.new()
		rect.color = z.bg
		rect.position = Vector2(z.x0, z.y0)
		rect.size = Vector2(z.x1 - z.x0, z.y1 - z.y0)
		rect.z_index = -10
		zones_node.add_child(rect)
		if GROUND_TEXTURES.has(key):
			_build_ground_mosaic(z)
		var label = Label.new()
		label.text = z.name
		label.position = Vector2(z.x0 + 40, z.y0 + 20)
		label.add_theme_font_size_override("font_size", 22)
		label.z_index = -9
		zones_node.add_child(label)
		if not z.safe:
			var lvl = Label.new()
			lvl.text = "Niv. %d-%d" % [z.lvl[0], z.lvl[1]]
			lvl.position = Vector2(z.x0 + 40, z.y0 + 50)
			lvl.z_index = -9
			zones_node.add_child(lvl)
	# Décor générique : arbres + bosquets, désormais réparti PAR ZONE selon sa
	# surface et sa densité propre (voir TREE_DENSITY). L'ancienne dispersion
	# globale à nombre fixe (420 arbres sur toute la boîte englobante) est
	# devenue inadaptée avec la carte en croix : la boîte est passée de 11.0M à
	# 27.0M px², dont ~56% hors de toute zone nommée, si bien que la majorité
	# des arbres tombait dans les coins vides et que les zones jouables se sont
	# vidées (mesuré : 152 arbres au lieu de 420, la forêt ressemblant à un
	# terrain nu). Voir test_decor_density.
	var tree_tex = load("res://assets/tiles/small_tree.png")
	seed(1234)
	for key in Data.ZONES.keys():
		var z = Data.ZONES[key]
		var density = TREE_DENSITY.get(key, 20.0)
		if density <= 0.0: continue # caverne : sous terre, rochers à la place
		var area_m = ((z.x1 - z.x0) * (z.y1 - z.y0)) / 1000000.0
		for i in range(int(area_m * density)):
			_spawn_tree(tree_tex, randi_range(int(z.x0) + 40, int(z.x1) - 40), randi_range(int(z.y0) + 40, int(z.y1) - 40))
	# Terres sauvages (coins entre les bras de la croix) : boisées légèrement
	# pour ne pas traverser du vide en passant d'un bras à l'autre.
	var wilds_area_m = (Data.WORLD_WIDTH * Data.WORLD_HEIGHT) / 1000000.0
	for i in range(int(wilds_area_m * WILDS_TREE_DENSITY)):
		var wx = randi_range(60, int(Data.WORLD_WIDTH) - 60)
		var wy = randi_range(60, int(Data.WORLD_HEIGHT) - 60)
		if Data.zone_at(wx, wy).id != Data.VOID_ZONE.id: continue # déjà traité par la passe par zone
		_spawn_tree(tree_tex, wx, wy)
	# rochers dans la caverne (formes procédurales, pas des arbres déguisés)
	var cav = Data.ZONES.caverne
	for i in range(70):
		var x = randi_range(int(cav.x0) + 60, int(cav.x1) - 60)
		var y = randi_range(int(cav.y0) + 60, int(cav.y1) - 60)
		_spawn_rock(x, y)
	# petites touffes d'herbe (points de couleur) pour casser l'uniformité du fond
	# — proportionnelles à la surface du monde pour la même raison que les arbres.
	for i in range(int(((Data.WORLD_WIDTH * Data.WORLD_HEIGHT) / 1000000.0) * TUFT_DENSITY)):
		var x = randi_range(20, int(Data.WORLD_WIDTH) - 20)
		var y = randi_range(20, int(Data.WORLD_HEIGHT) - 20)
		var tuft = ColorRect.new()
		var shade = randf_range(-0.08, 0.1)
		var base = Data.zone_at(x, y).bg
		tuft.color = Color(clamp(base.r+shade,0,1), clamp(base.g+shade+0.05,0,1), clamp(base.b+shade,0,1), 0.55)
		tuft.size = Vector2(randf_range(10,26), randf_range(6,12))
		tuft.position = Vector2(x, y)
		tuft.z_index = -8
		$Decor.add_child(tuft)

	build_village_structures()
	build_props()
	build_plaine_decor()
	build_foret_decor()
	build_caverne_decor()
	build_marais_decor()

func build_plaine_decor() -> void:
	# La plaine était restée plate/verte alors que le village a été détaillé —
	# bottes de foin, clôtures de pâture et parterres sauvages pour marquer
	# une zone traversée par des voyageurs, sans la rendre aussi "aménagée"
	# que le village.
	var plaine = Data.ZONES.plaine
	seed(5577)
	var wild_colors = [Color(0.9,0.85,0.3), Color(0.85,0.4,0.5), Color(0.6,0.5,0.85)]
	for i in range(60):
		var x = randi_range(int(plaine.x0) + 60, int(plaine.x1) - 60)
		var y = randi_range(int(plaine.y0) + 140, int(plaine.y1) - 40)
		var patch = Node2D.new()
		patch.position = Vector2(x, y)
		patch.z_index = -7
		for j in range(3):
			var dot = ColorRect.new()
			dot.color = wild_colors[randi() % wild_colors.size()]
			dot.size = Vector2(3, 3)
			dot.position = Vector2(randf_range(-6,6), randf_range(-4,4))
			patch.add_child(dot)
		$Decor.add_child(patch)
	for i in range(14):
		var x = randi_range(int(plaine.x0) + 80, int(plaine.x1) - 80)
		var y = randi_range(int(plaine.y0) + 140, int(plaine.y1) - 40)
		_spawn_hay_bale(x, y)
	for i in range(10):
		var x = randi_range(int(plaine.x0) + 80, int(plaine.x1) - 80)
		var y = randi_range(int(plaine.y0) + 140, int(plaine.y1) - 40)
		_spawn_rock(x, y)

func build_foret_decor() -> void:
	# La forêt n'avait que les mêmes arbres génériques que toutes les autres
	# zones (juste plus denses) : aucun décor qui lui soit propre, contrairement
	# au village et à la plaine. Champignons, troncs abattus et lucioles pour
	# un sous-bois reconnaissable, cohérent avec l'éclairage tamisé déjà en place.
	var foret = Data.ZONES.foret
	seed(9911)
	for i in range(45):
		var x = randi_range(int(foret.x0) + 60, int(foret.x1) - 60)
		var y = randi_range(int(foret.y0) + 140, int(foret.y1) - 40)
		_spawn_mushroom_cluster(x, y)
	for i in range(16):
		var x = randi_range(int(foret.x0) + 80, int(foret.x1) - 80)
		var y = randi_range(int(foret.y0) + 140, int(foret.y1) - 40)
		_spawn_fallen_log(x, y)
	for i in range(28):
		var x = randi_range(int(foret.x0) + 40, int(foret.x1) - 40)
		var y = randi_range(int(foret.y0) + 100, int(foret.y1) - 20)
		_spawn_firefly(x, y)

func _spawn_mushroom_cluster(x: int, y: int) -> void:
	var count = randi_range(2, 4)
	var cap_color = Color(0.85, 0.25, 0.2) if randf() < 0.5 else Color(0.7, 0.55, 0.35)
	for i in range(count):
		var ox = randf_range(-8, 8)
		var oy = randf_range(-4, 4)
		var stem = ColorRect.new()
		stem.color = Color(0.9, 0.85, 0.75)
		stem.size = Vector2(2, 4)
		stem.position = Vector2(x + ox - 1, y + oy)
		stem.z_index = int(y / 2.0)
		$Decor.add_child(stem)
		var cap = Polygon2D.new()
		var r = randf_range(3, 5)
		var pts = PackedVector2Array()
		for j in range(8):
			var a = j / 8.0 * PI # demi-cercle : un chapeau, pas un disque complet
			pts.append(Vector2(cos(a), -sin(a)) * r)
		cap.polygon = pts
		cap.color = cap_color
		cap.position = Vector2(x + ox, y + oy - 3)
		cap.z_index = int(y / 2.0) + 1
		$Decor.add_child(cap)

func _spawn_fallen_log(x: int, y: int) -> void:
	var log_len = randf_range(28, 44)
	var body = ColorRect.new()
	body.color = Color(0.35, 0.24, 0.14)
	body.size = Vector2(log_len, 8)
	body.position = Vector2(x - log_len / 2.0, y - 4)
	body.rotation = randf_range(-0.15, 0.15)
	body.z_index = int(y / 2.0)
	$Decor.add_child(body)
	var end_cap = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(10):
		var a = i / 10.0 * TAU
		pts.append(Vector2(cos(a), sin(a)) * 4)
	end_cap.polygon = pts
	end_cap.color = Color(0.55, 0.42, 0.28)
	end_cap.position = Vector2(x - log_len / 2.0, y)
	end_cap.z_index = int(y / 2.0) + 1
	$Decor.add_child(end_cap)

func _spawn_firefly(x: int, y: int) -> void:
	var glow = PointLight2D.new()
	glow.texture = _radial_light_texture()
	glow.position = Vector2(x, y)
	glow.color = Color(0.75, 1.0, 0.55)
	glow.energy = 0.5
	glow.texture_scale = 0.35
	glow.z_index = int(y / 2.0) + 3
	$Decor.add_child(glow)
	var dx = randf_range(-14, 14)
	var dy = randf_range(-10, 10)
	var drift = create_tween().set_loops()
	drift.tween_property(glow, "position", Vector2(x + dx, y + dy), randf_range(2.5, 4.0)).set_trans(Tween.TRANS_SINE)
	drift.tween_property(glow, "position", Vector2(x, y), randf_range(2.5, 4.0)).set_trans(Tween.TRANS_SINE)
	var pulse = create_tween().set_loops()
	pulse.tween_property(glow, "energy", 0.9, 0.6).set_trans(Tween.TRANS_SINE).set_delay(randf())
	pulse.tween_property(glow, "energy", 0.15, 0.8).set_trans(Tween.TRANS_SINE)

func build_caverne_decor() -> void:
	# Les rochers génériques donnaient une ambiance minérale correcte, mais rien
	# ne distinguait vraiment une grotte d'un simple terrain rocailleux : ni
	# cristaux, ni ossements (pourtant thématiquement liés aux squelettes du
	# lieu), ni lumière de torches pour percer la pénombre déjà en place
	# (ZONE_LIGHT.caverne).
	var cav = Data.ZONES.caverne
	seed(4488)
	for i in range(24):
		var x = randi_range(int(cav.x0) + 60, int(cav.x1) - 60)
		var y = randi_range(int(cav.y0) + 120, int(cav.y1) - 60)
		_spawn_crystal_cluster(x, y)
	for i in range(20):
		var x = randi_range(int(cav.x0) + 60, int(cav.x1) - 60)
		var y = randi_range(int(cav.y0) + 120, int(cav.y1) - 60)
		_spawn_bone_pile(x, y)
	for i in range(12):
		var x = randi_range(int(cav.x0) + 80, int(cav.x1) - 80)
		var y = randi_range(int(cav.y0) + 120, int(cav.y1) - 60)
		_spawn_torch(x, y)

func _spawn_crystal_cluster(x: int, y: int) -> void:
	var count = randi_range(2, 3)
	var base_hue = Color(0.4, 0.75, 0.95) if randf() < 0.5 else Color(0.75, 0.45, 0.95)
	for i in range(count):
		var ox = randf_range(-6, 6)
		var oy = randf_range(-3, 3)
		var h = randf_range(10, 18)
		var w = h * 0.4
		var shard = Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(0, -h), Vector2(w, -h * 0.3), Vector2(w * 0.6, 0), Vector2(-w * 0.6, 0), Vector2(-w, -h * 0.3)
		])
		shard.color = base_hue.lightened(randf_range(-0.1, 0.2))
		shard.position = Vector2(x + ox, y + oy)
		shard.z_index = int(y / 2.0)
		$Decor.add_child(shard)
	var glow = PointLight2D.new()
	glow.texture = _radial_light_texture()
	glow.position = Vector2(x, y - 8)
	glow.color = base_hue
	glow.energy = 0.7
	glow.texture_scale = 0.8
	glow.z_index = int(y / 2.0) + 2
	$Decor.add_child(glow)
	var pulse = create_tween().set_loops()
	pulse.tween_property(glow, "energy", 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_delay(randf())
	pulse.tween_property(glow, "energy", 0.5, 1.4).set_trans(Tween.TRANS_SINE)

func _spawn_bone_pile(x: int, y: int) -> void:
	var count = randi_range(3, 5)
	for i in range(count):
		var bone = ColorRect.new()
		bone.color = Color(0.82, 0.8, 0.72)
		var bone_len = randf_range(6, 12)
		bone.size = Vector2(bone_len, 2)
		bone.position = Vector2(x + randf_range(-8, 8) - bone_len / 2.0, y + randf_range(-5, 5))
		bone.rotation = randf_range(0, PI)
		bone.z_index = int(y / 2.0)
		$Decor.add_child(bone)

func build_marais_decor() -> void:
	# Le marais n'avait que les arbres/touffes génériques : aucune eau stagnante,
	# aucun roseau, aucun feu follet pour évoquer un bourbier hanté par les
	# zombies, contrairement aux trois autres zones déjà détaillées.
	var marais = Data.ZONES.marais
	seed(6633)
	for i in range(34):
		var x = randi_range(int(marais.x0) + 60, int(marais.x1) - 60)
		var y = randi_range(int(marais.y0) + 140, int(marais.y1) - 40)
		_spawn_reed_cluster(x, y)
	for i in range(22):
		var x = randi_range(int(marais.x0) + 60, int(marais.x1) - 60)
		var y = randi_range(int(marais.y0) + 140, int(marais.y1) - 40)
		_spawn_murky_puddle(x, y)
	for i in range(16):
		var x = randi_range(int(marais.x0) + 80, int(marais.x1) - 80)
		var y = randi_range(int(marais.y0) + 100, int(marais.y1) - 20)
		_spawn_will_o_wisp(x, y)

func _spawn_reed_cluster(x: int, y: int) -> void:
	var count = randi_range(3, 5)
	for i in range(count):
		var ox = randf_range(-10, 10)
		var h = randf_range(14, 24)
		var blade = Polygon2D.new()
		blade.polygon = PackedVector2Array([Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0.5, -h)])
		blade.color = Color(0.35, 0.42, 0.22) if randf() < 0.6 else Color(0.45, 0.36, 0.2)
		blade.position = Vector2(x + ox, y)
		blade.z_index = int(y / 2.0)
		$Decor.add_child(blade)
		var sway = create_tween().set_loops()
		sway.tween_property(blade, "rotation", randf_range(0.08, 0.16), randf_range(1.2, 1.8)).set_trans(Tween.TRANS_SINE).set_delay(randf())
		sway.tween_property(blade, "rotation", -randf_range(0.08, 0.16), randf_range(1.2, 1.8)).set_trans(Tween.TRANS_SINE)

func _spawn_murky_puddle(x: int, y: int) -> void:
	var puddle = Polygon2D.new()
	var w = randf_range(18, 34)
	var h = w * randf_range(0.4, 0.55)
	var pts = PackedVector2Array()
	for i in range(10):
		var a = i / 10.0 * TAU
		var jitter = randf_range(0.85, 1.15)
		pts.append(Vector2(cos(a) * w / 2.0, sin(a) * h / 2.0) * jitter)
	puddle.polygon = pts
	puddle.color = Color(0.16, 0.2, 0.12, 0.65)
	puddle.position = Vector2(x, y)
	puddle.z_index = -6
	$Decor.add_child(puddle)
	# Bulles de gaz occasionnelles : le marais a l'air vivant, pas juste peint au sol.
	var ripple = create_tween().set_loops()
	ripple.tween_property(puddle, "scale", Vector2(1.06, 1.06), randf_range(1.5, 2.2)).set_trans(Tween.TRANS_SINE).set_delay(randf() * 2.0)
	ripple.tween_property(puddle, "scale", Vector2(1.0, 1.0), randf_range(1.5, 2.2)).set_trans(Tween.TRANS_SINE)

func _spawn_will_o_wisp(x: int, y: int) -> void:
	var glow = PointLight2D.new()
	glow.texture = _radial_light_texture()
	glow.position = Vector2(x, y)
	glow.color = Color(0.55, 0.95, 0.75)
	glow.energy = 0.55
	glow.texture_scale = 0.45
	glow.z_index = int(y / 2.0) + 3
	$Decor.add_child(glow)
	var dx = randf_range(-20, 20)
	var dy = randf_range(-16, 16)
	var drift = create_tween().set_loops()
	drift.tween_property(glow, "position", Vector2(x + dx, y + dy), randf_range(3.0, 5.0)).set_trans(Tween.TRANS_SINE)
	drift.tween_property(glow, "position", Vector2(x, y), randf_range(3.0, 5.0)).set_trans(Tween.TRANS_SINE)
	var pulse = create_tween().set_loops()
	pulse.tween_property(glow, "energy", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_delay(randf())
	pulse.tween_property(glow, "energy", 0.2, 0.9).set_trans(Tween.TRANS_SINE)

func _spawn_hay_bale(x: int, y: int) -> void:
	var bale = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(12):
		var a = i / 12.0 * TAU
		pts.append(Vector2(cos(a), sin(a) * 0.75) * 11)
	bale.polygon = pts
	bale.color = Color(0.75, 0.62, 0.28)
	bale.position = Vector2(x, y)
	bale.z_index = int(y / 2.0)
	$Decor.add_child(bale)
	var band = ColorRect.new()
	band.color = Color(0.55, 0.42, 0.15)
	band.size = Vector2(20, 3)
	band.position = Vector2(x - 10, y - 1)
	band.z_index = int(y / 2.0) + 1
	$Decor.add_child(band)

func build_village_structures() -> void:
	# Bâtiments : murs procéduraux + vrai sprite de toit (tuiles LPC) pour une silhouette
	# bien plus lisible que le triangle plat d'avant.
	var roof_tan = load("res://assets/buildings/roof_tan.png")
	var roof_brown = load("res://assets/buildings/roof_brown.png")
	# Chaque maison est alignée avec le PNJ qui "y habite" (forge = Grondar, etc.)
	# pour que le village ait une disposition lisible au lieu de bâtiments épars.
	# Coordonnées décalées de +2000/+2000 (voir Data.ZONES) : le village garde
	# exactement sa disposition d'origine, juste recentré au milieu de la croix.
	var houses = [
		{"x":2600, "y":2530, "w":100, "h":75, "wall":Color(0.7,0.62,0.48), "roof":roof_brown}, # forge (Grondar, 2600,2600)
		{"x":2700, "y":2230, "w":90, "h":70, "wall":Color(0.75,0.65,0.5), "roof":roof_tan}, # alchimiste (Yvenne, 2700,2300)
		{"x":2500, "y":2680, "w":100, "h":75, "wall":Color(0.72,0.63,0.47), "roof":roof_tan}, # échoppe (Bosk, 2500,2750)
		{"x":2400, "y":2330, "w":80, "h":60, "wall":Color(0.76,0.66,0.5), "roof":roof_brown}, # cabane de l'Ancien (2400,2400)
		{"x":2800, "y":2430, "w":85, "h":65, "wall":Color(0.65,0.6,0.6), "roof":roof_brown}, # salle d'armes (Thoric, 2800,2500)
	]
	for h in houses:
		# ombre portée douce sous la maison
		var shadow = ColorRect.new()
		shadow.color = Color(0,0,0,0.18)
		shadow.size = Vector2(h.w + 16, h.h * 0.35)
		shadow.position = Vector2(h.x - h.w/2.0 - 8, h.y + h.h/2.0 - h.h*0.12)
		shadow.z_index = int(h.y / 2.0) - 2
		$Decor.add_child(shadow)
		# contour légèrement plus sombre derrière le mur pour donner du relief
		var outline = ColorRect.new()
		outline.color = h.wall.darkened(0.35)
		outline.size = Vector2(h.w + 4, h.h + 4)
		outline.position = Vector2(h.x - h.w/2.0 - 2, h.y - h.h/2.0 - 2)
		outline.z_index = int(h.y / 2.0) - 1
		$Decor.add_child(outline)
		var wall = ColorRect.new()
		wall.color = h.wall
		wall.size = Vector2(h.w, h.h)
		wall.position = Vector2(h.x - h.w/2.0, h.y - h.h/2.0)
		wall.z_index = int(h.y / 2.0)
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
		wall_shade.z_index = int(h.y / 2.0) + 1
		$Decor.add_child(wall_shade)
		var roof = Sprite2D.new()
		roof.texture = h.roof
		var roof_scale = (h.w + 26) / float(h.roof.get_width())
		roof.scale = Vector2(roof_scale, roof_scale)
		# Le toit doit chevaucher largement le haut du mur (comme un vrai avant-toit)
		# plutôt que de flotter au-dessus avec juste un mince contact — sinon il se
		# détache visuellement de la maison malgré un positionnement "correct" en x.
		roof.position = Vector2(h.x, h.y - h.h/2.0 - (h.roof.get_height() * roof_scale) * 0.02)
		roof.z_index = int(h.y / 2.0) + 2
		$Decor.add_child(roof)
		var door = ColorRect.new()
		door.color = Color(0.28, 0.18, 0.1)
		door.size = Vector2(18, 28)
		door.position = Vector2(h.x - 9, h.y + h.h/2.0 - 28)
		door.z_index = int(h.y / 2.0) + 3
		$Decor.add_child(door)
	_build_village_well(2700, 2480)
	_build_village_decor(houses)

func _build_village_well(x: int, y: int) -> void:
	# Puits central comme point de repère : anneau de pierre + toit en bois +
	# corde/seau, plutôt qu'un simple carré gris plat.
	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.18)
	shadow.size = Vector2(56, 16)
	shadow.position = Vector2(x - 28, y + 16)
	shadow.z_index = int(y / 2.0) - 1
	$Decor.add_child(shadow)
	var ring = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(16):
		var a = i / 16.0 * TAU
		pts.append(Vector2(cos(a), sin(a)) * 22)
	ring.polygon = pts
	ring.color = Color(0.55, 0.53, 0.5)
	ring.position = Vector2(x, y)
	ring.z_index = int(y / 2.0)
	$Decor.add_child(ring)
	var inner = Polygon2D.new()
	var pts2 = PackedVector2Array()
	for i in range(16):
		var a = i / 16.0 * TAU
		pts2.append(Vector2(cos(a), sin(a)) * 14)
	inner.polygon = pts2
	inner.color = Color(0.15, 0.22, 0.3)
	inner.position = Vector2(x, y - 3)
	inner.z_index = int(y / 2.0) + 1
	$Decor.add_child(inner)
	for side in [-1, 1]:
		var post = ColorRect.new()
		post.color = Color(0.35, 0.24, 0.14)
		post.size = Vector2(5, 26)
		post.position = Vector2(x + side * 20 - 2, y - 34)
		post.z_index = int(y / 2.0) + 2
		$Decor.add_child(post)
	var roof = Polygon2D.new()
	roof.polygon = PackedVector2Array([Vector2(-30,0), Vector2(30,0), Vector2(0,-16)])
	roof.color = Color(0.5, 0.3, 0.16)
	roof.position = Vector2(x, y - 34)
	roof.z_index = int(y / 2.0) + 3
	$Decor.add_child(roof)
	var bucket = ColorRect.new()
	bucket.color = Color(0.4, 0.28, 0.15)
	bucket.size = Vector2(8, 7)
	bucket.position = Vector2(x - 4, y - 18)
	bucket.z_index = int(y / 2.0) + 2
	$Decor.add_child(bucket)
	_add_circle_collision(x, y, 20.0)

# Collision légère et réutilisable pour les props solides (puits, caisses,
# barils, coffres) : sans ça le joueur les traverse visuellement.
func _add_circle_collision(x: float, y: float, radius: float) -> void:
	var body = StaticBody2D.new()
	body.position = Vector2(x, y)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	$Decor.add_child(body)

func _build_village_decor(houses: Array) -> void:
	# Torches près de chaque porte, parterres de fleurs et quelques caisses/barils
	# de commerce — le village était trop nu comparé aux zones sauvages.
	for h in houses:
		_spawn_torch(int(h.x - h.w/2.0 - 6), int(h.y + h.h/2.0 - 10))
	seed(9911)
	var vz = Data.ZONES.village
	var flower_colors = [Color(0.85,0.25,0.3), Color(0.9,0.75,0.2), Color(0.8,0.4,0.75), Color(0.95,0.55,0.15)]
	for i in range(45):
		var x = randi_range(int(vz.x0) + 80, int(vz.x1) - 80)
		var y = randi_range(int(vz.y0) + 150, int(vz.y1) - 40)
		var patch = Node2D.new()
		patch.position = Vector2(x, y)
		patch.z_index = -7
		for j in range(4):
			var dot = ColorRect.new()
			dot.color = flower_colors[randi() % flower_colors.size()]
			dot.size = Vector2(3, 3)
			dot.position = Vector2(randf_range(-6,6), randf_range(-4,4))
			patch.add_child(dot)
		$Decor.add_child(patch)
	var crate_spots = [Vector2(2560, 2700), Vector2(2440, 2720), Vector2(2650, 2560), Vector2(2560, 2560)]
	for i in range(crate_spots.size()):
		var pos = crate_spots[i]
		if i % 2 == 0:
			_spawn_crate(int(pos.x), int(pos.y))
		else:
			_spawn_barrel(int(pos.x), int(pos.y))

func _spawn_crate(x: int, y: int) -> void:
	var box = ColorRect.new()
	box.color = Color(0.5, 0.36, 0.2)
	box.size = Vector2(18, 16)
	box.position = Vector2(x - 9, y - 8)
	box.z_index = int(y / 2.0)
	$Decor.add_child(box)
	var edge = ColorRect.new()
	edge.color = Color(0.35, 0.24, 0.12)
	edge.size = Vector2(18, 3)
	edge.position = Vector2(x - 9, y - 8)
	edge.z_index = int(y / 2.0) + 1
	$Decor.add_child(edge)
	_add_circle_collision(x, y, 10.0)

func _spawn_barrel(x: int, y: int) -> void:
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-8,-10), Vector2(8,-10), Vector2(9,10), Vector2(-9,10)])
	body.color = Color(0.45, 0.32, 0.18)
	body.position = Vector2(x, y)
	body.z_index = int(y / 2.0)
	$Decor.add_child(body)
	for oy in [-6, 6]:
		var band = ColorRect.new()
		band.color = Color(0.25, 0.17, 0.09)
		band.size = Vector2(18, 2)
		band.position = Vector2(x - 9, y + oy)
		band.z_index = int(y / 2.0) + 1
		$Decor.add_child(band)
	_add_circle_collision(x, y, 9.0)

func build_props() -> void:
	# Coffres et torches dans les zones dangereuses, pour l'ambiance et un peu de loot passif.
	seed(4321)
	for key in Data.ZONES.keys():
		var z = Data.ZONES[key]
		if z.safe: continue
		# Densité par surface (et non plus par largeur seule) : les zones ne
		# partagent plus toutes la même hauteur depuis le passage à la croix
		# (voir Data.ZONES), un calcul basé uniquement sur x1-x0 sous-peuplerait
		# les bras plus étroits mais plus longs (ex: marais). 260*1200 = la
		# "cellule de densité" d'origine (largeur de référence x hauteur d'alors).
		var count = int(((z.x1 - z.x0) * (z.y1 - z.y0)) / (260.0 * 1200.0))
		for i in range(count):
			var x = randi_range(int(z.x0) + 100, int(z.x1) - 100)
			var y = randi_range(int(z.y0) + 60, int(z.y1) - 60)
			if randf() < 0.4:
				_spawn_torch(x, y)
			else:
				_spawn_chest(x, y)

func _spawn_torch(x: int, y: int) -> void:
	var pole = ColorRect.new()
	pole.color = Color(0.3, 0.2, 0.12)
	pole.size = Vector2(4, 20)
	pole.position = Vector2(x - 2, y - 10)
	pole.z_index = int(y / 2.0)
	$Decor.add_child(pole)
	var flame = ColorRect.new()
	flame.color = Color(1.0, 0.55, 0.15)
	flame.size = Vector2(8, 10)
	flame.position = Vector2(x - 4, y - 20)
	flame.z_index = int(y / 2.0) + 1
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
	glow.z_index = int(y / 2.0) + 2
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

func _spawn_tree(tree_tex: Texture2D, x: int, y: int) -> void:
	var spr = Sprite2D.new()
	spr.texture = tree_tex
	spr.position = Vector2(x, y)
	var is_bush = randf() < 0.35
	spr.scale = Vector2.ONE * (randf_range(0.7, 1.1) if is_bush else randf_range(1.6, 2.6))
	if is_bush:
		spr.modulate = Color(0.75, 0.95, 0.65)
	spr.z_index = int(y / 2.0)
	$Decor.add_child(spr)

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
	rock.z_index = int(y / 2.0)
	$Decor.add_child(rock)

func _spawn_chest(x: int, y: int) -> void:
	var base = ColorRect.new()
	base.color = Color(0.42, 0.28, 0.14)
	base.size = Vector2(22, 16)
	base.position = Vector2(x - 11, y - 8)
	base.z_index = int(y / 2.0)
	$Decor.add_child(base)
	var lid = ColorRect.new()
	lid.color = Color(0.55, 0.4, 0.2)
	lid.size = Vector2(22, 5)
	lid.position = Vector2(x - 11, y - 12)
	lid.pivot_offset = Vector2(0, 5) # charnière côté arrière : la couvercle bascule vers le haut
	lid.z_index = int(y / 2.0) + 1
	$Decor.add_child(lid)
	var gold = randi_range(5, 20)
	chest_nodes.append({"x": x, "y": y, "lid": lid, "base": base, "opened": false, "gold": gold})
	_add_circle_collision(x, y, 10.0)

func open_chest(c: Dictionary) -> void:
	if c.opened: return
	c.opened = true
	var tw = create_tween()
	tw.tween_property(c.lid, "rotation", -1.1, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.lid.color = Color(0.3, 0.22, 0.12) # intérieur du coffre, plus sombre une fois ouvert
	char_data.gold += c.gold
	float_text(Vector2(c.x, c.y - 24), "+%d or" % c.gold, Color(1.0, 0.85, 0.3))
	Audio.play("chest_open")
	Audio.play("gold_pickup", -6.0)
	emit_signal("hud_update", make_hud_data())

func _build_ground_mosaic(z: Dictionary) -> void:
	var paths = GROUND_TEXTURES[z.id]
	var texs = []
	for p in paths: texs.append(load(p))
	var chunk_w = 256
	var chunk_h = 256
	var x = z.x0
	while x < z.x1:
		var y = z.y0
		while y < z.y1:
			var tr = TextureRect.new()
			tr.texture = texs[randi() % texs.size()]
			tr.stretch_mode = TextureRect.STRETCH_TILE
			tr.position = Vector2(x, y)
			tr.size = Vector2(min(chunk_w, z.x1 - x), min(chunk_h, z.y1 - y))
			tr.modulate = GROUND_TINT.get(z.id, GROUND_TINT_DEFAULT)
			tr.z_index = -10
			$Zones.add_child(tr)
			y += chunk_h
		x += chunk_w

## Vecteur unitaire (axe dominant) pointant de la zone vers le village.
## Vector2.ZERO pour le village lui-même (il est sa propre référence).
func _zone_dir_to_village(z: Dictionary) -> Vector2:
	var vz = Data.ZONES.village
	var village_c = Vector2((vz.x0 + vz.x1) / 2.0, (vz.y0 + vz.y1) / 2.0)
	var zone_c = Vector2((z.x0 + z.x1) / 2.0, (z.y0 + z.y1) / 2.0)
	var d = village_c - zone_c
	if d == Vector2.ZERO: return Vector2.ZERO
	if absf(d.x) >= absf(d.y): return Vector2(signf(d.x), 0.0)
	return Vector2(0.0, signf(d.y))

## Point d'entrée (bord côté village) ou fond (bord opposé) d'une zone.
## Avant la refonte en croix, l'entrée était en dur à "x0+200" et le boss à
## "x1-200" : deux extrémités OPPOSÉES d'une bande horizontale. En passant
## les deux au centre de la zone pour être indépendant de l'orientation, on a
## fait se superposer le point d'arrivée du joueur ET le spawn du boss —
## voyager (ou réapparaître) dans une zone déposait le joueur pile sur le boss,
## donc mort immédiate. Rétablit la séparation entrée/fond, mais de façon
## orientable (chaque bras de la croix pointe dans une direction différente).
func _zone_edge_point(z: Dictionary, toward_village: bool) -> Vector2:
	var c = Vector2((z.x0 + z.x1) / 2.0, (z.y0 + z.y1) / 2.0)
	var dir = _zone_dir_to_village(z)
	if dir == Vector2.ZERO: return c
	var half_extent = ((z.x1 - z.x0) / 2.0) if dir.x != 0.0 else ((z.y1 - z.y0) / 2.0)
	var offset = maxf(0.0, half_extent - 200.0)
	return c + dir * offset * (1.0 if toward_village else -1.0)

func get_zone_spawn(zone_id: String) -> Vector2:
	# On arrive/réapparaît par le bord de la zone le plus proche du village,
	# jamais en plein centre (où se tient le boss) — voir _zone_edge_point().
	return _zone_edge_point(Data.ZONES[zone_id], true)

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
	player_camera = cam

const NPC_HAIR_COLORS := [
	Color(0.25, 0.16, 0.1),  # brun
	Color(0.07, 0.06, 0.06), # noir
	Color(0.55, 0.4, 0.15),  # blond fonce
	Color(0.78, 0.65, 0.3),  # blond
	Color(0.4, 0.12, 0.06),  # roux
	Color(0.6, 0.6, 0.63),   # gris
]

func build_teleporters() -> void:
	# Le voyage rapide n'existait que via un menu abstrait (touche M) : ajoute
	# un vrai portail visible et interactif dans chaque zone (façon "Zaap"),
	# repère de navigation en plus de l'option de menu qui reste disponible.
	for zid in Data.ZONES.keys():
		var z = Data.ZONES[zid]
		# À l'entrée de la zone (là où le voyage rapide dépose le joueur), pas
		# au centre : le portail sert de repère « vous arrivez ici », et le
		# centre est désormais sur le trajet vers le boss.
		var pos = get_zone_spawn(zid) + Vector2(0, 90)
		var node = Node2D.new()
		node.position = pos
		node.z_index = int(pos.y / 2.0)
		var ring = Polygon2D.new()
		ring.polygon = _ring_points(26.0)
		ring.color = Color(0.55, 0.35, 0.95, 0.8)
		node.add_child(ring)
		var inner = Polygon2D.new()
		inner.polygon = _ring_points(14.0)
		inner.color = Color(0.85, 0.7, 1.0, 0.9)
		node.add_child(inner)
		var tw = create_tween().set_loops()
		tw.tween_property(ring, "scale", Vector2(1.15, 1.15), 1.0).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ring, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
		var label = Label.new()
		label.text = "Téléporteur"
		label.position = Vector2(-45, -52)
		label.size = Vector2(90, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
		node.add_child(label)
		$Decor.add_child(node)
		teleporter_nodes.append({"zone": zid, "x": pos.x, "y": pos.y})

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
		# `node` est l'ancre de déplacement (sa position = l'emplacement réel du
		# PNJ dans le monde, bougée par le vagabondage ci-dessous) ; `visual` est
		# un enfant purement local qui porte l'animation de respiration, pour que
		# les deux mouvements (vagabondage + respiration) ne se marchent pas dessus
		# en se disputant la même propriété "position".
		var node = Node2D.new()
		node.position = Vector2(npc.x, npc.y)
		node.z_index = int(npc.y / 2.0) # sinon le PNJ reste toujours derrière les maisons (z_index en centaines)
		var visual = Node2D.new()
		node.add_child(visual)
		var legs = Sprite2D.new()
		legs.texture = npc_legs_tex
		legs.region_enabled = true; legs.region_rect = region
		legs.z_index = 0
		visual.add_child(legs)
		var spr = Sprite2D.new()
		spr.texture = npc_body_tex
		spr.region_enabled = true
		spr.region_rect = region
		spr.modulate = npc.tint
		spr.z_index = 1
		visual.add_child(spr)
		var vest = Sprite2D.new()
		vest.texture = vest_texs[idx % vest_texs.size()]
		vest.region_enabled = true; vest.region_rect = region
		vest.z_index = 2
		visual.add_child(vest)
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
		visual.add_child(hair)
		var head = Sprite2D.new()
		head.texture = npc_head_tex
		head.region_enabled = true
		head.region_rect = region
		head.modulate = npc.tint
		head.z_index = 3
		visual.add_child(head)
		idx += 1
		# petite animation d'idle (respiration) — locale à `visual`, ne bouge plus
		# jamais `node` (qui appartient désormais au vagabondage).
		var tw = create_tween().set_loops()
		tw.tween_property(visual, "position:y", -2.0, 1.1).set_trans(Tween.TRANS_SINE).set_delay(randf()*1.0)
		tw.tween_property(visual, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
		var label = Label.new()
		label.text = npc.name
		label.position = Vector2(-50, -54)
		label.size = Vector2(100, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(1, 0.88, 0.4))
		visual.add_child(label)
		var icon = Label.new()
		icon.text = "$" if npc.role == "shop" else ("*" if npc.role == "profession" else "!")
		icon.position = Vector2(-8, -72)
		icon.add_theme_font_size_override("font_size", 18)
		icon.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		visual.add_child(icon)
		$NPCs.add_child(node)
		# Collision légère pour que le joueur ne marche pas littéralement à travers/
		# par-dessus le PNJ. Enfant de `node` (pas de `visual`) : suit le
		# vagabondage mais ignore la respiration, qui reste purement cosmétique.
		var npc_body = StaticBody2D.new()
		var npc_shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 12.0
		npc_shape.shape = circle
		npc_body.add_child(npc_shape)
		node.add_child(npc_body)
		npc_nodes.append({
			"npc": npc, "node": node, "icon": icon,
			"home": Vector2(npc.x, npc.y), "wander_state": "idle",
			"wander_target": Vector2(npc.x, npc.y),
			"wander_next_at": Time.get_ticks_msec() / 1000.0 + randf_range(1.0, 6.0),
		})

func update_npc_wander(delta: float) -> void:
	# Les PNJ restaient figés en permanence sur un seul point (hors la petite
	# respiration verticale) : ils vagabondent maintenant sur un rayon modeste
	# autour de leur poste, pour rester facilement trouvables (nom/icône les
	# suivent) tout en donnant l'impression d'un village vivant.
	var now = Time.get_ticks_msec() / 1000.0
	for entry in npc_nodes:
		match entry.wander_state:
			"idle":
				if now > entry.wander_next_at:
					var angle = randf() * TAU
					var dist = randf_range(20.0, NPC_WANDER_RADIUS)
					entry.wander_target = entry.home + Vector2(cos(angle), sin(angle)) * dist
					entry.wander_state = "walking"
			"walking":
				var to_target = entry.wander_target - entry.node.position
				var step = NPC_WANDER_SPEED * delta
				if to_target.length() <= step:
					entry.node.position = entry.wander_target
					entry.wander_state = "idle"
					entry.wander_next_at = now + randf_range(3.0, 8.0)
				else:
					entry.node.position += to_target.normalized() * step

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
		# Proportionnel a la surface, comme TREE_DENSITY. Un nombre FIXE (14)
		# par zone donnait une densite tres inegale depuis que les bras de la
		# croix n'ont plus tous la meme taille : foret et marais (1400x2000 =
		# 2.80 Mpx2) tombaient a 5.0 ennemis/Mpx2 contre 6.5 pour la plaine
		# (1800x1200 = 2.16), soit ~23% plus vides — alors que ce sont
		# justement les zones de milieu et de fin de progression.
		var area_m = ((z.x1 - z.x0) * (z.y1 - z.y0)) / 1000000.0
		var count = maxi(1, int(area_m * ENEMY_DENSITY))
		for i in range(count):
			var x = randi_range(int(z.x0) + 80, int(z.x1) - 80)
			var y = randi_range(int(z.y0) + 120, int(z.y1) - 60)
			var tid = types[i % types.size()]
			var sd = {"x": x, "y": y, "type_id": tid, "respawn_at": 0.0}
			enemy_spawns.append(sd)
			spawn_enemy(sd)
		for t in by_zone[zone_id]:
			if Data.MONSTER_TYPES[t].get("boss", false):
				# Au fond de la zone, à l'opposé du point d'arrivée du joueur :
				# il faut traverser la zone pour l'affronter (voir
				# _zone_edge_point() pour le bug que ça corrige).
				var boss_pos = _zone_edge_point(z, false)
				var sd = {"x": boss_pos.x, "y": boss_pos.y, "type_id": t, "respawn_at": 0.0, "is_boss": true}
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

# ---------------- Événements de zone ----------------
# Le monde n'avait aucun événement dynamique : rien ne se passait jamais en
# dehors des actions du joueur. Toutes les quelques minutes, une horde
# surgit près du joueur dans la zone dangereuse où il se trouve, avec une
# annonce diffusée à tout le groupe. Cote hote uniquement (comme le reste
# de l'IA ennemie) ; les clients voient les nouveaux ennemis apparaître
# naturellement via le mécanisme de snapshot déjà existant.
func update_zone_events(delta: float) -> void:
	event_accum += delta
	if event_accum < next_event_at: return
	event_accum = 0.0
	next_event_at = randf_range(ZONE_EVENT_INTERVAL_MIN, ZONE_EVENT_INTERVAL_MAX)
	trigger_zone_event()

func trigger_zone_event() -> void:
	var zid = Data.zone_at(player.global_position.x, player.global_position.y).id
	# "village" = zone sûre, "wilds" = terres non revendiquées entre les bras de
	# la croix (Data.VOID_ZONE), ni l'une ni l'autre n'est une clé de Data.ZONES.
	if zid == "village" or zid == "wilds": return
	var z = Data.ZONES[zid]
	var types = []
	for tid in Data.MONSTER_TYPES.keys():
		var m = Data.MONSTER_TYPES[tid]
		if m.zone == zid and not m.get("boss", false): types.append(tid)
	if types.is_empty(): return
	var chosen_type = types[randi() % types.size()]
	var count = randi_range(4, 6)
	var cx = clampf(player.global_position.x + randf_range(-350.0, 350.0), z.x0 + 60, z.x1 - 60)
	var cy = clampf(player.global_position.y + randf_range(-350.0, 350.0), z.y0 + 60, z.y1 - 60)
	for i in range(count):
		var x = clampf(cx + randf_range(-150.0, 150.0), z.x0 + 40, z.x1 - 40)
		var y = clampf(cy + randf_range(-150.0, 150.0), z.y0 + 40, z.y1 - 40)
		var sd = {"x": x, "y": y, "type_id": chosen_type, "respawn_at": 0.0}
		var e = spawn_enemy(sd)
		e.set_meta("spawn_def", null) # pas de réapparition après la mort : évite une croissance sans fin de la population
	var msg = "Une horde de %s envahit %s !" % [Data.MONSTER_TYPES[chosen_type].name, z.name]
	announce_zone_event(msg)

func announce_zone_event(msg: String) -> void:
	float_text(player.global_position + Vector2(0, -140), msg, Color(1, 0.35, 0.2))
	if Net.is_online:
		rpc("net_zone_event_announce", msg)

@rpc("authority", "reliable")
func net_zone_event_announce(msg: String) -> void:
	float_text(player.global_position + Vector2(0, -140), msg, Color(1, 0.35, 0.2))

## Une phase de boss ne savait faire qu'UNE chose : invoquer des renforts. Un
## boss n'etait donc que de la piétaille avec plus de PV, au rythme identique
## du debut a la fin. Une phase peut desormais aussi changer son style de
## combat ou le mettre en rage — il faut reagir au lieu de repeter la meme
## parade jusqu'au bout.
func _on_boss_phase(boss: Enemy, phase: Dictionary) -> void:
	if phase.has("summon"):
		float_text(boss.global_position + Vector2(0,-70), "%s invoque des renforts !" % boss.mdef.name, Color(1,0.4,0.2))
		for i in range(phase.get("count", 1)):
			var ang = randf() * TAU
			var offset = Vector2(cos(ang), sin(ang)) * 70.0
			var sd = {"x": boss.global_position.x + offset.x, "y": boss.global_position.y + offset.y, "type_id": phase.summon, "respawn_at": 0.0}
			var add = spawn_enemy(sd)
			add.set_meta("spawn_def", null) # les renforts ne réapparaissent pas après leur mort
	if phase.has("behavior"):
		boss.behavior_override = phase.behavior
		float_text(boss.global_position + Vector2(0,-70), "%s change de tactique !" % boss.mdef.name, Color(1,0.75,0.2))
		spawn_telegraph_fx(boss, 90.0, 0.6)
	if phase.has("enrage"):
		var r = phase.enrage
		boss.rage_atk *= r.get("atk", 1.0)
		boss.rage_spd *= r.get("spd", 1.0)
		float_text(boss.global_position + Vector2(0,-70), "%s entre en rage !" % boss.mdef.name, Color(1,0.25,0.15))
		_camera_shake(7.0, 0.3)
		Audio.play("death", -4.0, 0.15)

# ---------------- Boucle ----------------
func _physics_process(delta: float) -> void:
	if player.dead:
		handle_respawn(delta)
		return
	handle_movement(delta)
	player.update_visuals()
	update_near_interactable()
	update_gather_respawns(delta)
	# Purement cosmétique et non synchronisé sur le réseau (comme l'idle bob
	# déjà existant) : deux joueurs peuvent voir un PNJ à une position
	# légèrement différente dans son rayon de vagabondage. Accepté comme
	# compromis simple — contrairement aux ennemis, l'interaction PNJ reste
	# correcte cote local puisque near_target suit la position réelle du nœud.
	update_npc_wander(delta)

	if is_sim:
		update_enemies(delta)
		update_zone_events(delta)

	for pid in remote_players.keys():
		if is_instance_valid(remote_players[pid]):
			remote_players[pid].update_visuals()

	if Net.is_online:
		network_tick(delta)

	hud_tick_accum += delta
	if hud_tick_accum > 0.4:
		hud_tick_accum = 0.0
		emit_signal("hud_update", make_hud_data())
		var zid = Data.zone_at(player.global_position.x, player.global_position.y).id
		# "wilds" (Data.VOID_ZONE) = terres non revendiquées entre les bras de la
		# croix, pas une clé de Data.ZONES : Data.ZONES[zid] planterait, et ce
		# n'est de toute façon pas un lieu valide à retenir comme point de mort
		# ou à débloquer pour le voyage rapide — on garde juste la dernière
		# vraie zone connue tant qu'on n'a pas retraversé dans une zone nommée.
		if zid != "wilds":
			death_zone_id = zid
			update_zone_lighting(zid)
			Audio.set_zone_mood(Data.ZONES[zid].safe)
			if not char_data.unlocked_zones.has(zid):
				char_data.unlocked_zones.append(zid)
				float_text(player.global_position + Vector2(0,-90), "Zone découverte : voyage rapide débloqué", Color(0.7,1,0.85))

	autosave_accum += delta
	if autosave_accum > 20.0:
		autosave_accum = 0.0
		save_now()

	update_village_economy(delta)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and player != null:
		save_now()

func save_now() -> void:
	char_data.last_x = player.global_position.x
	char_data.last_y = player.global_position.y
	char_data.hp = player.hp
	char_data.mana = player.mana
	GameState.save_character()

func quit_to_menu() -> void:
	save_now()
	if Net.is_online: Net.disconnect_all()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

## Roulade universelle. Le joueur n'avait aucune option defensive hormis
## marcher (seul le voleur avait un dash de classe), alors que les ennemis
## telegraphient desormais leurs coups et que les boss posent de larges zones :
## il manquait la reponse ACTIVE a ces signaux. Les i-frames durent un peu plus
## longtemps que le deplacement lui-meme, pour couvrir la reception.
const DODGE_SPEED := 1000.0
const DODGE_TIME := 0.2
const DODGE_INVULN := 0.35
const DODGE_COOLDOWN := 1.6

## Direction dictee par les touches actuellement enfoncees ; ZERO si immobile.
func _current_input_dir() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): v.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): v.x += 1
	return v.normalized()

func try_dodge() -> void:
	if player.dead: return
	if hud and hud.is_chat_focused(): return
	var now = Time.get_ticks_msec() / 1000.0
	if now < player.cooldowns.get("dodge", 0.0): return
	if now < player.dodge_until: return
	# On roule vers la ou le joueur se DIRIGE ; s'il est immobile, vers son
	# regard. Rouler toujours vers le regard donnerait l'impression de ne pas
	# repondre a l'intention du joueur.
	var d = _current_input_dir()
	if d == Vector2.ZERO: d = DIR_VEC[player.dir]
	player.dodge_dir = d
	player.dodge_until = now + DODGE_TIME
	player.cooldowns["dodge"] = now + DODGE_COOLDOWN
	player.invuln_until = now + DODGE_INVULN
	spawn_dodge_fx(player.global_position)
	Audio.play("ui_click", -8.0, 0.25)

## Anneau bref au point de depart : rend la roulade lisible en coop, ou l'on
## voit surtout les autres joueurs de loin.
func spawn_dodge_fx(pos: Vector2) -> void:
	var ring = Node2D.new()
	ring.position = pos
	ring.z_index = 60
	add_child(ring)
	var line = Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.8, 0.95, 1.0, 0.8)
	line.points = _ring_points(10.0)
	ring.add_child(line)
	var tw = create_tween()
	tw.tween_method(func(r): line.points = _ring_points(r), 10.0, 46.0, DODGE_TIME)
	tw.parallel().tween_property(line, "default_color:a", 0.0, DODGE_TIME)
	tw.tween_callback(ring.queue_free)

func handle_movement(delta: float) -> void:
	# is_physical_key_pressed() lit l'état brut du clavier, sans passer par le
	# système de focus GUI : sans ce garde, taper "s"/"d" dans le chat déplace
	# aussi le personnage.
	if hud and hud.is_chat_focused():
		player.velocity = Vector2.ZERO
		player.set_anim(player.dir, false)
		return
	# Roulade en cours : le mouvement est impose, l'entree clavier est ignoree.
	# On passe par move_and_slide (et non par une teleportation comme le dash du
	# voleur) pour que la roulade respecte les collisions — sans quoi elle
	# permettrait de traverser maisons et decors.
	var now_d = Time.get_ticks_msec() / 1000.0
	if now_d < player.dodge_until:
		player.velocity = player.dodge_dir * DODGE_SPEED
		player.move_and_slide()
		player.global_position.x = clamp(player.global_position.x, 20, Data.WORLD_WIDTH - 20)
		player.global_position.y = clamp(player.global_position.y, 90, Data.WORLD_HEIGHT - 20)
		player.set_anim(player.dir, true)
		return
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
		KEY_SHIFT: try_dodge()

func _unhandled_input(event: InputEvent) -> void:
	# Aucun moyen de zoomer/dézoomer n'existait : le niveau de zoom de la
	# caméra était figé, aucune adaptation possible aux préférences du joueur
	# ou à la situation (combat rapproché vs vue d'ensemble).
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_camera_zoom(CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_camera_zoom(-CAMERA_ZOOM_STEP)

func _adjust_camera_zoom(delta: float) -> void:
	if player_camera == null: return
	var z = clampf(player_camera.zoom.x + delta, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	player_camera.zoom = Vector2(z, z)

func _shake_offsets(strength: float) -> Array:
	# Suite de décalages d'amplitude décroissante pour une secousse caméra qui
	# s'estompe naturellement, toujours terminée par un retour exact à zéro
	# (sinon la caméra pourrait rester décalée si l'appel est interrompu).
	var steps = 6
	var offs = []
	for i in range(steps):
		var mag = strength * (1.0 - float(i) / steps)
		offs.append(Vector2(randf_range(-mag, mag), randf_range(-mag, mag)))
	offs.append(Vector2.ZERO)
	return offs

func _camera_shake(strength: float = 6.0, duration: float = 0.18) -> void:
	# Les coups critiques (et autres gros impacts) n'avaient aucun "punch" —
	# seul le texte de dégâts changeait de couleur. Une petite secousse caméra
	# donne un vrai retour physique, sans exagérer au point de gêner la lisibilité.
	if player_camera == null: return
	var offsets = _shake_offsets(strength)
	var tw = create_tween()
	var step_time = duration / offsets.size()
	for off in offsets:
		tw.tween_property(player_camera, "offset", off, step_time)

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
	flash_attack_fx(range_px, Color(1, 0.95, 0.8))
	player.play_attack_anim(player.dir)
	var targets = find_enemies_in_range(range_px)
	if targets.is_empty(): return
	var roll = roll_damage(player.stats.atk, 1.0, 0.0)
	deal_damage_to_enemy(targets[0].e, roll.dmg, roll.crit)
	spawn_hit_particles(targets[0].e.global_position, Color(1, 0.9, 0.7) if not roll.crit else Color(1, 0.5, 0.15), 6 if not roll.crit else 14)
	Audio.play("attack_hit", -4.0, 0.1)

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
	Audio.play("skill_cast", -3.0, 0.06)

	if skill.has("heal"):
		var heal_range = skill.get("range", 180.0)
		var ally = find_nearest_ally_in_range(heal_range) if skill.get("party", false) else null
		if ally != null:
			rpc_id(ally.pid, "net_apply_heal", skill.heal)
			spawn_heal_fx(ally.p)
			float_text(ally.p.global_position + Vector2(0,-50), "+%d PV" % skill.heal, Color(0.4,1,0.53))
			float_text(player.global_position + Vector2(0,-50), "Soin envoyé à %s" % ally.p.char_data.name, Color(0.6,0.85,1))
		else:
			player.heal(skill.heal)
			spawn_heal_fx(player)
			float_text(player.global_position + Vector2(0,-50), "+%d PV" % skill.heal, Color(0.4,1,0.53))
	if skill.has("shield"):
		var shield_range = skill.get("range", 180.0)
		var ally_s = find_nearest_ally_in_range(shield_range) if skill.get("party", false) else null
		if ally_s != null:
			rpc_id(ally_s.pid, "net_apply_shield", skill.shield, skill.duration)
			spawn_shield_fx(ally_s.p)
			float_text(ally_s.p.global_position + Vector2(0,-50), "+%d Bouclier" % skill.shield, Color(0.6,0.85,1))
		else:
			_apply_shield_to(player, skill.shield, skill.duration)
			spawn_shield_fx(player)
			float_text(player.global_position + Vector2(0,-50), "+%d Bouclier" % skill.shield, Color(0.6,0.85,1))
	if skill.has("buff"):
		var b = skill.buff
		_apply_buff_to(player, b)
		spawn_buff_fx(player)
		float_text(player.global_position + Vector2(0,-50), skill.name + " !", Color(1,0.88,0.4))
		if skill.get("party", false):
			var buff_range = skill.get("range", 0.0)
			if buff_range <= 0: buff_range = 220.0 # 0 = "portée illimitée locale" -> zone raisonnable autour du lanceur
			for pid in remote_players.keys():
				if not is_instance_valid(remote_players[pid]): continue
				var rp: Player = remote_players[pid]
				if rp.dead: continue
				if player.global_position.distance_to(rp.global_position) <= buff_range:
					rpc_id(pid, "net_apply_buff", b)
					spawn_buff_fx(rp)
					float_text(rp.global_position + Vector2(0,-50), skill.name + " !", Color(1,0.88,0.4))
	if skill.has("dash"):
		var v = DIR_VEC[player.dir] * skill.dash
		player.global_position.x = clamp(player.global_position.x + v.x, 20, Data.WORLD_WIDTH-20)
		player.global_position.y = clamp(player.global_position.y + v.y, 90, Data.WORLD_HEIGHT-20)
		player.invuln_until = now + skill.invuln
	if skill.has("dmg_mult"):
		var range_px = skill.get("range", 60.0)
		var fx_color = skill.get("fx_color", Color(1, 1, 1))
		flash_attack_fx(range_px, fx_color)
		if not skill.get("projectile", false): player.play_attack_anim(player.dir)
		var targets = find_enemies_in_range(range_px)
		var hits = targets if skill.get("aoe", false) else (targets.slice(0,1) if targets.size() > 0 else [])
		var apply_hits = func():
			for t in hits:
				# Le projectile a un temps de vol : la cible a pu mourir/être libérée
				# entre-temps (tuée par un allié, changement de zone...).
				if not is_instance_valid(t.e) or t.e.dead: continue
				var roll = roll_damage(player.stats.atk, skill.dmg_mult, skill.get("crit_bonus", 0.0))
				deal_damage_to_enemy(t.e, roll.dmg, roll.crit)
				spawn_hit_particles(t.e.global_position, fx_color, 10 if not roll.crit else 18)
				if skill.has("immobilize") and not t.e.dead: t.e.apply_immobilize(skill.immobilize)
				if skill.has("slow_pct") and not t.e.dead: t.e.apply_slow(1.0 - skill.slow_pct, skill.slow_duration)
		if skill.get("projectile", false) and hits.size() > 0:
			# L'orbe voyage visiblement jusqu'à la cible avant que les dégâts s'appliquent.
			spawn_projectile_fx(player.global_position, hits[0].e.global_position, fx_color, apply_hits)
		else:
			apply_hits.call()

func find_nearest_ally_in_range(range_px: float):
	var best = null
	var best_d = range_px
	for pid in remote_players.keys():
		if not is_instance_valid(remote_players[pid]): continue
		var rp: Player = remote_players[pid]
		if rp.dead: continue
		var d = player.global_position.distance_to(rp.global_position)
		if d <= best_d:
			best_d = d
			best = {"pid": pid, "p": rp}
	return best

func _apply_shield_to(p: Player, amount: float, duration: float) -> void:
	p.shield = amount
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(p): p.shield = 0.0)

@rpc("any_peer", "reliable")
func net_apply_shield(amount: float, duration: float) -> void:
	_apply_shield_to(player, amount, duration)
	spawn_shield_fx(player)
	float_text(player.global_position + Vector2(0,-50), "+%d Bouclier (reçu)" % amount, Color(0.6,0.85,1))
	emit_signal("hud_update", make_hud_data())

func spawn_heal_fx(target: Player) -> void:
	# Étincelles vertes montantes sur la cible soignée, au lieu d'un simple texte.
	var p = CPUParticles2D.new()
	p.position = target.global_position + Vector2(0, -10)
	p.z_index = 65
	p.emitting = true
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.6
	p.explosiveness = 0.5
	p.direction = Vector2.UP
	p.spread = 25.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, -20)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = Color(0.4, 1.0, 0.55)
	add_child(p)
	get_tree().create_timer(0.9).timeout.connect(func():
		if is_instance_valid(p): p.queue_free())

func spawn_buff_fx(target: Player, color: Color = Color(1, 0.88, 0.4)) -> void:
	# Anneau qui s'élève et s'estompe autour du personnage buffé.
	var ring = Node2D.new()
	ring.position = target.global_position
	ring.z_index = 63
	add_child(ring)
	var pts = PackedVector2Array()
	for i in range(16):
		var a = i / 16.0 * TAU
		pts.append(Vector2(cos(a), sin(a)) * 18)
	var circle = Polygon2D.new()
	circle.polygon = pts
	circle.color = Color(color.r, color.g, color.b, 0.35)
	ring.add_child(circle)
	var tw = create_tween()
	tw.tween_property(ring, "position:y", ring.position.y - 30.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(circle, "scale", Vector2(1.4, 1.4), 0.5)
	tw.parallel().tween_property(circle, "modulate:a", 0.0, 0.5)
	tw.tween_callback(ring.queue_free)

func spawn_shield_fx(target: Player) -> void:
	spawn_buff_fx(target, Color(0.5, 0.75, 1.0))

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

@rpc("authority", "reliable")
func net_enemy_attack(dmg: float) -> void:
	# L'hote a decide qu'un ennemi nous touche (IA cote hote uniquement, et il
	# a deja verifie la portee a la fin de l'armement) ; la mitigation reelle
	# (def, bouclier, invulnerabilite) s'applique ici avec NOS propres stats,
	# exactement comme pour un coup subi localement — d'ou le helper commun.
	apply_enemy_hit_to_local(dmg)

@rpc("any_peer", "reliable")
func net_apply_buff(b: Dictionary) -> void:
	_apply_buff_to(player, b)
	emit_signal("hud_update", make_hud_data())

func roll_damage(atk: float, mult: float, extra_crit: float) -> Dictionary:
	# Les critiques existaient déjà (8%+ de chance, x1.8 dégâts) mais étaient
	# invisibles : même texte blanc, même nombre de particules qu'un coup normal.
	# Renvoie maintenant si le coup est critique pour que l'appelant puisse le
	# faire ressentir (texte distinct, plus de particules, secousse caméra).
	var race = Data.RACES[char_data.race]
	var crit_chance = 0.08 + extra_crit + race.get("crit_bonus", 0.0)
	var dmg = atk * mult * randf_range(0.85, 1.15)
	var is_crit = randf() < crit_chance
	if is_crit: dmg *= 1.8
	return {"dmg": dmg, "crit": is_crit}

func flash_attack_fx(range_px: float, color: Color = Color(1, 1, 1)) -> void:
	# Anneau qui s'étend rapidement depuis le joueur pour matérialiser la portée de l'attaque,
	# teinté selon le sort (feu, glace, poison...) au lieu d'un blanc générique unique pour tout.
	var ring = Node2D.new()
	ring.position = player.global_position
	ring.z_index = 60
	add_child(ring)
	var pts = PackedVector2Array()
	var segs = 20
	for i in range(segs + 1):
		var a = i * TAU / segs
		pts.append(Vector2(cos(a), sin(a)) * 6.0)
	var line = Line2D.new()
	line.points = pts
	line.width = 3.0
	line.default_color = Color(color.r, color.g, color.b, 0.9)
	ring.add_child(line)
	var tw = create_tween()
	tw.tween_method(func(r): line.points = _ring_points(r), 6.0, range_px, 0.18)
	tw.parallel().tween_property(line, "default_color:a", 0.0, 0.18)
	tw.tween_callback(ring.queue_free)

func spawn_hit_particles(pos: Vector2, color: Color, count: int = 10) -> void:
	# Éclat de particules colorées à l'impact — donne un vrai "punch" visuel
	# aux sorts au lieu d'un simple texte de dégâts qui apparaît.
	var p = CPUParticles2D.new()
	p.position = pos
	p.z_index = 65
	p.emitting = true
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.4
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 240)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	add_child(p)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(p): p.queue_free())

func spawn_projectile_fx(from_pos: Vector2, to_pos: Vector2, color: Color, on_arrive: Callable) -> void:
	# Orbe lumineux qui voyage visiblement du lanceur à la cible avant que les
	# dégâts s'appliquent, au lieu d'un impact instantané malgré le tag "projectile".
	var orb = Node2D.new()
	orb.position = from_pos
	orb.z_index = 62
	add_child(orb)
	var glow = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in range(10):
		var a = i / 10.0 * TAU
		pts.append(Vector2(cos(a), sin(a)) * 6.0)
	glow.polygon = pts
	glow.color = color
	orb.add_child(glow)
	var dist = from_pos.distance_to(to_pos)
	var duration = clampf(dist / 700.0, 0.08, 0.4)
	var tw = create_tween()
	tw.tween_property(orb, "position", to_pos, duration).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func():
		orb.queue_free()
		on_arrive.call())

func _ring_points(radius: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var segs = 20
	for i in range(segs + 1):
		var a = i * TAU / segs
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts

func deal_damage_to_enemy(e: Enemy, dmg: float, is_crit: bool = false) -> void:
	if is_sim:
		var applied = e.take_damage(dmg)
		if is_crit:
			float_text(e.global_position + Vector2(0,-46), "-%d CRITIQUE !" % int(round(applied)), Color(1,0.35,0.1))
			_camera_shake(6.0, 0.18)
		else:
			float_text(e.global_position + Vector2(0,-40), "-%d" % int(round(applied)), Color(1,1,1))
		if e.dead: on_enemy_killed(e, multiplayer.get_unique_id())
	else:
		rpc_id(1, "net_attack_request", e.uid, dmg)
		if is_crit:
			float_text(e.global_position + Vector2(0,-46), "-%d CRITIQUE !" % int(round(dmg)), Color(1,0.35,0.1,0.6))
			_camera_shake(6.0, 0.18)
		else:
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
	# set_meta(key, null) EFFACE la clé plutôt que d'y stocker null (comportement
	# Godot) : get_meta("spawn_def", null) déclenchait donc une erreur console
	# ("no meta values with the key") à chaque mort d'un renfort de boss ou d'un
	# ennemi d'invasion (voir trigger_zone_event), qui effacent tous deux cette
	# clé pour empêcher leur réapparition.
	var sd = e.get_meta("spawn_def") if e.has_meta("spawn_def") else null
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


# ---------------- Chat ----------------
# Aucun moyen de communiquer en jeu n'existait alors que c'est un jeu coop
# jusqu'à 4 joueurs : seul l'hôte a des connexions directes à tous les clients
# (topologie étoile via ENet), donc un client relaie son message via l'hôte
# (net_chat_request) qui le rediffuse ensuite à tout le monde (net_chat_receive).
func send_chat_message(text: String) -> void:
	text = text.strip_edges()
	if text == "": return
	if text.length() > 140: text = text.substr(0, 140)
	if is_sim:
		_broadcast_chat(char_data.name, text)
	else:
		rpc_id(1, "net_chat_request", char_data.name, text)

@rpc("any_peer", "reliable")
func net_chat_request(sender_name: String, text: String) -> void:
	if not is_sim: return
	_broadcast_chat(sender_name, text)

func _broadcast_chat(sender_name: String, text: String) -> void:
	if hud: hud.add_chat_message(sender_name, text)
	if Net.is_online:
		rpc("net_chat_receive", sender_name, text)

@rpc("authority", "reliable")
func net_chat_receive(sender_name: String, text: String) -> void:
	if hud: hud.add_chat_message(sender_name, text)

func grant_kill_rewards(p: Player, e: Enemy, partial: bool) -> void:
	var xp_amount = int(e.mdef.xp * 0.5) if partial else e.mdef.xp
	var res = p.gain_xp(xp_amount)
	float_text(p.global_position + Vector2(0,-60), "+%d XP" % res.amount, Color(1,0.88,0.4))
	if res.leveled:
		float_text(p.global_position + Vector2(0,-80), "NIVEAU %d !" % p.char_data.level, Color(1,0.4,1))
		if p == player:
			Audio.play("level_up", -2.0)
			save_now()
			var tier = GameState.pending_talent(p.char_data)
			if not tier.is_empty(): emit_signal("talent_available", tier)
	if not partial:
		for drop in e.mdef.get("loot", []):
			if randf() < drop.chance:
				if GameState.add_item(p.char_data, drop.id, 1) > 0:
					float_text(p.global_position + Vector2(0,-20), "+1 " + Data.idef(drop.id).name, Color(0.75,1,0.75))
					register_drop_for_quests(drop.id)
				elif p == player:
					float_text(p.global_position + Vector2(0,-20), "Sac plein ! (%s perdu)" % Data.idef(drop.id).name, Color(1,0.5,0.35))
		_roll_gear_drop(p, e)
	update_quest_progress("kill", e.type_id)
	if e.mdef.get("boss", false): update_quest_progress("boss", e.type_id)
	if p.char_data.bounty != null and p.char_data.bounty.target == e.type_id and p == player:
		p.char_data.bounty.progress = min(p.char_data.bounty.count, p.char_data.bounty.progress + 1)
		float_text(p.global_position + Vector2(0,-90), "Prime: %d/%d" % [p.char_data.bounty.progress, p.char_data.bounty.count], Color(1,0.75,0.3))
	emit_signal("hud_update", make_hud_data())

func update_enemies(delta: float) -> void:
	for uid in enemies.keys():
		# Garde défensive : un ennemi ne devrait jamais être libéré sans être
		# aussi retiré de ce dictionnaire (voir le flux de respawn), mais mieux
		# vaut ignorer proprement une entrée invalide que planter en boucle.
		if not is_instance_valid(enemies[uid]):
			enemies.erase(uid)
			continue
		var e: Enemy = enemies[uid]
		if e.dead: continue
		var target: Player = player
		var best_d = e.global_position.distance_to(player.global_position)
		for pid in remote_players.keys():
			if not is_instance_valid(remote_players[pid]): continue
			var rp: Player = remote_players[pid]
			if rp.dead: continue
			var d = e.global_position.distance_to(rp.global_position)
			if d < best_d: best_d = d; target = rp
		var bh = enemy_behavior(e)
		# L'aggro doit couvrir la portee de l'archetype : un tireur avec 260px
		# de portee mais 150px d'aggro n'aurait JAMAIS pu s'en servir — il se
		# serait comporte comme un corps a corps qui s'arrete trop loin.
		var aggro_range = maxf(260.0 if e.mdef.get("boss", false) else 150.0, bh.reach + 40.0)
		var now_t = Time.get_ticks_msec() / 1000.0
		# Une attaque armee se resout meme si la cible s'est eloignee : c'est
		# exactement ce qui permet de l'esquiver en reculant. Resolu AVANT les
		# branches de portee, sinon fuir laisserait l'armement en suspens et
		# l'attaque tomberait des le retour du joueur.
		if e.windup_until > 0.0 and now_t >= e.windup_until:
			e.windup_until = 0.0
			_resolve_enemy_strike(e, target)
		var winding_up = e.windup_until > 0.0
		if best_d < aggro_range and not target.dead:
			var diff = target.global_position - e.global_position
			# Sens de deplacement voulu : +1 vers la cible, -1 pour s'en
			# eloigner, 0 pour tenir sa position. Chaque archetype ne fait que
			# choisir ce sens ; le reste du systeme est commun.
			var move_dir = 0.0
			if winding_up:
				# Engage dans son attaque : il ne poursuit pas pendant
				# l'armement, sans quoi l'esquive serait impossible.
				move_dir = 0.0
			elif bh.has("flee_below") and e.hp < e.max_hp * bh.flee_below:
				move_dir = -1.0 # blesse : decroche au lieu de mourir sur place
			elif now_t < e.retreat_until:
				move_dir = -1.0 # vient de frapper : recule avant de revenir
			elif best_d > bh.approach:
				move_dir = 1.0
			# Un ennemi qui recule s'arrete une fois a bonne distance, sinon il
			# traverserait la carte en fuyant indefiniment.
			if move_dir < 0.0 and best_d > bh.get("standoff", aggro_range):
				move_dir = 0.0
			if move_dir != 0.0:
				var v = diff.normalized() * e.effective_speed() * move_dir
				e.velocity = v
				e.move_and_slide()
				var look = diff * move_dir
				e.set_anim("right" if look.x>0 else "left" if abs(look.x)>abs(look.y) else ("down" if look.y>0 else "up"), true)
			else:
				e.velocity = Vector2.ZERO
				e.set_anim(e.dir, false)
				# Arme l'attaque au lieu de frapper immediatement : les degats
				# seront resolus apres le windup, et seulement si la cible est
				# encore a portee (voir _resolve_enemy_strike).
				# Attaque puissante de boss : zone bien plus large et armement
				# bien plus long, donc lisible mais impossible a encaisser sur
				# place — il faut sortir du cercle, pas juste reculer d'un pas.
				var slam = e.mdef.get("slam", {})
				var slam_ready = not slam.is_empty() and now_t > e.last_slam + slam.get("every", 6.0) and best_d <= slam.get("reach", 120.0)
				if not winding_up and slam_ready and now_t > e.last_attack + bh.cooldown:
					e.last_attack = now_t
					e.last_slam = now_t
					e.pending_slam = true
					e.windup_until = now_t + slam.get("windup", 1.1)
					e.play_attack_anim()
					spawn_telegraph_fx(e, slam.get("reach", 120.0), slam.get("windup", 1.1))
					float_text(e.global_position + Vector2(0, -60), "%s prépare un coup dévastateur !" % e.mdef.name, Color(1, 0.35, 0.15))
				elif not winding_up and best_d <= bh.reach and now_t > e.last_attack + bh.cooldown:
					e.last_attack = now_t
					e.windup_until = now_t + bh.windup
					e.play_attack_anim()
					spawn_telegraph_fx(e, bh.reach, bh.windup)
		else:
			e.velocity = Vector2.ZERO
			e.set_anim(e.dir, false)
		e.update_visuals()

## Tire un eventuel equipement sur la mort d'un ennemi. Avant, AUCUNE arme ni
## armure ne pouvait tomber de tout le jeu : le butin n'etait fait que de
## materiaux et d'objets de quete, donc tuer un boss ne rapportait jamais de
## piece a equiper. Les boss en laissent toujours une, avec plus de chance
## d'obtenir une rarete elevee.
func _roll_gear_drop(p: Player, e: Enemy) -> void:
	var zone_id = e.mdef.get("zone", "")
	var pool = Data.GEAR_DROPS.get(zone_id, [])
	if pool.is_empty(): return
	var is_boss = e.mdef.get("boss", false)
	if not is_boss and randf() > Data.GEAR_DROP_CHANCE: return
	var base_id = pool[randi() % pool.size()]
	var key = Data.item_key(base_id, Data.roll_rarity(Data.BOSS_GEAR_LUCK if is_boss else 0.0))
	if GameState.add_item(p.char_data, key, 1) > 0:
		if p == player:
			float_text(p.global_position + Vector2(0, -40), "✦ " + Data.item_display_name(key), Data.item_color(key))
			Audio.play("gold_pickup", -4.0)
	elif p == player:
		float_text(p.global_position + Vector2(0, -40), "Sac plein ! (%s perdu)" % Data.item_display_name(key), Color(1, 0.5, 0.35))

## Resout une attaque ennemie armee. Le coup ne porte QUE si la cible est
## encore a portee : reculer pendant l'armement fait rater l'attaque, ce qui
## donne enfin un interet au placement.
func _resolve_enemy_strike(e: Enemy, target: Player) -> void:
	if e.dead: return
	if target == null or not is_instance_valid(target) or target.dead: return
	var bh = enemy_behavior(e)
	# Une attaque puissante utilise SA portee et SES degats, pas ceux de
	# l'archetype : c'est ce qui la rend distincte d'un coup normal.
	var slam = e.mdef.get("slam", {})
	var is_slam = e.pending_slam
	e.pending_slam = false
	var reach = slam.get("reach", 120.0) if is_slam else bh.reach
	var power = slam.get("dmg_mult", 1.6) if is_slam else bh.get("dmg_mult", 1.0)
	# Les "charger" (loups) decrochent apres avoir frappe, qu'ils touchent ou
	# non : c'est ce qui donne le rythme piquer/reculer plutot qu'un corps a
	# corps colle.
	if bh.has("retreat"):
		e.retreat_until = Time.get_ticks_msec() / 1000.0 + bh.retreat
	if e.global_position.distance_to(target.global_position) > reach:
		float_text(e.global_position + Vector2(0, -30), "Esquive !", Color(0.65, 0.9, 1))
		Audio.play("ui_click", -14.0, 0.2)
		return
	if is_slam:
		spawn_hit_particles(target.global_position, Color(1, 0.5, 0.2), 16)
		_camera_shake(9.0, 0.25)
	# rage_atk : montee en puissance declenchee par une phase de boss
	var dmg = e.atk * power * e.rage_atk
	# Les tireurs envoient un projectile visible : les degats ne tombent qu'a
	# l'impact, ce qui laisse une seconde occasion de s'ecarter.
	if bh.get("projectile", false):
		var victim = target
		spawn_projectile_fx(e.global_position, target.global_position, Color(0.85, 0.9, 0.95), func():
			if is_instance_valid(victim) and not victim.dead:
				_deal_enemy_damage(victim, dmg))
		return
	_deal_enemy_damage(target, dmg)

func _deal_enemy_damage(target: Player, dmg: float) -> void:
	if target == player:
		apply_enemy_hit_to_local(dmg)
	elif Net.is_online:
		# BUG CRITIQUE trouvé en auditant le combat cote client : l'IA des
		# ennemis (update_enemies, cote hote uniquement) ne faisait JAMAIS rien
		# quand la cible la plus proche était un allié distant plutot que le
		# joueur hote lui-meme — aucun degat, aucun RPC, rien. En pratique,
		# seul l'hote pouvait etre blesse par les monstres. La mitigation
		# depend des stats propres a chaque joueur, donc c'est au pair
		# concerné d'appliquer les degats chez lui.
		rpc_id(target.peer_id, "net_enemy_attack", dmg)

## Encaissement d'un coup ennemi par le joueur LOCAL, du degat a la mort.
## Regroupe ici parce que la sequence (degats + texte + HUD + mort + fondu)
## etait dupliquee entre l'IA locale et la reception RPC : une troisieme
## source de degats aurait du re-deviner les quatre etapes.
func apply_enemy_hit_to_local(dmg: float) -> void:
	var applied = player.take_damage(dmg)
	if applied > 0:
		float_text(player.global_position + Vector2(0,-20), "-%d" % int(round(applied)), Color(1,0.4,0.4))
	emit_signal("hud_update", make_hud_data())
	if player.dead:
		float_text(player.global_position + Vector2(0,-40), "K.O.", Color(1,0.13,0.13))
		Audio.play("death")
		on_player_died()
		if hud: hud.fade_out(0.5)

## Cercle qui se resserre sur l'ennemi pendant l'armement : montre A LA FOIS
## la zone dangereuse et le temps restant avant l'impact.
func spawn_telegraph_fx(e: Enemy, reach: float = ENEMY_STRIKE_RANGE, windup: float = ENEMY_WINDUP) -> void:
	var ring = Node2D.new()
	ring.position = e.global_position
	ring.z_index = 61
	add_child(ring)
	var line = Line2D.new()
	line.width = 2.5
	# Plus l'armement est long, plus le cercle tire vers le rouge : un coup de
	# brute se distingue au premier coup d'oeil d'une morsure rapide de loup.
	var heavy = clampf((windup - 0.3) / 0.6, 0.0, 1.0)
	line.default_color = Color(1, 0.6 - 0.35 * heavy, 0.3 - 0.2 * heavy, 0.95)
	line.points = _ring_points(reach)
	ring.add_child(line)
	var tw = create_tween()
	tw.tween_method(func(r): line.points = _ring_points(r), reach, 8.0, windup)
	tw.parallel().tween_property(line, "default_color:a", 0.3, windup)
	tw.tween_callback(ring.queue_free)

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
	var now = Time.get_ticks_msec()/1000.0
	if now > respawn_at:
		respawn_at = -1.0
		# Réapparaît à l'entrée de la zone où le joueur est mort (pas toujours au village),
		# pour éviter d'avoir à retraverser toute la carte après une mort en zone avancée.
		player.respawn(get_zone_spawn(death_zone_id))
		emit_signal("hud_update", make_hud_data())
		if hud:
			hud.hide_death_screen()
			hud.fade_in(0.5)
	elif hud:
		# L'écran restait noir et vide pendant toute l'attente : affiche un
		# décompte et l'or perdu au lieu de ne rien montrer du tout.
		hud.show_death_screen(respawn_at - now, char_data.bloodstain.gold if char_data.bloodstain else 0)

# ---------------- Récolte & PNJ ----------------
func update_near_interactable() -> void:
	var nearest = null
	var best_d = 70.0
	for g in gather_nodes:
		if g.depleted: continue
		var d = player.global_position.distance_to(Vector2(g.node.x, g.node.y))
		if d < best_d: best_d = d; nearest = {"type":"gather", "ref": g}
	for n in npc_nodes:
		# Position réelle du nœud (n.node.position), pas la position de spawn
		# figée dans Data.NPCS : les PNJ vagabondent désormais autour d'elle.
		var d = player.global_position.distance_to(n.node.position)
		if d < best_d: best_d = d; nearest = {"type":"npc", "ref": n}
	for c in chest_nodes:
		if c.opened: continue
		var d = player.global_position.distance_to(Vector2(c.x, c.y))
		if d < best_d: best_d = d; nearest = {"type":"chest", "ref": c}
	if char_data.bloodstain:
		var b = char_data.bloodstain
		var d = player.global_position.distance_to(Vector2(b.x, b.y))
		if d < best_d: best_d = d; nearest = {"type":"bloodstain", "ref": null}
	for t in teleporter_nodes:
		var d = player.global_position.distance_to(Vector2(t.x, t.y))
		if d < best_d: best_d = d; nearest = {"type":"teleporter", "ref": null}
	near_target = nearest
	if nearest == null:
		emit_signal("near_update", "")
	elif nearest.type == "bloodstain":
		emit_signal("near_update", "Récupérer %d or" % char_data.bloodstain.gold)
	elif nearest.type == "npc":
		emit_signal("near_update", nearest.ref.npc.name)
	elif nearest.type == "chest":
		emit_signal("near_update", "Ouvrir le coffre")
	elif nearest.type == "teleporter":
		emit_signal("near_update", "Voyager")
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
		var mat = g.node.type
		# Sac plein : on ne consomme PAS le gisement, sinon le joueur perdrait
		# la ressource ET devrait attendre sa reapparition pour rien.
		if GameState.add_item(char_data, mat, 1) <= 0:
			float_text(Vector2(g.node.x, g.node.y - 20), "Sac plein !", Color(1,0.5,0.35))
			return
		g.depleted = true
		g.respawn_at = Time.get_ticks_msec()/1000.0 + 15.0
		g.label.modulate.a = 0.25
		float_text(Vector2(g.node.x, g.node.y - 20), "+1 " + Data.idef(mat).name, Color(0.75,1,0.75))
		char_data.gather_counts[mat] = char_data.gather_counts.get(mat, 0) + 1
		update_quest_progress("gather", mat)
		Audio.play("item_pickup", 0.0, 0.08)
		emit_signal("hud_update", make_hud_data())
	elif near_target.type == "npc":
		emit_signal("open_npc", near_target.ref.npc)
	elif near_target.type == "chest":
		open_chest(near_target.ref)
	elif near_target.type == "bloodstain":
		reclaim_bloodstain()
	elif near_target.type == "teleporter":
		if hud:
			hud.render_travel()
			hud.travel_overlay.visible = true

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
			refresh_quest_icons()

func register_drop_for_quests(item_id: String) -> void:
	for qid in char_data.quests_active.keys():
		var q = Data.get_quest(qid)
		if q.is_empty(): continue
		if q.obj.type == "gather_drop" and q.obj.target == item_id:
			char_data.quests_active[qid] = min(q.obj.count, char_data.quests_active[qid] + 1)
			emit_signal("quest_progress")
			refresh_quest_icons()
	# L'inventaire peut aussi débloquer une quête "deliver" déjà active (dont le
	# statut suit l'inventaire, pas quests_active) sans passer par la branche
	# gather_drop ci-dessus.
	refresh_quest_icons()

func npc_quest_icon_state(npc_id: String) -> String:
	# Reflète le même calcul que hud.gd:render_npc_dialogue() pour que
	# l'icône au-dessus du PNJ corresponde à ce que le dialogue affichera.
	for qid in char_data.quests_active.keys():
		var q = Data.get_quest(qid)
		if q.is_empty(): continue
		if GameState.quest_turnin_npc(qid) != npc_id: continue
		if GameState.quest_is_ready(char_data, qid): return "turnin"
	for q in Data.QUESTS:
		if q.giver != npc_id: continue
		if char_data.quests_active.has(q.id) or char_data.quests_completed.has(q.id): continue
		var ok = true
		for r in q.requires:
			if not char_data.quests_completed.has(r): ok = false; break
		if q.has("race_req") and char_data.race != q.race_req: ok = false
		if ok: return "available"
	return "none"

func refresh_quest_icons() -> void:
	for entry in npc_nodes:
		var npc = entry.npc
		if npc.role == "shop" or npc.role == "profession": continue
		var icon: Label = entry.icon
		match npc_quest_icon_state(npc.id):
			"turnin": icon.text = "?"; icon.visible = true
			"available": icon.text = "!"; icon.visible = true
			_: icon.visible = false

# ---------------- Réseau ----------------
const NETWORK_GRACE_PERIOD := 2.0 # laisse le temps à tous les pairs de charger World.tscn
# avant d'émettre le moindre RPC — sinon un pair encore en chargement peut se faire déconnecter
# (Godot ferme la connexion si un RPC cible un nœud "World" qui n'existe pas encore chez lui).
var network_uptime: float = 0.0

func network_tick(delta: float) -> void:
	# Si le pair multijoueur s'est déconnecté (coupure réseau, hôte qui ferme sa
	# partie...), inutile de continuer à spammer des RPC vers rien : ça remplissait
	# les logs d'erreurs "peer non connecté" en boucle chaque frame sans jamais
	# s'arrêter tant que World.tscn restait chargé.
	var peer = multiplayer.multiplayer_peer
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
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
				if is_instance_valid(remote_players[pid]):
					player_positions.append(remote_players[pid].global_position)
			var snap := []
			for uid in enemies.keys():
				var e: Enemy = enemies[uid]
				var near = false
				for pp in player_positions:
					if e.global_position.distance_to(pp) < relevance_range: near = true; break
				if not near: continue
				snap.append({"uid": uid, "type_id": e.type_id, "x": e.global_position.x, "y": e.global_position.y, "hp": e.hp, "max_hp": e.max_hp, "dead": e.dead, "dir": e.dir, "moving": e.velocity.length() > 5.0, "atk_t": e.last_attack})
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
		# Un client ne recevait ni l'anim de déplacement (toujours "moving=false"
		# ci-dessous) ni l'anim d'attaque (jamais déclenchée que côté hôte) :
		# les ennemis semblaient figés puis infligeaient des dégâts sans aucun
		# signal visuel pour quiconque n'était pas l'hôte.
		var just_spawned = e == null
		if just_spawned:
			e = EnemyScene.instantiate()
			$Enemies.add_child(e)
			e.setup(s.type_id, s.uid, 1)
			enemies[s.uid] = e
		e.global_position = Vector2(s.x, s.y)
		e.hp = s.hp; e.max_hp = s.max_hp
		e.set_anim(s.dir, s.get("moving", false))
		e.update_visuals()
		var atk_t = s.get("atk_t", 0.0)
		if not just_spawned and atk_t > e.last_seen_atk_t:
			e.play_attack_anim()
		e.last_seen_atk_t = atk_t
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
	# Le texte flottant (degats, XP, "CRITIQUE !"...) n'etait pas centre : pos
	# devenait le coin superieur GAUCHE du Label, donc plus le texte etait
	# long, plus il derivait vers la droite au lieu de rester au-dessus du
	# personnage/ennemi vise. Boite large + alignement centre corrige ça pour
	# n'importe quelle longueur de texte sans avoir à mesurer chaque chaîne.
	var l = Label.new()
	l.text = text
	l.size = Vector2(220, 20)
	l.position = Vector2(pos.x - 110, pos.y)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		"gold": char_data.gold, "zone": Data.zone_at(player.global_position.x, player.global_position.y).name,
	}
