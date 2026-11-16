pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// A row of dropdown menus. Qt's MenuBar API:
//
//     MenuBar {
//         Menu { title: "File"; Action { text: "Open…"; shortcut: StandardKey.Open; onTriggered: … } }
//         Menu { title: "Edit"; … }
//     }
//
// For a menu bar in the window's title bar, put the menus in a TitleBar.
T.MenuBar {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset, contentHeight + topPadding + bottomPadding)

    delegate: MenuBarItem { }

    contentItem: Row {
        spacing: control.spacing
        Repeater {
            model: control.contentModel
        }
    }

    background: Item {
        implicitHeight: Theme.controlHeight
    }
}
