import QtQuick

// While `active`, reports a press anywhere in `target`'s window that is not
// on `target`: the cue for a field being typed into to apply its text.
//
// Clicking something that takes no keyboard focus (a viewport, a canvas)
// leaves focus where it was, so without this a field would keep its typed
// text, and apply it later to whatever it shows by then.
//
// It sits over the whole window and only observes: the press still goes on
// to whatever is under it, after `pressed()` has been handled.
Item {
    id: watcher

    required property Item target
    property bool active: false

    signal pressed()

    parent: active && target && target.Window.window ? target.Window.contentItem : null
    anchors.fill: parent
    z: 1e9

    PointHandler {
        acceptedButtons: Qt.AllButtons
        onActiveChanged: {
            if (!active || !watcher.target)
                return;
            const p = watcher.target.mapFromItem(watcher, point.position);
            if (!watcher.target.contains(p))
                watcher.pressed();
        }
    }
}
