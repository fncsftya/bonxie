#!/bin/sh
# Test the whole of staging on a made-up release: an application in a disk image, a signed manifest, and the ways
# a download can go wrong. Needs the tests built (cd updater/tests && alr build) and swift, hdiutil and codesign.
#
#     updater/tests/stage_test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(mktemp -d)
trap 'hdiutil detach "$root/work/mount" -force >/dev/null 2>&1; rm -rf "$root"' EXIT HUP INT TERM
failures=0

check() { # name, command
	if ! eval "$2"; then
		echo "FAIL $1"
		failures=$((failures + 1))
	fi
}

swiftc -O "$here/../../tools/update-key.swift" -o "$root/update-key" 2>/dev/null || { echo "cannot build update-key"; exit 1; }
"$root/update-key" generate "$root/key" >"$root/key.pub"
"$root/update-key" generate "$root/other-key" >/dev/null
pub=$(cat "$root/key.pub")

make_release() { # version dir
	app="$root/payload/Bonxie.app"
	rm -rf "$root/payload"
	mkdir -p "$app/Contents/MacOS"
	printf '#!/bin/sh\nexit 0\n' >"$app/Contents/MacOS/bonxie"
	chmod +x "$app/Contents/MacOS/bonxie"
	cat >"$app/Contents/Info.plist" <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>bonxie</string>
<key>CFBundleIdentifier</key><string>com.bonxie.test</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$1</string>
</dict></plist>
EOT
	codesign --force --sign - "$app" >/dev/null 2>&1
	rm -rf "$2"
	mkdir -p "$2"
	hdiutil create -quiet -volname Bonxie -srcfolder "$root/payload" -format UDZO "$2/Bonxie.dmg"
	size=$(stat -f %z "$2/Bonxie.dmg")
	sum=$(shasum -a 256 "$2/Bonxie.dmg" | cut -d' ' -f1)
	printf 'bonxie-update 1\nversion %s\nfile Bonxie.dmg\nsize %s\nsha256 %s\n' "$1" "$size" "$sum" >"$2/Bonxie.dmg.manifest"
	"$root/update-key" sign "$root/key" "$2/Bonxie.dmg.manifest" >"$2/Bonxie.dmg.manifest.sig"
}

stage() { # dir version [key]
	"$here/bin/stage_updater" "${3:-$pub}" "$1" "$1/Bonxie.dmg" "$1/Bonxie.dmg.manifest" "$1/Bonxie.dmg.manifest.sig" "$2"
}

# A good release.
make_release 0.2.0 "$root/work"
out=$(stage "$root/work" 0.2.0)
check "good release stages" "[ \"\$out\" = \"staged $root/work/Bonxie.app\" ]"
check "staged application is there" "[ -x $root/work/Bonxie.app/Contents/MacOS/bonxie ]"
check "image is let go" "[ ! -e $root/work/mount ] && ! mount | grep -q $root/work/mount"
check "signature checks out" "codesign --verify --deep --strict $root/work/Bonxie.app"

# Staging again, over what is there.
out=$(stage "$root/work" 0.2.0)
check "stages again" "[ \"\$out\" = \"staged $root/work/Bonxie.app\" ]"

# The same release, another version offered.
out=$(stage "$root/work" 0.3.0)
check "other version refused" "echo \"\$out\" | grep -q '^failed the update is for version 0.2.0, not the one offered'"
check "refused leaves nothing staged" "[ ! -e $root/work/Bonxie.app ]"

# Signed by another key.
out=$(stage "$root/work" 0.2.0 "$("$root/update-key" public "$root/other-key")")
check "wrong key refused" "echo \"\$out\" | grep -q '^failed the update is not signed by its author'"

# A manifest that was changed.
changed=$(cat "$root/work/Bonxie.dmg.manifest")
printf '%s\n' "${changed%%version*}version 9.9.9${changed#*version 0.2.0}" >"$root/work/Bonxie.dmg.manifest"
out=$(stage "$root/work" 9.9.9)
check "changed manifest refused" "echo \"\$out\" | grep -q '^failed the update is not signed by its author'"

# A disk image that was changed (same size, other bytes).
make_release 0.2.0 "$root/work"
printf 'X' | dd of="$root/work/Bonxie.dmg" bs=1 seek=100 conv=notrunc 2>/dev/null
out=$(stage "$root/work" 0.2.0)
check "changed image refused" "echo \"\$out\" | grep -q '^failed the download is not the file the author signed'"

# A disk image that was cut short.
make_release 0.2.0 "$root/work"
head -c 1000 "$root/work/Bonxie.dmg" >"$root/work/short"
mv "$root/work/short" "$root/work/Bonxie.dmg"
out=$(stage "$root/work" 0.2.0)
check "short image refused" "echo \"\$out\" | grep -q '^failed the download is not the size the author signed'"

# A release whose application says another version than the manifest (signed, so the author's mistake).
make_release 0.1.5 "$root/work"
printf 'bonxie-update 1\nversion 0.2.0\nfile Bonxie.dmg\nsize %s\nsha256 %s\n' \
	"$(stat -f %z "$root/work/Bonxie.dmg")" "$(shasum -a 256 "$root/work/Bonxie.dmg" | cut -d' ' -f1)" >"$root/work/Bonxie.dmg.manifest"
"$root/update-key" sign "$root/key" "$root/work/Bonxie.dmg.manifest" >"$root/work/Bonxie.dmg.manifest.sig"
out=$(stage "$root/work" 0.2.0)
check "application of another version refused" "echo \"\$out\" | grep -q '^failed the application is not version 0.2.0'"
check "refused leaves nothing staged (2)" "[ ! -e $root/work/Bonxie.app ]"

# Files that are not there.
rm -f "$root/work/Bonxie.dmg.manifest.sig"
out=$(stage "$root/work" 0.2.0)
check "missing signature refused" "echo \"\$out\" | grep -q '^failed the update.s manifest or signature is missing'"

if [ "$failures" -eq 0 ]; then
	echo "staging: all checks passed"
else
	echo "staging: $failures checks failed"
	exit 1
fi
