#!/usr/bin/env sh
# Lints the Quilt modules and examples, then runs the QML test suite headless.
#
#   ./run-tests.sh                                       # everything
#   ./run-tests.sh -input tests/tst_layout_tree.qml      # arguments replace "-input tests"
#
# Finds Qt's tool directory with qtpaths/qmake. Set QT_BIN to override, e.g.
# QT_BIN=$HOME/Qt/6.8.3/gcc_64/bin ./run-tests.sh
set -eu
cd "$(dirname "$0")"

if [ -z "${QT_BIN:-}" ]; then
    for tool in "qtpaths6 --query" "qtpaths --query" "qmake6 -query" "qmake -query"; do
        if QT_BIN="$($tool QT_INSTALL_BINS 2>/dev/null)" && [ -n "$QT_BIN" ]; then
            break
        fi
    done
fi
if [ ! -x "${QT_BIN:-}/qmltestrunner" ]; then
    echo "run-tests.sh: can't find qmltestrunner; set QT_BIN to your Qt bin directory" >&2
    exit 1
fi

# Qt may log to the systemd journal instead of the terminal; force stderr.
export QT_FORCE_STDERR_LOGGING=1
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM_TESTS:-offscreen}"

# Keep the autosave test away from your real settings.
XDG_CONFIG_HOME="$(mktemp -d)"
export XDG_CONFIG_HOME
trap 'rm -rf "$XDG_CONFIG_HOME"' EXIT

echo "== qmllint"
# Any message fails the run. (qmllint's own exit code can't be used for that:
# -W 0 also counts warnings it decides not to print.)
lint() {
    if ! out="$("$QT_BIN/qmllint" -I . "$@" 2>&1)" || [ -n "$out" ]; then
        printf '%s\n' "$out" >&2
        exit 1
    fi
}
# A singleton linted as a file is wrongly reported as "not declared as
# singleton in qmldir" (Qt 6.12), so those are linted without that category.
SINGLETONS="Quilt/Style/Theme.qml Quilt/Controls/Expression.qml Quilt/Controls/Clipboard.qml Quilt/Controls/ColorHistory.qml"
OTHERS=""
# (examples/cpp-host/Main.qml uses a C++ type, so it is linted by its CMake
# build instead: cmake --build <dir> --target all_qmllint.)
for f in Quilt/*.qml Quilt/Style/*.qml Quilt/Controls/*.qml Quilt/Params/*.qml examples/*.qml; do
    case " $SINGLETONS " in
        *" $f "*) ;;
        *) OTHERS="$OTHERS $f" ;;
    esac
done
# shellcheck disable=SC2086
lint $OTHERS
# shellcheck disable=SC2086
lint --import disable $SINGLETONS

echo "== qmltestrunner"
if [ "$#" -gt 0 ]; then
    "$QT_BIN/qmltestrunner" -import . "$@"
else
    "$QT_BIN/qmltestrunner" -import . -input tests
fi
