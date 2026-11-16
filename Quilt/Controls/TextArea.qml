import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// Several lines of text. Enter adds a line; Ctrl+Enter, or clicking away,
// applies the text; Esc puts the old text back. It grows from minimumLines
// to maximumLines and then scrolls.
//
//     TextArea { text: shape.notes; onEdited: v => shape.notes = v }
T.Control {
    id: control

    property alias text: area.text
    property alias placeholderText: area.placeholderText
    property alias readOnly: area.readOnly
    property alias wrapMode: area.wrapMode
    property int minimumLines: 3
    property int maximumLines: 8
    property bool live: false               // true: report every keystroke

    property var param: null
    property var defaultValue
    property int paramState: Param.Normal
    property string expression
    property string message
    property bool acceptsExpressions: false

    readonly property bool modified: edit.modified
    readonly property bool fillsRow: true
    readonly property alias editing: area.activeFocus

    signal editStarted()
    signal edited(string value)
    signal editFinished(bool committed)
    signal expressionEdited(string text)

    function reset() { edit.reset(); }
    function setExpression(text: string) { edit.setExpression(text); }
    function activate() { area.forceActiveFocus(Qt.MouseFocusReason); }
    function copyText(): string { return edit.mixed ? "" : area.text; }
    function pasteText(text: string) { if (!area.readOnly) edit.instant(text); }

    property string _startText
    property bool _dirty: false

    function _commit() {
        if (!_dirty) {
            if (edit.mixed)
                edit.restore(_startText);
            return;
        }
        _dirty = false;
        if (live)
            edit.end(true);
        else
            edit.instant(area.text);
        _startText = area.text;
    }

    function _revert() {
        if (live && edit.active)
            edit.end(false);
        else
            edit.restore(_startText);
        _dirty = false;
    }

    implicitWidth: 160
    implicitHeight: Math.min(maximumLines, Math.max(minimumLines, area.lineCount)) * metrics.lineSpacing
                    + topPadding + bottomPadding
    padding: Theme.controlPadding
    topPadding: 5
    bottomPadding: 5
    opacity: enabled ? 1 : 0.4

    Accessible.ignored: true                // the text item inside speaks for it

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    FontMetrics { id: metrics; font: control.font }

    background: FieldFrame {
        hovered: hover.hovered
        focused: area.activeFocus
        invalid: edit.invalid
        flat: area.readOnly
    }
    HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }

    contentItem: Flickable {
        id: flick
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Its own text scrolls only while it has focus; otherwise the wheel
        // goes on to scroll the panel.
        interactive: area.activeFocus
        T.ScrollBar.vertical: ScrollBar { }

        T.TextArea.flickable: T.TextArea {
            id: area
            // The template doesn't size itself to its text; without this the
            // Flickable has nothing to scroll.
            implicitHeight: contentHeight + topPadding + bottomPadding
            padding: 0
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            Accessible.name: control.Accessible.name
            Accessible.description: edit.stateText
            color: !control.enabled ? Theme.textTertiary
                 : edit.mixed && !activeFocus ? "transparent"
                 : edit.driven ? Theme.driven : Theme.text
            selectionColor: Theme.textSelection
            selectedTextColor: Theme.text
            placeholderTextColor: Theme.textTertiary
            font: control.font
            renderType: Theme.textRenderType

            onActiveFocusChanged: {
                if (activeFocus) {
                    control._startText = text;
                    control._dirty = false;
                    if (edit.mixed)
                        edit.show("");
                } else {
                    control._commit();
                }
            }
            onTextChanged: {
                if (!activeFocus || text === control._startText && !control._dirty)
                    return;
                if (!control._dirty) {
                    control._dirty = true;
                    if (control.live) {
                        edit.begin();
                        edit.startValue = control._startText;
                    }
                }
                if (control.live)
                    edit.set(text);
            }
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
                    control._commit();
                } else if (event.key === Qt.Key_Escape && control._dirty) {
                    control._revert();
                } else {
                    return;
                }
                event.accepted = true;
            }

            Text {
                visible: area.length === 0 && area.preeditText === "" && !edit.mixed
                text: area.placeholderText
                width: area.width
                wrapMode: Text.Wrap
                color: area.placeholderTextColor
                font: area.font
                renderType: Theme.textRenderType
            }
            Text {
                visible: edit.mixed && !area.activeFocus
                text: qsTr("Mixed")
                color: Theme.textSecondary
                font: area.font
                renderType: Theme.textRenderType
            }
        }
    }

    Tip { text: edit.message; shown: hover.hovered && !area.activeFocus }

    // A press elsewhere in the window applies the text, as losing focus does.
    PressOutside {
        target: control
        active: area.activeFocus
        onPressed: area.focus = false
    }

    ValueEdit { id: edit; owner: control; name: "text"; fallback: ""; live: control.live }
}
