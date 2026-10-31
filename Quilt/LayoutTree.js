.pragma library

// Quilt layout tree: plain data and pure functions, with no Qt types, so every
// rule can be unit-tested headless.
//
// Internal node shapes. `size` is the node's weight inside its parent split;
// the weights of siblings always sum to 1.
//
//   split: { id, type: "row" | "column", children: [node, ...], size }
//   stack: { id, type: "tabs", panels: [panelId, ...], current: panelId, size }
//
// Compact JSON form, accepted by parse() and produced by serialize():
//
//   { row: [child, ...] }   { column: [child, ...] }   { tabs: ["a", "b"], current: "b" }
//
// Any child may carry `size`, its fraction of the parent.
//
// Invariants kept by normalize(): no empty stacks, no split with fewer than
// two children, no split directly inside a split of the same type.
//
// Sides are the strings "left", "right", "top" and "bottom".

var _counter = 0;

function newId(prefix) {
    _counter += 1;
    return prefix + _counter;
}

function makeStack(panels, current, size) {
    var list = panels ? panels.slice() : [];
    return {
        id: newId("stack"),
        type: "tabs",
        panels: list,
        current: list.indexOf(current) >= 0 ? current : (list.length ? list[0] : ""),
        size: size
    };
}

function makeSplit(type, children, size) {
    return { id: newId("split"), type: type, children: children, size: size };
}

function isSplit(node) {
    return !!node && (node.type === "row" || node.type === "column");
}

function isStack(node) {
    return !!node && node.type === "tabs";
}

// ---------------------------------------------------------------------------
//  Traversal and queries

function walk(node, fn, parent) {
    if (!node)
        return;
    fn(node, parent || null);
    if (isSplit(node))
        for (var i = 0; i < node.children.length; ++i)
            walk(node.children[i], fn, node);
}

function find(root, predicate) {
    var hit = null;
    walk(root, function (n) { if (!hit && predicate(n)) hit = n; });
    return hit;
}

function findNode(root, id) {
    return find(root, function (n) { return n.id === id; });
}

function findStack(root, id) {
    var n = findNode(root, id);
    return isStack(n) ? n : null;
}

function findStackOf(root, panelId) {
    return find(root, function (n) { return isStack(n) && n.panels.indexOf(panelId) >= 0; });
}

function findParent(root, node) {
    var hit = null;
    walk(root, function (n, p) { if (n === node) hit = p; });
    return hit;
}

function stacks(root) {
    var out = [];
    walk(root, function (n) { if (isStack(n)) out.push(n); });
    return out;
}

function stackIds(root) {
    return stacks(root).map(function (s) { return s.id; });
}

function panelIds(root) {
    var out = [];
    stacks(root).forEach(function (s) { out = out.concat(s.panels); });
    return out;
}

function handleKeys(root) {
    var out = [];
    walk(root, function (n) {
        if (isSplit(n))
            for (var i = 0; i + 1 < n.children.length; ++i)
                out.push(n.id + ":" + i);
    });
    return out;
}

// ---------------------------------------------------------------------------
//  Normalisation, parsing and serialisation

function _validSize(s) {
    return typeof s === "number" && s > 0 && isFinite(s);
}

// Gives unsized children a share of what is left and rescales everything so
// the weights sum to 1.
function _fixSizes(children) {
    var known = 0, nKnown = 0;
    children.forEach(function (c) {
        if (_validSize(c.size)) { known += c.size; nKnown += 1; }
    });
    var nUnknown = children.length - nKnown;
    if (nUnknown > 0) {
        var share = known < 1 ? (1 - known) / nUnknown : (nKnown ? known / nKnown : 1);
        children.forEach(function (c) { if (!_validSize(c.size)) c.size = share; });
    }
    var total = 0;
    children.forEach(function (c) { total += c.size; });
    children.forEach(function (c) { c.size = c.size / total; });
}

