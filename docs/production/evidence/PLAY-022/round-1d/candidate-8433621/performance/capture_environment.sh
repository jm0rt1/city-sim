#!/usr/bin/env bash

set -u

ordinal="${1:?sample ordinal required}"
output="${2:?output path required}"
repo_root="/Users/James/.codex/worktrees/cac1/city-sim"
product_commit="8433621760ba169995aa1a5dc81cac27c380d746"
executable="$repo_root/dist/CitySim-world-rendering-w5f893ad1da1b.app/Contents/MacOS/CitySimNative-w5f893ad1da1b"
packaged_manifest="$repo_root/dist/CitySim-world-rendering-w5f893ad1da1b.app/CitySimNative_CitySimNative.bundle/WorldAssets.atlas/generated-v4-manifest.json"
source_manifest="$repo_root/Native/CitySimNative/Sources/CitySimNative/Resources/WorldAssets.atlas/generated-v4-manifest.json"
candidate_manifest="$repo_root/dist/manifests/world-rendering-w5f893ad1da1b.manifest"

cd "$repo_root"

{
  echo "sample_ordinal=$ordinal"
  echo "captured_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "branch=$(git branch --show-current)"
  echo "evidence_head=$(git rev-parse HEAD)"
  echo "product_commit=$product_commit"
  echo "product_tree=$(git rev-parse "$product_commit^{tree}")"
  echo "status_begin"
  git status --short --branch
  echo "status_end"
  echo "product_resource_diff_begin"
  product_diff="$(git diff --name-only "$product_commit"..HEAD -- Native/CitySimNative)"
  if [[ -n "$product_diff" ]]; then
    printf '%s\n' "$product_diff"
  else
    echo "(none)"
  fi
  echo "product_resource_diff_end"
  echo "hashes_begin"
  shasum -a 256 "$executable" "$candidate_manifest" "$packaged_manifest" "$source_manifest"
  echo "hashes_end"
  echo "host_begin"
  sw_vers
  uname -a
  uptime
  sysctl -n hw.memsize
  echo "host_end"
  echo "thermal_begin"
  pmset -g therm
  echo "thermal_query_exit=$?"
  echo "thermal_end"
  echo "memory_pressure_begin"
  memory_pressure -Q
  echo "memory_pressure_query_exit=$?"
  echo "memory_pressure_end"
  echo "vm_stat_begin"
  vm_stat
  echo "vm_stat_end"
  echo "relevant_processes_begin"
  ps -axo pid=,ppid=,%cpu=,%mem=,rss=,etime=,command= | awk '$0 ~ /[C]itySim|[x]ctest|[s]wift-build|[s]wift test|[s]wift-frontend|[s]wiftc|[l]lbuild/'
  echo "relevant_processes_end"
  echo "all_processes_begin"
  ps -axo pid=,ppid=,%cpu=,%mem=,rss=,etime=,command=
  echo "all_processes_end"
} > "$output" 2>&1
