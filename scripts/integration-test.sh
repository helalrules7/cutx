#!/usr/bin/env bash
# Drives Finder and CutX end to end, from outside the sandbox, and checks the
# file system after every step. Replaces the file-operation half of
# docs/manual-testing.md; sounds and the on-screen indicator still need a human.
#
# Requirements, granted once in System Settings > Privacy & Security:
#   - Terminal (or whatever runs this) in Accessibility  -> to send keystrokes
#   - Terminal allowed to control Finder and System Events (Automation)
#   - Any CutX build running, with its own Accessibility permission granted
#
# Usage: scripts/integration-test.sh            # run everything
#        scripts/integration-test.sh --keep     # leave the fixture behind
set -uo pipefail

FIX="$HOME/Desktop/CutX-IntegrationTest"
SRC="$FIX/Source"; DST="$FIX/Destination"
PASS=0; FAIL=0; RESULTS=()
KEEP="${1:-}"

say_result() {   # name, ok(0/1), detail
    if [[ "$2" == 0 ]]; then PASS=$((PASS+1)); RESULTS+=("PASS  $1"); else FAIL=$((FAIL+1)); RESULTS+=("FAIL  $1 — $3"); fi
}
key() { osascript -e "tell application \"System Events\" to keystroke \"$1\" using {${2}}" ; sleep 0.9; }
finder_select() {  # POSIX paths...
    local items=""
    for p in "$@"; do items+="POSIX file \"$p\" as alias, "; done
    osascript -e "tell application \"Finder\"
        activate
        select {${items%, }}
    end tell"; sleep 0.6
}
finder_open() { osascript -e "tell application \"Finder\"
        activate
        set target of front Finder window to (POSIX file \"$1\" as alias)
    end tell"; sleep 0.8; }
finder_deselect() { osascript -e 'tell application "Finder" to set selection to {}'; sleep 0.4; }
cut_badge_visible() { :; }  # not observable from a script; humans check the badge

echo "== preflight"
pgrep -x CutX >/dev/null || { echo "CutX is not running. Start a build first."; exit 2; }
osascript -e 'tell application "System Events" to get name of first process' >/dev/null 2>&1 \
    || { echo "Terminal may not control System Events. Grant Automation in System Settings and retry."; exit 2; }
osascript -e 'tell application "Finder" to get name of startup disk' >/dev/null 2>&1 \
    || { echo "Terminal may not control Finder. Grant Automation in System Settings and retry."; exit 2; }
echo "   CutX running, Finder and System Events reachable"

echo "== fixture"
rm -rf "$FIX"; mkdir -p "$SRC/MyFolder/Nested" "$DST"
echo a > "$SRC/A.txt"; echo b > "$SRC/B.txt"; echo c > "$SRC/C.txt"; echo d > "$SRC/D.txt"
echo inside > "$SRC/MyFolder/inside.txt"; echo deep > "$SRC/MyFolder/Nested/deep.txt"
printf '' | pbcopy
osascript -e "tell application \"Finder\"
    activate
    close every window
    make new Finder window to (POSIX file \"$SRC\" as alias)
end tell" >/dev/null; sleep 1

echo "== 1. single file moves"
finder_select "$SRC/A.txt"; key x "command down"; finder_open "$DST"; key v "command down"; sleep 0.6
if [[ -f "$DST/A.txt" && ! -f "$SRC/A.txt" ]]; then say_result "single file moves" 0
else say_result "single file moves" 1 "dst=$([[ -f $DST/A.txt ]] && echo yes || echo no) src_still=$([[ -f $SRC/A.txt ]] && echo yes || echo no)"; fi

echo "== 2. undo restores it"
key z "command down"; sleep 0.8
if [[ -f "$SRC/A.txt" && ! -f "$DST/A.txt" ]]; then say_result "undo restores" 0
else say_result "undo restores" 1 "src=$([[ -f $SRC/A.txt ]] && echo yes || echo no)"; fi

echo "== 3. folder with nested contents moves"
finder_open "$SRC"; finder_select "$SRC/MyFolder"; key x "command down"; finder_open "$DST"; key v "command down"; sleep 0.8
if [[ -f "$DST/MyFolder/Nested/deep.txt" && ! -d "$SRC/MyFolder" ]]; then say_result "folder with contents moves" 0
else say_result "folder with contents moves" 1 "deep=$([[ -f $DST/MyFolder/Nested/deep.txt ]] && echo yes || echo no)"; fi

echo "== 4. multiple items move"
finder_open "$SRC"; finder_select "$SRC/B.txt" "$SRC/C.txt"; key x "command down"; finder_open "$DST"; key v "command down"; sleep 0.8
if [[ -f "$DST/B.txt" && -f "$DST/C.txt" && ! -f "$SRC/B.txt" ]]; then say_result "two items move" 0
else say_result "two items move" 1 "B=$([[ -f $DST/B.txt ]] && echo yes || echo no) C=$([[ -f $DST/C.txt ]] && echo yes || echo no)"; fi

echo "== 5. nothing selected -> nothing happens"
finder_open "$SRC"; finder_deselect; before=$(ls "$SRC" "$DST" | md5); key x "command down"; finder_open "$DST"; key v "command down"; sleep 0.6
after=$(ls "$SRC" "$DST" | md5)
if [[ "$before" == "$after" ]]; then say_result "empty selection is inert" 0
else say_result "empty selection is inert" 1 "file listing changed"; fi

echo "== 6. pasteboard safety: text copied after cut blocks the move"
finder_open "$SRC"; finder_select "$SRC/D.txt"; key x "command down"
printf 'hello from another app' | pbcopy; sleep 0.4
finder_open "$DST"; key v "command down"; sleep 0.8
if [[ -f "$SRC/D.txt" && ! -f "$DST/D.txt" ]]; then say_result "pasteboard safety" 0
else say_result "pasteboard safety" 1 "D moved=$([[ -f $DST/D.txt ]] && echo yes || echo no)"; fi
rm -f "$DST"/*.textClipping 2>/dev/null

echo "== 7. Cmd+X outside Finder still cuts text"
osascript -e 'tell application "TextEdit"
    activate
    set d to make new document
    set text of d to "the quick brown fox"
end tell' >/dev/null; sleep 0.8
key a "command down"; key x "command down"
remaining=$(osascript -e 'tell application "TextEdit" to get text of front document' 2>/dev/null)
osascript -e 'tell application "TextEdit" to close front document saving no' >/dev/null 2>&1
if [[ -z "$remaining" ]]; then say_result "text cut outside Finder" 0
else say_result "text cut outside Finder" 1 "text still present: '$remaining'"; fi

echo
echo "================ RESULTS ================"
printf '%s\n' "${RESULTS[@]}"
echo "-----------------------------------------"
echo "passed $PASS  failed $FAIL   (sound + indicator: not testable here)"
[[ "$KEEP" == "--keep" ]] || rm -rf "$FIX"
osascript -e 'tell application "Finder" to close every window' >/dev/null 2>&1
[[ $FAIL -eq 0 ]]
