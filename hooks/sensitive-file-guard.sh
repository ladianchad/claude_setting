#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then exit 0; fi

FILE_PATH=$(realpath "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
BASENAME=$(basename "$FILE_PATH")

# basename 패턴
SENSITIVE_PATTERNS=(
  ".env" ".env.*"
  "*.pem" "*.key" "*.cert" "*.crt"
  "*.p12" "*.pfx" "*.keystore" "*.jks"
  "credentials*" "secrets*" "*secret*"
  "id_rsa" "id_rsa.*" "id_ed25519" "id_ed25519.*"
  ".netrc" ".npmrc" ".pypirc"
)

for PATTERN in "${SENSITIVE_PATTERNS[@]}"; do
  if [[ "$BASENAME" == $PATTERN ]]; then
    echo "민감 파일 수정 차단: $BASENAME — 직접 수동으로 수정하세요."
    exit 2
  fi
done

# 경로 패턴
SENSITIVE_PATH_PATTERNS=(
  "*/.ssh/*"
  "*/.gnupg/*"
  "*/.aws/credentials*"
  "*/.config/gcloud/*"
)

for PATTERN in "${SENSITIVE_PATH_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == $PATTERN ]]; then
    echo "민감 경로 수정 차단: $FILE_PATH — 직접 수동으로 수정하세요."
    exit 2
  fi
done
