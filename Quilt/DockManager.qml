pragma Singleton
import QtQuick
import QtCore

/*!
    \qmltype DockManager
    \inqmlmodule Quilt
    \brief The single source of truth for all docking layout state.

    DockManager is a true QML singleton (see qmldir). It owns:

    \list
      \li the panel registry (panelId -> PanelModel),
      \li the binary layout tree (\l layoutRoot),
      \li the live drag/drop state, and
      \li layout serialisation/persistence.
    \endlist

    No PanelModel and no visual component stores its own position in the tree;
    every structural query and mutation goes through DockManager.

    \section1 The layout tree

    The layout is a binary tree built from two internal QtObject node kinds.
    They are created via \l _slotComponent / \l _splitComponent and are never
    exposed as separate public QML files.

    \b{SplitNode (branch)} — \c{nodeType: "split"}
    \list
      \li \c{string  nodeId}      unique id for this branch
      \li \c{string  axis}        "horizontal" or "vertical"
      \li \c{real    ratio}       0.0–1.0, proportion of space given to firstChild
      \li \c{var     firstChild}  a SplitNode or SlotNode
      \li \c{var     secondChild} a SplitNode or SlotNode
      \li \c{var     parentNode}  back-pointer used for pruning/collapsing
    \endlist

    \b{SlotNode (leaf)} — \c{nodeType: "slot"}
    \list
      \li \c{string  slotId}        unique id for this slot position
      \li \c{var     panelIds}      ordered list of stacked panel id strings
      \li \c{string  activePanelId} which stacked panel is currently visible
      \li \c{var     parentNode}    back-pointer used for pruning/collapsing
    \endlist
*/
QtObject {
    id: manager

    // =========================================================================
    //  Theme (referenced by the visual components)
    // =========================================================================

    /*! \brief Surface colour used for Isolated/Connected panel backgrounds. */
    readonly property color surfaceColor: "#2b2d31"
    /*! \brief Darker surface used behind the dock area / grooves. */
    readonly property color surfaceAltColor: "#1e1f22"
    /*! \brief Header bar base colour. */
    readonly property color headerColor: "#34373c"
    /*! \brief Hairline border colour. */
    readonly property color borderColor: "#45494f"
    /*! \brief Accent colour used for previews, active tabs and highlights. */
    readonly property color accentColor: "#4c8dff"
    /*! \brief Primary text colour. */
    readonly property color textColor: "#e7e9ec"
    /*! \brief Muted text/icon colour. */
    readonly property color mutedColor: "#9aa0a6"

    /*! \brief Standard animation duration for all state transitions (ms). */
    readonly property int animDuration: 180
    /*! \brief Faster animation duration used by the drag preview (ms). */
    readonly property int previewDuration: 150

    // =========================================================================
    //  Node factories  (internal QtObject tree types)
    // =========================================================================

    /*! \internal SlotNode (leaf) factory component. */
    property Component _slotComponent: Component {
        QtObject {
            property string nodeType: "slot"
            property string slotId: ""
            property var panelIds: []
            property string activePanelId: ""
            property var parentNode: null
        }
    }

    /*! \internal SplitNode (branch) factory component. */
    property Component _splitComponent: Component {
        QtObject {
            property string nodeType: "split"
            property string nodeId: ""
            property string axis: "horizontal"
            property real ratio: 0.5
            property var firstChild: null
            property var secondChild: null
            property var parentNode: null
        }
    }

    /*! \internal Monotonic id source for generated node ids. */
    property int _idCounter: 0

    /*! \internal Returns a unique id string with the given prefix. */
    function _nextId(prefix) { _idCounter += 1; return prefix + "_" + _idCounter; }

    /*! \internal Advances the id counter past a restored node id so ids
        generated after a restoreLayout never collide with restored ones. */
    function _noteRestoredId(id) {
        var m = /_(\d+)$/.exec(id);
        if (m) _idCounter = Math.max(_idCounter, parseInt(m[1], 10));
    }

    /*!
        \brief Creates a new SlotNode (leaf).
        \param panelIds ordered array of panel id strings to stack in the slot
        \param activePanelId optional id of the initially visible panel; defaults
               to the first entry of \a panelIds
        \return the new SlotNode object
    */
    function createSlot(panelIds, activePanelId) {
        var ids = panelIds ? panelIds.slice() : [];
        var node = _slotComponent.createObject(manager, {
            "slotId": _nextId("slot"),
            "panelIds": ids,
            "activePanelId": activePanelId !== undefined && activePanelId !== ""
                             ? activePanelId : (ids.length ? ids[0] : "")
        });
        return node;
    }

    /*!
        \brief Creates a new SplitNode (branch).
        \param axis "horizontal"/"vertical" or a DockEnums.SplitAxis value
        \param ratio proportion (0.0–1.0) of space given to \a first
        \param first first child node (left/top)
        \param second second child node (right/bottom)
        \return the new SplitNode object
    */
    function createSplit(axis, ratio, first, second) {
        var node = _splitComponent.createObject(manager, {
            "nodeId": _nextId("split"),
            "axis": _axisToString(axis),
            "ratio": ratio === undefined ? 0.5 : ratio,
            "firstChild": first || null,
            "secondChild": second || null
        });
        if (first) first.parentNode = node;
        if (second) second.parentNode = node;
        return node;
    }

    /*! \internal Normalises an axis argument to the stored string form. */
    function _axisToString(a) {
        if (a === DockEnums.Vertical || a === "vertical") return "vertical";
        return "horizontal";
    }

    /*! \internal Returns the stable id of any node (slotId or nodeId). */
    function idOf(node) {
        if (!node) return "";
        return node.nodeType === "slot" ? node.slotId : node.nodeId;
    }

    // =========================================================================
    //  Layout tree root + change notification
    // =========================================================================

    /*! \brief Root of the layout tree — a SplitNode, a SlotNode, or null. */
    property var layoutRoot: null

    /*! \brief Incremented on every *structural* change (add/remove/stack/move/
        restore). DockContainer rebinds its item tree when this changes; pure
        ratio changes do not bump it so live resizes stay smooth. */
    property int structureRevision: 0

    /*! \brief Emitted after any tree mutation or ratio change. */
    signal layoutChanged()

    /*! \internal Marks a structural change and notifies listeners. */
    function _bumpStructure() { structureRevision += 1; layoutChanged(); }

    /*!
        \brief Replaces the entire layout tree with \a node.
        \param node the new root SlotNode or SplitNode (or null for empty)
    */
    function setRoot(node) {
        layoutRoot = node;
        if (node) node.parentNode = null;
        _bumpStructure();
    }

    // =========================================================================
    //  Panel registry
    // =========================================================================

    /*! \brief Map of panelId -> PanelModel. Treated as read-mostly. */
    property var panelRegistry: ({})

    /*! \brief Ids of panels that are currently floating and visible. Drives the
        FloatingPanel repeater in DockContainer. */
    property var floatingPanelIds: []

    /*! \internal slotId of the slot Center panels stack into. */
    property string _centerSlotId: ""

    /*!
        \brief Adds a panel to the registry.

        If the model is docked (\c{isFloating === false}), visible, and does not
        yet appear anywhere in the layout tree, it is inserted according to its
        \c dockPosition and \c splitRatio (see \l dockAtEdge). Panels whose
        position is \c{DockEnums.Center} share one slot as a tab group; edge
        panels split off the requested side of the current layout, in
        registration order.

        Panels that are already placed (e.g. by a manually built tree or a
        restored layout) are left untouched.
        \param model the PanelModel to register
    */
    function registerPanel(model) {
        if (!model || !model.panelId) return;
        // Assign a fresh copy: re-assigning the same JS object would be elided
        // as a no-op write and bindings on the registry would never refresh.
        var reg = _copyRegistry();
        reg[model.panelId] = model;
        panelRegistry = reg;

        if (!model.isFloating && model.isVisible && !slotForPanel(model.panelId))
            _insertByPosition(model);
        _refreshFloating();
    }

    /*! \internal Shallow-copies the registry so writes notify bindings. */
    function _copyRegistry() {
        var out = {};
        for (var id in panelRegistry) out[id] = panelRegistry[id];
        return out;
    }

    /*! \internal Inserts a docked panel into the tree at its dockPosition. */
    function _insertByPosition(model) {
        var pos = model.dockPosition !== undefined ? model.dockPosition : DockEnums.Center;
        if (pos === DockEnums.Center) {
            var center = _centerSlotId ? slotById(_centerSlotId) : null;
            if (!center) center = _firstSlot(layoutRoot);
            if (center) {
                stackPanel(center.slotId, model.panelId);
                _centerSlotId = center.slotId;
            } else {
                var slot = createSlot([model.panelId], model.panelId);
                setRoot(slot);
                _centerSlotId = slot.slotId;
            }
        } else {
            dockAtEdge(model.panelId, pos, model.splitRatio);
        }
    }

    /*!
        \brief Docks a panel along one edge of the whole layout.

        The current tree becomes one side of a new root split and the panel the
        other, so e.g. \c{DockEnums.Bottom} produces a panel spanning the full
        container width beneath everything else.
        \param panelId panel to place (removed from its current slot first)
        \param position DockEnums.Left / Right / Top / Bottom
        \param ratio share of the container given to the new panel (0–1);
               defaults to 0.5
    */
    function dockAtEdge(panelId, position, ratio) {
        removeFromSlot(panelId);
        var newSlot = createSlot([panelId], panelId);
        if (!layoutRoot) { setRoot(newSlot); return; }
        var r = (ratio === undefined || ratio <= 0 || ratio >= 1) ? 0.5 : ratio;
        var axis = (position === DockEnums.Top || position === DockEnums.Bottom)
                   ? "vertical" : "horizontal";
        var before = (position === DockEnums.Left || position === DockEnums.Top);
        var old = layoutRoot;
        var split = before ? createSplit(axis, r, newSlot, old)
                           : createSplit(axis, 1 - r, old, newSlot);
        setRoot(split);
    }

    /*!
        \brief Removes a panel from the registry and prunes it from the tree.
        \param panelId id of the panel to remove
    */
    function unregisterPanel(panelId) {
        removeFromSlot(panelId);
        var reg = _copyRegistry();
        delete reg[panelId];
        panelRegistry = reg;
        _refreshFloating();
    }

    /*!
        \brief Looks up a registered panel.
        \param panelId id to resolve
        \return the PanelModel, or null if not registered
    */
    function panelById(panelId) {
        return panelRegistry[panelId] !== undefined ? panelRegistry[panelId] : null;
    }

    /*! \internal Rebuilds floatingPanelIds from the registry. */
    function _refreshFloating() {
        var out = [];
        for (var id in panelRegistry) {
            var m = panelRegistry[id];
            if (m && m.isFloating && m.isVisible) out.push(id);
        }
        floatingPanelIds = out;
    }

    // =========================================================================
    //  Tree traversal helpers
    // =========================================================================

    /*! \internal Depth-first visit; cb(node) called for every node. */
    function _visit(node, cb) {
        if (!node) return;
        cb(node);
        if (node.nodeType === "split") {
            _visit(node.firstChild, cb);
            _visit(node.secondChild, cb);
        }
    }

    /*! \internal Returns the first (left/top-most) slot under \a node. */
    function _firstSlot(node) {
        if (!node) return null;
        if (node.nodeType === "slot") return node;
        return _firstSlot(node.firstChild) || _firstSlot(node.secondChild);
    }

    /*!
        \brief Finds the SlotNode that currently contains \a panelId.
        \param panelId panel to locate
        \return the SlotNode, or null
    */
    function slotForPanel(panelId) {
        var found = null;
        _visit(layoutRoot, function(n) {
            if (!found && n.nodeType === "slot" && n.panelIds.indexOf(panelId) >= 0)
                found = n;
        });
        return found;
    }

    /*!
        \brief Finds a SlotNode by its slotId.
        \param slotId slot id to resolve
        \return the SlotNode, or null
    */
    function slotById(slotId) {
        var found = null;
        _visit(layoutRoot, function(n) {
            if (!found && n.nodeType === "slot" && n.slotId === slotId) found = n;
        });
        return found;
    }

    /*! \internal Finds any node (slot or split) by its stable id. */
    function nodeById(id) {
        var found = null;
        _visit(layoutRoot, function(n) { if (!found && idOf(n) === id) found = n; });
        return found;
    }

    /*! \internal Finds the SplitNode whose firstChild has the given id. */
    function _splitByFirstChildId(id) {
        var found = null;
        _visit(layoutRoot, function(n) {
            if (!found && n.nodeType === "split" && n.firstChild && idOf(n.firstChild) === id)
                found = n;
        });
        return found;
    }

    /*! \internal Finds the nearest ancestor SplitNode of \a node with \a axis. */
    function _nearestSplitOfAxis(node, axisStr) {
        var p = node ? node.parentNode : null;
        while (p) {
            if (p.nodeType === "split" && p.axis === axisStr) return p;
            p = p.parentNode;
        }
        return null;
    }

    /*! \internal Replaces \a oldChild with \a newChild under \a parent (or root
        when \a parent is null), maintaining parent back-pointers. */
    function _replaceChild(parent, oldChild, newChild) {
        if (!parent) {
            layoutRoot = newChild;
            if (newChild) newChild.parentNode = null;
            return;
        }
        if (parent.firstChild === oldChild) parent.firstChild = newChild;
        else if (parent.secondChild === oldChild) parent.secondChild = newChild;
        if (newChild) newChild.parentNode = parent;
    }

    // =========================================================================
    //  Structural mutations
    // =========================================================================

    /*!
        \brief Splits the named slot and inserts \a panelId as a new sibling slot.

        The slot is wrapped in a new SplitNode (ratio 0.5) along \a axis. With
        \c{DockEnums.Before} the new panel becomes the first child (left/top);
        with \c{DockEnums.After} it becomes the second child (right/bottom).
        \param slotId slot to split
        \param panelId panel to insert
        \param dropTarget DockEnums.Before or DockEnums.After
        \param axis "horizontal"/"vertical" or a DockEnums.SplitAxis value
    */
    function splitSlot(slotId, panelId, dropTarget, axis) {
        var slot = slotById(slotId);
        if (!slot) return;
        var parent = slot.parentNode;
        var newSlot = createSlot([panelId], panelId);
        var split = (dropTarget === DockEnums.Before)
            ? createSplit(axis, 0.5, newSlot, slot)
            : createSplit(axis, 0.5, slot, newSlot);
        _replaceChild(parent, slot, split);
        _bumpStructure();
    }

    /*!
        \brief Appends \a panelId to the named slot's tab group and shows it.
        \param slotId slot to stack into
        \param panelId panel to add
    */
    function stackPanel(slotId, panelId) {
        var slot = slotById(slotId);
        if (!slot) return;
        var ids = slot.panelIds.slice();
        if (ids.indexOf(panelId) < 0) ids.push(panelId);
        slot.panelIds = ids;
        slot.activePanelId = panelId;
        _bumpStructure();
    }

    /*!
        \brief Sets which stacked panel is visible in a slot.
        \param slotId slot to update
        \param panelId panel to activate

        This is not a structural change, so DockContainer does not rebuild; the
        DockSlot reacts to \c activePanelId via binding.
    */
    function setActivePanel(slotId, panelId) {
        var slot = slotById(slotId);
        if (!slot) return;
        if (slot.panelIds.indexOf(panelId) >= 0) {
            slot.activePanelId = panelId;
            layoutChanged();
        }
    }

    /*!
        \brief Moves an entire tab group from one slot to another.
        \param fromSlotId source slot (emptied and pruned)
        \param toSlotId destination slot
        \param dropTarget Before/After (split) or Stack
        \param axis split axis when \a dropTarget is Before/After
    */
    function moveSlot(fromSlotId, toSlotId, dropTarget, axis) {
        if (fromSlotId === toSlotId) return;
        var from = slotById(fromSlotId);
        if (!from) return;
        var group = from.panelIds.slice();
        var active = from.activePanelId;

        // Detach the source slot first so the sibling reclaims its space.
        _pruneSlot(from);

        var to = slotById(toSlotId);
        if (!to) return;
        if (dropTarget === DockEnums.Stack) {
            var ids = to.panelIds.slice();
            for (var i = 0; i < group.length; ++i)
                if (ids.indexOf(group[i]) < 0) ids.push(group[i]);
            to.panelIds = ids;
            to.activePanelId = active;
        } else {
            var newSlot = createSlot(group, active);
            var parent = to.parentNode;
            var split = (dropTarget === DockEnums.Before)
                ? createSplit(axis, 0.5, newSlot, to)
                : createSplit(axis, 0.5, to, newSlot);
            _replaceChild(parent, to, split);
        }
        _bumpStructure();
    }

    /*!
        \brief Removes \a panelId from its current slot.

        If that empties the slot, the leaf is pruned and its parent SplitNode is
        collapsed so the sibling subtree expands to fill the freed space.
        \param panelId panel to remove
    */
    function removeFromSlot(panelId) {
        var slot = slotForPanel(panelId);
        if (!slot) return;
        var ids = slot.panelIds.slice();
        var i = ids.indexOf(panelId);
        if (i < 0) return;
        ids.splice(i, 1);
        slot.panelIds = ids;
        if (slot.activePanelId === panelId)
            slot.activePanelId = ids.length ? ids[Math.max(0, i - 1)] : "";
        if (ids.length === 0) _pruneSlot(slot);
        _bumpStructure();
    }

    /*! \internal Removes an empty slot and collapses its parent split. */
    function _pruneSlot(slot) {
        var parent = slot.parentNode;
        if (!parent) { layoutRoot = null; return; }
        var sibling = (parent.firstChild === slot) ? parent.secondChild : parent.firstChild;
        _replaceChild(parent.parentNode, parent, sibling);
    }

    /*!
        \brief Updates the ratio of the SplitNode that owns the identified child.

        \a slotId is the stable id of the split's \e first child (a slotId for a
        leaf, or a nodeId for a nested split). Used live by SplitHandle and by
        Panel edge resizing. This is not a structural change, so the layout is
        not rebuilt — DockSplit reacts to the ratio via binding for a smooth
        resize.

        When \a lengthPx (the split's pixel extent along its axis) is supplied,
        the ratio is clamped so neither subtree shrinks below the minimum
        width/height of the panels it contains; otherwise a plain [0.1, 0.9]
        clamp applies.
        \param slotId id of the split's first child
        \param ratio new ratio (0.0–1.0, clamped)
        \param lengthPx optional pixel length of the split along its axis
    */
    function setSplitRatio(slotId, ratio, lengthPx) {
        var split = _splitByFirstChildId(slotId);
        if (!split) return;
        var lo = 0.1, hi = 0.9;
        if (lengthPx !== undefined && lengthPx > 0) {
            lo = Math.min(0.9, _minExtent(split.firstChild, split.axis) / lengthPx);
            hi = Math.max(0.1, 1 - _minExtent(split.secondChild, split.axis) / lengthPx);
            if (lo > hi) lo = hi = (lo + hi) / 2; // mins don't fit; pin centred
        }
        split.ratio = Math.max(lo, Math.min(hi, ratio));
        layoutChanged();
    }

    /*! \internal Minimum pixel extent of a subtree along \a axisStr, derived
        from the registered panels' minWidth/minHeight. */
    function _minExtent(node, axisStr) {
        if (!node) return 0;
        if (node.nodeType === "slot") {
            var mx = 40; // hard floor so a slot can never collapse entirely
            for (var i = 0; i < node.panelIds.length; ++i) {
                var m = panelById(node.panelIds[i]);
                if (!m) continue;
                mx = Math.max(mx, axisStr === "horizontal" ? m.minWidth : m.minHeight);
            }
            return mx;
        }
        var a = _minExtent(node.firstChild, axisStr);
        var b = _minExtent(node.secondChild, axisStr);
        // Children stack along the queried axis only when the axes match.
        return node.axis === axisStr ? a + b + 6 : Math.max(a, b);
    }

    // =========================================================================
    //  Float / dock / hide
    // =========================================================================

    /*!
        \brief Undocks a panel and makes it float at the given position.
        \param panelId panel to float
        \param x float X in DockContainer coordinates
        \param y float Y in DockContainer coordinates
    */
    function floatPanel(panelId, x, y) {
        var m = panelById(panelId);
        if (!m) return;
        removeFromSlot(panelId);
        m.isFloating = true;
        if (x !== undefined) m.floatX = x;
        if (y !== undefined) m.floatY = y;
        _refreshFloating();
    }

    /*!
        \brief Docks a floating panel into the named slot (or stacks into it).
        \param panelId floating panel to dock
        \param slotId destination slot; if empty, the panel is re-inserted
               according to its \c dockPosition
        \param dropTarget Before/After/Stack
        \param axis split axis for Before/After
    */
    function dockPanel(panelId, slotId, dropTarget, axis) {
        var m = panelById(panelId);
        if (!m) return;
        m.isFloating = false;
        if (!slotId) {
            _insertByPosition(m);
            _refreshFloating();
            return;
        }
        var target = slotById(slotId);
        if (!target) {
            setRoot(createSlot([panelId], panelId));
        } else if (dropTarget === DockEnums.Stack || dropTarget === undefined) {
            stackPanel(target.slotId, panelId);
        } else {
            splitSlot(target.slotId, panelId, dropTarget, axis);
        }
        _refreshFloating();
    }

    /*!
        \brief Hides a panel: clears visibility and removes it from the layout.
        \param panelId panel to hide
    */
    function hidePanel(panelId) {
        var m = panelById(panelId);
        if (m) m.isVisible = false;
        removeFromSlot(panelId);
        _refreshFloating();
    }

    /*!
        \brief Shows a previously hidden panel again.

        A floating panel simply reappears at its last float geometry. A docked
        panel that is no longer in the tree is re-inserted according to its
        \c dockPosition / \c splitRatio.
        \param panelId panel to show
    */
    function showPanel(panelId) {
        var m = panelById(panelId);
        if (!m) return;
        m.isVisible = true;
        if (!m.isFloating && !slotForPanel(panelId)) _insertByPosition(m);
        _refreshFloating();
    }

    // =========================================================================
    //  Drag state
    // =========================================================================

    /*! \brief panelId currently being dragged, or "" when no drag is active. */
    property string activeDragPanelId: ""
    /*! \brief Current cursor position { x, y } in DockContainer coordinates. */
    property var dragPos: ({ "x": 0, "y": 0 })
    /*! \brief slotId under the cursor during a drag, or "". */
    property string hoveredSlotId: ""
    /*! \brief DockEnums.DropTarget value for the current hover. */
    property int hoveredDropTarget: DockEnums.Stack
    /*! \brief DockEnums.SplitAxis detected for the current Before/After hover. */
    property int hoveredAxis: DockEnums.Horizontal

    /*! \internal Snapshot taken at drag start, used to restore on cancel. */
    property var _preDragSnapshot: null

    /*! \brief The DockContainer root Item (registered on completion). Used to
        map drag coordinates and to hit-test slots. */
    property var rootItem: null

    /*!
        \brief Begins a drag for \a panelId at cursor (\a x, \a y).

        A pre-drag snapshot is taken so the drag can be cancelled losslessly.

        \note Per the design intent this is where surrounding panels begin to
        make room. Quilt achieves that live via the animated DockPreview
        placeholder and the hovered slot's "make room" inset (see DockSlot),
        rather than by physically pruning the source on press. The actual tree
        removal is performed in \l commitDrop. This is deliberate: the drag
        gesture is hosted by a DragHandler on the panel header, and pruning the
        source on press would destroy that handler's item mid-gesture and drop
        the pointer grab. The dragged source instead renders dimmed while in
        flight, and the layout animates continuously as the user hovers targets.
        \param panelId panel being dragged
        \param x cursor X in DockContainer coordinates
        \param y cursor Y in DockContainer coordinates
    */
    function beginDrag(panelId, x, y) {
        _preDragSnapshot = _serialize();
        activeDragPanelId = panelId;
        dragPos = { "x": x, "y": y };
        hoveredSlotId = "";
        hoveredDropTarget = DockEnums.Stack;
        hoveredAxis = DockEnums.Horizontal;
    }

    /*!
        \brief Updates the live cursor position during a drag.

        DockContainer reads \l dragPos to position the drag ghost, and resolves
        the hovered slot/target by hit-testing (writing back \l hoveredSlotId,
        \l hoveredDropTarget and \l hoveredAxis via \l setHover).
        \param x cursor X in DockContainer coordinates
        \param y cursor Y in DockContainer coordinates
    */
    function updateDrag(x, y) {
        dragPos = { "x": x, "y": y };
    }

    /*!
        \brief Records the slot/target currently under the cursor.
        \param slotId hovered slot id ("" for none)
        \param dropTarget DockEnums.DropTarget value
        \param axis DockEnums.SplitAxis value for Before/After
    */
    function setHover(slotId, dropTarget, axis) {
        hoveredSlotId = slotId;
        hoveredDropTarget = dropTarget;
        if (axis !== undefined) hoveredAxis = axis;
    }

    /*!
        \brief Finalises the current drag using the live hover state, then clears
        drag state. Performs the tree mutation (split / stack / float).
    */
    function commitDrop() {
        var pid = activeDragPanelId;
        if (!pid) { _clearDrag(); return; }

        if (hoveredSlotId) {
            var src = slotForPanel(pid);
            // Ignore a no-op drop onto the panel's own (sole) slot.
            var selfDrop = src && src.slotId === hoveredSlotId &&
                           (hoveredDropTarget === DockEnums.Stack || src.panelIds.length === 1);
            if (!selfDrop) {
                removeFromSlot(pid);
                if (hoveredDropTarget === DockEnums.Stack)
                    stackPanel(hoveredSlotId, pid);
                else
                    splitSlot(hoveredSlotId, pid, hoveredDropTarget, hoveredAxis);
                var m = panelById(pid);
                if (m) m.isFloating = false;
            }
        } else {
            // Released over empty space -> let it float there.
            var m2 = panelById(pid);
            if (m2 && !m2.isFloating) {
                removeFromSlot(pid);
                m2.isFloating = true;
                m2.floatX = dragPos.x - 24;
                m2.floatY = dragPos.y - 12;
            }
        }
        _refreshFloating();
        _clearDrag();
    }

    /*!
        \brief Aborts the active drag and restores the pre-drag layout.
    */
    function cancelDrag() {
        if (_preDragSnapshot) _restore(_preDragSnapshot);
        _clearDrag();
    }

    /*! \internal Clears all transient drag state. */
    function _clearDrag() {
        activeDragPanelId = "";
        hoveredSlotId = "";
        hoveredDropTarget = DockEnums.Stack;
        hoveredAxis = DockEnums.Horizontal;
        _preDragSnapshot = null;
    }

    // =========================================================================
    //  Serialisation / persistence
    // =========================================================================

    /*! \internal Persistent store for the saved layout JSON (QtCore Settings,
        available since Qt 6.5). */
    property Settings _store: Settings {
        category: "QuiltDockLayout"
        property string layoutJson: ""
    }

    /*! \internal Recursively serialises a node to a plain object. */
    function _serializeNode(n) {
        if (!n) return null;
        if (n.nodeType === "slot") {
            return {
                "type": "slot",
                "slotId": n.slotId,
                "panelIds": n.panelIds.slice(),
                "activePanelId": n.activePanelId
            };
        }
        return {
            "type": "split",
            "nodeId": n.nodeId,
            "axis": n.axis,
            "ratio": n.ratio,
            "first": _serializeNode(n.firstChild),
            "second": _serializeNode(n.secondChild)
        };
    }

    /*! \internal Builds the full serialisable layout object. */
    function _serialize() {
        var panels = {};
        for (var id in panelRegistry) {
            var m = panelRegistry[id];
            if (!m) continue;
            panels[id] = {
                "isFloating": m.isFloating,
                "isVisible": m.isVisible,
                "floatX": m.floatX, "floatY": m.floatY,
                "floatWidth": m.floatWidth, "floatHeight": m.floatHeight
            };
        }
        return { "version": 1, "tree": _serializeNode(layoutRoot), "panels": panels };
    }

    /*! \internal Recursively rebuilds a node, skipping unknown panels and
        collapsing degenerate splits (where a child filtered out to null). */
    function _deserializeNode(obj) {
        if (!obj) return null;
        if (obj.type === "slot") {
            var ids = (obj.panelIds || []).filter(function(pid) {
                return panelRegistry[pid] !== undefined;
            });
            if (ids.length === 0) return null;
            var active = ids.indexOf(obj.activePanelId) >= 0 ? obj.activePanelId : ids[0];
            var slot = createSlot(ids, active);
            if (obj.slotId) { slot.slotId = obj.slotId; _noteRestoredId(obj.slotId); }
            return slot;
        }
        var a = _deserializeNode(obj.first);
        var b = _deserializeNode(obj.second);
        if (a && b) {
            var split = createSplit(obj.axis, obj.ratio, a, b);
            if (obj.nodeId) { split.nodeId = obj.nodeId; _noteRestoredId(obj.nodeId); }
            return split;
        }
        return a || b; // collapse if one side vanished
    }

    /*! \internal Applies persisted float state to registered panels. */
    function _applyPanelStates(panels) {
        if (!panels) return;
        for (var id in panels) {
            var m = panelRegistry[id];
            if (!m) continue;
            var s = panels[id];
            m.isFloating = !!s.isFloating;
            if (s.isVisible !== undefined) m.isVisible = !!s.isVisible;
            if (s.floatX !== undefined) m.floatX = s.floatX;
            if (s.floatY !== undefined) m.floatY = s.floatY;
            if (s.floatWidth !== undefined) m.floatWidth = s.floatWidth;
            if (s.floatHeight !== undefined) m.floatHeight = s.floatHeight;
        }
    }

    /*! \internal Rebuilds full state from a serialisable object. */
    function _restore(obj) {
        if (!obj) return;
        _centerSlotId = "";
        layoutRoot = _deserializeNode(obj.tree);
        if (layoutRoot) layoutRoot.parentNode = null;
        _applyPanelStates(obj.panels);
        _refreshFloating();
        _bumpStructure();
    }

    /*!
        \brief Serialises the layout tree and all panel float state to a
        human-readable JSON string and persists it.
        \return the JSON string
    */
    function saveLayout() {
        var json = JSON.stringify(_serialize(), null, 2);
        // qmllint disable missing-property
        _store.layoutJson = json;
        // qmllint enable missing-property
        return json;
    }

    /*!
        \brief Rebuilds the layout tree from a JSON string.

        Any panel id present in the saved tree that has no registered model is
        skipped; slots that become empty are dropped and their parent splits
        collapse, so restoration never fails on a missing panel.
        \param json the JSON produced by \l saveLayout
    */
    function restoreLayout(json) {
        if (!json) return;
        try {
            _restore(JSON.parse(json));
        } catch (e) {
            console.warn("Quilt: restoreLayout failed:", e);
        }
    }

    /*!
        \brief Restores the most recently persisted layout, if any.
        \return true if a saved layout was found and applied
    */
    function loadPersisted() {
        // qmllint disable missing-property
        if (_store.layoutJson && _store.layoutJson.length) {
            restoreLayout(_store.layoutJson);
            return true;
        }
        // qmllint enable missing-property
        return false;
    }
}
