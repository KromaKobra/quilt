.pragma library

// What hosts (Face, Surface, …) create only when they need it, so that
// Quilt's own look costs no more than a plain rectangle per control.

// Creates, replaces and removes the painter a theme gives a host. The
// painter becomes the host's child, under everything the host draws
// itself, the host's size, and never takes input. A host calls
//
//     onPainterChanged: Paint.apply(host, painter)
//     Component.onCompleted: if (painter) Paint.apply(host, painter)
//
// and keeps the painter in its `_painted`.
function apply(host, painter) {
    if (host._painted) {
        host._painted.destroy();
        host._painted = null;
    }
    if (!painter)
        return;
    const item = painter.createObject(host, { z: -1, enabled: false });
    if (!item) {
        console.warn("Quilt: a theme painter failed to load:", painter.errorString());
        return;
    }
    item.anchors.fill = host;
    host._painted = item;
}

let ringComponent = null;
let flashComponent = null;

// Gives `host` a FocusRing (kept in its `_ring`) the first time `shown()`
// is true; from then on the ring follows shown(). `radius()` is the host's
// corner radius; `extra` sets the ring further out than Theme.focusOffset.
function ring(host, shown, radius, extra) {
    if (host._ring || !shown())
        return;
    if (!ringComponent)
        ringComponent = Qt.createComponent("FocusRing.qml");
    host._ring = ringComponent.createObject(host, {
        z: 2,
        extra: extra,
        shown: Qt.binding(shown),
        invalid: Qt.binding(() => host.invalid === true),
        baseRadius: Qt.binding(radius)
    });
}

// Flashes `host` in the accent: Quilt corrected what the user entered.
function flash(host, radius) {
    if (!host._flash) {
        if (!flashComponent)
            flashComponent = Qt.createComponent("Flash.qml");
        host._flash = flashComponent.createObject(host, { z: 1, radius: Qt.binding(radius) });
    }
    host._flash.run();
}
