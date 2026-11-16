pragma ComponentBehavior: Bound
import QtQuick

// A tooltip for its parent that only exists while it is wanted:
//
//     HoverHandler { id: hover }
//     Tip { text: "Pop out"; shown: hover.hovered }
Loader {
    id: tip

    property string text
    property bool shown: false
    property bool immediate: false      // skip the delay (an error the user must see now)

    active: shown && text !== ""
    sourceComponent: ToolTip {
        parent: tip.parent
        text: tip.text
        visible: true
        // "Warm" tooltips: once one has shown, the next comes without the wait.
        delay: tip.immediate || Date.now() - Theme._toolTipSeen < 1500 ? 0 : Theme.toolTipDelay
        onOpened: Theme._toolTipSeen = Date.now()
        onClosed: Theme._toolTipSeen = Date.now()
    }
}
