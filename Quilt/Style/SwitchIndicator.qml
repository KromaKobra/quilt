import QtQuick
import "Paint.js" as Paint

// The track and thumb of a switch. `thumb` is where the thumb is drawn,
// 0 (off) to 1 (on); it eases there, except while the switch is held, when
// it follows the pointer. A theme redraws it with `skins.toggle`. Provisional.
Rectangle {
    id: indicator

    property bool on: false
    property bool mixed: false          // the thumb waits in the middle
    property bool driven: false
    property bool hovered: false
    property bool pressed: false
    property bool focused: false
    property real position: 0           // 0..1, where the thumb belongs

    property real thumb: mixed ? 0.5 : position     // read-only: where the thumb is drawn now
    Behavior on thumb { enabled: !indicator.pressed; NumberAnimation { duration: Theme.duration; easing.type: Theme.easing } }

    readonly property color fill: on ? (driven ? Theme.driven : Theme.accent)
                                     : hovered ? Theme.mix(Theme.controlFill, Theme.text, 0.1) : Theme.controlFill
    readonly property color ink: on ? Theme.accentInk : Theme.textSecondary     // the thumb

    readonly property Component painter: Theme.skins.toggle
    readonly property bool skinned: painter !== null

    implicitWidth: 26
    implicitHeight: 14
    radius: height / 2
    color: skinned ? "transparent" : fill
    Behavior on color { enabled: !indicator.skinned; ColorAnimation { duration: Theme.durationFast } }

    property Item _painted: null
    property Item _ring: null
    onPainterChanged: Paint.apply(indicator, painter)
    onFocusedChanged: Paint.ring(indicator, () => indicator.focused, () => indicator.radius, 1.5)
    Component.onCompleted: {
        if (painter)
            Paint.apply(indicator, painter);
        if (focused)
            Paint.ring(indicator, () => indicator.focused, () => indicator.radius, 1.5);
    }

    Rectangle {
        readonly property real travel: parent.width - width - 4
        visible: !indicator.skinned
        x: 2 + indicator.thumb * travel
        y: 2
        width: 10
        height: 10
        radius: width / 2
        color: indicator.ink
    }
}
