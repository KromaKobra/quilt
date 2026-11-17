pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// One of many options. Qt's ComboBox API, plus `value`: bind it to the
// selected option's value instead of juggling indexes.
//
//     ComboBox { model: ["Normal", "Multiply", "Screen"]; value: layer.blend; onEdited: v => layer.blend = v }
//     ComboBox { model: [{ text: "Low", value: 1 }, { text: "High", value: 3 }]
//                value: render.quality; onEdited: v => render.quality = v }
//
// An array of { text, value } objects needs no textRole or valueRole. Such
// an option may also carry `icon` (an Icon name), `color` (a chip),
// `enabled: false`, or be `{ separator: true }`.
//
// With more than `filterThreshold` options, typing while the list is open
// narrows it to the options that contain what was typed.
T.ComboBox {
    id: control

    // The value of the selected option: its valueRole, or its text when
    // the model has no values. Leave it unset to work with currentIndex.
    property var value
    property int filterThreshold: 12            // more options than this, and typing filters the open list

    property var param: null
    property var defaultValue
    property int paramState: Param.Normal
    property string expression
    property string message
    property bool readOnly: false
    property bool acceptsExpressions: false

    readonly property bool modified: edit.modified
    readonly property bool fillsRow: true
    readonly property bool filterable: count > filterThreshold
    readonly property alias filterText: control._filter

    signal editStarted()
    signal edited(var value)
    signal editFinished(bool committed)
    signal expressionEdited(string text)

    function reset() { edit.reset(); }
    function setExpression(text: string) { edit.setExpression(text); }  // "" removes it
    function activate() {
        control.forceActiveFocus(Qt.TabFocusReason);
        if (!_locked)
            control.popup.open();
    }
    function copyText(): string { return edit.mixed ? "" : control.currentText; }
    function pasteText(text: string) {
        const i = control.find(text.trim());
        if (i >= 0 && !_locked)
            edit.instant(_valueAt(i));
    }

    readonly property bool _locked: edit.readOnly || edit.driven
    // A JS array of objects (it reaches us as a list, not a true Array).
    readonly property bool _objects: !!model && typeof model === "object" && model.length > 0
                                     && model[0] !== null && typeof model[0] === "object"
    property real _popupWidth: 0
    property string _filter
    property int _hi: -1                        // the option highlighted in the open list
    property bool _open: false                  // from the moment it opens until it starts to close
    property bool _chooseOnRelease: false
    property bool _pointerMoved: false          // since the list opened

    // The option as the model holds it, when that is an object: { text, icon, … }.
    function _raw(index: int): var {
        const m = model;
        if (!m || typeof m !== "object" || index < 0 || index >= count)
            return null;
        const o = typeof m.get === "function" ? m.get(index) : m[index];
        return o !== null && typeof o === "object" ? o : null;
    }

    function _selectable(index: int): bool {
        const o = _raw(index);
        return index >= 0 && index < count && !(o && (o.enabled === false || o.separator === true));
    }

    function _matches(index: int): bool {
        if (_filter === "")
            return true;
        const o = _raw(index);
        return !(o && o.separator === true) && textAt(index).toLowerCase().indexOf(_filter.toLowerCase()) >= 0;
    }

    // The next option after (delta 1) or before (delta -1) `from` that can be chosen, or -1.
    function _next(from: int, delta: int): int {
        for (let i = from + delta; i >= 0 && i < count; i += delta)
            if (_selectable(i) && _matches(i))
                return i;
        return -1;
    }

    function _highlight(index: int) {
        if (index >= 0)
            _hi = index;
    }

    function _choose(index: int) {
        if (!_selectable(index))
            return;
        popup.close();
        currentIndex = index;
        activated(index);
    }

    on_FilterChanged: if (!_matches(_hi) || !_selectable(_hi)) _hi = _next(-1, 1)

    function _valueAt(index: int): var {
        return valueRole !== "" ? valueAt(index) : textAt(index);
    }

    function _indexOf(v): int {
        if (v === undefined || v === null)
            return -1;
        return valueRole !== "" ? indexOfValue(v) : find(String(v), Qt.MatchExactly);
    }

    // Keeps the shown option in step with `value`.
    function _follow() {
        if (value === undefined)
            return;                             // the application works with currentIndex
        const i = edit.mixed ? -1 : _indexOf(value);
        if (currentIndex !== i)
            currentIndex = i;
    }

    textRole: _objects && model[0].text !== undefined ? "text" : ""
    valueRole: _objects && model[0].value !== undefined ? "value" : ""

    onValueChanged: _follow()
    onCountChanged: _follow()
    Component.onCompleted: _follow()
    Connections {
        target: edit
        function onMixedChanged() { control._follow(); }
    }

    onActivated: index => {
        if (control._locked || !control._selectable(index))
            control._follow();
        else
            edit.instant(control._valueAt(index));
        if (control.value !== undefined)
            control._follow();                  // a refused choice snaps back
    }

    // Arrow keys skip what can't be chosen. In the open list, typing filters.
    Keys.onPressed: event => {
        const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
        if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            const delta = event.key === Qt.Key_Up ? -1 : 1;
            if (control._open) {
                control._highlight(control._next(control._hi, delta));
            } else if (!control._locked) {
                const i = control._next(control.currentIndex, delta);
                if (i >= 0) {
                    control.currentIndex = i;
                    control.activated(i);
                }
            }
        } else if (!control._open) {
            return;
        } else if (event.key === Qt.Key_Home) {
            control._highlight(control._next(-1, 1));
        } else if (event.key === Qt.Key_End) {
            control._highlight(control._next(control.count, -1));
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                   || (event.key === Qt.Key_Space && control._filter === "")) {
            control._chooseOnRelease = true;    // as the template does: on release
        } else if (event.key === Qt.Key_Escape && control._filter !== "") {
            control._filter = "";               // a second Esc closes the list
        } else if (event.key === Qt.Key_Backspace && control.filterable) {
            control._filter = control._filter.slice(0, -1);
        } else if (control.filterable && plain && event.text.length === 1 && event.text >= " " && event.text !== "\x7f") {
            control._filter += event.text;
        } else {
            return;
        }
        event.accepted = true;
    }
    Keys.onReleased: event => {
        if (!control._open || (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Space))
            return;
        if (control._chooseOnRelease)
            control._choose(control._hi);
        control._chooseOnRelease = false;
        event.accepted = true;                  // the template would pick its own highlight
    }

    implicitWidth: 120
    implicitHeight: Theme.controlHeight
    leftPadding: Theme.controlPadding
    rightPadding: Theme.controlPadding + 14
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true
    wheelEnabled: visualFocus                   // the wheel only acts on a focused control
    opacity: enabled ? 1 : 0.4

    Accessible.description: [edit.mixed ? "" : displayText, edit.stateText].filter(t => t !== "").join(", ")

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    FontMetrics { id: metrics; font: control.font }

    contentItem: Item {
        id: shown
        readonly property var raw: edit.mixed ? null : control._raw(control.currentIndex)

        OptionMark {
            id: shownMark
            anchors.verticalCenter: parent.verticalCenter
            raw: shown.raw
        }
        Text {
            objectName: "shownText"
            anchors { left: shownMark.right; right: parent.right; verticalCenter: parent.verticalCenter }
            text: edit.mixed ? qsTr("Mixed") : control.displayText
            color: !control.enabled ? Theme.textTertiary
                 : edit.mixed ? Theme.textSecondary
                 : edit.driven ? Theme.driven
                 : edit.invalid ? Theme.textTertiary : Theme.text
            font: control.font
            renderType: Theme.textRenderType
            elide: Text.ElideRight
        }
    }

    // An option's icon or colour chip; takes no room when it has neither.
    component OptionMark: Item {
        id: mark
        property var raw: null
        readonly property string iconName: raw && raw.icon ? String(raw.icon) : ""
        readonly property bool chip: !!raw && raw.color !== undefined && raw.color !== null
        width: iconName !== "" || chip ? 18 : 0
        height: 12
        Icon {
            visible: mark.iconName !== ""
            name: mark.iconName
            color: mark.enabled ? Theme.textSecondary : Theme.textTertiary
        }
        Rectangle {
            visible: mark.chip && mark.iconName === ""
            y: 1
            width: 10
            height: 10
            radius: Theme.innerRadius
            color: mark.chip ? mark.raw.color : "transparent"
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.15)
        }
    }

    indicator: Icon {
        x: control.width - width - Theme.controlPadding
        y: Math.round((control.height - height) / 2)
        name: "chevron-down"
        size: 10
        visible: !edit.readOnly
        color: control.hovered || control.down ? Theme.text : Theme.textSecondary
    }

    background: FieldFrame {
        hovered: control.hovered || control.down
        focused: control.visualFocus
        invalid: edit.invalid
        flat: edit.readOnly
    }

    delegate: T.ItemDelegate {
        id: option
        required property var model
        required property int index
        readonly property var raw: control._raw(index)
        readonly property bool separator: !!raw && raw.separator === true
        readonly property bool matches: control._matches(index)
        readonly property bool current: control.currentIndex === index

        width: ListView.view ? ListView.view.width : implicitWidth
        height: !matches ? 0 : separator ? 9 : Theme.controlHeight + 2
        visible: matches
        enabled: !separator && !(raw && raw.enabled === false)
        leftPadding: 26
        rightPadding: 10
        highlighted: control._hi === index
        hoverEnabled: control.hoverEnabled
        text: control.textAt(index)
        font: control.font

        contentItem: Item {
            visible: !option.separator
            OptionMark {
                id: optionMark
                objectName: "mark"
                anchors.verticalCenter: parent.verticalCenter
                raw: option.raw
                enabled: option.enabled
            }
            Text {
                objectName: "optionText"
                anchors { left: optionMark.right; right: parent.right; verticalCenter: parent.verticalCenter }
                text: option.text
                color: option.enabled ? Theme.text : Theme.textTertiary
                font: option.font
                renderType: Theme.textRenderType
                elide: Text.ElideRight
            }
        }
        background: Face {
            role: Face.Item
            hovered: option.highlighted && option.enabled && !option.separator
            Icon {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                name: "check"
                size: 10
                color: Theme.text
                visible: option.current && !option.separator
            }
            Rule {
                visible: option.separator
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 1
            }
        }
    }

    popup: T.Popup {
        id: list
        y: control.height + 4
        width: Math.max(control.width, control._popupWidth)
        height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding,
                         (control.filterable ? Theme.controlHeight + 5 : 0)
                         + 12 * (Theme.controlHeight + 2) + topPadding + bottomPadding,
                         control.Window.height - topMargin - bottomMargin)
        margins: 4
        padding: 4
        popupType: Theme.popupType

        onAboutToHide: control._open = false
        onAboutToShow: {
            control._open = true;
            control._chooseOnRelease = false;
            control._pointerMoved = false;
            control._filter = "";
            control._hi = control._selectable(control.currentIndex) ? control.currentIndex : -1;
            // Wide enough for the longest option.
            let w = 0, marks = false;
            for (let i = 0; i < control.count; ++i) {
                w = Math.max(w, metrics.advanceWidth(control.textAt(i)));
                const o = control._raw(i);
                marks = marks || (!!o && (!!o.icon || (o.color !== undefined && o.color !== null)));
            }
            control._popupWidth = Math.min(360, Math.ceil(w) + 26 + 10 + (marks ? 18 : 0) + 2 * padding);
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationFast } }

        contentItem: Item {
            implicitHeight: (filterBar.visible ? filterBar.height + 5 : 0)
                            + (options.contentHeight > 0 ? options.contentHeight : Theme.controlHeight + 2)

            // What has been typed. The keyboard stays with the dropdown, so
            // the arrow keys and Enter work while filtering.
            Item {
                id: filterBar
                objectName: "filterBar"
                visible: control.filterable
                width: parent.width
                height: Theme.controlHeight
                Icon {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    size: 10
                    color: Theme.textTertiary
                }
                Text {
                    anchors { left: parent.left; leftMargin: 26; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: control._filter !== "" ? control._filter : qsTr("Type to filter")
                    color: control._filter !== "" ? Theme.text : Theme.textTertiary
                    font: control.font
                    renderType: Theme.textRenderType
                    elide: Text.ElideLeft
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.bottom; topMargin: 2 }
                    height: 1
                    color: Theme.border
                }
            }

            ListView {
                id: options
                objectName: "options"
                anchors { fill: parent; topMargin: filterBar.visible ? filterBar.height + 5 : 0 }
                clip: true
                model: control.delegateModel
                currentIndex: control._hi
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                T.ScrollBar.vertical: ScrollBar { }

                // Hovering highlights an option, and nothing more. Only once the
                // pointer moves, though: a list that opens under a resting
                // pointer keeps the highlight the keyboard is steering.
                HoverHandler {
                    property point rest: Qt.point(-1, -1)
                    onHoveredChanged: rest = Qt.point(-1, -1)
                    onPointChanged: {
                        if (!hovered)
                            return;
                        const p = point.position;
                        if (rest.x < 0)
                            rest = p;
                        else if (Math.abs(p.x - rest.x) + Math.abs(p.y - rest.y) >= 2)
                            control._pointerMoved = true;
                        if (!control._pointerMoved)
                            return;
                        const i = options.indexAt(p.x + options.contentX, p.y + options.contentY);
                        if (control._selectable(i) && control._matches(i))
                            control._hi = i;
                    }
                }
            }

            Text {
                anchors { left: parent.left; leftMargin: 26; bottom: parent.bottom }
                height: Theme.controlHeight + 2
                verticalAlignment: Text.AlignVCenter
                visible: options.contentHeight <= 0 && control.count > 0
                text: qsTr("No matches")
                color: Theme.textTertiary
                font: control.font
                renderType: Theme.textRenderType
            }
        }

        background: PopupBackground { }
    }

    // A driven or read-only dropdown shows its value but doesn't open.
    MouseArea {
        anchors.fill: parent
        visible: control._locked
        acceptedButtons: Qt.AllButtons
        hoverEnabled: false
    }

    Tip { text: edit.message; shown: control.hovered && !control.popup.visible }

    ValueEdit { id: edit; owner: control; fallback: null }
}
