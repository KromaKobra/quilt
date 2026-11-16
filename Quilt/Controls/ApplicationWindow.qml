import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// Qt's ApplicationWindow in Quilt's theme: the canvas colour behind
// everything, the theme's font, and a palette that makes any stock Qt Quick
// controls inside it match.
//
//     ApplicationWindow {
//         frameless: true
//         menuBar: TitleBar { Menu { title: "File"; … } }
//         DockArea { anchors.fill: parent; … }
//     }
//
// `frameless` removes the system's title bar and border; a TitleBar then
// provides the window buttons, moving and resizing.
T.ApplicationWindow {
    id: window

    property bool frameless: false

    flags: frameless ? Qt.Window | Qt.FramelessWindowHint : Qt.Window
    color: Theme.canvas

    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    palette {
        window: Theme.canvas
        windowText: Theme.text
        base: Theme.control
        alternateBase: Theme.controlHover
        text: Theme.text
        button: Theme.control
        buttonText: Theme.text
        brightText: Theme.text
        light: Theme.controlFill
        midlight: Theme.controlHover
        mid: Theme.border
        dark: Theme.canvas
        shadow: Theme.canvas
        highlight: Theme.accent
        highlightedText: Theme.accentInk
        link: Theme.accent
        placeholderText: Theme.textTertiary
        toolTipBase: Theme.raised
        toolTipText: Theme.text
    }

    T.Overlay.modal: Rectangle { color: Theme.alpha(Theme.canvas, 0.6) }
    T.Overlay.modeless: Item { }
}
