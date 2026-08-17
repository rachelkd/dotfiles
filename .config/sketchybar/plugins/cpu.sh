#!/bin/bash
#
# Runs every 2 seconds (update_freq=2 in items/cpu.sh), so cost here is paid
# constantly. The previous version spent ~106ms across 12 processes (sysctl, ps,
# whoami x2, grep x2, sed x2, awk x3, sketchybar). Its user/system split was
# discarded anyway -- both halves were summed straight back together -- so the whole
# thing reduces to "sum every process's %CPU and divide by thread count", which is
# three processes and about half the time.

CORE_CACHE="${TMPDIR:-/tmp}/sketchybar_cpu_cores"

# Thread count cannot change while the machine is up, so pay sysctl once per boot.
if [ -f "$CORE_CACHE" ]; then
    CORE_COUNT=$(<"$CORE_CACHE")
else
    CORE_COUNT=$(sysctl -n machdep.cpu.thread_count)
    printf '%s' "$CORE_COUNT" > "$CORE_CACHE"
fi
[ -z "$CORE_COUNT" ] && CORE_COUNT=1

CPU_PERCENT=$(ps -eo pcpu | awk -v cores="$CORE_COUNT" '
    NR > 1 { sum += $1 }
    END { printf "%.0f", sum / cores }
')

sketchybar --set "$NAME" label="$CPU_PERCENT%"
