#!/bin/sh
# Populate the ignored vendor/harper tree from a shallow upstream fetch.
# Usage: ./fetch-harper.sh [revision] (default: upstream-revision).
set -eu

if [ "$#" -gt 1 ]; then
    echo "Usage: $0 [revision]" >&2
    exit 2
fi

here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
revision="${1:-$(cat "$here/upstream-revision")}"
case "$revision" in
    ''|-*) echo "Expected an upstream commit, tag, or branch." >&2; exit 2 ;;
esac

tmp="$(mktemp -d /tmp/bonxie-harper.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM

# Fetching the requested revision at depth one avoids cloning the current
# default branch first, which may differ from the pinned commit. No full
# working tree is needed: archive only the tracked package trees we use.
git init -q "$tmp/source"
git -C "$tmp/source" remote add origin https://github.com/Automattic/harper.git
git -C "$tmp/source" fetch --depth=1 origin "$revision"
resolved="$(git -C "$tmp/source" rev-parse 'FETCH_HEAD^{commit}')"
git -C "$tmp/source" archive --format=tar --output="$tmp/harper.tar" "$resolved" \
    LICENSE harper-core harper-brill harper-pos-utils harper-thesaurus harper-dictionary-wordlist
mkdir "$tmp/vendor"
tar xf "$tmp/harper.tar" -C "$tmp/vendor"

# Fail before replacing an existing snapshot if a future upstream revision
# needs a different compatibility patch.
git -C "$tmp/vendor" apply "$here/patches/rust-1.90.patch"
printf '%s\n' "$resolved" > "$tmp/vendor/UPSTREAM_REVISION"

mkdir -p "$here/vendor"
# Keep the previous snapshot until the download and patch have succeeded.
if [ -e "$here/vendor/harper" ]; then
    mv "$here/vendor/harper" "$tmp/previous"
fi
if ! mv "$tmp/vendor" "$here/vendor/harper"; then
    if [ -e "$tmp/previous" ]; then
        mv "$tmp/previous" "$here/vendor/harper"
    fi
    exit 1
fi

echo "Harper $resolved is in $here/vendor/harper"
