import QtQuick
import QtQuick.Templates as T

// One row of a Menu. Shows the action's shortcut at the right, a tick when
// checked, and an arrow when it opens a submenu.
T.MenuItem {
    id: control

    // Shown at the right instead of the action's shortcut.
    property string shortcutText: shortcut.nativeText
    // Set by Menu: room for the tick, when any row of the menu can be ticked.
    property real leadingWidth: 0

    readonly property string _label: control.text.replace(/&(.)/g, "$1")     // drop mnemonic markers

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Theme.controlHeight + 2

    leftPadding: 8 + leadingWidth
    rightPadding: 8 + (control.subMenu ? 16 : 0)
    verticalPadding: 0

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    contentItem: Item {
        implicitWidth: label.implicitWidth + (keys.visible ? keys.implicitWidth + 28 : 0)
        implicitHeight: label.implicitHeight

        Text {
            id: label
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: Math.min(implicitWidth, parent.width - (keys.visible ? keys.implicitWidth + 12 : 0))
            text: control._label
            font: control.font
            renderType: Theme.textRenderType
            elide: Text.ElideRight
            color: control.enabled ? Theme.text : Theme.textTertiary
        }
        Text {
            id: keys
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: text !== "" && !control.subMenu
            text: control.shortcutText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            renderType: Theme.textRenderType
            color: Theme.textTertiary
        }
    }

    indicator: Icon {
        x: 8
        y: Math.round((control.height - height) / 2)
        name: "check"
        color: control.enabled ? Theme.text : Theme.textTertiary
        visible: control.checked
    }

    arrow: Icon {
        x: control.width - width - 8
        y: Math.round((control.height - height) / 2)
        name: "chevron-right"
        size: 10
        color: control.enabled ? Theme.textSecondary : Theme.textTertiary
        visible: !!control.subMenu
    }

    background: Face {
        implicitWidth: 120
        implicitHeight: 0
        role: Face.Item
        hovered: control.highlighted && control.enabled
    }

    // A checkable row goes back to showing what its `checked` is bound to.
    onToggled: Qt.callLater(rebind.refresh)
    Rebind { id: rebind; target: control; property: "checked" }

    Shortcut {
        id: shortcut
        enabled: false                          // only here to format the key sequence
        sequences: control.action && control.action.shortcut !== undefined ? [control.action.shortcut] : []
    }
}
