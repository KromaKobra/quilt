import QtQuick
import QtQuick.Controls
import Quilt

ApplicationWindow {
    width: 1100
    height: 720
    minimumWidth: dock.minimumWidth
    minimumHeight: dock.minimumHeight + header.height
    visible: true
    title: "Quilt C++ host"
    color: dock.style.background

    header: ToolBar {
        Row {
            ToolButton { text: "Reset layout"; onClicked: dock.resetLayout() }
            ToolButton { text: "Show log"; onClicked: dock.openPanel("log") }
        }
    }

    DockArea {
        id: dock
        anchors.fill: parent
        autoSaveKey: "main"             // layout survives restarts

        DockPanel {
            panelId: "editor"
            title: "Editor"
            ScrollView {
                anchors.fill: parent
                TextArea { placeholderText: "Edit me, then move this panel around." }
            }
        }
        DockPanel {
            panelId: "files"
            title: "Files"
            area: Dock.Left
            areaSize: 0.22
            ListView {
                anchors.fill: parent
                model: 50
                delegate: ItemDelegate { required property int index; width: ListView.view.width; text: "file_" + index + ".txt" }
            }
        }
        DockPanel {
            panelId: "log"
            title: "Log"
            area: Dock.Bottom
            Label { anchors.centerIn: parent; text: "Log output" }
        }
    }
}
