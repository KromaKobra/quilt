# Using Quilt's controls, theme and parameters

This guide covers everything in Quilt besides docking: the value controls and the property grid (`Quilt.Controls`), the theme (`Quilt.Style`), and the optional parameter engine (`Quilt.Params`). For docking, see [integration.md](integration.md). For why the controls behave the way they do, see [controls.md](controls.md). A complete API reference is at the end.

- [Requirements and imports](#requirements-and-imports)
- [1. A single control](#1-a-single-control)
- [2. The edit contract](#2-the-edit-contract)
- [3. The property grid](#3-the-property-grid)
- [4. Undo](#4-undo)
- [5. Parameter states](#5-parameter-states)
- [6. Parameter objects](#6-parameter-objects)
- [7. A generated inspector](#7-a-generated-inspector)
- [8. Quilt.Params: linking and expressions](#8-quiltparams-linking-and-expressions)
- [9. Typed input and expressions](#9-typed-input-and-expressions)
- [10. Window chrome: title bar and menus](#10-window-chrome-title-bar-and-menus)
- [11. Theming](#11-theming)
- [12. Accessibility](#12-accessibility)
- [13. Living next to Qt Quick Controls](#13-living-next-to-qt-quick-controls)
- [14. Tips and gotchas](#14-tips-and-gotchas)
- [API reference](#api-reference)

## Requirements and imports

Qt 6.8 or newer, with Qt Quick, Qt Quick Controls (for its templates) and Qt Quick Shapes. All are part of `qtdeclarative`. Nothing needs compiling. Add the folder that contains `Quilt/` to the import path as described in [integration.md](integration.md#1-add-quilt-to-your-project).

| Import | Gives you | Brings along |
|---|---|---|
| `import Quilt.Controls` | Every control, the property grid, `ApplicationWindow`, `TitleBar` | `Quilt.Style` |
| `import Quilt.Style` | `Theme`, `Icon`, `Menu`, `MenuItem`, `MenuSeparator`, `Action`, `ToolTip`, `Tip`, `Rebind`, `PopupBackground` | |
| `import Quilt.Params` | `Parameter`, `ParameterSet`, `MergedParameter` | |
| `import Quilt` | Docking | `Quilt.Style` |

Each layer works without the others. `Quilt.Controls` doesn't need docking, and docking doesn't need the controls. To ship less, delete `Quilt/Controls/` or `Quilt/Params/`.

## 1. A single control

A Quilt control is used like a stock one: bind it to your value, and write the value back when the user edits it.

```qml
import QtQuick
import Quilt.Controls

ApplicationWindow {
    width: 400; height: 200; visible: true

    QtObject { id: shape; property real width: 120 }

    NumberField {
        x: 20; y: 20; width: 200
        value: shape.width
        from: 0; to: 500; suffix: " px"
        onEdited: v => shape.width = v
    }
}
```

That field can already be dragged sideways (Shift ×10, Ctrl ×0.1, Esc cancels), clicked and typed into (`2*pi`, `+=10`, `5cm` with a unit table), and stepped with the arrow keys or the wheel once it has focus. `from` and `to` make it a slider: a fill shows where the value sits in its range.

`ApplicationWindow` here is Quilt's: a Qt `ApplicationWindow` with the theme's canvas colour, font and a matching palette. Any window works; this one saves you the palette.

## 2. The edit contract

Every value control follows the same three rules, whatever it edits.

**The control shows what your application holds.** Like a stock control, it updates its own value when the user edits it, so a control nobody listens to still works. Unlike a stock control, after every edit it reads whatever its value is bound to again. If your application clamped, rounded or refused the edit, the control shows the result, not what the user asked for:

```qml
NumberField {
    value: shape.width
    onEdited: v => shape.width = Math.round(Math.min(v, 400))   // the field shows 400, not 1000
}
NumberField { value: document.locked ? 0 : 5 }   // no handler: an edit is refused and snaps back
NumberField { value: 5 }                         // no binding: it keeps what the user entered
```

`examples/cpp-host/` shows the same with a C++ object whose setters clamp, round and refuse.

**Edits are transactions.** Every value control has the same three signals:

| Signal | When |
|---|---|
| `editStarted()` | The first moment a gesture changes the value: a drag passes its threshold, a key is typed, a dropdown option is chosen |
| `edited(value)` | Each time the in-progress value changes. With `live: false`, once, at the end |
| `editFinished(committed)` | Exactly once per `editStarted`. `committed` is false when the user cancelled |

A checkbox click emits all three at once, so one pattern fits every control. On Esc the control emits `edited(startValue)` before `editFinished(false)`, so an application that only handles `edited` still ends up with the right value. A run of arrow-key or wheel steps is one transaction, closed after a short pause or when the control loses focus.

**An edit lands on the object it started on.** Clicking somewhere that takes no keyboard focus (a viewport, a canvas) applies the text being typed into a field before that click can act, so selecting another object never carries the typed value over to it. A drag or a run of steps whose parameter object is replaced midway finishes on the original object and changes nothing more.

**Nothing changes by accident.** Hovering never changes a value. The wheel only steps a control that has keyboard focus and is under the pointer; otherwise it scrolls the panel. A drag that starts mostly vertical isn't a scrub, so scrolling a panel with a pen or trackpad is safe. Clicking a field selects its text instead of changing anything.

## 3. The property grid

`Inspector`, `Section` and `PropertyRow` lay values out so that thirty of them can be read at a glance.

```qml
Inspector {
    anchors.fill: parent
    emptyText: "Nothing selected"

    PropertyRow { label: "Name"; TextField { text: shape.name; onEdited: v => shape.name = v } }

    Section {
        title: "Transform"
        key: "transform"                       // remembers open or closed between runs
        PropertyRow { label: "Position"; VectorField { value: shape.position; onEdited: v => shape.position = v } }
        PropertyRow { label: "Rotation"; NumberField { value: shape.rotation; from: 0; to: 360; wrap: true; suffix: "°"
                                                      onEdited: v => shape.rotation = v } }
    }

    Section {
        title: "Shadow"
        contentEnabled: shape.shadow           // the rows dim when the feature is off
        accessory: Switch { checked: shape.shadow; onEdited: v => shape.shadow = v }
        PropertyRow { label: "Blur"; NumberField { value: shape.blur; minimum: 0; onEdited: v => shape.blur = v } }
    }
}
```

What the grid does for you:

- **One value column.** Every control starts on the same vertical line. The user can drag the invisible divider between labels and values; a double-click on it goes back to the automatic width.
- **The label belongs to the control.** Clicking a label does the control's main action (focus a field, toggle a checkbox, open a dropdown). Dragging a number's label scrubs the number.
- **The row menu.** Right-click a row (or press the Menu key in its control) for Reset to Default, Copy Value, Paste Value, and, when the control supports linking, Copy Reference, Paste as Link, Edit Expression and Remove Expression. Add your own items with `PropertyRow.menu`:

  ```qml
  PropertyRow {
      label: "Opacity"
      menu: [{ text: "Add Keyframe", triggered: () => timeline.key("opacity") }]
      NumberField { … }
  }
  ```
- **Narrow and wide panels.** Below `stackBelow` (200 px) rows put the label above the control. Controls stop growing at `maximumFieldWidth` (280 px).
- **Scrolling** by wheel, with an overlay scroll bar and a fade at the clipped edge. Keyboard focus that moves off-screen is scrolled into view.
- **Filtering.** `searchable: true` adds a filter field; rows whose label doesn't match are hidden and sections containing matches open.
- **Sections** toggle from the whole header (Ctrl+click toggles every section), take Left/Right/Space from the keyboard, and show a dot when collapsed over a modified value.

`PropertyRow` accepts any item as its control, including your own. To take part in the row's features, the item offers what it can of: `modified`, `reset()`, `activate()`, `copyText()`, `pasteText(text)`, and for label scrubbing `canScrub`, `scrubBegin()`, `scrubBy(dx, modifiers)`, `scrubEnd(commit)`. A `fillsRow: true` property makes the row stretch it to the column width; `PropertyRow.fill` overrides that.

## 4. Undo

Connect the three transaction signals to your undo stack. A whole drag, however many values it passes through, becomes one step:

```qml
NumberField {
    value: shape.width
    onEditStarted: undo.begin("Change width")
    onEdited: v => shape.width = v
    onEditFinished: committed => committed ? undo.commit() : undo.rollback()
}
```

With parameter objects ([section 6](#6-parameter-objects)) the control calls `beginEdit()` and `endEdit(committed)` on the parameter instead, so the hook lives in one place. `examples/sandbox.qml` has a complete undo/redo stack built this way on top of `ParameterSet`.

Use `live: false` when applying a value is expensive (a re-render, a network call): the control then emits one `edited` at the end of a gesture instead of one per frame, while still showing the value under the pointer.

## 5. Parameter states

Every value control can show four states. Set them with plain properties, or let a parameter object supply them ([section 6](#6-parameter-objects)).

```qml
NumberField { value: 1.5; defaultValue: 1 }                                 // modified: a dot in the row's gutter
NumberField { value: w / 2; paramState: Param.Driven; expression: "width / 2"; message: "Follows Width" }
NumberField { paramState: Param.Mixed }                                     // a multiple selection that differs
NumberField { value: 2; paramState: Param.Invalid; message: "Missing ')'" }
NumberField { value: 3.14; readOnly: true }                                 // no fill: can't be edited
```

| State | Looks like | Behaves like |
|---|---|---|
| Modified (`defaultValue` set and different) | An accent dot left of the label | Clicking the dot resets. So does `reset()` and the row menu |
| `Param.Driven` | Violet value with an `ƒ` badge | Can't be dragged or stepped. Clicking shows the `expression` for editing. Typing a plain number replaces it |
| `Param.Mixed` | The word "Mixed" (a dash in a checkbox) | Can't be dragged. Typing a value sets it on everything |
| `Param.Invalid` | A red ring, the last good value dimmed | `message` explains why, in the tooltip |
| `readOnly` | The value with no field fill | Text can still be selected and copied |
| `enabled: false` | The control at reduced opacity | Skipped by Tab |

`message` is the tooltip: what drives the value, or why it is invalid. With `acceptsExpressions: true`, typing `=` followed by an expression emits `expressionEdited(text)` (without the `=`) instead of `edited`, and `""` means "remove the expression".

## 6. Parameter objects

When your application already describes each value as an object (most applications with an inspector do), hand that object to the control instead of wiring properties one by one:

```qml
PropertyRow { label: "Width"; NumberField { param: shape.params.width } }
```

A *parameter object* is anything with the members below: a QML `QtObject`, a C++ `QObject`, a Python object. It is duck-typed: there is no base class and nothing to register. Only `value` and `setValue` are required; each optional member switches on one feature.

| Member | Required | Enables |
|---|---|---|
| `value` | Yes | Display. Always the current, evaluated value |
| `setValue(v)` | Yes | Editing |
| `beginEdit()`, `endEdit(committed)` | | Undo grouping |
| `defaultValue` | | The modified marker and reset |
| `reset()` | | Your own reset (otherwise `setValue(defaultValue)`) |
| `state` | | `Param.Normal`, `Driven`, `Mixed` or `Invalid` |
| `expression` | | The text shown when the user edits a driven value |
| `setExpression(text)` | | Typing `=…`, Paste as Link, Remove Expression |
| `message` | | Tooltip text |
| `reference` | | Copy Reference: the name other expressions use for it |
| `readOnly` | | Display without editing |

When `param` is set, it replaces the control's own `value`, `defaultValue`, `paramState`, `expression`, `message` and `readOnly`.

A minimal C++ parameter:

```cpp
class Param : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariant value READ value NOTIFY valueChanged)
    Q_PROPERTY(QVariant defaultValue READ defaultValue CONSTANT)
public:
    Q_INVOKABLE void setValue(const QVariant &v);
    Q_INVOKABLE void beginEdit();               // open an undo macro
    Q_INVOKABLE void endEdit(bool committed);   // close or roll it back
    …
};
```

## 7. A generated inspector

Give the inspector a list of parameter objects and it builds the rows: one per parameter, grouped into sections by `group`, with a control chosen from `type`.

```qml
Inspector {
    model: selection.parameters                     // a JS array, a list of QObjects, a ListModel or a C++ item model
    delegates: ({ "curve": curveEditor })           // your own control for your own type
}
```

Each parameter describes itself with these members, beyond the adapter's:

| Member | |
|---|---|
| `label` (or `name`) | The row label |
| `group` | The section it goes in. Parameters without one come first, outside any section |
| `type` | Picks the control (table below). Without a type, the value decides: a boolean is a checkbox, a string a text field, anything else a number field |
| `control` | Asks for a specific control for its type: `"slider"`, `"segmented"`, `"switch"`, `"textarea"` |
| `description` | Tooltip on the label |
| hints | `from`, `to`, `minimum`, `maximum`, `step`, `stepSize`, `decimals`, `integer`, `suffix`, `displayScale`, `wrap`, `logarithmic`, `steppers`, `units`, `exclusive`, `alpha`, `swatches`, `labels`, `linkable`, `mode`, `seconds`, `placeholderText`, `minimumLines`, `maximumLines`, `live`, `options`. Either as members of the parameter, or gathered in one `hints` object |

| `type` / `control` | Control |
|---|---|
| `number`, `float`, `angle`, … (anything else) | `NumberField` |
| `int` | `NumberField` with `integer: true` |
| `bool` | `CheckBox` |
| `switch` | `Switch` |
| `string`, `text` | `TextField` |
| `textarea`, `multiline` | `TextArea` |
| `enum`, `options` | `ComboBox`, with `options` as its model |
| `segmented` | `SegmentedButton`, with `options` as its model |
| `slider` | `Slider` |
| `color` | `ColorField` |
| `vector` | `VectorField` |
| `date`, `time`, `datetime` | `DateField` in that mode |

**Your own types.** `delegates` maps a type (or `control`) name to a `Component`. Its root receives the parameter in a `param` property, plus any hint whose name matches one of its properties:

```qml
Component {
    id: curveEditor
    CurveField { property var param; height: 3 * Theme.rowHeight }
}
```

**Item models.** A row of a `ListModel` or C++ model either carries a whole parameter object in a role named `parameter`, or is described by roles named like the members above (`value`, `label`, `type`, `group`, `from`, …). An edit writes the `value` role; typing `=…` writes the `expression` role when the model has one.

**Rows are reused.** Selecting another object whose parameters have the same groups and types keeps every row: the scroll position, open sections and the label width stay as they were, and only the values change. The rows are rebuilt only when the structure differs.

**Multiple selection.** Show several objects at once by merging their parameters. `MergedParameter` (from `Quilt.Params`) reports `Param.Mixed` when its sources differ and sends an edit to all of them; it works with any parameter objects, not only Quilt's:

```qml
Instantiator {
    model: ["width", "height", "fill"]
    delegate: MergedParameter {
        required property string modelData
        sources: selection.map(shape => shape.params[modelData])
    }
    …
}
```

## 8. Quilt.Params: linking and expressions

`Quilt.Params` is a small reference engine for applications that don't have their own: values, defaults, expressions that refer to other values, and undo hooks. Applications with their own engine connect it through the adapter instead; nothing in `Quilt.Controls` depends on this module.

```qml
import Quilt.Params

ParameterSet {
    id: params

    Parameter { name: "cube.width"; label: "Width"; group: "Size"; value: 100; defaultValue: 100; suffix: " px" }
    Parameter { name: "cube.height"; label: "Height"; group: "Size"; value: 50; expression: "width / 2" }   // follows cube.width
    Parameter { name: "card.angle"; label: "Angle"; from: 0; to: 360; suffix: "°"; expression: "cube.width * 0.9" }

    onEditStarted: parameter => undo.begin()
    onEditFinished: (parameter, committed) => undo.end(committed)
}

Inspector { model: params.list("cube.") }
```

- **Names** may contain dots. Inside an expression, a bare name is first looked up next to the parameter (`cube.height` sees `cube.width` as `width`), then from the top. A component of a vector, size or colour is read as `cube.position.x`.
- **Evaluation** happens when something changes, on the UI thread: only what depends on the change is re-evaluated, in dependency order.
- **Cycles** are refused when they are entered. The parameter becomes `Invalid`, keeps its last good value, and says "Circular reference". It recovers by itself when the cycle is broken.
- **Linking from the UI.** Type `=cube.width * 2` into any field. Right-click › Copy Reference on one row, then Paste as Link on another. Typing a plain number into a driven field replaces the expression with that number; Remove Expression keeps the current value.
- **Saving and undo.** `save()` returns every value and expression as plain data (JSON-safe, colours and vectors included); `restore(state)` puts it back and re-evaluates. That is all an undo stack needs: see `history` in `examples/sandbox.qml`.
- **Size.** It is meant for interactive editing of hundreds or a few thousand values. It is not a per-frame animation evaluator or a constraint solver.

User text never reaches JavaScript's `eval` or `Function`. Quilt has its own parser, so an expression can't run code.

## 9. Typed input and expressions

What a number field accepts:

| Typed | Result |
|---|---|
| `12.5`, `1,5` | The number (a lone comma is a decimal separator) |
| `2*pi`, `(120+48)/2`, `sqrt(2)`, `2^10` | The arithmetic |
| `+=10`, `-=5`, `*=2`, `/=2` | Applied to the current value |
| `45°`, `12 px` | The field's own suffix is accepted and ignored |
| `5cm` | 0.05, with `units: ({ cm: 0.01, mm: 0.001 })` on a field measured in metres |
| `2.7` in an `integer` field, a value past `minimum`/`maximum` | Corrected, and the field flashes once to say so |
| `=cube.width/2` | An expression, when the control accepts them |
| `1, 2, 3` in a vector component | Fills every component |
| Anything else | The field stays in editing with a red ring and the reason in a tooltip. Esc or clicking away restores the old value |

The language: numbers (`12`, `.5`, `1e-3`), `+ - * / % ^`, comparisons, `&& || !`, `cond ? a : b`, the constants `pi`, `tau`, `e`, `true`, `false`, and the functions `abs sign sqrt round floor ceil trunc exp ln log log2 sin cos tan asin acos atan atan2 rad deg pow mod min max clamp lerp step smoothstep if`. A number directly followed by a name multiplies by it (`2pi`, `90deg` with a `deg` unit).

The same evaluator is available to your code through the `Expression` singleton:

```qml
Expression.evaluate("w / 2", { resolve: name => vars[name] }).value
```

For your own parsing, give a `NumberField` a `valueFromText` (return `NaN` to reject) and `textFromValue`, and a `resolver` function to give names a meaning in its arithmetic.

## 10. Window chrome: title bar and menus

`TitleBar` gives a window dropdown menus, a centred title and, in a frameless window, the minimize, maximize and close buttons, moving by drag, maximizing by double-click, and resizing from the window's edges.

```qml
ApplicationWindow {
    frameless: true                         // TitleBar replaces the system's title bar
    title: "Untitled — MyApp"

    menuBar: TitleBar {
        Menu {
            title: "&File"
            Action { text: "Open…"; shortcut: StandardKey.Open; onTriggered: openFile() }
            MenuSeparator { }
            Action { text: "Quit"; shortcut: StandardKey.Quit; onTriggered: Qt.quit() }
        }
        Menu {
            title: "&View"
            Action { text: "Grid"; checkable: true; checked: view.grid; onTriggered: view.grid = !view.grid }
        }
        trailing: Button { text: "Share"; flat: true; onClicked: share() }
    }
}
```

- With the system's title bar left on (`frameless: false`), `TitleBar` is simply a themed menu bar, and shows no title of its own.
- `leading` and `trailing` take your items: after the menus, and before the window buttons.
- The window buttons go on the left on macOS (`buttonsOnLeft`).
- Pop-out dock windows can use the same bar: see `windowComponent` in `examples/sandbox.qml`.

**Menus.** `Menu`, `MenuItem`, `MenuSeparator` and `Action` keep Qt's API. Shortcuts are shown dimmed at the right; checkable rows line their labels up. A checkable `Action` or `MenuItem` can simply be bound to your application's state, as above: after every click it shows that state again, even when nothing changed it. (A stock Qt one would flip itself and stay wrong.) `Rebind` brings the same fix to a stock control:

```qml
CheckBox {                                  // QtQuick.Controls
    id: box
    checked: document.visible
    onToggled: { document.setVisible(checked); rebind.refresh(); }
    Rebind { id: rebind; target: box; property: "checked" }
}
```

**Icons.** `Icon { name: "reset" }` draws one of Quilt's line glyphs (12-unit grid, round caps). `Icon.names` lists them: close, minimize, maximize, restore, popout, menu, more, grip, chevrons and arrows in four directions, check, dash, plus, minus, undo, redo, reset, copy, trash, link, unlink, search, filter, settings, eye, eye-off, lock, unlock, info, help, warning, play, pause, stop, calendar, folder, file, grid, layers. `Icon { path: "M 2 6 H 10" }` draws your own SVG path on the same grid. `Button.iconName` and `IconButton.iconName` take the same names, and `IconButton.iconPath` a path.

## 11. Theming

Every colour, size and duration is a token on the `Theme` singleton (`Quilt.Style`). Docking reads the same tokens through `DockStyle`, so the panels and the controls always match.

```qml
// Switch the whole application to the light theme, at runtime:
Theme.dark = false

// Your brand's accent, kept for as long as the Binding is on, following
// Theme.dark otherwise:
Binding { target: Theme; property: "accent"; value: Theme.dark ? "#ff8a3d" : "#d4621c" }

// Or once at start-up (this replaces the dark/light pair with one colour):
Component.onCompleted: Theme.accent = "#ff8a3d"
```

Common adjustments:

| To get | Set |
|---|---|
| A light interface | `Theme.dark = false` |
| A 1 px outline on every control, for users who need more contrast | `Theme.controlBorder = Theme.textTertiary` |
| No motion at all | `Theme.durationFast`, `Theme.duration` and `Theme.durationLayout` to `0` |
| A larger interface | Run with `QT_SCALE_FACTOR=1.25`; or raise `fontSize`, `controlHeight` and `rowHeight` together |
| Dropdowns and menus that may leave the window (Qt 6.8+, where the platform supports it) | `Theme.popupType = Popup.Window` (that is, `1`) |
| Your own font | `Theme.fontFamily` |
| Seamless panels (hairlines instead of gaps) | On the `DockArea`: `style.gap: 1; style.radius: 0; style.background: Theme.border` |
| Shift for fine and Ctrl for coarse | Swap `Theme.coarseFactor` and `Theme.fineFactor` (and the modifiers in `Theme.stepFactor` if you need other keys) |

The full list is in the [API reference](#theme). [visual-design.md](visual-design.md) explains what each colour role is for and the contrast every pair meets; `tests/tst_chrome.qml` checks those contrasts for both themes, so a token change that breaks them fails the tests.

Your own items can use the same tokens and pieces: `Theme.text` for a value, `Theme.textSecondary` for a label, `PopupBackground` behind anything that floats, `Tip { text: …; shown: hover.hovered }` for a tooltip that exists only while it's wanted.

## 12. Accessibility

- **Keyboard.** Every control is reachable with Tab and works without a pointer. Compound controls (vector, segmented button, date) are one Tab stop with the arrow keys inside. The focus ring shows for keyboard focus, not for a mouse click.
- **Names.** Inside a `PropertyRow`, the row label becomes the control's accessible name, unless you gave it one. Elsewhere, set `Accessible.name` yourself. An `IconButton` is named by its `tip`, a `Knob` by its caption.
- **Value and state.** Each control describes its value and state in words ("62%, modified", "45, driven, = width * 2") in `Accessible.description`.
- **Colour is never alone.** Every state has a shape as well: the dot, the `ƒ`, the ring, the word "Mixed".
- **Contrast.** Text and marks meet WCAG AA in both themes (checked by the tests).
- **Translation.** Every built-in string goes through `qsTr`.

## 13. Living next to Qt Quick Controls

Quilt uses the same names as Qt for the same controls (`CheckBox`, `ComboBox`, `Slider`, `Button`, `Menu`, …), each a superset of Qt's API. In a file that imports both, QML uses the module imported last. To remove any doubt, import one with a qualifier:

```qml
import QtQuick.Controls
import Quilt.Controls as Q

Q.NumberField { … }
```

Stock controls inside a Quilt `ApplicationWindow` pick up a palette made from the theme, so they don't look out of place while you migrate.

## 14. Tips and gotchas

- **Bind, then write back.** Bind `value` (or `checked`, `text`) to your data and write it in `onEdited`. Don't assign to the control's `value` from `onEdited`: the control already shows the edit, and re-reads your binding afterwards.
- **Assigning to `value` from script** removes your binding, as with any QML property. Bind instead, or use a parameter object.
- **A transaction is per control.** If one gesture changes several of your values (a linked vector, a merged selection), they all arrive inside the one `editStarted`/`editFinished` pair.
- **`live: false` in a slider-like field** still moves the fill under the pointer; only the reporting waits.
- **The inspector doesn't scroll by dragging.** A drag belongs to the controls; the wheel scrolls the panel.
- **Endless dragging isn't possible** in pure QML: the pointer stops at the screen edge, and so does the value. Shift (×10) and typing cover the gap.
- **No `MatrixField` yet.** A grid of numbers is a `Repeater` of `NumberField`s in a `Grid` for now.

## API reference

Properties marked *ro* are read-only. Every value control also has the [shared members](#shared-by-every-value-control).

### Shared by every value control

`NumberField`, `TextField`, `TextArea`, `CheckBox`, `Switch`, `SegmentedButton`, `ComboBox`, `Slider`, `VectorField`, `ColorField`, `Knob`, `DateField`.

| Property | Type | Default | |
|---|---|---|---|
| `param` | `var` | `null` | A [parameter object](#6-parameter-objects); replaces the five below |
| `defaultValue` | `var` | undefined | Enables the modified marker and `reset()` |
| `paramState` | `int` | `Param.Normal` | `Param.Normal`, `Param.Driven`, `Param.Mixed`, `Param.Invalid` |
| `expression` | `string` | | What editing shows while driven |
| `message` | `string` | | Tooltip: what drives the value, or why it is invalid |
| `readOnly` | `bool` | `false` | Display without editing |
| `acceptsExpressions` | `bool` | `false` | Typing `=…` emits `expressionEdited` (without a `param`) |
| `modified` | `bool` *ro* | | Differs from `defaultValue` |

| Signal | |
|---|---|
| `editStarted()` | A transaction began |
| `edited(value)` | The value changed during it |
| `editFinished(bool committed)` | It ended; `false` when cancelled |
| `expressionEdited(string text)` | The user entered an expression; `""` removes it |

| Method | |
|---|---|
| `reset()` | Back to `defaultValue`, as one edit |
| `setExpression(text)` | Hands an expression to the application, as one edit |
| `activate()` | The control's main action: what clicking its row label does |
| `copyText()`, `pasteText(text)` | The value as text, and back; used by the row menu and Ctrl+C / Ctrl+V |

### NumberField

Edits an int or a float. Also the inspector's slider (`from`/`to`) and stepper (`steppers`).

| Property | Type | Default | |
|---|---|---|---|
| `value` | `real` | `0` | |
| `integer` | `bool` | `false` | Whole numbers only |
| `from`, `to` | `real` | ±∞ | The soft range: what the fill shows and a drag covers. Both set: a slider |
| `minimum`, `maximum` | `real` | ±∞ | Hard limits: what the value can ever be |
| `step` | `real` | 1 (int), 1% of the range, or 0.1 | One arrow-key step; a drag lands on multiples of it |
| `wrap` | `bool` | `false` | Go round from `to` back to `from` (angles) |
| `logarithmic` | `bool` | `false` | Spread a ranged field logarithmically (needs `from > 0`) |
| `live` | `bool` | `true` | `false`: one `edited` at the end of a drag |
| `decimals` | `int` | 0 (int) or 3 | At most this many shown; trailing zeros dropped |
| `displayScale` | `real` | `1` | Shown and typed as `value × displayScale` (100 for a percentage) |
| `suffix` | `string` | | `"°"`, `" px"`, `"%"`: shown dimmed, never part of the edit text |
| `lead` | `string` | | A short dim label inside the field, e.g. `"X"` |
| `steppers` | `bool` | `false` | − and + buttons; holding repeats |
| `flat` | `bool` | `false` | No fill or ring; for use inside another control |
| `scrubbable` | `bool` | `true` | Dragging changes the value |
| `units` | `var` | `{}` | `{ cm: 0.01 }`: what a unit after a number multiplies by |
| `resolver` | `function(name)` | `null` | The value of a name used in typed arithmetic |
| `textFromValue` | `function(value)` | `null` | Your own display text |
| `valueFromText` | `function(text)` | `null` | Your own parser; return `NaN` to reject |
| `listHandler` | `function(numbers)` | `null` | Takes over when a list such as `1, 2, 3` is typed |
| `ranged`, `editing`, `scrubbing`, `focused`, `canScrub` | `bool` *ro* | | |
| `position` | `real` *ro* | | 0..1 along the soft range |
| `displayText` | `string` *ro* | | What is shown, without the suffix |

Methods: `increase()`, `decrease()`, `stepBy(n, modifiers)`, `beginEdit([replacement])`, `commitEdit()` (false when the text is refused), `cancelEdit()`, `scrubBegin()`, `scrubBy(dx, modifiers)`, `scrubEnd(commit)`.

Keys: Up/Down step (Shift ×10, Ctrl ×0.1), PageUp/PageDown ×10, Home/End the ends of the range, Enter or F2 edits, typing replaces, Backspace clears, Esc cancels a drag or a run of steps, Ctrl+C / Ctrl+V.

### TextField

Qt's `TextField`, plus:

| Property | Type | Default | |
|---|---|---|---|
| `live` | `bool` | `false` | Report every keystroke instead of the result |
| `elide` | `int` | `Text.ElideRight` | How text that doesn't fit is cut while idle; `ElideMiddle` for paths |
| `search` | `bool` | `false` | A leading glyph and a clear button |
| `flat` | `bool` | `false` | No fill or ring |

Enter or clicking away applies; Esc restores. A `validator` that refuses the text shows the invalid ring; text that can't be accepted is dropped when focus leaves.

### TextArea

| Property | Type | Default | |
|---|---|---|---|
| `text`, `placeholderText`, `readOnly`, `wrapMode` | | | As Qt's |
| `minimumLines`, `maximumLines` | `int` | `3`, `8` | It grows between these, then scrolls |
| `live` | `bool` | `false` | |
| `editing` | `bool` *ro* | | |

Enter adds a line; Ctrl+Enter or clicking away applies; Esc restores. The wheel scrolls its text only while it has focus.

### CheckBox and Switch

Qt's `CheckBox` and `Switch` (`checked`, `text`, …). A click is one complete edit. A mixed checkbox shows a dash; clicking it turns the value on. Use a `Switch` for turning a feature or a section on, a `CheckBox` for a property.

### SegmentedButton

| Property | Type | Default | |
|---|---|---|---|
| `model` | `var` | `[]` | Strings, or `{ text, value, icon, tip, enabled }` (value defaults to text) |
| `value` | `var` | | The chosen option's value; an array of them when not exclusive |
| `exclusive` | `bool` | `true` | `false`: a row of independent toggles |
| `count`, `currentIndex` | `int` *ro* | | |

Methods: `isOn(index)`, `choose(index)`. Left/Right move the choice (Space toggles when not exclusive).

### ComboBox

Qt's `ComboBox`, plus:

| Property | Type | Default | |
|---|---|---|---|
| `value` | `var` | | The chosen option's value (its `valueRole`, or its text). Leave unset to work with `currentIndex` |
| `filterThreshold` | `int` | `12` | With more options than this, typing in the open list filters it |
| `filterable` | `bool` *ro* | | |
| `filterText` | `string` *ro* | | |

Options are strings, or objects `{ text, value, icon, color, enabled }` (no `textRole`/`valueRole` needed). `icon` is an Icon name, `color` shows a chip, `enabled: false` greys an option out, and `{ separator: true }` draws a line. The arrow keys skip what can't be chosen. In the open list, Enter or Space chooses the highlighted option; the first Esc clears a filter and the next closes the list.

### Slider

The classic track and thumb, for use outside an inspector.

| Property | Type | Default | |
|---|---|---|---|
| `value`, `from`, `to` | `real` | `0`, `0`, `1` | |
| `stepSize` | `real` | `0` | `0`: continuous |
| `orientation` | `int` | `Qt.Horizontal` | |
| `live` | `bool` | `true` | |
| `horizontal`, `pressed` | `bool` *ro* | | |
| `position` | `real` *ro* | | |

Signal `moved()`. Methods `increase()`, `decrease()`, `valueAt(fraction)`. With a `defaultValue` the track shows a tick and the thumb snaps to it (Ctrl passes freely).

### VectorField

| Property | Type | Default | |
|---|---|---|---|
| `value` | `var` | `[0, 0, 0]` | An array, `vector2d`/`3d`/`4d`, `point`, `size` or `rect`; edits come back as the same kind |
| `labels` | `var` | X Y Z W (W H for a size) | |
| `linkable`, `linked` | `bool` | `false` | A chain toggle; while linked, components scale together |
| `componentStates` | `var` | | A `Param` state for each component |
| `integer`, `from`, `to`, `minimum`, `maximum`, `step`, `decimals`, `displayScale`, `suffix`, `live` | | | Passed to every component |
| `count` | `int` *ro* | | |

Pasting or typing `1, 2, 3` into any component fills them all. The components stack when the row is too narrow.

### ColorField

| Property | Type | Default | |
|---|---|---|---|
| `value` | `color` | `"#000000"` | |
| `alpha` | `bool` | `true` | Show and edit opacity |
| `swatches` | `var` | `[]` | Your palette, offered in the picker beside the recent colours |
| `live` | `bool` | `true` | |
| `pickerOpen` | `bool` *ro* | | |

Method `openPicker()`. The hex field takes `#fff`, `fff`, `rrggbbaa`, `rgb(…)`, `rgba(…)` and colour names. One visit to the picker is one edit: Esc restores the colour it opened with; Enter or a click outside keeps the new one. The picker keeps hue and saturation through black, white and grey.

### Knob

| Property | Type | Default | |
|---|---|---|---|
| `value`, `from`, `to` | `real` | `0`, `0`, `1` | |
| `step` | `real` | 1% of the range | |
| `logarithmic` | `bool` | `false` | Needs `from > 0` |
| `decimals` | `int` | `2` | |
| `displayScale`, `suffix` | | `1`, `""` | |
| `text` | `string` | | The caption; the value replaces it while hovered or dragged |
| `bipolar` | `bool` | `false` | Draw the arc from the middle (pan) |
| `valueVisible` | `bool` | `false` | Always show the value |
| `size` | `real` | `32` | Dial diameter |
| `live` | `bool` | `true` | |
| `pressed` | `bool` *ro* | | |
| `position` | `real` *ro* | | |
| `displayText` | `string` *ro* | | |

Drag up for more (200 px covers the range). Click to type a value.

### DateField

| Property | Type | Default | |
|---|---|---|---|
| `value` | `date` | now | |
| `mode` | `string` | `"date"` | `"date"`, `"time"` or `"datetime"` |
| `seconds` | `bool` | `false` | Show seconds |
| `minimum`, `maximum` | `var` | | Optional limits |
| `live` | `bool` | `true` | |
| `calendarOpen` | `bool` *ro* | | |
| `displayText` | `string` *ro* | | |

Method `openCalendar()`. Each segment works like a small number field: click it, type digits (the selection moves on when it is full), Up/Down, or drag sideways. Stepping carries into the next segment, and the day is kept within the month. Space opens the month grid.

### Inspector

| Property | Type | Default | |
|---|---|---|---|
| *(default)* `content` | | | Sections and rows |
| `model` | `var` | `null` | Parameter objects to build rows from ([section 7](#7-a-generated-inspector)) |
| `delegates` | `var` | `{}` | `{ typeName: Component }` |
| `labelWidth` | `real` | 38% of the width, 80–200 px | Follows the width until the user drags the divider |
| `maximumFieldWidth` | `real` | `280` | |
| `stackBelow` | `real` | `200` | Narrower than this, labels go above controls |
| `filter` | `string` | | Show only rows whose label contains it |
| `searchable` | `bool` | `false` | A field above the rows that sets `filter` |
| `emptyText` | `string` | | Shown when there are no rows |
| `background` | `color` | `Theme.surface` | What the inspector sits on, for the scroll fades |
| `stacked` | `bool` *ro* | | |
| `count` | `int` *ro* | | Generated rows |
| `contentY`, `contentHeight` | `real` *ro* | | |

Method `reveal(item)`: scrolls an item inside into view.

### Section

| Property | Type | Default | |
|---|---|---|---|
| `title` | `string` | | |
| `expanded` | `bool` | `true` | |
| `key` | `string` | | Remember `expanded` between runs under this name (QtCore `Settings`, category `QuiltSections`) |
| *(default)* `content` | | | Rows, and at most one level of subsections |
| `accessory` | | | Items at the right of the header, e.g. a `Switch` |
| `contentEnabled` | `bool` | `true` | `false` dims the rows and blocks input |
| `divider` | `bool` | `true` | The hairline beneath |
| `hasModified` | `bool` *ro* | | A row inside differs from its default |

Method `toggle()`.

### PropertyRow

| Property | Type | Default | |
|---|---|---|---|
| `label` | `string` | | Also the control's accessible name |
| `description` | `string` | | Tooltip on the label |
| *(default)* `content` | | | The control: any item |
| `fill` | `var` | the control's `fillsRow` | Stretch the control to the column |
| `menu` | `var` | `[]` | Extra row-menu items: `{ text, enabled, triggered() }` |
| `control` | `Item` *ro* | | The first item in the row (or what its `Loader` loaded) |
| `modified`, `stacked` | `bool` *ro* | | |

### Button and IconButton

`Button` is Qt's `Button` plus `primary` (the one main action of a view, in the accent colour) and `iconName`. `IconButton` is a square `AbstractButton` with `iconName` or `iconPath`, `tip` (always give one), and `color` for the glyph at rest. Checkable buttons follow their binding after a click, like checkable actions.

### ScrollBar, ProgressBar, BusyIndicator, Label

Qt's APIs. `ScrollBar` is an overlay, hidden at rest, with a thumb never shorter than 24 px; `policy: ScrollBar.AlwaysOn` keeps it shown. `ProgressBar` eases between values and has an indeterminate mode, animated on the render thread. `BusyIndicator` adds `delay` (400 ms before it appears), `color`, and `showing` *ro*; once shown it stays at least 300 ms. `Label` adds `dim` for the secondary text colour.

### ApplicationWindow, TitleBar, MenuBar

`ApplicationWindow` is Qt's, plus `frameless`. It sets the canvas colour, the theme's font and a matching palette.

| `TitleBar` property | Type | Default | |
|---|---|---|---|
| *(default)* `menus` | | | `Menu`s |
| `title` | `string` | the window's title when frameless, else `""` | |
| `icon` | `url` | | A small image at the far left |
| `leading`, `trailing` | | | Your items, after the menus / before the window buttons |
| `color` | `color` | `Theme.canvas` | |
| `windowButtons` | `bool` | `frameless` | Minimize, maximize, close |
| `buttonsOnLeft` | `bool` | on macOS | |
| `resizeMargin` | `real` | `5` | Width of the resize edges of a frameless window |
| `window` | *ro* | | |
| `frameless`, `maximized` | `bool` *ro* | | |

Method `toggleMaximized()`. `MenuBar` and `MenuBarItem` are Qt's, themed; use them for a menu bar outside the title bar.

### Style module

| Type | |
|---|---|
| `Icon` | `name`, `path` (12×12 SVG path data), `color`, `size`, `strokeWidth`; `names` *ro* lists the built-in glyphs |
| `Menu`, `MenuItem`, `MenuSeparator`, `Action` | Qt's APIs. `MenuItem.shortcutText` overrides the shortcut shown |
| `ToolTip` | Qt's `ToolTip`, themed, with "warm" timing: once one has shown, the next appears without the delay |
| `Tip` | A tooltip that is only created while wanted: `text`, `shown`, `pressed` (a press puts it away until the pointer leaves and returns), `immediate` |
| `Rebind` | `target`, `property`, `refresh()`: makes a property read its binding again |
| `PopupBackground` | The surface of anything that floats, with the theme's shadow |

### Theme

`Theme` is a singleton. Assign or bind any token.

| Token | Dark | Light | |
|---|---|---|---|
| `dark` | `true` | | Switches every colour below that you haven't assigned |
| `canvas` | `#0e0f12` | `#e4e6ea` | Behind the panels |
| `surface` | `#1a1c20` | `#fafafb` | A panel |
| `raised` | `#23262b` | `#ffffff` | Popups, menus, tooltips |
| `control` | `#272a30` | `#eceef1` | A field or button at rest |
| `controlHover` | `#2f3239` | `#e2e5e9` | |
| `controlFill` | `#3a3e47` | `#d2d6dc` | A ranged field's fill, a selected segment, a pressed button |
| `border` | `#2d3037` | `#dadde2` | Hairlines, popup edges |
| `controlBorder` | transparent | transparent | An outline on every control (high contrast) |
| `shadow` | transparent | black at 12% | Under popups |
| `text` | `#e4e6ea` | `#1b1d21` | Values, current tab, titles |
| `textSecondary` | `#9ca1ab` | `#565c66` | Labels, other tabs, glyphs |
| `textTertiary` | `#787d87` | `#7b818b` | Placeholders, disabled text |
| `accent` | `#4c8dff` | `#2a66dd` | Focus, selection, "on", modified |
| `accentInk` | `#0e0f12` | `#ffffff` | Glyphs drawn on the accent |
| `driven` | `#a98bf5` | `#6f4ad3` | A computed value |
| `error` | `#f0616d` | `#c92f3a` | |
| `warning` | `#e0a53a` | `#946000` | For your own use |
| `danger` | `#e5484d` | | The close button, hovered |
| `selection`, `textSelection`, `rowHover` | | | Derived from `accent` and `text` |

| Token | Default | |
|---|---|---|
| `fontFamily` | the application font | |
| `fontSize`, `fontSizeSmall` | `12`, `11` | |
| `fontWeight`, `fontWeightStrong` | `Font.Normal`, `Font.Medium` | |
| `textRenderType` | `Text.NativeRendering` | |
| `controlHeight`, `rowHeight`, `tabHeight`, `titleBarHeight` | `24`, `28`, `32`, `36` | |
| `gap`, `panelPadding`, `gutter`, `controlPadding`, `glyphSize` | `6`, `12`, `16`, `8`, `12` | |
| `radius`, `controlRadius`, `innerRadius`, `focusWidth` | `8`, `4`, `3`, `1.5` | |
| `durationFast`, `duration`, `durationLayout` | `80`, `120`, `160` ms | `0` switches motion off |
| `dragThreshold` | `3` px | Before a press becomes a drag |
| `coarseFactor`, `fineFactor` | `10`, `0.1` | Shift and Ctrl |
| `toolTipDelay` | `600` ms | |
| `popupType` | `Popup.Item` | `Popup.Window` lets popups leave the window |

Functions: `alpha(color, a)`, `mix(a, b, t)`, `stepFactor(modifiers)`.

### Param, Expression, Clipboard

- `Param.Normal`, `Param.Driven`, `Param.Mixed`, `Param.Invalid`: the states.
- `Expression.evaluate(text, { resolve, units, current })` returns `{ ok, value, error }`. `Expression.parse(text)` returns `{ ok, ast, refs, error }` to evaluate many times with `Expression.run(ast, { resolve, units })`. `Expression.list(text)` reads `"1, 2, 3"` as `[1, 2, 3]`, or returns `null`.
- `Clipboard.copy(text)` and `Clipboard.paste()`: plain-text clipboard access from QML.

### Parameter

| Property | Type | |
|---|---|---|
| `name` | `string` | Unique in its set; what expressions call it |
| `label` | `string` | Default: the last part of the name |
| `type`, `group`, `description`, `control` | `string` | For a generated inspector |
| `value` | `var` | The entered value, or the expression's result |
| `defaultValue` | `var` | |
| `expression` | `string` | `""` when not driven |
| `readOnly` | `bool` | |
| `state` | `int` *ro* | `Invalid` on an error, `Driven` with an expression, otherwise `Normal` |
| `message` | `string` *ro* | The error, or `= expression` |
| `reference` | `string` *ro* | The name |
| hints | `var` | `from`, `to`, `minimum`, `maximum`, `step`, `stepSize`, `decimals`, `integer`, `suffix`, `displayScale`, `wrap`, `logarithmic`, `steppers`, `units`, `live`, `options`, `exclusive`, `alpha`, `swatches`, `labels`, `linkable`, `mode`, `seconds`, `placeholderText`, `minimumLines`, `maximumLines` |
| `parameterSet` | `var` *ro* | Set by its set |

Signal `edited(value)`. Methods `setValue(v)` (replaces an expression), `setExpression(text)`, `reset()`, `beginEdit()`, `endEdit(committed)`. Your code may also assign `value` directly (an animation, a tool); dependants follow.

### ParameterSet

| Member | |
|---|---|
| *(default)* `parameters` | `list<Parameter>` |
| `count` | *ro* |
| `find(name)` | The parameter, or `null` |
| `list(prefix)` | The parameters whose name starts with `prefix`, in order |
| `add(parameter)`, `remove(parameter)` | At runtime. `add` returns `false` if the name is taken |
| `save()`, `restore(state)` | Every value and expression as plain data, and back |
| `editStarted(parameter)`, `editFinished(parameter, committed)` | Signals: hook your undo stack here |
| `changed(parameter)` | Signal: a value changed, for any reason |

### MergedParameter

`sources`: the parameters to merge (any objects with the adapter's members). It has the adapter's members and the first source's description and hints, reports `Param.Mixed` when the sources' values differ, and sends `setValue`, `setExpression` and `reset` to every source. Only the first source reports `beginEdit`/`endEdit`, so one edit is one undo step.
