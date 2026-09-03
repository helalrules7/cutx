# CutX manual test checklist

Event injection, Finder integration, permissions, icons, and launch-at-login cannot
be tested automatically. Run this list before tagging a release. `./scripts/test.sh`
covers the decision logic; this covers everything else.

Use a throwaway folder of junk files. Never run this against real work.

```bash
rm -rf ~/Desktop/CutX-Test
mkdir -p ~/Desktop/CutX-Test/Source/MyFolder ~/Desktop/CutX-Test/Destination
echo hello > ~/Desktop/CutX-Test/Source/MyFolder/inside.txt
for n in a b c; do echo hi > ~/Desktop/CutX-Test/Source/file-$n.txt; done
open ~/Desktop/CutX-Test/Source
```

## Transparency outside Finder

This section matters most. A regression here makes CutX unusable.

- [ ] TextEdit: type text, select, `⌘X` — text cuts. `⌘V` pastes it back.
- [ ] Terminal: `⌃X` does whatever it normally does.
- [ ] Browser address bar: `⌘X` cuts the URL text.
- [ ] With "Also use ⌃X" enabled, repeat all three. Behavior must be unchanged.

## Core move

- [ ] Select one file, `⌘X` — sound plays, indicator reads "1 item cut", badge reads 1.
- [ ] Open another folder, `⌘V` — the file moves, is gone from the source, badge clears.
- [ ] `⌘Z` — Finder undoes the move and the file returns.
- [ ] Repeat with a **folder that has contents** — the folder and everything inside
      it move together.
- [ ] Repeat with 4 items selected at once — indicator reads "4 items cut".
- [ ] Cut from the Desktop, paste into a folder.
- [ ] Cut from a folder, paste onto the Desktop.

## Finder's own behavior comes through

- [ ] Paste where a file of the same name exists — Finder's Replace / Keep Both
      dialog appears.
- [ ] Cut a large file (1 GB+) to another volume — Finder's progress window appears.
- [ ] Paste into a folder requiring admin rights — macOS asks for the password.

## Pasteboard safety

- [ ] `⌘X` files, then copy text from TextEdit, then `⌘V` in Finder — the paste does
      NOT move the files, and the badge clears.
- [ ] `⌘X` files, then `⌘C` different files in Finder, then `⌘V` — the copied files
      are copied, not moved. No data is lost either way.

## Window and settings

- [ ] Left-click the menu-bar icon — the window opens.
- [ ] Right-click — the short menu appears with cut state, Clear, Open, Buy me a
      coffee, and Quit.
- [ ] `⌘X`, then Clear from that menu — badge clears, `⌘V` does nothing special.
- [ ] **Sounds:** uncheck "Play sound" — cut and paste are silent, the list and
      slider grey out.
- [ ] **Sounds:** press ▶ on all six rows — each plays immediately, even with
      "Play sound" off.
- [ ] **Sounds:** pick Scissors, quit, relaunch — still selected, still plays on `⌘X`.
- [ ] **Sounds:** drag the volume slider far left, then `⌘X` — audibly quieter.
- [ ] **General:** enable "Also use ⌃X" — `⌃X` / `⌃V` move files in Finder. Disable
      it — `⌃X` in Finder does nothing special again.
- [ ] **General:** uncheck "Show cut indicator" — no indicator, sound still plays.
- [ ] **General:** toggle "Launch at login" on — CutX appears in System Settings ▸
      General ▸ Login Items. Toggle off — it disappears.
- [ ] **About:** the coffee button and both GitHub links open the right pages.
- [ ] Quit and relaunch — every setting survived.

## Permissions

```bash
tccutil reset Accessibility com.helalrules.CutX
pkill -x CutX && open /Applications/CutX.app
```

- [ ] The window opens **by itself**, with no click.
- [ ] General shows the orange "Setup needed" banner; the Accessibility row is a red
      ✗ with an Open button; the three toggles are hidden.
- [ ] The walkthrough animation loops — a cursor moves to a toggle and flips it.
- [ ] Grant Accessibility in System Settings, then look back at the CutX window
      **without touching it**: the row turns green within about a second, the banner
      turns green, and the toggles appear.
- [ ] `⌘X` in Finder works immediately, with no relaunch.

## Icons

- [ ] Menu-bar icon is legible in a **light** menu bar and in a **dark** one.
- [ ] It shows open scissors when idle and closed scissors with a count after a cut.
- [ ] The app icon in Finder and in the About tab is the blue scissors tile.
      (If it looks stale, relaunch Finder — macOS caches icons aggressively.)

## Install experience

- [ ] Unzip the notarized build on a Mac that has never seen CutX and open it — it
      launches with no Gatekeeper warning.
- [ ] `spctl --assess --type execute --verbose=4 /path/to/CutX.app` reports
      `accepted` and `source=Notarized Developer ID`.
