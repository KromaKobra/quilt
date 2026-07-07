pragma ComponentBehavior: Bound
import QtQuick

/*!
    \qmltype DockSlot
    \inqmlmodule Quilt
    \brief Renders a leaf (SlotNode) of the layout tree — a stacked tab group.

    The currently active panel is rendered via \l Panel. When the slot stacks
    more than one panel a \l DockTabBar is shown across the top. During a drag, when
    this slot is the hovered target, a five-region drop indicator is drawn (a
    strip on each edge for split drops, plus the centre for a stack drop) and the
    slot's content animates inward to "make room" for the incoming panel so the
    layout settles before release.
*/
Item {
    id: slot

    /*! \brief The SlotNode this DockSlot renders. */
    property var slotNode: null

    /*! \brief Edge adjacency inherited from the parent DockNode. */
    property var edges: ({ "top": true, "bottom": true, "left": true, "right": true })

    readonly property string slotId: (slotNode && slotNode.slotId !== undefined) ? slotNode.slotId : ""
    readonly property bool hasTabs: !!(slotNode && slotNode.panelIds && slotNode.panelIds.length > 1)
    readonly property int tabH: hasTabs ? 28 : 0

    // ---- live drag/preview state for this slot ----
    readonly property bool isDragActive: DockManager.activeDragPanelId !== ""
    readonly property bool isHovered: isDragActive && DockManager.hoveredSlotId === slotId
    readonly property int hoverTarget: DockManager.hoveredDropTarget
    readonly property int hoverAxis: DockManager.hoveredAxis
    readonly property bool previewSplit: isHovered && hoverTarget !== DockEnums.Stack

    // Register with DockContainer so the drag layer can hit-test this slot.
    Component.onCompleted: if (DockManager.rootItem && slotId)
        DockManager.rootItem.registerSlotItem(slotId, slot)
    onSlotIdChanged: if (DockManager.rootItem && slotId)
        DockManager.rootItem.registerSlotItem(slotId, slot)
    Component.onDestruction: if (DockManager.rootItem && slotId)
        DockManager.rootItem.unregisterSlotItem(slotId)

    // ---- tab strip ----
    DockTabBar {
        id: tabs
        slotNode: slot.slotNode
        visible: slot.hasTabs
        height: slot.tabH
        anchors { left: parent.left; right: parent.right; top: parent.top }
    }

    // ---- panel body, which animates inward to make room for a split preview ----
    Item {
        id: body

        readonly property real baseX: 0
        readonly property real baseY: slot.tabH
        readonly property real baseW: slot.width
        readonly property real baseH: slot.height - slot.tabH

        x: (slot.previewSplit && slot.hoverAxis === DockEnums.Horizontal
            && slot.hoverTarget === DockEnums.Before) ? baseX + baseW / 2 : baseX
        y: (slot.previewSplit && slot.hoverAxis === DockEnums.Vertical
            && slot.hoverTarget === DockEnums.Before) ? baseY + baseH / 2 : baseY
        width: (slot.previewSplit && slot.hoverAxis === DockEnums.Horizontal) ? baseW / 2 : baseW
        height: (slot.previewSplit && slot.hoverAxis === DockEnums.Vertical) ? baseH / 2 : baseH

        Behavior on x      { NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }
        Behavior on y      { NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }
        Behavior on width  { NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }

        Loader {
            anchors.fill: parent
            sourceComponent: panelComponent
        }
    }

    Component {
        id: panelComponent
        Panel {
            panelModel: slot.slotNode ? DockManager.panelById(slot.slotNode.activePanelId) : null
            edges: slot.edges
        }
    }

    // ---- five-region drop indicator (shown only while this slot is hovered) ----
    Item {
        id: dropZones
        anchors.fill: parent
        visible: slot.isHovered
        z: 50

        readonly property color guide: Qt.rgba(DockManager.accentColor.r,
            DockManager.accentColor.g, DockManager.accentColor.b, 0.18)
        readonly property color active: Qt.rgba(DockManager.accentColor.r,
            DockManager.accentColor.g, DockManager.accentColor.b, 0.40)
        readonly property real band: Math.min(width, height) * 0.22

        // outline of the whole drop area
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: DockManager.accentColor
            radius: 6
            opacity: 0.5
        }

        // edge strips + centre, each lit when it is the current target
        Rectangle {  // left  -> Before / Horizontal
            x: 0; y: 0; width: parent.band; height: parent.height
            color: (slot.hoverTarget === DockEnums.Before && slot.hoverAxis === DockEnums.Horizontal)
                   ? parent.active : parent.guide
        }
        Rectangle {  // right -> After / Horizontal
            x: parent.width - parent.band; y: 0; width: parent.band; height: parent.height
            color: (slot.hoverTarget === DockEnums.After && slot.hoverAxis === DockEnums.Horizontal)
                   ? parent.active : parent.guide
        }
        Rectangle {  // top   -> Before / Vertical
            x: 0; y: 0; width: parent.width; height: parent.band
            color: (slot.hoverTarget === DockEnums.Before && slot.hoverAxis === DockEnums.Vertical)
                   ? parent.active : parent.guide
        }
        Rectangle {  // bottom -> After / Vertical
            x: 0; y: parent.height - parent.band; width: parent.width; height: parent.band
            color: (slot.hoverTarget === DockEnums.After && slot.hoverAxis === DockEnums.Vertical)
                   ? parent.active : parent.guide
        }
        Rectangle {  // centre -> Stack
            anchors.centerIn: parent
            width: parent.width - 2 * parent.band
            height: parent.height - 2 * parent.band
            radius: 6
            color: (slot.hoverTarget === DockEnums.Stack) ? parent.active : parent.guide
        }
    }
}
