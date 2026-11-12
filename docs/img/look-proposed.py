#!/usr/bin/env python3
"""Draws docs/img/look-proposed.svg, a static mock of the proposed look.

    python3 docs/img/look-proposed.py docs/img/look-proposed.svg

The token values match docs/visual-design.md. Change them there and here together."""
import sys

T = dict(canvas="#0e0f12", surface="#1a1c20", raised="#23262b", control="#272a30",
         controlHover="#2f3239", controlFill="#3a3e47", border="#2d3037",
         text="#e4e6ea", text2="#9ca1ab", text3="#787d87", accent="#4c8dff",
         driven="#a98bf5", error="#f0616d", ink="#0e0f12", viewport="#121316")
W, H = 1280, 760
GAP, R, TAB = 6, 8, 32
out = []


def rect(x, y, w, h, fill, r=0, extra=""):
    out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" {extra}/>')


def text(x, y, s, fill=T["text"], size=12, weight=400, anchor="start", extra=""):
    out.append(f'<text x="{x}" y="{y}" fill="{fill}" font-size="{size}" font-weight="{weight}" '
               f'text-anchor="{anchor}" {extra}>{s}</text>')


def path(d, stroke, width=1.3, fill="none", extra=""):
    out.append(f'<path d="{d}" stroke="{stroke}" stroke-width="{width}" fill="{fill}" '
               f'stroke-linecap="round" stroke-linejoin="round" {extra}/>')


def chevron_down(x, y, c=T["text2"]):
    path(f"M{x} {y} l3.5 3.5 l3.5 -3.5", c)


def chevron_right(x, y, c=T["text2"]):
    path(f"M{x} {y} l3.5 3.5 l-3.5 3.5", c)


def panel(x, y, w, h, tabs, active=False, buttons=False):
    """One tab group: a single surface, text-only tabs, a hairline under the strip."""
    rect(x, y, w, h, T["surface"], R)
    rect(x, y + TAB, w, 1, T["border"])
    tx = x + 12
    for i, name in enumerate(tabs):
        tw = round(len(name) * 6.9)
        if i == 0:
            text(tx, y + 21, name, T["text"], weight=500)
            rect(tx, y + TAB - 1, tw, 2, T["accent"] if active else T["text3"], 1)
        else:
            text(tx, y + 21, name, T["text2"])
        tx += tw + 20
    if buttons:                                 # shown only while the strip is hovered
        bx = x + w - 48
        path(f"M{bx+4} {y+11} h-3 v8 h8 v-3 M{bx+6} {y+11} h3 v3 M{bx+9} {y+11} l-4.5 4.5", T["text2"])
        path(f"M{bx+22} {y+11} h8 v8 h-8 z", T["text2"])


def bottom_rounded(x, y, w, h, fill):
    out.append(f'<path d="M{x} {y} h{w} v{h-R} a{R} {R} 0 0 1 -{R} {R} h-{w-2*R} '
               f'a{R} {R} 0 0 1 -{R} -{R} z" fill="{fill}"/>')


out.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
           f'font-family="Inter, \'Noto Sans\', \'Segoe UI\', system-ui, sans-serif">')
out.append('<title>Quilt: proposed look</title>')
rect(0, 0, W, H, T["canvas"])

# --- Outliner -------------------------------------------------------------
ox, oy, ow, oh = GAP, GAP, 232, H - 2 * GAP
panel(ox, oy, ow, oh, ["Outliner", "Assets"])
rows = [(0, "down", "Scene"), (1, "down", "Group"), (2, None, "Cube"), (2, None, "Sphere"),
        (2, None, "Key light"), (1, None, "Camera"), (1, "right", "Environment")]
ry = oy + TAB + 9
for depth, chev, name in rows:
    selected = name == "Cube"
    if selected:
        rect(ox + 6, ry, ow - 12, 24, T["accent"], 4, 'fill-opacity="0.18"')
    cx = ox + 14 + depth * 14
    if chev == "down":
        chevron_down(cx, ry + 10)
    elif chev == "right":
        chevron_right(cx + 2, ry + 8.5)
    text(cx + 14, ry + 16, name, T["text"] if selected or depth == 0 else T["text2"])
    ry += 24

