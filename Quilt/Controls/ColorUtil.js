.pragma library

// Colour text for ColorField: "4C8DFF", and back from anything reasonable.

function hex2(x) {
    const s = Math.round(Math.min(1, Math.max(0, x)) * 255).toString(16).toUpperCase();
    return s.length < 2 ? "0" + s : s;
}

// "RRGGBB", or "RRGGBBAA" when withAlpha and the colour is not opaque.
function toHex(c, withAlpha) {
    const rgb = hex2(c.r) + hex2(c.g) + hex2(c.b);
    return withAlpha && c.a < 0.999 ? rgb + hex2(c.a) : rgb;
}

// [r, g, b, a, hasAlpha] from "#fff", "fff", "#rrggbb", "rrggbbaa", "rgb(1, 2, 3)" or
// "rgba(1, 2, 3, 0.5)"; null when the text is none of those. The channels
// are 0..1; hasAlpha says whether the text gave an opacity.
function parse(text) {
    const t = String(text).trim().toLowerCase();
    let m = /^#?([0-9a-f]{3,8})$/.exec(t);
    if (m) {
        let h = m[1];
        if (h.length === 3 || h.length === 4)
            h = h.split("").map(ch => ch + ch).join("");
        if (h.length !== 6 && h.length !== 8)
            return null;
        const n = i => parseInt(h.substr(i, 2), 16) / 255;
        return [n(0), n(2), n(4), h.length === 8 ? n(6) : 1, h.length === 8];
    }
    m = /^rgba?\(\s*([\d.]+)\s*[,\s]\s*([\d.]+)\s*[,\s]\s*([\d.]+)\s*(?:[,\/]\s*([\d.]+%?)\s*)?\)$/.exec(t);
    if (m) {
        let a = 1;
        if (m[4] !== undefined)
            a = m[4].endsWith("%") ? parseFloat(m[4]) / 100 : parseFloat(m[4]);
        return [Math.min(1, m[1] / 255), Math.min(1, m[2] / 255), Math.min(1, m[3] / 255), Math.min(1, Math.max(0, a)),
                m[4] !== undefined];
    }
    return null;
}

// Whether two colours are the same to within one 8-bit step.
function near(a, b) {
    const e = 0.5 / 255;
    return Math.abs(a.r - b.r) <= e && Math.abs(a.g - b.g) <= e
        && Math.abs(a.b - b.b) <= e && Math.abs(a.a - b.a) <= e;
}
