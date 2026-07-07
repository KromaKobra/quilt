import QtQuick

/*!
    \qmltype DockContainer
    \inqmlmodule Quilt
    \brief Root layout item that renders the whole docking interface.

    Place one DockContainer as the root of your window content. It:
    \list
      \li renders \c{DockManager.layoutRoot} recursively (a \l DockNode tree),
          updating reactively as the tree mutates;
      \li renders each floating panel via \l FloatingPanel;
      \li during a drag, hit-tests the cursor against the slots, writes the
          hovered slot/target back to DockManager, and shows the animated
          \l DockPreview plus a cursor-following drag ghost;
      \li forwards the cursor to \c{DockManager.updateDrag} through an overlay
          that is active only during a drag.
    \endlist
*/
Item {
    id: container
    anchors.fill: parent

    /*! \brief Convenience list of PanelModels to register on startup. Each is
        passed to \c{DockManager.registerPanel}, which places any unplaced,
        docked panel according to its \c dockPosition / \c splitRatio. Panels
        can equally be registered manually; this list is optional. */
    property list<PanelModel> panels

    /*! \brief When true (the default), a layout persisted by
        \c{DockManager.saveLayout()} in a previous session is restored after
        the \l panels list is registered. */
    property bool autoRestoreLayout: true

    /*! \internal Map of slotId -> DockSlot item, used for drag hit-testing. */
    property var slotItems: ({})

    /*! \brief Registers a DockSlot's item for hit-testing. */
    function registerSlotItem(slotId, item) {
        var m = _copySlotItems(); m[slotId] = item; slotItems = m;
    }
    /*! \brief Removes a DockSlot's item registration. */
    function unregisterSlotItem(slotId) {
        var m = _copySlotItems(); delete m[slotId]; slotItems = m;
    }
    /*! \internal Fresh copy so writes notify bindings (a same-object
        re-assignment is elided as a no-op). */
    function _copySlotItems() {
        var out = {};
        for (var id in slotItems) out[id] = slotItems[id];
        return out;
    }

    Component.onCompleted: {
        DockManager.rootItem = container;
        for (var i = 0; i < panels.length; ++i)
            DockManager.registerPanel(panels[i]);
        if (autoRestoreLayout) DockManager.loadPersisted();
    }

    // Dock surface background.
    Rectangle {
        anchors.fill: parent
        color: DockManager.surfaceAltColor
    }

    // ========================================================================
    //  Layout tree
    // ========================================================================
    DockNode {
        anchors.fill: parent
        node: DockManager.layoutRoot
        edges: ({ "top": true, "bottom": true, "left": true, "right": true })
    }

    // ========================================================================
    //  Floating panels
    // ========================================================================
    Repeater {
        model: DockManager.floatingPanelIds
        delegate: FloatingPanel {
            required property var modelData
            panelModel: DockManager.panelById(modelData)
        }
    }

    // ========================================================================
    //  Drag layer
    // ========================================================================

    /*! \internal Computed geometry the preview/ghost will occupy for the current
        hover. Depends on the hover state so it re-evaluates as the user moves. */
    readonly property var previewRect:
        _computePreview(DockManager.hoveredSlotId,
                        DockManager.hoveredDropTarget,
                        DockManager.hoveredAxis)

    function _computePreview(slotId, target, axis) {
        if (!slotId) return null;
        var it = slotItems[slotId];
        if (!it) return null;
        var tl = it.mapToItem(container, 0, 0);
        var x = tl.x, y = tl.y, w = it.width, h = it.height;
        if (target === DockEnums.Stack)
            return { "x": x, "y": y, "w": w, "h": h };
        if (axis === DockEnums.Horizontal) {
            var hw = w / 2;
            return { "x": (target === DockEnums.Before) ? x : x + hw, "y": y, "w": hw, "h": h };
        }
        var hh = h / 2;
        return { "x": x, "y": (target === DockEnums.Before) ? y : y + hh, "w": w, "h": hh };
    }

    /*! \brief Hit-tests (\a x, \a y) against the slots and writes the hovered
        slot, drop target and split axis back to DockManager. Called by Panel's
        header drag (and by the overlay) during a drag. */
    function resolveHover(x, y) {
        for (var id in slotItems) {
            var it = slotItems[id];
            if (!it) continue;
            var p = it.mapFromItem(container, x, y);
            if (p.x < 0 || p.y < 0 || p.x > it.width || p.y > it.height) continue;

            var band = Math.min(it.width, it.height) * 0.25;
            var dl = p.x, dr = it.width - p.x, dt = p.y, db = it.height - p.y;
            var m = Math.min(dl, dr, dt, db);
            if (m > band) { DockManager.setHover(id, DockEnums.Stack, DockEnums.Horizontal); return; }
            if (m === dl)      DockManager.setHover(id, DockEnums.Before, DockEnums.Horizontal);
            else if (m === dr) DockManager.setHover(id, DockEnums.After, DockEnums.Horizontal);
            else if (m === dt) DockManager.setHover(id, DockEnums.Before, DockEnums.Vertical);
            else               DockManager.setHover(id, DockEnums.After, DockEnums.Vertical);
            return;
        }
        DockManager.setHover("", DockEnums.Stack, DockEnums.Horizontal);
    }

    // Overlay active only during a drag: forwards the cursor to updateDrag.
    // (The header DragHandler holds the pointer grab and also forwards; this is
    // the spec-mandated overlay and a robustness fallback.)
    MouseArea {
        anchors.fill: parent
        enabled: DockManager.activeDragPanelId !== ""
        visible: enabled
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 900
        onPositionChanged: function(mouse) {
            DockManager.updateDrag(mouse.x, mouse.y);
            container.resolveHover(mouse.x, mouse.y);
        }
    }

    // Drop-position preview.
    DockPreview {
        z: 950
        visible: DockManager.activeDragPanelId !== "" && container.previewRect !== null
        x: container.previewRect ? container.previewRect.x : 0
        y: container.previewRect ? container.previewRect.y : 0
        width: container.previewRect ? container.previewRect.w : 0
        height: container.previewRect ? container.previewRect.h : 0
    }

    // Cursor-following ghost of the dragged (docked) panel.
    Item {
        id: dragGhost
        z: 1500
        readonly property var pm:
            DockManager.activeDragPanelId !== "" ? DockManager.panelById(DockManager.activeDragPanelId) : null
        // The ghost is only needed for docked drags; a floating panel follows
        // the cursor on its own.
        visible: pm !== null && !pm.isFloating
        width: 240
        height: 150
        opacity: 0.75
        x: DockManager.dragPos.x - 24
        y: DockManager.dragPos.y - 14

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: DockManager.surfaceColor
            border.width: 1
            border.color: DockManager.accentColor
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 32
            radius: 8
            color: DockManager.headerColor
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 8; color: parent.color
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                text: dragGhost.pm ? dragGhost.pm.title : ""
                color: DockManager.textColor
                font.pixelSize: 12
                font.bold: true
            }
        }
    }

    // Cancel an in-flight drag with Escape.
    focus: true
    Keys.onEscapePressed: if (DockManager.activeDragPanelId !== "") DockManager.cancelDrag()
}
