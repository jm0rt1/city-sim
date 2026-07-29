#!/bin/bash
set -euo pipefail

usage() {
  echo "usage: $0 --repo-root PATH --direction north|east|south|west --packet PATH --packet-sha256 SHA256 --admission PATH --admission-sha256 SHA256 --receipt-output PATH" >&2
}

repo_root=""
direction=""
packet=""
packet_sha256=""
admission=""
admission_sha256=""
receipt_output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      repo_root="${2:-}"
      shift 2
      ;;
    --direction)
      direction="${2:-}"
      shift 2
      ;;
    --packet)
      packet="${2:-}"
      shift 2
      ;;
    --packet-sha256)
      packet_sha256="${2:-}"
      shift 2
      ;;
    --admission)
      admission="${2:-}"
      shift 2
      ;;
    --admission-sha256)
      admission_sha256="${2:-}"
      shift 2
      ;;
    --receipt-output)
      receipt_output="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

if [[ -z "$repo_root" || -z "$direction" || -z "$packet" \
  || -z "$packet_sha256" || -z "$admission" \
  || -z "$admission_sha256" || -z "$receipt_output" ]]; then
  usage
  exit 64
fi

case "$direction" in
  north|east|south|west) ;;
  *)
    echo "invalid direction: $direction" >&2
    exit 65
    ;;
esac

if [[ ! "$packet_sha256" =~ ^[0-9a-f]{64}$ \
  || ! "$admission_sha256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "packet and admission SHA-256 values must be 64 lowercase hex characters" >&2
  exit 65
fi

repo_root="$(cd "$repo_root" && pwd -P)"
cd "$repo_root"

CITYSIM_L4_CLAIMED_ROOT="$repo_root" \
CITYSIM_L4_DIRECTION="$direction" \
CITYSIM_L4_PACKET_PATH="$packet" \
CITYSIM_L4_PACKET_SHA256="$packet_sha256" \
CITYSIM_L4_ADMISSION_PATH="$admission" \
CITYSIM_L4_ADMISSION_SHA256="$admission_sha256" \
CITYSIM_L4_RECEIPT_OUTPUT="$receipt_output" \
swift test \
  --package-path Native/CitySimNative \
  --filter \
  IndustrialL4V2SourceAdmissionHarnessTests/testCallerSuppliedDirectionPacketAndAdmissionReceipt
