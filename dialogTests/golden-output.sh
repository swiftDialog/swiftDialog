#!/bin/bash
#
# golden-output.sh — Item 0 of the swiftDialog improvement backlog.
#
# Captures the stdout bytes + exit code of swiftDialog's documented,
# machine-readable CLI surface into a set of "golden" baseline files, then
# re-runs the same matrix later and diffs against the baseline. stdout and exit
# codes are a public contract (MDM scripts parse stdout; exit codes are
# documented in swiftDialog-docs/operation/exit-codes.md), so every backlog
# change must leave this diff empty unless the change is an agreed behaviour
# change.
#
# Usage:
#   golden-output.sh capture [--gui]        # write/refresh the baseline
#   golden-output.sh verify  [--gui]        # re-run and diff against baseline (default)
#   golden-output.sh parity  <other-binary> [--gui]
#                                           # run the matrix through BOTH the app
#                                           # binary and <other-binary> (e.g. a
#                                           # dialogcli candidate) and diff their
#                                           # output — the check for the D-series
#                                           # "move option into dialogcli" items.
#
# Binary selection (first match wins):
#   $DIALOG_BIN environment variable
#   a Dialog.app built into DerivedData (searched)
#   /Library/Application Support/Dialog/Dialog.app/Contents/MacOS/Dialog
#   /usr/local/bin/dialog
#
# Notes:
#   - Only stdout + exit code are compared. stderr carries timestamped writeLog
#     output and is intentionally ignored — it is not the contract.
#   - Volatile tokens (version/build string, $HOME, temp paths, pids) are
#     normalised before comparison so a rebuild or a different machine does not
#     produce false diffs. See normalise().
#   - HEADLESS cases exit before any window is shown and need no display.
#     GUI cases render a window and are only run with --gui (they need an active
#     WindowServer session). They are driven deterministically: the harness adds
#     --commandfile + --alwaysreturninput, launches, waits for the window, then
#     writes "quit:" to the command file. The app quits (exit 5) and, because of
#     --alwaysreturninput, still prints the collected user input. This is far
#     more reliable than --timer auto-dismiss, which races the countdown.
#   - Only textfield and checkbox result output is captured this way. Select-list
#     and --json output are NOT included: on the command-file quit path they
#     produce nothing because those branches read through the observed object
#     (which is only threaded in on a real button press), whereas textfield and
#     checkbox read the global argument state. Capturing select/--json output
#     reliably needs a UI-test harness, not this script — see backlog M5.
#   - The real flag for the checksum/hash option is --checksum (the internal
#     property is named "hash"; --hash is NOT a valid flag).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/golden"
CASE_TIMEOUT=15   # seconds; a case that runs longer is treated as a failure

