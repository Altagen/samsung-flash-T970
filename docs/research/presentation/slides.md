# « Warranty Void » — les slides expliquées

[README](../../../README.md) · [Histoire du projet](../../histoire-du-projet.md) · [Dossier de recherche](../README.md) · [Récit complet](../recit-complet.md) · [Journal de bord](../journal.md) · **Slides expliquées** · [Script](script.md) · [Présentation (HTML)](warranty-void.html)

Ce document accompagne la présentation **« Warranty Void — Des conteneurs sur une tablette ? »**, donnée à Mesh Union (édition #01) le 7 mai 2026. Les slides sont numérotées de 1 à 26, dans l'ordre où elles défilent. Pour chacune :

- **Ce qu'on voit** : ce que montre la slide, décrit en quelques phrases ;
- **Ce qui est dit** : le commentaire donné à l'oral.

Pour suivre en même temps, ouvrez [`warranty-void.html`](warranty-void.html) dans un navigateur ([comment](../README.md#voir-la-présentation)) et avancez avec la flèche droite : la plupart des slides se construisent en plusieurs clics.

Ce numéro est celui du compteur en bas de l'écran et de l'en-tête « // Slide NN » affiché en haut des slides.

Trois slides contiennent des éléments contredits par des vérifications faites après le talk : une note l'indique sous chacune.

## Sommaire

- [Slide 1 — Ouverture](#slide-1--ouverture)
- **ACTE 0 — Hook**
  - [Slide 2 — Le hook : un seul octet](#slide-2--le-hook--un-seul-octet)
- **ACTE 1 — Pourquoi je me suis embarqué là-dedans**
  - [Slide 3 — Le point de départ](#slide-3--le-point-de-départ)
  - [Slide 4 — Et si c'était possible ?](#slide-4--et-si-cétait-possible-)
  - [Slide 5 — Le kernel est figé](#slide-5--le-kernel-est-figé)
  - [Slide 6 — Le terrain de jeu](#slide-6--le-terrain-de-jeu)
  - [Slide 7 — Les flags qu'il faut activer](#slide-7--les-flags-quil-faut-activer)
  - [Slide 8 — Déverrouillage OEM](#slide-8--déverrouillage-oem)
- **ACTE 2 — La saga du kernel**
  - [Slide 9 — Anatomie du boot.img](#slide-9--anatomie-du-bootimg)
  - [Slide 10 — Comment je récupère les logs](#slide-10--comment-je-récupère-les-logs)
  - [Slide 11 — Bonus : les captures OCR](#slide-11--bonus--les-captures-ocr)
  - [Slide 12 — Device Tree](#slide-12--device-tree)
  - [Slide 13 — Le retournement](#slide-13--le-retournement)
  - [Slide 14 — Premier boot complet](#slide-14--premier-boot-complet)
  - [Slide 15 — Le mystère résolu](#slide-15--le-mystère-résolu)
  - [Slide 16 — La solution radicale](#slide-16--la-solution-radicale)
- **ACTE 3 — La guerre du recovery (SELinux)**
  - [Slide 17 — Le paradoxe de la poule et de l'œuf](#slide-17--le-paradoxe-de-la-poule-et-de-lœuf)
  - [Slide 18 — Patcher le recovery](#slide-18--patcher-le-recovery)
  - [Slide 19 — SELinux](#slide-19--selinux)
  - [Slide 20 — Changer d'approche](#slide-20--changer-dapproche)
- **ACTE 4 — L'écran noir n'était pas du DRM**
  - [Slide 21 — Le kernel n'est pas le coupable](#slide-21--le-kernel-nest-pas-le-coupable)
  - [Slide 22 — Pivot stratégique](#slide-22--pivot-stratégique)
  - [Slide 23 — Le vrai coupable](#slide-23--le-vrai-coupable)
- **ACTE 5 — Containers : trois impasses, un déclic**
  - [Slide 24 — Containers, premières tentatives](#slide-24--containers-premières-tentatives)
  - [Slide 25 — Le pivot — dockerd natif](#slide-25--le-pivot--dockerd-natif)
  - [Slide 26 — Wrap-up](#slide-26--wrap-up)

### Slide 1 — Ouverture

**Ce qu'on voit.** Le titre du talk, **« Warranty Void. »**, avec le sous-titre *« Des conteneurs sur une tablette ? »*, sur un fond sombre animé. En bas : l'orateur, la date (7 mai 2026) et l'événement (Mesh Union, édition #01).

**Ce qui est dit.**

Écran d'ouverture, avant de prendre la parole.

---

## ACTE 0 — Hook

### Slide 2 — Le hook : un seul octet

**Ce qu'on voit.** Deux suites d'octets presque identiques, `07 00 02 00…` et `06 00 02 00…`, sur fond noir. Seul le premier octet diffère, et il se met à pulser en rouge. Puis quatre lignes apparaissent une à une : *comment Samsung boote*, *comment Android isole ses processus*, *comment SELinux contrôle l'exécution d'un programme*, *comment patcher un kernel Linux*, avec la chute : *« Tout ça parce que je voulais juste faire tourner des conteneurs sur une tablette. »* Le mystère de l'octet n'est résolu qu'à la slide 15.

**Ce qui est dit.**

Vous voyez ces deux lignes ?

Elles sont presques identiques à l'exception d'un seul octet. Et à cause de cet octet, il a fallu que je change 3 fois mon kernel. J'ai tout perdu pour un compteur, que personne n'est censé voir. ça m'a coûté très cher en temps mais ça m'a permis d'aller faire un tour dans les fin-fonds du bas niveau pour comprendre cet octet. J'ai dû comprendre comment samsung boote, comment android isole ses processus, comment SElinux contrôle l'exécution d'un programme, et aussi... Patcher un kernel Linux, tout ça parce-que je voulais mettre des conteneurs sur une tablette.

Petit disclaimer le but n'est pas de faire un tuto mais de vous présenter les recherches, je ne vais pas rentrer dans une explication technique à la commande près mais assez d'éléments pour que vous puissiez comprendre la démarche.

---

## ACTE 1 — Pourquoi je me suis embarqué là-dedans

### Slide 3 — Le point de départ

**Ce qu'on voit.** La Galaxy Tab S7+ et ses usages habituels (jeux, dessin, lecture, notes). Face à elle, la solution « classique » pour coder dessus : un VPN vers un PC à la maison et un bureau à distance (VNC), barrée d'un grand **NON** (environ 80 ms de latence, trois couches, deux réseaux). En conclusion : *« J'aime quand c'est natif »*, donc pas de VPN, pas de VNC, pas de laptop dans le sac.

**Ce qui est dit.**

Revenons au début :
Il y a 6 ans j'ai acheté une tablette : une samsung galaxy tab s7+. C'est une tablette parfaite pour le jeu, pour dessiner, et même pour travailler elle fait vraiment le job Seul bémol, elle est plus mise à jour par samsung depuis 2022. Le problème principal pour mon usage: c'est le code. En mobilité pour du travail léger, cette tablette est géniale mais impossible de faire quelque chose de relatif à du code. évidemment, je pourrai me connecter en VPN à mon infra chez moi et faire du VNC mais il y a une latence et j'aime quand c'est natif.

Et franchement la flemme de prendre un laptop.

---

### Slide 4 — Et si c'était possible ?

**Ce qu'on voit.** Une grille de conteneurs (nginx, postgres, api, redis…) et la question : *« Pourquoi pas faire tourner mes conteneurs directement sur la tablette ? »*. Trois cartes d'articles (forum XDA, Reddit, GitHub) disent toutes la même chose : *le matériel peut le faire, mais le kernel n'a pas les options nécessaires*. Dernier temps, un schéma simple : les programmes en haut, le matériel en bas, le **kernel** au milieu, avec *« Si le kernel dit non, rien ne fonctionne au-dessus. »*

**Ce qui est dit.**

Du coup, je me suis dit... Mais pourquoi pas faire de ma tablette un usage de laptop ? Pourquoi je pourrai pas juste prendre ma tablette et lancer mes conteneurs ?
Première chose que je fais, je regarde ce qui existe, je tente de faire des installations de "solutions" qui existent déjà sans grand succès, et plus je cherche et plus je tombe sur des articles qui me disent en gros "ton matériel peut le faire mais ton kernel n'a pas les flags pour lancer ça" En gros, le Noyau supporte ce que je veux faire mais quand samsung a fait sa release, il ont désactivé des flags en se disant : pourquoi lancer des conteneurs sur une tablette, on ne garde que ce dont on a besoin.

Petite apparté pour ceux qui ne savent pas ce que c'est un kernel : ça veut dire Noyau. C'est le composant central du système d'exploitation qui permet de faire le lien avec les interfaces physiques comme le stockage, le réseau, le processeur, la ram etc. Le noyau reçoit des demandes de la part des programmes qui tournent sur votre système d'exploitation et il va faire le médiateur entre les deux. Si le noyau dit non, rien ne fonctionnera.

> [!NOTE]
> Les trois cartes d'articles sont des illustrations reconstituées pour la présentation (le cahier des charges demandait de « faux » articles) : citations et chiffres ne renvoient pas à des sources précises. Et OverlayFS est déjà activé dans l'arbre de sources utilisé ; il manquait surtout les namespaces utilisateur, PID et réseau, le cgroup `pids` et IPVS ([détails](../../how-it-works.md#the-kernel)).

---

### Slide 5 — Le kernel est figé

**Ce qu'on voit.** Un fichier `kernel.img` montré comme un bloc binaire verrouillé : *« Une fois compilé, tout est figé »*, pas de modification à chaud. Dessous, la chaîne en trois étapes à refaire pour chaque changement : **configuration** (`make menuconfig`), **compilation** (environ 30 minutes), **flash** (`heimdall flash --BOOT boot.img`). Avec la phrase : *« Une ligne change. Tout reprend depuis zéro. »*

**Ce qui est dit.**

Le truc c'est que moi j'en ai besoin de ces flags. Donc je vais devoir les rajouter.

Pour ceux qui ne le savent pas: Un kernel une fois qu'il est compilé vous ne pouvez plus le modifier pour y rajouter des flags, vous devez obligatoirement modifier la configuration et les options de build, rebuilder votre kernel et le reflasher dans votre mâchine.

---

### Slide 6 — Le terrain de jeu

**Ce qu'on voit.** À gauche, la fiche de la tablette : SM-T970 Wi-Fi, Snapdragon 865 (SM8250, nom de code *kona*), Linux 4.19 patché par Samsung, Android 13 / One UI 5.1.1, écran 120 Hz, stylet S Pen. Un encart rappelle que **la licence GPL oblige Samsung à publier les sources du kernel**. À droite, le poste de compilation : un conteneur Podman avec clang-12, LLVM et binutils pour compiler vers ARM64, qui produit un `boot.img` en une trentaine de minutes.

**Ce qui est dit.**

Avant d'expliquer le reste, un petit tour sur les specs Galaxy Tab S7+ WI-Fi, Nom de code SM-T970 et un SoC (processeur) Snapdragon 865, nom de code Qualcomm SM8250. Le kernel tourne en linux 4.19 qui a été vraiment patché lourdement. Android 13, One UI 5.1.1, un stylet Wacom, 120hz...

Les sources de build : Faut savoir que la license GPL du kernel Linux oblige à livrer les sources, donc j'ai eu accès aux sources de samsung pour pouvoir rebuild.

Pour mon environnement de build, j'ai utilisé podman sur mon PC avec la version de clang qui a été utilisée (clang12) et la chaine de compilation en aarch64 vu que c'est une architecture arm.

---

### Slide 7 — Les flags qu'il faut activer

**Ce qu'on voit.** La liste des options du kernel indispensables aux conteneurs, chacune avec son rôle : `CONFIG_USER_NS` (isolation des utilisateurs), `CONFIG_CGROUPS` (limites CPU, mémoire, disque), `CONFIG_OVERLAY_FS` (couches de fichiers empilées), `CONFIG_NET_NS` (réseau isolé), `CONFIG_NAMESPACES` (la base de l'isolation). À la fin : un kernel personnalisé, prêt à flasher.

**Ce qui est dit.**

Le truc rigolo maintenant c'est AVANT de flasher quoi que ce soit j'ai dû avoir quelque chose à flasher, donc j'ai dû prendre les sources, comprendre à quoi servaient les flags, choisir les bons avec leurs dépendances et flasher, donc on arrive à ces flags là qui sont absolument obligatoires:

- `CONFIG_USER_NS=y` (User Namespaces — requis pour Podman rootless)
- `CONFIG_CGROUPS=y` + sous-systèmes (memory, cpu, cpuacct, blkio, etc.)
- `CONFIG_OVERLAY_FS=y` (requis pour les layers de containers)
- `CONFIG_NET_NS=y` (réseau container)
- `CONFIG_NAMESPACES=y` (namespaces en général)

Je build mon kernel depuis ce namespace et voilà, j'ai mon kernel tout propre avec mes flags.

---

### Slide 8 — Déverrouillage OEM

**Ce qu'on voit.** La chaîne de démarrage de la tablette en cinq maillons : ROM de la puce, chargeur secondaire, **ABL** (le bootloader Android), kernel, Android. Sans déverrouiller l'ABL, impossible d'insérer son propre kernel. Le déverrouillage est **irréversible** : le compteur Knox passe à 1, et Samsung Pay, Secure Folder et Knox sont désactivés pour toujours.

**Ce qui est dit.**

Le premier obstacle majeur c'est le dévérouillage OEM. En fait, je sais pas trop lire une doc ce qui est problématique vu que j'ai perdu beaucoup de temps. En fait pour dévérouiller le bootloader (qui est la chaine de boot d'android le premier programme exécuté par un appareil Android lors de l'allumage, agissant comme une passerelle critique entre le matériel et le système d'exploitation. Il initialise les composants matériels, charge le noyau Linux et vérifie l'intégrité des partitions système via des signatures numériques pour garantir la sécurité et empêcher l'installation de logiciels non autorisés. )  et permettre d'injecter mon kernel, il faut "dévérouiller" cette partie. Quand on le dévérouille on fait sauter les sécurités et la garantie, y'a un truc qui s'appelle Knox chez Samsung qui permet de savoir si on a flasher le firwmware, et ça désactive des fonctions de sécurité avancée comme les dossier sécurisés et d'autres trucs de l'écosystème dont j'ai pas spécialement besoin. En tout cas, ça flingue juste la garantie et ça fait passer le bit "WARRANTY_VOID" de 0x0 à 0x1 et c'est irréversible.

après avoir perdu un temps colossal, j'ai enfin compris la suite de bouton qui permettait le dévérouillage OEM (Original Equipment Manufacturer)

---

## ACTE 2 — La saga du kernel

### Slide 9 — Anatomie du boot.img

**Ce qu'on voit.** Le fichier `boot.img` ouvert en quatre parties : **kernel** (celui qu'on vient de compiler, le seul remplacé), **ramdisk** (mini système qui contient `/init`), **dtb** (description du matériel) et **cmdline** (options passées au kernel), ces trois dernières gardées d'origine. Puis les deux premiers essais : la tablette démarre sur l'écran de recovery Samsung (*« Can't load Android system »*). On ajoute alors `androidboot.force_normal_boot=1` dans la cmdline, et elle redémarre en boucle.

**Ce qui est dit.**

Maintenant que j'ai mon kernel custom, il faut que je comprenne où il va atterrir avant de pouvoir le mettre dans la tablette.

Sur Android, il y a un fichier qui s'appelle `boot.img`. C'est une image binaire qui contient quatre choses : le kernel, un mini système de fichiers qu'on appelle le ramdisk — c'est ce qui contient le tout premier programme à se lancer après le kernel — un fichier qui décrit le matériel, et une ligne de paramètres pour le kernel.

Mon plan : je remplace juste le kernel par le mien, je laisse tout le reste stock, je reflashe. Sauf que c'est pas comme ça que Samsung voit les choses.

Premier flash. La tablette boot... sur l'écran de recovery Samsung. Avec un message qui dit "Can't load Android system". Pas dans Android, dans recovery.

Donc déjà, premier truc : Android sur les versions récentes, par défaut, il boot en mode recovery. Pour qu'il fasse un boot normal, il faut explicitement lui dire dans la cmdline. Donc je rajoute un flag, `force_normal_boot=1`. Reflash. Cette fois, plus de recovery. Mais... bootloop.

---

### Slide 10 — Comment je récupère les logs

**Ce qu'on voit.** Comment lire un crash quand la tablette redémarre en boucle : une petite zone de la RAM, **pstore**, survit aux redémarrages et garde les derniers messages du kernel. Le cycle en quatre temps : flasher le kernel, crash, reflasher le kernel d'origine, lire `/sys/fs/pstore/console-ramoops-0`. Trois lignes de log résument le problème : `init` ne trouve pas sa table de partitions (le *fstab*), ne monte rien, et le kernel s'arrête (*kernel panic*).

**Ce qui est dit.**

Je vois rien. La tablette redémarre en boucle. Comment je suis censé debug si j'ai aucun log ?

Et là je découvre un truc qui s'appelle pstore — ou ramoops. C'est une zone de la mémoire RAM qui est configurée pour survivre aux redémarrages. Quand le kernel crashe, ses derniers messages restent stockés là, et au prochain boot, on peut les relire.

Donc le workflow devient : je flashe mon kernel custom, ça crashe, je reflashe le kernel stock, Android démarre normalement, et je vais lire les logs du crash précédent.

Ça, c'est le workflow idéal. Mais parfois ça ne marche pas — soit le crash arrive trop tôt et pstore n'a rien capturé, soit la tablette reste bloquée dans un écran d'erreur sans que je puisse y accéder en ADB. Dans ces cas-là, je sors mon téléphone, je photographie l'écran de la tablette, et je passe l'image dans un outil de reconnaissance de caractères — un OCR — pour reconstituer le texte. C'est lent, ça fait des erreurs sur les caractères qui se ressemblent — un `1` qui devient un `l`, un `0` qui devient un `O`, des espaces qui sautent — mais sur une bonne partie du projet, c'est mon seul moyen d'extraire les logs des boots qui ne laissent rien de propre derrière eux.

Et là, je vois ça :

```
init: ReadFstabFromDt(): failed to read fstab from dt
init: execv("/system/bin/init") failed: No such file or directory
Kernel panic - not syncing: Attempted to kill init!
```

En clair : init — c'est le tout premier programme qui se lance après le kernel, celui qui va monter les partitions et démarrer Android — il cherche son fichier de configuration des partitions (qu'on appelle le fstab), il le trouve pas, du coup il monte rien, il essaie de lancer la deuxième étape d'Android, le binaire n'existe pas parce que rien n'est monté, kernel panic.

J'ai une cause. Maintenant, faut comprendre pourquoi init ne trouve pas son fstab.

---

### Slide 11 — Bonus : les captures OCR

**Ce qu'on voit.** Une mosaïque de 16 photos de l'écran de la tablette, prises en rafale le 9 avril 2026 entre 20 h 35 et 20 h 38, toutes nécessaires pour reconstituer **un seul** log de démarrage par reconnaissance de caractères (OCR). Sous-titre : *« workflow temporaire débile, mais qui a marché »*.

**Ce qui est dit.**

Pas de commentaire à l'oral sur celle-ci : elle illustre la méthode décrite à la slide précédente. Avant que l'ADB ne fonctionne, la seule façon de lire certains logs de démarrage était de photographier l'écran de la tablette, page par page, puis de passer les photos dans un logiciel de reconnaissance de caractères. Les logs ainsi obtenus sont publiés dans [`../logs/`](../logs/).

---

### Slide 12 — Device Tree

**Ce qu'on voit.** L'arbre du matériel (*device tree*) que le kernel lit au démarrage : mémoire, écran, stylet… et l'**overlay Samsung** (DTBO), une couche spécifique au modèle exact, qui vient se greffer dessus. Deux découvertes successives : le kernel ne compilait aucun device tree, puis ceux compilés n'avaient pas de **table de symboles** (`__symbols__`), si bien que l'overlay Samsung ne trouvait pas où se greffer. Sept versions passent, et le crash recule de 0 à 10 secondes, mais il est toujours là.

**Ce qui est dit.**

Pour comprendre,il faut que j'introduise un truc qui s'appelle le Device Tree. C'est un arbre qui décrit le matériel au kernel : "voilà le CPU, voilà l'écran, voilà l'USB, à telle adresse, avec telles options". Sans ce fichier, le kernel sait pas avec quoi il parle.

Et sur Android, il y a une couche de plus : un overlay — que Samsung appelle DTBO ((Device Tree Blob Overlay) - qui permet d'ajouter ou de modifier des nœuds et des propriétés dans l'arborescence des périphériques sans modifier le fichier DTB central) — qui vient compléter ce Device Tree avec les spécificités du modèle exact. Pour ma tablette, ça contient les paramètres précis du stylet, de l'écran, etc.

Première découverte : le Makefile des sources Samsung avait un répertoire commenté qui empêchait la compilation des Device Trees. Mon kernel n'en avait aucun. Je dé-commente, je rajoute les bons, je compile, je flash. Premier progrès dans les logs : "Hardware name: Samsung GTS7XL" apparaît. La tablette se reconnaît comme une Tab S7+. C'est gagné de ce côté-là.

Sauf que le crash continue. Init dit toujours qu'il trouve pas son fstab.

Et c'est là que je creuse encore : le DTBO Samsung, pour fonctionner, doit pouvoir cibler des éléments précis dans mon Device Tree par leur nom. Pour ça, il faut une table de symboles à l'intérieur du fichier — la fameuse `__symbols__`. Mes Device Trees, je les ai compilés sans cette table. Du coup, le DTBO de Samsung ne peut pas se greffer correctement. Tout fonctionne à moitié.

Bon... je passe quand même 7 versions à modifier le Device Tree, à enrichir le fstab, à ajouter des entrées partout. Toujours bootloop. Toujours le même message. Sauf que le timing du crash change : avant ça crashait immédiatement, maintenant ça crashe au bout de 10 secondes. Donc init essaie quelque chose. Il trouve quelque chose. Mais ça finit pareil.

---

### Slide 13 — Le retournement

**Ce qu'on voit.** En rendant les logs plus bavards, une ligne jamais vue apparaît : `Switching root to '/first_stage_ramdisk'`. Un schéma montre ce qui se passe : `init` bascule dans un dossier vide, et le `fstab` du ramdisk devient inaccessible. Le coupable est surligné dans la cmdline : `androidboot.force_normal_boot=1`, le flag ajouté à la slide 9. Sur le kernel d'origine, c'est le bootloader qui l'ajoute lui-même au démarrage ; écrit en dur, il fait prendre à `init` un autre chemin. Solution : **le retirer**.

**Ce qui est dit.**

Au bout de 7 versions, je fais que de modifier le Device Tree, je tourne en rond. Et je me dis : et si je rendais les logs plus verbeux ? Je rajoute un paramètre tout simple, `loglevel=5`, qui demande au kernel de tout dire au lieu de juste les erreurs critiques.

Et là, je vois enfin une ligne que je n'avais jamais vue avant :

```
init: Switching root to '/first_stage_ramdisk'
```

Traduction : init crée un nouveau système de fichiers temporaire — vide — et il déplace dedans, il fait un changement de racine. Tout ce qui était disponible avant, dont mon ramdisk avec mon fstab dedans, devient inaccessible.

Et qu'est-ce qui déclenche ce SwitchRoot ?

Le flag `force_normal_boot=1` que j'avais ajouté à ma cmdline en slide 9. Pour que la tablette boot en mode normal au lieu de recovery.

Donc je récapitule : ce flag, je l'ai ajouté pour résoudre le tout premier problème de la slide 9. Et c'est exactement ce flag qui cause le crash que je traque depuis 7 versions.

Comment ça marche dans le kernel d'origine, alors ? Le kernel stock n'a pas ce flag dans sa cmdline hardcodée — c'est le bootloader Samsung qui l'injecte dynamiquement au moment du boot, et l'init Samsung sait gérer ce cas. Mais quand le flag est figé en dur dans le boot.img, l'init prend un autre chemin : le SwitchRoot.

La solution, c'est de retirer ce flag. Tout simplement.

Toutes mes modifications de Device Tree des dernières versions étaient sur une fausse piste. Pas inutiles : les Device Trees sont mieux maintenant. Mais le crash, c'était jamais ça.

---

### Slide 14 — Premier boot complet

**Ce qu'on voit.** Une frise du démarrage, version 15 : les partitions se montent une à une (`metadata`, `system`, `vendor`, `product`, `odm`), puis `init second stage started!`, **la première fois qu'Android démarre sur ce kernel**. Environ 18 secondes plus tard, le service de chiffrement (`vold`) échoue (`enablefilecrypto failed`), et l'écran de recovery Samsung propose *Try again* ou *Factory reset*.

**Ce qui est dit.**

Je flashe sans le flag. Je regarde les logs.

Cette fois, init monte la partition `metadata`. Il monte `system`, `vendor`, `product`, `odm`. Il fait son SwitchRoot — celui-là est légitime, il bascule vers le vrai système — et il dit :

```
init second stage started!
```

C'est la première fois que ça arrive. C'est le signal que la deuxième étape d'Android démarre. À partir de là, c'est l'OS qui prend le relais.

Sauf que... 18 secondes plus tard, vold — le service qui gère le chiffrement de la partition utilisateur — crashe. Message d'erreur :

```
enablefilecrypto failed
```

Et la tablette retourne en recovery avec un menu "Retry / Factory Reset".

Je suis content parce que pour la première fois, mon kernel a vraiment démarré Android. Je suis pas content parce que... y'a un nouveau problème.

---

### Slide 15 — Le mystère résolu

**Ce qu'on voit.** Retour aux deux octets du début, cette fois expliqués. La clé qui chiffre `/data` est gardée par **Keymaster**, dans une zone sécurisée de la puce (TrustZone) que même le kernel ne peut pas lire. Cette clé est liée à la **Root of Trust** (ROT), qui reflète l'état du bootloader : `06` quand il était verrouillé, `07` depuis le déverrouillage. La clé a été scellée avec `06`, la ROT vaut maintenant `07` : Keymaster refuse de déchiffrer. *« C'est ça, l'octet du début. »*

**Ce qui est dit.**

OK, on remonte au tout début de la présentation, vous vous souvenez des deux octets ?

Voilà ce que c'était.

Sur les téléphones et tablettes Samsung modernes, la partition utilisateur — celle qui contient vos données, vos photos, vos applis — est chiffrée. Et la clé de chiffrement n'est pas stockée n'importe où : elle est gardée par un programme qui s'appelle Keymaster, qui tourne dans une enclave de sécurité matérielle qu'on appelle TrustZone — c'est une zone du processeur isolée du reste, à laquelle même le kernel n'a pas accès directement.

Et Samsung a ajouté une règle : avant de déchiffrer une clé, Keymaster vérifie un truc qu'on appelle la Root of Trust. Cette ROT, c'est une valeur calculée par le bootloader, à partir de l'état actuel de l'appareil : verrouillé ou déverrouillé, plus un compteur qui s'incrémente à chaque fois qu'on déverrouille.

Quand vous achetez la tablette, le bootloader est verrouillé, le compteur est à 0, la ROT vaut quelque chose qui commence par `06`. Toutes les clés de chiffrement de la tablette sont liées à cette valeur.

Et au moment où j'ai déverrouillé l'OEM — vous vous souvenez, le bouton volume qui m'a cassé les pieds — le compteur est passé de 0 à 1. La ROT est devenue `07`.

Et là, Keymaster, fidèle à sa mission, refuse de déchiffrer les clés. Parce que ces clés ont été créées avec ROT=06. Maintenant, ROT=07. Pour lui, ça veut dire : "quelqu'un a touché au système, je ne déchiffre rien".

C'est ça l'octet du début. Le compteur qu'on ne voit jamais. C'est lui qui m'a empêché de booter.

---

### Slide 16 — La solution radicale

**Ce qu'on voit.** *« La solution : factory reset. On perd tout. Et c'est OK. »* Une nouvelle clé est générée, scellée avec la ROT `07` actuelle. Tout passe au vert : Android démarre, l'USB répond, aucun crash. *« Sauf que… l'écran reste noir. »* Le logo Samsung et l'avertissement de bootloader s'affichent bien avant le kernel, puis plus rien dès qu'Android démarre.

**Ce qui est dit.**

La solution, à ce stade, elle est radicale mais logique : factory reset. Effacer toute la partition utilisateur. Comme ça, vold est obligé de regénérer des nouvelles clés — qui seront liées à la ROT actuelle, donc 07. Et là tout marche.

Je fais le factory reset depuis le menu recovery. Je perds tout. Bon, c'est OK, c'était une tablette de test à ce stade. Je reboot avec mon kernel custom.

Et là... pour la première fois, Android boot. Le kernel CIP (Civil Infrastructure Platform durée de vie de 10 ans mais on s'en fiche) a démarré le système. La tablette apparaît sur mon PC en USB, en mode MTP — comme une tablette normale. Plus de crash. enablefilecrypto a réussi.

Sauf que l'écran reste noir.

L'ABL — le bootloader Samsung — affiche bien ses propres écrans, le logo Samsung au démarrage, le warning sur le bootloader déverrouillé. Mais dès que le kernel prend le relais, plus rien.

Donc je résume : j'ai un kernel qui boot, qui monte les partitions, qui démarre Android, qui me donne accès à la tablette en USB. Et je vois rien à l'écran.

J'ai un problème d'affichage maintenant.

---

## ACTE 3 — La guerre du recovery (SELinux)

### Slide 17 — Le paradoxe de la poule et de l'œuf

**Ce qu'on voit.** Une boucle fermée : pour comprendre l'écran noir, il faut les logs (`adb logcat`) ; pour ADB, il faut activer le débogage USB ; pour l'activer, il faut les paramètres Android ; pour les paramètres, il faut un écran. *« Pour débugguer l'écran, il me faut ADB. Pour avoir ADB, il me faut l'écran. »*

**Ce qui est dit.**

Bon, donc nouveau problème. La tablette boot, elle est vivante, mais l'écran est noir.

Et là, on tombe dans un truc rigolo. Pour comprendre pourquoi l'écran est noir, il faudrait que je récupère les logs d'Android — `logcat`, `dmesg`, ce genre de trucs. Ces logs sont accessibles par ADB — Android Debug Bridge — qui est l'outil qu'on utilise pour parler à un téléphone Android depuis un PC.

Sauf que pour qu'ADB fonctionne, il faut activer "USB debugging" dans les paramètres Android. Et pour activer USB debugging, il faut accéder à l'écran de configuration. Et l'écran est noir.

Pour débugguer l'écran, il me faut ADB. Pour avoir ADB, il me faut l'écran.

Donc il faut que je trouve ADB autrement.

---

### Slide 18 — Patcher le recovery

**Ce qu'on voit.** La tablette a deux systèmes : Android, et un **mini-système de recovery** séparé, avec son propre kernel et son propre ramdisk. L'idée : modifier le ramdisk de la recovery pour y obtenir un shell ADB. Première tentative avec `default.prop` : `unauthorized`. Deuxième tentative avec les deux fichiers, dont `prop.default` qui est le vrai fichier depuis Android 11 : ADB se connecte enfin. Mais `adb shell` crashe aussitôt (`ABRT signal 6`).

**Ce qui est dit.**

Sur Android, en plus du système normal, il y a une partition spéciale qu'on appelle le `recovery`. C'est un mini-système qui sert à faire les mises à jour, les factory reset, et accessoirement, à récupérer un téléphone qui ne boot plus. Le recovery a son propre ramdisk, indépendant de celui du système.

Mon plan : je patche le ramdisk du recovery pour activer ADB par défaut, sans avoir besoin de l'autoriser depuis l'écran. Comme ça, quand je boot en recovery, j'ai un shell.

Première tentative : je modifie un fichier qui s'appelle `default.prop` pour mettre `ro.adb.secure=0` — en gros "désactive l'autorisation ADB". Je flashe. ADB me voit toujours en `unauthorized`.

Je creuse, et je découvre que sur Android 11 et plus, le fichier qui prime n'est plus `default.prop` mais `prop.default`. Les deux coexistent — vestige historique — mais c'est le deuxième qui est lu activement.

Je patche les deux. Je flashe. Cette fois, `adb devices` me montre la tablette en `recovery`, plus en `unauthorized`. Je tape `adb shell`...

Crash immédiat.

---

### Slide 19 — SELinux

**Ce qu'on voit.** Les trois règles de **SELinux**, le gardien d'Android : chaque programme tourne dans un *domaine*, chaque domaine a une liste précise de droits, et tout le reste est refusé. Le crash vient de là : ADB veut lancer un shell dans un domaine `su` qui n'existe pas chez Samsung. Suit la liste des six contournements tentés, tous barrés, sur 26 versions de recovery. *« SELinux est conçu pour résister exactement à ce que je suis en train d'essayer. »*

**Ce qui est dit.**

Ça crashe à cause de SELinux.

SELinux, pour ceux qui connaissent pas, c'est un système de sécurité qui ajoute une couche de contrôle sur tout ce qui se passe sur la machine. Par défaut, sur Android, c'est en mode "enforcing" — strict. Chaque programme tourne dans ce qu'on appelle un "domaine", avec une liste précise de ce qu'il a le droit de faire.

Le problème : le service ADB du recovery est configuré pour démarrer le shell utilisateur dans un domaine SELinux qui s'appelle `su`. Sauf que ce domaine n'existe pas dans la politique du recovery Samsung. ADB tente le changement, échoue, et crashe.

Donc il faut désactiver SELinux. Ou au moins le mettre en "permissive" — il observe mais il bloque pas. Et c'est là que je rentre dans une longue série de tentatives. Je vais pas vous infliger les détails de chacune, mais en gros :

D'abord j'essaie de retirer la configuration SELinux du service ADB. Bloqué — il en calcule une autre tout seul, même crash.

Ensuite, le paramètre standard `androidboot.selinux=permissive` dans la cmdline du kernel. Samsung l'ignore.

Ensuite, le paramètre kernel `selinux=0`. Le kernel Samsung a été compilé avec une option qui désactive ce paramètre. Inutile.

Ensuite, je patche le binaire ADB lui-même. Une instruction ARM64, à un offset précis dans le binaire, je la remplace pour faire sauter le check d'erreur. Le crash disparaît, mais SELinux bloque ensuite l'exécution du shell.

Ensuite, j'écris directement dans le fichier qui contrôle SELinux — `/sys/fs/selinux/enforce` — au tout début du démarrage. Le binaire recovery de Samsung ré-écrit `1` derrière moi, juste après mon `0`.

Ensuite, j'essaie de faire `adb push` d'un fichier dans `/sys/fs/selinux/enforce`. SELinux bloque l'opération `adb push` elle-même.

Au total : 26 versions de recovery. Toutes les portes que je trouve sont fermées. SELinux est conçu pour ça — résister exactement à ce que je suis en train d'essayer de faire.

---

### Slide 20 — Changer d'approche

**Ce qu'on voit.** Au lieu de désactiver SELinux, **modifier ses règles** : elles sont compilées dans un fichier, `sepolicy`, qu'on peut patcher. L'outil `magiskpolicy` (du projet Magisk) le fait en une commande : `magiskpolicy --load sepolicy 'permissive adbd' --save sepolicy`. Seul le domaine d'ADB passe en mode permissif, tout le reste reste protégé. Résultat : un shell, et `adb pull /proc/last_kmsg` récupère enfin 2 Mo de logs.

**Ce qui est dit.**

Je décide de changer de stratégie.

Au lieu d'essayer de désactiver SELinux, je me dis : et si je modifiais ses règles directement ? SELinux a une politique compilée dans un fichier qu'on appelle `sepolicy`. Cette politique, on peut la patcher.

Pour la patcher, il y a un outil qui s'appelle `magiskpolicy`. Il fait partie du projet Magisk — celui qu'on utilise classiquement pour rooter Android. Et — c'est ça la blague — Magisk, je l'avais cloné dans mon répertoire de travail depuis le début du projet. L'outil de la solution était littéralement dans mon dossier, sans que je m'en rende compte.

Une commande :

```
magiskpolicy --load sepolicy 'permissive adbd' --save sepolicy
```

Ça dit à SELinux : "le domaine `adbd` est en mode permissive". Pas tout SELinux, juste ce domaine. Le reste reste enforcing.

Je flashe. Je tape `adb shell`. Cette fois, je tombe dans un shell. Je tape `adb pull /proc/last_kmsg`. Ça pull deux mégaoctets de logs du dernier boot.

J'ai un environnement de debug stable. Pour la première fois depuis le début du projet, je peux lire les logs sans avoir à reflasher le kernel stock entre chaque essai.

---

## ACTE 4 — L'écran noir n'était pas du DRM

### Slide 21 — Le kernel n'est pas le coupable

**Ce qu'on voit.** Avant, chaque essai demandait environ 10 minutes de va-et-vient entre kernels ; maintenant, environ 30 secondes avec la recovery patchée. Les erreurs d'affichage (`NULL attachment`) qu'on croyait venir de notre kernel n'apparaissent pas dans ses logs : l'affichage s'initialise correctement. L'explication : `/proc/last_kmsg` contient le log du démarrage **précédent**, et ces erreurs venaient du kernel de la recovery. Verdict : *« Le kernel n'est pas le coupable. »*

**Ce qui est dit.**

Donc maintenant j'ai ADB depuis le recovery. Je peux pull les logs du dernier boot avec mon kernel custom — `/proc/last_kmsg`, deux mégaoctets de logs. Je m'attendais à trouver des erreurs DRM en pagaille, parce que dans les logs précédents — ceux que je récupérais en photographiant l'écran et en faisant de la reconnaissance de caractères — j'avais vu un message qui revenait sans arrêt : `NULL attachment`. C'est typiquement le genre d'erreur qu'on voit quand le driver d'affichage galère à allouer de la mémoire pour le framebuffer.

Sauf que dans les logs propres que j'extrais maintenant... aucun message de ce type. Le driver DRM du kernel CIP fonctionne nickel. Il alloue ses buffers, il configure l'IOMMU (Input–Output Memory Management Unit), il identifie le panel Samsung. Tout est vert.

Et là je comprends. Les `NULL attachment` que j'avais vus avant, ils venaient du kernel recovery, pas du kernel CIP. Quand on lit `/proc/last_kmsg`, ça contient les logs du boot précédent — et le boot précédent, dans mon workflow, c'était souvent un boot recovery. Je traquais une erreur qui n'avait jamais existé dans mon kernel.

Le kernel n'est pas le coupable.

---

### Slide 22 — Pivot stratégique

**Ce qu'on voit.** Changement de stratégie : revenir au kernel d'origine pour retrouver un écran et un Android qui marchent, puis s'outiller. Étape 1 : installer **TWRP**, une recovery communautaire non signée par Samsung. Un schéma montre la chaîne de signatures (**vbmeta**) qui la bloque, et comment la désactiver avec `vbmeta_disabled.img`. Étape finale : **Magisk** pour le root. Avec `logcat`, `dmesg` et `getevent`, on peut enfin enquêter comme sur n'importe quel Linux.

**Ce qui est dit.**

À ce stade, je prends une décision stratégique. J'arrête de me battre uniquement avec le kernel custom.

Je remets le kernel d'origine. L'écran refonctionne. J'installe TWRP — un recovery custom communautaire. Pour ça il y a une petite ruse : il faut désactiver la vérification de signature des partitions, parce que TWRP n'est évidemment pas signé par Samsung. Ça se fait en flashant une partition spéciale qui s'appelle `vbmeta` (Verified Boot Metadata) avec le flag de désactivation.

TWRP me donne accès à un shell root en recovery. Depuis ce shell, j'installe Magisk — c'est l'outil qui permet d'avoir root sur Android sans modifier la partition système. Magisk patche le `boot.img` à la volée pour s'injecter au démarrage.

Le résultat : Android d'origine qui boot normalement, écran fonctionnel, mais maintenant j'ai ADB, j'ai root via Magisk, je peux utiliser `logcat`, `dmesg`, `getevent` en live. Je peux investiguer comme sur n'importe quelle distribution Linux.

Du coup je reflashe mon kernel custom, mais avec Magisk patché dedans. Et je m'attaque au vrai problème : pourquoi l'écran est noir.

---

### Slide 23 — Le vrai coupable

**Ce qu'on voit.** Le moniteur d'événements (`getevent`) montre `SW_MACHINE_COVER` passer à 1 quand le S Pen entre dans son logement : son aimant active un capteur, et le système croit la *cover* fermée, donc il éteint l'écran. Première hypothèse, un bug du driver kernel `hall_ic_wacom` : le correctif ne suffit pas. Le log Android révèle la suite : un composant Samsung (`SEP_UNION_CoverManager`, dans `services.jar`) ignore le bouton power tant qu'une cover est détectée. Trois options sont comparées ; la slide retient la plus simple, désactiver le verrouillage automatique (voir la note).

**Ce qui est dit.**

Avec `getevent` en live, je vois quelque chose d'étrange. Quand je manipule la tablette, il y a un événement qui arrête pas de toggle :

```
SW_MACHINE_COVER     1
SW_MACHINE_COVER     0
```

Cet événement, c'est un capteur magnétique. La Book Cover de la tablette — la coque Samsung officielle — contient un aimant. Quand la coque est fermée, l'aimant est près d'un capteur Hall dans la tablette, et le capteur passe à 1. Le système comprend "la coque est fermée, éteins l'écran".

Mais pas que la coque. Le S Pen aussi est magnétique. Donc quand le stylet est dans son slot, le capteur réagit comme si la coque était fermée.

Première hypothèse : c'est un bug du driver kernel — `hall_ic_wacom` — qui lit le GPIO trop tôt au démarrage et passe l'info à Android avant qu'Android ait le temps de savoir qu'il n'y a pas vraiment de Book Cover attachée. Je patche le driver. Je rebuild. Je flashe. Le bug persiste.

Et c'est là, avec `logcat` en live, que je vois la vraie cause :

```
PowerManagerService: !@Screen__On : Cancel (coverType: 0)
```

Quand j'appuie sur le bouton power, l'événement est bien reçu. Android appelle `wakeUp()`. Et tout de suite après, il l'annule. Pourquoi ? Parce qu'il y a une extension Samsung dans le framework Android — `SEP_UNION_CoverManager` — qui dit : "si une coque est attachée, le bouton power ne réveille pas l'écran, c'est l'ouverture de la coque qui doit le faire".

Sauf que pour un coverType=0 — qu'on pourrait traduire par "coque générique non identifiée" — Samsung n'a implémenté aucun mécanisme alternatif de réveil. Donc le power button ne fait rien. La tablette est bloquée jusqu'à ce qu'on retire le stylet de son slot.

Le bug n'est pas dans mon kernel. Il n'est même pas dans Linux. Il est dans `services.jar` — du code Java framework Samsung — où il y a une condition `if (coverAttached) { return; }` sans alternative pour le cas générique.

Patcher le kernel pour retirer la capacité du capteur, c'est techniquement possible, mais ça casserait la fonctionnalité légitime du Book Cover Keyboard que j'ai. Patcher `services.jar`, c'est lourd. Donc workaround pragmatique : je désactive le verrouillage automatique d'écran dans les paramètres Android. J'appuierai sur power manuellement quand j'aurai fini.

La vraie leçon ? Le bug n'est pas toujours où on le cherche. J'ai passé un temps fou à blâmer mon kernel pour un comportement qui était dans une classe Java de Samsung.

> [!NOTE]
> La « solution retenue » affichée (désactiver le verrouillage automatique) a été remplacée ensuite : la version finale du patch modifie `hall_ic_wacom.c` pour que le capteur signale toujours « cover ouverte », sans aucun réglage Android ([détails](../../how-it-works.md#the-kernel)).

---

## ACTE 5 — Containers : trois impasses, un déclic

### Slide 24 — Containers, premières tentatives

**Ce qu'on voit.** Le kernel marche, ADB et root aussi : *« Y'a plus qu'à installer Podman, c'est plié. »* — *« Ben non. »* Trois portes, trois échecs, chacun avec son mécanisme : **proot** (l'interception des appels système bloque la création d'un namespace utilisateur), **chroot réel** (le kernel refuse le `remount /` du conteneur), **LXC** (la clé de chiffrement de `/data` est perdue après le `pivot_root`, erreur `ENOKEY`). Point commun : les trois lancent le conteneur à l'intérieur d'un chroot, dans le stockage chiffré d'Android.

**Ce qui est dit.**

Bon, donc maintenant que le kernel marche, que j'ai ADB et root, qu'Android est stable, je peux enfin attaquer ce pour quoi j'avais commencé tout ça : faire tourner des containers.

Et là, je pensais que ce serait la partie facile. Le kernel a tous les flags qu'il faut, j'ai vérifié, c'est validé. Y'a plus qu'à installer Podman et c'est plié.

Ben non.

Première tentative : Termux + une distro Ubuntu via un truc qui s'appelle proot. Proot, c'est une émulation de chroot — au lieu de demander un vrai changement de racine au kernel, ça intercepte tous les appels système d'un programme avec un mécanisme qu'on appelle ptrace, et ça fait croire au programme qu'il vit dans un autre système de fichiers. C'est pratique, ça ne demande pas root.

Sauf que ptrace, c'est exactement le mécanisme qui sert aussi à debug les programmes. Et quand un container essaie de créer un User Namespace — la base de tout container moderne — il fait un appel système `clone` avec un flag spécial. Ptrace l'intercepte, voit ce flag, et dit non. Container refusé.

Première porte fermée.

Deuxième tentative : un vrai chroot, avec Magisk root cette fois, donc un vrai changement de racine kernel-level. Ça démarre, Podman pull bien des images. Je lance un container. Et ça crashe avec ce message :

```
remount /, flags: 0x44000: invalid argument
```

Quand un container démarre, il essaie de faire un `remount /` avec deux flags qui demandent au kernel d'isoler son système de fichiers du reste. Ce remount, le kernel Linux le refuse quand le processus est dans un chroot dont la racine est partagée avec le namespace parent. C'est pas une option configurable, c'est codé en dur dans le VFS — la couche système de fichiers du kernel. J'ai retrouvé un thread sur GitHub où le mainteneur de Podman dit textuellement : "il y a des checks kernel qui empêchent de faire certaines choses depuis ce genre d'environnement, et il n'y aura pas de fix".

Deuxième porte fermée.

Troisième tentative : LXC. Ce runtime utilise un autre appel système, `pivot_root`, qui contourne le check précédent. Bonne nouvelle, le premier container LXC démarre, je vois Debian booter, il prend une IP. Mais à la session suivante, plus rien. Erreur :

```
Required key not available
```

ENOKEY. La partition `/data` d'Android est chiffrée avec un système qui s'appelle fscrypt. Le rootfs des containers LXC, je l'avais placé sur cette partition. Quand LXC fait son `pivot_root` et change de contexte de processus, la clé de déchiffrement présente dans le keyring du processus parent n'est plus accessible. Le container voit le rootfs chiffré et ne peut plus l'exécuter.

Troisième porte fermée.

Trois runtimes différents, trois mécanismes architecturaux qui s'entrechoquent. Le point commun : tous tentaient de faire tourner les containers à l'intérieur d'un chroot. Et Android, pour des raisons de sécurité, met des bâtons dans les roues à tout ce qui ressemble à un container imbriqué dans son rootfs chiffré.

---

### Slide 25 — Le pivot — dockerd natif

**Ce qu'on voit.** Un article de blog donne l'idée : lancer `dockerd` **directement sur Android**, sans chroot ni proot, puisque le kernel Android est un kernel Linux qui a tous les namespaces. Le schéma *avant / après* retire la couche chroot, et les trois problèmes précédents disparaissent avec elle. Reste à fournir à Docker ce qu'un vrai Linux a et qu'Android n'a pas (`/run`, `/etc/resolv.conf`, certificats…), jusqu'au premier `hello-world`.

**Ce qui est dit.**

Et le déclic vient d'un article de blog. Un développeur japonais, sur un Sony Xperia avec un kernel custom, fait tourner Docker sans aucun chroot. Il lance le daemon directement dans Termux, en root via Magisk, comme un processus Android normal.

Et c'est exactement ce qui débloque tout. Tant que j'essayais de faire tourner Docker dans un chroot, je me battais contre l'architecture. Quand je sors le daemon du chroot, qu'il vit comme un processus root Android natif, plus aucune restriction VFS, plus de problème de fscrypt, parce qu'on n'a plus jamais besoin de faire un changement de racine.

Bon, c'est pas magique pour autant. Android n'est pas une distribution Linux POSIX classique. Y a une dizaine de petits trucs qui manquent et qu'il faut reconstruire. Le système de fichiers racine est en lecture seule. Le dossier `/run` qui contient les sockets et les fichiers de PID des daemons n'existe pas — sur Android c'est pas tmpfs comme sur Linux. Le fichier `/etc/resolv.conf` qui dit où trouver le DNS, il n'existe pas non plus. Le bundle de certificats SSL pour HTTPS, absent. Cgroups, montés différemment. Pas de `/etc/passwd`. Pas de `/dev/shm` (shared memory).

Pour chaque manque, on bind-monte ou on monte un tmpfs ou on pousse un fichier. C'est tout. C'est répétitif, mais c'est une fois, ça tient dans un script. Et une fois tout ça en place, Docker tourne.

```
docker run --rm --net=host hello-world
Hello from Docker!
```

Mais attendez, j'avais quand même envie de mon environnement Ubuntu propre — pour faire de l'`apt install`, avoir un compilateur, un vrai shell. Donc je garde un chroot Ubuntu, mais cette fois pas pour faire tourner les containers. Le chroot, c'est juste pour mon environnement de dev. Et dans ce chroot, je mets des liens symboliques qui pointent vers les binaires Docker et Podman natifs Android. La variable `DOCKER_HOST` pointe vers la socket du daemon, qui tourne en dehors du chroot.

Résultat : quand j'ouvre mon shell Ubuntu et que je tape `docker ps`, ça parle au daemon natif Android via une socket, et j'ai mes containers. C'est complètement transparent.

---

### Slide 26 — Wrap-up

**Ce qu'on voit.** Le chemin parcouru en quatre actes : le kernel, le boot, l'écran, les conteneurs. Ce qui tourne aujourd'hui sur la tablette : le kernel personnalisé, Android 13 intact, ADB et root permanents, Docker natif, un environnement Ubuntu, le tout hors ligne. Les chiffres : 21 `boot.img` avant que ça démarre, 26 `recovery.img` avant qu'ADB réponde, plus de 100 crashs lus en OCR, des cafés non comptés. Et le compteur `WARRANTY_VOID`, passé de `0x0` à `0x1`. *Merci.*

**Ce qui est dit.**

On revient au point de départ. Je voulais Linux dans ma tablette, sans renoncer à ce qu'elle savait déjà faire.

Aujourd'hui, sur cette même tablette, je peux faire du dessin avec le stylet, regarder une vidéo, prendre des notes — tout ce qu'Android sait faire. Et en parallèle, je peux ouvrir un shell Ubuntu, lancer un container Docker, faire tourner un serveur web, écrire du code dans un éditeur. Sans débrancher mon laptop. Sans VPN. Sans VNC. Sans latence.

Tout ça, c'est rendu possible par un kernel modifié — quelques flags à activer, dont la version officielle Samsung ne voulait pas — un patch sur un capteur magnétique, et une architecture où Docker tourne comme un processus Android normal au lieu de se battre contre le système.

Au fond, ce qu'il y a à retenir, c'est que sous chaque appareil que vous achetez, il y a une plateforme qu'on a délibérément verrouillée pour vous. Pas par malveillance — pour des questions de sécurité, de garantie, de support. Mais ce verrouillage, c'est de la convention, pas de la fatalité. Si vous prenez le temps de regarder, de lire les sources, de comprendre les mécanismes, vous pouvez faire bouger les choses.

J'ai modifié quelques flags dans un kernel, contourné une protection cryptographique, identifié un capteur qui éteignait l'écran sans raison, et inversé une architecture container. C'est le résultat de tout ça que vous voyez à droite.

Tout ça parce que je voulais juste mettre des conteneurs sur une tablette.

Merci.

> [!NOTE]
> Aucun patch `xt_qtaguid` n'a été nécessaire : ce fichier n'existe pas dans cet arbre Android 13. Les cgroups v2 ne sont pas utilisés : Android réserve les contrôleurs à cgroup v1, les conteneurs tournent donc sans limites (`cgroups = "disabled"`). Le « kernel CIP 4.19 » est l'arbre LineageOS `android_kernel_samsung_sm8250`, qui intègre les mises à jour CIP.

---

[README](../../../README.md) · [Histoire du projet](../../histoire-du-projet.md) · [Dossier de recherche](../README.md) · [Récit complet](../recit-complet.md) · [Journal de bord](../journal.md) · **Slides expliquées** · [Script](script.md) · [Présentation (HTML)](warranty-void.html)
