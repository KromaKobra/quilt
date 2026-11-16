import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// An overlay scroll bar: it takes no room, so content doesn't shift when it
// appears. Hidden at rest; shown while scrolling or under the pointer.
//
//     Flickable { ScrollBar.vertical: ScrollBar { } }
//
// Set policy: ScrollBar.AlwaysOn to keep it visible.
T.ScrollBar {
    id: control

    readonly property bool _shown: policy === T.ScrollBar.AlwaysOn
                                   || (policy === T.ScrollBar.AsNeeded && size < 1.0 && (active || hovered || pressed))

    implicitWidth: horizontal ? 0 : 10
    implicitHeight: horizontal ? 10 : 0
    padding: 2
    minimumSize: 24 / Math.max(24, horizontal ? availableWidth : availableHeight)   // the thumb is never shorter than 24 px
    hoverEnabled: true
    visible: policy !== T.ScrollBar.AlwaysOff && size < 1.0

    contentItem: Item {
        implicitWidth: 6
        implicitHeight: 6
        opacity: control._shown ? 1 : 0
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: control._shown ? 0 : 700 }
                NumberAnimation { duration: Theme.duration }
            }
        }

        // Thin at rest, full width under the pointer.
        Rectangle {
            property real thickness: control.hovered || control.pressed ? 6 : 3
            x: control.horizontal ? 0 : parent.width - width
            y: control.horizontal ? parent.height - height : 0
            width: control.horizontal ? parent.width : thickness
            height: control.horizontal ? thickness : parent.height
            radius: thickness / 2
            color: control.pressed ? Theme.textSecondary
                 : control.hovered ? Theme.textTertiary : Theme.controlFill
            Behavior on thickness { NumberAnimation { duration: Theme.durationFast } }
        }
    }
}
