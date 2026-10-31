// The smallest useful Quilt app. Run from the repository root:
//
//     qml6 -I . examples/minimal.qml
//
// Drag tabs to rearrange, drag a tab outside the window to pop it out,
// drag split gaps to resize, double-click a tab to maximize it.
import QtQuick
import QtQuick.Controls
import Quilt

ApplicationWindow {
    width: 1200
    height: 760
    minimumWidth: dock.minimumWidth
    minimumHeight: dock.minimumHeight
    visible: true
    title: "Quilt — minimal"
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

    DockArea {
        id: dock
        anchors.fill: parent

        DockPanel {
            panelId: "viewport"
            title: "Viewport"
            Rectangle {
                anchors.fill: parent
                color: "#0d0f12"
                Text { anchors.centerIn: parent; text: "Viewport"; color: "#5d6470"; font.pixelSize: 28 }
            }
        }

        DockPanel {
            panelId: "outliner"
            title: "Outliner"
            area: Dock.Left
            areaSize: 0.2
            ListView {
                anchors.fill: parent
                anchors.margins: 6
                model: 40
                delegate: Text { required property int index; text: "Object " + index; color: "#d7dae0"; padding: 4 }
            }
        }

        DockPanel {
            panelId: "inspector"
            title: "Inspector"
            area: Dock.Right
            minimumWidth: 220
            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                TextField { width: parent.width; placeholderText: "Name" }
                Slider { width: parent.width }
                CheckBox { text: "Visible" }
            }
        }

        DockPanel {
            panelId: "timeline"
            title: "Timeline"
            area: Dock.Bottom
            Text { anchors.centerIn: parent; text: "Timeline"; color: "#5d6470" }
        }
    }
}
