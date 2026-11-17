import QtQuick
import QtQuick.Shapes
import "Paint.js" as Paint

// The face of a knob: an arc from `origin` to `position` around a 270°
// scale with the gap at the bottom, and a pointer at the value. A theme
// redraws it with `skins.dial`. Provisional.
Item {
    id: dial

    property real position: 0           // 0..1 along the scale
    property real origin: 0             // 0..1 where the arc starts: 0.5 for a pan knob
    property bool mixed: false          // no arc, no pointer
    property bool driven: false
    property bool hovered: false
    property bool pressed: false        // being dragged
    property bool focused: false

    // Degrees, clockwise from 3 o'clock, as PathAngleArc counts them.
    readonly property real angle: 135 + 270 * position
    readonly property real originAngle: 135 + 270 * origin
    readonly property real r: Math.min(width, height) / 2 - 2.5

    readonly property color fill: hovered || pressed ? Theme.mix(Theme.controlFill, Theme.text, 0.12) : Theme.controlFill
    readonly property color ink: driven ? Theme.driven : Theme.accent
    readonly property color pointer: Theme.text

    readonly property Component painter: Theme.skins.dial
    readonly property bool skinned: painter !== null

    property Item _painted: null
    property Item _ring: null
    onPainterChanged: Paint.apply(dial, painter)
    onFocusedChanged: Paint.ring(dial, () => dial.focused, () => dial.width / 2, 1)
    Component.onCompleted: {
        if (painter)
            Paint.apply(dial, painter);
        if (focused)
            Paint.ring(dial, () => dial.focused, () => dial.width / 2, 1);
    }

    Shape {
        anchors.fill: parent
        visible: !dial.skinned
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: dial.fill
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: dial.width / 2; centerY: dial.height / 2
                radiusX: dial.r; radiusY: dial.r
                startAngle: 135; sweepAngle: 270
            }
        }
        ShapePath {
            strokeColor: dial.mixed ? "transparent" : dial.ink
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: dial.width / 2; centerY: dial.height / 2
                radiusX: dial.r; radiusY: dial.r
                startAngle: dial.originAngle; sweepAngle: dial.angle - dial.originAngle
            }
        }
    }

    // The pointer: a short line aimed at the value.
    Item {
        visible: !dial.mixed && !dial.skinned
        x: dial.width / 2
        y: dial.height / 2
        rotation: dial.angle
        transformOrigin: Item.TopLeft
        Rectangle {
            x: dial.r * 0.3
            y: -1
            width: dial.r * 0.7 - 3.5
            height: 2
            radius: height / 2
            color: dial.pointer
        }
    }
}
