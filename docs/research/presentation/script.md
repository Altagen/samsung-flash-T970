# Présentation — script & slides

[README](../../../README.md) · [Histoire du projet](../../histoire-du-projet.md) · [Dossier de recherche](../README.md) · [Récit complet](../recit-complet.md) · [Journal de bord](../journal.md) · [Slides expliquées](slides.md) · **Script** · [Présentation (HTML)](warranty-void.html)

> Numérotation alignée sur les 26 slides de la présentation (compteur en bas de l'écran, en-têtes « // Slide NN »). La version présentée le 7 mai 2026 numérotait 24 « scènes », sans la slide de titre ni la slide bonus.

**Format** : présentation web Next.js + Framer Motion + GSAP + Tailwind, navigation clavier (clicker)
**Durée cible** : ~30 min
**Audience** : ingénieurs (pas experts kernel)
**Hook** : mystère cryptographique (boucle narrative — résolu en slide 15)

Format de chaque slide :
- `[SLIDE]` — uniquement le visuel, jamais le texte parlé
- `[SCRIPT]` — le texte à dire
- `[PHOTOS À FOURNIR]` — checklist des images à insérer depuis le dossier photos

---

## Slide 1

[SLIDE]
- Titre du talk : **« Warranty Void. »**, sous-titre *« Des conteneurs sur une tablette ? »*, fond sombre animé.
- En bas : orateur, date (7 mai 2026), événement (Mesh Union · édition #01).

[SCRIPT]
*(Pas de texte parlé : écran d'accueil avant de prendre la parole.)*

---

# ACTE 0 — Hook

## Slide 2
[SLIDE]
- **Layout** : fullscreen noir profond, typographie monospace blanche, lettrage XL.
- **Élément central** : deux lignes hexadécimales empilées au centre :
  ```
  07 00 02 00 00 00 00 00 00 00 00 00 00 00 00 00
  06 00 02 00 00 00 00 00 00 00 00 00 00 00 00 00
  ```
- **Animation** : les deux chaînes apparaissent avec un fade-in décalé (1ère ligne, puis 2ème). Après ~3s, l'octet `07` (haut, première paire) et `06` (bas, première paire) se mettent à pulser en rouge, doucement. Le reste reste en blanc.
- **Sous-titre minuscule** en bas, tout petit, en gris : `Root of Trust — Samsung Keymaster — Tab S7+`
- **Pas de titre, pas de logo, rien d'autre.** L'œil n'a que ces octets à regarder.

[SCRIPT]
Vous voyez ces deux lignes ?

Elles sont presques identiques à l'exception d'un seul octet. Et à cause de cet octet, il a fallu que je change 3 fois mon kernel. J'ai tout perdu pour un compteur, que personne n'est censé voir. ça m'a coûté très cher en temps mais ça m'a permis d'aller faire un tour dans les fin-fonds du bas niveau pour comprendre cet octet. J'ai dû comprendre comment samsung boote, comment android isole ses processus, comment SElinux contrôle l'exécution d'un programme, et aussi... Patcher un kernel Linux, tout ça parce-que je voulais mettre des conteneurs sur une tablette.

Petit disclaimer le but n'est pas de faire un tuto mais de vous présenter les recherches, je ne vais pas rentrer dans une explication technique à la commande près mais assez d'éléments pour que vous puissiez comprendre la démarche.

[PHOTOS À FOURNIR]
- Aucune photo pour cette slide — full CSS / typographie. (Optionnel : si tu as une capture nette d'un log pstore où on voit `current rot value` et `saved rot value`, on peut l'utiliser en easter-egg en arrière-plan ultra atténué.)

---

# ACTE 1 — Pourquoi je me suis embarqué là-dedans

## Slide 3
[SLIDE]
- **Layout** : split-screen 50/50 horizontal.
- **Côté gauche** : photo de la tablette dans ses usages "normaux" — dessin au stylet, lecture de PDF, browser. Saturée, lumineuse.
- **Côté droit** : capture monospace d'un terminal vide avec juste un prompt qui clignote `$ _`, fond très sombre, texte gris.
- **Animation** : à la mention de "compiler du code", le côté gauche s'estompe (-30% luminosité), le côté droit gagne en saturation. Subtil, ne prend pas le focus.

[SCRIPT]
Revenons au début :
Il y a 6 ans j'ai acheté une tablette : une samsung galaxy tab s7+. C'est une tablette parfaite pour le jeu, pour dessiner, et même pour travailler elle fait vraiment le job Seul bémol, elle est plus mise à jour par samsung depuis 2022. Le problème principal pour mon usage: c'est le code. En mobilité pour du travail léger, cette tablette est géniale mais impossible de faire quelque chose de relatif à du code. évidemment, je pourrai me connecter en VPN à mon infra chez moi et faire du VNC mais il y a une latence et j'aime quand c'est natif.

Et franchement la flemme de prendre un laptop.

[PHOTOS À FOURNIR]
- 1 photo de la tablette en usage "normal" (idéalement avec stylet en main, ou affichant un PDF / une vidéo).

---

## Slide 4
[SLIDE]
- **Layout** : composition en deux temps.
- **Temps 1** (pendant la narration "je regarde ce qui existe") : un mockup de plusieurs onglets de navigateur empilés en cascade, avec des titres d'articles flous mais lisibles ("Run Docker on Android", "Custom kernel build for tablet", "Container support on Android..."). Sur l'un d'entre eux, une phrase est highlightée en jaune fluo : *"your kernel doesn't have the flags to run this"*.
- **Temps 2** (pendant l'aparté kernel = noyau) : transition douce vers un schéma simple.
  - Au centre, un rectangle étiqueté `KERNEL` (noyau).
  - Au-dessus, plusieurs petites icônes étiquetées `programmes` (terminal, app, browser).
  - En-dessous, des icônes hardware (CPU, RAM, stockage, réseau).
  - Des flèches bidirectionnelles entre programmes ↔ kernel ↔ hardware.
  - Sur l'une des flèches, en rouge : `kernel dit non → rien ne fonctionne`.

[SCRIPT]
Du coup, je me suis dit... Mais pourquoi pas faire de ma tablette un usage de laptop ? Pourquoi je pourrai pas juste prendre ma tablette et lancer mes conteneurs ?
Première chose que je fais, je regarde ce qui existe, je tente de faire des installations de "solutions" qui existent déjà sans grand succès, et plus je cherche et plus je tombe sur des articles qui me disent en gros "ton matériel peut le faire mais ton kernel n'a pas les flags pour lancer ça" En gros, le Noyau supporte ce que je veux faire mais quand samsung a fait sa release, il ont désactivé des flags en se disant : pourquoi lancer des conteneurs sur une tablette, on ne garde que ce dont on a besoin.

Petite apparté pour ceux qui ne savent pas ce que c'est un kernel : ça veut dire Noyau. C'est le composant central du système d'exploitation qui permet de faire le lien avec les interfaces physiques comme le stockage, le réseau, le processeur, la ram etc. Le noyau reçoit des demandes de la part des programmes qui tournent sur votre système d'exploitation et il va faire le médiateur entre les deux. Si le noyau dit non, rien ne fonctionnera.

[PHOTOS À FOURNIR]
- Aucune. Tout en CSS/SVG.

---

## Slide 5
[SLIDE]
- **Layout** : flow horizontal en 4 étapes, type pipeline de build.
- **Étapes** :
  1. `Sources kernel` (icône fichier code)
  2. `Configuration` (icône cases à cocher) ← une étoile flashe ici, c'est là qu'on choisit les flags
  3. `Compilation` (icône engrenages)
  4. `Image binaire` (icône paquet)
- **Animation** : le flow se dessine de gauche à droite. Une fois arrivé à l'image binaire, un cadenas apparaît dessus avec une légende : *"Une fois compilé, c'est figé."*
- **En bas, en plus petit** : *"Pour changer un flag → on refait tout."*

[SCRIPT]
Le truc c'est que moi j'en ai besoin de ces flags. Donc je vais devoir les rajouter.

Pour ceux qui ne le savent pas: Un kernel une fois qu'il est compilé vous ne pouvez plus le modifier pour y rajouter des flags, vous devez obligatoirement modifier la configuration et les options de build, rebuilder votre kernel et le reflasher dans votre mâchine.

[PHOTOS À FOURNIR]
- Aucune photo nécessaire.

---

## Slide 6
[SLIDE]
- **Layout** : carte d'identité technique, look "fiche produit" en deux blocs.
- **Bloc gauche — Le device** :
  - `Galaxy Tab S7+ Wi-Fi`
  - `SM-T970`
  - `Snapdragon 865 (SM8250)`
  - `Linux 4.19 patché Samsung`
  - `Android 13 · One UI 5.1.1`
  - `Stylet Wacom · 120 Hz`
- **Bloc droit — L'environnement de build** :
  - `Sources : kernel open source Samsung (GPL)`
  - `Container Podman sur PC`
  - `clang-12`
  - `Cross-compile aarch64`
- **Animation** : chaque ligne apparaît en cascade (200ms entre chaque). Sur la dernière ligne du bloc gauche, un petit S Pen stylisé "fait un trait". Sur le mot "GPL" du bloc droit, un highlight discret (c'est le levier qui permet tout le reste).

[SCRIPT]
Avant d'expliquer le reste, un petit tour sur les specs Galaxy Tab S7+ WI-Fi, Nom de code SM-T970 et un SoC (processeur) Snapdragon 865, nom de code Qualcomm SM8250. Le kernel tourne en linux 4.19 qui a été vraiment patché lourdement. Android 13, One UI 5.1.1, un stylet Wacom, 120hz...

Les sources de build : Faut savoir que la license GPL du kernel Linux oblige à livrer les sources, donc j'ai eu accès aux sources de samsung pour pouvoir rebuild.

Pour mon environnement de build, j'ai utilisé podman sur mon PC avec la version de clang qui a été utilisée (clang12) et la chaine de compilation en aarch64 vu que c'est une architecture arm.

[PHOTOS À FOURNIR]
- (Optionnel) 1 photo macro de la tablette posée sur ton bureau de dev, vue de dessus.

---

## Slide 7
[SLIDE]
- **Layout** : liste centrale en monospace, chaque flag avec une petite icône à gauche et une légende à droite.
- **Liste** :
  - 🔐 `CONFIG_USER_NS=y`           → User Namespaces — isolation des utilisateurs par container
  - 🎚️ `CONFIG_CGROUPS=y`           → contrôle CPU / RAM / disque par container
  - 🥞 `CONFIG_OVERLAY_FS=y`        → couches de fichiers empilées (image + delta)
  - 🌐 `CONFIG_NET_NS=y`            → réseau isolé par container
  - 🧱 `CONFIG_NAMESPACES=y`        → la base de toute isolation
- **Animation** : chaque ligne apparaît une à une avec un léger glow vert quand elle se pose. À la fin, en bas, une coche verte ✓ avec : *"5 flags. C'est tout. Mais Samsung les avait désactivés."*

[SCRIPT]
Le truc rigolo maintenant c'est AVANT de flasher quoi que ce soit j'ai dû avoir quelque chose à flasher, donc j'ai dû prendre les sources, comprendre à quoi servaient les flags, choisir les bons avec leurs dépendances et flasher, donc on arrive à ces flags là qui sont absolument obligatoires:

- `CONFIG_USER_NS=y` (User Namespaces — requis pour Podman rootless)
- `CONFIG_CGROUPS=y` + sous-systèmes (memory, cpu, cpuacct, blkio, etc.)
- `CONFIG_OVERLAY_FS=y` (requis pour les layers de containers)
- `CONFIG_NET_NS=y` (réseau container)
- `CONFIG_NAMESPACES=y` (namespaces en général)

Je build mon kernel depuis ce namespace et voilà, j'ai mon kernel tout propre avec mes flags.

[PHOTOS À FOURNIR]
- Aucune photo.

---

## Slide 8
[SLIDE]
- **Layout** : fullscreen, fond noir.
- **Au centre** : un compteur cryptographique stylisé qui passe de `0` à `1` avec un effet glitch. À côté, en rouge : `KNOX_WARRANTY_VOID`. En dessous, plus petit : `irréversible`.
- **Tout autour**, en cercle, des icônes qui s'allument/s'éteignent : Samsung Pay (s'éteint), Secure Folder (s'éteint), Knox enterprise (s'éteint). Animation : à mesure que le `0` devient `1`, les icônes s'éteignent en cascade.
- **Bas de slide**, petit : `Vol Haut + Vol Bas + USB → écran 1 → maintenir Vol Haut`

[SCRIPT]
Le premier obstacle majeur c'est le dévérouillage OEM. En fait, je sais pas trop lire une doc ce qui est problématique vu que j'ai perdu beaucoup de temps. En fait pour dévérouiller le bootloader (qui est la chaine de boot d'android le premier programme exécuté par un appareil Android lors de l'allumage, agissant comme une passerelle critique entre le matériel et le système d'exploitation. Il initialise les composants matériels, charge le noyau Linux et vérifie l'intégrité des partitions système via des signatures numériques pour garantir la sécurité et empêcher l'installation de logiciels non autorisés. )  et permettre d'injecter mon kernel, il faut "dévérouiller" cette partie. Quand on le dévérouille on fait sauter les sécurités et la garantie, y'a un truc qui s'appelle Knox chez Samsung qui permet de savoir si on a flasher le firwmware, et ça désactive des fonctions de sécurité avancée comme les dossier sécurisés et d'autres trucs de l'écosystème dont j'ai pas spécialement besoin. En tout cas, ça flingue juste la garantie et ça fait passer le bit "WARRANTY_VOID" de 0x0 à 0x1 et c'est irréversible.

après avoir perdu un temps colossal, j'ai enfin compris la suite de bouton qui permettait le dévérouillage OEM (Original Equipment Manufacturer)

[PHOTOS À FOURNIR]
- 1 photo de l'écran "Warning" Samsung en Download Mode (le fond jaune/orange, texte d'avertissement). En arrière-plan flouté ou en incrustation.
- (Optionnel) 1 photo de l'écran de déverrouillage OEM avec compteur, si tu en as une.

---

# ACTE 2 — La saga du kernel

## Slide 9
[SLIDE]
- **Layout** : schéma propre d'une boot.img qu'on "ouvre" comme un coffre.
- **Au centre**, une représentation visuelle de boot.img : une boîte rectangulaire qui s'éclate en 4 morceaux étiquetés :
  - `kernel` (l'image que je viens de compiler)
  - `ramdisk` (mini système de fichiers chargé en RAM au boot)
  - `dtb` (description du hardware)
  - `cmdline` (paramètres passés au kernel)
- **Animation** : la boîte s'ouvre, les 4 morceaux glissent vers l'extérieur. Le morceau `kernel` se met à pulser doucement (c'est celui que je remplace). Les 3 autres restent stables (je les garde stock).

[SCRIPT]
Maintenant que j'ai mon kernel custom, il faut que je comprenne où il va atterrir avant de pouvoir le mettre dans la tablette.

Sur Android, il y a un fichier qui s'appelle `boot.img`. C'est une image binaire qui contient quatre choses : le kernel, un mini système de fichiers qu'on appelle le ramdisk — c'est ce qui contient le tout premier programme à se lancer après le kernel — un fichier qui décrit le matériel, et une ligne de paramètres pour le kernel.

Mon plan : je remplace juste le kernel par le mien, je laisse tout le reste stock, je reflashe. Sauf que c'est pas comme ça que Samsung voit les choses.

Premier flash. La tablette boot... sur l'écran de recovery Samsung. Avec un message qui dit "Can't load Android system". Pas dans Android, dans recovery.

Donc déjà, premier truc : Android sur les versions récentes, par défaut, il boot en mode recovery. Pour qu'il fasse un boot normal, il faut explicitement lui dire dans la cmdline. Donc je rajoute un flag, `force_normal_boot=1`. Reflash. Cette fois, plus de recovery. Mais... bootloop.

[PHOTOS À FOURNIR]
- 1 photo de l'écran "Can't load Android system" du recovery Samsung. Si tu en as une, c'est l'idéal en vignette.
- (Optionnel) 1 photo de la tablette en bootloop (le logo Samsung qui revient en boucle).

---

## Slide 10
[SLIDE]
- **Layout** : split. À gauche, un écran noir avec juste le logo Samsung qui réapparaît en boucle (gif/animation). À droite, une zone "RAM" stylisée — un rectangle tramé — avec un petit segment lumineux étiqueté `pstore (ramoops)` qui survit malgré les reboots successifs.
- **Animation** : la tablette se reboot 3-4 fois côté gauche. À chaque reboot, le segment pstore côté droit reste éclairé alors que tout le reste s'éteint.
- **Bas de slide** : la commande, en gros, monospace : `cat /sys/fs/pstore/console-ramoops-0`
- **Animation secondaire** (en fin de slide, quand l'OCR est introduit) : une petite illustration apparaît en bas-droite — un téléphone qui photographie un écran de tablette, puis une flèche vers une bulle de texte transcrit (avec quelques caractères flagués en rouge `1↔l`, `0↔O`).

[SCRIPT]
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

[PHOTOS À FOURNIR]
- 1 photo de log pstore brut (celui que tu as OCR-isé), qu'on puisse afficher en overlay subtil.
- 1 photo "OCR en action" — idéalement une photo prise par toi de la tablette à l'écran avec des logs, pour incarner concrètement le workflow.
- (Optionnel) Capture du terminal où tu tapes `cat /sys/fs/pstore/console-ramoops-0`.

---

## Slide 11

[SLIDE]
- Slide bonus, ajoutée pendant la réalisation : mosaïque des 16 photos de l'écran de la tablette prises le 9 avril 2026 entre 20:35 et 20:38 pour reconstituer un seul log par OCR.
- Légende : *« workflow temporaire débile, mais qui a marché »*.

[SCRIPT]
*(Pas de texte parlé propre : illustre le workflow OCR décrit à la slide 10.)*

---

## Slide 12
[SLIDE]
- **Layout** : grand schéma au centre, type "arbre" stylisé.
- **Au sommet** : un rectangle `kernel`.
- **En dessous**, un arbre — Device Tree — qui descend en branches : chaque branche est un composant matériel (CPU, écran, USB, audio, modem, capteurs...).
- **À côté de l'arbre principal**, plus petit : une feuille étiquetée `DTBO Samsung — overlay spécifique gts7xlwifi` qui se "greffe" sur l'arbre principal avec une animation de pioche/insertion.
- **En bas, en rouge** : une zone qui clignote, étiquetée `__symbols__ — manquant dans mon DTB`.

[SCRIPT]
Pour comprendre,il faut que j'introduise un truc qui s'appelle le Device Tree. C'est un arbre qui décrit le matériel au kernel : "voilà le CPU, voilà l'écran, voilà l'USB, à telle adresse, avec telles options". Sans ce fichier, le kernel sait pas avec quoi il parle.

Et sur Android, il y a une couche de plus : un overlay — que Samsung appelle DTBO ((Device Tree Blob Overlay) - qui permet d'ajouter ou de modifier des nœuds et des propriétés dans l'arborescence des périphériques sans modifier le fichier DTB central) — qui vient compléter ce Device Tree avec les spécificités du modèle exact. Pour ma tablette, ça contient les paramètres précis du stylet, de l'écran, etc.

Première découverte : le Makefile des sources Samsung avait un répertoire commenté qui empêchait la compilation des Device Trees. Mon kernel n'en avait aucun. Je dé-commente, je rajoute les bons, je compile, je flash. Premier progrès dans les logs : "Hardware name: Samsung GTS7XL" apparaît. La tablette se reconnaît comme une Tab S7+. C'est gagné de ce côté-là.

Sauf que le crash continue. Init dit toujours qu'il trouve pas son fstab.

Et c'est là que je creuse encore : le DTBO Samsung, pour fonctionner, doit pouvoir cibler des éléments précis dans mon Device Tree par leur nom. Pour ça, il faut une table de symboles à l'intérieur du fichier — la fameuse `__symbols__`. Mes Device Trees, je les ai compilés sans cette table. Du coup, le DTBO de Samsung ne peut pas se greffer correctement. Tout fonctionne à moitié.

Bon... je passe quand même 7 versions à modifier le Device Tree, à enrichir le fstab, à ajouter des entrées partout. Toujours bootloop. Toujours le même message. Sauf que le timing du crash change : avant ça crashait immédiatement, maintenant ça crashe au bout de 10 secondes. Donc init essaie quelque chose. Il trouve quelque chose. Mais ça finit pareil.

[PHOTOS À FOURNIR]
- (Optionnel) Capture d'un fichier `.dts` ouvert dans ton éditeur, avec syntaxe colorée — pour illustrer "voilà à quoi ça ressemble".

---

## Slide 13
[SLIDE]
- **Layout** : une seule cmdline gigantesque en monospace, qui occupe toute la largeur de la slide. La ligne contient tous les paramètres habituels (`console=null androidboot.hardware=qcom ...`) et au milieu, surligné en rouge : `androidboot.force_normal_boot=1`.
- **Animation** : la cmdline apparaît normalement. Puis, brutalement, le flag `force_normal_boot=1` est barré (animation strikethrough), puis disparaît. Le reste de la cmdline glisse pour combler le trou. Pause. Au-dessus de la cmdline, un texte apparaît : *"La solution était de retirer le flag que j'avais ajouté."*

[SCRIPT]
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

[PHOTOS À FOURNIR]
- Aucune photo. Pure typographie + animation.

---

## Slide 14
[SLIDE]
- **Layout** : timeline horizontale qui se déroule, étape par étape.
- **Étapes affichées** au fil du script (apparaissent une à une) :
  - `t=3.35s` — `metadata mounted`
  - `t=3.39s` — `system / vendor / product / odm mounted`
  - `t=5.16s` — `Switching root to /system`
  - `t=5.16s` — `init second stage started!`  ← celui-là grossit, en vert, animation de victoire
  - `t=23s` — `vold: enablefilecrypto failed`  ← celui-là apparaît plus tard, en rouge
- **Animation** : la timeline avance, on voit la victoire, puis le crash final.

[SCRIPT]
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

[PHOTOS À FOURNIR]
- 1 photo de la recovery Samsung qui propose "Retry / Factory Reset" après crash ODE. Si tu as la photo où on voit clairement le menu, c'est parfait.

---

## Slide 15
[SLIDE]
- **Layout** : retour aux deux chaînes hexadécimales du hook (slide 2). Mêmes octets, même typographie, mais cette fois on **explique**.
- **Animation, en plusieurs temps** :
  1. Les deux chaînes apparaissent (rappel direct du hook).
  2. Une flèche apparaît à gauche, pointant le `06` du bas, légende : `bootloader verrouillé · compteur unlock = 0`
  3. Une flèche apparaît à gauche, pointant le `07` du haut, légende : `bootloader déverrouillé · compteur unlock = 1`
  4. Au-dessous des deux chaînes, un cadenas stylisé apparaît avec une légende : `Samsung Keymaster — TrustZone — refuse de déchiffrer si ROT a changé`
  5. Punchline visuelle, en bas, après une pause : *"Mes clés ont été créées avec ROT=06. Maintenant, ROT=07."*

[SCRIPT]
OK, on remonte au tout début de la présentation, vous vous souvenez des deux octets ?

Voilà ce que c'était.

Sur les téléphones et tablettes Samsung modernes, la partition utilisateur — celle qui contient vos données, vos photos, vos applis — est chiffrée. Et la clé de chiffrement n'est pas stockée n'importe où : elle est gardée par un programme qui s'appelle Keymaster, qui tourne dans une enclave de sécurité matérielle qu'on appelle TrustZone — c'est une zone du processeur isolée du reste, à laquelle même le kernel n'a pas accès directement.

Et Samsung a ajouté une règle : avant de déchiffrer une clé, Keymaster vérifie un truc qu'on appelle la Root of Trust. Cette ROT, c'est une valeur calculée par le bootloader, à partir de l'état actuel de l'appareil : verrouillé ou déverrouillé, plus un compteur qui s'incrémente à chaque fois qu'on déverrouille.

Quand vous achetez la tablette, le bootloader est verrouillé, le compteur est à 0, la ROT vaut quelque chose qui commence par `06`. Toutes les clés de chiffrement de la tablette sont liées à cette valeur.

Et au moment où j'ai déverrouillé l'OEM — vous vous souvenez, le bouton volume qui m'a cassé les pieds — le compteur est passé de 0 à 1. La ROT est devenue `07`.

Et là, Keymaster, fidèle à sa mission, refuse de déchiffrer les clés. Parce que ces clés ont été créées avec ROT=06. Maintenant, ROT=07. Pour lui, ça veut dire : "quelqu'un a touché au système, je ne déchiffre rien".

C'est ça l'octet du début. Le compteur qu'on ne voit jamais. C'est lui qui m'a empêché de booter.

[PHOTOS À FOURNIR]
- 1 photo de log `prev_dump.log` ou `last_kmsg` où on voit `KM_TAG_SAMSUNG_ROT_REQUIRED` ou les valeurs `current rot value` / `saved rot value`. En arrière-plan ou en zoom, c'est l'illustration parfaite.

---

## Slide 16
[SLIDE]
- **Layout** : trois moments visuels qui se succèdent.
  1. **Image 1** : icône factory reset avec une corbeille qui se vide. Légende : `efface /data — détruit toutes les anciennes clés`
  2. **Image 2** : transition avec un écran de boot Samsung qui apparaît, un petit `04e8:6860 — MTP detected` qui clignote en bas. Légende : `Android boot. La tablette est vivante.`
  3. **Image 3** : un cadre noir vide, juste au centre une petite phrase : `Mais l'écran reste noir.`
- **Animation** : les trois images se succèdent avec une transition qui ralentit progressivement, créant un effet d'anticipation.

[SCRIPT]
La solution, à ce stade, elle est radicale mais logique : factory reset. Effacer toute la partition utilisateur. Comme ça, vold est obligé de regénérer des nouvelles clés — qui seront liées à la ROT actuelle, donc 07. Et là tout marche.

Je fais le factory reset depuis le menu recovery. Je perds tout. Bon, c'est OK, c'était une tablette de test à ce stade. Je reboot avec mon kernel custom.

Et là... pour la première fois, Android boot. Le kernel CIP (Civil Infrastructure Platform durée de vie de 10 ans mais on s'en fiche) a démarré le système. La tablette apparaît sur mon PC en USB, en mode MTP — comme une tablette normale. Plus de crash. enablefilecrypto a réussi.

Sauf que l'écran reste noir.

L'ABL — le bootloader Samsung — affiche bien ses propres écrans, le logo Samsung au démarrage, le warning sur le bootloader déverrouillé. Mais dès que le kernel prend le relais, plus rien.

Donc je résume : j'ai un kernel qui boot, qui monte les partitions, qui démarre Android, qui me donne accès à la tablette en USB. Et je vois rien à l'écran.

J'ai un problème d'affichage maintenant.

[PHOTOS À FOURNIR]
- 1 photo de la tablette avec l'écran noir mais visiblement allumée (rétroéclairage actif).
- 1 photo (ou capture PC) montrant la tablette détectée en MTP `04e8:6860` dans `lsusb` ou un explorateur de fichiers — ça prouve qu'elle est vivante.

---

# ACTE 3 — La guerre du recovery (SELinux)

## Slide 17
[SLIDE]
- **Layout** : composition centrée, schéma "circuit fermé".
- **Au centre**, un cercle de 3 éléments reliés par des flèches qui forment une boucle :
  1. `Écran noir` → 2. `Pas d'accès UI` → 3. `Pas de USB debugging activable` → 4. `Pas d'ADB` → retour à 1 (`Pas de logs pour comprendre l'écran noir`)
- **Animation** : les flèches s'illuminent dans l'ordre du cycle, puis tout le cercle se met à pulser doucement en rouge.
- **En bas, petit** : *"Pour débugguer l'écran, il me faut ADB. Pour avoir ADB, il me faut l'écran."*

[SCRIPT]
Bon, donc nouveau problème. La tablette boot, elle est vivante, mais l'écran est noir.

Et là, on tombe dans un truc rigolo. Pour comprendre pourquoi l'écran est noir, il faudrait que je récupère les logs d'Android — `logcat`, `dmesg`, ce genre de trucs. Ces logs sont accessibles par ADB — Android Debug Bridge — qui est l'outil qu'on utilise pour parler à un téléphone Android depuis un PC.

Sauf que pour qu'ADB fonctionne, il faut activer "USB debugging" dans les paramètres Android. Et pour activer USB debugging, il faut accéder à l'écran de configuration. Et l'écran est noir.

Pour débugguer l'écran, il me faut ADB. Pour avoir ADB, il me faut l'écran.

Donc il faut que je trouve ADB autrement.

[PHOTOS À FOURNIR]
- (Optionnel) 1 photo de la tablette dans le noir, allumée mais sans rien à l'écran.

---

## Slide 18
[SLIDE]
- **Layout** : split-screen.
- **Côté gauche** : icône stylisée de la partition `recovery` qui s'éclate, on voit le ramdisk extrait, deux fichiers en évidence : `default.prop` et `prop.default`.
- **Animation** : `default.prop` est barré en gris (legacy), `prop.default` se met à briller (le vrai fichier sur Android 11+). Les deux fichiers sont modifiés (icône clé/cadenas) avec des lignes qui apparaissent : `ro.adb.secure=0`, `ro.debuggable=1`.
- **Côté droit** : un terminal qui affiche progressivement :
  ```
  $ adb devices
  R52N•••••••    unauthorized   ← première version
  R52N•••••••    recovery       ← après le fix
  ```

[SCRIPT]
Sur Android, en plus du système normal, il y a une partition spéciale qu'on appelle le `recovery`. C'est un mini-système qui sert à faire les mises à jour, les factory reset, et accessoirement, à récupérer un téléphone qui ne boot plus. Le recovery a son propre ramdisk, indépendant de celui du système.

Mon plan : je patche le ramdisk du recovery pour activer ADB par défaut, sans avoir besoin de l'autoriser depuis l'écran. Comme ça, quand je boot en recovery, j'ai un shell.

Première tentative : je modifie un fichier qui s'appelle `default.prop` pour mettre `ro.adb.secure=0` — en gros "désactive l'autorisation ADB". Je flashe. ADB me voit toujours en `unauthorized`.

Je creuse, et je découvre que sur Android 11 et plus, le fichier qui prime n'est plus `default.prop` mais `prop.default`. Les deux coexistent — vestige historique — mais c'est le deuxième qui est lu activement.

Je patche les deux. Je flashe. Cette fois, `adb devices` me montre la tablette en `recovery`, plus en `unauthorized`. Je tape `adb shell`...

Crash immédiat.

[PHOTOS À FOURNIR]
- (Optionnel) Capture du terminal montrant la transition `unauthorized` → `recovery`.

---

## Slide 19
[SLIDE]
- **Layout** : liste centrale, type "carnet de tentatives".
- **Au centre**, un titre : `Comment contourner SELinux`.
- **En dessous**, une liste qui se construit ligne par ligne. Chaque ligne, après ~1.5s, se fait barrer en rouge avec une croix `✗` à côté :
  1. `Retirer --root_seclabel du service adbd` ✗
  2. `androidboot.selinux=permissive en cmdline` ✗
  3. `selinux=0 en paramètre kernel` ✗
  4. `Patch binaire de adbd (bypass SIGABRT)` ✗
  5. `Écrire 0 dans /sys/fs/selinux/enforce au early-init` ✗
  6. `adb push 0 vers /sys/fs/selinux/enforce` ✗
- **En bas, petit** : *"26 versions de recovery."*

[SCRIPT]
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

[PHOTOS À FOURNIR]
- (Optionnel) Photo d'un terminal qui affiche un AVC denial SELinux — ça donne du grain à la slide.

---

## Slide 20
[SLIDE]
- **Layout** : centré, contraste fort.
- **En haut**, une question : `Et si je ne désactivais pas SELinux ?`
- **En dessous**, la commande, en grand, monospace :
  ```
  magiskpolicy --load sepolicy 'permissive adbd' --save sepolicy
  ```
- **Animation** : le texte de la commande apparaît mot par mot. Le mot `permissive` se met à briller en vert. À côté de la commande, une petite icône Magisk discrète.
- **En bas, après une pause** : *"L'outil était dans mon repo depuis le début."*

[SCRIPT]
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

[PHOTOS À FOURNIR]
- (Optionnel) Capture du terminal avec `adb shell uname -r` qui retourne `4.19.113-...` depuis le recovery.

---

# ACTE 4 — L'écran noir n'était pas du DRM

## Slide 21
[SLIDE]
- **Layout** : style "wanted poster" minimaliste mais sobre, fond papier vieilli ou texture discrète.
- **Au centre, en grand** : `[drm:msm_fb_obj_get_attrs] *ERROR* NULL attachment` (en monospace, façon log).
- **Animation** :
  1. Le message d'erreur apparaît, gros, entouré d'un cadre rouge.
  2. Pause.
  3. Une estampille circulaire bleue glisse depuis le coin et vient s'apposer sur la phrase : `INNOCENT`.
  4. Un sous-texte apparaît : *"Cette erreur venait du kernel recovery, pas du kernel CIP."*

[SCRIPT]
Donc maintenant j'ai ADB depuis le recovery. Je peux pull les logs du dernier boot avec mon kernel custom — `/proc/last_kmsg`, deux mégaoctets de logs. Je m'attendais à trouver des erreurs DRM en pagaille, parce que dans les logs précédents — ceux que je récupérais en photographiant l'écran et en faisant de la reconnaissance de caractères — j'avais vu un message qui revenait sans arrêt : `NULL attachment`. C'est typiquement le genre d'erreur qu'on voit quand le driver d'affichage galère à allouer de la mémoire pour le framebuffer.

Sauf que dans les logs propres que j'extrais maintenant... aucun message de ce type. Le driver DRM du kernel CIP fonctionne nickel. Il alloue ses buffers, il configure l'IOMMU (Input–Output Memory Management Unit), il identifie le panel Samsung. Tout est vert.

Et là je comprends. Les `NULL attachment` que j'avais vus avant, ils venaient du kernel recovery, pas du kernel CIP. Quand on lit `/proc/last_kmsg`, ça contient les logs du boot précédent — et le boot précédent, dans mon workflow, c'était souvent un boot recovery. Je traquais une erreur qui n'avait jamais existé dans mon kernel.

Le kernel n'est pas le coupable.

[PHOTOS À FOURNIR]
- (Optionnel) 1 photo d'un de tes anciens logs OCR-isés où on voit `NULL attachment`, en arrière-plan flouté pour appuyer le contraste avec la nouvelle découverte.

---

## Slide 22
[SLIDE]
- **Layout** : flow horizontal en 3 étapes, type infographie.
- **Étapes** (chacune représentée par une icône stylisée + un mot) :
  1. `Re-flasher boot.img stock` (icône : flèche retour) → écran fonctionne ✓
  2. `Flasher TWRP en recovery` (icône : ramdisk + clé) → recovery custom avec shell root ✓
  3. `Installer Magisk via TWRP` (icône : Magisk) → root Android ✓
- **Animation** : chaque étape s'illumine en cascade, les coches verts apparaissent. À la fin, une zone "outils dispos" apparaît en bas avec : `ADB ✓  · root ✓  · écran ✓  · logcat ✓`.

[SCRIPT]
À ce stade, je prends une décision stratégique. J'arrête de me battre uniquement avec le kernel custom.

Je remets le kernel d'origine. L'écran refonctionne. J'installe TWRP — un recovery custom communautaire. Pour ça il y a une petite ruse : il faut désactiver la vérification de signature des partitions, parce que TWRP n'est évidemment pas signé par Samsung. Ça se fait en flashant une partition spéciale qui s'appelle `vbmeta` (Verified Boot Metadata) avec le flag de désactivation.

TWRP me donne accès à un shell root en recovery. Depuis ce shell, j'installe Magisk — c'est l'outil qui permet d'avoir root sur Android sans modifier la partition système. Magisk patche le `boot.img` à la volée pour s'injecter au démarrage.

Le résultat : Android d'origine qui boot normalement, écran fonctionnel, mais maintenant j'ai ADB, j'ai root via Magisk, je peux utiliser `logcat`, `dmesg`, `getevent` en live. Je peux investiguer comme sur n'importe quelle distribution Linux.

Du coup je reflashe mon kernel custom, mais avec Magisk patché dedans. Et je m'attaque au vrai problème : pourquoi l'écran est noir.

[PHOTOS À FOURNIR]
- (Optionnel) Capture d'écran de TWRP en cours de fonctionnement (l'interface bleue/orange caractéristique).
- (Optionnel) Capture de l'app Magisk sur la tablette une fois installée.

---

## Slide 23
[SLIDE]
- **Layout** : split en deux temps.
- **Temps 1 (apparition initiale)** :
  - Une vue éclatée de la tablette avec sa Book Cover ouverte. Un aimant stylisé est mis en évidence dans le slot du S Pen.
  - À côté, un extrait de log live monospace :
    ```
    SW_MACHINE_COVER     1
    KEY_POWER            DOWN
    PowerManagerService: Cancel (coverType: 0)
    ```
- **Temps 2 (après pause narrative)** :
  - Sur l'extrait de log, la ligne `Cancel (coverType: 0)` s'illumine en rouge.
  - Une flèche pointe vers elle, légende : `Code Java framework Samsung — pas le kernel`.
  - Le mot "kernel" est barré dans la légende, remplacé par `services.jar`.

[SCRIPT]
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

[PHOTOS À FOURNIR]
- 1 photo de la tablette dans sa Book Cover, idéalement avec le S Pen visible dans son slot magnétique. Si tu as une vue de l'aimant intégré, c'est le top.
- (Optionnel) Capture de logcat où apparaît le `Cancel (coverType: 0)`.

---

# ACTE 5 — Containers : trois impasses, un déclic

## Slide 24
[SLIDE]
- **Layout** : trois portes alignées horizontalement, fond sombre, éclairage de scène.
- **Chaque porte** porte une étiquette en haut :
  1. `proot`
  2. `chroot réel`
  3. `LXC`
- **Animation séquentielle** : chaque porte s'ouvre tour à tour.
  - Derrière la porte 1 (`proot`) : un mur en briques avec écrit dessus en rouge `ptrace ne laisse pas passer clone(CLONE_NEWUSER)`.
  - Derrière la porte 2 (`chroot réel`) : un autre mur avec `remount /, MS_REC|MS_PRIVATE — invalid argument`.
  - Derrière la porte 3 (`LXC`) : un troisième mur avec `Required key not available — ENOKEY`.
- À la fin, les trois portes restent ouvertes côte à côte, les trois murs visibles.

[SCRIPT]
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

[PHOTOS À FOURNIR]
- Aucune photo strictement nécessaire — tout est animation/CSS.

---

## Slide 25
[SLIDE]
- **Layout** : deux schémas d'architecture côte à côte.
- **Côté gauche, barré en rouge** : empilement vertical
  ```
  Android
    └─ Magisk root
        └─ Termux
            └─ chroot Ubuntu
                └─ Docker / Podman    ← échoue
  ```
- **Côté droit, en vert, qui apparaît après une animation de "renversement"** :
  ```
  Android
    └─ Magisk root
        └─ Termux (processus root, pas de chroot)
            ├─ Docker / Podman natifs    ← marche
            │     ↓ socket Unix
            │   /data/docker.sock
            └─ Ubuntu chroot (pour le dev — apt, gcc...)
                  ↑ symlinks vers /usr/local/bin/docker
  ```
- **Animation** : la version gauche s'estompe, la droite glisse depuis le bas. Sur la droite, la flèche entre le chroot Ubuntu et Docker se met à pulser — c'est le pont qui connecte les deux mondes.

[SCRIPT]
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

[PHOTOS À FOURNIR]
- (Optionnel) Capture d'écran de la tablette qui run `docker run hello-world` avec succès, depuis le shell Ubuntu chroot.
- (Optionnel) Capture de `docker ps` qui liste un container nginx ou autre avec un statut `Up`.

---

## Slide 26
[SLIDE]
- **Layout** : split-screen identique à la slide 3 (la frustration), mais cette fois côté droit changé.
- **Côté gauche** : la même tablette en usage "normal" — vidéo, dessin, lecture (rappel direct de la slide 3).
- **Côté droit** : la même tablette, mais l'écran montre maintenant un terminal Ubuntu avec `docker ps` qui liste plusieurs containers actifs. À côté de la tablette, un clavier physique en Bluetooth.
- **Animation** : en début de slide, c'est l'image de la slide 3 (côté droit avec le prompt vide qui clignote). Puis le terminal se "remplit" — les commandes apparaissent une à une, les containers se listent. Côté gauche, les usages "normaux" continuent en parallèle, sans s'éteindre. Les deux côtés cohabitent.

[SCRIPT]
On revient au point de départ. Je voulais Linux dans ma tablette, sans renoncer à ce qu'elle savait déjà faire.

Aujourd'hui, sur cette même tablette, je peux faire du dessin avec le stylet, regarder une vidéo, prendre des notes — tout ce qu'Android sait faire. Et en parallèle, je peux ouvrir un shell Ubuntu, lancer un container Docker, faire tourner un serveur web, écrire du code dans un éditeur. Sans débrancher mon laptop. Sans VPN. Sans VNC. Sans latence.

Tout ça, c'est rendu possible par un kernel modifié — quelques flags à activer, dont la version officielle Samsung ne voulait pas — un patch sur un capteur magnétique, et une architecture où Docker tourne comme un processus Android normal au lieu de se battre contre le système.

Au fond, ce qu'il y a à retenir, c'est que sous chaque appareil que vous achetez, il y a une plateforme qu'on a délibérément verrouillée pour vous. Pas par malveillance — pour des questions de sécurité, de garantie, de support. Mais ce verrouillage, c'est de la convention, pas de la fatalité. Si vous prenez le temps de regarder, de lire les sources, de comprendre les mécanismes, vous pouvez faire bouger les choses.

J'ai modifié quelques flags dans un kernel, contourné une protection cryptographique, identifié un capteur qui éteignait l'écran sans raison, et inversé une architecture container. C'est le résultat de tout ça que vous voyez à droite.

Tout ça parce que je voulais juste mettre des conteneurs sur une tablette.

Merci.

[PHOTOS À FOURNIR]
- Photo "héros" de la tablette en usage final : terminal Ubuntu ouvert avec `docker ps` lisible, idéalement sur un bureau ou avec un clavier Bluetooth visible. Si tu peux la prendre dans des conditions un peu cinématographiques (lumière travaillée, profondeur de champ), c'est l'image qui clôt la présentation et reste dans la tête du jury.

---

[README](../../../README.md) · [Histoire du projet](../../histoire-du-projet.md) · [Dossier de recherche](../README.md) · [Récit complet](../recit-complet.md) · [Journal de bord](../journal.md) · [Slides expliquées](slides.md) · **Script** · [Présentation (HTML)](warranty-void.html)
