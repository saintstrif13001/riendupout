extends Node
# Autoload "Data" : toutes les données statiques du jeu.

const RACES := {
	"humain": {"name":"Humain", "desc":"Polyvalents et adaptables. +5% XP gagnée.",
		"bonus":{"hp":0,"mana":0,"atk":0,"def":0,"spd":0}, "xp_mult":1.05, "tint":Color(1,1,1)},
	"elfe": {"name":"Elfe Sylvain", "desc":"Agilité et affinité nature/magie. +Vitesse, +Mana.",
		"bonus":{"hp":-10,"mana":15,"atk":1,"def":-1,"spd":25}, "xp_mult":1.0, "tint":Color(0.8,0.96,0.88)},
	"nain": {"name":"Nain des Forges", "desc":"Résistants, doués pour l'artisanat/minage. +Vie, +Défense.",
		"bonus":{"hp":25,"mana":-10,"atk":0,"def":3,"spd":-15}, "xp_mult":1.0, "tint":Color(0.88,0.73,0.54)},
	"orc": {"name":"Orc des Terres Brisées", "desc":"Force brute. +Attaque, +Vie.",
		"bonus":{"hp":15,"mana":-15,"atk":3,"def":1,"spd":0}, "xp_mult":1.0, "tint":Color(0.73,0.85,0.54)},
	"ratkin": {"name":"Ratkin", "desc":"Peuple-bête furtif, perception accrue. +Vitesse, +Critique.",
		"bonus":{"hp":-5,"mana":5,"atk":1,"def":0,"spd":20}, "xp_mult":1.0, "tint":Color(0.79,0.66,0.47), "crit_bonus":0.08},
	"golem": {"name":"Golem de Pierre Vivante", "desc":"Tank naturel, résiste aux éléments. +Vie, +Défense, -Vitesse.",
		"bonus":{"hp":40,"mana":-20,"atk":1,"def":5,"spd":-25}, "xp_mult":0.95, "tint":Color(0.6,0.6,0.6)},
}

const CLASSES := {
	"guerrier": {"name":"Guerrier/Tank", "role":"tank", "desc":"Encaisse et contrôle les ennemis.",
		"base":{"hp":150,"mana":20,"atk":11,"def":11,"spd":150},
		"growth":{"hp":19,"mana":2,"atk":2.1,"def":2.0},
		"color":Color(0.85,0.29,0.29),
		"skills":[
			{"id":"coup_puissant","name":"Coup Puissant","key":"skill_q","cd":4.0,"cost":8,"dmg_mult":2.0,"range":60,"desc":"Frappe lourde."},
			{"id":"cri_guerre","name":"Cri de Guerre","key":"skill_e","cd":12.0,"cost":15,"buff":{"atk":6,"def":6,"duration":6.0},"range":0,"party":true,"desc":"+ATK/DEF pour le groupe."},
		]},
	"mage": {"name":"Mage Élémentaire", "role":"dps_zone", "desc":"Sorts de zone dévastateurs, fragile.",
		"base":{"hp":75,"mana":110,"atk":14,"def":3,"spd":150},
		"growth":{"hp":8,"mana":15,"atk":2.8,"def":0.6},
		"color":Color(0.29,0.56,0.85),
		"skills":[
			{"id":"boule_feu","name":"Boule de Feu","key":"skill_q","cd":2.5,"cost":14,"dmg_mult":2.6,"range":260,"projectile":true,"desc":"Projectile de feu."},
			{"id":"nova_glace","name":"Nova de Glace","key":"skill_e","cd":9.0,"cost":35,"dmg_mult":1.6,"range":130,"aoe":true,"desc":"Dégâts de zone + ralentit."},
		]},
	"pretre": {"name":"Soigneur/Prêtre", "role":"heal", "desc":"Soigne et protège le groupe.",
		"base":{"hp":90,"mana":100,"atk":8,"def":5,"spd":150},
		"growth":{"hp":10,"mana":13,"atk":1.4,"def":1.0},
		"color":Color(0.94,0.88,0.56),
		"skills":[
			{"id":"soin","name":"Lumière Bienfaisante","key":"skill_q","cd":2.2,"cost":16,"heal":35,"range":180,"party":true,"desc":"Soigne toi ou l'allié le plus proche."},
			{"id":"bouclier_saint","name":"Bouclier Saint","key":"skill_e","cd":10.0,"cost":30,"shield":60,"duration":5.0,"range":180,"party":true,"desc":"Bouclier absorbant."},
		]},
	"archer": {"name":"Rôdeur/Chasseur", "role":"dps_range", "desc":"Dégâts à distance et pièges.",
		"base":{"hp":100,"mana":50,"atk":13,"def":5,"spd":170},
		"growth":{"hp":11,"mana":6,"atk":2.6,"def":1.0},
		"color":Color(0.29,0.85,0.56),
		"skills":[
			{"id":"tir_rapide","name":"Tir Rapide","key":"skill_q","cd":1.8,"cost":8,"dmg_mult":1.5,"range":220,"projectile":true,"desc":"Flèche rapide."},
			{"id":"piege","name":"Piège à Ours","key":"skill_e","cd":9.0,"cost":20,"dmg_mult":0.8,"range":150,"desc":"Immobilise un ennemi."},
		]},
	"voleur": {"name":"Voleur/Assassin", "role":"dps_burst", "desc":"Burst de dégâts et crochetage.",
		"base":{"hp":95,"mana":40,"atk":12,"def":4,"spd":195},
		"growth":{"hp":10,"mana":4,"atk":2.4,"def":0.8},
		"color":Color(0.6,0.29,0.85),
		"skills":[
			{"id":"coup_dos","name":"Coup dans le Dos","key":"skill_q","cd":3.0,"cost":10,"dmg_mult":2.8,"range":55,"crit_bonus":0.5,"desc":"Fort dégâts, critique accru."},
			{"id":"esquive","name":"Esquive Fumigène","key":"skill_e","cd":8.0,"cost":12,"dash":220,"invuln":0.4,"desc":"Fonce en avant, invulnérabilité brève."},
		]},
	"barde": {"name":"Barde/Support", "role":"support", "desc":"Buffs de groupe, débuffs ennemis.",
		"base":{"hp":100,"mana":80,"atk":9,"def":5,"spd":165},
		"growth":{"hp":11,"mana":10,"atk":1.8,"def":1.0},
		"color":Color(0.85,0.29,0.69),
		"skills":[
			{"id":"chant_vaillance","name":"Chant de Vaillance","key":"skill_q","cd":9.0,"cost":20,"buff":{"atk":5,"spd":20,"duration":7.0},"range":0,"party":true,"desc":"+ATK/Vitesse pour le groupe."},
			{"id":"complainte","name":"Complainte Lugubre","key":"skill_e","cd":9.0,"cost":20,"dmg_mult":0.5,"range":180,"aoe":true,"desc":"Réduit la défense ennemie."},
		]},
}

