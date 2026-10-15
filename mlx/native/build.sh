#!/bin/sh
# Build libBonxieMLX (local language models on MLX, by mlx-swift-lm: see
# ../swift) into native/lib, with mlx.metallib beside it, for the Ada crate
# to link. Run by Alire after the crate is fetched, and by hand when ../swift
# changes (it does nothing if the library is newer than everything in
# ../swift).
#
# xcodebuild builds it, not SwiftPM: only xcodebuild compiles MLX's Metal
# shaders, which needs Xcode and its Metal Toolchain
# (`xcodebuild -downloadComponent MetalToolchain`).
set -e
here=$(cd "$(dirname "$0")" && pwd)
source_dir="$here/../swift"
library="$here/lib/libBonxieMLX.dylib"
if [ -f "$library" ] \
   && [ -z "$(find "$source_dir/Package.swift" "$source_dir/Sources" -newer "$library" -type f 2>/dev/null)" ]; then
   exit 0
fi
derived="$source_dir/.build/xcode"
mkdir -p "$source_dir/.build"
(cd "$source_dir" && xcodebuild -scheme BonxieMLX -destination 'platform=macOS' \
   -configuration Release -derivedDataPath "$derived" build >"$derived.log" 2>&1) \
   || { tail -20 "$derived.log" >&2; echo "libBonxieMLX did not build (see $derived.log)" >&2; exit 1; }
built="$derived/Build/Products/Release"
mkdir -p "$here/lib"
cp "$built/PackageFrameworks/BonxieMLX.framework/BonxieMLX" "$library"
install_name_tool -id @rpath/libBonxieMLX.dylib "$library"
# MLX looks for mlx.metallib in the folder of the library that has it.
cp "$built/mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib" "$here/lib/mlx.metallib"
