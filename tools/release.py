#!/usr/bin/env python3
"""Build, sign and publish a release that installed copies of Bonxie can update themselves to.

    tools/release.py                 build the disk image, sign it, show the release, ask, publish it
    tools/release.py --dry-run       everything but publishing: the files are left in bin/release/
    tools/release.py --skip-build    use the bin/Bonxie.dmg that is there (it must be of this version)
    tools/release.py --key FILE      the private key (default: $BONXIE_UPDATE_KEY, else
                                     ~/.config/bonxie-release/update-key; make one with `update-key.swift generate`)
    tools/release.py --yes           do not ask before publishing

The version is the one in alire.toml (the program is built with it, and the bundle says it). The release is
`v<version>` on GitHub, with the notes of that version's section of CHANGELOG.md, and these assets, which the
updater looks for by name (see updater/src/updater.ads):

    Bonxie.dmg                  the disk image
    Bonxie.dmg.manifest         what the image must be: its version, size and SHA-256 (updater/src/updater-manifests.ads)
    Bonxie.dmg.manifest.sig     the Ed25519 signature of the manifest

The updater trusts the signature, made by the private key whose public half is built into the program
(updater/src/updater-keys.ads). A key that does not match is refused here, before anything is published: a
release that older copies could not verify would be one they could never update from.
"""
import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = 'fncsftya/bonxie'
OUTPUT = ROOT / 'bin' / 'release'
IMAGE = 'Bonxie.dmg'
DEFAULT_KEY = Path.home() / '.config' / 'bonxie-release' / 'update-key'


def run(*args, **options):
    return subprocess.run(args, check=True, text=True, **options)


def output(*args):
    return subprocess.check_output(args, text=True).strip()


def fail(message):
    print(f'release: {message}', file=sys.stderr)
    sys.exit(1)


def crate_version():
    found = re.search(r'^version\s*=\s*"([^"]+)"', (ROOT / 'alire.toml').read_text(), re.MULTILINE)
    return found.group(1) if found else fail('no version in alire.toml')


def built_in_key():
    """The public key the program checks releases against."""
    found = re.search(r'Public_Key : constant String := "([^"]+)"', (ROOT / 'updater/src/updater-keys.ads').read_text())
    return found.group(1) if found else fail('no public key in updater/src/updater-keys.ads')


def changelog_notes(version):
    """The lines under `## <version>` in CHANGELOG.md, up to the next heading."""
    lines = (ROOT / 'CHANGELOG.md').read_text().splitlines()
    try:
        start = lines.index(f'## {version}') + 1
    except ValueError:
        fail(f'CHANGELOG.md has no section "## {version}"')
    end = next((at for at in range(start, len(lines)) if lines[at].startswith('## ')), len(lines))
    notes = '\n'.join(lines[start:end]).strip()
    return notes or fail(f'the section for {version} in CHANGELOG.md is empty')


def build_signer(directory):
    """Compile the signing tool (the one the tests use) once."""
    tool = Path(directory) / 'update-key'
    run('swiftc', '-O', str(ROOT / 'tools/update-key.swift'), '-o', str(tool))
    return str(tool)


