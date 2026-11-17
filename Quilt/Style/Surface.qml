import QtQuick
import "Paint.js" as Paint

// A surface something sits on: the window's canvas, a docked panel, a popup,
// a tooltip, the title bar, or the overlay over everything. `slot` says
// which, and so which painter of the theme's `skins` redraws it:
//
//     Surface { slot: "popup"; fill: Theme.raised; edge: Theme.border; radius: Theme.radius }
//
// Without a painter it is a plain rectangle in `fill` and `edge`. A panel
// draws its tab strip as `header`, a strip of `headerFill` along the top.
// Provisional: the properties may change in the next release.
Rectangle {
    id: surface

    property string slot: "panel"       // canvas | panel | popup | toolTip | bar | overlay
    property color fill: "transparent"
    property color edge: "transparent"
    property real edgeWidth: 1
    property real header: 0             // height of the tab strip, for a panel
    property color headerFill: fill
    property bool active: false         // a panel that holds the focus; an active window's bar

    readonly property Component painter: {
        const s = Theme.skins;
        switch (slot) {
        case "canvas": return s.canvas;
        case "panel": return s.panel;
        case "popup": return s.popup;
        case "toolTip": return s.toolTip ?? s.popup;
        case "bar": return s.bar;
        case "overlay": return s.overlay;
        default: return null;
        }
    }
    readonly property bool skinned: painter !== null

    color: skinned ? "transparent" : fill
    border.color: edge
    border.width: skinned ? 0 : edgeWidth

    property Item _painted: null
    onPainterChanged: Paint.apply(surface, painter)
    Component.onCompleted: if (painter) Paint.apply(surface, painter)
}
