pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Templates as T
import Quilt.Style

// A rotary control, for dense grids of continuous values (audio, synths).
// A knob is slower and less precise than a NumberField; its one advantage
// is size.
//
//     Knob { text: "Cutoff"; from: 20; to: 20000; value: synth.cutoff; onEdited: v => synth.cutoff = v }
//
// Drag up for more and down for less (Shift x10, Ctrl x0.1, Esc cancels).
// Click to type a value. The caption shows the value while you hover or drag.
T.Control {
    id: control

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: (to - from) / 100
    property int decimals: 2
    property real displayScale: 1
    property string suffix
    property string text                    // the caption beneath
    property bool bipolar: false            // draw the arc from the middle of the range (pan)
    property bool valueVisible: false       // always show the value instead of the caption
    property real size: 32                  // diameter of the dial
    property bool live: true

    property var param: null
    property var defaultValue
    property int paramState: Param.Normal
    property string expression
    property string message
    property bool readOnly: false
    property bool acceptsExpressions: false

    readonly property bool modified: edit.modified
    readonly property bool pressed: mouse.pressed && _dragging
    readonly property real position: to > from ? Math.min(1, Math.max(0, (Number(edit.shown) - from) / (to - from))) : 0
    readonly property string displayText: edit.mixed ? qsTr("Mixed") : _format(Number(edit.shown)) + suffix

    signal editStarted()
    signal edited(real value)
    signal editFinished(bool committed)
    signal expressionEdited(string text)

    function reset() { edit.reset(); }
    function setExpression(text: string) { edit.setExpression(text); }
    function increase() { _step(1, Qt.NoModifier); }
    function decrease() { _step(-1, Qt.NoModifier); }
    function activate() { if (!_locked) _typing = true; }
    function copyText(): string { return edit.mixed ? "" : String(parseFloat((Number(edit.shown) * displayScale).toPrecision(12))); }
    function pasteText(text: string) {
        const r = Expression.evaluate(text, { current: Number(edit.shown) * displayScale });
        if (r.ok && !_locked)
            edit.instant(_fit(r.value / displayScale, 1));
    }

    readonly property bool _locked: edit.readOnly || edit.driven || !enabled
    property bool _dragging: false
    property bool _cancelled: false
    property bool _typing: false
    property real _start: 0
    property real _travel: 0

    function _doneTyping() { _typing = false; }

    function _format(v: real): string {
        let s = (v * displayScale).toFixed(Math.max(0, decimals));
        if (decimals > 0)
            s = s.replace(/\.?0+$/, "");
        return Number(s) === 0 ? "0" : s;
    }

    // Clamps to the range and lands on a multiple of the step (scaled by `fine`).
    function _fit(v: real, fine: real): real {
        const q = step * fine;
        let r = Math.min(to, Math.max(from, v));
        if (q > 0)
            r = Math.min(to, Math.max(from, from + Math.round((r - from) / q) * q));
        return parseFloat(r.toPrecision(12));
    }

    function _step(n: int, modifiers: int) {
        if (_locked || edit.mixed)
            return;
        const f = Theme.stepFactor(modifiers);
        edit.step(_fit(Number(edit.shown) + n * step * f, Math.min(1, f)));
    }

    implicitWidth: Math.max(size + 8, caption.visible ? 48 : 0)
    implicitHeight: size + 6 + (caption.visible ? caption.height + 2 : 0)
    activeFocusOnTab: true
    focusPolicy: Qt.TabFocus
    opacity: enabled ? 1 : 0.4

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeSmall

    Keys.onPressed: event => {
        const up = event.key === Qt.Key_Up || event.key === Qt.Key_Right;
        if (up || event.key === Qt.Key_Down || event.key === Qt.Key_Left) {
            control._step(up ? 1 : -1, event.modifiers);
        } else if (event.key === Qt.Key_Escape && edit.active) {
            control._cancelled = control._dragging;
            edit.end(false);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_F2) {
            control.activate();
        } else {
            return;
        }
        event.accepted = true;
    }

    contentItem: Item {
        Item {
            id: dial
            anchors.horizontalCenter: parent.horizontalCenter
            y: 3
            width: control.size
            height: control.size

            readonly property real r: control.size / 2 - 2.5
            // The arc runs 270 degrees, clockwise from lower left, with the gap at the bottom.
            readonly property real angle: 135 + 270 * control.position
            readonly property real origin: control.bipolar ? 270 : 135
            readonly property color ink: edit.driven ? Theme.driven : Theme.accent

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: mouse.containsMouse || control._dragging
                                 ? Theme.mix(Theme.controlFill, Theme.text, 0.12) : Theme.controlFill
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: dial.width / 2; centerY: dial.height / 2
                        radiusX: dial.r; radiusY: dial.r
                        startAngle: 135; sweepAngle: 270
                    }
                }
                ShapePath {
                    strokeColor: edit.mixed ? "transparent" : dial.ink
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: dial.width / 2; centerY: dial.height / 2
                        radiusX: dial.r; radiusY: dial.r
                        startAngle: dial.origin; sweepAngle: dial.angle - dial.origin
                    }
                }
            }

            // The pointer: a short line aimed at the value.
            Item {
                visible: !edit.mixed
                x: dial.width / 2
                y: dial.height / 2
                rotation: dial.angle
                transformOrigin: Item.TopLeft
                Rectangle {
                    x: dial.r * 0.3
                    y: -1
                    width: dial.r * 0.7 - 3.5
                    height: 2
                    radius: 1
                    color: Theme.text
                }
            }

            Rectangle {
                anchors { fill: parent; margins: -2 }
                radius: width / 2
                color: "transparent"
                border.width: Theme.focusWidth
                border.pixelAligned: false
                border.color: Theme.accent
                visible: control.activeFocus
            }
        }

        Text {
            id: caption
            anchors { horizontalCenter: parent.horizontalCenter; top: dial.bottom; topMargin: 4 }
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: control.text !== "" || control.valueVisible
            // The caption gives way to the value under the pointer, in place.
            readonly property bool numeric: control.valueVisible || control.text === ""
                                            || mouse.containsMouse || control._dragging || control.activeFocus
            text: numeric ? control.displayText : control.text
            elide: Text.ElideRight
            color: numeric && edit.driven ? Theme.driven : numeric ? Theme.text : Theme.textSecondary
            font: control.font
            renderType: Theme.textRenderType
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !control._locked && !control._typing
        hoverEnabled: true
        preventStealing: control._dragging
        property real pressY: 0
        property real lastY: 0

        onPressed: event => {
            pressY = lastY = event.y;
            control._cancelled = false;
        }
        onPositionChanged: event => {
            if (!pressed || control._cancelled)
                return;
            if (!control._dragging) {
                if (Math.abs(event.y - pressY) < Theme.dragThreshold || edit.mixed)
                    return;
                control._dragging = true;
                control._start = Number(edit.shown);
                control._travel = 0;
                lastY = event.y;
                control.forceActiveFocus(Qt.MouseFocusReason);     // so Esc reaches us
                edit.begin();
            }
            const f = Theme.stepFactor(event.modifiers);
            // Up is more: 200 px of travel covers the range.
            control._travel += (lastY - event.y) / 200 * (control.to - control.from) * f;
            lastY = event.y;
            const raw = control._start + control._travel;
            const clamped = Math.min(control.to, Math.max(control.from, raw));
            control._travel = clamped - control._start;             // no dead travel at the ends
            edit.set(control._fit(clamped, Math.min(1, f)));
        }
        onReleased: {
            if (control._dragging) {
                control._dragging = false;
                edit.end(!control._cancelled);
                control.focus = false;
            } else if (containsMouse) {
                control.activate();
            }
        }
        onCanceled: {
            if (control._dragging) {
                control._dragging = false;
                edit.end(false);
                control.focus = false;
            }
        }
    }

    WheelHandler {
        enabled: control.activeFocus && !control._locked
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real pending: 0
        onWheel: event => {
            pending += event.angleDelta.y;
            while (Math.abs(pending) >= 120) {
                const n = pending > 0 ? 1 : -1;
                pending -= n * 120;
                control._step(n, event.modifiers);
            }
        }
    }

    // Click to type: a number field appears over the dial.
    Loader {
        active: control._typing
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(3 + (control.size - Theme.controlHeight) / 2)
        sourceComponent: NumberField {
            width: 64
            value: control.value
            minimum: control.from
            maximum: control.to
            decimals: Math.max(control.decimals, 4)
            displayScale: control.displayScale
            suffix: control.suffix
            scrubbable: false
            onEdited: v => edit.instant(control._fit(v, 0))
            // Not at once: the field is still in the middle of applying its text.
            onEditingChanged: if (!editing) Qt.callLater(control._doneTyping)
            Component.onCompleted: beginEdit()
        }
    }

    Tip { text: edit.message; shown: mouse.containsMouse && !mouse.pressed }

    ValueEdit { id: edit; owner: control; live: control.live }
}
