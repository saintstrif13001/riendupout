extends Node
# Autoload "GameState" : personnage courant + session multijoueur.

var mode: String = "solo" # "solo" | "host" | "join"
var char_data: Dictionary = {}
var roster: Dictionary = {} # peer_id(int) -> char_data (host/clients)
var join_ip: String = "127.0.0.1"

const SAVE_PATH := "user://save.json"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_character() -> void:
	if char_data.is_empty(): return
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(char_data))
	f.close()

func load_saved_character() -> Dictionary:
	if not has_save(): return {}
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
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

func delete_save() -> void:
	if has_save(): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func new_character(cname: String, race: String, cls: String) -> Dictionary:
	return {
		"name": cname, "race": race, "class": cls, "level": 1, "xp": 0, "gold": 20,
		"equipment": {"weapon": "", "armor": ""},
		"inventory": {},
		"quests_active": {}, # qid -> progress(int)
		"quests_completed": [],
		"profession": "",
		"gather_counts": {},
		"bounty": null, # {target, target_name, count, progress, reward_gold, reward_xp}
		"bounties_done": 0,
	}

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
		var it = Data.ITEMS.get(item_id, {})
		var bonus = it.get("bonus", {})
		hp += bonus.get("hp", 0); mana += bonus.get("mana", 0)
		atk += bonus.get("atk", 0); def += bonus.get("def", 0); spd += bonus.get("spd", 0)
	return {"max_hp": round(hp), "max_mana": round(mana), "atk": atk, "def": def, "spd": spd}
