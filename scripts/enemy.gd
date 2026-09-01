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
## Timestamp de resolution d'une attaque en cours d'armement (0 = aucune).
## Les attaques ennemies etaient INSTANTANEES : des que le minuteur expirait
## et qu'on etait a portee, les degats tombaient, sans aucune fenetre pour
## reagir. Le combat se resumait donc a un echange de statistiques ou le
## placement ne servait a rien. L'ennemi s'arme desormais visiblement, puis
## frappe — et rate si la cible est sortie de portee entre-temps.
var windup_until: float = 0.0
## Archetype "charger" (loups) : decroche jusqu'a ce timestamp apres avoir
## frappe, pour donner un rythme piquer/reculer au lieu d'un corps a corps colle.
var retreat_until: float = 0.0
## --- Etat de boss (voir world._on_boss_phase) ---
## Les boss ne differaient de la piétaille que par leurs PV et une phase qui
## invoque des renforts : meme comportement, meme rythme, aucune raison de
## changer de tactique en cours de combat.
var behavior_override: String = "" # archetype impose par une phase
var rage_atk: float = 1.0          # multiplicateur de degats (enrage)
var rage_spd: float = 1.0          # multiplicateur de vitesse (enrage)
var last_slam: float = -100.0      # derniere attaque puissante (-100 : dispo d'emblee)
var pending_slam: bool = false     # l'armement en cours est une attaque puissante

## --- Reaction aux coups (voir world._apply_hit_reaction) ---
## Frapper un ennemi ne faisait que baisser des chiffres : il continuait
## d'avancer sans broncher, donc un coup n'avait aucun poids.
var stagger_until: float = 0.0     # sonne : n'agit pas
var knockback_vel: Vector2 = Vector2.ZERO
## Empeche de verrouiller un ennemi en enchainant les interruptions : une fois
## son armement interrompu, il ne peut plus l'etre avant ce timestamp.
var interrupt_ready_at: float = 0.0
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
	# Onze feuilles de sprites seulement pour 33 creatures : une meme silhouette
	# sert a plusieurs especes, distinguees par leur TEINTE et leur TAILLE. Sans
	# ca un Loup de Givre serait pixel pour pixel un Loup des Plaines, et les
	# zones se ressembleraient toutes malgre un bestiaire etoffe.
	sprite.modulate = mdef.get("tint", Color.WHITE)
	var spr_scale = mdef.get("scale", 1.6 if mdef.get("boss", false) else 1.0)
	sprite.scale = Vector2(spr_scale, spr_scale)

	var yoff = -52.0 if mdef.get("boss", false) else -40.0
	name_label.text = "%s Nv.%d" % [mdef.name, level]
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.modulate = Color(1, 0.4, 0.4) if mdef.get("boss", false) else Color(1, 0.67, 0.67)
	# Boite large + centrage : a -40 avec une boite de 80, "Squelette Guerrier
	# Nv.18" debordait vers la droite au lieu de rester au-dessus du monstre.
	name_label.position = Vector2(-110, yoff - 14)
	name_label.size = Vector2(220, 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	if now < slow_until: return spd * slow_factor * rage_spd
	return spd * rage_spd

func take_damage(dmg: float) -> float:
	if dead: return 0.0
	var mitig = max(1.0, dmg - edef * 0.4)
	hp = max(0.0, hp - mitig)
	sprite.modulate = Color(2, 2, 2)
	# Restaure la TEINTE de l'espece, pas un blanc fixe : sinon le premier coup
	# encaisse effacait definitivement la couleur qui distingue la creature de
	# celles qui partagent son sprite (voir setup()).
	var base_tint = mdef.get("tint", Color.WHITE)
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(sprite): sprite.modulate = base_tint)
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
	z_index = int(global_position.y / 4.0) # même échelle que player.gd/world.gd (voir leur commentaire) — tri en profondeur : sinon disparait derrière les maisons/décors
	var pct = clamp(hp / max(1.0, max_hp), 0.0, 1.0)
	hp_fg.size.x = 28 * pct
