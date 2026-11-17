#!/usr/bin/env sh
# Times building Quilt's interface (bench/*.qml), headless.
#
#   ./run-bench.sh                       # every benchmark
#   ./run-bench.sh -input bench/bench_controls.qml benchmark_inspector_300_rows
#
# Each benchmark runs until its time is stable; the number to compare is
# "msecs per iteration". Run it a few times on an idle machine: differences
# under 3% are noise. Set QT_BIN as for run-tests.sh.
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
    echo "run-bench.sh: can't find qmltestrunner; set QT_BIN to your Qt bin directory" >&2
    exit 1
fi

export QT_FORCE_STDERR_LOGGING=1
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM_TESTS:-offscreen}"
XDG_CONFIG_HOME="$(mktemp -d)"
export XDG_CONFIG_HOME
trap 'rm -rf "$XDG_CONFIG_HOME"' EXIT

# (qmltestrunner only finds tst_*.qml in a directory, so name each file.)
if [ "$#" -gt 0 ]; then
    "$QT_BIN/qmltestrunner" -import . "$@" -minimumtotal 2000
else
    for file in bench/bench_*.qml; do
        "$QT_BIN/qmltestrunner" -import . -input "$file" -minimumtotal 2000
    done
fi 2>&1 | grep -E 'RESULT|msecs|FAIL|Totals'
