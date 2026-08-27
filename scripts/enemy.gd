extends CharacterBody2D
class_name Enemy

const DIR_ROW := {"up":0, "left":1, "down":2, "right":3}
const FW := 48
const FH := 64

var uid: String = ""
var type_id: String = ""
var mdef: Dictionary
var level: int = 1
var max_hp: float
var hp: float
var atk: float
var edef: float
var spd: float
var dead: bool = false
var dir: String = "down"
var last_attack: float = 0.0
var spawn_pos: Vector2

@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $NameLabel
@onready var hp_bg: ColorRect = $HpBg
@onready var hp_fg: ColorRect = $HpFg
@onready var collider: CollisionShape2D = $CollisionShape2D

func setup(tid: String, u: String, lvl: int) -> void:
	type_id = tid
	uid = u
	mdef = Data.MONSTER_TYPES[tid]
	level = lvl
	var scale_f = 1.0 + (level - 1) * 0.12
	max_hp = mdef.hp * scale_f
	hp = max_hp
	atk = mdef.atk * scale_f
	edef = mdef.def * scale_f
	spd = mdef.spd

	sprite.texture = load("res://assets/sprites/enemies/%s.png" % mdef.sprite)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 2*FH, FW, FH)
	sprite.centered = true
	if mdef.get("boss", false):
		sprite.scale = Vector2(1.6, 1.6)

	var yoff = -52.0 if mdef.get("boss", false) else -40.0
	name_label.text = "%s Nv.%d" % [mdef.name, level]
	name_label.modulate = Color(1, 0.4, 0.4) if mdef.get("boss", false) else Color(1, 0.67, 0.67)
	name_label.position = Vector2(-40, yoff - 14)
	hp_bg.position = Vector2(-16, yoff)
	hp_fg.position = Vector2(-14, yoff + 2)

func set_anim(new_dir: String, moving: bool) -> void:
	dir = new_dir
	var row = DIR_ROW[dir]
	var frame = 0
	if moving:
		frame = int(Time.get_ticks_msec() / 150) % 3
	sprite.region_rect = Rect2(frame * FW, row * FH, FW, FH)

func take_damage(dmg: float) -> float:
	if dead: return 0.0
	var mitig = max(1.0, dmg - edef * 0.4)
	hp = max(0.0, hp - mitig)
	sprite.modulate = Color(2, 2, 2)
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(sprite): sprite.modulate = Color(1,1,1))
	if hp <= 0: die()
	return mitig

func die() -> void:
	dead = true
	visible = false
	set_physics_process(false)
	if collider: collider.disabled = true

func update_visuals() -> void:
	var pct = clamp(hp / max(1.0, max_hp), 0.0, 1.0)
	hp_fg.size.x = 28 * pct
