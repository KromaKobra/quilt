import QtQuick

/*!
    \qmltype DockSplit
    \inqmlmodule Quilt
    \brief Renders a branch (SplitNode) of the layout tree.

    Lays its two child nodes out side by side (horizontal axis) or stacked
    (vertical axis) at the node's ratio, with an interactive \l SplitHandle
    between them. The geometry is bound to \c{node.ratio}, so a live resize
    driven by the handle (which calls \c{DockManager.setSplitRatio}) animates
    smoothly; the per-frame ratio binding plus the Behaviors keep the second
    child following the first. Behaviors are suspended while the handle is being
    dragged so the split tracks the cursor exactly.
*/
Item {
    id: split

    /*! \brief The SplitNode this DockSplit renders. */
    property var node: null

    /*! \brief Edge adjacency inherited from the parent DockNode. */
    property var edges: ({ "top": true, "bottom": true, "left": true, "right": true })

    /*! \brief Thickness of the split handle / gap between children. */
    property real handleSize: 6

    /*! \internal True while the split's handle is being dragged. */
    readonly property bool resizing: handle.dragging

    readonly property bool horizontal: node && node.axis === "horizontal"
    readonly property real ratio: (node && node.ratio !== undefined) ? node.ratio : 0.5
    readonly property real firstExtent: horizontal
        ? Math.round((width - handleSize) * ratio)
        : Math.round((height - handleSize) * ratio)

    /*! \internal Computes the edge adjacency for a child: the shared interior
        edge between the two children loses its "border" status. */
    function _childEdges(isFirst) {
        var e = { "top": edges.top, "bottom": edges.bottom,
                  "left": edges.left, "right": edges.right };
        if (horizontal) {
            if (isFirst) e.right = false; else e.left = false;
        } else {
            if (isFirst) e.bottom = false; else e.top = false;
        }
        return e;
    }

    // ---- first child (left / top) ----
    DockNode {
        id: firstNode
        node: split.node ? split.node.firstChild : null
        edges: split._childEdges(true)
        x: 0
        y: 0
        width: split.horizontal ? split.firstExtent : split.width
        height: split.horizontal ? split.height : split.firstExtent
        Behavior on width  { enabled: !split.resizing; NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }
        Behavior on height { enabled: !split.resizing; NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }
    }

    // ---- resize handle ----
    SplitHandle {
        id: handle
        axis: split.horizontal ? DockEnums.Horizontal : DockEnums.Vertical
        slotId: split.node ? DockManager.idOf(split.node.firstChild) : ""
        ratio: split.ratio
        splitLength: split.horizontal ? (split.width - split.handleSize)
                                      : (split.height - split.handleSize)
        x: split.horizontal ? firstNode.width : 0
        y: split.horizontal ? 0 : firstNode.height
        width: split.horizontal ? split.handleSize : split.width
        height: split.horizontal ? split.height : split.handleSize
    }

    // ---- second child (right / bottom) ----
    DockNode {
        id: secondNode
        node: split.node ? split.node.secondChild : null
        edges: split._childEdges(false)
        x: split.horizontal ? (firstNode.width + split.handleSize) : 0
        y: split.horizontal ? 0 : (firstNode.height + split.handleSize)
        width: split.horizontal ? (split.width - firstNode.width - split.handleSize) : split.width
        height: split.horizontal ? split.height : (split.height - firstNode.height - split.handleSize)
    }
}
