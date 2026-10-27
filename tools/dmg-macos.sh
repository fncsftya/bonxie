#!/bin/sh
# Build the release app and package it with an Applications shortcut.
set -eu
cd "$(dirname "$0")/.."
root=$(pwd)
./tools/bundle-macos.py
stage=$(mktemp -d "$root/bin/.bonxie-dmg.XXXXXXXX")
trap 'rm -rf "$stage"' EXIT HUP INT TERM
mkdir "$stage/payload"
cp -R bin/Bonxie.app "$stage/payload/Bonxie.app"
ln -s /Applications "$stage/payload/Applications"
hdiutil create -quiet -volname Bonxie -srcfolder "$stage/payload" -format UDZO "$stage/Bonxie.dmg"
mv -f "$stage/Bonxie.dmg" bin/Bonxie.dmg
printf 'Created %s\n' "$root/bin/Bonxie.dmg"
