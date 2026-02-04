#!/usr/bin/env bash
set -euo pipefail

HOST="7bmb@stokes"
ENV="APSstatus"
SCRIPT="07bm_monitor.py"
OUTPNG="/net/joulefs/coulomb_Public/docroot/tomolog/07bm_monitor.png"

ACTION="${1:-}"
case "$ACTION" in start|stop|status) ;; *) echo "Usage: $0 {start|stop|status}"; exit 2;; esac

ssh -T "$HOST" bash -s -- "$ACTION" "$ENV" "$SCRIPT" "$OUTPNG" <<'REMOTE'
ACTION="$1"
ENV="$2"
SCRIPT="$3"
OUTPNG="$4"

RUNDIR="$HOME/.apsstatus_monitors"
PIDFILE="$RUNDIR/07bm.pid"
LOGFILE="$RUNDIR/07bm.log"
WORKDIR="$(readlink -f ~/conda/APSstatus/APSstatus_beamlines 2>/dev/null || echo "$HOME/conda/APSstatus/APSstatus_beamlines")"

mkdir -p "$RUNDIR"

find_pids() {
  pgrep -u "$USER" -f "python(3)? .*${SCRIPT}" || true
}

conda_init() {
  [ -f ~/.bashrc ] && source ~/.bashrc
  if ! command -v conda >/dev/null 2>&1; then
    [ -f ~/miniconda3/etc/profile.d/conda.sh ] && source ~/miniconda3/etc/profile.d/conda.sh
    [ -f ~/anaconda3/etc/profile.d/conda.sh ] && source ~/anaconda3/etc/profile.d/conda.sh
  fi
}

start() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "07bm already running (pid $(cat "$PIDFILE"))"
    exit 0
  fi

  PIDS="$(find_pids)"
  if [ -n "$PIDS" ]; then
    PID="$(echo "$PIDS" | head -n1)"
    echo "$PID" > "$PIDFILE"
    echo "07bm already running (refreshed pidfile, pid $PID)"
    exit 0
  fi

  conda_init
  conda activate "$ENV"
  cd "$WORKDIR"

  nohup python "$SCRIPT" >> "$LOGFILE" 2>&1 &
  echo $! > "$PIDFILE"
  echo "07bm started (pid $(cat "$PIDFILE"))"
}

stop() {
  if [ -f "$PIDFILE" ]; then
    PID="$(cat "$PIDFILE")"
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID" 2>/dev/null || true
      rm -f "$PIDFILE"
      echo "07bm stopped (pid $PID)"
      return 0
    fi
    rm -f "$PIDFILE"
    echo "07bm not running (stale pidfile $PID) -- trying pgrep fallback"
  fi

  PIDS="$(find_pids)"
  if [ -n "$PIDS" ]; then
    kill $PIDS 2>/dev/null || true
    echo "07bm stopped (killed pids: $PIDS)"
    return 0
  fi

  echo "07bm not running"
}

status() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    PID="$(cat "$PIDFILE")"
    echo "07bm running (pid $PID)"
    ps -p "$PID" -o pid,etime,cmd

    if [ -f "$OUTPNG" ]; then
      echo "PNG:"
      stat -c "%y %s %n" "$OUTPNG"
    else
      echo "PNG missing: $OUTPNG"
    fi
  else
    echo "07bm not running"
    exit 1
  fi
}

"$ACTION"
REMOTE
