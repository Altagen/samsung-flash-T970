# Récit du projet — version longue

[README](../../README.md) · [Histoire du projet](../histoire-du-projet.md) · [Dossier de recherche](README.md) · **Récit complet** · [Journal de bord](journal.md) · [Slides expliquées](presentation/slides.md) · [Script](presentation/script.md) · [Présentation (HTML)](presentation/warranty-void.html)

*Titre d'origine : « Script de présentation — Faire tourner des containers Linux sur une tablette Samsung »*

[← Dossier de recherche](README.md) · [Histoire du projet (version courte)](../histoire-du-projet.md) · [Journal de bord](journal.md)

Le récit complet du projet, **acte par acte**, écrit fin avril 2026 juste après
la fin des travaux, comme base de la présentation « Warranty Void ». Il raconte
de façon continue ce que le [journal de bord](journal.md) consigne au jour le
jour, et ce que l'[histoire du projet](../histoire-du-projet.md) résume.

Le texte est publié **tel qu'il a été écrit**. Quatre passages, contredits par
des vérifications ultérieures, sont signalés par un encadré *Erratum* et
corrigés ci-dessous.

## Errata

| # | Passage | Ce qui est vrai |
|---|---|---|
| R1 | *Contexte* : « mes sources sont les sources kernel open-source publiées par Samsung » ; options « que Samsung a laissées désactivées : User Namespaces, cgroups v2, OverlayFS, … » | L'arbre utilisé est celui de **LineageOS**, [`android_kernel_samsung_sm8250`](https://github.com/LineageOS/android_kernel_samsung_sm8250) au commit `4910fe83f` (kernel Samsung + mises à jour CIP 4.19.325). Dans sa configuration par défaut, OverlayFS, VETH, BRIDGE et NAT sont **déjà activés** ; la `.config` a ajouté surtout les namespaces user/PID/réseau, le cgroup `pids`, IPVS et les files POSIX. Les cgroups v2 ne servent finalement pas : Android réserve les contrôleurs à cgroup v1, les conteneurs tournent avec `cgroups = "disabled"` |
| R2 | *L'impasse TWRP* : « TWRP abandonné » | TWRP fonctionne si l'on démarre **directement** dessus depuis le Download Mode, avant que la recovery Samsung ne soit restaurée. C'est ainsi qu'a été installé Magisk le 13 avril, ce qui a permis de résoudre l'écran noir (acte 5) |
| R3 | *La vraie cause : le capteur hall* : « Résolution : workaround côté paramètres Android » | La version finale du patch modifie `hall_ic_wacom.c` pour que le capteur signale **toujours** « cover ouverte ». Aucun réglage Android n'est nécessaire |
| R4 | *Kernel v22* : « le patch `xt_qtaguid` (obligatoire sur kernel 4.19 …) » | Ce fichier n'existe pas dans cet arbre Android 13 : **aucun patch `xt_qtaguid` n'a été appliqué ni nécessaire** |

---

## Contexte du projet