function normalize(node) {
    if (!node)
        return null;
    if (isStack(node)) {
        if (node.panels.length === 0)
            return null;
        if (node.panels.indexOf(node.current) < 0)
            node.current = node.panels[0];
        return node;
    }
    var kept = [];
    node.children.forEach(function (c) {
        var n = normalize(c);
        if (n)
            kept.push(n);
    });
    if (kept.length === 0)
        return null;
    if (kept.length === 1) {
        kept[0].size = node.size;
        return kept[0];
    }
    _fixSizes(kept);
    var flat = [];
    kept.forEach(function (c) {
        if (c.type === node.type) {
            c.children.forEach(function (g) { g.size = g.size * c.size; flat.push(g); });
        } else {
            flat.push(c);
        }
    });
    node.children = flat;
    _fixSizes(flat);
    return node;
}

// `accept(panelId)` decides whether a panel may be placed; it is called once
// per occurrence, so it can also reject duplicates.
function parse(json, accept) {
    var ok = accept || function () { return true; };
    return normalize(_parseNode(json, ok));
}

// Layouts handed over from QML or C++ may arrive as array-like sequences
// rather than real JS arrays.
function _list(x) {
    if (Array.isArray(x))
        return x;
    if (x && typeof x === "object" && typeof x.length === "number")
        return Array.prototype.slice.call(x);
    return null;
}

function _parseNode(j, accept) {
    if (!j || typeof j !== "object")
        return null;
    var size = _validSize(j.size) ? j.size : undefined;
    var tabs = _list(j.tabs);
    if (tabs) {
        var ids = tabs.filter(function (id) { return typeof id === "string" && accept(id); });
        return makeStack(ids, j.current, size);
    }
    var type = _list(j.row) ? "row" : (_list(j.column) ? "column" : "");
    if (!type)
        return null;
    return makeSplit(type, _list(j[type]).map(function (c) { return _parseNode(c, accept); }), size);
}

function serialize(node, withSize) {
    if (!node)
        return null;
    var out;
    if (isStack(node)) {
        out = { tabs: node.panels.slice(), current: node.current };
    } else {
        out = {};
        out[node.type] = node.children.map(function (c) { return serialize(c, true); });
    }
    if (withSize)
        out.size = Math.round(node.size * 10000) / 10000;
    return out;
}

// ---------------------------------------------------------------------------
//  Mutations. Each returns the (possibly new) root and leaves it normalised.

function _axis(side) {
    return (side === "left" || side === "right") ? "row" : "column";
}

function _before(side) {
    return side === "left" || side === "top";
}

function _clampFraction(f, fallback) {
    if (!(f > 0 && f < 1))
        return fallback;
    return Math.min(0.9, Math.max(0.05, f));
}

function _replace(root, oldNode, newNode) {
    var parent = findParent(root, oldNode);
    if (!parent)
        return newNode;
    parent.children[parent.children.indexOf(oldNode)] = newNode;
    return root;
}

// Adds a panel to a stack at `index` (-1 or undefined appends). Reorders when
// the panel is already in that stack.
function insertTab(root, stackId, panelId, index, activate) {
    var s = findStack(root, stackId);
    if (!s)
        return root;
    var from = s.panels.indexOf(panelId);
    var at = (index === undefined || index < 0) ? s.panels.length : index;
    if (from >= 0) {
        s.panels.splice(from, 1);
        if (at > from)
            at -= 1;
    }
    at = Math.min(at, s.panels.length);
    s.panels.splice(at, 0, panelId);
    if (activate !== false)
        s.current = panelId;
    return root;
}

// Removes a panel. An emptied stack disappears and its space goes to the
// neighbour before it (or after it, for a first child).
function removePanel(root, panelId) {
    var s = findStackOf(root, panelId);
    if (!s)
        return root;
    var i = s.panels.indexOf(panelId);
    s.panels.splice(i, 1);
    if (s.panels.length > 0) {
        if (s.current === panelId)
            s.current = s.panels[Math.min(i, s.panels.length - 1)];
        return root;
    }
    var parent = findParent(root, s);
    if (!parent)
        return null;
    var k = parent.children.indexOf(s);
    parent.children.splice(k, 1);
    parent.children[k > 0 ? k - 1 : 0].size += s.size;
    return normalize(root);
}

