# Trying themes and layouts

A hands-on guide: what to run, what to click, and what to edit to see Quilt in another look or another arrangement of panels. For the APIs behind it, see [controls-guide.md §11](controls-guide.md#11-theming) (the Theme tokens) and [integration.md](integration.md) (docking). For tests and screenshots, see [testing.md](testing.md).

Everything here runs from the repository root. `-I .` puts the `Quilt/` folder on the import path:

```sh
qml6 -I . examples/gallery.qml       # every control in every state, no docking
qml6 -I . examples/sandbox.qml       # a small editor: docked panels to rearrange
qml6 -I . examples/try-theme.qml     # the gallery under a theme you edit
```

## Themes

### What there is today

Quilt has one look of its own, in a dark and a light version. The twelve themes planned for the optional `Quilt.Themes` module (Swiss, Brutalism, CRT Terminal, Liquid Glass and the rest) are **not built yet**. Today you can try Quilt's own look in its variations, and any theme you write yourself. Everything a theme needs is already in place: the `ThemeSpec` type, painters, and borrowing feel from another theme. When the bundled themes land, they will appear in a **View › Theme** menu in the gallery and the sandbox, and in a theme lab, `examples/themes.qml`.

### Quilt's own look, in the examples

| Where | Menu item | What it shows |
|---|---|---|
| Gallery | View › Dark theme | Dark and light |
| Gallery | View › High contrast | An outline round every control (`Theme.controlBorder`) |
| Gallery | View › No motion | Every duration at 0 (`Theme.reduceMotion`) |
| Sandbox | View › Dark Theme | Dark and light, with docking |
| Sandbox | View › Seamless Panels | The same tokens with other values: 1 px gaps, no corner radius |
| Sandbox | View › Always Show Panel Buttons | Pop-out, maximize and close stay visible instead of appearing on hover |

The gallery's States section, at the bottom left, shows what every theme must keep readable: driven (violet, with ƒ), mixed, invalid and read-only.

### Your own theme: `examples/try-theme.qml`

This file sets up a theme called "Paper" and opens the gallery under it. Paper is warm and light-only, with square corners, and its fields are a single underline instead of a box. Edit the `ThemeSpec` and run the file again:

```sh
qml6 -I . examples/try-theme.qml
```

A `ThemeSpec` starts out as Quilt's own look, so you set only what you change. Its properties, by group:

| Group | Properties | Notes |
|---|---|---|
| About | `name`, `description`, `question`, `modes` | `modes`: `ThemeSpec.Both`, `DarkOnly` or `LightOnly`. A one-mode theme forces `Theme.dark`. Switch back to a two-mode theme and the mode chosen before returns |
| Surfaces | `canvas`, `surface`, `raised`, `control`, `controlHover`, `controlFill`, `border`, `controlBorder`, `panelOutline`, `shadow`, `well` | From furthest to nearest. [visual-design.md](visual-design.md) explains each role |
| Text | `text`, `textSecondary`, `textTertiary` | |
| Meaning | `accent`, `accentInk`, `driven`, `error`, `warning`, `danger`, `dangerInk` | |
| Derived | `selection`, `textSelection`, `rowHover`, `focus`, `fillInk` | Leave them unset to have them computed from the accent and text |
| Type | `fontFamily`, `fontFamilyTitle`, `fontFamilyValue`, `fontSize`, `fontSizeSmall`, `fontSizeTitle`, `fontWeight`, `fontWeightStrong`, `titleCapitalization`, `titleLetterSpacing`, `textRenderType` | Title fonts are used for section titles, tabs and the window title; value fonts for numbers, dates and colours |
| Shape | `radius`, `controlRadius`, `innerRadius`, `focusWidth`, `focusOffset`, `controlBorderWidth`, `outlineWidth` | |
| Icons | `iconStrokeWidth`, `iconCap`, `icons` | `icons` maps a glyph name to your own SVG path on the 12-unit grid |
| Feel | `durationFast`, `duration`, `durationLayout`, `easing`, the sizes (`controlHeight`, `rowHeight`, `tabHeight`, `gap`, …), `hoverReveal`, `pressTravel`, `caretStyle` | `caretStyle`: `ThemeSpec.Line`, `Bar`, `Block` or `Underline`. `pressTravel` sinks a pressed button by that many pixels |

Colours may depend on `dark`, which Quilt sets on the spec:

```qml
accent: dark ? "#ff7a45" : "#c2410c"
```

What a theme can't change is how the controls work. Dragging, typing, stepping, Esc to cancel, Shift ×10 and Ctrl ×0.1 behave the same under every look.

### Redrawing a part: painters

Tokens change colours and sizes. To draw a part differently, give the spec a **painter** for it. A painter is a Component that Quilt creates inside that part, under its text and icons, at the part's size. The example's fields are drawn by one:

```qml
skins.field: Component {
    Item {
        id: underline
        readonly property Face host: parent as Face     // the part being drawn
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: underline.host && underline.host.focused ? 2 : 1
            color: underline.host && underline.host.focused ? Theme.accent : Theme.textTertiary
        }
    }
}
```

| Slot | Part | The painter's parent is a | Useful properties of the parent |
|---|---|---|---|
| `field` | Number, text, dropdown, date and colour fields | `Face` | `hovered`, `focused`, `invalid`, `flat`, `driven`, `leveled`, `level`, `levelActive`, `fill` |
| `button` | Buttons, icon buttons, menu titles, window buttons, steppers, a segmented button's groove | `Face` | `role` (`Face.Button`, `Primary`, `Tool`, `Step`, `Track`), `hovered`, `pressed`, `checked`, `danger`, `fill`, `ink()` |
| `segment` | The selected part of a segmented button | `Face` | `checked`, `focused`, `driven`, `fill` |
| `item` | Highlighted rows in menus and lists; calendar days | `Face` | `hovered`, `checked`, `marked` (today), `fill`, `ink()` |
| `check` | A checkbox's box | `CheckIndicator` | `on`, `mixed`, `driven`, `hovered`, `pressed`, `fill`, `ink` |
| `toggle` | A switch | `SwitchIndicator` | `on`, `thumb` (0..1, already eased), `driven`, `hovered`, `fill`, `ink` |
| `track` | A slider's groove, a progress bar | `Track` | `horizontal`, `position`, `fillLength`, `indeterminate`, `mixed`, `driven`, `ink` |
| `thumb` | A slider's handle, a scroll bar's thumb | `Thumb` | `scroll`, `hovered`, `pressed`, `focused`, `fill` |
| `dial` | A knob's face | `DialFace` | `position`, `origin`, `angle`, `originAngle`, `r`, `mixed`, `driven`, `ink`, `pointer` |
| `spinner` | A busy indicator | `Spinner` | `running`, `color` (the painter animates itself) |
| `tab` | The mark of a tab in a panel's tab strip | `TabFace` | `current`, `active`, `hovered`, `inset`, `ink` |
| `focusRing` | The focus ring, around any control | `FocusRing` | `invalid`, `radius` |
| `rule` | Separators and dividers | `Rule` | `vertical`, `ink` |
| `canvas`, `panel`, `popup`, `toolTip`, `bar`, `overlay` | The window background, a docked panel, a popup, a tooltip, the title bar, a layer over the whole window | `Surface` | `fill`, `edge`, `radius`, `header` and `headerFill` (a panel's tab strip), `active` |

Rules a painter keeps, so that themes stay comparable:

- **Read; never write.** Read the parent's states and colours, and `Theme`. Draw with its `fill` and `ink` rather than your own colours where you can, so an application's overrides still apply.
- **The part keeps its size.** The painter is sized for you. Don't resize the parent or take input: painters are created with `enabled: false`.
- **Draw everything the part drew.** A `field` painter replaces Quilt's fill, so it draws the level of a ranged number itself (`leveled`, `level`). The example does this.
- **Stay close.** Draw no further than `Theme.paintOverflow` (12 px) outside the part, for shadows and glows.
- **Move only with the theme.** Animate with `Theme.duration*` and `Theme.easing`; with motion reduced they are 0. Nothing animates at rest, except a spinner, an indeterminate bar and the caret.

A painter is created only when its theme is applied, so Quilt's own look costs nothing extra.

### A look with another feel

`Theme.feel` takes motion, sizes and behaviour from a second spec, while colours and painters stay with `Theme.spec`. This lets you tell whether a reaction comes from how a theme looks or from how it moves:

```qml
Component.onCompleted: {
    Theme.spec = paper;         // Paper's colours and painters…
    Theme.feel = Theme.quilt;   // …with Quilt's own sizes, motion and hover behaviour
}
```

Set `Theme.feel = null` to go back to the look's own feel.

### Small changes without a theme

For a quick experiment you don't need a spec. Any token can be set on `Theme` directly, and it stays set when the theme changes:

```qml
Component.onCompleted: {
    Theme.accent = "#ff8a3d";
    Theme.radius = 0;
    Theme.reduceMotion = true;
}
```

A `Binding { target: Theme; property: "accent"; … }` overrides a token only while it is on, and hands it back to the theme afterwards.

## Layouts

### The sandbox

`qml6 -I . examples/sandbox.qml` starts with this arrangement:

```
┌───────┬──────────────┬─────────────────────┬────────────────────┐
│ Tools │ [Outliner]   │ [Viewport] Glass    │ [Inspector] Notes  │
│       │  Layout JSON │                     │                    │
│       │              ├─────────────────────┼────────────────────┤
│       │              │ [Timeline] Console  │ [Status]           │
└───────┴──────────────┴─────────────────────┴────────────────────┘
```

Each box is a tab group; the tab in brackets is the one showing.

Every panel keeps its state while it moves: the viewport keeps animating, typed text stays, and the timeline keeps its frame. So you can rearrange freely and check that nothing resets.

| Try | How |
|---|---|
| Rearrange | Drag a tab onto the edge of a panel (split it), its middle (join it as a tab), a tab strip (insert at that place), or the markers along the window's edges (dock along a whole side) |
| Pop out | Drop a tab outside the window, or right-click the tab › Pop Out. Drag tabs into the new window and back again |
| Resize | Drag a gap between panels; the whole straight line moves. Ctrl-drag moves only the segment under the pointer |
| Maximize | Double-click a tab. Double-click it again to restore |
| A grid | View › 2×2 Grid puts four panels in quadrants, for trying split lines |
| Seamless | View › Seamless Panels: no gaps, no rounded corners |
| Open and close | View › Panels lists every panel. File › New Document adds panels at runtime |
| Restricted panels | Tools has a fixed width and can't share a tab group. Status can't be moved, popped out or closed |
| Save and restore | File › Save Layout, rearrange, then File › Restore Layout. File › Reset Layout goes back to the start |
| Watch the layout | The Layout JSON panel shows the current layout as JSON, updated with every change; the Console panel logs each change |

Esc cancels a drag in progress. Help › Gestures and Shortcuts lists the rest.

### Your own starting layout

The arrangement a `DockArea` starts with is its `defaultLayout`. Rows lay tab groups side by side; columns stack them; `size` is the share of the parent that a group takes:

```qml
DockArea {
    defaultLayout: ({
        row: [
            { tabs: ["outliner"], size: 0.2 },
            { column: [
                { tabs: ["viewport"], size: 0.75 },
                { tabs: ["timeline", "console"] }
            ] },
            { tabs: ["inspector"], size: 0.25 }
        ]
    })
}
```

The quickest way to try one is to edit `defaultLayout` in `examples/sandbox.qml` (panel ids: `tools`, `outliner`, `layout`, `viewport`, `glass`, `timeline`, `console`, `inspector`, `notes`, `status`, `palette`, `help`). Or arrange the panels by hand and copy the JSON from the Layout JSON panel: the `main` part of what it shows is a `defaultLayout`. A panel the layout leaves out is placed by its `area` hint (`Dock.Left`, `Dock.Bottom`, …) when it opens. `examples/minimal.qml` shows hints alone, without a `defaultLayout`.

To keep the arrangement between runs, set `autoSaveKey` on the area; [integration.md §7](integration.md#7-saving-and-restoring-layouts) explains saving, restoring and the JSON format.

## Seeing a change without a window

To check a theme or layout over SSH or in CI, render it headlessly. The commands are in [testing.md](testing.md):

- the `qml6` one-liner smoke-loads a file;
- `quiltshot` takes screenshots, clicks and keys from a script.

Use `QT_QUICK_BACKEND=software` for screenshots that match on every machine.
