# Architecture

## Layers

Dependencies point down. `tools/check_layers.py` checks the rules below (run it before committing); a rule
that must be broken is added to `BASELINE` in the script, with the reason, and the list only shrinks.

```
src/view            screens, canvas, writing, settings, grammar; view/items = the item windows and readers;
                    view/widgets = application widgets (colour picker, word tools); view/build = declarative views
src/view_models     screen state and rules, no widgets, no SDL3 (items-models.* is the item's view-model)
src/items           the domain: records, links, marks, words, sources, directories, schema
src/repository      SQLite tables         src/projects   projects, sections, rules, preferences
src/support         containers, files, downloads (knows nothing of the application)
src/appearance      themes, backgrounds, icons
pomarine/*          the toolkit: model (words, pages, marks: data only) < ui (widgets, views) < sdl3, texts, typeset,
                    coretext, yoga, vm; native (accessibility, menus)
ebook, vision, speech, webshot, harper   sidecars (C, Swift, Objective-C, Rust)
```

Known and accepted:

- `Repository.*` specs name `Items.*` and `Projects.*` types, and the bodies of `Items.*` and `Projects.*` call
  `Repository.*`: a spec/body pairing, not a compile-order cycle.
- `View.Navigation` calls each screen (`Enter`, `Leave`, `Show_*`), and `Writing` and `Settings_View` call back
  into it (`Show`, `Do_Command`): seven `View.*` units depend on each other in their bodies.
- `View.Session` has one component per screen (`*_Parts`, `*_State`) and an `Owner : Session_Access` adapter for
  each view-model's effects.
- `Pomarine.Widgets` is one package because the tree's tables are private to it, but its body is only the table and
  what a widget answers about itself (about 1,000 lines). The work is in private children under
  `pomarine/ui/src/pomarine/tree/`, each one part of the tree's job (the list is at the top of the body):
  `Nodes` (shared pixels, cold parts, table lookups), `Adding`, `Lifecycle`, `Queueing`, `Commanding`, `Focusing`,
  `Dispatching`, `Drawing`, `Accessibility`, `Animations`. A public operation of the parent calls the child's
  operation of another name (`Dispatch` calls `Dispatching.Dispatch_Event`), so a stack trace says which.

## Where things were found to be weak (see the review of 2026-10)

Long subprograms (Load_Stored in texts-documents.adb, Place_Sections, Build_Write, Build_Settings, Build_Home,
Text_Areas.Draw) and the unchecked-pointer lifetime rule of `Pomarine.UI` (the model must outlive the view).
