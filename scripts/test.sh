#!/bin/bash
# Runs the CLI transliteration checks in tests/cases_*.txt (format: latin<TAB>expected top-1 or top-3).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release >/dev/null
B=.build/release/Franco
fail=0; total=0
for f in tests/cases_*.txt; do
  lang=$(basename "$f" .txt | sed 's/cases_//')
  while IFS=$'\t' read -r latin expected; do
    [ -z "$latin" ] && continue
    total=$((total+1))
    out=$($B --translit "$lang" "$latin" | head -1 | sed 's/^[^→]*→ //' | sed 's/ ([0-9.]* ms)$//')
    top3=$(echo "$out" | awk -F'  \\|  ' '{print $1"\n"$2"\n"$3}' | sed 's/·lit//; s/·+//; s/[[:space:]]*$//')
    if echo "$top3" | grep -qx "$expected"; then :; else echo "FAIL [$lang] $latin → expected '$expected' in top-3, got: $out"; fail=$((fail+1)); fi
  done < "$f"
done
echo "$((total-fail))/$total passed"
[ $fail -eq 0 ]
