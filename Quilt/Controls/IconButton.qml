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

    Accessible.name: tip                        // an icon has no text of its own

    // A checkable button goes back to showing what its `checked` is bound to.
    onToggled: Qt.callLater(rebind.refresh)
    Rebind { id: rebind; target: control; property: "checked" }

    Translate { id: travel; y: control.down ? Theme.pressTravel : 0 }

    contentItem: Item {
        transform: travel
        Icon {
            anchors.centerIn: parent
            name: control.iconName
            path: control.iconPath
            color: control.checked ? Theme.accent
                 : control.hovered || control.down ? Theme.text : control.color
        }
    }

    background: Face {
        transform: travel
        role: Face.Tool
        hovered: control.hovered
        pressed: control.down
        checked: control.checked
        focused: control.visualFocus
        focusRing: true
    }

    Tip { text: control.tip; shown: control.hovered; pressed: control.down }
}
