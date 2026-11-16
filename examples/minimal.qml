// The smallest useful Quilt app: four docked panels, one of them an
// inspector that edits a shape. Run from the repository root:
//
//     qml6 -I . examples/minimal.qml
//
// Drag tabs to rearrange, drag a tab outside the window to pop it out,
// drag split gaps to resize, double-click a tab to maximize it. In the
// inspector, drag a number sideways, or click it and type.
import QtQuick
import Quilt
import Quilt.Controls

ApplicationWindow {
    width: 1200
    height: 760
    minimumWidth: dock.minimumWidth
    minimumHeight: dock.minimumHeight
    visible: true
    title: "Quilt — minimal"

    // The application's data. Quilt never keeps a copy of it.
    QtObject {
        id: box
        property string name: "Box"
        property real size: 160
        property real angle: 15
        property color fill: "#4c8dff"
        property bool visible: true
    }

    DockArea {
        id: dock
        anchors.fill: parent

        DockPanel {
            panelId: "viewport"
            title: "Viewport"
            Rectangle {
                anchors.centerIn: parent
                width: box.size
                height: box.size
                rotation: box.angle
                radius: 12
                color: box.fill
                visible: box.visible
            }
        }

        DockPanel {
            panelId: "outliner"
            title: "Outliner"
            area: Dock.Left
            areaSize: 0.2
            ListView {
                anchors { fill: parent; margins: 8 }
                clip: true
                model: 40
                delegate: Label { required property int index; text: "Object " + index; dim: true; padding: 4 }
            }
        }

        DockPanel {
            panelId: "inspector"
            title: "Inspector"
            area: Dock.Right
            minimumWidth: 220
            Inspector {
                anchors.fill: parent
                PropertyRow { label: "Name"; TextField { text: box.name; onEdited: v => box.name = v } }
                Section {
                    title: "Shape"
                    PropertyRow {
                        label: "Size"
                        NumberField { value: box.size; defaultValue: 160; from: 10; to: 400; suffix: " px"; onEdited: v => box.size = v }
                    }
                    PropertyRow {
                        label: "Angle"
                        NumberField { value: box.angle; defaultValue: 0; from: 0; to: 360; wrap: true; suffix: "°"; onEdited: v => box.angle = v }
                    }
                    PropertyRow { label: "Fill"; ColorField { value: box.fill; alpha: false; onEdited: c => box.fill = c } }
                    PropertyRow { label: "Visible"; CheckBox { checked: box.visible; onEdited: v => box.visible = v } }
                }
            }
        }

        DockPanel {
            panelId: "timeline"
            title: "Timeline"
            area: Dock.Bottom
            Label { anchors.centerIn: parent; text: "Timeline"; dim: true }
        }
    }
}
