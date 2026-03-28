#!/bin/bash
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then exit 0; fi

# 체인 구분자(&&, ||, ;)로 분할하여 각 서브커맨드 검사
# 파이프(|)는 데이터 흐름이므로 분할하지 않음
IFS=$'\n'
for SUBCMD in $(echo "$COMMAND" | sed 's/&&/\n/g; s/||/\n/g; s/;/\n/g'); do
  SUBCMD=$(echo "$SUBCMD" | sed 's/^[[:space:]]*//')
  [ -z "$SUBCMD" ] && continue

  # 1. git push force 우회 방지 (원본에서 플래그 검사 — 따옴표 우회 방지)
  if echo "$SUBCMD" | grep -qE '\bgit\s+push\b'; then
    if echo "$SUBCMD" | grep -qE -- '--force\b|--force-with-lease\b|\s-[a-zA-Z]*f[a-zA-Z]*\b|"--force"|'\''--force'\''|"-f"|'\''-f'\'''; then
      echo "force push 차단: $COMMAND — force push는 수동으로 실행하세요."
      exit 2
    fi
  fi

  # 2. git commit -a/--all 차단 (원본에서 플래그 검사)
  if echo "$SUBCMD" | grep -qE '\bgit\s+commit\b'; then
    if echo "$SUBCMD" | grep -qE -- '(\s-[a-zA-Z]*a[a-zA-Z]*\b|--all\b|"-a"|"--all"|'\''-a'\''|'\''--all'\'')'; then
      echo "git commit -a 차단: $COMMAND — git add로 파일을 명시적으로 스테이징하세요."
      exit 2
    fi
  fi

  # 3. 민감 파일 경로 감지 (따옴표 문자만 제거, 내용은 보존)
  STRIPPED_SUB=$(echo "$SUBCMD" | sed "s/'//g; s/\"//g")

  SENSITIVE_FILE_PATTERNS='\.env\b|\.pem\b|\.key\b|\.cert\b|\.crt\b|\.p12\b|\.pfx\b|\.keystore\b|\.jks\b|\bid_rsa\b|\bid_ed25519\b|\.netrc\b|\.npmrc\b|\.pypirc\b|/credentials\b|/secrets\b'
  SENSITIVE_PATH_PATTERNS='\.ssh/|\.gnupg/|\.aws/credentials|\.config/gcloud/'

  if echo "$STRIPPED_SUB" | grep -qE "$SENSITIVE_FILE_PATTERNS|$SENSITIVE_PATH_PATTERNS"; then
    # 읽기 전용 git 명령만 이 서브커맨드에서 허용
    if ! echo "$STRIPPED_SUB" | grep -qE '\bgit\s+(diff|log|show|status|blame)\b'; then
      echo "민감 파일 접근 감지: $COMMAND — 직접 수동으로 실행하세요."
      exit 2
    fi
  fi
done
