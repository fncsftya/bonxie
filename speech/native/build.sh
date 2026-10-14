#!/bin/sh
# Build libBonxieParakeet (Parakeet on Core ML, by FluidAudio: see
# ../parakeet) into native/lib, for the Ada crate to link. Run by Alire after
# the crate is fetched, and by hand when ../parakeet changes (it does
# nothing if the library is newer than everything in ../parakeet).
set -e
here=$(cd "$(dirname "$0")" && pwd)
source_dir="$here/../parakeet"
library="$here/lib/libBonxieParakeet.dylib"
if [ -f "$library" ] \
   && [ -z "$(find "$source_dir/Package.swift" "$source_dir/Sources" -newer "$library" -type f 2>/dev/null)" ]; then
   exit 0
fi
(cd "$source_dir" && swift build -c release)
built=$(cd "$source_dir" && swift build -c release --show-bin-path)
mkdir -p "$here/lib"
cp "$built/libBonxieParakeet.dylib" "$library"
