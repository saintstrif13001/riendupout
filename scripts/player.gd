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
var buff_expiry: Array = [] # [{atk,def,spd,at}]

var body_tex: Texture2D
var legs_tex: Texture2D
var head_tex: Texture2D

@onready var legs_sprite: Sprite2D = $Legs
@onready var body_sprite: Sprite2D = $Body
@onready var head_sprite: Sprite2D = $Head
@onready var name_label: Label = $NameLabel
@onready var hp_bg: ColorRect = $HpBg
@onready var hp_fg: ColorRect = $HpFg
@onready var collider: CollisionShape2D = $CollisionShape2D

func setup(cd: Dictionary, local: bool, pid: int) -> void:
	char_data = cd
	is_local = local
	peer_id = pid
	stats = GameState.compute_stats(cd)
	hp = stats.max_hp
	mana = stats.max_mana

	body_tex = load("res://assets/sprites/player/body_walk.png")
	legs_tex = load("res://assets/sprites/player/legs_walk.png")
	head_tex = load("res://assets/sprites/player/head_walk.png")

	body_sprite.texture = body_tex
	legs_sprite.texture = legs_tex
	head_sprite.texture = head_tex
	for spr in [body_sprite, legs_sprite, head_sprite]:
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 2*FH, FW, FH)
		spr.centered = true
	body_sprite.z_index = 1
	head_sprite.z_index = 2
	legs_sprite.z_index = 0

	var race = Data.RACES[cd.race]
	body_sprite.modulate = race.tint
	head_sprite.modulate = race.tint

	name_label.text = cd.name
	name_label.modulate = Color(1, 0.88, 0.4) if is_local else Color(0.65, 0.85, 1)
	hp_fg.color = Color(0.23, 0.82, 0.23)

func set_anim(new_dir: String, is_moving: bool) -> void:
	dir = new_dir
	moving = is_moving
	var row = DIR_ROW[dir]
	var frame = 2
	if is_moving:
		frame = int(Time.get_ticks_msec() / 100) % FCOUNT
	var rect = Rect2(frame * FW, row * FH, FW, FH)
	body_sprite.region_rect = rect
	legs_sprite.region_rect = rect
	head_sprite.region_rect = rect

func take_damage(dmg: float) -> float:
	if dead: return 0.0
	if Time.get_ticks_msec() / 1000.0 < invuln_until: return 0.0
	var mitig = max(1.0, dmg - stats.def * 0.5)
	hp = max(0.0, hp - mitig)
	if hp <= 0: die()
	return mitig

func heal(amount: float) -> void:
	hp = min(stats.max_hp, hp + amount)

func die() -> void:
	dead = true
	body_sprite.modulate = Color(0.3, 0.3, 0.3)
	head_sprite.modulate = Color(0.3, 0.3, 0.3)

func respawn(pos: Vector2) -> void:
	dead = false
	hp = stats.max_hp
	mana = stats.max_mana
	global_position = pos
	var race = Data.RACES[char_data.race]
	body_sprite.modulate = race.tint
	head_sprite.modulate = race.tint

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
	name_label.position = Vector2(-name_label.size.x/2, -58)
	hp_bg.position = Vector2(-20, -46)
	hp_fg.position = Vector2(-18, -44)
	var pct = clamp(hp / max(1.0, stats.max_hp), 0.0, 1.0)
	hp_fg.size.x = 36 * pct
	hp_fg.color = Color(0.23,0.82,0.23) if pct > 0.5 else (Color(0.82,0.78,0.23) if pct > 0.2 else Color(0.82,0.23,0.23))
