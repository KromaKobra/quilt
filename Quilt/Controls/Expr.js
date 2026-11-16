.pragma library

// A small, safe expression language for number fields and for linking
// parameters. It has its own parser: nothing a user types is ever handed to
// JavaScript's eval or Function.
//
//   numbers      12  .5  1e-3
//   operators    + - * / % ^   < <= > >= == !=   && || !   cond ? a : b
//   functions    see FUNCTIONS below
//   constants    pi  tau  e  true  false
//   names        width, cube.width: resolved by the caller
//   units        5cm, 90deg: a number directly followed by a name multiplies
//                by that unit, constant or name (so 2pi works too)

const CONSTANTS = { pi: Math.PI, tau: 2 * Math.PI, e: Math.E, "true": 1, "false": 0 };

const FUNCTIONS = {
    abs: [1, Math.abs], sign: [1, Math.sign], sqrt: [1, Math.sqrt],
    round: [1, Math.round], floor: [1, Math.floor], ceil: [1, Math.ceil], trunc: [1, Math.trunc],
    exp: [1, Math.exp], ln: [1, Math.log], log: [1, Math.log10], log2: [1, Math.log2],
    sin: [1, Math.sin], cos: [1, Math.cos], tan: [1, Math.tan],
    asin: [1, Math.asin], acos: [1, Math.acos], atan: [1, Math.atan], atan2: [2, Math.atan2],
    rad: [1, d => d * Math.PI / 180], deg: [1, r => r * 180 / Math.PI],
    pow: [2, Math.pow], mod: [2, (a, b) => a - b * Math.floor(a / b)],
    min: [-1, Math.min], max: [-1, Math.max],
    clamp: [3, (x, lo, hi) => Math.min(hi, Math.max(lo, x))],
    lerp: [3, (a, b, t) => a + (b - a) * t],
    step: [2, (edge, x) => x < edge ? 0 : 1],
    smoothstep: [3, (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); }],
    "if": [3, (c, a, b) => c ? a : b]
};

function fail(message) {
    throw { expr: true, message: message };
}

// table[key], but only the table's own entries: a name such as "toString"
// or "constructor" must not find what every JavaScript object inherits.
function own(table, key) {
    return table && Object.prototype.hasOwnProperty.call(table, key) ? table[key] : undefined;
}

// ---- tokens: { t: "num" | "id" | "unit" | "op" | "end", v }

