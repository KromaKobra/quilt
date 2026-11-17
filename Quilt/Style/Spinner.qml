import QtQuick
import QtQuick.Shapes
import "Paint.js" as Paint

// The turning wheel of a busy indicator. It turns while `running`. A theme
// redraws it with `skins.spinner`; that painter animates itself, and stops
// when the host's `running` goes false. Provisional.
Item {
    id: spinner

    property bool running: false
    property color color: Theme.textSecondary

    readonly property Component painter: Theme.skins.spinner
    readonly property bool skinned: painter !== null

    property Item _painted: null
    onPainterChanged: Paint.apply(spinner, painter)
    Component.onCompleted: if (painter) Paint.apply(spinner, painter)

    Shape {
        anchors.centerIn: parent
        visible: !spinner.skinned
        width: 16
        height: 16
        scale: Math.min(spinner.width, spinner.height) / 16
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: spinner.color
            strokeWidth: 1.8
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 8; centerY: 8; radiusX: 6; radiusY: 6; startAngle: 0; sweepAngle: 270 }
        }
        // On the render thread: a spinner that freezes says "crashed".
        RotationAnimator on rotation {
            running: spinner.running && !spinner.skinned
            from: 0
            to: 360
            duration: 800
            loops: Animation.Infinite
        }
    }
}
