import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// The waiting wheel, for short waits of unknown length. Qt's BusyIndicator
// API. It waits `delay` before appearing, so quick tasks show nothing, and
// then stays at least 300 ms, so it never flickers.
T.BusyIndicator {
    id: control

    property int delay: 400
    property color color: Theme.textSecondary
    readonly property bool showing: _shown

    property bool _shown: false
    property double _since: 0

    implicitWidth: 16
    implicitHeight: 16

    onRunningChanged: {
        if (running) {
            hideTimer.stop();
            if (!_shown)
                showTimer.restart();
        } else {
            showTimer.stop();
            if (_shown) {
                hideTimer.interval = Math.max(1, 300 - (Date.now() - _since));
                hideTimer.restart();
            }
        }
    }
    Component.onCompleted: if (running) showTimer.restart()

    Timer {
        id: showTimer
        interval: Math.max(1, control.delay)
        onTriggered: {
            control._shown = true;
            control._since = Date.now();
        }
    }
    Timer {
        id: hideTimer
        onTriggered: control._shown = false
    }

    contentItem: Item {
        opacity: control._shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

        Spinner {
            anchors.fill: parent
            running: control._shown && control.visible
            color: control.color
        }
    }
}
