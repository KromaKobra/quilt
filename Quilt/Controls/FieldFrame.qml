import QtQuick
import Quilt.Style

// The background of a field: a flat fill, a ring for focus or an error,
// and a brief flash for when Quilt corrected what the user entered.
Rectangle {
    id: frame

    property bool hovered: false
    property bool focused: false
    property bool invalid: false
    property bool flat: false           // no fill: a read-only value, or a field inside another

    function flash() { flashAnimation.restart(); }

    implicitHeight: Theme.controlHeight
    radius: Theme.controlRadius
    color: flat ? "transparent" : (hovered ? Theme.controlHover : Theme.control)
    border.width: flat ? 0 : 1
    border.color: Theme.controlBorder

    // Hover arrives at once and leaves softly.
    Behavior on color {
        enabled: !frame.hovered && Theme.durationFast > 0
        ColorAnimation { duration: Theme.durationFast }
    }

    Rectangle {
        id: flashFill
        anchors.fill: parent
        radius: parent.radius
        color: Theme.accent
        opacity: 0
        visible: opacity > 0
        SequentialAnimation {
            id: flashAnimation
            NumberAnimation { target: flashFill; property: "opacity"; from: 0; to: 0.4; duration: 60 }
            NumberAnimation { target: flashFill; property: "opacity"; to: 0; duration: 320; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: parent.radius + 1
        color: "transparent"
        border.width: Theme.focusWidth
        border.pixelAligned: false
        border.color: frame.invalid ? Theme.error : Theme.accent
        visible: frame.focused || frame.invalid
    }
}
