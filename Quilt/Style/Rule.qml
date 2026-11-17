import QtQuick
import "Paint.js" as Paint

// A separator: between menu rows, under a section, between columns. Size it
// like a Rectangle; `vertical` tells a painter which way it runs. A theme
// redraws it with `skins.rule`. Provisional.
Rectangle {
    id: rule

    property color ink: Theme.border
    property bool vertical: height > width

    readonly property Component painter: Theme.skins.rule
    readonly property bool skinned: painter !== null

    color: skinned ? "transparent" : ink

    property Item _painted: null
    onPainterChanged: Paint.apply(rule, painter)
    Component.onCompleted: if (painter) Paint.apply(rule, painter)
}
