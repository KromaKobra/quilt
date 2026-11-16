pragma Singleton
import QtQml
import "Expr.js" as Expr

// Quilt's expression evaluator, for applications that want the same
// arithmetic the number fields accept. User text is parsed by Quilt's own
// parser and never reaches JavaScript's eval.
//
//     Expression.evaluate("2*pi").value                    // 6.283…
//     Expression.evaluate("w/2", { resolve: n => vars[n] })
//
// Syntax: + - * / % ^, comparisons, && || !, cond ? a : b, functions (min,
// max, clamp, abs, round, floor, ceil, sqrt, pow, sin, cos, tan, rad, deg,
// lerp, …), the constants pi, tau and e, names, and units (5cm, 90deg).
QtObject {
    // Evaluates what a user typed. options: { resolve(name), units, current }.
    // Returns { ok, value, error }.
    function evaluate(text: string, options: var): var {
        return Expr.compute(text, options);
    }

    // Parses once, to evaluate many times. Returns { ok, ast, refs, error },
    // where refs lists the names the expression reads.
    function parse(text: string): var {
        return Expr.parse(text);
    }

    // Evaluates a parsed expression. env: { resolve(name), units }.
    function run(ast: var, env: var): var {
        return Expr.evaluate(ast, env);
    }

    // "1, 2, 3" as [1, 2, 3], or null when the text is not a list of numbers.
    function list(text: string): var {
        return Expr.list(text);
    }
}
