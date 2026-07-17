#!/bin/bash
# mining_summary.sh - summarize the last 24 hours of mining logs

set -euo pipefail

LOG_FILE="${HOME}/mining_stats.log"
DOCS_FILE="${HOME}/mining_orchestrator_docs.md"
CUTOFF_EPOCH=$(date -d '24 hours ago' +%s)

strip_prefix() {
    sed -E 's/^\[[0-9]+\] \[[^]]+\] //'
}

filter_last_24h() {
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "No log file found at $LOG_FILE"
        return
    fi
    awk -v cutoff="$CUTOFF_EPOCH" '
        /^\[[0-9]+\] \[/ {
            epoch = $1
            gsub(/^\[/, "", epoch)
            gsub(/\]$/, "", epoch)
            if (epoch + 0 >= cutoff + 0) print
        }
    ' "$LOG_FILE"
}

print_header() {
    echo "=================================="
    echo "Mining summary (last 24 hours)"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "Log file:  $LOG_FILE"
    echo "=================================="
    echo
}

print_last_logs() {
    echo "--- Last 24h log entries ---"
    filter_last_24h
    echo
}

print_hashrate_lines() {
    echo "--- Hashrate / speed lines (last 24h) ---"
    local lines
    lines=$(filter_last_24h | strip_prefix | grep -iE 'hashrate|speed|H/s|KH/s|MH/s|GH/s|TH/s' || true)
    if [[ -z "$lines" ]]; then
        echo "No hashrate/speed lines found."
    else
        echo "$lines"
    fi
    echo

    echo "--- Parsed average hashrate (numeric values only) ---"
    local avg
    avg=$(echo "$lines" | awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+\.?[0-9]*$/) {
                    unit = ""
                    if ((i + 1) <= NF) unit = $(i + 1)
                    if (unit ~ /^[KMGT]?H\/s$/) {
                        sum += $i
                        count++
                        last_unit = unit
                    }
                }
            }
        }
        END {
            if (count > 0) {
                printf "%.2f %s (from %d samples)\n", sum / count, last_unit, count
            } else {
                print "No numeric hashrate values available to average."
            }
        }
    ')
    echo "$avg"
    echo
}

print_uptime() {
    echo "--- System uptime ---"
    uptime
    echo
}

append_to_docs() {
    echo "Appending summary to $DOCS_FILE"
    {
        echo
        echo "## 24h Test Results"
        echo
        echo "- **Generated:** $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "- **Uptime:** $(uptime)"
        echo "- **Log file:** ${LOG_FILE/#$HOME/~}"
        echo "- **24h log line count:** $(filter_last_24h | wc -l)"
        echo "- **Average hashrate (parsed):** $(print_hashrate_lines | grep 'Parsed average' -A1 | tail -n1)"
        echo "- **Status:** Summary generated; inspect ${LOG_FILE/#$HOME/~} for full details."
        echo
    } >> "$DOCS_FILE"
}

# Output summary to terminal
print_header
print_last_logs
print_hashrate_lines
print_uptime

# Append concise summary section to the orchestrator docs
append_to_docs

echo "Summary complete."
