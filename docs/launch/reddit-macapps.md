# r/macapps post — APPROVED 2026-09-17, ready to post

CutX is live: **https://apps.apple.com/app/id6808423707** (App ID 6808423707). That makes the account **Tier 1** under
r/macapps' trust rules ("Mac App Store developers"), so a main-feed post is unlocked.
Still required regardless of tier: **10 local karma in r/MacApps** from genuine comments, a "I read the rules"
acknowledgement, the `[OS]` title prefix, PCP body structure, the **Free** flair, and
**no em dashes** anywhere (Reddit's auto-filter). One promo post per 30 days, counted
even if removed — so it must be right the first time.

r/MacOS: promotional posts **Saturdays (UTC) only**. The store requirement is now met.
Next window: **Saturday 2026-09-19 (UTC)**, with the different wording below.

Hacker News: Show HN is throttled for new accounts (karma 1). Build ordinary comment
history first; the draft is below.

## Title

    [OS] CutX: free, open-source Windows-style cut and paste for files in Finder

## Body

PROBLEM
macOS has no cut for files. Finder's Cmd+X is permanently greyed out, and the real move gesture (Cmd+C, then Option+Cmd+V) is hidden until you hold Option. Coming from Windows, my hands never adjusted, so I built CutX. Press Cmd+X on a file or folder, then Cmd+V where you want it, and the items move.

The design choice that matters: CutX never touches your files. It presses Finder's own Copy for you, reads what Finder put on the clipboard, then presses Finder's own Move Item Here. Finder performs the move, so Cmd+Z undo, the progress window, Replace/Keep Both and permission prompts all work exactly as they normally do. Outside Finder it is inert: Cmd+X in your editor still cuts text.

COMPARISON
Command X (Mac App Store, about $4) does the same core thing and is well made. CutX differs in three ways: it is free and MIT licensed with the full source public, it ships in eleven languages including a properly mirrored Arabic UI, and it needs only the Accessibility permission (no Automation prompt). If you already own Command X, you do not need this.

Honest limitations, same as any app in this category: it cannot dim the cut files inside the Finder window (macOS gives third-party apps no way to draw there; you get a menu-bar count and a brief indicator instead), it works in Finder and on the Desktop only, and pasting into a non-Finder app copies rather than moves, which is the safe direction to fail in.

PRICING
Free. No ads, no tracking, no account, no network access. MIT licensed. Signed and notarized by Apple. Also on the Mac App Store.

GitHub: https://github.com/helalrules7/cutx
Mac App Store: https://apps.apple.com/app/id6808423707
Site and privacy policy: https://ahmedhelal.dev/cutx
Support: https://ahmedhelal.dev/cutx/support

I would genuinely like to hear what breaks or what feels wrong.

## r/MacOS (Saturday UTC, different wording)

Title: Finally made Cmd+X cut files in Finder, free and open source, feedback welcome

Coming from Windows, Cmd+X doing nothing on files drove me up the wall, so I built a small menu-bar app that fixes it. Cmd+X to cut, Cmd+V to move. Finder performs the move itself (the app just triggers Finder's own Copy and Move Item Here), so Cmd+Z undo and all the normal dialogs still work. Free, MIT, no tracking, needs only the Accessibility permission. It cannot grey out the cut files like Windows does, macOS does not allow that, so there is a menu-bar count instead. Mac App Store: https://apps.apple.com/app/id6808423707 · Source: https://github.com/helalrules7/cutx

## Show HN (after the account has some history)

Title: Show HN: CutX – Windows-style cut and paste for files in macOS Finder
URL: https://github.com/helalrules7/cutx
First comment: see the author comment drafted 2026-09-14 in the conversation; key
points are the Finder-performs-the-move design, physical key codes for layout
independence, and the App Store re-architecture that removed Apple Events.
