#!/bin/zsh

set -eu

ROOT="${0:A:h}"

exec /bin/zsh "$ROOT/scripts/bootstrap.zsh" "$@"
