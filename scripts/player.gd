extends CharacterBody2D
class_name Player

const DIR_ROW := {"up":0, "left":1, "down":2, "right":3}
const FCOUNT := 9
const FW := 64
const FH := 64

var char_data: Dictionary
var is_local: bool = false
var peer_id: int = 0
var stats: Dictionary
var hp: float
var mana: float
var dir: String = "down"
var moving: bool = false
var dead: bool = false
var cooldowns: Dictionary = {}
var invuln_until: float = 0.0
## Roulade universelle (voir world.try_dodge). Le joueur n'avait AUCUNE option
## defensive en dehors de marcher : seul le voleur possedait un dash. Depuis
## que les ennemis telegraphient leurs coups et que les boss posent de larges
## zones, il fallait une reponse active accessible a toutes les classes.
var dodge_until: float = 0.0
var dodge_dir: Vector2 = Vector2.ZERO
var buff_expiry: Array = [] # [{atk,def,spd,at}]
var shield: float = 0.0 # absorbe les dégâts avant les PV (ex: Bouclier Saint)

var body_tex: Texture2D
var legs_tex: Texture2D
var head_tex: Texture2D
var body_slash_tex: Texture2D
var head_slash_tex: Texture2D
var attacking: bool = false
const SLASH_FCOUNT := 6

@onready var legs_sprite: Sprite2D = $Legs
@onready var body_sprite: Sprite2D = $Body
@onready var vest_sprite: Sprite2D = $Vest
@onready var hair_sprite: Sprite2D = $Hair
@onready var head_sprite: Sprite2D = $Head
@onready var name_label: Label = $NameLabel
@onready var equip_icon_weapon: Sprite2D = $EquipIconWeapon
@onready var equip_icon_armor: Sprite2D = $EquipIconArmor
@onready var hp_bg: ColorRect = $HpBg
@onready var hp_fg: ColorRect = $HpFg
@onready var collider: CollisionShape2D = $CollisionShape2D

func setup(cd: Dictionary, local: bool, pid: int) -> void:
	char_data = cd
	is_local = local
	peer_id = pid
	stats = GameState.compute_stats(cd)
	hp = cd.hp if cd.get("hp") != null else stats.max_hp
	mana = cd.mana if cd.get("mana") != null else stats.max_mana
	hp = clamp(hp, 1.0, stats.max_hp)
	mana = clamp(mana, 0.0, stats.max_mana)

	body_tex = load("res://assets/sprites/player/body_walk.png")
	legs_tex = load("res://assets/sprites/player/legs_walk.png")
	head_tex = load("res://assets/sprites/player/head_walk.png")
	var vest_tex = load("res://assets/sprites/player/vest_tan_walk.png")
	var hair_tex = load("res://assets/sprites/player/hair_walk.png")
	body_slash_tex = load("res://assets/sprites/player/body_slash.png")
	head_slash_tex = load("res://assets/sprites/player/head_slash.png")

	body_sprite.texture = body_tex
	legs_sprite.texture = legs_tex
	head_sprite.texture = head_tex
	vest_sprite.texture = vest_tex
	hair_sprite.texture = hair_tex
	for spr in [body_sprite, legs_sprite, head_sprite, vest_sprite, hair_sprite]:
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 2*FH, FW, FH)
		spr.centered = true
	legs_sprite.z_index = 0
	body_sprite.z_index = 1
	vest_sprite.z_index = 2
	hair_sprite.z_index = 3
	head_sprite.z_index = 4
	hair_sprite.modulate = Color(cd.get("hair_color", "#3f2a1a"))
	var cls = Data.CLASSES[cd["class"]]
	vest_sprite.modulate = cls.color

	var race = Data.RACES[cd.race]
	body_sprite.modulate = race.tint
	head_sprite.modulate = race.tint

	name_label.text = cd.name
	name_label.modulate = Color(1, 0.88, 0.4) if is_local else Color(0.65, 0.85, 1)
	hp_fg.color = Color(0.23, 0.82, 0.23)
	update_equipment_visual()

func update_equipment_visual() -> void:
	# Pas de sprites d'armure dédiés : on teinte légèrement les jambes/le torse
	# selon l'armure équipée pour donner un indice visuel de progression.
	var race = Data.RACES[char_data.race]
	var armor_id = char_data.equipment.get("armor", "")
	if armor_id == "" or armor_id == null:
		legs_sprite.modulate = race.tint
	else:
		var armor = Data.ITEMS.get(armor_id, {})
		var def_bonus = armor.get("bonus", {}).get("def", 0)
		if def_bonus >= 8:
			legs_sprite.modulate = Color(0.55, 0.58, 0.62) # gris acier (armures lourdes)
		elif def_bonus >= 4:
			legs_sprite.modulate = Color(0.5, 0.36, 0.2) # brun cuir
		else:
			legs_sprite.modulate = race.tint
	_update_equip_icons()

func _update_equip_icons() -> void:
	var w = char_data.equipment.get("weapon", "")
	var a = char_data.equipment.get("armor", "")
	if w != "" and w != null:
		equip_icon_weapon.texture = load(Data.ICON_PATH + Data.idef(w).icon)
		equip_icon_weapon.visible = true
	else:
		equip_icon_weapon.visible = false
	if a != "" and a != null:
		equip_icon_armor.texture = load(Data.ICON_PATH + Data.idef(a).icon)
		equip_icon_armor.visible = true
	else:
		equip_icon_armor.visible = false

