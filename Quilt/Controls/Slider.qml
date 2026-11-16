import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// The classic track and thumb, for use outside a property grid: a toolbar,
// a timeline, volume, zoom. Inside an inspector, use a NumberField with
// `from` and `to` instead.
//
//     Slider { from: 0; to: 240; stepSize: 1; value: player.frame; onEdited: v => player.frame = v }
//
// Grabbing the thumb drags it without a jump. Pressing the track moves the
// thumb there and keeps dragging. Esc cancels. With a defaultValue the track
// shows a tick there and the thumb snaps to it (hold Ctrl to pass freely).
T.Control {
    id: control

    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0               // 0: continuous
    property int orientation: Qt.Horizontal
    property bool live: true

    property var param: null
    property var defaultValue
    property int paramState: Param.Normal
    property string expression
    property string message
    property bool readOnly: false
    property bool acceptsExpressions: false

    readonly property bool modified: edit.modified
    readonly property bool fillsRow: true
    readonly property bool horizontal: orientation === Qt.Horizontal
    readonly property bool pressed: mouse.pressed && !_cancelled
    readonly property real position: to > from ? Math.min(1, Math.max(0, (Number(edit.shown) - from) / (to - from))) : 0

    signal editStarted()
    signal edited(real value)
    signal editFinished(bool committed)
    signal expressionEdited(string text)
    signal moved()                          // as Qt's Slider: the user changed the value

    function reset() { edit.reset(); }
    function setExpression(text: string) { edit.setExpression(text); }  // "" removes it
    function increase() { _step(1, Qt.NoModifier); }
    function decrease() { _step(-1, Qt.NoModifier); }
    function activate() { control.forceActiveFocus(Qt.TabFocusReason); }
    function copyText(): string { return String(parseFloat(Number(edit.shown).toPrecision(12))); }
    function pasteText(text: string) {
        const v = Number(text.trim());
        if (text.trim() !== "" && isFinite(v) && !_locked)
            edit.instant(_snap(v));
    }
    // The value at `fraction` (0..1) of the way along the track.
    function valueAt(fraction: real): real { return _snap(from + (to - from) * fraction); }

    readonly property bool _locked: edit.readOnly || edit.driven || !enabled
    readonly property real _thumb: 12
    readonly property real _travel: (horizontal ? availableWidth : availableHeight) - _thumb
    property real _grab: 0
    property bool _cancelled: false

    function _snap(v: real): real {
        let s = Math.min(to, Math.max(from, v));
        if (stepSize > 0)
            s = Math.min(to, from + Math.round((s - from) / stepSize) * stepSize);
        return parseFloat(s.toPrecision(12));
    }

    function _step(n: int, modifiers: int) {
        if (_locked || edit.mixed)
            return;
        const q = (stepSize > 0 ? stepSize : (to - from) / 100) * Theme.stepFactor(modifiers);
        const v = Math.min(to, Math.max(from, Number(edit.shown) + n * q));
        edit.step(parseFloat(v.toPrecision(12)));
        moved();
    }

    // Where along the track (0..1) a pointer position is.
    function _fraction(x: real, y: real): real {
        const along = horizontal ? x - leftPadding : (height - bottomPadding) - y;
        return _travel > 0 ? Math.min(1, Math.max(0, (along - _grab - _thumb / 2) / _travel)) : 0;
    }

    function _drag(x: real, y: real, modifiers: int) {
        let v = valueAt(_fraction(x, y));
        const d = Number(edit.defaultValue);
        // A light magnet at the default value; Ctrl switches it off.
        if (edit.defaultValue !== undefined && isFinite(d) && !(modifiers & Qt.ControlModifier)
                && Math.abs(v - d) / (to - from) * _travel < 5)
            v = d;
        if (!edit.same(v, edit.shown)) {
            edit.set(v);
            moved();
        }
    }

    implicitWidth: horizontal ? 140 : Theme.controlHeight
    implicitHeight: horizontal ? Theme.controlHeight : 140
    activeFocusOnTab: true
    focusPolicy: Qt.TabFocus
    opacity: enabled ? 1 : 0.4

    Accessible.role: Accessible.Slider
    Accessible.description: edit.stateText
    Accessible.onIncreaseAction: increase()
    Accessible.onDecreaseAction: decrease()

    Keys.onPressed: event => {
        const up = event.key === Qt.Key_Right || event.key === Qt.Key_Up;
        if (up || event.key === Qt.Key_Left || event.key === Qt.Key_Down) {
            control._step(up ? 1 : -1, event.modifiers);
        } else if (event.key === Qt.Key_Home || event.key === Qt.Key_End) {
            if (!control._locked) {
                edit.step(event.key === Qt.Key_Home ? control.from : control.to);
                control.moved();
            }
        } else if (event.key === Qt.Key_Escape && edit.active) {
            control._cancelled = mouse.pressed;
            edit.end(false);
        } else {
            return;
        }
        event.accepted = true;
    }

    contentItem: Item {
        // Track
        Rectangle {
            id: track
            x: control.horizontal ? 0 : Math.round((parent.width - width) / 2)
            y: control.horizontal ? Math.round((parent.height - height) / 2) : 0
            width: control.horizontal ? parent.width : 4
            height: control.horizontal ? 4 : parent.height
            radius: 2
            color: Theme.controlFill

            // Filled part, from the start of the range to the thumb
            Rectangle {
                visible: !edit.mixed
                y: control.horizontal ? 0 : parent.height - height
                width: control.horizontal ? thumb.x + thumb.width / 2 : parent.width
                height: control.horizontal ? parent.height : parent.height - thumb.y - thumb.height / 2
                radius: 2
                color: edit.driven ? Theme.driven : Theme.accent
            }
        }

        // Tick at the default value
        Rectangle {
            readonly property real at: control.to > control.from
                ? (Number(edit.defaultValue) - control.from) / (control.to - control.from) : 0
            visible: edit.defaultValue !== undefined && edit.defaultValue !== null && at >= 0 && at <= 1
            x: control.horizontal ? Math.round(control._thumb / 2 + at * control._travel) : track.x - 3
            y: control.horizontal ? track.y - 3 : Math.round(parent.height - control._thumb / 2 - at * control._travel)
            width: control.horizontal ? 1 : 10
            height: control.horizontal ? 10 : 1
            color: Theme.textTertiary
            z: -1
        }

        Rectangle {
            id: thumb
            property real grow: mouse.containsMouse || mouse.pressed ? 2 : 0
            x: (control.horizontal ? control.position * control._travel
                                   : (parent.width - control._thumb) / 2) - grow / 2
            y: (control.horizontal ? (parent.height - control._thumb) / 2
                                   : (1 - control.position) * control._travel) - grow / 2
            width: control._thumb + grow
            height: control._thumb + grow
            radius: width / 2
            visible: !edit.mixed
            color: Theme.text
            border.width: control.visualFocus || mouse.pressed ? 2 : 0
            border.color: Theme.accent
            Behavior on grow { NumberAnimation { duration: Theme.durationFast } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !control._locked
        hoverEnabled: true
        preventStealing: true

        onPressed: event => {
            control._cancelled = false;
            control.forceActiveFocus(Qt.MouseFocusReason);     // so Esc reaches us
            const along = control.horizontal ? event.x - control.leftPadding
                                             : (control.height - control.bottomPadding) - event.y;
            const centre = control._thumb / 2 + control.position * control._travel;
            // On the thumb: keep the offset, so it doesn't jump. On the track: go there.
            control._grab = !edit.mixed && Math.abs(along - centre) <= control._thumb / 2 + 2 ? along - centre : 0;
            edit.begin();
            if (control._grab === 0)
                control._drag(event.x, event.y, event.modifiers);
        }
        onPositionChanged: event => {
            if (pressed && !control._cancelled)
                control._drag(event.x, event.y, event.modifiers);
        }
        onReleased: {
            edit.end(!control._cancelled);
            control.focus = false;
        }
        onCanceled: {
            edit.end(false);
            control.focus = false;
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

    Tip { text: edit.message; shown: mouse.containsMouse; pressed: mouse.pressed }

    ValueEdit { id: edit; owner: control; live: control.live }
}