> **Erratum R1** : un point de ce passage a été corrigé depuis, voir les [errata](#errata) en tête du récit.

Le point de départ, c'est une Samsung Galaxy Tab S7+ — modèle SM-T970, SoC Snapdragon 865, sous Android 13 avec OneUI 5.1. L'objectif : transformer cette tablette en poste de travail mobile capable de faire tourner des containers Linux (Docker, Podman), tout en conservant Android parfaitement fonctionnel — écran tactile, stylet Wacom, 120Hz, Wi-Fi, Bluetooth, tout.

Pour y arriver, il faut recompiler le kernel Linux de la tablette en activant des options que Samsung a laissées désactivées : les User Namespaces, les cgroups v2, OverlayFS, et tout l'écosystème réseau (veth, bridge, netfilter, NAT). Ce sont les briques de base qui permettent à un runtime de containers de fonctionner.

Le kernel Samsung est basé sur Linux 4.19, fortement patché par Qualcomm et Samsung. Mes sources sont les sources kernel open-source publiées par Samsung pour ce modèle. Tout le build se fait dans un container Podman sur mon PC (Ubuntu 22.04, clang-12, cross-compilation aarch64).

---

## Acte 1 — Le déverrouillage et les premiers flashs (v1–v6)

### Déverrouiller le bootloader

Avant de pouvoir flasher quoi que ce soit, j'ai dû déverrouiller le bootloader OEM de la tablette. La procédure officielle Samsung est mal documentée : il faut maintenir Volume Haut sur le *premier* écran d'avertissement du Download Mode, pas le deuxième. Ce détail m'a coûté du temps. Le déverrouillage déclenche un Knox WARRANTY_VOID irréversible et un factory reset complet.

### L'impasse TWRP

> **Erratum R2** : un point de ce passage a été corrigé depuis, voir les [errata](#errata) en tête du récit.

Ma première idée était classique : flasher TWRP (une recovery custom) pour avoir un environnement de travail confortable. J'ai découvert que Samsung, depuis Android 12, réécrit automatiquement la partition recovery à chaque boot normal. TWRP disparaît au premier redémarrage. Cette protection n'a pas de contournement fiable sans root préexistant — exactement ce qu'on essaie d'obtenir. TWRP abandonné.

Par ailleurs, `heimdall dump` — la commande qui permet théoriquement de lire les partitions depuis le Download Mode — n'existe tout simplement plus. La fonctionnalité a été retirée en 2013 car le firmware Samsung en Download Mode n'a jamais supporté la lecture de partitions.

### Le pivot : patcher boot.img directement

Au lieu de passer par une recovery, j'ai opté pour le patching direct du boot.img. Le firmware stock Samsung est téléchargeable depuis SAMFW.COM. Le boot.img contient le kernel compressé, un ramdisk (avec le binaire init et le fichier fstab.qcom), et une section DTB (Device Tree Blob). Le principe : je remplace le kernel par le mien, je garde tout le reste, je reflashe via heimdall.

### Les premiers flashs : comprendre pourquoi ça ne boot pas

**v1/v2** — Mon kernel compilé, ramdisk stock, DTB stock. Résultat : la tablette boot sur l'écran de recovery Samsung avec "Can't load Android system". Sans le flag `androidboot.force_normal_boot=1` dans la command line du kernel, Android 12+ entre systématiquement en mode recovery. C'est normal — l'ABL (Android Boot Loader) de Qualcomm ajoute ce flag dynamiquement lors d'un boot normal, mais moi je l'avais omis de ma command line hardcodée.

**v3** — J'ajoute `force_normal_boot=1`. Résultat : bootloop immédiat, plus rapide qu'avant. Init tente de monter les partitions système, n'y arrive pas, appelle `reboot()`.

**v4** — J'ajoute `panic=30` pour avoir 30 secondes de délai avant le reboot en cas de kernel panic, espérant voir un message d'erreur à l'écran. Samsung a un mécanisme `sec_debug` qui force le reboot immédiat, contournant le timeout. Rien de visible.

Mais c'est là que j'ai découvert **pstore** (ramoops) : une zone mémoire qui persiste à travers les reboots. En rebootant sur le kernel stock, je peux lire les logs du crash précédent dans `/sys/fs/pstore/console-ramoops-0`. Première vraie information :

```
init: [libfs_mgr]ReadFstabFromDt(): failed to read fstab from dt
init: [libfs_mgr]ReadDefaultFstab(): failed to find device default fstab
init: execv("/system/bin/init") failed: No such file or directory
Kernel panic - not syncing: Attempted to kill init!
```

Init ne trouve pas le fstab, ne monte pas `/system`, le second stage init n'existe pas, kernel panic.

### La piste des DTBs (v5–v6)

J'ai constaté que mon `Image.gz-dtb` faisait exactement la même taille que `Image.gz` seul : aucun DTB n'était appendé au kernel. La raison : dans le Makefile DTS des sources Samsung, le sous-répertoire `vendor` (qui contient les DTBs Qualcomm kona) était commenté. Et même une fois décommenté, les fichiers `kona.dtb`, `kona-v2.dtb`, `kona-v2.1.dtb` n'étaient pas listés dans les targets de compilation.

**v5** — Après avoir activé la compilation des DTBs et les avoir concaténés au kernel, le pstore révèle un progrès majeur : `Hardware name: Samsung GTS7XL PROJECT - PV Rev0.4 (board-id,6)`. L'ABL a trouvé mes DTBs, sélectionné le bon, et appliqué le DTBO Samsung depuis la partition dtbo de la tablette. L'identification du matériel fonctionne. Mais le fstab échoue toujours.

**v6** — Tentative d'un nœud `fstab_custom` dans mes DTBs pour contourner le DTBO Samsung qui désactive le fstab standard. L'init Android ne cherche que le nœud nommé exactement `fstab` sous `/proc/device-tree/firmware/android/`. Mon `fstab_custom` est silencieusement ignoré.

C'est aussi à ce moment que j'ai découvert un point technique important : mes DTBs compilés n'avaient pas de section `__symbols__` (il aurait fallu compiler avec `dtc -@`). Sans `__symbols__`, le mécanisme d'overlay DTBO ne peut pas appliquer les fixups — les 864 fixups Samsung échouent tous silencieusement. Le DTBO Samsung qui fait `android_q_fstab { status = "disabled" }` ne peut pas cibler mon nœud fstab, car il ne trouve pas le label `android_q_fstab` dans ma table de symboles.

---

## Acte 2 — La vraie cause du bootloop (v7–v15)

### Les DTBs patchés : progrès mesuré (v7–v10)

**v7/v8** — J'ai réécrit le contenu du nœud fstab dans mes trois DTBs avec des entrées complètes (system, vendor, product, odm, metadata) et le flag `first_stage_mount`. Cette fois, le timing du crash change : au lieu d'un crash immédiat, init met **10 secondes** avant de mourir. Ce délai est significatif — il prouve qu'init lit mon fstab et *tente* de monter les partitions. Le montage échoue après un timeout.

### La révélation : `force_normal_boot` est le problème (v11)

**v11** — Avec `loglevel=5`, les logs deviennent enfin assez verbeux pour voir ce qui se passe pendant ces 10 secondes. Et là, la prise de conscience :

```
init: Switching root to '/first_stage_ramdisk'
```

`force_normal_boot=1` dans la command line hardcodée du boot.img déclenche un `SwitchRoot` dans l'init Samsung. Ce SwitchRoot crée un tmpfs vide, y déplace `/dev`, `/proc`, `/sys`, fait un chroot dedans — et le ramdisk original avec son `/fstab.qcom` devient inaccessible. Init cherche le fstab dans le tmpfs vide. Il ne le trouve évidemment pas.

**C'était la cause depuis le début, depuis v3.** Toutes les manipulations de DTBs (v5 à v13) étaient une fausse piste. Le fstab DT aurait pu fonctionner si `ReadFstabFromDt()` réussissait, mais le problème principal était en amont.

Ce qui m'a induit en erreur : la documentation AOSP dit qu'init a besoin de `force_normal_boot=1` pour distinguer un boot normal d'un boot recovery. C'est vrai — mais l'ABL Qualcomm l'ajoute *dynamiquement* au runtime, sans qu'il apparaisse dans la command line du boot.img stock. En le mettant dans ma command line hardcodée, je doublonnais le flag, et l'init Samsung traitait ce doublon en déclenchant le SwitchRoot prématurément.

### Le premier boot complet (v15)

La solution est d'une simplicité brutale : retirer `force_normal_boot=1` de ma command line. Utiliser exactement la command line stock, sans aucun ajout.

Résultat v15 :

```
[3.35s]  init: __mount(metadata): Success
[3.37s]  init: Built verity table for system/vendor/product/odm
[3.39s]  init: dm-0 (system), dm-1 (vendor), dm-2 (product), dm-3 (odm) créés
[5.16s]  init: Switching root to '/system'
[5.16s]  init: init second stage started!
```

**First stage mount complet. C'est la première fois que le kernel CIP monte les partitions Android.**

---

## Acte 3 — Le chiffrement Samsung et l'écran noir (v15–v21)

### ROT mismatch : les clés refusent de parler (v15–v17)

Le boot ne s'arrête pas là. Après le first stage mount, vold (le daemon de volumes Android) tente de configurer le chiffrement de `/data`. Samsung implémente une couche propriétaire ODE (On-Device Encryption) qui utilise le hardware ICE (Inline Crypto Engine) pour le chiffrement FBE (File-Based Encryption).

Symptôme : 4 fichiers vides `enablefilecrypto_failed` apparaissent dans `/data/log/`. La recovery Samsung s'affiche avec "Retry / Factory Reset".

J'ai d'abord pensé que le problème venait de l'interface ICE elle-même — notre kernel CIP a l'infrastructure ICE upstream Qualcomm, mais Samsung a modifié l'interface QSEE (TrustZone). J'ai passé deux versions (v16, v17) à modifier le fstab pour changer le mode de chiffrement (`ice` → `aes-256-xts` → suppression totale). Aucun changement.

L'analyse du fichier `prev_dump.log` (dumpstate du boot précédent) a révélé la vraie cause :

```
convertKeyParametersToLegacy : KM_TAG_SAMSUNG_ROT_REQUIRED = 10
begin : result = -33
KeyStorage: checkRotStr current rot value : 07000200000000000000000000000000
KeyStorage: checkRotStr saved rot value   : 06000200000000000000000000000000
```

Samsung lie les clés FBE à la **ROT** (Root of Trust) du bootloader. La ROT est calculée à partir de l'état de verrouillage du bootloader et du compteur de déverrouillage. Les clés ont été créées avec ROT=`06` (avant déverrouillage OEM). Après déverrouillage, la ROT est `07`. Samsung Keymaster (dans TrustZone) refuse catégoriquement de déchiffrer une clé liée à un ROT différent.

Le fstab n'avait jamais été la cause.

**La solution : un factory reset unique.** Effacer `/keydata` force vold à générer de nouvelles clés liées au ROT courant (`07`). Après ce reset, tous les boots futurs avec n'importe quelle version du kernel CIP fonctionneront, car le ROT est stable (basé uniquement sur `device_state` + `ulcnt`).

### L'écran noir (v17 post-reset)

Après le factory reset, Android boote. Le device apparaît en MTP sur USB. `enablefilecrypto` réussit. Mais l'écran reste noir.

L'ABL affiche bien ses propres écrans (logo Samsung, popup de déverrouillage bootloader) — il a son propre driver display, indépendant du kernel. Dès que le kernel prend le relais, plus rien.

### Le mur de l'ADB (v18–v21)

Sans écran, impossible d'activer les options développeur et USB debugging via l'interface. Il me faut ADB pour diagnostiquer le problème d'écran, mais ADB est bloqué par l'absence d'écran. C'est un cercle vicieux.

J'ai tenté plusieurs approches pour forcer ADB sans interface :

- **adb_debug.prop** dans le ramdisk (v18) : le mécanisme Android est bien là (`/debug_ramdisk/adb_debug.prop`), `ro.adb.secure=0` est accepté. Mais ADB n'apparaît pas sur USB : le vendor init Samsung écrase `persist.sys.usb.config` avec `mtp` seul, supprimant l'interface ADB.

- **persist.sys.usb.config=mtp,adb** dans adb_debug.prop (v20) : les propriétés `persist.*` injectées en first-stage init sont écrasées par le vendor init Samsung au démarrage.

- **androidboot.usb.config=mtp,adb** dans la command line kernel (v21) : Samsung ne consomme pas ce paramètre.

- **CONFIG_FB_SIMPLE** (v19) : ce flag kernel réutilise le framebuffer initialisé par l'ABL. Résultat spectaculaire mais fugace — l'UI Android apparaît pendant 0,5 seconde avec le message "There is an internal problem with your device", puis écran noir. Confirmation que le kernel CIP lui-même gère le display, mais que quelque chose crashe côté userspace Android.

En inspectant l'USB avec `lsusb -v`, j'ai découvert que Samsung expose aussi un port CDC ACM (`/dev/ttyACM0`), un port série virtuel. Testé : aucune sortie utile, probablement un port AT commands propriétaire Samsung.

---

## Acte 4 — La bataille du recovery (v1–v29)

### Le problème SELinux

Puisqu'ADB est inaccessible depuis le boot Android normal, je me suis tourné vers le recovery Samsung. L'idée : patcher le ramdisk de la recovery pour avoir un shell ADB opérationnel, depuis lequel je pourrais lire les logs du boot Android.

**recovery_v1** — Modification de `default.prop` dans le ramdisk : `ro.adb.secure=0`, `ro.debuggable=1`, `persist.sys.usb.config=mtp,adb`, plus injection de ma clé publique ADB. Résultat : toujours `unauthorized`. Il s'avère qu'Android 11+ utilise `prop.default`, pas `default.prop`. Les deux fichiers coexistent, mais seul `prop.default` est lu activement.

**recovery_v2** — Les deux fichiers patchés. ADB se connecte ! Mais `adb shell` crashe immédiatement :

```
adbd F shell_service.cpp:380] Could not set SELinux context for subprocess
libc: Fatal signal 6 (SIGABRT)
```

Le service adbd est défini avec `--root_seclabel=u:r:su:s0`. Le label SELinux `su` n'existe pas dans la policy du recovery Samsung. `setcon()` échoue, adbd appelle `LOG(FATAL)`, abort, SIGABRT.

### 20+ versions de recovery

Ce qui a suivi, c'est une longue série de tentatives pour contourner SELinux dans le recovery Samsung :

- `androidboot.selinux=permissive` : Samsung l'ignore. Les AVC denials montrent toujours `permissive=0`.
- `selinux=0` : le kernel Samsung compile avec `CONFIG_SECURITY_SELINUX_BOOTPARAM=n`. Le paramètre est purement ignoré.
- Suppression de `--root_seclabel` du service adbd : adbd calcule quand même une transition SELinux et crashe.
- Patch binaire du adbd à l'offset `0x9ec3c` : remplacement de l'instruction ARM64 `tbz w0, #31, 0x9ec98` par `b 0x9ec98` — on saute inconditionnellement, ignorant l'erreur setcon. Le SIGABRT disparaît, mais on tombe sur `exec '/system/bin/sh' failed: Permission denied` — SELinux bloque l'exécution du shell.
- Écriture de `/sys/fs/selinux/enforce 0` dans `early-init` du init.rc : le recovery binary Samsung appelle explicitement `setenforce(1)` *après* `early-init`, annulant ma modification.
- `adb push` vers `/sys/fs/selinux/enforce` : le domaine adbd dans la policy Samsung n'a pas le droit `security_setenforce`. SELinux bloque la tentative de désactiver SELinux.

### La percée : magiskpolicy (recovery_v29)

Après 26 versions de recovery, la solution est venue d'un outil que j'avais sous la main depuis le début : `magiskpolicy`. Au lieu d'essayer de désactiver SELinux globalement, je modifie directement le fichier binaire `sepolicy` dans le ramdisk recovery pour marquer le domaine `adbd` comme permissif.

```bash
magiskpolicy --load sepolicy \
  'permissive adbd' \
  'allow adbd shell_exec file { execute execute_no_trans open read getattr }' \
  --save sepolicy
```

Le fichier `sepolicy` est à la racine du ramdisk (pas dans `system/etc/selinux/`). `magiskpolicy` est un binaire ARM32 que j'exécute sur mon PC x86_64 via `qemu-user`.

Résultat :

```
adb shell uname -r → 4.19.113-27114284  ✓
adb pull /proc/last_kmsg → 21031 lignes, 2MB  ✓
```

ADB shell et `adb pull` fonctionnent. SELinux reste enforcing globalement, mais le domaine adbd est permissif. Recovery_v29 est devenue ma baseline debug stable — plus besoin de faire de l'OCR sur des photos de l'écran de la tablette pour lire les logs.

---

## Acte 5 — L'écran noir résolu (v22)

### Ce que les logs révèlent (et ne révèlent pas)

Avec recovery_v29, j'ai pu extraire les logs kernel complets du boot CIP. Le workflow : booter le kernel CIP, laisser tourner 30 secondes, rebooter en recovery, `adb pull /proc/last_kmsg`.

L'analyse a contredit mon hypothèse initiale. Les logs CIP montraient :

- MDP (Mobile Display Processor) correctement mappé
- IOMMU configuré pour mdp_ns et mdp_s
- Cont_splash enabled
- `dsi_display_cont_splash_config: set samsung splash (1)`
- **Zéro** `NULL attachment`, **zéro** `Atomic Commit failed`

Les erreurs `NULL attachment` que j'avais observées précédemment venaient en fait du kernel *recovery* stock, pas du kernel CIP. Confusion due au fait que `/proc/last_kmsg` contient les logs du boot *précédent*.

Le kernel DRM CIP fonctionnait correctement. L'écran noir venait de l'espace utilisateur Android — HWComposer/SurfaceFlinger qui crashait. Le flash v19 avec `CONFIG_FB_SIMPLE=y` (0,5 seconde d'UI visible) le confirmait déjà.

### La vraie cause : le capteur hall magnétique

> **Erratum R3** : un point de ce passage a été corrigé depuis, voir les [errata](#errata) en tête du récit.

Avec Magisk root et ADB fonctionnel (retour au kernel stock + Magisk), j'ai pu investiguer le problème d'écran noir en live. Et c'est là que j'ai découvert que le problème n'était pas DRM du tout.

En capturant les événements d'entrée (`getevent -l`), j'ai identifié trois capteurs hall magnétiques distincts, dont `hall_wacom` qui réagissait au S Pen et au Book Cover. Le driver `hall_ic_wacom.c` lisait le GPIO au probe : avec le S Pen dans son slot, la valeur est 0 (CLOSE). Android lisait le sysfs `hall_wacom_detect`, voyait "CLOSE", et déclenchait l'extinction de l'écran — le tout avant que `coverType` ne soit établi à -1 (pas de cover).

J'ai patché le driver pour ne plus lire le GPIO au probe, gardant la valeur par défaut OPEN. Mais le problème persistait en utilisation normale (fermer le Book Cover → écran éteint, impossible de rallumer avec le bouton power).

L'analyse logcat a montré la vraie mécanique : `SEP_UNION_CoverManager` dans le framework Samsung intercepte le bouton power quand un cover est détecté (coverType ≠ -1). Pour un cover "Generic" (type 0), aucun mécanisme de réveil alternatif n'est implémenté. Le power key est routé vers `sendPowerKeyToCover` qui ne fait rien. C'est du code framework Java, pas du kernel.

Résolution : workaround côté paramètres Android — désactivation du verrouillage automatique par cover.

### Kernel v22 : l'objectif atteint

> **Erratum R4** : un point de ce passage a été corrigé depuis, voir les [errata](#errata) en tête du récit.

Avec le hall sensor fix, les CONFIGs containers vérifiés (50/50 via le script Docker `check-config.sh`), et le patch `xt_qtaguid` (obligatoire sur kernel 4.19 — sans lui, tout container provoque un kernel panic), j'ai compilé et flashé le kernel CIP v22.

Vérification finale depuis la tablette elle-même :

```bash
adb shell su -c "zcat /proc/config.gz" > config.txt
bash check-config.sh config.txt
```

Tous les namespaces (USER_NS, NET_NS, PID_NS, IPC_NS, UTS_NS), cgroups v2 complet, OverlayFS, Netfilter + NAT + Bridge + IP_VS, BTRFS, SECCOMP, AppArmor, SELinux — tout est là. Android 13 OneUI 5.1 fonctionne correctement. L'écran affiche le 120Hz. Magisk root est actif. ADB est fonctionnel.

La phase kernel est terminée.

---

## Acte 6 — Les containers sur Android : trois impasses avant le succès

### Impasse 1 : Podman en proot (ptrace)

Premier essai naturel : Termux + proot-distro + Ubuntu. Proot fonctionne par interception des appels système via `ptrace`. Le problème : `ptrace` intercepte `clone(CLONE_NEWUSER)` et le bloque. Podman ne peut pas créer de namespaces. Impasse architecturale — proot est conçu pour l'isolation, pas pour la passthrough de privilèges kernel.

### Impasse 2 : Podman en chroot réel

Pivot vers un vrai chroot via Magisk root, avec `unshare -m` pour un mount namespace propre. Podman se lance, tire des images, mais `podman run` échoue systématiquement :

```
ApplyLayer stderr: remount /, flags: 0x44000: invalid argument
```

Le VFS Linux refuse le `remount /` avec les flags `MS_REC | MS_PRIVATE` quand le process est dans un chroot dont le mount racine est partagé avec le namespace parent. C'est une limitation en dur dans le code VFS du kernel — pas une option configurable. Le mainteneur Podman a confirmé dans l'issue GitHub : *"there are some kernel checks that just prevent doing some stuff from such environment"*. Issue fermée sans fix.

### Impasse 3 : LXC en chroot

LXC utilise `pivot_root` au lieu de `remount /` — il devrait échapper à la restriction. Et en effet, ça a marché une fois : un conteneur Debian a démarré, avec réseau (IPv4 + IPv6), systemd brièvement actif.

Puis, à la session suivante, plus rien ne démarrait :

```
ERROR start - Failed to exec "/sbin/init"
Required key not available
```

ENOKEY. Le rootfs des conteneurs LXC vivait sous `/data/data/com.termux/...`, dans la zone FBE CE (credential-encrypted) liée au UID Termux. La clé fscrypt est dans le keyring du process parent, mais pas dans celui de l'enfant LXC après sa séquence de préparation (unshare, pivot_root, drop caps). La première session marchait probablement parce que le keyring était "frais". Comportement non-déterministe, non-reproductible.

### La solution : Docker et Podman natifs, sans chroot

La clé est venue d'un article de blog d'un développeur japonais qui avait fait tourner Docker sur un Sony Xperia avec kernel custom. Son approche : pas de chroot pour le daemon. Docker tourne directement dans Termux en Magisk root, avec ses données sur `/data/docker` — une zone DE (Device Encrypted), hors du FBE de Termux.

**Docker** — Binaires statiques officiels aarch64. Les obstacles Android-spécifiques :
- `/run` en lecture seule → bind-mounts depuis `/data/docker/run-*`
- `/dev/shm` absent → `mount -t tmpfs`
- Pas de `/etc/resolv.conf` → création manuelle
- Pas de CA bundle → copie depuis le PC hôte
- Chemins hardcodés dans containerd et dockerd qui ignorent la configuration → bind-mounts supplémentaires

`docker run --rm --net=host hello-world` — succès.

**Podman** — Binaires statiques depuis `mgoltzsche/podman-static`. Mêmes catégories d'obstacles, plus :
- Pas de `/etc/passwd` → `getpwuid(0)` échoue → `export HOME=/data/podman`
- cgroup v2 unifié vide (Android monte les contrôleurs en v1 sous `/dev/*` pour son propre usage) → `cgroups = "disabled"` dans la config
- Vérification de boot ID → les `/run/*` doivent être tmpfs, pas persistants

`podman run --rm --net=host hello-world` — succès.

### Persistance au reboot

Android partition system est dm-verity + ro. Tout fichier écrit via `mount -o rw,remount /` est en mémoire uniquement — perdu au reboot. J'ai créé un script `prepare-rootfs-overrides.sh` qui reconstruit les fichiers nécessaires (`/etc/resolv.conf`, CA bundle, configs containers) depuis `/data/` à chaque boot, déclenché par Magisk `service.d`.

Docker-compose et `podman compose` fonctionnent tous les deux. Validation multi-reboot : deux serveurs web (un Docker, un Podman) reviennent up automatiquement après chaque reboot.

---

## Acte 7 — L'automatisation complète : du stock au desktop (18-19 avril 2026)

### Le script maître

L'objectif final : partant d'une tablette avec le kernel custom et Magisk, une seule commande sur le PC installe tout — Termux, Ubuntu chroot, Docker, Podman, bureau graphique XFCE.

L'architecture finale :

```
PC (Linux)
└─ ADB USB
    └─ Android 13 (kernel CIP 4.19 custom)
        └─ Magisk su
            └─ Termux (bootstrapped automatiquement)
                ├─ termux-x11 :0 (serveur X11)
                ├─ Docker/Podman natifs (/data/docker, /data/podman)
                └─ unshare -m → chroot /data/ubuntu
                    ├─ socat (bridge socket X11)
                    ├─ dbus-daemon
                    └─ startxfce4 (DISPLAY=:0)
```

### Automatiser Termux depuis le PC

Le défi : installer des packages dans Termux sans jamais toucher la tablette. L'`apt` de Termux refuse de tourner en root (`getuid()` check). Android restreint l'accès réseau par groupes UID.

Solution : `su -G 3003 -G 9997 <TUID> -c 'apt ...'`
- `-G 3003` : groupe inet (accès réseau)
- `-G 9997` : groupe everybody (résolution DNS)
- `<TUID>` : UID de Termux, obtenu via `stat -c %u /data/data/com.termux`

Cette commande contourne à la fois le blocage root de apt et la restriction réseau Android.

### Ubuntu chroot automatisé

Installation d'un chroot Ubuntu 24.04 minimal depuis le PC :
- Download du rootfs Ubuntu base aarch64
- Extraction et configuration du chroot (resolv.conf, apt sources, locale)
- Script `enter-ubuntu.sh` qui prépare l'environnement (unshare, mounts, bind `/data`)

Point technique notable : `chattr +i resolv.conf`. Ubuntu-base crée `/etc/resolv.conf` comme symlink vers systemd-resolved, qui n'existe pas en chroot. Le package `software-properties-common` tire systemd qui recrée le symlink. La solution : écrire un resolv.conf statique et le marquer immutable avec `chattr +i`. Conséquence : il faut `chattr -i` avant toute réinstallation ou désinstallation, sinon `rm -rf` et `tar xzf` échouent silencieusement.

### Le bureau graphique XFCE

Termux:X11 fournit un serveur X11 sur Android. Le chroot Ubuntu se connecte au serveur via un bridge socat entre un socket file-based (visible dans le chroot) et le socket abstract de Termux:X11 (invisible depuis le chroot) :

```bash
socat UNIX-LISTEN:/tmp/.X11-unix/X0,fork \
  ABSTRACT-CONNECT:/data/data/com.termux/files/usr/tmp/.X11-unix/X0
```

Configuration DPI pour le SM-T970 (2800×1752, 12.4") : `GDK_SCALE=2`, `Xft.dpi=192`, panel XFCE 48px, icônes 64px.

Pour les applications qui refusent de tourner en root (Firefox, Chrome, VS Code), j'ai compilé une bibliothèque `fakeuid.so` de 3 lignes de C qui override `getuid()` et `geteuid()` pour retourner 1000, utilisée via `LD_PRELOAD`.

### Pourquoi pas Cinnamon (ni GNOME) ?

J'ai investigué Cinnamon comme alternative à XFCE — son interface est plus moderne. Six tentatives exhaustives :

| Tentative | Résultat |
|---|---|
| `cinnamon-session` standard | Erreur "Unsupported session type" |
| + `XDG_SESSION_TYPE=x11` | WM démarre, écran noir |
| + `LIBGL_ALWAYS_SOFTWARE=1` | GL fonctionne (llvmpipe Mesa), écran noir |
| `cinnamon-session --session=cinnamon2d` | Écran noir |
| `META_DEBUG_NO_COMPOSITE=1` | Écran noir |
| Test contrôle : `xterm` | S'affiche correctement |

Cinnamon utilise Mutter, un compositeur basé sur Clutter/Cogl qui capture toutes les fenêtres dans un pipeline OpenGL et présente le résultat via `glXSwapBuffers`. Termux:X11 gère correctement les applications X11 traditionnelles, mais ne supporte pas la présentation du buffer composité par Mutter. C'est une incompatibilité architecturale — pas un bug corrigeable côté scripts.

XFCE fonctionne car xfwm4 est un window manager X11 traditionnel : les fenêtres dessinent directement sur leurs surfaces X11, sans pipeline GL.

---

## Bilan

### Ce qui fonctionne

- Kernel CIP 4.19.325 avec tous les CONFIGs containers, Android 13 intact, 120Hz, Magisk root
- Docker + docker-compose : containers persistants, survie au reboot
- Podman + podman compose : même chose, architecture daemonless
- Ubuntu 24.04 chroot avec apt, compilateurs, outils de dev
- Bureau XFCE complet via Termux:X11, DPI calibré pour l'écran de la tablette
- Automatisation complète depuis le PC via ADB — zéro interaction manuelle sur la tablette

### Les chiffres

- 21 versions de boot.img
- 29 versions de recovery
- 56 sections de documentation technique
- ~2500 lignes de retour d'expérience

### Les enseignements techniques majeurs

1. **`force_normal_boot=1` dans le cmdline hardcodé ≠ injection dynamique par l'ABL** — un flag qui semble anodin peut déclencher un code path complètement différent dans l'init Samsung.

2. **Le ROT Samsung est stable après factory reset** — les clés FBE sont liées à l'état du bootloader, pas au hash du boot.img. Un seul factory reset suffit pour toute la durée de vie du projet.

3. **SELinux sur recovery Samsung est un mur** — pas de `selinux=0`, pas de `selinux=permissive`, pas de write enforce. La seule approche qui fonctionne : patcher le binaire sepolicy pour rendre un domaine spécifique permissif.

4. **Android n'est pas POSIX** — tout runtime Linux assume `/run`, `/etc/resolv.conf`, `/dev/shm`, `/etc/passwd`, un rootfs en lecture-écriture, des cgroups montés. Android ne fournit rien de tout ça. Le pattern de contournement est toujours le même : bind-mounts depuis `/data/` + script de reconstruction au boot.

5. **Podman et Docker en chroot Android = impasse architecturale** — VFS refuse `remount /` avec `MS_REC|MS_PRIVATE`, fscrypt ENOKEY après pivot_root. La solution est de ne pas chrooter le daemon.

6. **Les compositeurs GL (Mutter) sont incompatibles avec Termux:X11** — limitation architecturale, pas configurable. Seuls les WM X11 traditionnels fonctionnent.

---

[README](../../README.md) · [Histoire du projet](../histoire-du-projet.md) · [Dossier de recherche](README.md) · **Récit complet** · [Journal de bord](journal.md) · [Slides expliquées](presentation/slides.md) · [Script](presentation/script.md) · [Présentation (HTML)](presentation/warranty-void.html)