# --- Viewport -------------------------------------------------------------
vx, vy, vw, vh = ox + ow + GAP, GAP, 716, 520
panel(vx, vy, vw, vh, ["Viewport", "UV editor"])
bottom_rounded(vx, vy + TAB + 1, vw, vh - TAB - 1, T["viewport"])
out.append(f'<g stroke="{T["surface"]}" stroke-width="1">')
for gx in range(vx + 38, vx + vw, 40):
    out.append(f'<line x1="{gx}" y1="{vy+TAB+1}" x2="{gx}" y2="{vy+vh}"/>')
for gy in range(vy + TAB + 41, vy + vh, 40):
    out.append(f'<line x1="{vx}" y1="{gy}" x2="{vx+vw}" y2="{gy}"/>')
out.append('</g>')
ccx, ccy = vx + vw / 2, vy + TAB + (vh - TAB) / 2
out.append(f'<rect x="{ccx-52}" y="{ccy-52}" width="104" height="104" rx="14" fill="{T["accent"]}" '
           f'transform="rotate(16 {ccx} {ccy})"/>')
text(vx + 12, vy + TAB + 22, "Perspective", T["text3"], 11)

# --- Timeline -------------------------------------------------------------
tx0, ty0, tw0, th0 = vx, vy + vh + GAP, vw, H - GAP - (vy + vh + GAP)
panel(tx0, ty0, tw0, th0, ["Timeline", "Console"])
lane_x = tx0 + 120
for i, frame in enumerate(range(0, 241, 24)):
    fx = lane_x + 14 + i * 56
    text(fx, ty0 + TAB + 19, str(frame), T["text3"], 11, anchor="middle")
    rect(fx, ty0 + TAB + 26, 1, 4, T["border"])
rect(tx0, ty0 + TAB + 31, tw0, 1, T["border"])
tracks = [("Position", [(40, 180)], [40, 150, 220]), ("Rotation", [(96, 230)], [96, 326]),
          ("Opacity", [(180, 120)], [180, 300])]
ly = ty0 + TAB + 40
for name, clips, keys in tracks:
    text(tx0 + 14, ly + 16, name, T["text2"])
    for cx0, cw in clips:
        rect(lane_x + cx0, ly + 3, cw, 18, T["control"], 4)
    for k in keys:
        out.append(f'<rect x="{lane_x+k-3.5}" y="{ly+8.5}" width="7" height="7" rx="1.5" fill="{T["text2"]}" '
                   f'transform="rotate(45 {lane_x+k} {ly+12})"/>')
    ly += 28
ph = lane_x + 150
rect(ph - 0.5, ty0 + TAB + 1, 1, th0 - TAB - 1, T["accent"])
rect(ph - 5, ty0 + TAB + 1, 10, 6, T["accent"], 2)

# --- Inspector (the active panel, pointer over its tab strip) -------------
ix, iy, iw, ih = vx + vw + GAP, GAP, W - GAP - (vx + vw + GAP), H - 2 * GAP
panel(ix, iy, iw, ih, ["Inspector", "Notes"], active=True, buttons=True)
DOT, LBL, CTL = ix + 9, ix + 16, ix + 108
CW = ix + iw - 12 - CTL
y = iy + TAB + 7


def section(title, expanded=True, changed=False):
    global y
    if expanded:
        chevron_down(ix + 14, y + 12, T["text2"])
    else:
        chevron_right(ix + 16, y + 10.5, T["text2"])
    text(ix + 30, y + 18, title, T["text"], weight=500)
    if changed:
        out.append(f'<circle cx="{ix + 30 + len(title) * 7 + 8}" cy="{y+14}" r="2.5" fill="{T["accent"]}"/>')
    y += 28


def divider():
    global y
    y += 6
    rect(ix, y, iw, 1, T["border"])
    y += 7


