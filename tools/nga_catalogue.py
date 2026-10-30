#!/usr/bin/env python3
"""Make a compact list of NGA open-access paintings from its CSV export.

Download objects.csv and published_images.csv from
https://github.com/NationalGalleryOfArt/opendata/tree/main/data first, then run:

    python3 tools/nga_catalogue.py objects.csv published_images.csv catalogue.tsv

Each line contains an object ID and the UUID of its primary image. The IIIF
base URL is https://api.nga.gov/iiif/ followed by that UUID.
Only works whose entire known date range falls within 1200–1950 are included.
The output is sorted by object ID and is reproducible for the same input files.
"""

import csv
import sys
import uuid
from pathlib import Path


def rows(path):
    with path.open(encoding="utf-8-sig", newline="") as source:
        yield from csv.DictReader(source)


def catalogue(objects, images):
    eligible = set()
    for row in rows(objects):
        try:
            start, end = int(row["beginyear"]), int(row["endyear"])
        except ValueError:
            continue
        if row["visualbrowserclassification"].lower() == "painting" and 1200 <= start <= end <= 1950:
            eligible.add(row["objectid"])

    selected = {}
    for row in rows(images):
        object_id = row["depictstmsobjectid"]
        url = row["iiifurl"].strip().rstrip("/")
        image_id = row["uuid"].strip().lower()
        try:
            valid_id = str(uuid.UUID(image_id)) == image_id
        except ValueError:
            valid_id = False
        if (object_id in eligible and row["openaccess"] == "1" and row["viewtype"] == "primary"
                and valid_id and url == "https://api.nga.gov/iiif/" + image_id):
            # Multiple primary images are possible; choose deterministically.
            selected[object_id] = min(image_id, selected.get(object_id, image_id))
    return sorted(selected.items(), key=lambda item: int(item[0]))


def main():
    if len(sys.argv) != 4:
        raise SystemExit("Usage: nga_catalogue.py objects.csv published_images.csv catalogue.tsv")
    csv.field_size_limit(sys.maxsize)
    result = catalogue(Path(sys.argv[1]), Path(sys.argv[2]))
    if not result:
        raise SystemExit("No eligible paintings found; catalogue was not written")
    with Path(sys.argv[3]).open("w", encoding="utf-8", newline="") as output:
        writer = csv.writer(output, delimiter="\t", lineterminator="\n")
        writer.writerows(result)
    print(f"Wrote {len(result)} paintings")


if __name__ == "__main__":
    main()
