import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// Progress of a task. Qt's ProgressBar API. It eases between values, so it
// never jumps, and with indeterminate: true it shows that work is going on
// without saying how much.
T.ProgressBar {
    id: control

    implicitWidth: 140
    implicitHeight: 4

    background: Rectangle {
        radius: height / 2
        color: Theme.controlFill
    }

    contentItem: Item {
        clip: true

        Rectangle {
            visible: !control.indeterminate
            width: Math.round(control.visualPosition * parent.width)
            height: parent.height
            radius: height / 2
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            id: runner
            visible: control.indeterminate
            width: parent.width * 0.3
            height: parent.height
            radius: height / 2
            color: Theme.accent
            // On the render thread: it keeps moving while the application is busy.
            XAnimator on x {
                running: control.indeterminate && control.visible
                from: -runner.width
                to: control.width
                duration: 1100
                loops: Animation.Infinite
                easing.type: Easing.InOutCubic
            }
        }
    }
}
