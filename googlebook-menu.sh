#!/bin/bash
# Interactive start/stop menu for the Googlebook VM.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${GOOGLEBOOK_WORK:-$ROOT/work}"
case "$WORK" in
  /*) ;;
  *) WORK="$(pwd)/$WORK" ;;
esac
PYTHON="${PYTHON:-python3}"
PID_FILE="$WORK/logs/menu-launch.pid"
LOG_FILE="$WORK/logs/menu-launch.log"

launcher_pid() {
  local pid command
  [ -f "$PID_FILE" ] || return 1
  IFS= read -r pid < "$PID_FILE" || return 1
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  command="$(/bin/ps -ww -p "$pid" -o command= 2>/dev/null || true)"
  [[ "$command" == *"$ROOT/run/launch.py"* && "$command" == *"$WORK"* ]] || return 1
  printf '%s\n' "$pid"
}

is_running() {
  local pid
  pid="$(launcher_pid)" || return 1
  kill -0 "$pid" 2>/dev/null
}

start_vm() {
  if is_running; then
    echo "The VM is already starting or running."
    return
  fi
  rm -f "$PID_FILE"
  local required
  for required in \
    "$WORK/host/Googlebook VM.app/Contents/MacOS/GooglebookViewer" \
    "$WORK/host/qemu-interop" \
    "$WORK/host/qemu-aarch64-softmmu" \
    "$WORK/host/virgl_render_server" \
    "$WORK/UTM-beta/UTM.app/Contents/Frameworks" \
    "$WORK/image/googlebook.raw" "$WORK/image/initrd.img" "$WORK/image/kernel.Image"; do
    if [ ! -e "$required" ]; then
      echo "The VM is not built yet. Run ./install.sh first."
      return
    fi
  done
  mkdir -p "$WORK/logs"
  nohup "$PYTHON" "$ROOT/run/launch.py" "$WORK" >>"$LOG_FILE" 2>&1 </dev/null &
  local pid=$!
  printf '%s\n' "$pid" > "$PID_FILE"
  sleep 1
  if is_running; then
    echo "VM started (launcher PID $pid). The desktop window should appear shortly."
  else
    rm -f "$PID_FILE"
    echo "The VM did not start. Recent log output:"
    tail -n 20 "$LOG_FILE" 2>/dev/null || true
  fi
}

stop_vm() {
  local pid i
  if ! pid="$(launcher_pid)"; then
    rm -f "$PID_FILE"
    echo "No VM started from this menu is running."
    return
  fi
  echo "Asking Android to shut down cleanly..."
  kill -TERM "$pid"
  for i in {1..100}; do
    if ! is_running; then
      rm -f "$PID_FILE"
      echo "VM stopped."
      return
    fi
    sleep 1
  done
  echo "The launcher is still stopping. Check $LOG_FILE before trying again."
}

while true; do
  echo
  echo "Googlebook OS"
  echo "1) Start VM"
  echo "2) Stop VM"
  echo "3) Quit"
  read -r -p "Choose an option: " choice || exit 0
  case "$choice" in
    1) start_vm ;;
    2) stop_vm ;;
    3) exit 0 ;;
    *) echo "Choose 1, 2, or 3." ;;
  esac
done
