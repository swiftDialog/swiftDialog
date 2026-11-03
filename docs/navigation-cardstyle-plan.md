# Navigation view as a cards display style — design plan

Status: phase 1 first pass implemented on `feature/navigation-cardstyle` (2026-10-30).
Example config: `examples/navigation/navigation-example.json`.

## Summary

Add a sidebar navigation layout to swiftDialog, implemented as a **display style of the existing
cards/workflow feature** rather than a new config format. The same `cards` / `pages` / `workflow`
(etc.) JSON is used; a top-level key switches the presentation from the linear Next/Back wizard to
a `NavigationSplitView` where each card is a sidebar item and its content is the detail pane.

JSON-only (no CLI flags), consistent with cards.

## Config

```json
{
  "cardstyle": "navigation",
  "title": "Company Setup",
  "icon": "/path/to/logo.png",
  "button1text": "Done",
  "button2text": "Cancel",
  "width": 900, "height": 600,
  "cards": [
    { "cardId": "welcome", "section": "Getting Started",
      "title": "Welcome", "icon": "SF=hand.wave",
      "message": "..." },
    { "cardId": "account", "section": "Getting Started",
      "title": "Your Account", "icon": "SF=person.crop.circle",
      "textfield": [{ "title": "Email", "required": true }] },
    { "cardId": "apps", "section": "Software",
      "title": "Applications", "sidebartitle": "Apps", "sidebaricon": "SF=shippingbox",
      "icon": "/Applications/Self Service.app",
      "listitem": [] }
  ]
}
```

New keys:

| Key | Level | Purpose |
|---|---|---|
| `cardstyle` | top | `"wizard"` (default, current behaviour) or `"navigation"`. Explicit key rather than overloading one of the `appDefaults.cardTypes` keywords, which are synonyms today. |
| `section` | card | Sidebar section header. A new header starts whenever the value changes between consecutive cards; cards without it have no header. Keeps the flat array so the same JSON still works as a wizard. |
| `sidebartitle` | card | Optional override for the sidebar label (defaults to the card's `title`). |
| `sidebaricon` | card | Optional override for the sidebar icon (defaults to the card's `icon`). |
| `sidebarwidth` | top | Sidebar width in points. The sidebar is a fixed width (default 260pt, roughly System Settings). |

The navigation sidebar replaces the standard icon / infobox column, so a card's `icon` is shown
only in the sidebar (`centreicon` still places it above the message), and `infobox` /
`infoboxwidth` are unavailable in navigation style (ignored with a log warning).

Label rules:

- A card's `title` / `icon` drive **both** the sidebar row (small) and the detail pane header (full size), System Settings style.
- If a card inherits `title` / `icon` from the top level (or `icon` is `none`), the sidebar shows a fallback (no icon / "Page N") rather than repeating the global value on every row.
- The top-level `title` / `icon` render as the sidebar header (logo + name above the list).
- `cardId` is the stable page identifier (already passed to `onAdvance`) — used for command-file targeting.

## Reuse of the cards engine

| Piece | Status |
|---|---|
| `CardState.loadCards`, `DialogCard`, `getMergedConfiguration` | Reused as-is |
| `DialogUpdatableContent.applyCardConfiguration` | Reused; add a flag to skip the per-card window resize and strip top-level-only keys |
| `accumulatedInput`, `storeCurrentCardInput`, `restoreUserInput` | Reused as-is (index-keyed, random access already works) |
| Exit output (`getAllAccumulatedInput`, `Functions/System.swift`) | Reused as-is — identical output to cards, existing parsers keep working |
| `getInputAsVariables` | Change: currently iterates `navigationHistory`; in navigation style use every page with stored input |
| `validateRequiredFields` | Reused per page, on leaving a page |
| `onAdvance` callback | Fires when **leaving a page** (see below) |
| `branch`, `nextpage`, `finalpage` | Ignored in navigation style, log warning |
| `nextbuttontext`, `previousbuttontext`, Back/Next logic in `ButtonBarView` | Ignored; button1 = Done, button2 = Cancel |

New code: `CardState.select(index:)` (store input, switch, no history), a `NavigationDialogView`
shell selected in `dialogApp.swift` alongside Mini/Inspect/Presentation, sidebar row model, and
the per-page status tracking below.

Top-level only (ignored on individual cards, with a log warning): `width`, `height`, `position`,
`blurscreen`, `ontop`, `moveable`, `button1text`, `button2text`, `timer`.

## Validation and onAdvance (decided)

- On **leaving a page** (sidebar selection change):
  1. Store the page's input.
  2. Run `validateRequiredFields` for that page.
  3. Run `onAdvance` (if configured) with the page's input and `cardId`.
  4. Record the result as the page's status (`complete` / `incomplete`, with the error message).
  5. **Never block the switch** — the user can always move to another page.
- Per-page status is shown in the sidebar: a warning indicator on the incomplete item, and the
  section header also shows a warning when any item within it is incomplete.
- Warnings are only shown for pages the user has visited (left at least once). Unvisited pages
  never show a warning, though their required fields still block Done. A blocked Done reveals
  the warnings on every incomplete page.
- **Dismissal is blocked at the top level**: on Done, the current page is validated (same steps
  as leaving), then if any page is incomplete the dialog does not exit. Show the existing error
  sheet summarising which pages need attention, and select the first incomplete page.
- Pages never visited that contain `required` fields: pre-scan card JSON at load and mark them
  incomplete from the start, so Done can't succeed without visiting them. Pages with no required
  fields start complete.
- `onAdvance` failure marks the page incomplete with the callback's error message (same treatment
  as a validation failure).
- Cancel (button2) and other non-Done exits are not blocked.

## Phases

1. **MVP** — `cardstyle` + `section` / `sidebartitle` / `sidebaricon` parsing; `select(index:)`;
   `applyCardConfiguration` no-resize / top-level-only flag; `NavigationDialogView`
   (`NavigationSplitView`, `List(selection:)`, `Section`, `Label`, existing icon resolution);
   detail pane reuses `TitleView` + `DialogView` + `TaskProgressView`; global button bar;
   `getInputAsVariables` fix; validation/onAdvance-on-leave with sidebar + section indicators and
   top-level Done blocking.
2. **Command file** — `navigation: select <cardId>`, `navigation: status <cardId> success|fail|wait|progress`,
   `navigation: badge <cardId> <n>`, `navigation: disable|enable <cardId>`; per-card `status` /
   `badge` / `disabled` keys. Existing commands continue to target the visible page only.
3. **Polish** — sidebar header/footer, ⌘1–⌘9 shortcuts, collapsible sections.

## Risks / notes

- `appArguments`, `appvars`, `userInputState` are global and rebuilt on every page switch (as cards
  already does). Timer stays global; progress resets per page (as `applyCardConfiguration` does).
- Heavy content (web, video) is rebuilt on every switch. Acceptable for MVP; caching would require
  breaking the single-global-state model.
- Deployment target is macOS 15, so `NavigationSplitView` and related APIs are available.
- The Inspect `SidebarNavigationModule` is not a fit (tied to `InspectConfig.ItemConfig`, stepper-oriented).
