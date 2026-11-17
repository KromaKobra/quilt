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

    background: Track {
        position: control.visualPosition
        fillLength: Math.round(control.visualPosition * width)
        animated: true
        indeterminate: control.indeterminate
    }

    contentItem: Item { }
}
