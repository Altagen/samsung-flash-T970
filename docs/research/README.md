# Dossier de recherche

[README](../../README.md) · [Histoire du projet](../histoire-du-projet.md) · **Dossier de recherche** · [Récit complet](recit-complet.md) · [Journal de bord](journal.md) · [Slides expliquées](presentation/slides.md) · [Script](presentation/script.md) · [Présentation (HTML)](presentation/warranty-void.html)

Les pièces du travail de recherche mené en avril-mai 2026, en français. Pour la
procédure qui fonctionne, voir le [guide](../guide/00-before-you-start.md) ; pour
le récit synthétique, l'[histoire du projet](../histoire-du-projet.md).

| Document | Contenu |
|---|---|
| [`recit-complet.md`](recit-complet.md) | **Le récit complet**, en sept actes : la version longue et narrative de l'histoire, écrite fin avril 2026 comme base de la présentation |
| [`journal.md`](journal.md) | **Le journal de bord complet** (59 sections, ~2 700 lignes), tenu au fil des essais : chaque flash (boot v1→v27, recovery v1→v29), chaque log, chaque impasse. Publié tel quel, avec des errata pour les passages corrigés depuis |
| [`presentation/warranty-void.html`](presentation/warranty-void.html) | **La présentation « Warranty Void »** (Mesh Union, 7 mai 2026) : site autonome en un seul fichier, à ouvrir dans un navigateur, navigation au clavier |
| [`presentation/slides.md`](presentation/slides.md) | **Les slides expliquées** : pour chacune des 26 slides, le texte affiché et l'explication donnée à l'oral. À lire à côté de la présentation |
| [`presentation/script.md`](presentation/script.md) | Le script de travail complet : description visuelle de chaque slide, texte parlé, photos à fournir |
| [`presentation/slides-brief.txt`](presentation/slides-brief.txt) | Le cahier des charges des slides (intentions visuelles et animations) |
| [`logs/`](logs/) | Deux logs bruts du 9 avril, obtenus avant que l'ADB ne fonctionne : photographiés page par page sur l'écran de la tablette, puis transcrits par OCR (d'où les caractères parasites) |

## Voir la présentation

GitHub affiche le code source des fichiers HTML, pas la page. Pour la voir :

- téléchargez `warranty-void.html` (bouton *Download raw file* sur GitHub, ou
  depuis la [release](https://github.com/Altagen/samsung-flash-T970/releases/latest))
  et ouvrez-le dans un navigateur ;
- ou, depuis un clone : `xdg-open docs/research/presentation/warranty-void.html`.

Le fichier est autonome (images incluses). Seules les polices viennent de
Google Fonts : hors ligne, le navigateur utilise des polices de remplacement.

## Les logs

| Fichier | Origine |
|---|---|
| `logs/last_kmsg-ocr-2026-04-09.txt` | `/proc/last_kmsg` lu depuis la recovery Samsung, c'est-à-dire le log kernel du boot précédent. Le début est celui du kernel stock 4.19.113, utile pour comparer avec notre kernel |
| `logs/recovery-lastlog-ocr-2026-04-09.txt` | Le journal de la recovery Samsung (`/efs/recovery`) : table des partitions, historique des redémarrages, traces `enablefilecrypto_failed` |

Ils ont été vérifiés avant publication : ni numéro de série, ni IMEI, ni
adresse MAC ou IP. Le contexte de ces logs est raconté dans le journal
(sections 9, 29 et 35).

## Ce qui a été laissé de côté

Les dizaines d'images `boot.img` et `recovery.img` intermédiaires, le firmware
Samsung complet, les objets de compilation et une tentative AnyKernel3
abandonnée au premier jour n'ont pas été conservés : tout se régénère avec le
repo, ou se retélécharge (voir le [miroir](../mirror.md)). Les photos originales
non plus : elles contenaient la position GPS du lieu de travail. Celles utilisées
dans la documentation ont été nettoyées ([`docs/images`](../images/README.md)).

---

[README](../../README.md) · [Histoire du projet](../histoire-du-projet.md) · **Dossier de recherche** · [Récit complet](recit-complet.md) · [Journal de bord](journal.md) · [Slides expliquées](presentation/slides.md) · [Script](presentation/script.md) · [Présentation (HTML)](presentation/warranty-void.html)