def row(label, modified=False):
    """Label column; returns the control's top y and advances one row."""
    global y
    if modified:
        out.append(f'<circle cx="{DOT}" cy="{y+14}" r="2.5" fill="{T["accent"]}"/>')
    text(LBL, y + 18, label, T["text2"])
    top = y + 2
    y += 28
    return top


def field(x, top, w, value, color=T["text"], fill=None, ring=None, lead=None):
    rect(x, top, w, 24, T["control"], 4)
    if fill:
        out.append(f'<path d="M{x+4} {top} h{fill-4} v24 h-{fill-4} a4 4 0 0 1 -4 -4 v-16 a4 4 0 0 1 4 -4 z" '
                   f'fill="{T["controlFill"]}"/>')
    if ring:
        rect(x - 0.75, top - 0.75, w + 1.5, 25.5, "none", 4.75, f'stroke="{ring}" stroke-width="1.5"')
    tx = x + 8
    if lead:
        text(x + 8, top + 16, lead, T["text2"])
        tx = x + 22
    text(tx, top + 16, value, color, extra='style="font-variant-numeric: tabular-nums"')


section("Transform")
t = row("Position")
cw3 = (CW - 8) / 3
for i, (axis, val) in enumerate([("X", "120"), ("Y", "48"), ("Z", "0")]):
    field(CTL + i * (cw3 + 4), t, cw3, val, lead=axis)
t = row("Rotation")
field(CTL, t, CW, "45°", T["driven"])
text(CTL + CW - 8, t + 16, "ƒ", T["driven"], 12, anchor="end", extra='font-style="italic"')
t = row("Scale", modified=True)
field(CTL, t, CW, "1.5")
divider()

section("Appearance")
t = row("Opacity")
field(CTL, t, CW, "62%", fill=round(CW * 0.62), ring=T["accent"])
t = row("Blend")
field(CTL, t, CW, "Normal")
chevron_down(CTL + CW - 16, t + 10.5)
t = row("Fill")
rect(CTL, t, CW, 24, T["control"], 4)
rect(CTL + 3, t + 3, 18, 18, T["accent"], 3)
text(CTL + 28, t + 16, "4C8DFF")
text(CTL + CW - 8, t + 16, "100%", T["text2"], anchor="end")
t = row("Align")
rect(CTL, t, CW, 24, T["control"], 4)
sw = (CW - 4) / 3
rect(CTL + 2 + sw, t + 2, sw, 20, T["controlFill"], 3)
for i, name in enumerate(["Left", "Center", "Right"]):
    text(CTL + 2 + sw * i + sw / 2, t + 16, name, T["text"] if i == 1 else T["text2"], anchor="middle")
t = row("Visible")
rect(CTL, t + 5, 14, 14, T["accent"], 3)
path(f"M{CTL+3.5} {t+12.2} l2.6 2.6 l4.6 -5.2", T["ink"], 1.7)
t = row("Shadows")
rect(CTL, t + 5, 26, 14, T["accent"], 7)
out.append(f'<circle cx="{CTL+19}" cy="{t+12}" r="5" fill="{T["ink"]}"/>')
divider()

section("Geometry")
t = row("Segments")
rect(CTL, t, CW, 24, T["control"], 4)
path(f"M{CTL+9} {t+12} h7", T["text2"])
path(f"M{CTL+CW-16} {t+12} h7 M{CTL+CW-12.5} {t+8.5} v7", T["text2"])
text(CTL + CW / 2, t + 16, "12", anchor="middle")
t = row("Width")
field(CTL, t, CW, "Mixed", T["text2"])
t = row("Bevel")
field(CTL, t, CW, "2 * (3", ring=T["error"])
divider()

section("Physics", expanded=False, changed=True)

# overlay scroll bar: no gutter of its own
rect(ix + iw - 5, iy + TAB + 8, 3, 190, T["controlFill"], 1.5)

out.append('</svg>')
open(sys.argv[1], "w").write("\n".join(out) + "\n")
