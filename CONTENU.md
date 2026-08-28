# Rien du Pout Online — Contenu du jeu

Récapitulatif de ce qui existe actuellement, pour s'y retrouver.

## Personnage

- **6 races** : Humain, Elfe Sylvain, Nain des Forges, Orc des Terres Brisées, Ratkin, Golem de Pierre Vivante
- **6 classes** : Guerrier/Tank, Mage Élémentaire, Soigneur/Prêtre, Rôdeur/Chasseur, Voleur/Assassin, Barde/Support
- **Spécialisations (talents)** : 2 choix à Nv.5 et Nv.15 par classe, permanents mais réinitialisables (Maître Thoric, village, contre de l'or)
- **5 métiers jouables** : Mineur, Bûcheron, Herboriste, Forgeron, Alchimiste (+ 7 métiers de PNJ non-jouables)

## Monde (5 zones, 9200 unités de large)

| Zone | Niveau conseillé | Monstres | Boss |
|---|---|---|---|
| Val-Repos (village) | 1 | — | — |
| Plaine d'Aubval | 1-5 | Slime Vert, Slime Rouge, Loup des Plaines | Loup Alpha |
| Forêt de Sylvombre | 5-12 | Gobelin, Orc Guerrier | Chef Orc Grondmar |
| Caverne des Ossements | 10-18 | Squelette, Kobold Soldat | Squelette Guerrier |
| Marais Putride | 16-25 | Zombie, Zombie Pourrissant | Zombie Ancestral |

Les 4 boss ont des **phases** : ils invoquent des renforts à certains seuils de PV.

## Quêtes

**36 quêtes** fixes réparties en chaînes par zone, plus **6 quêtes de trame narrative par race** (une par race, visible seulement pour la race correspondante), plus un **système de primes répétables** (Chasseur Kessler, village) pour du farm à l'infini.

## Progression & confort

- **Réputation de faction** (3 factions : Garde de Val-Repos, Rangers de Sylvombre, Cercle d'Ozias), débloque 3 objets exclusifs
- **Voyage rapide** (touche M) débloqué zone par zone en les visitant
- **Réapparition contextuelle** : à l'entrée de la zone où on est mort, pas systématiquement au village
- **Sauvegarde automatique** (toutes les 20s + événements clés), bouton "Continuer" au menu

## Coop

Jusqu'à 4 joueurs via ENet (un joueur héberge, IP locale ou VPN de jeu type Hamachi/ZeroTier).

## Outils de développement (scripts/tools/)

- `capture.gd` — capture d'écran headless + framework de tests fonctionnels (16 scénarios de test couvrant combat, quêtes, primes, compétences, réputation, talents, sauvegarde, mort, voyage rapide, intégrité des données, phases de boss, respec)
- `nettest.gd` / `nettest2.gd` / `coop_test.gd` — tests de connectivité réseau
- `export_build.ps1` — régénère l'exécutable Windows

## Estimation de contenu

36 quêtes (souvent 8-20 kills + trajet, ~3-8 min chacune) + primes infinies + artisanat + exploration de 5 zones + 4 combats de boss ≈ **2h30-3h30** pour un joueur qui prend son temps, plus selon l'envie de farmer les primes/factions.
