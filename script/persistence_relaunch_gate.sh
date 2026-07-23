#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage:
  persistence_relaunch_gate.sh start --manifest PATH --evidence-dir PATH
  persistence_relaunch_gate.sh finish --session PATH

The start phase consumes an existing staged-candidate manifest, records save
hashes, terminates only that manifest's exact executable PID, and relaunches the
same bundle without rebuilding. The new process receives one explicit absolute
data root and compact-window mode. Operate Save/Load in the app between start
and finish; finish records the post-load files and terminates only the proof PID.
USAGE
  exit 2
}

manifest_value() {
  local source_file="$1"
  local key="$2"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$source_file"
}

require_value() {
  local label="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "error: missing $label" >&2
    exit 1
  fi
}

require_absolute_path() {
  local label="$1"
  local value="$2"
  case "$value" in
    /*) ;;
    *)
      echo "error: $label must be absolute: $value" >&2
      exit 1
      ;;
  esac
}

process_command() {
  local process_id="$1"
  ps -p "$process_id" -o command= 2>/dev/null | sed -E 's/^[[:space:]]+//'
}

exact_process_ids() {
  local executable_path="$1"
  local process_id
  local process_command_line

  while read -r process_id process_command_line; do
    if [[ "$process_command_line" == "$executable_path" ]]; then
      printf '%s\n' "$process_id"
    fi
  done < <(ps -axo pid=,command=)
}

stop_exact_pid() {
  local process_id="$1"
  local executable_path="$2"
  local current_command

  if ! kill -0 "$process_id" 2>/dev/null; then
    return
  fi

  current_command="$(process_command "$process_id")"
  if [[ "$current_command" != "$executable_path" ]]; then
    echo "error: refusing to terminate PID $process_id; expected '$executable_path', found '$current_command'" >&2
    exit 1
  fi

  kill -TERM "$process_id"
  for _ in {1..30}; do
    if ! kill -0 "$process_id" 2>/dev/null; then
      return
    fi
    sleep 0.1
  done

  echo "error: exact staged PID $process_id did not terminate" >&2
  exit 1
}

wait_for_new_exact_pid() {
  local executable_path="$1"
  local process_ids

  for _ in {1..80}; do
    process_ids="$(exact_process_ids "$executable_path")"
    if [[ "$(printf '%s\n' "$process_ids" | sed '/^$/d' | wc -l | tr -d ' ')" == "1" ]]; then
      printf '%s\n' "$process_ids"
      return
    fi
    sleep 0.1
  done

  echo "error: expected exactly one relaunched process for $executable_path" >&2
  exact_process_ids "$executable_path" >&2 || true
  exit 1
}

record_save_inventory() {
  local data_root="$1"
  local output_file="$2"
  local save_file

  {
    printf 'data_root=%s\n' "$data_root"
    if [[ ! -d "$data_root" ]]; then
      echo "status=data-root-missing"
      return
    fi

    while IFS= read -r save_file; do
      [[ -n "$save_file" ]] || continue
      printf 'file=%s\n' "$save_file"
      wc -c "$save_file"
      shasum -a 256 "$save_file"
    done < <(
      find "$data_root" -maxdepth 1 -type f \
        \( -name 'quicksave.json' -o -name 'quicksave.backup.json' -o -name 'quicksave*.corrupt-*.json' \) \
        -print | LC_ALL=C sort
    )
  } >"$output_file"
}

start_gate() {
  local manifest_path=""
  local evidence_dir=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --manifest)
        [[ $# -ge 2 ]] || usage
        manifest_path="$2"
        shift 2
        ;;
      --evidence-dir)
        [[ $# -ge 2 ]] || usage
        evidence_dir="$2"
        shift 2
        ;;
      *) usage ;;
    esac
  done

  require_value "manifest path" "$manifest_path"
  require_value "evidence directory" "$evidence_dir"
  require_absolute_path "manifest path" "$manifest_path"
  require_absolute_path "evidence directory" "$evidence_dir"
  [[ -f "$manifest_path" ]] || { echo "error: manifest not found: $manifest_path" >&2; exit 1; }
  if [[ -e "$evidence_dir" && -n "$(find "$evidence_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
    echo "error: evidence directory must be new or empty: $evidence_dir" >&2
    exit 1
  fi
  mkdir -p "$evidence_dir"
  evidence_dir="$(cd "$evidence_dir" && pwd -P)"

  local candidate_id
  local candidate_commit
  local bundle_path
  local executable_path
  local manifest_root
  local prior_pid
  candidate_id="$(manifest_value "$manifest_path" candidate_id)"
  candidate_commit="$(manifest_value "$manifest_path" commit)"
  bundle_path="$(manifest_value "$manifest_path" staged_bundle_path)"
  executable_path="$(manifest_value "$manifest_path" executable_path)"
  manifest_root="$(manifest_value "$manifest_path" data_root)"
  prior_pid="$(manifest_value "$manifest_path" process_id)"

  require_value "candidate id" "$candidate_id"
  require_value "candidate commit" "$candidate_commit"
  require_value "staged bundle path" "$bundle_path"
  require_value "executable path" "$executable_path"
  require_value "manifest data root" "$manifest_root"
  require_absolute_path "staged bundle path" "$bundle_path"
  require_absolute_path "executable path" "$executable_path"
  [[ -d "$bundle_path" ]] || { echo "error: staged bundle not found: $bundle_path" >&2; exit 1; }
  [[ -x "$executable_path" ]] || { echo "error: staged executable not found: $executable_path" >&2; exit 1; }
  case "$executable_path" in
    "$bundle_path"/Contents/MacOS/*) ;;
    *) echo "error: manifest executable is outside its staged bundle" >&2; exit 1 ;;
  esac

  local data_root
  if [[ "$manifest_root" == "production-default" ]]; then
    data_root="${HOME:?}/Library/Application Support/CitySimNative"
  else
    require_absolute_path "manifest data root" "$manifest_root"
    data_root="$manifest_root"
  fi
  mkdir -p "$data_root"
  data_root="$(cd "$data_root" && pwd -P)"

  {
    printf 'started_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'manifest_path=%s\n' "$manifest_path"
    printf 'manifest_sha256=%s\n' "$(shasum -a 256 "$manifest_path" | awk '{print $1}')"
    printf 'candidate_id=%s\n' "$candidate_id"
    printf 'candidate_commit=%s\n' "$candidate_commit"
    printf 'staged_bundle_path=%s\n' "$bundle_path"
    printf 'executable_path=%s\n' "$executable_path"
    printf 'executable_sha256=%s\n' "$(shasum -a 256 "$executable_path" | awk '{print $1}')"
    printf 'manifest_data_root=%s\n' "$manifest_root"
    printf 'resolved_data_root=%s\n' "$data_root"
    printf 'prior_manifest_pid=%s\n' "$prior_pid"
  } >"$evidence_dir/identity-before.txt"
  record_save_inventory "$data_root" "$evidence_dir/save-inventory-before.txt"

  if [[ "$prior_pid" =~ ^[0-9]+$ ]]; then
    stop_exact_pid "$prior_pid" "$executable_path"
  fi

  local survivors
  survivors="$(exact_process_ids "$executable_path")"
  if [[ -n "$survivors" ]]; then
    echo "error: exact staged executable still has unowned processes; refusing ambiguous relaunch" >&2
    printf '%s\n' "$survivors" >&2
    exit 1
  fi

  /usr/bin/open -n \
    --env "CITYSIM_DATA_ROOT=$data_root" \
    --env "CITYSIM_COMPACT_WINDOW=1" \
    "$bundle_path"

  local relaunched_pid
  local process_environment
  relaunched_pid="$(wait_for_new_exact_pid "$executable_path")"
  process_environment="$(ps eww -p "$relaunched_pid" -o command=)"
  if [[ "$process_environment" != *"CITYSIM_DATA_ROOT=$data_root"* ]]; then
    echo "error: relaunched PID does not expose the exact data root" >&2
    stop_exact_pid "$relaunched_pid" "$executable_path"
    exit 1
  fi
  if [[ "$process_environment" != *"CITYSIM_COMPACT_WINDOW=1"* ]]; then
    echo "error: relaunched PID is not explicit compact mode" >&2
    stop_exact_pid "$relaunched_pid" "$executable_path"
    exit 1
  fi

  {
    printf 'process_id=%s\n' "$relaunched_pid"
    printf 'process_command=%s\n' "$(process_command "$relaunched_pid")"
    printf 'CITYSIM_DATA_ROOT=%s\n' "$data_root"
    echo 'CITYSIM_COMPACT_WINDOW=1'
  } >"$evidence_dir/process-proof.txt"
  {
    printf 'manifest_path=%s\n' "$manifest_path"
    printf 'candidate_id=%s\n' "$candidate_id"
    printf 'candidate_commit=%s\n' "$candidate_commit"
    printf 'staged_bundle_path=%s\n' "$bundle_path"
    printf 'executable_path=%s\n' "$executable_path"
    printf 'resolved_data_root=%s\n' "$data_root"
    printf 'proof_pid=%s\n' "$relaunched_pid"
    printf 'evidence_dir=%s\n' "$evidence_dir"
  } >"$evidence_dir/relaunch.session"

  printf 'candidate_id=%s\n' "$candidate_id"
  printf 'candidate_commit=%s\n' "$candidate_commit"
  printf 'resolved_data_root=%s\n' "$data_root"
  printf 'proof_pid=%s\n' "$relaunched_pid"
  printf 'session=%s\n' "$evidence_dir/relaunch.session"
  echo "status=ready-for-live-load"
}

finish_gate() {
  local session_path=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --session)
        [[ $# -ge 2 ]] || usage
        session_path="$2"
        shift 2
        ;;
      *) usage ;;
    esac
  done

  require_value "session path" "$session_path"
  require_absolute_path "session path" "$session_path"
  [[ -f "$session_path" ]] || { echo "error: session not found: $session_path" >&2; exit 1; }

  local executable_path
  local data_root
  local proof_pid
  local evidence_dir
  executable_path="$(manifest_value "$session_path" executable_path)"
  data_root="$(manifest_value "$session_path" resolved_data_root)"
  proof_pid="$(manifest_value "$session_path" proof_pid)"
  evidence_dir="$(manifest_value "$session_path" evidence_dir)"
  require_absolute_path "session executable path" "$executable_path"
  require_absolute_path "session data root" "$data_root"
  require_absolute_path "session evidence directory" "$evidence_dir"
  [[ "$proof_pid" =~ ^[0-9]+$ ]] || { echo "error: invalid proof PID: $proof_pid" >&2; exit 1; }

  record_save_inventory "$data_root" "$evidence_dir/save-inventory-after.txt"
  {
    printf 'finished_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'proof_pid=%s\n' "$proof_pid"
    printf 'process_command=%s\n' "$(process_command "$proof_pid")"
  } >"$evidence_dir/identity-after.txt"

  stop_exact_pid "$proof_pid" "$executable_path"
  if [[ -n "$(exact_process_ids "$executable_path")" ]]; then
    echo "error: exact staged executable still has a process after cleanup" >&2
    exit 1
  fi

  {
    cat "$evidence_dir/identity-before.txt"
    cat "$evidence_dir/identity-after.txt"
    echo "cleanup=exact-proof-pid-terminated"
    echo "status=complete"
  } >"$evidence_dir/SUMMARY.txt"

  printf 'evidence_dir=%s\n' "$evidence_dir"
  echo "cleanup=exact-proof-pid-terminated"
  echo "status=complete"
}

[[ $# -ge 1 ]] || usage
mode="$1"
shift

case "$mode" in
  start) start_gate "$@" ;;
  finish) finish_gate "$@" ;;
  *) usage ;;
esac
