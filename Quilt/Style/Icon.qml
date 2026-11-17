import QtQuick
import QtQuick.Shapes
import "Icons.js" as Icons

// A small line glyph drawn on a 12-unit grid.
//
//     Icon { name: "chevron-down" }
//     Icon { path: "M 2 6 H 10"; color: Theme.accent }     // your own
//
// Names: close, minimize, maximize, restore, popout, menu, more, grip,
// chevron-down/-up/-left/-right, arrow-down/-up/-left/-right, check, dash,
// plus, minus, undo, redo, reset, copy, trash, link, unlink, search, filter,
// settings, eye, eye-off, lock, unlock, info, help, warning, play, pause,
// stop, calendar, folder, file, grid, layers. `names` lists them. A theme
// may redraw any of them (Theme.icons) and sets the stroke and its caps.
Item {
    id: icon

    property string name
    property string path                    // SVG path data on a 12 x 12 grid; replaces `name`
    property color color: Theme.textSecondary
    property real size: Theme.glyphSize
    property real strokeWidth: Theme.iconStrokeWidth

    readonly property var names: Icons.names()

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.centerIn: parent
        width: 12
        height: 12
        scale: icon.size / 12
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: icon.color
            strokeWidth: icon.path === "" && Icons.dotted[icon.name] ? icon.strokeWidth + 0.4 : icon.strokeWidth
            fillColor: "transparent"
            capStyle: Theme.iconCap
            joinStyle: Theme._iconJoin
            PathSvg { path: icon.path !== "" ? icon.path : Icons.path(icon.name, Theme.icons) }
        }
    }
}
