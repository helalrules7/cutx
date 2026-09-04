# App Store listing — CutX

Everything App Store Connect asks for, written out. Paste, don't improvise.

## Identity

| Field | Value |
|---|---|
| Name (30 chars max) | `CutX — Cut and Paste Files` |
| Subtitle (30 chars max) | `Move files from the keyboard` |
| Bundle ID | `com.helalrules.CutX` |
| SKU | `cutx-mac-001` |
| Primary category | Utilities |
| Secondary category | Productivity |
| Price | Free |
| Age rating | 4+ |

**On the name:** plain `CutX` is unavailable in App Store Connect, even though a
public App Store search returns nothing for it — Apple reserves names for apps that
were registered but never shipped, and for apps withdrawn from sale. Searching the
storefront does not prove availability; only App Store Connect does.

The app itself is still called **CutX** everywhere — in the bundle, the menu bar,
and the interface. Only the store listing carries the longer name.

Name and subtitle are deliberately non-overlapping: Apple indexes both, so
repeating "cut and paste files" in each would waste one of them. Between them they
cover cut, paste, files, move, and keyboard.

**The subtitle field rejects ⌘ and other symbols** — it takes letters, digits and
basic punctuation only. The description field does accept them.

**Never write "Command X" in any store field.** It is the name of a competing app
already on the store, and using another app's name in your own metadata is grounds
for rejection.

## Description

```
Press ⌘X on a file or folder in Finder, then ⌘V where you want it. The items move — they are removed from the original location, exactly like Windows.

macOS has no cut for files. Finder's ⌘X is permanently greyed out, and the real move gesture is ⌘C followed by ⌥⌘V — which almost nobody knows about, and which your fingers will never learn if they grew up on Windows.

CutX makes the obvious shortcut do the obvious thing.

HOW IT WORKS

CutX never touches your files. It asks Finder to do the move.

On ⌘X it forwards a copy to Finder and remembers what you marked. On ⌘V it forwards Finder's own Move Item Here. That means undo, the progress window for large transfers, the Replace / Keep Both dialog, authentication for protected folders, and permission preservation all work exactly as they normally do — because it really is Finder doing the work.

Outside Finder, CutX is invisible. ⌘X in your editor still cuts text.

FEATURES

• ⌘X and ⌘V move files and folders in Finder and on the Desktop
• Optional ⌃X and ⌃V for Windows muscle memory
• Works on any keyboard layout — CutX reads the physical key, not the character
• Six cut sounds with preview, plus a volume control
• An on-screen indicator when you cut, and a live count in the menu bar
• Launch at login
• Eleven languages, with a properly mirrored Arabic interface
• Lives in the menu bar — no Dock icon, no window on launch

FREE AND OPEN SOURCE

CutX is free, has no ads, no tracking, no account, and makes no network connections. The full source is on GitHub under the MIT licence.

HONEST LIMITS

CutX does not dim the cut files inside the Finder window the way Windows does — macOS gives third-party apps no way to draw there. The menu-bar count and the on-screen indicator are the alternative.

It works in Finder and on the Desktop, not in third-party file browsers or Open/Save dialogs. Pasting into a non-Finder app copies rather than moves, which is the safe direction to fail in.
```

## Keywords (100 chars max, comma separated, no spaces after commas)

```
cut,paste,move,files,finder,clipboard,windows,shortcut,keyboard,productivity,utility,folder
```

## URLs

| Field | Value |
|---|---|
| Support URL | `https://github.com/helalrules7/cutx/issues` |
| Marketing URL | `https://github.com/helalrules7/cutx` |
| Privacy Policy URL | `https://github.com/helalrules7/cutx/blob/master/PRIVACY.md` |

## Privacy questionnaire

Answer **"No"** to data collection on every question. CutX has no analytics, no
network calls, and no third-party SDKs. This is true, and it is verifiable from the
public source.

## Notes for the reviewer

This is the field that decides whether CutX is approved or rejected. A reviewer who
cannot see why an app wants to read the keyboard will reject it, and rightly so.

```
CutX adds Windows-style cut and paste for files in Finder. It requires two permissions, and here is exactly why.

ACCESSIBILITY
CutX installs a CGEventTap to recognise two keystrokes: ⌘X and ⌘V (optionally ⌃X and ⌃V). Every other key is passed through untouched, immediately, without inspection beyond its key code. Nothing is recorded, stored, or transmitted — the app makes no network connections at all.

The event tap is the only mechanism macOS offers for this. Finder's own ⌘X is permanently disabled and cannot be enabled by a third party.

AUTOMATION (Finder)
CutX sends two Apple Events to Finder: one to ask which items are selected, and one to trigger Finder's own Edit ▸ Move Item Here. CutX never moves, opens, reads, or modifies a file itself — Finder performs every file operation. This is a deliberate design decision: it means undo, progress reporting, name-conflict dialogs, and authentication all behave exactly as the user expects, because they are Finder's.

HOW TO TEST
1. Grant Accessibility when CutX asks. Its setup screen shows a live checklist and walks you through it.
2. In Finder, select a file or folder and press ⌘X. A sound plays and the menu-bar icon shows a count.
3. Open another folder and press ⌘V. The item moves.
4. Press ⌘Z. Finder undoes the move — confirming that Finder, not CutX, performed it.
5. Open TextEdit, type and select text, press ⌘X. The text is cut normally, confirming CutX is inert outside Finder.

The full source is public at https://github.com/helalrules7/cutx — the keystroke handling is one pure function, `decide(event:context:)`, in Sources/CutXCore/Decision.swift, with unit tests covering every case.
```

## Screenshots

Mac App Store accepts 1280×800, 1440×900, 2560×1600, or 2880×1800. The app's own
window is far smaller than any of these, so screenshots must be composed — the app
window placed on a background with a short headline, the way most Mac listings do it.

`scripts/make-store-screenshots.swift` generates them at 2560×1600.

Order matters; the first is the only one many people see:

1. **The cut in progress** — files selected in Finder with the indicator visible.
2. **⌘X and ⌘V, that's it** — the keyboard reference.
3. **Eleven languages** — the picker plus the mirrored Arabic window.
4. **Six sounds** — the Sounds tab.
5. **Free and open source** — the About tab.

## Before submitting

- [ ] Confirm the name "CutX" is available.
- [ ] Verify `SMAppService.mainApp` (Launch at login) works in the sandboxed build —
      the spike did not test it, and it is the feature most likely to differ.
- [ ] Run the whole of `docs/manual-testing.md` against the App Store build, not the
      Developer ID one.
- [ ] Check the app still opens with no window and no Dock icon.
