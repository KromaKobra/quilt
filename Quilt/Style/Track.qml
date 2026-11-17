import QtQuick
import "Paint.js" as Paint

// The groove of a slider or progress bar, filled from its start up to
// `position`. `inset` keeps the fill's end under the centre of a thumb that
// can't leave the groove. With `indeterminate` a short run of fill sweeps
// along it instead. A theme redraws it with `skins.track`. Provisional.
Rectangle {
    id: track

    property bool horizontal: true
    property real position: 0           // 0..1
    property real inset: 0              // where position 0 and 1 fall, in from each end
    property bool indeterminate: false
    property bool animated: false       // the fill eases to a new position (a progress bar)
    property bool mixed: false          // no fill: the selection holds different values
    property bool driven: false
    property bool hovered: false
    property bool pressed: false

    readonly property real length: horizontal ? width : height
    // Pixels of fill from the start. Override it to round.
    property real fillLength: inset + position * (length - 2 * inset)
    Behavior on fillLength { enabled: track.animated; NumberAnimation { duration: Theme.duration; easing.type: Theme.easing } }

    readonly property color fill: Theme.controlFill
    readonly property color ink: driven ? Theme.driven : Theme.accent       // the filled part

    readonly property Component painter: Theme.skins.track
    readonly property bool skinned: painter !== null

    radius: Math.min(width, height) / 2
    color: skinned ? "transparent" : fill

    property Item _painted: null
    onPainterChanged: Paint.apply(track, painter)
    Component.onCompleted: if (painter) Paint.apply(track, painter)

    Rectangle {
        visible: !track.mixed && !track.indeterminate && !track.skinned
        y: track.horizontal ? 0 : track.height - height
        width: track.horizontal ? track.fillLength : track.width
        height: track.horizontal ? track.height : track.fillLength
        radius: track.radius
        color: track.ink
    }

    Item {
        anchors.fill: parent
        clip: true
        visible: track.indeterminate && !track.skinned
        Rectangle {
            id: runner
            width: parent.width * 0.3
            height: parent.height
            radius: height / 2
            color: track.ink
            // On the render thread: it keeps moving while the application is busy.
            XAnimator on x {
                running: track.indeterminate && track.visible && !track.skinned
                from: -runner.width
                to: track.width
                duration: 1100
                loops: Animation.Infinite
                easing.type: Easing.InOutCubic
            }
        }
    }
}
