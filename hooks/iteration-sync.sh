#!/bin/bash
# Stop hook: 현재 프로젝트에 iteration 진행 상태 파일이 있으면 reminder를 출력한다.
# 상태 파일이 남아있다는 건 iteration skill이 실행 중이거나 중단된 상태라는 의미.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
[ -z "$CWD" ] && exit 0

STATE_DIR="$CWD/.claude/state"
[ ! -d "$STATE_DIR" ] && exit 0

STATE_FILES=$(find "$STATE_DIR" -maxdepth 1 -name "iteration-*.json" 2>/dev/null)
[ -z "$STATE_FILES" ] && exit 0

# 각 파일의 상태를 간단히 확인
while IFS= read -r FILE; do
  [ -z "$FILE" ] && continue
  CURRENT_VERDICT=$(jq -r '.current_verdict // "UNKNOWN"' "$FILE" 2>/dev/null)
  if [ "$CURRENT_VERDICT" != "PASS" ]; then
    FNAME=$(basename "$FILE")
    echo "ℹ iteration 진행 중: $FNAME (verdict=$CURRENT_VERDICT) — /iteration 재실행 또는 상태 파일 확인 필요." >&2
  fi
done <<< "$STATE_FILES"

exit 0