def check_bundle(version):
    """The application in the image is what the updater will insist on: signed intact, and of this version."""
    app = ROOT / 'bin' / 'Bonxie.app'
    if not app.is_dir():
        fail('bin/Bonxie.app is missing (run without --skip-build)')
    run('codesign', '--verify', '--deep', '--strict', str(app))
    said = output('/usr/libexec/PlistBuddy', '-c', 'Print :CFBundleShortVersionString',
                  str(app / 'Contents/Info.plist'))
    if said != version:
        fail(f'bin/Bonxie.app says it is {said}, not {version} (build it again)')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--dry-run', action='store_true', help='do everything but publish')
    parser.add_argument('--skip-build', action='store_true', help='use the existing bin/Bonxie.dmg')
    parser.add_argument('--yes', action='store_true', help='do not ask before publishing')
    parser.add_argument('--key', default=os.environ.get('BONXIE_UPDATE_KEY', str(DEFAULT_KEY)))
    options = parser.parse_args()

    if os.uname().sysname != 'Darwin':
        fail('releases are built on macOS')
    os.chdir(ROOT)
    version = crate_version()
    tag = f'v{version}'
    prerelease = '-' in version  # the updater ignores prereleases, so they are for people who download them
    notes = changelog_notes(version)
    key = Path(options.key).expanduser()
    if not key.is_file():
        fail(f'no private key at {key} (make one: swift tools/update-key.swift generate {key})')
    if output('git', 'status', '--porcelain'):
        print('release: warning: the working tree has uncommitted changes', file=sys.stderr)
    if not options.dry_run:
        if subprocess.run(['git', 'rev-parse', '-q', '--verify', f'refs/tags/{tag}'], capture_output=True).returncode == 0:
            fail(f'the tag {tag} exists already')
        if subprocess.run(['gh', 'release', 'view', tag, '--repo', REPOSITORY], capture_output=True).returncode == 0:
            fail(f'{tag} is already released')

    if not options.skip_build:
        run('./tools/dmg-macos.sh')
    check_bundle(version)
    image = ROOT / 'bin' / IMAGE
    if not image.is_file():
        fail(f'{image} is missing')

    with tempfile.TemporaryDirectory() as scratch:
        signer = build_signer(scratch)
        if output(signer, 'public', str(key)) != built_in_key():
            fail('the private key is not the one whose public half is in updater/src/updater-keys.ads; '
                 'copies of Bonxie would refuse this release')

        if OUTPUT.exists():
            shutil.rmtree(OUTPUT)
        OUTPUT.mkdir(parents=True)
        shutil.copy2(image, OUTPUT / IMAGE)
        digest = hashlib.sha256((OUTPUT / IMAGE).read_bytes()).hexdigest()
        manifest = OUTPUT / f'{IMAGE}.manifest'
        manifest.write_text(
            f'bonxie-update 1\nversion {version}\nfile {IMAGE}\nsize {(OUTPUT / IMAGE).stat().st_size}\nsha256 {digest}\n')
        signature = OUTPUT / f'{IMAGE}.manifest.sig'
        signature.write_text(output(signer, 'sign', str(key), str(manifest)) + '\n')
        # Checked as a copy of Bonxie will check it, with the key that is in the program.
        if subprocess.run([signer, 'verify', built_in_key(), str(manifest), str(signature)]).returncode != 0:
            fail('the signature does not verify against the key built into the program')

    body = f'{notes}\n\nSHA-256 (`{IMAGE}`):\n\n```text\n{digest}\n```\n'
    (OUTPUT / 'notes.md').write_text(body)
    print(f'\nrelease {tag}{" (prerelease)" if prerelease else ""} for {REPOSITORY}\n')
    print(body)
    for name in (IMAGE, f'{IMAGE}.manifest', f'{IMAGE}.manifest.sig'):
        print(f'  {OUTPUT / name}  ({(OUTPUT / name).stat().st_size:,} bytes)')
    if options.dry_run:
        print('\nrelease: dry run; nothing was published')
        return
    if not options.yes and input(f'\nPublish {tag} to github.com/{REPOSITORY}? [y/N] ').strip().lower() != 'y':
        print('release: not published; the files are in bin/release/')
        return

    command = ['gh', 'release', 'create', tag, '--repo', REPOSITORY, '--title', version,
               '--notes-file', str(OUTPUT / 'notes.md'), '--target', output('git', 'rev-parse', 'HEAD')]
    command += ['--prerelease'] if prerelease else ['--latest']
    command += [str(OUTPUT / IMAGE), str(manifest), str(signature)]
    run(*command)
    print(f'release: published https://github.com/{REPOSITORY}/releases/tag/{tag}')


if __name__ == '__main__':
    main()
