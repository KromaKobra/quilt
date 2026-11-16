import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// A square button that shows one Icon. An icon alone is a guess, so give
// it a `tip`:
//
//     IconButton { iconName: "reset"; tip: "Reset view"; onClicked: view.reset() }
T.AbstractButton {
    id: control

    property string iconName
    property string iconPath                    // or your own 12 x 12 path data
    property string tip
    property color color: Theme.textSecondary

    implicitWidth: Theme.controlHeight
    implicitHeight: Theme.controlHeight
    hoverEnabled: true
    opacity: enabled ? 1 : 0.5

    // A checkable button goes back to showing what its `checked` is bound to.
    onToggled: Qt.callLater(rebind.refresh)
    Rebind { id: rebind; target: control; property: "checked" }

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            name: control.iconName
            path: control.iconPath !== "" ? control.iconPath : (paths[name] ?? "")
            color: control.checked ? Theme.accent
                 : control.hovered || control.down ? Theme.text : control.color
        }
    }

    background: Rectangle {
        radius: Theme.controlRadius
        color: control.down || control.checked ? Theme.controlFill
             : control.hovered ? Theme.controlHover : "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.width: Theme.focusWidth
            border.pixelAligned: false
            border.color: Theme.accent
            visible: control.visualFocus
        }
    }

    Tip { text: control.tip; shown: control.hovered && !control.down }
}
