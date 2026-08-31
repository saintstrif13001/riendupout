extends CharacterBody2D
class_name Enemy

const DIR_ROW := {"up":0, "left":1, "down":2, "right":3}
const FW := 48
const FH := 64

var fw := FW
var fh := FH

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
var cc_until: float = 0.0    # immobilisé (racine) jusqu'à ce timestamp
var slow_until: float = 0.0
var slow_factor: float = 1.0
var dir: String = "down"
var last_attack: float = 0.0
var last_seen_atk_t: float = 0.0 # côté client réseau : détecte une nouvelle attaque via net_enemy_snapshot
var spawn_pos: Vector2
var triggered_phases: Dictionary = {}

signal phase_triggered(phase: Dictionary)

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

	fw = mdef.get("fw", FW)
	fh = mdef.get("fh", FH)
	sprite.texture = load("res://assets/sprites/enemies/%s.png" % mdef.sprite)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 2*fh, fw, fh)
	sprite.centered = true
	if mdef.get("boss", false):
		sprite.scale = Vector2(1.6, 1.6)

	var yoff = -52.0 if mdef.get("boss", false) else -40.0
	name_label.text = "%s Nv.%d" % [mdef.name, level]
	name_label.modulate = Color(1, 0.4, 0.4) if mdef.get("boss", false) else Color(1, 0.67, 0.67)
	name_label.position = Vector2(-40, yoff - 14)
	hp_bg.position = Vector2(-16, yoff)
	hp_fg.position = Vector2(-14, yoff + 2)

	# Respiration à l'arrêt : sans ça les monstres restaient parfaitement figés
	# dès qu'ils ne se déplaçaient pas, contrairement aux PNJ/joueur animés.
	_start_idle_bob()

var _idle_tween: Tween = null

func _start_idle_bob() -> void:
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(sprite, "position:y", -2.0, 0.7).set_trans(Tween.TRANS_SINE).set_delay(randf() * 0.6)
	_idle_tween.tween_property(sprite, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE)

func play_attack_anim() -> void:
	# Pas de feuille de sprites d'attaque dédiée pour les monstres : un coup de
	# "punch" (grossit + s'avance vers la cible) donne quand même un vrai signal
	# visuel au lieu d'une attaque totalement silencieuse. On coupe la
	# respiration le temps du coup pour éviter que les deux tweens se battent
	# sur sprite.position, puis on la relance.
	if dead or not is_instance_valid(sprite): return
	if _idle_tween != null and _idle_tween.is_valid(): _idle_tween.kill()
	sprite.position = Vector2.ZERO
	var lunge = target_dir_vec() * 6.0
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.18, 1.18), 0.1).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(sprite, "position", lunge, 0.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "scale", Vector2(1, 1), 0.15).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(sprite, "position", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(_start_idle_bob)

func target_dir_vec() -> Vector2:
	match dir:
		"up": return Vector2(0, -1)
		"down": return Vector2(0, 1)
		"left": return Vector2(-1, 0)
		_: return Vector2(1, 0)

func set_anim(new_dir: String, moving: bool) -> void:
	dir = new_dir
	var row = DIR_ROW[dir]
	var frame = 0
	if moving:
		frame = int(Time.get_ticks_msec() / 150) % 3
	sprite.region_rect = Rect2(frame * fw, row * fh, fw, fh)

func apply_immobilize(duration: float) -> void:
	cc_until = max(cc_until, Time.get_ticks_msec() / 1000.0 + duration)

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_until = Time.get_ticks_msec() / 1000.0 + duration

func effective_speed() -> float:
	var now = Time.get_ticks_msec() / 1000.0
	if now < cc_until: return 0.0
	if now < slow_until: return spd * slow_factor
	return spd

func take_damage(dmg: float) -> float:
	if dead: return 0.0
	var mitig = max(1.0, dmg - edef * 0.4)
	hp = max(0.0, hp - mitig)
	sprite.modulate = Color(2, 2, 2)
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(sprite): sprite.modulate = Color(1,1,1))
	if hp <= 0:
		die()
	else:
		_check_phases()
	return mitig

func _check_phases() -> void:
	for phase in mdef.get("phases", []):
		var key = str(phase.hp_pct)
		if triggered_phases.has(key): continue
		if hp <= max_hp * phase.hp_pct:
			triggered_phases[key] = true
			phase_triggered.emit(phase)

func die() -> void:
	dead = true
	visible = false
	set_physics_process(false)
	if collider: collider.disabled = true

func update_visuals() -> void:
	z_index = int(global_position.y / 2.0) # même échelle que player.gd/world.gd (voir leur commentaire) — tri en profondeur : sinon disparait derrière les maisons/décors
	var pct = clamp(hp / max(1.0, max_hp), 0.0, 1.0)
	hp_fg.size.x = 28 * pct
