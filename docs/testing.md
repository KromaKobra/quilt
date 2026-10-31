# Testing Quilt (raw QML, no build)

Quilt is plain QML, so everything here runs straight from the source tree with Qt's own tools. Nothing needs compiling.

- [Finding the Qt tools](#finding-the-qt-tools)
- [See the output: `QT_FORCE_STDERR_LOGGING`](#see-the-output-qt_force_stderr_logging)
- [Run the examples](#run-the-examples)
- [Automated tests](#automated-tests)
- [Lint](#lint)
- [Quick experiments](#quick-experiments)
- [Headless screenshots](#headless-screenshots)
- [Debugging drags](#debugging-drags)
- [Manual test checklist](#manual-test-checklist)
- [Writing tests](#writing-tests)

## Finding the Qt tools

You need three tools from Qt 6.8+:

- `qml`, the QML runtime
- `qmltestrunner`
- `qmllint`

Distributions name and place them differently:

| | `qml` runtime | `qmltestrunner`, `qmllint` |
|---|---|---|
| Arch Linux | `qml6` on PATH | `/usr/lib/qt6/bin/` |
| Debian / Ubuntu | `qml6` or `/usr/lib/qt6/bin/qml` | `/usr/lib/qt6/bin/` |
| Qt online installer | `~/Qt/<ver>/<kit>/bin/qml` | same directory |

When in doubt, ask Qt where its tools live:

```sh
qmake6 -query QT_INSTALL_BINS        # or: qtpaths6 --query QT_INSTALL_BINS
export PATH="$(qmake6 -query QT_INSTALL_BINS):$PATH"   # then plain `qml`, `qmltestrunner` work
```

The commands below use `qml6`. Substitute `qml` if that is what you have.

## See the output: `QT_FORCE_STDERR_LOGGING`

On systemd distributions Qt may send its log, including **QML errors** and `console.log`, to the journal instead of the terminal. A broken QML file then fails silently (`qml: Did not load any objects, exiting.`). Force the log to the terminal:

```sh
export QT_FORCE_STDERR_LOGGING=1
```

`run-tests.sh` sets this for you.

## Run the examples

From the repository root. `-I .` puts the `Quilt/` folder on the import path:

```sh
qml6 -I . examples/minimal.qml       # four panels, the quick-start app
qml6 -I . examples/sandbox.qml       # every feature + stateful panels to test against
```

Useful variations:

```sh
QT_QPA_PLATFORM=xcb qml6 -I . examples/sandbox.qml        # force X11 (XWayland) instead of Wayland
QT_QUICK_CONTROLS_STYLE=Fusion qml6 -I . examples/sandbox.qml
QT_QPA_PLATFORM=offscreen timeout 5 qml6 -I . examples/sandbox.qml   # smoke-load without a window:
                                                                      # any QML error is printed, exit 124 = loaded fine
```

**The sandbox.** Every panel holds live state so you can watch it survive moves:

- the viewport's animation never restarts
- typed text in Inspector, Notes and documents stays put
- the outliner keeps its scroll position
- the timeline keeps its frame

It also has:

- restricted panels: "Tools" has a fixed width and can't share a tab group (plain title bar); "Status" can't be moved, popped out or closed
- a **2×2 grid** button that arranges four panels in quadrants, for trying split lines
- a transparent panel ("Glass")
- runtime-created panels: *New document*
- a **Panels** menu
- Save / Restore / Reset buttons
- a live **Layout JSON** panel
- a **Console** that logs every layout change
- pop-outs with a custom toolbar (`windowComponent`)

## Automated tests

```sh
./run-tests.sh
```

This runs `qmllint` over the module and examples, then every `tests/tst_*.qml` with the **offscreen** platform: no window appears, and it works over SSH and in CI. It exits non-zero on any failure. It also points `XDG_CONFIG_HOME` at a temporary directory, so the autosave test never touches your real settings.

The same thing by hand:

```sh
BIN="$(qmake6 -query QT_INSTALL_BINS)"
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 "$BIN/qmltestrunner" -import . -input tests
```

To run one file, or one test function:

```sh
./run-tests.sh -input tests/tst_layout_tree.qml       # args replace "-input tests"
QT_QPA_PLATFORM=offscreen "$BIN/qmltestrunner" -import . -input tests/tst_dock_area.qml DockArea::test_pop_out_moves_panel_into_its_own_window
```

To watch the integration tests run in a real window, drop `QT_QPA_PLATFORM=offscreen` (and add `-platform xcb` or `wayland` if needed).

### What is covered

| Suite | Covers |
|---|---|
| `tst_layout_tree.qml` (47 tests, pure JS, no window) | parse/serialize round trips; unknown/duplicate panels; flattening and collapsing; tab insert/reorder; remove with space hand-off; split into or around parents; edge docking; hint placement; drop no-ops; move/split/edge/empty drops; never losing a panel; non-tabbable panels (placement, drops, hit-testing, separating them in JSON layouts); min/max water-filling; overflow; layout rectangles and handles; maximize; pair resizing with clamps; handle hit-testing; linked lines; snap candidates; line resizing with shared limits; breaking a handle at shared cuts with geometry preserved; hit-test zones and gaps |
| `tst_dock_area.qml` (36 tests, real components, offscreen windows) | initial layout from hints and `defaultLayout`; panels parented into stacks; tab clicks; dragging a split handle to its minimum; clicks reaching panel content; maximize; close/reopen keeping content state; reopen by hint; drops that split, insert into a tab bar, or dock at an edge; drops on the panel's own group; tear-off at the window border vs. cancel; non-movable panels; pop-out windows; docking into pop-outs; non-floatable refusal; auto-closing empty pop-outs; closing pop-outs (both policies); save/restore including windows; tolerant restore; autosave across a restart; runtime panels; minimum sizes; non-tabbable panels (own group, title bar, refused tabs, restore); real-mouse split-line drags: whole lines, Ctrl segments, breaking a full-length handle, snapping, no snapping with Ctrl |

### What can't be automated

The platform drag loop (`Drag.Automatic`) needs a real compositor and a real pointer, so the tests call the same entry points the `DropArea`s call:

- `manager.beginDrag(panel, area)`
- `area.dragMoved(x, y)`
- `area.dropped()`
- `manager.finishDrag(action)`

Each of those steps is tested, but the actual gesture on your desktop must be checked by hand; see the [manual checklist](#manual-test-checklist).

## Lint

```sh
"$(qmake6 -query QT_INSTALL_BINS)/qmllint" -I . Quilt/*.qml examples/*.qml
```

The module and examples lint clean; keep it that way.

## Quick experiments

To poke at one behaviour, write a throwaway file anywhere and run it against the repository:

```qml
// /tmp/try.qml
import QtQuick
import Quilt

Window {
    width: 900; height: 600; visible: true
    DockArea {
        id: dock
        anchors.fill: parent
        style.gap: 0
        DockPanel { panelId: "a"; title: "A"; Rectangle { anchors.fill: parent; color: "#223" } }
        DockPanel { panelId: "b"; title: "B"; area: Dock.Right; maximumWidth: 200 }
        onLayoutChanged: console.log(JSON.stringify(dock.saveLayout(), null, 2))
    }
}
```

```sh
qml6 -I /path/to/quilt /tmp/try.qml
```

## Headless screenshots

To check visuals without a display (handy in CI or over SSH), load a window offscreen and grab it:

```qml
// shot.qml: qml6 -I . shot.qml -- file:///abs/path/examples/sandbox.qml /tmp/out.png
import QtQuick
QtObject {
    id: shot
    property var win
    property var args: Qt.application.arguments
    property Timer t: Timer {
        interval: 800
        // Grab the window's first item (the root item has no QML engine).
        onTriggered: shot.win.contentItem.children[0].grabToImage(r => {
            r.saveToFile(shot.args[shot.args.length - 1]); Qt.exit(0); })
    }
    Component.onCompleted: {
        const c = Qt.createComponent(args[args.length - 2]);
        if (c.status === Component.Error) { console.log(c.errorString()); Qt.exit(1); return; }
        win = c.createObject(null);
        t.start();
    }
}
```

```sh
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml6 -I . shot.qml -- file://$PWD/examples/sandbox.qml /tmp/sandbox.png
```

Before grabbing, you can call the API to stage a state: `popOut(...)`, `toggleMaximized(...)`, or a simulated hover (`manager.beginDrag(panel, area); area.dragMoved(x, y)`) to render the drop preview.

## Debugging drags

```sh
QT_LOGGING_RULES="quilt.drag.debug=true" qml6 -I . examples/sandbox.qml
```

Each drag logs its start, the accepted drop target, and how it ended:

```
quilt.drag: begin timeline from main window
quilt.drag: drop accepted: split right in main window
quilt.drag: finished, action 2 last seen 1104,388 in 1440x900 -> move
```

A drop that ends with `-> cancel` when you expected a tear-off means the last position seen was not near the window border. That can happen with a very fast flick out of the window. Wayland's own drag logging, `QT_LOGGING_RULES="qt.qpa.wayland*=true"`, shows the protocol side.

## Manual test checklist

Run `qml6 -I . examples/sandbox.qml` and go through the list. Do it on each platform you ship (Wayland, X11/XWayland, Windows, macOS).

**Rearranging**

- [ ] Drag a tab to the left, right, top and bottom of another panel. The preview shows the half it will take, and it lands there.
- [ ] Drag a tab to the middle of another panel. It joins as a tab.
- [ ] Drag a tab within its own tab bar. It reorders, and the insertion marker follows.
- [ ] Drag a tab onto each of the four edge markers. It spans the whole side of the window.
- [ ] Drag a panel onto its own lone tab group. No preview, and nothing happens.
- [ ] Press Esc mid-drag, inside the window. Nothing changes.
- [ ] Drop on the toolbar. Nothing changes.
- [ ] Repeat drags 10+ times quickly. A tab never gets stuck, and a single click still selects tabs afterwards.

**State**

- [ ] Type in Notes, move it, pop it out, close and reopen it from Panels. The text is still there.
- [ ] The viewport frame counter keeps counting through every move and pop-out.

**Resizing** (click **2×2 grid** first)

- [ ] Drag the middle vertical line, at the top or the bottom. All four panels change width together. The middle horizontal line does the same for heights.
- [ ] Hover a line. The whole line lights up; with Ctrl held, only the segment under the cursor does.
- [ ] Ctrl-drag the top half of the vertical line. Only the top two panels change.
- [ ] Drag that top half (no Ctrl) back near the bottom half. It snaps into line; drag again and both halves move together.
- [ ] Ctrl-drag a half close to the other one. It does not snap.
- [ ] Drag a line far past a panel's minimum. It stops, and the whole line stops with it.
- [ ] Press **Reset**. "Tools" stays 52 px wide when the window is resized.

**Non-tabbable panels** ("Tools")

- [ ] It has a plain title bar: no tab, no accent line when active.
- [ ] Drag another tab onto the middle of Tools. The preview shows a split, never a tab.
- [ ] Drag Tools by its title bar onto the middle of another panel. It splits beside it rather than joining.

**Pop-out windows**

- [ ] Drag a tab outside the window and release. A new window opens with that panel (on Wayland the compositor decides where).
- [ ] Use the pop-out button. Same result.
- [ ] Drag a tab from the main window into the pop-out (edges, middle, tab bar, edge markers). It docks there.
- [ ] Drag the last tab out of a pop-out back to the main window. The pop-out closes itself.
- [ ] Close a pop-out with two panels in it. Both return to the main window.
- [ ] "Status" (not floatable) has no pop-out button, gets no preview over a pop-out, and nothing happens when it is dropped outside.
- [ ] Panels in pop-outs use the dark palette, and the pop-out shows its custom toolbar.

**Other**

- [ ] Double-click a tab. It maximizes; double-click again to restore.
- [ ] Right-click a tab. The menu's Pop Out, Maximize and Close items work and respect restrictions.
- [ ] Middle-click a tab. It closes, unless it isn't closable.
- [ ] Save layout, rearrange, Restore. Back to the saved state, including pop-outs.
- [ ] Reset. Back to the default layout, with pop-outs closed.
- [ ] Close the main window while pop-outs are open. Everything closes and the app exits.
- [ ] With `autoSaveKey` set (see `examples/cpp-host`), restart. The layout comes back.

## Writing tests

Tests are ordinary [Qt Quick Test](https://doc.qt.io/qt-6/qtquicktest-index.html) files named `tst_*.qml` in `tests/`.

- **Pure model tests** import `../Quilt/LayoutTree.js` directly and need no window (see `tst_layout_tree.qml`). A `shape()` helper that prints trees as `row(tabs[a*,b],tabs[c*])` makes expectations readable.
- **Component tests** wrap a `DockArea` in a `Component`. They create a fresh one per test with `createTemporaryObject(component, root)`; temporary objects, including their pop-out windows, are destroyed after each test. Set `style.animationDuration: 0` so geometry is final immediately.
- **Drags:** see [What can't be automated](#what-cant-be-automated). Drops are applied via `Qt.callLater`, so check results with `tryVerify` / `tryCompare`.
- **Pitfall.** The manager *reassigns* arrays (`windows`, `panelOrder`) rather than mutating them. `tryCompare(manager.windows, "length", 0)` keeps polling the old array; use `tryVerify(() => manager.windows.length === 0)`.
- **Expected warnings** go in `ignoreWarning(/pattern/)` before the call that triggers them, so a clean run prints none of Quilt's own warnings.
