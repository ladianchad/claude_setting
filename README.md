# claude-config

Claude Code를 프로덕션 수준으로 제어하는 설정 모음. rules, hooks, skills로 구성되어 있으며, 코딩부터 논문 작성까지 다중 에이전트 기반 검증 루프로 품질을 보장한다.

## 특징

- **Teammate Mode**: 모든 skill이 `context: fork`로 격리된 subagent에서 실행. skill별 model/effort/allowed-tools 차등 설정
- **병렬 구현**: 복수 에이전트가 독립 구현 → 관리자가 최선안 통합
- **다관점 병렬 리뷰**: 정확성 리뷰어 + 설계 리뷰어(프로젝트 전체 DRY/SOLID 검증) 병렬 수행
- **매몰 방지**: 같은 접근 2회 실패 시 subagent 위임 → 사용자 에스컬레이션
- **안전장치**: PreToolUse hooks로 force push, 민감 파일 접근, `git commit -a` 등 사전 차단
- **다중 에이전트 합의**: 설계/구현/논문 작성 시 복수 subagent 병렬 생성 → 합의안 도출
- **Skill 체이닝**: sprint/refactor → `/design` → `/coding` 자동 호출, paper_submit → `/paper` → `/paper_exam` 자동 호출
- **조건부 승인**: 자명한 경우 자동 진행, 트레이드오프가 있을 때만 사용자 확인
- **스케일링**: 변경 규모(10줄 미만/이상/100줄 이상)에 따라 검증 강도 자동 조절
- **SOLID 원칙 기반**: 모든 코딩/리뷰에 SOLID + LoD 원칙을 일관 적용

## 디렉토리 구조

```
~/.claude/
├── CLAUDE.md                        # 전역 지침 (한국어 응답, conventional commits 등)
├── settings.json                    # permissions, hooks, statusline 설정
├── statusline-command.sh            # context window/비용/시간 실시간 표시
├── hooks/
│   ├── bash-guard.sh                # force push, commit -a, 민감 파일 Bash 차단
│   └── sensitive-file-guard.sh      # Edit/Write/Read 민감 파일 차단
├── rules/
│   ├── principles.md                # SOLID + LoD + 구현 규칙
│   ├── review.md                    # 코드 리뷰 프레임워크 (심각도 4단계)
│   ├── escalation.md                # 매몰 방지 규칙
│   └── round-agent-protocol.md      # 라운드 기반 에이전트 프로토콜
└── skills/
    ├── coding/SKILL.md              # 프로덕션 코딩 (검증 루프)
    ├── debug/SKILL.md               # 체계적 디버깅 (가설 → 검증 → 이분 탐색)
    ├── design/SKILL.md              # 아키텍처 설계 (다중 에이전트 합의)
    ├── sprint/SKILL.md              # 요구사항 → 설계 → 구현 원스톱
    ├── refactor/SKILL.md            # 코드베이스 분석 + 리팩토링
    ├── paper/SKILL.md               # 논문 작성 (전문가 패널 라운드)
    ├── paper_exam/SKILL.md          # 투고 전 모의 심사
    ├── paper_review/SKILL.md        # 논문 분석/리뷰
    └── paper_submit/SKILL.md        # 작성 → 심사 → 수정 Accept까지
```

## Skills

모든 skill은 `context: fork`로 격리된 subagent에서 실행된다 (teammate mode). `disable-model-invocation: false`로 명시적 `/command` 호출만 허용.

### 개발

| Skill | 호출 | model | effort | allowed-tools |
|-------|------|-------|--------|---------------|
| **coding** | `/coding` | opus | high | Read, Edit, Write, Glob, Grep, Bash, Agent |
| **debug** | `/debug` | opus | high | Read, Edit, Write, Glob, Grep, Bash, Agent |
| **design** | `/design` | opus | high | Read, Glob, Grep, Bash, Agent |
| **sprint** | `/sprint <파일>` | opus | high | Read, Edit, Write, Glob, Grep, Bash, Agent |
| **refactor** | `/refactor` | opus | high | Read, Edit, Write, Glob, Grep, Bash, Agent |

### 논문

| Skill | 호출 | model | effort | allowed-tools |
|-------|------|-------|--------|---------------|
| **paper** | `/paper [short]` | opus | high | Read, Write, Glob, Grep, Bash, Agent |
| **paper_exam** | `/paper_exam [quick]` | opus | high | Read, Write, Glob, Grep, Bash, Agent |
| **paper_review** | `/paper_review <깊이>` | opus | medium | Read, Glob, Grep |
| **paper_submit** | `/paper_submit` | opus | high | Read, Write, Glob, Grep, Bash, Agent |

## 안전장치

`settings.json`의 permissions와 PreToolUse hooks로 2중 보호.

**Permissions**:
- **Allow**: git 읽기/쓰기, npm/pnpm/tsc/jest/vitest/eslint/prettier, gh 읽기
- **Deny**: `rm`, `sudo`, `chmod`, force push, `git reset --hard`, `git checkout`, `npm publish`

**Hooks** (PreToolUse):
- **bash-guard.sh** -- Bash 명령 수준에서 force push 우회(따옴표 포함), `git commit -a`, `.env`/`.pem`/`.ssh/` 등 민감 파일 접근 차단
- **sensitive-file-guard.sh** -- Edit/Write/Read 도구의 민감 파일 수정 차단 (basename + 경로 패턴 매칭)

## 설치

```bash
# 1. 기존 ~/.claude가 있으면 백업
mv ~/.claude ~/.claude.bak

# 2. clone
git clone https://github.com/<username>/claude-config.git ~/.claude

# 3. hook 실행 권한 부여
chmod +x ~/.claude/hooks/*.sh ~/.claude/statusline-command.sh
```

Claude Code를 실행하면 `~/.claude/CLAUDE.md`와 `settings.json`이 자동으로 로드된다.

## 커스터마이징

| 파일 | 용도 |
|------|------|
| `CLAUDE.md` | 응답 언어, Git 규칙 등 전역 지침 |
| `settings.json` | permissions allow/deny, hooks, statusline |
| `rules/principles.md` | SOLID 원칙, LoD, 구현 규칙 |
| `rules/review.md` | 리뷰 심각도 기준 (Critical/Major/Minor/Nitpick) |
| `rules/escalation.md` | 매몰 방지 임계값, 에스컬레이션 절차 |
| `rules/round-agent-protocol.md` | 라운드 에이전트 프로토콜, Cross-Round Escalation |
| `skills/*/SKILL.md` | 각 skill의 프로세스, 검증 기준, frontmatter 설정 |

프로젝트별로 `.claude/rules/workflow.md`를 추가하면 해당 프로젝트의 Git 워크플로우를 별도 지정할 수 있다.