const PROFESSIONS := {
	"mineur": {"name":"Mineur", "desc":"Extrait le minerai.", "gather":"minerai"},
	"bucheron": {"name":"Bûcheron", "desc":"Coupe le bois.", "gather":"bois"},
	"herboriste": {"name":"Herboriste", "desc":"Récolte les plantes.", "gather":"herbe"},
	"forgeron": {"name":"Forgeron / Armurier", "desc":"Forge armes et armures.", "craft_uses":"minerai"},
	"alchimiste": {"name":"Alchimiste", "desc":"Prépare potions.", "craft_uses":"herbe"},
	"dresseur": {"name":"Dresseur de Montures", "desc":"Vend des montures.", "npc_only":true},
	"maitre_armes": {"name":"Maître d'Armes", "desc":"Entraîne les compétences.", "npc_only":true},
	"cartographe": {"name":"Cartographe / Guide", "desc":"Vend des cartes.", "npc_only":true},
	"tavernier": {"name":"Tavernier", "desc":"Rumeurs et quêtes annexes.", "npc_only":true},
	"enchanteur": {"name":"Enchanteur / Runiste", "desc":"Ajoute des runes à l'équipement.", "npc_only":true},
	"chasseur_primes": {"name":"Chasseur de Primes", "desc":"Contrats contre monstres d'élite.", "npc_only":true},
	"necromancien": {"name":"Nécromancien Renégat", "desc":"Quêtes grises.", "npc_only":true},
}

const ZONES := {
	"village": {"id":"village", "name":"Val-Repos", "x0":0, "x1":1400, "safe":true, "bg":Color("4a7a3a"), "lvl":[1,1]},
	"plaine": {"id":"plaine", "name":"Plaine d'Aubval", "x0":1400, "x1":3200, "safe":false, "bg":Color("5a8a42"), "lvl":[1,5]},
	"foret": {"id":"foret", "name":"Forêt de Sylvombre", "x0":3200, "x1":5200, "safe":false, "bg":Color("2f5a34"), "lvl":[5,12]},
	"caverne": {"id":"caverne", "name":"Caverne des Ossements", "x0":5200, "x1":7200, "safe":false, "bg":Color("332b2b"), "lvl":[10,18]},
	"marais": {"id":"marais", "name":"Marais Putride", "x0":7200, "x1":9200, "safe":false, "bg":Color("3a4a2e"), "lvl":[16,25]},
}
const WORLD_WIDTH := 9200.0
const WORLD_HEIGHT := 1200.0

