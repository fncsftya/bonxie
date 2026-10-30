#!/usr/bin/env python3
"""Check the NGA catalogue's selection and deterministic image choice."""

import csv
import tempfile
import unittest
from pathlib import Path

from nga_catalogue import catalogue


class CatalogueTest(unittest.TestCase):
    def test_filters_and_deduplicates(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            objects = root / "objects.csv"
            images = root / "images.csv"
            object_fields = ["objectid", "beginyear", "endyear", "visualbrowserclassification"]
            image_fields = ["uuid", "iiifurl", "depictstmsobjectid", "openaccess", "viewtype"]
            with objects.open("w", newline="") as output:
                writer = csv.writer(output)
                writer.writerow(object_fields)
                writer.writerows([
                    ["1", "1200", "1950", "painting"],
                    ["2", "1199", "1200", "painting"],
                    ["3", "1950", "1951", "painting"],
                    ["4", "", "1800", "painting"],
                    ["5", "1800", "1800", "drawing"],
                    ["6", "1800", "1800", "painting"],
                ])
            first = "00000000-0000-0000-0000-000000000001"
            second = "00000000-0000-0000-0000-000000000002"
            with images.open("w", newline="") as output:
                writer = csv.writer(output)
                writer.writerow(image_fields)
                for object_id, image_id, access, view in [
                    ("1", second, "1", "primary"),
                    ("1", first, "1", "primary"),
                    ("2", first, "1", "primary"),
                    ("3", first, "1", "primary"),
                    ("4", first, "1", "primary"),
                    ("5", first, "1", "primary"),
                    ("6", first, "0", "primary"),
                    ("6", first, "1", "alternate"),
                ]:
                    writer.writerow([image_id, "https://api.nga.gov/iiif/" + image_id, object_id, access, view])
                writer.writerow([first, "https://example.com/" + first, "6", "1", "primary"])
            self.assertEqual(catalogue(objects, images), [("1", first)])


if __name__ == "__main__":
    unittest.main()
