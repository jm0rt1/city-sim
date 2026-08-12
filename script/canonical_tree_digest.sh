#!/usr/bin/env bash
set -euo pipefail

citysim_canonical_tree_digest() {
  local root="$1"

  if [[ ! -d "$root" ]]; then
    printf 'error: canonical tree root is not a directory: %s\n' "$root" >&2
    return 1
  fi

  (
    cd "$root"
    find . -type f -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 shasum -a 256 \
      | shasum -a 256 \
      | awk '{ print $1 }'
  )
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [[ "$#" -ne 1 ]]; then
    printf 'usage: %s <tree-root>\n' "$0" >&2
    exit 64
  fi
  citysim_canonical_tree_digest "$1"
fi
