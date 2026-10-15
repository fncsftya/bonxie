#!/bin/sh
# Fetch PDFium (prebuilt by https://github.com/bblanchon/pdfium-binaries,
# BSD-3/Apache-2.0) into ./pdfium, where ebook.gpr looks for it.
# Usage: ./fetch-pdfium.sh [release]   (default: the one below)
set -eu
release="${1:-chromium/8100}"
case "$(uname -m)" in
  arm64) asset=pdfium-mac-arm64 ;;
  *)     asset=pdfium-mac-x64 ;;
esac
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/$asset.tgz" \
  "https://github.com/bblanchon/pdfium-binaries/releases/download/$release/$asset.tgz"
rm -rf "$here/pdfium"
mkdir -p "$here/pdfium"
tar xzf "$tmp/$asset.tgz" -C "$here/pdfium"
# The library's install name is "./libpdfium.dylib", which finds it only
# from its own folder: make it an rpath one, and sign again.
install_name_tool -id @rpath/libpdfium.dylib "$here/pdfium/lib/libpdfium.dylib"
codesign --force --sign - "$here/pdfium/lib/libpdfium.dylib"
echo "PDFium $(tr '\n' ' ' < "$here/pdfium/VERSION") is in $here/pdfium"
