#!/bin/sh
# Test share/bonxie/update-helper.sh on made-up applications in a made-up folder: no Bonxie is touched or opened.
#
#     updater/tests/helper_test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
helper="$here/../../share/bonxie/update-helper.sh"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT HUP INT TERM
failures=0

check() {
	if ! eval "$2"; then
		echo "FAIL $1"
		failures=$((failures + 1))
	fi
}

# A program that stands for open(1): it notes what it was asked to open.
cat >"$root/open" <<EOT
#!/bin/sh
echo "\$1" >>"$root/opened"
EOT
chmod +x "$root/open"

make_app() { # path version
	mkdir -p "$1/Contents/MacOS"
	echo "$2" >"$1/Contents/version"
	echo '#!/bin/sh' >"$1/Contents/MacOS/bonxie"
}

fresh() {
	rm -rf "$root/apps" "$root/work" "$root/opened"
	mkdir -p "$root/apps" "$root/work"
	make_app "$root/apps/Bonxie.app" old
	make_app "$root/work/Bonxie.app" new
	touch "$root/work/Bonxie.dmg" "$root/work/Bonxie.dmg.manifest"
}

run() { # pid
	BONXIE_OPEN="$root/open" sh "$helper" "$1" "$root/work/Bonxie.app" "$root/apps/Bonxie.app" "$root/work/result"
}

# It waits for the process to end, then swaps.
fresh
sleep 1 &
pid=$!
start=$(date +%s)
run "$pid"
check "waits for the process" "[ $(($(date +%s) - start)) -ge 1 ]"
check "new version in place" "[ \"\$(cat $root/apps/Bonxie.app/Contents/version)\" = new ]"
check "old version gone" "[ ! -e $root/apps/Bonxie.app.update-old ] && [ ! -e $root/apps/Bonxie.app.update-new ]"
check "staged gone" "[ ! -e $root/work/Bonxie.app ]"
check "download gone" "[ ! -e $root/work/Bonxie.dmg ] && [ ! -e $root/work/Bonxie.dmg.manifest ]"
check "no failure noted" "[ ! -e $root/work/result ]"
check "opens the application" "[ \"\$(cat $root/opened)\" = $root/apps/Bonxie.app ]"
check "keeps a log" "grep -q done $root/work/update.log"

# A staged application that is not there leaves the old one, opens it and says why.
fresh
rm -rf "$root/work/Bonxie.app"
run 999999
check "missing staged: old kept" "[ \"\$(cat $root/apps/Bonxie.app/Contents/version)\" = old ]"
check "missing staged: says why" "grep -q '^failed: the staged application is not there' $root/work/result"
check "missing staged: old opened" "[ \"\$(cat $root/opened)\" = $root/apps/Bonxie.app ]"

# A folder that cannot be written to leaves the old one whole.
fresh
chmod 555 "$root/apps"
run 999999
chmod 755 "$root/apps"
check "read-only folder: old kept" "[ \"\$(cat $root/apps/Bonxie.app/Contents/version)\" = old ]"
check "read-only folder: says why" "grep -q '^failed: the new version could not be written' $root/work/result"
check "read-only folder: staged kept" "[ -d $root/work/Bonxie.app ]"

# Odd arguments are refused, not acted on.
fresh
BONXIE_OPEN="$root/open" sh "$helper" "1; rm -rf /" "$root/work/Bonxie.app" "$root/apps/Bonxie.app" "$root/work/result"
check "bad pid refused" "grep -q '^failed: the process number' $root/work/result"
fresh
BONXIE_OPEN="$root/open" sh "$helper" 999999 "relative.app" "$root/apps/Bonxie.app" "$root/work/result"
check "relative path refused" "grep -q '^failed: the staged application is not the path' $root/work/result"
fresh
BONXIE_OPEN="$root/open" sh "$helper" 999999 "$root/work/Bonxie.app" "$root/apps/Other" "$root/work/result"
check "not an app refused" "grep -q '^failed: the application to replace is not the path' $root/work/result"
check "not an app: nothing changed" "[ \"\$(cat $root/apps/Bonxie.app/Contents/version)\" = old ]"

# A process that does not end.
fresh
sleep 100 &
long=$!
trap 'kill $long 2>/dev/null; rm -rf "$root"' EXIT
if [ "${SLOW:-}" = 1 ]; then
	run "$long"
	check "stuck process: old kept" "[ \"\$(cat $root/apps/Bonxie.app/Contents/version)\" = old ]"
	check "stuck process: says why" "grep -q '^failed: Bonxie did not quit' $root/work/result"
fi
kill $long 2>/dev/null

if [ "$failures" -eq 0 ]; then
	echo "update-helper: all checks passed"
else
	echo "update-helper: $failures checks failed"
	exit 1
fi
