# National Gallery of Art catalogue

`nga-paintings.tsv` is generated from the National Gallery of Art's
[open data](https://github.com/NationalGalleryOfArt/opendata), downloaded on
2026-10-30. The dataset is released under CC0. Each line holds an object ID and
an open-access primary image UUID, separated by a tab. Image URLs are formed
as `https://api.nga.gov/iiif/<uuid>` using the IIIF Image API.

The generator selects paintings whose known start and end years both fall
within 1200–1950, inclusive. It excludes works with missing dates and images
that are not marked open access. Where a work has multiple primary images,
the first UUID in lexical order is used. NGA notes that dates may sometimes
reflect an artist's lifetime rather than the artwork's actual creation date.

To update the file, download `data/objects.csv` and
`data/published_images.csv` from that repository and run:

```
python3 tools/nga_catalogue.py objects.csv published_images.csv share/bonxie/art/nga-paintings.tsv
```
