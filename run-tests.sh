#!/usr/bin/env sh
# Lints the Quilt module and examples, then runs the QML test suite headless.
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
"$QT_BIN/qmllint" -I . Quilt/*.qml examples/*.qml examples/cpp-host/Main.qml

echo "== qmltestrunner"
if [ "$#" -gt 0 ]; then
    "$QT_BIN/qmltestrunner" -import . "$@"
else
    "$QT_BIN/qmltestrunner" -import . -input tests
fi