const MONSTER_TYPES := {
	"slime_vert": {"name":"Slime Vert", "sprite":"slime_green", "hp":24, "atk":4, "def":0, "spd":60, "xp":8, "loot":[{"id":"gelee","chance":0.6}], "zone":"plaine"},
	"slime_rouge": {"name":"Slime Rouge", "sprite":"slime_red", "hp":36, "atk":7, "def":1, "spd":70, "xp":14, "loot":[{"id":"gelee","chance":0.6},{"id":"minerai","chance":0.15}], "zone":"plaine"},
	"loup": {"name":"Loup des Plaines", "sprite":"wolf", "fw":64, "fh":85, "hp":45, "atk":9, "def":1, "spd":110, "xp":18, "loot":[{"id":"peau_loup","chance":0.5},{"id":"gelee","chance":0.1}], "zone":"plaine"},
	"loup_alpha": {"name":"Loup Alpha", "sprite":"wolf", "fw":64, "fh":85, "hp":150, "atk":16, "def":3, "spd":130, "xp":55, "boss":true, "loot":[{"id":"peau_loup","chance":1.0},{"id":"peau_loup","chance":0.6}], "zone":"plaine",
		"phases":[{"hp_pct":0.5, "summon":"loup", "count":2}]},
	"gobelin": {"name":"Gobelin", "sprite":"goblin", "hp":60, "atk":10, "def":2, "spd":90, "xp":22, "loot":[{"id":"bois","chance":0.3},{"id":"dent_gobelin","chance":0.5}], "zone":"foret"},
	"squelette": {"name":"Squelette", "sprite":"skeleton", "hp":90, "atk":13, "def":4, "spd":80, "xp":34, "loot":[{"id":"os","chance":0.6},{"id":"minerai","chance":0.25}], "zone":"caverne"},
	"kobold": {"name":"Kobold Soldat", "sprite":"kobold", "hp":75, "atk":12, "def":3, "spd":95, "xp":30, "loot":[{"id":"minerai","chance":0.3},{"id":"ecaille_kobold","chance":0.45}], "zone":"caverne"},
	"squelette_guerrier": {"name":"Squelette Guerrier", "sprite":"skeleton_warrior", "hp":260, "atk":20, "def":8, "spd":70, "xp":120, "boss":true, "loot":[{"id":"os","chance":1.0},{"id":"relique_ossements","chance":1.0}], "zone":"caverne",
		"phases":[{"hp_pct":0.5, "summon":"squelette", "count":2}]},
	"orc_guerrier": {"name":"Orc Guerrier", "sprite":"orc_warrior", "hp":80, "atk":14, "def":5, "spd":85, "xp":40, "loot":[{"id":"bois","chance":0.2},{"id":"croc_orc","chance":0.5}], "zone":"foret"},
	"orc_chef": {"name":"Chef Orc Grondmar", "sprite":"orc_chief", "hp":340, "atk":24, "def":10, "spd":75, "xp":160, "boss":true, "loot":[{"id":"croc_orc","chance":1.0},{"id":"totem_orc","chance":1.0}], "zone":"foret",
		"phases":[{"hp_pct":0.6, "summon":"orc_guerrier", "count":2}, {"hp_pct":0.25, "summon":"orc_guerrier", "count":2}]},
	"zombie": {"name":"Zombie", "sprite":"zombie", "hp":110, "atk":15, "def":5, "spd":55, "xp":45, "loot":[{"id":"chair_pourrie","chance":0.6},{"id":"herbe","chance":0.2}], "zone":"marais"},
	"zombie_pourri": {"name":"Zombie Pourrissant", "sprite":"zombie_rotting", "hp":150, "atk":19, "def":7, "spd":50, "xp":60, "loot":[{"id":"chair_pourrie","chance":0.7},{"id":"ichor_putride","chance":0.35}], "zone":"marais"},
	"zombie_ancien": {"name":"Zombie Ancestral", "sprite":"zombie_rotting", "hp":420, "atk":28, "def":11, "spd":45, "xp":220, "boss":true, "loot":[{"id":"ichor_putride","chance":1.0},{"id":"coeur_marais","chance":1.0}], "zone":"marais",
		"phases":[{"hp_pct":0.66, "summon":"zombie", "count":3}, {"hp_pct":0.33, "summon":"zombie_pourri", "count":2}]},
}

const ITEMS := {
	"gelee": {"name":"Gelée de Slime", "type":"mat", "icon":"o"},
	"peau_loup": {"name":"Peau de Loup", "type":"mat", "icon":"o"},
	"ecaille_kobold": {"name":"Écaille de Kobold", "type":"mat", "icon":"o"},
	"bois": {"name":"Bois", "type":"mat", "icon":"o"},
	"minerai": {"name":"Minerai", "type":"mat", "icon":"o"},
	"herbe": {"name":"Herbe Médicinale", "type":"mat", "icon":"o"},
	"os": {"name":"Os", "type":"mat", "icon":"o"},
	"dent_gobelin": {"name":"Dent de Gobelin", "type":"mat", "icon":"o"},
	"relique_ossements": {"name":"Relique d'Ossements", "type":"quest", "icon":"*"},
	"croc_orc": {"name":"Croc d'Orc", "type":"mat", "icon":"o"},
	"totem_orc": {"name":"Totem du Chef Orc", "type":"quest", "icon":"*"},
	"chair_pourrie": {"name":"Chair Pourrie", "type":"mat", "icon":"o"},
	"ichor_putride": {"name":"Ichor Putride", "type":"mat", "icon":"o"},
	"coeur_marais": {"name":"Coeur du Marais", "type":"quest", "icon":"*"},
	"hache_orc": {"name":"Hache Orc", "type":"weapon", "icon":"/", "bonus":{"atk":9,"def":-1}},
	"armure_ecailles": {"name":"Armure d'Écailles Putrides", "type":"armor", "icon":"#", "bonus":{"def":12,"hp":25}},
	"amulette_marais": {"name":"Amulette du Marais", "type":"weapon", "icon":"|", "bonus":{"atk":10,"mana":25}},
	"cape_heros": {"name":"Cape du Héros de Val-Repos", "type":"armor", "icon":"#", "bonus":{"def":6,"hp":15,"spd":8}, "rep_req":{"faction":"garde","min":250}, "price":80},
	"arc_rangers": {"name":"Arc des Rangers", "type":"weapon", "icon":"}", "bonus":{"atk":9,"spd":10}, "rep_req":{"faction":"rangers","min":250}, "price":90},
	"robe_cercle": {"name":"Robe du Cercle d'Ozias", "type":"armor", "icon":"[", "bonus":{"def":5,"mana":20,"hp":10}, "rep_req":{"faction":"cercle","min":250}, "price":90},
	"epee_fer": {"name":"Épée de Fer", "type":"weapon", "icon":"/", "bonus":{"atk":5}},
	"arc_chasse": {"name":"Arc de Chasse", "type":"weapon", "icon":"}", "bonus":{"atk":4,"spd":5}},
	"baton_novice": {"name":"Bâton du Novice", "type":"weapon", "icon":"|", "bonus":{"atk":6,"mana":10}},
	"armure_cuir": {"name":"Armure de Cuir", "type":"armor", "icon":"[", "bonus":{"def":4,"hp":10}},
	"bottes_loup": {"name":"Bottes en Peau de Loup", "type":"armor", "icon":"[", "bonus":{"spd":12,"def":2}},
	"armure_plates": {"name":"Armure de Plates", "type":"armor", "icon":"#", "bonus":{"def":8,"hp":20}},
	"potion_vie": {"name":"Potion de Vie", "type":"consumable", "icon":"+", "heal":40},
	"potion_mana": {"name":"Potion de Mana", "type":"consumable", "icon":"~", "mana":40},
}

