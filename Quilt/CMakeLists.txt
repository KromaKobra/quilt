# Optional: build Quilt as compiled QML modules, with qmlcachegen and the
# files embedded in your binary. You don't need this when you load Quilt from
# an import path (`qml -I`, QQmlEngine::addImportPath).
#
#   add_subdirectory(path/to/Quilt)
#   target_link_libraries(myapp PRIVATE Quilt::Quilt)
#
# Quilt::Quilt is everything. To take less, link the parts you import:
#   Quilt::Docking    import Quilt            (brings Quilt.Style)
#   Quilt::Controls   import Quilt.Controls   (brings Quilt.Style)
#   Quilt::Params     import Quilt.Params     (brings Quilt.Controls)
#   Quilt::Style      import Quilt.Style

cmake_minimum_required(VERSION 3.21)

find_package(Qt6 6.8 REQUIRED COMPONENTS Quick QuickControls2)

if(QT_KNOWN_POLICY_QTP0001)
    qt_policy(SET QTP0001 NEW)      # resources under :/qt/qml, on the default import path
endif()
if(QT_KNOWN_POLICY_QTP0004)
    qt_policy(SET QTP0004 NEW)      # a qmldir for every directory that holds QML files
endif()

add_subdirectory(Style)
add_subdirectory(Controls)
add_subdirectory(Params)

set_source_files_properties(DockManager.qml DockStack.qml SplitHandles.qml
    PROPERTIES QT_QML_INTERNAL_TYPE TRUE)

qt_add_library(quilt STATIC)
qt_add_qml_module(quilt
    URI Quilt
    VERSION 1.0
    IMPORTS Quilt.Style
    QML_FILES
        Dock.qml
        DockArea.qml
        DockPanel.qml
        DockStyle.qml
        DockWindow.qml
        DockManager.qml
        DockStack.qml
        SplitHandles.qml
        LayoutTree.js
)

target_link_libraries(quilt PRIVATE Qt6::Quick)

# Linking a plugin target registers its module with the QML engine; no
# Q_IMPORT_QML_PLUGIN is needed.
add_library(quilt_docking INTERFACE)
target_link_libraries(quilt_docking INTERFACE quiltplugin quiltstyleplugin)
add_library(Quilt::Docking ALIAS quilt_docking)

add_library(quilt_style INTERFACE)
target_link_libraries(quilt_style INTERFACE quiltstyleplugin)
add_library(Quilt::Style ALIAS quilt_style)

add_library(quilt_controls INTERFACE)
target_link_libraries(quilt_controls INTERFACE quiltcontrolsplugin quiltstyleplugin)
add_library(Quilt::Controls ALIAS quilt_controls)

add_library(quilt_params INTERFACE)
target_link_libraries(quilt_params INTERFACE quiltparamsplugin quilt_controls)
add_library(Quilt::Params ALIAS quilt_params)

add_library(quilt_all INTERFACE)
target_link_libraries(quilt_all INTERFACE quilt_docking quilt_controls quilt_params)
add_library(Quilt::Quilt ALIAS quilt_all)
