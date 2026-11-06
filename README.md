# Serato Crates Sync

Petite app Mac qui transforme tes dossiers de musique en crates Serato. Chaque sous-dossier devient une crate, et les crates parentes contiennent les morceaux de leurs sous-dossiers.

Outil indépendant, non affilié à Serato. macOS 13 ou plus récent, Mac Intel ou Apple Silicon.

## Installation

1. [Télécharge `Serato-Crates-Sync.zip`](https://github.com/jay78/serato-crates-sync-app/releases/latest/download/Serato-Crates-Sync.zip), décompresse-le, puis glisse **Serato Crates Sync** dans le dossier Applications.
2. Double-clique dessus. macOS le bloque, car l'app n'est pas signée par un compte Apple Developer.
3. Ouvre **Réglages Système > Confidentialité et sécurité**, descends jusqu'à Serato Crates Sync, puis clique sur **Ouvrir quand même**.
4. Si macOS demande l'accès à ton dossier Musique ou à un disque externe, accepte : sinon l'app ne peut pas lire tes dossiers.

Ces étapes ne sont à faire qu'une fois.

## Utilisation

Au premier lancement, choisis ton dossier de musique et l'emplacement de Serato, c'est-à-dire le dossier qui contient `_Serato_`. Ces choix sont mémorisés.

- **Aperçu** montre ce qui changerait, sans rien écrire.
- **Synchroniser** crée et met à jour les crates.
- **Nettoyer…** liste les crates sans dossier. Rien n'est coché d'avance, et celles que tu coches vont à la corbeille.

Rouvre ensuite Serato pour voir le résultat.

## Protections

- Synchroniser et Nettoyer sont bloqués tant que Serato est ouvert.
- Avant chaque écriture, `Subcrates` est copié dans `~/Library/Application Support/Serato Crates Sync/Backups`. Les 10 dernières copies sont gardées, et **Afficher les sauvegardes** ouvre ce dossier.
- Si un dossier est illisible ou si le dossier de musique est vide, rien n'est modifié.

## Bon à savoir

- Les `.wma` sont ignorés, car Serato pour Mac ne les prend pas en charge.
- Un `:` dans un nom de dossier est écrit `␛␛3a` dans le nom de la crate, comme le fait Serato.
- Une crate portant le nom d'un dossier est remplacée par le contenu de ce dossier, même si elle a été faite à la main. La version précédente reste dans les sauvegardes.
- Le fonctionnement sur disque externe n'a pas encore été testé sur un vrai disque. Fais un Aperçu, puis vérifie une crate dans Serato.

## Développement

Seuls les Command Line Tools sont nécessaires, pas Xcode. C'est pourquoi le code évite `@State` et que les tests sont un simple exécutable : sans Xcode, les macros de SwiftUI et de Swift Testing ne sont pas disponibles.

```bash
swift run crate-sync-tests
```

```bash
./scripts/build-app.sh
```

Le second produit `dist/Serato Crates Sync.app` et `dist/Serato-Crates-Sync.zip`, à partager. Serato DJ Pro doit être installé : l'icône est composée à partir de la sienne au moment de la construction.

`crate-sync-check` lance le moteur sans interface, pour comparer sa sortie avec `sync_serato_crates.py`. Sans l'option `--write`, il n'écrit rien.
