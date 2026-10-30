#!/usr/bin/env python3
"""Build a local, ad-hoc-signed macOS application bundle."""
import os
import plistlib
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / 'bin' / 'Bonxie.app'


def crate_version():
    """The version of the program: the one in alire.toml, which the program is also built with
    (Bonxie_Config.Crate_Version) and which the updater compares with the newest release."""
    found = re.search(r'^version\s*=\s*"([^"]+)"', (ROOT / 'alire.toml').read_text(), re.MULTILINE)
    if not found:
        raise RuntimeError('No version in alire.toml')
    return found.group(1)


def run(*args):
    subprocess.run(args, check=True)


def output(*args):
    return subprocess.check_output(args, text=True)


def rpaths(binary):
    return re.findall(r'\s+path (.+?) \(offset \d+\)', output('otool', '-l', str(binary)))


def dependencies(binary):
    lines = output('otool', '-L', str(binary)).splitlines()[1:]
    return [line.strip().split(' (compatibility version ', 1)[0] for line in lines]


def resolve(name, binary, executable, paths):
    def expand(value):
        return value.replace('@loader_path', str(binary.parent)).replace('@executable_path', str(executable.parent))

    if name.startswith('@rpath/'):
        candidates = [Path(expand(path)) / name[7:] for path in paths]
    else:
        candidates = [Path(expand(name))]
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    raise RuntimeError(f'Cannot resolve {name} required by {binary}')


def main():
    if os.uname().sysname != 'Darwin':
        raise RuntimeError('The macOS bundle must be built on macOS')
    os.chdir(ROOT)
    version = crate_version()
    run('alr', 'build', '--release')
    executable = ROOT / 'bin/bonxie'
    with tempfile.TemporaryDirectory(dir=ROOT / 'bin', prefix='.bonxie-bundle-') as temp:
        app = Path(temp) / 'Bonxie.app'
        contents = app / 'Contents'
        macos = contents / 'MacOS'
        frameworks = contents / 'Frameworks'
        resources = contents / 'Resources'
        for directory in (macos, frameworks, resources):
            directory.mkdir(parents=True)
        shutil.copy2(executable, macos / 'bonxie')
        shutil.copytree(ROOT / 'share', contents / 'share')
        with (ROOT / 'speech/Info.plist').open('rb') as source:
            info = plistlib.load(source)
        info.update(CFBundleExecutable='bonxie', CFBundleIconFile='Bonxie.icns',
                    CFBundlePackageType='APPL', CFBundleName='Bonxie',
                    CFBundleVersion=version, CFBundleShortVersionString=version)
        with (contents / 'Info.plist').open('wb') as target:
            plistlib.dump(info, target)

        iconset = Path(temp) / 'Bonxie.iconset'
        iconset.mkdir()
        for size in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                suffix = '@2x' if scale == 2 else ''
                run('sips', '-z', str(size * scale), str(size * scale),
                    str(ROOT / 'share/bonxie/logo.png'), '--out',
                    str(iconset / f'icon_{size}x{size}{suffix}.png'))
        run('iconutil', '-c', 'icns', str(iconset), '-o', str(resources / 'Bonxie.icns'))

        # Resolve dependencies against the original binaries, then rewrite every
        # non-system library to a bundle-relative path. Traverse transitively.
        queue = [(executable, macos / 'bonxie', rpaths(executable))]
        copied = {}
        while queue:
            original, bundled, inherited_paths = queue.pop(0)
            paths = rpaths(original) + inherited_paths
            for name in dependencies(original):
                if name.startswith(('/usr/lib/', '/System/Library/')):
                    continue
                source = resolve(name, original, executable, paths)
                if source == original.resolve():  # A dylib's own install name.
                    continue
                destination = frameworks / source.name
                if destination.name in copied and copied[destination.name] != source:
                    raise RuntimeError(f'Conflicting library names: {source} and {copied[destination.name]}')
                if destination.name not in copied:
                    copied[destination.name] = source
                    shutil.copy2(source, destination)
                    destination.chmod(destination.stat().st_mode | 0o200)
                    metallib = source.parent / 'mlx.metallib'  # MLX's GPU code, found beside its library.
                    if metallib.exists():
                        shutil.copy2(metallib, frameworks / metallib.name)
                    queue.append((source, destination, paths))
                run('install_name_tool', '-change', name, '@executable_path/../Frameworks/' + destination.name,
                    str(bundled))
            if bundled != macos / 'bonxie':
                run('install_name_tool', '-id', '@executable_path/../Frameworks/' + bundled.name, str(bundled))
        for library in frameworks.glob('*.dylib'):
            run('codesign', '--force', '--sign', '-', str(library))
        for gpu_code in frameworks.glob('*.metallib'):  # The bundle's seal covers every file in Frameworks.
            run('codesign', '--force', '--sign', '-', str(gpu_code))
        run('codesign', '--force', '--sign', '-', str(app))
        if OUTPUT.exists():
            shutil.rmtree(OUTPUT)
        shutil.move(str(app), OUTPUT)
    print(f'Created {OUTPUT} (version {version})')


if __name__ == '__main__':
    main()
