extends Node
# Autoload "GameState" : personnage courant + session multijoueur.

var mode: String = "solo" # "solo" | "host" | "join"
var char_data: Dictionary = {}
var roster: Dictionary = {} # peer_id(int) -> char_data (host/clients)
var join_ip: String = "127.0.0.1"

## ---------------- Sauvegardes (emplacements multiples) ----------------
## Le jeu n'avait qu'UN seul fichier de sauvegarde : creer un nouveau
## personnage ecrasait definitivement le precedent. On gere desormais
## plusieurs emplacements independants.
const SAVE_SLOTS := 3
const SAVE_PATH_LEGACY := "user://save.json" # ancien fichier unique, migre vers l'emplacement 1
var current_slot: int = 1

func _ready() -> void:
	migrate_legacy_save()

func slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot

## Recupere l'ancienne sauvegarde unique dans l'emplacement 1 pour ne pas
## faire perdre son personnage a un joueur qui met le jeu a jour. Le fichier
## d'origine est supprime APRES copie reussie : sinon, supprimer l'emplacement
## 1 le ferait "ressusciter" au lancement suivant.
func migrate_legacy_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH_LEGACY): return
	if FileAccess.file_exists(slot_path(1)): return # emplacement deja occupe, on ne l'ecrase pas
	var src = FileAccess.open(SAVE_PATH_LEGACY, FileAccess.READ)
	if src == null: return
	var txt = src.get_as_text()
	src.close()
	var dst = FileAccess.open(slot_path(1), FileAccess.WRITE)
	if dst == null: return
	dst.store_string(txt)
	dst.close()
	if FileAccess.file_exists(slot_path(1)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH_LEGACY))

## slot < 0 => emplacement courant. Garde les appels existants valides.
func _resolve_slot(slot: int) -> int:
	return current_slot if slot < 0 else slot

func has_save(slot: int = -1) -> bool:
	return FileAccess.file_exists(slot_path(_resolve_slot(slot)))

func any_save_exists() -> bool:
	for s in range(1, SAVE_SLOTS + 1):
		if has_save(s): return true
	return false

func save_character(slot: int = -1) -> void:
	if char_data.is_empty(): return
	var f = FileAccess.open(slot_path(_resolve_slot(slot)), FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(char_data))
	f.close()

func load_saved_character(slot: int = -1) -> Dictionary:
	var s = _resolve_slot(slot)
	if not has_save(s): return {}
	var f = FileAccess.open(slot_path(s), FileAccess.READ)
	if f == null: return {}
	var txt = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY: return {}
	# rétro-compatibilité : complète les champs manquants si la sauvegarde est ancienne
	var defaults = new_character(parsed.get("name","Aventurier"), parsed.get("race","humain"), parsed.get("class","guerrier"))
	for k in defaults.keys():
		if not parsed.has(k): parsed[k] = defaults[k]
	return parsed

func delete_save(slot: int = -1) -> void:
	var s = _resolve_slot(slot)
	if has_save(s): DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(s)))

## Resume d'un emplacement pour l'affichage du menu ({} si vide).
func slot_summary(slot: int) -> Dictionary:
	var cd = load_saved_character(slot)
	if cd.is_empty(): return {}
	var zone_name = ""
	if cd.get("last_x") != null and cd.get("last_y") != null:
		zone_name = Data.zone_at(cd.last_x, cd.last_y).name
	return {
		"name": cd.get("name", "?"),
		"level": cd.get("level", 1),
		"class_name": Data.CLASSES.get(cd.get("class"), {}).get("name", str(cd.get("class"))),
		"zone": zone_name,
	}

func new_character(cname: String, race: String, cls: String, hair_color: String = "#3f2a1a") -> Dictionary:
	return {
		"name": cname, "race": race, "class": cls, "level": 1, "xp": 0, "gold": 20,
		"hair_color": hair_color, # couleur de cheveux choisie à la création (personnalisation d'apparence)
		"equipment": {"weapon": "", "armor": ""},
		"inventory": {},
		"quests_active": {}, # qid -> progress(int)
		"quests_completed": [],
		"profession": "",
		"gather_counts": {},
		"bounty": null, # {target, target_name, count, progress, reward_gold, reward_xp}
		"bounties_done": 0,
		"talents": {}, # "5" -> talent_id, "15" -> talent_id
		"reputation": {}, # faction_id -> int
		"unlocked_zones": ["village"], # zones visitées, débloque le voyage rapide
		"bloodstain": null, # {x, y, gold} — or perdu à la dernière mort, récupérable une fois
	}

func pending_talent(cd: Dictionary) -> Dictionary:
	var tiers = Data.TALENTS.get(cd.get("class"), [])
	for tier in tiers:
		if cd.level >= tier.level and not cd.talents.has(str(tier.level)):
			return tier
	return {}

