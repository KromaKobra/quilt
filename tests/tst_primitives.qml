pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quilt.Controls

// The hosts controls draw through (Face, Surface, FocusRing, …): Quilt's
// own colours, and what a theme's painters get from them.
Item {
    id: root
    width: 400
    height: 300

    // A theme whose painters only record what they were given.
    ThemeSpec {
        id: painted
        name: "Painted"
        skins.field: Component { Swatch { } }
        skins.button: Component { Swatch { } }
        skins.panel: Component { Swatch { } }
        skins.check: Component { Swatch { } }
        skins.focusRing: Component { Swatch { } }

        component Swatch: Rectangle {
            readonly property Item host: parent
            readonly property Face face: parent as Face
            objectName: "painter"
            // A shadow, as far out as a painter may draw.
            Rectangle { x: -Theme.paintOverflow; y: -Theme.paintOverflow; width: 4; height: 4 }
            color: face ? face.fill : "gray"
        }
    }

    Component { id: faceComponent; Face { width: 80; height: 24 } }
    Component { id: buttonComponent; Button { text: "Apply" } }
    Component { id: checkComponent; CheckBox { text: "On" } }
    Component { id: fieldComponent; TextField { width: 120; text: "abc" } }
    Component { id: numberComponent; NumberField { width: 120; value: 5; from: 0; to: 10 } }

    function painterOf(host) {
        for (const c of host.children)
            if (c.objectName === "painter")
                return c;
        return null;
    }

    TestCase {
        name: "Primitives"
        when: windowShown

        function cleanup() {
            Theme.spec = Theme.quilt;
            Theme.dark = true;
        }

        function test_face_draws_what_the_controls_drew() {
            const f = createTemporaryObject(faceComponent, root);
            f.role = Face.Field;
            compare(f.color, Theme.control);
            f.hovered = true;
            compare(f.fill, Theme.controlHover);
            f.flat = true;
            compare(f.fill, Qt.color("transparent"));
            compare(f.border.width, 0);

            f.flat = false;
            f.hovered = false;
            f.role = Face.Button;
            compare(f.fill, Theme.control);
            f.pressed = true;
            compare(f.fill, Theme.controlFill);
            compare(f.border.width, 1);

            f.role = Face.Primary;
            f.pressed = false;
            compare(f.fill, Theme.accent);
            compare(f.border.width, 0);
            compare(f.ink(), Theme.accentInk);

            f.role = Face.Tool;
            compare(f.fill, Qt.color("transparent"));
            f.hovered = true;
            compare(f.fill, Theme.controlHover);
            f.danger = true;
            compare(f.fill, Theme.danger);
            compare(f.ink(), Theme.dangerInk);

            f.danger = false;
            f.role = Face.Item;
            compare(f.fill, Theme.controlFill);
            f.checked = true;
            compare(f.fill, Theme.accent);
            f.checked = false;
            f.marked = true;
            compare(f.border.width, 1);
            compare(f.border.color, Theme.textTertiary);

            f.role = Face.Segment;
            f.checked = true;
            compare(f.fill, Theme.controlFill);
            compare(f.radius, Theme.innerRadius);
        }

        function test_rings_and_flash_are_made_when_needed() {
            const f = createTemporaryObject(fieldComponent, root);
            const frame = f.background as Face;
            compare(frame._ring, null);
            compare(frame._flash, null);
            f.forceActiveFocus();
            verify(frame._ring);
            verify(frame._ring.visible);
            compare(frame._ring.border.color, Theme.focus);
            f.focus = false;
            verify(!frame._ring.visible);
            frame.flash();
            verify(frame._flash);
        }

        function test_no_painters_in_quilts_own_look() {
            const b = createTemporaryObject(buttonComponent, root);
            compare((b.background as Face)._painted, null);
            compare(Theme.skins.field, null);
        }

        function test_a_theme_paints_through_the_hosts() {
            const b = createTemporaryObject(buttonComponent, root);
            const n = createTemporaryObject(numberComponent, root, { y: 40 });
            const c = createTemporaryObject(checkComponent, root, { y: 80 });
            const size = Qt.size(b.implicitWidth, b.implicitHeight);
            const bg = b.background as Face;

            Theme.spec = painted;
            const p = root.painterOf(bg);
            verify(p);
            compare(p.face, bg);                    // the painter reaches its host…
            verify(!p.enabled);                     // …but never its input
            compare(p.width, bg.width);
            compare(p.height, bg.height);
            compare(p.color, bg.fill);
            compare(bg.color, Qt.color("transparent"));     // the host steps aside
            compare(Qt.size(b.implicitWidth, b.implicitHeight), size);    // and keeps its size

            // It may draw outside, but no further than paintOverflow.
            const r = p.childrenRect;
            verify(r.x >= -Theme.paintOverflow && r.y >= -Theme.paintOverflow);

            verify(root.painterOf(n.background));
            verify(root.painterOf(c.indicator));

            // Pressed and hovered states reach the painter.
            mousePress(b);
            compare(p.color, bg.fill);
            compare(bg.fill, Theme.controlFill);
            mouseRelease(b);

            // A ring's painter waits until the ring is first shown.
            n.forceActiveFocus();
            const ring = (n.background as Face)._ring;
            verify(ring);
            verify(root.painterOf(ring));

            // Back to Quilt's look: the painters go.
            Theme.spec = Theme.quilt;
            compare(bg._painted, null);
            tryVerify(() => root.painterOf(bg) === null);       // (destroyed a moment later)
            compare(bg.color, Theme.control);
        }

        function test_painter_follows_the_theme_mode() {
            const b = createTemporaryObject(buttonComponent, root);
            Theme.spec = painted;
            const p = root.painterOf(b.background);
            const dark = String(p.color);
            Theme.dark = false;
            verify(String(p.color) !== dark);
        }
    }
}
