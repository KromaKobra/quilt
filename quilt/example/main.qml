import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Quilt is imported via a relative path so this example runs straight from the
// source tree with e.g.  `qml quilt/example/main.qml`. When Quilt is installed
// as a module on the import path you can instead write `import Quilt 1.0`.
import "../"

/*!
    Quilt demonstration.

    Builds a seven-panel IDE-style layout:

        +--------+-------------------------------------------+
        |        |                Minimap (~15% h)           |
        |  File  +---------------------+---------------------+
        |  Tree  |                     |  Properties (~40%)  |
        | (~20%  |   Primary editor    +---------------------+
        |   w)   |   (+ Secondary,     |  Git History (~60%) |
        |        |    stacked tab)     |                     |
        |        +---------------------+---------------------+
        |        |              Terminal (~20% h)            |
        +--------+-------------------------------------------+

    Demonstrates all three panel styles, stacked tab groups, per-panel size
    constraints, and layout save/reset.
*/
ApplicationWindow {
    id: win
    visible: true
    width: 1280
    height: 800
    title: "Quilt — Docking Demo"
    color: "#16171a"

    // ------------------------------------------------------------------------
    //  Shared placeholder content. Reads its panel via the content Loader's
    //  exposed `panelModel` (see Panel.qml) so one component serves every panel.
    // ------------------------------------------------------------------------
    Component {
        id: placeholder
        Rectangle {
            id: ph
            color: "transparent"
            // The content Loader (see Panel.qml) exposes the model as `panelModel`.
            // qmllint disable missing-property
            property var pm: parent ? parent.panelModel : null
            // qmllint enable missing-property
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: ph.pm ? ph.pm.title : ""
                    color: "#e7e9ec"
                    font.pixelSize: 18
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: ph.pm ? ("type: " + ph.pm.panelType) : ""
                    color: "#8b9096"
                    font.pixelSize: 12
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    //  The seven panel models
    // ------------------------------------------------------------------------
    PanelModel {
        id: fileTreeModel
        panelId: "fileTree"; panelType: "files"; title: "Files"
        panelStyle: DockEnums.Connected
        cornerRadius: 4; minWidth: 160; minHeight: 120
        contentComponent: placeholder
    }
    PanelModel {
        id: primaryEditorModel
        panelId: "primaryEditor"; panelType: "editor"; title: "main.qml"
        panelStyle: DockEnums.Isolated
        cornerRadius: 10; minWidth: 320; minHeight: 200
        contentComponent: placeholder
    }
    PanelModel {
        id: secondaryEditorModel
        panelId: "secondaryEditor"; panelType: "editor"; title: "helpers.js"
        panelStyle: DockEnums.Isolated
        cornerRadius: 10; minWidth: 280; minHeight: 180
        contentComponent: placeholder
    }
    PanelModel {
        id: terminalModel
        panelId: "terminal"; panelType: "terminal"; title: "Terminal"
        panelStyle: DockEnums.Empty; customColor: "#22ffffff"
        cornerRadius: 8; minWidth: 240; minHeight: 100
        contentComponent: placeholder
    }
    PanelModel {
        id: propertiesModel
        panelId: "properties"; panelType: "inspector"; title: "Properties"
        panelStyle: DockEnums.Isolated
        cornerRadius: 6; minWidth: 200; minHeight: 140
        contentComponent: placeholder
    }
    PanelModel {
        id: minimapModel
        panelId: "minimap"; panelType: "minimap"; title: "Minimap"
        panelStyle: DockEnums.Isolated
        cornerRadius: 12; minWidth: 160; minHeight: 80
        contentComponent: placeholder
    }
    PanelModel {
        id: gitHistoryModel
        panelId: "gitHistory"; panelType: "vcs"; title: "Git History"
        panelStyle: DockEnums.Isolated
        cornerRadius: 6; minWidth: 220; minHeight: 160
        contentComponent: placeholder
    }

    readonly property var allModels: [
        fileTreeModel, primaryEditorModel, secondaryEditorModel, terminalModel,
        propertiesModel, minimapModel, gitHistoryModel
    ]

    /*! Builds (or rebuilds) the default layout tree described above. */
    function buildLayout() {
        for (var i = 0; i < allModels.length; ++i) {
            allModels[i].isFloating = false;
            allModels[i].isVisible = true;
        }

        var fileTree = DockManager.createSlot(["fileTree"], "fileTree");
        // Secondary editor stacked on top of the primary editor (tab group).
        var editor   = DockManager.createSlot(["primaryEditor", "secondaryEditor"], "primaryEditor");
        var props    = DockManager.createSlot(["properties"], "properties");
        var git      = DockManager.createSlot(["gitHistory"], "gitHistory");
        var minimap  = DockManager.createSlot(["minimap"], "minimap");
        var terminal = DockManager.createSlot(["terminal"], "terminal");

        var rightCol     = DockManager.createSplit("vertical",   0.40, props, git);
        var centerRow    = DockManager.createSplit("horizontal", 0.40, editor, rightCol);
        var belowMinimap = DockManager.createSplit("vertical",   0.78, centerRow, terminal);
        var rightRegion  = DockManager.createSplit("vertical",   0.15, minimap, belowMinimap);
        var root         = DockManager.createSplit("horizontal", 0.20, fileTree, rightRegion);

        DockManager.setRoot(root);
    }

    Component.onCompleted: {
        // 1. Build the default tree (slots reference panel ids).
        buildLayout();
        // 2. Register the models (they are already placed, so no auto-insert).
        for (var i = 0; i < allModels.length; ++i)
            DockManager.registerPanel(allModels[i]);
        // 3. If a layout was persisted in a previous run, restore it over the
        //    default. (Comment this out to always start from the default.)
        DockManager.loadPersisted();
    }

    // ------------------------------------------------------------------------
    //  Toolbar
    // ------------------------------------------------------------------------
    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            Label {
                text: "Quilt"
                font.bold: true
                font.pixelSize: 14
                Layout.rightMargin: 12
            }
            Button {
                text: "Save layout"
                onClicked: DockManager.saveLayout()
            }
            Button {
                text: "Reset layout"
                onClicked: win.buildLayout()
            }
            Item { Layout.fillWidth: true }
            Label {
                text: "Drag a panel header to rearrange · drag a tab out to split · ⊞ to float"
                color: "#8b9096"
                font.pixelSize: 12
            }
        }
    }

    // ------------------------------------------------------------------------
    //  The dock area
    // ------------------------------------------------------------------------
    DockContainer {
        anchors.fill: parent
    }
}
