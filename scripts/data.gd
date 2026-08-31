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

## Chaque classe n'avait que DEUX competences, disponibles des le niveau 1 et
## inchangees jusqu'au niveau 30 : on traversait toute la progression avec les
## deux memes boutons, alors que le monde, lui, s'etoffait. Deux competences
## supplementaires s'ajoutent en cours de route (niveaux 8 et 18), ce qui donne
## deux vrais paliers ou la facon de jouer change.
##   "level" : niveau requis (voir SKILL_UNLOCK_LEVELS et world.use_skill)
##   "shockwave" : multiplicateur de recul applique aux cibles, qui INTERROMPT
##                 aussi leur attaque en cours d'armement (voir
##                 world._apply_hit_reaction) — de quoi punir un telegraphe.
const SKILL_UNLOCK_LEVELS := [1, 1, 8, 18]

const CLASSES := {
	"guerrier": {"name":"Guerrier/Tank", "role":"tank", "desc":"Encaisse et contrôle les ennemis.",
		"base":{"hp":150,"mana":20,"atk":11,"def":11,"spd":150},
		"growth":{"hp":19,"mana":2,"atk":2.1,"def":2.0},
		"color":Color(0.85,0.29,0.29),
		"skills":[
			{"id":"coup_puissant","name":"Coup Puissant","key":"skill_q","level":1,"cd":4.0,"cost":8,"dmg_mult":2.0,"range":60,"fx_color":Color(0.95,0.3,0.25),"icon":"sword.png","desc":"Frappe lourde."},
			{"id":"cri_guerre","name":"Cri de Guerre","key":"skill_e","level":1,"cd":12.0,"cost":15,"buff":{"atk":6,"def":6,"duration":6.0},"range":0,"party":true,"icon":"shield.png","desc":"+ATK/DEF pour le groupe."},
			{"id":"choc_sismique","name":"Choc Sismique","key":"skill_r","level":8,"cd":10.0,"cost":24,"dmg_mult":1.5,"range":150,"aoe":true,"shockwave":2.0,"fx_color":Color(0.9,0.62,0.25),"icon":"axe.png","desc":"Onde de choc : repousse et interrompt tout autour."},
			{"id":"rempart","name":"Rempart Inébranlable","key":"skill_t","level":18,"cd":24.0,"cost":38,"shield":150,"duration":7.0,"buff":{"def":12,"duration":7.0},"range":0,"icon":"helmet.png","desc":"Gros bouclier et défense accrue."},
		]},
	"mage": {"name":"Mage Élémentaire", "role":"dps_zone", "desc":"Sorts de zone dévastateurs, fragile.",
		"base":{"hp":75,"mana":110,"atk":14,"def":3,"spd":150},
		"growth":{"hp":8,"mana":15,"atk":2.8,"def":0.6},
		"color":Color(0.29,0.56,0.85),
		"skills":[
			{"id":"boule_feu","name":"Boule de Feu","key":"skill_q","level":1,"cd":2.5,"cost":14,"dmg_mult":2.6,"range":260,"projectile":true,"fx_color":Color(1,0.5,0.1),"icon":"staff.png","desc":"Projectile de feu."},
			{"id":"nova_glace","name":"Nova de Glace","key":"skill_e","level":1,"cd":9.0,"cost":35,"dmg_mult":1.6,"range":130,"aoe":true,"fx_color":Color(0.5,0.85,1.0),"slow_pct":0.5,"slow_duration":3.0,"icon":"gem.png","desc":"Dégâts de zone + ralentit."},
			{"id":"foudre","name":"Foudre","key":"skill_r","level":8,"cd":6.0,"cost":30,"dmg_mult":3.4,"range":300,"projectile":true,"fx_color":Color(0.75,0.85,1.0),"icon":"amulet.png","desc":"Trait de foudre à très longue portée."},
			{"id":"meteore","name":"Météore","key":"skill_t","level":18,"cd":20.0,"cost":55,"dmg_mult":3.0,"range":210,"aoe":true,"shockwave":2.5,"fx_color":Color(1,0.55,0.2),"icon":"ore.png","desc":"Impact de zone qui balaie tout."},
		]},
	"pretre": {"name":"Soigneur/Prêtre", "role":"heal", "desc":"Soigne et protège le groupe.",
		"base":{"hp":90,"mana":100,"atk":8,"def":5,"spd":150},
		"growth":{"hp":10,"mana":13,"atk":1.4,"def":1.0},
		"color":Color(0.94,0.88,0.56),
		"skills":[
			{"id":"soin","name":"Lumière Bienfaisante","key":"skill_q","level":1,"cd":2.2,"cost":16,"heal":35,"range":180,"party":true,"icon":"potion_red.png","desc":"Soigne toi ou l'allié le plus proche."},
			{"id":"bouclier_saint","name":"Bouclier Saint","key":"skill_e","level":1,"cd":10.0,"cost":30,"shield":60,"duration":5.0,"range":180,"party":true,"icon":"shield.png","desc":"Bouclier absorbant."},
			{"id":"chatiment","name":"Châtiment","key":"skill_r","level":8,"cd":5.0,"cost":18,"dmg_mult":2.2,"range":230,"projectile":true,"fx_color":Color(1,0.92,0.6),"icon":"amulet.png","desc":"Trait sacré : enfin de quoi frapper seul."},
			{"id":"renaissance","name":"Renaissance","key":"skill_t","level":18,"cd":26.0,"cost":55,"heal":150,"shield":90,"duration":6.0,"range":200,"party":true,"icon":"chest.png","desc":"Gros soin doublé d'un bouclier."},
		]},
	"archer": {"name":"Rôdeur/Chasseur", "role":"dps_range", "desc":"Dégâts à distance et pièges.",
		"base":{"hp":100,"mana":50,"atk":13,"def":5,"spd":170},
		"growth":{"hp":11,"mana":6,"atk":2.6,"def":1.0},
		"color":Color(0.29,0.85,0.56),
		"skills":[
			{"id":"tir_rapide","name":"Tir Rapide","key":"skill_q","level":1,"cd":1.8,"cost":8,"dmg_mult":1.5,"range":220,"projectile":true,"fx_color":Color(0.55,0.85,0.35),"icon":"bow.png","desc":"Flèche rapide."},
			{"id":"piege","name":"Piège à Ours","key":"skill_e","level":1,"cd":9.0,"cost":20,"dmg_mult":0.8,"range":150,"fx_color":Color(0.6,0.45,0.2),"immobilize":2.0,"icon":"dagger.png","desc":"Immobilise un ennemi."},
			{"id":"fleche_perforante","name":"Flèche Perforante","key":"skill_r","level":8,"cd":5.5,"cost":18,"dmg_mult":2.6,"range":320,"projectile":true,"crit_bonus":0.25,"fx_color":Color(0.8,0.95,0.5),"icon":"bow.png","desc":"Tir très long, critique accru."},
			{"id":"pluie_fleches","name":"Pluie de Flèches","key":"skill_t","level":18,"cd":17.0,"cost":42,"dmg_mult":2.0,"range":210,"aoe":true,"slow_pct":0.4,"slow_duration":3.0,"fx_color":Color(0.6,0.9,0.45),"icon":"bow.png","desc":"Salve de zone qui ralentit."},
		]},
	"voleur": {"name":"Voleur/Assassin", "role":"dps_burst", "desc":"Burst de dégâts et crochetage.",
		"base":{"hp":95,"mana":40,"atk":12,"def":4,"spd":195},
		"growth":{"hp":10,"mana":4,"atk":2.4,"def":0.8},
		"color":Color(0.6,0.29,0.85),
		"skills":[
			{"id":"coup_dos","name":"Coup dans le Dos","key":"skill_q","level":1,"cd":3.0,"cost":10,"dmg_mult":2.8,"range":55,"crit_bonus":0.5,"fx_color":Color(0.65,0.3,0.85),"icon":"dagger.png","desc":"Fort dégâts, critique accru."},
			{"id":"esquive","name":"Esquive Fumigène","key":"skill_e","level":1,"cd":8.0,"cost":12,"dash":220,"invuln":0.4,"icon":"boots.png","desc":"Fonce en avant, invulnérabilité brève."},
			{"id":"eventail_lames","name":"Éventail de Lames","key":"skill_r","level":8,"cd":8.0,"cost":22,"dmg_mult":1.9,"range":120,"aoe":true,"fx_color":Color(0.75,0.4,0.95),"icon":"dagger.png","desc":"Taillade tout ce qui est proche."},
			{"id":"execution","name":"Exécution","key":"skill_t","level":18,"cd":18.0,"cost":32,"dmg_mult":4.6,"range":60,"crit_bonus":0.8,"fx_color":Color(0.9,0.25,0.45),"icon":"dagger.png","desc":"Coup unique dévastateur."},
		]},
	"barde": {"name":"Barde/Support", "role":"support", "desc":"Buffs de groupe, débuffs ennemis.",
		"base":{"hp":100,"mana":80,"atk":9,"def":5,"spd":165},
		"growth":{"hp":11,"mana":10,"atk":1.8,"def":1.0},
		"color":Color(0.85,0.29,0.69),
		"skills":[
			{"id":"chant_vaillance","name":"Chant de Vaillance","key":"skill_q","level":1,"cd":9.0,"cost":20,"buff":{"atk":5,"spd":20,"duration":7.0},"range":0,"party":true,"icon":"amulet.png","desc":"+ATK/Vitesse pour le groupe."},
			{"id":"complainte","name":"Complainte Lugubre","key":"skill_e","level":1,"cd":9.0,"cost":20,"dmg_mult":0.5,"range":180,"aoe":true,"fx_color":Color(0.55,0.3,0.55),"icon":"gem.png","desc":"Réduit la défense ennemie."},
			{"id":"berceuse","name":"Berceuse Envoûtante","key":"skill_r","level":8,"cd":14.0,"cost":26,"dmg_mult":0.4,"range":170,"aoe":true,"immobilize":2.5,"fx_color":Color(0.7,0.55,0.95),"icon":"potion_blue.png","desc":"Endort la zone : tout le monde est cloué sur place."},
			{"id":"hymne_final","name":"Hymne Final","key":"skill_t","level":18,"cd":30.0,"cost":60,"buff":{"atk":12,"def":10,"spd":25,"duration":10.0},"range":240,"party":true,"icon":"amulet.png","desc":"Buff massif et durable pour tout le groupe."},
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

# Le monde formait une seule bande horizontale (9200x1200, ratio ~7.7:1) —
# village/plaine/foret/caverne/marais alignés en ligne droite d'ouest en est.
# Retour direct du joueur ("en long c'etait nul, il faut un monde qui va de
# tout les cotes") : les quatre zones sauvages rayonnent maintenant en croix
# depuis Val-Repos (nord=foret, est=plaine, sud=marais, ouest=caverne), dans
# un monde carre 5200x5200. Chaque zone garde x0/x1/y0/y1 (plus seulement
# x0/x1) : zone_at() doit donc verifier les deux axes.
## La carte etait une CROIX : cinq zones rayonnant du village, et les quatre
## coins du carre englobant laisses a l'etat de "Terres Sauvages" — soit 56%
## de la surface du monde sans identite, sans monstre propre, sans decor.
## D'ou l'impression de zones petites et vides : on traversait du remplissage
## entre deux bras. Les coins sont desormais quatre vraies zones, ce qui
## complete la grille 3x3 et enchaine la progression 1 -> 30 sans trou :
##
##      Cimes de Givrefer  |   Foret de Sylvombre  |  Ruines de Kaldremm
##          (14-20)        |        (5-12)         |        (8-14)
##     -------------------+-----------------------+---------------------
##   Caverne des Ossements |      Val-Repos        |   Plaine d'Aubval
##          (10-18)        |       (village)       |        (1-5)
##     -------------------+-----------------------+---------------------
##    Fosse de Braisombre  |    Marais Putride     | Necropole d'Ombrelune
##          (20-26)        |       (16-25)         |       (26-30)
const ZONES := {
	"village": {"id":"village", "name":"Val-Repos", "x0":2000, "x1":3400, "y0":2000, "y1":3200, "safe":true, "bg":Color("4a7a3a"), "lvl":[1,1]},
	"plaine": {"id":"plaine", "name":"Plaine d'Aubval", "x0":3400, "x1":5200, "y0":2000, "y1":3200, "safe":false, "bg":Color("5a8a42"), "lvl":[1,5]},
	"foret": {"id":"foret", "name":"Forêt de Sylvombre", "x0":2000, "x1":3400, "y0":0, "y1":2000, "safe":false, "bg":Color("2f5a34"), "lvl":[5,12]},
	"ruines": {"id":"ruines", "name":"Ruines de Kaldremm", "x0":3400, "x1":5200, "y0":0, "y1":2000, "safe":false, "bg":Color("6b6250"), "lvl":[8,14]},
	"caverne": {"id":"caverne", "name":"Caverne des Ossements", "x0":0, "x1":2000, "y0":2000, "y1":3200, "safe":false, "bg":Color("332b2b"), "lvl":[10,18]},
	"cimes": {"id":"cimes", "name":"Cimes de Givrefer", "x0":0, "x1":2000, "y0":0, "y1":2000, "safe":false, "bg":Color("9fb4c8"), "lvl":[14,20]},
	"marais": {"id":"marais", "name":"Marais Putride", "x0":2000, "x1":3400, "y0":3200, "y1":5200, "safe":false, "bg":Color("3a4a2e"), "lvl":[16,25]},
	"fosse": {"id":"fosse", "name":"Fosse de Braisombre", "x0":0, "x1":2000, "y0":3200, "y1":5200, "safe":false, "bg":Color("4a2f26"), "lvl":[20,26]},
	"necropole": {"id":"necropole", "name":"Nécropole d'Ombrelune", "x0":3400, "x1":5200, "y0":3200, "y1":5200, "safe":false, "bg":Color("3b3245"), "lvl":[26,30]},
}
const WORLD_WIDTH := 5200.0
const WORLD_HEIGHT := 5200.0
# Terres non revendiquees dans les coins de la croix (hors de toute zone nommee) :
# zone_at() y retombe sur ce pseudo-lieu plutot que de renvoyer un dictionnaire
# vide (qui ferait planter tout code lisant .id/.name/.bg sans verification).
const VOID_ZONE := {"id":"wilds", "name":"Terres Sauvages", "x0":0, "x1":0, "y0":0, "y1":0, "safe":false, "bg":Color("3a5a30"), "lvl":[1,25]}

## Le bestiaire tenait en 9 monstres ordinaires pour TOUT le jeu, soit deux
## par zone : on avait fait le tour d'une region apres deux combats, et une
## zone ressemblait a la suivante. Chaque zone compte desormais 3 a 4 especes
## ordinaires en plus de son boss.
##   tint  : les feuilles de sprites sont peu nombreuses (11 en tout), donc une
##           meme silhouette sert a plusieurs creatures, differenciee par sa
##           teinte et sa taille — un Loup de Givre bleu pale ne se confond pas
##           avec un Loup des Plaines, meme s'ils partagent le sprite.
##   scale : les grosses creatures (colosses, chevaliers) doivent SE VOIR comme
##           telles avant meme qu'on lise leur nom.
const MONSTER_TYPES := {
	# --- Plaine d'Aubval (1-5) ---
	"slime_vert": {"name":"Slime Vert", "sprite":"slime_green", "hp":24, "atk":28, "def":0, "spd":60, "xp":8, "loot":[{"id":"gelee","chance":0.6}], "zone":"plaine"},
	"slime_bleu": {"name":"Slime Bleu", "sprite":"slime_blue", "hp":30, "atk":32, "def":1, "spd":85, "xp":11, "loot":[{"id":"gelee","chance":0.65}], "zone":"plaine", "behavior":"skittish"},
	"slime_rouge": {"name":"Slime Rouge", "sprite":"slime_red", "hp":36, "atk":36, "def":1, "spd":70, "xp":14, "loot":[{"id":"gelee","chance":0.6},{"id":"minerai","chance":0.15}], "zone":"plaine"},
	"loup": {"name":"Loup des Plaines", "sprite":"wolf", "fw":64, "fh":85, "hp":45, "atk":42, "def":1, "spd":110, "xp":18, "loot":[{"id":"peau_loup","chance":0.5},{"id":"gelee","chance":0.1}], "zone":"plaine", "behavior":"charger"},
	"loup_alpha": {"name":"Loup Alpha", "sprite":"wolf", "fw":64, "fh":85, "hp":150, "atk":68, "def":3, "spd":130, "xp":55, "boss":true, "loot":[{"id":"peau_loup","chance":1.0},{"id":"peau_loup","chance":0.6}], "zone":"plaine", "behavior":"charger",
		"slam":{"every":7.0,"reach":110.0,"windup":0.9,"dmg_mult":1.5},
		"phases":[{"hp_pct":0.5, "summon":"loup", "count":2}, {"hp_pct":0.3, "enrage":{"atk":1.25,"spd":1.25}}]},
	# --- Forêt de Sylvombre (5-12) ---
	"gobelin": {"name":"Gobelin", "sprite":"goblin", "hp":60, "atk":44, "def":2, "spd":90, "xp":22, "loot":[{"id":"bois","chance":0.3},{"id":"dent_gobelin","chance":0.5}], "zone":"foret", "behavior":"skittish"},
	"gobelin_archer": {"name":"Gobelin Archer", "sprite":"goblin", "tint":Color(0.68,0.85,0.58), "hp":55, "atk":46, "def":2, "spd":85, "xp":26, "loot":[{"id":"dent_gobelin","chance":0.55},{"id":"bois","chance":0.2}], "zone":"foret", "behavior":"ranged"},
	"orc_guerrier": {"name":"Orc Guerrier", "sprite":"orc_warrior", "hp":80, "atk":54, "def":5, "spd":85, "xp":40, "loot":[{"id":"bois","chance":0.2},{"id":"croc_orc","chance":0.5}], "zone":"foret", "behavior":"bruiser"},
	"orc_chef": {"name":"Chef Orc Grondmar", "sprite":"orc_chief", "hp":340, "atk":92, "def":10, "spd":75, "xp":160, "boss":true, "loot":[{"id":"croc_orc","chance":1.0},{"id":"totem_orc","chance":1.0}], "zone":"foret", "behavior":"bruiser",
		"slam":{"every":6.0,"reach":135.0,"windup":1.2,"dmg_mult":1.8},
		"phases":[{"hp_pct":0.6, "summon":"orc_guerrier", "count":2}, {"hp_pct":0.35, "behavior":"charger"}, {"hp_pct":0.2, "summon":"orc_guerrier", "count":2, "enrage":{"atk":1.3,"spd":1.3}}]},
	# --- Ruines de Kaldremm (8-14) : une cite morte, ses pillards et ses gardiens ---
	"pillard": {"name":"Pillard de Kaldremm", "sprite":"goblin", "tint":Color(0.95,0.62,0.5), "scale":1.1, "hp":85, "atk":50, "def":3, "spd":100, "xp":36, "loot":[{"id":"dent_gobelin","chance":0.4},{"id":"eclat_runique","chance":0.25}], "zone":"ruines", "behavior":"charger"},
	"archer_dechu": {"name":"Archer Déchu", "sprite":"skeleton", "tint":Color(0.58,0.62,0.5), "hp":95, "atk":52, "def":4, "spd":75, "xp":44, "loot":[{"id":"os","chance":0.5},{"id":"eclat_runique","chance":0.3}], "zone":"ruines", "behavior":"ranged"},
	"sentinelle_pierre": {"name":"Sentinelle de Pierre", "sprite":"skeleton", "tint":Color(0.62,0.65,0.72), "scale":1.2, "hp":130, "atk":58, "def":9, "spd":55, "xp":52, "loot":[{"id":"eclat_runique","chance":0.5},{"id":"minerai","chance":0.3}], "zone":"ruines", "behavior":"bruiser"},
	"gardien_kaldremm": {"name":"Gardien de Kaldremm", "sprite":"skeleton_warrior", "tint":Color(0.6,0.64,0.72), "scale":2.0, "hp":300, "atk":86, "def":12, "spd":65, "xp":175, "boss":true, "loot":[{"id":"eclat_runique","chance":1.0},{"id":"coeur_pierre","chance":1.0}], "zone":"ruines", "behavior":"bruiser",
		"slam":{"every":6.5,"reach":130.0,"windup":1.15,"dmg_mult":1.7},
		"phases":[{"hp_pct":0.55, "summon":"sentinelle_pierre", "count":2}, {"hp_pct":0.3, "behavior":"ranged", "enrage":{"atk":1.2,"spd":1.1}}]},
	# --- Caverne des Ossements (10-18) ---
	"kobold": {"name":"Kobold Soldat", "sprite":"kobold", "hp":75, "atk":47, "def":3, "spd":95, "xp":30, "loot":[{"id":"minerai","chance":0.3},{"id":"ecaille_kobold","chance":0.45}], "zone":"caverne"},
	"squelette": {"name":"Squelette", "sprite":"skeleton", "hp":90, "atk":50, "def":4, "spd":80, "xp":34, "loot":[{"id":"os","chance":0.6},{"id":"minerai","chance":0.25}], "zone":"caverne", "behavior":"ranged"},
	"gobelin_profondeurs": {"name":"Gobelin des Profondeurs", "sprite":"goblin", "tint":Color(0.55,0.62,0.75), "scale":1.15, "hp":105, "atk":55, "def":6, "spd":80, "xp":42, "loot":[{"id":"dent_gobelin","chance":0.5},{"id":"minerai","chance":0.35}], "zone":"caverne", "behavior":"bruiser"},
	"squelette_guerrier": {"name":"Squelette Guerrier", "sprite":"skeleton_warrior", "hp":260, "atk":82, "def":8, "spd":70, "xp":120, "boss":true, "loot":[{"id":"os","chance":1.0},{"id":"relique_ossements","chance":1.0}], "zone":"caverne", "behavior":"bruiser",
		"slam":{"every":6.5,"reach":125.0,"windup":1.15,"dmg_mult":1.7},
		"phases":[{"hp_pct":0.5, "summon":"squelette", "count":2}, {"hp_pct":0.28, "behavior":"bruiser", "enrage":{"atk":1.2,"spd":1.15}}]},
	# --- Cimes de Givrefer (14-20) : le froid, la meute et les colosses ---
	"loup_givre": {"name":"Loup de Givre", "sprite":"wolf", "fw":64, "fh":85, "tint":Color(0.72,0.88,1.0), "hp":140, "atk":68, "def":6, "spd":135, "xp":70, "loot":[{"id":"peau_loup","chance":0.6},{"id":"givre_eternel","chance":0.25}], "zone":"cimes", "behavior":"charger"},
	"kobold_glace": {"name":"Kobold Glaciaire", "sprite":"kobold", "tint":Color(0.6,0.86,0.98), "hp":125, "atk":64, "def":7, "spd":95, "xp":64, "loot":[{"id":"ecaille_kobold","chance":0.5},{"id":"givre_eternel","chance":0.3}], "zone":"cimes", "behavior":"ranged"},
	"colosse_gel": {"name":"Colosse de Gel", "sprite":"orc_warrior", "tint":Color(0.72,0.86,0.98), "scale":1.3, "hp":190, "atk":74, "def":11, "spd":60, "xp":88, "loot":[{"id":"givre_eternel","chance":0.55},{"id":"croc_orc","chance":0.3}], "zone":"cimes", "behavior":"bruiser"},
	"jarl_givrefer": {"name":"Jarl Givrefer", "sprite":"orc_chief", "tint":Color(0.78,0.92,1.0), "scale":2.0, "hp":480, "atk":108, "def":14, "spd":70, "xp":260, "boss":true, "loot":[{"id":"givre_eternel","chance":1.0},{"id":"corne_jarl","chance":1.0}], "zone":"cimes", "behavior":"bruiser",
		"slam":{"every":6.0,"reach":145.0,"windup":1.25,"dmg_mult":1.9},
		"phases":[{"hp_pct":0.65, "summon":"loup_givre", "count":3}, {"hp_pct":0.4, "behavior":"charger"}, {"hp_pct":0.2, "summon":"colosse_gel", "count":2, "enrage":{"atk":1.3,"spd":1.25}}]},
	# --- Marais Putride (16-25) ---
	"zombie": {"name":"Zombie", "sprite":"zombie", "hp":110, "atk":56, "def":5, "spd":55, "xp":45, "loot":[{"id":"chair_pourrie","chance":0.6},{"id":"herbe","chance":0.2}], "zone":"marais"},
	"noye": {"name":"Noyé du Marais", "sprite":"zombie", "tint":Color(0.5,0.78,0.72), "hp":130, "atk":60, "def":5, "spd":70, "xp":52, "loot":[{"id":"chair_pourrie","chance":0.55},{"id":"ichor_putride","chance":0.25}], "zone":"marais", "behavior":"ranged"},
	"zombie_pourri": {"name":"Zombie Pourrissant", "sprite":"zombie_rotting", "hp":150, "atk":64, "def":7, "spd":50, "xp":60, "loot":[{"id":"chair_pourrie","chance":0.7},{"id":"ichor_putride","chance":0.35}], "zone":"marais"},
	"zombie_ancien": {"name":"Zombie Ancestral", "sprite":"zombie_rotting", "hp":420, "atk":105, "def":11, "spd":45, "xp":220, "boss":true, "loot":[{"id":"ichor_putride","chance":1.0},{"id":"coeur_marais","chance":1.0}], "zone":"marais",
		"slam":{"every":8.0,"reach":150.0,"windup":1.35,"dmg_mult":2.0},
		"phases":[{"hp_pct":0.66, "summon":"zombie", "count":3}, {"hp_pct":0.45, "behavior":"ranged"}, {"hp_pct":0.25, "summon":"zombie_pourri", "count":2, "behavior":"bruiser", "enrage":{"atk":1.35,"spd":1.4}}]},
	# --- Fosse de Braisombre (20-26) : cendre, magma et fureur ---
	"slime_magma": {"name":"Slime de Magma", "sprite":"slime_red", "tint":Color(1.7,0.85,0.3), "scale":1.4, "hp":200, "atk":82, "def":8, "spd":65, "xp":95, "loot":[{"id":"gelee","chance":0.5},{"id":"braise_vive","chance":0.3}], "zone":"fosse"},
	"cendreux": {"name":"Cendreux", "sprite":"zombie", "tint":Color(0.58,0.53,0.5), "hp":210, "atk":86, "def":10, "spd":70, "xp":100, "loot":[{"id":"chair_pourrie","chance":0.4},{"id":"braise_vive","chance":0.3}], "zone":"fosse", "behavior":"ranged"},
	"orc_brulure": {"name":"Orc Brûlure", "sprite":"orc_warrior", "tint":Color(1.35,0.52,0.35), "scale":1.15, "hp":230, "atk":92, "def":12, "spd":90, "xp":110, "loot":[{"id":"croc_orc","chance":0.5},{"id":"braise_vive","chance":0.4}], "zone":"fosse", "behavior":"bruiser"},
	"seigneur_braise": {"name":"Seigneur Braise", "sprite":"orc_chief", "tint":Color(1.55,0.48,0.25), "scale":2.1, "hp":620, "atk":125, "def":16, "spd":80, "xp":340, "boss":true, "loot":[{"id":"braise_vive","chance":1.0},{"id":"sceau_braise","chance":1.0}], "zone":"fosse", "behavior":"bruiser",
		"slam":{"every":5.5,"reach":160.0,"windup":1.2,"dmg_mult":2.0},
		"phases":[{"hp_pct":0.7, "summon":"slime_magma", "count":2}, {"hp_pct":0.45, "behavior":"charger", "enrage":{"atk":1.2,"spd":1.2}}, {"hp_pct":0.2, "summon":"orc_brulure", "count":3, "enrage":{"atk":1.4,"spd":1.35}}]},
	# --- Nécropole d'Ombrelune (26-30) : la zone terminale ---
	"spectre": {"name":"Spectre d'Ombrelune", "sprite":"zombie_rotting", "tint":Color(0.68,0.62,1.0,0.72), "hp":250, "atk":100, "def":10, "spd":85, "xp":130, "loot":[{"id":"poussiere_ame","chance":0.45},{"id":"ichor_putride","chance":0.2}], "zone":"necropole", "behavior":"ranged"},
	"goule": {"name":"Goule d'Ossuaire", "sprite":"zombie", "tint":Color(0.75,0.7,0.58), "hp":280, "atk":105, "def":12, "spd":115, "xp":140, "loot":[{"id":"os","chance":0.5},{"id":"poussiere_ame","chance":0.35}], "zone":"necropole", "behavior":"charger"},
	"chevalier_dechu": {"name":"Chevalier Déchu", "sprite":"skeleton_warrior", "tint":Color(0.52,0.46,0.66), "scale":1.25, "hp":330, "atk":112, "def":18, "spd":70, "xp":155, "loot":[{"id":"poussiere_ame","chance":0.5},{"id":"os","chance":0.4}], "zone":"necropole", "behavior":"bruiser"},
	"roi_ossuaire": {"name":"Roi Ossuaire Vhalmir", "sprite":"skeleton_warrior", "tint":Color(1.0,0.88,0.55), "scale":2.2, "hp":900, "atk":145, "def":20, "spd":75, "xp":500, "boss":true, "loot":[{"id":"poussiere_ame","chance":1.0},{"id":"couronne_ossuaire","chance":1.0}], "zone":"necropole", "behavior":"bruiser",
		"slam":{"every":5.0,"reach":170.0,"windup":1.3,"dmg_mult":2.1},
		"phases":[{"hp_pct":0.75, "summon":"goule", "count":3}, {"hp_pct":0.55, "behavior":"ranged"}, {"hp_pct":0.35, "summon":"chevalier_dechu", "count":2, "enrage":{"atk":1.25,"spd":1.2}}, {"hp_pct":0.15, "summon":"spectre", "count":3, "behavior":"charger", "enrage":{"atk":1.45,"spd":1.4}}]},
}

const ICON_PATH := "res://assets/icons/"

## ---------------- Butin : raretes d'equipement ----------------
## Les ennemis ne laissaient tomber QUE des materiaux et des objets de quete :
## AUCUNE arme ni armure ne pouvait tomber de tout le jeu. Tuer le boss le plus
## coriace rapportait un croc et un totem. Le combat ne produisait donc jamais
## de recompense directe qui donne envie.
## Une piece qui tombe est desormais tiree avec une RARETE qui multiplie ses
## bonus. La rarete est encodee DANS la cle de l'objet ("epee_fer@rare") : ainsi
## l'inventaire {cle: quantite}, les emplacements d'equipement et les
## sauvegardes restent de simples chaines, et deux epees de raretes
## differentes s'empilent separement — ce qui est le comportement voulu.
const RARITY_SEP := "@"
const RARITIES := {
	"commun": {"name": "", "mult": 1.0, "weight": 58, "color": Color(0.86, 0.86, 0.86)},
	"rare": {"name": "Rare", "mult": 1.4, "weight": 28, "color": Color(0.45, 0.72, 1.0)},
	"epique": {"name": "Épique", "mult": 1.9, "weight": 11, "color": Color(0.76, 0.45, 0.96)},
	"legendaire": {"name": "Légendaire", "mult": 2.6, "weight": 3, "color": Color(1.0, 0.66, 0.2)},
}

## Identifiant de base d'une cle, avec ou sans suffixe de rarete.
func base_of(key: String) -> String:
	var i = key.find(RARITY_SEP)
	return key if i < 0 else key.substr(0, i)

func rarity_of(key: String) -> String:
	var i = key.find(RARITY_SEP)
	if i < 0: return "commun"
	var r = key.substr(i + 1)
	return r if RARITIES.has(r) else "commun"

func item_key(base_id: String, rarity: String) -> String:
	return base_id if rarity == "commun" else base_id + RARITY_SEP + rarity

## Definition de base d'un objet. TOUT le code passe par ici plutot que
## d'indexer ITEMS directement, sinon une cle avec suffixe planterait.
func idef(key: String) -> Dictionary:
	return ITEMS.get(base_of(key), {})

func item_display_name(key: String) -> String:
	var d = idef(key)
	var n = d.get("name", key)
	var r = rarity_of(key)
	return n if r == "commun" else "%s (%s)" % [n, RARITIES[r].name]

func item_color(key: String) -> Color:
	return RARITIES[rarity_of(key)].color

## Bonus reels, mis a l'echelle par la rarete. Arrondi a l'entier le plus
## proche pour rester lisible, et jamais en dessous de 1 quand le bonus de
## base est positif (une piece rare ne doit pas paraitre pire).
func item_bonus(key: String) -> Dictionary:
	var base = idef(key).get("bonus", {})
	var mult = RARITIES[rarity_of(key)].mult
	if mult == 1.0: return base
	var out = {}
	for k in base.keys():
		var v = base[k]
		out[k] = maxi(1, int(round(v * mult))) if v > 0 else int(round(v))
	return out

## Equipement susceptible de tomber, par zone, adapte au niveau du secteur.
## Les objets de faction (rep_req) en sont exclus : ils doivent rester la
## recompense d'une reputation, pas un coup de chance.
const GEAR_DROPS := {
	"plaine": ["epee_fer", "arc_chasse", "armure_cuir"],
	"foret": ["arc_chasse", "baton_novice", "bottes_loup", "armure_cuir"],
	"caverne": ["epee_fer", "armure_plates", "bottes_loup", "baton_novice"],
	"marais": ["hache_orc", "armure_plates", "armure_ecailles", "amulette_marais"],
	"ruines": ["dague_runique", "plastron_runique", "epee_fer", "bottes_loup"],
	"cimes": ["heaume_givre", "lance_glace", "plastron_runique", "armure_plates"],
	"fosse": ["lame_braise", "armure_scories", "hache_orc", "heaume_givre"],
	"necropole": ["sceptre_ombrelune", "armure_ossuaire", "faux_vhalmir", "armure_scories"],
}
## Un ennemi normal laisse rarement une piece ; un boss en laisse toujours une,
## et tire sa rarete avec de la chance en plus.
const GEAR_DROP_CHANCE := 0.12
const BOSS_GEAR_LUCK := 1.6

## Tirage pondere d'une rarete. `bonus_luck` decale le tirage vers le haut
## (utilise pour les boss, qui doivent laisser mieux que du trash).
func roll_rarity(bonus_luck: float = 0.0) -> String:
	var keys = RARITIES.keys()
	var total = 0.0
	var weights = []
	for i in range(keys.size()):
		# Les raretes superieures (indices plus eleves) profitent de la chance.
		var w = RARITIES[keys[i]].weight * (1.0 + bonus_luck * i)
		weights.append(w)
		total += w
	var pick = randf() * total
	for i in range(keys.size()):
		pick -= weights[i]
		if pick <= 0.0: return keys[i]
	return "commun"

## Capacite du sac, en nombre total d'objets (toutes piles confondues).
## L'inventaire etait totalement illimite : on pouvait accumuler sans fin, ce
## qui retirait tout interet a la vente chez Bosk et a l'arbitrage "que
## garder ?". Les objets de quete sont EXEMPTES (ils ne comptent pas et sont
## toujours acceptes) : bloquer un objet de quete sur un sac plein pourrait
## rendre une quete impossible a terminer.
const INVENTORY_CAPACITY := 80
const ITEMS := {
	"gelee": {"name":"Gelée de Slime", "type":"mat", "icon":"potion_blue.png"},
	"peau_loup": {"name":"Peau de Loup", "type":"mat", "icon":"armor2.png"},
	"ecaille_kobold": {"name":"Écaille de Kobold", "type":"mat", "icon":"gem.png"},
	"bois": {"name":"Bois", "type":"mat", "icon":"nut.png"},
	"minerai": {"name":"Minerai", "type":"mat", "icon":"ore.png"},
	"herbe": {"name":"Herbe Médicinale", "type":"mat", "icon":"herb.png"},
	"os": {"name":"Os", "type":"mat", "icon":"key.png"},
	"dent_gobelin": {"name":"Dent de Gobelin", "type":"mat", "icon":"gem.png"},
	"relique_ossements": {"name":"Relique d'Ossements", "type":"quest", "icon":"chest.png"},
	"croc_orc": {"name":"Croc d'Orc", "type":"mat", "icon":"gem.png"},
	"totem_orc": {"name":"Totem du Chef Orc", "type":"quest", "icon":"chest.png"},
	"chair_pourrie": {"name":"Chair Pourrie", "type":"mat", "icon":"meat.png"},
	"ichor_putride": {"name":"Ichor Putride", "type":"mat", "icon":"potion_blue.png"},
	"coeur_marais": {"name":"Coeur du Marais", "type":"quest", "icon":"chest.png"},
	"hache_orc": {"name":"Hache Orc", "type":"weapon", "icon":"axe.png", "bonus":{"atk":9,"def":-1}},
	"armure_ecailles": {"name":"Armure d'Écailles Putrides", "type":"armor", "icon":"armor2.png", "bonus":{"def":12,"hp":25}},
	"amulette_marais": {"name":"Amulette du Marais", "type":"weapon", "icon":"amulet.png", "bonus":{"atk":10,"mana":25}},
	"cape_heros": {"name":"Cape du Héros de Val-Repos", "type":"armor", "icon":"armor.png", "bonus":{"def":6,"hp":15,"spd":8}, "rep_req":{"faction":"garde","min":250}, "price":80},
	"arc_rangers": {"name":"Arc des Rangers", "type":"weapon", "icon":"bow.png", "bonus":{"atk":9,"spd":10}, "rep_req":{"faction":"rangers","min":250}, "price":90},
	"robe_cercle": {"name":"Robe du Cercle d'Ozias", "type":"armor", "icon":"armor.png", "bonus":{"def":5,"mana":20,"hp":10}, "rep_req":{"faction":"cercle","min":250}, "price":90},
	"epee_fer": {"name":"Épée de Fer", "type":"weapon", "icon":"sword.png", "bonus":{"atk":5}},
	"arc_chasse": {"name":"Arc de Chasse", "type":"weapon", "icon":"bow.png", "bonus":{"atk":4,"spd":5}},
	"baton_novice": {"name":"Bâton du Novice", "type":"weapon", "icon":"staff.png", "bonus":{"atk":6,"mana":10}},
	"armure_cuir": {"name":"Armure de Cuir", "type":"armor", "icon":"armor2.png", "bonus":{"def":4,"hp":10}},
	"bottes_loup": {"name":"Bottes en Peau de Loup", "type":"armor", "icon":"boots.png", "bonus":{"spd":12,"def":2}},
	"armure_plates": {"name":"Armure de Plates", "type":"armor", "icon":"shield.png", "bonus":{"def":8,"hp":20}},
	# --- Matieres et pieces des quatre nouvelles zones ---
	"eclat_runique": {"name":"Éclat Runique", "type":"mat", "icon":"gem.png"},
	"givre_eternel": {"name":"Givre Éternel", "type":"mat", "icon":"potion_blue.png"},
	"braise_vive": {"name":"Braise Vive", "type":"mat", "icon":"gem.png"},
	"poussiere_ame": {"name":"Poussière d'Âme", "type":"mat", "icon":"gem.png"},
	"coeur_pierre": {"name":"Coeur de Pierre du Gardien", "type":"quest", "icon":"chest.png"},
	"corne_jarl": {"name":"Corne du Jarl Givrefer", "type":"quest", "icon":"chest.png"},
	"sceau_braise": {"name":"Sceau de Braise", "type":"quest", "icon":"chest.png"},
	"couronne_ossuaire": {"name":"Couronne d'Ossuaire", "type":"quest", "icon":"chest.png"},
	"dague_runique": {"name":"Dague Runique", "type":"weapon", "icon":"dagger.png", "bonus":{"atk":12,"spd":8}},
	"plastron_runique": {"name":"Plastron Runique", "type":"armor", "icon":"armor2.png", "bonus":{"def":10,"hp":22}},
	"heaume_givre": {"name":"Heaume de Givrefer", "type":"armor", "icon":"helmet.png", "bonus":{"def":14,"hp":30}},
	"lance_glace": {"name":"Lance de Glace", "type":"weapon", "icon":"staff.png", "bonus":{"atk":14,"mana":20}},
	"lame_braise": {"name":"Lame de Braise", "type":"weapon", "icon":"sword.png", "bonus":{"atk":18,"hp":10}},
	"armure_scories": {"name":"Armure de Scories", "type":"armor", "icon":"armor.png", "bonus":{"def":17,"hp":38}},
	"sceptre_ombrelune": {"name":"Sceptre d'Ombrelune", "type":"weapon", "icon":"staff.png", "bonus":{"atk":22,"mana":45}},
	"armure_ossuaire": {"name":"Armure d'Ossuaire", "type":"armor", "icon":"armor.png", "bonus":{"def":22,"hp":50}},
	"faux_vhalmir": {"name":"Faux de Vhalmir", "type":"weapon", "icon":"axe.png", "bonus":{"atk":26,"def":-3}},
	"potion_vie": {"name":"Potion de Vie", "type":"consumable", "icon":"potion_red.png", "heal":55, "use_cd":5.0},
	"potion_mana": {"name":"Potion de Mana", "type":"consumable", "icon":"potion_blue.png", "mana":40},
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

# Repositionnes pour la disposition en croix (voir ZONES) : plaine (est) garde ses
# coordonnees d'origine +2000/+2000 ; foret (nord)/caverne (ouest)/marais (sud)
# sont pivotees pour rester a une distance equivalente de Val-Repos dans leur
# nouvel axe (proche du village = pres du bord partage avec lui).
const GATHER_NODES := [
	{"type":"bois","x":3650,"y":2300}, {"type":"bois","x":3800,"y":2850}, {"type":"bois","x":2292,"y":1600},
	{"type":"bois","x":3050,"y":1300}, {"type":"bois","x":2583,"y":800},
	{"type":"minerai","x":4100,"y":2900}, {"type":"minerai","x":1700,"y":2300}, {"type":"minerai","x":1000,"y":2850},
	{"type":"minerai","x":400,"y":2500},
	{"type":"herbe","x":3900,"y":2500}, {"type":"herbe","x":4600,"y":2300}, {"type":"herbe","x":2817,"y":1800},
	{"type":"herbe","x":2933,"y":500},
	{"type":"bois","x":2350,"y":3600}, {"type":"bois","x":2992,"y":4300},
	{"type":"minerai","x":2467,"y":4600},
	{"type":"herbe","x":3050,"y":3700}, {"type":"herbe","x":2700,"y":4900},
	# Ruines de Kaldremm : on fouille les gravats, on ne bucheronne pas.
	{"type":"minerai","x":3900,"y":700}, {"type":"minerai","x":4700,"y":1500}, {"type":"minerai","x":4200,"y":1250},
	{"type":"herbe","x":3700,"y":1600}, {"type":"bois","x":4900,"y":500},
	# Cimes de Givrefer : filons a nu dans la roche gelee.
	{"type":"minerai","x":600,"y":600}, {"type":"minerai","x":1500,"y":1300}, {"type":"minerai","x":300,"y":1600},
	{"type":"bois","x":1200,"y":400}, {"type":"herbe","x":900,"y":1100},
	# Fosse de Braisombre : mineraux cuits, presque rien de vivant.
	{"type":"minerai","x":500,"y":3700}, {"type":"minerai","x":1400,"y":4400}, {"type":"minerai","x":900,"y":4900},
	{"type":"bois","x":1600,"y":3600}, {"type":"herbe","x":400,"y":4200},
	# Necropole d'Ombrelune : herbes funeraires et pierre taillee.
	{"type":"herbe","x":3800,"y":3700}, {"type":"herbe","x":4800,"y":4600}, {"type":"herbe","x":4200,"y":4100},
	{"type":"minerai","x":4600,"y":3600}, {"type":"bois","x":3600,"y":4800},
]

const NPCS := [
	{"id":"ancien", "name":"l'Ancien Malorin", "x":2400, "y":2400, "role":"quest_turnin", "tint":Color(1,1,1), "lore":[
		"\"Val-Repos fut bâti par des colons fuyant la chute du vieux royaume, il y a trois générations. Les fondations que tu vois sous l'auberge sont d'origine.\"",
		"\"Autrefois la Forêt de Sylvombre s'étendait jusqu'aux portes du village. On a coupé pour bâtir, et la forêt n'a jamais pardonné — demande aux rôdeurs.\"",
		"\"La Caverne des Ossements n'a pas toujours porté ce nom. Avant les squelettes, on l'appelait la Grotte aux Échos. Je préfère l'ancien nom, personnellement.\"",
	]},
	{"id":"forgeron_pnj", "name":"Grondar le Forgeron", "x":2600, "y":2600, "role":"profession", "profession":"forgeron", "tint":Color(0.53,0.53,0.53), "lore":[
		"\"Le bon minerai vient de la Plaine d'Aubval — plus friable, plus facile à purifier que celui de la caverne. Mais celui de la caverne fait de meilleures lames.\"",
		"\"Mon grand-père forgeait déjà ici. Il disait qu'un vrai forgeron reconnaît la qualité d'un métal au son qu'il fait sur l'enclume, pas à sa couleur.\"",
		"\"Je n'ai jamais réussi à reproduire les techniques des anciennes armures qu'on trouve parfois en fouillant. Un savoir perdu, sans doute.\"",
	]},
	{"id":"alchimiste_pnj", "name":"Yvenne l'Alchimiste", "x":2700, "y":2300, "role":"profession", "profession":"alchimiste", "tint":Color(0.56,0.29,0.85), "lore":[
		"\"La gelée de slime est étonnamment stable en potion — c'est l'ichor putride du marais qui est délicat, il faut le travailler vite avant qu'il ne tourne.\"",
		"\"On m'a longtemps prise pour une sorcière. Je préfère 'chimiste appliquée', mais bon, dans ce village les nuances ne portent pas loin.\"",
		"\"Les fleurs de la plaine et les champignons de Sylvombre ne se marient jamais bien en potion. J'ai essayé. Trois fois. Ne recommencez pas mon erreur.\"",
	]},
	{"id":"marchand", "name":"Bosk le Marchand", "x":2500, "y":2750, "role":"shop", "tint":Color(0.85,0.76,0.29), "lore":[
		"\"Mes prix montent avec la demande, baissent avec le stock — c'est pas de la magie, c'est du commerce. Demandez à Yvenne pour la magie.\"",
		"\"J'ai fait la route entre trois villages avant de m'installer ici. Val-Repos a le marché le plus honnête que j'aie vu — enfin, presque.\"",
		"\"Un jour un aventurier m'a vendu une amulette du marais encore tiède. Je n'ai pas posé de questions. Je pose rarement des questions.\"",
	]},
	{"id":"garde", "name":"Garde Ren", "x":3300, "y":2500, "role":"quest", "tint":Color(0.29,0.43,0.85), "lore":[
		"\"La frontière entre le village et la plaine n'a jamais été aussi calme qu'aujourd'hui — et ça, ça m'inquiète plus que ça me rassure.\"",
		"\"On m'a affecté ici après mon service dans la garde royale. Moins de gloire, mais je dors mieux. La plupart des nuits.\"",
		"\"Les loups de la plaine chassent en meute organisée depuis peu. Ce n'est pas naturel pour des loups ordinaires.\"",
	]},
	{"id":"fermier", "name":"Fermier Otto", "x":3900, "y":2700, "role":"quest", "tint":Color(0.85,0.56,0.29), "lore":[
		"\"Mes récoltes ont doublé depuis que les patrouilles du village repoussent les gobelins hors de mes champs. Petit prix à payer en impôts, franchement.\"",
		"\"Mon père labourait cette terre avant les loups alpha. Il disait que la plaine était plus sauvage encore de son temps. Difficile à croire.\"",
		"\"Je troque mes légumes contre les potions de Yvenne. Elle prétend que ça la 'venge' des champignons de la forêt. Je n'ai jamais compris la blague.\"",
	]},
	{"id":"eclaireur", "name":"Éclaireuse Lira", "x":2350, "y":1300, "role":"quest", "tint":Color(0.29,0.85,0.43), "lore":[
		"\"Sylvombre porte bien son nom : même en plein midi, la canopée ne laisse passer qu'un filet de lumière. On s'y perd vite si on ne connaît pas les sentiers.\"",
		"\"Les lucioles qu'on voit la nuit ne sont pas de simples insectes — les anciens de la forêt disent qu'elles suivent les voyageurs égarés jusqu'à un chemin sûr.\"",
		"\"J'ai cartographié la moitié de cette forêt et je découvre encore des clairières inconnues. Sylvombre garde ses secrets.\"",
	]},
	{"id":"ranger", "name":"Ranger Doff", "x":3050, "y":1800, "role":"quest", "tint":Color(0.18,0.54,0.23), "lore":[
		"\"Les gobelins de Sylvombre ne sont pas bêtes — ils évitent nos pièges depuis qu'on en a posé un peu trop souvent au même endroit. On varie, maintenant.\"",
		"\"Un tronc abattu dans cette forêt n'est jamais du bois mort bien longtemps — la mousse et les champignons colonisent tout en quelques semaines à peine.\"",
		"\"Je chasse ici depuis quinze ans. Je n'ai toujours pas vu la lisière est de la forêt, du côté de la caverne. Certains coins ne m'attirent pas.\"",
	]},
	{"id":"pretre", "name":"Prêtre Ozias", "x":1800, "y":2600, "role":"quest", "tint":Color(0.85,0.85,0.85), "lore":[
		"\"On m'appelait autrefois la 'Grotte aux Échos', avant qu'elle ne devienne la Caverne des Ossements. Les échos, eux, n'ont jamais cessé.\"",
		"\"Je prie ici pour apaiser les morts qui n'ont pas trouvé le repos. Certains jours, j'ai l'impression qu'ils m'écoutent. D'autres jours, moins.\"",
		"\"Les cristaux qu'on trouve dans la roche ne sont pas naturels — je crois qu'ils sont nés du même rituel qui a peuplé cette grotte de squelettes.\"",
	]},
	{"id":"hulda", "name":"Vieille Hulda", "x":2700, "y":3400, "role":"quest", "tint":Color(0.55,0.7,0.4), "lore":[
		"\"Le Marais Putride n'a pas toujours empesté ainsi. C'est le rituel raté d'un nécromancien d'autrefois qui a corrompu ces eaux, il y a bien longtemps.\"",
		"\"Les feux follets qui dansent la nuit sur les mares ne sont pas de simples gaz — ce sont les âmes de ceux que le marais a pris et n'a jamais rendus.\"",
		"\"Le Coeur du Marais que je cherche à récupérer contient ce qu'il reste du rituel original. Le détruire pourrait bien purifier ces terres. Ou pas.\"",
	]},
	{"id":"chasseur", "name":"Chasseur Kessler", "x":3100, "y":2450, "role":"bounty", "tint":Color(0.6,0.45,0.25), "lore":[
		"\"Les primes payent mieux que la chasse ordinaire, mais elles attirent aussi les têtes brûlées. Je préfère les aventuriers qui savent quand fuir.\"",
		"\"J'ai traqué un loup alpha pendant trois semaines avant de comprendre qu'il me traquait aussi. On a fini par se laisser tranquilles, tous les deux.\"",
		"\"Chaque prime raconte une histoire — une ferme attaquée, une caravane perdue. Je ne les affiche jamais sans vérifier qu'elles sont vraies.\"",
	]},
	{"id":"maitre_armes_pnj", "name":"Maître Thoric", "x":2800, "y":2500, "role":"respec", "tint":Color(0.8,0.65,0.3), "lore":[
		"\"Changer de voie n'est pas une honte — j'ai moi-même été trois choses avant de devenir maître d'armes. On ne trouve pas toujours sa voie du premier coup.\"",
		"\"J'ai formé la moitié de la garde du village. Certains soirs, je regrette de ne pas avoir mieux formé Ren aux patrouilles de nuit.\"",
		"\"Un guerrier qui ne doute jamais de ses choix n'apprend jamais rien de nouveau. Le doute, bien dirigé, est un outil comme un autre.\"",
	]},
	# --- Habitants des quatre nouvelles zones ---
	# Une region sans personne a qui parler reste un decor. Chacune a son
	# temoin, poste pres de son entree, qui explique ce qu'on regarde et la
	# rattache au reste du monde (Kaldremm est le "vieux royaume" dont l'Ancien
	# Malorin dit que les colons de Val-Repos ont fui la chute).
	{"id":"archeologue", "name":"Sivelle l'Archéologue", "x":4300, "y":1750, "role":"quest", "tint":Color(0.85,0.75,0.5), "lore":[
		"\"Kaldremm, c'est le vieux royaume. Celui que les fondateurs de Val-Repos ont fui. Ils n'ont jamais raconté pourquoi — moi, je creuse pour le savoir.\"",
		"\"Les sentinelles de pierre ne sont pas des statues animées : ce sont les gardes de la cité, changés en pierre pendant leur tour de garde. Ils tiennent encore leur poste.\"",
		"\"Les pillards qui rôdent ici ne cherchent que de l'or. Ils passent à côté de l'essentiel : ces ruines racontent comment un royaume entier a pu disparaître en une nuit.\"",
	]},
	{"id":"guide_montagne", "name":"Brann le Guide", "x":1200, "y":1750, "role":"quest", "tint":Color(0.7,0.85,0.95), "lore":[
		"\"Les Cimes de Givrefer ne pardonnent pas l'imprudence. Le froid tue plus d'aventuriers que les loups — et pourtant les loups en tuent beaucoup.\"",
		"\"Le Jarl Givrefer régnait sur un clan, avant. Le gel l'a pris sans le tuer. Il commande toujours, mais à des colosses de glace maintenant.\"",
		"\"Le givre éternel qu'on récolte ici ne fond jamais, même dans une forge. Yvenne l'Alchimiste m'en achète tout ce que je descends.\"",
	]},
	{"id":"forgeron_cendres", "name":"Karsk des Cendres", "x":1200, "y":3450, "role":"quest", "tint":Color(0.85,0.45,0.3), "lore":[
		"\"La Fosse brûle depuis avant ma naissance et brûlera après ma mort. Personne ne sait ce qui l'alimente. Personne ne descend assez profond pour vérifier.\"",
		"\"La braise vive garde sa chaleur des années. Grondar refuse d'en travailler — il dit que ça déforme le métal. Il a raison, mais ça fait de meilleures lames.\"",
		"\"Le Seigneur Braise était un orc, avant. La Fosse ne tue pas toujours : parfois elle garde, et transforme. C'est bien pire.\"",
	]},
	{"id":"gardienne_tombes", "name":"Soeur Vaelis", "x":3700, "y":3450, "role":"quest", "tint":Color(0.6,0.5,0.75), "lore":[
		"\"Ombrelune est la dernière nécropole du vieux royaume. Tout ce que Kaldremm a perdu est enterré ici — y compris ce qu'il aurait mieux valu brûler.\"",
		"\"Le Roi Ossuaire Vhalmir a été enseveli avec sa couronne, sa garde et sa rancune. Deux de ces trois choses se sont relevées.\"",
		"\"Le Prêtre Ozias prie pour apaiser les morts de sa grotte. Ici, prier ne suffit plus depuis longtemps. Ici, on tranche.\"",
	]},
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

	# --- Ruines de Kaldremm (8-14) : branche parallèle à la fin de la forêt ---
	# La progression guidée s'arrêtait au niveau 21 alors que le niveau maximum
	# est 30 : passé le marais, plus une seule quête ne disait où aller. Les
	# quatre nouvelles zones prolongent la chaîne jusqu'au bout.
	{"id":"q_vers_ruines","name":"Les Pierres du Vieux Royaume","giver":"ancien","requires":["q_chasse_profonde"],"level":8,
		"desc":"L'Ancien évoque enfin le royaume que les fondateurs ont fui. Une archéologue, Sivelle, fouille ses ruines au nord-est de la plaine.",
		"obj":{"type":"talk","target":"archeologue","count":1}, "reward":{"xp":140,"gold":60}},
	{"id":"q_pillards","name":"Chasse aux Pillards","giver":"archeologue","requires":["q_vers_ruines"],"level":9,
		"desc":"Les pillards saccagent le site plus vite que Sivelle ne peut le fouiller. Élimine 12 Pillards de Kaldremm.",
		"obj":{"type":"kill","target":["pillard"],"count":12}, "reward":{"xp":280,"gold":120}},
	{"id":"q_eclats","name":"Fragments de Mémoire","giver":"archeologue","requires":["q_vers_ruines"],"level":10,
		"desc":"Chaque éclat runique porte un morceau des archives de la cité. Rapportes-en 8.",
		"obj":{"type":"gather_drop","target":"eclat_runique","count":8}, "reward":{"xp":300,"gold":130}},
	{"id":"q_sentinelles","name":"La Garde Pétrifiée","giver":"archeologue","requires":["q_pillards"],"level":12,
		"desc":"Les sentinelles tiennent encore leur poste et frappent tout ce qui approche. Abats-en 10.",
		"obj":{"type":"kill","target":["sentinelle_pierre"],"count":10}, "reward":{"xp":420,"gold":180,"items":["plastron_runique"]}},
	{"id":"q_ruines_boss","name":"Le Gardien de Kaldremm","giver":"archeologue","requires":["q_sentinelles","q_eclats"],"level":14,
		"desc":"Un Gardien colossal barre l'accès au coeur de la cité. Vaincs-le.",
		"obj":{"type":"boss","target":"gardien_kaldremm","count":1}, "reward":{"xp":650,"gold":280,"items":["dague_runique"]}},
	{"id":"q_ruines_final","name":"Ce que Kaldremm a Caché","giver":"archeologue","requires":["q_ruines_boss"],"level":14,
		"desc":"Le Coeur de Pierre du Gardien contient les dernières heures de la cité. Porte-le à l'Ancien Malorin.",
		"obj":{"type":"deliver","target":"ancien","item":"coeur_pierre","count":1}, "reward":{"xp":520,"gold":260}},

	# --- Cimes de Givrefer (14-20) : au nord-ouest, au-dessus de la caverne ---
	{"id":"q_vers_cimes","name":"L'Appel des Cimes","giver":"pretre","requires":["q_echo_caverne"],"level":14,
		"desc":"Les échos de la grotte viennent des hauteurs gelées au-dessus. Trouve Brann le Guide, à l'entrée des Cimes de Givrefer.",
		"obj":{"type":"talk","target":"guide_montagne","count":1}, "reward":{"xp":200,"gold":90}},
	{"id":"q_loups_givre","name":"La Meute Blanche","giver":"guide_montagne","requires":["q_vers_cimes"],"level":15,
		"desc":"Les Loups de Givre descendent chasser jusqu'aux sentiers. Élimines-en 14.",
		"obj":{"type":"kill","target":["loup_givre"],"count":14}, "reward":{"xp":420,"gold":180}},
	{"id":"q_givre","name":"Le Froid qui Dure","giver":"guide_montagne","requires":["q_vers_cimes"],"level":16,
		"desc":"Le givre éternel ne fond jamais. Rapportes-en 8 à Brann, qui les revend à l'alchimiste.",
		"obj":{"type":"gather_drop","target":"givre_eternel","count":8}, "reward":{"xp":440,"gold":190}},
	{"id":"q_colosses","name":"Colosses des Hauteurs","giver":"guide_montagne","requires":["q_loups_givre"],"level":18,
		"desc":"Les Colosses de Gel bloquent le col menant au Jarl. Abats-en 8.",
		"obj":{"type":"kill","target":["colosse_gel"],"count":8}, "reward":{"xp":560,"gold":250,"items":["heaume_givre"]}},
	{"id":"q_cimes_boss","name":"Le Jarl Givrefer","giver":"guide_montagne","requires":["q_colosses","q_givre"],"level":20,
		"desc":"Le Jarl règne sur les Cimes depuis que le gel l'a pris. Mets fin à son règne.",
		"obj":{"type":"boss","target":"jarl_givrefer","count":1}, "reward":{"xp":850,"gold":400,"items":["lance_glace"]}},
	{"id":"q_cimes_final","name":"La Corne du Jarl","giver":"guide_montagne","requires":["q_cimes_boss"],"level":20,
		"desc":"Porte la Corne du Jarl au Prêtre Ozias : il saura si le clan peut enfin reposer.",
		"obj":{"type":"deliver","target":"pretre","item":"corne_jarl","count":1}, "reward":{"xp":700,"gold":340}},

	# --- Fosse de Braisombre (20-26) : au sud-ouest, sous la caverne ---
	{"id":"q_vers_fosse","name":"La Fosse qui Brûle","giver":"hulda","requires":["q_marais_final"],"level":21,
		"desc":"À l'ouest du marais, une fosse brûle depuis des générations. Karsk des Cendres y forge encore. Va le voir.",
		"obj":{"type":"talk","target":"forgeron_cendres","count":1}, "reward":{"xp":260,"gold":120}},
	{"id":"q_cendreux","name":"Ceux que la Cendre a Pris","giver":"forgeron_cendres","requires":["q_vers_fosse"],"level":22,
		"desc":"Les Cendreux errent autour des coulées et lancent des braises. Élimines-en 14.",
		"obj":{"type":"kill","target":["cendreux"],"count":14}, "reward":{"xp":600,"gold":260}},
	{"id":"q_braises","name":"Chaleur Persistante","giver":"forgeron_cendres","requires":["q_vers_fosse"],"level":23,
		"desc":"Karsk a besoin de 10 Braises Vives pour sa prochaine coulée.",
		"obj":{"type":"gather_drop","target":"braise_vive","count":10}, "reward":{"xp":620,"gold":280}},
	{"id":"q_orcs_brulure","name":"Les Orcs Brûlure","giver":"forgeron_cendres","requires":["q_cendreux"],"level":24,
		"desc":"La Fosse a transformé un clan orc entier. Abats 10 Orcs Brûlure.",
		"obj":{"type":"kill","target":["orc_brulure"],"count":10}, "reward":{"xp":760,"gold":330,"items":["armure_scories"]}},
	{"id":"q_fosse_boss","name":"Le Seigneur Braise","giver":"forgeron_cendres","requires":["q_orcs_brulure","q_braises"],"level":26,
		"desc":"Ce qui commande la Fosse était un orc, autrefois. Descends et affronte-le.",
		"obj":{"type":"boss","target":"seigneur_braise","count":1}, "reward":{"xp":1100,"gold":520,"items":["lame_braise"]}},
	{"id":"q_fosse_final","name":"Le Sceau de Braise","giver":"forgeron_cendres","requires":["q_fosse_boss"],"level":26,
		"desc":"Le Sceau retenait quelque chose sous la Fosse. Rapporte-le à Karsk avant de l'apprendre à tes dépens.",
		"obj":{"type":"deliver","target":"forgeron_cendres","item":"sceau_braise","count":1}, "reward":{"xp":900,"gold":450}},

	# --- Nécropole d'Ombrelune (26-30) : la fin du jeu ---
	{"id":"q_vers_necropole","name":"La Dernière Nécropole","giver":"ancien","requires":["q_fosse_final","q_ruines_final"],"level":26,
		"desc":"Tout ce que Kaldremm a perdu est enterré au sud-est. Soeur Vaelis y monte la garde. Rejoins-la.",
		"obj":{"type":"talk","target":"gardienne_tombes","count":1}, "reward":{"xp":400,"gold":200}},
	{"id":"q_spectres","name":"Ceux qui n'ont pas de Tombe","giver":"gardienne_tombes","requires":["q_vers_necropole"],"level":27,
		"desc":"Les Spectres d'Ombrelune frappent de loin et ne se laissent pas approcher. Disperses-en 16.",
		"obj":{"type":"kill","target":["spectre"],"count":16}, "reward":{"xp":900,"gold":420}},
	{"id":"q_poussiere","name":"Poussière d'Âme","giver":"gardienne_tombes","requires":["q_vers_necropole"],"level":28,
		"desc":"Vaelis a besoin de 12 Poussières d'Âme pour sceller à nouveau les caveaux.",
		"obj":{"type":"gather_drop","target":"poussiere_ame","count":12}, "reward":{"xp":950,"gold":440}},
	{"id":"q_chevaliers","name":"La Garde Déchue","giver":"gardienne_tombes","requires":["q_spectres"],"level":29,
		"desc":"La garde de Vhalmir s'est relevée avec lui. Abats 10 Chevaliers Déchus.",
		"obj":{"type":"kill","target":["chevalier_dechu"],"count":10}, "reward":{"xp":1200,"gold":560,"items":["armure_ossuaire"]}},
	{"id":"q_necropole_boss","name":"Le Roi Ossuaire","giver":"gardienne_tombes","requires":["q_chevaliers","q_poussiere"],"level":30,
		"desc":"Vhalmir a été enseveli avec sa couronne et sa rancune. Il est temps de lui reprendre les deux.",
		"obj":{"type":"boss","target":"roi_ossuaire","count":1}, "reward":{"xp":1800,"gold":900,"items":["sceptre_ombrelune"]}},
	{"id":"q_necropole_final","name":"La Couronne d'Ossuaire","giver":"gardienne_tombes","requires":["q_necropole_boss"],"level":30,
		"desc":"Porte la Couronne à l'Ancien Malorin. Val-Repos peut enfin refermer l'histoire du vieux royaume.",
		"obj":{"type":"deliver","target":"ancien","item":"couronne_ossuaire","count":1}, "reward":{"xp":1500,"gold":800,"items":["faux_vhalmir"]}},
]

func get_quest(id: String) -> Dictionary:
	for q in QUESTS:
		if q.id == id: return q
	return {}

func get_npc(id: String) -> Dictionary:
	for n in NPCS:
		if n.id == id: return n
	return {}

func zone_at(x: float, y: float) -> Dictionary:
	for key in ZONES:
		var z = ZONES[key]
		if x >= z.x0 and x < z.x1 and y >= z.y0 and y < z.y1: return z
	return VOID_ZONE

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
	"q_vers_ruines":"garde", "q_pillards":"rangers", "q_eclats":"cercle", "q_sentinelles":"rangers",
	"q_ruines_boss":"rangers", "q_ruines_final":"garde",
	"q_vers_cimes":"cercle", "q_loups_givre":"rangers", "q_givre":"cercle", "q_colosses":"rangers",
	"q_cimes_boss":"rangers", "q_cimes_final":"cercle",
	"q_vers_fosse":"cercle", "q_cendreux":"cercle", "q_braises":"garde", "q_orcs_brulure":"rangers",
	"q_fosse_boss":"rangers", "q_fosse_final":"garde",
	"q_vers_necropole":"garde", "q_spectres":"cercle", "q_poussiere":"cercle", "q_chevaliers":"cercle",
	"q_necropole_boss":"cercle", "q_necropole_final":"garde",
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
