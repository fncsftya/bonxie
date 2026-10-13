#!/bin/sh
# Build transcribe.cpp (and the ggml it is on) as static libraries, into
# native/lib, for the Ada crate to link. Run by Alire after the crate is
# fetched, and by hand when the submodule moves (it does nothing if the
# libraries are newer than the submodule's commit).
set -e
here=$(cd "$(dirname "$0")" && pwd)
source_dir="$here/../transcribe.cpp"
build_dir="$here/build"
stamp="$here/lib/.built"
head=$(git -C "$source_dir" rev-parse HEAD 2>/dev/null || echo unknown)
if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$head" ]; then
   exit 0
fi
if [ ! -f "$source_dir/CMakeLists.txt" ]; then
   git -C "$here/.." submodule update --init --recursive transcribe/transcribe.cpp
fi
cmake -S "$source_dir" -B "$build_dir" \
   -DCMAKE_BUILD_TYPE=Release \
   -DCMAKE_OSX_DEPLOYMENT_TARGET=26.0 \
   -DTRANSCRIBE_BUILD_TESTS=OFF \
   -DTRANSCRIBE_BUILD_EXAMPLES=OFF
cmake --build "$build_dir" -j "$(sysctl -n hw.ncpu)"
mkdir -p "$here/lib"
find "$build_dir" -name '*.a' -exec cp {} "$here/lib/" \;
echo "$head" > "$stamp"