const RECIPES := [
	{"id":"r_epee_fer", "profession":"forgeron", "result":"epee_fer", "cost":{"minerai":5}, "name":"Épée de Fer"},
	{"id":"r_armure_cuir", "profession":"forgeron", "result":"armure_cuir", "cost":{"minerai":3,"bois":2}, "name":"Armure de Cuir"},
	{"id":"r_bottes_loup", "profession":"forgeron", "result":"bottes_loup", "cost":{"peau_loup":4,"minerai":1}, "name":"Bottes en Peau de Loup"},
	{"id":"r_armure_plates", "profession":"forgeron", "result":"armure_plates", "cost":{"minerai":8}, "name":"Armure de Plates"},
	{"id":"r_potion_vie", "profession":"alchimiste", "result":"potion_vie", "cost":{"herbe":3}, "name":"Potion de Vie"},
	{"id":"r_potion_mana", "profession":"alchimiste", "result":"potion_mana", "cost":{"herbe":2,"minerai":1}, "name":"Potion de Mana"},
	{"id":"r_arc", "profession":"forgeron", "result":"arc_chasse", "cost":{"bois":5,"minerai":2}, "name":"Arc de Chasse"},
	{"id":"r_baton", "profession":"alchimiste", "result":"baton_novice", "cost":{"herbe":4,"bois":2}, "name":"Bâton du Novice"},
	{"id":"r_hache_orc", "profession":"forgeron", "result":"hache_orc", "cost":{"minerai":6,"croc_orc":3}, "name":"Hache Orc"},
	{"id":"r_armure_ecailles", "profession":"forgeron", "result":"armure_ecailles", "cost":{"minerai":10,"ichor_putride":2}, "name":"Armure d'Écailles Putrides"},
	{"id":"r_amulette_marais", "profession":"alchimiste", "result":"amulette_marais", "cost":{"ichor_putride":4,"chair_pourrie":3}, "name":"Amulette du Marais"},
]

const GATHER_NODES := [
	{"type":"bois","x":1650,"y":300}, {"type":"bois","x":1800,"y":850}, {"type":"bois","x":3600,"y":250},
	{"type":"bois","x":3900,"y":900}, {"type":"bois","x":4400,"y":500},
	{"type":"minerai","x":2100,"y":900}, {"type":"minerai","x":5500,"y":300}, {"type":"minerai","x":6200,"y":850},
	{"type":"minerai","x":6800,"y":500},
	{"type":"herbe","x":1900,"y":500}, {"type":"herbe","x":2600,"y":300}, {"type":"herbe","x":3400,"y":700},
	{"type":"herbe","x":4700,"y":800},
	{"type":"bois","x":7600,"y":300}, {"type":"bois","x":8300,"y":850},
	{"type":"minerai","x":8600,"y":400},
	{"type":"herbe","x":7700,"y":900}, {"type":"herbe","x":8900,"y":600},
]

const NPCS := [
	{"id":"ancien", "name":"l'Ancien Malorin", "x":400, "y":400, "role":"quest_turnin", "tint":Color(1,1,1)},
	{"id":"forgeron_pnj", "name":"Grondar le Forgeron", "x":600, "y":600, "role":"profession", "profession":"forgeron", "tint":Color(0.53,0.53,0.53)},
	{"id":"alchimiste_pnj", "name":"Yvenne l'Alchimiste", "x":700, "y":300, "role":"profession", "profession":"alchimiste", "tint":Color(0.56,0.29,0.85)},
	{"id":"marchand", "name":"Bosk le Marchand", "x":500, "y":750, "role":"shop", "tint":Color(0.85,0.76,0.29)},
	{"id":"garde", "name":"Garde Ren", "x":1300, "y":500, "role":"quest", "tint":Color(0.29,0.43,0.85)},
	{"id":"fermier", "name":"Fermier Otto", "x":1900, "y":700, "role":"quest", "tint":Color(0.85,0.56,0.29)},
	{"id":"eclaireur", "name":"Éclaireuse Lira", "x":3900, "y":300, "role":"quest", "tint":Color(0.29,0.85,0.43)},
	{"id":"ranger", "name":"Ranger Doff", "x":3400, "y":900, "role":"quest", "tint":Color(0.18,0.54,0.23)},
	{"id":"pretre", "name":"Prêtre Ozias", "x":5400, "y":600, "role":"quest", "tint":Color(0.85,0.85,0.85)},
	{"id":"hulda", "name":"Vieille Hulda", "x":7400, "y":600, "role":"quest", "tint":Color(0.55,0.7,0.4)},
	{"id":"chasseur", "name":"Chasseur Kessler", "x":1100, "y":450, "role":"bounty", "tint":Color(0.6,0.45,0.25)},
]

