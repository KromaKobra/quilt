pragma Singleton
import QtQuick

/*!
    \qmltype DockEnums
    \inqmlmodule Quilt
    \brief Central enumeration singleton for the Quilt docking system.

    DockEnums is a true QML singleton (see qmldir). All Quilt components and
    application code share the same enumeration values through it, so layout
    state can be compared and serialised consistently.

    Because QML flattens enum value names onto the declaring type, the values
    are accessed directly on the singleton, e.g. \c{DockEnums.Isolated},
    \c{DockEnums.Horizontal}, \c{DockEnums.Stack}. The groupings below are
    documented for clarity even though access is flat.
*/
QtObject {

    /*!
        \enum DockEnums::PanelStyle
        Visual rendering mode for a Panel.

        \value Isolated   Filled surface background, uniform rounded corners on
                          all four sides. Panels read as standalone cards.
        \value Connected  Corners at edges shared with a neighbour curve
                          *outward* (convex), producing an interlocking groove
                          between adjacent panels.
        \value Empty      No background is painted. Only the header bar is drawn,
                          tinted with PanelModel.customColor.
    */
    enum PanelStyle { Isolated, Connected, Empty }

    /*!
        \enum DockEnums::SplitAxis
        Orientation of a branch (SplitNode) in the layout tree.

        \value Horizontal  Children are laid out left/right; ratio is a width
                           proportion.
        \value Vertical    Children are laid out top/bottom; ratio is a height
                           proportion.
    */
    enum SplitAxis { Horizontal, Vertical }

    /*!
        \enum DockEnums::DropTarget
        Where a dragged panel will land relative to the slot under the cursor.

        \value Before  Split the hovered slot and insert the new panel before it
                       along the contextually detected axis (left for a
                       horizontal split, top for a vertical split).
        \value After   Split the hovered slot and insert the new panel after it
                       (right for horizontal, bottom for vertical).
        \value Stack   Add the dragged panel into the hovered slot's tab group.
    */
    enum DropTarget { Before, After, Stack }
}
