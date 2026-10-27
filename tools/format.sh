#!/bin/sh
# Format Ada sources with gnatformat, as AGENTS.md asks before handoff.
#   tools/format.sh            every .adb/.ads/.ada under the repository
#   tools/format.sh FILE...    only those files
# Finds gnatformat on PATH or in ~/.alire/bin; if there is none, installs gnatformat_bin there.
set -e
cd "$(dirname "$0")/.."

find_tool() {
	if command -v gnatformat >/dev/null 2>&1; then
		command -v gnatformat
	elif [ -x "$HOME/.alire/bin/gnatformat" ]; then
		echo "$HOME/.alire/bin/gnatformat"
	fi
}

tool=$(find_tool)
if [ -z "$tool" ]; then
	echo "installing gnatformat_bin into ~/.alire" >&2
	alr -n install gnatformat_bin </dev/null >&2
	tool=$(find_tool)
fi
[ -n "$tool" ] || { echo "gnatformat is not available" >&2; exit 1; }

if [ $# -gt 0 ]; then
	printf '%s\0' "$@" | xargs -0 "$tool" --no-project --keep-going --width 120 --charset utf-8
else
	rg --files -0 -g '*.adb' -g '*.ads' -g '*.ada' |
		xargs -0 "$tool" --no-project --keep-going --width 120 --charset utf-8
fi