const QUESTS := [
	{"id":"q_intro","name":"Premiers Pas","giver":"ancien","requires":[],"level":1,
		"desc":"Parle à Garde Ren à la sortie du village.", "obj":{"type":"talk","target":"garde","count":1}, "reward":{"xp":20,"gold":10}},

	{"id":"q_race_humain","name":"Racines de Val-Repos","giver":"ancien","requires":[],"level":1,"race_req":"humain",
		"desc":"Ta famille a aidé à bâtir ce village. Rapporte 2 Bois pour restaurer une poutre de la maison commune.",
		"obj":{"type":"gather","target":"bois","count":2}, "reward":{"xp":25,"gold":10}},
	{"id":"q_race_elfe","name":"Écho de la Forêt Natale","giver":"ancien","requires":[],"level":1,"race_req":"elfe",
		"desc":"Loin de Sylvombre, tu ressens encore l'appel des bois. Récolte 2 Herbes pour rester en accord avec la nature.",
		"obj":{"type":"gather","target":"herbe","count":2}, "reward":{"xp":25,"gold":10}},
	{"id":"q_race_nain","name":"Le Sang des Forges","giver":"ancien","requires":[],"level":1,"race_req":"nain",
		"desc":"Ton clan forge depuis des générations. Rapporte 2 Minerais pour honorer cette tradition.",
		"obj":{"type":"gather","target":"minerai","count":2}, "reward":{"xp":25,"gold":15}},
	{"id":"q_race_orc","name":"Rites des Terres Brisées","giver":"ancien","requires":[],"level":1,"race_req":"orc",
		"desc":"Chez les tiens, on prouve sa valeur par la force. Élimine 3 Slimes Verts pour ton premier rite.",
		"obj":{"type":"kill","target":["slime_vert"],"count":3}, "reward":{"xp":30,"gold":10}},
	{"id":"q_race_ratkin","name":"Instincts du Charognard","giver":"ancien","requires":[],"level":1,"race_req":"ratkin",
		"desc":"Ton peuple survit en flairant les ressources. Rapporte 3 Bois trouvés au flair plus que par la force.",
		"obj":{"type":"gather","target":"bois","count":3}, "reward":{"xp":25,"gold":12}},
	{"id":"q_race_golem","name":"Premier Éveil","giver":"ancien","requires":[],"level":1,"race_req":"golem",
		"desc":"Tu marches depuis peu parmi les vivants. Élimine 2 Slimes Verts pour tester ta force de pierre.",
		"obj":{"type":"kill","target":["slime_vert"],"count":2}, "reward":{"xp":30,"gold":8}},
	{"id":"q_bois_village","name":"Ravitaillement du Forgeron","giver":"forgeron_pnj","requires":[],"level":1,
		"desc":"Récolte 3 Bois pour Grondar.", "obj":{"type":"gather","target":"bois","count":3}, "reward":{"xp":25,"gold":15}},
	{"id":"q_herbe_village","name":"Remèdes Simples","giver":"alchimiste_pnj","requires":[],"level":1,
		"desc":"Récolte 3 Herbes pour Yvenne.", "obj":{"type":"gather","target":"herbe","count":3}, "reward":{"xp":25,"gold":15}},
	{"id":"q_slime1","name":"Peste de Gelée","giver":"garde","requires":["q_intro"],"level":1,
		"desc":"Élimine 8 Slimes Verts.", "obj":{"type":"kill","target":["slime_vert"],"count":8}, "reward":{"xp":60,"gold":25,"items":["potion_vie"]}},
	{"id":"q_slime2","name":"Le Rouge Danger","giver":"garde","requires":["q_slime1"],"level":2,
		"desc":"Élimine 5 Slimes Rouges.", "obj":{"type":"kill","target":["slime_rouge"],"count":5}, "reward":{"xp":80,"gold":35,"items":["potion_vie"]}},
	{"id":"q_fermier_intro","name":"Le Repos du Fermier","giver":"fermier","requires":["q_intro"],"level":1,
		"desc":"Rapporte 5 Minerais à Otto.", "obj":{"type":"gather","target":"minerai","count":5}, "reward":{"xp":70,"gold":30}},
	{"id":"q_fermier_herbe","name":"Récolte Utile","giver":"fermier","requires":["q_fermier_intro"],"level":2,
		"desc":"Récolte 6 Herbes pour Otto.", "obj":{"type":"gather","target":"herbe","count":6}, "reward":{"xp":75,"gold":30}},
	{"id":"q_loups","name":"Hurlements Nocturnes","giver":"garde","requires":["q_slime2"],"level":3,
		"desc":"Des loups rôdent près du village. Élimine 8 Loups des Plaines.", "obj":{"type":"kill","target":["loup"],"count":8}, "reward":{"xp":95,"gold":40}},
	{"id":"q_loup_alpha","name":"La Tanière de l'Alpha","giver":"garde","requires":["q_loups"],"level":4,
		"desc":"Un Loup Alpha mène la meute depuis sa tanière au coeur de la plaine. Élimine-le.",
		"obj":{"type":"boss","target":"loup_alpha","count":1}, "reward":{"xp":140,"gold":60,"items":["bottes_loup"]}},
	{"id":"q_garde_frontiere","name":"Garde-Frontière","giver":"garde","requires":["q_loup_alpha"],"level":3,
		"desc":"Élimine 10 Slimes.", "obj":{"type":"kill","target":["slime_vert","slime_rouge"],"count":10}, "reward":{"xp":110,"gold":50,"items":["armure_cuir"]}},
	{"id":"q_vers_foret","name":"Vers la Forêt","giver":"fermier","requires":["q_garde_frontiere","q_fermier_herbe"],"level":4,
		"desc":"Parle à l'Éclaireuse Lira.", "obj":{"type":"talk","target":"eclaireur","count":1}, "reward":{"xp":60,"gold":20}},
	{"id":"q_gobelin1","name":"Infestation Gobeline","giver":"eclaireur","requires":["q_vers_foret"],"level":5,
		"desc":"Élimine 10 Gobelins.", "obj":{"type":"kill","target":["gobelin"],"count":10}, "reward":{"xp":140,"gold":60,"items":["potion_vie","potion_vie"]}},
	{"id":"q_dents","name":"Les Dents Longues","giver":"eclaireur","requires":["q_gobelin1"],"level":6,
		"desc":"Collecte 6 Dents de Gobelin.", "obj":{"type":"gather_drop","target":"dent_gobelin","count":6}, "reward":{"xp":150,"gold":70}},
	{"id":"q_bois_ancien","name":"Le Bois Ancien","giver":"ranger","requires":["q_vers_foret"],"level":6,
		"desc":"Rapporte 8 Bois à Doff.", "obj":{"type":"gather","target":"bois","count":8}, "reward":{"xp":120,"gold":55}},
	{"id":"q_chasse_profonde","name":"Chasse Profonde","giver":"ranger","requires":["q_bois_ancien","q_dents"],"level":8,
		"desc":"Élimine 15 Gobelins.", "obj":{"type":"kill","target":["gobelin"],"count":15}, "reward":{"xp":220,"gold":90,"items":["arc_chasse"]}},
	{"id":"q_orc1","name":"Le Camp Orc","giver":"ranger","requires":["q_chasse_profonde"],"level":9,
		"desc":"Un camp orc s'est installé au coeur de la forêt. Élimine 10 Orcs Guerriers.", "obj":{"type":"kill","target":["orc_guerrier"],"count":10}, "reward":{"xp":260,"gold":110}},
	{"id":"q_orc_chef","name":"Le Chef Grondmar","giver":"ranger","requires":["q_orc1"],"level":11,
		"desc":"Vaincs le Chef Orc Grondmar qui dirige le camp.", "obj":{"type":"boss","target":"orc_chef","count":1}, "reward":{"xp":420,"gold":180,"items":["hache_orc"]}},
	{"id":"q_vers_caverne","name":"Vers les Profondeurs","giver":"ranger","requires":["q_orc_chef"],"level":11,
		"desc":"Parle au Prêtre Ozias.", "obj":{"type":"talk","target":"pretre","count":1}, "reward":{"xp":80,"gold":30}},
	{"id":"q_kobolds","name":"Fouisseurs Indésirables","giver":"pretre","requires":["q_vers_caverne"],"level":10,
		"desc":"Élimine 10 Kobolds Soldats qui infestent les tunnels.", "obj":{"type":"kill","target":["kobold"],"count":10}, "reward":{"xp":220,"gold":95}},
	{"id":"q_squelette1","name":"Profondeurs Osseuses","giver":"pretre","requires":["q_vers_caverne"],"level":10,
		"desc":"Élimine 12 Squelettes.", "obj":{"type":"kill","target":["squelette"],"count":12}, "reward":{"xp":260,"gold":100,"items":["armure_plates"]}},
	{"id":"q_reserve_os","name":"Réserve d'Os","giver":"pretre","requires":["q_squelette1"],"level":11,
		"desc":"Rapporte 10 Os.", "obj":{"type":"gather_drop","target":"os","count":10}, "reward":{"xp":230,"gold":100}},
	{"id":"q_echo_caverne","name":"Écho de la Caverne","giver":"pretre","requires":["q_reserve_os"],"level":13,
		"desc":"Élimine 20 Squelettes de plus.", "obj":{"type":"kill","target":["squelette"],"count":20}, "reward":{"xp":380,"gold":160,"items":["epee_fer"]}},
	{"id":"q_gardien","name":"Le Gardien Ossu","giver":"pretre","requires":["q_echo_caverne"],"level":15,
		"desc":"Vaincs le Squelette Guerrier.", "obj":{"type":"boss","target":"squelette_guerrier","count":1}, "reward":{"xp":600,"gold":300,"items":["relique_ossements"]}},
	{"id":"q_relique","name":"Relique Retrouvée","giver":"pretre","requires":["q_gardien"],"level":16,
		"desc":"Ramène la Relique à l'Ancien Malorin.", "obj":{"type":"deliver","target":"ancien","item":"relique_ossements","count":1}, "reward":{"xp":500,"gold":250}},

	{"id":"q_vers_marais","name":"Rumeurs du Marais","giver":"ancien","requires":["q_relique"],"level":16,
		"desc":"L'Ancien parle d'une vieille recluse, Hulda, qui vit en lisière du Marais Putride, à l'est de la caverne.",
		"obj":{"type":"talk","target":"hulda","count":1}, "reward":{"xp":100,"gold":40}},
	{"id":"q_zombie1","name":"Les Morts qui Marchent","giver":"hulda","requires":["q_vers_marais"],"level":16,
		"desc":"Élimine 14 Zombies dans le marais.", "obj":{"type":"kill","target":["zombie"],"count":14}, "reward":{"xp":300,"gold":120}},
	{"id":"q_chair","name":"Ingrédients Répugnants","giver":"hulda","requires":["q_zombie1"],"level":17,
		"desc":"Rapporte 8 morceaux de Chair Pourrie pour les rituels d'Hulda.", "obj":{"type":"gather_drop","target":"chair_pourrie","count":8}, "reward":{"xp":260,"gold":110}},
	{"id":"q_zombie2","name":"Putréfaction Galopante","giver":"hulda","requires":["q_zombie1"],"level":18,
		"desc":"Élimine 10 Zombies Pourrissants, plus coriaces.", "obj":{"type":"kill","target":["zombie_pourri"],"count":10}, "reward":{"xp":380,"gold":160,"items":["armure_ecailles"]}},
	{"id":"q_marais_boss","name":"Le Coeur Putride","giver":"hulda","requires":["q_zombie2","q_chair"],"level":20,
		"desc":"Un Zombie Ancestral règne sur le marais. Vaincs-le.", "obj":{"type":"boss","target":"zombie_ancien","count":1}, "reward":{"xp":700,"gold":320,"items":["amulette_marais"]}},
	{"id":"q_marais_final","name":"Le Rituel d'Hulda","giver":"hulda","requires":["q_marais_boss"],"level":21,
		"desc":"Ramène le Coeur du Marais à Hulda pour clore le rituel.", "obj":{"type":"deliver","target":"hulda","item":"coeur_marais","count":1}, "reward":{"xp":600,"gold":300}},
]

