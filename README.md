# Quilt

Quilt is a docking framework for Qt Quick tool applications. Every panel can be resized, rearranged, tabbed, maximized, and popped out into its own window. Each pop-out window is a full docking area, so you can spread one application across several monitors and dock more panels into each window.

Quilt is pure QML: copy one folder and add `import Quilt`.

```qml
import QtQuick
import QtQuick.Controls
import Quilt

ApplicationWindow {
    width: 1200; height: 760; visible: true

    DockArea {
        anchors.fill: parent

        DockPanel { panelId: "viewport";  title: "Viewport";  Viewport { } }
        DockPanel { panelId: "outliner";  title: "Outliner";  area: Dock.Left;   areaSize: 0.2;  Outliner { } }
        DockPanel { panelId: "inspector"; title: "Inspector"; area: Dock.Right;  minimumWidth: 260; Inspector { } }
        DockPanel { panelId: "timeline";  title: "Timeline";  area: Dock.Bottom; Timeline { } }
    }
}
```

## Why

Most tool UIs are built from panel sections: inspectors, outliners, timelines, spline editors, media views. Those sections are usually fixed in place inside one window. Splitters let you nudge their sizes, but when your work shifts (from the timeline to the inspector, or to the media view), you can't get the space you need where you need it.

Quilt lets users arrange panels to fit what they're doing right now:

- They can stack panels as tabs, split them side by side, or maximize one temporarily.
- They can drag a panel onto a second monitor in its own window and keep docking other panels next to it.
- The arrangement is saved and comes back on the next start.

The defaults allow everything. Developers can restrict individual panels when they need to: fixed or limited sizes, panels that can't be popped out, panels that can't be moved, and panels that can't be closed.

## Features

- **Rearrange by dragging tabs.** Drop a tab on any edge of another panel to split it, in the middle to add it as a tab, between tabs to reorder, or on the edge markers to dock along a whole side of the window. A live preview shows where the panel will land.
- **Pop-out windows.** Drag a tab outside the window, or click its pop-out button. Pop-out windows accept docked panels exactly like the main window. They close themselves when emptied. Closing one sends its panels back to the main window.
- **State is never lost.** A panel is created once and only re-parented as it moves. Text being edited, scroll positions, running animations and GPU views all survive every move.
- **Resizing that respects limits.** Dragging a split handle changes only its two neighbours. Each panel's minimum and maximum size is honoured, including fixed sizes.
- **Maximize** any panel within its window (double-click the tab), then restore it.
- **Save and restore** the whole arrangement, pop-out windows included, as readable JSON. Autosave is one property. Panels added in later versions of your app are placed sensibly instead of disappearing.
- **Per-panel restrictions.** The `movable`, `floatable` and `closable` flags, plus `minimum*`/`maximum*` sizes.
- **Themeable** through one `DockStyle` object. Transparent panels are supported.
- **Works on Wayland, X11, Windows and macOS.** Dragging uses the platform's drag-and-drop, the only mechanism that crosses windows on Wayland.

## Try it

You need Qt 6.8 or newer (developed against 6.12). From the repository root:

```sh
qml6 -I . examples/minimal.qml      # the snippet above, runnable
qml6 -I . examples/sandbox.qml      # every feature, with stateful panels to test against
./run-tests.sh                      # lint + 63 headless tests
```

The `qml` runtime may be called `qml6` or `qml`, or it may only exist in Qt's bin directory (`qmake6 -query QT_INSTALL_BINS`). [docs/testing.md](docs/testing.md) covers this.

## Documentation

| Document | What it covers |
|---|---|
| [Integration guide](docs/integration.md) | Adding Quilt to your app; panels, layouts, restrictions, persistence, pop-out windows, styling; API reference |
| [Architecture](docs/architecture.md) | How it works: the layout tree, rendering, re-parenting, drag and drop, windows, persistence |
| [Testing](docs/testing.md) | Running the QML directly, the automated tests, headless screenshots, debugging drags, the manual checklist |

## Repository layout

```
Quilt/              the module — copy this folder into your project
  DockArea.qml        public: a docking surface (one per window)
  DockPanel.qml       public: a panel; its children are the content
  DockStyle.qml       public: colours and metrics
  DockWindow.qml      public: the pop-out window (customisable)
  Dock.qml            public: enums (Dock.Left, Dock.ReturnPanels, ...)
  DockManager.qml     internal: shared state, windows, drag session, persistence
  DockStack.qml       internal: a tab group
  SplitHandle.qml     internal: resize handle
  LayoutTree.js       internal: the layout model (pure functions)
  CMakeLists.txt      optional: build as a compiled QML module
examples/           minimal.qml, sandbox.qml, cpp-host/ (CMake + C++ app)
tests/              QtQuick.Test suites (run headless)
docs/               the documentation above
run-tests.sh        lint + tests
```
