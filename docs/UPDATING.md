# Updating and releasing

Installed copies of Bonxie look for a newer release on GitHub, offer it, and, if the person says yes, replace
themselves with it. Nobody downloads anything by hand. This describes how that works, how to make a release it
can update to, and what to look after.

## What a person sees

- **File > Check for Updates…** and **Settings > Updates > Check for Updates** look now. The menu says so when
  there is nothing newer; the settings show it in the line beside the button.
- By itself, at start and at most once a day, it looks quietly: nothing is shown unless a newer version is there.
  *Settings > Updates > Check for updates automatically* turns that off. Copies that are not installed (run from
  the build tree, a disk image or a read-only folder) never look by themselves.
- A newer version is **offered** in a dialog: **Install and Restart**, **Skip This Version** or **Later**.
  Nothing is downloaded until Install. Skip keeps that version from being offered again by the automatic look
  (a look the person asks for still shows it); the next version is offered. Later puts it away until the next
  look.
- Install shows how the download is going (Cancel stops it), checks it, saves the work, quits, and the new version
  opens in place of the old. If anything fails, the old version is left whole and the dialog says why; if the
  swap itself fails after Bonxie has quit, the old version is reopened and the next start tells the person.

## How it works

Source: the `updater` crate (no screens), `src/view_models/updates/` (`Update_VM`, its states and rules),
`src/view/dialogs/view-updates.*` (the dialog, in `Confirm_VM`'s), and `share/bonxie/update-helper.sh`.

1. **Look.** `GET https://api.github.com/repos/fncsftya/bonxie/releases/latest` (with curl, by `Download_Jobs`).
   GitHub's *latest* is never a draft or prerelease; the parser refuses those too. The tag (`v0.2.0`) is compared
   with the running version, `Bonxie_Config.Crate_Version`, as semantic versioning orders them
   (`0.1.0-alpha` < `0.2.0`).
2. **Fetch**, on Install: `Bonxie.dmg.manifest`, `Bonxie.dmg.manifest.sig`, `Bonxie.dmg`, only from
   `https://github.com/fncsftya/bonxie/releases/download/…`.
3. **Check** (`Updater.Staging`, in the background):
   - the **Ed25519 signature** of the manifest, against the public key in `updater/src/updater-keys.ads`;
   - the manifest names this version, and the image's size and SHA-256 are the signed ones;
   - the image is mounted read-only, `Bonxie.app` copied out, the image detached;
   - the copy has its `com.apple.quarantine` attribute removed (and no other: some files keep their signature in one) (the program is not notarized, so macOS would refuse a
     downloaded copy), `codesign --verify --deep --strict` passes, and its `CFBundleShortVersionString` is the
     signed version.

   The signature is what makes a release trusted: GitHub, or anyone who can upload to the repository, cannot make
   a release that installed copies accept without the private key.
4. **Hand over.** `update-helper.sh` is copied out of the bundle and started on its own (`sh update-helper.sh PID
   STAGED TARGET RESULT`); Bonxie saves and quits. The script waits for the process to end, copies the staged
   app beside the old one, swaps the two with renames, clears quarantine, opens the new one, and removes what was
   fetched. On any failure it puts the old one back, opens it, and writes `failed: …` to `updates/result`, which
   `Update_VM.Start` reports next time. Its log is `updates/update.log`. The files are in
   `~/.config/bonxie/updates/`.

Preferences kept in `~/.config/bonxie/settings`: `update_checks`, `skipped_version`, `last_update_check`.

## Making a release

One-time: make the signing key and keep it safe.

```sh
swift tools/update-key.swift generate ~/.config/bonxie-release/update-key
```

It prints the public key, which must be the one in `updater/src/updater-keys.ads` (a key was made for the
project already; `release.py` refuses a private key that does not match). **Back the private key up** (a password
manager, not the repository): copies of Bonxie accept only releases signed by it. If it is lost or leaked,
release a version by hand (the usual DMG) with a new public key built in; installed copies cannot update to it
automatically, as they will not trust its signature, so people download that one once.

Each release:

1. Set `version` in `alire.toml` (it is also the bundle's version and what the program reports), and write the
   `## <version>` section of `CHANGELOG.md`; that is the release's description and what the dialog quotes.
2. Commit and push.
3. `tools/release.py --dry-run` builds the app and the disk image, signs, checks the signature against the key in
   the program, and leaves `bin/release/` to look at. Then `tools/release.py` asks, and runs `gh release create
   v<version>` with `Bonxie.dmg`, `Bonxie.dmg.manifest` and `Bonxie.dmg.manifest.sig`. A version with a `-` in it
   (`0.3.0-beta`) is published as a prerelease, which the updater never offers.

The assets must have exactly those names. A release without them is not offered (the updater cannot tell it
from a broken one).

## Tests

- `updater/tests`: `alr build`, then `bin/check_updater` (versions, manifests, release JSON, locations, and, with
  arguments, an Ed25519 signature and SHA-256 made by other tools), `./helper_test.sh` (the swap and its
  failures on made-up apps), `./stage_test.sh` (a made-up release in a real disk image: good, wrong key, changed
  manifest, changed or truncated image, wrong version).
- `tests`: `bin/golden update-vm` runs `Update_VM` on fakes (no network, no disk).

## What is not covered

The swap has been tested on made-up applications, and the pipeline up to the hand-over on the real bundle; a
complete update from one released version to the next needs two real releases (0.2.0 is the first that can
update, as 0.1.0-alpha has no updater: install 0.2.0 by hand once).