func get_quest(id: String) -> Dictionary:
	for q in QUESTS:
		if q.id == id: return q
	return {}

func get_npc(id: String) -> Dictionary:
	for n in NPCS:
		if n.id == id: return n
	return {}

func zone_at(x: float) -> Dictionary:
	for key in ZONES:
		var z = ZONES[key]
		if x >= z.x0 and x < z.x1: return z
	return ZONES.village

const FACTIONS := {
	"garde": {"name":"Garde de Val-Repos", "desc":"La milice qui protège le village et la Plaine d'Aubval."},
	"rangers": {"name":"Rangers de Sylvombre", "desc":"Les gardiens de la Forêt de Sylvombre, ennemis des orcs."},
	"cercle": {"name":"Cercle d'Ozias", "desc":"L'ordre religieux qui veille sur la Caverne et le Marais."},
}
const REP_TIERS := [
	{"min":0, "name":"Neutre"}, {"min":100, "name":"Amical"},
	{"min":250, "name":"Honoré"}, {"min":500, "name":"Vénéré"},
]
func rep_tier_name(rep: int) -> String:
	var name = REP_TIERS[0].name
	for t in REP_TIERS:
		if rep >= t.min: name = t.name
	return name

# Faction associée à chaque quête — la réputation gagnée = xp de récompense / 10 (arrondi).
const QUEST_FACTION := {
	"q_intro":"garde", "q_bois_village":"garde", "q_herbe_village":"garde",
	"q_slime1":"garde", "q_slime2":"garde", "q_loups":"garde", "q_loup_alpha":"garde", "q_fermier_intro":"garde", "q_fermier_herbe":"garde",
	"q_race_humain":"garde", "q_race_elfe":"garde", "q_race_nain":"garde", "q_race_orc":"garde",
	"q_race_ratkin":"garde", "q_race_golem":"garde",
	"q_garde_frontiere":"garde", "q_vers_foret":"garde",
	"q_gobelin1":"rangers", "q_dents":"rangers", "q_bois_ancien":"rangers", "q_chasse_profonde":"rangers",
	"q_orc1":"rangers", "q_orc_chef":"rangers", "q_vers_caverne":"rangers",
	"q_kobolds":"cercle", "q_squelette1":"cercle", "q_reserve_os":"cercle", "q_echo_caverne":"cercle", "q_gardien":"cercle",
	"q_relique":"cercle", "q_vers_marais":"cercle", "q_zombie1":"cercle", "q_chair":"cercle",
	"q_zombie2":"cercle", "q_marais_boss":"cercle", "q_marais_final":"cercle",
}