// Splits stack `stackId` and puts the panel on `side` of it, taking
// `fraction` (default half) of the stack's space.
function splitAt(root, stackId, panelId, side, fraction) {
    var s = findStack(root, stackId);
    if (!s)
        return root;
    var f = _clampFraction(fraction, 0.5);
    var type = _axis(side), before = _before(side);
    var fresh = makeStack([panelId], panelId);
    var parent = findParent(root, s);
    if (parent && parent.type === type) {
        fresh.size = s.size * f;
        s.size = s.size * (1 - f);
        var k = parent.children.indexOf(s);
        parent.children.splice(before ? k : k + 1, 0, fresh);
        return normalize(root);
    }
    var split = makeSplit(type, before ? [fresh, s] : [s, fresh], s.size);
    root = _replace(root, s, split);
    fresh.size = f;
    s.size = 1 - f;
    return normalize(root);
}

// Docks a panel along a whole edge of the layout, taking `fraction`
// (default a quarter) of the area.
function dockAtEdge(root, panelId, side, fraction) {
    var fresh = makeStack([panelId], panelId, 1);
    if (!root)
        return fresh;
    var f = _clampFraction(fraction, 0.25);
    var type = _axis(side), before = _before(side);
    if (root.type === type) {
        // Take the space from the largest child (normally the centre) so
        // panels already docked along this axis keep their size; fall back
        // to shrinking everyone when it has no room to spare.
        var largest = root.children[0];
        root.children.forEach(function (c) { if (c.size > largest.size) largest = c; });
        if (largest.size - f >= 0.1)
            largest.size -= f;
        else
            root.children.forEach(function (c) { c.size *= (1 - f); });
        fresh.size = f;
        if (before)
            root.children.unshift(fresh);
        else
            root.children.push(fresh);
        return normalize(root);
    }
    fresh.size = f;
    root.size = 1 - f;
    return normalize(makeSplit(type, before ? [fresh, root] : [root, fresh], 1));
}

// The stack with the most area, used as the "centre" of a layout.
function largestStack(root) {
    if (!root)
        return null;
    var l = computeLayout(root, 1000, 1000, {});
    var best = null, bestArea = -1;
    stacks(root).forEach(function (s) {
        var r = l.rects[s.id];
        var a = r.width * r.height;
        if (a > bestArea) { bestArea = a; best = s; }
    });
    return best;
}

// Places a panel using its declarative hint:
//   { side: "center" | "left" | ..., fraction, group: [panelIds], activate }
// It joins the first stack that holds a panel of `group` (panels sharing the
// same hint); otherwise centre panels join the largest stack and edge panels
// dock along their edge.
function placeByHint(root, panelId, hint) {
    var h = hint || {};
    var target = null;
    var group = h.group || [];
    for (var i = 0; i < group.length && !target; ++i)
        if (group[i] !== panelId)
            target = findStackOf(root, group[i]);
    if (!target && (h.side === "center" || !h.side))
        target = largestStack(root);
    if (target)
        return insertTab(root, target.id, panelId, -1, h.activate !== false);
    if (!root)
        return makeStack([panelId], panelId, 1);
    return dockAtEdge(root, panelId, h.side, h.fraction);
}

// True when dropping `panelId` on `target` would leave the layout unchanged.
function isNoop(root, panelId, target) {
    var src = findStackOf(root, panelId);
    if (!src || !target)
        return false;
    var alone = src.panels.length === 1;
    if (target.kind === "tab" && target.stackId === src.id) {
        if (alone || target.index === undefined || target.index < 0)
            return true;
        var i = src.panels.indexOf(panelId);
        return target.index === i || target.index === i + 1;
    }
    if (target.kind === "split" && target.stackId === src.id)
        return alone;
    if (target.kind === "edge")
        return alone && root === src;
    return false;
}

