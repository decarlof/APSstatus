#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  aps_status.sh [--parallel] {start|stop|status|restart|logs}
EOF
}

PARALLEL=0
if [[ "${1:-}" == "--parallel" ]]; then
  PARALLEL=1
  shift
fi

ACTION="${1:-}"
case "$ACTION" in start|stop|status|restart|logs) ;; *) usage; exit 2;; esac

# beamline|script|host|png
ITEMS=(
  "2bm|$HOME/bin/2bm_monitor.sh|2bmb@arcturus|/net/joulefs/coulomb_Public/docroot/tomolog/02bm_monitor.png"
  "7bm|$HOME/bin/7bm_monitor.sh|7bmb@stokes|/net/joulefs/coulomb_Public/docroot/tomolog/07bm_monitor.png"
  "32id|$HOME/bin/32id_monitor.sh|usertxm@gauss|/net/joulefs/coulomb_Public/docroot/tomolog/32id_monitor.png"
)

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

run_one() {
  local beam="$1" script="$2"
  local out="$tmpdir/${beam}.out"
  local rcfile="$tmpdir/${beam}.rc"

  if [[ ! -x "$script" ]]; then
    printf 'Missing or not executable: %s\n' "$script" >"$out"
    echo 2 >"$rcfile"
    return 0
  fi

  if [[ "$ACTION" == "restart" ]]; then
    { "$script" stop || true; "$script" start; } >"$out" 2>&1
    echo $? >"$rcfile"
    return 0
  fi

  # don't let nonzero exit codes abort the orchestrator (status returns 1 when not running)
  set +e
  "$script" "$ACTION" >"$out" 2>&1
  rc=$?
  set -e
  echo "$rc" >"$rcfile"
}

png_stat_ssh() {
  local host="$1" png="$2"
  # returns: "YYYY-mm-dd HH:MM:SS.NNNNNNNNN -TZ SIZE" or empty
  ssh -T "$host" "bash -lc 'stat -c \"%y %s\" \"$png\" 2>/dev/null'" 2>/dev/null || true
}

# Run scripts
pids=()
for item in "${ITEMS[@]}"; do
  IFS='|' read -r beam script host png <<<"$item"
  if (( PARALLEL )); then
    run_one "$beam" "$script" &
    pids+=("$!")
  else
    run_one "$beam" "$script"
  fi
done
if (( PARALLEL )); then
  for p in "${pids[@]}"; do wait "$p" || true; done
fi

if [[ "$ACTION" == "status" ]]; then
  printf "%-6s %-16s %-8s %-10s %-28s %-10s %s\n" \
    "BL" "STATE" "PID" "ELAPSED" "PNG_TIME" "PNG_SIZE" "CMD"
  printf "%-6s %-16s %-8s %-10s %-28s %-10s %s\n" \
    "------" "----------------" "--------" "----------" "----------------------------" "----------" "------------------------------"

  overall=0
  for item in "${ITEMS[@]}"; do
    IFS='|' read -r beam script host png <<<"$item"
    out="$tmpdir/${beam}.out"
    rcf="$tmpdir/${beam}.rc"
    thisrc="$(cat "$rcf" 2>/dev/null || echo 1)"

    state="not running"; pid="-"; etime="-"; cmd="-"; pngts="-"; pngsz="-"

    # PID from: "... running (pid 12345)"
    pid="$(awk '
      match($0, /running \(pid[[:space:]]+([0-9]+)\)/, m) {print m[1]; exit}
    ' "$out" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]]; then
      state="running"
    else
      pid="-"
    fi

    # ps detail line is the line after header starting with "PID"
    psline="$(awk '$1=="PID"{getline; print; exit}' "$out" 2>/dev/null || true)"
    if [[ -n "${psline:-}" ]]; then
      etime="$(awk '{print $2}' <<<"$psline" 2>/dev/null || true)"
      cmd="$(awk '{$1="";$2="";sub(/^  */,"");print}' <<<"$psline" 2>/dev/null || true)"
      [[ -n "${etime:-}" ]] || etime="-"
      [[ -n "${cmd:-}" ]] || cmd="-"
    fi

    # Try to parse PNG from script output first
    if grep -q "^PNG:" "$out"; then
      pngline="$(awk 'found{print; exit} /^PNG:/{found=1}' "$out" 2>/dev/null || true)"
      pngts="$(awk '{print $1" "$2}' <<<"$pngline" 2>/dev/null || true)"
      pngsz="$(awk '{print $3}' <<<"$pngline" 2>/dev/null || true)"
      [[ -n "${pngts:-}" ]] || pngts="-"
      [[ -n "${pngsz:-}" ]] || pngsz="-"
    fi

    # If script didn't print PNG info (common when not running), stat via SSH
    if [[ "$pngts" == "-" || "$pngsz" == "-" ]]; then
      statline="$(png_stat_ssh "$host" "$png")"
      if [[ -n "$statline" ]]; then
        pngts="$(awk '{print $1" "$2}' <<<"$statline")"
        pngsz="$(awk '{print $4}' <<<"$statline")"
      fi
    fi

    printf "%-6s %-16s %-8s %-10s %-28s %-10s %s\n" \
      "$beam" "$state" "$pid" "$etime" "$pngts" "$pngsz" "$cmd"

    [[ "$thisrc" -eq 0 || "$thisrc" -eq 1 ]] || overall=1
  done

  exit "$overall"
