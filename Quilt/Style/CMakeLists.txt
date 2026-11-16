# Quilt.Style: the theme tokens, and the icon, menu and tooltip that docking
# and controls both draw with. Built from ../CMakeLists.txt.

set_source_files_properties(Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_library(quiltstyle STATIC)
qt_add_qml_module(quiltstyle
    URI Quilt.Style
    VERSION 1.0
    QML_FILES
        Theme.qml
        Icon.qml
        Icons.js
        PopupBackground.qml
        Menu.qml
        MenuItem.qml
        MenuSeparator.qml
        Action.qml
        ToolTip.qml
        Tip.qml
        Rebind.qml
)

target_link_libraries(quiltstyle PRIVATE Qt6::Quick Qt6::QuickControls2)