// Moves a panel already in (or new to) this tree onto a drop target:
//   { kind: "tab", stackId, index } | { kind: "split", stackId, side, fraction }
//   { kind: "edge", side, fraction } | { kind: "empty" }
function applyDrop(root, panelId, target) {
    if (!target || isNoop(root, panelId, target))
        return root;
    var src = findStackOf(root, panelId);
    if (target.kind === "tab" && src && src.id === target.stackId)
        return insertTab(root, target.stackId, panelId, target.index, true);
    root = removePanel(root, panelId);
    var hasTarget = !!findStack(root, target.stackId);
    if (target.kind === "tab" && hasTarget)
        return insertTab(root, target.stackId, panelId, target.index, true);
    if (target.kind === "split" && hasTarget)
        return splitAt(root, target.stackId, panelId, target.side, target.fraction);
    if (target.kind === "edge")
        return dockAtEdge(root, panelId, target.side, target.fraction);
    // "empty", or a target that no longer exists: never lose the panel.
    return placeByHint(root, panelId, { side: "center" });
}

// ---------------------------------------------------------------------------
//  Geometry

// Splits `total` pixels between children proportionally to `weights` while
// honouring each child's [min, max]. When the minimums cannot fit, sizes
// shrink proportionally to the minimums. When every child sits at its
// maximum, the leftover is shared out anyway (maximums are soft in that case).
function distribute(weights, mins, maxs, total) {
    var n = weights.length, sizes = [], fixed = [], i;
    var minSum = 0;
    for (i = 0; i < n; ++i) { minSum += mins[i]; fixed.push(false); sizes.push(0); }
    if (n === 0)
        return sizes;
    if (minSum >= total) {
        for (i = 0; i < n; ++i)
            sizes[i] = minSum > 0 ? total * mins[i] / minSum : total / n;
        return sizes;
    }
    var remaining = total;
    for (var pass = 0; pass <= n; ++pass) {
        var wsum = 0, free = 0;
        for (i = 0; i < n; ++i)
            if (!fixed[i]) { wsum += Math.max(0, weights[i]); free += 1; }
        if (free === 0)
            break;
        for (i = 0; i < n; ++i)
            if (!fixed[i])
                sizes[i] = wsum > 0 ? remaining * Math.max(0, weights[i]) / wsum : remaining / free;
        var clamped = false;
        for (i = 0; i < n; ++i)
            if (!fixed[i] && sizes[i] < mins[i]) {
                sizes[i] = mins[i]; fixed[i] = true; remaining -= mins[i]; clamped = true;
            }
        if (clamped)
            continue;
        for (i = 0; i < n; ++i)
            if (!fixed[i] && sizes[i] > maxs[i]) {
                sizes[i] = maxs[i]; fixed[i] = true; remaining -= maxs[i]; clamped = true;
            }
        if (!clamped)
            return sizes;
    }
    var used = 0, ws = 0;
    for (i = 0; i < n; ++i) { used += sizes[i]; ws += Math.max(0, weights[i]); }
    var extra = total - used;
    if (Math.abs(extra) > 0.001)
        for (i = 0; i < n; ++i)
            sizes[i] += extra * (ws > 0 ? Math.max(0, weights[i]) / ws : 1 / n);
    return sizes;
}

// Min/max extent of a subtree along one axis. A stack takes the strictest
// limits of its panels plus the tab bar height (vertically). A split sums its
// children along its own axis and intersects them across it.
//   opts: { constraints(panelId) -> { minimumWidth, minimumHeight,
//           maximumWidth, maximumHeight } | null, tabHeight, gap }
function limits(node, horizontal, opts, cache) {
    var key = node.id + (horizontal ? ":h" : ":v");
    if (cache && cache[key])
        return cache[key];
    var o = opts || {};
    var lo = 0, hi = Infinity;
    if (isStack(node)) {
        node.panels.forEach(function (pid) {
            var c = o.constraints ? o.constraints(pid) : null;
            if (!c)
                return;
            lo = Math.max(lo, horizontal ? c.minimumWidth : c.minimumHeight);
            hi = Math.min(hi, horizontal ? c.maximumWidth : c.maximumHeight);
        });
        if (!horizontal) {
            lo += o.tabHeight || 0;
            hi += o.tabHeight || 0;
        }
    } else {
        var along = (node.type === "row") === horizontal;
        if (along) {
            lo = (o.gap || 0) * (node.children.length - 1);
            hi = lo;
        }
        node.children.forEach(function (c) {
            var l = limits(c, horizontal, o, cache);
            if (along) {
                lo += l.min;
                hi += l.max;
            } else {
                lo = Math.max(lo, l.min);
                hi = Math.min(hi, l.max);
            }
        });
    }
    var r = { min: lo, max: Math.max(hi, lo) };
    if (cache)
        cache[key] = r;
    return r;
}

