# firmware/

[README](../README.md) · [Guide, step 2 (uses this file)](../docs/guide/02-root-twrp-magisk.md) · [How it works › verified boot](../docs/how-it-works.md) · [Download mirror](../docs/mirror.md)

No binaries are versioned here. This folder only holds the script that
generates the one image the project needs besides the kernel.

## vbmeta_disabled.img

```bash
firmware/make-vbmeta-disabled.sh        # -> firmware/vbmeta_disabled.img (git-ignored)
```

```
Algorithm:                NONE
Flags:                    3
Written: …/firmware/vbmeta_disabled.img (4096 bytes)
```

It is a 4 KiB vbmeta with no descriptors and no signature, and flags = 3
(`HASHTREE_DISABLED | VERIFICATION_DISABLED`). Flashed to the `VBMETA`
partition, it turns Android Verified Boot off, so the bootloader accepts TWRP
and the custom `boot.img`.

The script uses the avbtool pinned in the `sm8250-builder:v2` image (AOSP
`android-14.0.0_r75`). The result is byte-identical to the image flashed during
the project: `sha256sum -c --ignore-missing SHA256SUMS` checks it.

The other binaries (TWRP, Magisk, stock firmware, container runtimes) are
downloaded into `downloads/`, see
[step 0, action 5](../docs/guide/00-before-you-start.md).

---

[README](../README.md) · [Guide, step 2 (uses this file)](../docs/guide/02-root-twrp-magisk.md) · [How it works › verified boot](../docs/how-it-works.md) · [Download mirror](../docs/mirror.md)
