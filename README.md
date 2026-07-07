# Quilt — Developer Guide

Quilt is a pure-QML template that adds dockable, resizable, and rearrangeable
panels to any Qt Quick application. There is no C++ or Python required. You
connect your backend to panel content the same way you always do — Quilt only
handles the UI shell.

Requires Qt 6.5 or newer (tested against Qt 6.11).

```
Repository layout
├── Quilt/      the QML module — copy this folder into your project
├── example/    runnable demos (main.qml, simple.qml)
└── tests/      headless functional tests for the docking engine
```

---

## Installation

Copy the `Quilt/` folder into your project and put its **parent** directory on
the QML import path. The folder name must stay `Quilt` (case matters on Linux).

**From C++ (CMake projects):**

```cpp
QQmlApplicationEngine engine;
engine.addImportPath("qrc:/");        // or the filesystem path holding Quilt/
```

**With the `qml` runtime (no build step):**

```sh
qml -I /path/to/dir-containing-Quilt your-app.qml
```

Then import it in any QML file:

```qml
import Quilt
```

Try it right now from this repository:

```sh
qml -I . example/simple.qml     # minimal declarative demo
qml -I . example/main.qml       # full seven-panel IDE-style demo
```

---

## Core concepts

Each panel in your app has two parts:

1. A **PanelModel** — a data object describing the panel: identity, title,
   visual style, size constraints, starting dock position, and the Component
   that produces its content. You define this; Quilt reads it.

2. The **Panel** shell — the visual chrome (header bar, background, resize
   handles) that Quilt renders around your content automatically. Because
   panels are created and destroyed as the user rearranges the layout, content
   is supplied as a `Component` via `contentComponent`, not as inline children.

The **DockManager** singleton is the single source of truth: it owns the panel
registry, the layout tree (a binary tree of splits and tabbed slots), the live
drag state, and serialisation. For basic use you never touch it; for scripted
control it exposes the full API (see "Runtime API" below).

The **DockContainer** item renders everything: the docked tree, floating
panels, and the drag-and-drop overlay.

---

## Quick start

```qml
import QtQuick
import QtQuick.Controls
import Quilt

ApplicationWindow {
    visible: true
    width: 1100
    height: 700

    Component {
        id: editorContent
        TextArea { text: "your editor here" }   // any Item works
    }

    PanelModel {
        id: editorPanel
        panelId: "editor"
        title: "Editor"
        dockPosition: DockEnums.Center
        contentComponent: editorContent
    }

    PanelModel {
        id: sidebarPanel
        panelId: "sidebar"
        title: "Sidebar"
        dockPosition: DockEnums.Left
        splitRatio: 0.22          // 22% of the window width
        minWidth: 160
        contentComponent: sidebarContent
    }

    PanelModel {
        id: logPanel
        panelId: "log"
        title: "Log"
        dockPosition: DockEnums.Bottom
        splitRatio: 0.25
        contentComponent: logContent
    }

    DockContainer {
        anchors.fill: parent
        panels: [editorPanel, sidebarPanel, logPanel]
    }
}
```

`DockContainer` registers each model and builds the starting layout from the
panels' `dockPosition` / `splitRatio`, in list order:

- `DockEnums.Center` panels share the central slot; several of them form a
  tab group.
- `DockEnums.Left` / `Right` / `Top` / `Bottom` panels split off that edge of
  the whole layout, so a `Bottom` panel spans the full width beneath
  everything docked before it.

If a saved layout exists from a previous session it is restored instead (see
"Saving and restoring layout").

### Reaching your data from panel content

The content `Component` is instantiated inside the panel; its parent exposes
the model as `panelModel`:

```qml
Component {
    id: shared
    Rectangle {
        property var pm: parent ? parent.panelModel : null
        Text { anchors.centerIn: parent; text: parent.pm ? parent.pm.title : "" }
    }
}
```

Bindings to your application singletons, context properties, or ids in the
enclosing file all work as usual — the content lives in your QML scope.

