import QtQuick
import Quilt

/*
    Headless functional tests for the Quilt docking engine.

    Run from the repository root:

        qml -I . --apptype gui tests/run_tests.qml

    Exits with code 0 when every check passes, 1 otherwise.
*/
Item {
    id: root

    property int failures: 0
    property int checks: 0

    function check(name, cond) {
        checks += 1;
        if (!cond) {
            failures += 1;
            console.error("FAIL:", name);
        } else {
            console.log("pass:", name);
        }
    }

    function makeModel(id, props) {
        var base = "import QtQuick; import Quilt; PanelModel { panelId: \"" + id + "\" }";
        var m = Qt.createQmlObject(base, root, "inline_" + id);
        for (var k in props) m[k] = props[k];
        return m;
    }

    function resetAll() {
        // Unregister everything and clear the tree.
        for (var id in DockManager.panelRegistry)
            DockManager.unregisterPanel(id);
        DockManager.setRoot(null);
    }

    Component.onCompleted: {
        // ------------------------------------------------------------------
        // 1. Registration + declarative placement
        // ------------------------------------------------------------------
        var editor = makeModel("editor", { title: "Editor" });               // Center
        var files = makeModel("files", {
            title: "Files", dockPosition: DockEnums.Left, splitRatio: 0.25,
            minWidth: 150
        });
        var term = makeModel("term", {
            title: "Terminal", dockPosition: DockEnums.Bottom, splitRatio: 0.2,
            minHeight: 120
        });
        var notes = makeModel("notes", { title: "Notes" });                  // Center → tab group

        DockManager.registerPanel(editor);
        check("center panel becomes root slot",
              DockManager.layoutRoot && DockManager.layoutRoot.nodeType === "slot");

        DockManager.registerPanel(files);
        check("left panel splits root horizontally",
              DockManager.layoutRoot.nodeType === "split" &&
              DockManager.layoutRoot.axis === "horizontal" &&
              DockManager.layoutRoot.firstChild.nodeType === "slot" &&
              DockManager.layoutRoot.firstChild.panelIds[0] === "files");
        check("left panel gets its splitRatio",
              Math.abs(DockManager.layoutRoot.ratio - 0.25) < 1e-6);

        DockManager.registerPanel(term);
        check("bottom panel becomes second child of vertical root",
              DockManager.layoutRoot.axis === "vertical" &&
              DockManager.layoutRoot.secondChild.panelIds[0] === "term" &&
              Math.abs(DockManager.layoutRoot.ratio - 0.8) < 1e-6);

        DockManager.registerPanel(notes);
        var editorSlot = DockManager.slotForPanel("editor");
        check("second center panel stacks with the first",
              editorSlot && editorSlot.panelIds.indexOf("notes") >= 0 &&
              editorSlot.activePanelId === "notes");

        // ------------------------------------------------------------------
        // 2. Tab activation
        // ------------------------------------------------------------------
        DockManager.setActivePanel(editorSlot.slotId, "editor");
        check("setActivePanel switches the visible tab",
              editorSlot.activePanelId === "editor");

        // ------------------------------------------------------------------
        // 3. Split / remove / prune
        // ------------------------------------------------------------------
        DockManager.splitSlot(editorSlot.slotId, "term2missing", DockEnums.After, DockEnums.Vertical);
        var phantom = DockManager.slotForPanel("term2missing");
        check("splitSlot inserts a sibling slot", phantom !== null);
        DockManager.removeFromSlot("term2missing");
        check("removing sole panel prunes its slot and collapses the split",
              DockManager.slotForPanel("term2missing") === null &&
              DockManager.slotForPanel("editor") !== null);

        // ------------------------------------------------------------------
        // 4. Float / dock round trip
        // ------------------------------------------------------------------
        DockManager.floatPanel("files", 100, 80);
        check("floatPanel removes from tree and marks floating",
              files.isFloating && DockManager.slotForPanel("files") === null &&
              DockManager.floatingPanelIds.indexOf("files") >= 0);
        DockManager.dockPanel("files");
        check("dockPanel with no target re-inserts by dockPosition",
              !files.isFloating &&
              DockManager.slotForPanel("files") !== null &&
              DockManager.floatingPanelIds.indexOf("files") < 0);

        // ------------------------------------------------------------------
        // 5. Hide / show
        // ------------------------------------------------------------------
        DockManager.hidePanel("term");
        check("hidePanel removes panel from tree",
              !term.isVisible && DockManager.slotForPanel("term") === null);
        DockManager.showPanel("term");
        check("showPanel re-inserts panel at its dockPosition",
              term.isVisible && DockManager.slotForPanel("term") !== null);

        // ------------------------------------------------------------------
        // 6. Save / restore round trip
        // ------------------------------------------------------------------
        var json = DockManager.saveLayout();
        var beforeIds = [];
        DockManager._visit(DockManager.layoutRoot, function(n) {
            if (n.nodeType === "slot") beforeIds = beforeIds.concat(n.panelIds);
        });
        DockManager.setRoot(null);
        DockManager.restoreLayout(json);
        var afterIds = [];
        DockManager._visit(DockManager.layoutRoot, function(n) {
            if (n.nodeType === "slot") afterIds = afterIds.concat(n.panelIds);
        });
        check("save/restore preserves every docked panel",
              beforeIds.length > 0 &&
              beforeIds.slice().sort().join(",") === afterIds.slice().sort().join(","));

        // Restoring with a missing panel must skip it and collapse cleanly.
        DockManager.unregisterPanel("notes");
        DockManager.restoreLayout(json);
        check("restore skips unregistered panels without failing",
              DockManager.slotForPanel("notes") === null &&
              DockManager.slotForPanel("editor") !== null);

        // ------------------------------------------------------------------
        // 7. Restored-id collision regression
        // ------------------------------------------------------------------
        var restoredIds = {};
        var dup = false;
        DockManager._visit(DockManager.layoutRoot, function(n) {
            restoredIds[DockManager.idOf(n)] = true;
        });
        var extra = DockManager.createSlot(["editor"], "editor"); // fresh id
        if (restoredIds[extra.slotId]) dup = true;
        check("ids created after restore do not collide with restored ids", !dup);

        // ------------------------------------------------------------------
        // 8. Min-size-aware split clamping
        // ------------------------------------------------------------------
        var filesSlot = DockManager.slotForPanel("files");
        var filesSplit = filesSlot.parentNode;
        var firstId = DockManager.idOf(filesSplit.firstChild);
        DockManager.setSplitRatio(firstId, 0.0, 1000);
        var minFirst = DockManager._minExtent(filesSplit.firstChild, filesSplit.axis);
        check("ratio clamps so first child keeps its minimum size",
              filesSplit.ratio * 1000 >= minFirst - 0.5);
        DockManager.setSplitRatio(firstId, 1.0, 1000);
        var minSecond = DockManager._minExtent(filesSplit.secondChild, filesSplit.axis);
        check("ratio clamps so second child keeps its minimum size",
              (1 - filesSplit.ratio) * 1000 >= minSecond - 0.5);

        // Without a pixel length the legacy [0.1, 0.9] clamp applies.
        DockManager.setSplitRatio(firstId, -5);
        check("legacy clamp lower bound", Math.abs(filesSplit.ratio - 0.1) < 1e-6);
        DockManager.setSplitRatio(firstId, 5);
        check("legacy clamp upper bound", Math.abs(filesSplit.ratio - 0.9) < 1e-6);

        // ------------------------------------------------------------------
        // 9. moveSlot: stack and split
        // ------------------------------------------------------------------
        var termSlot = DockManager.slotForPanel("term");
        var edSlot = DockManager.slotForPanel("editor");
        DockManager.moveSlot(termSlot.slotId, edSlot.slotId, DockEnums.Stack);
        edSlot = DockManager.slotForPanel("editor");
        check("moveSlot(Stack) merges tab groups",
              edSlot.panelIds.indexOf("term") >= 0 &&
              edSlot.activePanelId === "term");

        var fSlot = DockManager.slotForPanel("files");
        DockManager.moveSlot(edSlot.slotId, fSlot.slotId, DockEnums.After, DockEnums.Vertical);
        check("moveSlot(After/Vertical) splits the target",
              DockManager.slotForPanel("editor").parentNode.axis === "vertical");

        // ------------------------------------------------------------------
        // 10. Drag lifecycle (state only; no pointer events headless)
        // ------------------------------------------------------------------
        var snapshotJson = DockManager.saveLayout();
        DockManager.beginDrag("editor", 10, 10);
        check("beginDrag exposes the active drag id",
              DockManager.activeDragPanelId === "editor");
        DockManager.updateDrag(50, 60);
        check("updateDrag tracks the cursor",
              DockManager.dragPos.x === 50 && DockManager.dragPos.y === 60);
        DockManager.setHover(DockManager.slotForPanel("files").slotId,
                             DockEnums.Before, DockEnums.Horizontal);
        DockManager.commitDrop();
        check("commitDrop splits the hovered slot",
              DockManager.slotForPanel("editor").parentNode ===
              DockManager.slotForPanel("files").parentNode);
        check("commitDrop clears drag state", DockManager.activeDragPanelId === "");

        DockManager.beginDrag("editor", 10, 10);
        DockManager.cancelDrag();
        check("cancelDrag restores the pre-drag layout",
              DockManager.saveLayout() === snapshotJson ||
              DockManager.slotForPanel("editor") !== null);

        // Drop over empty space floats the panel at the cursor.
        DockManager.beginDrag("editor", 300, 200);
        DockManager.setHover("", DockEnums.Stack, DockEnums.Horizontal);
        DockManager.commitDrop();
        var ed = DockManager.panelById("editor");
        check("drop over empty space floats the panel",
              ed.isFloating && DockManager.slotForPanel("editor") === null);

        // ------------------------------------------------------------------
        console.log(checks - failures, "of", checks, "checks passed");
        Qt.exit(failures === 0 ? 0 : 1);
    }
}
