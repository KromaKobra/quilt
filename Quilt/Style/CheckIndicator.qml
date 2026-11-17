import QtQuick
import "Paint.js" as Paint

// The box of a checkbox: empty, ticked, or a dash for a mixed selection.
// A theme redraws it with `skins.check`. Provisional.
Rectangle {
    id: box

    property bool on: false             // ticked, or mixed
    property bool mixed: false          // a dash instead of a tick
    property bool driven: false
    property bool hovered: false
    property bool pressed: false
    property bool readOnly: false
    property bool focused: false

    readonly property color fill: on ? (driven ? Theme.driven : Theme.accent) : pressed ? Theme.controlHover : "transparent"
    readonly property color edge: hovered ? Theme.textSecondary : Theme.textTertiary
    readonly property color ink: Theme.accentInk

    readonly property Component painter: Theme.skins.check
    readonly property bool skinned: painter !== null

    implicitWidth: 14
    implicitHeight: 14
    radius: Theme.innerRadius
    color: skinned ? "transparent" : fill
    border.width: on || skinned ? 0 : 1.5
    border.pixelAligned: false
    border.color: edge
    opacity: readOnly ? 0.6 : 1

    property Item _painted: null
    property Item _ring: null
    onPainterChanged: Paint.apply(box, painter)
    onFocusedChanged: Paint.ring(box, () => box.focused, () => box.radius, 1.5)
    Component.onCompleted: {
        if (painter)
            Paint.apply(box, painter);
        if (focused)
            Paint.ring(box, () => box.focused, () => box.radius, 1.5);
    }

    Icon {
        anchors.centerIn: parent
        visible: box.on && !box.skinned
        name: box.mixed ? "dash" : "check"
        size: 10
        strokeWidth: 1.8
        color: box.ink
    }
}
