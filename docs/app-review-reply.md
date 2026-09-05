# Reply to App Review — additional information request

Paste this into the App Store Connect review reply **and** into the Notes field of
App Review Information, so future submissions already have it.

---

## 2. Purpose and target audience

CutX adds Windows-style cut and paste for files in Finder.

**The problem.** macOS has no cut for files. Finder's Edit ▸ Cut is permanently
disabled and cannot be enabled by a third party. The real move gesture is ⌘C
followed by ⌥⌘V (Edit ▸ Move Item Here), which is undiscoverable — it does not
appear in the Edit menu until the Option key is held.

**The audience.** People who came to macOS from Windows and keep pressing ⌘X on a
file expecting it to move. This is a large and specific group; the muscle memory
does not transfer.

**The value.** CutX makes the shortcut people already press do what they already
expect. Press ⌘X on a file or folder in Finder, then ⌘V at the destination, and the
items move.

**What it deliberately does not do.** CutX never moves, copies, opens, reads or
modifies a file itself. On ⌘X it asks Finder to copy the selection; on ⌘V it
triggers Finder's own Move Item Here. Finder performs every file operation. This is
the central design decision: it means undo, the progress window, the Replace / Keep
Both dialog and authentication prompts all behave exactly as the user expects,
because they are Finder's, not a reimplementation.

Outside Finder, CutX is inert. ⌘X in a text editor still cuts text.

## 3. Setting up and accessing the main features

There is no account, no login, and no sample data. Nothing to sign in to.

CutX is a menu-bar app: on launch it shows no window and no Dock icon, only a
scissors icon in the menu bar.

**First run.** CutX opens its setup window automatically and asks for two
permissions. It shows a live checklist that turns green as each is granted, and an
animated illustration of where to click in System Settings.

1. **Accessibility** — required to see the ⌘X and ⌘V keystrokes. Grant it in
   System Settings ▸ Privacy & Security ▸ Accessibility.
2. **Automation (Finder)** — macOS prompts for this on the first ⌘X. Click OK.

**To exercise the main feature:**

1. In Finder, select any file or folder and press ⌘X. A short sound plays, a small
   indicator appears near the pointer, and the menu-bar icon shows a count.
2. Open a different folder and press ⌘V. The item moves and is gone from its
   original location.
3. Press ⌘Z. Finder undoes the move — this confirms Finder performed it, not CutX.
4. Open TextEdit, type and select some text, press ⌘X. The text is cut normally,
   confirming CutX does nothing outside Finder.

**To reach the settings:** left-click the menu-bar icon. Right-click shows a short
menu with the current cut state, Clear, Open and Quit.

## 4. External services, tools and platforms

**None.**

CutX makes no network connections of any kind. It has no analytics, no telemetry,
no crash reporting, no advertising, no accounts, no servers, no data providers, no
authentication services, no payment processing, and no AI services. It contains no
third-party SDKs or frameworks.

It uses only Apple frameworks: AppKit, ApplicationServices (CGEventTap),
Foundation, ServiceManagement, and Apple Events to communicate with Finder.

The full source is public at https://github.com/helalrules7/cutx and this is
verifiable from it.

## 5. Regional differences

**None.** CutX behaves identically in every region.

It ships localised interface text in eleven languages — English, Arabic, Spanish,
French, German, Brazilian Portuguese, Russian, Simplified Chinese, Japanese,
Turkish and Italian — and follows the system language, with a manual override in
the General tab. Arabic renders in a mirrored right-to-left layout. Only the
wording and layout direction change; every feature is available everywhere.

## 6. Regulated industry or protected third-party material

CutX operates in no regulated industry and provides no regulated service.

It bundles six short cut sounds. Three of the seven audio files are generated in
code by `scripts/make-sounds.py` in the repository and are original work. The other
four are trimmed from royalty-free sound effects downloaded from Pixabay and used
under the Pixabay Content License, which permits commercial use and modification
and does not require attribution. Each is nonetheless credited by author, title and
source URL in ATTRIBUTIONS.md in the public repository. This is why the Content
Rights question is answered "Yes".

No other third-party material is included.

## Note on permissions

The two permissions CutX requests are the reason it can work at all, and it is
worth stating plainly what it does with them.

The CGEventTap inspects only the key code of each keystroke to determine whether it
is ⌘X or ⌘V (optionally ⌃X and ⌃V). Every other key is passed through immediately,
untouched. Nothing is recorded, stored or transmitted — the app has no networking
code.

The Apple Events sent to Finder are exactly two: a request for the current
selection, and a request to perform Move Item Here.

The entire keystroke decision is one pure function, `decide(event:context:)`, in
Sources/CutXCore/Decision.swift, with unit tests covering every case — including
the guarantee that CutX passes ⌘X through whenever Finder is not frontmost.