# ----------------------------------------------------------------------------
# Locate the Dialog binary
# ----------------------------------------------------------------------------
find_dialog_bin() {
    if [ -n "${DIALOG_BIN:-}" ] && [ -x "$DIALOG_BIN" ]; then
        echo "$DIALOG_BIN"; return 0
    fi
    # DerivedData builds (Xcode default location + a repo-local scratch build)
    local dd
    for dd in \
        "$HOME/Library/Developer/Xcode/DerivedData"/dialog-*/Build/Products/*/Dialog.app/Contents/MacOS/Dialog \
        "$SCRIPT_DIR"/../**/Build/Products/*/Dialog.app/Contents/MacOS/Dialog; do
        [ -x "$dd" ] && { echo "$dd"; return 0; }
    done
    for dd in \
        "/Library/Application Support/Dialog/Dialog.app/Contents/MacOS/Dialog" \
        "/usr/local/bin/dialog"; do
        [ -x "$dd" ] && { echo "$dd"; return 0; }
    done
    return 1
}

# ----------------------------------------------------------------------------
# Test matrix.  Each entry: "name|mode|args"
#   mode = headless (no display needed) | gui (needs WindowServer)
# args is eval'd, so quote values containing spaces/commas.
# ----------------------------------------------------------------------------
CASES=(
    "version|headless|--version"
    "licence|headless|--licence"
    "coffee|headless|--coffee"
    "help|headless|--help"
    "help-title|headless|--help title"
    "listfonts|headless|--listfonts"
    "checksum|headless|--checksum foo"
    # GUI result-output cases (need --gui). Driven via the command-file quit:
    # mechanism (see header). The harness adds --commandfile + --alwaysreturninput.
    "textfield|gui|--title T --message M --textfield \"Name\",value=Bart"
    "checkbox|gui|--title T --message M --checkbox \"Agree\",checked"
    "select|gui|--title T --message M --selecttitle \"Choice\" --selectvalues \"a,b,c\" --selectdefault \"b\""
    "textfield-json|gui|--title T --message M --textfield \"Name\",value=Bart --json"
)

# ----------------------------------------------------------------------------
# Normalise volatile content so rebuilds / machines don't cause false diffs.
# Reads stdin, writes stdout.
# ----------------------------------------------------------------------------
normalise() {
    sed -E \
        -e 's/swiftDialog v[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?/swiftDialog v<VERSION>/g' \
        -e 's/^[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$/<VERSION>/' \
        -e "s#${HOME}#<HOME>#g" \
        -e 's#/private/var/folders/[^ ]*#<TMPDIR>#g' \
        -e 's#/var/folders/[^ ]*#<TMPDIR>#g' \
        -e 's/\bpid[: ]*[0-9]+/pid <PID>/gi'
}

# Run one case with a timeout. Sets globals: OUT (normalised stdout), CODE.
#   mode headless -> run args as-is, capture until natural exit.
#   mode gui      -> add --commandfile + --alwaysreturninput, launch, wait for
#                    the window, send "quit:", capture the exit-with-output.
run_case() {
    local bin="$1" args="$2" mode="${3:-headless}"
    local raw; raw="$(mktemp)"
    local codef; codef="$(mktemp)"
    local cmdfile=""
    if [ "$mode" = "gui" ]; then
        cmdfile="$(mktemp -t gh_cmd)"; : >"$cmdfile"
        args="$args --commandfile \"$cmdfile\" --alwaysreturninput"
    fi
    (
        eval "\"$bin\" $args" >"$raw" 2>/dev/null
        echo $? >"$codef"
    ) &
    local p=$!
    if [ "$mode" = "gui" ]; then
        sleep 2.5                      # let the window come up
        echo "quit:" >>"$cmdfile"      # deterministic exit-with-output
    fi
    local i=0
    while kill -0 "$p" 2>/dev/null; do
        sleep 0.2; i=$((i+1))
        if [ $i -ge $((CASE_TIMEOUT*5)) ]; then
            kill "$p" 2>/dev/null
            pkill -f "MacOS/Dialog" 2>/dev/null
            OUT="<<TIMEOUT after ${CASE_TIMEOUT}s>>"; CODE="timeout"
            rm -f "$raw" "$codef" "$cmdfile"; return 0
        fi
    done
    wait "$p" 2>/dev/null
    OUT="$(normalise <"$raw")"
    CODE="$(cat "$codef" 2>/dev/null)"
    rm -f "$raw" "$codef" "$cmdfile"
}

should_run() {   # should_run <mode>
    [ "$1" = "headless" ] && return 0
    [ "$RUN_GUI" = "1" ] && return 0
    return 1
}

# ----------------------------------------------------------------------------
# Sub-commands
# ----------------------------------------------------------------------------
do_capture() {
    local bin="$1"
    mkdir -p "$GOLDEN_DIR"
    local entry name mode args
    for entry in "${CASES[@]}"; do
        IFS='|' read -r name mode args <<<"$entry"
        should_run "$mode" || { echo "skip  $name (gui; pass --gui)"; continue; }
        run_case "$bin" "$args" "$mode"
        printf '%s' "$OUT" >"$GOLDEN_DIR/$name.stdout"
        printf '%s' "$CODE" >"$GOLDEN_DIR/$name.exit"
        echo "saved $name (exit $CODE, $(printf '%s' "$OUT" | wc -l | tr -d ' ') lines)"
    done
    echo "Baseline written to $GOLDEN_DIR"
}

do_verify() {
    local bin="$1" fails=0 checked=0
    if [ ! -d "$GOLDEN_DIR" ]; then
        echo "No baseline at $GOLDEN_DIR — run '$0 capture' first." >&2
        return 2
    fi
    local entry name mode args exp_out exp_code
    for entry in "${CASES[@]}"; do
        IFS='|' read -r name mode args <<<"$entry"
        should_run "$mode" || continue
        [ -f "$GOLDEN_DIR/$name.stdout" ] || { echo "skip  $name (no baseline)"; continue; }
        run_case "$bin" "$args" "$mode"
        checked=$((checked+1))
        exp_out="$(cat "$GOLDEN_DIR/$name.stdout")"
        exp_code="$(cat "$GOLDEN_DIR/$name.exit")"
        if [ "$OUT" = "$exp_out" ] && [ "$CODE" = "$exp_code" ]; then
            echo "ok    $name (exit $CODE)"
        else
            fails=$((fails+1))
            echo "FAIL  $name"
            [ "$CODE" != "$exp_code" ] && echo "        exit: expected $exp_code, got $CODE"
            if [ "$OUT" != "$exp_out" ]; then
                echo "        stdout diff (expected < / actual >):"
                diff <(printf '%s' "$exp_out") <(printf '%s' "$OUT") | sed 's/^/        /' | head -40
            fi
        fi
    done
    echo "---"
    echo "$checked checked, $fails failed."
    [ "$fails" -eq 0 ]
}

do_parity() {
    local app_bin="$1" other_bin="$2" fails=0 checked=0
    local entry name mode args
    echo "Parity: app=$app_bin  other=$other_bin"
    for entry in "${CASES[@]}"; do
        IFS='|' read -r name mode args <<<"$entry"
        should_run "$mode" || continue
        run_case "$app_bin" "$args" "$mode"; local a_out="$OUT" a_code="$CODE"
        run_case "$other_bin" "$args" "$mode"; local o_out="$OUT" o_code="$CODE"
        checked=$((checked+1))
        if [ "$a_out" = "$o_out" ] && [ "$a_code" = "$o_code" ]; then
            echo "match $name (exit $a_code)"
        else
            fails=$((fails+1))
            echo "DIFF  $name"
            [ "$a_code" != "$o_code" ] && echo "        exit: app $a_code, other $o_code"
            if [ "$a_out" != "$o_out" ]; then
                diff <(printf '%s' "$a_out") <(printf '%s' "$o_out") | sed 's/^/        /' | head -40
            fi
        fi
    done
    echo "---"
    echo "$checked compared, $fails differ."
    [ "$fails" -eq 0 ]
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
CMD="verify"
PARITY_BIN=""
RUN_GUI=0
POSITIONAL=()
for a in "$@"; do
    case "$a" in
        --gui) RUN_GUI=1 ;;
        capture|baseline) CMD="capture" ;;
        verify) CMD="verify" ;;
        parity) CMD="parity" ;;
        *) POSITIONAL+=("$a") ;;
    esac
done
[ "$CMD" = "parity" ] && PARITY_BIN="${POSITIONAL[0]:-}"

BIN="$(find_dialog_bin)" || { echo "Could not locate a Dialog binary. Set \$DIALOG_BIN." >&2; exit 2; }
echo "Dialog binary: $BIN"
[ "$RUN_GUI" = "1" ] && echo "(GUI cases enabled)"

case "$CMD" in
    capture) do_capture "$BIN" ;;
    verify)  do_verify  "$BIN" ;;
    parity)
        [ -x "$PARITY_BIN" ] || { echo "parity needs an executable second binary" >&2; exit 2; }
        do_parity "$BIN" "$PARITY_BIN" ;;
esac
