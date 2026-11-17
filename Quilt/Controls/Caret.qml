import QtQuick
import Quilt.Style

// The text cursor for a theme whose caret isn't Qt's thin line
// (Theme.caretStyle): a bar, a block or an underline. Used as a text
// input's cursorDelegate; the input places it and sets its height. It
// blinks, except with motion reduced.
Item {
    id: caret

    readonly property bool _on: (parent as TextInput)?.cursorVisible ?? (parent as TextEdit)?.cursorVisible ?? false
    property bool _lit: true

    width: Theme.caretStyle === ThemeSpec.Bar ? 2 : Math.round(Theme.fontSize * 0.6)
    visible: _on && _lit

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Theme.caretStyle === ThemeSpec.Underline ? 2 : parent.height
        color: Theme.caretStyle === ThemeSpec.Block ? Theme.alpha(Theme.text, 0.65) : Theme.text
    }

    Timer {
        interval: 530
        repeat: true
        running: caret._on && Theme.duration > 0
        onTriggered: caret._lit = !caret._lit
        onRunningChanged: caret._lit = true
    }
}
