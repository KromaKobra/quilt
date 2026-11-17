import QtQuick
import QtQuick.Templates as T

T.MenuSeparator {
    id: control

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset, implicitContentHeight + topPadding + bottomPadding)

    verticalPadding: 4
    horizontalPadding: 4

    contentItem: Rule {
        implicitWidth: 120
        implicitHeight: 1
    }
}
