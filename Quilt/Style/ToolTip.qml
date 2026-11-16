import QtQuick
import QtQuick.Templates as T

// Help on hover. It waits Theme.toolTipDelay, but appears at once when
// another tooltip was showing a moment ago. It sits above its parent, or
// below when there is no room above.
T.ToolTip {
    id: control

    property bool _below: false
    property double _closedAt: 0

    x: parent ? Math.round((parent.width - implicitWidth) / 2) : 0
    y: _below && parent ? parent.height + 6 : -implicitHeight - 6

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset, contentHeight + topPadding + bottomPadding)

    margins: 4
    horizontalPadding: 8
    verticalPadding: 5
    delay: Theme.toolTipDelay
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutsideParent | T.Popup.CloseOnReleaseOutsideParent

    onAboutToShow: _below = !!parent && parent.mapToItem(null, 0, 0).y < implicitHeight + 10

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationFast } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationFast } }

    contentItem: Text {
        text: control.text
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        renderType: Theme.textRenderType
        wrapMode: Text.Wrap
        // Wrap long help text instead of growing without limit.
        width: Math.min(implicitWidth, 280)
    }

    background: PopupBackground {
        radius: Theme.controlRadius + 2
    }
}
