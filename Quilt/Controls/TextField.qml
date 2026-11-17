import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// One line of text. Qt's TextField API, plus Quilt's edit contract:
// Enter or clicking away applies the text, Esc puts the old text back.
//
//     TextField { text: shape.name; onEdited: v => shape.name = v }
//     TextField { search: true; placeholderText: "Filter"; live: true; onEdited: v => list.filter = v }
T.TextField {
    id: control

    property bool live: false               // true: report every keystroke, not just the result
    property int elide: Text.ElideRight     // how text that doesn't fit is cut while idle
    property bool search: false             // a search field: a leading glyph and a clear button
    property bool flat: false               // no fill or ring of its own; for use inside another control

    property var param: null
    property var defaultValue
    property int paramState: Param.Normal
    property string expression
    property string message
    property bool acceptsExpressions: false

    readonly property bool modified: edit.modified
    readonly property bool fillsRow: true

    signal editStarted()
    signal edited(string value)
    signal editFinished(bool committed)
    signal expressionEdited(string text)

    function reset() { edit.reset(); }
    function setExpression(text: string) { edit.setExpression(text); }  // "" removes it
    function activate() { control.forceActiveFocus(Qt.MouseFocusReason); control.selectAll(); }
    function copyText(): string { return edit.mixed ? "" : control.text; }
    function pasteText(text: string) { if (!control.readOnly) edit.instant(text); }

    property string _startText
    property bool _dirty: false
    readonly property bool _special: edit.mixed || ((edit.driven || edit.invalid) && edit.expression !== "")

    // Applies what was typed.
    function _commit() {
        if (!_dirty) {
            if (_special)
                edit.restore(_startText);
            return;
        }
        _dirty = false;
        if (!control.acceptableInput) {
            _revert();
        } else if (control.text[0] === "=" && edit.acceptsExpressions) {
            const expr = control.text.slice(1).trim();
            edit.restore(_startText);
            if (control.live)
                edit.end(false);
            edit.setExpression(expr);
        } else if (control.live) {
            edit.end(true);
        } else {
            edit.instant(control.text);
        }
        _startText = control.text;
    }

    function _revert() {
        if (control.live && edit.active)
            edit.end(false);
        else
            edit.restore(_startText);
        _dirty = false;
    }

    implicitWidth: 120
    implicitHeight: Theme.controlHeight
    leftPadding: Theme.controlPadding + (search ? 16 : 0)
    rightPadding: Theme.controlPadding + (clear.visible ? 16 : 0)
    topPadding: 0
    bottomPadding: 0
    verticalAlignment: TextInput.AlignVCenter
    selectByMouse: true
    opacity: enabled ? 1 : 0.4

    Accessible.description: edit.stateText

    // While idle the text is drawn by `idle` below, so it can be cut with
    // an ellipsis and show "Mixed".
    color: activeFocus ? Theme.text : "transparent"
    selectionColor: Theme.textSelection
    selectedTextColor: Theme.text
    placeholderTextColor: Theme.textTertiary
    cursorDelegate: Theme._ownCaret ? caret : null
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    renderType: Theme.textRenderType

    onActiveFocusChanged: {
        if (activeFocus) {
            _startText = text;
            _dirty = false;
            // A mixed value is typed over from empty; a driven one shows its expression.
            if (edit.mixed)
                edit.show("");
            else if (_special)
                edit.show("=" + edit.expression);
            if (focusReason === Qt.TabFocusReason || focusReason === Qt.BacktabFocusReason)
                selectAll();
        } else if (_dirty || _special) {
            _commit();                          // text that isn't acceptable is dropped here
        }
    }
    onTextEdited: {
        if (!_dirty) {
            _dirty = true;
            if (live) {
                edit.begin();
                edit.startValue = _startText;
            }
        }
        if (live)
            edit.set(text);
    }
    onAccepted: _commit()
    Keys.onEscapePressed: event => {
        if (_dirty)
            _revert();
        else
            event.accepted = false;
        selectAll();
    }

    background: FieldFrame {
        hovered: control.hovered
        focused: control.activeFocus && !control.flat
        invalid: (edit.invalid || (control._dirty && !control.acceptableInput)) && !control.flat
        flat: control.readOnly || control.flat
    }

    Icon {
        x: Theme.controlPadding - 1
        anchors.verticalCenter: parent.verticalCenter
        visible: control.search
        name: "search"
        color: Theme.textTertiary
    }

    Text {
        id: idle
        x: control.leftPadding
        width: control.width - control.leftPadding - control.rightPadding
        anchors.verticalCenter: parent.verticalCenter
        visible: !control.activeFocus
        text: edit.mixed ? qsTr("Mixed") : control.displayText
        elide: control.elide
        color: !control.enabled ? Theme.textTertiary
             : edit.mixed ? Theme.textSecondary
             : edit.driven ? Theme.driven
             : edit.invalid ? Theme.textTertiary : Theme.text
        font: control.font
        renderType: Theme.textRenderType
    }

    Text {
        x: control.leftPadding
        width: control.width - control.leftPadding - control.rightPadding
        anchors.verticalCenter: parent.verticalCenter
        visible: control.length === 0 && control.preeditText === "" && !edit.mixed
        text: control.placeholderText
        elide: Text.ElideRight
        color: control.placeholderTextColor
        font: control.font
        renderType: Theme.textRenderType
    }

    MouseArea {
        id: clear
        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
        width: 16
        height: 16
        visible: control.search && control.length > 0 && !control.readOnly
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
        onClicked: {
            control._dirty = false;
            edit.instant("");
            control._startText = control.text;
        }
        Icon {
            anchors.centerIn: parent
            name: "close"
            size: 10
            color: clear.containsMouse ? Theme.text : Theme.textSecondary
        }
    }

    Tip { text: edit.message; shown: control.hovered && !control.activeFocus }

    // A press elsewhere in the window applies the text, as losing focus does.
    PressOutside {
        target: control
        active: control.activeFocus
        onPressed: control.focus = false
    }

    ValueEdit { id: edit; owner: control; name: "text"; fallback: ""; live: control.live }

    Component { id: caret; Caret { } }
}
