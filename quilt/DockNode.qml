import QtQuick

/*!
    \qmltype DockNode
    \inqmlmodule Quilt
    \brief Recursive renderer for one node of the layout tree.

    DockNode inspects its \l node and loads either a \l DockSplit (for a branch)
    or a \l DockSlot (for a leaf). DockSplit in turn instantiates a DockNode for
    each of its children, so the whole tree is rendered by recursion.

    \note The children are loaded \e by URL (a runtime \c Loader source) rather
    than by static type reference. DockSplit references DockNode statically, so
    if DockNode also referenced DockSplit statically the two would form a compile
    -time cyclic dependency, which the QML type system rejects. Loading by URL
    breaks that cycle while the \l Binding elements keep \c node / \c edges fully
    reactive: a node-reference change of the same kind updates the existing item
    in place (no reload, so resizes and the make-room animation stay smooth); a
    change of kind swaps the loaded component.
*/
Item {
    id: dockNode

    /*! \brief The SlotNode or SplitNode this DockNode renders. */
    property var node: null

    /*! \brief Edge adjacency for this node: \c{{ top, bottom, left, right }}
        where \c true means the edge is a container border (no neighbour) and
        \c false means it is shared with a sibling. Threaded down so Connected
        panels know which corners to curve outward. */
    property var edges: ({ "top": true, "bottom": true, "left": true, "right": true })

    readonly property bool isSplit: node && node.nodeType === "split"

    Loader {
        id: ldr
        anchors.fill: parent
        source: !dockNode.node ? "" : (dockNode.isSplit ? "DockSplit.qml" : "DockSlot.qml")
    }

    // Reactive property wiring for the loaded DockSplit / DockSlot.
    Binding {
        target: ldr.item
        property: "node"
        value: dockNode.node
        when: ldr.item && dockNode.isSplit
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: ldr.item
        property: "slotNode"
        value: dockNode.node
        when: ldr.item && !dockNode.isSplit
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: ldr.item
        property: "edges"
        value: dockNode.edges
        when: ldr.item !== null
        restoreMode: Binding.RestoreNone
    }
}