const TALENTS := {
	"guerrier": [
		{"level":5, "options":[
			{"id":"berserker", "name":"Berserker", "desc":"+18% ATK, -8% DEF", "bonus":{"atk_pct":0.18,"def_pct":-0.08}},
			{"id":"bastion", "name":"Bastion", "desc":"+22% DEF, -6% Vitesse", "bonus":{"def_pct":0.22,"spd_pct":-0.06}}]},
		{"level":15, "options":[
			{"id":"implacable", "name":"Implacable", "desc":"+12% PV max, +8% ATK", "bonus":{"hp_pct":0.12,"atk_pct":0.08}},
			{"id":"rempart", "name":"Rempart", "desc":"+20% PV max, +10% DEF", "bonus":{"hp_pct":0.20,"def_pct":0.10}}]},
	],
	"mage": [
		{"level":5, "options":[
			{"id":"pyromancie", "name":"Pyromancie", "desc":"+20% ATK magique", "bonus":{"atk_pct":0.20}},
			{"id":"reserve_arcane", "name":"Réserve Arcane", "desc":"+25% Mana max", "bonus":{"mana_pct":0.25}}]},
		{"level":15, "options":[
			{"id":"archimage", "name":"Archimage", "desc":"+18% ATK, +10% Mana", "bonus":{"atk_pct":0.18,"mana_pct":0.10}},
			{"id":"survie_arcanique", "name":"Survie Arcanique", "desc":"+22% PV max", "bonus":{"hp_pct":0.22}}]},
	],
	"pretre": [
		{"level":5, "options":[
			{"id":"lumiere_vive", "name":"Lumière Vive", "desc":"+20% Mana max", "bonus":{"mana_pct":0.20}},
			{"id":"devotion", "name":"Dévotion", "desc":"+15% PV max, +8% DEF", "bonus":{"hp_pct":0.15,"def_pct":0.08}}]},
		{"level":15, "options":[
			{"id":"grand_pretre", "name":"Grand Prêtre", "desc":"+25% Mana, +10% ATK", "bonus":{"mana_pct":0.25,"atk_pct":0.10}},
			{"id":"gardien_sacre", "name":"Gardien Sacré", "desc":"+18% PV, +12% DEF", "bonus":{"hp_pct":0.18,"def_pct":0.12}}]},
	],
	"archer": [
		{"level":5, "options":[
			{"id":"oeil_de_faucon", "name":"Œil de Faucon", "desc":"+18% ATK", "bonus":{"atk_pct":0.18}},
			{"id":"pieds_legers", "name":"Pieds Légers", "desc":"+15% Vitesse", "bonus":{"spd_pct":0.15}}]},
		{"level":15, "options":[
			{"id":"tireur_elite", "name":"Tireur d'Élite", "desc":"+22% ATK", "bonus":{"atk_pct":0.22}},
			{"id":"survivant", "name":"Survivant", "desc":"+18% PV, +10% Vitesse", "bonus":{"hp_pct":0.18,"spd_pct":0.10}}]},
	],
	"voleur": [
		{"level":5, "options":[
			{"id":"lame_rapide", "name":"Lame Rapide", "desc":"+16% ATK, +8% Vitesse", "bonus":{"atk_pct":0.16,"spd_pct":0.08}},
			{"id":"ombre", "name":"Ombre", "desc":"+16% PV max, +8% DEF", "bonus":{"hp_pct":0.16,"def_pct":0.08}}]},
		{"level":15, "options":[
			{"id":"assassin", "name":"Assassin", "desc":"+24% ATK", "bonus":{"atk_pct":0.24}},
			{"id":"maitre_evasion", "name":"Maître de l'Évasion", "desc":"+16% Vitesse, +14% PV", "bonus":{"spd_pct":0.16,"hp_pct":0.14}}]},
	],
	"barde": [
		{"level":5, "options":[
			{"id":"virtuose", "name":"Virtuose", "desc":"+18% ATK", "bonus":{"atk_pct":0.18}},
			{"id":"harmonie", "name":"Harmonie", "desc":"+20% Mana max", "bonus":{"mana_pct":0.20}}]},
		{"level":15, "options":[
			{"id":"chef_de_choeur", "name":"Chef de Chœur", "desc":"+16% PV, +16% Mana", "bonus":{"hp_pct":0.16,"mana_pct":0.16}},
			{"id":"discorde", "name":"Discorde", "desc":"+22% ATK", "bonus":{"atk_pct":0.22}}]},
	],
}

func xp_for_level(level: int) -> int:
	return int(floor(30 * pow(level, 1.7)))

func random_bounty(level: int) -> Dictionary:
	# Choisit un monstre non-boss dont la zone correspond approximativement au niveau du joueur.
	var candidates := []
	for tid in MONSTER_TYPES.keys():
		var m = MONSTER_TYPES[tid]
		if m.get("boss", false): continue
		var lvl = ZONES[m.zone].lvl
		if level >= lvl[0] - 3 and level <= lvl[1] + 4:
			candidates.append(tid)
	if candidates.is_empty():
		candidates = MONSTER_TYPES.keys().filter(func(t): return not MONSTER_TYPES[t].get("boss", false))
	var tid = candidates[randi() % candidates.size()]
	var m = MONSTER_TYPES[tid]
	var count = randi_range(6, 12)
	return {
		"target": tid, "target_name": m.name, "count": count, "progress": 0,
		"reward_gold": int(m.xp * count * 0.6), "reward_xp": int(m.xp * count * 0.7),
	}
