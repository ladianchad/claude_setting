#!/bin/bash
# SessionStart hook: gh CLI 인증 상태 확인. 미인증 시 stderr에 경고만 출력하고 세션은 계속 진행한다.

if ! command -v gh >/dev/null 2>&1; then
  echo "⚠ gh CLI 미설치 — iteration skill 사용 시 설치 필요: https://cli.github.com" >&2
  exit 0
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "⚠ gh CLI 미인증 — 'gh auth login'으로 인증하세요 (project scope 필요)." >&2
  exit 0
fi

# project scope 확인 (project item-list가 가능한지)
SCOPES=$(gh auth status 2>&1 | grep -oE "Token scopes:.*" || echo "")
if [[ -n "$SCOPES" && "$SCOPES" != *"project"* && "$SCOPES" != *"'project'"* ]]; then
  echo "⚠ gh CLI에 'project' scope 없음 — 'gh auth refresh -s project'로 추가하세요." >&2
fi

exit 0
