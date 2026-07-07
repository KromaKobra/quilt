import QtQuick

/*!
    \qmltype PanelModel
    \inqmlmodule Quilt
    \brief Identity and visual configuration of a single panel.

    A PanelModel describes *what* a panel is and *how it looks* — never *where*
    it sits in the layout. Position within the dock tree, stacking order and
    split ratios are owned exclusively by \l DockManager. A PanelModel only
    stores its own identity, content provider, visual style and (when
    undocked) its free-floating geometry.

    Register the model with \c{DockManager.registerPanel(model)} so the docking
    system can resolve it by id.
*/
QtObject {
    id: model

    /*! \brief Unique identifier for this panel. Required; serialisation and all
        DockManager lookups key on this value. */
    property string panelId: ""

    /*! \brief Developer-defined category label (e.g. "editor", "terminal").
        Quilt does not interpret it; it is provided for application use. */
    property string panelType: ""

    /*! \brief Display title shown in the panel header and tab bar. */
    property string title: ""

    /*! \brief Path or resource URL for the icon shown in the tab switcher when
        this panel is stacked with others. If empty, the tab falls back to the
        first two characters of \l title. */
    property string tabIconSource: ""

    /*! \brief Component that produces this panel's content. The dock system
        instantiates panels dynamically, so content is supplied here rather than
        as inline children. The Component's root becomes the panel body content.

        \note This is the content provider for docked/floating rendering. Panel
        also exposes a default \c content alias for direct, standalone use. */
    property Component contentComponent: null

    /*! \brief Where the panel is initially docked when registered without
        already being placed in the layout tree: one of
        \c{DockEnums.Left / Right / Top / Bottom / Center}. Edge panels split
        off that side of the layout in registration order; Center panels share
        one slot as a tab group. Ignored once the panel is in the tree. */
    property int dockPosition: DockEnums.Center

    /*! \brief Share of the container (0–1, exclusive) given to this panel when
        it is auto-placed at an edge via \l dockPosition. Ignored for Center. */
    property real splitRatio: 0.5

    /*! \brief True when the panel floats freely inside the window; false when it
        is docked into the layout tree. There is deliberately no \c isDocked
        property — \c{isFloating === false} means docked. */
    property bool isFloating: false

    /*! \brief Whether the panel is shown at all. Setting this false (via the
        header close button) removes the panel from the layout. */
    property bool isVisible: true

    /*! \brief X position (in DockContainer coordinates) while floating. */
    property real floatX: 60
    /*! \brief Y position (in DockContainer coordinates) while floating. */
    property real floatY: 60
    /*! \brief Width while floating. */
    property real floatWidth: 360
    /*! \brief Height while floating. */
    property real floatHeight: 260

    /*! \brief Minimum width the panel may be resized to. */
    property real minWidth: 140
    /*! \brief Minimum height the panel may be resized to. */
    property real minHeight: 90
    /*! \brief Maximum width the panel may be resized to. */
    property real maxWidth: 100000
    /*! \brief Maximum height the panel may be resized to. */
    property real maxHeight: 100000

    /*! \brief Base corner radius used by the Isolated and Connected styles. */
    property real cornerRadius: 8

    /*! \brief One of \l DockEnums.PanelStyle (Isolated / Connected / Empty). */
    property int panelStyle: DockEnums.Isolated

    /*! \brief Semi-transparent colour applied to the header bar only, and only
        when \l panelStyle is \c Empty. */
    property string customColor: "#22ffffff"
}
