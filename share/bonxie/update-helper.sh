#!/bin/sh
# Put an update in place of the running Bonxie, and start it.
#
#     sh update-helper.sh PID STAGED_APP TARGET_APP RESULT_FILE
#
# Bonxie has checked and unpacked the update (STAGED_APP) and then starts this script, from a copy outside the
# application it is about to replace, and quits. The script waits for process PID to end, puts the staged
# application next to TARGET_APP, swaps the two with renames (so that there is always a whole application where
# TARGET_APP is) and opens it. If any step fails the old application is put back and opened, and RESULT_FILE says
# why ("failed: ..."), for Bonxie to tell the person next time it runs. What it did is in update.log beside it.
#
# BONXIE_OPEN names the program that opens the application (/usr/bin/open): the tests change it.
set -u

if [ $# -ne 4 ]; then
	echo "usage: update-helper.sh PID STAGED_APP TARGET_APP RESULT_FILE" >&2
	exit 2
fi
pid=$1
staged=$2
target=$3
result=$4
open_app=${BONXIE_OPEN:-/usr/bin/open}
work=$(dirname "$result")
new="$target.update-new"
old="$target.update-old"

# The script is started by a program that is quitting, and may outlive its terminal.
trap '' HUP
exec >"$work/update.log" 2>&1 </dev/null
printf 'update-helper: %s -> %s (waiting for %s)\n' "$staged" "$target" "$pid"

fail() {
	printf 'update-helper: failed: %s\n' "$1"
	printf 'failed: %s\n' "$1" >"$result"
	"$open_app" "$target"
	exit 1
}

case $pid in
'' | *[!0-9]*) fail "the process number is not a number" ;;
esac
case $staged in
/*.app) ;;
*) fail "the staged application is not the path of an application" ;;
esac
case $target in
/*.app) ;;
*) fail "the application to replace is not the path of an application" ;;
esac
[ -d "$staged/Contents/MacOS" ] || fail "the staged application is not there"
[ -d "$target" ] || fail "the application to replace is not there"

# Up to a minute for Bonxie to finish saving and quit.
waited=0
while kill -0 "$pid" 2>/dev/null; do
	waited=$((waited + 1))
	[ "$waited" -le 600 ] || fail "Bonxie did not quit"
	sleep 0.1
done

rm -rf "$new" "$old"
# Copied beside the target, so that the swap is two renames on one volume.
/usr/bin/ditto "$staged" "$new" || {
	rm -rf "$new"
	fail "the new version could not be written beside the old (is its folder yours to change?)"
}
mv "$target" "$old" || {
	rm -rf "$new"
	fail "the old version could not be moved aside"
}
mv "$new" "$target" || {
	mv "$old" "$target"
	fail "the new version could not be moved into place"
}
# Only the quarantine mark: other attributes hold the signature of files that are not code (mlx.metallib).
/usr/bin/xattr -dr com.apple.quarantine "$target" 2>/dev/null

rm -rf "$old" "$staged"
rm -f "$work"/Bonxie.dmg* "$result"
printf 'update-helper: done\n'
"$open_app" "$target"
