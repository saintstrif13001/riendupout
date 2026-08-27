# Comment jouer — Rien du Pout Online

## Lancer le jeu

- **Le plus simple** : récupère `RienDuPoutOnline.exe` (généré via Godot, voir plus bas) et double-clique dessus. Aucune installation nécessaire.
- **Depuis le code source** : ouvre le dossier avec Godot 4.7+ et appuie sur F5.

## Jouer en coop (jusqu'à 4 joueurs)

1. Un joueur choisit **"Héberger (coop)"**, crée son personnage. Le jeu affiche son **adresse IP locale** (ex: `192.168.1.23`).
2. Les 3 autres joueurs choisissent **"Rejoindre"**, créent leur personnage, puis entrent l'adresse IP de l'hôte.
3. ⚠️ Tout le monde doit être sur le **même réseau local** (même Wi-Fi/box), ou connecté via un VPN de jeu type Hamachi/ZeroTier/Radmin VPN pour jouer à distance — le jeu n'utilise pas de serveur relais public.
4. Une fois tous les joueurs dans le salon, l'hôte clique sur **"Lancer la partie"**.

## Sauvegarde

Chaque joueur a sa propre sauvegarde locale (personnage, niveau, quêtes, objets). Elle se fait automatiquement toutes les 20 secondes et à chaque étape importante (montée de niveau, quête rendue, etc.). Au prochain lancement, le bouton **"Continuer"** apparaît sur le menu principal.

## Générer un nouvel exécutable (.exe)

Depuis un terminal, à la racine de ce dossier :

```
godot --headless --export-release "Windows Desktop" build/windows/RienDuPoutOnline.exe
```

(Nécessite Godot 4.7+ avec les templates d'export installés — Éditeur > Gérer les modèles d'export.)
