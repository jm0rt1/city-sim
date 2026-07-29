#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 --repo-root PATH --manifest PATH --manifest-sha256 HASH --ledger-output PATH"
}

repo_root=""
manifest=""
manifest_sha256=""
ledger_output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="$2"
      shift 2
      ;;
    --manifest)
      manifest="$2"
      shift 2
      ;;
    --manifest-sha256)
      manifest_sha256="$2"
      shift 2
      ;;
    --ledger-output)
      ledger_output="$2"
      shift 2
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

if [[ -z "$repo_root" || -z "$manifest" || -z "$manifest_sha256" || -z "$ledger_output" ]]; then
  usage
  exit 64
fi

if [[ ! "$manifest_sha256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "manifest SHA-256 must be 64 lowercase hexadecimal characters"
  exit 65
fi

repo_root="$(cd "$repo_root" && pwd -P)"
cd "$repo_root"

export CITYSIM_L4_CLAIMED_ROOT="$repo_root"
export CITYSIM_L4_ASSEMBLY_MANIFEST_PATH="$manifest"
export CITYSIM_L4_ASSEMBLY_MANIFEST_SHA256="$manifest_sha256"
export CITYSIM_L4_ATOMIC_LEDGER_OUTPUT="$ledger_output"

swift test \
  --package-path Native/CitySimNative \
  --filter IndustrialL4V2SourceAdmissionHarnessTests/testCallerSuppliedAtomicAssemblyManifest