function minimumSize(root, opts) {
    if (!root)
        return { width: 0, height: 0 };
    return { width: limits(root, true, opts, {}).min, height: limits(root, false, opts, {}).min };
}

// Lays the tree out in a width x height rectangle.
//   opts: { gap, tabHeight, constraints, maximized: stackId }
// Returns { rects: { nodeId: rect }, handles: { "splitId:i": handle },
//           stackIds: [...] } where a handle is the gap between children i
// and i + 1: { x, y, width, height, horizontal, splitId, index }.
function computeLayout(root, width, height, opts) {
    var o = opts || {};
    var out = { rects: {}, handles: {}, stackIds: [] };
    if (!root)
        return out;
    var w = Math.max(0, width), h = Math.max(0, height);
    if (o.maximized) {
        var m = findStack(root, o.maximized);
        if (m) {
            out.rects[m.id] = { x: 0, y: 0, width: w, height: h };
            out.stackIds.push(m.id);
            return out;
        }
    }
    _layoutNode(root, 0, 0, w, h, o, out, {});
    return out;
}

function _layoutNode(node, x, y, w, h, opts, out, cache) {
    out.rects[node.id] = { x: x, y: y, width: w, height: h };
    if (isStack(node)) {
        out.stackIds.push(node.id);
        return;
    }
    var horizontal = node.type === "row";
    var gap = opts.gap || 0, n = node.children.length;
    var weights = [], mins = [], maxs = [];
    node.children.forEach(function (c) {
        var l = limits(c, horizontal, opts, cache);
        weights.push(c.size);
        mins.push(l.min);
        maxs.push(l.max);
    });
    var sizes = distribute(weights, mins, maxs, Math.max(0, (horizontal ? w : h) - gap * (n - 1)));
    var origin = horizontal ? x : y, acc = 0;
    for (var i = 0; i < n; ++i) {
        var start = Math.round(origin + acc);
        acc += sizes[i];
        var end = Math.round(origin + acc);
        if (horizontal)
            _layoutNode(node.children[i], start, y, end - start, h, opts, out, cache);
        else
            _layoutNode(node.children[i], x, start, w, end - start, opts, out, cache);
        if (i + 1 < n) {
            var g = Math.round(origin + acc + gap) - end;
            out.handles[node.id + ":" + i] = horizontal
                ? { x: end, y: y, width: g, height: h, horizontal: true, splitId: node.id, index: i }
                : { x: x, y: end, width: w, height: g, horizontal: false, splitId: node.id, index: i };
            acc += gap;
        }
    }
}

// Snapshot taken when a split handle is grabbed; feed it to applyResize.
function beginResize(root, layout, splitId, index, opts) {
    var split = findNode(root, splitId);
    if (!isSplit(split) || index + 1 >= split.children.length)
        return null;
    var horizontal = split.type === "row";
    var a = split.children[index], b = split.children[index + 1];
    var ra = layout.rects[a.id], rb = layout.rects[b.id];
    if (!ra || !rb)
        return null;
    var la = limits(a, horizontal, opts, {}), lb = limits(b, horizontal, opts, {});
    return {
        split: split, index: index,
        a: horizontal ? ra.width : ra.height,
        b: horizontal ? rb.width : rb.height,
        wa: a.size, wb: b.size,
        minA: la.min, maxA: la.max, minB: lb.min, maxB: lb.max
    };
}

