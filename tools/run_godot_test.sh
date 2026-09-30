#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if (($# == 0)); then
  echo "usage: tools/run_godot_test.sh <tests/foo.gd|test/foo.gd> [godot arguments...]" >&2
  exit 64
fi

target=$1
shift
case "$target" in
  res://tests/*.gd|res://test/*.gd)
    ;;
  tests/*.gd|test/*.gd)
    target="res://$target"
    ;;
  *)
    echo "test target must be a GDScript under tests/ or test/: $target" >&2
    exit 64
    ;;
esac

exec "$ROOT/tools/run_godot_isolated.sh" --headless --script "$target" "$@"
