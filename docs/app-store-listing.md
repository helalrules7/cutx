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
| Copyright | `2026 Ahmed Helal` — year then name. Apple adds the © itself; do not type it, and do not add "All rights reserved". The year is the year of first publication and stays fixed in later versions. |

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

## Promotional text (170 chars max)

**No price words here either.** Guideline 2.3.7 treats "free" as a price reference
in screenshots; promotional text is metadata of the same kind, so keep it out. The
description is the one field Apple explicitly allows pricing language in.

Unlike the description, this can be changed at any time **without submitting a new
version or waiting for review**. So it should carry whatever is currently worth
saying — a launch note, a new feature, a milestone — not a permanent description.

Launch text:

```
Open source, with no ads and no tracking. Cut a file from the keyboard, paste it where you want, and it actually moves.
```

Deliberately free of three words: **"free"** (a price reference under 2.3.7),
**"Windows"** (Microsoft's trademark — the same objection that hit "Finder" could
apply), and **"Finder"** (rejected in the subtitle under 5.2.5). The description is
the only field where Apple tolerates that language, and even there "Windows" is a
risk worth weighing.

## Keywords (100 chars max, comma separated, no spaces after commas)

```
cut,paste,move,files,finder,clipboard,windows,shortcut,keyboard,productivity,utility,folder
```

## URLs

| Field | Value |
|---|---|
| Support URL | `https://ahmedhelal.dev/cutx/support` — a GitHub issues page was rejected under guideline 1.5; Apple wants a page with contact information |
| Marketing URL | `https://github.com/helalrules7/cutx` |
| Privacy Policy URL | `https://github.com/helalrules7/cutx/blob/master/PRIVACY.md` |

## App Privacy

This lives in its own **App Privacy** section in the sidebar, not on the version
page, and review cannot start until it is filled in.

**Get Started** → *"Do you or your third-party partners collect data from this
app?"* → **No, we do not collect data from this app** → **Publish**.

That is accurate: no analytics, no account, no third-party SDKs, and no network
calls of any kind — verifiable from the public source.

Note that answering "No" commits the app to collecting nothing. That is not a
constraint here; CutX contains no networking code at all.

## Notes for the reviewer

This is the field that decides whether CutX is approved or rejected. A reviewer who
cannot see why an app wants to read the keyboard will reject it, and rightly so.

```
CutX adds Windows-style cut and paste for files in the macOS file manager. It requires one permission, and here is exactly why.

ACCESSIBILITY
CutX installs a CGEventTap to recognise two keystrokes: Command-X and Command-V (optionally Control-X and Control-V), and only while the file manager is the frontmost application. Every other keystroke is passed through immediately and untouched, inspected only by key code. Nothing is recorded, stored or transmitted; the app makes no network connections at all.

This is the only mechanism macOS offers for the feature: the file manager's own Cut command is permanently disabled and cannot be enabled by a third party, so there is no menu item or Service to attach to instead.

HOW THE MOVE HAPPENS (no Apple Events)
CutX does not move, copy, open, read or modify any file, and it sends no Apple Events. On Command-X it posts the file manager's own Copy keystroke and then reads the file URLs the file manager placed on the pasteboard. On Command-V it posts the file manager's own Move Item Here keystroke. The file manager performs the entire operation, which is why undo, the progress window, the Replace / Keep Both dialog and authentication prompts all behave exactly as the user expects.

The app is fully sandboxed with no entitlements beyond app-sandbox itself. It requests no Automation permission.

HOW TO TEST
1. Grant Accessibility when CutX asks. Its setup screen shows a live checklist and walks you through it.
2. In the file manager, select a file or folder and press Command-X. A sound plays and the menu-bar icon shows a count.
3. Open another folder and press Command-V. The item moves.
4. Press Command-Z. The file manager undoes the move, confirming it performed the move, not CutX.
5. Open TextEdit, type and select text, press Command-X. The text is cut normally, confirming CutX is inert outside the file manager.

BUNDLED AUDIO
CutX ships six selectable cut sounds plus one paste sound. Three of the seven files are generated in code by scripts/make-sounds.py and are original. The other four are trimmed from royalty-free effects downloaded from Pixabay and used under the Pixabay Content License, which permits commercial use and modification. Each is credited by author, title and source URL in ATTRIBUTIONS.md in the repository. This is why the Content Rights question is answered "Yes".

The full source is public at https://github.com/helalrules7/cutx.
```

## Content Rights

Answer **"Yes, it contains third-party content, and I have the necessary rights."**

Four of the six cut sounds come from Pixabay under the Pixabay Content License,
which permits commercial use and modification and requires no attribution — though
`ATTRIBUTIONS.md` credits each one anyway, by author, title and source URL.

Answering "No" while shipping licensed third-party audio would be inaccurate, and
"Yes" costs nothing: it does not by itself add review steps.

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
