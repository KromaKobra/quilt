import QtQuick
import Quilt
import Quilt.Controls
import CppHost

// A C++ application's window. The Shape is a C++ object (shape.h); the
// Inspector edits it through ordinary property bindings. Try typing a width
// of 1000, or switching "Locked" on: the fields show what the C++ setters
// made of the edit.
ApplicationWindow {
    id: window
    width: 1100
    height: 720
    minimumWidth: dock.minimumWidth
    minimumHeight: dock.minimumHeight + menus.height
    visible: true
    title: shape.name + " — Quilt C++ host"

    Shape { id: shape }

    function note(text: string) {
        log.append({ line: new Date().toLocaleTimeString(Qt.locale(), "hh:mm:ss") + "  " + text });
        if (log.count > 200)
            log.remove(0);
    }

    ListModel { id: log }

    // With the system's title bar left on, a TitleBar is simply the menu bar.
    menuBar: TitleBar {
        id: menus
        Menu {
            title: "&File"
            Action { text: "Quit"; shortcut: StandardKey.Quit; onTriggered: Qt.quit() }
        }
        Menu {
            title: "&View"
            Action { text: "Reset Layout"; onTriggered: dock.resetLayout() }
            Action { text: "Show Log"; onTriggered: dock.openPanel("log") }
            MenuSeparator { }
            Action { text: "Dark Theme"; checkable: true; checked: Theme.dark; onTriggered: Theme.dark = !Theme.dark }
        }
    }

    DockArea {
        id: dock
        anchors.fill: parent
        autoSaveKey: "main"             // the layout survives restarts

        DockPanel {
            panelId: "canvas"
            title: "Canvas"
            minimumWidth: 240
            minimumHeight: 160
            Item {
                anchors.fill: parent
                clip: true
                Rectangle {
                    anchors.centerIn: parent
                    width: shape.width
                    height: shape.height
                    rotation: shape.rotation
                    radius: Math.min(shape.corners, width / 2, height / 2)
                    color: shape.fill
                    opacity: shape.opacity
                }
            }
        }

        DockPanel {
            panelId: "inspector"
            title: "Inspector"
            area: Dock.Right
            areaSize: 0.28
            minimumWidth: 200

            Inspector {
                anchors.fill: parent

                PropertyRow {
                    label: "Name"
                    TextField { text: shape.name; onEdited: v => shape.name = v }
                }
                PropertyRow {
                    label: "Locked"
                    description: "A locked shape refuses every edit: the C++ setters ignore it."
                    Switch { checked: shape.locked; onEdited: v => shape.locked = v }
                }

                Section {
                    title: "Geometry"
                    key: "geometry"         // remembers open or closed between runs
                    PropertyRow {
                        label: "Width"
                        NumberField {
                            value: shape.width; defaultValue: 220; from: 8; to: 400; suffix: " px"
                            onEdited: v => shape.width = v
                            onEditFinished: committed => window.note((committed ? "width " : "cancelled width, still ") + shape.width)
                        }
                    }
                    PropertyRow {
                        label: "Height"
                        NumberField {
                            value: shape.height; defaultValue: 140; from: 8; to: 400; suffix: " px"
                            onEdited: v => shape.height = v
                            onEditFinished: committed => window.note((committed ? "height " : "cancelled height, still ") + shape.height)
                        }
                    }
                    PropertyRow {
                        label: "Rotation"
                        NumberField {
                            value: shape.rotation; defaultValue: 0; from: 0; to: 360; wrap: true; suffix: "°"
                            onEdited: v => shape.rotation = v
                        }
                    }
                }

                Section {
                    title: "Appearance"
                    key: "appearance"
                    PropertyRow {
                        label: "Fill"
                        ColorField { value: shape.fill; defaultValue: "#4c8dff"; alpha: false; onEdited: c => shape.fill = c }
                    }
                    PropertyRow {
                        label: "Opacity"
                        NumberField {
                            value: shape.opacity; defaultValue: 1; from: 0; to: 1; displayScale: 100; suffix: "%"; decimals: 0
                            onEdited: v => shape.opacity = v
                        }
                    }
                    PropertyRow {
                        label: "Corners"
                        NumberField {
                            value: shape.corners; defaultValue: 16; minimum: 0; integer: true; steppers: true
                            onEdited: v => shape.corners = v
                        }
                    }
                }
            }
        }

        DockPanel {
            panelId: "log"
            title: "Log"
            area: Dock.Bottom
            ListView {
                id: logView
                anchors { fill: parent; margins: 8 }
                clip: true
                model: log
                onCountChanged: positionViewAtEnd()
                ScrollBar.vertical: ScrollBar { }
                delegate: Label {
                    required property string line
                    text: line
                    dim: true
                    font.pixelSize: Theme.fontSizeSmall
                }
                Label {
                    anchors.centerIn: parent
                    visible: logView.count === 0
                    dim: true
                    text: "Edits to the width and height are listed here."
                }
            }
        }
    }
}
