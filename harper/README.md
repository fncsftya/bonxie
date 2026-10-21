# Harper bindings

An Alire library around Harper's curated spelling and grammar checker. Bonxie
depends on this crate through a local pin. Editor integration can use the
`Harper` package without calling Rust on the UI thread.

`Harper.Checker` owns a statically allocated Ada task. `Submit` copies a UTF-8
document and its caller-supplied revision into that task; `Poll` collects the
result. Both use conditional rendezvous and return immediately if the task
is unavailable. Retry an unaccepted submission on a later UI iteration.
Collect the previous result before submitting another document. Compare
the returned revision with the current document revision before displaying
diagnostics or applying an edit. Multiple checkers can work independently.

Every Rust call happens in the Ada task, including the first initialization
of the built-in dictionary. The Rust wrapper is synchronous and starts no
threads or asynchronous runtime. Each call creates and drops a linter;
Harper caches its immutable dictionary and thread-local parsing data.
At the Checker's enclosing scope exit, any current check finishes and the
task terminates; an uncollected result does not keep it alive. There is no
cancellation of an in-progress Harper call.

The API accepts plain text or Markdown and all five Harper dialects;
British English and plain text are the defaults. All strings are UTF-8.
Diagnostic and edit spans are zero based, half open **byte** ranges into
the submitted text, converted from Harper's character offsets. Each edit
is a replacement: insertion uses an empty span and removal uses empty
replacement text. Messages contain Harper's Markdown.

Ada request and result storage is fixed: 64 KiB input, 128 diagnostics,
four suggestions per diagnostic, 512 message bytes and 256 replacement
bytes. Counts specify the meaningful array entries. Results report omitted
diagnostics and suggestions. Long messages are shortened at a UTF-8
boundary and flagged; long replacements are omitted to avoid offering
incorrect edits. Harper itself requires dynamic allocation for dictionaries,
parsing and linting. Each Checker has a 16 MiB task stack for Rust and Ada.

The writing view uses four checkers. Longer documents are submitted in
64 KiB chunks, preferring paragraph boundaries and splitting oversized
paragraphs at whitespace or UTF-8 boundaries. Grammar spanning a chunk
boundary may be missed. Each text area stores up to 512 highlighted spans;
the per-request diagnostic limit above also applies.
The diagnostic popout retains the same limit of 512 diagnostics per document,
including explanations and corrections. It reuses a fixed pool of 32 card
widgets for its visible rows. A document edit invalidates both its retained
diagnostics and any correction actions before they can change the text.

A project's own rules are not part of this crate: bonxie keeps them in its database
(`Projects.Rules`) and applies them in Ada to each result (`Grammar_Rules.Apply`), so
Harper is called as before. A rule ignores the diagnostics of one kind on an exact text, or
corrects an exact text to the replacement a person typed; a correction is offered first at
Harper's own diagnostics on that text, and makes a diagnostic of its own, with `Custom` set,
at each whole word Harper did not mark. Diagnostics made by rules are listed first.

The C ABI is documented in `include/bonxie_harper.h`. It uses caller-owned
buffers and retains no pointers. Invalid UTF-8, invalid arguments and caught
Rust panics return distinct statuses with empty output. As with other native
libraries, allocation failure or a process fault cannot be recovered through
this interface.

Build with Rust/Cargo (edition 2024, tested with Rust 1.90) and Alire:

```sh
cd harper
./fetch-harper.sh
alr build
cd tests
alr build
alr exec -- bin/check_harper
```

Run `fetch-harper.sh` once before building a fresh checkout, as with PDFium's
fetch script. It downloads the revision pinned in `upstream-revision`, copies
the required crates and dictionary into the ignored `vendor/harper` directory,
and applies the checked-in compatibility patch. The generated source is not
included in this repository.

Alire builds the Rust shared library in release mode using `--locked` before
building Ada. Cargo downloads registry dependencies on the first build.
No runtime download is needed. The standalone tests cover task reuse and shutdown, simultaneous
checkers, spelling, grammar, dialects, Markdown, UTF-8 byte offsets, invalid
UTF-8, revision echoing, and capacity reporting.

The shared library isolates Harper's unwinding Rust runtime from the
separately built Rust runtime in Pomarine Native. Keep the built
`rust/target/release/libbonxie_harper.dylib` with the application when
packaging it; the GPR supplies its build location as a runtime search path.
On macOS its install name uses `@rpath`, so a packaged application can add
its bundled library directory to the runtime search paths.

See `vendor/README.md` for the upstream revision, license and local patch.
`harper-dictionary-wordlist` is included in the snapshot for later user
dictionary persistence; the built-in dictionary needs only `harper-core`.
