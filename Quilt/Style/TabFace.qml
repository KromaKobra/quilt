import QtQuick
import "Paint.js" as Paint

// What marks a tab in a panel's tab strip: an underline under the current
// one, in the accent when its panel is the active one. It covers the whole
// tab, so a theme's painter (`skins.tab`) may mark it any way it likes.
// Provisional.
Item {
    id: tab

    property bool current: false
    property bool active: false         // current, and its panel holds the focus
    property bool hovered: false
    property real inset: 10             // from each side to the title
    property color accent: Theme.accent
    property color faint: Theme.textTertiary

    readonly property color ink: active ? accent : faint

    readonly property Component painter: Theme.skins.tab
    readonly property bool skinned: painter !== null

    property Item _painted: null
    onPainterChanged: Paint.apply(tab, painter)
    Component.onCompleted: if (painter) Paint.apply(tab, painter)

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: tab.inset; rightMargin: tab.inset }
        height: 2
        radius: height / 2
        color: tab.ink
        visible: tab.current && !tab.skinned
    }
}
