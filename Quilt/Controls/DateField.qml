pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// A date, a time, or both, shown as segments: 2026-11-12  14:30.
//
//     DateField { value: task.due; onEdited: d => task.due = d }
//     DateField { mode: "time"; seconds: true; … }
//     DateField { mode: "datetime"; … }
//
// Each segment works like a small number field: click it, then type digits
// (the selection moves on when a segment is full), press Up/Down, or drag it
// sideways. Stepping carries into the next segment, and the day is kept
// within the month, so the field can't hold an impossible date. The button
// opens a month to pick from.
T.Control {
    id: control

    property date value: new Date()
    property string mode: "date"            // "date", "time" or "datetime"
    property bool seconds: false            // show seconds in the time
    property var minimum                    // optional earliest and latest dates
    property var maximum
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
    readonly property bool calendarOpen: _calendar !== null
    readonly property string displayText: edit.mixed ? "" : _text(_date)

    signal editStarted()
    signal edited(date value)
    signal editFinished(bool committed)
    signal expressionEdited(string text)

    function reset() { edit.reset(); }
    function setExpression(text: string) { edit.setExpression(text); }
    function activate() {
        control.forceActiveFocus(Qt.TabFocusReason);
        _segment = 0;
    }
    function copyText(): string { return displayText; }
    function pasteText(text: string) {
        const d = _parse(text);
        if (d !== null && !_locked)
            edit.instant(_limit(d));
    }

    function openCalendar() {
        if (_locked || _calendar || mode === "time")
            return;
        _flushTyping();
        _calendar = calendarComponent.createObject(control);
        _calendar.open();
    }

    // ---- internals

    readonly property date _date: edit.shown
    readonly property bool _locked: edit.readOnly || edit.driven || !enabled
    readonly property bool _hasDate: mode !== "time"
    readonly property bool _hasTime: mode !== "date"
    // What is shown, in order: key, width in digits, and the text before it.
    readonly property var _segments: {
        const out = [];
        if (_hasDate)
            out.push({ key: "Y", digits: 4, before: "" }, { key: "M", digits: 2, before: "-" }, { key: "D", digits: 2, before: "-" });
        if (_hasTime) {
            out.push({ key: "h", digits: 2, before: _hasDate ? "  " : "" }, { key: "m", digits: 2, before: ":" });
            if (seconds)
                out.push({ key: "s", digits: 2, before: ":" });
        }
        return out;
    }
    property int _segment: 0                // the segment keys act on
    property string _typed                  // digits typed into it so far
    property T.Popup _calendar: null

    function _daysIn(year: int, month: int): int { return new Date(year, month, 0).getDate(); }   // month: 1..12

    function _get(d: date, key: string): int {
        switch (key) {
        case "Y": return d.getFullYear();
        case "M": return d.getMonth() + 1;
        case "D": return d.getDate();
        case "h": return d.getHours();
        case "m": return d.getMinutes();
        default: return d.getSeconds();
        }
    }

    function _max(key: string): int {
        return key === "Y" ? 9999 : key === "M" ? 12 : key === "D" ? 31 : key === "h" ? 23 : 59;
    }

    function _build(y: int, mo: int, d: int, h: int, mi: int, s: int): date {
        const year = Math.min(9999, Math.max(1, y));
        const month = Math.min(12, Math.max(1, mo));
        const out = new Date(2000, month - 1, Math.min(_daysIn(year, month), Math.max(1, d)),
                             Math.min(23, Math.max(0, h)), Math.min(59, Math.max(0, mi)), Math.min(59, Math.max(0, s)));
        out.setFullYear(year);                  // the constructor reads years 0..99 as 1900..1999
        return out;
    }

    // `d` with one segment set to `n`; the day is kept within the month.
    function _with(d: date, key: string, n: int): date {
        const v = k => k === key ? n : _get(d, k);
        return _build(v("Y"), v("M"), v("D"), v("h"), v("m"), v("s"));
    }

    // `d` with `n` added to one segment, carrying into the larger ones.
    function _add(d: date, key: string, n: int): date {
        if (key === "Y")
            return _with(d, "Y", d.getFullYear() + n);
        if (key === "M") {
            const months = d.getFullYear() * 12 + d.getMonth() + n;
            return _build(Math.floor(months / 12), months % 12 + 1, d.getDate(), d.getHours(), d.getMinutes(), d.getSeconds());
        }
        if (key === "D")
            return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n, d.getHours(), d.getMinutes(), d.getSeconds());
        return new Date(d.getTime() + n * (key === "h" ? 3600000 : key === "m" ? 60000 : 1000));
    }

    function _limit(d: date): date {
        if (minimum !== undefined && minimum !== null && d < minimum)
            return minimum;
        if (maximum !== undefined && maximum !== null && d > maximum)
            return maximum;
        return d;
    }

    function _pad(n: int, digits: int): string {
        let s = String(n);
        while (s.length < digits)
            s = "0" + s;
        return s;
    }

    function _text(d: date): string {
        if (isNaN(d.getTime()))
            return "";
        return _segments.map(s => s.before + _pad(_get(d, s.key), s.digits)).join("");
    }

    // A date from "2026-11-12", "14:30", "2026-11-12 14:30:05" or anything
    // else JavaScript can read; null otherwise.
    function _parse(text: string): var {
        const t = text.trim();
        const m = /^(?:(\d{1,4})[-\/.](\d{1,2})[-\/.](\d{1,2}))?(?:[T\s]*(\d{1,2}):(\d{2})(?::(\d{2}))?)?$/.exec(t);
        if (m && (m[1] !== undefined || m[4] !== undefined)) {
            const base = _date;
            return _build(m[1] !== undefined ? Number(m[1]) : base.getFullYear(),
                          m[2] !== undefined ? Number(m[2]) : base.getMonth() + 1,
                          m[3] !== undefined ? Number(m[3]) : base.getDate(),
                          m[4] !== undefined ? Number(m[4]) : base.getHours(),
                          m[5] !== undefined ? Number(m[5]) : base.getMinutes(),
                          m[6] !== undefined ? Number(m[6]) : (m[4] !== undefined ? 0 : base.getSeconds()));
        }
        const parsed = new Date(t);
        return t !== "" && !isNaN(parsed.getTime()) ? parsed : null;
    }

    function _stepSegment(n: int, modifiers: int) {
        if (_locked || edit.mixed)
            return;
        _flushTyping();
        const key = _segments[_segment].key;
        edit.step(_limit(_add(_date, key, n * (modifiers & Qt.ShiftModifier ? 10 : 1))));
    }

    // Applies the digits typed into the current segment.
    function _flushTyping() {
        if (_typed === "")
            return;
        const n = parseInt(_typed);
        const key = _segments[_segment].key;
        _typed = "";
        if (!_locked && !(n === 0 && (key === "Y" || key === "M" || key === "D")))
            edit.instant(_limit(_with(_date, key, n)));
    }

    function _typeDigit(digit: string) {
        if (_locked)
            return;
        const seg = _segments[_segment];
        _typed += digit;
        // Full, or no further digit could fit: apply and move on.
        if (_typed.length >= seg.digits || parseInt(_typed) * 10 > _max(seg.key)) {
            _flushTyping();
            if (_segment < _segments.length - 1)
                _segment += 1;
        }
    }

    function _moveSegment(delta: int) {
        _flushTyping();
        _segment = Math.min(_segments.length - 1, Math.max(0, _segment + delta));
    }

    on_SegmentsChanged: _segment = Math.min(_segment, Math.max(0, _segments.length - 1))
    onActiveFocusChanged: {
        if (!activeFocus) {
            _flushTyping();
            edit.flush();
        }
    }

    implicitWidth: row.implicitWidth + leftPadding + rightPadding
    implicitHeight: Theme.controlHeight
    leftPadding: Theme.controlPadding
    rightPadding: _hasDate ? Theme.controlHeight : Theme.controlPadding
    activeFocusOnTab: true
    focusPolicy: Qt.TabFocus
    opacity: enabled ? 1 : 0.4

    Accessible.role: Accessible.EditableText
    Accessible.description: [displayText, edit.stateText].filter(t => t !== "").join(", ")
    Accessible.readOnly: _locked

    font.family: Theme.fontFamilyValue
    font.pixelSize: Theme.fontSize
    font.features: ({ "tnum": 1 })

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) {
            control._moveSegment(-1);
        } else if (event.key === Qt.Key_Right) {
            control._moveSegment(1);
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            control._stepSegment(event.key === Qt.Key_Up ? 1 : -1, event.modifiers);
        } else if (event.key === Qt.Key_Escape && (control._typed !== "" || edit.active)) {
            control._typed = "";
            edit.end(false);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            control._flushTyping();
            edit.flush();
        } else if (event.key === Qt.Key_Backspace) {
            control._typed = control._typed.slice(0, -1);
        } else if (event.key === Qt.Key_Space && control._hasDate) {
            control.openCalendar();
        } else if (event.matches(StandardKey.Copy)) {
            Clipboard.copy(control.copyText());
        } else if (event.matches(StandardKey.Paste)) {
            control.pasteText(Clipboard.paste());
        } else if (event.text >= "0" && event.text <= "9" && event.text.length === 1) {
            control._typeDigit(event.text);
        } else if ("-/.: ".indexOf(event.text) >= 0 && event.text.length === 1) {
            control._moveSegment(1);            // typing a separator moves on, as when writing a date out
        } else {
            return;
        }
        event.accepted = true;
    }

    background: FieldFrame {
        hovered: hover.hovered
        focused: control.activeFocus
        invalid: edit.invalid
        flat: edit.readOnly
    }
    HoverHandler { id: hover }

    contentItem: Item {
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: edit.mixed
            text: qsTr("Mixed")
            color: Theme.textSecondary
            font: control.font
            renderType: Theme.textRenderType
        }

        Row {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            visible: !edit.mixed

            Repeater {
                model: control._segments
                delegate: Row {
                    id: part
                    required property var modelData
                    required property int index
                    readonly property bool current: control.activeFocus && control._segment === index

                    Text {
                        text: part.modelData.before
                        color: Theme.textTertiary
                        font: control.font
                        renderType: Theme.textRenderType
                        // A double space between date and time, kept as typed.
                        textFormat: Text.PlainText
                    }
                    Text {
                        id: digits
                        text: part.current && control._typed !== ""
                              ? control._typed
                              : control._pad(control._get(control._date, part.modelData.key), part.modelData.digits)
                        color: !control.enabled ? Theme.textTertiary : edit.driven ? Theme.driven : Theme.text
                        font: control.font
                        renderType: Theme.textRenderType

                        Rectangle {
                            anchors { fill: parent; leftMargin: -2; rightMargin: -2; topMargin: -1; bottomMargin: -1 }
                            z: -1
                            radius: Theme.controlRadius / 2
                            color: Theme.textSelection
                            visible: part.current
                        }

                        // Click to select the segment; drag sideways to scrub it.
                        MouseArea {
                            anchors { fill: parent; margins: -4 }
                            enabled: !control._locked
                            cursorShape: Qt.SizeHorCursor
                            preventStealing: scrubbing
                            property bool scrubbing: false
                            property real pressX: 0
                            property real travel: 0
                            property int applied: 0
                            property date start

                            onPressed: event => {
                                pressX = event.x;
                                control._flushTyping();
                                control._segment = part.index;
                                control.forceActiveFocus(Qt.TabFocusReason);
                            }
                            onPositionChanged: event => {
                                if (!pressed)
                                    return;
                                if (!scrubbing) {
                                    if (Math.abs(event.x - pressX) < Theme.dragThreshold)
                                        return;
                                    scrubbing = true;
                                    pressX = event.x;
                                    travel = 0;
                                    applied = 0;
                                    start = control._date;
                                    edit.begin();
                                }
                                // 6 px a step; Shift makes it ten.
                                travel += (event.x - pressX) / 6 * (event.modifiers & Qt.ShiftModifier ? 10 : 1);
                                pressX = event.x;
                                const n = Math.round(travel);
                                if (n !== applied) {
                                    applied = n;
                                    edit.set(control._limit(control._add(start, part.modelData.key, n)));
                                }
                            }
                            onReleased: {
                                if (scrubbing) {
                                    scrubbing = false;
                                    edit.end(true);
                                }
                            }
                            onCanceled: {
                                if (scrubbing) {
                                    scrubbing = false;
                                    edit.end(false);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IconButton {
        anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
        width: 20
        height: 20
        visible: control._hasDate && !edit.readOnly
        enabled: !control._locked
        iconName: "calendar"
        tip: qsTr("Pick a date")
        onClicked: control.openCalendar()
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
                control._stepSegment(n, event.modifiers);
            }
        }
    }

    Component {
        id: calendarComponent

        // A month to pick a day from.
        T.Popup {
            id: calendar

            property int year: control._date.getFullYear()
            property int month: control._date.getMonth()         // 0..11
            readonly property int firstColumn: {
                const first = new Date(year, month, 1).getDay();        // 0: Sunday
                return (first - Qt.locale().firstDayOfWeek + 7) % 7;
            }

            function shift(months: int) {
                const m = year * 12 + month + months;
                year = Math.floor(m / 12);
                month = m % 12;
            }

            x: Math.max(0, control.width - implicitWidth)
            y: control.height + 4
            padding: 8
            margins: 6
            focus: true
            popupType: Theme.popupType
            closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside
            implicitWidth: contentWidth + leftPadding + rightPadding
            implicitHeight: contentHeight + topPadding + bottomPadding

            onClosed: {
                control._calendar = null;
                destroy();
            }

            enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast } }
            exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationFast } }

            background: PopupBackground { }

            contentItem: Column {
                spacing: 4
                width: 7 * 26

                Item {
                    width: parent.width
                    height: Theme.controlHeight
                    IconButton { width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter; iconName: "chevron-left"; onClicked: calendar.shift(-1) }
                    Text {
                        anchors.centerIn: parent
                        text: Qt.locale().standaloneMonthName(calendar.month, Locale.LongFormat) + " " + calendar.year
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Theme.fontWeightStrong
                        renderType: Theme.textRenderType
                    }
                    IconButton { width: 22; height: 22; anchors { right: parent.right; verticalCenter: parent.verticalCenter } iconName: "chevron-right"; onClicked: calendar.shift(1) }
                }

                Row {
                    Repeater {
                        model: 7
                        delegate: Text {
                            required property int index
                            width: 26
                            height: 18
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: Qt.locale().standaloneDayName((Qt.locale().firstDayOfWeek + index) % 7, Locale.NarrowFormat)
                            color: Theme.textTertiary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            renderType: Theme.textRenderType
                        }
                    }
                }

                Grid {
                    columns: 7
                    Repeater {
                        model: 42
                        delegate: Item {
                            id: cell
                            required property int index
                            readonly property date day: new Date(calendar.year, calendar.month, 1 - calendar.firstColumn + index)
                            readonly property bool inMonth: day.getMonth() === calendar.month
                            readonly property bool selected: !edit.mixed && day.getFullYear() === control._date.getFullYear()
                                && day.getMonth() === control._date.getMonth() && day.getDate() === control._date.getDate()
                            readonly property bool today: {
                                const now = new Date();
                                return day.getFullYear() === now.getFullYear() && day.getMonth() === now.getMonth()
                                    && day.getDate() === now.getDate();
                            }
                            width: 26
                            height: 24

                            Face {
                                anchors { fill: parent; margins: 1 }
                                role: Face.Item
                                checked: cell.selected
                                hovered: cellHover.hovered
                                marked: cell.today
                            }
                            Text {
                                anchors.centerIn: parent
                                text: cell.day.getDate()
                                color: cell.selected ? Theme.accentInk : cell.inMonth ? Theme.text : Theme.textTertiary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.features: ({ "tnum": 1 })
                                renderType: Theme.textRenderType
                            }
                            HoverHandler { id: cellHover }
                            TapHandler {
                                onTapped: {
                                    const d = control._date;
                                    edit.instant(control._limit(control._build(cell.day.getFullYear(), cell.day.getMonth() + 1,
                                        cell.day.getDate(), d.getHours(), d.getMinutes(), d.getSeconds())));
                                    calendar.close();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Tip { text: edit.message; shown: hover.hovered && !control.calendarOpen }

    // Digits typed into a segment are applied before a press elsewhere acts.
    PressOutside {
        target: control
        active: control.activeFocus && control._typed !== ""
        onPressed: {
            control._flushTyping();
            edit.flush();
        }
    }

    ValueEdit { id: edit; owner: control; fallback: new Date(); live: control.live }
}
