import QtQuick
import QtQuick.Controls

// Minimal Quilt demo using the declarative API: define PanelModels with a
// dockPosition, hand them to DockContainer, done. Run from the repo root:
//
//     qml -I . example/simple.qml
import Quilt

ApplicationWindow {
    id: win
    visible: true
    width: 1100
    height: 700
    title: "Quilt — Declarative Demo"
    color: "#16171a"

    Component {
        id: label
        Rectangle {
            color: "transparent"
            // The content Loader (see Panel.qml) exposes the model as `panelModel`.
            // qmllint disable missing-property
            property var pm: parent ? parent.panelModel : null
            // qmllint enable missing-property
            Text {
                anchors.centerIn: parent
                text: parent.pm ? parent.pm.title : ""
                color: "#e7e9ec"
                font.pixelSize: 16
                font.bold: true
            }
        }
    }

    PanelModel {
        id: editorPanel
        panelId: "editor"; title: "Editor"
        dockPosition: DockEnums.Center
        contentComponent: label
    }
    PanelModel {
        id: previewPanel
        panelId: "preview"; title: "Preview"
        dockPosition: DockEnums.Center       // stacks with the editor as a tab
        contentComponent: label
    }
    PanelModel {
        id: sidebarPanel
        panelId: "sidebar"; title: "Sidebar"
        dockPosition: DockEnums.Left; splitRatio: 0.22
        panelStyle: DockEnums.Connected; cornerRadius: 4
        minWidth: 160
        contentComponent: label
    }
    PanelModel {
        id: logPanel
        panelId: "log"; title: "Log"
        dockPosition: DockEnums.Bottom; splitRatio: 0.25
        minHeight: 100
        contentComponent: label
    }

    DockContainer {
        anchors.fill: parent
        panels: [editorPanel, previewPanel, sidebarPanel, logPanel]
        // Set to true to restore the layout from the previous session instead
        // of starting from the panels' dockPositions.
        autoRestoreLayout: false
    }
}
