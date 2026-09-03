# Translations

CutX ships in eleven languages. English and Arabic were written by the author.
**The other nine were machine-translated and have not been reviewed by a native
speaker.**

They are grammatically sound, but interface terminology has conventions that a
correct translation can still miss — "Cut", in a file manager, has an established
term in each platform's vocabulary that is not always the dictionary word.

If something reads wrong in your language, a one-line pull request against
`Resources/<code>.lproj/Localizable.strings` is very welcome, and you will be
credited here.

| Language | Code | Status |
|---|---|---|
| English | `en` | Author |
| العربية | `ar` | Author |
| Español | `es` | Needs native review |
| Français | `fr` | Needs native review |
| Deutsch | `de` | Needs native review |
| Português (BR) | `pt-BR` | Needs native review |
| Русский | `ru` | Needs native review |
| 中文 (简体) | `zh-Hans` | Needs native review |
| 日本語 | `ja` | Needs native review |
| Türkçe | `tr` | Needs native review |
| Italiano | `it` | Needs native review |

## Known limits

**Plural forms are approximated as English-style singular/plural.** Russian and
Arabic have richer plural rules — Arabic distinguishes singular, dual, and several
plural ranges — and CutX does not yet handle them correctly. A count of 2 in Arabic
should read "عنصران", not "2 عناصر".

## Adding a language

1. Copy `Resources/en.lproj/Localizable.strings` to `Resources/<code>.lproj/`.
2. Translate the values. Leave the keys alone.
3. Keep `⌘X`, `⌘V`, `⌘Z` and `⌃X` as symbols — they are what is printed on the key.
4. Do not translate "CutX", "Finder", "GitHub", "MIT", or "ATTRIBUTIONS.md".
5. Add the case to `Language` in `Sources/CutXCore/Language.swift` and the code to
   `CFBundleLocalizations` in `Resources/Info.plist`.

Every file must contain exactly the same keys as `en.lproj`. A missing key shows the
raw key name in the interface. To check:

```bash
diff <(grep -o '^"[^"]*"' Resources/en.lproj/Localizable.strings) \
     <(grep -o '^"[^"]*"' Resources/<code>.lproj/Localizable.strings)
```

Right-to-left languages need no layout work — the interface is built with Auto
Layout and mirrors itself.
