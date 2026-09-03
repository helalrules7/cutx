# CutX — Design Spec

**Date:** 2026-09-03
**Status:** Approved

## Summary

CutX is a free macOS menu-bar utility that adds Windows-style cut-and-paste for
files in Finder. The user presses `⌘X` on a file or folder, hears a sound, sees a
brief indicator, then presses `⌘V` elsewhere and the items **move** — they are
removed from the original location.

The app runs as a menu-bar-only agent with no Dock icon and no window on launch.

## Goals

- `⌘X` / `⌘V` move files in Finder, matching Windows behavior.
- Completely transparent outside Finder — `⌘X` in any other app cuts text as usual.
- Audible and visible feedback at cut time.
- Menu-bar UI with four settings: sound, indicator, `⌃X`, launch at login.
- Free, with a Buy Me a Coffee link.

## Non-Goals

- Third-party file browsers (Path Finder, ForkLift) and Open/Save dialogs.
- Dimming ("ghosting") icons inside Finder windows — macOS exposes no API for this.
- Moving files when pasting into a non-Finder app (behaves as a copy; safe by design).
- Auto-update. Deferred to a later version; needs Sparkle plus appcast hosting.

## Key Decisions

### 1. Hotkeys

`⌘X` / `⌘V` are the defaults. `⌃X` / `⌃V` are supported behind an opt-in setting
("Also use ⌃X"), off by default.

Rationale: `⌘X` is what Mac users reach for; `⌃X` is what the Windows muscle
memory expects. Supporting both costs little.

### 2. Scope

Finder windows and the Desktop only. In every other context the key event passes
through untouched.

Rationale: Finder can be queried reliably over Apple Events. Reading other apps'
Accessibility trees is fragile and breaks on OS updates.

### 3. Move engine — delegate to Finder

CutX never touches a file. Finder performs every move.

- On cut: forward `⌘C` to Finder, record state locally.
- On paste: forward `⌥⌘V` ("Move Item Here") to Finder, clear state.

This inherits Finder's undo (`⌘Z`), progress UI for large transfers, name-conflict
dialogs, authentication prompts for protected locations, cross-volume and network
moves, and permission preservation — none of which we then have to write or test.

Rejected: implementing the move with `FileManager`. It would require re-writing
conflict detection, cross-volume copy, progress reporting, and rollback — the code
paths where a bug destroys user data.

### 4. Visual feedback

A small translucent HUD appears near the pointer at cut time showing the item count,
then fades. The menu-bar icon switches to a "loaded" state with a badge count that
persists until paste or clear.

Rejected: overlaying a gray rectangle on the Finder icons via the Accessibility
tree. It desynchronizes on scroll, window move, view change, or Space switch —
worse than showing nothing.

Rejected: applying a temporary Finder tag. It mutates the user's metadata and leaves
stale tags behind if the app terminates unexpectedly.

### 5. Distribution

Developer ID signed and notarized. The user already holds an Apple Developer
account. This means a one-click install and, critically, Accessibility permission
that survives updates (ad-hoc signing revokes it on every rebuild).

### 6. Build system

Swift Package Manager plus a shell script that assembles the `.app` bundle. No
`.xcodeproj`. Xcode is not installed on the development machine, and a text-only
project produces readable diffs.

## Architecture

Application type: `LSUIElement` agent. No Dock icon, no launch window.
Minimum OS: macOS 13 (required by `SMAppService`).

### Components

| Component | Responsibility |
|---|---|
| `HotkeyMonitor` | Owns the `CGEventTap`. Calls `decide()` and either suppresses or passes each event. |
| `Decision` | Pure function mapping (key event, context) to `.passThrough` / `.cut` / `.paste`. All branching logic lives here. |
| `FinderBridge` | All Apple Events to Finder: query selection, send `⌘C`, send `⌥⌘V`. |
| `CutState` | Single source of truth for what is marked and whether it is still valid. Watches pasteboard `changeCount`. |
| `MenuBarController` | `NSStatusItem`, menu construction, badge state. |
| `CutHUD` | Borderless panel shown at cut time. |
| `SoundPlayer` | Plays the bundled cut and paste sounds. |
| `Preferences` | Four booleans in `UserDefaults`. |
| `PermissionsCoordinator` | Checks Accessibility and Automation; drives the onboarding window. |

### Cut flow

