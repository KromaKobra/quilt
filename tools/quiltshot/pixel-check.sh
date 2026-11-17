#!/usr/bin/env sh
# Checks that a change leaves Quilt's pixels exactly as they were.
#
#   tools/quiltshot/pixel-check.sh baseline     # capture build/pixels/baseline
#   (make the change)
#   tools/quiltshot/pixel-check.sh              # capture build/pixels/current and compare
#
# Captures the scripts in tools/quiltshot/pixels/ at 1x and 2x with the
# software renderer, which draws the same pixels on every machine. A
# difference leaves a *-diff.png beside the capture, with the changed
# pixels in red. Needs quiltshot built in build/quiltshot (see its
# CMakeLists.txt). The calendar shot rings today's date, so capture the
# baseline on the day you compare.
set -eu
cd "$(dirname "$0")/../.."

shot=build/quiltshot/quiltshot
if [ ! -x "$shot" ]; then
    echo "pixel-check.sh: build quiltshot first:" >&2
    echo "  cmake -S tools/quiltshot -B build/quiltshot && cmake --build build/quiltshot" >&2
    exit 2
fi

name="${1:-current}"
out="build/pixels/$name"
rm -rf "$out"

export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1
XDG_CONFIG_HOME="$(mktemp -d)"         # no saved layouts or sections
export XDG_CONFIG_HOME
trap 'rm -rf "$XDG_CONFIG_HOME"' EXIT

for scale in 1 2; do
    mkdir -p "$out/$scale"
    for app in gallery sandbox; do
        sed "s|@OUT@|$out/$scale|g" "tools/quiltshot/pixels/$app.txt" > "$out/$app-$scale.txt"
        QT_SCALE_FACTOR=$scale "$shot" "examples/$app.qml" "$out/$app-$scale.txt" 2>&1 \
            | grep -v -e '^eval:' -e 'propagateSizeHints' || true
    done
done

[ "$name" = baseline ] && { echo "Baseline captured in $out"; exit 0; }

base=build/pixels/baseline
failed=0
count=0
for file in "$base"/*/*.png; do
    rel="${file#"$base"/}"
    count=$((count + 1))
    if ! "$shot" compare "$file" "$out/$rel" "$out/${rel%.png}-diff.png" >/dev/null 2>&1; then
        echo "DIFFERS: $rel  (see $out/${rel%.png}-diff.png)"
        failed=$((failed + 1))
    fi
done
echo "$((count - failed)) of $count images identical"
[ "$failed" -eq 0 ]
