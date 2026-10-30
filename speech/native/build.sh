#!/bin/sh
# Build libBonxieParakeet (Parakeet on Core ML, by FluidAudio: see
# ../parakeet) and libBonxieGranite (Granite Speech on MLX, by
# mlx-audio-swift: see ../granite, with mlx.metallib beside it) into
# native/lib, for the Ada crate to link. Run by Alire after the crate is
# fetched, and by hand when ../parakeet or ../granite change (each does
# nothing if its library is newer than everything in its source).
set -e
here=$(cd "$(dirname "$0")" && pwd)

parakeet_dir="$here/../parakeet"
parakeet="$here/lib/libBonxieParakeet.dylib"
if [ ! -f "$parakeet" ] \
   || [ -n "$(find "$parakeet_dir/Package.swift" "$parakeet_dir/Sources" -newer "$parakeet" -type f 2>/dev/null)" ]; then
   (cd "$parakeet_dir" && swift build -c release)
   built=$(cd "$parakeet_dir" && swift build -c release --show-bin-path)
   mkdir -p "$here/lib"
   cp "$built/libBonxieParakeet.dylib" "$parakeet"
fi

# xcodebuild builds Granite, not SwiftPM: only xcodebuild compiles MLX's
# Metal shaders, which needs Xcode and its Metal Toolchain
# (`xcodebuild -downloadComponent MetalToolchain`).
granite_dir="$here/../granite"
granite="$here/lib/libBonxieGranite.dylib"
if [ ! -f "$granite" ] \
   || [ -n "$(find "$granite_dir/Package.swift" "$granite_dir/Sources" -newer "$granite" -type f 2>/dev/null)" ]; then
   derived="$granite_dir/.build/xcode"
   mkdir -p "$granite_dir/.build"
   (cd "$granite_dir" && xcodebuild -scheme BonxieGranite -destination 'platform=macOS' \
      -configuration Release -derivedDataPath "$derived" build >"$derived.log" 2>&1) \
      || { tail -20 "$derived.log" >&2; echo "libBonxieGranite did not build (see $derived.log)" >&2; exit 1; }
   built="$derived/Build/Products/Release"
   mkdir -p "$here/lib"
   cp "$built/PackageFrameworks/BonxieGranite.framework/BonxieGranite" "$granite"
   install_name_tool -id @rpath/libBonxieGranite.dylib "$granite"
   # MLX looks for mlx.metallib in the folder of the library that has it.
   cp "$built/mlx-swift_Cmlx.bundle/Contents/Resources/default.metallib" "$here/lib/mlx.metallib"
fi
