#!/usr/bin/env bash
# BasementIO: check every site before and after a change, then compare the two runs.
#
# Usage:  bash healthcheck.sh [targets-file]      (default: healthcheck-targets.txt)
#         bash healthcheck.sh | tee healthcheck-before.log
#
# The targets file has one URL per line; lines starting with # are ignored.
# A site counts as DOWN on connection failure (000) or a 5xx response. 401/403/404
# still count as UP: the server answered, which is what this check is for.
# Exit code is 1 if anything is DOWN.

set -uo pipefail

file="${1:-healthcheck-targets.txt}"
[[ -f "$file" ]] || { echo "targets file not found: $file" >&2; exit 2; }

down=0
while IFS= read -r url || [[ -n "$url" ]]; do
  [[ -z "$url" || "$url" == \#* ]] && continue
  result=$(curl -s -o /dev/null -L --max-time 15 -w '%{http_code} %{time_total}s' "$url" 2>/dev/null)
  code=${result%% *}
  if [[ "$code" == "000" || "$code" == 5* ]]; then
    status="DOWN"; down=1
  else
    status="UP"
  fi
  printf '%-4s  %-50s  %s\n' "$status" "$url" "$result"
done < "$file"

exit "$down"
