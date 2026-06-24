pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

/*!
    \qmltype TabBar
    \inqmlmodule Quilt
    \brief Compact tab strip shown atop a \l DockSlot that stacks >1 panel.

    Renders one button per stacked panel. Each button shows the panel's
    \c tabIconSource as an Image when set, otherwise the first two characters of
    its \c title in a small rounded pill. The active tab is filled with the
    accent colour; the others are outlined. Tapping a tab calls
    \c{DockManager.setActivePanel}. The strip is no taller than 28px and scrolls
    horizontally when the tabs overflow.
*/
Item {
    id: tabBar

    /*! \brief The SlotNode whose panelIds are shown as tabs. */
    property var slotNode: null

    implicitHeight: 28
    height: 28

    Rectangle {
        anchors.fill: parent
        color: DockManager.surfaceAltColor
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        orientation: ListView.Horizontal
        spacing: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: (tabBar.slotNode && tabBar.slotNode.panelIds) ? tabBar.slotNode.panelIds : []

        delegate: Rectangle {
            id: tab
            required property var modelData
            property var pm: DockManager.panelById(modelData)
            property bool active: tabBar.slotNode && tabBar.slotNode.activePanelId === modelData

            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            height: 22
            width: Math.max(28, content.implicitWidth + 14)
            radius: 5
            color: active ? DockManager.accentColor : "transparent"
            border.width: active ? 0 : 1
            border.color: DockManager.borderColor

            Behavior on color { ColorAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }

            Row {
                id: content
                anchors.centerIn: parent
                spacing: 4
                Image {
                    id: icon
                    visible: tab.pm && tab.pm.tabIconSource !== ""
                    source: tab.pm ? tab.pm.tabIconSource : ""
                    width: visible ? 14 : 0
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
                Text {
                    visible: !icon.visible
                    text: tab.pm ? tab.pm.title.substring(0, 2).toUpperCase() : "??"
                    color: tab.active ? "#ffffff" : DockManager.textColor
                    font.pixelSize: 11
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            TapHandler {
                onTapped: if (tabBar.slotNode)
                    DockManager.setActivePanel(tabBar.slotNode.slotId, tab.modelData)
            }

            HoverHandler { id: tabHover }
            ToolTip {
                visible: tabHover.hovered && tab.pm
                text: tab.pm ? tab.pm.title : ""
                delay: 400
            }
        }
    }
}
