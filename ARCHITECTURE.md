# mHUB — architecture proposée (à valider, aucun code écrit)

Hub du **Mac Desktop Toolkit** : catalogue, installation, mises à jour, lancement et réglages des applis, depuis une seule icône.
Design : Flat Round, arrondis 20 (clair/sombre). Swift/SwiftUI + AppKit, app d'agent (`LSUIElement`), 4 langues (clés `hub.*`).

## Décisions (19/11/2026)
Design Flat Round, arrondis 20 · icône de barre des menus en couleur · téléchargement depuis les releases GitHub publiques seulement · le Hub met à jour toutes les applis (leur mise à jour intégrée reste en secours).

## Principe
Le Hub ne héberge pas les applis : chaque appli reste un processus indépendant. Le Hub catalogue, installe, met à jour, lance et pilote leur présence.

## Modules
| Module | Rôle |
|---|---|
| `Catalog` | Lit `catalogue.json` (id, nom, bundle id, dépôt GitHub, catégorie, descriptions fr/en/es/it, icône, macOS minimum, schéma d'URL). Copie locale en cache, mise à jour avec le Hub. |
| `Scanner` | Détecte les applis installées par bundle id (LaunchServices) et lit leur version dans l'Info.plist. |
| `Installer` | Dernière release GitHub → télécharge le `.zip` → vérifie la signature Developer ID (même équipe) et la notarisation → copie dans `~/Applications/Applications Personnelles` → retire la quarantaine. Annulation, reprise, erreurs lisibles. |
| `Updater` | Vérification quotidienne ; compare versions ; « Tout mettre à jour » ; jamais pendant qu'une appli tourne (propose « Quitter et mettre à jour »). Option « installer automatiquement ». Se met aussi à jour lui-même (modèle `mBACKUP/Sources/Updater.swift`). |
| `AppControl` | Ouvrir, quitter, lancer à l'ouverture de session, ouvrir les réglages (voir contrat). |
| `Presence` | Icône unique en barre des menus (bouton + `menu.popUp` sous l'icône, jamais `statusItem.menu`), préférence Dock / barre / les deux (modèle `hERALD/Sources/Presence.swift`). |
| `Views` | Catalogue, fiche appli, activité, réglages, À propos (`AboutWindow.swift` de Socle). |

## Contrat léger avec les applis (adoption progressive)
1. Schéma d'URL `<appid>://settings` ouvre les réglages de l'appli (sans cela : l'entrée « Réglages » est masquée).
2. Préférence partagée « icône dans la barre des menus » : le Hub écrit une notification distribuée `fr.starbudweiser.toolkit.presence` (`appid`, `visible`) ; l'appli l'applique et mémorise. Sans cela : la bascule est masquée.
3. Le Hub reste utile sans rien de tout ça (installer, mettre à jour, ouvrir).

## Dev / livraison
Version de dev `….dev` ; mise à jour locale par `_tools/build_all.sh mHUB` ; ajout à la liste APPS de `build_all.sh` ; icône via iCONIQ ; dépôt GitHub `starbudweiser/mHUB` ; `release.sh` + notarisation à ta demande.

## Hors périmètre v1
Panneau de réglages unifié des autres applis, hébergement de leurs interfaces, applis Skyrim (autre collection, le format du catalogue le permettrait plus tard).
