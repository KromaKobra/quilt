pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quilt.Style
import "Expr.js" as Expr

// Edits a number: drag it, type it, or step it.
//
//     NumberField { value: shape.width; suffix: " px"; onEdited: v => shape.width = v }
//     NumberField { value: shape.opacity; from: 0; to: 1; displayScale: 100; suffix: "%" }   // a slider
//     NumberField { value: mesh.segments; integer: true; minimum: 3; steppers: true }        // a stepper
//
// Drag horizontally to change the value (Shift x10, Ctrl x0.1, Esc cancels).
// Click to type; arithmetic such as 2*pi, (a+b)/2 and +=10 is evaluated.
// Up/Down and the wheel step a focused field. docs/controls.md has the rest.
T.Control {
    id: control

    // ---- the value

    property real value: 0
    property bool integer: false

    // The soft range: what the fill bar shows and what a drag covers. Setting
    // both turns the field into a slider. Typing may go beyond it.
    property real from: Number.NEGATIVE_INFINITY
    property real to: Number.POSITIVE_INFINITY
    // The hard limits: what the value can ever be.
    property real minimum: Number.NEGATIVE_INFINITY
    property real maximum: Number.POSITIVE_INFINITY

    property real step: integer ? 1 : (ranged ? (to - from) / 100 : 0.1)
    property bool wrap: false               // go round from `to` back to `from` (angles)
    property bool logarithmic: false        // spread a ranged field logarithmically (needs from > 0)
    property bool live: true                // false: report only the final value of a drag

    // ---- how it is shown

    property int decimals: integer ? 0 : 3  // at most this many; trailing zeros are dropped
    property real displayScale: 1           // shown = value * displayScale (100 with a "%" suffix)
    property string suffix                  // "°", " px", "%": shown dimmed, never part of the edit text
    property string lead                    // a short dim label inside the field, e.g. "X"
    property bool steppers: false           // − and + buttons at the ends
    property bool flat: false               // no fill of its own; for use inside another control
    property bool scrubbable: true

    // ---- typed input

    property var units: ({})                // { cm: 0.01, mm: 0.001 }: "5cm" multiplies by the unit
    property var resolver: null             // function(name): the value of a name used in arithmetic
    property var textFromValue: null        // function(value): your own display text
    property var valueFromText: null        // function(text): your own parser; return NaN to reject
    property var listHandler: null          // function(numbers): takes over when a list is typed (VectorField)

    // ---- parameter state. See docs/controls.md.

    property var param: null                // a parameter object; replaces the properties below
    property var defaultValue               // enables the modified marker and reset()
    property int paramState: Param.Normal
    property string expression              // what editing shows while the value is driven
    property string message                 // tooltip: what drives the value, or why it is invalid
    property bool readOnly: false
    property bool acceptsExpressions: false // typing "=…" emits expressionEdited

    readonly property bool modified: edit.modified
    readonly property bool ranged: isFinite(from) && isFinite(to) && to > from
    readonly property bool editing: input.visible
    readonly property bool scrubbing: _scrub
    readonly property bool focused: _focused || _scrub    // it has the keyboard, or is being dragged
    readonly property bool canScrub: enabled && scrubbable && !edit.readOnly && !edit.driven && !edit.mixed
    readonly property real position: _positionOf(Number(edit.shown))    // 0..1 along the soft range
    readonly property bool fillsRow: true   // PropertyRow stretches it

    readonly property string displayText: {
        if (edit.mixed)
            return content.room < metrics.advanceWidth(qsTr("Mixed")) ? "—" : qsTr("Mixed");
        const v = Number(edit.shown);
        if (control.textFromValue)
            return String(control.textFromValue(v));
        let d = Math.max(0, control.decimals);
        let s = control._format(v * control.displayScale, d);
        while (d > 0 && metrics.advanceWidth(s) > content.room)
            s = control._format(v * control.displayScale, --d);
        return s;
    }

    signal editStarted()
    signal edited(real value)
    signal editFinished(bool committed)
    signal expressionEdited(string text)    // without the leading "="

    // ---- actions

    function reset() { edit.reset(); }
    function setExpression(text: string) { edit.setExpression(text); }  // "" removes it
    function increase() { stepBy(1, Qt.NoModifier); }
    function decrease() { stepBy(-1, Qt.NoModifier); }
    function activate() { beginEdit(); }    // what clicking the row label does
    function copyText(): string { return edit.mixed ? "" : _plain(Number(edit.shown) * displayScale); }
    function pasteText(text: string) {
        if (edit.readOnly)
            return;
        const r = _parse(text.trim());
        if (r.ok && r.list)
            listHandler(r.list);
        else if (r.ok)
            edit.instant(_clean(_limit(r.value / displayScale)));
    }

    // `n` steps up (or down, if negative), landing on a multiple of the step.
    function stepBy(n: int, modifiers: int) {
        if (!enabled || edit.readOnly || edit.driven || edit.mixed)
            return;
        const cur = Number(edit.shown);
        let v;
        if (ranged && logarithmic && from > 0) {
            v = _valueAt(_positionOf(cur) + n * 0.01 * Theme.stepFactor(modifiers));
        } else {
            const q = step * Theme.stepFactor(modifiers);
            if (!(q > 0))
                return;
            const k = cur / q;
            v = ((n > 0 ? Math.floor(k + 1e-6) : Math.ceil(k - 1e-6)) + n) * q;
        }
        edit.step(_clean(_limit(v, cur)));
    }

    // Scrubbing, as three calls so a row label can drive it too.
    function scrubBegin(): bool {
        if (!canScrub)
            return false;
        if (editing && !commitEdit())
            cancelEdit();
        edit.begin();
        _scrubStart = Number(edit.shown);
        _scrubTravel = 0;
        _scrubCancelled = false;
        _scrub = true;
        control.forceActiveFocus(Qt.MouseFocusReason);     // so Esc reaches us
        return true;
    }

    function scrubBy(dx: real, modifiers: int) {
        if (!_scrub || _scrubCancelled)
            return;
        const speed = Theme.stepFactor(modifiers);
        const fine = speed < 1;
        let v;
        if (ranged && logarithmic && from > 0) {
            const p0 = _positionOf(_scrubStart);
            _scrubTravel += dx / Math.max(160, width) * speed;
            const p = Math.min(1, Math.max(0, p0 + _scrubTravel));
            _scrubTravel = p - p0;
            v = _valueAt(p);
        } else {
            _scrubTravel += dx * (ranged ? (to - from) / Math.max(160, width) : step / 2) * speed;
            const raw = _scrubStart + _scrubTravel;
            v = _limit(raw, _scrubStart);
            if (!wrap && v !== raw)
                _scrubTravel = v - _scrubStart;             // at a limit: no dead travel on the way back
            const q = step * (fine ? Theme.fineFactor : 1);
            if (q > 0)
                v = _limit(Math.round(v / q) * q, _scrubStart);
        }
        edit.set(_clean(v));
    }

    function scrubEnd(commit) {
        if (!_scrub)
            return;
        _scrub = false;
        edit.end(commit !== false && !_scrubCancelled);
        control.focus = false;                  // a drag leaves no focus behind for the wheel to act on
    }

    // Typing. `replacement` starts the text with what the user just typed.
    function beginEdit(replacement) {
        if (!enabled || edit.readOnly || editing)
            return;
        _inputError = "";
        _editStartText = _editText();
        input.text = replacement !== undefined ? replacement : _editStartText;
        input.visible = true;
        input.forceActiveFocus(Qt.MouseFocusReason);
        if (replacement !== undefined)
            input.cursorPosition = input.text.length;
        else
            input.selectAll();
    }

    // Applies the typed text. Returns false, and stays in editing, when the
    // text can't be understood.
    function commitEdit(): bool {
        if (!editing)
            return true;
        const text = input.text.trim();
        if (text === "" || text === _editStartText) {       // nothing typed: nothing changes
            _endEdit();
            return true;
        }
        if (text[0] === "=" && edit.acceptsExpressions) {
            _endEdit();
            edit.setExpression(text.slice(1).trim());
            return true;
        }
        const r = _parse(text);
        if (!r.ok) {
            _inputError = r.error;
            return false;
        }
        _endEdit();
        if (r.list) {
            listHandler(r.list);
            return true;
        }
        const typed = r.value / displayScale;
        const v = _clean(_limit(typed));
        if (!edit.same(v, typed))
            frame.flash();                      // rounded or clamped: show that it was corrected
        edit.instant(v);
        return true;
    }

    function cancelEdit() { _endEdit(); }

    // ---- internals

    property bool _scrub: false
    property bool _scrubCancelled: false
    property real _scrubStart: 0
    property real _scrubTravel: 0
    property real _wheel: 0
    property string _inputError
    property string _editStartText
    readonly property bool _focused: control.activeFocus || input.activeFocus
    // The display dropped decimals or the suffix for want of room.
    readonly property bool _cut: !edit.mixed && !textFromValue
                                 && (displayText !== _format(Number(edit.shown) * displayScale, Math.max(0, decimals))
                                     || (suffix !== "" && !suffixText.visible))
    readonly property color _ink: !enabled ? Theme.textTertiary
                                  : edit.driven ? Theme.driven
                                  : edit.mixed ? Theme.textSecondary
                                  : edit.invalid ? Theme.textTertiary : Theme.text

    on_FocusedChanged: if (!_focused) edit.flush()

    function _endEdit() {
        if (!editing)
            return;
        const hadFocus = input.activeFocus;
        _inputError = "";
        input.visible = false;
        if (hadFocus)
            control.forceActiveFocus(Qt.TabFocusReason);
    }

    // A step from the keyboard or wheel; while typing, the text is applied first.
    function _nudge(n, modifiers) {
        if (editing) {
            if (!commitEdit())
                return;
            stepBy(n, modifiers);
            beginEdit();
        } else {
            stepBy(n, modifiers);
        }
    }

    function _editText(): string {
        if (edit.mixed)
            return "";
        if ((edit.driven || edit.invalid) && edit.expression !== "")
            return "=" + edit.expression;
        return _plain(Number(edit.shown) * displayScale);
    }

    function _parse(text: string): var {
        let t = text;
        // The field's own suffix is accepted and ignored: "45°", "12 px". (But
        // "5cm" in a field of metres is a unit, not 5c followed by the suffix.)
        const unit = suffix.trim();
        if (unit !== "" && t.endsWith(unit) && !/[A-Za-z_]{2}$/.test(t.slice(0, t.length - unit.length + 1)))
            t = t.slice(0, -unit.length).trim();
        if (valueFromText) {
            const v = Number(valueFromText(t));
            return isFinite(v) ? { ok: true, value: v * displayScale } : { ok: false, error: qsTr("Not a number") };
        }
        if (listHandler) {
            const numbers = Expr.list(t);
            if (numbers)
                return { ok: true, list: numbers };
        }
        if (t[0] === "=")
            t = t.slice(1);
        return Expr.compute(t, {
            units: units,
            resolve: resolver,
            current: edit.mixed ? NaN : Number(edit.shown) * displayScale
        });
    }

    // Clamps to the hard limits. With `reference` (the value a drag or step
    // started from) also to the soft range, widened to include that value.
    function _limit(v: real, reference): real {
        let lo = minimum, hi = maximum;
        if (reference !== undefined && ranged) {
            if (wrap) {
                const span = to - from;
                return from + ((((v - from) % span) + span) % span);
            }
            lo = Math.max(lo, Math.min(from, reference));
            hi = Math.min(hi, Math.max(to, reference));
        }
        return Math.min(hi, Math.max(lo, v));
    }

    // Removes floating-point fuzz (0.30000000000000004), and fractions of ints.
    function _clean(v: real): real {
        return integer ? Math.round(v) : parseFloat(v.toPrecision(12));
    }

    function _format(v: real, places: int): string {
        let s = v.toFixed(places);
        if (places > 0)
            s = s.replace(/\.?0+$/, "");
        return Number(s) === 0 ? "0" : s;
    }

    function _plain(v: real): string {
        return String(parseFloat(v.toPrecision(12)));
    }

    function _positionOf(v: real): real {
        if (!ranged)
            return 0;
        const p = logarithmic && from > 0 ? Math.log(Math.max(v, from) / from) / Math.log(to / from)
                                          : (v - from) / (to - from);
        return Math.min(1, Math.max(0, p));
    }

    function _valueAt(p: real): real {
        const t = Math.min(1, Math.max(0, p));
        return logarithmic && from > 0 ? from * Math.pow(to / from, t) : from + (to - from) * t;
    }

    implicitWidth: 96
    implicitHeight: Theme.controlHeight
    leftPadding: steppers ? Theme.controlHeight : Theme.controlPadding
    rightPadding: steppers ? Theme.controlHeight : Theme.controlPadding
    activeFocusOnTab: true
    focusPolicy: Qt.TabFocus
    opacity: enabled ? 1 : 0.4

    Accessible.role: ranged ? Accessible.Slider : Accessible.SpinBox
    Accessible.name: lead
    Accessible.description: [edit.mixed ? "" : displayText + suffix, edit.stateText].filter(t => t !== "").join(", ")
    Accessible.editable: !edit.readOnly
    Accessible.onIncreaseAction: increase()
    Accessible.onDecreaseAction: decrease()

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.features: ({ "tnum": 1 })              // digits of equal width: nothing shifts while dragging

    Keys.onPressed: event => {
        if (control.editing)
            return;
        const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            control.stepBy(event.key === Qt.Key_Up ? 1 : -1, event.modifiers);
        } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
            control.stepBy(event.key === Qt.Key_PageUp ? 10 : -10, event.modifiers);
        } else if ((event.key === Qt.Key_Home || event.key === Qt.Key_End) && control.ranged && control.canScrub) {
            edit.step(event.key === Qt.Key_Home ? control.from : control.to);
        } else if (event.key === Qt.Key_Escape && (control._scrub || edit.active)) {
            control._scrubCancelled = control._scrub;   // later movement of this drag is ignored
            edit.end(false);                            // restores the value from before the drag or steps
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_F2) {
            control.beginEdit();
        } else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
            control.beginEdit("");
        } else if (event.matches(StandardKey.Copy)) {
            Clipboard.copy(control.copyText());
        } else if (event.matches(StandardKey.Paste)) {
            control.pasteText(Clipboard.paste());
        } else if (plain && event.text.length === 1 && event.text > " " && event.text !== "\x7f") {
            control.beginEdit(event.text);          // typing on a focused field replaces its value
        } else {
            return;
        }
        event.accepted = true;
    }

    FontMetrics { id: metrics; font: control.font }

    background: FieldFrame {
        id: frame
        hovered: mouse.containsMouse || minus.containsMouse || plus.containsMouse
        focused: control.focused && !control.flat
        invalid: (edit.invalid || control._inputError !== "") && !control.flat
        flat: control.flat || edit.readOnly

        // The slider part: how far along the soft range the value is.
        Rectangle {
            visible: control.ranged && !edit.mixed && !control.flat && !control.editing
            width: Math.round(parent.width * control.position)
            height: parent.height
            topLeftRadius: parent.radius
            bottomLeftRadius: parent.radius
            topRightRadius: control.position >= 1 ? parent.radius : 0
            bottomRightRadius: topRightRadius
            color: control._scrub ? Theme.mix(Theme.controlFill, Theme.accent, 0.45)
                 : frame.hovered ? Theme.mix(Theme.controlFill, Theme.text, 0.1) : Theme.controlFill
        }
    }

    contentItem: Item {
        id: content

        // Width the value text may use.
        readonly property real room: width - (leadText.visible ? leadText.width + 6 : 0)
                                     - (badge.visible ? badge.width + 4 : 0)

        Text {
            id: leadText
            anchors.verticalCenter: parent.verticalCenter
            visible: control.lead !== ""
            text: control.lead
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            renderType: Theme.textRenderType
        }

        Row {
            id: shown
            anchors.verticalCenter: parent.verticalCenter
            x: control.steppers ? Math.round((parent.width - width) / 2)
                                : (leadText.visible ? leadText.width + 6 : 0)
            visible: !control.editing

            Text {
                id: valueText
                text: control.displayText
                color: control._ink
                font: control.font
                renderType: Theme.textRenderType
            }
            Text {
                id: suffixText
                visible: control.suffix !== "" && !edit.mixed
                         && valueText.implicitWidth + implicitWidth <= content.room
                text: control.suffix
                color: edit.driven ? control._ink : Theme.textSecondary
                font: control.font
                renderType: Theme.textRenderType
            }
        }

        // "ƒ": this value is computed by something else.
        Text {
            id: badge
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            visible: edit.driven && !control.editing
            text: "ƒ"
            color: Theme.driven
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.italic: true
            renderType: Theme.textRenderType
        }

        TextInput {
            id: input
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: control.steppers ? 0 : shown.x
                verticalCenter: parent.verticalCenter
            }
            visible: false
            clip: true
            selectByMouse: true
            horizontalAlignment: control.steppers ? TextInput.AlignHCenter : TextInput.AlignLeft
            color: Theme.text
            selectionColor: Theme.textSelection
            selectedTextColor: Theme.text
            font: control.font
            renderType: Theme.textRenderType
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

            onTextEdited: control._inputError = ""
            onActiveFocusChanged: {
                // Clicking elsewhere applies the text. Text that can't be
                // understood is dropped: focus is never held hostage.
                if (!activeFocus && visible && !control.commitEdit())
                    control.cancelEdit();
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    control.commitEdit();
                } else if (event.key === Qt.Key_Escape) {
                    control.cancelEdit();
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    control._nudge(event.key === Qt.Key_Up ? 1 : -1, event.modifiers);
                } else if (event.key === Qt.Key_Backtab) {
                    // The field itself is the previous focus stop; skip past it.
                    if (!control.commitEdit())
                        control.cancelEdit();
                    const previous = control.nextItemInFocusChain(false);
                    if (previous)
                        previous.forceActiveFocus(Qt.BacktabFocusReason);
                } else {
                    return;
                }
                event.accepted = true;
            }
        }
    }

    // Click to type, drag sideways to scrub. A drag that starts mostly
    // vertical is neither, so scrolling a panel by pen or trackpad is safe.
    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.leftMargin: control.steppers ? Theme.controlHeight : 0
        anchors.rightMargin: control.steppers ? Theme.controlHeight : 0
        enabled: control.enabled && !control.editing
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        preventStealing: control._scrub
        cursorShape: control.canScrub ? Qt.SizeHorCursor
                   : edit.readOnly ? Qt.ArrowCursor : Qt.IBeamCursor

        property real pressX: 0
        property real pressY: 0
        property real lastX: 0
        property bool decided: false            // this press is a scrub, or not a click any more

        onPressed: event => {
            pressX = lastX = event.x;
            pressY = event.y;
            decided = false;
        }
        onPositionChanged: event => {
            if (!pressed)
                return;
            if (control._scrub) {
                control.scrubBy(event.x - lastX, event.modifiers);
                lastX = event.x;
            } else if (!decided) {
                const dx = Math.abs(event.x - pressX), dy = Math.abs(event.y - pressY);
                if (dx >= Theme.dragThreshold && dx >= dy) {
                    decided = true;
                    lastX = event.x;            // the value starts from here: no jump
                    control.scrubBegin();
                } else if (dy >= Theme.dragThreshold) {
                    decided = true;
                }
            }
        }
        onReleased: {
            if (control._scrub)
                control.scrubEnd(true);
            else if (!decided && containsMouse)
                control.beginEdit();
        }
        onCanceled: control.scrubEnd(false)
    }

    // The wheel only steps a field that has keyboard focus. Otherwise the
    // event is left for the panel to scroll.
    WheelHandler {
        enabled: control._focused && control.enabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            control._wheel += event.angleDelta.y;
            while (Math.abs(control._wheel) >= 120) {
                const n = control._wheel > 0 ? 1 : -1;
                control._wheel -= n * 120;
                control._nudge(n, event.modifiers);
            }
        }
    }

    component StepButton: MouseArea {
        id: button
        required property int direction
        width: Theme.controlHeight
        height: control.height
        visible: control.steppers
        enabled: control.enabled && !edit.readOnly && !edit.driven && !edit.mixed
        hoverEnabled: true

        onPressed: event => {
            control._nudge(direction, event.modifiers);
            repeat.interval = 400;
            repeat.start();
        }
        onReleased: repeat.stop()
        onCanceled: repeat.stop()

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Theme.innerRadius
            color: Theme.controlFill
            visible: button.pressed || button.containsMouse
            opacity: button.pressed ? 1 : 0.6
        }
        Icon {
            anchors.centerIn: parent
            name: button.direction > 0 ? "plus" : "minus"
            size: 10
            color: button.containsMouse ? Theme.text : Theme.textSecondary
        }
        // Holding repeats, slowly at first and then faster.
        Timer {
            id: repeat
            repeat: true
            onTriggered: {
                control._nudge(button.direction, Qt.NoModifier);
                interval = Math.max(30, interval > 200 ? 90 : interval - 4);
            }
        }
    }

    StepButton { id: minus; direction: -1 }
    StepButton { id: plus; direction: 1; x: control.width - width }

    // Why the text was refused; else what drives the value; else the whole
    // value, when there was no room to show all of it.
    Tip {
        text: control._inputError !== "" ? control._inputError
            : edit.message !== "" ? edit.message
            : control._cut ? control._plain(Number(edit.shown) * control.displayScale) + control.suffix : ""
        shown: control._inputError !== "" || mouse.containsMouse
        pressed: mouse.pressed
        immediate: control._inputError !== ""
    }

    // A press elsewhere in the window applies the typed text first, before
    // whatever was clicked can act on it (change the selection, say).
    PressOutside {
        target: control
        active: control.editing
        onPressed: {
            if (!control.commitEdit())
                control.cancelEdit();
            control.focus = false;
        }
    }

    ValueEdit { id: edit; owner: control; live: control.live }
}
