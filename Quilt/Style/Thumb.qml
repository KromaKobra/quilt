import QtQuick
import "Paint.js" as Paint

// The handle of a slider, or the thumb of a scroll bar (`scroll`). The
// control sizes and places it. A theme redraws it with `skins.thumb`.
// Provisional.
Rectangle {
    id: thumb

    property bool scroll: false
    property bool hovered: false
    property bool pressed: false
    property bool focused: false

    readonly property color fill: !scroll ? Theme.text
                                : pressed ? Theme.textSecondary : hovered ? Theme.textTertiary : Theme.controlFill
    readonly property color edge: Theme.focus

    readonly property Component painter: Theme.skins.thumb
    readonly property bool skinned: painter !== null

    radius: Math.min(width, height) / 2
    color: skinned ? "transparent" : fill
    border.width: !skinned && !scroll && (focused || pressed) ? 2 : 0
    border.color: edge

    property Item _painted: null
    onPainterChanged: Paint.apply(thumb, painter)
    Component.onCompleted: if (painter) Paint.apply(thumb, painter)
}
