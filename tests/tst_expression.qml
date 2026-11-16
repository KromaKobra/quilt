import QtQuick
import QtTest
import Quilt.Controls

// The expression evaluator behind number fields and Quilt.Params. Pure
// functions: no window needed.
TestCase {
    name: "Expression"

    function value(text, options) {
        const r = Expression.evaluate(text, options);
        verify(r.ok, text + ": " + r.error);
        return r.value;
    }

    function error(text, options) {
        const r = Expression.evaluate(text, options);
        verify(!r.ok, text + " should fail, got " + r.value);
        return r.error;
    }

    function test_numbers() {
        compare(value("12"), 12);
        compare(value(".5"), 0.5);
        compare(value("1e3"), 1000);
        compare(value("1.5e-2"), 0.015);
        compare(value("-5"), -5);
        compare(value("  7  "), 7);
    }

    function test_arithmetic_and_precedence() {
        compare(value("2*3+1"), 7);
        compare(value("2+3*4"), 14);
        compare(value("(2+3)*4"), 20);
        compare(value("(120+48)/2"), 84);
        compare(value("7 % 4"), 3);
        compare(value("2^10"), 1024);
        compare(value("2**3"), 8);
        compare(value("2^3^2"), 512);           // right-associative
        compare(value("-2^2"), -4);             // as in maths, not (-2)^2
        compare(value("--3"), 3);
        compare(value("10 - 4 - 3"), 3);        // left-associative
    }

    function test_comparisons_and_logic() {
        compare(value("1 < 2"), 1);
        compare(value("2 <= 1"), 0);
        compare(value("3 == 3 && 2 != 3"), 1);
        compare(value("0 || 0"), 0);
        compare(value("!0"), 1);
        compare(value("1 > 0 ? 10 : 20"), 10);
        compare(value("0 ? 10 : 1 ? 20 : 30"), 20);
    }

    function test_functions_and_constants() {
        fuzzyCompare(value("2*pi"), 2 * Math.PI, 1e-12);
        fuzzyCompare(value("tau"), 2 * Math.PI, 1e-12);
        fuzzyCompare(value("sqrt(2)"), Math.SQRT2, 1e-12);
        compare(value("max(1, 2, 3) + min(4, 5)"), 7);
        compare(value("clamp(15, 0, 10)"), 10);
        compare(value("lerp(10, 20, 0.25)"), 12.5);
        compare(value("round(2.5) + floor(2.9) + ceil(2.1)"), 8);
        compare(value("abs(-3)"), 3);
        compare(value("mod(-1, 4)"), 3);
        fuzzyCompare(value("sin(rad(90))"), 1, 1e-12);
        fuzzyCompare(value("deg(pi)"), 180, 1e-9);
        compare(value("if(1, 5, 6)"), 5);
    }

    function test_units_and_implicit_multiplication() {
        compare(value("5cm", { units: { cm: 0.01 } }), 0.05);
        fuzzyCompare(value("2pi"), 2 * Math.PI, 1e-12);
        compare(value("3w", { resolve: n => n === "w" ? 4 : undefined }), 12);
        compare(error("5cm"), "Unknown unit: cm");
    }

    function test_names() {
        const vars = { w: 8, "cube.width": 100 };
        const resolve = n => vars[n];
        compare(value("w/2", { resolve: resolve }), 4);
        compare(value("cube.width + w", { resolve: resolve }), 108);
        compare(error("foo"), "Unknown name: foo");
        const parsed = Expression.parse("cube.width / 2 + w + w");
        verify(parsed.ok);
        compare(parsed.refs, ["cube.width", "w"]);
        compare(Expression.run(parsed.ast, { resolve: resolve }).value, 66);
    }

    function test_what_a_user_types() {
        compare(value("1,5"), 1.5);             // a lone decimal comma
        compare(value("+=10", { current: 5 }), 15);
        compare(value("-=5", { current: 5 }), 0);
        compare(value("*=2", { current: 5 }), 10);
        compare(value("/=2", { current: 5 }), 2.5);
        compare(error("+=10"), "There is no single value to change");
    }

    function test_errors() {
        compare(error(""), "Enter a number");
        compare(error("2 * (3"), "Missing ')'");
        compare(error("2 *"), "Incomplete expression");
        compare(error("2 $ 3"), "Unexpected '$'");
        compare(error("2 3"), "Unexpected '3'");
        compare(error("nope(1)"), "Unknown function: nope");
        compare(error("clamp(1)"), "clamp() takes 3 arguments");
        compare(error("1/0"), "Not a finite number");
        compare(error("sqrt(-1)"), "Not a number");
    }

    // User text is data. It must never reach the JavaScript engine.
    function test_text_is_never_executed() {
        verify(!Expression.evaluate("Qt.quit()").ok);
        verify(!Expression.evaluate("constructor").ok);
        verify(!Expression.evaluate("(function(){ return 1 })()").ok);
        verify(!Expression.evaluate("a = 1").ok);
        verify(!Expression.evaluate("[1][0]").ok);
        verify(!Expression.evaluate("\"x\"").ok);
        // Names that exist on every JS object are still just unknown names.
        compare(error("toString"), "Unknown name: toString");
        compare(error("hasOwnProperty(1)"), "Unknown function: hasOwnProperty");
        compare(error("constructor(1)"), "Unknown function: constructor");
        compare(error("5__proto__"), "Unknown unit: __proto__");
        compare(error("5constructor", { units: { cm: 0.01 } }), "Unknown unit: constructor");
    }

    function test_lists() {
        compare(Expression.list("1, 2, 3"), [1, 2, 3]);
        compare(Expression.list("1 2 3"), [1, 2, 3]);
        compare(Expression.list("1.5; -2; 1e2"), [1.5, -2, 100]);
        compare(Expression.list("1\t2\n3"), [1, 2, 3]);
        compare(Expression.list("1,5"), null);          // one number with a decimal comma
        compare(Expression.list("12"), null);
        compare(Expression.list("1, x"), null);
    }
}
