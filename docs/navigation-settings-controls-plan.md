# Settings-style pages: groups, action buttons and new controls — discussion plan

Status: for discussion, nothing implemented (2026-11-03).
Builds on the navigation card style (`docs/navigation-cardstyle-plan.md`).

## Goal

Make navigation-style pages work like System Settings panes: controls arranged in titled
groups with explanatory text, buttons that do something without closing the dialog, and the
controls settings screens need (sliders, steppers, segmented choices, colour pickers,
read-only values).

Priority order (from discussion): **groups → action buttons → new controls → the rest**.

## How input works today (constraints)

- Each input type is a separate array in `UserInputState` (`textFields`, `checkBoxes`,
  `dropdownItems`, `listItems`). JSON defines them as per-type arrays on the card
  (`textfield`, `checkbox`, `selectitems`, `listitem`).
- `MessageContent` renders one block per type, in `appvars.viewOrder` order. Each view
  (`TextEntryView`, `CheckboxView`, `DropdownView`, `RadioView`, `ListView`) draws **all**
  items of its type inside its own rounded container.
- Output, validation (`validateRequiredFields`), cards input store/restore
  (`collectCurrentUserInput`, `restoreUserInput`) and command-file updates all address items
  by **array index** (and output by `name`, falling back to title/label).

So today a page can only ever show "all text fields, then all checkboxes, ...". Anything that
keeps those arrays and indices intact keeps output, validation and restore working for free.

---

## 1. Groups

### Options

**A. Tag each control with a `group` key**

```json
"textfield": [{ "title": "Proxy Host", "name": "proxyhost", "group": "Proxy" }],
"checkbox":  [{ "label": "Use proxy", "name": "useproxy", "group": "Proxy" }]
```

- Smallest change to config. Groups render in order of first appearance.
- Within a group, order still follows type (`viewOrder`), so you can't put a switch *between*
  two text fields. No natural home for group title/footer text.

**B. A list of groups that references controls by `name`** *(chosen — expressed through
`vieworder`, see "One key: `vieworder`" below)*

```json
"vieworder": {
  "groups": [
    { "title": "Proxy",
      "description": "Only change these if asked to by IT.",
      "items": ["useproxy", "proxyhost", "proxyport"] },
    { "title": "VPN",
      "items": ["vpngateway", "vpnatlogin"] }
  ]
},
"checkbox":    [{ "label": "Use proxy", "name": "useproxy" }],
"textfield":   [{ "title": "Proxy Host", "name": "proxyhost" },
                { "title": "Port", "name": "proxyport" }],
"selectitems": [{ "title": "Gateway", "name": "vpngateway", "values": ["Auto", "Sydney"] }]
```

- Controls are defined exactly as today; the groups only say *where* they go. Explicit order,
  so different types can be mixed freely. Group title, description (header) and footer have an
  obvious home.
- Arrays and indices are untouched → output, validation, restore keep working.
- Authors must give referenced controls a `name` (checkboxes can fall back to `label`).

**C. One mixed list of control objects**

```json
"vieworder": { "groups": [{ "title": "Proxy", "items": [
  { "type": "switch", "label": "Use proxy", "name": "useproxy" },
  { "type": "textfield", "title": "Proxy Host", "name": "proxyhost" }
]}]}
```

- Reads most naturally, but it is a second way to define every control — exactly the "new
  config format" we avoided for navigation. Parsing would have to fan out into the per-type
  arrays anyway.

### Recommended behaviour (option B)

- Set with `vieworder` (string or object). Like any argument in cards mode it can be set at the
  top level as a default and overridden per card. Pages without it render as today.
- Each group renders as a System Settings-style rounded box: optional title above,
  optional `description` above the rows, optional `footer` below.
- Rows inside a group are separated by dividers, label on the left, control on the right.
- Controls not referenced by any group render in a final untitled group (logged), so nothing
  silently disappears.
- A name referenced by a group but not defined → logged and skipped.
- A name referenced twice → first occurrence wins, logged.

### Plumbing

The main work: each input view currently draws its whole array plus its own container. Split
each into a **row** view (one item, by index) and the existing **container** view (which now just
loops over rows). The grouped renderer then asks for individual rows by index.