// Moves the boundary by `delta` pixels from where it was grabbed, changing
// only the two adjacent children and respecting both of their limits.
function applyResize(state, delta) {
    if (!state)
        return;
    var total = state.a + state.b;
    if (total <= 0)
        return;
    var lower = Math.max(state.minA, total - state.maxB);
    var upper = Math.min(state.maxA, total - state.minB);
    var a = lower <= upper ? Math.min(upper, Math.max(lower, state.a + delta)) : state.a;
    var w = state.wa + state.wb;
    state.split.children[state.index].size = w * a / total;
    state.split.children[state.index + 1].size = w - w * a / total;
}

// ---------------------------------------------------------------------------
//  Drop hit-testing

function _inside(r, x, y) {
    return !!r && x >= r.x && y >= r.y && x < r.x + r.width && y < r.y + r.height;
}

// The four "dock at the full edge" indicator squares of an area.
function edgeIndicators(width, height, size, inset) {
    return {
        left: { x: inset, y: (height - size) / 2, width: size, height: size },
        right: { x: width - inset - size, y: (height - size) / 2, width: size, height: size },
        top: { x: (width - size) / 2, y: inset, width: size, height: size },
        bottom: { x: (width - size) / 2, y: height - inset - size, width: size, height: size }
    };
}

function sideRect(r, side, fraction) {
    switch (side) {
    case "left": return { x: r.x, y: r.y, width: r.width * fraction, height: r.height };
    case "right": return { x: r.x + r.width * (1 - fraction), y: r.y, width: r.width * fraction, height: r.height };
    case "top": return { x: r.x, y: r.y, width: r.width, height: r.height * fraction };
    default: return { x: r.x, y: r.y + r.height * (1 - fraction), width: r.width, height: r.height * fraction };
    }
}

// Resolves what a drop at (x, y) would do. Returns a target (see applyDrop)
// with a `rect` to preview, or null over a gap.
//   opts: { tabHeight, indicatorSize, indicatorInset, edgeFraction,
//           tabIndexAt(stackId, localX) -> insertion index }
function hitTest(root, layout, width, height, x, y, opts) {
    var o = opts || {};
    var whole = { x: 0, y: 0, width: width, height: height };
    if (!root)
        return { kind: "empty", rect: whole };
    var fraction = _clampFraction(o.edgeFraction, 0.25);
    var ind = edgeIndicators(width, height, o.indicatorSize || 36, o.indicatorInset || 8);
    var sides = ["left", "right", "top", "bottom"];
    for (var i = 0; i < sides.length; ++i)
        if (_inside(ind[sides[i]], x, y))
            return { kind: "edge", side: sides[i], fraction: fraction, rect: sideRect(whole, sides[i], fraction) };
    var tabH = o.tabHeight || 0;
    for (var k = 0; k < layout.stackIds.length; ++k) {
        var id = layout.stackIds[k], r = layout.rects[id];
        if (!_inside(r, x, y))
            continue;
        var lx = x - r.x, ly = y - r.y;
        if (ly < tabH)
            return { kind: "tab", stackId: id, inTabBar: true, rect: r,
                     index: o.tabIndexAt ? o.tabIndexAt(id, lx) : -1 };
        var ch = r.height - tabH;
        var fx = r.width > 0 ? lx / r.width : 0.5;
        var fy = ch > 0 ? (ly - tabH) / ch : 0.5;
        var d = { left: fx, right: 1 - fx, top: fy, bottom: 1 - fy };
        var best = "left";
        for (var s = 1; s < sides.length; ++s)
            if (d[sides[s]] < d[best])
                best = sides[s];
        if (d[best] < 0.25)
            return { kind: "split", stackId: id, side: best, rect: sideRect(r, best, 0.5) };
        return { kind: "tab", stackId: id, index: -1, inTabBar: false, rect: r };
    }
    return null;
}
