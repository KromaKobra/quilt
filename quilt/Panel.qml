pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

/*!
    \qmltype Panel
    \inqmlmodule Quilt
    \brief The visible panel shell: header, styled body, content and resize edges.

    A Panel renders one \l PanelModel. Content is supplied either through the
    model's \c contentComponent (used by the dock system, which instantiates
    panels dynamically) or, for standalone use, as inline children via the
    default \c content alias.

    \section1 Visual styles (PanelModel.panelStyle)
    \list
      \li \c Isolated  — filled surface with uniform rounded corners.
      \li \c Connected — corners on edges shared with a neighbour curve outward
            (convex), drawn with real arcs via \l Shape so adjacent panels read
            as interlocked rather than merely butted together.
      \li \c Empty     — no body background; only the header is drawn, tinted
            with \c customColor.
    \endlist
*/
Item {
    id: panel

    /*! \brief The PanelModel rendered by this Panel. */
    required property var panelModel

    /*! \brief Edge adjacency \c{{ top, bottom, left, right }} (true = container
        border). Drives the Connected style's convex corners and gates docked
        edge-resize to shared edges only. */
    property var edges: ({ "top": true, "bottom": true, "left": true, "right": true })

    /*! \brief Default content slot. Inline children of \c{Panel { ... }} land
        here, alongside the model's \c contentComponent. */
    default property alias content: contentHolder.data

    readonly property int headerHeight: 32
    readonly property int pstyle: panelModel ? panelModel.panelStyle : DockEnums.Isolated
    readonly property real pradius: panelModel ? panelModel.cornerRadius : 8
    readonly property bool isDragGhostSource:
        panelModel && DockManager.activeDragPanelId === panelModel.panelId

    visible: panelModel !== null

    // The in-flight source dims while being dragged (the live preview + the
    // make-room inset carry the motion); see DockManager.beginDrag.
    opacity: isDragGhostSource ? 0.4 : 1.0
    Behavior on opacity { NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }

    // ========================================================================
    //  Background — Isolated
    // ========================================================================
    Rectangle {
        anchors.fill: parent
        visible: panel.pstyle === DockEnums.Isolated
        color: DockManager.surfaceColor
        radius: panel.pradius
        border.width: 1
        border.color: DockManager.borderColor
    }

    // ========================================================================
    //  Background — Connected (convex arcs at shared corners)
    // ========================================================================
    Shape {
        id: connectedBg
        anchors.fill: parent
        visible: panel.pstyle === DockEnums.Connected
        preferredRendererType: Shape.CurveRenderer

        // A corner is "shared" when either adjacent edge touches a neighbour.
        readonly property bool tlShared: !(panel.edges.left && panel.edges.top)
        readonly property bool trShared: !(panel.edges.right && panel.edges.top)
        readonly property bool brShared: !(panel.edges.right && panel.edges.bottom)
        readonly property bool blShared: !(panel.edges.left && panel.edges.bottom)

        readonly property real maxR: Math.min(width, height) / 2
        readonly property real concaveR: Math.min(panel.pradius, maxR)
        readonly property real convexR: Math.min(panel.pradius * 1.6, maxR)

        function cr(shared) { return shared ? convexR : concaveR; }
        // Convex (shared) corners sweep outward (counter-clockwise around the
        // clockwise outline); concave (outer) corners are normal rounded arcs.
        function dir(shared) {
            return shared ? PathArc.Counterclockwise : PathArc.Clockwise;
        }

        ShapePath {
            fillColor: DockManager.surfaceColor
            strokeColor: DockManager.borderColor
            strokeWidth: 1

            startX: connectedBg.cr(connectedBg.tlShared); startY: 0

            PathLine { x: connectedBg.width - connectedBg.cr(connectedBg.trShared); y: 0 }
            PathArc {
                x: connectedBg.width; y: connectedBg.cr(connectedBg.trShared)
                radiusX: connectedBg.cr(connectedBg.trShared)
                radiusY: connectedBg.cr(connectedBg.trShared)
                direction: connectedBg.dir(connectedBg.trShared)
            }
            PathLine { x: connectedBg.width; y: connectedBg.height - connectedBg.cr(connectedBg.brShared) }
            PathArc {
                x: connectedBg.width - connectedBg.cr(connectedBg.brShared); y: connectedBg.height
                radiusX: connectedBg.cr(connectedBg.brShared)
                radiusY: connectedBg.cr(connectedBg.brShared)
                direction: connectedBg.dir(connectedBg.brShared)
            }
            PathLine { x: connectedBg.cr(connectedBg.blShared); y: connectedBg.height }
            PathArc {
                x: 0; y: connectedBg.height - connectedBg.cr(connectedBg.blShared)
                radiusX: connectedBg.cr(connectedBg.blShared)
                radiusY: connectedBg.cr(connectedBg.blShared)
                direction: connectedBg.dir(connectedBg.blShared)
            }
            PathLine { x: 0; y: connectedBg.cr(connectedBg.tlShared) }
            PathArc {
                x: connectedBg.cr(connectedBg.tlShared); y: 0
                radiusX: connectedBg.cr(connectedBg.tlShared)
                radiusY: connectedBg.cr(connectedBg.tlShared)
                direction: connectedBg.dir(connectedBg.tlShared)
            }
        }
    }

    // ========================================================================
    //  Content area (below the header)
    // ========================================================================
    Item {
        id: contentHolder
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: panel.pstyle === DockEnums.Empty ? 0 : 1
        anchors.topMargin: panel.headerHeight
        clip: true

        // Content supplied by the model (dock-system path). The model is
        // exposed so a content Component can bind to it via `parent.panelModel`.
        Loader {
            anchors.fill: parent
            property var panelModel: panel.panelModel
            active: panel.panelModel && panel.panelModel.contentComponent !== null
            sourceComponent: panel.panelModel ? panel.panelModel.contentComponent : null
        }
    }

    // ========================================================================
    //  Header bar
    // ========================================================================
    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: panel.pstyle === DockEnums.Empty ? 0 : 1
        height: panel.headerHeight

        // Header fill: surface-ish for Isolated/Connected, customColor for Empty.
        Rectangle {
            id: headerFill
            anchors.fill: parent
            radius: panel.pradius
            color: panel.pstyle === DockEnums.Empty
                   ? panel.panelModel.customColor
                   : DockManager.headerColor
            // Square off the lower corners so only the top is rounded.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: panel.pradius
                color: parent.color
            }
        }

        // Drag area = header minus the buttons. Initiates a panel drag.
        Item {
            id: dragArea
            anchors.left: parent.left
            anchors.right: buttons.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 6
                elide: Text.ElideRight
                text: panel.panelModel ? panel.panelModel.title : ""
                color: DockManager.textColor
                font.pixelSize: 12
                font.bold: true
            }

            HoverHandler { cursorShape: Qt.OpenHandCursor }

            // Header drag. Docked: starts a dock-drag (source dims, ghost +
            // live preview follow). Floating: moves the panel and, by driving
            // the same hover/preview machinery, lets the user drop it onto a
            // dock zone to re-dock.
            DragHandler {
                id: headerDrag
                target: null
                property bool started: false
                property real sX: 0
                property real sY: 0
                onActiveChanged: {
                    if (!panel.panelModel) return;
                    if (active) {
                        var p = panel._toContainer(dragArea, centroid.position);
                        sX = panel.panelModel.floatX;
                        sY = panel.panelModel.floatY;
                        DockManager.beginDrag(panel.panelModel.panelId, p.x, p.y);
                        started = true;
                    } else if (started) {
                        DockManager.commitDrop();
                        started = false;
                    }
                }
                onCentroidChanged: {
                    if (!active || !started || !panel.panelModel) return;
                    var p = panel._toContainer(dragArea, centroid.position);
                    if (panel.panelModel.isFloating) {
                        var cw = DockManager.rootItem ? DockManager.rootItem.width : panel.width;
                        var ch = DockManager.rootItem ? DockManager.rootItem.height : panel.height;
                        panel.panelModel.floatX = Math.max(0,
                            Math.min(cw - panel.panelModel.floatWidth, sX + translation.x));
                        panel.panelModel.floatY = Math.max(0,
                            Math.min(ch - panel.panelModel.floatHeight, sY + translation.y));
                    }
                    DockManager.updateDrag(p.x, p.y);
                    if (DockManager.rootItem) DockManager.rootItem.resolveHover(p.x, p.y);
                }
            }
        }

        // Header buttons (float / undock and close / hide).
        Row {
            id: buttons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 6
            spacing: 2

            // Float / undock (docked panels only)
            HeaderButton {
                glyph: "❐"
                tooltip: "Float panel"
                visible: panel.panelModel && !panel.panelModel.isFloating
                onActivated: {
                    if (!panel.panelModel) return;
                    var p = panel._toContainer(panel, Qt.point(0, 0));
                    DockManager.floatPanel(panel.panelModel.panelId, p.x + 24, p.y + 24);
                }
            }
            // Re-dock (floating panels only). Docks to a sensible default; the
            // primary re-dock gesture is dragging the header onto a dock zone.
            HeaderButton {
                glyph: "⤓"
                tooltip: "Dock panel"
                visible: panel.panelModel && panel.panelModel.isFloating
                onActivated: if (panel.panelModel) DockManager.dockPanel(panel.panelModel.panelId)
            }
            // Close / hide
            HeaderButton {
                glyph: "✕"
                tooltip: "Close panel"
                onActivated: if (panel.panelModel) DockManager.hidePanel(panel.panelModel.panelId)
            }
        }
    }

    // ========================================================================
    //  Edge / corner resize handles (8)
    // ========================================================================
    Repeater {
        model: ["l", "r", "t", "b", "tl", "tr", "bl", "br"]
        delegate: Item {
            id: rh
            required property string modelData
            readonly property string edge: modelData
            readonly property bool hasLeft:   edge === "l" || edge === "tl" || edge === "bl"
            readonly property bool hasRight:  edge === "r" || edge === "tr" || edge === "br"
            readonly property bool hasTop:    edge === "t" || edge === "tl" || edge === "tr"
            readonly property bool hasBottom: edge === "b" || edge === "bl" || edge === "br"
            readonly property bool isCorner: (hasLeft || hasRight) && (hasTop || hasBottom)
            readonly property bool floating: panel.panelModel && panel.panelModel.isFloating
            readonly property real eh: 7
            readonly property real cc: 14

            readonly property bool resizable: floating
                || (hasLeft && !panel.edges.left) || (hasRight && !panel.edges.right)
                || (hasTop && !panel.edges.top) || (hasBottom && !panel.edges.bottom)

            z: 100
            width: isCorner ? cc : ((hasLeft || hasRight) ? eh : panel.width - 2 * cc)
            height: isCorner ? cc : ((hasTop || hasBottom) ? eh : panel.height - 2 * cc)
            x: hasRight ? panel.width - width : (hasLeft ? 0 : cc)
            y: hasBottom ? panel.height - height : (hasTop ? 0 : cc)

            readonly property int cur: isCorner
                ? (((hasLeft && hasTop) || (hasRight && hasBottom)) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                : ((hasLeft || hasRight) ? Qt.SizeHorCursor : Qt.SizeVerCursor)

            Rectangle {
                anchors.fill: parent
                color: DockManager.accentColor
                opacity: (rh.resizable && (hh.hovered || dh.active)) ? 0.35 : 0.0
                Behavior on opacity { NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }
            }

            HoverHandler { id: hh; enabled: rh.resizable; cursorShape: rh.cur }

            DragHandler {
                id: dh
                target: null
                enabled: rh.resizable
                cursorShape: rh.cur

                property real sW: 0
                property real sH: 0
                property real sX: 0
                property real sY: 0
                property real sRH: 0
                property real sRV: 0
                property var splitH: null
                property var splitV: null

                onActiveChanged: {
                    if (!active) return;
                    var pm = panel.panelModel;
                    if (!pm) return;
                    if (rh.floating) {
                        sW = pm.floatWidth; sH = pm.floatHeight;
                        sX = pm.floatX; sY = pm.floatY;
                    } else {
                        var slot = DockManager.slotForPanel(pm.panelId);
                        splitH = rh.hasRight ? panel._findEdgeSplit(slot, "horizontal", true)
                               : rh.hasLeft  ? panel._findEdgeSplit(slot, "horizontal", false) : null;
                        splitV = rh.hasBottom ? panel._findEdgeSplit(slot, "vertical", true)
                               : rh.hasTop    ? panel._findEdgeSplit(slot, "vertical", false) : null;
                        sRH = splitH ? splitH.ratio : 0;
                        sRV = splitV ? splitV.ratio : 0;
                    }
                }

                onTranslationChanged: {
                    if (!active) return;
                    var pm = panel.panelModel;
                    if (!pm) return;
                    if (rh.floating) {
                        var tw = sW, th = sH, tx = sX, ty = sY;
                        if (rh.hasRight)  tw = sW + translation.x;
                        if (rh.hasLeft)   tw = sW - translation.x;
                        if (rh.hasBottom) th = sH + translation.y;
                        if (rh.hasTop)    th = sH - translation.y;
                        tw = Math.max(pm.minWidth, Math.min(pm.maxWidth, tw));
                        th = Math.max(pm.minHeight, Math.min(pm.maxHeight, th));
                        if (rh.hasLeft) tx = sX + (sW - tw);
                        if (rh.hasTop)  ty = sY + (sH - th);
                        pm.floatWidth = tw; pm.floatHeight = th;
                        pm.floatX = tx; pm.floatY = ty;
                    } else {
                        if (splitH) {
                            var lenH = Math.max(1, panel.width);
                            DockManager.setSplitRatio(DockManager.idOf(splitH.firstChild),
                                                      sRH + translation.x / lenH);
                        }
                        if (splitV) {
                            var lenV = Math.max(1, panel.height);
                            DockManager.setSplitRatio(DockManager.idOf(splitV.firstChild),
                                                      sRV + translation.y / lenV);
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    //  Helpers
    // ========================================================================

    /*! \internal Maps a point in \a fromItem to DockContainer coordinates. */
    function _toContainer(fromItem, pt) {
        if (!DockManager.rootItem) return pt;
        return fromItem.mapToItem(DockManager.rootItem, pt.x, pt.y);
    }

    /*! \internal Walks up from \a slot to the nearest ancestor SplitNode of
        \a axisStr where the ascending subtree is the first (\a wantFirst true)
        or second child — i.e. the split whose handle coincides with the
        requested shared edge. */
    function _findEdgeSplit(slot, axisStr, wantFirst) {
        var child = slot;
        var p = slot ? slot.parentNode : null;
        while (p) {
            if (p.nodeType === "split" && p.axis === axisStr) {
                if ((p.firstChild === child) === wantFirst) return p;
            }
            child = p;
            p = p.parentNode;
        }
        return null;
    }

    // ------------------------------------------------------------------------
    //  Small header button (Rectangle + handlers + tooltip)
    // ------------------------------------------------------------------------
    component HeaderButton: Item {
        id: btn
        property string glyph: ""
        property string tooltip: ""
        signal activated()
        width: 22
        height: 22
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: DockManager.textColor
            opacity: btnHover.hovered ? 0.14 : 0.0
            Behavior on opacity { NumberAnimation { duration: DockManager.animDuration; easing.type: Easing.OutCubic } }
        }
        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: DockManager.mutedColor
            font.pixelSize: 12
        }
        HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: btn.activated() }
    }
}
