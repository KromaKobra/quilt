pragma ComponentBehavior: Bound

// Quilt sandbox: a manual test bench that exercises every feature.
//
//     qml6 -I . examples/sandbox.qml
//
// Panels hold live state (text, scroll position, a running animation,
// counters) so you can see it survive every move, tab switch, pop-out and
// close/reopen. "Tools", "Status" and "Palette" show the restriction flags.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quilt

ApplicationWindow {
    id: window
    width: 1440
    height: 900
    minimumWidth: dock.minimumWidth
    minimumHeight: dock.minimumHeight + header.height
    visible: true
    title: "Quilt sandbox" + (dock.activePanel ? " — " + dock.activePanel.title : "")
    color: dock.style.background

    // Dark palette so the stock Controls match the dock theme.
    palette {
        window: dock.style.background
        windowText: dock.style.text
        base: "#15171b"
        alternateBase: "#1a1d22"
        text: dock.style.text
        button: "#2a2e36"
        buttonText: dock.style.text
        light: "#3a3f48"
        midlight: "#30343c"
        mid: "#262a31"
        dark: "#101215"
        highlight: dock.style.accent
        highlightedText: "#ffffff"
        placeholderText: dock.style.textDim
        toolTipBase: "#2a2e36"
        toolTipText: dock.style.text
    }

    property var savedLayout: null
    property int documentCount: 0

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

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            spacing: 2

            ToolButton {
                text: "Panels ▾"
                onClicked: panelsMenu.popup(this, 0, height)
                Menu {
                    id: panelsMenu
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
                                checked = Qt.binding(() => !!panel && panel.isOpen);
                            }
                        }
                        onObjectAdded: (index, object) => panelsMenu.insertItem(index, object)
                        onObjectRemoved: (index, object) => panelsMenu.removeItem(object)
                    }
                }
            }
            ToolButton { text: "New document"; onClicked: window.newDocument() }
            ToolSeparator { }
            ToolButton { text: "Save layout"; onClicked: window.savedLayout = dock.saveLayout() }
            ToolButton { text: "Restore"; enabled: window.savedLayout !== null; onClicked: dock.restoreLayout(window.savedLayout) }
            ToolButton { text: "Reset"; onClicked: dock.resetLayout() }
            ToolButton { text: "2×2 grid"; onClicked: window.gridDemo() }
            Item { Layout.fillWidth: true }
            Label {
                text: "drag tabs to rearrange · drop outside to pop out · Ctrl-drag a split line to move one segment"
                opacity: 0.55
                Layout.rightMargin: 10
            }
        }
    }

    Component {
        id: documentComponent
        DockPanel {
            title: "Untitled"
            ScrollView {
                anchors.fill: parent
                TextArea { placeholderText: "Type something, then move this tab around…"; wrapMode: TextEdit.Wrap }
            }
        }
    }

    DockArea {
        id: dock
        anchors.fill: parent

        // Explicit starting layout. Panels it leaves out ("Palette") are
        // placed by their `area` hint when opened.
        defaultLayout: ({
            row: [
                { tabs: ["tools"], size: 0.04 },
                { tabs: ["outliner", "layout"], size: 0.18 },
                { column: [
                    { tabs: ["viewport", "glass"], size: 0.72 },
                    { tabs: ["timeline", "console"] }
                ] },
                { column: [
                    { tabs: ["inspector", "notes"], size: 0.7 },
                    { tabs: ["status"] }
                ], size: 0.22 }
            ]
        })

        // Pop-out windows get a small toolbar of their own.
        windowComponent: Component {
            DockWindow {
                id: popout
                header: ToolBar {
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        Label { text: "Pop-out: " + popout.dockArea.title; elide: Text.ElideRight; Layout.fillWidth: true }
                        ToolButton { text: "Close window"; onClicked: popout.close() }
                    }
                }
            }
        }

        DockPanel {
            panelId: "viewport"
            title: "Viewport"
            minimumWidth: 240
            minimumHeight: 160
            Rectangle {
                anchors.fill: parent
                color: "#0c0e11"
                Rectangle {
                    width: 90; height: 90; radius: 12
                    anchors.centerIn: parent
                    color: dock.style.accent
                    NumberAnimation on rotation { from: 0; to: 360; duration: 4000; loops: Animation.Infinite }
                }
                Text {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 10 }
                    color: "#7f8591"
                    text: "frame " + frames.count + " — the animation never restarts"
                    Timer { id: frames; property int count: 0; interval: 33; running: true; repeat: true; onTriggered: count += 1 }
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
                text: "background: \"transparent\" — whatever is behind the dock area shows through."
                opacity: 0.7
            }
        }

        DockPanel {
            panelId: "outliner"
            title: "Outliner"
            area: Dock.Left
            ListView {
                anchors.fill: parent
                clip: true
                model: 300
                ScrollBar.vertical: ScrollBar { }
                delegate: ItemDelegate {
                    required property int index
                    width: ListView.view.width
                    text: "Object " + index
                }
            }
        }

        DockPanel {
            panelId: "layout"
            title: "Layout JSON"
            area: Dock.Left
            ScrollView {
                anchors.fill: parent
                TextArea {
                    id: layoutJson
                    readOnly: true
                    font.family: "monospace"
                    font.pixelSize: 11
                    function refresh() { text = JSON.stringify(dock.saveLayout(), null, 2); }
                    Connections { target: dock; function onLayoutChanged() { layoutJson.refresh(); } }
                    Component.onCompleted: refresh()
                }
            }
        }

        DockPanel {
            panelId: "tools"
            title: "Tools"
            area: Dock.Left
            minimumWidth: 52
            maximumWidth: 52                    // fixed width
            closable: false
            tabbable: false                     // its own group, with a plain title bar
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 6
                spacing: 4
                Repeater {
                    model: ["↖", "✥", "⟳", "⤡", "✎"]
                    delegate: ToolButton { required property string modelData; text: modelData; checkable: true; width: 40 }
                }
            }
        }

        DockPanel {
            panelId: "inspector"
            title: "Inspector"
            area: Dock.Right
            minimumWidth: 220
            ColumnLayout {
                anchors { fill: parent; margins: 12 }
                spacing: 8
                TextField { Layout.fillWidth: true; placeholderText: "Name" }
                Label { text: "Opacity " + opacitySlider.value.toFixed(2) }
                Slider { id: opacitySlider; Layout.fillWidth: true; value: 0.5 }
                SpinBox { value: 42 }
                CheckBox { text: "Visible"; checked: true }
                Button {
                    property int clicks: 0
                    text: "Clicked " + clicks + "×"
                    onClicked: clicks += 1
                }
                Item { Layout.fillHeight: true }
            }
        }

        DockPanel {
            panelId: "notes"
            title: "Notes"
            area: Dock.Right
            ScrollView {
                anchors.fill: parent
                TextArea { placeholderText: "Notes survive moves, pop-outs and close/reopen."; wrapMode: TextEdit.Wrap }
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
                opacity: 0.75
                text: "movable: false · floatable: false · closable: false\nActive panel: "
                      + (dock.activePanel ? dock.activePanel.title : "none")
            }
        }

        DockPanel {
            panelId: "timeline"
            title: "Timeline"
            area: Dock.Bottom
            minimumHeight: 90
            RowLayout {
                anchors { fill: parent; margins: 10 }
                Button {
                    text: playing.running ? "Pause" : "Play"
                    onClicked: playing.running = !playing.running
                    Timer { id: playing; interval: 40; repeat: true; onTriggered: scrub.value = (scrub.value + 1) % 241 }
                }
                Slider { id: scrub; Layout.fillWidth: true; from: 0; to: 240; stepSize: 1 }
                Label { text: "frame " + scrub.value }
            }
        }

        DockPanel {
            panelId: "console"
            title: "Console"
            area: Dock.Bottom
            ListView {
                id: log
                anchors { fill: parent; margins: 6 }
                clip: true
                model: ListModel { id: logModel }
                delegate: Label { required property string line; text: line; font.family: "monospace"; font.pixelSize: 11; opacity: 0.8 }
                Connections {
                    target: dock
                    function onLayoutChanged() {
                        logModel.append({ line: new Date().toLocaleTimeString() + "  layout changed — "
                                                + dock.manager.windows.length + " pop-out window(s)" });
                        if (logModel.count > 200)
                            logModel.remove(0);
                        log.positionViewAtEnd();
                    }
                }
            }
        }

        DockPanel {
            panelId: "palette"
            title: "Palette"
            area: Dock.Right
            openOnStart: false
            floatable: true
            Grid {
                anchors { fill: parent; margins: 10 }
                columns: 6
                spacing: 6
                Repeater {
                    model: 24
                    delegate: Rectangle {
                        required property int index
                        width: 28; height: 28; radius: 4
                        color: Qt.hsla(index / 24, 0.6, 0.55, 1)
                    }
                }
            }
        }
    }
}
