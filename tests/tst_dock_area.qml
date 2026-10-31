import QtQuick
import QtQuick.Controls
import QtTest
import Quilt
import "../Quilt/LayoutTree.js" as Tree

// Integration tests: real DockAreas, panels and pop-out windows, rendered
// with the offscreen platform. The platform drag-and-drop loop can't run
// headless, so drag tests drive the same entry points the DropAreas call.
Item {
    id: root
    width: 1200
    height: 800

    Component {
        id: dockComponent
        DockArea {
            anchors.fill: parent
            style.animationDuration: 0

            DockPanel {
                panelId: "viewport"; title: "Viewport"
                TextInput { anchors.fill: parent; text: "" }
            }
            DockPanel { panelId: "uv"; title: "UV" }
            DockPanel { panelId: "outliner"; title: "Outliner"; area: Dock.Left; areaSize: 0.2; minimumWidth: 150 }
            DockPanel {
                panelId: "inspector"; title: "Inspector"; area: Dock.Right; areaSize: 0.25
                Button { property int clicks: 0; text: "Apply"; onClicked: clicks += 1 }
            }
            DockPanel { panelId: "pinned"; title: "Pinned"; area: Dock.Right; movable: false; floatable: false; closable: false }
            DockPanel { panelId: "timeline"; title: "Timeline"; area: Dock.Bottom; areaSize: 0.25 }
            DockPanel { panelId: "hidden"; title: "Hidden"; openOnStart: false }
        }
    }

    Component {
        id: lateComponent
        DockPanel { title: "Late" }
    }

    // Four plain panels for split-line tests, plus a non-tabbable one.
    Component {
        id: gridComponent
        DockArea {
            anchors.fill: parent
            style.animationDuration: 0
            DockPanel { panelId: "a"; title: "A" }
            DockPanel { panelId: "b"; title: "B" }
            DockPanel { panelId: "c"; title: "C" }
            DockPanel { panelId: "d"; title: "D" }
            DockPanel { panelId: "tools"; title: "Tools"; area: Dock.Left; tabbable: false; openOnStart: false }
        }
    }

    TestCase {
        id: test
        name: "DockArea"
        when: windowShown

        property var area: null

        function init() {
            area = createTemporaryObject(dockComponent, root);
            verify(area);
            verify(area.isMain);
        }

        function shape(node) {
            if (!node)
                return "null";
            if (node.type === "tabs")
                return "tabs[" + node.panels.map(p => p === node.current ? p + "*" : p).join(",") + "]";
            return node.type + "(" + node.children.map(shape).join(",") + ")";
        }

        function stackOf(panelId, a) {
            return Tree.findStackOf((a || area).root, panelId);
        }

        function stackRect(panelId, a) {
            const ar = a || area;
            return ar.geometry.rects[stackOf(panelId, ar).id];
        }

        // ---- placement -------------------------------------------------------

        function test_initial_layout_from_hints() {
            compare(shape(area.root),
                    "column(row(tabs[outliner*],tabs[viewport*,uv],tabs[inspector*,pinned]),tabs[timeline*])");
            const r = stackRect("outliner");
            compare(r.width, Math.round(0.2 * (1200 - 2 * 4)));
            verify(!area.panel("hidden").isOpen);
        }

        function test_panels_are_parented_into_their_stacks() {
            const vp = area.panel("viewport"), uv = area.panel("uv");
            verify(vp.isOpen && vp.isCurrent && vp.visible);
            verify(uv.isOpen && !uv.isCurrent && !uv.visible);
            compare(vp.parent, area._stackItems[stackOf("viewport").id].contentHost);
            compare(vp.parent, uv.parent);
            compare(vp.dockArea, area);
            verify(vp.width > 0 && vp.height > 0);
            compare(vp.Window.window, root.Window.window);
        }

        function test_default_layout_property() {
            const a = createTemporaryObject(dockComponent, root, {
                defaultLayout: { row: [ { tabs: ["timeline", "outliner"], size: 0.3 }, { tabs: ["viewport"] } ] }
            });
            // The panels it doesn't mention still get placed by their hints.
            compare(shape(a.root), "row(tabs[timeline*,outliner],tabs[viewport*,uv],tabs[inspector*,pinned])");
        }

        // ---- interaction -----------------------------------------------------

        function test_clicking_a_tab_makes_it_current() {
            const s = area._stackItems[stackOf("viewport").id];
            mouseClick(s, s.tabInsertX(1) + 12, area.style.tabHeight / 2);
            const st = stackOf("uv");
            compare(st.current, "uv");
            verify(area.panel("uv").visible);
            verify(!area.panel("viewport").visible);
            compare(area.activePanel, area.panel("uv"));
        }

        function test_resize_handle_respects_minimums() {
            const row = area.root.children[0];
            const h = area.geometry.handles[row.id + ":0"];
            verify(h);
            const before = stackRect("outliner").width;
            mouseDrag(area, h.x + h.width / 2, h.y + h.height / 2, 100, 0);
            tryVerify(() => Math.abs(stackRect("outliner").width - (before + 100)) <= 2);
            const h2 = area.geometry.handles[row.id + ":0"];
            mouseDrag(area, h2.x + h2.width / 2, h2.y + h2.height / 2, -600, 0);
            tryCompare(stackRect("outliner"), "width", 150);
            verify(!area.resizing);
        }

        function test_content_stays_interactive_and_tracks_active_panel() {
            const button = area.panel("inspector").children[0];
            mouseClick(button);
            compare(button.clicks, 1);
            compare(area.activePanel, area.panel("inspector"));
        }

        function test_maximize_toggles() {
            area.toggleMaximized("viewport");
            compare(area.geometry.stackIds.length, 1);
            compare(stackRect("viewport").width, area.width);
            verify(!area._stackItems[stackOf("outliner").id].visible);
            area.toggleMaximized("viewport");
            compare(area.geometry.stackIds.length, 4);
        }

        // ---- open / close ----------------------------------------------------

        function test_close_and_reopen_keeps_content_state() {
            const vp = area.panel("viewport");
            const input = vp.children[0];
            input.text = "unsaved work";
            vp.close();
            verify(!vp.isOpen);
            compare(vp.parent, null);
            compare(stackOf("uv").panels, ["uv"]);
            vp.open();
            verify(vp.isOpen && vp.isCurrent);
            compare(stackOf("viewport"), stackOf("uv"));          // back into the group it left
            compare(vp.children[0], input);
            compare(input.text, "unsaved work");
        }

        function test_reopen_uses_hint_when_group_is_gone() {
            area.closePanel("timeline");
            compare(shape(area.root), "row(tabs[outliner*],tabs[viewport*,uv],tabs[inspector*,pinned])");
            area.openPanel("timeline");
            compare(area.root.type, "column");
            compare(shape(area.root.children[1]), "tabs[timeline*]");
            area.openPanel("hidden");
            compare(stackOf("hidden"), stackOf("viewport"));
        }

        // ---- drag and drop ---------------------------------------------------

        function dragTo(panelId, targetArea, x, y) {
            const m = area.manager;
            m.beginDrag(area.panel(panelId), area);
            targetArea.dragMoved(x, y);
            const ok = targetArea.dropped();
            m.finishDrag(ok ? Qt.MoveAction : Qt.IgnoreAction);
            return ok;
        }

        function test_drop_splits_a_stack() {
            const r = stackRect("viewport");
            verify(dragTo("timeline", area, r.x + r.width - 10, r.y + r.height / 2));
            tryCompare(area, "panelCount", 7 - 1);
            tryVerify(() => shape(area.root) === "row(tabs[outliner*],row(tabs[viewport*,uv],tabs[timeline*]),tabs[inspector*,pinned])"
                            || shape(area.root) === "row(tabs[outliner*],tabs[viewport*,uv],tabs[timeline*],tabs[inspector*,pinned])");
        }

        function test_drop_into_tab_bar_inserts_at_index() {
            const r = stackRect("inspector");
            const s = area._stackItems[stackOf("inspector").id];
            verify(dragTo("outliner", area, r.x + s.tabInsertX(1) - 2, r.y + 10));
            tryCompare(stackOf("inspector"), "panels", ["inspector", "outliner", "pinned"]);
            compare(stackOf("inspector").current, "outliner");
        }

        function test_drop_on_edge_indicator_docks_full_edge() {
            verify(dragTo("outliner", area, area.width / 2, area.height - 20));
            tryVerify(() => shape(area.root) === "column(row(tabs[viewport*,uv],tabs[inspector*,pinned]),tabs[timeline*],tabs[outliner*])");
        }

        function test_drop_on_own_stack_is_ignored() {
            const before = JSON.stringify(area.saveLayout());
            const r = stackRect("outliner");
            verify(!dragTo("outliner", area, r.x + r.width / 2, r.y + r.height / 2));
            wait(20);
            compare(JSON.stringify(area.saveLayout()), before);
            compare(area.manager.windows.length, 0);
        }

        function test_release_near_window_edge_tears_off() {
            const m = area.manager;
            m.beginDrag(area.panel("uv"), area);
            area.dragMoved(600, 400);
            m.trackDrag(root.Window.window, 3, 400);      // last seen at the window border
            area.clearDragState();
            m.finishDrag(Qt.IgnoreAction);
            tryVerify(() => m.windows.length === 1);
            verify(area.panel("uv").isPoppedOut);
        }

        function test_cancel_inside_window_does_nothing() {
            const m = area.manager;
            const before = JSON.stringify(area.saveLayout());
            m.beginDrag(area.panel("uv"), area);
            area.dragMoved(600, 400);                       // Esc while over the middle
            area.clearDragState();
            m.finishDrag(Qt.IgnoreAction);
            wait(20);
            compare(m.windows.length, 0);
            compare(JSON.stringify(area.saveLayout()), before);
        }

        function test_unmovable_panel_cannot_start_a_drag() {
            area.startDrag(area.panel("pinned"), "", Qt.point(0, 0));
            compare(area.manager.dragPanel, null);
        }

        // ---- pop-out windows -------------------------------------------------

        function test_pop_out_moves_panel_into_its_own_window() {
            const vp = area.panel("viewport");
            const input = vp.children[0];
            input.text = "kept";
            const popArea = area.popOut("viewport");
            verify(popArea);
            compare(area.manager.windows.length, 1);
            verify(vp.isPoppedOut);
            compare(vp.dockArea, popArea);
            compare(vp.Window.window, area.manager.windows[0]);
            compare(input.text, "kept");
            compare(stackOf("uv").panels, ["uv"]);
            verify(!area.panel("pinned").popOut());
            verify(!area.panel("pinned").isPoppedOut);
        }

        function test_panels_dock_into_pop_out_windows() {
            const popArea = area.popOut("viewport");
            const r = popArea.geometry.rects[popArea.root.id];
            verify(dragTo("uv", popArea, r.x + r.width / 2, r.y + r.height - 5));
            tryCompare(popArea, "panelCount", 2);
            compare(shape(popArea.root), "column(tabs[viewport*],tabs[uv*])");
            compare(area.panel("uv").Window.window, area.manager.windows[0]);
            // Non-floatable panels are refused by pop-out areas.
            verify(!dragTo("pinned", popArea, r.x + r.width / 2, r.y + 50));
            verify(!area.panel("pinned").isPoppedOut);
        }

        function test_empty_pop_out_window_closes_itself() {
            area.popOut("timeline");
            const win = area.manager.windows[0];
            const r = stackRect("viewport");
            verify(dragTo("timeline", area, r.x + r.width / 2, r.y + r.height / 2));
            tryVerify(() => area.manager.windows.length === 0);
            compare(stackOf("timeline"), stackOf("viewport"));
            verify(!area.panel("timeline").isPoppedOut);
        }

        function test_closing_pop_out_returns_panels() {
            area.popOut("timeline");
            const popArea = area.manager.windows[0].dockArea;
            popArea.manager.movePanel("uv", popArea, { kind: "tab", stackId: popArea.root.id, index: -1 });
            area.manager.windows[0].close();
            tryVerify(() => area.manager.windows.length === 0);
            verify(area.panel("timeline").isOpen && !area.panel("timeline").isPoppedOut);
            verify(area.panel("uv").isOpen && !area.panel("uv").isPoppedOut);
        }

        function test_close_panels_policy() {
            area.windowClosePolicy = Dock.ClosePanels;
            area.popOut("timeline");
            area.manager.windows[0].close();
            tryVerify(() => area.manager.windows.length === 0);
            verify(!area.panel("timeline").isOpen);
        }

        // ---- persistence -----------------------------------------------------

        function test_save_restore_round_trip() {
            area.popOut("uv");
            area.closePanel("timeline");
            const saved = area.saveLayout();
            compare(saved.windows.length, 1);
            compare(saved.closed.sort(), ["hidden", "timeline"]);

            area.resetLayout();
            compare(area.manager.windows.length, 0);
            verify(area.panel("timeline").isOpen);

            verify(area.restoreLayout(JSON.stringify(saved)));
            compare(area.manager.windows.length, 1);
            verify(area.panel("uv").isPoppedOut);
            verify(!area.panel("timeline").isOpen);
            compare(JSON.stringify(area.saveLayout().main), JSON.stringify(saved.main));
        }

        function test_restore_tolerates_unknown_and_new_panels() {
            const ok = area.restoreLayout({
                version: 1,
                main: { row: [ { tabs: ["ghost", "viewport"] }, { tabs: ["outliner"] } ] },
                windows: [],
                closed: ["uv"]
            });
            verify(ok);
            // inspector, pinned and timeline aren't in the saved layout, so
            // they are new to it and get placed by their hints.
            compare(shape(area.root),
                    "column(row(tabs[viewport*],tabs[outliner*],tabs[inspector*,pinned]),tabs[timeline*])");
            verify(!area.panel("uv").isOpen);
            ignoreWarning(/restoreLayout: invalid JSON/);
            verify(!area.restoreLayout("{ not json"));
            ignoreWarning(/restoreLayout: unsupported layout/);
            verify(!area.restoreLayout({ version: 99 }));
        }

        function test_autosave_restores_on_next_start() {
            const key = "tst-autosave";
            // Apps must name themselves for QSettings (the qml tool does).
            Qt.application.organization = "QuiltTests";
            const first = createTemporaryObject(dockComponent, root, { autoSaveKey: key });
            first.closePanel("timeline");
            first.popOut("uv");
            first.manager.saveNow();

            const second = createTemporaryObject(dockComponent, root, { autoSaveKey: key });
            verify(!second.panel("timeline").isOpen);
            verify(second.panel("uv").isPoppedOut);

            // Leave nothing behind in the settings store.
            first.autoSaveKey = "";
            second.autoSaveKey = "";
            second.manager._store().setValue(key, "");
        }

        // ---- dynamic panels and constraints ---------------------------------

        function test_dynamic_panels() {
            const p = lateComponent.createObject(area, { panelId: "late" });
            verify(area.addPanel(p));
            verify(p.isOpen && p.isCurrent);
            compare(stackOf("late"), stackOf("viewport"));
            ignoreWarning(/duplicate panelId late/);
            verify(!area.addPanel(lateComponent.createObject(area, { panelId: "late" })));   // duplicate id
            area.removePanel("late");
            verify(!p.isOpen);
            compare(area.panel("late"), null);
        }

        function test_minimum_size_follows_constraints() {
            const minW = area.minimumWidth;
            verify(minW >= 150 + 2 * 120);
            area.panel("viewport").minimumWidth = 500;
            compare(area.minimumWidth, minW - 120 + 500);
            compare(stackRect("viewport").width >= 500, true);
        }

        // ---- panels that can't share a tab group ----------------------------

        function test_non_tabbable_panel_gets_its_own_group_and_title_bar() {
            const g = createTemporaryObject(gridComponent, root, { defaultLayout: { row: [ { tabs: ["a", "b"] }, { tabs: ["c", "d"] } ] } });
            g.openPanel("tools");
            compare(stackOf("tools", g).panels, ["tools"]);
            const s = g._stackItems[stackOf("tools", g).id];
            verify(s.solo);
            verify(!g._stackItems[stackOf("a", g).id].solo);

            // Dropping another panel on its middle (or header) splits instead.
            const m = g.manager;
            const r = stackRect("tools", g);
            m.beginDrag(g.panel("a"), g);
            g.dragMoved(r.x + r.width / 2, r.y + 10);
            compare(g._target.kind, "split");
            g.clearDragState();
            m.finishDrag(Qt.IgnoreAction);

            // ...and it never joins another group, even through the API.
            m.movePanel("tools", g, { kind: "tab", stackId: stackOf("c", g).id, index: -1 });
            compare(stackOf("tools", g).panels, ["tools"]);
            compare(stackOf("c", g).panels, ["c", "d"]);
        }

        function test_restore_separates_non_tabbable_panels() {
            const g = createTemporaryObject(gridComponent, root);
            verify(g.restoreLayout({ version: 1, main: { tabs: ["a", "tools", "b"] }, windows: [], closed: ["c", "d"] }));
            compare(shape(g.root), "row(tabs[a*,b],tabs[tools*])");
        }

        // ---- split lines -----------------------------------------------------

        readonly property var gridRows: ({ column: [ { row: [ { tabs: ["a"] }, { tabs: ["b"] } ] },
                                                     { row: [ { tabs: ["c"] }, { tabs: ["d"] } ] } ] })
        readonly property var gridColumns: ({ row: [ { column: [ { tabs: ["a"] }, { tabs: ["c"] } ] },
                                                     { column: [ { tabs: ["b"] }, { tabs: ["d"] } ] } ] })

        function grid(layout) {
            return createTemporaryObject(gridComponent, root, { defaultLayout: layout });
        }

        function widthOf(g, id) { return stackRect(id, g).width; }
        function heightOf(g, id) { return stackRect(id, g).height; }

        // Press at (x, y), move by (dx, dy) in two steps, release.
        function dragLine(g, x, y, dx, dy, modifiers) {
            mousePress(g, x, y, Qt.LeftButton, modifiers);
            mouseMove(g, x + dx / 2, y + dy / 2, -1, Qt.LeftButton, modifiers);
            mouseMove(g, x + dx, y + dy, -1, Qt.LeftButton, modifiers);
            mouseRelease(g, x + dx, y + dy, Qt.LeftButton, modifiers);
            verify(!g.resizing);
        }

        // 1200 wide, gap 4: the middle vertical line is centred at x = 600.
        function test_aligned_segments_move_as_one_line() {
            const g = grid(gridRows);
            compare([widthOf(g, "a"), widthOf(g, "c")], [598, 598]);
            dragLine(g, 600, 200, 100, 0, Qt.NoModifier);
            compare([widthOf(g, "a"), widthOf(g, "c")], [698, 698]);
            compare([widthOf(g, "b"), widthOf(g, "d")], [498, 498]);
        }

        function test_ctrl_moves_only_the_segment() {
            const g = grid(gridRows);
            dragLine(g, 600, 200, 100, 0, Qt.ControlModifier);
            compare([widthOf(g, "a"), widthOf(g, "c")], [698, 598]);
        }

        function test_ctrl_breaks_a_full_length_handle() {
            const g = grid(gridColumns);
            // Without Ctrl the single handle moves the whole line.
            dragLine(g, 600, 200, 50, 0, Qt.NoModifier);
            compare([widthOf(g, "a"), widthOf(g, "c")], [648, 648]);
            // With Ctrl only the top part moves; the tree is re-shaped.
            dragLine(g, 650, 200, 50, 0, Qt.ControlModifier);
            compare(g.root.type, "column");
            compare([widthOf(g, "a"), widthOf(g, "c")], [698, 648]);
            compare([heightOf(g, "a"), heightOf(g, "c")], [398, 398]);
        }

        function test_horizontal_line_across_columns_moves_as_one() {
            const g = grid(gridColumns);                  // two handles, one per column, at y = 400
            dragLine(g, 300, 400, 0, 80, Qt.NoModifier);
            compare([heightOf(g, "a"), heightOf(g, "b")], [478, 478]);
            dragLine(g, 900, 480, 0, -40, Qt.ControlModifier);
            compare([heightOf(g, "a"), heightOf(g, "b")], [478, 438]);
        }

        function test_close_segments_snap_and_then_link() {
            const g = grid(gridRows);
            dragLine(g, 600, 200, 6, 0, Qt.ControlModifier);      // misalign the top by 6 px
            compare([widthOf(g, "a"), widthOf(g, "c")], [604, 598]);
            dragLine(g, 600, 600, 3, 0, Qt.NoModifier);           // bottom comes within snap distance
            compare([widthOf(g, "a"), widthOf(g, "c")], [604, 604]);
            dragLine(g, 606, 600, -50, 0, Qt.NoModifier);         // now they move together
            compare([widthOf(g, "a"), widthOf(g, "c")], [554, 554]);
        }

        function test_ctrl_drag_does_not_snap() {
            const g = grid(gridRows);
            dragLine(g, 600, 200, 6, 0, Qt.ControlModifier);
            dragLine(g, 600, 600, 3, 0, Qt.ControlModifier);
            compare([widthOf(g, "a"), widthOf(g, "c")], [604, 601]);
        }
    }
}
