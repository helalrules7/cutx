<div align="center">

<img src="assets/app-icon-preview.png" width="128" alt="CutX">

# CutX

**Cut and paste files in Finder, the way you expect.**

Press <kbd>⌘X</kbd> on a file or folder, then <kbd>⌘V</kbd> where you want it.
The items move — they are removed from the original location, exactly like Windows.

Free, open source, no ads, no tracking. Speaks eleven languages.

[Download](https://github.com/helalrules7/cutx/releases) ·
[Buy me a coffee ☕](https://buymeacoffee.com/ahmedhelal)

</div>

<div align="center">

<img src="screenshots/cut-indicator.png" width="620" alt="Four files selected in Finder with a floating indicator reading 4 items cut">

<sub>⌘X on four items. The indicator fades after a moment; the menu-bar count stays until you paste.</sub>

</div>

---

## Why

macOS has no cut for files. Finder's <kbd>⌘X</kbd> is permanently greyed out, and
the real move gesture is <kbd>⌘C</kbd> followed by <kbd>⌥⌘V</kbd> — which almost
nobody knows about, and which your fingers will not learn if they grew up on
Windows.

CutX makes the obvious shortcut do the obvious thing.

## How it works

**CutX never touches your files. It asks Finder to do the move.**

On <kbd>⌘X</kbd> it forwards a copy to Finder and remembers what you marked. On
<kbd>⌘V</kbd> it forwards Finder's own **Move Item Here**. That means undo
(<kbd>⌘Z</kbd>), the progress window for large transfers, the Replace / Keep Both
dialog, authentication for protected folders, and permission preservation all work
exactly as they normally do — because it really is Finder doing the work.

Outside Finder, CutX is invisible. <kbd>⌘X</kbd> in your editor cuts text, as
always. That guarantee is the most heavily tested part of the codebase.

CutX reads the physical key, not the character on it, so it works on any keyboard
layout — Arabic, AZERTY, QWERTZ. Press wherever X lives on your keyboard.

## Install

1. Download `CutX.zip` from [Releases](https://github.com/helalrules7/cutx/releases).
2. Unzip and drag **CutX.app** to Applications.
3. Open it. It lives in the menu bar — no Dock icon, no window on launch.
4. Grant the two permissions it asks for. The setup screen shows a live checklist
   and walks you through it; rows turn green the moment you flip the switch.

Requires macOS 13 or later. Signed and notarized by Apple, so it opens with one
click.

## Settings

Left-click the scissors in the menu bar to open the window.

| Tab | What's in it |
|---|---|
| **General** | Whether CutX is active, the permission checklist, `Also use ⌃X`, `Show cut indicator`, `Launch at login` |
| **Sounds** | On/off, volume, and six cut sounds with a ▶ on every row |
| **About** | Version, links, and the coffee button |

<div align="center">

<img src="screenshots/general.png" width="290" alt="General tab">
<img src="screenshots/sounds.png" width="290" alt="Sounds tab">

<img src="screenshots/about.png" width="290" alt="About tab">
<img src="screenshots/menu.png" width="270" alt="Right-click menu showing 4 items cut, Clear, Open CutX, Buy me a coffee, and Quit">

</div>

Right-click the icon for a short menu: what's currently cut, Clear, Open, Buy me a
coffee, and Quit.

## Languages

CutX speaks **English, العربية, Español, Français, Deutsch, Português (BR),
Русский, 中文 (简体), 日本語, Türkçe** and **Italiano**. It follows your Mac's
language by default, and you can override it in the General tab.

<div align="center">

<img src="screenshots/languages.png" width="290" alt="The language picker listing eleven languages, each named in its own script">
<img src="screenshots/arabic.png" width="290" alt="The General tab in Arabic, fully mirrored right to left">

<sub>Arabic is genuinely mirrored — checkboxes, columns and tabs all flip.</sub>

</div>

English and Arabic were written by the author. The other nine are
machine-translated and **have not been reviewed by a native speaker** — corrections
are very welcome, and take one line. See
[TRANSLATIONS.md](TRANSLATIONS.md).

## What it does not do

- **It does not dim the cut files inside the Finder window.** macOS exposes no API
  for that — the greyed-out look in Windows is part of Explorer itself. The
  menu-bar badge and the on-screen indicator are the honest alternative.
- It does not work in third-party file browsers or Open/Save dialogs.
- Pasting into a non-Finder app copies rather than moves. This is deliberate — it
  is the safe direction to fail in.

## Build from source

```bash
git clone https://github.com/helalrules7/cutx.git
cd cutx
./scripts/test.sh        # decision logic — 31 tests
./scripts/build-app.sh   # produces dist/CutX.app
```

`python3 scripts/make-sounds.py` regenerates every file in `Resources/sounds/`, and
`./scripts/make-icon.sh` regenerates the app icon.

Releases are produced by `./scripts/sign-and-notarize.sh`, which needs a Developer
ID certificate and a notarytool keychain profile.

Before tagging a release, work through
[docs/manual-testing.md](docs/manual-testing.md).

### How the code is arranged

Everything that can be tested without a keyboard, a Finder, or a granted permission
lives in `Sources/CutXCore`. `Sources/CutX` is the thin, untestable shell around it.

The whole behavior of the app funnels through one pure function:

```swift
func decide(event: KeyEvent, context: Context) -> Decision   // .passThrough | .cut | .paste
```

When anything is uncertain the answer is `.passThrough`. A key that behaves
normally is always better than a key that surprises you.

## Support

CutX is free and always will be. If it saves you some clicks:

☕ **[buymeacoffee.com/ahmedhelal](https://buymeacoffee.com/ahmedhelal)**

## License

MIT — see [LICENSE](LICENSE). Bundled sound credits are in
[ATTRIBUTIONS.md](ATTRIBUTIONS.md); translation credits and status are in
[TRANSLATIONS.md](TRANSLATIONS.md).

Made by [Ahmed Helal](https://github.com/helalrules7).
