# Quilt — Developer Guide

Quilt is a pure-QML template that adds dockable, resizable, and rearrangeable
panels to any Qt application. There is no C++ or Python required. You connect
your backend to panel content the same way you always do — Quilt only handles
the UI shell.

---

## Installation

Copy the `Quilt/` folder into your project. In your CMakeLists.txt or .pro
file, add the folder to your QML import path:

    # CMake
    target_compile_definitions(myapp PRIVATE QML_IMPORT_PATH="${CMAKE_SOURCE_DIR}/Quilt")

    # .pro
    QML_IMPORT_PATH += $$PWD/Quilt

Then import it in any QML file:

    import Quilt 1.0

---

## Core concepts

Each panel in your app has two parts:

1. A **PanelModel** — a data object that stores everything about the panel
   (size, position, dock state, visual style). You define this; Quilt reads it.

2. A **Panel** — the visual component that renders the panel shell. You place
   your content inside it as a child item.

The **DockManager** singleton watches all panels and handles drag-and-drop
placement automatically. You never interact with it directly for basic use.

---

## Defining panels

Create a PanelModel for each panel. You can define these inline in your root
component, in a separate QML file, or dynamically at runtime.

    PanelModel {
        id: editorPanel
        panelId:      "editor"
        panelType:    "editor"
        title:        "Code Editor"
        dockPosition: DockEnums.Left
        splitRatio:   0.65
        minWidth:     240
        maxWidth:     900
        minHeight:    200
        maxHeight:    9999
        cornerRadius: 10
        panelStyle:   DockEnums.Isolated
    }

---

## Panel styles

Each panel independently uses one of three visual styles set via `panelStyle`.

**Isolated** — the panel has a filled background with rounded corners on all
four sides. It looks like a self-contained card. Use this for panels that
should visually stand alone.

    panelStyle: DockEnums.Isolated

**Connected** — the panel's corners curve *outward* at edges it shares with
neighboring panels, creating a grooved seam between them. The panels look as
though they are physically interlocked. Use this when you want a group of
panels to read as a unified surface.

    panelStyle: DockEnums.Connected

**Empty** — no background is drawn. The panel content is visible against
whatever is behind it (your window background, a map, a canvas, etc.). Only
the header bar is rendered, tinted with `customColor`.

    panelStyle:   DockEnums.Empty
    customColor:  "#33ffffff"   // semi-transparent white tint on header

---

## Placing panels in your window

Wrap your window content in a `DockContainer` and pass it your panel models:

    ApplicationWindow {
        visible: true
        width: 1280
        height: 800

        DockContainer {
            anchors.fill: parent
            model: [ editorPanel, sidebarPanel, terminalPanel ]

            Panel {
                panelModel: editorPanel
                // your content here
                Rectangle { color: "transparent"; Text { text: "Editor" } }
            }

            Panel {
                panelModel: sidebarPanel
                ListView { /* your file tree */ }
            }

            Panel {
                panelModel: terminalPanel
                TextArea { /* your terminal output */ }
            }
        }
    }

The `DockContainer` reads each panel's `dockPosition` and `splitRatio` to
build the initial layout. If a saved layout exists from a previous session,
it restores that instead.

---

## Letting users rearrange panels

No extra code needed. Quilt handles all of the following automatically:

- **Drag to move** — users drag a panel by its header bar. During the drag,
  dock zone indicators appear on the edges and center of the window.
- **Drop to dock** — releasing over a zone docks the panel there.
- **Drag to float** — clicking the ⊞ button in the header undocks the panel
  and makes it float freely inside the window. Users can then drag it
  anywhere or drop it back into a dock zone.
- **Resize docked panels** — users drag the SplitHandle bars between panels.
- **Resize floating panels** — users drag the edge/corner handles on the panel.

All of these write back to the `PanelModel` properties in real time.

---

## Saving and restoring layout

Call `DockManager.saveLayout()` to write the current arrangement to a JSON
file. Call `DockManager.restoreLayout(jsonString)` to load it back.

The `DockContainer` calls `restoreLayout` automatically on startup. To add
manual save/load buttons:

    ToolBar {
        RowLayout {
            Button {
                text: "Save layout"
                onClicked: DockManager.saveLayout()
            }
            Button {
                text: "Reset layout"
                onClicked: DockManager.restoreLayout(defaultLayoutJson)
            }
        }
    }

The saved JSON is human-readable. You can ship a default layout as a string
constant and use it as the fallback when no saved layout exists.

---

## Adjusting panel properties at runtime

All PanelModel properties are live bindings. You can change them from anywhere:

    // Programmatically float a panel
    editorPanel.isDocked  = false
    editorPanel.isFloating = true

    // Change the visual style on the fly
    sidebarPanel.panelStyle   = DockEnums.Connected
    sidebarPanel.cornerRadius = 14

    // Enforce new size constraints
    terminalPanel.minHeight = 300

---

## Listening to layout changes

    Connections {
        target: DockManager
        function onLayoutChanged() {
            console.log("Layout updated — auto-saving")
            DockManager.saveLayout()
        }
    }

---

## Property reference — PanelModel

| Property       | Type   | Description                                              |
|----------------|--------|----------------------------------------------------------|
| panelId        | string | Unique ID used for serialisation and lookup              |
| panelType      | string | Developer-defined category label                         |
| title          | string | Text shown in the panel header bar                       |
| isFloating     | bool   | Panel is free-floating inside the window                 |
| isVisible      | bool   | Panel is shown at all                                    |
| splitRatio     | real   | 0.0–1.0, share of space relative to neighbor             |
| x, y           | real   | Position when floating                                   |
| width, height  | real   | Current size                                             |
| minWidth       | real   | Minimum allowed width                                    |
| maxWidth       | real   | Maximum allowed width (use 9999 for unconstrained)       |
| minHeight      | real   | Minimum allowed height                                   |
| maxHeight      | real   | Maximum allowed height                                   |
| cornerRadius   | real   | Base corner radius for Isolated and Connected styles     |
| panelStyle     | int    | DockEnums.Isolated / Connected / Empty                   |
| customColor    | string | Header tint color, used only when panelStyle is Empty    |

---

## DockManager signals

| Signal          | When it fires                                             |
|-----------------|-----------------------------------------------------------|
| layoutChanged() | Any panel moves, resizes, docks, or undocks               |

---

## Tips

- Give every PanelModel a unique `panelId`. Serialisation depends on it.
- For a two-column layout, set left panel `splitRatio: 0.3` and right panel
  `splitRatio: 0.7`.
- The `Connected` style looks best when two or more adjacent panels all use
  it. A single Connected panel surrounded by Isolated panels will have the
  outward curve on all four corners, which looks fine but is more subtle.
- Use `Empty` for overlay panels like minimaps or HUD elements that should
  feel like they're floating above the content rather than beside it.
- Set `maxWidth: 9999` and `maxHeight: 9999` for panels with no upper bound.