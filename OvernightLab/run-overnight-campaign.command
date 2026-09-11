#!/bin/zsh
set -euo pipefail

readonly LAB_ROOT="${0:A:h}"
readonly CONTROLLER="$LAB_ROOT/overnight_lab.py"

[[ -f "$CONTROLLER" ]] || { print -u2 -- "OvernightLab controller is missing: $CONTROLLER"; exit 2; }

if [[ "${1:-}" == "--self-test" ]]; then
    shift
    (( $# == 0 )) || { print -u2 -- "--self-test accepts no additional arguments"; exit 2; }
    /usr/bin/python3 "$CONTROLLER" self-test
    /usr/bin/python3 "$CONTROLLER" fault-test
    exit 0
fi

exec /usr/bin/caffeinate -d -i -s -m /usr/bin/python3 "$CONTROLLER" campaign "$@"
