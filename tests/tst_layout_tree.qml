import QtQuick
import QtTest
import "../Quilt/LayoutTree.js" as Tree

// Unit tests for the pure layout model. No windows are needed.
TestCase {
    name: "LayoutTree"

    // Compact description of a tree, ignoring ids and sizes, e.g.
    // "row(tabs[a,b*],column(tabs[c*],tabs[d*]))" where * marks the current tab.
    function shape(node) {
        if (!node)
            return "null";
        if (node.type === "tabs")
            return "tabs[" + node.panels.map(p => p === node.current ? p + "*" : p).join(",") + "]";
        return node.type + "(" + node.children.map(shape).join(",") + ")";
    }

    function sizes(node) {
        return node.children.map(c => Math.round(c.size * 1000) / 1000);
    }

    function sample() {
        return Tree.parse({
            row: [
                { tabs: ["outliner"], size: 0.2 },
                { column: [ { tabs: ["viewport", "uv"], current: "viewport" }, { tabs: ["timeline"], size: 0.25 } ] },
                { tabs: ["inspector"], size: 0.2 }
            ]
        });
    }

    // ---- parse / serialize -------------------------------------------------

    function test_parse_fills_missing_sizes() {
        const root = sample();
        compare(shape(root), "row(tabs[outliner*],column(tabs[viewport*,uv],tabs[timeline*]),tabs[inspector*])");
        compare(sizes(root), [0.2, 0.6, 0.2]);
        compare(sizes(root.children[1]), [0.75, 0.25]);
    }

    function test_serialize_round_trip() {
        const json = Tree.serialize(sample());
        compare(shape(Tree.parse(json)), shape(sample()));
        compare(JSON.stringify(Tree.serialize(Tree.parse(json))), JSON.stringify(json));
    }

    function test_parse_drops_unknown_and_duplicate_panels() {
        const seen = {};
        const accept = id => { if (id === "ghost" || seen[id]) return false; seen[id] = true; return true; };
        const root = Tree.parse({ row: [ { tabs: ["a", "ghost"] }, { tabs: ["ghost"] }, { tabs: ["a", "b"] } ] }, accept);
        compare(shape(root), "row(tabs[a*],tabs[b*])");
    }

    function test_parse_collapses_and_flattens() {
        const root = Tree.parse({ row: [ { row: [ { tabs: ["a"] }, { tabs: ["b"] } ] }, { column: [ { tabs: ["c"] } ] } ] });
        compare(shape(root), "row(tabs[a*],tabs[b*],tabs[c*])");
        compare(sizes(root), [0.25, 0.25, 0.5]);
    }

    function test_parse_rejects_garbage() {
        compare(Tree.parse(null), null);
        compare(Tree.parse({ foo: 1 }), null);
        compare(Tree.parse({ row: [] }), null);
        compare(Tree.parse({ tabs: [] }), null);
    }

    // ---- insert / remove ---------------------------------------------------

    function test_insert_tab_appends_and_activates() {
        let root = sample();
        const s = Tree.findStackOf(root, "timeline");
        root = Tree.insertTab(root, s.id, "console", -1);
        compare(shape(s), "tabs[timeline,console*]");
        root = Tree.insertTab(root, s.id, "log", 0, false);
        compare(shape(s), "tabs[log,timeline,console*]");
    }

    function test_insert_tab_reorders_within_stack() {
        let root = Tree.parse({ tabs: ["a", "b", "c"] });
        root = Tree.insertTab(root, root.id, "a", 3);
        compare(root.panels, ["b", "c", "a"]);
        root = Tree.insertTab(root, root.id, "a", 0);
        compare(root.panels, ["a", "b", "c"]);
        root = Tree.insertTab(root, root.id, "c", 1);
        compare(root.panels, ["a", "c", "b"]);
    }

    function test_remove_tab_keeps_stack() {
        let root = sample();
        root = Tree.removePanel(root, "viewport");
        compare(shape(root), "row(tabs[outliner*],column(tabs[uv*],tabs[timeline*]),tabs[inspector*])");
    }

    function test_remove_last_tab_collapses_and_gives_space_to_neighbour() {
        let root = sample();
        root = Tree.removePanel(root, "timeline");
        compare(shape(root), "row(tabs[outliner*],tabs[viewport*,uv],tabs[inspector*])");
        compare(sizes(root), [0.2, 0.6, 0.2]);
        root = Tree.removePanel(root, "inspector");
        compare(sizes(root), [0.2, 0.8]);
        root = Tree.removePanel(root, "outliner");
        compare(shape(root), "tabs[viewport*,uv]");
        root = Tree.removePanel(Tree.removePanel(root, "uv"), "viewport");
        compare(root, null);
    }

    function test_remove_unknown_panel_is_harmless() {
        const root = sample();
        compare(Tree.removePanel(root, "nope"), root);
        compare(Tree.removePanel(null, "nope"), null);
    }

    // ---- split / edge ------------------------------------------------------

    function test_split_wraps_stack_in_new_split() {
        let root = sample();
        const vp = Tree.findStackOf(root, "viewport");
        root = Tree.splitAt(root, vp.id, "graph", "right");
        compare(shape(root.children[1]), "column(row(tabs[viewport*,uv],tabs[graph*]),tabs[timeline*])");
        compare(sizes(root.children[1].children[0]), [0.5, 0.5]);
    }

    function test_split_inserts_into_matching_parent() {
        let root = sample();
        const ins = Tree.findStackOf(root, "inspector");
        root = Tree.splitAt(root, ins.id, "props", "left");
        compare(shape(root), "row(tabs[outliner*],column(tabs[viewport*,uv],tabs[timeline*]),tabs[props*],tabs[inspector*])");
        compare(sizes(root), [0.2, 0.6, 0.1, 0.1]);
    }

    function test_split_root_stack() {
        let root = Tree.parse({ tabs: ["a"] });
        root = Tree.splitAt(root, root.id, "b", "top");
        compare(shape(root), "column(tabs[b*],tabs[a*])");
    }

    function test_dock_at_edge() {
        let root = sample();
        root = Tree.dockAtEdge(root, "console", "bottom", 0.3);
        compare(root.type, "column");
        compare(shape(root.children[1]), "tabs[console*]");
        compare(sizes(root), [0.7, 0.3]);
        // Same orientation as the root: joins the existing split, taking
        // its space from the largest child.
        root = Tree.dockAtEdge(root, "toolbar", "top", 0.1);
        compare(root.children.length, 3);
        compare(shape(root.children[0]), "tabs[toolbar*]");
        compare(sizes(root), [0.1, 0.6, 0.3]);
        // No child has room to spare: everyone shrinks.
        let even = Tree.parse({ row: [ { tabs: ["a"] }, { tabs: ["b"] }, { tabs: ["c"] }, { tabs: ["d"] } ] });
        even = Tree.dockAtEdge(even, "e", "left", 0.2);
        compare(sizes(even), [0.2, 0.2, 0.2, 0.2, 0.2]);
        compare(shape(Tree.dockAtEdge(null, "x", "left")), "tabs[x*]");
    }

    // ---- hints -------------------------------------------------------------

    function test_place_by_hint_builds_ide_layout() {
        let root = null;
        root = Tree.placeByHint(root, "viewport", { side: "center" });
        root = Tree.placeByHint(root, "uv", { side: "center", activate: false });
        root = Tree.placeByHint(root, "outliner", { side: "left", fraction: 0.2 });
        root = Tree.placeByHint(root, "inspector", { side: "right", fraction: 0.25 });
        root = Tree.placeByHint(root, "settings", { side: "right", group: ["inspector", "settings"], activate: false });
        root = Tree.placeByHint(root, "timeline", { side: "bottom", fraction: 0.25 });
        compare(shape(root), "column(row(tabs[outliner*],tabs[viewport*,uv],tabs[inspector*,settings]),tabs[timeline*])");
        compare(sizes(root), [0.75, 0.25]);
        compare(sizes(root.children[0]), [0.2, 0.55, 0.25]);
    }

    function test_place_center_joins_largest_stack() {
        let root = Tree.parse({ row: [ { tabs: ["a"], size: 0.3 }, { tabs: ["b"], size: 0.7 } ] });
        root = Tree.placeByHint(root, "c", { side: "center" });
        compare(shape(root), "row(tabs[a*],tabs[b,c*])");
    }

    // ---- drops ---------------------------------------------------------------

    function test_drop_noops() {
        const root = sample();
        const out = Tree.findStackOf(root, "outliner");
        const vp = Tree.findStackOf(root, "viewport");
        verify(Tree.isNoop(root, "outliner", { kind: "tab", stackId: out.id, index: -1 }));
        verify(Tree.isNoop(root, "outliner", { kind: "split", stackId: out.id, side: "left" }));
        verify(Tree.isNoop(root, "viewport", { kind: "tab", stackId: vp.id, index: 0 }));
        verify(Tree.isNoop(root, "viewport", { kind: "tab", stackId: vp.id, index: 1 }));
        verify(!Tree.isNoop(root, "viewport", { kind: "tab", stackId: vp.id, index: 2 }));
        verify(!Tree.isNoop(root, "viewport", { kind: "split", stackId: vp.id, side: "left" }));
        const single = Tree.parse({ tabs: ["a"] });
        verify(Tree.isNoop(single, "a", { kind: "edge", side: "left" }));
    }

    function test_drop_moves_between_stacks() {
        let root = sample();
        const ins = Tree.findStackOf(root, "inspector");
        root = Tree.applyDrop(root, "uv", { kind: "tab", stackId: ins.id, index: 0 });
        compare(shape(root), "row(tabs[outliner*],column(tabs[viewport*],tabs[timeline*]),tabs[uv*,inspector])");
    }

    function test_drop_split_of_own_stack_with_other_tabs() {
        let root = sample();
        const vp = Tree.findStackOf(root, "viewport");
        root = Tree.applyDrop(root, "uv", { kind: "split", stackId: vp.id, side: "bottom" });
        compare(shape(root.children[1]), "column(tabs[viewport*],tabs[uv*],tabs[timeline*])");
    }

    function test_drop_single_panel_next_to_sibling_collapses_source() {
        let root = sample();
        const vp = Tree.findStackOf(root, "viewport");
        root = Tree.applyDrop(root, "outliner", { kind: "split", stackId: vp.id, side: "left" });
        compare(shape(root), "row(column(row(tabs[outliner*],tabs[viewport*,uv]),tabs[timeline*]),tabs[inspector*])");
    }

    function test_drop_to_edge_and_empty() {
        let root = sample();
        root = Tree.applyDrop(root, "timeline", { kind: "edge", side: "bottom", fraction: 0.2 });
        compare(shape(root), "column(row(tabs[outliner*],tabs[viewport*,uv],tabs[inspector*]),tabs[timeline*])");
        compare(shape(Tree.applyDrop(null, "x", { kind: "empty" })), "tabs[x*]");
    }

    function test_drop_onto_missing_stack_never_loses_panel() {
        let root = sample();
        root = Tree.applyDrop(root, "uv", { kind: "tab", stackId: "stack-gone", index: -1 });
        verify(Tree.findStackOf(root, "uv") !== null);
    }

    // ---- geometry ------------------------------------------------------------

    function test_distribute_proportional() {
        compare(Tree.distribute([0.25, 0.75], [0, 0], [Infinity, Infinity], 400), [100, 300]);
    }

    function test_distribute_respects_min_and_max() {
        const s = Tree.distribute([0.1, 0.45, 0.45], [150, 0, 0], [Infinity, Infinity, 100], 1000);
        compare(s[0], 150);
        compare(s[2], 100);
        compare(s[1], 750);
    }

    function test_distribute_overflow_scales_minimums() {
        compare(Tree.distribute([0.5, 0.5], [300, 100], [Infinity, Infinity], 200), [150, 50]);
    }

    function test_distribute_all_at_max_shares_leftover() {
        const s = Tree.distribute([0.5, 0.5], [0, 0], [100, 100], 400);
        compare(s[0] + s[1], 400);
    }

    function test_compute_layout_rects_and_handles() {
        const root = Tree.parse({ row: [ { tabs: ["a"], size: 0.25 }, { tabs: ["b"] } ] });
        const l = Tree.computeLayout(root, 404, 300, { gap: 4 });
        const a = l.rects[root.children[0].id], b = l.rects[root.children[1].id];
        compare([a.x, a.width, b.x, b.width], [0, 100, 104, 300]);
        const h = l.handles[root.id + ":0"];
        compare([h.x, h.width, h.height, h.horizontal], [100, 4, 300, true]);
        compare(l.stackIds.length, 2);
    }

    function test_compute_layout_honours_minimums() {
        const mins = { a: 200, b: 0 };
        const opts = { gap: 0, tabHeight: 30, constraints: id => ({ minimumWidth: mins[id], minimumHeight: 50,
                                                                     maximumWidth: Infinity, maximumHeight: Infinity }) };
        const root = Tree.parse({ row: [ { tabs: ["a"], size: 0.1 }, { tabs: ["b"] } ] });
        const l = Tree.computeLayout(root, 1000, 500, opts);
        compare(l.rects[root.children[0].id].width, 200);
        compare(Tree.minimumSize(root, opts).width, 200);
        compare(Tree.minimumSize(root, opts).height, 80);
    }

    function test_compute_layout_maximized() {
        const root = sample();
        const vp = Tree.findStackOf(root, "viewport");
        const l = Tree.computeLayout(root, 800, 600, { maximized: vp.id });
        compare(l.stackIds, [vp.id]);
        compare(l.rects[vp.id].width, 800);
        compare(Object.keys(l.handles).length, 0);
    }

    function test_resize_moves_only_the_adjacent_pair() {
        const root = Tree.parse({ row: [ { tabs: ["a"] }, { tabs: ["b"] }, { tabs: ["c"] } ] });
        const opts = { gap: 0 };
        const l = Tree.computeLayout(root, 900, 100, opts);
        const st = Tree.beginResize(root, l, root.id, 0, opts);
        Tree.applyResize(st, 100);
        const l2 = Tree.computeLayout(root, 900, 100, opts);
        compare(l2.rects[root.children[0].id].width, 400);
        compare(l2.rects[root.children[1].id].width, 200);
        compare(l2.rects[root.children[2].id].width, 300);
    }

    function test_resize_clamps_to_limits() {
        const opts = { gap: 0, constraints: id => ({ minimumWidth: id === "b" ? 250 : 50, minimumHeight: 0,
                                                     maximumWidth: id === "a" ? 400 : Infinity, maximumHeight: Infinity }) };
        const root = Tree.parse({ row: [ { tabs: ["a"] }, { tabs: ["b"] } ] });
        const l = Tree.computeLayout(root, 600, 100, opts);
        const st = Tree.beginResize(root, l, root.id, 0, opts);
        Tree.applyResize(st, 1000);
        let l2 = Tree.computeLayout(root, 600, 100, opts);
        compare(l2.rects[root.children[0].id].width, 350);     // stopped by b's minimum
        Tree.applyResize(st, -1000);
        l2 = Tree.computeLayout(root, 600, 100, opts);
        compare(l2.rects[root.children[0].id].width, 50);      // stopped by a's minimum
    }

    // ---- hit testing ---------------------------------------------------------

    function test_hit_test_zones() {
        const root = Tree.parse({ row: [ { tabs: ["a"] }, { tabs: ["b"] } ] });
        const l = Tree.computeLayout(root, 800, 600, { gap: 0 });
        const opts = { tabHeight: 30, indicatorSize: 36, indicatorInset: 8, tabIndexAt: () => 1 };
        const a = root.children[0].id;

        let t = Tree.hitTest(root, l, 800, 600, 200, 330, opts);          // middle of a
        compare([t.kind, t.stackId, t.index], ["tab", a, -1]);
        t = Tree.hitTest(root, l, 800, 600, 380, 330, opts);              // right edge of a
        compare([t.kind, t.stackId, t.side], ["split", a, "right"]);
        compare(t.rect.width, 200);
        t = Tree.hitTest(root, l, 800, 600, 200, 590, opts);              // bottom edge of a
        compare([t.kind, t.side], ["split", "bottom"]);
        t = Tree.hitTest(root, l, 800, 600, 200, 10, opts);               // a's tab bar
        compare([t.kind, t.inTabBar, t.index], ["tab", true, 1]);
        t = Tree.hitTest(root, l, 800, 600, 20, 300, opts);               // left edge indicator
        compare([t.kind, t.side, t.rect.width], ["edge", "left", 200]);
        t = Tree.hitTest(null, null, 800, 600, 5, 5, opts);
        compare(t.kind, "empty");
    }

    function test_hit_test_gap_returns_null() {
        const root = Tree.parse({ row: [ { tabs: ["a"] }, { tabs: ["b"] } ] });
        const l = Tree.computeLayout(root, 804, 600, { gap: 4 });
        compare(Tree.hitTest(root, l, 804, 600, 401, 200, { tabHeight: 30 }), null);
    }
}
