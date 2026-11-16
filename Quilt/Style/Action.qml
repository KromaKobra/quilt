import QtQml
import QtQuick.Templates as T

// Qt's Action, so that menus need no other import:
//
//     Menu { Action { text: "Open…"; shortcut: StandardKey.Open; onTriggered: openFile() } }
//
// A checkable action can simply be bound to the application's state. It
// shows that state again after every click, even one that changed nothing:
//
//     Action { text: "Grid"; checkable: true; checked: view.grid; onTriggered: view.grid = !view.grid }
T.Action {
    id: action

    onToggled: Qt.callLater(_rebind.refresh)

    property Rebind _rebind: Rebind {
        target: action
        property: "checked"
    }
}
