import QtQuick
import "Paint.js" as Paint

// The ring that shows which control has keyboard focus, or that a field's
// value is invalid. It sits `offset` outside its parent:
//
//     FocusRing { shown: control.visualFocus; baseRadius: parent.radius }
//
// A theme redraws it with `skins.focusRing`; the painter reads the ring's
// `invalid`, `radius` and `color`.
Rectangle {
    id: ring

    property bool shown: false
    property bool invalid: false            // drawn in Theme.error
    property real extra: 0                  // further out than the theme puts rings
    property real offset: Theme.focusOffset + extra     // how far outside the parent; negative is inside
    property real baseRadius: 0             // the parent's corner radius

    readonly property Component painter: Theme.skins.focusRing
    readonly property bool skinned: painter !== null

    anchors.fill: parent
    anchors.margins: -offset
    radius: baseRadius + offset
    color: "transparent"
    border.width: skinned ? 0 : Theme.focusWidth
    border.pixelAligned: false
    border.color: invalid ? Theme.error : Theme.focus
    visible: shown

    property Item _painted: null
    readonly property Component _wanted: shown ? painter : null
    on_WantedChanged: Paint.apply(ring, _wanted)
    Component.onCompleted: if (_wanted) Paint.apply(ring, _wanted)
}
