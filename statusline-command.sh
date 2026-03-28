#!/bin/sh
input=$(cat)

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // empty')
output_tokens=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
cost_fmt=$(printf '$%.4f' "$cost")
mins=$((duration_ms / 60000))
secs=$(((duration_ms % 60000) / 1000))

if [ -n "$used_pct" ] && [ -n "$input_tokens" ] && [ -n "$output_tokens" ]; then
  printf "\033[0;36m%s\033[0m | ctx: \033[0;33m%s%%\033[0m used (\033[0;32m%s%%\033[0m left) | last: in=\033[0;35m%s\033[0m out=\033[0;35m%s\033[0m | total: in=\033[0;34m%s\033[0m out=\033[0;34m%s\033[0m | \033[0;33m%s\033[0m | \033[0;32m%dm%ds\033[0m" \
    "$model" \
    "$used_pct" \
    "$remaining_pct" \
    "$input_tokens" \
    "$output_tokens" \
    "$total_input" \
    "$total_output" \
    "$cost_fmt" \
    "$mins" \
    "$secs"
elif [ -n "$used_pct" ]; then
  printf "\033[0;36m%s\033[0m | ctx: \033[0;33m%s%%\033[0m used (\033[0;32m%s%%\033[0m left) | total: in=\033[0;34m%s\033[0m out=\033[0;34m%s\033[0m | \033[0;33m%s\033[0m | \033[0;32m%dm%ds\033[0m" \
    "$model" \
    "$used_pct" \
    "$remaining_pct" \
    "$total_input" \
    "$total_output" \
    "$cost_fmt" \
    "$mins" \
    "$secs"
else
  printf "\033[0;36m%s\033[0m | ctx: no messages yet | total: in=\033[0;34m%s\033[0m out=\033[0;34m%s\033[0m | \033[0;33m%s\033[0m" \
    "$model" \
    "$total_input" \
    "$total_output" \
    "$cost_fmt"
fi
