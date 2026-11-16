pragma ComponentBehavior: Bound

// Quilt sandbox: a small "editor" that exercises every layer.
//
//     qml6 -I . examples/sandbox.qml
//
// Layout     Drag tabs to rearrange, drop one outside to pop it out, drag
//            the gaps to resize. Panels keep their state through every move.
// Controls   Select a shape and edit it in the Inspector: drag numbers, type
//            arithmetic, reset with the dot. Ctrl+click selects several shapes
//            and the Inspector shows "Mixed" where they differ.
// Linking    Type =cube.rotation * 2 into a field and it follows the cube.
//            Press Play: the disc's rotation is driven by the timeline.
// Window     The title bar, its menus and the window buttons are Quilt's.
//            Edit > Undo takes back one edit, however long the drag was.
import QtQuick
import Quilt
import Quilt.Controls
import Quilt.Params

ApplicationWindow {
    id: window
    width: 1440
    height: 900
    minimumWidth: dock.minimumWidth
    minimumHeight: dock.minimumHeight + titleBar.height
    visible: true
    frameless: true
    title: "Quilt sandbox" + (dock.activePanel ? " — " + dock.activePanel.title : "")
    color: dock.style.background

    // ---------------------------------------------------------------------
    //  The document: three shapes, each a handful of parameters.

    readonly property var shapes: ["cube", "disc", "card"]
    property var selection: ["cube"]
    property int frame: 0
    property bool seamless: false
    property var savedLayout: null
    property int documentCount: 0

    function select(id: string, add: bool) {
        if (!add)
            selection = [id];
        else if (selection.indexOf(id) >= 0)
            selection = selection.filter(s => s !== id);
        else
            selection = shapes.filter(s => s === id || selection.indexOf(s) >= 0);
    }

    function valueOf(id: string, key: string): var {
        const p = params.find(id + "." + key);
        return p ? p.value : undefined;
    }

    ParameterSet {
        id: params

        // The timeline, as something expressions can read.
        Parameter { name: "time.frame"; value: 0; type: "int" }

        Parameter { name: "cube.name"; label: "Name"; type: "string"; value: "Cube" }
        Parameter { name: "cube.position"; label: "Position"; group: "Transform"; type: "vector"; value: Qt.vector2d(-150, -20); step: 1; decimals: 1 }
        Parameter { name: "cube.size"; label: "Size"; group: "Transform"; type: "vector"; value: Qt.vector2d(120, 120); labels: ["W", "H"]; minimum: 4; step: 1; decimals: 1; linkable: true }
        Parameter { name: "cube.rotation"; label: "Rotation"; group: "Transform"; value: 18; defaultValue: 0; from: 0; to: 360; wrap: true; suffix: "°"; decimals: 1 }
        Parameter { name: "cube.opacity"; label: "Opacity"; group: "Appearance"; value: 1; defaultValue: 1; from: 0; to: 1; displayScale: 100; suffix: "%"; decimals: 0 }
        Parameter { name: "cube.fill"; label: "Fill"; group: "Appearance"; type: "color"; value: "#4c8dff"; defaultValue: "#4c8dff" }
        Parameter { name: "cube.radius"; label: "Corners"; group: "Appearance"; value: 14; defaultValue: 0; from: 0; to: 100; suffix: " px"; decimals: 0 }
        Parameter { name: "cube.visible"; label: "Visible"; group: "Appearance"; type: "bool"; value: true; defaultValue: true }

        Parameter { name: "disc.name"; label: "Name"; type: "string"; value: "Disc" }
        Parameter { name: "disc.position"; label: "Position"; group: "Transform"; type: "vector"; value: Qt.vector2d(60, 30); step: 1; decimals: 1 }
        Parameter { name: "disc.size"; label: "Size"; group: "Transform"; type: "vector"; value: Qt.vector2d(90, 90); labels: ["W", "H"]; minimum: 4; step: 1; decimals: 1; linkable: true }
        // Driven by the timeline: it turns while the timeline plays.
        Parameter { name: "disc.rotation"; label: "Rotation"; group: "Transform"; value: 0; defaultValue: 0; from: 0; to: 360; wrap: true; suffix: "°"; decimals: 1
                    expression: "time.frame * 3 % 360" }
        Parameter { name: "disc.opacity"; label: "Opacity"; group: "Appearance"; value: 0.9; defaultValue: 1; from: 0; to: 1; displayScale: 100; suffix: "%"; decimals: 0 }
        Parameter { name: "disc.fill"; label: "Fill"; group: "Appearance"; type: "color"; value: "#a98bf5"; defaultValue: "#4c8dff" }
        Parameter { name: "disc.radius"; label: "Corners"; group: "Appearance"; value: 45; defaultValue: 0; from: 0; to: 100; suffix: " px"; decimals: 0 }
        Parameter { name: "disc.visible"; label: "Visible"; group: "Appearance"; type: "bool"; value: true; defaultValue: true }

        Parameter { name: "card.name"; label: "Name"; type: "string"; value: "Card" }
        Parameter { name: "card.position"; label: "Position"; group: "Transform"; type: "vector"; value: Qt.vector2d(190, -70); step: 1; decimals: 1 }
        // Linked: the card is always half as wide as the cube, and twice as tall as that.
        Parameter { name: "card.size"; label: "Size"; group: "Transform"; type: "vector"; value: Qt.vector2d(70, 110); labels: ["W", "H"]; minimum: 4; step: 1; decimals: 1; linkable: true }
        Parameter { name: "card.rotation"; label: "Rotation"; group: "Transform"; value: 0; defaultValue: 0; from: 0; to: 360; wrap: true; suffix: "°"; decimals: 1
                    expression: "cube.rotation / 2" }
        Parameter { name: "card.opacity"; label: "Opacity"; group: "Appearance"; value: 1; defaultValue: 1; from: 0; to: 1; displayScale: 100; suffix: "%"; decimals: 0 }
        Parameter { name: "card.fill"; label: "Fill"; group: "Appearance"; type: "color"; value: "#4fbf7b"; defaultValue: "#4c8dff" }
        Parameter { name: "card.radius"; label: "Corners"; group: "Appearance"; value: 6; defaultValue: 0; from: 0; to: 100; suffix: " px"; decimals: 0 }
        Parameter { name: "card.visible"; label: "Visible"; group: "Appearance"; type: "bool"; value: true; defaultValue: true }

        // One edit, however many values it passed through, is one undo step.
        onEditStarted: history.begin()
        onEditFinished: (parameter, committed) => history.end(committed)
    }

    onFrameChanged: params.find("time.frame").value = frame

    // What the Inspector shows: each parameter of the selected shapes, merged
    // so that several shapes can be edited at once.
    readonly property var parameterKeys: ["name", "position", "size", "rotation", "opacity", "fill", "radius", "visible"]
    property var inspected: []
    Instantiator {
        model: window.parameterKeys
        delegate: MergedParameter {
            required property string modelData
            sources: window.selection.map(id => params.find(id + "." + modelData))
        }
        onObjectAdded: (index, object) => {
            const list = window.inspected.slice();
            list[index] = object;
            window.inspected = list;
        }
    }

    // A minimal undo stack on top of the transaction signals.
    QtObject {
        id: history
        property var undoStack: []
        property var redoStack: []
        property var pending: null

        function begin() { pending = params.save(); }
        function end(committed: bool) {
            if (pending && committed && JSON.stringify(pending) !== JSON.stringify(params.save())) {
                undoStack = undoStack.concat([pending]);
                redoStack = [];
            }
            pending = null;
        }
        function undo() {
            if (!undoStack.length)
                return;
            redoStack = redoStack.concat([params.save()]);
            params.restore(undoStack[undoStack.length - 1]);
            undoStack = undoStack.slice(0, -1);
        }
        function redo() {
            if (!redoStack.length)
                return;
            undoStack = undoStack.concat([params.save()]);
            params.restore(redoStack[redoStack.length - 1]);
            redoStack = redoStack.slice(0, -1);
        }
    }

    // ---------------------------------------------------------------------
    //  Layout helpers

    // Four panels in quadrants, for trying split lines: drag the middle
    // lines, Ctrl-drag one half, drag it back close to the other half.
    function gridDemo() {
        const shown = ["viewport", "inspector", "timeline", "notes"];
        dock.restoreLayout({
            version: 1,
            main: { column: [ { row: [ { tabs: ["viewport"] }, { tabs: ["inspector"] } ] },
                              { row: [ { tabs: ["timeline"] }, { tabs: ["notes"] } ] } ] },
            windows: [],
            closed: dock.manager.panelOrder.filter(id => shown.indexOf(id) < 0)
        });
    }

    function newDocument() {
        documentCount += 1;
        const p = documentComponent.createObject(dock, {
            panelId: "document-" + documentCount,
            title: "Untitled " + documentCount
        });
        dock.addPanel(p);
    }

    // ---------------------------------------------------------------------
    //  The title bar: menus, title, window buttons

    menuBar: TitleBar {
        id: titleBar

        Menu {
            title: "&File"
            Action { text: "New Document"; shortcut: StandardKey.New; onTriggered: window.newDocument() }
            MenuSeparator { }
            Action { text: "Save Layout"; onTriggered: window.savedLayout = dock.saveLayout() }
            Action { text: "Restore Layout"; enabled: window.savedLayout !== null; onTriggered: dock.restoreLayout(window.savedLayout) }
            Action { text: "Reset Layout"; onTriggered: dock.resetLayout() }
            MenuSeparator { }
            Action { text: "Quit"; shortcut: StandardKey.Quit; onTriggered: Qt.quit() }
        }
        Menu {
            title: "&Edit"
            Action { text: "Undo"; shortcut: StandardKey.Undo; enabled: history.undoStack.length > 0; onTriggered: history.undo() }
            Action { text: "Redo"; shortcut: StandardKey.Redo; enabled: history.redoStack.length > 0; onTriggered: history.redo() }
            MenuSeparator { }
            Action { text: "Select All Shapes"; shortcut: "Ctrl+Shift+A"; onTriggered: window.selection = window.shapes }
            Action { text: "Select None"; onTriggered: window.selection = [] }
        }
        Menu {
            title: "&View"
            Menu {
                id: panelsMenu
                title: "Panels"
                Instantiator {
                    model: dock.manager ? dock.manager.panelOrder : []
                    delegate: MenuItem {
                        required property string modelData
                        readonly property var panel: dock.panel(modelData)
                        text: panel ? panel.title : modelData
                        checkable: true
                        checked: !!panel && panel.isOpen
                        onTriggered: {
                            if (panel.isOpen) panel.close(); else panel.open();
                            checked = Qt.binding(() => !!panel && panel.isOpen);   // keep following the panel
                        }
                    }
                    onObjectAdded: (index, object) => panelsMenu.insertItem(index, object as MenuItem)
                    onObjectRemoved: (index, object) => panelsMenu.removeItem(object as MenuItem)
                }
            }
            Action { text: "2×2 Grid"; onTriggered: window.gridDemo() }
            MenuSeparator { }
            Action { text: "Dark Theme"; checkable: true; checked: Theme.dark; onTriggered: Theme.dark = !Theme.dark }
            Action { text: "Seamless Panels"; checkable: true; checked: window.seamless; onTriggered: window.seamless = !window.seamless }
            Action { text: "Always Show Panel Buttons"; checkable: true; checked: !dock.style.buttonsOnHover
                     onTriggered: dock.style.buttonsOnHover = !dock.style.buttonsOnHover }
        }
        Menu {
            title: "&Help"
            Action { text: "Gestures and Shortcuts"; shortcut: StandardKey.HelpContents; onTriggered: dock.openPanel("help") }
        }
    }

    Component {
        id: documentComponent
        DockPanel {
            title: "Untitled"
            TextArea {
                anchors { fill: parent; margins: 8 }
                maximumLines: 1000
                placeholderText: "Type something, then move this tab around…"
            }
        }
    }

    // ---------------------------------------------------------------------
    //  Panels

    DockArea {
        id: dock
        anchors.fill: parent

        // The "Seamless" look is the same tokens with other values.
        style.gap: window.seamless ? 1 : Theme.gap
        style.radius: window.seamless ? 0 : Theme.radius
        style.background: window.seamless ? Theme.border : Theme.canvas

        // Explicit starting layout. Panels it leaves out ("Palette", "Help")
        // are placed by their `area` hint when opened.
        defaultLayout: ({
            row: [
                { tabs: ["tools"], size: 0.035 },
                { tabs: ["outliner", "layout"], size: 0.16 },
                { column: [
                    { tabs: ["viewport", "glass"], size: 0.72 },
                    { tabs: ["timeline", "console"] }
                ] },
                { column: [
                    { tabs: ["inspector", "notes"], size: 0.72 },
                    { tabs: ["status"] }
                ], size: 0.24 }
            ]
        })

        // Pop-out windows get the same title bar, without menus.
        windowComponent: Component {
            DockWindow {
                id: popout
                flags: Qt.Window | Qt.FramelessWindowHint
                header: TitleBar { title: popout.dockArea.title }
            }
        }

        DockPanel {
            id: viewportPanel
            panelId: "viewport"
            title: "Viewport"
            minimumWidth: 240
            minimumHeight: 160
            background: Theme.dark ? "#121316" : "#eef0f3"

            Item {
                id: scene
                anchors.fill: parent
                clip: true

                TapHandler { onTapped: window.selection = [] }

                Repeater {
                    model: window.shapes
                    delegate: Rectangle {
                        id: shape
                        required property string modelData
                        readonly property bool selected: window.selection.indexOf(modelData) >= 0
                        readonly property vector2d position: window.valueOf(modelData, "position") ?? Qt.vector2d(0, 0)
                        readonly property vector2d size: window.valueOf(modelData, "size") ?? Qt.vector2d(10, 10)

                        x: Math.round(scene.width / 2 + position.x - width / 2)
                        y: Math.round(scene.height / 2 + position.y - height / 2)
                        width: size.x
                        height: size.y
                        rotation: window.valueOf(modelData, "rotation") ?? 0
                        radius: Math.min(Math.min(width, height) / 2, window.valueOf(modelData, "radius") ?? 0)
                        color: window.valueOf(modelData, "fill") ?? "gray"
                        opacity: window.valueOf(modelData, "opacity") ?? 1
                        visible: window.valueOf(modelData, "visible") !== false

                        Rectangle {
                            anchors { fill: parent; margins: -4 }
                            radius: parent.radius + 4
                            color: "transparent"
                            border.width: 1.5
                            border.color: Theme.accent
                            visible: shape.selected
                        }

                        // An exclusive grab, so the background's "select nothing" doesn't
                        // also see the tap. (The DragHandler can still take over.)
                        TapHandler {
                            id: shapeTap
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            acceptedModifiers: Qt.KeyboardModifierMask
                            onTapped: window.select(shape.modelData, (shapeTap.point.modifiers & Qt.ControlModifier) !== 0)
                        }

                        // Dragging a shape is an edit like any other: one transaction, one undo step.
                        DragHandler {
                            target: null
                            property vector2d start
                            property var parameter: null
                            onActiveChanged: {
                                if (active) {
                                    window.select(shape.modelData, false);
                                    parameter = params.find(shape.modelData + ".position");
                                    start = parameter.value;
                                    parameter.beginEdit();
                                } else if (parameter) {
                                    parameter.endEdit(true);
                                    parameter = null;
                                }
                            }
                            onActiveTranslationChanged: {
                                if (active && parameter)
                                    parameter.setValue(Qt.vector2d(Math.round(start.x + activeTranslation.x),
                                                                   Math.round(start.y + activeTranslation.y)));
                            }
                        }
                    }
                }

                Label {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
                    dim: true
                    font.pixelSize: Theme.fontSizeSmall
                    text: "up " + uptime.seconds + " s: this counter never restarts, wherever the panel goes"
                    Timer { id: uptime; property int seconds: 0; interval: 1000; running: true; repeat: true; onTriggered: seconds += 1 }
                }
            }
        }

        DockPanel {
            panelId: "glass"
            title: "Glass (transparent)"
            background: "transparent"
            Label {
                anchors.centerIn: parent
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                dim: true
                text: "background: \"transparent\": whatever is behind the dock area shows through."
            }
        }

        DockPanel {
            panelId: "outliner"
            title: "Outliner"
            area: Dock.Left
            ListView {
                anchors { fill: parent; topMargin: 6; bottomMargin: 6 }
                clip: true
                model: window.shapes
                delegate: Item {
                    id: entry
                    required property string modelData
                    readonly property bool selected: window.selection.indexOf(modelData) >= 0
                    width: ListView.view.width
                    height: 26

                    Rectangle {
                        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                        radius: Theme.controlRadius
                        color: entry.selected ? Theme.selection : entryHover.hovered ? Theme.rowHover : "transparent"
                    }
                    Rectangle {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 3
                        color: window.valueOf(entry.modelData, "fill") ?? "gray"
                    }
                    Label {
                        x: 34
                        anchors.verticalCenter: parent.verticalCenter
                        text: window.valueOf(entry.modelData, "name") ?? entry.modelData
                        dim: !entry.selected
                    }
                    HoverHandler { id: entryHover }
                    TapHandler {
                        id: entryTap
                        acceptedModifiers: Qt.KeyboardModifierMask
                        onTapped: window.select(entry.modelData, (entryTap.point.modifiers & Qt.ControlModifier) !== 0)
                    }
                }
            }
        }

        DockPanel {
            panelId: "layout"
            title: "Layout JSON"
            area: Dock.Left
            TextArea {
                id: layoutJson
                anchors { fill: parent; margins: 8 }
                readOnly: true
                maximumLines: 1000
                font.family: "monospace"
                font.pixelSize: Theme.fontSizeSmall
                function refresh() { text = JSON.stringify(dock.saveLayout(), null, 2); }
                Connections { target: dock; function onLayoutChanged() { layoutJson.refresh(); } }
                Component.onCompleted: refresh()
            }
        }

        DockPanel {
            panelId: "tools"
            title: "Tools"
            area: Dock.Left
            minimumWidth: 44
            maximumWidth: 44                    // fixed width
            closable: false
            tabbable: false                     // its own group, with a plain title bar
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 8
                spacing: 4
                IconButton { iconName: "plus"; tip: "New document"; onClicked: window.newDocument() }
                IconButton { iconName: "reset"; tip: "Undo"; enabled: history.undoStack.length > 0; onClicked: history.undo() }
                IconButton { iconName: "link"; tip: "Select all shapes"; onClicked: window.selection = window.shapes }
                IconButton { iconName: "search"; tip: "Gestures and shortcuts"; onClicked: dock.openPanel("help") }
            }
        }

        DockPanel {
            panelId: "inspector"
            title: "Inspector"
            area: Dock.Right
            minimumWidth: 160
            Inspector {
                anchors.fill: parent
                model: window.selection.length > 0 ? window.inspected : []
                emptyText: "Nothing selected"
            }
        }

        DockPanel {
            panelId: "notes"
            title: "Notes"
            area: Dock.Right
            TextArea {
                anchors { fill: parent; margins: 8 }
                maximumLines: 1000
                placeholderText: "Notes survive moves, pop-outs and close/reopen."
            }
        }

        DockPanel {
            panelId: "status"
            title: "Status (pinned)"
            area: Dock.Right
            movable: false
            floatable: false
            closable: false
            minimumHeight: 90
            Label {
                anchors { fill: parent; margins: 12 }
                wrapMode: Text.Wrap
                dim: true
                text: "movable: false · floatable: false · closable: false\n"
                      + "Active panel: " + (dock.activePanel ? dock.activePanel.title : "none") + "\n"
                      + "Selected: " + (window.selection.length ? window.selection.join(", ") : "nothing")
                      + " · undo steps: " + history.undoStack.length
            }
        }

        DockPanel {
            panelId: "timeline"
            title: "Timeline"
            area: Dock.Bottom
            minimumHeight: 70
            Row {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                spacing: 12
                Button {
                    width: 64
                    text: playing.running ? "Pause" : "Play"
                    onClicked: playing.running = !playing.running
                    Timer { id: playing; interval: 40; repeat: true; onTriggered: window.frame = (window.frame + 1) % 241 }
                }
                Slider {
                    width: parent.width - 64 - 80 - 2 * parent.spacing
                    from: 0
                    to: 240
                    stepSize: 1
                    value: window.frame
                    onEdited: v => window.frame = v
                }
                Label {
                    width: 80
                    anchors.verticalCenter: parent.verticalCenter
                    dim: true
                    font.features: ({ "tnum": 1 })
                    text: "frame " + window.frame
                }
            }
        }

        DockPanel {
            panelId: "console"
            title: "Console"
            area: Dock.Bottom
            ListView {
                id: log
                anchors { fill: parent; margins: 8 }
                clip: true
                model: ListModel { id: logModel }
                delegate: Label {
                    required property string line
                    text: line
                    dim: true
                    font.family: "monospace"
                    font.pixelSize: Theme.fontSizeSmall
                }
                function note(text: string) {
                    logModel.append({ line: new Date().toLocaleTimeString() + "  " + text });
                    if (logModel.count > 200)
                        logModel.remove(0);
                    positionViewAtEnd();
                }
                Connections {
                    target: dock
                    function onLayoutChanged() { log.note("layout changed, " + dock.manager.windows.length + " pop-out window(s)"); }
                }
                Connections {
                    target: params
                    function onEditFinished(parameter, committed) {
                        log.note((committed ? "edited " : "cancelled ") + parameter.name);
                    }
                }
            }
        }

        DockPanel {
            panelId: "palette"
            title: "Palette"
            area: Dock.Right
            openOnStart: false
            Grid {
                anchors { fill: parent; margins: 12 }
                columns: Math.max(1, Math.floor((width + 6) / 34))
                spacing: 6
                Repeater {
                    model: 24
                    delegate: Rectangle {
                        id: chip
                        required property int index
                        width: 28
                        height: 28
                        radius: Theme.controlRadius
                        color: Qt.hsla(index / 24, 0.6, 0.55, 1)
                        // Sets the fill of the selection: an edit made by the app, not a control.
                        TapHandler {
                            onTapped: {
                                const fill = window.inspected[window.parameterKeys.indexOf("fill")];
                                fill.beginEdit();
                                fill.setValue(chip.color);
                                fill.endEdit(true);
                            }
                        }
                    }
                }
            }
        }

        DockPanel {
            panelId: "help"
            title: "Help"
            area: Dock.Right
            openOnStart: false
            Label {
                anchors { fill: parent; margins: 12 }
                wrapMode: Text.Wrap
                dim: true
                lineHeight: 1.35
                text: "Panels\n"
                      + "Drag a tab to rearrange · drop it outside the window to pop it out · double-click a tab to maximize · "
                      + "drag a gap to resize, Ctrl-drag to move one segment.\n\n"
                      + "Values\n"
                      + "Drag a number or its label to change it (Shift ×10, Ctrl ×0.1, Esc cancels) · click to type; "
                      + "2*pi and +=10 work · Tab to a field, then Up/Down or the wheel · the dot resets to the default · "
                      + "right-click a row for more.\n\n"
                      + "Linking\n"
                      + "Type =cube.rotation * 2 to make a value follow another. Right-click › Copy Reference, then "
                      + "Paste as Link on another row. A linked value is violet and can't be dragged; type a number to unlink it."
            }
        }
    }
}
