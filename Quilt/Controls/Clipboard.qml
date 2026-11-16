pragma Singleton
import QtQuick

// Plain-text clipboard access for the row menu and Ctrl+C / Ctrl+V on a
// focused control. QML has no clipboard API of its own; a text item does.
QtObject {
    property TextEdit _buffer: TextEdit { visible: false }

    function copy(text: string) {
        _buffer.text = text;
        _buffer.selectAll();
        _buffer.copy();
        _buffer.text = "";
    }

    function paste(): string {
        _buffer.text = "";
        _buffer.paste();
        const text = _buffer.text;
        _buffer.text = "";
        return text;
    }
}