else
  printf "%-6s %-14s %s\n" "BL" "RESULT" "MESSAGE"
  printf "%-6s %-14s %s\n" "------" "--------------" "------------------------------"

  overall=0
  for item in "${ITEMS[@]}"; do
    IFS='|' read -r beam script host png <<<"$item"
    out="$tmpdir/${beam}.out"
    rcf="$tmpdir/${beam}.rc"
    thisrc="$(cat "$rcf" 2>/dev/null || echo 1)"
    msg="$(tail -n 1 "$out" 2>/dev/null || true)"
    [[ -n "$msg" ]] || msg="(no output)"

    result="ERR($thisrc)"
    case "$thisrc" in
      0) result="OK" ;;
      1) result="NOT_RUNNING" ;;
      2) result="MISSING_SCRIPT" ;;
    esac

    printf "%-6s %-14s %s\n" "$beam" "$result" "$msg"

    # For start/stop/restart/logs, treat anything other than 0 or 1 as "overall failure"
    # (1 can happen depending on your per-beamline behavior; keep as non-fatal if you want)
    if [[ "$thisrc" -ne 0 && "$thisrc" -ne 1 ]]; then
      overall=1
    fi
  done

  if [[ "$ACTION" == "logs" ]]; then
    echo
    for item in "${ITEMS[@]}"; do
      IFS='|' read -r beam script host png <<<"$item"
      out="$tmpdir/${beam}.out"
      echo "==== $beam logs ===="
      cat "$out"
      echo
    done
  fi

  exit "$overall"
fi

  overall=0
  for item in "${ITEMS[@]}"; do
    IFS='|' read -r beam script host png <<<"$item"
    out="$tmpdir/${beam}.out"
    rcf="$tmpdir/${beam}.rc"
    thisrc="$(cat "$rcf" 2>/dev/null || echo 1)"
    msg="$(tail -n 1 "$out" 2>/dev/null || true)"
    [[ -n "$msg" ]] || msg="(no output)"
    printf "%-6s %-8s %s\n" "$beam" "$thisrc" "$msg"
    [[ "$thisrc" -eq 0 ]] || overall=1
  done

  if [[ "$ACTION" == "logs" ]]; then
    echo
    for item in "${ITEMS[@]}"; do
      IFS='|' read -r beam script host png <<<"$item"
      out="$tmpdir/${beam}.out"
      echo "==== $beam logs ===="
      cat "$out"
      echo
    done
  fi

  exit "$overall"
fi
