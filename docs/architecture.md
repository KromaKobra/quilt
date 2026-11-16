# How Quilt works

This document explains how Quilt is put together and why. It is for people changing Quilt itself, or anyone who wants to understand its behaviour before relying on it. For using Quilt, see [integration.md](integration.md) (docking) and [controls-guide.md](controls-guide.md) (everything else).

Quilt has four layers. Most of this document is about docking, the largest and oldest. The other three are described in [Theme, controls and parameters](#theme-controls-and-parameters).

```
Quilt.Style  ◄──  Quilt            (docking)
     ▲
     └────────  Quilt.Controls  ◄──  Quilt.Params   (optional)
```

## Goals

1. **Every panel is flexible by default:** resizable, rearrangeable, tabbable, maximizable, and able to pop out into its own window. Restrictions are opt-in per panel.
2. **Multi-window, multi-monitor.** A popped-out window is a full docking host, not a floating box.
3. **Stable.** Moving a panel must never lose its state, and the layout must stay valid under any sequence of operations.
4. **Simple to adopt.** Pure QML, one folder, a small API. The only requirements are Qt Quick, Controls and Shapes.
5. **Works on Wayland.** Wayland forbids reading global coordinates and positioning windows, which rules out the classic "drag the floating window around" approach.
6. **The application owns its data.** Controls show the application's value and hand every edit back. Quilt keeps no copy, no undo history and no object model.

## The pieces

```
           your main window                            a pop-out window (DockWindow)
 ┌───────────────────────────────────────┐       ┌──────────────────────────────┐
 │ DockArea (main)  ── owns ──► DockManager ◄──── │ DockArea (secondary)          │
 │   root: layout tree (plain JS)        │   ▲   │   root: layout tree           │
 │   Repeater ► DockStack (tab group)    │   │   │   Repeater ► DockStack ...    │
 │   SplitHandles (one item, all gaps)   │   │   └──────────────────────────────┘
 │   DropArea, drop preview, dragProxy   │   │
 │   DockPanel × n  (declared here)      │   └── registry of every DockPanel,
 └───────────────────────────────────────┘       every DockArea and pop-out window,
                                                 the drag session, persistence
```

| File | Role |
|---|---|
| `LayoutTree.js` | The layout model: a tree of plain JS objects and pure functions over it (parse, serialize, insert, split, remove, layout, resize, hit-test). No Qt types, so it is unit-tested in isolation. |
| `DockArea.qml` | One docking surface per window. Owns its window's tree, renders it, and handles drops. The first one (with no `manager` set) creates the `DockManager` and becomes the *main* area. |
| `DockManager.qml` | State shared by all areas: panels, areas, pop-out windows, the active panel, the drag session, save/restore and autosave. |
| `DockStack.qml` | Renders one tab group: the tab bar and a content host that panels are parented into. |
| `SplitHandles.qml` | One item per area that handles every split line: hover highlight, cursors, dragging, snapping. |
| `DockPanel.qml` | The developer's panel: configuration plus content (its children). |
| `DockWindow.qml` | Default pop-out window: an `ApplicationWindow` wrapping a secondary `DockArea`. |
| `DockStyle.qml`, `Dock.qml` | Theme values and enums. |

## The layout model

Each area's layout is an **n-ary tree** stored as plain JS objects:

```
split: { id, type: "row" | "column", children: [node, ...], size }
stack: { id, type: "tabs", panels: [panelId, ...], current: panelId, size }
```

`size` is a node's **weight** inside its parent; siblings' weights sum to 1. Ids (`stack12`, `split7`) are generated at runtime and are not saved.

`normalize()` keeps the tree canonical after every operation:

- **No empty stacks.** An empty stack is removed, and its weight goes to the neighbour before it.
- **No splits with a single child.** The split is replaced by that child, which inherits the split's weight.
- **No split directly inside a split of the same type.** A row inside a row is flattened into its parent, with the weights multiplied through.

N-ary rather than binary matters for usability. Three columns are one `row` with three children, so dragging the handle between columns 2 and 3 moves exactly that boundary. A binary tree would nest pairs, and dragging one handle would move whole subtrees.

The **save format** is the same tree in a compact form: `{ row: [...] }`, `{ column: [...] }`, `{ tabs: [...], current }`, plus `size`. `parse()` accepts it, takes a filter that rejects unknown or duplicate panels, and normalises. `serialize()` produces it. A developer's `defaultLayout` uses the same format.

### Operations

| Function | What it does |
|---|---|
| `insertTab(root, stackId, panelId, index)` | Add a panel to a group at an index, or reorder within the group |
| `splitAt(root, stackId, panelId, side)` | Put a panel on one side of a group. If the group's parent already runs in that direction, the panel is inserted as a sibling; otherwise the group is wrapped in a new split. Either way it takes half the group's space. |
| `dockAtEdge(root, panelId, side, fraction)` | Dock along a whole edge, taking the space from the largest child so existing edge panels keep their size |
| `removePanel(root, panelId)` | Remove the panel, then collapse whatever became degenerate |
| `placeByHint(root, panelId, hint)` | Join a group of panels with the same `area` hint, otherwise centre into the largest group, otherwise dock at the hinted edge |
| `applyDrop(root, panelId, target, canShare)` | Remove then insert, for a drop target. Detects no-ops, and never loses the panel even if the target has vanished |
| `separateSolo(root, canShare)` | Move panels that may not share a group into groups of their own (for layouts loaded from JSON) |
| `isolateSegment(root, layout, key)` | Break a handle at its shared cuts (see [Split lines](#split-lines)) |

Every operation is covered by `tests/tst_layout_tree.qml`.

### Panels that can't share a group

`DockPanel.tabbable: false` reaches the tree functions as a `canShare(panelId)` predicate, and `canJoin(stack, panelId, canShare)` is the single rule: a panel may join a stack only if it and every panel already there may share. Everything respects it:

- **Hint placement** skips groups it may not join. A non-tabbable centre panel splits the largest group instead of joining it.
- **Hit-testing** turns the whole stack into split zones (nearest edge) when the dragged panel may not join it.
- **`applyDrop`** turns a "tab" target that breaks the rule into a split, so API calls can't break it either.
- **Restoring and resetting** run `separateSolo` on every parsed tree.

A stack holding a non-tabbable panel renders a plain title bar instead of tabs (`DockStack.solo`).

## Rendering: a flat pass, no recursion

`computeLayout(root, width, height, opts)` walks the tree once and returns:

- a rectangle for every node
- a rectangle for every **handle** (the gap between neighbours), keyed `"splitId:index"`
- the list of stack ids

A `DockArea` renders the stacks with one `Repeater` of `DockStack`s. Each delegate looks up its own rectangle by id. The split handles need no items of their own: a single `SplitHandles` item covers the area and works from the handle rectangles (see [Split lines](#split-lines)). The tree is never mirrored as a tree of items, so there are no recursive Loaders and nothing to keep in sync by hand.

The Repeater's model is a `ListModel` **diff-synced by id** (`DockArea._sync()`):

- **Resizing** the window or a handle recomputes rectangles only. No items are created or destroyed.
- **Structural changes** (drops, closes) keep the delegates of stacks that still exist. Those animate to their new rectangles: `Behavior`s are enabled for one animation period after each change.
- **Sync order is deliberate:** (1) create delegates for new stacks, (2) move panels into their hosts, (3) destroy delegates of stacks that are gone. A panel is never inside a delegate while it is being destroyed.

Because the tree is plain data, bindings can't observe it. `DockArea` bumps a `revision` counter on every change, and bindings read the tree through `_tree(revision)`, which makes the counter their dependency.

## Panels are re-parented, never recreated

A `DockPanel` is an `Item` created once, where the developer declared it. Whenever an area's tree changes, `_placePanels()` walks its stacks and, for each panel:

```js
panel.parent = stackDelegate.contentHost;   // only if it changed
panel.anchors.fill = stackDelegate.contentHost;
panel.visible = (panelId === stack.current);
```

Items can move between windows this way: Qt Quick moves the item into the other window's scene graph. Content keeps all its state: text being edited, scroll positions, running animations, GPU resources (re-uploaded to the new window), and bindings.

A panel that leaves every layout is **parked**: `parent = null`, invisible, with its last group remembered so `open()` can return it there. Its QObject owner never changes (the `DockArea` it was declared in), so parking and moving never destroy anything.

## Sizing

- **Limits.** `limits(node, axis)` returns the min and max extent of a subtree:
  - A stack takes the strictest limits of its panels, plus `tabHeight` vertically.
  - A split sums its children along its own axis, plus the gaps, and intersects them across it.
- **Distribution.** `distribute(weights, mins, maxs, total)` water-fills: proportional to the weights, then it pins children at their limits and redistributes until nothing violates a limit.
  - If the minimums don't fit, everyone shrinks proportionally to their minimum.
  - If every child is pinned at its maximum, the leftover is shared out anyway, so there is never an unpainted hole.
- **Pixel snapping.** Boundaries are rounded to whole pixels on cumulative positions, so there is no blur and no drift.
- **Resizing one handle.** Dragging a handle snapshots the pixel sizes and weights of its two neighbours (`beginResize`). Each move recomputes just those two weights within their combined weight (`applyResize`), clamped so neither crosses its own limits. Other children are untouched.
- **Window minimums.** `DockArea.minimumWidth` and `minimumHeight` are the root's limits; windows bind to them.

### Split lines

Users see lines, not tree handles. In a 2×2 grid the middle vertical line is two handles when the tree is `column(row(A, B), row(C, D))`, but one handle when it is `row(column(A, C), column(B, D))`. Both shapes must behave the same, so resizing works on **lines**:

- **Linking.** `linkedHandles(layout, key)` collects every handle that continues the grabbed one in a straight line: same direction, same position (within 1 px), end to end across at most one crossing gap. A normal drag resizes all of them. `lineRange()` intersects their allowed ranges, so the line moves as one and stops as soon as any panel along it reaches a limit (`applyLineResize`).
- **Ctrl: one segment.** A Ctrl-drag resizes only the handle under the cursor. When that handle is one long handle bordering several panels, `sharedCuts()` finds the positions where both of its neighbours are cut at the same place, and `isolateSegment()` re-shapes the tree so each piece becomes its own handle. For example, `row(column(A, C), column(B, D))` becomes `column(row(A, B), row(C, D))`. Bands between non-shared cuts are kept as nested splits. Geometry is preserved, and the stacks (and so the panels) are untouched.
- **Snapping.** At the start of a drag, `snapCandidates()` lists the handles that continue the line end to end but sit at another position. While Ctrl is up, the line jumps onto any candidate within `style.snapDistance`. Once aligned, the two are linked by the rule above.
- **One persistent item.** `SplitHandles` covers the whole area with a `containmentMask` that accepts points only over a handle, so every other press reaches the panels underneath. One `HoverHandler` drives the cursor and highlight, and one `DragHandler` drives the resizing. A per-handle item would be destroyed by `isolateSegment()` re-shaping the tree at the start of its own drag, which is why there is a single item.
- **Drag distance.** The item computes the drag distance itself (pointer minus press position). `DragHandler.activeTranslation` skips the move that crosses the drag threshold.

## Drag and drop

### Why platform drag-and-drop

The obvious design moves the floating panel window under the cursor and hit-tests other windows by global coordinates. Wayland allows neither. The only thing that crosses windows there is the compositor's drag-and-drop protocol, which Qt exposes as `QDrag` and QML exposes as `Drag.dragType: Drag.Automatic`. KDDockWidgets uses the same approach on Wayland.

Quilt uses that one mechanism for **every** panel drag, on every platform. Rearranging within a window, moving between windows, and tearing off all share a single code path.

### The sequence

1. **Start.** A tab's `DragHandler` activates past the drag threshold. The stack grabs a scaled snapshot of the panel (at most 240×180; KWin rejects drag images over 250×250) for the drag image. It then calls `DockArea.startDrag()`, which records the panel in `manager.dragPanel` and sets `Drag.active = true` on the area's **`dragProxy`**.

   `Drag.Automatic` runs the platform drag loop. The call returns only when the drag is over, while events keep flowing in a nested event loop. The proxy lives as long as the area, so no layout change can destroy the object that owns a running drag.
2. **Hover.** Each area's `DropArea` accepts the drag only if `manager.dragPanel` is set and the drag source belongs to this manager. Only one system drag can run at a time, so this also rejects a second instance of the app.

   On every move, `dragMoved(x, y)` calls `hitTest()`. The result is a target, which the area shows as an animated preview rectangle (or an insertion marker in a tab bar). Targets that would change nothing (a panel onto its own lone tab group), or that are not allowed (a non-floatable panel over a pop-out area), are shown as "no target".
3. **Drop.** `dropped()` records `{ area, target }` in the manager and accepts the drop.
4. **Finish.** The proxy's `dragFinished` calls `manager.finishDrag(action)`. The layout is changed only now, from the event loop via `Qt.callLater`, never inside the drag loop.

### Hit-testing

`hitTest()` checks these in order:

1. **Edge markers.** Four squares centred on the area's edges dock along the whole side.
2. **A stack's tab bar.** Insert at the nearest tab boundary.
3. **The outer 25% of a stack's content.** Split on that side; the preview is the half the panel will take.
4. **Anything else inside a stack.** Add as a tab.
5. **Over a gap between panels.** Returns `null`; the area keeps the previous target, so the preview doesn't flicker.

Over a stack the dragged panel may not join (one of them isn't `tabbable`), steps 2 and 4 don't apply: the whole stack splits at its nearest edge.

### Tearing off versus cancelling

When a drop lands outside every window, no window accepts it and the platform reports `IgnoreAction`. When the user presses Esc, the platform reports exactly the same thing. To tell them apart, the manager remembers where the cursor was last seen over any of its windows:

- Each `DockArea` reports drag positions.
- A transparent "catch-all" `DropArea` sits beneath everything in each window. It covers toolbars and menus, and treats a drop there as an explicit cancel.

If a drop has no target and the last position was within 48 px of a window border, the cursor left the window, so Quilt **tears the panel off** into a new window. Otherwise the drag is **cancelled**. A very fast flick out of the window can be misread as a cancel. That fails safe: nothing happens, and the user can drag again or use the pop-out button.

### Known Qt quirk

After a platform drag the pointer handler that started it may never see the button release, and can stay "active". Quilt toggles the tab drag handlers off and on after every drag.

### Debugging

`QT_LOGGING_RULES="quilt.drag.debug=true"` logs each drag's start, the accepted target, and the final decision (move, tear off or cancel), with the last-seen position.

## Pop-out windows

`DockManager.createWindow()` instantiates `DockArea.windowComponent`, or by default `DockWindow.qml`. The default is loaded by URL rather than referenced as a type, because `DockArea` → `DockWindow` → `DockArea` would be a cyclic type dependency.

- The window's `DockArea` gets the shared `manager`, so it registers as a secondary area.
- **Auto-close.** When a secondary area's tree becomes empty, the manager closes and destroys its window on the next event-loop turn.
- **User closes the window.** By `windowClosePolicy`, its panels are either re-placed in the main window by their hints, or closed. Non-closable panels always return.
- **Main window closes.** The manager saves the layout if autosave is on, then destroys every pop-out, so the application can quit.
- **Look.** Pop-outs copy the main window's palette and font, so stock Controls look identical.
- **Placement.**
  - On X11, Windows and macOS, a pop-out opens near the panel's previous position, and saved positions are restored.
  - On Wayland, the compositor decides. Quilt doesn't try to position windows there, and doesn't call `requestActivate()`.

## Persistence

`saveLayout()` produces:

```js
{ version: 1, main: <tree>, windows: [{ x, y, width, height, layout: <tree> }], closed: [panelId, ...] }
```

`restoreLayout()` works in this order:

1. Closes all pop-outs.
2. Parses each tree, **claiming** each panel at most once. Unknown ids are dropped, and non-floatable panels are refused in windows.
3. Creates windows for non-empty window trees.
4. Places every panel that was neither claimed nor listed in `closed` (one new since the layout was saved) by its hint.
5. Installs the main tree.

It returns `false`, and leaves everything untouched, for unparseable input or an unknown version.

**Autosave** (`autoSaveKey`) stores the JSON with QtCore `Settings` in category `QuiltLayouts`:

- It saves 500 ms after the last change, when the main window closes, and on `aboutToQuit`.
- The `Settings` object is only created when autosave is used, because QSettings needs an organization name and warns without one.

## Active panel

`manager.activePanel` is the panel the user last pressed in, switched to, dropped, or opened. A transparent item over each stack's content holds a `PointHandler`, which only takes *passive* grabs. It observes presses without stealing them (a `TapHandler` there would swallow clicks meant for the content). The active panel's tab shows an accent line.

## Theme, controls and parameters

### The theme

`Quilt/Style/Theme.qml` is a singleton `QtObject` of tokens. Each colour is a binding on `dark` (`surface: dark ? "#1a1c20" : "#fafafb"`), so switching the theme is one assignment and everything bound to a token repaints. An application that assigns a token replaces that binding; one that wants to keep following `dark` overrides it with a `Binding` instead.

A singleton, because pure QML can't pass a theme down the item tree the way Qt's Material style does through attached properties. The cost is one theme per application. Docking keeps its own per-area `DockStyle`, whose defaults are bindings to the theme, so the two always match unless the application decides otherwise.

The pieces that docking and controls both draw with live in the same module:

- **`Icon`** draws a path from one shared table (`Icons.js`) with a `Shape` and the curve renderer. The glyphs are 1.3 px strokes on a 12-unit grid, so they stay sharp at any scale.
- **`Tip`** is a `Loader` that creates a `ToolTip` only while it is wanted. A tooltip is a popup, and an inspector of 300 rows would otherwise carry 300 of them. "Warm" timing (no delay when another tooltip just closed) is one timestamp on the theme.
- **`PopupBackground`** is the surface of anything that floats. Its shadow, when `Theme.shadow` is set, is four widening rounded rectangles behind it: no shader effects, and nothing to clip when the popup is a window of its own.
- **`Rebind`** re-evaluates a property's binding (see below). Checkable `Action`s, `MenuItem`s and buttons use it after every click.

### The value plumbing: ValueEdit

Every value control contains one `ValueEdit` (`Controls/ValueEdit.qml`, internal). It is the only place that knows how values move, so every control behaves the same way.

**Showing the application's value.** A stock control flips its own `checked` when clicked, which leaves a binding like `checked: document.visible` installed but not re-evaluated. If the application refused the change, control and model disagree until the model changes for some other reason. Assigning from JavaScript is worse: it destroys the binding.

`ValueEdit` writes the control's value property through a `Binding` element with `restoreMode: Binding.RestoreBinding`:

1. `when = true` with the new value: the control shows the edit at once. The application's binding is set aside, not destroyed.
2. The control emits `edited(value)`, and the application writes its model (or doesn't).
3. `when = false`: Qt puts the application's binding back and evaluates it, so the control shows what the model now holds.

A control whose value has no binding keeps what was written, so a control nobody listens to still works like a stock one. `Rebind` is the same mechanism, packaged for any property. This relies on `RestoreBinding` re-evaluating the restored binding, checked on Qt 6.12 and covered by the tests ("refused edit snaps back" in each control's suite).

**Parameter objects.** With `param` set, a second `Binding` makes the control's value follow `param.value`, and an edit calls `param.setValue()` instead of writing the property. The state (`Driven`, `Mixed`, …), `expression`, `message`, `defaultValue` and `readOnly` are read from the parameter when it has them and from the control's own properties when it doesn't, member by member. This is the whole of the "duck-typed adapter": a few `!== undefined` checks.

**Transactions.** `begin()`, `set(v)` and `end(commit)` bracket a gesture; `instant(v)` is all three for a click. `begin` remembers the start value; `end(false)` writes it back (emitting `edited(startValue)`) before `editFinished(false)`. Key and wheel steps call `step(v)`, which keeps one transaction open until 600 ms pass without a step or the control loses focus. With `live: false`, `set` stores a preview that the control draws, and only `end` reports it.

**The original target.** `begin()` remembers the parameter it opened on, and every write and the closing `endEdit` go to that one. If the control's `param` is replaced while a transaction is open (the selection changed in the middle of a drag), the transaction is finished on the original, and the rest of the gesture is ignored until the control ends it.

Typed text isn't a transaction until it is applied, so it needs one more piece. While a field is being typed into, `PressOutside` puts an item over the whole window whose `PointHandler` observes every press. Pointer handlers on the topmost item see a press first and a passive one doesn't take it, so the field applies its text before whatever was pressed (a viewport changing the selection) acts on it.

**Temporary text.** Editing a mixed or driven value starts from an empty field or from the expression text, not from the number. `show(v)` displays such a value without reporting an edit, and `restore()` goes back to the model's value.

### Controls

Controls whose API matches Qt's are built on `QtQuick.Templates` (`CheckBox`, `Switch`, `ComboBox`, `TextField`, `Button`, `Menu`, `ScrollBar`, …), which supplies focus handling, keyboard behaviour and accessibility. Quilt supplies the visuals and routes every change through `ValueEdit`. `CheckBox`, for instance, sets `nextCheckState` to return the current state, so the template never flips the box by itself.

Controls whose value handling differs from Qt's are built on the plain `T.Control`: `NumberField`, `Slider`, `Knob`, `SegmentedButton`, `VectorField`, `ColorField`, `DateField`, `TextArea`.

**`NumberField`** draws the value as text and swaps in a `TextInput` only while typing. Dragging accumulates travel in value units from the start of the drag, then quantises: the value lands on multiples of the step counted from zero, and `toPrecision(12)` removes floating-point fuzz such as `0.30000000000000004`. When the value hits a limit the accumulated travel is clamped too, so reversing direction takes effect at once ("no dead travel"). A press only becomes a drag after `Theme.dragThreshold` pixels, and only if it moved more sideways than vertically. The wheel's `angleDelta` is accumulated into whole notches. `VectorField` is a row of `NumberField`s sharing one transaction; `ColorField` and `Knob` embed one for typing.

**Typed input** goes through `Expr.js`: a tokenizer, a precedence-climbing parser that produces nested arrays, and an evaluator. It never calls `eval` or `Function`, and looks names up only in the tables' own properties, so `constructor` or `toString` can't reach JavaScript's built-ins. The same parser serves arithmetic in fields and expressions in `Quilt.Params`.

**Popups** (dropdown lists, the colour picker, the calendar, menus) are created when first opened. The picker and the calendar are destroyed when they close, so a closed one costs nothing. All of them use `Theme.popupType`: `Popup.Item` by default, `Popup.Window` to let them leave a small window where the platform supports it.

### The property grid

`Inspector` is an `Item` holding a `Flickable` (not interactive: a drag belongs to the controls) around a `Column`. A `WheelHandler` scrolls it, with a short glide for notched wheels and none for trackpads. A control that takes the wheel (a focused number field) gets it first.

**Finding each other.** A `PropertyRow` finds its `Section` and `Inspector` by walking up its parents and looking for marker properties (`isQuiltInspector`, `isQuiltSection`). Nothing is registered, so rows work inside `Repeater`s, `Loader`s and the application's own items, and a row used alone simply has no inspector. The label column width is a property of the inspector that every row reads.

**Counts instead of scans.** A collapsed section shows a dot when a row inside is modified, and a filtered section hides when none of its rows match. Each row adds or removes itself from its section's two counts when its own state changes, so neither needs a scan of the rows.

**Generated rows.** With a `model`, the inspector:

1. Turns the model into an array of parameter objects. A JS array or a list of QObjects is used as is; an item model goes through an `Instantiator` of small adapter objects, one per row, that present the roles as parameter members.
2. Computes a *shape*: for each parameter, its group and the kind of control its `type` asks for.
3. Builds rows from a layout (groups, then kinds) that is only replaced when its JSON signature changes.
4. Each row looks its parameter up by group and index, and copies the parameter's hints onto its control by name.

Selecting another object of the same kind produces the same signature, so the rows stay: only the parameter each row points at changes. The scroll position, open sections and label width survive, and nothing is created. A hint that disappears can't be "un-set" on a control, so a row whose hints lose a name reloads its control.

### The parameter engine

`Quilt/Params/ParameterSet.qml` keeps three tables, all created with `Object.create(null)` so that no inherited name (`toString`) can be mistaken for a parameter:

- `_byName`: name → `Parameter`.
- `_parsed`: for each driven parameter, its parsed expression and the names it reads.
- `_readers`: name → the parameters whose expressions read it. Rebuilt lazily, only after an expression or the set of parameters changed.

**Resolving names.** A name in `cube.height`'s expression is looked up first next to it (`cube.` + name), then from the top. The longest prefix that names a parameter wins, and the rest is a property path, so `cube.position.x` reads one component of a vector.

**Propagation.** When a value changes, a depth-first walk over `_readers` from that parameter collects everything downstream in post-order. Evaluating that list backwards visits every parameter after all the parameters it reads, and each one once, however the dependencies fan out and join.

**Cycles** are checked when an expression is set, by walking what it reads. A parameter that closes a cycle is marked `Invalid` with "Circular reference" and keeps its last good value. After every expression change, invalid parameters are tried again, so breaking the cycle anywhere heals it.

**Undo** needs nothing special: `save()` returns every value and expression as plain, JSON-safe data (colours and vectors as their parts), and `restore()` puts it back and re-evaluates everything. `editStarted` and `editFinished` come from the controls' transactions.

`MergedParameter` presents several parameters as one: `Mixed` when their values differ, edits sent to all of them, and a single `beginEdit`/`endEdit` pair so a multi-object edit is one undo step.

## Design decisions and trade-offs

| Decision | Why | Cost |
|---|---|---|
| Pure QML | Drop-in, no build step, run directly with `qml` | Some Qt internals (exact cursor position, native window moves) are out of reach |
| Platform DnD for all drags | The only cross-window mechanism on Wayland; one code path | Drag image is a snapshot, not a live item; tear-off vs Esc needs a heuristic |
| Floating = real OS windows only | One concept; multi-monitor by construction | No in-window floating overlays |
| Weights, not pixels | Layouts scale with the window; JSON is resolution-independent | Side panels grow with the window unless given a maximum size |
| Re-parenting panels | Content state always survives | Panels must not manage their own `visible`/geometry |
| Controls write their own value, then restore the application's binding | A control nobody listens to works like a stock one; a refused or corrected edit shows what the model really holds | Relies on `Binding.RestoreBinding` re-evaluating the restored binding |
| A duck-typed parameter adapter | Any object (QML, C++, Python) works; nothing to inherit or register | No compile-time check that an object has the right members |
| One theme singleton | Pure QML can't inherit a theme down the item tree | One theme per application |
| No shader effects | Cheap; popups that are windows need no transparent margins | The light theme's shadow is an approximation |
| Quilt's own expression parser | User text never runs as code | A small language; applications that need more bring their own engine through the adapter |