## ---------------- Quetes ----------------
## Les quetes "deliver" ne progressent PAS via quests_active : rien
## n'incremente ce compteur pour ce type, leur avancement suit l'INVENTAIRE.
## Trois endroits calculaient cela separement (dialogue PNJ, icone au-dessus
## du PNJ, suivi de quetes du HUD) et le troisieme avait diverge : le suivi
## affichait "0/1" en permanence pour les deux quetes de livraison, meme en
## ayant l'objet en main et avec l'icone "a rendre" affichee sur le PNJ.
## Centralise ici pour qu'un quatrieme endroit ne puisse pas re-diverger.
func quest_progress(cd: Dictionary, qid: String) -> int:
	var q = Data.get_quest(qid)
	if q.is_empty(): return 0
	if q.obj.type == "deliver":
		return mini(q.obj.count, cd.inventory.get(q.obj.item, 0))
	return cd.quests_active.get(qid, 0)

func quest_is_ready(cd: Dictionary, qid: String) -> bool:
	var q = Data.get_quest(qid)
	if q.is_empty(): return false
	return quest_progress(cd, qid) >= q.obj.count

## PNJ aupres de qui rendre la quete : les "deliver" se rendent a obj.target,
## pas au donneur (ex: q_relique est donnee par le pretre mais se rend a
## l'Ancien).
func quest_turnin_npc(qid: String) -> String:
	var q = Data.get_quest(qid)
	if q.is_empty(): return ""
	return q.obj.target if q.obj.type == "deliver" else q.giver

## ---------------- Sac / capacite ----------------
## Centralise ici plutot que disperse sur les 7 endroits qui ajoutaient
## directement dans cd.inventory : c'est exactement le genre de constante
## eparpillee qui a deja cause plusieurs bugs dans ce projet.

## Nombre total d'objets portes, hors objets de quete (exemptes de la limite).
func inventory_load(cd: Dictionary) -> int:
	var total = 0
	for id in cd.inventory.keys():
		var qty = cd.inventory[id]
		if qty <= 0: continue
		if Data.idef(id).is_empty(): continue # idef gere les cles suffixees par la rarete
		if Data.idef(id).type == "quest": continue
		total += qty
	return total

func inventory_space_left(cd: Dictionary) -> int:
	return maxi(0, Data.INVENTORY_CAPACITY - inventory_load(cd))

func inventory_is_full(cd: Dictionary) -> bool:
	return inventory_space_left(cd) <= 0

## Ajoute jusqu'a `count` exemplaires et renvoie combien ont REELLEMENT ete
## ajoutes (0 si le sac est plein). Les objets de quete passent toujours.
func add_item(cd: Dictionary, id: String, count: int = 1) -> int:
	if count <= 0: return 0
	var is_quest = not Data.idef(id).is_empty() and Data.idef(id).type == "quest"
	var added = count if is_quest else mini(count, inventory_space_left(cd))
	if added <= 0: return 0
	cd.inventory[id] = cd.inventory.get(id, 0) + added
	return added

func compute_stats(cd: Dictionary) -> Dictionary:
	var race = Data.RACES[cd.race]
	var cls = Data.CLASSES[cd["class"]]
	var lvl = cd.level
	var hp = cls.base.hp + cls.growth.hp * (lvl - 1) + race.bonus.hp
	var mana = cls.base.mana + cls.growth.mana * (lvl - 1) + race.bonus.mana
	var atk = cls.base.atk + cls.growth.atk * (lvl - 1) + race.bonus.atk
	var def = cls.base.def + cls.growth.def * (lvl - 1) + race.bonus.def
	var spd = cls.base.spd + race.bonus.spd
	for slot in cd.equipment.keys():
		var item_id = cd.equipment[slot]
		if item_id == "" or item_id == null: continue
		# item_bonus applique le multiplicateur de rarete : une "Épée de Fer
		# (Épique)" vaut reellement plus qu'une commune, et gere aussi les
		# cles sans suffixe (rarete commune, multiplicateur 1.0).
		var bonus = Data.item_bonus(item_id)
		hp += bonus.get("hp", 0); mana += bonus.get("mana", 0)
		atk += bonus.get("atk", 0); def += bonus.get("def", 0); spd += bonus.get("spd", 0)
	# talents (bonus en %, appliqués après l'équipement)
	var tiers = Data.TALENTS.get(cd.get("class"), [])
	for tier in tiers:
		var chosen_id = cd.get("talents", {}).get(str(tier.level))
		if chosen_id == null: continue
		for opt in tier.options:
			if opt.id != chosen_id: continue
			var b = opt.bonus
			hp *= (1.0 + b.get("hp_pct", 0.0))
			mana *= (1.0 + b.get("mana_pct", 0.0))
			atk *= (1.0 + b.get("atk_pct", 0.0))
			def *= (1.0 + b.get("def_pct", 0.0))
			spd *= (1.0 + b.get("spd_pct", 0.0))
	return {"max_hp": round(hp), "max_mana": round(mana), "atk": atk, "def": def, "spd": spd}
