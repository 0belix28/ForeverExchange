# ForeverExchange

**🇫🇷 Français** · [🇬🇧 English](#-english)

> Les prix de l'hôtel des ventes de **World of Warcraft Forever**, consultables partout dans le jeu : historique, graphiques, prix bas et tendances.

ForeverExchange analyse l'hôtel des ventes quand tu l'ouvres, enregistre les prix de toutes les enchères en cours et te laisse les consulter **n'importe où**, même loin de l'HV. Il sert uniquement à **regarder les prix** : il n'achète et ne vend rien.

## ✨ Fonctionnalités

- **Analyse complète de l'HV** : tous les objets en vente sont lus (prix minimum et quantité), automatiquement à l'ouverture de l'HV ou avec le bouton « Analyser ». Si un autre addon (Auctionator par exemple) lance déjà une analyse, ForeverExchange lit les mêmes données au lieu d'en redemander une.
- **Fenêtre au style de l'hôtel des ventes** :
  - recherche par nom (sans tenir compte des accents) ;
  - **catégories et sous-catégories** de l'HV, sur trois niveaux (ex. Armures › Plaques › Tête) ;
  - **favoris** : une étoile sur chaque objet, une catégorie dédiée ;
  - colonnes triables : prix minimum, valeur marché, quantité disponible, évolution sur 7 jours.
- **Fiche de chaque objet** :
  - prix minimum, valeur marché, quantité, nombre d'enchères ;
  - moyennes sur 7 et 30 jours, plus bas et plus haut sur 30 jours ;
  - **graphique de l'historique** (48 h, 7 j, 30 j ou tout), avec les valeurs au survol.
- **Prix bas** : les objets en vente nettement sous leur prix habituel (seuil réglable).
- **Tendances** : les plus fortes hausses et baisses de la semaine.
- **Prix dans les infobulles** de tous les objets (désactivable), comparaison avec l'objet équipé en option.
- **Onglet « ForeverExchange » dans l'HV**, à côté d'Acheter / Vendre / Ventes : progression de l'analyse, ouverture de la fenêtre, options.
- **Panneau d'options** dans Échap › Options › AddOns, et **bouton sur la minicarte**.
- **Historique conservé 120 jours** : un point par heure sur 48 h, puis un point par jour.

## 📦 Installation

1. Télécharge la dernière version et décompresse-la.
2. Copie le dossier `ForeverExchange` dans `World of Warcraft\_forever_\Interface\AddOns\`.
3. Lance le jeu (ou fais `/reload`).

Aucune dépendance : ForeverExchange fonctionne seul, avec ou sans Auctionator.

## 🚀 Utilisation

1. Ouvre l'hôtel des ventes un instant : l'analyse se lance toute seule. Attends le message « Analyse terminée » dans le chat avant de fermer l'HV.
2. Ensuite, ouvre ForeverExchange **où tu veux** :
   - avec `/fx` ;
   - avec le bouton de la minicarte ;
   - avec un raccourci clavier (Options › Raccourcis › AddOns).
3. Plus tu analyses l'HV souvent, sur plusieurs jours, plus les moyennes, les prix bas et les tendances sont fiables.

Dans les listes : **clic** = fiche de l'objet, **Maj+clic** = lien dans le chat, **étoile** = favori.

## ⌨️ Commandes

| Commande | Action |
| --- | --- |
| `/fx` | Ouvrir / fermer la fenêtre |
| `/fx <nom, lien ou ID>` | Voir le prix d'un objet |
| `/fx options` | Ouvrir les options |
| `/fx scan` | Analyser l'HV (HV ouvert) |
| `/fx auto` | Analyse automatique à l'ouverture de l'HV : on / off |
| `/fx infobulle` | Prix dans les infobulles : on / off |
| `/fx aide` | Aide |

## ⚠️ Limites

- Les prix viennent **de tes propres analyses** : l'addon ne partage aucune donnée avec d'autres joueurs.
- Le serveur de WoW Forever n'envoie pas le détail de chaque enchère : la valeur marché est donc égale au prix minimum.
- Les équipements qui ont le même ID mais des niveaux d'objet différents partagent un seul prix.

---

## 🇬🇧 English

[🇫🇷 Français](#foreverexchange)

> **World of Warcraft Forever** auction house prices, available anywhere in the game: price history, charts, low prices and trends.

ForeverExchange scans the auction house when you open it, saves the prices of every active auction and lets you browse them **anywhere**, even far from the auction house. It is **view-only**: it never buys or sells anything.

> The in-game interface is in French.

## ✨ Features

- **Full auction house scan**: every item for sale is read (minimum price and quantity), automatically when you open the auction house or with the "Analyser" button. If another addon (Auctionator, for example) already started a scan, ForeverExchange reads the same data instead of requesting a new one.
- **Auction-house-style window**:
  - search by name (accents are ignored);
  - auction house **categories and subcategories**, three levels deep (e.g. Armor › Plate › Head);
  - **favorites**: a star on every item and a dedicated category;
  - sortable columns: minimum price, market value, available quantity, 7-day change.
- **Item page**:
  - minimum price, market value, quantity, number of auctions;
  - 7-day and 30-day averages, 30-day low and high;
  - **price history chart** (48 h, 7 days, 30 days or all), with values on hover.
- **Low prices**: items listed well below their usual price (adjustable threshold).
- **Trends**: the biggest risers and fallers of the week.
- **Prices in every item tooltip** (can be turned off), optional comparison with your equipped item.
- **"ForeverExchange" tab in the auction house**, next to Buy / Sell / Auctions: scan progress, open the window, options.
- **Options panel** in Esc › Options › AddOns, and a **minimap button**.
- **120 days of history**: one point per hour for 48 h, then one point per day.

## 📦 Installation

1. Download the latest release and unzip it.
2. Copy the `ForeverExchange` folder into `World of Warcraft\_forever_\Interface\AddOns\`.
3. Start the game (or type `/reload`).

No dependencies: ForeverExchange works on its own, with or without Auctionator.

## 🚀 Usage

1. Open the auction house for a moment: the scan starts by itself. Wait for the "Analyse terminée" message in chat before closing the auction house.
2. Then open ForeverExchange **wherever you are**:
   - with `/fx`;
   - with the minimap button;
   - with a key binding (Options › Keybindings › AddOns).
3. The more often you scan, over several days, the more reliable the averages, low prices and trends become.

In lists: **click** = item page, **Shift+click** = link in chat, **star** = favorite.

## ⌨️ Commands

| Command | Action |
| --- | --- |
| `/fx` | Open / close the window |
| `/fx <name, link or ID>` | Show an item's price |
| `/fx options` | Open the options |
| `/fx scan` | Scan the auction house (auction house open) |
| `/fx auto` | Automatic scan when the auction house opens: on / off |
| `/fx infobulle` | Prices in tooltips: on / off |
| `/fx aide` | Help |

## ⚠️ Limitations

- Prices come **from your own scans only**: the addon shares no data with other players.
- The WoW Forever server does not send the details of every auction, so the market value equals the minimum price.
- Gear with the same item ID but different item levels shares a single price.

---

*ForeverExchange is a fan-made addon. It is not affiliated with or endorsed by Blizzard Entertainment.*