func set_anim(new_dir: String, is_moving: bool) -> void:
	dir = new_dir
	moving = is_moving
	if attacking: return # l'animation d'attaque a la priorité, ne pas l'écraser
	var row = DIR_ROW[dir]
	var frame = 2
	if is_moving:
		frame = int(Time.get_ticks_msec() / 100) % FCOUNT
	var rect = Rect2(frame * FW, row * FH, FW, FH)
	body_sprite.region_rect = rect
	legs_sprite.region_rect = rect
	head_sprite.region_rect = rect
	vest_sprite.region_rect = rect
	hair_sprite.region_rect = rect

func play_attack_anim(attack_dir: String) -> void:
	if attacking or dead: return
	attacking = true
	body_sprite.texture = body_slash_tex
	head_sprite.texture = head_slash_tex
	var row = DIR_ROW[attack_dir]
	var duration = 0.32
	var frame_time = duration / float(SLASH_FCOUNT)
	for i in range(SLASH_FCOUNT):
		if not is_instance_valid(self) or not attacking: return
		var rect = Rect2(i * FW, row * FH, FW, FH)
		body_sprite.region_rect = rect
		head_sprite.region_rect = rect
		await get_tree().create_timer(frame_time).timeout
	if not is_instance_valid(self): return
	body_sprite.texture = body_tex
	head_sprite.texture = head_tex
	attacking = false

func take_damage(dmg: float) -> float:
	if dead: return 0.0
	if Time.get_ticks_msec() / 1000.0 < invuln_until: return 0.0
	# Mitigation "souls-like" : la défense réduit les dégâts mais un coup fait toujours
	# mal (au moins 45% du dégât brut passe, même avec une armure lourde) — pas question
	# de tanker indéfiniment, il faut esquiver/gérer les affrontements avec prudence.
	var reduced = dmg - stats.def * 0.35
	var mitig = max(dmg * 0.45, reduced)
	# Le bouclier absorbe avant les PV (ex: Bouclier Saint du Prêtre).
	var to_hp = mitig
	if shield > 0.0:
		var absorbed = min(shield, mitig)
		shield -= absorbed
		to_hp -= absorbed
	hp = max(0.0, hp - to_hp)
	if to_hp > 0: _flash_hit()
	if hp <= 0: die()
	return mitig

# Les ennemis avaient un flash blanc au coup (voir Enemy.take_damage) mais le
# joueur n'avait AUCUN retour visuel en encaissant des dégâts — seul le texte
# flottant "-X" au-dessus de la tête. Flash rouge bref sur tous les sprites,
# en restaurant la teinte d'origine (race/équipement) au lieu d'un blanc fixe.
func _flash_hit() -> void:
	var parts = [body_sprite, head_sprite, legs_sprite, vest_sprite, hair_sprite]
	var originals = []
	for s in parts:
		originals.append(s.modulate if s else Color.WHITE)
		if s: s.modulate = Color(2.2, 0.35, 0.35)
	get_tree().create_timer(0.1).timeout.connect(func():
		for i in range(parts.size()):
			if parts[i] and is_instance_valid(parts[i]): parts[i].modulate = originals[i])

func heal(amount: float) -> void:
	if dead: return
	hp = min(stats.max_hp, hp + amount)

func die() -> void:
	dead = true
	var gray = Color(0.3, 0.3, 0.3)
	body_sprite.modulate = gray
	head_sprite.modulate = gray
	vest_sprite.modulate = gray
	hair_sprite.modulate = gray

func respawn(pos: Vector2) -> void:
	dead = false
	hp = stats.max_hp
	mana = stats.max_mana
	global_position = pos
	var race = Data.RACES[char_data.race]
	body_sprite.modulate = race.tint
	head_sprite.modulate = race.tint
	var cls = Data.CLASSES[char_data["class"]]
	vest_sprite.modulate = cls.color
	hair_sprite.modulate = Color(char_data.get("hair_color", "#3f2a1a"))

func gain_xp(amount: int) -> Dictionary:
	var race = Data.RACES[char_data.race]
	amount = int(round(amount * race.get("xp_mult", 1.0)))
	char_data.xp += amount
	var leveled = false
	while char_data.xp >= Data.xp_for_level(char_data.level) and char_data.level < 30:
		char_data.xp -= Data.xp_for_level(char_data.level)
		char_data.level += 1
		leveled = true
	if leveled:
		stats = GameState.compute_stats(char_data)
		hp = stats.max_hp
		mana = stats.max_mana
	return {"amount": amount, "leveled": leveled}

func update_visuals() -> void:
	# /2.0 : le monde carre (5200 de haut) depasse la limite de z_index de Godot
	# (+/-4096) si on utilise y brut - meme echelle partout (decor, PNJ, ennemis)
	# pour que le tri en profondeur reste coherent entre eux.
	z_index = int(global_position.y / 4.0) # tri en profondeur : sinon on disparait derrière les maisons/décors
	name_label.position = Vector2(-name_label.size.x/2, -58)
	hp_bg.position = Vector2(-20, -46)
	hp_fg.position = Vector2(-18, -44)
	var pct = clamp(hp / max(1.0, stats.max_hp), 0.0, 1.0)
	hp_fg.size.x = 36 * pct
	hp_fg.color = Color(0.23,0.82,0.23) if pct > 0.5 else (Color(0.82,0.78,0.23) if pct > 0.2 else Color(0.82,0.23,0.23))
