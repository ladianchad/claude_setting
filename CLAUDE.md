# Global

- 한국어 응답. 기술 용어/코드/커밋 메시지는 영어. 코드 주석(한 줄, 블록, KDoc 등)은 한국어 허용 — 단 코드 식별자/함수 참조/어노테이션 등 코드 인용은 영어 보존.
- 불확실하면 추측 말고 질문.
- 요청하지 않은 파일 생성 금지.
- Git: conventional commits, 원자적 커밋, git add는 파일 지정.
- 작업 완료 시 핵심만 간결하게 보고.
- **모든 코드 수정 및 피쳐 추가 필수 확인 항목** (사용자가 명시적으로 제외 지시한 경우만 면제):
  1. pre-existing error 수정 (빌드/타입/린터 경고 포함).
  2. dead code 삭제 (미사용 함수/변수/import/분기, 프로젝트 전체 탐색 후 판정).
  3. 중복 코드 검사 (DRY 위반, 기존 추상화 미활용 여부).
  4. 실제 main program 실행 검증 — 테스트 통과와 별개로 실서비스/CLI/라이브러리를 실제 기동해 정상 동작 확인 (test code 통과로 갈음 금지).
  5. 코드/주석에 **사적 룰 파일 인용 금지**(`~/.claude/CLAUDE.md`, `~/.claude/rules/*`, `principles.md` 등 사용자 환경 한정 파일) 및 **세션/워크플로우 산출물 어휘 금지**(`consensus §X`, `decision_rationale §X`, `impact_analysis`, `round-NNN-summary`, "the design consensus for this sprint", "during an earlier sprint", "in this phase" 등 `.claude/state/` 산출물을 가리키는 표현). 결정 근거는 룰 이름이 아니라 **WHY를 인라인으로** 풀어쓴다. 프로젝트에 실재하는 파일(예: `backend/CLAUDE.md`, `README.md`) 참조는 허용.
- 세부 처리 절차는 ~/.claude/rules/principles.md 참조.

@RTK.md
