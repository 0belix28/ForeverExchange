# Changelog

## 0.5.0

- **Analyse qui fonctionne sur WoW Forever** : le serveur n'envoie pas la liste complète des enchères (les analyses restaient sans résultat). Après 10 s sans réponse, ForeverExchange lance une recherche vide à l'HV et lit toutes les pages de résultats : prix minimum et quantité de chaque objet. (Dans ce mode, la valeur marché est égale au prix minimum.)
- Option **« Comparer avec l'objet équipé »** (désactivée par défaut) : affiche ou non la comparaison avec ton équipement quand tu survoles un objet dans ForeverExchange.
- Surbrillance des lignes translucide : la ligne survolée reste entièrement lisible.

## 0.4.1

- Plus de délai de 15 min imposé par l'addon : le bouton s'appelle **« Analyser »** et n'est grisé (« Analyse en cours… ») que pendant une analyse.
- Analyse plus robuste : en plus du signal du serveur, l'addon vérifie chaque seconde si la liste des enchères est arrivée, et prévient si le serveur ne l'envoie pas (3 min max).
- « Relevé » devient « Analyse » dans tous les textes.

## 0.4.0

- **Onglet « ForeverExchange » dans l'hôtel des ventes**, à côté d'Acheter / Vendre / Ventes (et des onglets d'Auctionator) : logo, barre de progression du relevé, bouton « Relever les prix », « Ouvrir ForeverExchange », « Options » et case « Relever les prix automatiquement ». Il remplace le bouton au-dessus de l'HV.
- Le relevé complet lancé par un autre addon (ex. Auctionator à l'ouverture de l'HV) est maintenant détecté : ForeverExchange lit les mêmes données au lieu de redemander un relevé que le serveur refuserait (1 par 15 min). Corrige « Aucun relevé » quand Auctionator scannait en même temps.
- La fenêtre s'ouvre à côté de l'HV quand il est ouvert.

## 0.3.2

- Catégories obsolètes du jeu (« Jewelry(OBSOLETE) », « Generic(OBSOLETE) »…) masquées.
- Correction des avertissements « Bindings.xml: Unrecognized XML » : le fichier des raccourcis clavier est chargé automatiquement par le jeu et ne doit pas figurer dans le TOC.

## 0.3.1

- **Sous-catégories de l'HV** : la liste de gauche reprend l'arbre de l'hôtel des ventes de WoW Forever, sur trois niveaux comme sur Retail (ex. Armures > Plaques > Tête). Il est recopié à chaque ouverture de l'HV et disponible ensuite partout ; avant la première ouverture, un arbre équivalent est construit à partir des classes d'objets.
- Cliquer une catégorie la déplie, recliquer dessus la replie.

## 0.3.0

- **Nouvelle fenêtre au style de l'hôtel des ventes** : portrait avec le logo, barre de recherche (bouton Favoris, champ de recherche, Filtre, Rechercher), **liste des catégories** à gauche (Favoris, Tous les objets, puis les catégories de l'HV avec leurs sous-catégories), liste façon HV (en-têtes triables, lignes rayées), onglets en bas (Parcourir, Prix bas, Tendances).
- **Favoris** : étoile sur chaque ligne et sur la fiche d'un objet ; catégorie « Favoris » et bouton étoile pour les afficher.
- La fiche d'un objet (stats + graphique) s'ouvre à la place de la liste, avec un bouton « Retour ».
- Filtre « En vente uniquement » et « Réinitialiser la recherche ».
- Le bouton « Scan complet » devient « Relever les prix » ; les cases à cocher du bas sont dans le panneau d'options.

## 0.2.1

- Nouveau logo : la pièce d'or (128×128), partout où le logo apparaît (options, minicarte, fenêtre, liste des addons).

## 0.2.0

- **Panneau d'options** avec le logo (Échap > Options > AddOns > ForeverExchange, `/fx options`, bouton « Options » de la fenêtre ou clic droit sur le bouton de la minicarte) : bouton de la minicarte, prix dans les infobulles, relevé automatique, réglages Prix bas / Tendances, statistiques des données, effacement des données.
- **Bouton sur la minicarte** avec le logo (déplaçable) pour ouvrir l'addon n'importe où.
- Logo dans la liste des addons et dans la fenêtre.
- **Consultation uniquement** : retrait de « Chercher à l'HV » et du clic droit qui lançait une recherche d'achat ; l'onglet « Bonnes affaires » devient « Prix bas ».

## 0.1.0

- Première version : l'équivalent d'undermine.exchange, en jeu, pour l'HV de WoW Forever.
- **Scan complet** de l'hôtel des ventes (toutes les enchères d'un coup, autorisé par le serveur toutes les 15 min) : automatique à l'ouverture de l'HV, ou bouton « Scan complet » / `/fx scan`. Si un autre addon lance un scan complet, ForeverExchange en profite aussi.
- Les recherches faites à l'HV mettent à jour le prix minimum en direct (marchandises comprises).
- Pour chaque objet : prix minimum, **valeur marché** (moyenne des 15 % d'unités les moins chères), quantité, nombre d'enchères, moyennes 7 j / 30 j, plus bas / plus haut 30 j, évolution sur 7 j.
- **Historique** conservé 120 jours : un point par heure sur 48 h, puis un point par jour.
- Onglet **Recherche** : recherche par nom (accents ignorés), catégorie, en vente / favoris, colonnes triables.
- Onglet **Bonnes affaires** : objets en vente bien en dessous de leur moyenne 30 j (seuil et valeur minimale réglables).
- Onglet **Tendances** : plus fortes hausses et baisses sur 7 jours.
- Onglet **Objet** : fiche détaillée avec **graphique** (prix min, valeur marché, quantité ; 48 h / 7 j / 30 j / tout, survol pour les valeurs), favori, « Chercher à l'HV ».
- Prix dans les **infobulles** de tous les objets (désactivable).
- Fenêtre : `/fx`, raccourci clavier, bouton des addons de la minicarte, bouton « ForeverExchange » sur la fenêtre de l'HV.