| View | Row extraction effort |
|---|---|
| `CheckboxView` / switches | Low — rows already independent |
| `DropdownView` (menu/searchable/multiselect) | Medium — per-item state is already indexed |
| `RadioView` | Low |
| `TextEntryView` | Medium — onSubmit/validation/confirm field logic per index |
| `ListView` | Not a row — stays a self-contained block that can be placed in a group as one item |

Group lookup: build a `name → (type, index)` map when the card is applied.

### Scope

Groups also answer a long-standing request for standard dialogs: mixing input types (text
field, then checkbox, then text field). So groups should work in **both** layouts. In the
standard layout the grouped block takes the place of the per-type input blocks; message
placement etc. is unchanged.

### Row refactor and backward compatibility

Requirement: existing configs (JSON or command line) must behave exactly as before; new features
are additive.

What the views look like today (checked 2026-11-03):

- Every input view is: `init` (setup) → guard → `VStack { ForEach(index) { row } }` → container
  styling (`font`, `padding(10)`, `background`, `cornerRadius(8)`).
- Each row only reads its own index from the shared arrays. No row measures or depends on its
  siblings (label widths come from the window width, not from other labels).

So the refactor is mostly *moving* code: lift each row body into a `XRow(index:)` view and have
the existing container loop over it. The container keeps its guard, `ForEach`, dividers and
styling, so the default path renders the same views in the same order.

Points that need care:

| Item | Why | Handling |
|---|---|---|
| `DropdownView` / `RadioView` hold `@State selectedOption: [String]` for the whole array | A row rendered on its own has no container state | Rows take a `Binding<String>`. The container passes `$selectedOption[index]` as today; the grouped renderer uses a small per-row wrapper seeded from `userInputState` |
| `DropdownView.init` rewrites `---` divider values to be unique; `RadioView.init` sets an empty radio default to the first value | Side effects in view init; skipping them in the grouped path would change menus / **output** | Move both into one shared preparation step run once when inputs are parsed (or on both paths) |
| Radio dividers use `index < radioCount-1` | Existing quirk tied to the container | Leave the container untouched; grouped renderer draws its own dividers |
| Card-transition guards (`count == userInputState.count`) | Prevent out-of-range during page switches | Every row view re-checks its index is in bounds |

Activation: the grouped renderer is used **only** when `vieworder` is a JSON object, or a CSV
string that takes the input ordering path (see below). Every existing `vieworder` value is a CSV
of type names, and dialogs without `vieworder` are unaffected, so CLI-built and existing JSON
dialogs always take the unchanged container path.

### Command-line layout: extended `--vieworder`

Grouping is presented as an **enhancement to view ordering**, not a new option. The CSV form of
`--vieworder` is extended so it can also name individual inputs and start groups:

```
--vieworder "[Account],fullname,email,newsletter,[Preferences],textfield,checkbox"
```

How `--vieworder` works today: the CSV is matched against the seven type names
(`textfile`, `webcontent`, `listitem`, `checkbox`, `textfield`, `radiobutton`, `dropdown`).
Matching types move to the front in the order given, remaining types are appended in default
order, and **unknown tokens are silently ignored**. It is also read from JSON (`"vieworder"`).

Proposed token rules:

