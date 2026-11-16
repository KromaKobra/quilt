import QtQuick

// The value plumbing every value control shares.
//
// A control behaves like a stock one: it updates its own `value` when the
// user edits it, so a control nobody listens to still works. Unlike a stock
// one it never goes stale. After each edit it re-reads whatever `value` is
// bound to, so if the application clamped, rounded or refused the edit, the
// control shows what the application holds.
//
// It also runs the edit transaction (editStarted / edited / editFinished),
// and reads the parameter state from `owner.param` when one is set.
QtObject {
    id: edit

    required property var owner         // the control
    property string name: "value"       // the control's value property
    property var fallback: 0            // what `value` is when a parameter has none (a mixed selection)
    property bool live: true            // false: one `edited` at the end of a gesture, not one per change

    // ---- state: from the parameter object when there is one

    readonly property var param: owner.param ?? null
    readonly property int state: param && param.state !== undefined ? param.state : owner.paramState
    readonly property bool driven: state === Param.Driven
    readonly property bool mixed: state === Param.Mixed
    readonly property bool invalid: state === Param.Invalid
    readonly property string expression: String((param && param.expression !== undefined ? param.expression : owner.expression) ?? "")
    readonly property string message: String((param && param.message !== undefined ? param.message : owner.message) ?? "")
    readonly property bool readOnly: !!(param && param.readOnly !== undefined ? param.readOnly : owner.readOnly)
    readonly property var defaultValue: param && param.defaultValue !== undefined ? param.defaultValue : owner.defaultValue
    readonly property bool acceptsExpressions: param ? typeof param.setExpression === "function" : !!owner.acceptsExpressions
    readonly property bool modified: defaultValue !== undefined && defaultValue !== null && !mixed
                                     && !same(current, defaultValue)

    // The state in words, for assistive technology: "driven, modified, = width / 2".
    readonly property string stateText: {
        const parts = [];
        if (mixed)
            parts.push(qsTr("mixed"));
        else if (driven)
            parts.push(qsTr("driven"));
        else if (invalid)
            parts.push(qsTr("invalid"));
        if (modified)
            parts.push(qsTr("modified"));
        if (readOnly)
            parts.push(qsTr("read-only"));
        if (message !== "")
            parts.push(message);
        return parts.join(", ");
    }

    // ---- the value

    readonly property var current: owner[name]
    readonly property var shown: hasPreview ? preview : current    // what to draw
    readonly property bool active: _active                          // a transaction is open

    property bool hasPreview: false
    property var preview
    property var startValue

    property bool _active: false
    property var _target: null              // the parameter the open transaction edits
    property bool _ignoring: false          // the rest of an interrupted gesture changes nothing
    property bool _stepping: false
    property bool _changed: false
    property bool _pause: false

    // A JS array, or a list that came back from a property or a signal
    // (those are array-like, but Array.isArray() says no).
    function isList(v): bool {
        return v !== null && typeof v === "object" && typeof v.length === "number";
    }

    // `v` as a real JS array; [] when it isn't a list.
    function list(v): var {
        const out = [];
        for (let i = 0; isList(v) && i < v.length; ++i)
            out.push(v[i]);
        return out;
    }

    function same(a, b): bool {
        if (a === b)
            return true;
        if (typeof a === "number" && typeof b === "number")
            return Math.abs(a - b) <= 1e-9 * Math.max(1, Math.abs(a), Math.abs(b));
        if (a === undefined || a === null || b === undefined || b === null)
            return false;
        if (isList(a) || isList(b)) {
            if (!isList(a) || !isList(b) || a.length !== b.length)
                return false;
            for (let i = 0; i < a.length; ++i)
                if (!same(a[i], b[i]))
                    return false;
            return true;
        }
        if (a instanceof Date && b instanceof Date)
            return a.getTime() === b.getTime();
        return String(a) === String(b);         // colours, vectors and other value types
    }

    // An edit lands on the object it started on. If the parameter is
    // swapped while a transaction is open (the selection changed in the
    // middle of a drag), the edit is finished on the original one, and the
    // rest of that gesture changes nothing.
    onParamChanged: {
        if (!_active)
            return;
        end(true);
        _ignoring = true;
    }

    // Opens a transaction. Safe to call twice.
    function begin() {
        if (_active) {
            if (!_stepping)
                return;
            end(true);                          // a run of key or wheel steps ends when a gesture starts
        }
        _active = true;
        _ignoring = false;
        _changed = false;
        hasPreview = false;
        startValue = current;
        _target = param;
        if (_target && typeof _target.beginEdit === "function")
            _target.beginEdit();
        owner.editStarted();
    }

    // Changes the value inside a transaction.
    function set(v) {
        if (_ignoring)
            return;
        if (!_active)
            begin();
        if (live) {
            _commit(v);
        } else {
            preview = v;
            hasPreview = true;
        }
    }

    // Closes the transaction. `commit` false puts the starting value back.
    function end(commit) {
        if (!_active) {
            _ignoring = false;                  // the interrupted gesture is over
            return;
        }
        const ok = commit !== false;
        _idle.stop();
        _stepping = false;
        const pending = hasPreview;
        hasPreview = false;
        if (ok && pending)
            _commit(preview);
        else if (!ok && _changed)
            _commit(startValue);
        _active = false;
        const target = _target;
        _target = null;
        if (target && typeof target.endEdit === "function")
            target.endEdit(ok);
        owner.editFinished(ok);
    }

    // One complete edit: a click, a typed value, a menu choice.
    function instant(v) {
        begin();
        _commit(v);
        end(true);
    }

    // One step from a key or the wheel. A run of steps is a single
    // transaction, closed after a short pause.
    function step(v) {
        if (!(_active && _stepping)) {
            begin();
            _stepping = true;
        }
        _commit(v);
        _idle.restart();
    }

    // Closes a run of steps now (the control lost focus, say).
    function flush() {
        if (_active && _stepping)
            end(true);
    }

    function reset() {
        if (readOnly)
            return;
        if (param && typeof param.reset === "function") {
            begin();
            param.reset();
            _resync();
            end(true);
        } else if (defaultValue !== undefined && defaultValue !== null) {
            instant(defaultValue);
        }
    }

    // Hands an expression (without its leading "=") to the application, as
    // one edit. "" removes the expression.
    function setExpression(text) {
        begin();
        if (param && typeof param.setExpression === "function")
            param.setExpression(text);
        owner.expressionEdited(text);
        _resync();
        end(true);
    }

    // Shows `v` in the control without reporting an edit, until the next
    // edit or restore(): the text a mixed or driven field opens with.
    function show(v) {
        if (param)
            _pause = true;                      // stop following the parameter meanwhile
        _write(v);
    }

    // Back to what the application holds, without reporting an edit. `v` is
    // what a control that nothing is bound to goes back to.
    function restore(v) {
        if (!param)
            _write(v);
        _resync();
    }

    function _commit(v) {
        _changed = true;
        const target = _active ? _target : param;
        if (target) {
            if (typeof target.setValue === "function")
                target.setValue(v);
        } else {
            _write(v);
        }
        owner.edited(v);
        _resync();
    }

    // Puts `v` into the control's property. A binding the application put
    // on that property is set aside, not removed: _resync() brings it back.
    function _write(v) {
        if (_sync.when)
            _sync.when = false;
        _sync.value = v;
        _sync.when = true;
    }

    // Makes the property re-read its source. The application's binding is
    // put back and evaluated again, so the control shows the application's
    // value. A property nothing is bound to keeps what was written.
    function _resync() {
        _sync.when = false;
        if (param) {
            _pause = true;
            _pause = false;
        }
    }

    property Binding _sync: Binding {
        target: edit.owner
        property: edit.name
        when: false
        restoreMode: Binding.RestoreBinding
    }

    // With a parameter object, the control's value simply follows it.
    property Binding _follow: Binding {
        target: edit.owner
        property: edit.name
        value: {
            const v = edit.param ? edit.param.value : undefined;
            return v === undefined || v === null || (typeof v === "number" && isNaN(v)) ? edit.fallback : v;
        }
        when: edit.param !== null && !edit._pause
        restoreMode: Binding.RestoreBindingOrValue
    }

    property Timer _idle: Timer {
        interval: 600
        onTriggered: edit.end(true)
    }
}
