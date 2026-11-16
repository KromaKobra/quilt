.pragma library

// Quilt's glyphs: SVG path data on a 12 x 12 grid, drawn as 1.3 px strokes
// with round caps and joins. One shared table, so an Icon costs no more
// than its path.

const paths = {
    // window and panel chrome
    "close": "M 2.5 2.5 L 9.5 9.5 M 9.5 2.5 L 2.5 9.5",
    "minimize": "M 2 6 H 10",
    "maximize": "M 2.5 2.5 H 9.5 V 9.5 H 2.5 Z",
    "restore": "M 2 4.5 H 7.5 V 10 H 2 Z M 4.5 4.5 V 2 H 10 V 7.5 H 7.5",
    "popout": "M 5 2 H 2 V 10 H 10 V 7 M 7 2 H 10 V 5 M 10 2 L 5.5 6.5",
    "menu": "M 2 3.5 H 10 M 2 6 H 10 M 2 8.5 H 10",
    "more": "M 2.5 6 H 2.51 M 6 6 H 6.01 M 9.5 6 H 9.51",
    "grip": "M 4.2 2.8 H 4.21 M 7.8 2.8 H 7.81 M 4.2 6 H 4.21 M 7.8 6 H 7.81 M 4.2 9.2 H 4.21 M 7.8 9.2 H 7.81",

    // direction
    "chevron-down": "M 2.5 4.5 L 6 8 L 9.5 4.5",
    "chevron-up": "M 2.5 7.5 L 6 4 L 9.5 7.5",
    "chevron-right": "M 4.5 2.5 L 8 6 L 4.5 9.5",
    "chevron-left": "M 7.5 2.5 L 4 6 L 7.5 9.5",
    "arrow-up": "M 6 10 V 2 M 2.5 5.5 L 6 2 L 9.5 5.5",
    "arrow-down": "M 6 2 V 10 M 2.5 6.5 L 6 10 L 9.5 6.5",
    "arrow-left": "M 10 6 H 2 M 5.5 2.5 L 2 6 L 5.5 9.5",
    "arrow-right": "M 2 6 H 10 M 6.5 2.5 L 10 6 L 6.5 9.5",

    // marks
    "check": "M 2.5 6.3 L 5 8.8 L 9.5 3.4",
    "dash": "M 3 6 H 9",
    "plus": "M 6 2.5 V 9.5 M 2.5 6 H 9.5",
    "minus": "M 2.5 6 H 9.5",

    // editing
    "undo": "M 4.3 2.2 L 1.8 4.7 L 4.3 7.2 M 1.8 4.7 H 7.4 A 2.6 2.6 0 0 1 7.4 9.9 H 5",
    "redo": "M 7.7 2.2 L 10.2 4.7 L 7.7 7.2 M 10.2 4.7 H 4.6 A 2.6 2.6 0 0 0 4.6 9.9 H 7",
    "reset": "M 2.6 6.4 A 3.4 3.4 0 1 0 3.6 3.6 M 2.4 1.9 V 3.9 H 4.4",
    "copy": "M 4.5 4.5 H 10 V 10 H 4.5 Z M 2 7.5 V 2 H 7.5",
    "trash": "M 2.2 3.5 H 9.8 M 4.8 3.5 V 2.2 H 7.2 V 3.5 M 3.3 3.5 L 3.8 10 H 8.2 L 8.7 3.5 M 5.2 5.5 V 8 M 6.8 5.5 V 8",
    "link": "M 5 3.6 H 3.9 A 2.4 2.4 0 0 0 3.9 8.4 H 5 M 7 3.6 H 8.1 A 2.4 2.4 0 0 1 8.1 8.4 H 7 M 4.4 6 H 7.6",
    "unlink": "M 4.6 3.6 H 3.9 A 2.4 2.4 0 0 0 3.9 8.4 H 4.6 M 7.4 3.6 H 8.1 A 2.4 2.4 0 0 1 8.1 8.4 H 7.4",
    "search": "M 2 5.2 A 3.2 3.2 0 1 0 8.4 5.2 A 3.2 3.2 0 1 0 2 5.2 M 7.6 7.6 L 10 10",
    "filter": "M 1.8 2.6 H 10.2 L 7.1 6.4 V 9.9 L 4.9 8.9 V 6.4 Z",
    "settings": "M 2 3.6 H 10 M 2 8.4 H 10 M 4.2 2.3 V 4.9 M 7.8 7.1 V 9.7",

    // state
    "eye": "M 1.2 6 C 2.6 3.7 4.2 2.7 6 2.7 C 7.8 2.7 9.4 3.7 10.8 6 C 9.4 8.3 7.8 9.3 6 9.3 C 4.2 9.3 2.6 8.3 1.2 6 Z"
         + " M 4.6 6 A 1.4 1.4 0 1 0 7.4 6 A 1.4 1.4 0 1 0 4.6 6",
    "eye-off": "M 3.4 3.5 C 2.6 4.1 1.9 4.9 1.2 6 C 2.6 8.3 4.2 9.3 6 9.3 C 6.8 9.3 7.6 9.1 8.3 8.7"
             + " M 5.2 2.8 C 5.5 2.7 5.7 2.7 6 2.7 C 7.8 2.7 9.4 3.7 10.8 6 C 10.5 6.5 10.2 6.9 9.9 7.3 M 2.2 2 L 9.8 10",
    "lock": "M 2.8 5.5 H 9.2 V 10.2 H 2.8 Z M 4.2 5.5 V 4 A 1.8 1.8 0 0 1 7.8 4 V 5.5",
    "unlock": "M 2.8 5.5 H 9.2 V 10.2 H 2.8 Z M 4.2 5.5 V 4 A 1.8 1.8 0 0 1 7.6 3.1",
    "info": "M 1.5 6 A 4.5 4.5 0 1 0 10.5 6 A 4.5 4.5 0 1 0 1.5 6 M 6 5.6 V 8.4 M 6 3.7 H 6.01",
    "help": "M 1.5 6 A 4.5 4.5 0 1 0 10.5 6 A 4.5 4.5 0 1 0 1.5 6 M 4.7 4.8 A 1.35 1.35 0 1 1 6 6.2 V 6.9 M 6 8.6 H 6.01",
    "warning": "M 6 1.8 L 10.6 9.8 H 1.4 Z M 6 5 V 7.2 M 6 8.5 H 6.01",

    // things
    "play": "M 3.5 2.2 L 9.8 6 L 3.5 9.8 Z",
    "pause": "M 4 2.5 V 9.5 M 8 2.5 V 9.5",
    "stop": "M 3 3 H 9 V 9 H 3 Z",
    "calendar": "M 2 3.5 H 10 V 10 H 2 Z M 2 5.7 H 10 M 4.2 2 V 4 M 7.8 2 V 4",
    "folder": "M 1.8 3 H 5 L 6 4.2 H 10.2 V 9.6 H 1.8 Z",
    "file": "M 3 1.8 H 7 L 9.5 4.3 V 10.2 H 3 Z M 7 1.8 V 4.3 H 9.5",
    "grid": "M 2 2 H 10 V 10 H 2 Z M 6 2 V 10 M 2 6 H 10",
    "layers": "M 6 1.8 L 10.5 4.2 L 6 6.6 L 1.5 4.2 Z M 1.5 6.8 L 6 9.2 L 10.5 6.8"
};

// Glyphs made of dots need a heavier stroke to read at all.
const dotted = { "more": true, "grip": true };

function path(name) {
    return Object.prototype.hasOwnProperty.call(paths, name) ? paths[name] : "";
}

function names() {
    return Object.keys(paths);
}