```
⌘X pressed
  → Finder frontmost?        no → pass through (normal text cut)
  → Selection non-empty?     no → pass through
  → suppress event
  → send ⌘C to Finder
  → arm CutState, record pasteboard changeCount
  → play sound, show HUD, update badge
```

### Paste flow

```
⌘V pressed
  → Finder frontmost?              no → pass through
  → CutState armed?                no → pass through
  → pasteboard changeCount intact? no → clear state, pass through
  → suppress event
  → send ⌥⌘V to Finder
  → clear state, play sound, clear badge
```

### Two constraints baked into the architecture

**The event tap must return immediately.** Apple Events to Finder take tens of
milliseconds; blocking inside the tap callback stalls all keyboard input system-wide.
The selection state is therefore read from a cache refreshed when Finder becomes
frontmost, and all Finder communication happens after the decision is returned.

**Pasteboard ownership must be verified before every paste.** If the user cuts files
and then copies anything else, `⌥⌘V` would act on the wrong content. `CutState`
records the pasteboard `changeCount` at cut time and invalidates itself the moment it
changes. This is the highest-severity failure mode in the app, so the check is a
precondition of the paste path rather than an added guard.

## User Interface

Menu-bar menu:

```
✂︎ 3 items cut
   Report.pdf, Screenshots, invoice-2024.xlsx
   Clear
───────────────────────────────
✓ Play sound
   Cut sound                                ▸
✓ Show cut indicator
✓ Also use ⌃X
✓ Launch at login
───────────────────────────────
   Buy me a coffee  ☕
   About CutX
   Quit CutX                                  ⌘Q
```

The "Clear" item is a menu action only; it is not a global shortcut.

No separate preferences window. The only window is a first-run onboarding screen
explaining the two required permissions, with a button that opens the exact System
Settings pane. It stops appearing once both permissions are granted.

Buy Me a Coffee link: `https://buymeacoffee.com/ahmedhelal` (suggested tier: $3).

Sounds: seven short audio files bundled with the app — six selectable cut sounds
and one paste sound. "Play sound" controls whether any sound plays at all; a
"Cut sound" submenu picks which one, and selecting an entry previews it
immediately so the user can compare without leaving the menu.

The six cut sounds are `snip` (default) and `tick`, both synthesized, plus
`scissors`, `paper`, `knife`, and `bush`, trimmed from royalty-free Pixabay
recordings. Every sound is at most 130 ms and normalized to a common peak: a UI
sound must finish before the user's fingers leave the keys, and no option may be
noticeably louder than another. `scripts/make-sounds.py` regenerates all of them.
Credits are in `ATTRIBUTIONS.md`.

The paste sound is fixed, and lower in pitch than any cut sound, so the ear reads
it as "landed" rather than "lifted".

Launch at login: `SMAppService.mainApp`.

## Error Handling

| Condition | Behavior |
|---|---|
| Accessibility permission missing | Onboarding window; hotkeys inert; menu shows a warning item. |
| Automation permission denied | Same, with the Finder-specific instruction. |
| Event tap disabled by the system (timeout) | Re-enable it from the tap callback; log the occurrence. |
| Finder not responding to Apple Events | Pass the event through so the user is never blocked, clear state. |
| Pasteboard changed after cut | Clear state, clear badge, pass the paste through. |
| Source files deleted before paste | Finder reports it; CutX takes no action. |

The recurring principle: when anything is uncertain, pass the event through. A key
that behaves normally is always better than a key that does something unexpected.

## Testing

`decide()` is a pure function, so the entire decision surface is unit-testable
without a keyboard or a running Finder:

- `⌘X`, Finder not frontmost → `.passThrough` (the most important test in the project)
- `⌘X`, Finder frontmost, empty selection → `.passThrough`
- `⌘X`, Finder frontmost, non-empty selection → `.cut`
- `⌘V`, state armed, pasteboard intact → `.paste`
- `⌘V`, state armed, pasteboard changed → `.passThrough`
- `⌘V`, state not armed → `.passThrough`
- `⌃X`, setting disabled → `.passThrough`
- `⌃X`, setting enabled, Finder frontmost, selection → `.cut`
- `⌘⇧X` → not a cut

Also unit-tested: `CutState` invalidation and `Preferences` defaults and persistence.

Event injection, Finder integration, permissions, and launch-at-login cannot be
tested automatically. They are covered by a written checklist in
`docs/manual-testing.md`, run before each release. This is stated plainly rather
than claimed as automated coverage.
