# Integrating Quilt into your QML application

This guide takes you from an empty window to a fully dockable tool UI. A complete API reference is at the end.

- [Requirements](#requirements)
- [1. Add Quilt to your project](#1-add-quilt-to-your-project)
- [2. Your first dock layout](#2-your-first-dock-layout)
- [3. Declaring panels](#3-declaring-panels)
- [4. The starting layout](#4-the-starting-layout)
- [5. Restricting panels](#5-restricting-panels)
- [6. Controlling panels from code](#6-controlling-panels-from-code)
- [7. Saving and restoring layouts](#7-saving-and-restoring-layouts)
- [8. Pop-out windows](#8-pop-out-windows)
- [9. Panels created at runtime](#9-panels-created-at-runtime)
- [10. Styling](#10-styling)
- [11. Connecting panels to your application](#11-connecting-panels-to-your-application)
- [12. Tips and gotchas](#12-tips-and-gotchas)
- [API reference](#api-reference)

## Requirements

- Qt 6.8 or newer, with the Qt Quick, Qt Quick Controls and Qt Quick Shapes modules (all part of `qtdeclarative`).
- No C++ is required. Quilt is a plain QML module.

## 1. Add Quilt to your project

Copy the `Quilt/` folder into your project. The folder name must stay `Quilt`, because it is the module name. Then pick one of the two ways below to make it importable.

### Option A: import path (no build step)

Put the **parent** directory of `Quilt/` on the QML import path.

With the `qml` runtime:

```sh
qml6 -I path/to/dir-containing-Quilt main.qml
```

From C++:

```cpp
QQmlApplicationEngine engine;
engine.addImportPath(QStringLiteral("path/to/dir-containing-Quilt"));   // or a qrc:/ path
engine.load(QUrl::fromLocalFile("main.qml"));
```

### Option B: compiled QML module (CMake)

`Quilt/CMakeLists.txt` builds the module with `qt_add_qml_module`. QML is precompiled by qmlcachegen and the files are embedded in your binary.

```cmake
find_package(Qt6 6.8 REQUIRED COMPONENTS Quick QuickControls2)
qt_standard_project_setup(REQUIRES 6.8)

add_subdirectory(third_party/Quilt)          # wherever you copied it

qt_add_executable(myapp main.cpp)
qt_add_qml_module(myapp URI MyApp QML_FILES Main.qml)
target_link_libraries(myapp PRIVATE Qt6::Quick quiltplugin)
```

```cpp
#include <QtQml/qqmlextensionplugin.h>
Q_IMPORT_QML_PLUGIN(QuiltPlugin)             // Quilt is a static module

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName("MyCompany");     // needed for autosave (QSettings)
    app.setApplicationName("MyApp");
    QQmlApplicationEngine engine;
    engine.loadFromModule("MyApp", "Main");
    return app.exec();
}
```

`examples/cpp-host/` is a complete, buildable version of this setup.

## 2. Your first dock layout

```qml
import QtQuick
import QtQuick.Controls
import Quilt

ApplicationWindow {
    width: 1280; height: 800
    minimumWidth: dock.minimumWidth          // never smaller than the panels allow
    minimumHeight: dock.minimumHeight
    visible: true

    DockArea {
        id: dock
        anchors.fill: parent

        DockPanel {
            panelId: "viewport"
            title: "Viewport"
            MyViewport { anchors.fill: parent }
        }
        DockPanel {
            panelId: "inspector"
            title: "Inspector"
            area: Dock.Right
            MyInspector { anchors.fill: parent }
        }
    }
}
```

The `DockArea` in your main window is the **main area**. It owns the panels and the configuration. Each pop-out window gets its own secondary `DockArea` that shares the main area's state. You never create those yourself.

Everything else is automatic:

- dragging tabs to rearrange
- splitting and tabbing
- resize handles
- pop-out windows
- maximize and restore
- tab context menus

## 3. Declaring panels

A `DockPanel` is an `Item`. Whatever you put inside it is the panel's content, and should normally use `anchors.fill: parent`.

```qml
DockPanel {
    panelId: "timeline"          // required, unique and stable (saved layouts use it)
    title: "Timeline"            // tab text; defaults to panelId
    icon: "qrc:/icons/clock.svg" // optional tab icon

    TimelineView { anchors.fill: parent }
}
```

Only `DockPanel`s go directly inside a `DockArea`.

Quilt creates each panel once and **moves** it from place to place by changing its parent. It never destroys and recreates a panel. Your content keeps its state through every drag, tab switch, pop-out, and close/reopen.

Quilt manages each panel's `visible`, `parent` and geometry. Don't bind or set those yourself. Use `isOpen`, `isCurrent` and the methods below instead.

## 4. The starting layout

The first time the app runs (or after `resetLayout()`), the layout is built from two sources.

### Placement hints on each panel

| Property | Meaning |
|---|---|
| `area` | `Dock.Center` (default), `Dock.Left`, `Dock.Right`, `Dock.Top` or `Dock.Bottom` |
| `areaSize` | The fraction of the window it takes along that edge (default `0.25`) |
| `openOnStart` | `false` keeps the panel closed until it is opened |

The hints are applied with these rules:

- **Same area, same tab group.** All `Center` panels share one tab group. So do all `Left` panels, and so on.
- **Centre first.** Edge panels then dock around the centre in declaration order. Each edge panel spans the full height or width of everything placed before it.

  For example, with `Left`, `Right`, `Bottom`, the bottom panel spans the full window width below the other three. Declare `Bottom` first if you want the side panels to run full height instead.
- **Reopening.** When a closed panel is reopened, it goes back to the tab group it was closed from if that group still exists. Otherwise its hint is used.

### An explicit `defaultLayout`

Use this for anything the hints can't express. It is the same JSON format that `saveLayout()` produces.

```qml
DockArea {
    defaultLayout: ({
        row: [
            { tabs: ["outliner", "assets"], size: 0.2 },
            { column: [
                { tabs: ["viewport", "uv"], current: "viewport" },
                { tabs: ["timeline"], size: 0.25 }
            ] },
            { tabs: ["inspector"], size: 0.22 }
        ]
    })
    // ... DockPanels ...
}
```

The node types are:

- `{ row: [...] }` lays its children out left to right.
- `{ column: [...] }` lays its children out top to bottom.
- `{ tabs: ["id", ...], current: "id" }` is a tab group.

Any child can carry `size`, its fraction of the parent. Children without one share whatever is left.

Panels missing from `defaultLayout` are still placed by their hints, unless `openOnStart: false`.

## 5. Restricting panels

Everything is allowed by default. Restrict only what you need:

```qml
DockPanel {
    panelId: "tools"
    movable: false        // can't be dragged; other panels can still dock around it
    floatable: false      // never lives in a pop-out window
    closable: false       // no close button; closing its pop-out window brings it home
    minimumWidth: 56      // the defaults are 120 x 80
    maximumWidth: 56      // min == max gives a fixed width
}
```

| Property | Default | Effect |
|---|---|---|
| `movable` | `true` | `false`: the tab can't be dragged |
| `floatable` | `true` | `false`: no pop-out button. Pop-out windows refuse it, and dropping it outside the window does nothing |
| `closable` | `true` | `false`: no close button or menu item |
| `minimumWidth`, `minimumHeight` | `120`, `80` | Resizing stops here. Window minimums account for it |
| `maximumWidth`, `maximumHeight` | infinite | Resizing stops here. Set min == max for a fixed size |

Size limits apply to the panel's content area; the tab bar comes on top of that. A tab group uses the strictest limits of its panels.

To disable pop-out windows for the whole app, set `DockArea.allowPopOut: false` on the main area.

## 6. Controlling panels from code

Both the panels and the main area have methods:

```qml
dock.openPanel("timeline")        // open (if closed), make it the visible tab, raise its window
dock.closePanel("timeline")
dock.popOut("inspector")          // into its own window; returns that window's DockArea
dock.toggleMaximized("viewport")

timelinePanel.open()              // the same, called on a DockPanel
timelinePanel.close()
timelinePanel.popOut()
timelinePanel.raise()
```

A typical "Window" menu that toggles panels:

```qml
Menu {
    id: windowMenu
    title: "Window"
    Instantiator {
        model: dock.manager ? dock.manager.panelOrder : []
        delegate: MenuItem {
            required property string modelData
            readonly property var panel: dock.panel(modelData)
            text: panel.title
            checkable: true
            checked: panel.isOpen
            onTriggered: {
                if (panel.isOpen) panel.close(); else panel.open();
                checked = Qt.binding(() => panel.isOpen);   // keep following the panel
            }
        }
        onObjectAdded: (i, o) => windowMenu.insertItem(i, o)
        onObjectRemoved: (i, o) => windowMenu.removeItem(o)
    }
}
```

`dock.activePanel` is the panel the user last clicked in or switched to. Use it for shortcuts that act on "the current panel":

```qml
Shortcut {
    sequence: "Ctrl+Space"
    context: Qt.ApplicationShortcut           // also works inside pop-out windows
    onActivated: if (dock.activePanel) dock.toggleMaximized(dock.activePanel.panelId)
}
```

## 7. Saving and restoring layouts

**Autosave** is one property:

```qml
DockArea { autoSaveKey: "main" }
```

The layout, including pop-out windows, closed panels, sizes and current tabs, is written with QtCore `Settings` shortly after each change and when the main window closes. It is restored on the next start.

QSettings needs your application's organization name (or domain) and application name. The `qml` runtime sets these. In C++, set `QGuiApplication::setOrganizationName()` and `setApplicationName()`, or set `Qt.application.organization` and `Qt.application.name` from QML before the `DockArea` is created.

**Manual control.** `saveLayout()` returns a plain JS object you can `JSON.stringify` and store anywhere. `restoreLayout(objOrJsonString)` brings it back.

```qml
Button { text: "Save";  onClicked: myStore.layout = JSON.stringify(dock.saveLayout()) }
Button { text: "Load";  onClicked: dock.restoreLayout(myStore.layout) }
Button { text: "Reset"; onClicked: dock.resetLayout() }   // back to defaultLayout + hints
```

A saved layout looks like this:

```json
{
  "version": 1,
  "main": { "column": [
      { "row": [ { "tabs": ["outliner"], "current": "outliner", "size": 0.2 },
                 { "tabs": ["viewport"], "current": "viewport", "size": 0.8 } ], "size": 0.75 },
      { "tabs": ["timeline"], "current": "timeline", "size": 0.25 } ] },
  "windows": [ { "x": 1940, "y": 80, "width": 640, "height": 900,
                 "layout": { "tabs": ["inspector"], "current": "inspector" } } ],
  "closed": ["console"]
}
```

Restoring is forgiving, so layouts survive app updates:

- Unknown panel ids are skipped, and their empty groups collapse.
- Panels that exist now but aren't in the saved layout are placed by their hints. This covers panels added in a newer version of your app.
- Panels listed in `closed` stay closed.
- A non-floatable panel is never restored into a pop-out window.
- `restoreLayout` returns `false`, and changes nothing, for invalid JSON or an unknown `version`.

## 8. Pop-out windows

Users pop a panel out by dragging its tab outside the window, with the pop-out button, or from the tab's context menu.

- The new window is a full dock host, so other panels can be docked into it.
- When its last panel leaves, the window closes itself.
- When the user closes it, its panels go back to the main window. Set `windowClosePolicy: Dock.ClosePanels` to close them instead. Non-closable panels always go back.

Pop-out windows copy the main window's `palette` and `font`, so stock Controls look the same. To give them your app's own chrome (a menu bar, a toolbar, a different title), supply a `windowComponent` whose root is a `DockWindow`:

```qml
DockArea {
    windowComponent: Component {
        DockWindow {
            id: popout
            title: popout.dockArea.title + " — MyApp"
            menuBar: MyMenuBar { }
            header: MyToolBar { }
        }
    }
}
```

`DockWindow` is an `ApplicationWindow`, so `header`, `footer`, `menuBar`, `Material.theme` and similar all work. If you build a window from scratch instead, it must have a `required property var manager` and a `dockArea` property pointing at a `DockArea { manager: <that manager> }` that fills it.

**Platform note.** On Wayland, applications can't choose where windows appear. The compositor places pop-outs, and Hyprland and other tiling compositors tile them. Saved window positions are restored on X11, Windows and macOS, while saved sizes are restored everywhere.

## 9. Panels created at runtime

Panels can be created on the fly, for example one per open document:

```qml
Component {
    id: documentPanel
    DockPanel {
        property url file
        title: file.toString().split("/").pop()
        Editor { anchors.fill: parent; source: parent.file }
    }
}

function openDocument(file) {
    const id = "doc:" + file;
    if (dock.panel(id)) { dock.openPanel(id); return; }
    const p = documentPanel.createObject(dock, { panelId: id, file: file });
    dock.addPanel(p);                     // opens it (Center group) unless openOnStart is false
}

function forgetDocument(id) {
    const p = dock.panel(id);
    dock.removePanel(id);                 // closes and unregisters; the object is yours
    p.destroy();
}
```

Create dynamic panels with the `DockArea` as their parent (`createObject(dock, ...)`) so they live as long as it does.

A saved layout may mention dynamic panels. Recreate and `addPanel` them before calling `restoreLayout`, or their places are dropped.

## 10. Styling

All visuals come from the main area's `style`, a `DockStyle`. Override individual values, or assign a whole new `DockStyle { }`:

```qml
DockArea {
    style.accent: "#ff8a3d"
    style.gap: 0              // seamless panels
    style.radius: 0
    style.tabHeight: 28
}
```

| Property | Default | Used for |
|---|---|---|
| `background` | `#111317` | Behind the panels (visible in the gaps). The area paints it |
| `panel` | `#1e2127` | Default `DockPanel.background` |
| `tabBar`, `tabHover` | `#16181c`, `#23262d` | Tab bar and hovered tabs |
| `text`, `textDim` | `#d7dae0`, `#7f8591` | Current and other tab titles, icons |
| `accent` | `#4c8dff` | Active tab marker, drop preview, handles |
| `dropFill` | accent at 22% | Fill of the drop preview |
| `gap` | `4` | Space between panels (`0` for a seamless look) |
| `radius` | `6` | Panel corner radius |
| `tabHeight` | `30` | Tab bar height |
| `handleGrabSize` | `8` | Grab width of split handles (even when `gap` is 0) |
| `dropIndicatorSize` | `36` | The "dock along the whole edge" markers |
| `fontPixelSize` | `12` | Tab titles |
| `animationDuration` | `160` | Layout animations (`0` disables them) |

Set `background: "transparent"` on a panel to let whatever is behind it show through. If you also want to see *through the dock area*, set `style.background: "transparent"` too.

## 11. Connecting panels to your application

Panel content is ordinary QML in your file's scope. Bindings to ids, singletons, context properties and C++ models all work as usual, and keep working when the panel moves between windows. Quilt only owns the shell around the content.

A few things change when content moves to another window, because it now belongs to that window:

- `Window.window`, `Window.active` and similar attached properties update to the new window.
- A `Popup` or `Dialog` declared inside a panel opens in whichever window the panel is in. That is usually what you want.
- `palette`, `font` and Controls style attached properties (such as `Material.theme`) are inherited from the window. Pop-outs copy the palette and font. Set anything else on a custom `DockWindow`.
- Keyboard focus is not carried across windows.

Heavy content can be made lazy with a `Loader`:

```qml
DockPanel {
    id: graph
    panelId: "graph"
    Loader { anchors.fill: parent; active: graph.isOpen; sourceComponent: NodeGraph { } }
}
```

## 12. Tips and gotchas

- **Keep `panelId`s stable** across app versions; saved layouts depend on them.
- **Use one main `DockArea` per application.** Pop-out windows provide the rest.
- **Bind your window's minimum size** to `dock.minimumWidth` and `dock.minimumHeight`; otherwise the window can shrink below what the panels need.
- **On a tiling compositor** such as Hyprland, add a window rule if you'd rather have pop-outs float. They share your application's app-id/class.
- **Don't set `visible` or the geometry on a `DockPanel`.** Quilt controls those.
- **Debugging a drag?** Run with `QT_LOGGING_RULES="quilt.drag.debug=true"` (see [testing.md](testing.md#debugging-drags)).

## API reference

### DockArea (Item)

Configuration. Set these on the main area:

| Property | Type | Default | |
|---|---|---|---|
| *(default)* `panels` | `list<DockPanel>` | | The panels |
| `defaultLayout` | `var` | `null` | Starting layout (JSON tree, see section 4) |
| `style` | `DockStyle` | `DockStyle {}` | Colours and metrics |
| `windowComponent` | `Component` | `null` (uses `DockWindow`) | Creates pop-out windows |
| `allowPopOut` | `bool` | `true` | Pop-out windows allowed at all |
| `windowClosePolicy` | `int` | `Dock.ReturnPanels` | Or `Dock.ClosePanels` |
| `autoSaveKey` | `string` | `""` | Enables autosave under this key |

Read-only:

| Property | Type | |
|---|---|---|
| `isMain` | `bool` | This is the main area |
| `activePanel` | `DockPanel` | Last panel the user interacted with |
| `minimumWidth`, `minimumHeight` | `real` | Smallest size that fits the docked panels |
| `title` | `string` | Titles of the visible tabs, joined with " · " |
| `panelCount`, `stackCount` | `int` | Open panels / tab groups in this area |
| `manager` | `var` | The shared manager (advanced use) |

Methods (on any area; they act on the whole docking system):

| Method | |
|---|---|
| `panel(id)` | The `DockPanel` with that id, or `null` |
| `openPanel(id)` / `closePanel(id)` | Open (and raise) / close |
| `popOut(id)` | Move into a new window. Returns its `DockArea`, or `null` if not allowed |
| `toggleMaximized(id)` | Maximize the panel's tab group within its window, or restore it |
| `saveLayout()` | Returns the layout object |
| `restoreLayout(objOrJson)` | Returns `true` on success |
| `resetLayout()` | Back to `defaultLayout` plus hints |
| `addPanel(panel[, open])` | Register a runtime-created panel. Opens it unless `open` is false (default: `openOnStart`) |
| `removePanel(id)` | Close and unregister. Doesn't destroy the panel |

Signal: `layoutChanged()`, emitted on the main area after any change in any window.

### DockPanel (Item)

| Property | Type | Default | |
|---|---|---|---|
| `panelId` | `string` | required | Unique, stable id |
| `title` | `string` | `panelId` | Tab text |
| `icon` | `url` | | Tab icon |
| `area` | `int` | `Dock.Center` | Placement hint |
| `areaSize` | `real` | `0.25` | Fraction of the window for edge hints |
| `openOnStart` | `bool` | `true` | |
| `movable`, `floatable`, `closable` | `bool` | `true` | Restrictions |
| `minimumWidth`, `minimumHeight` | `real` | `120`, `80` | |
| `maximumWidth`, `maximumHeight` | `real` | infinite | |
| `background` | `color` | `style.panel` | `"transparent"` to show what's behind |
| `isOpen` | `bool` | read-only | In some window's layout |
| `isCurrent` | `bool` | read-only | The visible tab of its group |
| `isPoppedOut` | `bool` | read-only | In a pop-out window |
| `dockArea` | `DockArea` | read-only | The area showing it, or `null` |

Methods: `open()`, `close()`, `popOut()`, `raise()`.

### DockWindow (ApplicationWindow)

| Property | |
|---|---|
| `manager` | required. Passed in by Quilt |
| `dockArea` | read-only. The window's `DockArea` |
| `mainWindow` | read-only. The main window (its palette and font are copied) |

### Dock (enums)

- `Dock.Center`, `Dock.Left`, `Dock.Right`, `Dock.Top`, `Dock.Bottom`: values for `DockPanel.area`.
- `Dock.ReturnPanels`, `Dock.ClosePanels`: values for `DockArea.windowClosePolicy`.

### User interactions (built in)

| Gesture | Result |
|---|---|
| Drag a tab onto the edge of a panel | Split that panel |
| Drag onto the middle of a panel | Add as a tab |
| Drag onto a tab bar | Insert or reorder at that position |
| Drag onto an edge marker (shown while dragging) | Dock along the whole side of the window |
| Drag into another Quilt window | Move it there |
| Drop outside every window | Pop out into a new window |
| Esc while dragging | Cancel |
| Drag the gap between panels | Resize |
| Double-click a tab, or the □ button | Maximize / restore |
| Pop-out button (box with arrow), or right-click › Pop Out | Pop out |
| × button, middle-click, or right-click › Close | Close |
