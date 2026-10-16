#!/bin/bash
#
# Matches Activity Monitor's "Memory Used": app memory (anonymous minus purgeable
# pages) + wired + compressed, as a share of physical memory.

MEMORY_PERCENT=$(vm_stat | awk -v total="$(sysctl -n hw.memsize)" '
    /page size of/ { page = $8 }
    /^Anonymous pages/ { used += $3 }
    /^Pages purgeable/ { used -= $3 }
    /^Pages wired down/ { used += $4 }
    /^Pages occupied by compressor/ { used += $5 }
    END { printf "%.0f", used * page / total * 100 }
')

sketchybar --set "$NAME" label="$MEMORY_PERCENT%"
