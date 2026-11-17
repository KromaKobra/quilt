import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// A push button. Qt's Button API, plus:
//   primary   the one main action of a view; drawn in the accent colour
//   iconName  an Icon name shown before the text
T.Button {
    id: control

    property bool primary: false
    property string iconName

    readonly property color _ink: !enabled ? Theme.textTertiary : primary ? Theme.accentInk : Theme.text

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Theme.controlHeight

    horizontalPadding: 12
    verticalPadding: 0
    spacing: 6
    hoverEnabled: true
    opacity: enabled ? 1 : 0.5

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    // A checkable button goes back to showing what its `checked` is bound to.
    onToggled: Qt.callLater(rebind.refresh)
    Rebind { id: rebind; target: control; property: "checked" }

    // Pressed, the face and its label sink (Theme.pressTravel); what
    // takes the click stays put.
    Translate { id: travel; y: control.down ? Theme.pressTravel : 0 }

    contentItem: Item {
        transform: travel
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight
        Row {
            id: row
            anchors.centerIn: parent
            spacing: control.spacing
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: control.iconName !== ""
                name: control.iconName
                color: control._ink
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: control.text.replace(/&(.)/g, "$1")
                font: control.font
                renderType: Theme.textRenderType
                color: control._ink
            }
        }
    }

    background: Face {
        implicitWidth: 24
        transform: travel
        role: control.primary ? Face.Primary : Face.Button
        hovered: control.hovered
        pressed: control.down
        checked: control.checked
        flat: control.flat
        focused: control.visualFocus
        focusRing: true
    }
}
