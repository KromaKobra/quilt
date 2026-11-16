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
// An array of { text, value } objects needs no textRole or valueRole.
T.ComboBox {
    id: control

    // The value of the selected option: its valueRole, or its text when
    // the model has no values. Leave it unset to work with currentIndex.
    property var value

    property var param: null
    property var defaultValue
    property int paramState: Param.Normal
    property string expression
    property string message
    property bool readOnly: false
    property bool acceptsExpressions: false

    readonly property bool modified: edit.modified
    readonly property bool fillsRow: true

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
        if (control._locked)
            control._follow();
        else
            edit.instant(control._valueAt(index));
        if (control.value !== undefined)
            control._follow();                  // a refused choice snaps back
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

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    FontMetrics { id: metrics; font: control.font }

    contentItem: Text {
        text: edit.mixed ? qsTr("Mixed") : control.displayText
        color: !control.enabled ? Theme.textTertiary
             : edit.mixed ? Theme.textSecondary
             : edit.driven ? Theme.driven
             : edit.invalid ? Theme.textTertiary : Theme.text
        font: control.font
        renderType: Theme.textRenderType
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
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
        readonly property bool current: control.currentIndex === index

        width: ListView.view ? ListView.view.width : implicitWidth
        implicitHeight: Theme.controlHeight + 2
        leftPadding: 26
        rightPadding: 10
        highlighted: control.highlightedIndex === index
        hoverEnabled: control.hoverEnabled
        text: control.textAt(index)
        font: control.font

        contentItem: Text {
            text: option.text
            color: option.enabled ? Theme.text : Theme.textTertiary
            font: option.font
            renderType: Theme.textRenderType
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Theme.controlRadius
            color: option.highlighted ? Theme.controlFill : "transparent"
            Icon {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                name: "check"
                size: 10
                color: Theme.text
                visible: option.current
            }
        }
    }

    popup: T.Popup {
        y: control.height + 4
        width: Math.max(control.width, control._popupWidth)
        height: Math.min(contentItem.implicitHeight + topPadding + bottomPadding,
                         12 * (Theme.controlHeight + 2) + topPadding + bottomPadding,
                         control.Window.height - topMargin - bottomMargin)
        margins: 4
        padding: 4
        popupType: Theme.popupType

        // Wide enough for the longest option.
        onAboutToShow: {
            let w = 0;
            for (let i = 0; i < control.count; ++i)
                w = Math.max(w, metrics.advanceWidth(control.textAt(i)));
            control._popupWidth = Math.min(360, Math.ceil(w) + 26 + 10 + 2 * padding);
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationFast } }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            T.ScrollBar.vertical: ScrollBar { }
        }

        background: Rectangle {
            radius: Theme.radius
            color: Theme.raised
            border.color: Theme.border
        }
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