| Token | Meaning |
|---|---|
| A type name (`textfield`, `checkbox`, ...) | All inputs of that type **not placed individually elsewhere**, as one block (today's behaviour) |
| Any other word | An input with that `name` (falling back to title/label, as output does). Text fields, select items and checkboxes all support `name=` on the command line |
| `[Title]` | Starts a group with that title; following items go in it. `[]` starts an untitled group |

#### Two paths: type ordering (existing) and input ordering (new)

The CSV value is classified once, after inputs have been parsed (where `reorderViewArray` runs
today, so input names are known):

- **Type ordering path — unchanged code.** Every token is a type name or an unknown word that
  matches no input, and there is no `[...]` token. Runs today's `reorderViewArray` exactly,
  including silently ignoring unknown words.
- **Input ordering path — new.** Any `[...]` token, or any token that matches an input name,
  switches to the layout builder.

#### Reserved words

The seven type names are **reserved words in the input ordering path only**:

- Inputs may still be *named* `checkbox`, `textfield`, etc. — that works today and keeps working
  everywhere (output, validation, type ordering). Nothing about defining such an input changes.
- In the input ordering path, a reserved word always means "the block of that type", never an
  input name. An input whose name is a reserved word can't be placed individually; it is shown
  in its type's block (or with the unplaced inputs). A warning is logged naming the input and
  suggesting a different `name`.
- Same rule for `items` in the JSON form, so both forms behave identically.

Complexity: low — one pass over the tokens against two sets (reserved words, input names).

#### Error handling (input ordering path)

Consistent with how swiftDialog treats bad input elsewhere: **log a warning and keep going**,
never fail the dialog.

| Problem | Behaviour |
|---|---|
| Unknown token (no type, no input with that name) | Skipped, warning logged (type ordering path stays silent, as today) |
| Input placed twice | First placement wins, warning |
| Input named with a reserved word | Shown in its type block, warning (above) |
| Type block whose inputs were all placed individually | Renders nothing |
| Value starts with `{` but isn't valid JSON | Warning, then treated as CSV (same fallback as `--textfield`) |

#### Other rules

- **Unplaced inputs** are appended after everything listed, in default type order — the same
  "append the rest" rule as today, so nothing disappears.
- **Tokenising:** plain split on commas. Group titles can't contain commas in the CSV form —
  use the JSON form for that (low priority by decision; JSON is the advanced option).
- `textfile`, `webcontent` and `listitem` stay whole blocks and can be placed like any item.
- **Edge case to accept:** a word that is ignored today as unknown but happens to equal an input
  name now places that input. Unlikely; release-note line.

#### JSON form of `--vieworder`

Following the per-argument JSON pattern used by `--textfield`, `--checkbox` and `--selectitem`:
if the value parses as a JSON **object**, it is built from the same schema as the JSON config;
otherwise it is treated as the CSV form.

```
--vieworder '{"groups": [
  {"title": "Network, VPN", "description": "Company network settings",
   "items": ["vpnatlogin", "vpngateway", "dropdown"]}
]}'
```

- Only objects are accepted, not bare arrays: `[]` is valid JSON *and* a valid CSV group token,
  so arrays would be ambiguous.
- Shared builder (`makeLayout(from:)`, like `makeCheckBox(from:)`) used by the CLI JSON form and
  the JSON config, so the two can't drift.

#### One key: `vieworder` (decided 2026-11-03)

There is no separate `groups` key. `vieworder` accepts three forms, all an enhancement of the
existing option:

| Where | Form | Example |
|---|---|---|
| Command line or JSON config | CSV string — existing type ordering, plus input names and `[Title]` groups | `"textfield,checkbox"` / `"[Account],fullname,newsletter"` |
| Command line | JSON object string | `--vieworder '{"groups": [...]}'` |
| JSON config | JSON object | `"vieworder": {"groups": [...]}` |

- Communicated as "view ordering can now place individual inputs and group them", not as a new
  option. Existing `vieworder` docs and examples stay valid.
- Plumbing note: `vieworder` is currently read as a string (`CommandlineArgument.evaluate`). In
  JSON config an object value needs a special case (check `json["vieworder"].type ==
  .dictionary` before the string path), the same kind of handling `textfield` / `checkbox`
  arrays already get.
- One internal layout model: CSV, CLI JSON and JSON config all build the same ordered list of
  groups → items, rendered by the same grouped renderer.
  `[Group 1],textfield1,checkbox1` ≡ `{"groups": [{"title": "Group 1", "items": ["textfield1", "checkbox1"]}]}`.
- CSV limits (by design): no group description/footer, no commas in titles, nothing for later
  features like `enabledif`. The JSON form has all of them.

### Verification

- `dialogTests/golden-output.sh verify` before/after the refactor: stdout + exit codes must not
  change. Note its documented gap: select-list and `--json` output aren't captured on its
  command-file quit path.
- Unit tests for the group resolver (name lookup, missing/duplicate names, unreferenced
  controls) and the shared preparation step (radio default, divider uniquing) — this is where
  output could change.
- Visual check of standard dialogs with every input type, before/after (no snapshot harness
  exists; possible addition: `ImageRenderer` snapshots of container views in unit tests).

---

## 2. Action buttons

Status: design direction agreed in discussion (2026-11-03); details below for review.

Buttons that **act immediately** when clicked: open a URL, run a shell command, or open a
sheet. They are an **input type** (defined like other controls, placed by `name` with
`vieworder`, usable in both layouts), not dialog-dismissing buttons like button1/button2.

Principle (2026-11-03): swiftDialog **provides the means, it doesn't parent** how actions are
used. Actions run "in the blind": start them, log what happens, don't judge success.

Reference examples (System Settings):

1. **Push buttons**, right-aligned row, no label: "Shortcuts…", "Hot Corners…", and a round
   "?" (symbol only).
2. **Colour swatches**: label on the left, a row of plain `circle.fill` symbols with no button
   surround; the selected one has a ring, its name shown underneath.
3. **Image choices**: label on the left, a row of thumbnails (Light / Dark / Auto) with a
   caption under each; the selected one has a ring and bold caption.

### Model: a button row

One control = one **row** of one or more buttons, laid out horizontally.

```json
"buttons": [
  {
    "name": "accent",
    "title": "Colour",
    "style": "plain",
    "selectable": true,
    "default": "blue",
    "items": [
      { "value": "multicolour", "label": "Multicolour", "image": "/path/multicolour.png",
        "shell": "defaults write com.example accent multicolour" },
      { "value": "blue",   "label": "Blue",   "symbol": "circle.fill,colour=blue",
        "shell": "defaults write com.example accent blue" },
      { "value": "purple", "label": "Purple", "symbol": "circle.fill,colour=purple",
        "shell": "defaults write com.example accent purple" }
    ]
  },
  {
    "name": "desktoptools",
    "items": [
      { "label": "Shortcuts…",   "url": "x-apple.systempreferences:com.apple.Desktop-Settings.extension" },
      { "label": "Hot Corners…", "shell": "/usr/local/bin/open-hot-corners" },
      { "label": "Help", "symbol": "questionmark", "display": "symbol",
        "sheet": "## Desktop & Dock\nHot corners let you trigger an action by moving the pointer to a corner." }
    ]
  }
]
```

#### Row keys

| Key | Meaning |
|---|---|
| `name` | Used by `vieworder` and for output |
| `title` | Row label on the left (like other inputs). No title → buttons only, aligned by `alignment` |
| `alignment` | `leading` / `trailing` (default when no title) / `center` |
| `style` | `bordered` (default — standard push button, as in example 1) or `plain` (no surround — swatches, thumbnails) |
| `selectable` | Row behaves like a radio choice: one item is selected (ring), selection is output. Default `false` |
| `default` | `value` of the initially selected item (selectable rows) |
| `size` | Symbol/image size in points (default per style; e.g. 28 for swatches) |
| `labelposition` | Where item labels go: `inline` (default for `bordered`), `below` (captions, examples 2–3), `selected` (only under the selected item, example 2), `hidden` |
| `detail` | Subtext under the row `title` (shared with all inputs, §4) |

#### Item keys

| Key | Meaning |
|---|---|
| `label` | Text. Also used as tooltip and accessibility label when not displayed |
| `symbol` | SF Symbol, same spec as `--button1symbol` (`name,colour=…,size=…,palette=…` or JSON object) — reuse `normalizedButtonSymbol` |
| `image` | Image path / URL (rendered via `IconView`) |
| `display` | `both` (default when label + symbol/image), `symbol` (symbol/image only — label kept for tooltip/accessibility), `label` |
| `value` | Output value when selected (selectable rows). Defaults to `label` |
| `type` | `action` (default), `colour` or `info` — see "Button types" |
| `url` / `shell` / `sheet` | The action — exactly one (`action` type) |
| `confirm` | Optional confirmation prompt before running |
| `disabled` | Shown but not clickable |

Display rules:
- Symbol/image **only** (no `label`) → shows only the symbol. With `style: bordered` a
  symbol-only button is drawn circular (the "?" in example 1).
- Label **and** symbol/image → both by default; `display: "symbol"` shows only the symbol but
  keeps the label for the tooltip and VoiceOver. This covers both "symbol only by default" and
  "symbol only as an option" without losing accessibility.

### Actions

| Action | Behaviour |
|---|---|
| `url` | Opens immediately (`openSpecifiedURL`, as button actions do today) |
| `shell` | Runs immediately via `/bin/zsh -c`, **asynchronously** — the UI never blocks. Button disabled while running |
| `sheet` | Shows a sheet with markdown text — like `--helpmessage`, but any message. String shorthand, or object: `{"message": "...", "image": "...", "buttontext": "OK"}`. Supports `.md` file paths and `{system tags}` the same way `--helpmessage` does. Read-only: no inputs on the sheet (for now) |

Shell specifics:
- Run "in the blind" on a background thread: start the process, log stdout/stderr and the exit
  code when it finishes, and otherwise don't care whether it worked — that's the admin's
  responsibility. No success/failure indicator on the button; the exit code is only recorded
  for the final output (see Output).
- The existing `shell()` is synchronous and blocks until the command finishes; add a background
  variant (`Process` + `terminationHandler`) that logs output and exit code.
- **Command output is never printed to swiftDialog's stdout.** Today's button1 shell action
  prints its output; doing that here would corrupt the output scripts parse. Log only.
- Actions may do anything, including running scripts that send command-file updates back to
  the dialog. That's supported, not special-cased.
- Security: same trust model as `button1shellaction` — commands come from the author's config.

### Button types (decided 2026-11-03)

An item's `type` decides what it is. Colour picker and read-only info rows are button types
rather than separate controls, so they share the row model, `vieworder` placement, `title` /
`detail`, and output keys.

| `type` | What it is | Output |
|---|---|---|
| `action` (default) | Clickable button running `url` / `shell` / `sheet` (above) | clicked + exit code |
| `colour` (alias `color`) | Native colour well. `value` = initial hex, `opacity` bool | hex string, e.g. `"accent" : "#0066FF"` |
| `info` | Read-only value shown on the right (no surround, not clickable), e.g. title "Serial Number", value `{serialnumber}`. System tags substituted | none |

Examples:

```json
{ "name": "serial", "title": "Serial Number", "type": "info", "value": "{serialnumber}" }
{ "name": "brand", "title": "Highlight colour", "detail": "Used for window accents",
  "type": "colour", "value": "#0066FF" }
```

Notes:
- `info` replaces the markdown-table workaround in the settings example. Updating its value from
  the command file is a later addition.

- `colour` items **don't run actions** for now (decided 2026-11-03) — the chosen colour is
  returned in the output only. Running a command with the picked value could be added later
  (it would need the item's own value substituted, and should fire once the choice settles,
  not on every intermediate colour while dragging).

### Running actions and quitting (decided 2026-11-03)

swiftDialog tracks the processes it started (an "action registry").

| How the dialog is closing | Running actions |
|---|---|
| **button1 or button2** (including their Return/Escape shortcuts) | **Blocked**: a sheet says one or more button actions are still processing; the dialog stays open |
| **Everything else** — info button with quit, quit key, timer expiry, command-file `quit:` | **Force quit**: not blocked; running actions are killed, then the dialog exits with its normal exit code |
| **Terminated** — SIGTERM (e.g. from `dialogcli` on SIGINT), SIGINT, SIGHUP | Running actions are killed, then the process dies by the same signal as today |
| **SIGKILL** (`kill -9`) | Can't be intercepted by any process — children are orphaned. Documented limitation |

Exit code 40 belongs to `dialogcli` (checked): on SIGINT it sends SIGTERM to the Dialog process
and exits 40 itself, and otherwise returns Dialog's termination status. So Dialog doesn't adopt
exit 40.

Plumbing notes:
- Dialog has **no signal handling today**, and child processes are not killed when it dies.
  Add SIGTERM/SIGINT/SIGHUP handlers that kill registered actions, then **restore the default
  handler and re-raise the signal**. The process still dies by that signal, so `dialogcli`,
  MDM tooling and scripts see exactly what they see today — no exit-code change.
- Kill the whole process tree, not just `zsh`: a script's own child processes otherwise survive.
  Launch each action in its own process group and signal the group.
- **Spinner** (decided 2026-11-03): shown on the button only if its action hasn't returned
  after **500ms**, so quick actions like `defaults write` never show one. Removed when the
  action finishes. No success/failure state in the UI.

Aside (not part of this work): `dialogcli` traps SIGINT only. A SIGTERM sent to `dialogcli`
itself doesn't reach the Dialog process.

### Selectable rows ("acts as an input")

- Clicking an item selects it **and** runs its action.
- Output: `name : value` of the selected item, like a select item (and in `--json`), plus the
  click/exit-code details below.
- The action's result doesn't affect the selection — clicking selects, full stop ("in the
  blind").
- Cards/navigation: selection is stored/restored with other input when changing pages.
- Considered and rejected: a new `selectitems` style. Per-item actions, images and plain/bordered
  rendering don't fit the select model, and non-selectable rows aren't a selection at all.

### Output (decided 2026-11-03)

No live reporting — calling scripts wait for the reply. So the reply carries what happened:
whether each button was clicked and, if its action ran and failed, an error code.

- Output key per button: the item's `name`, falling back to the row's `name` (single-button
  rows), then `label`. Selectable rows also output the selected value under the row `name`.
- Recorded per button: `clicked` (at least once) and the **exit code of its last run**
  (`shell`: process exit status; `url`: non-zero if the URL couldn't be opened; `sheet`: always 0).
- Plain text, following the existing `"name" index : …` pattern for selects:

  ```
  "shortcuts" : "clicked"
  "shortcuts" exitcode : "0"
  "hotcorners" : "not clicked"
  "accent" : "blue"
  "accent" exitcode : "1"
  ```
- `--json`:

  ```json
  "shortcuts":  { "clicked": true,  "exitcode": 0 },
  "hotcorners": { "clicked": false },
  "accent":     { "selectedValue": "blue", "clicked": true, "exitcode": 1 }
  ```
- The **dialog's own exit code is unchanged** (button1 = 0 etc.) — the per-button exit code
  is the error code. Changing the dialog exit code because a side action failed would break the
  "OK pressed = 0" contract scripts rely on. No "any action failed" dialog exit code
  (decided 2026-11-03: per-button exit codes are enough).
- Same rules as other input: printed on exit 0 or with `--alwaysreturninput`.

### Plumbing

- New state type (`ButtonRow` with `[ButtonItem]`, each item tracking `clicked`, `isRunning`,
  `lastExitCode`), parse function `makeButtonRow(from:)` shared by JSON config,
  `--button(s) '{...}'` and the `--button` CSV form. New `ViewType` `button` (adds a reserved
  word for `vieworder`; `buttons` accepted as a synonym there too).
- Selection and click/exit-code state participate in `collectCurrentUserInput`,
  `restoreUserInput` and exit output.
- Sheet: generalise `HelpView` into a message sheet both `--helpmessage` and `sheet` actions use
  (help behaviour unchanged).

### Naming and command line (decided 2026-11-03)

- Key: **`button`**, with **`buttons`** as a synonym (JSON config keys, CLI argument and
  `vieworder` type word). "Button" already implies an action, so no `action` prefix.
- **One `--button` / `--buttons` argument = one row.** CSV form is a single button:
  ```
  --button "name=shortcuts,label=Shortcuts…,url=x-apple.systempreferences:…"
  ```
  JSON form can hold several items, which then share the row:
  ```
  --buttons '{"name": "desktoptools", "items": [
    {"name": "shortcuts", "label": "Shortcuts…", "url": "x-apple.systempreferences:…"},
    {"name": "hotcorners", "label": "Hot Corners…", "shell": "/usr/local/bin/open-hot-corners"},
    {"name": "help", "symbol": "questionmark", "display": "symbol", "sheet": "Hot corners let you…"}
  ]}'
  ```
  Each additional `--button(s)` argument is a new row. Rows are placed with `vieworder` by row
  `name`.
- Shape unification: a JSON entry is either a single button (item keys directly on the object,
  same as the CLI CSV form) or a row (`items` array). `makeButtonRow` treats a single button as
  a row of one.
- Complex arrangements (selectable swatch rows, images with captions) are realistically JSON;
  the CSV form deliberately stays simple.
- No clash with existing options: arguments, JSON keys and command-file commands are all
  matched by exact name, so `button`/`buttons` are distinct from `button1`, `button2`,
  `buttonstyle`, `buttonsize`, `buttontextsize`, `infobutton` and the `button1:` / `button2:` /
  `buttonsize:` commands. Naming note only: `--buttonstyle`/`--buttonsize` style the button bar,
  not page buttons — the docs should say so.

### Scope (decided 2026-11-03)

- Actions are only **open a thing** (`url`), **run a script** (`shell`) and **show a sheet**
  (`sheet`, read-only markdown). No dialog-internal actions (switching cards, changing other
  inputs, etc.).
- Clicking a button whose action is **still running is ignored**.
- No live reporting to calling scripts.

### Deferred

- `{fieldname}` substitution of current page input into `shell` actions — later (needs
  shell-escaping care).

All action-button design questions are resolved (2026-11-03).

## 3. New controls

All defined as new per-type arrays on the card (consistent with existing controls), placeable
in groups, and also usable in standard dialogs via `viewOrder`.

| Control | Key | Config | Output |
|---|---|---|---|
| Slider | `slider` | `title`, `name`, `min`, `max`, `step`, `value`, optional `minlabel`/`maxlabel`, `showvalue`, `unit` | number |
| Stepper / number field | `stepper` | `title`, `name`, `min`, `max`, `step`, `value`, `unit` | integer |
| Segmented control | `selectitems` with `"style": "segmented"` | existing select keys | same as select |

Notes:
- Slider and stepper share a numeric model (min/max/step/value) — one state type, two views.
- Segmented is just another select style; renderer only.
- Colour picker and read-only info rows are **button types** rather than new controls (§2,
  "Button types").
- Each new type needs: parse function (like `makeCheckBox`), state array in `UserInputState`,
  `collectCurrentUserInput` / `restoreUserInput` / exit-output support, and a `ViewType`.

## 4. `detail` subtext on all inputs (decided 2026-11-03)

A new `detail` property on **every user input item**, shown as grey subtext directly under the
item's title, like System Settings. (Supersedes the earlier `description` caption idea, which
sat under the whole row.)

Why `detail`: it's unused today. `description` is already a jamfHelper-compatibility argument
(`-description`, the main message) and is used for group header text in `vieworder` groups.
`subtitle` already means the dialog subtitle (`--subtitle`) and list item subtitles.

Example ("Intel-based Apps" / "Support ending for Intel-based apps
in macOS 28." with a "Details…" button on the right).

- Added to `TextFieldState`, `CheckBoxes`, `DropDownItems` (select and radio) and the new
  types (slider, stepper, button rows). Default is an empty string.
- **Only rendered when not empty.** With an empty `detail` no extra view, spacing or padding is
  added, so existing dialogs lay out exactly as before.
- Placement: under the title/label in the left column — for checkboxes and switches under the
  label text, for radios under the group title, for text fields and selects under the field
  title.
- Config: `"detail": "..."` in JSON and per-argument JSON; `detail=...` in the CSV forms
  (`--textfield "Proxy Host,detail=Leave blank to connect directly"`). CSV values can't contain
  commas — use the JSON form for longer text.
- `listitem` already has `subtitle`, which fills the same role; no `detail` there.
- Supports `{system tags}` like other text. Markdown? (open question — plain text suggested.)
- Independent of groups (works in any layout) but most useful with them.

## 4b. Control dependencies (implemented)

`enabledif` and `visibleif` on any input (text field, checkbox, select / radio, slider, stepper,
button row, and `enabledif` on an individual button). `visibleif` hides the control while false,
`enabledif` disables it. In JSON and in the comma separated forms (`enabledif=useproxy`).

Conditions use the output names (`name`, falling back to title / label):

| Condition | True when |
|---|---|
| `useproxy` | a checkbox is on / a field has text / a select has a choice / a number is not 0 |
| `!useproxy` | the opposite |
| `channel=Phone`, `channel!=Email` | equals / not equals (not case sensitive; numbers compare as numbers) |
| `volume>50`, `<`, `>=`, `<=` | numeric comparison |
| `a && b`, `a \|\| b` | both / either. `&&` binds tighter than `\|\|`. No brackets |

Rules:
- Conditions see inputs **on the same page** (in navigation style other pages aren't loaded).
- Sources: text fields, checkboxes, selects (including radio), sliders / steppers, selectable
  button rows (their selected value) and colour wells (hex).
- A condition that can't be understood never locks a control: unknown names read as empty (and
  are logged); non-numeric ordering is false.
- A control that is disabled or hidden is **reset to its default** (the value it loaded with; a
  select's configured default, or the first option for a radio without one) and stays there while
  it is unavailable, so it never reports a value set before it became unavailable (e.g. a
  "restart" switch left on after its "automatic updates" parent is turned off). It still appears
  in the output with that default. Date / time fields are not reset. Resetting never runs a
  button action. Their `required` / regex checks are skipped, since the user can't reach them.
- In navigation style a required field that has `enabledif` / `visibleif` doesn't force an
  unvisited page to be "incomplete"; it is checked when the page is visited.
- Inside `vieworder` groups hidden rows leave no gap or divider, and a group with nothing visible
  disappears with its title and footer.
- Not supported: brackets, `visibleif` on one button in a row, and references to other pages.

## 5. Later

- **Dependencies** (`enabledif` / `visibleif`): **implemented** (2026-11-03) - see "Control
  dependencies" below.
- **Changed-values-only output**: `"outputchanges": true` → only emit values that differ from
  the defaults in the JSON. Needs defaults captured per card at load time (including unvisited
  pages).
- **Command-file updates** for the new types: **deliberately not planned** (decided 2026-11-03).
  The command file earns its place for background-task feedback (status text, progress), and
  forms built from inputs are largely static after launch. Revisit only if there's feedback that
  a specific function is needed. Candidates if that happens, roughly by likely value: set an
  input's value, enable/disable an input, update an `info` row or button, update `detail`
  text, navigation (select/next/previous page, page warning), and a values snapshot. In
  navigation style, hidden pages are rebuilt on each visit, so changes to them would need the
  per-page stored input plus a small pending-changes layer.

## Suggested phasing

1. Row refactor of existing input views + `vieworder` groups (CSV, CLI JSON, JSON config) + `detail` subtext on all inputs.
2. Action buttons: button rows (bordered/plain, symbol/image/label), url/shell/sheet actions,
   async shell, selectable rows as input, generalised message sheet.
3. Slider, stepper, segmented, colour picker.
4. Dependencies, changed-only output, command-file support for new types.

## Decisions needed

1. ~~Grouping model~~ — **B (reference by name)** chosen (2026-11-03).
2. ~~Groups in which layouts~~ — **both** (solves mixed input ordering in standard dialogs too).
   Command-line equivalent via extended `--vieworder` — agreed (2026-11-03): type names are
   reserved words only in the input ordering path; warnings not failures; no bracket-aware
   comma splitting; `--vieworder` also accepts a JSON object.
   Single key: `vieworder` carries groups (CSV, CLI JSON object, JSON config object) — no separate `groups` key (decided 2026-11-03).
3. ~~Action button direction~~ — agreed (2026-11-03): an input type in both layouts; rows of
   one or more buttons (text, SF symbol, both, or image; symbol-only display); actions are url,
   shell or a read-only markdown sheet; selectable rows output a value. Action button
   design is fully resolved (§2). Decided 2026-11-03: key `button`/`buttons`;
   one `--button(s)` argument = one row; actions run in the blind; clicks ignored while running;
   button1/button2 blocked while actions run, everything else force quits and kills actions;
   signals clean up and re-raise (exit 40 stays in `dialogcli`); output reports clicked state and
   per-button exit code (no dialog-level failure code); spinner only after 500ms; actions
   limited to url/shell/sheet; `{fieldname}` substitution deferred.
4. ~~Key names~~ — `slider` and `stepper` (decided 2026-11-03). Colour picker and info are
   button types, not separate keys. `detail` subtext on all inputs.