function tokenize(text) {
    const out = [];
    let i = 0;
    const n = text.length;
    const isDigit = c => c >= "0" && c <= "9";
    const isAlpha = c => (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c === "_";
    const readName = () => {
        const start = i;
        while (i < n && (isAlpha(text[i]) || isDigit(text[i])
                         || (text[i] === "." && i + 1 < n && isAlpha(text[i + 1]))))
            ++i;
        return text.slice(start, i);
    };
    while (i < n) {
        const c = text[i];
        if (c === " " || c === "\t" || c === "\n") {
            ++i;
        } else if (isDigit(c) || (c === "." && i + 1 < n && isDigit(text[i + 1]))) {
            const start = i;
            while (i < n && isDigit(text[i])) ++i;
            if (text[i] === ".") { ++i; while (i < n && isDigit(text[i])) ++i; }
            if ((text[i] === "e" || text[i] === "E")
                    && (isDigit(text[i + 1]) || ((text[i + 1] === "+" || text[i + 1] === "-") && isDigit(text[i + 2])))) {
                i += 2;
                while (i < n && isDigit(text[i])) ++i;
            }
            out.push({ t: "num", v: parseFloat(text.slice(start, i)) });
            if (i < n && isAlpha(text[i]))
                out.push({ t: "unit", v: readName() });
        } else if (isAlpha(c)) {
            out.push({ t: "id", v: readName() });
        } else {
            const two = text.slice(i, i + 2);
            if (["<=", ">=", "==", "!=", "&&", "||", "**"].indexOf(two) >= 0) {
                out.push({ t: "op", v: two === "**" ? "^" : two });
                i += 2;
            } else if ("+-*/%^()<>!?:,".indexOf(c) >= 0) {
                out.push({ t: "op", v: c });
                ++i;
            } else {
                fail("Unexpected '" + c + "'");
            }
        }
    }
    out.push({ t: "end" });
    return out;
}

// ---- parser: precedence climbing, producing nested arrays

const BINARY = {
    "||": 1, "&&": 2, "==": 3, "!=": 3, "<": 4, "<=": 4, ">": 4, ">=": 4,
    "+": 5, "-": 5, "*": 6, "/": 6, "%": 6
};

function parseTokens(tokens, refs) {
    let pos = 0;
    const peek = () => tokens[pos];
    const isOp = v => peek().t === "op" && peek().v === v;
    const expect = v => {
        if (!isOp(v))
            fail(peek().t === "end" ? "Missing '" + v + "'" : "Expected '" + v + "'");
        ++pos;
    };

    function primary() {
        const tok = peek();
        if (tok.t === "num") {
            ++pos;
            let node = ["num", tok.v];
            if (peek().t === "unit") {
                node = ["unit", node, peek().v];
                ++pos;
            }
            return node;
        }
        if (tok.t === "id") {
            ++pos;
            if (isOp("(")) {
                ++pos;
                const args = [];
                if (!isOp(")")) {
                    do {
                        args.push(ternary());
                    } while (isOp(",") && ++pos);
                }
                expect(")");
                const fn = own(FUNCTIONS, tok.v);
                if (!fn)
                    fail("Unknown function: " + tok.v);
                if (fn[0] >= 0 ? args.length !== fn[0] : args.length === 0)
                    fail(tok.v + "() takes " + (fn[0] >= 0 ? fn[0] : "at least 1") + " argument" + (fn[0] === 1 ? "" : "s"));
                return ["call", tok.v, args];
            }
            if (own(CONSTANTS, tok.v) !== undefined)
                return ["num", CONSTANTS[tok.v]];
            if (refs.indexOf(tok.v) < 0)
                refs.push(tok.v);
            return ["ref", tok.v];
        }
        if (isOp("(")) {
            ++pos;
            const inner = ternary();
            expect(")");
            return inner;
        }
        if (tok.t === "end")
            fail("Incomplete expression");
        fail("Unexpected '" + tok.v + "'");
    }

    function power() {
        const base = primary();
        if (isOp("^")) {
            ++pos;
            return ["bin", "^", base, unary()];     // right-associative; -2^2 is -(2^2)
        }
        return base;
    }

    function unary() {
        if (isOp("-") || isOp("+") || isOp("!")) {
            const op = peek().v;
            ++pos;
            return ["un", op, unary()];
        }
        return power();
    }

    function binary(minPrec) {
        let left = unary();
        for (;;) {
            const tok = peek();
            const prec = tok.t === "op" ? BINARY[tok.v] : undefined;
            if (prec === undefined || prec < minPrec)
                return left;
            ++pos;
            left = ["bin", tok.v, left, binary(prec + 1)];
        }
    }

    function ternary() {
        const cond = binary(1);
        if (!isOp("?"))
            return cond;
        ++pos;
        const a = ternary();
        expect(":");
        return ["cond", cond, a, ternary()];
    }

    const ast = ternary();
    if (peek().t !== "end")
        fail(peek().t === "op" ? "Unexpected '" + peek().v + "'" : "Unexpected '" + String(peek().v) + "'");
    return ast;
}

// Parses `text`. Returns { ok, ast, refs, error }; refs are the names the
// expression reads.
function parse(text) {
    const refs = [];
    try {
        return { ok: true, ast: parseTokens(tokenize(String(text)), refs), refs: refs, error: "" };
    } catch (e) {
        if (e && e.expr)
            return { ok: false, ast: null, refs: refs, error: e.message };
        throw e;
    }
}

// ---- evaluation

function run(node, env) {
    switch (node[0]) {
    case "num":
        return node[1];
    case "ref": {
        const v = env.resolve ? env.resolve(node[1]) : undefined;
        if (v === undefined || v === null)
            fail("Unknown name: " + node[1]);
        return Number(v);
    }
    case "unit": {
        const name = node[2];
        let f = own(env.units, name);
        if (f === undefined)
            f = own(CONSTANTS, name);
        if (f === undefined && env.resolve)
            f = env.resolve(name);
        if (f === undefined || f === null)
            fail("Unknown unit: " + name);
        return run(node[1], env) * Number(f);
    }
    case "un": {
        const a = run(node[2], env);
        return node[1] === "-" ? -a : node[1] === "!" ? (a ? 0 : 1) : a;
    }
    case "bin": {
        const op = node[1];
        if (op === "&&")
            return run(node[2], env) && run(node[3], env) ? 1 : 0;
        if (op === "||")
            return run(node[2], env) || run(node[3], env) ? 1 : 0;
        const a = run(node[2], env), b = run(node[3], env);
        switch (op) {
        case "+": return a + b;
        case "-": return a - b;
        case "*": return a * b;
        case "/": return a / b;
        case "%": return a % b;
        case "^": return Math.pow(a, b);
        case "<": return a < b ? 1 : 0;
        case "<=": return a <= b ? 1 : 0;
        case ">": return a > b ? 1 : 0;
        case ">=": return a >= b ? 1 : 0;
        case "==": return a === b ? 1 : 0;
        default: return a !== b ? 1 : 0;       // !=
        }
    }
    case "call":
        return FUNCTIONS[node[1]][1].apply(null, node[2].map(a => run(a, env)));
    default:                                    // cond
        return run(node[1], env) ? run(node[2], env) : run(node[3], env);
    }
}

// Evaluates a parsed expression. `env` is { resolve(name), units }.
// Returns { ok, value, error }.
function evaluate(ast, env) {
    try {
        const v = run(ast, env || {});
        if (typeof v !== "number" || !isFinite(v))
            return { ok: false, value: NaN, error: isNaN(v) ? "Not a number" : "Not a finite number" };
        return { ok: true, value: v, error: "" };
    } catch (e) {
        if (e && e.expr)
            return { ok: false, value: NaN, error: e.message };
        throw e;
    }
}

// What a number field does with typed text. On top of parse + evaluate:
//   "1,5"            a lone decimal comma is accepted
//   "+=10" "*=2"     applies to options.current
// options: { resolve, units, current }. Returns { ok, value, error }.
function compute(text, options) {
    const opts = options || {};
    let t = String(text).trim();
    if (t === "")
        return { ok: false, value: NaN, error: "Enter a number" };
    if (/^[-+]?\d+,\d+$/.test(t))
        t = t.replace(",", ".");
    let relative = "";
    const m = /^([-+*\/])=(.*)$/.exec(t);
    if (m) {
        relative = m[1];
        t = m[2];
    }
    const parsed = parse(t);
    if (!parsed.ok)
        return { ok: false, value: NaN, error: parsed.error };
    const result = evaluate(parsed.ast, opts);
    if (!result.ok || relative === "")
        return result;
    const cur = Number(opts.current);
    if (!isFinite(cur))
        return { ok: false, value: NaN, error: "There is no single value to change" };
    const v = relative === "+" ? cur + result.value : relative === "-" ? cur - result.value
            : relative === "*" ? cur * result.value : cur / result.value;
    return isFinite(v) ? { ok: true, value: v, error: "" }
                       : { ok: false, value: NaN, error: "Not a finite number" };
}

// "1, 2, 3" or "1 2 3" as [1, 2, 3]; null unless the text is a list of two
// or more plain numbers.
function list(text) {
    const t = String(text).trim();
    if (!/[\s,;]/.test(t))
        return null;
    const parts = t.split(/\s*[,;]\s*|\s+/).filter(p => p !== "");
    if (parts.length < 2 || (parts.length === 2 && /^[-+]?\d+,\d+$/.test(t)))
        return null;                            // "1,5" is one number with a decimal comma
    const out = [];
    for (const p of parts) {
        if (!/^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/.test(p))
            return null;
        out.push(parseFloat(p));
    }
    return out;
}
