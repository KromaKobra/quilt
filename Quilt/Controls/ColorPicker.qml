pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quilt.Style
import "ColorUtil.js" as ColorUtil

// The popover a ColorField opens. One visit is one edit: Esc closes it and
// restores the colour it opened with; Enter or a click outside keeps the
// new one.
//
// The picker holds hue, saturation and value itself while it is open, so
// dragging to black, white or grey never loses the hue.
T.Popup {
    id: picker

    property bool alpha: true
    property var swatches: []
    property color original: "black"        // the colour the picker opened with
    property bool cancelled: false

    property real h: 0
    property real s: 0
    property real v: 0
    property real a: 1
    readonly property color color: Qt.hsva(h, s, v, alpha ? a : 1)
    readonly property color hueColor: Qt.hsva(h, 1, 1, 1)
    readonly property color opaque: Qt.hsva(h, s, v, 1)

    signal picked(color color)

    function load(c: color) {
        original = c;
        cancelled = false;
        _adopt(c);
    }

    // The field's value changed from outside (the application clamped it,
    // or an undo happened).
    function sync(c: color) {
        if (!ColorUtil.near(c, color))
            _adopt(c);
    }

    // Takes a colour, keeping our hue where the colour has none (greys) and
    // our saturation where it can't be seen (black).
    function _adopt(c: color) {
        if (c.hsvSaturation > 0.0001 && c.hsvValue > 0.0001 && c.hsvHue >= 0)
            h = c.hsvHue;
        if (c.hsvValue > 0.0001)
            s = c.hsvSaturation;
        v = c.hsvValue;
        a = c.a;
    }

    function _set(nh: real, ns: real, nv: real, na: real) {
        const clamp = x => Math.min(1, Math.max(0, x));
        h = clamp(nh);
        s = clamp(ns);
        v = clamp(nv);
        a = clamp(na);
        picked(color);
    }

    function _take(c: color) {
        _adopt(c);
        picked(color);
    }

    x: 0
    y: parent ? parent.height + 4 : 0
    padding: 10
    margins: 6
    focus: true
    popupType: Theme.popupType
    closePolicy: T.Popup.CloseOnPressOutside

    implicitWidth: 216 + leftPadding + rightPadding
    implicitHeight: contentHeight + topPadding + bottomPadding

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationFast } }

    background: PopupBackground { }

    component Checker: Image {
        source: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAAAAADhZOFXAAAAFklEQVR42mPoAYI0IGDAwwARIA4eBgBBhB5BaFSA3gAAAABJRU5ErkJggg=="
        fillMode: Image.Tile
        smooth: false
    }

    // A strip the pointer drags along: hue, alpha.
    component Strip: Item {
        id: strip
        property real position: 0
        signal moved(real position)
        width: parent.width
        height: 12

        Rectangle {
            x: Math.round(strip.position * (strip.width - width))
            y: -2
            width: 6
            height: strip.height + 4
            radius: 3
            color: "white"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.55)
            z: 1
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -3
            preventStealing: true
            property real last: 0
            onPressed: event => { last = event.x; strip.moved((event.x - 3 - 3) / (strip.width - 6)); }
            onPositionChanged: event => {
                // Ctrl: a tenth of the speed, relative to where the marker is.
                if (event.modifiers & Qt.ControlModifier)
                    strip.moved(strip.position + (event.x - last) / (strip.width - 6) * Theme.fineFactor);
                else
                    strip.moved((event.x - 3 - 3) / (strip.width - 6));
                last = event.x;
            }
        }
    }

    contentItem: Column {
        id: column
        spacing: 8
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                picker.cancelled = true;
                picker.close();
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                picker.close();
            } else {
                return;
            }
            event.accepted = true;
        }

        // Saturation across, value up.
        Item {
            id: square
            width: parent.width
            height: 132

            Rectangle {
                anchors.fill: parent
                radius: Theme.controlRadius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "white" }
                    GradientStop { position: 1; color: picker.hueColor }
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.controlRadius
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: "black" }
                }
            }
            Rectangle {
                x: Math.round(picker.s * square.width - width / 2)
                y: Math.round((1 - picker.v) * square.height - height / 2)
                width: 12
                height: 12
                radius: 6
                color: picker.opaque
                border.width: 2
                border.color: "white"
                Rectangle {
                    anchors { fill: parent; margins: -1 }
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.55)
                }
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                property real pressX: 0
                property real pressY: 0
                property real lastX: 0
                property real lastY: 0
                property int axis: 0            // Shift locks the drag to 1: saturation, 2: value

                onPressed: event => {
                    pressX = lastX = event.x;
                    pressY = lastY = event.y;
                    axis = 0;
                    picker._set(picker.h, event.x / width, 1 - event.y / height, picker.a);
                }
                onPositionChanged: event => {
                    const fine = (event.modifiers & Qt.ControlModifier) !== 0;
                    let ns = fine ? picker.s + (event.x - lastX) / width * Theme.fineFactor : event.x / width;
                    let nv = fine ? picker.v - (event.y - lastY) / height * Theme.fineFactor : 1 - event.y / height;
                    lastX = event.x;
                    lastY = event.y;
                    if (event.modifiers & Qt.ShiftModifier) {
                        if (axis === 0 && Math.max(Math.abs(event.x - pressX), Math.abs(event.y - pressY)) > 3)
                            axis = Math.abs(event.x - pressX) >= Math.abs(event.y - pressY) ? 1 : 2;
                        if (axis !== 1)
                            ns = picker.s;
                        if (axis !== 2)
                            nv = picker.v;
                    } else {
                        axis = 0;
                    }
                    picker._set(picker.h, ns, nv, picker.a);
                }
            }
        }

        Strip {
            position: picker.h
            onMoved: p => picker._set(Math.min(0.9999, p), picker.s, picker.v, picker.a)
            Rectangle {
                anchors.fill: parent
                radius: 6
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0 / 6; color: "#ff0000" }
                    GradientStop { position: 1 / 6; color: "#ffff00" }
                    GradientStop { position: 2 / 6; color: "#00ff00" }
                    GradientStop { position: 3 / 6; color: "#00ffff" }
                    GradientStop { position: 4 / 6; color: "#0000ff" }
                    GradientStop { position: 5 / 6; color: "#ff00ff" }
                    GradientStop { position: 6 / 6; color: "#ff0000" }
                }
            }
        }

        Strip {
            visible: picker.alpha
            position: picker.a
            onMoved: p => picker._set(picker.h, picker.s, picker.v, p)
            Checker { x: 4; width: parent.width - 8; height: parent.height }
            Rectangle {
                anchors.fill: parent
                radius: 6
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.alpha(picker.opaque, 0) }
                    GradientStop { position: 1; color: picker.opaque }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 8

            // Before | now. Click "before" to go back to it.
            Item {
                width: 48
                height: Theme.controlHeight
                Checker { anchors.fill: parent; anchors.margins: 1 }
                Rectangle {
                    width: parent.width / 2
                    height: parent.height
                    topLeftRadius: Theme.controlRadius
                    bottomLeftRadius: Theme.controlRadius
                    color: picker.original
                    TapHandler { onTapped: picker._take(picker.original) }
                    HoverHandler { id: beforeHover }
                    Tip { text: qsTr("The colour before"); shown: beforeHover.hovered }
                }
                Rectangle {
                    x: parent.width / 2
                    width: parent.width / 2
                    height: parent.height
                    topRightRadius: Theme.controlRadius
                    bottomRightRadius: Theme.controlRadius
                    color: picker.color
                }
            }

            SegmentedButton {
                id: mode
                width: parent.width - 56
                model: ["HSV", "RGB", "Hex"]
                value: "HSV"
            }
        }

        Row {
            width: parent.width
            spacing: 4
            visible: mode.value === "HSV"
            readonly property real cell: (width - (picker.alpha ? 3 : 2) * spacing) / (picker.alpha ? 4 : 3)
            NumberField {
                width: parent.cell; lead: "H"; integer: true; from: 0; to: 360; wrap: true
                value: picker.h * 360
                onEdited: n => picker._set(Math.min(0.9999, n / 360), picker.s, picker.v, picker.a)
            }
            NumberField {
                width: parent.cell; lead: "S"; integer: true; from: 0; to: 100
                value: picker.s * 100
                onEdited: n => picker._set(picker.h, n / 100, picker.v, picker.a)
            }
            NumberField {
                width: parent.cell; lead: "V"; integer: true; from: 0; to: 100
                value: picker.v * 100
                onEdited: n => picker._set(picker.h, picker.s, n / 100, picker.a)
            }
            NumberField {
                width: parent.cell; lead: "A"; integer: true; from: 0; to: 100; visible: picker.alpha
                value: picker.a * 100
                onEdited: n => picker._set(picker.h, picker.s, picker.v, n / 100)
            }
        }

        Row {
            width: parent.width
            spacing: 4
            visible: mode.value === "RGB"
            readonly property real cell: (width - (picker.alpha ? 3 : 2) * spacing) / (picker.alpha ? 4 : 3)
            NumberField {
                width: parent.cell; lead: "R"; integer: true; from: 0; to: 255
                value: picker.color.r * 255
                onEdited: n => picker._take(Qt.rgba(n / 255, picker.color.g, picker.color.b, picker.a))
            }
            NumberField {
                width: parent.cell; lead: "G"; integer: true; from: 0; to: 255
                value: picker.color.g * 255
                onEdited: n => picker._take(Qt.rgba(picker.color.r, n / 255, picker.color.b, picker.a))
            }
            NumberField {
                width: parent.cell; lead: "B"; integer: true; from: 0; to: 255
                value: picker.color.b * 255
                onEdited: n => picker._take(Qt.rgba(picker.color.r, picker.color.g, n / 255, picker.a))
            }
            NumberField {
                width: parent.cell; lead: "A"; integer: true; from: 0; to: 100; visible: picker.alpha
                value: picker.a * 100
                onEdited: n => picker._set(picker.h, picker.s, picker.v, n / 100)
            }
        }

        TextField {
            width: parent.width
            visible: mode.value === "Hex"
            text: ColorUtil.toHex(picker.color, picker.alpha)
            font.features: ({ "tnum": 1 })
            onEdited: t => {
                const c = ColorUtil.parse(t);
                if (c)
                    picker._take(Qt.rgba(c[0], c[1], c[2], picker.alpha ? c[3] : 1));
            }
        }

        // The application's palette, then the colours used recently.
        Flow {
            width: parent.width
            spacing: 4
            visible: swatchRepeater.count > 0
            Repeater {
                id: swatchRepeater
                model: (picker.swatches || []).concat(ColorHistory.recent)
                delegate: Rectangle {
                    id: swatch
                    required property var modelData
                    width: 16
                    height: 16
                    radius: Theme.innerRadius
                    color: modelData
                    border.width: swatchHover.hovered ? 1 : 0
                    border.color: Theme.text
                    HoverHandler { id: swatchHover }
                    TapHandler { onTapped: picker._take(swatch.color) }
                }
            }
        }
    }
}
