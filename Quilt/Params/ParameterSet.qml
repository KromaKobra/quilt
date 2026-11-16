pragma ComponentBehavior: Bound
import QtQuick
import Quilt.Controls

// A set of Parameters that can refer to each other. It is a small reference
// engine for applications that have none of their own: it resolves names,
// re-evaluates what depends on a value when that value changes, and refuses
// circular references.
//
//     ParameterSet {
//         id: params
//         Parameter { name: "cube.width"; value: 100 }
//         Parameter { name: "cube.height"; expression: "width / 2" }     // "width" is cube.width
//         Parameter { name: "ball.size"; expression: "cube.width + cube.height" }
//     }
//
//     Inspector { model: params.list("cube.") }
//
// Names may contain dots. Inside an expression a bare name is looked up
// next to the parameter first (cube.height sees cube.width as "width").
// A component of a vector or colour can be read as cube.position.x.
//
// It evaluates on the UI thread when something changes. It is meant for
// interactive editing of hundreds or a few thousand values, not for
// evaluating animation channels every frame.
QtObject {
    id: parameterSet

    default property list<Parameter> parameters
    readonly property int count: _all.length

    // An edit through a control began / ended: hook your undo stack here.
    signal editStarted(var parameter)
    signal editFinished(var parameter, bool committed)
    // A parameter's value changed, for any reason.
    signal changed(var parameter)

    // The parameter called `name`, or null. A binding that calls this is
    // re-evaluated when parameters are added or removed.
    function find(name: string): var {
        return count >= 0 ? (_byName[name] ?? null) : null;
    }

    // The parameters whose name starts with `prefix`, in order: an
    // Inspector model for one object.
    function list(prefix: string): var {
        return _all.filter(p => p.name.indexOf(prefix) === 0);
    }

    // Adds a parameter created at runtime. Returns false if the name is taken.
    function add(p: Parameter): bool {
        if (!_register(p))
            return false;
        _all = _all.concat([p]);
        _expressionChanged(p);                  // evaluates it, and whatever was waiting for its name
        return true;
    }

    function remove(p: Parameter) {
        if (!p || _byName[p.name] !== p)
            return;
        const readers = (_index()[p.name] || []).slice();
        delete _byName[p.name];
        delete _parsed[p.name];
        _readers = null;
        _all = _all.filter(x => x !== p);
        p.parameterSet = null;
        _propagate(readers, true);              // they now name something that isn't there
    }

    // Every value and expression, as plain data: for saving, and for undo.
    function save(): var {
        const out = {};
        for (const p of _all)
            out[p.name] = p.expression !== "" ? { expression: p.expression } : { value: _plain(p.value) };
        return out;
    }

    function restore(state: var) {
        if (!state)
            return;
        _restoring = true;
        for (const p of _all) {
            const s = state[p.name];
            if (!s)
                continue;
            p._settingValue = true;
            p.expression = s.expression ?? "";
            if (s.value !== undefined)
                p.value = _revive(s.value, p.value);
            p._error = "";
            p._settingValue = false;
        }
        _restoring = false;
        _evaluateAll();
        for (const p of _all)
            changed(p);
    }

    // ---- internals

    property var _all: []                       // every parameter, in order
    property var _byName: Object.create(null)   // name -> Parameter. (No prototype: "toString" is not a parameter.)
    property var _parsed: Object.create(null)   // name -> { ast, refs, error, cyclic, hits } for driven parameters
    property var _readers: null                 // name -> [Parameter]: who reads each one. null: needs rebuilding
    property bool _restoring: false

    Component.onCompleted: {
        const list = [];
        for (let i = 0; i < parameters.length; ++i)
            if (_register(parameters[i]))
                list.push(parameters[i]);
        _all = list;
        _evaluateAll();
    }

    function _register(p: Parameter): bool {
        if (!p || p.name === "" || _byName[p.name]) {
            console.warn("Quilt: a Parameter needs a unique name:", p ? p.name : p);
            return false;
        }
        p.parameterSet = parameterSet;
        _byName[p.name] = p;
        _readers = null;
        return true;
    }

    function _plain(v): var {
        if (v instanceof Date)
            return { date: v.getTime() };
        if (v !== null && typeof v === "object" && typeof v.length !== "number")
            return { text: String(v), parts: _parts(v) };       // a colour or vector
        return v;
    }

    function _parts(v): var {
        const out = {};
        for (const k of ["x", "y", "z", "w", "width", "height", "r", "g", "b", "a"])
            if (typeof v[k] === "number")
                out[k] = v[k];
        return out;
    }

    function _revive(saved, like): var {
        if (saved !== null && typeof saved === "object" && saved.date !== undefined)
            return new Date(saved.date);
        if (saved !== null && typeof saved === "object" && saved.parts !== undefined) {
            const q = saved.parts;
            if (q.r !== undefined)
                return Qt.rgba(q.r, q.g, q.b, q.a);
            if (q.width !== undefined)
                return q.x !== undefined ? Qt.rect(q.x, q.y, q.width, q.height) : Qt.size(q.width, q.height);
            if (q.w !== undefined)
                return Qt.vector4d(q.x, q.y, q.z, q.w);
            if (q.z !== undefined)
                return Qt.vector3d(q.x, q.y, q.z);
            return String(like).indexOf("QPoint") === 0 ? Qt.point(q.x, q.y) : Qt.vector2d(q.x, q.y);
        }
        return saved;
    }

    // The parameter a name in `owner`'s expression refers to, plus the
    // property path left over ("cube.position.x" -> cube.position, ["x"]).
    function _lookup(owner: Parameter, ref: string): var {
        const dot = owner.name.lastIndexOf(".");
        const candidates = dot >= 0 ? [owner.name.slice(0, dot + 1) + ref, ref] : [ref];
        for (const full of candidates) {
            const parts = full.split(".");
            for (let n = parts.length; n >= 1; --n) {
                const p = _byName[parts.slice(0, n).join(".")];
                if (p)
                    return { parameter: p, path: parts.slice(n) };
            }
        }
        return null;
    }

    function _parse(p: Parameter) {
        _readers = null;
        if (p.expression === "") {
            delete _parsed[p.name];
            return;
        }
        const r = Expression.parse(p.expression);
        _parsed[p.name] = r.ok ? { ast: r.ast, refs: r.refs } : { ast: null, refs: [], error: r.error };
    }

    // Resolves every name in every expression, once, and notes who reads
    // whom. Rebuilt only after an expression or the set of parameters changed.
    function _index(): var {
        if (_readers)
            return _readers;
        const index = Object.create(null);
        for (const key in _parsed) {
            const owner = _byName[key], entry = _parsed[key];
            entry.hits = Object.create(null);
            for (const ref of entry.refs) {
                const hit = _lookup(owner, ref);
                if (!hit)
                    continue;
                entry.hits[ref] = hit;
                const readers = index[hit.parameter.name] || (index[hit.parameter.name] = []);
                if (readers.indexOf(owner) < 0)
                    readers.push(owner);
            }
        }
        return _readers = index;
    }

    // The number a name stands for in `owner`'s expression, or undefined.
    function _number(owner: Parameter, ref: string): var {
        const hit = _parsed[owner.name].hits[ref];
        if (!hit)
            return undefined;
        let v = hit.parameter.value;
        for (const key of hit.path) {
            if (v === null || v === undefined || v[key] === undefined)
                return undefined;
            v = v[key];
        }
        return typeof v === "boolean" ? (v ? 1 : 0) : typeof v === "number" ? v : undefined;
    }

    // Whether `p`'s expression leads back to `p` itself.
    function _cyclic(p: Parameter): bool {
        _index();
        const seen = Object.create(null);
        const walk = q => {
            const entry = _parsed[q.name];
            if (!entry)
                return false;
            for (const ref in entry.hits) {
                const source = entry.hits[ref].parameter;
                if (source === p)
                    return true;
                if (!seen[source.name]) {
                    seen[source.name] = true;
                    if (walk(source))
                        return true;
                }
            }
            return false;
        };
        return walk(p);
    }

    function _evaluate(p: Parameter) {
        const entry = _parsed[p.name];
        if (!entry)
            return;
        if (entry.error || entry.cyclic) {
            p._error = entry.error || qsTr("Circular reference");
            return;                             // keeps its last good value
        }
        const r = Expression.run(entry.ast, { resolve: ref => _number(p, ref) });
        if (!r.ok) {
            p._error = r.error;
            return;
        }
        p._error = "";
        const v = p._coerce(r.value);
        if (v !== p.value) {
            p._evaluating = true;
            p.value = v;
            p._evaluating = false;
            changed(p);
        }
    }

    // Re-evaluates what reads `sources`, and what reads that in turn: each
    // parameter once, and never before the ones it reads. `inclusive` also
    // evaluates the sources themselves.
    function _propagate(sources, inclusive: bool) {
        const index = _index();
        const seen = Object.create(null), order = [];
        const visit = p => {
            if (seen[p.name])
                return;
            seen[p.name] = true;
            (index[p.name] || []).forEach(visit);
            order.push(p);                      // after everything that reads it…
        };
        sources.forEach(visit);
        for (let i = order.length - 1; i >= 0; --i)     // …so backwards is sources first
            if (inclusive || sources.indexOf(order[i]) < 0)
                _evaluate(order[i]);
    }

    function _evaluateAll() {
        for (const p of _all)
            _parse(p);
        for (const key in _parsed)
            _parsed[key].cyclic = _cyclic(_byName[key]);
        _propagate(_all, true);
    }

    // Parameters that failed get another go: the name they wanted may exist
    // now, or the cycle they closed may be open.
    function _retryInvalid(except) {
        for (const p of _all) {
            if (p === except || p._error === "" || !_parsed[p.name])
                continue;
            _parsed[p.name].cyclic = _cyclic(p);
            _propagate([p], true);
        }
    }

    function _valueChanged(p: Parameter) {
        if (_restoring)
            return;
        changed(p);
        _propagate([p], false);
    }

    function _expressionChanged(p: Parameter) {
        if (_restoring || _byName[p.name] !== p)
            return;
        _parse(p);
        if (p.expression === "")
            p._error = "";
        else
            _parsed[p.name].cyclic = _cyclic(p);
        _propagate([p], true);
        _retryInvalid(p);
    }
}
