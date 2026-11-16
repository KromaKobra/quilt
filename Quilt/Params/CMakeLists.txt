# Quilt.Params: the optional reference parameter engine. Built from
# ../CMakeLists.txt.

qt_add_library(quiltparams STATIC)
qt_add_qml_module(quiltparams
    URI Quilt.Params
    VERSION 1.0
    QML_FILES
        Parameter.qml
        ParameterSet.qml
        MergedParameter.qml
)

target_link_libraries(quiltparams PRIVATE Qt6::Quick)
