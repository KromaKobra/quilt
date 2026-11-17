# Quilt.Controls: the value controls, the property grid and the window
# chrome. Built from ../CMakeLists.txt.

set_source_files_properties(Expression.qml ColorHistory.qml Clipboard.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(ValueEdit.qml FieldFrame.qml Caret.qml ColorPicker.qml PressOutside.qml
    PROPERTIES QT_QML_INTERNAL_TYPE TRUE)

qt_add_library(quiltcontrols STATIC)
qt_add_qml_module(quiltcontrols
    URI Quilt.Controls
    VERSION 1.0
    IMPORTS Quilt.Style
    QML_FILES
        Inspector.qml
        Section.qml
        PropertyRow.qml
        NumberField.qml
        TextField.qml
        TextArea.qml
        CheckBox.qml
        Switch.qml
        SegmentedButton.qml
        ComboBox.qml
        Slider.qml
        VectorField.qml
        ColorField.qml
        Knob.qml
        DateField.qml
        Label.qml
        Button.qml
        IconButton.qml
        ScrollBar.qml
        ProgressBar.qml
        BusyIndicator.qml
        ApplicationWindow.qml
        TitleBar.qml
        MenuBar.qml
        MenuBarItem.qml
        Param.qml
        Expression.qml
        ValueEdit.qml
        FieldFrame.qml
        Caret.qml
        PressOutside.qml
        ColorPicker.qml
        ColorHistory.qml
        Clipboard.qml
        Expr.js
        ColorUtil.js
)

target_link_libraries(quiltcontrols PRIVATE Qt6::Quick Qt6::QuickControls2)
