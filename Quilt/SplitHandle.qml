import QtQuick

/*!
    \qmltype SplitHandle
    \inqmlmodule Quilt
    \brief Thin interactive bar between the two children of a \l DockSplit.

    A DragHandler updates the owning split's ratio live by calling
    \c{DockManager.setSplitRatio}. The ratio is clamped by DockManager to
    [0.1, 0.9]. A subtle highlight appears on hover or while dragging.
*/
Item {
    id: handle

    /*! \brief Orientation of the split (DockEnums.Horizontal / Vertical). */
    property int axis: DockEnums.Horizontal

    /*! \brief Stable id of the split's first child — identifies which split's
        ratio to update (a slotId for a leaf, a nodeId for a nested split). */
    property string slotId: ""

    /*! \brief Current ratio of the owning split (bound by DockSplit). */
    property real ratio: 0.5

    /*! \brief Pixel length of the split along its axis (excludes the handle). */
    property real splitLength: 1

    /*! \brief True while the handle is actively being dragged. */
    readonly property bool dragging: drag.active

    readonly property bool horizontal: axis === DockEnums.Horizontal

    // Subtle highlight; brighter while hovered or dragging.
    Rectangle {
        anchors.centerIn: parent
        width: handle.horizontal ? 2 : parent.width
        height: handle.horizontal ? parent.height : 2
        radius: 1
        color: DockManager.accentColor
        opacity: drag.active ? 0.9 : (hover.hovered ? 0.5 : 0.0)
        Behavior on opacity { NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }
    }

    HoverHandler {
        id: hover
        cursorShape: handle.horizontal ? Qt.SplitHCursor : Qt.SplitVCursor
    }

    DragHandler {
        id: drag
        target: null
        cursorShape: handle.horizontal ? Qt.SplitHCursor : Qt.SplitVCursor
        property real startRatio: 0.5
        onActiveChanged: if (active) startRatio = handle.ratio
        onTranslationChanged: {
            if (!active || handle.splitLength <= 0) return;
            var delta = (handle.horizontal ? translation.x : translation.y) / handle.splitLength;
            DockManager.setSplitRatio(handle.slotId, startRatio + delta, handle.splitLength);
        }
    }
}
