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

    readonly property color _fill: {
        if (primary)
            return down ? Theme.mix(Theme.accent, Theme.accentInk, 0.18)
                        : hovered ? Theme.mix(Theme.accent, Theme.text, 0.12) : Theme.accent;
        if (down || checked)
            return Theme.controlFill;
        if (hovered)
            return Theme.controlHover;
        return flat ? "transparent" : Theme.control;
    }
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

    contentItem: Item {
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

    background: Rectangle {
        implicitWidth: 24
        radius: Theme.controlRadius
        color: control._fill
        border.width: control.primary ? 0 : 1
        border.color: Theme.controlBorder

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
}
