# Journal de recherche — Kernel conteneurs sur Galaxy Tab S7+ (SM-T970)

[README](../../README.md) · [Histoire du projet](../histoire-du-projet.md) · [Dossier de recherche](README.md) · [Récit complet](recit-complet.md) · **Journal de bord** · [Slides expliquées](presentation/slides.md) · [Script](presentation/script.md) · [Présentation (HTML)](presentation/warranty-void.html)

Ce document est le **journal de bord tenu pendant le projet** (avril 2026), au fil
des essais : hypothèses, flashs, logs, impasses et corrections, dans l'ordre où
ils se sont produits. Il est publié **tel qu'il a été écrit**, à quelques
exceptions près :

- les chemins absolus de la machine de travail sont devenus relatifs au projet ;
- le numéro de série de la tablette et une adresse IP locale sont masqués ;
- des encadrés **Erratum** signalent les passages contredits par la suite (liste ci-dessous).

La numérotation des sections est celle d'origine : elle n'est pas toujours
continue (une section 25b, deux sections 34, une section 31 placée après la 34).
Pour une version racontée et synthétique, lire l'[histoire du projet](../histoire-du-projet.md) ;
pour la procédure qui fonctionne, le [guide](../guide/00-before-you-start.md).

## Errata

| # | Passage | Ce qui est vrai |
|---|---|---|
| E1 | §1 : objectif « Podman rootless », « cgroups v2 » | Le résultat final est **rootful** (pas de subuid/subgid sur Android), et les conteneurs tournent avec `cgroups = "disabled"` : Android réserve tous les contrôleurs à cgroup v1 (§54) |
| E2 | §3 : « kernel Samsung officiel open-source », configuration `gts7xlwifi_defconfig` | L'arbre utilisé est celui de **LineageOS**, [`android_kernel_samsung_sm8250`](https://github.com/LineageOS/android_kernel_samsung_sm8250) au commit `4910fe83f` (kernel Samsung + mises à jour CIP 4.19.325). La configuration par défaut y est assemblée à partir de `kona_defconfig` et des fragments Samsung ; la configuration finale est [`kernel/config/gts7xlwifi_containers.config`](../../kernel/config/gts7xlwifi_containers.config) |
| E3 | §4 : écran `OEM LOCK : ON (U1)` | La photo prise ce soir-là montre `OEM LOCK : ON (U)` ([étape 1 du guide](../guide/01-unlock-bootloader.md)) |
| E4 | §5 : « TWRP a été définitivement abandonné » | TWRP fonctionne si l'on démarre **directement** dessus depuis le Download Mode, avant que la recovery Samsung ne soit restaurée. C'est la méthode retenue pour installer Magisk (§43-44) |
| E5 | §42 : patch `xt_qtaguid` « OBLIGATOIRE sur kernel 4.19 » ; aussi évoqué dans la présentation | Le fichier n'existe pas dans cet arbre Android 13 : **aucun patch `xt_qtaguid` n'a été nécessaire**. OverlayFS, VETH, BRIDGE, MEMCG y sont déjà activés par défaut ; la `.config` a surtout ajouté les namespaces user/PID/réseau, le cgroup `pids`, IPVS, les files POSIX |
| E6 | §48 : « Workaround Android-level retenu » (verrouillage automatique désactivé) | La version finale du patch modifie `hall_ic_wacom.c` pour que le capteur signale **toujours** « cover ouverte » ([le kernel](../how-it-works.md#the-kernel)) |

## Sommaire

- [1. Contexte et objectif](#1-contexte-et-objectif)
- [2. Matériel et logiciels installés](#2-matériel-et-logiciels-installés)
- [3. Sources du kernel](#3-sources-du-kernel)
- [4. Premier obstacle majeur : le déverrouillage OEM](#4-premier-obstacle-majeur--le-déverrouillage-oem)
- [5. Approche TWRP — abandonnée](#5-approche-twrp--abandonnée)
- [6. Pivot stratégique : patching direct de boot.img](#6-pivot-stratégique--patching-direct-de-bootimg)
- [7. Premier flash (v1/v2) — kernel sans DTBs](#7-premier-flash-v1v2--kernel-sans-dtbs)
- [8. Flash v3 — ajout de `force_normal_boot=1`](#8-flash-v3--ajout-de-forcenormalboot1)
- [9. Flash v4 — ajout de `panic=30`](#9-flash-v4--ajout-de-panic30)
- [10. Investigation DTB — hypothèse initiale (fausse)](#10-investigation-dtb--hypothèse-initiale-fausse)
- [11. Flash v5 — DTBs appendés, même crash](#11-flash-v5--dtbs-appendés-même-crash)
- [12. Investigation approfondie : pourquoi le fstab échoue ?](#12-investigation-approfondie--pourquoi-le-fstab-échoue-)
- [13. Flash v6 — fstab_custom (mauvaise approche, mais révélatrice)](#13-flash-v6--fstabcustom-mauvaise-approche-mais-révélatrice)
- [14. Flashs v7 → v10 — investigation du crash à t=13.6s](#14-flashs-v7--v10--investigation-du-crash-à-t136s)
- [15. Informations architecturales clés découvertes](#15-informations-architecturales-clés-découvertes)
- [16. Chronologie des flashs](#16-chronologie-des-flashs)
- [17. Outils de debug utilisés](#17-outils-de-debug-utilisés)
- [18. Ce qu'on sait maintenant sur le kernel stock Samsung](#18-ce-quon-sait-maintenant-sur-le-kernel-stock-samsung)
- [19. Questions ouvertes](#19-questions-ouvertes)
- [20. Commandes de flash de référence](#20-commandes-de-flash-de-référence)
- [21. Flash v11 — loglevel=5, découverte `force_normal_boot` vs SwitchRoot](#21-flash-v11--loglevel5-découverte-forcenormalboot-vs-switchroot)
- [22. Flash v12 → v13 — DTBs patchés dans la section --dtb](#22-flash-v12--v13--dtbs-patchés-dans-la-section---dtb)
- [23. Flash v14 — ajout de fstab.default dans le ramdisk (échec partiel)](#23-flash-v14--ajout-de-fstabdefault-dans-le-ramdisk-échec-partiel)
- [24. Flash v15 — SUPPRESSION de force_normal_boot=1 : PREMIER SUCCÈS](#24-flash-v15--suppression-de-forcenormalboot1--premier-succès)
- [25. Flash v16 — contournement ICE : software FBE + formattable](#25-flash-v16--contournement-ice--software-fbe--formattable)
- [25b. Flash v17 — suppression totale de fileencryption](#25b-flash-v17--suppression-totale-de-fileencryption)
- [26. Chronologie complète des flashs (mise à jour)](#26-chronologie-complète-des-flashs-mise-à-jour)
- [27. Architecture du problème ICE — analyse initiale (hypothèse invalide)](#27-architecture-du-problème-ice--analyse-initiale-hypothèse-invalide)
- [28. Cause racine réelle : ROT (Root of Trust) mismatch Samsung Keymaster](#28-cause-racine-réelle--rot-root-of-trust-mismatch-samsung-keymaster)
- [29. Solution : factory reset unique](#29-solution--factory-reset-unique)
- [30. Flash v18 — déblocage ADB via adb_debug.prop](#30-flash-v18--déblocage-adb-via-adbdebugprop)
- [34. Tentatives déblocage ADB — v19 à v21 et recovery](#34-tentatives-déblocage-adb--v19-à-v21-et-recovery)
- [31. Chronologie complète des flashs (mise à jour finale)](#31-chronologie-complète-des-flashs-mise-à-jour-finale)
- [32. État des questions ouvertes](#32-état-des-questions-ouvertes)
- [33. Prochaines étapes](#33-prochaines-étapes)
- [34. Recovery ADB — Tentatives v7 à v26 (résumé)](#34-recovery-adb--tentatives-v7-à-v26-résumé)
- [35. Recovery_v29 — Déblocage ADB via magiskpolicy (SUCCÈS)](#35-recoveryv29--déblocage-adb-via-magiskpolicy-succès)
- [36. Analyse last_kmsg depuis recovery_v29](#36-analyse-lastkmsg-depuis-recoveryv29)
- [37. ADB sur le boot Android normal — analyse](#37-adb-sur-le-boot-android-normal--analyse)
- [38. Corrections et précisions importantes](#38-corrections-et-précisions-importantes)
- [39. Chronologie complète des flashs — mise à jour finale](#39-chronologie-complète-des-flashs--mise-à-jour-finale)
- [40. Tentatives d'ADB via boot Android — v22 à v27 (12 avril 2026)](#40-tentatives-dadb-via-boot-android--v22-à-v27-12-avril-2026)
- [41. Découvertes techniques sur l'architecture Android init (12 avril 2026)](#41-découvertes-techniques-sur-larchitecture-android-init-12-avril-2026)
- [42. Recherche communautaire — Docker/Containers sur Android (12 avril 2026)](#42-recherche-communautaire--dockercontainers-sur-android-12-avril-2026)
- [43. Pivot stratégique — Retour à l'état 0 + TWRP (12 avril 2026)](#43-pivot-stratégique--retour-à-létat-0--twrp-12-avril-2026)
- [44. Installation TWRP + Magisk (13 avril 2026)](#44-installation-twrp--magisk-13-avril-2026)
- [45. Reprise du kernel CIP avec root disponible (13 avril 2026)](#45-reprise-du-kernel-cip-avec-root-disponible-13-avril-2026)
- [46. Diagnostic black screen — cause identifiée : hall_ic_wacom (13 avril 2026)](#46-diagnostic-black-screen--cause-identifiée--hallicwacom-13-avril-2026)
- [47. Rebuild kernel CIP v22 + flash (13 avril 2026)](#47-rebuild-kernel-cip-v22--flash-13-avril-2026)
- [48. Diagnostic cover — vraie cause identifiée (14 avril 2026)](#48-diagnostic-cover--vraie-cause-identifiée-14-avril-2026)
- [49. Validation du kernel qui tourne sur la tablette (14 avril 2026)](#49-validation-du-kernel-qui-tourne-sur-la-tablette-14-avril-2026)
- [50. Phase userland : Podman sur Android — limites rencontrées et pivot vers LXC](#50-phase-userland--podman-sur-android--limites-rencontrées-et-pivot-vers-lxc)
- [51. Phase userland (suite) : échec LXC en chroot FBE — pivot vers runtime natif Termux](#51-phase-userland-suite--échec-lxc-en-chroot-fbe--pivot-vers-runtime-natif-termux)
- [52. Docker fonctionnel — bout en bout (15 avril 2026)](#52-docker-fonctionnel--bout-en-bout-15-avril-2026)
- [53. Podman fonctionnel — wrap-up (15 avril 2026)](#53-podman-fonctionnel--wrap-up-15-avril-2026)
- [54. Persistance Podman au reboot — 5 corrections Android-spécifiques (15 avril 2026)](#54-persistance-podman-au-reboot--5-corrections-android-spécifiques-15-avril-2026)
- [55. Compose + Shell unifié (17 avril 2026)](#55-compose--shell-unifié-17-avril-2026)
- [56. Ubuntu chroot + X11 desktop XFCE — setup automatisé (18-19 avril 2026)](#56-ubuntu-chroot--x11-desktop-xfce--setup-automatisé-18-19-avril-2026)
- [57. sshd dans le chroot + client ConnectBot Android (23 avril 2026)](#57-sshd-dans-le-chroot--client-connectbot-android-23-avril-2026)

---

---

## 1. Contexte et objectif

> **Erratum E1** : ce passage a été corrigé depuis, voir les [errata](#errata) en tête du journal.

L'objectif du projet est de flasher un **kernel Linux custom** sur une Samsung Galaxy Tab S7+ WiFi (SM-T970, SoC Snapdragon 865 / SM8250 "kona", Android 13 / One UI 5.1.1) de manière à :

- Conserver Android **entièrement fonctionnel** (stylet Wacom W9021, 120Hz, WiFi, Bluetooth, caméra, batterie, USB-C)
- Ajouter les capacités Linux container : **Podman rootless**, proot, réseau container
- Toute l'infrastructure de build doit tourner dans un **container persistant** (`sm8250-builder`)

La tablette sert de poste de travail mobile. L'idée est de compiler un kernel avec les namespaces, cgroups v2 et overlayfs activés, tout en conservant le reste de Samsung.

---

## 2. Matériel et logiciels installés

### Matériel
- Samsung Galaxy Tab S7+ WiFi — SM-T970
- SoC : Qualcomm Snapdragon 865 (SM8250, architecture kona)
- Firmware de départ : T970XXS7DXH1 (Android 13 / One UI 5.1.1)
- Bootloader : déverrouillé en cours de projet (voir section 4)

### Outils installés sur le poste (CachyOS)
- `adb` / `fastboot` (Android SDK platform-tools)
- `heimdall` v2.2.2 (flasher Samsung via Download Mode)
- `android-tools` (contient `mkbootimg`, `unpackbootimg`)
- `dtc` 1.7.2 (Device Tree Compiler, installé via pacman)
- `podman` (pour le container de build)

### Container de build `sm8250-builder`
Basé sur Ubuntu 22.04 avec clang-12, LLVM-12, binutils-aarch64-linux-gnu. Le container est **persistant** (pas `--rm`) pour conserver l'état du build entre les sessions. Les sources du kernel sont montées en lecture seule à `/work/sources`, l'output à `/work/output`.

```dockerfile
FROM ubuntu:22.04
RUN apt-get install -y bc bison build-essential flex clang-12 lld-12 llvm-12 ...
ENV PATH="/usr/lib/llvm-12/bin:${PATH}"
WORKDIR /work
```

---

## 3. Sources du kernel

> **Erratum E2** : ce passage a été corrigé depuis, voir les [errata](#errata) en tête du journal.

Les sources utilisées sont le **kernel Samsung officiel open-source** pour le SM-T970, basé sur Linux 4.19 avec les patches Qualcomm et Samsung.

### Configuration du kernel

La configuration de base `gts7xlwifi_defconfig` a été chargée puis modifiée interactivement avec **`make menuconfig`** (interface ncurses dans le container) pour activer les options nécessaires aux containers Linux :

- `CONFIG_USER_NS=y` (User Namespaces — requis pour Podman rootless)
- `CONFIG_CGROUPS=y` + sous-systèmes (memory, cpu, cpuacct, blkio, etc.)
- `CONFIG_OVERLAY_FS=y` (requis pour les layers de containers)
- `CONFIG_NET_NS=y` (réseau container)
- `CONFIG_NAMESPACES=y` (namespaces en général)

Le `.config` résultant est dans `output/.config`. La config a été générée/modifiée dans le container `sm8250-builder` :

```bash
# Charger la defconfig de base
make O=/work/output gts7xlwifi_defconfig

# Modifier interactivement
make O=/work/output menuconfig

# Vérifier une option
grep USER_NS /work/output/.config
```

Structure du projet :
```

├── sources/          ← kernel Samsung (read-only dans le container)
├── output/           ← build artifacts
├── anykernel/        ← AnyKernel3 (abandonné, voir section 5)
└── Containerfile
```

---

## 4. Premier obstacle majeur : le déverrouillage OEM

> **Erratum E3** : ce passage a été corrigé depuis, voir les [errata](#errata) en tête du journal.

### Le problème du Download Mode

Avant de pouvoir flasher quoi que ce soit, il faut déverrouiller le bootloader (OEM Unlock). La tablette avait "Déverrouillage OEM" activé dans les paramètres développeur, mais l'écran Download Mode affichait `OEM LOCK : ON (U1)`.

**Erreur de manipulation** : on maintenait Vol Haut sur le **deuxième** écran (après avoir appuyé une fois pour entrer en Download Mode), alors qu'il faut le maintenir sur le **premier** écran d'avertissement (celui avec le fond jaune/orange). Ce détail ne figure nulle part clairement dans les guides.

**Procédure correcte** :
1. Éteindre la tablette complètement
2. Brancher l'USB
3. Maintenir **Vol Bas + Vol Haut** simultanément
4. Sur le **premier** écran d'avertissement (avant d'appuyer sur Vol Bas pour confirmer) → maintenir **Vol Haut** 7 secondes → l'écran de déverrouillage Samsung s'affiche
5. Un compte Samsung connecté est requis pour la vérification serveur

**Conséquence** : le Knox WARRANTY_VOID bit passe de `0x0` à `0x1` — irréversible. Android effectue une factory reset complète. Plusieurs resets ont été nécessaires car le système se retrouvait dans un état incohérent.

---

## 5. Approche TWRP — abandonnée

> **Erratum E4** : ce passage a été corrigé depuis, voir les [errata](#errata) en tête du journal.

### Tentative initiale

La première idée était de flasher TWRP pour avoir une recovery custom qui permette d'installer un ZIP AnyKernel3. TWRP a été flashé via heimdall sur la partition `RECOVERY`.

```bash
heimdall flash --RECOVERY twrp-gts7xl-3.6.0_11-A12-1a7_ianmacd.img
```

### Samsung Recovery Protection — le mur

**Problème découvert** : Samsung sur Android 12+ implémente une **protection de recovery**. À chaque démarrage normal, le système Android réécrit la partition recovery avec la recovery Samsung originale. TWRP disparaît au premier reboot.

Ce comportement est documenté sur XDA pour tous les appareils Samsung depuis Android 12, et il n'existe aucun contournement fiable sans root préexistant. **TWRP a été définitivement abandonné.**

### Heimdall `dump` — fonctionnalité manquante

Tentative de dump de la partition boot pour analyse : `heimdall dump --BOOT boot.img`. **Résultat** : la commande n'existe pas. Heimdall a **supprimé la commande `dump` en 2013** car le firmware Samsung en Download Mode n'a jamais supporté la lecture de partitions. Les partitions ont été récupérées autrement (ADB depuis Android démarré).

---

## 6. Pivot stratégique : patching direct de boot.img

### Approche adoptée

Au lieu de passer par une recovery custom, on patche directement la `boot.img` :

1. Télécharger le firmware Samsung stock depuis **SAMFW.COM** : `SAMFW.COM_SM-T970_EUX_T970XXS7DXH1_fac.zip` (correspondant exactement au firmware T970XXS7DXH1 d'origine)
2. Extraire la `boot.img` de l'archive firmware (Samsung LZ4) : `lz4 -d boot.img.lz4 boot.img`
3. Extraire les composants avec `unpackbootimg`
4. Remplacer le kernel par notre `Image.gz-dtb` custom
5. Repackager avec `mkbootimg`
6. Flasher directement via heimdall sur la partition `BOOT`

> **Note** : La commande `heimdall dump --BOOT` ne fonctionne pas (voir section 5). La commande `adb pull /dev/block/by-name/boot` est théoriquement possible depuis Android démarré, mais nous avons préféré la source officielle SAMFW.COM pour avoir un stock propre et reproductible. Le ramdisk (`boot.img-ramdisk`) et le DTB section (`boot.img-dtb`) utilisés dans tous nos flashs v1→v7 proviennent de ce même firmware stock.

### Structure du boot.img Samsung (header v2)

```
boot.img (header version 2)
├── kernel      : Image.gz-dtb (kernel compressé + DTBs)
├── ramdisk     : initramfs gzippé (contient /init, /fstab.qcom, ...)
├── dtb         : Device Tree Blob séparé (section spécifique header v2)
└── métadonnées : base, offsets, os_version, page_size, etc.
```

**Point important** : le header v2 a une section DTB dédiée, séparée du kernel. Dans le stock Samsung, cette section contient les 3 DTBs kona de base concaténés (528KB × 3 ≈ 1.5MB).

### Cmdline importante

```
console=null androidboot.hardware=qcom androidboot.memcg=1 
lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 
msm_rtb.filter=0x237 service_locator.enable=1 
androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 
printk.devkmsg=on firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7
```

---

## 7. Premier flash (v1/v2) — kernel sans DTBs

### Ce qu'on a fait

Boot.img patché avec notre `Image.gz` (kernel compilé, 22MB) + ramdisk stock + DTB stock.

**Résultat** : la tablette bootait sur l'**écran de recovery Samsung** avec le message "Can't load Android system". Elle ne bootait pas sur Android.

### Analyse

Sans `androidboot.force_normal_boot=1` dans la cmdline, Android 12+ init entre en mode recovery. C'est le comportement attendu — ABL ajoute normalement ce flag dynamiquement lors d'un boot normal, mais notre cmdline hardcodée ne l'avait pas.

---

## 8. Flash v3 — ajout de `force_normal_boot=1`

### Ce qu'on a fait

Ajout de `androidboot.force_normal_boot=1` à la cmdline. Ce flag indique à init (première étape) de procéder à un boot normal plutôt qu'un boot recovery.

**Résultat** : bootloop **plus rapide** sans jamais atteindre l'écran de recovery. La tablette redémarrait en boucle en quelques secondes.

### Analyse

Avec `force_normal_boot=1`, init essaie de monter les partitions système (first stage mount). Sans fstab valide, il appelle `reboot()` directement — contournant le timeout `panic=`. L'absence de pstore lisible à ce stade rendait le debug difficile.

---

## 9. Flash v4 — ajout de `panic=30`

### Ce qu'on a fait

Ajout de `panic=30` pour avoir 30 secondes avant le reboot sur kernel panic, espérant voir un message.

**Résultat** : toujours un bootloop, mais légèrement plus long. **Aucun écran de panique visible** — Samsung a un mécanisme `sec_debug` qui force le reboot immédiat après panic, contournant le timeout.

### Récupération des logs via pstore

**Découverte clé** : le noyau Samsung implémente **ramoops/pstore** — une zone mémoire persistante à travers les reboots. Les logs du dernier crash sont accessibles depuis Android normal dans `/sys/fs/pstore/console-ramoops-0`.

```bash
# adb pull /sys/fs/pstore/console-ramoops-0 → Permission denied
# Solution de contournement :
adb shell "cat /sys/fs/pstore/console-ramoops-0 > /tmp/pstore.bin"
```

Le fichier est un mélange binaire/texte. On a utilisé `strings` pour extraire les lignes lisibles.

### Logs pstore v4 — première vraie information

Extrait des logs (reconstitution via OCR + strings) :

```
[14.528181] init: init first stage started!(old)
[14.528370] init: Unable to open /lib/modules, skipping module loading.
[14.528388] init: init first stage started!
[14.529632] init: Switching root to '/first_stage_ramdisk'
[14.531016] init: [libfs_mgr]ReadFstabFromDt(): failed to read fstab from dt
[14.532427] init: [libfs_mgr]ReadDefaultFstab(): failed to find device default fstab
[14.532446] init: Failed to fstab for first stage mount
[14.433233] init: First stage mount skipped (missing/incompatible/empty fstab in device tree)
[14.483599] init: execv("/system/bin/init") failed: No such file or directory
[14.483665] Kernel panic - not syncing: Attempted to kill init! exitcode=0x00007f00
```

**Cause racine identifiée** : init ne trouve pas le fstab → ne monte pas `/system` → `execv("/system/bin/init")` échoue → kernel panic.

---

## 10. Investigation DTB — hypothèse initiale (fausse)

### Hypothèse de départ

`Image.gz-dtb` avait exactement la même taille que `Image.gz` (22,165,565 bytes). Aucun DTB n'était appendé. Or, le kernel Samsung stock pèse ~54MB (compressé) — la différence était supposément les DTBs appendés.

**Vérification** :

```bash
find output/arch/arm64/boot/dts -name "*.dtb"
# → Rien. Aucun DTB construit.
```

Le Makefile DTS avait la section `vendor` commentée :

```makefile
# DTS/Makefile (ligne 34-37) — COMMENTÉ :
#vendor := $(dtstree)/vendor
#ifneq "$(wildcard $(vendor)/Makefile)" ""
#        subdir-y += vendor
#endif
```

Sans ce subdir activé, les DTBs Qualcomm (kona.dtb, kona-v2.dtb, kona-v2.1.dtb) ne sont jamais compilés.

---

## 11. Flash v5 — DTBs appendés, même crash

### Ce qu'on a fait

1. Activation du subdir `vendor` dans le Makefile DTS
2. Ajout de `kona.dtb`, `kona-v2.dtb`, `kona-v2.1.dtb` dans `dtb-y` du Makefile vendor/qcom (ils n'y étaient pas — seulement les variantes `kona-mtp.dtb`, `kona-cdp.dtb`, etc.)
3. Build des DTBs dans le container : `make dtbs`
4. Concaténation manuelle : `cat Image.gz kona.dtb kona-v2.dtb kona-v2.1.dtb > Image.gz-dtb`
5. Image.gz-dtb : 23,260,247 bytes (+1,094,832 bytes de DTBs)

**Résultat pstore v5** :

```
Hardware name: Samsung GTS7XL PROJECT - PV Rev0.4 (board-id,6) (DT)
[14.480579] init: [libfs_mgr]ReadFstabFromDt(): failed to read fstab from dt
[14.481974] init: [libfs_mgr]ReadDefaultFstab(): failed to find device default fstab
[14.483599] init: execv("/system/bin/init") failed: No such file or directory
[14.483665] Kernel panic - not syncing: Attempted to kill init! exitcode=0x00007f00
```

### Avancement majeur

**`Hardware name: Samsung GTS7XL PROJECT - PV Rev0.4 (board-id,6)`** — l'ABL a trouvé les DTBs appendés, sélectionné kona-v2.1.dtb (board-id 0 = base SoC), et **appliqué le DTBO Samsung** depuis la partition `dtbo` du device (overlay r06 = PV Rev0.4 = board-id 6).

Les DTBs fonctionnent. Le problème est maintenant ailleurs : le **fstab est vide ou incompatible**.

---

## 12. Investigation approfondie : pourquoi le fstab échoue ?

### Architecture DTB/DTBO Samsung SM8250

L'ABL (Android Boot Loader) Qualcomm suit ce pipeline pour le boot :

```
1. Kernel image → contient les DTBs appendés (kona.dtb, kona-v2.dtb, kona-v2.1.dtb)
   → ABL sélectionne le bon DTB par qcom,msm-id (SoC version)

2. Partition dtbo → contient les overlays Samsung (kona-sec-gts7xlwifi-eur-overlay-r06.dtbo)
   → ABL sélectionne le bon DTBO par qcom,board-id
   → ABL applique l'overlay sur le DTB de base

3. DT combiné → passé au kernel
```

### La section DTBO Samsung source (kona-sec-common.dtsi)

En cherchant dans les sources du kernel :

```
sources/arch/arm64/boot/dts/samsung/common/kona-sec-common.dtsi
```

```dts
&android_q_fstab {
    status = "disabled";
};
```

Samsung **désactive explicitement le DT fstab** dans son overlay. C'est intentionnel : Samsung utilise le fichier `/fstab.qcom` dans le ramdisk plutôt que le DT fstab.

### Le fstab.qcom dans le ramdisk (stock)

Extraction du ramdisk stock :

```bash
mkdir /tmp/ramdisk_extract
gunzip -c boot.img-ramdisk | cpio -idm
```

Contenu : `./fstab.qcom`, `./init`, `./dev`, `./proc`, `./sys` — **pas de répertoire `first_stage_ramdisk`**.

Le `fstab.qcom` est complet et correct :

```
system  /system  ext4  ro  wait,avb=vbmeta,logical,first_stage_mount,...
vendor  /vendor  ext4  ro  wait,avb,logical,first_stage_mount
product /product ext4  ro  wait,avb,logical,first_stage_mount
odm     /odm     ext4  ro  wait,avb,logical,first_stage_mount
/dev/block/.../metadata  /metadata  ext4  ...  wait,first_stage_mount,formattable
```

### Pourquoi ReadDefaultFstab échoue

L'init Samsung (Android 12) suit cette séquence :

```
1. "init first stage started!(old)"  ← log Samsung custom
2. Essai chargement modules (échoue)
3. "init first stage started!"
4. "Switching root to '/first_stage_ramdisk'"
   → crée /first_stage_ramdisk comme tmpfs vide
   → pivot_root vers ce tmpfs vide
5. ReadFstabFromDt() → lit /proc/device-tree/firmware/android/fstab/ → ÉCHOUE
6. ReadDefaultFstab() → cherche /fstab.qcom dans la ROOT ACTUELLE (tmpfs vide) → ÉCHOUE
7. First stage mount skipped
8. execv("/system/bin/init") → ENOENT (system pas monté)
9. Kernel panic
```

Avec le kernel stock, l'init **réussit** — ce qui signifie que quelque chose est différent. Le mystère n'est pas entièrement résolu, mais les investigations ont conduit à une découverte clé (voir section suivante).

---

## 13. Flash v6 — fstab_custom (mauvaise approche, mais révélatrice)

### Hypothèse initiale (incorrecte)

Idée : injecter un nouveau nœud `fstab_custom` avec `compatible = "android,fstab"` dans nos DTBs. Puisque ce nœud n'a pas de label `android_q_fstab`, le DTBO Samsung ne peut pas le cibler.

**Problème identifié après coup** : `ReadFstabFromDt()` dans l'init Android 12 cherche **spécifiquement** le nœud nommé `"fstab"` à l'adresse `/proc/device-tree/firmware/android/fstab/`. Il ne scanne pas tous les enfants de `firmware/android/` pour trouver des nœuds compatibles.

**Confirmation** depuis les strings du binaire init du ramdisk :

```bash
strings /tmp/ramdisk_extract/init | grep "firmware/android\|/fstab"
# → /proc/device-tree/firmware/android/
# → /fstab
# → /fstab/compatible
# → /fstab/status
```

La string `/fstab` (pas `/fstab/`, juste le path relatif) confirme qu'init construit le chemin :
`/proc/device-tree/firmware/android/` + `fstab` = chemin fixe.

Le `fstab_custom` n'est **jamais lu par init**.

### Découverte critique : nos DTBs n'ont pas de `__symbols__`

**Vérification clé** :

```bash
# DTB stock (boot.img-dtb) :
strings /tmp/dtb0.dtb | grep "__symbols__\|android_q_fstab"
# → __symbols__
# → android_q_fstab  ← PRÉSENT avec phandle 0x618

# Nos DTBs compilés :
strings output/arch/arm64/boot/dts/vendor/qcom/kona-v2.1.dtb | grep "__symbols__"
# → (rien)
```

**Implication majeure** :

Le mécanisme DTBO overlay (standard Linux) fonctionne ainsi :
1. Le DTBO a une section `__fixups__` : `android_q_fstab = "/fragment:android_q_fstab:..."` 
2. L'ABL cherche `android_q_fstab` dans la section `__symbols__` du DTB de base
3. S'il ne trouve pas l'entrée → le fixup **échoue silencieusement**
4. `status = "disabled"` n'est **pas appliqué** au nœud fstab

Nos DTBs compilés (sans `-@` dans dtc) n'ont pas de `__symbols__`. **Le DTBO Samsung ne peut donc pas désactiver notre fstab.**

### Conclusion réelle sur l'échec

Le fstab n'est **pas désactivé** dans nos DTBs. Mais il ne fonctionne toujours pas car il ne contient qu'une entrée `vendor` **sans le flag `first_stage_mount`** :

```dts
fstab {
    compatible = "android,fstab";
    vendor {
        compatible = "android,vendor";
        dev = "/dev/block/platform/soc/1d84000.ufshc/by-name/vendor";
        type = "ext4";
        mnt_flags = "ro,barrier=1,discard";
        fsmgr_flags = "wait,slotselect,avb";  ← PAS de first_stage_mount !
        status = "ok";
    };
};
```

Init lit ce fstab, ne trouve **aucune entrée avec `first_stage_mount`**, traite ça comme "empty fstab" → "First stage mount skipped".

---

## 14. Flashs v7 → v10 — investigation du crash à t=13.6s

### v7/v8 — fstab correct, nouveau symptôme

Remplacement du contenu du nœud `fstab` dans les 3 DTBs (kona.dtb, kona-v2.dtb, kona-v2.1.dtb) avec des entrées complètes :

```dts
fstab {
    compatible = "android,fstab";
    system  { dev = "system";  fsmgr_flags = "wait,logical,first_stage_mount"; ... };
    vendor  { dev = "vendor";  fsmgr_flags = "wait,logical,first_stage_mount"; ... };
    product { dev = "product"; fsmgr_flags = "wait,logical,first_stage_mount"; ... };
    odm     { dev = "odm";     fsmgr_flags = "wait,logical,first_stage_mount"; ... };
    metadata { dev = "/dev/block/platform/soc/1d84000.ufshc/by-name/metadata";
               fsmgr_flags = "wait,first_stage_mount,formattable"; };
};
```

v7 avait `avb=vbmeta` et `avb` (comme le fstab.qcom stock). v8 les a supprimés. Les deux bootloopent.

**Découverte clé via comparaison des timings pstore :**

| Version | Timing crash | Signification |
|---|---|---|
| v4/v5/v6 (fstab vide/absent) | ~immédiat après init start | "First stage mount skipped" — init ne tente rien |
| v7/v8/v9 (fstab avec first_stage_mount) | **t=13.636s** (+10s après init start) | Init lit le fstab, **tente le montage**, attend, échoue |

Le délai de ~10 secondes confirme qu'**init lit bien notre fstab DT et tente de monter les partitions**. Ce n'est plus un problème de fstab manquant — c'est un échec pendant le montage lui-même.

### Théorie actuelle : échec de création des partitions logiques

Pour monter `system` (partition logique/dynamique), init doit :
1. Trouver `/dev/block/by-name/super` (super partition physique)
2. Lire les métadonnées LVM-like (liblp) pour localiser `system` dans la super partition
3. Créer un device `dm-linear` → `/dev/block/dm-X`
4. Monter `/dev/block/dm-X` sur `/system`

Le flag `wait` dans fsmgr_flags attend l'apparition de ce device. Après ~10s de timeout (Samsung a probablement réduit le timeout AOSP de 20s à 10s), init renonce → `execv("/system/bin/init") failed`.

**Hypothèse principale** : notre kernel CIP 4.19.325 a un driver UFS légèrement différent du Samsung 4.19.113. Les symlinks `/dev/block/by-name/` sont créés par le first stage init via ses règles uevent internes. Si le driver UFS de notre kernel expose un chemin sysfs différent, aucune règle uevent ne matche → pas de symlink `/dev/block/by-name/super` → impossible de lire les métadonnées de la super partition → dm-linear non créé → timeout → crash.

Le binaire `init` du ramdisk contient ces strings qui correspondent à ce scénario :
```
"Could not create logical partition"
"Could not read logical partition metadata from"
```

### v10 — objectif : voir les messages init pendant les 10 secondes

`loglevel=4` (WARNING) au lieu de `loglevel=3` (ERROR) : les messages d'erreur de Samsung init (écrits via `/dev/kmsg` au niveau WARNING) deviendraient visibles dans le pstore, révélant exactement où ça échoue pendant la fenêtre t=3s→t=13s.

**v10 bloqué** à l'écran ABL ("Hash of data does not match") suite à un flash corrompu (heimdall a affiché `Failed to receive file part response! Retrying` pendant le transfert). Le fichier `boot_patched_v10.img` est correct sur disque — il faut le reflasher.

```bash
# Commande de flash v10 (depuis Download Mode) :
heimdall flash --BOOT output/firmware/boot_patched_v10.img --no-reboot
```

---

## 15. Informations architecturales clés découvertes

### Qualcomm ABL (Android Boot Loader) pour SM8250

- **QCDT** (Qualcomm Combined Device Tree) : format propriétaire où plusieurs DTBs sont appendés au kernel. L'ABL sélectionne par `qcom,msm-id` (version SoC)
- **DTBO** : overlay appliqué depuis la partition `dtbo`. Sélectionné par `qcom,board-id`. Nécessite `__symbols__` dans le DTB de base pour les fixups de labels
- **boot.img v2 DTB** : section dédiée dans le header v2. Dans notre cas, contient les 3 DTBs kona de base (même si l'ABL utilise surtout les DTBs appendés au kernel)
- `ro.boot.dtb_idx=0` : ABL a sélectionné DTB #0 (kona.dtb, base SoC)
- `ro.boot.dtbo_idx=3` : ABL a sélectionné DTBO #3 depuis la partition dtbo (= r06 EUR = PV Rev0.4)

### Structure des partitions Samsung SM-T970

- Partitions dynamiques (super) : system, vendor, product, odm, system_ext
- Partitions physiques : boot, dtbo, metadata, userdata, misc, vbmeta, prism, optics, etc.
- Contrôleur UFS : `/dev/block/platform/soc/1d84000.ufshc/`

### Fichiers sources importants

| Fichier | Rôle |
|---|---|
| `sources/arch/arm64/boot/dts/vendor/qcom/kona.dts` | DTB base SoC kona v1 |
| `sources/arch/arm64/boot/dts/vendor/qcom/kona-v2.1.dts` | DTB base SoC kona v2.1 (notre device) |
| `sources/arch/arm64/boot/dts/vendor/qcom/kona.dtsi` | Définit `android_q_fstab` avec `vendor` seulement |
| `sources/arch/arm64/boot/dts/samsung/common/kona-sec-common.dtsi` | DTSO Samsung : désactive `android_q_fstab` |
| `sources/arch/arm64/boot/dts/samsung/gts7xl/kona-sec-gts7xlwifi-eur-overlay-r06.dts` | DTSO spécifique gts7xlwifi EUR Rev0.4 |
| `sources/arch/arm64/boot/dts/Makefile` | Avait `subdir vendor` commenté (bug!) |
| `sources/arch/arm64/boot/dts/vendor/qcom/Makefile` | N'avait pas `kona.dtb`, `kona-v2.dtb`, `kona-v2.1.dtb` en `dtb-y` |

### Extrait clé de kona.dtsi (où le fstab de base est défini)

```dts
firmware: firmware {
    android {
        compatible = "android,firmware";
        android_q_fstab: fstab {
            compatible = "android,fstab";
            vendor {
                compatible = "android,vendor";
                dev = "/dev/block/platform/soc/1d84000.ufshc/by-name/vendor";
                type = "ext4";
                mnt_flags = "ro,barrier=1,discard";
                fsmgr_flags = "wait,slotselect,avb";  // ← pas de first_stage_mount
                status = "ok";
            };
        };
    };
};
```

Le label `android_q_fstab:` est le point d'accroche pour le DTBO Samsung. Dans le DTB stock compilé avec `-@`, ce label génère une entrée dans `__symbols__` que l'ABL utilise pour appliquer le disable. Nos DTBs compilés sans `-@` ne génèrent pas cette entrée → DTBO impuissant sur ce nœud.

---

## 16. Chronologie des flashs

| Version | Kernel | Cmdline | Résultat |
|---|---|---|---|
| Stock | Samsung 4.19 | Stock | Android normal ✓ |
| v1/v2 | Custom 4.19 CIP | Stock sans force_normal_boot | Recovery "can't load Android" |
| v3 | Custom 4.19 CIP | + force_normal_boot=1 | Bootloop rapide (init appelle reboot) |
| v4 | Custom 4.19 CIP | + panic=30 | Bootloop, pstore lisible → root cause identifiée |
| v5 | Custom 4.19 CIP + DTBs appendés | + force_normal_boot=1 | Même crash, mais HW name correct (DTBO appliqué !) |
| v6 | Custom 4.19 CIP + DTBs + fstab_custom | + force_normal_boot=1 | Même crash (fstab_custom ignoré par init) |
| v7 | Custom 4.19 CIP + DTBs patchés v2 (fstab complet + avb) | + force_normal_boot=1 | Bootloop — crash à t=13.6s (`execv /system/bin/init` failed) |
| v8 | Custom 4.19 CIP + DTBs patchés v3 (fstab sans avb) | + force_normal_boot=1 + loglevel=3 | Bootloop — même crash t=13.636s, pstore 154KB lisible |
| v9 | Custom 4.19 CIP + DTBs patchés v3 | + force_normal_boot=1 (sans loglevel) | Bootloop — pstore 35KB seulement (buffer saturé en 5s) |
| v10 | Custom 4.19 CIP + DTBs patchés v3 | + force_normal_boot=1 + loglevel=4 | Bloqué écran ABL (flash corrompu heimdall — retry pendant transfert) → à reflasher |

---

## 17. Outils de debug utilisés

### pstore (ramoops)
```bash
# Depuis Android stock après crash du kernel custom :
adb shell "strings /sys/fs/pstore/console-ramoops-0" | grep "init:\|fstab\|panic\|execv"
```

### getprop (depuis Android)
```bash
adb shell getprop | grep "ro.boot\|ro.hardware\|kernel"
# ro.boot.bootreason=kernel_panic,init  ← confirmation du crash
# ro.boot.dtb_idx=0
# ro.boot.dtbo_idx=3
```

### dtc (device tree compiler)
```bash
# Décompiler un DTB pour inspection :
dtc -I dtb -O dts fichier.dtb

# Inspecter la structure des phandles :
strings fichier.dtb | grep "__symbols__\|android_q_fstab"
```

### Analyse du binaire init du ramdisk
```bash
strings /tmp/ramdisk_extract/init | grep "firmware/android\|/fstab\|ReadFstab"
# Révèle les chemins DT exacts utilisés par init
```

---

## 18. Ce qu'on sait maintenant sur le kernel stock Samsung

Le kernel stock Samsung (4.19.113-27114284) est un Linux **fortement patché** par Samsung. Il pèse ~54MB compressé (vs 22MB pour notre build) car il inclut :

- Drivers propriétaires Samsung (Knox, sec_debug, display Samsung, Wacom W9021 SPen, etc.)
- Drivers Qualcomm complets (DSI display, camera ISP, audio ADSP, etc.)
- Mécanismes de sécurité Samsung (RKP, Knox hypervisor)
- Le kernel stock génère des DTBs avec `__symbols__` (compilés avec `dtc -@`)

Pour les prochaines étapes, une fois le boot Android confirmé, les drivers manquants devront être activés un par un dans la config kernel.

---

## 19. Questions ouvertes

1. **Pourquoi le kernel stock fonctionne-t-il avec le même fstab DT désactivé ?**
   - Hypothèse principale : init stock lit `/fstab.qcom` depuis le ramdisk **avant** le pivot_root vers `/first_stage_ramdisk`
   - Le timing exact de ce pivot_root vs lecture fstab reste non élucidé
   - Peut-être une modification Samsung dans `first_stage_init.cpp`

2. **Le format `dev = "system"` est-il correct pour Samsung ?**
   - Cohérent avec `fstab.qcom` qui utilise `system` comme source avec `logical` flag
   - À confirmer par le résultat du flash v7

3. **Quels drivers seront manquants après le premier boot ?**
   - Display (DSI/MDSS), Wi-Fi, caméra, Wacom SPen probablement non fonctionnels
   - À traiter partition par partition après confirmation du boot

---

## 20. Commandes de flash de référence

### Entrer en Download Mode
```
Tablette éteinte → Vol Bas + Vol Haut + USB
(pour déverrouiller OEM : Vol Haut sur le PREMIER écran d'avertissement)
```

### Flash via heimdall
```bash
# Flash boot partition
heimdall flash --BOOT /chemin/vers/boot_patched.img --no-reboot

# Reboot manuel après flash
# Vol Bas + Power → reboot normal
# Vol Haut + Power → recovery / download mode
```

### Retour au stock
```bash
heimdall flash --BOOT output/firmware/boot.img
```

### Lire pstore après crash
```bash
adb shell "strings /sys/fs/pstore/console-ramoops-0" | \
  grep -i "init:\|fstab\|panic\|execv\|mount\|system\|vendor" | head -60
```

---

## 21. Flash v11 — loglevel=5, découverte `force_normal_boot` vs SwitchRoot

### Ce qu'on a fait

Build v11 avec `loglevel=5` (NOTICE) pour voir les messages WARNING de Samsung init pendant la fenêtre t=10s→t=14s où le montage échoue.

**Source kernel** : CIP 4.19.325-cip128-st12+ (build #4 du container)
**Ramdisk** : stock (pas de fstab.default)
**DTB** : section `--dtb` = stock `boot.img-dtb` (pas les DTBs patchés dans l'Image.gz-dtb)
**Cmdline** : stock + `androidboot.force_normal_boot=1 loglevel=5`

### Résultat v11

Les logs loglevel=5 ont révélé quelque chose de fondamental que les versions précédentes masquaient :

```
init: [libfs_mgr]ReadFstabFromDt(): failed to read fstab from dt
init: [libfs_mgr]ReadDefaultFstab(): failed to find device default fstab
```

Ces deux lignes reviennent dans TOUS les boots depuis v4. Mais avec loglevel=5, on a aussi vu :

```
init: Switching root to '/first_stage_ramdisk'
```

**Prise de conscience critique** : `force_normal_boot=1` déclenche `SwitchRoot('/first_stage_ramdisk')` dans le Samsung init AVANT la recherche du fstab. Ce `SwitchRoot` :
1. Crée un tmpfs vide à `/first_stage_ramdisk`
2. Monte le tmpfs, déplace `/dev`, `/proc`, `/sys`, `/mnt` dedans
3. Effectue un `chroot` dans ce tmpfs
4. Le ramdisk original (avec `/fstab.qcom`) devient **inaccessible**
5. `ReadDefaultFstab()` cherche `/fstab.qcom` dans le tmpfs vide → ÉCHOUE

**C'était la vraie cause depuis v3.** Toutes les DTB patches (v5→v13) étaient une fausse piste — les DTB fstab auraient pu fonctionner si `ReadFstabFromDt()` réussissait, mais ce n'est pas le problème principal.

### Prise de conscience sur le boot stock

Sur le kernel stock, l'init (Samsung) lit `/fstab.qcom` **AVANT** d'appeler `SwitchRoot` — ou ne l'appelle pas du tout si `fstab_suffix` est défini correctement. Avec notre kernel CIP, le comportement est identique au stock Samsung niveau init binaire (c'est le même binaire init du ramdisk).

La différence : le kernel stock passe `androidboot.fstab_suffix=default` via ABL en temps normal, sans `force_normal_boot=1` dans le boot.img. L'ABL ajoute `force_normal_boot=1` dynamiquement pour les boots normaux, mais ce flag n'est **pas** dans le cmdline hardcodé du boot.img stock.

---

## 22. Flash v12 → v13 — DTBs patchés dans la section --dtb

### Stratégie v12/v13

Puisque `ReadFstabFromDt()` échoue toujours (le DTBO Samsung désactive notre fstab DT ou les `__symbols__` manquent), l'idée était de patcher les 3 DTBs kona et les mettre dans la section `--dtb` du boot.img header v2 (à la place du DTB stock).

**v13** incluait en plus le blob RTIC (Runtime Integrity Check) du DTB stock pour éviter un blocage ABL lié à la vérification RTIC.

**Résultat v13** : `ReadFstabFromDt(): failed` persiste. L'ABL écrit dans ses logs :
```
Override DTB: GetBlkIOHandles failed loading user_dtbo!
EDTBO check fail
Apply Overlay total time: 416 ms
Error finding dtbo-version property at Dtb
```

L'ABL passe quand même 416ms à tenter d'appliquer le DTBO (864 fixups, tous échouent sans `__symbols__`). Le `force_normal_boot=1` dans notre cmdline cause toujours le SwitchRoot → fstab inaccessible.

---

## 23. Flash v14 — ajout de fstab.default dans le ramdisk (échec partiel)

### Ce qu'on a fait

Prise de conscience : si `force_normal_boot=1` + `fstab_suffix=default` → init cherche `/fstab.default` dans le nouveau root (tmpfs post-SwitchRoot). Solution : ajouter `/fstab.default` dans le ramdisk — il sera copié dans le tmpfs lors du SwitchRoot.

**Extraction et modification du ramdisk** :
```bash
mkdir /tmp/ramdisk_extract
cd /tmp/ramdisk_extract
gunzip -c output/firmware/boot_unpacked/boot.img-ramdisk | cpio -idm
cp fstab.qcom fstab.default   # fstab.default = copie de fstab.qcom
find . | cpio -H newc -o | gzip -9 > /tmp/ramdisk_v14.img.gz
```

**Résultat v14** : `ReadFstabFromDt(): failed` + `ReadDefaultFstab(): failed`. `fstab.default` toujours inaccessible.

**Analyse post-log** : `SwitchRoot` ne copie PAS les fichiers du ramdisk dans le tmpfs — il déplace seulement `/dev`, `/proc`, `/sys`, `/mnt` et fait un `chroot`. Les fichiers du ramdisk restent dans l'ancien namespace de fichiers, inaccessible depuis le nouveau chroot.

---

## 24. Flash v15 — SUPPRESSION de force_normal_boot=1 : PREMIER SUCCÈS

### La vraie solution

Au lieu d'ajouter `fstab.default` pour survivre au SwitchRoot, on supprime simplement `force_normal_boot=1` de la cmdline. Sans ce flag, init ne fait pas de SwitchRoot, lit `/fstab.qcom` directement depuis le ramdisk.

**Ramdisk** : `/tmp/ramdisk_v14.img.gz` (conservé, contient quand même `fstab.default`)
**Cmdline** : **STOCK UNIQUEMENT** — pas d'ajout de `force_normal_boot=1`

```bash
CMDLINE="$(cat $UNPACKED/boot.img-cmdline)"  # stock seulement, sans ajout
```

**Note importante** : l'ABL ajoute lui-même `androidboot.force_normal_boot=1` dans les paramètres kernel dynamiques (non visibles dans le boot.img cmdline). Ce flag ABL-injecté n'est PAS dans le cmdline hardcodé et ne déclenche PAS le SwitchRoot dans le Samsung init — seule la présence du flag dans le cmdline **hardcodé du boot.img** le déclenchait.

### Résultats v15 — timeline complète du pstore

```
[3.35s]  init: __mount(metadata): Success
[3.37s]  init: Built verity table for system/vendor/product/odm
[3.39s]  init: [libfs_avb] Allowing rollbacked standalone image (device unlocked)
[3.39s]  init: dm-0 (system), dm-1 (vendor), dm-2 (product), dm-3 (odm) créés
[3.39s]  init: system/product/vendor/odm/prism/optics montés ✓
[5.16s]  init: Switching root to '/system'  ← CORRECT
[5.16s]  init: init second stage started!   ← SUCCÈS MAJEUR
[5.18s]  init: Using Android DT directory /proc/device-tree/firmware/android/
[5.23s]  → parsing de tous les .rc vendor/system
[5.16s→18s]  → SELinux policy chargée, services démarrés
[18.7s]  → vold démarre, lit fstab pour userdata
[~26s]   recovery PID 552 : reboot, recovery
[26.88s] sec_log_buf: reboot, recovery
```

**First stage mount : COMPLET.** C'est la première fois que le kernel CIP monte les partitions Android.

### Obstacle suivant : enablefilecrypto (ICE ODE failure)

Après que second stage init démarre, vold tente de configurer le chiffrement de `/data` (userdata). Samsung implémente une couche ODE (On-Device Encryption) propriétaire qui appelle `enablefilecrypto` — un appel binder vers vold qui configure le **hardware ICE** (Inline Crypto Engine) pour le chiffrement FBE de userdata.

**Symptôme** :
- 4 fichiers vides `/data/log/last_ode_dumpstate_enablefilecrypto_failed` créés
- Recovery invoquée avec `--prompt_and_wipe_data --reason=enablefilecrypto_failedR`
- Écran Samsung "Retry / Factory Reset" après 2 boots failed

**Cause racine** : le fstab.qcom stock utilise `fileencryption=ice,inlinecrypt` pour userdata :
```
/dev/block/bootdevice/by-name/userdata  /data  f2fs  
  noatime,...,inlinecrypt  
  latemount,wait,check,fileencryption=ice,quota,...
```

Samsung's vold appelle des APIs TrustZone (QSEE) Samsung-spécifiques pour configurer les clés hardware-wrappées de l'ICE engine. Notre kernel CIP a bien `CONFIG_CRYPTO_DEV_QCOM_ICE=y` mais implémente l'interface **upstream Qualcomm**, différente de l'interface Samsung modifiée qu'attend leur vold.

---

## 25. Flash v16 — contournement ICE : software FBE + formattable

### Stratégie

Modifier `fstab.qcom` (et `fstab.default`) pour remplacer le chiffrement ICE hardware par du chiffrement AES software standard, et ajouter `formattable` pour permettre à vold de reformater userdata (actuellement chiffré ICE, illisible sans ICE).

**Modification dans `/tmp/ramdisk_extract/fstab.qcom`** :
```
# AVANT (ICE hardware) :
...inlinecrypt   latemount,wait,check,fileencryption=ice,quota,...

# APRÈS (AES software) :
...              latemount,wait,check,fileencryption=aes-256-xts:aes-256-cts:v2,quota,...,formattable
```

Changements clés :
- Suppression de `inlinecrypt` dans les mount flags
- `fileencryption=ice` → `fileencryption=aes-256-xts:aes-256-cts:v2`
- Ajout de `formattable` : vold peut reformater si le FS est illisible

```bash
# Rebuild ramdisk :
cd /tmp/ramdisk_extract
find . | cpio -H newc -o | gzip -9 > /tmp/ramdisk_v16.img.gz

# Build boot.img v16 (SANS force_normal_boot=1, cmdline stock uniquement) :
mkbootimg \
  --kernel $KERNEL \
  --ramdisk /tmp/ramdisk_v16.img.gz \
  --dtb $UNPACKED/boot.img-dtb \
  --cmdline "$(cat $UNPACKED/boot.img-cmdline)" \
  [... offsets standard ...] \
  --output boot_patched_v16.img
```

**Taille** : 25,661,440 bytes (identique à v15 — delta ramdisk minimal)

### Résultat v16 — Cas 2 : enablefilecrypto_failedR encore

**CONSTAT** : v16 échoue avec exactement le même `enablefilecrypto_failedR`. Le changement de `fileencryption=ice` vers `fileencryption=aes-256-xts:aes-256-cts:v2` n'a eu aucun effet.

**Explication** : l'hypothèse initiale était fausse. Samsung ODE n'est pas déclenché par le flag `fileencryption=` du fstab, mais par les **propriétés système** `ro.crypto.state=encrypted` et `ro.crypto.type=file` sur la partition `system` (protégée dm-verity, non modifiable). Ces propriétés font que vold appelle `enablefilecrypto` quel que soit le mode de chiffrement déclaré dans le fstab ramdisk.

**Fichiers d'intérêt créés sur le device après v16** :
- `/data/log/vold-dump_14` (19,285 bytes) — dump vold à l'échec ODE ; SELinux-protégé (`-rw------- system system`), illisible via adb
- `security.securehw.available=false` dans recovery.log
- `security.securenvm.available=false` dans recovery.log

---

## 25b. Flash v17 — suppression totale de fileencryption

### Stratégie

Si `fileencryption=ice` et `fileencryption=aes-256-xts` échouent tous les deux, peut-être qu'en supprimant **tout flag de chiffrement** vold traiterait userdata comme non chiffré, contournant le trigger ODE.

Modifications dans `/tmp/ramdisk_extract/fstab.qcom` et `fstab.default` :

```
# userdata — suppression complète de fileencryption= :
/dev/block/bootdevice/by-name/userdata  /data  f2fs
  noatime,nosuid,nodev,discard,usrquota,grpquota,fsync_mode=nobarrier,reserve_root=32768,resgid=5678
  latemount,wait,check,quota,reservedsize=128M,checkpoint=fs,formattable

# keydata — suppression de inlinecrypt + fileencryption=ice :
/dev/block/bootdevice/by-name/keydata    /keydata    ext4  ...  wait,check,nofail
/dev/block/bootdevice/by-name/keyrefuge  /keyrefuge  ext4  ...  wait,check,nofail
```

**Taille ramdisk_v17.img.gz** : 807,832 bytes

### Résultat v17 — Cas 2 encore

Même échec. La suppression totale de `fileencryption=` n'a aucun effet sur le déclenchement de `enablefilecrypto`. Confirmation définitive : **le fstab ramdisk n'est pas la cause**.

---

## 26. Chronologie complète des flashs (mise à jour)

| Version | Ramdisk | DTB section | Cmdline ajouts | Résultat |
|---|---|---|---|---|
| Stock | Stock | Stock | (stock) | Android normal ✓ |
| v1/v2 | Stock | Stock | rien | Recovery "can't load Android" |
| v3 | Stock | Stock | `force_normal_boot=1` | Bootloop rapide |
| v4 | Stock | Stock | `force_normal_boot=1 panic=30` | Pstore lisible → ReadFstabFromDt/ReadDefaultFstab failed |
| v5 | Stock | Stock (DTBs appendés kernel) | `force_normal_boot=1` | Hardware name correct (DTBO appliqué) — même crash |
| v6 | Stock | Stock | `force_normal_boot=1` | fstab_custom ignoré par init |
| v7 | Stock | Stock (DTBs patchés kernel) | `force_normal_boot=1` | Crash t=13.6s — init tente le montage ! |
| v8 | Stock | Stock (DTBs patchés v3) | `force_normal_boot=1 loglevel=3` | Même crash t=13.6s |
| v9 | Stock | Stock (DTBs patchés v3) | `force_normal_boot=1` | Même crash — pstore tronqué |
| v10 | Stock | Stock (DTBs patchés v3) | `force_normal_boot=1 loglevel=4` | Flash corrompu heimdall |
| v11 | Stock | Stock (boot.img-dtb) | `force_normal_boot=1 loglevel=5` | **DÉCOUVERTE** : SwitchRoot avant fstab → cause racine |
| v12 | Stock | DTBs patchés kona_v3 | `force_normal_boot=1 loglevel=5` | ReadFstabFromDt failed (ABL 416ms overlay) |
| v13 | Stock | DTBs patchés + RTIC blob | `force_normal_boot=1 loglevel=5` | Même résultat |
| v14 | + fstab.default | Stock (boot.img-dtb) | `force_normal_boot=1` | fstab.default inaccessible post-SwitchRoot |
| **v15** | + fstab.default | Stock (boot.img-dtb) | **(aucun ajout)** | **PREMIER BOOT COMPLET !** → ODE failure : `enablefilecrypto_failedR` |
| **v16** | fstab ICE→AES-256-XTS + formattable | Stock (boot.img-dtb) | **(aucun ajout)** | Cas 2 : même `enablefilecrypto_failedR` — fstab n'est pas la cause |
| **v17** | fstab sans fileencryption= du tout | Stock (boot.img-dtb) | **(aucun ajout)** | Cas 2 : même `enablefilecrypto_failedR` — cause racine ROT mismatch |

---

## 27. Architecture du problème ICE — analyse initiale (hypothèse invalide)

### Pourquoi on pensait que c'était ICE

Hypothèse de v15 : le Samsung Galaxy Tab S7+ utilise FBE avec hardware ICE. Le kernel CIP a l'infrastructure ICE upstream Qualcomm (`CONFIG_CRYPTO_DEV_QCOM_ICE=y`, `CONFIG_SCSI_UFS_CRYPTO_QTI=y`…) mais Samsung a modifié l'interface QSEE pour ICE. Donc le vold Samsung ne pouvait pas initialiser ICE avec le CIP kernel.

**Cette hypothèse était partiellement correcte** mais identifiait le mauvais niveau du problème. L'interface ICE n'est jamais atteinte — le failure se produit en amont, lors de la récupération de la clé FBE depuis `/keydata`.

---

## 28. Cause racine réelle : ROT (Root of Trust) mismatch Samsung Keymaster

### Découverte — analyse de `prev_dump.log` (boot v17)

Après v16 et v17 (tous deux Cas 2), le fichier `/data/log/prev_dump.log` (dumpstate du boot CIP précédent) a livré la séquence exacte :

```
[24.222] init: Command 'exec_start wait_for_keymaster' action=late-fs → failed: Service not found
[25.317] init: FBE will be enabled!
[25.319] init: unencrypted_dir:/keydata/unencrypted / ret:0 / errorno:17   (EEXIST = répertoire existe déjà)
[25.320] init: unencrypted_dir:/keyrefuge/unencrypted / ret:0 / errorno:17
[25.320] init: starting service 'exec 6 (/system/bin/vdc --wait cryptfs enablefilecrypto)'...

[25.358] vdc: Waited 0ms for vold
[25.360] FsCrypt: Key exists, using: /keydata/unencrypted/key
[25.361] KeyStorage: retrieveKey : /keydata/unencrypted/key

[25.370] !@ convertKeyParametersToLegacy : KM_TAG_SAMSUNG_ROT_REQUIRED = 10
[25.375] !@ begin : result = -33                ← keymaster begin() ÉCHOUE
[25.375] KeyStorage: getRotStr There is no rot value
[25.377] KeyStorage: rot value: 07000200000000000000000000000000
[25.377] KeyStorage: checkRotStr ROT value was invalid
[25.377] KeyStorage: checkRotStr current rot value : 07000200000000000000000000000000
[25.377] KeyStorage: checkRotStr saved rot value   : 06000200000000000000000000000000  ← MISMATCH
[25.378] KeyStorage: decryptWithKeymasterKey fail

[25.381] KeyStorage: FBE key integrity check success: /keydata/unencrypted/key  (hash seul, pas la clé)
[25.382] voldUtils: PROP : security.fbe.fail_cause : , value R   ← "R" = ROT mismatch

[26.176] vdc: Command: cryptfs enablefilecrypto Failed: Status(-8, EX_SERVICE_SPECIFIC): '0: '
[26.180] init: Service 'exec 6 (/system/bin/vdc --wait cryptfs enablefilecrypto)' exited with status 25
[26.181] init: Exec service failed, status 25: Rebooting into recovery, reason: enablefilecrypto_failed; value : R
```

### Explication du mécanisme

Samsung ODE utilise **`KM_TAG_SAMSUNG_ROT_REQUIRED`** — une extension Samsung de Keymaster qui lie les clés FBE à la **ROT (Root of Trust)** courante du bootloader.

La ROT est calculée par l'ABL (Samsung bootloader) à partir de :
- L'état du bootloader (`device_state=unlocked`)
- Le compteur de déverrouillage (`androidboot.ulcnt=1`)

**Ce qui s'est passé** :
| Moment | ROT | État |
|---|---|---|
| Première mise en service de la tablette | `06000200…` | Device verrouillé (ulcnt=0) ou stock Android |
| Après déverrouillage OEM | `07000200…` | ulcnt=1, state=unlocked |
| Boot avec CIP kernel (v15/v16/v17) | `07000200…` | Identique au post-unlock |

La clé FBE dans `/keydata/unencrypted/key` a été créée avec ROT=`06`. Maintenant ROT=`07`. Samsung `fabrickeymaster` TrustZone App refuse de déchiffrer une clé liée à un ROT différent → `begin(-33)` → `fail_cause=R` → `enablefilecrypto` échoue.

### Preuve que le fstab n'a jamais été la cause

- v15 : `fileencryption=ice` → Cas 2
- v16 : `fileencryption=aes-256-xts:aes-256-cts:v2` → Cas 2
- v17 : aucun `fileencryption=` → Cas 2

Les trois boots donnent **exactement la même séquence de log** avec le même mismatch ROT. La protection est en amont de tout code qui regarde le fstab.

### Stabilité du ROT entre versions du CIP kernel

**Point clé** : v15, v16, v17 utilisent des ramdisks différents mais affichent tous `current rot = 07000200…`. Puisque ces trois boots ont des boot.img différents (ramdisk différent → hash partition boot différent), et que le ROT reste identique à `07`, **le ROT n'est PAS basé sur le hash du boot.img**.

Le ROT est basé uniquement sur `device_state + ulcnt`. Il est donc **stable pour tous les futurs CIP kernels** (quelle que soit la version du kernel ou du ramdisk), tant que le compteur d'unlock ne change pas.

### Propriétés recovery liées à l'ODE

Vues dans `recovery.log` à chaque session d'échec ODE avec CIP kernel :
```
security.securehw.available=false
security.securenvm.available=false
ro.crypto.allow_encrypt_override=true
```

`security.securehw.available=false` indique que le Secure Element Samsung (SecureNVM) n'est pas accessible avec le CIP kernel. Ceci peut affecter des opérations Samsung Knox mais n'est pas la cause directe de l'échec ODE — le failure se produit au niveau `fabrickeymaster` QSEE App (TrustZone), qui lui fonctionne (`QSEECOM: App (fabrickeymaster) now loaded` dans les logs CIP).

---

## 29. Solution : factory reset unique

### Principe

Effacer `/keydata` (qui contient la clé FBE liée à ROT=06) force vold à générer une **nouvelle clé** liée au ROT courant (07). Après ce reset, tous les boots CIP futurs utiliseront ROT=07 → correspondance avec les nouvelles clés → `enablefilecrypto` devrait réussir.

Le factory reset est **unique** : pas besoin d'en faire un à chaque mise à jour du kernel CIP (le ROT est stable).

### Résultat du factory reset — SUCCÈS MAJEUR

**Factory reset effectué depuis le menu AOSP recovery (avec v17 flashée).** Résultat :

1. Reboot post-reset → logo Samsung (ABL) ✓
2. Popup système (avertissement bootloader déverrouillé, affiché par ABL) ✓
3. Kernel CIP boote → Android démarre → **écran noir**

**`enablefilecrypto` a RÉUSSI.** Le device est passé en mode MTP sur USB (`04e8:6860`) — preuve qu'Android tourne. Aucun `enablefilecrypto_failedR` dans les logs. Le ROT mismatch est résolu.

### Problème suivant : écran noir (DRM display driver)

L'écran reste noir une fois le kernel CIP en contrôle du display. L'ABL affiche correctement ses propres écrans (logo + popup) car il a son propre driver display indépendant du kernel.

**Diagnostic depuis `last_kmsg` (OCR en recovery)** :

```
[drm:msm_fb_obj_get_attrs] *ERROR* NULL attachment   ← ×15+ fois
n_drm gem object                                      ← échecs d'allocation GEM
```

Le driver MSM DRM du CIP kernel s'initialise mais ne peut pas allouer les GEM objects (objets mémoire GPU) pour le framebuffer. `NULL attachment` = l'objet DRM n'a pas de backing device/memory attaché. Conséquence : aucun frame ne peut être rendu → écran noir permanent sous Android.

Le driver MSM DRM upstream (CIP) ne contient pas les modifications Samsung pour le panel DSI S6TUUM3 AMSA24VU01 WQXGA (panel de la SM-T970). C'est un problème de driver display à résoudre séparément.

### Problème ADB : factory reset a effacé les clés

Après le factory reset, `/data/misc/adb/adb_keys` est vide. La recovery AOSP Samsung montre le device comme `unauthorized` (adbd attend une confirmation UI impossible à afficher). ADB inaccessible sans résoudre d'abord l'autorisation.

---

## 30. Flash v18 — déblocage ADB via adb_debug.prop

### Problème à résoudre

Pour accéder à ADB sans écran (pour diagnostiquer le display et progresser), il faut contourner l'autorisation ADB post-factory-reset. Naviguer dans le setup wizard à l'aveugle pour activer les options développeur est possible mais peu fiable.

### Mécanisme découvert

Le binaire `init` du ramdisk contient explicitement la string `/debug_ramdisk/adb_debug.prop`. C'est un mécanisme Android standard : first-stage init charge ce fichier avant les propriétés system/vendor. Les propriétés `ro.*` étant first-write-wins, si on définit `ro.adb.secure=0` ici, ça prend le dessus sur la valeur system (`=1`).

Le répertoire `/debug_ramdisk/` existait déjà vide dans le ramdisk stock — Samsung prévoit ce mécanisme.

**Confiance : ~75%** (strings confirment le code path, mais Samsung pourrait l'avoir neutralisé malgré la référence).

### Modification

Création de `/tmp/ramdisk_extract/debug_ramdisk/adb_debug.prop` :
```
ro.adb.secure=0
ro.debuggable=1
```

Toutes les autres modifications v17 (fstab sans fileencryption=) sont conservées.

**Taille ramdisk_v18.img.gz** : 807,895 bytes

### Procédure de flash v18

```bash
# Depuis recovery : "Reboot to bootloader" → Download Mode
heimdall flash --BOOT output/firmware/boot_patched_v18.img
```

Après boot, `adb devices` devrait montrer le device sans dialog d'autorisation, et `adb shell` devrait fonctionner.

### Résultat v18

`adb devices` → device absent. `lsusb` → `04e8:6860` (MTP seulement, pas d'interface ADB).

**Cause** : `adb_debug.prop` ne contient que `ro.adb.secure=0` et `ro.debuggable=1`. Le gadget USB expose bien MTP mais pas ADB car `persist.sys.usb.config` n'inclut pas `adb`. Le vendor init Samsung écrase cette propriété avec `mtp` au boot.

---

## 34. Tentatives déblocage ADB — v19 à v21 et recovery

### v19 — Kernel CONFIG_FB_SIMPLE + adb_debug.prop (même ramdisk v18)

**Changements kernel** :
```
CONFIG_FB_SIMPLE=y
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y
```

**Objectif** : afficher quelque chose à l'écran pour naviguer visuellement (fix écran noir).

**Résultat** : L'interface Android apparaît **0,5 seconde** juste après le logo Samsung, avec le message *"Android System — There is an internal problem with your device. Contact your manufacturer."* puis écran noir. USB toujours MTP seulement, ADB non exposé.

**Diagnostic** : `CONFIG_FB_SIMPLE` réutilise le framebuffer initialisé par l'ABL (simple-framebuffer), donc l'image s'affiche brièvement. Le crash Android (system services) empêche le démarrage complet. L'erreur DRM vue précédemment (`[drm:msm_fb_obj_get_attrs] *ERROR* NULL attachment`) vient du driver panel Samsung (`CONFIG_PANEL_S6TUUM3=y`) sans contrôleur DRM (`CONFIG_DRM_MSM` non activé dans CIP).

---

### v20 — Ajout persist.sys.usb.config=mtp,adb dans adb_debug.prop

**Hypothèse** : si `persist.sys.usb.config=mtp,adb` est injecté en first-stage init via `adb_debug.prop`, le gadget USB exposera ADB.

**`/debug_ramdisk/adb_debug.prop`** :
```
ro.adb.secure=0
ro.debuggable=1
persist.sys.usb.config=mtp,adb
```

**Résultat** : toujours MTP seulement. ADB absent.

**Cause réelle** : les propriétés `persist.*` dans `adb_debug.prop` sont écrasées par le vendor init Samsung. Dans `init.qcom.usb.rc` ou équivalent, Samsung fait `setprop persist.sys.usb.config mtp` dans le trigger `on init`, ce qui écrase la valeur posée par first-stage init. La propriété `persist.sys.usb.config` n'est correctement prise en compte que si elle est dans `/data/property/persistent_properties` (format protobuf) ou imposée par le vendor init.

---

### v21 — Cmdline androidboot.usb.config=mtp,adb

**Hypothèse** : `androidboot.usb.config=mtp,adb` dans le cmdline kernel → `ro.boot.usb.config=mtp,adb` → vendor init l'utilise pour initialiser USB.

**Résultat** : toujours MTP seulement. Samsung ne consomme pas `ro.boot.usb.config` pour la config ADB.

**Constat** : `lsusb -v -d 04e8:6860` révèle 3 interfaces :
- Interface 0 : MTP (Imaging/PTP)
- Interface 1+2 : **CDC ACM** (port série virtuel) → apparaît comme `/dev/ttyACM0` sur le host

Le CDC ACM est le port diagnostic Samsung (`sec_acm`). Testé : aucune sortie utile (pas de shell, pas de logs — probablement un port AT commands ou diag propriétaire Samsung).

**Conclusion** : impossible d'activer ADB côté boot Android normal sans modifier le vendor init (partition vendor non accessible sans flasher). La voie de déblocage ADB passe par le **recovery**.

---

### Recovery patché — approche choisie

**Objectif** : modifier le recovery Samsung pour avoir un shell ADB opérationnel, depuis lequel on pourra :
1. Lire les logs du boot Android pour diagnostiquer le crash système
2. Écrire `/data/property/persistent_properties` pour fixer `persist.sys.usb.config=mtp,adb` au prochain boot normal

**Fichiers clés dans le recovery** :
- `default.prop` — propriétés boot legacy (Android < 11)
- `prop.default` — propriétés boot Android 11+ (**c'est celui-là qui prime**)
- `system/etc/init/hw/init.rc` — définition du service adbd
- `adb_keys` — clés ADB pré-autorisées (à la racine du ramdisk)

**Images construites** :

| Version | Modifications | Résultat |
|---|---|---|
| `recovery_patched` (v1) | `default.prop` : `ro.adb.secure=0`, `ro.debuggable=1`, `persist.sys.usb.config=mtp,adb` + `/adb_keys` | Toujours `unauthorized` — `prop.default` non patché |
| `recovery_patched_v2` | + `prop.default` patché (même changements) | ADB connecté (`recovery`) ✓ — mais `adb shell` crash SELinux |
| `recovery_patched_v3` | + `androidboot.selinux=permissive` dans cmdline | Toujours crash SELinux — `setcon()` échoue même en permissive si le type n'existe pas dans la policy |
| `recovery_patched_v4` | Suppression `--root_seclabel=u:r:su:s0` du service adbd | **En cours** |

**Erreur SELinux** :
```
adbd F shell_service.cpp:380] Could not set SELinux context for subprocess
libc: Fatal signal 6 (SIGABRT)
```
Le service adbd est défini avec `--root_seclabel=u:r:su:s0`. Ce label SELinux (`su`) n'existe pas dans la policy du recovery Samsung. `setcon()` échoue et crashe adbd. Fix : supprimer ce paramètre pour que le subprocess hérite du contexte adbd standard.

**Leçon** : dans le recovery Android 11, deux fichiers de propriétés coexistent. `default.prop` est un vestige (chargé en dernier dans les vieilles versions), `prop.default` est le fichier actif pour Android 11. Patcher l'un sans l'autre n'a aucun effet.

---

## 31. Chronologie complète des flashs (mise à jour finale)

| Version | Ramdisk | DTB section | Cmdline | Résultat |
|---|---|---|---|---|
| Stock | Stock | Stock | (stock) | Android normal ✓ |
| v1/v2 | Stock | Stock | rien | Recovery "can't load Android" |
| v3 | Stock | Stock | `force_normal_boot=1` | Bootloop rapide |
| v4 | Stock | Stock | `force_normal_boot=1 panic=30` | Pstore lisible → root cause |
| v5 | Stock | Stock (DTBs appendés kernel) | `force_normal_boot=1` | HW name correct — même crash |
| v6 | Stock | Stock | `force_normal_boot=1` | fstab_custom ignoré |
| v7 | Stock | Stock (DTBs patchés kernel) | `force_normal_boot=1` | Crash t=13.6s — init tente le montage |
| v8 | Stock | Stock (DTBs patchés v3) | `force_normal_boot=1 loglevel=3` | Même crash t=13.6s |
| v9 | Stock | Stock (DTBs patchés v3) | `force_normal_boot=1` | Même crash — pstore tronqué |
| v10 | Stock | Stock (DTBs patchés v3) | `force_normal_boot=1 loglevel=4` | Flash corrompu heimdall |
| v11 | Stock | Stock (boot.img-dtb) | `force_normal_boot=1 loglevel=5` | **DÉCOUVERTE** : SwitchRoot root cause |
| v12 | Stock | DTBs patchés kona_v3 | `force_normal_boot=1 loglevel=5` | ReadFstabFromDt failed |
| v13 | Stock | DTBs patchés + RTIC blob | `force_normal_boot=1 loglevel=5` | Même résultat |
| v14 | + fstab.default | Stock (boot.img-dtb) | `force_normal_boot=1` | fstab.default inaccessible post-SwitchRoot |
| **v15** | + fstab.default | Stock (boot.img-dtb) | **(aucun ajout)** | **PREMIER BOOT COMPLET** → enablefilecrypto_failedR |
| **v16** | fstab ICE→AES-256 + formattable | Stock (boot.img-dtb) | **(aucun ajout)** | Cas 2 — fstab pas la cause |
| **v17** | fstab sans fileencryption= | Stock (boot.img-dtb) | **(aucun ajout)** | Cas 2 — ROT mismatch confirmé |
| **Factory reset** | — | — | — | **enablefilecrypto RÉUSSI** — Android boote, écran noir (DRM) |
| **v18** | + debug_ramdisk/adb_debug.prop (ro.adb.secure=0, ro.debuggable=1) | Stock (boot.img-dtb) | **(aucun ajout)** | MTP seulement — persist.sys.usb.config écrasé par vendor init |
| **v19** | même ramdisk v18 | **CIP kernel FB_SIMPLE** (boot.img-dtb) | **(aucun ajout)** | Android System dialog 0.5s → écran noir — USB MTP seulement |
| **v20** | + persist.sys.usb.config=mtp,adb dans adb_debug.prop | CIP kernel FB_SIMPLE | **(aucun ajout)** | MTP seulement — persist. ignoré (vendor init écrase) |
| **v21** | même ramdisk v20 | CIP kernel FB_SIMPLE | `androidboot.usb.config=mtp,adb` | MTP seulement — Samsung ignore ro.boot.usb.config |
| **recovery_v1** | default.prop patché + /adb_keys | Stock recovery kernel | **(stock)** | Toujours unauthorized — prop.default non patché |
| **recovery_v2** | default.prop + prop.default patchés + /adb_keys | Stock recovery kernel | **(stock)** | ADB connecté ✓ — shell crash SELinux (root_seclabel=su) |
| **recovery_v3** | idem v2 | Stock recovery kernel | `androidboot.selinux=permissive` | Toujours crash SELinux — setcon() échoue même en permissive |
| **recovery_v4** | idem v2 + suppression --root_seclabel | Stock recovery kernel | `androidboot.selinux=permissive` | Shell crash SELinux — `setcon()` échoue même sans `--root_seclabel` (adbd calcule un contexte de transition) |
| **recovery_v5** | idem v3 | Stock recovery kernel | `selinux=0` (kernel param) | Ignoré — Samsung compile avec `CONFIG_SECURITY_SELINUX_BOOTPARAM=n` |
| **recovery_v6** | idem v3 + **patch binaire adbd** | Stock recovery kernel | `androidboot.selinux=permissive` | **En cours** |

---

### Détail du patch binaire adbd (recovery_v6)

**Problème** : `selinux_android_setcon()` est appelé dans `StartSubprocess()` (`shell_service.cpp:380`) pour changer le contexte SELinux du shell avant de l'exécuter. Si ce contexte n'est pas accessible (policy incomplète), la fonction retourne une erreur, et le code appelle `LOG(FATAL)` → `abort()` → SIGABRT.

**Localisation** : offset `0x9ec3c` dans `/system/bin/adbd` du ramdisk recovery.

```
AVANT : tbz w0, #31, 0x9ec98   ; 0xe002f836 — si résultat négatif (échec), FATAL
APRÈS : b   0x9ec98             ; 0x14000017 — toujours sauter (ignorer l'erreur)
```

**Outil** : patch Python direct sur le binaire (4 octets).

**Effets de bord** :
- Le shell fils hérite du contexte SELinux de adbd (`u:r:adbd:s0`) au lieu du contexte cible calculé → avec `androidboot.selinux=permissive` en cmdline, aucun impact sur les accès
- Impact **nul** sur le boot Android normal : ce binaire n'est que dans le ramdisk recovery, le `adbd` de la partition system n'est pas touché
- Limité au recovery patché — le recovery stock est conservé (`recovery.img.original`)

---

## 32. État des questions ouvertes

| Question | Statut |
|---|---|
| Pourquoi ReadDefaultFstab échouait ? | **RÉSOLU** : `force_normal_boot=1` → SwitchRoot avant fstab lookup |
| Le kernel stock réussit sans force_normal_boot dans boot.img ? | **RÉSOLU** : l'ABL l'ajoute dynamiquement |
| DTBs patchés nécessaires ? | **NON** : fstab.qcom du ramdisk suffit |
| enablefilecrypto — lié à ICE ? | **INVALIDE** : c'était le ROT mismatch Keymaster |
| enablefilecrypto — cause réelle ? | **RÉSOLU** : ROT 06→07 + factory reset = fix permanent |
| ROT stable entre versions CIP kernel ? | **OUI** : basé sur device_state+ulcnt uniquement |
| ADB sans écran | **EN COURS** : recovery_v6 — patch binaire adbd (ignore erreur setcon) |
| Écran noir (DRM NULL attachment) | **IDENTIFIÉ** — driver MSM DRM CIP sans panel Samsung DSI |
| Drivers manquants (WiFi, caméra, Wacom) | À traiter après ADB opérationnel |

---

## 33. Prochaines étapes

1. **Flasher v18** et vérifier `adb shell uname -r` → `4.19.325-cip128-st12+`
2. **Si ADB fonctionne** :
   - Tirer les logs du boot Android (dmesg, logcat) pour le display
   - Activer les options développeur depuis adb (`settings put global development_settings_enabled 1`)
   - Activer USB debugging : `settings put global adb_enabled 1`
3. **Display** : investiguer le driver MSM DRM — ajouter les sources Samsung DSI panel ou activer `CONFIG_DRM_MSM` avec les bons overlays
4. **Si adb_debug.prop ne fonctionne pas** : navigation aveugle au tactile pour activer les options développeur manuellement
5. **Après ADB + display stables** — drivers à activer :
   - WiFi : `CONFIG_QCA_CLD_WLAN`
   - Caméra, Wacom SPen W9021, Audio ADSP

---

*Document mis à jour le 7 avril 2026 — recovery_v6 : patch binaire adbd pour ignorer l'erreur SELinux setcon (tbz→b à 0x9ec3c). En cours de test.*
## 34. Recovery ADB — Tentatives v7 à v26 (résumé)

Suite à la découverte (section 33) que adbd crashait sur `setcon()`, une longue série de versions recovery a été construite pour débloquer ADB shell.

### Tentatives infructueuses documentées (v7-v26)

| Version | Modification | Résultat |
|---|---|---|
| recovery_v7 | + `androidboot.selinux=permissive` dans cmdline | `setcon()` échoue encore — Samsung ignore le paramètre en recovery |
| recovery_v8 | Suppression `--root_seclabel=u:r:su:s0` du service adbd | Adbd calcule toujours une transition SELinux, `setcon()` crash |
| recovery_v9 | `selinux=0` dans cmdline kernel | Ignoré — `CONFIG_SECURITY_SELINUX_BOOTPARAM=n` dans le kernel Samsung |
| recovery_v10→v11 | Patch binaire adbd offset 0x9ec3c : `tbz w0,#31` → `b` | SIGABRT supprimé ✓ — mais `exec '/system/bin/sh' failed: Permission denied` |
| recovery_v12→v26 | Tentatives SELinux (`write enforce 0` dans init.rc early-init, property triggers, `adb push` vers enforce) | Samsung recovery binary appelle `setenforce(1)` après init, `adb push` bloqué par SELinux lui-même |

**Cause racine identifiée** : Samsung recovery binary appelle explicitement `setenforce(1)` après `early-init`. Toutes les approches "écrire 0 dans /sys/fs/selinux/enforce" échouent car :
- `early-init` write : écrasé par recovery binary
- `on property:sys.usb.ffs.ready=1` write : init n'a pas `security_setenforce` dans la policy Samsung recovery
- `adb push` vers enforce : adbd domain bloqué par SELinux pour cette opération
- `adb pull /proc/last_kmsg` : SELinux bloque même le `stat`

---

## 35. Recovery_v29 — Déblocage ADB via magiskpolicy (SUCCÈS)

### Solution : patch du binaire `sepolicy` dans le ramdisk

Au lieu d'essayer de désactiver SELinux globalement, on modifie directement la policy SELinux dans le ramdisk recovery pour marquer le domaine `adbd` comme permissif.

**Outil** : `magiskpolicy` (disponible dans `anykernel/tools/magiskpolicy` — binaire ARM32, exécuté via `qemu-user` sur le host x86_64)

**Commande appliquée** :
```bash
magiskpolicy --load sepolicy \
  'permissive adbd' \
  'allow adbd shell_exec file { execute execute_no_trans open read getattr }' \
  'allow adbd rootfs file { execute execute_no_trans open read getattr }' \
  'allow adbd shell process { noatsecure signal dyntransition sigchld }' \
  --save sepolicy
```

Le fichier `sepolicy` se trouve à la **racine du ramdisk** (pas dans `system/etc/selinux/`).

**Résultat recovery_v29** :
```
adb shell uname -r → 4.19.113-27114284  ✓ (kernel recovery stock, attendu)
adb pull /proc/last_kmsg → 21031 lignes, 2MB  ✓
```

ADB shell et adb pull fonctionnent. SELinux reste globalement enforcing mais le domaine adbd est permissif → plus de blocage exec.

**Note** : `adb root` fait redémarrer adbd mais l'appareil ne reconnecte pas (non supporté dans ce recovery). Le shell tourne en `uid=2000(shell)`.

**Recovery_v29 est la baseline debug stable.** Plus besoin d'OCR pour les logs.

---

## 36. Analyse last_kmsg depuis recovery_v29

### Workflow d'extraction des logs

`adb pull /proc/last_kmsg` donne les logs du **boot précédent**. Pour avoir les logs CIP kernel :
1. Booter `boot_patched_vN.img` (kernel CIP)
2. Laisser tourner ~30s
3. Rebooter en recovery_v29
4. `adb pull /proc/last_kmsg /tmp/last_kmsg_vN.log`

**Note** : `/sys/fs/pstore/` est monté en recovery mais **vide** (pas de données ramoops disponibles en recovery). `/proc/last_kmsg` est la seule source de logs kernel depuis recovery.

**Note** : `adb pull` pour les logs nécessite SELinux permissive (recovery_v29+). Avec SELinux enforcing, même `stat` est bloqué.

### Résultats de l'analyse (last_kmsg_v29.log — section CIP kernel 4.19.325)

**DRM/Display dans le kernel CIP** :
- MDP address space mappé à `0xffffff802f100000` ✓ (valide)
- IOMMU groupes 56 et 57 (`mdp_ns`, `mdp_s`) ajoutés ✓
- `cont_splash enabled in 1 of 1 display(s)` ✓
- `dsi_display_cont_splash_config: set samsung splash (1)` ✓
- **Zéro** `NULL attachment`, **zéro** `Atomic Commit failed` dans la section CIP

**Erreurs DTS non-fatales** :
- `[13.48s] dsi_panel_get ERROR: failed to parse fod dim lut` — propriété `samsung,fod-dim-lut` absente du DTS S6TUUM3. Non fatal, `panel->fod_dim_lut = NULL`, feature désactivée.
- `[13.48s] panel_node not found` — le driver DSI cherche `ss_dsi_panel_S6TUUM3_AMSA24VU01_WQXGA` via `of_find_node_by_name(mdp_node, ...)`. Ce nœud devrait venir de `kona-sec-gts7xl-display-r01.dtsi` via DTBO, mais les fixups DTBO sont partiels sans `__symbols__`.

**Conclusion** : le kernel DRM CIP fonctionne. L'écran noir vient de l'espace utilisateur Android (HWComposer/SurfaceFlinger crash). V19 (`CONFIG_FB_SIMPLE=y`) avait montré 0,5s d'UI Android avant le crash — confirmation que le problème est au niveau HAL, pas kernel.

**`NULL attachment` précédemment observé** : ces erreurs venaient du **kernel recovery stock** (4.19.113), pas du kernel CIP. Le MDP se mappe à `0x0` dans le boot recovery (stock kernel dans recovery.img), ce qui n'affecte pas le boot Android normal.

---

## 37. ADB sur le boot Android normal — analyse

### Propriétés confirmées (depuis recovery shell)

```
persist.sys.usb.config  = mtp,adb   (dans persistent_properties — lue par getprop en recovery)
ro.adb.secure           = 0         (dans prop.default du ramdisk)
ro.debuggable           = 1         (dans prop.default du ramdisk)
ro.boot.debug_level     = 0x4f4c    (Samsung debug level "LOW" — pas "HIGH" = 0x4948)
```

### Mécanisme du blocage ADB sur boot Android

L'init.rc et vendor init (`/vendor/etc/init/hw/init.qcom.usb.rc`) ne sont pas la cause directe. Le blocage vient de **`UsbDeviceManager`** (service Java dans `frameworks/base`) qui réinitialise `persist.sys.usb.config` à `mtp` si `adb_enabled=1` n'est pas dans la settings database Android.

La settings DB (`/data/data/com.android.providers.settings/databases/settings.db`) est chiffrée FBE — inaccessible depuis recovery (uid=2000 shell, `adb root` non supporté).

### Plan de déblocage ADB Android

**Option 1 (à tester d'abord)** : `persist.sys.usb.config=mtp,adb` est déjà dans persistent_properties. Avec `ro.adb.secure=0`, ADB pourrait fonctionner dès le prochain boot Android sans modification. `UsbDeviceManager` ne réinitialise pas forcément si la valeur est déjà `mtp,adb`.

**Option 2 (si option 1 échoue)** : Ajouter dans le ramdisk boot init.rc :
```
on property:sys.boot_completed=1
    exec_background /system/bin/settings put global development_settings_enabled 1
    exec_background /system/bin/settings put global adb_enabled 1
```
`settings` est disponible après second-stage init. Cette commande active USB debugging depuis Android lui-même au premier boot.

---

## 38. Corrections et précisions importantes

### Capteur d'empreinte (FOD)
La Samsung Galaxy Tab S7+ SM-T970 **possède bien un capteur d'empreinte** utilisé avec `samsung,fod-dim-lut`. L'erreur `failed to parse fod dim lut` dans les logs CIP est donc potentiellement fonctionnellement significative (dimming lors de l'utilisation du capteur). À investiguer si l'authentification par empreinte est requise après le déblocage display.

### Version Android
La tablette tourne sous **Android 13 / OneUI 5.1.1**. La mention "Android 11" dans certains logs vient de la build string de la recovery Samsung v10.0.6 (compilée contre une base Android 11 AOSP) — elle ne reflète pas la version de l'OS.

### Factory Reset
Un factory reset / wipe n'efface **pas** les partitions `boot` et `recovery`. Il efface uniquement `/data` et `/cache`. Les kernels custom restent intacts après un wipe.

---

## 39. Chronologie complète des flashs — mise à jour finale

| Version | Partition | Modifications | Résultat |
|---|---|---|---|
| recovery_v7→v9 | RECOVERY | SELinux bypass tentatives diverses | Échec — `CONFIG_SECURITY_SELINUX_BOOTPARAM=n` |
| recovery_v10→v11 | RECOVERY | Patch binaire adbd (tbz→b à 0x9ec3c) | SIGABRT supprimé ✓ — exec bloqué |
| recovery_v12→v26 | RECOVERY | write enforce, property triggers, adb push | SELinux bloque toutes les approches |
| **recovery_v27** | RECOVERY | `write /sys/fs/selinux/enforce 0` first in early-init | No-op — déjà présent en v26 |
| **recovery_v28** | RECOVERY | `on property:sys.usb.ffs.ready=1 write enforce 0` | init n'a pas `security_setenforce` perm |
| **recovery_v29** | RECOVERY | `magiskpolicy 'permissive adbd' + allow rules` sur sepolicy | **ADB SHELL FONCTIONNE** ✓ — baseline debug stable |
| boot_patched_v21 | BOOT | (dernier kernel CIP build #5) | Android boot ✓, écran noir (userspace crash) |

---

*Document mis à jour le 11 avril 2026 — recovery_v29 : ADB shell opérationnel via magiskpolicy sepolicy patch. Display : kernel DRM CIP sain, userspace Android crash à diagnostiquer via logcat.*

## 40. Tentatives d'ADB via boot Android — v22 à v27 (12 avril 2026)

### Contexte
Recovery_v29 fonctionnelle pour les logs, mais l'objectif est d'obtenir ADB pendant le boot Android normal pour pouvoir analyser le crash HWComposer/SurfaceFlinger (cause de l'écran noir). Le mécanisme choisi : `androidboot.init_rc` dans le cmdline du boot.img pour charger un init.rc custom qui exécute `settings put global adb_enabled 1` après `sys.boot_completed=1`.

### boot_patched_v22
- **Cmdline** : `androidboot.init_rc=/first_stage_ramdisk/init.v22.rc`
- **init.v22.rc** : `import /init.rc` + `exec_background u:r:shell:s0 -- settings put global adb_enabled 1`
- **Problème au flash** : erreur "Error verifying vbmeta image" — oublié de reflasher `vbmeta_disabled.img` en même temps
- **Fix** : toujours flasher `--BOOT` ET `--VBMETA vbmeta_disabled.img` simultanément
- **Résultat** : hard reset utilisateur à ~18s (SDI dump "User press reset keys for 7 sec"). Logs insuffisants.

### boot_patched_v23
- **Cmdline** : sans `androidboot.init_rc`, ajout `androidboot.debug_level=0x4948`
- **Résultat** : Android boot ✓, USB MTP visible (04e8:6860), pas d'ADB. Debug level HIGH insuffisant.

### boot_patched_v24
- **Cmdline** : `androidboot.init_rc=/init.v22.rc` (path incorrect — racine système après SwitchRoot)
- **Log confirmé** : `init: Unable to read config file '/init.v22.rc': No such file or directory`
- **Résultat** : Android boot normal (600s+ d'activité confirmée), MTP visible, pas d'ADB
- **Découverte clé** : Samsung honore `androidboot.init_rc`. En cas d'ENOENT, init continue avec l'init.rc par défaut.

### boot_patched_v25
- **Cmdline** : `androidboot.init_rc=/first_stage_ramdisk/init.v22.rc` + `androidboot.selinux=permissive`
- **init.v22.rc** : `import /init.rc` + setprop + `exec_background u:r:shell:s0 -- settings put global adb_enabled 1`
- **Symptôme** : "Powered by Knox uniquement, jamais de logo Samsung"
- **Log CIP confirmé (ligne 14545)** : kernel 4.19.325 a bien démarré, SwitchRoot à t=14s. "Powered by Knox = pas de logo" = confusion avec l'écran noir habituel
- **Découverte** : `persist.sys.usb.config=mtp,adb` lu depuis recovery après ce boot → le trigger `on property:sys.boot_completed=1` a bien tiré ! `setprop persist.sys.usb.config mtp,adb` a fonctionné.
- **Mais** : `exec_background u:r:shell:s0 -- settings put` bloqué par SELinux
- **Découverte** : `androidboot.selinux=permissive` ignoré par Samsung — AVC denials toujours `permissive=0` en recovery

### boot_patched_v26
- **Cmdline** : `androidboot.init_rc=/first_stage_ramdisk/init.v22.rc` (sans `selinux=permissive`)
- **init.v22.rc** : même contenu + `exec_background u:r:init:s0` (contexte changé) + `write /data/local/tmp/adb_trigger_fired 1`
- **Log (lignes 16720-16721)** : `init: Parsing file /first_stage_ramdisk/init.v22.rc... Unable to read config file: No such file or directory`
- **Découverte critique** : Samsung ne bind-mount PAS l'ancien ramdisk à `/first_stage_ramdisk` après SwitchRoot. Le path ENOENT en v24 (racine système) et en v26 (first_stage_ramdisk) donnent tous deux ENOENT mais par des mécanismes différents.
- **Résultat** : pas d'USB visible côté host. Quand `androidboot.init_rc` pointe vers un fichier introuvable, Android init ne charge PAS de RC par défaut — aucune action USB n'est exécutée. (Différent de v24 où le path incorrect tombait différemment.)

### boot_patched_v27
- **Cmdline** : sans `androidboot.init_rc` — retour au boot Android normal
- **Résultat** : Android boot ✓, USB MTP visible (04e8:6860), ADB jamais visible
- **Confirmé** : `UsbDeviceManager` Java écrase `sys.usb.config` de `mtp,adb` → `mtp` avant qu'adbd soit prêt, parce que `adb_enabled=0` dans la settings DB

---

## 41. Découvertes techniques sur l'architecture Android init (12 avril 2026)

### Partitions dynamiques (super) — inaccessibles en recovery shell

La partition `vendor`, `system`, `odm`, `product` sont des **volumes logiques** dans la partition `super` (Android Dynamic Partitions). En recovery :
- Pas de `/dev/block/dm-*` disponibles (dm-linear non configuré par recovery init)
- Block device `/dev/block/bootdevice/by-name/super` : `brw-------` root only — inaccessible à uid=2000 shell
- Pas de `lptools`, `dmsetup`, `dmctl` disponibles dans le shell recovery
- Pas de `su`, pas de `magiskpolicy` dans le PATH recovery shell
- `/tmp`, `/cache` : création de fichiers bloquée par SELinux (shell context)

### Partitions statiques accessibles depuis Android init

`/prism` (`sda29`, ext4) et `/optics` (`sda30`, ext4) sont des partitions **statiques** (hors super), montées dès t=14.031s après SwitchRoot. Potentiellement utilisables comme vecteur d'injection init.rc — mais nécessitent root pour le montage depuis recovery.

### Séquence init après SwitchRoot (v26 log, kernel CIP)

```
t=14.011s  SwitchRoot to /system
t=14.019s  Mount /product (dm-2, ext4)
t=14.031s  Mount /vendor (dm-1, ext4)
t=14.037s  Mount /odm (dm-3, ext4)
t=14.043s  Mount /prism (sda29, ext4, statique)
t=14.049s  Mount /optics (sda30, ext4, statique)
t=14.225s  SELinux policy compilation (hash mismatch precompilé/compilé)
t=16.018s  SELinux policy chargée
t=17.410s  vendor/default.prop tente de set ro.adb.secure=1 → BLOQUÉ par SELinux
t=17.480s  Parsing androidboot.init_rc → ENOENT
t=17.484s  SetupCgroups (builtin)
t=23.264s  USB plug détecté (câble branché)
```

**Note importante** : `init: Do not have permissions to set 'ro.adb.secure' to '1'` — la politique SELinux compilée (non precompilée) bloque vendor/default.prop. `ro.adb.secure` reste à 0 (valeur du ramdisk prop.default).

### androidboot.selinux=permissive — inefficace sur Samsung

Testé en v25. Le paramètre est passé au kernel (`ro.boot.selinux=permissive` visible en recovery), mais Samsung's init l'ignore ou l'écrase. Les AVC denials en recovery montrent toujours `permissive=0`. **À ne pas utiliser.**

### Fenêtre ADB pendant boot Android — inexistante en pratique

Test avec v27 (boot Android normal, `persist.sys.usb.config=mtp,adb` confirmé) + monitoring agressif (`watch -n 0.2 lsusb; adb devices`) : USB visible uniquement comme MTP (04e8:6860), jamais comme ADB. `UsbDeviceManager` Java écrase la config avant qu'adbd puisse configurer le gadget USB. La "fenêtre ADB" n'est pas exploitable sans `adb_enabled=1` dans la settings DB.

---

## 42. Recherche communautaire — Docker/Containers sur Android (12 avril 2026)

> **Erratum E5** : ce passage a été corrigé depuis, voir les [errata](#errata) en tête du journal.

### Sources consultées
Gist FreddieOliveira (Docker natif Android), XDA S22/S21 FE, XDA Tab S7 kernel sources, GitHub gts9fe/gts7xllite, Reddit termux/docker, StackOverflow cgroups, Medium cgroups.

### Patch critique — `net/netfilter/xt_qtaguid.c` (OBLIGATOIRE sur kernel 4.19)

Sans ce patch, tout container qui tourne provoque un **kernel panic + reboot** immédiat. Samsung a conservé ce fichier dans leur fork 4.19 (supprimé upstream en 5.0, remplacé par eBPF).

**Fix** : dans `iface_stat_fmt_proc_read()`, supprimer la variable locale `dev_stats` et utiliser inconditionnellement `stats = &no_dev_stats` au lieu de déréférencer des stats potentiellement NULL.

### Patch — `kernel/Makefile`
Remplacer la référence au defconfig hardcodé par `$(KCONFIG_CONFIG)` pour que `check-config.sh` lise le `.config` réel compilé (sinon rapporte des faux positifs depuis l'ancien defconfig).

### CONFIGs Docker/Podman manquants potentiels dans notre build

À vérifier dans notre `.config` actuel :
```
CONFIG_CGROUP_PIDS=y, CONFIG_CGROUP_BPF=y, CONFIG_POSIX_MQUEUE=y, CONFIG_KEYS=y
CONFIG_IP_NF_MANGLE=y, CONFIG_IP6_NF_FILTER=y, CONFIG_IP6_NF_MANGLE=y, CONFIG_IP6_NF_NAT=y
CONFIG_NF_NAT_IPV4=y, CONFIG_NF_NAT_NEEDED=y, CONFIG_NETFILTER_XT_MATCH_IPVS=y
CONFIG_MEMCG_SWAP=y, CONFIG_BLK_CGROUP=y, CONFIG_BLK_DEV_THROTTLING=y
CONFIG_FAIR_GROUP_SCHED=y, CONFIG_CFS_BANDWIDTH=y, CONFIG_CGROUP_NET_PRIO=y
```
`CONFIG_CGROUP_BPF` requis kernel ≥ 4.15. `schedtune` est Samsung/EAS-spécifique, inclure si présent.

### Conflits Kconfig Samsung GPU/display
L'ajout de CONFIGs Docker peut provoquer des erreurs de compilation dans `drivers/gpu/arm/Kconfig` (lignes 27-29, 58) et `drivers/video/Kconfig` (lignes 40-52) — dépendances Samsung propriétaires conflictuelles. Éditer ces Kconfig si la compilation échoue.

### Architecture runtime containers
**Ne pas modifier init.rc pour les cgroups.** Utiliser un wrapper shell script lancé avant podman/dockerd :
```sh
for ctrl in blkio cpu cpuacct cpuset devices freezer memory pids schedtune; do
    mkdir -p /sys/fs/cgroup/$ctrl
    mountpoint -q /sys/fs/cgroup/$ctrl || mount -t cgroup -o $ctrl cgroup /sys/fs/cgroup/$ctrl
done
```
`schedtune` = contrôleur Samsung EAS, présent dans le kernel 4.19 Samsung, à inclure.

### Stockage et versions
- Data root : `/data/docker/` — **jamais** `/data/data/` ni chemins Termux (overlayfs échoue à cause des options de mount Android)
- **containerd ≤ v1.1.12 et runc ≤ v1.1.12** — versions supérieures bloquent indéfiniment sur Android 11+
- Réseau initial : `--net=host --dns=8.8.8.8` pour les premiers tests

---

## 43. Pivot stratégique — Retour à l'état 0 + TWRP (12 avril 2026)

### Pourquoi on en est arrivés là

Le plan original était simple : remplacer le kernel Samsung par notre kernel CIP 4.19 avec les CONFIGs containers. Android devait continuer à booter normalement.

**Problème inattendu** : le kernel CIP 4.19.325 provoque un écran noir (crash HWComposer/SurfaceFlinger — `panel_node not found` dans DTS). Sans écran, impossible d'activer les options développeur → ADB via l'UI. Tout le travail de recovery patché, boot patché (v1→v27), tentatives init.rc d'injection ADB est de l'infrastructure de debug pour compenser ce problème d'écran — pas du travail sur les containers eux-mêmes.

Les gens qui ont réussi Docker/containers sur Android (Freddie, XDA) avaient tous soit TWRP, soit Magisk déjà installés AVANT le travail kernel, ce qui leur donnait root et ADB d'emblée. Leur écran fonctionnait, ils activaient ADB via l'UI normalement.

### Erreur initiale sur TWRP

Au tout début du projet, TWRP a été écarté car impossible d'entrer en Download Mode. La procédure correcte pour SM-T970 (non documentée clairement) :
- Éteindre complètement
- Maintenir **Volume Bas + Volume Haut + Power** simultanément
- Écran "Warning" → appuyer **Volume Haut** pour confirmer Download Mode
- (Ou selon firmware : maintenir vol- puis rappuyer vol- au menu)

### Décision : retour à l'état 0

1. **Flasher le boot.img stock** → écran fonctionne, Android normal
2. **vbmeta_disabled.img conservé** — INDISPENSABLE : sans ça le bootloader rejette TWRP (non signé Samsung)
3. **Flasher TWRP en recovery** → shell root en recovery → peut monter/modifier toutes partitions
4. **Activer options développeur via l'UI** → ADB permanent
5. **Magisk via TWRP** → root Android → `adb shell su` possible
6. **Depuis là** : flasher notre kernel CIP avec les CONFIGs containers, diagnostiquer l'écran noir via logcat

### État au moment de la décision

- boot.img stock flashé ✓ → écran fonctionne ✓
- Android 13 OneUI 5.1 operationnel ✓
- Wi-Fi configuré (pas obligatoire pour ADB, mais sans risque)
- TWRP disponible : `twrp-gts7xl-3.6.0_11-A12-1a7_ianmacd.img` (67MB, format bootimg valide, cmdline SM-T970 confirmé)
- `gts7xl` = codename Tab S7+ = SM-T970/T976 ✓

---

## 44. Installation TWRP + Magisk (13 avril 2026)

### Contexte TWRP

Seul build communautaire disponible pour SM-T970 : `twrp-gts7xl-3.6.0_11-A12-1a7_ianmacd.img` (A12, pas de build A13).
- Pas de TWRP officiel pour gts7xl sur dl.twrp.me
- ianmacd/twrp_gts7xl sur GitHub n'a pas de releases publiées
- Build A12 confirmé fonctionnel pour flasher Magisk sur Android 13 (FBE /data non déchiffrable depuis TWRP, mais pas nécessaire pour notre usage)

### Flash TWRP

```bash
adb reboot download
heimdall flash --RECOVERY downloads/twrp-gts7xl-3.6.0_11-A12-1a7_ianmacd.img --no-reboot
adb reboot recovery
```

TWRP démarre correctement. Écran TWRP accessible, navigation fonctionnelle.

### Problème ADB Sideload dans TWRP

**Symptôme** : dès que le mode "ADB Sideload" est démarré dans TWRP (après le swipe), la tablette disparaît complètement de `lsusb` et `adb devices`. Impossible de lancer `adb sideload`.

**Cause** : TWRP reinitialise le sous-système USB en passant en mode sideload, et ce mode ne s'initialise pas correctement sur ce device.

**Comportement normal** : en dehors du mode sideload, la tablette apparaît bien :
```
adb devices → R52N•••••••    recovery
```

**Solution** : utiliser `adb push` vers `/tmp/` (toujours monté en recovery), puis installer depuis TWRP → Install en naviguant vers `/tmp/`.

```bash
adb push Magisk-v30.7.apk /tmp/Magisk.apk
# Puis TWRP → Install → /tmp/ → Magisk.apk → flash
```

Note : `/sdcard` inaccessible (`Invalid argument`) car FBE Android 13 non déchiffré. `/tmp/` fonctionne.

### Installation Magisk via TWRP

Flash de `/tmp/Magisk.apk` dans TWRP :
- Erreurs `Permission denied` sur `/data` → normal (FBE chiffré)
- Magisk détecte bien : stock boot image, system-as-root, arm64-v8a
- Patch ramdisk + repack boot image + flash partition boot → **OK**
- Warning : `Unable to find preinit dir` → mineur, non bloquant sur Samsung

### Reinstallation complémentaire depuis Android

Au premier démarrage Android, l'app Magisk affiche :
> "Installation supplémentaire requise — votre périphérique nécessite de réinstaller Magisk par l'application, le mode de récupération ne pouvant pas récupérer les informations correctement."

Cause : le warning `preinit dir` de l'étape précédente. Fix : dans l'app Magisk → **Installer** → **Installation directe (recommandée)**. Redémarrage automatique.

### Root confirmé

```
adb shell su -c "id"
→ uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
```

Magisk v30.7 (30700), Zygisk Non, Ramdisk Oui.

Note : la première tentative `su` a été refusée (popup root auto-refusée après timeout). Fix : Magisk → Superuser → supprimer l'entrée Shell → relancer la commande et accepter rapidement.

---

## 45. Reprise du kernel CIP avec root disponible (13 avril 2026)

### Situation

- Boot stock Samsung + Magisk → écran ✓, root ✓, ADB ✓
- Kernel CIP v21 toujours incomplet : manque CONFIGs containers + patch xt_qtaguid
- Prochaine étape : diagnostiquer le black screen avec root disponible

### Ordre des priorités

1. **Black screen** : sans écran fonctionnel sur le CIP kernel, Android inutilisable — diagnostic en premier
2. **CONFIGs containers + xt_qtaguid** : s'ajouteront dans le même build que le fix DRM

### Workflow Magisk + kernel CIP

À chaque nouveau kernel build, **ne pas flasher directement** — passer par Magisk :
1. `adb push boot_nouveau.img /sdcard/boot_cip.img`
2. App Magisk → Installer → Patch a file → sélectionner le fichier
3. `adb pull /sdcard/Download/magisk_patched_*.img boot_cip_magisk.img`
4. `adb reboot download && heimdall flash --BOOT boot_cip_magisk.img`

TWRP reste intact (partition recovery, jamais écrasée). Pas besoin de refaire l'installation complète TWRP+Magisk à chaque nouveau kernel.

### Diagnostic black screen — en cours

boot_patched_v21.img patché via Magisk → `boot_cip_magisk_v21.img` (25247744 bytes).
Flash en cours au moment de la rédaction. Objectif : récupérer logcat DRM avec `adb shell su -c "logcat"` malgré l'écran noir.

---

---

## 46. Diagnostic black screen — cause identifiée : hall_ic_wacom (13 avril 2026)

### Symptôme

Avec le kernel CIP, l'écran reste noir dès le boot. Poser le S Pen dans son slot de la Book Cover provoque un écran noir permanent. Retirer le S Pen permet de rallumer. Fermer physiquement la Book Cover (la partie écran, pas le clavier) fait la même chose.

### Investigation

Logs pstore/ramdisk analysés → pas de DRM NULL attachment. L'erreur DRM initiale (v1–v20) était une fausse piste. Le vrai problème est dans le driver `hall_ic_wacom`.

**Séquence de démarrage problématique :**
- t=0s : kernel probe `hall_ic_wacom` → lit GPIO → S Pen dans slot = GPIO 0 → `hall_wacom_status = 0` (CLOSE)
- t=46.8s : `PowerManagerService` Android lit sysfs `hall_wacom_detect` → voit "CLOSE" → déclenche `cover_close` → écran éteint
- t=49.8s : Android établit `coverType=0` (pas de cover) → trop tard, l'écran est déjà éteint

**Pourquoi SW_MACHINE_COVER n'aide pas :** Samsung lit le sysfs directement (`mFeatureCoverSysfs: true`), ignore les événements input.

**Fichier concerné :** `sources/drivers/input/keyboard/hall_ic_wacom.c`

Dans `init_hall_ic_wacom_irq()`, la lecture GPIO au probe :
```c
// AVANT (ligne 120, problématique) :
hall_wacom_status = gpio_get_value(ddata->gpio_wacom_cover);
```

Avec le S Pen dans son slot, cette valeur est 0 = CLOSE. `hall_wacom_status` initialisée à 1 (OPEN, ligne 38) est écrasée.

### Fix appliqué

Suppression de la lecture GPIO au probe. La valeur par défaut `hall_wacom_status = 1` (OPEN) est conservée jusqu'à ce que `wacom_hall_open` se déclenche (500ms après l'ouverture du device Android, quand `coverType=0` est déjà établi).

```c
// APRÈS — commentaire explicatif à la place de la lecture GPIO :
/* Do not read GPIO at init: Samsung Android reads hall_wacom_detect sysfs
 * early (t~46s) before coverType=0 is established (t~49s). Reading GPIO
 * here with S Pen in slot gives hall_wacom_status=0 (CLOSE), which
 * triggers a spurious cover_close sleep. Keep initial value=1 (OPEN)
 * so Android sees OPEN until wacom_hall_open fires (500ms after Android
 * opens the device, when coverType=0 is already known). */
INIT_DELAYED_WORK(&ddata->wacom_cover_dwork, wacom_cover_work);
```

---

## 47. Rebuild kernel CIP v22 + flash (13 avril 2026)

### CONFIGs containers vérifiés

Avant le rebuild, vérification via le script officiel Docker `check-config.sh` : **49/50 CONFIGs présents**. Manquant :
- `CONFIG_IP_VS` et sous-options (IP_VS_NFCT, IP_VS_PROTO_TCP/UDP, IP_VS_RR)

Ajoutés manuellement dans `output/.config`. Ces options concernent le load balancing IPVS — utile pour kind/k3s, pas indispensable pour Podman seul.

Après `make olddefconfig` (résolution des nouvelles dépendances sans prompt interactif) : **50/50**.

### Build

Commande (dans le conteneur Podman `sm8250-builder`) :
```bash
podman exec sm8250-builder make -C /work/sources -j$(nproc) O=/work/output ARCH=arm64 LLVM=1 LLVM_IAS=1 Image.gz
```

**Erreur rencontrée :** Makefile DTS référençait des DTBs IoT/RB5 manquant un fichier `kona-camera-sensor-rb5-nopop.dtsi`. Fix : suppression des 7 entrées DTB concernées dans `sources/arch/arm64/boot/dts/vendor/qcom/Makefile`.

Build réussi, **13 avril 2026 18:24**.

### Assemblage boot.img

**Erreur initiale :** utilisation de `Image-dtb` (78MB non compressé + tous les DTBs) → `boot_patched_v22.img` = 80MB → `ERROR: BOOT partition is too small`.

**Cause :** `Image.gz-dtb` concaténait 49 DTBs (×~500KB = 24MB supplémentaires) en plus du kernel compressé (22MB) = 45MB → encore trop grand.

**Solution correcte :** avec `--header_version 2`, le DTB est dans une section séparée du boot.img. Le kernel doit être `Image.gz` seul (22MB). Le DTB stock est passé via `--dtb`.

```bash
mkbootimg \
  --kernel output/arch/arm64/boot/Image.gz \
  --ramdisk /tmp/boot_stock_info/boot.img-ramdisk \
  --dtb /tmp/boot_stock_info/boot.img-dtb \
  --cmdline "console=null androidboot.hardware=qcom androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 printk.devkmsg=on firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7" \
  --base 0x00000000 --pagesize 4096 \
  --kernel_offset 0x00008000 --ramdisk_offset 0x02000000 \
  --tags_offset 0x01e00000 --dtb_offset 0x01f00000 \
  --os_version 11.0.0 --os_patch_level 2024-08 \
  --header_version 2 \
  --output output/firmware/boot_patched_v22.img
```

Résultat : `boot_patched_v22.img` = **24MB** ✓ (même taille que v21).

### Flash

```bash
adb push output/firmware/boot_patched_v22.img /sdcard/Download/boot_v22.img
# Magisk → Installer → Sélectionner et patcher un fichier → boot_v22.img
adb pull /sdcard/Download/magisk_patched_*.img output/firmware/boot_cip_magisk_v22.img
heimdall flash --BOOT output/firmware/boot_cip_magisk_v22.img --no-reboot
heimdall reboot
```

### Résultat

Android boot ✓ — écran visible. **Mais : le problème de cover reste.** Fermer la Book Cover (partie stylet) éteint l'écran et il est impossible de le rallumer sans rouvrir le cover. Le fix `hall_ic_wacom.c` n'a pas résolu le problème : soit le comportement vient d'un autre driver, soit d'un autre mécanisme Android.

**À investiguer** → section suivante.

---

---

## 48. Diagnostic cover — vraie cause identifiée (14 avril 2026)

> **Erratum E6** : ce passage a été corrigé depuis, voir les [errata](#errata) en tête du journal.

### Contexte

Après le flash v22, le problème "capot magnétique → écran éteint + bouton power inopérant" persistait. Le fix kernel `hall_ic_wacom.c` (section 46) n'a rien changé parce qu'il ciblait le mauvais problème (race condition au boot). Le vrai problème est en cours de fonctionnement, pas au démarrage.

### Investigation via ADB + Magisk root

Avec root Magisk opérationnel, capture des événements d'entrée en direct :

```bash
adb shell su -c "getevent -l" | grep -E "SW_|KEY_POWER|hall"
```

Trois devices hall distincts identifiés :
- `hall` (capteur principal)
- `hall_logical` (agrégat virtuel)
- `hall_wacom` (capteur S Pen / capot arrière)

Événements observés :
- `event12` (hall_wacom) : `SW_MACHINE_COVER` toggle 0↔1 selon aimant
- `event6` : `SW_PEN_INSERTED` toggle pour le stylet (device séparé)

Le capteur déclenche `SW_MACHINE_COVER=1` dès que l'aimant du capot arrière touche la tablette — y compris quand le S Pen est sorti et utilisé en main.

### Analyse logcat → vraie cause

Capture logcat pendant la manipulation :

```
D/PowerManagerService: !@Screen__On : Cancel (coverType: 0)
D/SEP_UNION_CoverManager: sendPowerKeyToCover
```

Séquence complète :
1. `SW_MACHINE_COVER=1` → `SEP_UNION_CoverManager` détecte cover attaché (coverType=0 = Book Cover générique)
2. Bouton power pressé → `PhoneWindowManager.interceptKeyTq keycode=26 interactive=false interceptKeyResult=8` (key bien reçu)
3. `PowerManagerService.wakeUp()` appelé correctement
4. **Annulation immédiate** par Samsung : `!@Screen__On : Cancel (coverType: 0)`
5. Le power key est routé vers `sendPowerKeyToCover` qui, pour coverType=0, ne fait rien

**Cause réelle : 100% framework Android Samsung, pas kernel.**

L'extension `SEP_UNION_CoverManager` dans `PowerManagerService.java` contient une logique qui supprime le wakeup via bouton power quand un cover est attaché (coverType ≠ -1). L'intention Samsung : avec un Book Cover, l'utilisateur doit ouvrir le cover pour réveiller le device, pas appuyer sur power. Pour un cover "Generic" (type 0), aucun mécanisme de réveil alternatif n'est implémenté → device bloqué jusqu'à réouverture physique.

### Pourquoi ça marchait avec le kernel Samsung stock ?

Hypothèse la plus probable : avec le firmware stock untouched, `coverType` restait à -1 parce que l'utilisateur n'avait jamais déclenché `SW_MACHINE_COVER=1` dans cette session. Les flashes successifs du projet ont laissé le cover "attaché" dans la mémoire persistante de `SEP_UNION_CoverManager`, le seuil franchi une fois reste franchi.

### Résolution retenue

Deux fixes possibles envisagés :
1. **Kernel** — retirer la capacité `SW_MACHINE_COVER` de l'input device `hall_wacom` → CoverManager ne voit plus le cover → `coverType=-1` → power button fonctionne
2. **Framework** — patcher `services.jar` pour ne pas supprimer le wakeup sur `coverType=0`

Mais l'utilisateur possède un Book Cover Keyboard (non branché pendant les tests) qui nécessite la détection SW_MACHINE_COVER pour son fonctionnement légitime. L'option 1 briserait cette fonctionnalité.

**Workaround Android-level retenu** : désactivation du verrouillage automatique dans les paramètres Samsung. Acceptable comme compromis — l'utilisateur appuiera sur power manuellement au lieu de compter sur l'auto-lock.

---

## 49. Validation du kernel qui tourne sur la tablette (14 avril 2026)

### Réglage 120Hz

L'utilisateur constatait du lag. Inspection via ADB root :

```bash
adb shell su -c "dumpsys display"
```

Résultats :
```
supportedModes [
  {id=1, 1752x2800, fps=120.00001, alternativeRefreshRates=[60.000004]},
  {id=2, 1752x2800, fps=60.000004, alternativeRefreshRates=[120.00001]}
]
mActiveModeId=2  (60Hz)
primaryRefreshRateRange=[60 60]
```

**Le kernel supporte parfaitement les deux modes.** Le display tournait à 60Hz parce que le mode économie d'énergie Samsung était activé par défaut après factory reset. Désactivé côté Android → 120Hz restauré.

### Vérification exhaustive des CONFIGs kernel

Extraction de la config du kernel en fonction sur l'appareil (`/proc/config.gz` exposé grâce à `CONFIG_IKCONFIG_PROC=y`) :

```bash
adb shell su -c "zcat /proc/config.gz" > /tmp/running-kernel-config.txt
bash /tmp/check-config.sh /tmp/running-kernel-config.txt
```

**Piège rencontré** : le script Docker `check-config.sh` exécuté directement sur Android via `adb shell su` échoue ("zcat: not gzip" en boucle) à cause des différences busybox. Il faut l'exécuter en local sur le PC contre le fichier de config préalablement extrait.

### Résultats check-config.sh

**Generally Necessary (100% ✓)** :
- Cgroup hierarchy cgroupv2 — tous les controllers disponibles (cpu, cpuset, io, memory, pids)
- Namespaces : NAMESPACES, NET_NS, PID_NS, IPC_NS, UTS_NS
- Cgroups : CGROUPS, CGROUP_CPUACCT, CGROUP_DEVICE, CGROUP_FREEZER, CGROUP_SCHED, CPUSETS, MEMCG, CGROUP_BPF
- Réseau : VETH, BRIDGE, BRIDGE_NETFILTER, IP_NF_* complet, IP6_NF_* complet, NF_NAT, NETFILTER_XT_MATCH_*
- Divers : KEYS, POSIX_MQUEUE

**Optional Features (tous activés sauf 2)** :
- USER_NS, SECCOMP, SECCOMP_FILTER ✓
- CGROUP_PIDS, MEMCG_SWAP, BLK_CGROUP, BLK_DEV_THROTTLING ✓
- CGROUP_PERF, NET_CLS_CGROUP, CGROUP_NET_PRIO, CFS_BANDWIDTH, FAIR_GROUP_SCHED ✓
- IP_VS + IP_VS_NFCT + IP_VS_PROTO_TCP/UDP + IP_VS_RR ✓
- SECURITY_SELINUX, SECURITY_APPARMOR ✓
- NFT_* complet, NF_TABLES ✓
- EXT4_FS + POSIX_ACL + SECURITY ✓

**Manquants non bloquants** :
- `CONFIG_CGROUP_HUGETLB` — hugepages, inutile sur tablette
- `CONFIG_BRIDGE_VLAN_FILTERING` — réseau overlay chiffré, optionnel

**Network/Storage drivers** :
- VXLAN, IPVLAN, MACVLAN, DUMMY ✓
- CRYPTO complet (AEAD, GCM, SEQIV, GHASH), XFRM (USER, ALGO), INET_ESP ✓
- NF_NAT_FTP/TFTP, NF_CONNTRACK_FTP/TFTP ✓
- BTRFS_FS + POSIX_ACL ✓
- **OVERLAY_FS ✓** (critique pour Podman)

**Limits** :
- `/proc/sys/kernel/keys/root_maxkeys` : 1000000 ✓ (au-dessus du minimum 10000 requis)

### État final du kernel CIP v22

**Le kernel qui tourne actuellement sur la tablette expose l'intégralité de l'environnement nécessaire à Podman** :
- Tous les namespaces (dont USER_NS)
- Cgroups v2 complet
- OverlayFS
- Netfilter + NAT + Bridge + IP_VS
- BTRFS, SECCOMP, APPARMOR, SELinux

**Conclusion étape kernel** : objectif atteint. Le kernel CIP 4.19.325 avec toutes les CONFIGs containers est opérationnel sur la tablette. Android 13 OneUI 5.1 fonctionne correctement. Magisk root actif. ADB fonctionnel.

Prochaine étape : setup de l'environnement userland (Podman + affichage graphique) — indépendant du travail kernel, traité dans une phase séparée.

---

*Document mis à jour le 14 avril 2026 — kernel CIP v22 validé en production sur la tablette, 50/52 CONFIGs containers présents (les 2 manquants sans impact), cover réglé via workaround Android, 120Hz actif. Phase kernel du projet : complète.*

---

## 50. Phase userland : Podman sur Android — limites rencontrées et pivot vers LXC

### Objectif
Faire tourner Podman dans une distro Linux complète sur la tablette (apt/yum), avec conteneurs persistants (nginx, etc.) en plus d'un desktop graphique.

### Chemin suivi
1. **Termux + proot-distro + Ubuntu 25.10** installé → fonctionnel mais proot (ptrace) bloque `clone(CLONE_NEWUSER)` → Podman échoue sur "cannot clone: Operation not permitted".
2. **Pivot vers chroot réel via Magisk root** — nécessaire pour utiliser les vrais appels kernel.
3. Setup chroot dans Termux su :
   - `pkg install mount-utils` (⚠ nom du package Termux — **pas** `util-linux` qui n'existe pas dans les repos Termux). Fournit le vrai `mount` supportant `--make-rprivate`, absent de busybox/toybox.
   - `unshare -m /bin/bash` → nouveau mount namespace.
   - `mount --make-rprivate /` dans ce namespace avant chroot.
   - `chroot /data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu /bin/bash`.
   - Setup dans le chroot : PATH, `/proc`, `/sys`, `/dev` (bind), `/dev/pts`, `/dev/shm`, `/run`, `unset TMPDIR`.
4. **Storage driver** : `overlay` sur f2fs Android dans chroot casse (mountopt mismatch) → forcé `vfs` via `/etc/containers/storage.conf` (`driver = "vfs"`). Lent mais fonctionnel.

### Résultat Podman
- `podman version`, `podman pull`, `podman images` → OK.
- `podman run --rm hello-world` → **échec** systématique à l'extraction de layer :
  ```
  ApplyLayer stderr: remount /, flags: 0x44000: invalid argument
  ```
  (0x44000 = MS_REC | MS_PRIVATE)
- Reproduit avec runc **et** crun (Ubuntu 25.10 default = crun).

### Cause racine (vérifiée via thread upstream)
Références :
- https://github.com/containers/podman/issues/22680
- https://github.com/containers/podman/discussions/22739

Le VFS Linux refuse le `remount /` avec ces flags quand le process est dans un chroot dont le mount racine est partagé avec le namespace parent. **Ce n'est pas une option kernel désactivable** — c'est une logique VFS en dur (pas un `CONFIG_*`). Les CONFIGs containers sont toutes présentes et activées, ça ne suffit pas : l'architecture chroot+runc/crun est incompatible avec Android, point.

Citation du mainteneur Podman : *« there are some kernel checks that just prevent doing some stuff from such environment »*. Issue fermée sans fix — limitation architecturale.

### Décision : pivot vers LXC
LXC utilise `pivot_root` (pas remount /) → échappe à la restriction. Il consomme exactement les mêmes CONFIGs kernel qu'on a construites (namespaces, cgroups v2, overlayfs, veth, bridge, netfilter, xt_qtaguid patch). **Le travail kernel reste intégralement utile.**

Architecture cible :
```
Android
└─ Termux (su Magisk)
    └─ chroot Ubuntu 25.10
        └─ conteneur LXC "linuxbox" (vrai rootfs, namespaces propres)
            ├─ services natifs LXC (nginx, etc.)
            └─ Podman imbriqué (plus dans un chroot → remount / autorisé)
```

### Limites à retenir pour la documentation finale
| Limite | Cause | Contournement |
|---|---|---|
| proot bloque namespaces | ptrace intercepte `clone()` | chroot réel via Magisk root |
| busybox/toybox `mount` ne connaît pas `--make-rprivate` | implémentations minimales | `pkg install mount-utils` (nom Termux ≠ util-linux) |
| overlay storage driver casse sur f2fs dans chroot | xattr/mount options incompatibles | forcer `vfs` dans storage.conf |
| `podman run` échoue à `remount /` dans chroot | logique VFS Linux, SELinux enforcing Android | **LXC** (pivot_root au lieu de remount) |
| Podman direct sur Android chroot | incompatible architecturalement | Podman **imbriqué dans LXC** |

### CLI conséquence
- LXC a sa propre CLI (`lxc-create`, `lxc-start`, `lxc-attach`) non compatible Podman/Docker.
- Pour garder `podman run` : lancer Podman **dans** un conteneur LXC.

---

*Mise à jour 14 avril 2026 — Phase userland : Podman direct sur chroot Android abandonné (limite VFS/kernel non-contournable), bascule vers LXC qui réutilise 100 % des CONFIGs kernel. Prochaine étape : `lxc-checkconfig` et création du premier conteneur.*

---

## 51. Phase userland (suite) : échec LXC en chroot FBE — pivot vers runtime natif Termux

### Contexte après section 50
Après avoir acté que Podman/runc/crun en chroot bute sur `remount /, flags: 0x44000`, on avait choisi LXC comme alternative (pivot_root au lieu de remount). Cette section documente la tentative LXC, ses échecs propres, et le pivot final vers l'approche "runtime conteneur natif Termux sans chroot".

### Ce qui a été tenté pour LXC

**Setup chroot Ubuntu renforcé** (`scripts/enter-ubuntu.sh`) pour permettre pivot_root :
```sh
unshare -m /bin/sh
mount --make-rprivate /
mount --bind $UBUNTU $UBUNTU       # rend / un vrai mountpoint, requis par pivot_root
chroot $UBUNTU /bin/bash
# puis mount /proc, /sys, /dev (bind), /dev/pts (newinstance+ptmxmode), /dev/shm, /run, /sys/fs/cgroup (cgroup2)
# + symlink /dev/pts/ptmx → /dev/ptmx pour PTY fonctionnel (script -q, lxc-console)
```

Package Termux requis : `mount-utils` (⚠ pas `util-linux` — nom absent des repos Termux) pour un `mount` supportant `--make-rprivate`.

**Premier succès partiel** : avec cette préparation,
- `lxc-create -n test -t download --dist debian --release bookworm --arch arm64` → OK
- `lxc-checkconfig` → tout vert (cgroup2 monté, USER_NS, veth, bridge, netfilter, FUSE, checkpoint/restore)
- Premier démarrage avec `lxc.seccomp.profile = ` (seccomp vidé) + `00-lxcfs.conf` désactivé → `lxc-ls -f` affichait **RUNNING + IPv4 192.168.1.x + IPv6**. systemd exit 127 quelques instants après (pas surprenant sans cgroup delegation ni lxcfs), mais le conteneur avait démarré, réseau OK.

**Dégradation entre sessions** : après redémarrage ADB et ré-entrée dans le chroot, même config → plus moyen de faire démarrer le moindre conteneur. Erreur constante :
```
ERROR start - ../src/lxc/start.c:start:2209 - Required key not available - Failed to exec "/sbin/init"
```
Reproduit avec `lxc.init.cmd = /bin/sleep 3600` et `= /bin/bash` — ENOKEY sur **tout** exec après pivot_root.

### Diagnostic ENOKEY

Pistes testées et éliminées :
| Hypothèse | Action | Résultat |
|---|---|---|
| lxcfs hook manquant | `mv 00-lxcfs.conf 00-lxcfs.conf.disabled` | ENOKEY persiste à l'étape suivante (init) |
| Seccomp trop strict | `lxc.seccomp.profile =` (vide) | ENOKEY persiste |
| Drop de capabilities | `lxc.cap.drop =` (vide) | ENOKEY persiste |
| SELinux enforcing | `setenforce 0` depuis Magisk (Permissive confirmé) | ENOKEY persiste |
| Session keyring isolé | `lxc.keyring.session = 0` | ENOKEY persiste |
| Binaire cassé | `chroot /var/lib/lxc/test/rootfs /sbin/init --version` direct | ✓ exécute systemd ("Couldn't find telinit" = OK, binaire OK) |

Le fait que `chroot + exec` marche depuis le shell Ubuntu alors que `lxc-start` échoue pointe une perte de contexte **entre fork/clone et execve** dans le processus enfant LXC. Le rootfs du conteneur vit sous `/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/ubuntu/var/lib/lxc/test/rootfs`, donc entièrement dans la zone **FBE CE (credential-encrypted)** liée au UID Termux. La clé fscrypt est dans le keyring du process parent, mais pas dans celui de l'enfant LXC après sa séquence de préparation (unshare user+mount, drop groups, pivot_root, drop caps).

Kernel.org fscrypt doc + issues google/fscrypt#128, lxc/lxc#4461, lxc/lxd#6107 confirment : ENOKEY sur exec dans un conteneur quand le rootfs est sur un filesystem fscrypt dont la clé n'est pas accessible au contexte enfant. Pas de fix officiel côté LXC, la recommandation est de ne pas placer le rootfs conteneur sous fscrypt.

### Pourquoi la première session LXC avait-elle marché ?

Hypothèse la plus probable : lors du premier démarrage, le keyring du process parent était "frais" (juste après login Termux, fscrypt key récemment ajoutée par le loader Android). Ré-entrée ultérieure → keyring session différent, clé inaccessible dans le sous-contexte LXC. Comportement non-déterministe et non-reproductible = incompatible avec l'exigence "setup scriptable" du projet.

### Conclusion : le chroot FBE est un cul-de-sac pour les runtimes conteneur

Tout runtime qui fait pivot_root + drop caps/groups + execve depuis un rootfs situé sous `/data/data/com.termux/...` va buter soit sur :
- `remount /` (runc, crun — Podman/Docker)
- `ENOKEY` (LXC après pivot_root)

Sources consultées pour valider l'impasse :
- https://github.com/containers/podman/issues/22680
- https://github.com/containers/podman/discussions/22739
- https://github.com/lxc/lxc/issues/4461
- https://github.com/google/fscrypt/issues/128
- https://github.com/meefik/linuxdeploy/issues/1099
- https://www.kernel.org/doc/html/latest/filesystems/fscrypt.html

### Décision : pivot vers runtime natif Termux (pas de chroot pour le daemon)

Référence positive : https://ivonblog.com/en-us/posts/sony-xperia-5-ii-docker-kernel/ — Docker tourne sur Android avec kernel custom + xt_qtaguid patché (on l'a) **sans chroot**, directement dans Termux en Magisk root, data dir sur `/data/docker` (zone DE, hors FBE Termux CE).

Architecture retenue :
```
Android 13 (kernel CIP 4.19 custom)
└─ Magisk su
    └─ Termux (processus root Android, aucun chroot)
        ├─ podman/dockerd (process direct)
        │   ├─ data-root = /data/docker  (hors FBE Termux)
        │   └─ storage-driver overlay2 (fallback vfs)
        └─ conteneurs (nginx, apps rust/ts, …)
```

Ordre de préférence (user) : **Podman** (pods/kind) > Docker (fallback).

Le chroot Ubuntu reste conservé comme environnement de dev "vrai Linux" (apt, compilateurs) mais n'héberge plus aucun runtime conteneur.

### Fichiers / assets liés à cette phase
- `scripts/enter-ubuntu.sh` : conservé pour usage dev (apt), pas pour conteneurs
- Conteneur LXC `test` : sera détruit (`lxc-destroy -n test`)
- Scripts à produire (phase suivante) : `mount-cgroups.sh`, `start-docker.sh` ou équivalent podman, `setup.sh` one-shot, config `/data/docker/daemon.json` ou `containers.conf`

---

*Mise à jour 14 avril 2026 — LXC en chroot sur FBE abandonné (ENOKEY non-déterministe, non-reproductible), pivot définitif vers runtime conteneur natif Termux root sans chroot, data dir `/data/docker`. Préférence Podman puis Docker fallback.*

---

## 52. Docker fonctionnel — bout en bout (15 avril 2026)

### Résultat
`docker run --rm --net=host hello-world` s'exécute avec succès sur SM-T970, kernel CIP 4.19 custom, Android 13 + Magisk root. Docker 27.3.1 + containerd 1.7.22 + runc 1.1.14, tous en binaires statiques aarch64 officiels (`docker-27.3.1.tgz`).

### Chemin d'installation final

**Fichiers produits** :
| Chemin | Rôle |
|---|---|
| `scripts/mount-cgroups.sh` | Monte cgroup v1 (blkio/cpu/cpuacct/cpuset/devices/freezer/memory/schedtune). `pids` non supporté (non bloquant). |
| `scripts/containerd-config.toml` | Override tous les chemins `/run/*` et `/var/lib/*` hardcodés → `/data/docker/containerd-{root,state}` |
| `scripts/daemon.json` | `data-root=/data/docker`, `storage-driver=overlay2`, `iptables=false`, `bridge=none`, `ip-masq=false`, DNS 8.8.8.8/1.1.1.1 |
| `scripts/start-docker.sh` | Lance containerd puis dockerd, avec bind-mounts pour les `/run/*` non-configurables |
| `scripts/setup-docker.sh` | One-shot depuis PC : push binaires + scripts + config |
| `output/docker-binaries/docker-27.3.1.tgz` | Binaires officiels docker.com/linux/static/stable/aarch64/ |

### Fausses pistes corrigées dans cette phase

| Problème rencontré | Cause | Fix |
|---|---|---|
| `pkg install podman` → `Sike Error: Cannot run 'pkg' as root` | Termux `pkg` refuse root | N/A, Podman absent des repos Termux de toute façon → pivot binaires statiques |
| `pkg install docker` absent | Non packagé | Binaires statiques `docker-27.3.1.tgz` depuis docker.com |
| `containerd: mkdir /run: read-only filesystem` | rootfs Android `/` ro, `/run` inexistant | Passe 1 : `mount -o rw,remount / && mkdir /run && mount -o ro,remount /` |
| `containerd-config.toml` ignoré : `/run/containerd` toujours utilisé | Chemin hardcodé dans certains composants (pas couvert par `state=`) | Bind-mount `/data/docker/run-containerd` → `/run/containerd` |
| `dockerd: mkdir /run/docker: read-only filesystem` | Même problème côté dockerd (plugin manager) | Bind-mount `/data/docker/run-docker` → `/run/docker` |
| `failed to bind /var/run/docker.sock` | `/var/run` inexistant sur Android | Flag CLI `-H unix:///data/docker/docker.sock` (on ne passe plus par `/var/run`) |
| `exec-root` / `pidfile` conflict entre daemon.json et CLI | Dupliqués | Gardés côté CLI uniquement |
| `pkill -f dockerd` tuait le script lui-même | `-f` matche toute la cmdline, script contient "dockerd" | Remplacé par `pidof dockerd` (basename exact) |
| `pgrep -f "dockerd"` false-positive "already running" | Idem, matche le wrapper | `pidof dockerd` |
| `lookup registry-1.docker.io on [::1]:53: connection refused` | Pas de `/etc/resolv.conf` sur Android | `printf "nameserver 8.8.8.8\n..." > /etc/resolv.conf` (après `remount rw /`) |
| `tls: certificate signed by unknown authority` | Pas de CA bundle | `adb push /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/` (bundle Arch Linux, 222 KB) |
| CRI plugin `failed to create cni conf monitor: mkdir /etc/cni: ro-fs` | Plugin CRI Kubernetes tente `/etc/cni` | Warning non-bloquant — le daemon démarre quand même |

### Warnings non-bloquants au démarrage

```
WARNING: No memory limit support
WARNING: No swap limit support
WARNING: No cpu cfs quota/period/shares support
WARNING: No cpuset support
WARNING: No io.weight/max support
cgroup pids: mount failed (may be unsupported on this kernel, continuing)
```
→ Limitations cgroup v1 + kernel Samsung 4.19 sans certains contrôleurs. Docker run OK malgré ces absences.

### Leçons transférables

1. **`/run` et `/etc` sont en lecture seule sur Android** : tout ce qu'un daemon Linux y écrit doit être bind-mounté depuis `/data/...` (zone writable). Un simple `remount rw` + `mkdir` suffit pour créer le point de montage, mais les écritures ultérieures du daemon se feront toujours via le bind sur `/data`.
2. **Les config files ne couvrent pas tous les chemins hardcodés** : containerd accepte `state=` mais garde quand même `/run/containerd` pour ses FIFO. Dockerd accepte `data-root` mais garde `/run/docker` pour son plugin manager. Solution générique : **bind-mount `/run/<daemon>` avant de lancer le daemon**.
3. **`pkill -f` dans un script qui contient le nom du process = auto-kill**. Utiliser `pidof` ou `killall <basename>`.
4. **Les CA certs doivent venir d'un host Linux** : Android n'a pas de bundle PEM utilisable par Go/OpenSSL. `/etc/ssl/certs/ca-certificates.crt` d'une distro hôte fait l'affaire (~220 KB).
5. **Pas de `/etc/resolv.conf` sur Android** : à créer manuellement sinon toute résolution DNS depuis le daemon échoue sur `[::1]:53`.
6. **Android a `/sdcard/` accessible en écriture sans root** : utile pour `adb push` de fichiers à copier ensuite via `su cp` vers `/etc/`.

### Ce qui reste à automatiser dans `setup-docker.sh`
- [ ] Push `/etc/resolv.conf` (actuellement manuel)
- [ ] Push CA bundle vers `/etc/ssl/certs/`
- [ ] Copie `containerd-config.toml` vers `/data/docker/`
- [ ] Magisk service.d pour autostart au boot

### Variante Podman (phase suivante)
Même architecture cible : binaires statiques Podman arm64 + crun, config `containers.conf` avec `cgroup_manager=cgroupfs`, graphroot `/data/podman`, réutiliser `mount-cgroups.sh` et les bind-mounts `/run/*`. À tester pour offrir le choix docker/podman à la communauté.

---

*Mise à jour 15 avril 2026 — Docker opérationnel sur SM-T970 kernel CIP 4.19. Tous les obstacles (rootfs ro, fs hardcodés, DNS/CA, cgroups partiels) contournés. Documentation complète des fausses pistes pour livraison open-source.*

---

## 53. Podman fonctionnel — wrap-up (15 avril 2026)

### Résultat
`podman run --rm --net=host hello-world` s'exécute avec succès sur SM-T970. Podman 5.8.1 + crun + conmon + netavark, binaires statiques de `mgoltzsche/podman-static` v5.8.1.

### Fichiers produits
| Chemin | Rôle |
|---|---|
| `output/podman-binaries/podman-linux-arm64.tar.gz` | Bundle static (~30 MB) : podman, crun, runc, conmon, netavark, aardvark-dns, catatonit, rootlessport, fuse-overlayfs, pasta, fusermount3 |
| `scripts/podman/containers.conf` | `cgroup_manager=cgroupfs`, runtime=crun, chemins `/data/podman/*` |
| `scripts/podman/storage.conf` | driver=overlay, `ignore_chown_errors=true`, `mount_program=fuse-overlayfs` |
| `scripts/podman/registries.conf` | unqualified: docker.io, quay.io, ghcr.io |
| `scripts/podman/policy.json` | `insecureAcceptAnything` (pas de signature verification) |
| `scripts/podman/podman-wrapper.sh` | Bind-mounts `/run/*` + `/var/cache` + `/dev/shm`, export env, invoque podman avec flags explicites |
| `scripts/podman/setup-podman.sh` | One-shot depuis PC |

### Fausses pistes / fixes successifs

| Erreur | Cause | Fix |
|---|---|---|
| `mkdir /run/lock: read-only filesystem` | libpod hardcode `/run/lock` | Bind-mount `/data/podman/run-lock` → `/run/lock` |
| `failed to create 2048 locks in /libpod_lock: no such file or directory` | `/dev/shm` absent sur Android (podman SHM lock manager) | `mount -t tmpfs tmpfs /dev/shm; chmod 1777 /dev/shm` |
| `mkdir /var/cache: read-only filesystem` | containers/image blob-info-cache | Bind-mount `/data/podman/var-cache` → `/var/cache` |
| `no policy.json file found at any of: /.config/containers/, /etc/containers/` | `CONTAINERS_POLICY` env var **pas honoré** par la lib pull (seulement par le CLI podman) — les libs vont chercher dans des chemins en dur | Copier `policy.json` et `registries.conf` dans `/etc/containers/` via `remount rw /` |
| `create directory /run/crun: read-only filesystem` | crun hardcode `/run/crun` pour son state dir | Bind-mount `/data/podman/run-crun` → `/run/crun` |

### Généralisation : le pattern d'Android-ification d'un runtime OCI

Tout runtime conteneur (Docker, Podman, LXC, nerdctl…) assume une distro POSIX complète. Android ne l'est pas. Les absences systématiques à compenser :

1. **rootfs `/` en read-only** → `mount -o rw,remount / && mkdir <missing_dirs> && mount -o ro,remount /` avant chaque lancement (idempotent)
2. **`/run/*` inexistants** → bind-mounts depuis `/data/<runtime>/run-<subdir>`
3. **`/dev/shm` absent** → `mount -t tmpfs`
4. **`/etc/resolv.conf` absent** → écrire manuellement (`nameserver 8.8.8.8`)
5. **CA bundle absent** → pousser `/etc/ssl/certs/ca-certificates.crt` depuis un hôte Linux
6. **`/etc/containers/` absent** → push configs (même si le runtime a des env vars, certaines libs internes scannent des chemins en dur)
7. **`/var/cache` absent** → bind-mount
8. **cgroups non montés** → script `mount-cgroups.sh` manuel, inclure `schedtune` (spécifique Samsung EAS, absent sur kernels mainline)
9. **Pas de systemd** → Magisk `/data/adb/service.d/*.sh` pour l'autostart
10. **Pas de subuid/subgid** → **rootful only**. Rootless implique de faire croire à Android d'un UID mapping user_namespaces, chantier séparé

### Comparaison Docker vs Podman sur ce setup

| Critère | Docker | Podman |
|---|---|---|
| Architecture | daemon (dockerd + containerd) + CLI client | daemonless (fork/exec direct) |
| Processus permanents | 2 daemons (~150-300 MB RAM) | 0 (conmon ~100 KB par conteneur actif) |
| Survie si crash parent | conteneurs tombent avec dockerd | conteneurs indépendants |
| Pods (netns partagé multi-containers) | ❌ | ✅ natif |
| Rootless | complexe, pas tenté ici | natif mais pas configuré sur Android (subuid) |
| Compatibilité CLI | `docker …` | alias `docker` possible |
| Compose | `docker compose` natif v2 | `podman-compose` (tiers) ou `podman kube play` |
| Poids disque binaires | ~150 MB (tgz officiel) | ~80 MB (podman-static) |
| Intégration systemd | `docker.service` | `podman generate systemd` |

Les deux fonctionnent. Préférence utilisateur : Podman (pods + roadmap kind-like).

### Limitations connues du setup actuel

- **cgroup v1 partiel** : warnings `No memory limit/cpu cfs quota/cpuset support` — les `--memory`, `--cpus` ne seront pas enforced (kernel Samsung 4.19 sans certains contrôleurs). Workload qui dépend de ces limites devra être adapté.
- **Bridge networking non testé** — on reste en `--net=host`. netavark + aardvark-dns fournis, mais `default_network=podman` CNI à valider séparément.
- **Rootful uniquement** — tout tourne en su Magisk. Pas de user namespaces rootless.
- **Pas d'autostart au boot** — à ajouter via `/data/adb/service.d/docker-boot.sh` ou `podman-boot.sh`.

### Assets livrables open-source (à préparer)

- README : instructions flash kernel CIP + Magisk + `setup-{docker,podman}.sh`
- Repo structure : `scripts/` + `output/*-binaries/` + kernel build doc
- Un-liner install depuis un PC Arch/Debian vers tablette Android rootée

---

*Mise à jour 15 avril 2026 — Docker **et** Podman opérationnels sur SM-T970 kernel CIP 4.19. Pattern d'Android-ification d'un runtime OCI généralisé. Préparation livraison communauté open-source.*

---

## 54. Persistance Podman au reboot — 5 corrections Android-spécifiques (15 avril 2026)

Validation : après `adb reboot` (testé 2 fois), les deux conteneurs `web-docker:8080` et `web-podman:8081` reviennent up tout seuls via Magisk `service.d`, HTTP 200 confirmé depuis le PC externe.

### Problèmes rencontrés et fixes

#### 1. `HOME` / `USER` absents pour root
- **Symptôme** : `Failed to obtain podman configuration: unable to resolve HOME directory: user: unknown userid 0`
- **Cause** : Android n'a pas de `/etc/passwd`. Podman fait `getpwuid(0)` pour trouver `~/.config/containers/` → échec.
- **Fix** : `export HOME=/data/podman; export USER=root` dans `podman-wrapper.sh`.

#### 2. `/run/*` bind-mounts persistants → stale state après reboot
- **Symptôme** : `current system boot ID differs from cached boot ID; an unhandled reboot has occurred. Please delete directories "/data/podman/run" and "/data/podman/tmp"` puis `container already exists` côté crun.
- **Cause** : sur Linux, `/run/*` est un **tmpfs** (vidé au boot). J'avais bind-monté `/run/{lock,containers,netns,crun}` vers `/data/podman/run-*` (persistants). Podman vérifie explicitement l'égalité entre boot-ID kernel courant et boot-ID cached dans `runroot` → détecte le reboot → refuse.
- **Fix** : remplacé bind-mounts par `mount -t tmpfs` pour tous ces chemins. Comportement identique à un vrai Linux.
- **Généralisation** : tout chemin que Linux fournit en tmpfs par défaut (`/run`, `/run/lock`, `/run/user/*`, `/tmp` parfois) **doit** être tmpfs sur Android aussi, sous peine de casser les invariants "lock file = process vivant".

#### 3. Podman `runroot`/`tmpdir` persistants
- **Symptôme** : même que (2), plus profond dans la config Podman.
- **Cause** : `runroot = /data/podman/run` et `tmp_dir = /data/podman/tmp` dans `containers.conf` → Podman cache son boot-ID dans ces dossiers persistants.
- **Fix** : dans `podman-boot.sh` (Magisk service.d), `rm -rf /data/podman/run/* /data/podman/tmp/*` avant de relancer le moindre conteneur. Idempotent, sûr (vraie sémantique tmpfs).

#### 4. cgroup v2 unifié vide → crun fail
- **Symptôme** : `controller pids is not available under /sys/fs/cgroup/libpod_parent/.../cgroup.controllers`
- **Cause (détaillée)** :
  - Android 12+ monte les deux hiérarchies en parallèle :
    - `/sys/fs/cgroup` en **cgroup v2** (unifié) **mais `cgroup.controllers` vide**
    - `/dev/{cpuctl,memcg,stune,blkio,…}` en **cgroup v1** (tous les contrôleurs actifs)
  - Règle kernel : un contrôleur ne peut être dans une seule hiérarchie à la fois (hybrid mode exclusif). Samsung EAS/thermal/zygote dépendent des v1 à `/dev/*` → v2 reste vide.
  - crun, quand il voit `cgroup2` monté, part en unified mode → cherche `pids` dans le subtree → absent → échoue.
- **Ce n'est pas un problème de kernel CONFIG** : CIP 4.19 supporte parfaitement v2 unifié. C'est l'**userspace Android `init` + `libprocessgroup`** qui impose le binding v1. Identique sur tout kernel LTS récent. Seul Android 14+ mainline migre progressivement.
- **Leviers théoriques et leur coût** :
  | Option | Effet | Viable ? |
  |---|---|---|
  | `cgroup_no_v1=all` cmdline kernel | Libère tout pour v2 | **Non** : Android init fail / thermal runaway / boot loop |
  | `cgroup_no_v1=pids` | Libère juste pids | Marginal (memcg/cpu encore en v1) |
  | Recompiler userspace Android en v2 | Correct | Hors périmètre, casse OTA |
  | `cgroups = disabled` côté container | Pas de limites CPU/mem mais tout marche | **Retenu** |
- **Fix** : `cgroups = "disabled"` dans `[engine]` de `containers.conf`. crun ne cherche plus de contrôleurs. **Conséquence acceptée** : `--memory`, `--cpus`, `--pids-limit` ignorés côté containers (cohérent avec les warnings Docker `No memory limit support` déjà vus).

#### 5. Rootfs overrides (`/etc/resolv.conf`, CA bundle, `/etc/containers/*`) perdus au reboot
- **Cause** : partition `system` Android est **dm-verity + ro**. Toute écriture via `mount -o rw,remount /` est en mémoire uniquement → perdue au reboot.
- **Fix** : script `prepare-rootfs-overrides.sh` qui lit les sources depuis `/data/*` (persistant) et recrée les fichiers via `remount rw → cp → remount ro` à chaque boot. Appelé en tête des deux scripts Magisk `service.d`.
- **Files reconstruits au boot** :
  - `/etc/resolv.conf` (DNS)
  - `/etc/ssl/certs/ca-certificates.crt` (source : `/data/local/tmp/ca-certificates.crt`)
  - `/etc/containers/policy.json` + `registries.conf` (sources : `/data/podman/*.json|*.conf`)
  - `mkdir -p` des futurs points de montage `/run/*` et `/var/cache`

### Leçons transférables

1. **Podman est plus strict que Docker sur l'intégrité entre boots** : il vérifie explicitement `boot ID`, présence de `/etc/passwd`, cohérence des cgroups. C'est précieux pour la fiabilité mais fait remonter des problèmes que Docker tolère silencieusement.
2. **Le pattern "tmpfs pour /run, persistant pour /var"** est un **invariant Linux** : tout runtime respecte cette convention. Android casse les deux (rootfs ro inclut /run et /var) → il faut restaurer les deux côtés.
3. **cgroup v2 sur Android n'est pas un simple `mount -t cgroup2`** : la migration dépend de l'userspace entier (init, zygote, thermal, EAS). Pour un projet kernel-custom, ne pas chercher à forcer v2, accepter `cgroups=disabled`.
4. **Dm-verity oblige à des "rootfs overlays" au boot** : pour tout fichier que le runtime attend dans `/etc/`, `/run/`, `/var/`, il faut un script idempotent déclenché par Magisk `service.d` qui reconstruit l'arborescence depuis `/data`.

### Commandes / diagnostic utilisés

```sh
# Voir la dualité cgroup Android
mount | grep cgroup
cat /sys/fs/cgroup/cgroup.controllers   # vide = v2 unifié sans contrôleur

# Tester un reset propre Podman
rm -rf /data/podman/run/* /data/podman/tmp/*
/data/local/tmp/podman/podman-wrapper.sh ps -a

# Logs boot
cat /data/docker/boot.log
cat /data/podman/boot.log

# Kill-switch autostart en cas de pathologie
rm /data/adb/service.d/*.sh && reboot
```

---

*Mise à jour 15 avril 2026 — Persistance multi-reboot Docker + Podman validée. cgroup v2 vide sur Android 12+ = contrainte userspace, pas kernel : `cgroups=disabled` est la résolution pragmatique, identique sur tout kernel récent.*

---

## 55. Compose + Shell unifié (17 avril 2026)

### docker-compose
- Binaire static aarch64 : `docker-compose-linux-aarch64` v2.32.4 (60 MB, Go static)
- Testé : `docker-compose up -d` avec 2 services (nginx:alpine port 9090 + traefik/whoami port 9091) → HTTP 200 les deux
- `docker-compose ps` / `docker-compose down` fonctionnels
- Installé dans `/data/local/tmp/docker/docker-compose`

### podman compose
- `podman compose` délègue à un "compose provider" externe (docker-compose ou podman-compose)
- **podman-compose** = script Python → inutilisable sur Android sans python
- **docker-compose** réutilisé via symlink : `ln -sf /data/local/tmp/docker/docker-compose /data/podman/.docker/cli-plugins/docker-compose`
- Podman expose une socket API compatible Docker via `podman system service --time=0 unix:///run/podman/podman.sock`
- Testé : `podman compose up -d` avec 2 services (nginx port 9092 + whoami port 9093) → HTTP 200

#### Fix critique : `cgroups = "disabled"` dans `[containers]`
- **Piège** : la documentation Podman place `cgroups` dans `[engine]`, mais quand docker-compose crée des conteneurs via l'API REST, seule la section `[containers]` est honorée pour les paramètres runtime
- **Symptôme** : `podman compose up` échoue avec `controller pids is not available` alors que `podman run --cgroups=disabled` marchait en CLI
- **Fix** : déplacer `cgroups = "disabled"` de `[engine]` vers `[containers]` dans `containers.conf`

### Shell unifié Ubuntu chroot
- Modifié `enter-ubuntu.sh` : bind-mount `/data` **avant** le chroot (pas après — sinon /data pointe vers un dir vide dans le rootfs Ubuntu)
- Symlinks automatiques : `/usr/local/bin/docker` → `/data/local/tmp/docker/docker` (idem compose)
- `DOCKER_HOST=unix:///data/docker/docker.sock` exporté
- `PATH` inclut `/usr/local/bin`
- **Résultat** : un seul shell (`enter-ubuntu.sh`) donne accès à apt (1196 packages Ubuntu 25.10) + docker + docker-compose, les commandes parlent au daemon natif Android via socket

#### Bind-mount /data dans chroot — subtilité
Le bind-mount doit se faire **entre** le `mount --make-rprivate $UBUNTU` et le `chroot $UBUNTU`. Si fait après le chroot, `/data` est un répertoire vide du rootfs Ubuntu, pas le vrai `/data` Android. Séquence correcte :
```sh
$MOUNT --bind $UBUNTU $UBUNTU
$MOUNT --make-rprivate $UBUNTU
mkdir -p $UBUNTU/data
$MOUNT --bind /data $UBUNTU/data     # ← ICI, avant chroot
chroot $UBUNTU /bin/bash -c '...'
```

### Binaires et versions validés sur SM-T970
| Composant | Version | Source | Taille |
|---|---|---|---|
| Docker daemon + CLI | 27.3.1 | docker.com/linux/static/stable/aarch64/ | 69 MB tgz |
| docker-compose | 2.32.4 | github.com/docker/compose/releases | 60 MB |
| containerd | 1.7.22 | (inclus dans docker tgz) | — |
| runc | 1.1.14 | (inclus dans docker tgz) | — |
| Podman | 5.8.1 | github.com/mgoltzsche/podman-static | 30 MB tgz |
| crun | (bundled) | (inclus dans podman-static) | — |
| conmon | (bundled) | (inclus dans podman-static) | — |
| netavark + aardvark-dns | (bundled) | (inclus dans podman-static) | — |
| fuse-overlayfs | (bundled) | (inclus dans podman-static) | — |

### `/run/podman` — oubli à corriger
Le service API Podman (`podman system service`) a besoin de `/run/podman/` (tmpfs). Actuellement créé manuellement. À ajouter au `podman-wrapper.sh` (même pattern que les autres `/run/*`).

---

*Mise à jour 17 avril 2026 — docker-compose et podman compose validés. Shell unifié Ubuntu chroot avec apt + docker opérationnel. Phase 1 terminée, pivot vers Phase 2 (reset + bootstrap from scratch).*

## 56. Ubuntu chroot + X11 desktop XFCE — setup automatisé (18-19 avril 2026)

### Objectif

Environnement graphique Linux complet sur la tablette, piloté depuis le PC via ADB, avec **zéro commandes manuelles dans Termux**. L'ensemble doit être scriptable, idempotent, et reproductible depuis un état vierge (tablette avec kernel custom + Magisk, rien d'autre).

### Architecture finale

```
PC (Linux)
└─ ADB USB
    └─ Android 13 (kernel CIP 4.19 custom)
        └─ Magisk su
            └─ Termux (bootstrapped + mount-utils installés automatiquement)
                ├─ termux-x11 :0 (serveur X11)
                └─ unshare -m → chroot /data/ubuntu
                    ├─ socat (bridge socket X11 abstract → file)
                    ├─ dbus-daemon --system
                    └─ startxfce4 (DISPLAY=:0, GDK_SCALE=2)
```

### Scripts créés

| Script | Rôle | Étapes |
|---|---|---|
| `setup-ubuntu.sh` | Installe Termux + Ubuntu 24.04 chroot | 7 (APK → bootstrap → mount-utils → rootfs → enter-ubuntu.sh → apt config → verify) |
| `setup-x11.sh` | Installe Termux:X11 + XFCE | 5 (APK → termux-x11 pkg → XFCE apt → disable broken services → push scripts) |
| `start-desktop.sh` | Lance X11 + chroot (côté tablette) | Idempotent : kill stale → start/reuse X11 → unshare+chroot |
| `start-desktop-inner.sh` | Setup session XFCE (inside chroot) | Mounts → socat → DPI → xfconf → fakeuid.so → dbus → startxfce4 |
| `uninstall.sh` | Désinstallation granulaire | 7 options (Docker/Podman/X11/Ubuntu/Termux/combinaisons/tout) |

### Découvertes techniques clés

#### 1. Automatisation Termux via ADB : `su -G 3003 -G 9997 <TUID>`
Android restreint l'accès réseau par groupes UID. Le binaire apt de Termux vérifie aussi `getuid()` et refuse de tourner en root.

**Solution :** `su -G 3003 -G 9997 <TUID> -c 'apt ...'`
- `-G 3003` : groupe inet (accès réseau)
- `-G 9997` : groupe everybody (nécessaire pour la résolution DNS)
- `<TUID>` : UID de Termux (ex: 10345), obtenu via `stat -c %u /data/data/com.termux`

Ceci bypasse à la fois le blocage root de apt ET la restriction réseau Android.

#### 2. resolv.conf : `chattr +i`
Ubuntu-base crée `/etc/resolv.conf` comme symlink vers systemd-resolved. En chroot, systemd-resolved n'existe pas → pas de DNS. Le package `software-properties-common` (nécessaire pour PPA) tire systemd qui recrée le symlink.

**Solution :** `rm -f resolv.conf && echo "nameserver 8.8.8.8" > resolv.conf && chattr +i resolv.conf`

Le flag immutable empêche tout package de recréer le symlink. Nécessite `chattr -i` avant désinstallation (`rm -rf` échoue sinon).

#### 3. Firefox snap → .deb Mozilla PPA
Ubuntu 24.04 redirige `apt install firefox` vers un paquet transitional snap. Snap ne fonctionne pas en chroot.

**Solution :** `add-apt-repository ppa:mozillateam/ppa` + apt pin priority 1001 pour le PPA, -1 pour le snap.

#### 4. DPI scaling pour SM-T970 (2800×1752, 12.4")
Sans scaling, tout est minuscule. Configuration qui survit aux redémarrages :
- `GDK_SCALE=2`, `GDK_DPI_SCALE=0.5`, `QT_SCALE_FACTOR=2` (env vars)
- `Xft.dpi: 192`, `Xcursor.size: 48` (Xresources, appliqué via `xrdb`)
- xfconf XML : panel 48px, icônes 64px, police Sans 11, curseur 48

#### 5. socat bridge X11 abstract socket
Termux:X11 crée un socket **abstract** (`@/data/data/com.termux/files/usr/tmp/.X11-unix/X0`). Le chroot ne voit que les sockets **file-based**.

**Solution :** `socat UNIX-LISTEN:/tmp/.X11-unix/X0,fork ABSTRACT-CONNECT:/data/data/com.termux/files/usr/tmp/.X11-unix/X0`

#### 6. fakeuid.so — LD_PRELOAD pour apps refusant root
Firefox, Chrome, VS Code refusent de démarrer en root (getuid()==0). Solution : une lib partagée de 3 lignes C qui override `getuid()` et `geteuid()` pour retourner 1000, compilée avec gcc, utilisée via `fake-root firefox`.

#### 7. `env -i` dans enter-ubuntu.sh
Sans ça, les variables Android (BOOTCLASSPATH, ANDROID_DATA, etc.) polluent l'environnement du chroot et cassent certains outils.

#### 8. dpkg ownership fix
Après bootstrap Termux, les répertoires dpkg sont owned par root (créés par `su`). L'apt Termux refuse d'écrire. Fix : `chown -R <TUID>:<TUID> .../var/lib/dpkg .../var/cache/apt .../var/log/apt`

### Cinnamon — investigation et échec (19 avril 2026)

Cinnamon a été testé en profondeur comme alternative à XFCE. **Résultat : ne fonctionne pas avec Termux:X11.**

#### Cause racine
Cinnamon utilise **Mutter** (fork : Muffin), un compositeur basé sur Clutter/Cogl. Mutter capture toutes les fenêtres dans un pipeline OpenGL, composite le rendu dans un framebuffer GL, et présente le résultat via `glXSwapBuffers`.

Termux:X11 fournit un serveur X11 qui gère correctement les apps X traditionnelles (xterm, Firefox via xfwm4) mais **ne supporte pas la présentation du buffer composité par Mutter**. Résultat : écran noir avec curseur, aucun contenu visible.

#### Tentatives exhaustives

| Tentative | Résultat |
|---|---|
| `cinnamon-session` standard | Erreur "Unsupported session type" → WM `cinnamon` ne démarre pas |
| + `XDG_SESSION_TYPE=x11` | WM démarre, PID actif, mais écran noir |
| + `LIBGL_ALWAYS_SOFTWARE=1` | GL fonctionne (llvmpipe Mesa 25.2.8, OpenGL 4.5 Core), tous les applets chargés en JS (visible dans logs), mais **rendu invisible** |
| `cinnamon-session --session=cinnamon2d` | Wrapper `cinnamon2d` (CINNAMON_2D=1, MUFFIN_NO_SHADOWS=1, FPS=15) → même écran noir |
| `META_DEBUG_NO_COMPOSITE=1` | Même résultat |
| `COGL_DEBUG=winsys` | Logs montrent : GLX context créé, FBConfig sélectionné, driver Mesa/llvmpipe 4.5 Core, tout semble correct côté GL |
| Test contrôle : `xterm` | S'affiche correctement → X11 fonctionne pour les apps non-composites |

#### Analyse GL (COGL_DEBUG=winsys)
```
GL_VENDOR: Mesa
GL_RENDERER: llvmpipe (LLVM 20.1.2, 128 bits)
GL_VERSION: 4.5 (Core Profile) Mesa 25.2.8
GLX: context créé, FBConfig sélectionné, direct rendering actif
```
Le rendu GL software fonctionne parfaitement. Le problème est dans la couche de présentation Mutter → Termux:X11 (swap buffers / surface attachment).

#### Conclusion
C'est une **incompatibilité architecturale** entre le compositing GL de Mutter et le serveur X11 de Termux:X11. Ce n'est pas un bug corrigeable côté scripts — c'est dans le code de Mutter et/ou Termux:X11.

**XFCE fonctionne** car xfwm4 est un WM X11 traditionnel : les fenêtres dessinent directement sur leurs surfaces X11 via le protocole X classique, sans pipeline GL.

**DE qui ne fonctionneront pas :** GNOME Shell, Budgie, Deepin (tous basés sur Mutter/Clutter).
**DE qui pourraient fonctionner (non testés) :** MATE (Marco, fork de Metacity), LXQt (Openbox).

### Bugs corrigés pendant le développement

| Bug | Symptôme | Cause | Fix |
|---|---|---|---|
| `set -e` + `chown` inexistant | Script s'arrête silencieusement à l'étape 3 | `chown` retourne 1 si un répertoire n'existe pas | `\|\| true` après chown |
| `set -euo pipefail` + `apt update` | Script s'arrête silencieusement | apt update retourne non-zero si certains repos sont inaccessibles | `\|\| true` après termux_pkg update |
| `chattr +i` bloque uninstall | `rm -rf /data/ubuntu` échoue sur resolv.conf | Attribut immutable empêche la suppression | `chattr -i` dans uninstall.sh avant `rm -rf` |
| `chattr +i` bloque réinstallation | `tar xzf` échoue sur resolv.conf existant | Même attribut bloque l'extraction | `chattr -i` dans setup-ubuntu.sh avant `tar` |
| Cinnamon "Unsupported session type" | WM ne démarre pas du tout | `XDG_SESSION_TYPE` non défini | `export XDG_SESSION_TYPE=x11` |

### Validation

- Cycle complet testé : `uninstall.sh 7 --yes` → `setup-ubuntu.sh` → `setup-x11.sh` → `start-desktop.sh` → XFCE fonctionnel avec DPI correct
- Idempotence vérifiée : chaque script skippe les étapes déjà faites
- Scripts de test Cinnamon nettoyés (tablette + local)

---

*Mise à jour 19 avril 2026 — Ubuntu chroot + XFCE X11 automatisés. Cinnamon écarté (incompatibilité compositeur GL / Termux:X11). Scripts production-ready.*

---

## 57. sshd dans le chroot + client ConnectBot Android (23 avril 2026)

### Motivation

Termux comme terminal quotidien n'est pas idéal :
- UX basique (pas d'onglets natifs, pas de gestion multi-session propre, rendu moins soigné qu'un vrai émulateur de terminal Android)
- Processus Android séparé du chroot Ubuntu : pour lancer `docker`/`podman`/`apt` il faut passer par `enter-ubuntu.sh` à chaque ouverture
- XFCE via Termux:X11 montre le refresh par tiles (transport framebuffer X) — lisible en terminal mais gênant en usage quotidien

Objectif : avoir un client SSH Android natif (gestes, onglets, clavier physique correctement mappé) qui tombe **directement dans le chroot Ubuntu** — pas dans Termux, pas dans un shell Android.

### Choix du client : ConnectBot

- FOSS (GPL), disponible sur F-Droid et Play Store
- **Pas de compte** requis (vs Termius)
- Fonctionne 100% offline
- Historique long (app majeure des premières années d'Android), maintenance active
- Stockage des clés dans une DB SQLite interne, pas de cloud

### Architecture

```
Android (kernel CIP 4.19)
└─ ConnectBot (app native)
    └─ ssh 127.0.0.1:2222 (loopback, pas de réseau exposé)
        └─ sshd dans Ubuntu chroot (unshare -m + chroot /data/ubuntu)
            └─ /bin/bash root@chroot
                ├─ apt, gcc, compilateurs natifs
                ├─ docker, podman, docker-compose (symlinks /usr/local/bin/)
                └─ DOCKER_HOST=unix:///data/docker/docker.sock (bind /data)
```

sshd écoute **uniquement sur 127.0.0.1** : seule la tablette elle-même peut se connecter, pas le réseau Wi-Fi. Zéro surface d'attaque externe. Clés uniquement (pas de password), root autorisé (on est de toute façon seul sur le device).

### Scripts créés

| Fichier | Rôle |
|---|---|
| `scripts/setup-ssh.sh` | Installer PC-side (6 étapes, idempotent) : keypair + apt install openssh-server + sshd_config + authorized_keys + host keys + push des scripts + Magisk service.d |
| `scripts/start-ssh.sh` | Launcher on-device : kill sshd stale dans le chroot, entre en mount namespace + chroot, lance l'inner |
| `scripts/start-ssh-inner.sh` | Inner : mounts (proc, sys, dev/pts, shm, run tmpfs, cgroup2), symlinks docker/podman, `exec /usr/sbin/sshd -D -e` |
| `scripts/magisk-service.d/ssh-boot.sh` | Autostart 30s après boot (pattern identique à docker-boot/podman-boot) |

Intégration dans les scripts maîtres :
- `setup.sh` option 6 : « SSH server in chroot (for ConnectBot/JuiceSSH — requires Ubuntu) »
- `uninstall.sh` option 5 : désinstallation granulaire (`apt remove openssh-server` si Ubuntu est conservé, sinon cleanup lors du wipe chroot)

### Gestion de la clé SSH (idempotente)

Logique à l'étape 1 de `setup-ssh.sh` :

1. Si `--pubkey /path/to/key.pub` passé → clé custom utilisée, pas de génération
2. Sinon si `~/.ssh/sm-t970_ed25519` existe déjà → réutilisée (re-run sans effet)
3. Sinon génération fraîche d'une ed25519 sans passphrase

Ce flux permet :
- **Re-runs sûrs** du script (dev/debug)
- **Réutilisation d'une clé existante** : l'utilisateur copie sa clé personnelle vers `~/.ssh/sm-t970_ed25519` avant le premier run
- **Clé dédiée** par défaut : nom explicite (`sm-t970-chroot` en comment), séparée des clés perso

La clé publique part dans le chroot (`/root/.ssh/authorized_keys`). La clé privée reste côté PC + doit être importée manuellement dans ConnectBot (pas d'automatisation réaliste — voir section suivante).

### Limite : import de clé dans ConnectBot — non automatisable

ConnectBot stocke ses clés privées dans `/data/data/org.connectbot/databases/pubkeys` sous forme d'**objets `java.security.PrivateKey` Java-sérialisés**. Injecter une clé en base demanderait :

1. Parser le format OpenSSH du fichier privé
2. Reconstruire la sérialisation Java byte-pour-byte (class header stable entre versions)
3. Écrire dans SQLite avec le bon schema (varie selon version ConnectBot)
4. Arrêter ConnectBot avant d'écrire pour éviter l'écrasement par le cache en mémoire

Coût d'ingénierie disproportionné pour ~4 taps manuels (Manage Pubkeys → Import → naviguer → sélectionner). Arbitrage : on s'arrête au push de la clé privée via `adb push`, l'utilisateur fait l'import final à la main.

Workflow documenté pour l'utilisateur :
```
adb push ~/.ssh/sm-t970_ed25519 /sdcard/sm-t970_ed25519
# ConnectBot → ⋮ → Manage Pubkeys → ⋮ → Import → /sdcard/sm-t970_ed25519
adb shell rm /sdcard/sm-t970_ed25519          # cleanup une fois importée
# ConnectBot → + → "root@127.0.0.1:2222" (quick-connect) → clé auto-utilisée
```

### Bug découvert au premier reboot : `/run/sshd` en 0777

**Symptôme** : ConnectBot → `ECONNREFUSED` après reboot. Le log `/data/local/tmp/ssh-boot.log` révèle :
```
/run/sshd must be owned by root and not group or world-writable.
```

**Cause** : `mkdir -p /run/sshd` dans `start-ssh-inner.sh` hérite de l'umask courante. Les deux contextes d'invocation ont des umasks différentes :
- Depuis `adb shell → su -c 'start-ssh.sh'` (test interactif) : umask `0022` héritée de la session interactive → `/run/sshd` en `0755` ✓
- Depuis Magisk `service.d/ssh-boot.sh` (boot daemon) : umask `0000` (default init) → `/run/sshd` en `0777` ✗

sshd vérifie strictement les permissions de son privilege separation dir et refuse de démarrer si world-writable. Différence invisible sur les tests interactifs, apparaît uniquement après reboot.

**Fix** (`start-ssh-inner.sh`) :
```bash
umask 0022                       # cohérent quel que soit le contexte d'appel
# ...
mkdir -p /run/sshd
chown 0:0 /run/sshd              # défensif
chmod 0755 /run/sshd              # défensif, override umask si jamais
```

**Leçon transférable** : toute commande critique exécutée à la fois via `adb shell` et via Magisk `service.d` doit expliciter son contexte (umask, PATH, HOME). Les deux n'héritent pas du même environnement. Ne pas valider uniquement en interactif — reboot test obligatoire.

### Validation

1. **Test PC-side** : `adb forward tcp:22222 tcp:2222` puis `ssh -i ~/.ssh/sm-t970_ed25519 -p 22222 root@127.0.0.1` → connexion OK, Ubuntu 24.04 sur kernel 4.19.325, docker/podman dans PATH
2. **Test ConnectBot tablette** : import manuel de la clé, host `root@127.0.0.1:2222`, connexion réussie
3. **Test reboot initial** : ECONNREFUSED → diagnostic via log → fix umask → retest → sshd opérationnel
4. **Persistance reboot post-fix** : sshd redémarre automatiquement ~30s après boot, ConnectBot se reconnecte sans push ni setup supplémentaire

### Comparaison terminale : Termux vs ConnectBot+chroot

| Critère | Termux | ConnectBot + sshd chroot |
|---|---|---|
| Onglets natifs Android | Non (swipe latéral custom) | Oui |
| Copier/coller avec apps Android | Basique | Fluide (API Android standard) |
| Clavier physique Bluetooth | Gestion limitée des combos | Mappage complet Ctrl/Alt/flèches |
| Persistance session (suspend app) | Coupe le shell | tmux/screen survit, reconnexion instantanée |
| Environnement par défaut | Termux apt (packages limités) | Ubuntu 24.04 apt (full distro) |
| docker/podman accessibles | Via enter-ubuntu.sh | Direct (symlinks dans PATH) |
| Mosh possible | Oui | Oui |

### Assets livrables

- 4 nouveaux scripts dans `samsung-flash-T970/scripts/` et `scripts/magisk-service.d/`
- Intégration `setup.sh` (option 6) et `uninstall.sh` (option 5)
- Documentation du workflow d'import ConnectBot dans le message final de `setup-ssh.sh`
- Recommandation ConnectBot (F-Droid/Play Store) explicitée dans la doc

---

*Mise à jour 23 avril 2026 — SSH dans le chroot + ConnectBot validé comme terminal quotidien. Bug umask/Magisk service.d identifié et corrigé dès le premier reboot. Scripts production-ready.*

---

[README](../../README.md) · [Histoire du projet](../histoire-du-projet.md) · [Dossier de recherche](README.md) · [Récit complet](recit-complet.md) · **Journal de bord** · [Slides expliquées](presentation/slides.md) · [Script](presentation/script.md) · [Présentation (HTML)](presentation/warranty-void.html)