---

## Panel styles

Each panel independently uses one of three visual styles set via `panelStyle`.

**Isolated** — the panel has a filled background with rounded corners on all
four sides. It looks like a self-contained card.

```qml
panelStyle: DockEnums.Isolated
```

**Connected** — corners at edges shared with neighbouring panels curve
*outward* (convex), creating a grooved seam so adjacent panels read as one
interlocked surface. Looks best when neighbouring panels use it too.

```qml
panelStyle: DockEnums.Connected
```

**Empty** — no background is drawn; your content shows against whatever is
behind the dock area (window background, map, canvas…). Only the header bar is
rendered, tinted with `customColor`.

```qml
panelStyle:  DockEnums.Empty
customColor: "#33ffffff"   // semi-transparent header tint
```

---

## Letting users rearrange panels

No extra code needed. Quilt handles all of the following automatically:

- **Drag to move** — drag a panel by its header. Drop indicators appear on the
  hovered slot (four edge strips + centre), the layout animates to make room,
  and an animated preview shows exactly where the panel will land.
- **Drop to split or stack** — dropping on an edge strip splits that slot;
  dropping on the centre stacks the panel into the slot's tab group.
- **Drag to float** — the ❐ header button undocks the panel so it floats
  above the dock area; dropping over empty space while dragging does the same.
  Floating panels re-dock by dragging their header onto a dock zone, or with
  the ⤓ button (which re-inserts at the panel's `dockPosition`).
- **Close** — the ✕ header button hides the panel
  (`DockManager.showPanel(id)` brings it back).
- **Resize docked panels** — drag the handle between panels, or the shared
  edge of a panel. Resizing respects every affected panel's
  `minWidth` / `minHeight`.
- **Resize floating panels** — drag any edge or corner.
- **Tabs** — stacked panels show a compact tab strip; click to switch.
- **Escape** cancels an in-flight drag and restores the previous layout.

All of this state lives in `DockManager` and the `PanelModel`s in real time.

---

## Building a custom starting layout

For full control, build the layout tree yourself instead of (or before)
relying on `dockPosition`. Slots hold one or more panels (a tab group); splits
divide space between two children at a ratio:

```qml
Component.onCompleted: {
    var files    = DockManager.createSlot(["fileTree"], "fileTree");
    var editors  = DockManager.createSlot(["editorA", "editorB"], "editorA"); // tab group
    var terminal = DockManager.createSlot(["terminal"], "terminal");

    var right = DockManager.createSplit("vertical", 0.75, editors, terminal);
    var root  = DockManager.createSplit("horizontal", 0.20, files, right);
    DockManager.setRoot(root);

    // Register the models afterwards; panels already placed in the tree
    // are left where they are.
    for (var i = 0; i < allModels.length; ++i)
        DockManager.registerPanel(allModels[i]);
}
```

`example/main.qml` builds a seven-panel IDE layout this way.

---

## Saving and restoring layout

`DockManager.saveLayout()` serialises the tree and all floating-panel geometry
to human-readable JSON, persists it via `QtCore` `Settings`, and returns the
string. `DockManager.restoreLayout(json)` rebuilds from any such string;
`DockManager.loadPersisted()` reloads the last persisted one.

`DockContainer` restores the persisted layout automatically on startup; set
`autoRestoreLayout: false` if you manage persistence yourself.

```qml
ToolBar {
    RowLayout {
        Button { text: "Save layout";  onClicked: DockManager.saveLayout() }
        Button { text: "Reset layout"; onClicked: DockManager.restoreLayout(defaultLayoutJson) }
    }
}
```

Restoration is fault-tolerant: panel ids in the JSON with no registered model
are skipped and the surrounding splits collapse, so it never fails on a
missing panel. You can ship a default layout as a string constant.

To auto-save on every change:

```qml
Connections {
    target: DockManager
    function onLayoutChanged() { DockManager.saveLayout() }
}
```

---

## Runtime API (DockManager)

All PanelModel properties are live bindings, and the manager's functions can
be called from anywhere:

```qml
DockManager.floatPanel("editor", 100, 80)   // undock, float at (100, 80)
DockManager.dockPanel("editor")             // re-dock at its dockPosition
DockManager.hidePanel("terminal")           // remove from layout
DockManager.showPanel("terminal")           // bring back
DockManager.dockAtEdge("log", DockEnums.Bottom, 0.3)
DockManager.setActivePanel(slotId, "editorB")

sidebarPanel.panelStyle   = DockEnums.Connected   // restyle on the fly
terminalPanel.minHeight   = 300                   // new constraint
```

| Function | Effect |
|---|---|
| `registerPanel(model)` / `unregisterPanel(id)` | Add/remove a panel; unplaced docked panels are inserted at their `dockPosition` |
| `panelById(id)` | Look up a registered PanelModel |
| `floatPanel(id, x, y)` | Undock and float |
| `dockPanel(id [, slotId, dropTarget, axis])` | Dock a floating panel |
| `hidePanel(id)` / `showPanel(id)` | Remove from / return to the layout |
| `dockAtEdge(id, position, ratio)` | Dock along an edge of the whole layout |
| `setActivePanel(slotId, id)` | Switch the visible tab in a slot |
| `moveSlot(fromSlotId, toSlotId, dropTarget, axis)` | Move a whole tab group |
| `createSlot(ids, activeId)` / `createSplit(axis, ratio, a, b)` / `setRoot(node)` | Build layouts manually |
| `saveLayout()` / `restoreLayout(json)` / `loadPersisted()` | Persistence |

| Signal | When it fires |
|---|---|
| `layoutChanged()` | Any panel moves, resizes, docks, undocks, or switches tab |

---

## Property reference — PanelModel

| Property | Type | Description |
|---|---|---|
| `panelId` | string | Unique ID used for serialisation and lookup. **Required.** |
| `panelType` | string | Developer-defined category label; Quilt does not interpret it |
| `title` | string | Text shown in the panel header bar |
| `tabIconSource` | url | Icon shown in the tab strip; falls back to the title's first two letters |
| `contentComponent` | Component | Produces the panel's content |
| `dockPosition` | int | Starting position: `DockEnums.Left/Right/Top/Bottom/Center` |
| `splitRatio` | real | 0–1, share of the container when auto-placed at an edge |
| `isFloating` | bool | Panel floats freely inside the window (false = docked) |
| `isVisible` | bool | Panel is shown at all |
| `floatX`, `floatY` | real | Position while floating |
| `floatWidth`, `floatHeight` | real | Size while floating |
| `minWidth`, `minHeight` | real | Minimum size, enforced while docked and floating |
| `maxWidth`, `maxHeight` | real | Maximum size (floating resize) |
| `cornerRadius` | real | Base corner radius for Isolated and Connected styles |
| `panelStyle` | int | `DockEnums.Isolated` / `Connected` / `Empty` |
| `customColor` | color | Header tint, used only when `panelStyle` is `Empty` |

---

## Tests

The docking engine has a headless test suite covering placement, tab groups,
split/stack/move/prune, float/dock round trips, hide/show, save/restore, and
resize clamping:

```sh
qml -I . tests/run_tests.qml    # exits 0 when all checks pass
```

---

## Tips

- Give every PanelModel a unique `panelId`. Serialisation depends on it.
- Registration order is layout order for `dockPosition` panels: each edge
  panel splits off the layout built so far.
- Use `Empty` for overlay-ish panels (minimaps, HUDs) that should feel like
  they float above the content rather than sit beside it.
- A single `Connected` panel among `Isolated` neighbours is legal — the convex
  corners simply appear on all shared edges.
- Panels are identified by id everywhere, so you can create PanelModels
  dynamically (e.g. one per open document) and register them at runtime.
