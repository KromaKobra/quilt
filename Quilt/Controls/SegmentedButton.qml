pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// One of a few options, all visible at once.
//
//     SegmentedButton { model: ["Left", "Center", "Right"]; value: text.align; onEdited: v => text.align = v }
//     SegmentedButton { model: [{ text: "B", value: "bold" }, { text: "I", value: "italic" }]
//                       exclusive: false; value: text.styles; onEdited: v => text.styles = v }
//
// An option is a string, or { text, value, icon, tip, enabled }; `value`
// defaults to the text. With exclusive: false it is a row of independent
// toggles and `value` is the array of the options that are on.
T.Control {
    id: control

    property var model: []
    property var value
    property bool exclusive: true

    property var param: null
    property var defaultValue
    property int paramState: Param.Normal
    property string expression
    property string message
    property bool readOnly: false
    property bool acceptsExpressions: false

    readonly property bool modified: edit.modified
    readonly property bool fillsRow: true
    readonly property int count: _options.length
    readonly property int currentIndex: exclusive && !edit.mixed ? _options.findIndex(o => edit.same(o.value, edit.shown)) : -1

    signal editStarted()
    signal edited(var value)
    signal editFinished(bool committed)
    signal expressionEdited(string text)

    function reset() { edit.reset(); }
    function setExpression(text: string) { edit.setExpression(text); }  // "" removes it
    function activate() { control.forceActiveFocus(Qt.TabFocusReason); }
    function copyText(): string { return edit.mixed ? "" : edit.isList(edit.shown) ? edit.list(edit.shown).join(", ") : String(edit.shown ?? ""); }
    function pasteText(text: string) {
        const i = _options.findIndex(o => String(o.value) === text.trim() || o.text === text.trim());
        if (i >= 0 && exclusive)
            choose(i);
    }

    function isOn(index: int): bool {
        if (edit.mixed || index < 0 || index >= count)
            return false;
        const v = edit.shown;
        return exclusive ? edit.same(_options[index].value, v)
                         : edit.list(v).some(x => edit.same(x, _options[index].value));
    }

    // Picks an option, or toggles it when not exclusive.
    function choose(index: int) {
        if (edit.readOnly || edit.driven || index < 0 || index >= count || !_options[index].enabled)
            return;
        const picked = _options[index].value;
        if (exclusive) {
            if (!isOn(index))
                edit.instant(picked);
            return;
        }
        const now = edit.mixed ? [] : edit.list(edit.shown);
        const without = now.filter(x => !edit.same(x, picked));
        // Kept in the order of the options, so the result doesn't depend on click order.
        const next = without.length === now.length ? now.concat([picked]) : without;
        edit.instant(_options.map(o => o.value).filter(x => next.some(y => edit.same(x, y))));
    }

    readonly property var _options: (model || []).map(o => {
        if (o !== null && typeof o === "object")
            return { text: o.text ?? "", value: o.value !== undefined ? o.value : o.text,
                     icon: o.icon ?? "", tip: o.tip ?? "", enabled: o.enabled !== false };
        return { text: String(o), value: o, icon: "", tip: "", enabled: true };
    })
    property int _cursor: 0                 // keyboard position among independent toggles

    function _move(delta: int) {
        const start = exclusive ? (currentIndex >= 0 ? currentIndex : (delta > 0 ? -1 : count)) : _cursor;
        for (let i = start + delta; i >= 0 && i < count; i += delta) {
            if (_options[i].enabled) {
                if (exclusive)
                    choose(i);
                else
                    _cursor = i;
                return;
            }
        }
    }

    implicitWidth: Math.max(72, count * (_widest + 20) + 4)
    implicitHeight: Theme.controlHeight
    padding: 2
    activeFocusOnTab: true
    focusPolicy: Qt.TabFocus
    opacity: enabled ? 1 : 0.4

    Accessible.role: Accessible.Grouping
    Accessible.description: [copyText(), edit.stateText].filter(t => t !== "").join(", ")

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    readonly property real _widest: {
        let w = 12;
        for (const o of _options)
            w = Math.max(w, (o.text !== "" ? metrics.advanceWidth(o.text) : 0) + (o.icon !== "" ? 12 + (o.text !== "" ? 5 : 0) : 0));
        return Math.ceil(w);
    }
    FontMetrics { id: metrics; font: control.font }

    Keys.onLeftPressed: _move(-1)
    Keys.onRightPressed: _move(1)
    Keys.onSpacePressed: if (!exclusive) choose(_cursor)

    background: Face {
        role: Face.Track
        focused: control.visualFocus
        focusRing: true
    }

    contentItem: Item {
        id: track
        readonly property real segment: control.count > 0 ? width / control.count : 0

        // The selection slides between segments.
        Face {
            visible: control.exclusive && control.currentIndex >= 0
            x: Math.max(0, control.currentIndex) * track.segment
            width: track.segment
            height: parent.height
            role: Face.Segment
            checked: true
            driven: edit.driven
            Behavior on x { NumberAnimation { duration: Theme.duration; easing.type: Theme.easing } }
        }

        Repeater {
            model: control._options
            delegate: Item {
                id: segment
                required property var modelData
                required property int index
                readonly property bool on: control.isOn(index)

                x: index * track.segment
                width: track.segment
                height: track.height
                opacity: modelData.enabled ? 1 : 0.4

                Accessible.role: control.exclusive ? Accessible.RadioButton : Accessible.CheckBox
                Accessible.name: modelData.text !== "" ? modelData.text : modelData.tip
                Accessible.checkable: true
                Accessible.checked: on
                Accessible.onPressAction: control.choose(index)

                Face {
                    anchors.fill: parent
                    visible: !control.exclusive && (segment.on || focused)
                    role: Face.Segment
                    checked: segment.on
                    focused: control.visualFocus && control._cursor === segment.index
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: segment.modelData.icon !== ""
                        name: segment.modelData.icon
                        color: label.color
                    }
                    Text {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: segment.modelData.text
                        color: segment.on || hover.hovered ? Theme.text : Theme.textSecondary
                        font: control.font
                        renderType: Theme.textRenderType
                    }
                }

                HoverHandler { id: hover; enabled: segment.modelData.enabled && !edit.readOnly }
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        control._cursor = segment.index;
                        control.choose(segment.index);
                    }
                }
                Tip { text: segment.modelData.tip !== "" ? segment.modelData.tip : edit.message; shown: hover.hovered }
            }
        }
    }

    ValueEdit { id: edit; owner: control; fallback: null }
}
