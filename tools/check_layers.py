#!/usr/bin/env python3
"""Check that the application's layers depend only downwards.

    tools/check_layers.py            exit 1 on a dependency that is neither allowed nor in BASELINE
    tools/check_layers.py --list     print every violation, baseline or not

The layers, top to bottom: view, view_models, items, repository / projects, support / appearance.
A rule says which units a directory's files must not `with`. BASELINE holds the violations that
were there when the rule was made; it only shrinks: remove an entry when the dependency is gone.
"""
import re, subprocess, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

VIEW = ("view", "reader_ui", "item_window_ui", "previews")
VMS = tuple(f"{n}_vm" for n in (
    "canvas confirm editor grammar home item_list item_window menu naming nav outline publish reader "
    "search settings sidebar writing_sources writing").split())
TOOLKIT_UI = ("pomarine.widgets", "sdl3", "pomarine.text_areas")

# (directory prefix, forbidden unit prefixes, why)
RULES = [
    ("src/view_models/", VIEW + TOOLKIT_UI,
     "a view-model names no widget and no view (AGENTS.md: Writing a view-model)"),
    ("src/items/", VIEW + VMS + TOOLKIT_UI,
     "the domain does not depend on the screens that show it"),
    ("src/repository/", VIEW + VMS + TOOLKIT_UI,
     "persistence does not depend on screens"),
    ("src/projects/", VIEW + VMS + TOOLKIT_UI,
     "persistence does not depend on screens"),
    ("src/support/", VIEW + VMS + TOOLKIT_UI + ("projects", "repository", "items", "icon_set", "backgrounds",
                                                "adaptive_themes", "section_colour_pickers"),
     "support is the bottom layer: containers, files and text helpers that know nothing of the application"),
    ("ebook/src/", TOOLKIT_UI + ("pomarine.ui", "pomarine.themes", "pomarine.application"),
     "ebook reads pages into pomarine_model's Words and Pages; it draws nothing"),
    ("src/appearance/", VIEW + VMS + ("projects", "repository", "items", "word_tools"),
     "appearance (themes, backgrounds, icons) is below the screens and the domain"),
]

# Not checked: Repository.* specs name Items and Projects types, and the bodies of Items.* and Projects.* call
# Repository.*. That is a spec/body pairing, not a compile-order cycle; the packages in each pair change together.

# Violations that existed when the rule was written: (file, with'd unit).
BASELINE = set()


def forbidden(unit, prefixes):
    u = unit.lower()
    return any(u == p or u.startswith(p + ".") for p in prefixes)


def main():
    files = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "src", "ebook"], cwd=ROOT, text=True
    ).split()
    found = []
    for f in files:
        if not f.endswith((".ads", ".adb")) or not os.path.isfile(os.path.join(ROOT, f)):
            continue
        text = open(os.path.join(ROOT, f), errors="ignore").read()
        for clause in re.findall(r"^\s*(?:limited\s+|private\s+)*with\s+([^;]+);", text, re.M):
            for unit in (x.strip() for x in clause.split(",")):
                for prefix, banned, why in RULES:
                    if f.startswith(prefix) and forbidden(unit, banned):
                        found.append((f, unit, why))
    fresh = [v for v in found if (v[0], v[1].lower()) not in BASELINE]
    listing = sys.argv[1:] == ["--list"]
    for f, unit, why in (found if listing else fresh):
        print(f"{f}: with {unit}: {why}")
    stale = BASELINE - {(f, u.lower()) for f, u, _ in found}
    for f, u in sorted(stale):
        print(f"{f}: baseline entry for {u} no longer needed; remove it from BASELINE")
    return 1 if (fresh or stale) and not listing else 0


sys.exit(main())
