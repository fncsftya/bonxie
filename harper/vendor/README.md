# Harper source

Source: https://github.com/Automattic/harper
Pinned revision: [`../upstream-revision`](../upstream-revision)
License: Apache-2.0 (downloaded upstream text in `harper/LICENSE`).

`harper/` is generated and gitignored. From a fresh checkout run:

```sh
harper/fetch-harper.sh
```

The script performs a depth-one Git fetch into a temporary directory under
`/tmp`, then copies tracked files from these package trees and the root license:

- `harper-core`: parser, dictionary, grammar and spelling rules.
- `harper-brill`: grammatical tagging models used by core.
- `harper-pos-utils`: tagging support used by Brill.
- `harper-thesaurus`: core's default thesaurus feature and its data.
- `harper-dictionary-wordlist`: user dictionary persistence, reserved for later use.

All package files and embedded assets are preserved. Registry dependencies
are pinned by `../rust/Cargo.lock` and fetched by Cargo rather than copied.
The generated `harper/UPSTREAM_REVISION` records the resolved upstream commit.
The temporary clone is removed on exit.

## Local patch

`../patches/rust-1.90.patch` explicitly casts the first predicate in four
heterogeneous function arrays to `fn(&TokenKind) -> bool`. This resolves Rust
1.90 type inference errors without changing lint behavior. The script applies
it before replacing an existing snapshot, and fails if the patch no longer
applies. There are no other changes to upstream files.

## Updating

Edit `harper/upstream-revision` to pin the desired commit, then rerun
`harper/fetch-harper.sh`. An optional commit, tag, or branch argument can be
used to explore an update without changing the committed pin; copy the
resolved `vendor/harper/UPSTREAM_REVISION` into `upstream-revision` to retain it.

Review or remove the compatibility patch when updating Rust or Harper. If
upstream dependencies changed, regenerate the wrapper lockfile with
`cargo generate-lockfile --manifest-path harper/rust/Cargo.toml`. Review the
category colors and the C/Rust/Ada layouts if Harper's diagnostic API changes.
The binding checks are described in `../README.md` and the project's
`TESTING.md`.
