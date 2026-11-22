# docs/images

[README](../../README.md) · [Guide](../guide/00-before-you-start.md) · [How it works](../how-it-works.md) · [Dossier de recherche (FR)](../research/README.md)

Photos taken with a phone during the project (April 2026), used to illustrate
the guide and the story.

Every image here was **re-encoded from pixels only** before being committed:

```bash
magick IN.jpg -auto-orient [-rotate …] [-fill … -draw "rectangle …"] \
    -strip -resize '1400x1400>' -quality 82 -sampling-factor 4:2:0 OUT.jpg
```

- `-strip` and the re-encode drop all metadata: EXIF (including **GPS
  position**, phone model, unique image ID), XMP, ICC, plus Samsung's embedded
  HDR gain map and trailer data;
- identifying content visible on screen is masked (the device ID and its
  barcode on `download-mode-oem-lock-on.jpg`);
- photos showing a reflection of the photographer were left out.

Check before adding a new image (both must print nothing):

```bash
exiv2 -pa docs/images/NEW.jpg
grep -a -c -i -E 'GPS|Exif|SEFH|hdrgm' docs/images/NEW.jpg | grep -v '^0$'
```

---

[README](../../README.md) · [Guide](../guide/00-before-you-start.md) · [How it works](../how-it-works.md) · [Dossier de recherche (FR)](../research/README.md)
