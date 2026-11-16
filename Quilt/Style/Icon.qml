import QtQuick
import QtQuick.Shapes

// A small line glyph drawn on a 12-unit grid.
//
//     Icon { name: "chevron-down" }
//     Icon { path: "M 2 6 H 10"; color: Theme.accent }     // your own
//
// Names: close, minimize, maximize, restore, popout, chevron-down,
// chevron-up, chevron-right, chevron-left, check, dash, plus, minus, link,
// unlink, reset, search, more, menu, calendar.
Item {
    id: icon

    property string name
    property string path: icon.paths[name] ?? ""    // SVG path data on a 12 x 12 grid
    property color color: Theme.textSecondary
    property real size: Theme.glyphSize
    property real strokeWidth: 1.3

    readonly property var paths: ({
        "close": "M 2.5 2.5 L 9.5 9.5 M 9.5 2.5 L 2.5 9.5",
        "minimize": "M 2 6 H 10",
        "maximize": "M 2.5 2.5 H 9.5 V 9.5 H 2.5 Z",
        "restore": "M 2 4.5 H 7.5 V 10 H 2 Z M 4.5 4.5 V 2 H 10 V 7.5 H 7.5",
        "popout": "M 5 2 H 2 V 10 H 10 V 7 M 7 2 H 10 V 5 M 10 2 L 5.5 6.5",
        "chevron-down": "M 2.5 4.5 L 6 8 L 9.5 4.5",
        "chevron-up": "M 2.5 7.5 L 6 4 L 9.5 7.5",
        "chevron-right": "M 4.5 2.5 L 8 6 L 4.5 9.5",
        "chevron-left": "M 7.5 2.5 L 4 6 L 7.5 9.5",
        "check": "M 2.5 6.3 L 5 8.8 L 9.5 3.4",
        "dash": "M 3 6 H 9",
        "plus": "M 6 2.5 V 9.5 M 2.5 6 H 9.5",
        "minus": "M 2.5 6 H 9.5",
        "link": "M 4.8 7.2 L 7.2 4.8 M 4.4 5 L 3.1 6.3 A 1.85 1.85 0 0 0 5.7 8.9 L 7 7.6 M 7.6 7 L 8.9 5.7 A 1.85 1.85 0 0 0 6.3 3.1 L 5 4.4",
        "unlink": "M 4.4 5 L 3.1 6.3 A 1.85 1.85 0 0 0 5.7 8.9 L 7 7.6 M 7.6 7 L 8.9 5.7 A 1.85 1.85 0 0 0 6.3 3.1 L 5 4.4",
        "reset": "M 2.6 6.4 A 3.4 3.4 0 1 0 3.6 3.6 M 2.4 1.9 V 3.9 H 4.4",
        "search": "M 2 5.2 A 3.2 3.2 0 1 0 8.4 5.2 A 3.2 3.2 0 1 0 2 5.2 M 7.6 7.6 L 10 10",
        "more": "M 2.5 6 H 2.51 M 6 6 H 6.01 M 9.5 6 H 9.51",
        "menu": "M 2 3.5 H 10 M 2 6 H 10 M 2 8.5 H 10",
        "calendar": "M 2 3.5 H 10 V 10 H 2 Z M 2 5.7 H 10 M 4.2 2 V 4 M 7.8 2 V 4"
    })

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
            strokeWidth: icon.name === "more" ? 1.7 : icon.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.path }
        }
    }
}
