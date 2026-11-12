# Quilt scope

This document says what Quilt is, what it will grow into, and what it will never be. It is the reference for deciding whether a feature belongs in the project.

Docking exists today. Everything else here is **planned**: names and code samples are proposals, not a finished API.

Related planning documents: [controls.md](controls.md) (every control and how it behaves) and [visual-design.md](visual-design.md) (the look).

- [Quilt in one paragraph](#quilt-in-one-paragraph)
- [The layers](#the-layers)
- [Who uses Quilt](#who-uses-quilt)
- [The scope test](#the-scope-test)
- [In scope](#in-scope)
- [Out of scope](#out-of-scope)
- [How a developer uses Quilt](#how-a-developer-uses-quilt)
- [The three contracts](#the-three-contracts)
- [Linking and expressions](#linking-and-expressions)
- [Fitting into any panel-based program](#fitting-into-any-panel-based-program)
- [Constraints](#constraints)
- [Milestones](#milestones)
- [Open decisions](#open-decisions)

## Quilt in one paragraph

Quilt is a UI kit for panel-based tool applications built with Qt Quick: editors, DCC tools, IDE-like apps, anything made of inspectors, outliners, viewports and timelines. Such an app has two problems that have nothing to do with what it edits. The first is **where the panels go**, which the docking framework solves. The second is **how the user changes a value inside a panel**, which the controls and the property grid will solve. Quilt never knows what the app's data means. It arranges panels and edits values, and hands every change back to the app.

## The layers

| Layer | Module | Status | What it gives you |
|---|---|---|---|
| Style | `Quilt.Style` | Planned | One set of theme tokens (colours, sizes, timing) that every other layer reads |
| Layout | `Quilt` | **Built** | Docking: panels that split, tab, resize, maximize, pop out, and save their arrangement |
| Controls | `Quilt.Controls` | Planned | Input controls for editing values, and the property grid that lays them out |
| Parameters | `Quilt.Params` | Planned, optional | A small reference parameter model with linking and expressions, for apps that don't have their own |

```
Quilt.Style  ◄──  Quilt            (docking)
     ▲
     └────────  Quilt.Controls  ◄──  Quilt.Params   (optional)
```

The rules between layers:

- **Each layer works without the ones beside or above it.** An app can use docking with its own controls, or the controls with no docking at all. Docking never imports `Quilt.Controls`.
- **Everything still lives in the one `Quilt/` folder.** `Quilt/Style/`, `Quilt/Controls/` and `Quilt/Params/` are subfolders, so "copy one folder" stays true. An app that wants less deletes `Controls/` or `Params/`.
- **One theme.** `DockStyle` keeps working as it does today, but its defaults come from `Quilt.Style`, so docking and controls match without any setup.

## Who uses Quilt

Quilt has two kinds of user, and the scope has to serve both.

**The developer** builds a tool app. What they should experience:

- Adding a layer takes minutes: one import, a few lines of QML.
- Their data stays theirs. Quilt never stores, copies or owns application values.
- Nothing forces an architecture on them. Plain QML objects, C++ `QObject`s, item models and Python objects all work.
- When the default isn't right, there is one obvious place to change it (a property, a theme token, or a delegate), never a fork.

**The end user** operates the finished app. What they should experience:

- Every numeric value can be changed three ways: drag it, type it, or step it.
- Nothing changes unless they meant it to. Scrolling past a field, or clicking to focus it, never edits it.
- Everything can be taken back. Esc cancels the edit in progress, and one edit is one undo step.
- Every control answers the same keys and gestures, so what they learn on one field works on all of them.
- The state of a value is visible without clicking: changed from default, driven by something else, mixed across a selection, or invalid.

Typical apps and the layers they would use:

| App | Layout | Controls | Parameters |
|---|---|---|---|
| 3D / DCC tool, game editor | ✓ | ✓ | Own engine, via the adapter |
| Node-based compositor or shader editor | ✓ | ✓ | Own engine, via the adapter |
| Vector or UI design tool | ✓ | ✓ | `Quilt.Params` is enough |
| Audio tool, synth editor | ✓ | ✓ (knobs, sliders) | Usually none |
| CAD, parametric modeller | ✓ | ✓ | Own solver, via the adapter |
| IDE, log viewer, data explorer | ✓ | Some (settings panels) | None |
| A settings dialog in any app | | ✓ | None |

## The scope test

A feature belongs in Quilt only if the answer to all three questions is yes:

1. **Do most panel-based tool apps need it?** A number field, yes. A keyframe editor, no.
2. **Can it be built without knowing what the app's data means?** Showing that a value is driven by an expression, yes. Deciding what `cube.width` refers to, no.
3. **Is it hard enough to get right that doing it once is worth it?** Drag-to-scrub with correct thresholds, undo grouping and cancel, yes. A label, no.

When a feature fails question 2 but users still need it, Quilt provides the **hook** (a signal, an adapter property, a delegate slot) and the app provides the meaning.

## In scope

**Layout (built)**

- Docking, tabs, split lines, maximize, pop-out windows, per-panel restrictions, layout persistence. See [integration.md](integration.md).

**Controls (planned)**

- Value controls: number field (int and float, with slider and stepper modes), text field and text area, checkbox, switch, dropdown, segmented button, slider, vector field, colour field with picker, matrix field, knob, date field.
- The property grid: an inspector container, collapsible sections, and aligned label/value rows.
- Supporting controls, so an app built on Quilt looks like one thing: button, icon button, menu, tooltip, scroll bar, progress bar, busy indicator.
- One interaction grammar shared by all of them (drag, type, step, cancel, reset). See [controls.md](controls.md#the-interaction-grammar).
- Parameter state on every value control: modified, driven, mixed, invalid, read-only.
- Typed input that forgives: arithmetic (`2*pi`, `120/3`), relative edits (`+=10`), unit suffixes, pasted lists.
- Undo hooks: every edit is a transaction the app can turn into one undo step.
- The gestures for linking: typing `=` to enter an expression, a badge that shows what drives a value, copy and paste of references. Quilt forwards these to the app; it does not evaluate anything.
- A generated inspector: give it a list of parameter descriptions and it builds the rows.
- Full keyboard operation and accessibility metadata.

**Style (planned)**

- Theme tokens shared by all layers, with dark and light sets. See [visual-design.md](visual-design.md).
- The small set of glyphs the controls need (chevrons, check, close, link), drawn as paths.

**Parameters (planned, optional)**

- A reference parameter object that implements the adapter described [below](#3-the-parameter-adapter).
- A small, safe expression evaluator: arithmetic, common functions, references to other parameters, dependency tracking, cycle detection.

## Out of scope

These are the app's job, or another library's. Where a hook exists, it is named.

| Not in Quilt | Why | Hook Quilt provides |
|---|---|---|
| The app's data: object model, selection, file formats, serialisation | Fails test 2 | Controls bind to any property; the generated inspector takes any model |
| The undo stack | Every app already has one, each with different rules | `editStarted` / `edited` / `editFinished` |
| A general expression or scripting language | Fails tests 1 and 2: every app's naming, types and evaluation timing differ | `setExpression(text)` on the adapter; the reference engine for simple cases |
| Animation: keyframes, curves, a curve editor | Fails test 1 | The `driven` state shows that something else owns the value |
| Whole editors as panel content: viewport, timeline, node graph, outliner, code editor, table, chart | Each is a project of its own | They go inside a `DockPanel` like any content |
| The app shell: menu structure, toolbars, command palette, shortcut manager, preferences, file dialogs, notifications | Qt already provides these | Restyled `Menu`, `Button` and `ToolTip` so they match |
| A general icon set | Apps have their own | Icon properties take any URL |
| Picking a colour from anywhere on screen | Impossible in pure QML; needs a portal on Wayland | The app can add a button to the picker |
| Touch-first or mobile UI | Tool apps are pointer and keyboard driven; a touch grammar would be a second design | Pen input works as a mouse |
| Qt Widgets apps, other toolkits | Quilt is Qt Quick | None |
| Bundled fonts | Size and licensing; the platform font is the default | A font token |
| Native (C++) code in the core | Breaks "copy one folder, no build step" | See [open decision 6](#open-decisions) |

**Deferred, not rejected.** These pass the scope test but are not needed for a first complete release: object-reference field (drop target plus picker), file path field, list/array editor, range slider, XY pad, gradient editor, right-to-left mirroring. They can be added without changing anything described here.

## How a developer uses Quilt

Adoption comes in levels, from 0 to 5. Each one is useful alone, and each builds on the one before, so a developer adopts only as much as they need.

### Level 0: docking only (today)

```qml
import Quilt

DockArea {
    anchors.fill: parent
    DockPanel { panelId: "viewport";  title: "Viewport";  Viewport { } }
    DockPanel { panelId: "inspector"; title: "Inspector"; area: Dock.Right; MyInspector { } }
}
```

### Level 1: single controls

Use a control anywhere, the way you would use a stock one. The control shows the app's value and reports edits. The app decides what to do with them.

```qml
import Quilt.Controls

NumberField {
    value: shape.width                  // always shows what the app holds
    from: 0; to: 500; suffix: " px"
    onEdited: v => shape.width = v
}
```

### Level 2: the property grid

Rows keep labels and values aligned. Sections collapse. The inspector handles scrolling, the label column, keyboard movement and narrow panels.

```qml
Inspector {
    Section {
        title: "Transform"
        PropertyRow { label: "Position"; VectorField { value: shape.position; onEdited: v => shape.position = v } }
        PropertyRow { label: "Rotation"; NumberField { value: shape.rotation; suffix: "°"; onEdited: v => shape.rotation = v } }
    }
    Section {
        title: "Appearance"
        PropertyRow { label: "Opacity"; NumberField { value: shape.opacity; from: 0; to: 1; onEdited: v => shape.opacity = v } }
        PropertyRow { label: "Visible"; CheckBox { checked: shape.visible; onEdited: v => shape.visible = v } }
    }
}
```

### Level 3: undo

Connect the three transaction signals. A whole drag, however many values it passes through, becomes one undo step.

```qml
NumberField {
    value: shape.width
    onEditStarted: undo.begin("Change width")
    onEdited: v => shape.width = v
    onEditFinished: committed => committed ? undo.commit() : undo.rollback()
}
```

### Level 4: parameter objects

When the app describes each value as an object (most apps with an inspector do), pass that object instead of wiring properties one by one. The control reads the value, default, state and expression from it, and calls its methods. This is where modified markers, mixed values and linking switch on.

```qml
PropertyRow { label: "Width"; NumberField { param: shape.params.width } }
```

### Level 5: a generated inspector

Give the inspector the list of parameters for the current selection. It picks a control for each from its type and groups them into sections. Apps whose objects have many types never write inspector QML by hand.

```qml
Inspector {
    model: selection.parameters         // a JS array, a ListModel, or a C++ item model
    delegates: ({ "curve": curveEditorComponent })   // the app's own control for its own type
}
```

## The three contracts

Everything that makes Quilt fit into "any program" comes down to three small agreements between a control and the app.

### 1. The app owns the value

A Quilt control displays `value`. It does not keep a copy of its own.

- While the user is editing, the control shows the in-progress value and emits `edited(value)`.
- When the edit ends, the control goes back to showing exactly what the app holds.

So if the app clamps, rounds, or refuses an edit, the control shows the real result.

This is a deliberate fix for a problem in stock Qt Quick Controls. A stock `CheckBox { checked: model.flag }` flips itself when clicked. If the model refuses the change, the checkbox and the model now disagree, and nothing brings them back together. (The binding is still installed, but it only re-evaluates when the model changes. This was checked against Qt 6.12.) `examples/sandbox.qml` has to work around this for its panel menu today.

### 2. Edits are transactions

Every value control emits the same three signals:

| Signal | When | Typical use |
|---|---|---|
| `editStarted()` | The first moment a gesture will change the value: a drag passes its threshold, a key is typed | Open an undo step |
| `edited(value)` | Each time the in-progress value changes. With `live: false`, only once, at the end | Write the value to the app |
| `editFinished(committed)` | Exactly once per `editStarted`. `committed` is false when the user cancelled | Close or roll back the undo step |

Rules that keep this dependable:

- **Cancel restores.** On Esc, the control emits `edited(startValue)` before `editFinished(false)`. An app that ignores transactions and only handles `edited` still ends up correct.
- **Instant controls use the same signals.** A checkbox click emits all three at once. The app needs one pattern for everything.
- **An edit lands on the object it started on.** If the selection changes mid-edit, the edit is finished against the original target first. The value never leaks onto the newly selected object.

### 3. The parameter adapter

A *parameter object* is anything with the properties and methods below: a QML `QtObject`, a C++ `QObject`, a Python object. It is duck-typed. There is no base class to inherit from and nothing to register. Only `value` and `setValue` are required. Each optional member switches on one feature.

| Member | Required | Enables |
|---|---|---|
| `value` | Yes | Display. Always the current, evaluated value |
| `setValue(v)` | Yes | Editing |
| `beginEdit()`, `endEdit(committed)` | No | Undo grouping |
| `defaultValue` | No | The modified marker and "Reset to default" |
| `state` | No | `Normal`, `Driven`, `Mixed` or `Invalid` (see [controls.md](controls.md#parameter-states)) |
| `expression` | No | The text shown when the user edits a driven value |
| `setExpression(text)` | No | Typing `=` in the field |
| `message` | No | Tooltip text: what drives the value, or why it is invalid |
| `reference` | No | "Copy reference": the text other expressions use to name this parameter |
| `readOnly` | No | Display without editing |

For a generated inspector (level 5), each parameter also carries a description: `label`, `type`, `group`, and hints such as `from`, `to`, `step`, `suffix`, `options`.

## Linking and expressions

The apps Quilt is for will link values together: "this width is always half of that one". The question is how much of that Quilt should own.

**Linking cannot be implemented once, efficiently, for every app, and Quilt should not try.** What a reference means, when values are re-evaluated, which types exist, and how results are stored all depend on the app. A node compositor evaluates lazily on a worker thread. A parametric modeller runs a constraint solver. A game editor evaluates every frame in C++. No single engine serves all three, and an engine that tried would be the largest and least stable part of Quilt.

What *is* the same in every app is the user interface of a linked value. That part Quilt owns completely. The split is:

| Tier | What it is | Who owns it | Status |
|---|---|---|---|
| **A. Arithmetic in fields** | Typing `2*pi`, `120/3` or `+=10`. Evaluated once on commit; the result is stored as a plain number | Quilt | In scope, always on |
| **B. Linking UI** | A driven value looks driven and can't be scrubbed by accident. Editing it shows the expression, as a spreadsheet cell does. `=` starts an expression. The badge and tooltip show the source. Errors show on the field. References can be copied and pasted | Quilt draws it and forwards it. The app answers through the [adapter](#3-the-parameter-adapter) | In scope |
| **C. Evaluation** | Parsing references, the dependency graph, cycle detection, re-evaluating when a source changes | The app. Or `Quilt.Params`, for apps without an engine | Optional module |
| **D. Everything beyond** | Animation, scripting, solvers, node graphs | The app | Out of scope |

Why this split is cheap to build: tier A already needs a small arithmetic parser. Tier C's reference engine is that same parser, plus named references and a dependency graph. Nothing is built twice.

**What `Quilt.Params` will be.** A reference implementation for apps with a modest number of parameters, such as a design tool, a settings-heavy utility, or a prototype.

- Expressions are arithmetic, comparisons, a fixed list of functions (`min`, `max`, `clamp`, `abs`, `round`, `sqrt`, `sin`, `lerp`, ...), constants, and references to other parameters by name (`cube.width / 2`).
- It has its own parser. User text never reaches JavaScript's `eval` or `Function`, so an expression can't run code.
- When a parameter changes, only the parameters that depend on it are re-evaluated, in dependency order.
- A cycle is rejected when it is entered. The parameter becomes `Invalid` and keeps its last good value.
- It evaluates on the UI thread, in response to edits. It is meant for interactive editing, not for per-frame evaluation of animation channels or large simulations. Apps with those needs already have an engine and should connect it through the adapter.

**What `Quilt.Params` will not be.** A scripting language, a unit system, a solver, or the required way to use the controls. Every control works without it.

## Fitting into any panel-based program

"Any" is a strong word, so here is what it is made of.

| Requirement | How Quilt meets it |
|---|---|
| Any data source | Controls bind to plain properties. The adapter is duck-typed. The generated inspector accepts arrays, `ListModel`s and C++ item models |
| Any language | QML only on Quilt's side; the app can be QML, C++, or Python (PySide, PyQt) |
| Any undo system | Three signals; Quilt keeps no history |
| Any selection model | Multi-selection reaches Quilt only as the `Mixed` state. How values are merged is the app's call |
| Any expression engine | Tier B talks to it through four adapter members |
| Any panel size | Rows restack when a panel is narrow and cap their width when it is wide. Dropdowns open as real windows so they aren't clipped by a small pop-out window |
| Any existing look | Every colour and size is a token. An app can match its own brand by overriding tokens |
| Any existing controls | Quilt controls sit next to stock or third-party controls. Nothing requires converting a whole app |
| Any custom value type | The generated inspector takes app-supplied delegates. `PropertyRow` accepts any item as its control |
| Any platform Qt Quick runs on | Wayland, X11, Windows, macOS, as for docking |

## Constraints

These hold for everything in scope. A feature that can't meet them is redesigned or dropped.

- **Qt 6.8 or newer.** No feature may need a newer Qt unless it degrades cleanly on 6.8.
- **Pure QML and JavaScript.** No build step, no compiled plugin.
- **No dependencies beyond `qtdeclarative`** (Qt Quick, Controls, Templates, Shapes).
- **Built on Qt's templates where they fit.** `QtQuick.Templates` supplies focus handling, keyboard behaviour and accessibility for standard controls. Quilt supplies the visuals and the behaviour described in [controls.md](controls.md). Controls whose value handling differs from Qt's (the number field, above all) are built on the plain `Control` template.
- **Lightweight.** Docking is about 2,700 lines today. The budget for `Quilt.Controls` is 5,000 lines and for `Quilt.Params` 1,200. These are limits to design against, not estimates.
- **Tested headlessly.** Every control ships with QtQuick.Test coverage of the interaction grammar, as docking does today.
- **Stable API.** A released property or signal isn't renamed. New behaviour arrives as a new property with a default that preserves the old behaviour.

## Milestones

Each milestone leaves Quilt in a releasable state.

| | Milestone | Contents | Done when |
|---|---|---|---|
| 1 | **Foundations** | `Quilt.Style` tokens. Dock chrome restyled. The shared control base (states, transactions). `NumberField`, `TextField`, `CheckBox`. `Inspector`, `Section`, `PropertyRow` | The sandbox inspector uses no stock controls, and the grammar tests pass |
| 2 | **Everyday set** | `ComboBox`, `Switch`, `SegmentedButton`, `Slider`, `Button`, `IconButton`, `Menu`, `ToolTip`, `ScrollBar`. Parameter states and the row context menu. Arithmetic in fields | A realistic inspector (30+ rows, every state) can be built from Quilt alone |
| 3 | **Compound controls** | `VectorField`, `ColorField` and its picker, stepper mode, `ProgressBar`, `BusyIndicator` | The design-tool example needs no custom control |
| 4 | **Linking** | The parameter adapter. `=` entry, badges, reference copy and paste. The generated inspector. `Quilt.Params` | An example app links values across two panels, with undo |
| 5 | **Specialised** | `MatrixField`, `Knob`, `DateField`. Light theme. Items from the deferred list by demand | Released as they are ready |

The parameter-state properties are defined in milestone 1, even though nothing drives them until milestone 4. Adding them later would change every control's API.

## Open decisions

Each has a recommendation. Until decided otherwise, the planning documents assume it.

1. **Names that match Qt's.** Should Quilt's checkbox be called `CheckBox`, the same as Qt's?
   *Recommendation: yes, wherever it is the same control with a superset of Qt's API* (`CheckBox`, `Switch`, `ComboBox`, `Slider`, `Button`, `Menu`, `ToolTip`, `ScrollBar`, `ProgressBar`, `BusyIndicator`). New controls get new names (`NumberField`, `VectorField`, `Section`). When a file imports both modules, QML uses the one imported last (checked on Qt 6.12), and `import Quilt.Controls as Q` removes any doubt. Matching names also leaves the door open to registering `Quilt.Controls` as a Qt Quick Controls style later, which would restyle an existing app with no code changes.
2. **Modifier keys.** *Recommendation: Shift is ×10, Ctrl is ×0.1, for dragging, arrow keys and the wheel alike.* Shift for bigger steps is the convention in design tools and browser developer tools. Ctrl is the fine modifier rather than Alt because many Linux window managers take Alt-drag for moving windows, and because Ctrl already means "precise" for Quilt's split lines. This differs from Blender, where Shift is fine and Ctrl snaps. The mapping would live in one place and be overridable.
3. **"2D matrix input control."** This could mean a grid of numbers (a 3×3 transform) or a pad for picking a 2D point. *Recommendation: the grid (`MatrixField`) is in scope; the pad (`XYPad`) is on the deferred list.* Say if you meant the pad.
4. **One theme per application.** Pure QML can't pass a theme down the item tree the way Qt's Material style does. *Recommendation: a singleton.* One app, one theme, switchable at runtime. Docking keeps its per-area `style` override.
5. **Light theme.** *Recommendation: design every token for both themes now; ship dark first and light in milestone 5.*
6. **Endless drag.** Dragging a number is limited by how far the pointer can travel. An inspector docked at the right edge of the screen has little room to drag right. Removing the limit means moving the pointer from code, which pure QML can't do (Qt 6.12 has no QML API for it), and which Wayland only allows through a pointer-lock protocol. *Recommendation: accept the limit for now.* The ×10 modifier and typing cover the gap. Revisit as an optional native add-on outside the core once the controls exist.
7. **Shipping `Quilt.Params` at all.** *Recommendation: yes, but last and optional.* It proves the adapter against a real engine and serves small apps. If it starts to grow past its budget, it becomes a separate repository.
