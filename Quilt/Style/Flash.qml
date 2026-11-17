import QtQuick

// The accent flash over a field whose value Quilt corrected (see
// Paint.flash).
Rectangle {
    id: flash

    function run() { animation.restart(); }

    anchors.fill: parent
    color: Theme.accent
    opacity: 0
    visible: opacity > 0

    SequentialAnimation {
        id: animation
        NumberAnimation { target: flash; property: "opacity"; from: 0; to: 0.4; duration: Theme.durationFast * 0.75 }
        NumberAnimation { target: flash; property: "opacity"; to: 0; duration: Theme.durationFast * 4; easing.type: Theme.easing }
    }
}
