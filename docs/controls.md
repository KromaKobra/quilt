# Controls: catalogue and interaction design

This document lists every control planned for `Quilt.Controls` and specifies how each one behaves. It is a design document: nothing here is built yet, and property names are proposals. For what is in and out of the project, see [scope.md](scope.md). For colours, sizes and motion, see [visual-design.md](visual-design.md).

The goal is that a user never has to think about *how* to change a value. That comes from three things, in this order:

1. **One grammar.** Every control answers the same gestures and keys in the same way.
2. **No accidents.** A value changes only when the user clearly meant it to, and any change can be cancelled.
3. **Visible state.** What a value is, and what will happen if you touch it, can be read without touching it.

Numbers marked *(start)* are starting values to tune on a prototype. They are not final.

- [Catalogue](#catalogue)
- [Principles](#principles)
- [The interaction grammar](#the-interaction-grammar)
- [Focus and editing](#focus-and-editing)
- [Parameter states](#parameter-states)
- [The property grid](#the-property-grid)
- [Value controls](#value-controls)
- [Supporting controls](#supporting-controls)
- [Choosing a control](#choosing-a-control)
- [Engineering rules](#engineering-rules)
- [Accessibility](#accessibility)

## Catalogue

| Control | Edits | Built on | Milestone |
|---|---|---|---|
| [`Inspector`](#inspector) | Container for rows and sections | `Flickable` | 1 |
| [`Section`](#section) | Expandable heading | `T.Control` | 1 |
| [`PropertyRow`](#propertyrow) | Label plus one control | `Item` | 1 |
| [`NumberField`](#numberfield) | Int or float; also the inspector's slider and stepper | `T.Control` + `TextInput` | 1 |
| [`TextField`, `TextArea`](#textfield-and-textarea) | Text | `T.TextField`, `T.TextArea` | 1 |
| [`CheckBox`](#checkbox) | Boolean property | `T.CheckBox` | 1 |
| [`Switch`](#switch) | Feature on or off | `T.Switch` | 2 |
| [`SegmentedButton`](#segmentedbutton) | One of 2 to 5 options | `T.Control` + `T.AbstractButton` | 2 |
| [`ComboBox`](#combobox) | One of many options | `T.ComboBox` | 2 |
| [`Slider`](#slider) | A position along a range, outside the grid | `T.Slider` | 2 |
| [`VectorField`](#vectorfield) | 2 to 4 numbers | `NumberField` × n | 3 |
| [`ColorField`](#colorfield) | Colour, with a picker | `T.Control` + `T.Popup` | 3 |
| [`MatrixField`](#matrixfield) | A small grid of numbers | `T.Control` | 5 |
| [`Knob`](#knob) | A number, where space is tight | `T.Control` | 5 |
| [`DateField`](#datefield) | Date, time | `T.Control` | 5 |
| [`Button`, `IconButton`](#button-and-iconbutton) | Actions | `T.Button` | 2 |
| [`Menu`](#menu) | Context and dropdown menus | `T.Menu` | 2 |
| [`ToolTip`](#tooltip) | Help on hover | `T.ToolTip` | 2 |
| [`ScrollBar`](#scrollbar) | Scrolling | `T.ScrollBar` | 2 |
| [`ProgressBar`](#progressbar) | Progress of a task | `T.ProgressBar` | 3 |
| [`BusyIndicator`](#busyindicator) | Waiting, duration unknown | `T.BusyIndicator` | 3 |

`T` is `QtQuick.Templates`. The templates supply focus, keyboard handling and accessibility; Quilt supplies the visuals and the behaviour below.

A **stepper** is a mode of `NumberField`, not a separate control. An inspector **slider** is too.

## Principles

Each rule in this document traces back to one of these. They are established findings about how people perceive and act, applied to inspectors.

| Principle | What it says | What Quilt does about it |
|---|---|---|
| **Consistency** | People transfer what they learn in one place to everything that looks alike | One grammar for all controls. One key, one meaning |
| **Familiar conventions** | People bring habits from the tools they already use | Spreadsheet rules for cells and `=`. Text-field rules for text. Up and right mean more |
| **Fitts's law** | Bigger and closer targets are faster and less error-prone | The label is part of the control. A whole section header is clickable. Hit areas fill the row height even when the drawn shape is small |
| **Hick's law** | Each extra choice slows the decision | One control per kind of value. 2 to 5 options are all shown; more go in a dropdown |
| **Recognition over recall** | Seeing is easier than remembering | State is drawn on the row. Units are displayed. `Mixed` is spelled out |
| **Direct manipulation** | Acting on the thing itself, with continuous and reversible feedback, feels effortless | Drag the number itself. The value follows in the same frame. Esc undoes the gesture |
| **Feedback within 100 ms** | Slower than that, and cause and effect stop feeling connected | Press and drag feedback happens in the frame of the input. Nothing waits for an animation |
| **Slip prevention** | Most errors are slips of the hand, not wrong intentions | Drag thresholds. The wheel rule. Driven values can't be scrubbed. Hover never changes anything |
| **Forgiveness** | People explore when mistakes are cheap | Esc restores. One edit is one undo step. Typed text is never thrown away |
| **Be liberal in what you accept** | Input comes in more forms than you planned for | Arithmetic, units, either decimal separator, pasted lists, any colour format |
| **Gestalt grouping** | Things that are close, aligned or enclosed read as belonging together | Label and control share a row. Values share one left edge. Sections group by whitespace |
| **Signifiers** | A control should show what it does | If it has a fill, you can edit it. The drag cursor appears over scrubbable values |
| **Preattentive attributes** | Colour and shape are seen before reading begins | Each state has one colour and one shape. The accent colour is reserved for the user's own focus and choices |
| **Spatial memory** | People find things by where they were | Nothing shifts. Rows keep their height. Sections remember whether they were open |
| **Change blindness** | A change the eye wasn't on is missed | When Quilt corrects a value (clamps it, rounds it), the field flashes once |
| **Weber–Fechner law** | Perceived change is proportional, not absolute | An optional logarithmic scale for values that span orders of magnitude |

## The interaction grammar

This table is the centre of the design. It holds for every control.

| Input | What it always means | What it never does |
|---|---|---|
| **Hover** | Shows that the thing is interactive. May show a tooltip | Changes a value or opens anything |
| **Click** | Activates: toggles, opens, or starts typing | Changes a number by where you clicked |
| **Drag** (horizontal) | Changes a continuous value, relative to where the drag began | Jumps the value to the pointer |
| **Type** | Replaces the value | Applies before Enter (unless the control is `live`) |
| **Up / Down** | One step more / less. Next / previous option | |
| **Shift** | ×10: coarse | |
| **Ctrl** (Cmd on macOS) | ×0.1: fine | |
| **Wheel** | Scrolls the panel. Steps a value only when that control has keyboard focus *and* the pointer is over it | Changes a value you were only scrolling past |
| **Enter** | Commits | |
| **Esc** | Cancels the gesture or edit in progress and restores the value from before it | |
| **Tab / Shift+Tab** | Commits, then moves to the next / previous control | |
| **Right-click** | Opens the row menu: reset, copy, paste, link | |
| **Click the modified dot** | Resets to default | |
| **`=` as the first character** | Starts an expression (when the app supports it) | |

Details that make the grammar dependable:

- **Drag threshold.** A drag begins after 3 px *(start)* of horizontal movement. A press that moves less is a click. The 3 px are not lost: the value starts changing from the threshold point, so there is no jump.
- **Axis lock.** A drag that starts more vertical than horizontal is not a scrub. This keeps trackpad and pen scrolling of the inspector from changing values.
- **The control keeps the drag.** Once a drag starts, the pointer may go anywhere, including outside the control and over other controls, and the drag continues until release.
- **No dead travel.** When a drag pushes a value against its limit and the pointer keeps going, reversing direction takes effect immediately. The user never has to "drag back" the overshoot.
- **Modifiers can change mid-drag.** Pressing or releasing Shift or Ctrl changes the speed from that point on, without a jump.
- **Wheel steps are whole notches.** High-resolution wheels and trackpads send many small deltas. They are accumulated into whole steps so a light swipe can't send a value flying.
- **Shift and Ctrl mean the same thing** in a drag, with the arrow keys, and on the wheel. See [open decision 2](scope.md#open-decisions) for why these two keys.

### Timing

| Event | Time | Why |
|---|---|---|
| Press, drag and key feedback | Same frame | Cause and effect must feel connected |
| Hover highlight | In: immediate. Out: 80 ms | Fast in so the target feels alive, soft out so the eye isn't pulled |
| State animation (toggle, expand) | 80–120 ms | Long enough to see what changed, short enough not to wait for |
| Tooltip | After 600 ms at rest; immediately when another tooltip was just showing | Doesn't flash while passing; fast when the user is clearly reading tooltips |
| Hold-to-repeat (stepper buttons) | Starts after 400 ms, then accelerates | A click is one step; a hold is clearly a hold |
| Busy indicator | Appears after 400 ms, then stays at least 300 ms | Short waits show nothing; nothing ever flickers |

No animation ever delays input. A control that is mid-animation accepts the next click.

## Focus and editing

Value controls follow the model people know from spreadsheets. A control is in one of three conditions:

| Condition | How you get there | What keys do |
|---|---|---|
| **Idle** | The default | Nothing: keys go elsewhere |
| **Focused** | Tab to it | Up/Down step it. Typing a character starts editing and *replaces* the value. Enter or F2 starts editing with the current text selected |
| **Editing** | Click it, or type while focused | Text editing. Enter commits. Esc reverts. Tab commits and moves on. Up/Down still step |

Rules:

- **Clicking a number selects all of it.** Numbers are replaced far more often than they are edited digit by digit, so one click and typing is the fast path. A second click places the caret.
- **Clicking text places the caret**, as in every text field. Tabbing into text selects all.
- **Losing focus commits.** Clicking elsewhere is not a cancel. Only Esc is.
- **Entering and leaving without typing changes nothing.** The edit text is the full stored value, not the rounded display. Clicking into a field that shows `0.33` for a stored `0.3333333` and pressing Enter leaves the value alone.
- **Invalid text is never thrown away.** If the text can't be understood, the field stays in editing with an error ring and a tooltip saying why. The user fixes it or presses Esc. Focus is not trapped: clicking away reverts to the last good value.
- **The focus ring** shows on keyboard focus and while editing. A mouse click on a button or checkbox does not draw it.

## Parameter states

Every value control can show these states. They come from the app, through plain properties or the [parameter adapter](scope.md#3-the-parameter-adapter). Each has a colour *and* a shape, so none depends on colour vision.

| State | Meaning | How it looks | How it behaves |
|---|---|---|---|
| **Default** | Equals its default | Nothing extra | |
| **Modified** | Differs from its default | A dot in the row's left gutter, in the accent colour | Clicking the dot resets. Hovering it shows the default value |
| **Driven** | Something else computes this value: an expression, a link, an animation | Value in the driven colour, with an `ƒ` badge at the field's right edge | Shows the computed value. Can't be scrubbed or stepped. Editing shows the expression text. The tooltip names the source |
| **Mixed** | Several objects are selected and they differ | The word `Mixed` in dim text (`—` if the field is too narrow). Checkbox: a dash | Can't be scrubbed. Typing a value sets it on every selected object |
| **Invalid** | The entered text or expression failed | Error-coloured ring; the last good value, dimmed | The tooltip gives the reason. Editing shows the failing text |
| **Read-only** | Can be seen, not changed | Plain text with **no field fill** | Text can be selected and copied |
| **Disabled** | Doesn't apply right now | Whole row at reduced opacity | Skipped by Tab; ignores input |

Notes:

- **A fill means editable.** Read-only values have no fill, and that single rule tells the user what can be changed.
- **Modified and driven can combine** with read-only and disabled. Driven, mixed and invalid exclude each other.
- **Why a driven value can't be scrubbed.** An accidental drag would silently replace an expression with a number. Replacing it stays possible, but takes a deliberate act: click, see the expression, type a number, press Enter. That is one undoable step.
- **Driven has one colour.** Apps that distinguish kinds of driver (keyframed, linked, inherited) can pass their own colour and badge glyph per parameter.

### The row menu

Right-click on any row (or the Menu key) opens the same menu. Items appear only when they apply.

| Item | Needs |
|---|---|
| Reset to Default | A default value |
| Copy Value / Paste Value | |
| Copy Reference | `reference` on the adapter |
| Paste as Link | `setExpression` on the adapter |
| Edit Expression / Remove Expression | A driven parameter |
| *App items* | The app can append its own (Add Keyframe, ...) |

## The property grid

The grid matters more than any single control. It is what makes thirty values readable at a glance.

```
┌ Inspector ────────────────────────────────┐
│ ⌄ Transform                               │  Section header: the whole row is the button
│     Position    X 120    Y 48     Z 0     │
│     Rotation    45°                    ƒ  │  driven
│   ● Scale       1.5                       │  modified: the dot resets it
│ ───────────────────────────────────────── │
│ ⌄ Appearance                              │
│     Opacity     ▓▓▓▓▓▓▓░░░░ 62%           │  a number field with a range
│     Blend       Normal                 ⌄  │
│ ───────────────────────────────────────── │
│ › Physics  ●                              │  collapsed, and something inside is modified
└───────────────────────────────────────────┘
  ↑ gutter  ↑ label column  ↑ value column: one shared left edge
```

### Inspector

The scrolling container. It owns everything rows must agree on.

- **Label column width** is shared by all rows, so every value starts on the same vertical line. The user can drag the boundary between labels and values; the divider is invisible until hovered. Default: 40% of the width, between 80 and 200 px *(start)*.
- **Scrolls vertically only.** There is never a horizontal scroll bar: content adapts to the width instead.
- **Narrow panels.** A dock panel can be dragged down to 120 px. Below about 200 px *(start)*, rows restack with the label above the control.
- **Wide panels.** Controls stop growing at 280 px *(start)*. A value that stretches 600 px from its label is slower to read and to hit.
- **More content below** is signalled by a soft fade at the clipped edge, because the overlay scroll bar is hidden at rest.
- **Keeps its place.** When the selection changes to an object of the same kind, rows are reused: the scroll position, open sections and label width stay as they were, and only the values change.
- **Empty state.** With nothing to show, a single dim line says so ("Nothing selected"), set by the app.
- **Filter** (optional). A search field at the top hides rows whose label doesn't match, and opens sections that contain matches.

### Section

An expandable heading.

- **The whole header row toggles it**, not just the chevron. The chevron is a signifier, not the target.
- **Keys.** Right expands, Left collapses, Space or Enter toggles. Ctrl+click toggles every section in the inspector at once.
- **The header can carry** a `Switch` that enables the whole group, and a menu button shown on hover.
- **A collapsed section that contains modified values shows a dot** beside its title, so collapsing never hides the fact that something was changed.
- **State persists.** Give a section a `key` and it remembers open or closed between runs, like the dock layout.
- **Animation.** The chevron turns in 100 ms. Content height animates for small sections and switches instantly for large ones; a long section sliding open costs more than it explains.
- **Content is created on first expand** and kept afterwards, so a closed section costs nothing at start-up and loses nothing when re-closed.
- **Nesting.** One level of subsections. Deeper structure belongs in the app's own navigation.

### PropertyRow

A label and one control.

- **The label belongs to the control.** Clicking it does the control's main action: focuses a field, toggles a checkbox, opens a dropdown. Dragging a number's label scrubs the number.
- **One height for every row** (the control height plus spacing), whatever the control. Taller controls (text area, matrix) take whole multiples of it.
- **Long labels** are cut with an ellipsis at the end. The full text appears in a tooltip, and only when the label was actually cut.
- **The gutter** left of the label is always reserved for the modified dot. A state marker appearing never moves the text.
- **Hover** tints the row faintly, tying the label to its value across the gap.
- **Any item can be the control**, including the app's own.

## Value controls

### NumberField

The keystone. It edits ints and floats, and replaces three stock controls: the spin box, the inspector slider, and the label that shows a slider's value.

**Modes**

| Mode | When | Looks like |
|---|---|---|
| Plain | No natural range (a position, a count) | A field with the value |
| Ranged | `from` and `to` are set | The same field, with a fill bar behind the value showing where it sits in the range |
| Stepper | `steppers: true`: small whole numbers changed a few at a time | The same field, with − and + buttons at its ends |

One control means one behaviour to learn, and it removes the separate value label, which is a large share of inspector clutter.

**Pointer**

- Hovering shows the horizontal-resize cursor: this value can be dragged.
- A click starts editing with everything selected.
- A horizontal drag scrubs the value. In ranged mode, one field width of travel (at least 160 px) covers the whole range. In plain mode, 2 px is one `step` *(start)*.
- Values land on multiples of the step, counted in whole steps from the start value, so there is no floating-point drift such as `0.30000000000000004`.
- Stepper buttons: a click is one step; holding repeats.

**Typing**

| Typed | Result |
|---|---|
| `12.5` | 12.5 |
| `2*pi`, `(120+48)/2`, `sqrt(2)` | The result of the arithmetic |
| `+=10`, `-=5`, `*=2`, `/=2` | Applied to the current value. (A plain `-5` is the number minus five.) |
| `5cm` in a field measured in metres | 0.05, when the developer supplies a unit table. The field's own suffix is always accepted and ignored |
| `1,5` | 1.5: a comma is taken as the decimal separator when the text contains exactly one comma and no point |
| `2.7` in an int field | 3. The field flashes once to show the correction |
| A value beyond a hard limit | Clamped to the limit, with the same flash |
| `=cube.width/2` | Sent to the app as an expression (when supported) |
| Anything else | Invalid: the field stays in editing and says why |

**Range and limits**

- `from` / `to` are the *soft* range: what the fill bar shows and what a drag covers.
- `minimum` / `maximum` are the *hard* limits: what the value can ever be.
- Typing can go beyond the soft range, up to the hard limits. A slider should suggest a range, not jail the value in it.
- `wrap: true` makes the value wrap around instead of stopping (angles).
- `scale: Log` spreads a ranged field logarithmically (frequencies, zoom factors).

**Display**

- Left-aligned on the value column's edge, in tabular numerals so digits don't shift while the value changes.
- At most `decimals` digits, with trailing zeros dropped. This is display only: the stored value keeps full precision.
- The suffix (`px`, `°`, `%`) is shown dimmed after the number. It is not part of the edit text.
- A number is never cut off in a way that reads as a different number. When space runs out, the suffix goes first, then decimals. The tooltip shows the full value.

### Slider

The classic track and thumb. Use it **outside the property grid**: in a toolbar, on a timeline, for volume or zoom. Use it where the position along the range matters more than the number. Inside an inspector, use a ranged `NumberField`.

- Pressing the thumb drags it from where it was grabbed, with no jump.
- Pressing the track moves the thumb to the pointer and continues as a drag.
- The hit area is the full control height, though the track is drawn 4 px tall.
- A tick marks the default value, and the thumb snaps to it lightly. Ctrl suppresses snapping.
- Keys, wheel, Esc and modifiers follow the grammar. Home and End go to the ends.

### Knob

A rotary control. Knobs are slower and less precise than sliders and harder to read. Their one advantage is size, so they are for dense grids of continuous values (audio, synths) and not for general inspectors.

- **Drag vertically:** up is more. Not in a circle; circular dragging is hard to control and no faster. 200 px covers the range *(start)*.
- A 270° arc shows the value, with the gap at the bottom. `bipolar: true` draws the arc from the centre, for values such as pan.
- The value is shown as text beneath while hovering or dragging, or always with `valueVisible`.
- A click opens a small field to type the value.
- Keys, wheel, Esc and modifiers follow the grammar.

### TextField and TextArea

- **TextField** is one line. Enter commits, Esc reverts, losing focus commits. By default it reports the edit when it ends, not on every keystroke (`live: true` changes that).
- Text that doesn't fit is cut with an ellipsis while idle, at the end, or in the middle for paths (`elide`).
- A `validator` makes bad input show the invalid state. Characters are not silently swallowed.
- A search variant adds a leading glyph and a clear button.
- **TextArea** is several lines. Enter adds a line; Ctrl+Enter commits. It grows to `maximumLines`, then scrolls. The wheel rule applies: it scrolls its own text only when focused.

### CheckBox

For a yes/no **property of the thing being edited**.

- The box and its label are one target. In a `PropertyRow`, clicking the row label toggles it.
- Space toggles.
- Mixed shows a dash. Clicking a mixed checkbox turns it on for all; the next click turns it off. A click never produces the mixed state.
- The change applies at once. There is nothing to commit.

### Switch

For turning **a feature or a whole section on or off**, typically in a section header. Use a checkbox for an ordinary property. Keeping the two roles separate means a switch always signals something bigger than one value.

- A click toggles it. Dragging the thumb also works: it follows the pointer, and where it is released decides.
- On is the accent colour with the thumb to the right. Off is neutral with the thumb to the left. Position and colour both carry the state.
- Space toggles. The thumb moves in 100 ms.

### SegmentedButton

For **one of 2 to 5 options**, all visible at once. One click instead of the dropdown's two, and nothing to remember.

- Segments are equal in width, with a short word or an icon each.
- Left and Right move the selection. The control is a single Tab stop.
- `exclusive: false` turns it into a row of independent toggles (bold, italic, underline).
- Mixed shows no segment selected.
- If the options don't fit the width, the control was the wrong choice: use a `ComboBox`.

### ComboBox

For **one of many options**.

- A click opens the list below the field (above when there is no room). The current option is marked and scrolled into view.
- **Press, drag, release** selects in one motion, as menus do. Click, then click, also works.
- The list is at least as wide as the field and grows to fit its longest option.
- The list opens as a real window (Qt's `Popup.Window`), so it isn't clipped by a narrow panel or a small pop-out window.
- With more than 12 options *(start)*, a filter field appears at the top. Typing narrows the list.
- Keys while closed: Up/Down change the option, typing a letter jumps to a match, Space or Enter opens. While open: Enter selects, Esc closes with no change.
- Hovering an option highlights it and nothing more. Apps that want a live preview can listen for the highlight and must restore on Esc.
- Options can have icons or colour chips, separators, and disabled entries.

### VectorField

Two, three or four numbers on one row: a position, a size, a scale.

- Each component is a `NumberField` with a dim leading letter (`X`, `Y`, `Z`, `W`, or the developer's own). The letter is a drag handle, like a label.
- Tab moves through the components.
- **Pasting `1, 2, 3` into any component fills them all.** Copying copies them all.
- `linkable: true` adds a chain toggle. While linked, editing one component scales the others in proportion.
- Each component has its own state: one can be driven or mixed while the others are not.
- When the row is too narrow for the components side by side, they stack.
- It accepts and returns whatever type it was given: a QML vector, point or size, or a plain array.

### ColorField

In the row: a swatch, the hex value, and (when the colour has alpha) the opacity as a scrubbable number. Clicking the swatch opens the picker beside the field. It is a popover, not a dialog, so the inspector stays visible and usable.

The picker has:

- A saturation/value square with a hue strip, the arrangement most people already know. An alpha strip when relevant.
- Number fields for the components, switchable between HSV, RGB and hex with a segmented button.
- A split swatch showing the colour from before the picker opened beside the current one, so the two can be compared without remembering.
- Swatches: the app's palette, plus colours used recently.

Behaviour:

- **One visit to the picker is one edit.** `editStarted` fires at the first change and `editFinished` when the picker closes. Esc closes it and restores the original colour. Clicking outside, or Enter, keeps the new one.
- **Hue and saturation are remembered.** Dragging to black, white or grey does not reset the hue to red. The picker keeps its own hue, saturation and value while open and only converts outward.
- The hex field accepts `#fff`, `fff`, `#ffffffff`, `rgb(…)` and colour names.
- In the square, Shift locks the drag to one axis and Ctrl slows it.
- One picker exists per window, created the first time it is needed and shared by every colour field.
- Colours are sRGB. HDR and wide-gamut editing, and picking from the screen, are [out of scope](scope.md#out-of-scope).

### MatrixField

A small grid of numbers, up to about 6 × 6. A larger grid is a table, which is out of scope.

- It is drawn as **one field** divided by hairlines, not as a block of separate boxes, so it reads as a single value.
- It works like a spreadsheet. Arrows move between cells. Typing replaces the cell. Enter or F2 edits it. Enter commits and moves down; Tab commits and moves right.
- Each cell scrubs like a number field.
- **Pasting a block** of numbers separated by tabs, commas or newlines fills cells starting from the focused one. Copying copies the whole grid in that form, so it round-trips with a spreadsheet.
- The row menu offers Reset to Identity for square matrices.
- Optional row and column headers.

See [open decision 3](scope.md#open-decisions) if "2D matrix input" meant a pad for picking a point instead.

### DateField

- The date is shown as segments (`2026-11-12`). Each segment acts like a small int field: click to select it, type digits (the selection advances when a segment is full), Up/Down to step, drag to scrub.
- Stepping rolls over into the next segment, and the day is clamped to the length of the month. The field can't hold an impossible date.
- Pasting a whole date in a common format fills every segment.
- A button opens a month grid for picking by sight.
- The same control edits times (`14:30`) and date-times.

## Supporting controls

These exist so an app built on Quilt reads as one design. They keep Qt's API.

### Button and IconButton

- The pressed state shows in the frame of the press.
- At most one `primary` button per view takes the accent colour. The rest are neutral.
- `IconButton` requires a tooltip text. An icon alone is a guess; the tooltip makes it certain.
- The hit area of an icon button is the full control height, whatever the glyph's size.

### Menu

- Rows are the control height. Shortcuts are shown dimmed at the right.
- Items that can't apply are hidden in the row menu, and disabled in app menus, where a fixed position matters more.
- Menus open as real windows, like dropdown lists.

### ToolTip

- Appears after 600 ms at rest. Once one tooltip has shown, moving to a neighbouring control shows the next immediately.
- Disappears on any press, key or scroll.
- Only says what isn't already on screen: the full text of a cut-off label, a description, a shortcut, what drives a value, why it is invalid.
- Never holds information the user needs in order to proceed.

### ScrollBar

- An overlay: it takes no space, so content doesn't shift when it appears.
- Hidden at rest. It appears while scrolling or when the pointer nears the edge, grows wider on hover, and fades after a second of stillness.
- The thumb is never shorter than 24 px.
- `policy: AlwaysOn` keeps it visible for those who want it.

### ProgressBar

- Determinate when the amount is known; indeterminate otherwise.
- It moves forward only, and eases between values so it doesn't jump.
- It is meant for work longer than about a second. Shorter tasks should show nothing.
- Past roughly ten seconds, a bar alone isn't enough: the app should say what is happening and offer a way to cancel.

### BusyIndicator

The waiting wheel, for short waits of unknown length.

- It appears only after 400 ms and then stays at least 300 ms, so it never flickers.
- It is small (16 px) and sits where the result will appear. It never covers the interface.
- It is animated on the render thread, so it keeps turning while the app's main thread is busy. A frozen spinner says "crashed".

## Choosing a control

For developers. One row per kind of value, so there is no choice to deliberate over.

| The value is | Use |
|---|---|
| A number | `NumberField` |
| A number with a natural range | `NumberField` with `from` / `to` |
| A small count changed one at a time | `NumberField` with `steppers: true` |
| A position along a range, outside an inspector | `Slider` |
| One of many continuous values in a dense grid | `Knob` |
| A yes/no property | `CheckBox` |
| A feature or section on/off | `Switch` |
| One of 2 to 5 options | `SegmentedButton` |
| One of 6 or more options | `ComboBox` |
| Several independent on/off options | `SegmentedButton` with `exclusive: false` |
| Short text | `TextField` |
| Long text | `TextArea` |
| 2 to 4 related numbers | `VectorField` |
| A small grid of numbers | `MatrixField` |
| A colour | `ColorField` |
| A date or time | `DateField` |
| Something else | The app's own item inside a `PropertyRow` |

## Engineering rules

These are requirements on the implementation. Each one exists because breaking it produces a control that feels unstable.

**Stability**

1. **Controls never write to their own `value`.** They display it and emit edits. This removes binding loops and the stale-control problem described in [scope.md](scope.md#1-the-app-owns-the-value).
2. **Nothing shifts.** Row heights are fixed. Gutters are reserved. Numerals are tabular. Scroll bars overlay. A state marker, an error or a hover never moves a neighbouring pixel.
3. **An edit lands where it started.** The target is captured at `editStarted`. A pending edit is committed before the selection changes, before its panel is moved, tabbed away or closed, and before a popup's owner goes away.
4. **Display never alters data.** Rounding is for showing. Stepping is counted in whole steps from the start value.
5. **A drag is owned.** Once started, the control holds the pointer grab until release. The inspector's scroll view may not steal it.
6. **Popups follow the panel.** Dock panels move between windows. A control must not hold on to its window: popups are created for the window the control is in when they open, and close if their panel is re-parented.
7. **Hover is free of side effects.** Only visuals and tooltips respond to hover.

**Responsiveness**

8. **Input is answered in the same frame.** No handler waits on an animation or a timer before changing state.
9. **Animations are interruptible** and never block the next input.
10. **Created on demand.** Popups, pickers and menus are created when first opened. Section content is created on first expand. One picker and one row menu are shared per window.
11. **Rows are reused.** A selection change updates values in place. It doesn't rebuild the inspector.
12. **Controls are cheap.** A simple control is a few rectangles and a text item. No per-control shader effects, shadows or canvases.
13. **Idle means idle.** No timers or animations run when nothing is happening, and none run for controls that aren't visible.
14. **`live: false` exists everywhere.** For values that are expensive to apply, the app can ask for one `edited` at the end of a gesture instead of one per frame.

**Targets** to verify once the controls exist: an inspector of 300 rows scrolls at the display's refresh rate, and switching between two objects of the same kind updates within one frame.

**Tests.** Every control has headless QtQuick.Test coverage for: a click doesn't change a number; the drag threshold; Esc restores the start value; the wheel is ignored without focus; exactly one `editStarted` and one `editFinished` per gesture; clamping; each parameter state; and the control showing the app's value after a refused edit.

## Accessibility

- **Everything works from the keyboard.** Every control is reachable with Tab and operable without a pointer. Compound controls are a single Tab stop with arrow keys inside.
- **Names and roles.** Each control sets its accessible role, takes its accessible name from the row label, and exposes its value and state as text ("Opacity, 62 percent, modified").
- **Contrast.** Primary and secondary text meet WCAG AA (4.5:1). Tertiary text (placeholders, disabled values), state colours and focus rings meet 3:1 against what they sit on. The figures are in [visual-design.md](visual-design.md#colour).
- **Never colour alone.** Every state has a shape as well as a colour.
- **Reduced motion.** Setting the animation duration token to 0 switches off all motion.
- **Scaling.** One token scales text and control sizes together, for users who need a larger interface.
- **Translation.** Every built-in string (`Mixed`, menu items, tooltips) is translatable.
