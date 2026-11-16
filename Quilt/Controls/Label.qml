import QtQuick
import QtQuick.Templates as T
import Quilt.Style

// Text in the theme's font and colour. `dim` gives the secondary colour
// that labels use.
T.Label {
    property bool dim: false

    color: !enabled ? Theme.textTertiary : dim ? Theme.textSecondary : Theme.text
    linkColor: Theme.accent
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    renderType: Theme.textRenderType
}
