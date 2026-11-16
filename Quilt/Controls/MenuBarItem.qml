import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// One title in a MenuBar.
T.MenuBarItem {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Theme.controlHeight
    horizontalPadding: 9
    verticalPadding: 0

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    contentItem: Text {
        text: control.text.replace(/&(.)/g, "$1")      // drop mnemonic markers
        font: control.font
        renderType: Theme.textRenderType
        color: !control.enabled ? Theme.textTertiary
             : control.highlighted || control.down ? Theme.text : Theme.textSecondary
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
    }

    background: Rectangle {
        implicitHeight: Theme.controlHeight
        radius: Theme.controlRadius
        color: control.down || control.highlighted ? Theme.controlHover : "transparent"
    }
}
