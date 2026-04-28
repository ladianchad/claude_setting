---
name: mockup
description: 목업(HTML/이미지) 파일을 프로젝트 페이지에 반영. 디자인 충돌을 탐지해 variant 스크린샷으로 사용자 선택 유도 → 구현 → 브라우저 실조작 검증 → 다관점 병렬 리뷰 라운드 루프.
argument-hint: [목업파일경로]
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, Agent, Skill
disable-model-invocation: false
---

# Mockup → Page

목업 파일을 받아 **프로젝트 디자인 시스템/코드 구조를 해치지 않고** 기존 페이지에 반영하거나 새 페이지를 구성한다. `/mockup <파일경로>` 로 호출.

현재 working directory(cwd)의 앱을 대상으로 동작한다. 사용자는 client-web / admin-web 중 작업하려는 앱 루트에서 호출해야 한다.

## 입력
- 목업 파일 경로를 인자로 받는다. (HTML, PNG/JPG 이미지, Figma export 모두 허용)
- 인자가 없으면 `mockup/` 디렉토리를 스캔해 후보를 열거하고 사용자에게 선택을 요청한다.
- **타겟 페이지**는 Phase 1 말미에 사용자에게 확인한다. 자동 결정 금지.

## Design 연계
사용자가 `/design` 상태 파일 경로를 명시적으로 전달한 경우에만 해당 설계안을 Phase 2 입력으로 사용. 경로 없이 "설계안 반영" 이라고만 하면 경로를 질문한다. 자동으로 state 디렉토리 탐색 금지.

## 스케일링 판단
목업의 복잡도로 규모를 판단한다:
- **소규모**: 단일 섹션, 상호작용 1~2개, 10줄 미만 신규 코드 — Phase 2 간소화.
- **중규모**: 페이지 하나, 상호작용/상태 5개 이하 — 전체 Phase 적용.
- **대규모**: 복수 화면, 폼·모달·네트워크 호출 연계 — Phase 2 에서 `/design` 호출.

---

## Phase 1: 목업 & 프로젝트 패턴 추출

### 1-1. 목업 분해
목업을 읽어 구조화된 명세로 추출한다:
- **레이아웃**: 최대폭, 그리드, 헤더/본문/푸터 구조.
- **색상**: 사용된 모든 hex / rgb / hsl 값 목록.
- **타이포**: font-family, size, weight, line-height.
- **간격**: padding/margin/gap 값 목록.
- **컴포넌트**: button, chip, badge, card, modal/sheet, input 등 재사용 단위.
- **상호작용**: onclick, open/close, toggle, form submit, navigation 등 (HTML 목업이면 script 블록에서 추출).
- **반응형**: `@media` 규칙 또는 breakpoint 전환 지점.
- **문자열**: 화면에 표시되는 모든 텍스트 (i18n 후보).

이미지 목업이면 Read 로 이미지를 보고 위 항목을 시각적으로 추출. HTML 목업이면 파싱.

### 1-2. 프로젝트 baseline 스캔
현재 cwd 기준으로 아래를 수집:
- `tailwind.config.ts|js`: screens (`2xs/xs/mobile` 등), colors (`g.gray.*`, `g.orange.*`, `kakao/naver`), zIndex semantic tokens (`base/overlay/content/dropdown/side/tooltip/toast/modal/layout/alert/error`), fontFamily.
- `src/modules/Ui/` 및 `src/modules/Ui/GUI/` 의 기존 프리미티브 목록.
- `src/modules/` 최상위 공용 모듈 목록 (Popup, ToastManager, ImageUploader, Permission, Auth, Fetch, Axios 등).
- `src/api/<domain>/` 도메인 목록 — 필요한 API 호출이 이미 있는지 후보 식별.
- `messages/ko.json` + `messages/en.json` (client-web) / 해당 없음 (admin-web, 한국어 전용).
- `src/app/(pages)/` 기존 라우트 — 타겟 후보 식별.
- `next.config.ts` 의 `env` 블록 + `images.remotePatterns` — 새 호스트/env 필요 여부.
- prettier/eslint 설정 → 포매팅 계약.
- `~/.claude/CLAUDE.md`, 프로젝트 루트 `CLAUDE.md`, cwd `CLAUDE.md` 를 **전부** 읽어 프로젝트 규칙(RTK.md, principles.md 포함)을 컨텍스트화한다.

### 1-3. Pre-existing 이슈 baseline
`/coding` Step 3 Static Analysis 와 동일 범위로 baseline 스캔 1회 실행하여 기록한다 (`yarn lint`, `yarn tsc`, `yarn build` 중 필요한 것, 프로젝트 설정 기준). 신규 도입 에러와 구분하기 위한 pre-existing 목록 확보. 이후 ~/.claude/rules/principles.md "Pre-existing 문제 처리" 절차 적용.

### 1-4. 타겟 페이지 확인 (사용자 질문 필수)
아래를 사용자에게 묻는다:
1. **기존 페이지 업데이트 vs 새 라우트 생성?**
2. 기존 업데이트라면 어떤 경로? (1-2 에서 추출한 후보 제시)
3. 새 라우트라면 어떤 경로? (예: `src/app/(pages)/event/[slug]/page.tsx`)
4. 권한 가드 필요 여부 (`<PermissionGuard>`).
5. 서버 컴포넌트 vs 클라이언트 컴포넌트 기본 분기 (`'use client'` 범위).

자동 결정 금지. 사용자 답변을 명시적으로 받고 기록한다.

---

## Phase 2: 매핑 + 디자인 충돌 해결

### 2-1. 목업 ↔ 프로젝트 컴포넌트 매핑표
아래 형식으로 매핑을 정리:

| 목업 섹션 | 재사용 컴포넌트 | 신규 컴포넌트 | 비고 |
|---|---|---|---|
| topbar | `GUI/TopBar` (있으면) | — | 뒤로가기 포함 |
| filter bar | — | `EventFilterBar` | chip은 `GUI/Chip` 재사용 |
| bottom sheet | `modules/Popup` 또는 `NotchPopup` | — | client-web 는 NotchPopup 우선 |
| toast | `modules/ToastManager` | — | mutation meta 경유 |

원칙:
- `src/modules/Ui` / `src/modules/Ui/GUI` 에 유사한 프리미티브가 있으면 **반드시 재사용**. 없는 경우에만 신규.
- Toast = `ToastManager`, Popup = `modules/Popup`/`NotchPopup`, Form = `react-hook-form` + `zod` + `zodResolver`, Image upload = `ImageUploader`, Cookie = `GogifarmCookie`, Auth = `modules/Auth`.
- API 호출 필요하면 `src/api/<domain>/` 의 `request.ts`/`response.ts`/`keys.ts`/`hook/*` 표준 구조를 따름. 스키마는 zod 먼저, 타입은 `z.infer` 파생.

### 2-2. 디자인 충돌 탐지 (핵심)
목업의 구현과 프로젝트 디자인 시스템 사이에서 **다음 유형의 충돌**을 식별:

| 유형 | 충돌 조건 | 예시 |
|---|---|---|
| **색상** | 목업이 팔레트 외 raw hex 사용 | `#768194` → `g.gray.300` 로 매핑 가능. `#XX9999` 같은 팔레트 외 값은 충돌 |
| **zIndex** | raw 숫자(`z-50`) 사용 | semantic token (`z-modal` 등) 로 치환 후보 제시 |
| **간격/패딩** | 프로젝트 공통 리듬(4/8/12/16/24)과 어긋남 | `padding: 13px` 같은 비표준 값 |
| **타이포** | tailwind.config 에 없는 font-family | `Apple SD Gothic Neo` → `NotoSanKR` 로 치환 후보 |
| **브레이크포인트** | 프로젝트 `2xs/xs/mobile` 과 다른 미디어 쿼리 | `@media (max-width: 768px)` → `md:` 대응 |
| **컴포넌트 모양** | 프로젝트의 기존 Button/Chip/Card 와 시각적으로 다름 | 목업의 filter chip vs `GUI/Chip` 스타일 |
| **그림자/라운드** | 프로젝트에 없는 shadow/radius 값 | `border-radius: 14px` (프로젝트는 12/16 위주) |
| **아이콘 시스템** | `<img src="*.svg">` 혹은 외부 아이콘 | 프로젝트는 SVGR(`import Icon from './icon.svg'`) + 라이브러리 |

각 충돌은 아래 메타로 카드화:
```
id: conflict-001
section: filter-bar 의 reset button 색
mockup_value: color #888888, border #dddddd
project_convention: g-gray-300 (#768194) / g-gray-100 (#dddddd)
severity: minor | major   # 프로젝트 통일성에 얼마나 영향?
```

### 2-3. 충돌별 variant 시각 제시 & 사용자 선택 (필수)

**"프로젝트 디자인을 해치는 것은 사용자 확인 후 화면에 띄워 선택하게 한다"** 는 요구사항의 구현 단계.

각 충돌 카드마다 다음 variant 를 준비:
- **Variant A — 목업 충실**: 목업 그대로 재현.
- **Variant B — 프로젝트 토큰 준수**: 프로젝트 디자인 시스템으로 치환.
- **Variant C — 하이브리드** (있으면): 일부만 토큰 맞춤.

**렌더링 방법**:
1. Orchestrator 는 각 variant 를 임시 HTML 조각으로 만든다 (프로젝트 tailwind 설정을 CDN 또는 build 된 CSS 로 로드하여 실제 색/폰트 반영).
2. 조각을 `.claude/state/mockup-variants/{conflict-id}.html` 에 저장.
3. Playwright MCP (`mcp__playwright__browser_navigate` + `mcp__playwright__browser_take_screenshot`) 로 각 variant 의 스크린샷을 `.claude/state/mockup-variants/{conflict-id}-{variant}.png` 로 캡처 (desktop + mobile 2 viewport 씩).
4. 사용자에게 아래 형식으로 제시:

```
## 디자인 충돌 [conflict-001]: filter-bar reset button 색

- 영향 영역: 필터 영역의 보조 버튼 전반
- 심각도: minor

Variant A (목업 충실):   .claude/state/mockup-variants/conflict-001-A.png
  color #888888, border #dddddd (팔레트 외)

Variant B (프로젝트 토큰):   .claude/state/mockup-variants/conflict-001-B.png
  text-g-gray-300 border-g-gray-100 (프로젝트 팔레트)

어느 쪽으로 갈까요? (A / B / 직접 조합 설명)
```

**원칙**:
- 사용자가 답하기 전까지 해당 충돌은 **미결** 상태. 미결 항목이 있으면 Phase 3 으로 넘어가지 않는다.
- 스크린샷은 실제 파일 경로로 제시한다. 사용자가 에디터/뷰어로 확인 가능.
- 사용자가 "알아서 해" 라고 답하면 기본값은 **Variant B (프로젝트 토큰 준수)**.
- 같은 유형의 충돌이 10개 이상 나오면 **대표 3개만 카드화** 하고, 나머지는 "같은 규칙으로 일괄 적용" 여부를 묻는다.

### 2-4. i18n 키 추출 (client-web 인 경우)
목업의 모든 사용자 표시 문자열을 `Domain.Section.Key` PascalCase 중첩으로 구조화. ko + en 양쪽 초안 작성. 사용자 승인 후 `messages/ko.json`, `messages/en.json` 에 추가.

### 2-5. 설계안 확정
아래를 명시한 설계안을 사용자에게 제시하고 승인받는다:
- 타겟 경로 (Phase 1-4 확정값).
- 신규/수정 파일 목록 + 역할.
- 재사용 컴포넌트/모듈 목록.
- 신규 API 호출 필요 여부 + zod 스키마 초안.
- 디자인 충돌 해결 결과 요약표.
- i18n 신규 키 목록.
- Server/Client 컴포넌트 경계.

대규모 (100줄 이상 또는 구조 변경) 인 경우 Skill tool 로 `/design` 을 호출하여 다중 에이전트 합의로 설계 확정.

---

## Phase 3: 구현

→ ~/.claude/rules/round-agent-protocol.md 적용 (Thin Loop + 상태 파일 규약).

### 3-1. 상태 파일 초기화
`.claude/state/mockup-{YYYYMMDD-HHmmss}.json` 생성. `requirements` 에 Phase 2 확정 설계안 + 디자인 충돌 해결 결과 + i18n 키 + 타겟 경로 기록.

### 3-2. `/coding` 위임
Skill tool 로 `/coding` 호출. 전달:
- 확정 설계안 (변경 명세 + 구현 순서).
- 디자인 충돌 해결 결정 (각 conflict-id 별 채택된 variant).
- Phase 1-3 의 pre-existing 이슈 목록 및 분류.
- 정적 분석 명령 세트: `yarn lint`, `yarn tsc --noEmit` (있으면), `yarn test --run <관련>`, `yarn build` (라우트/RSC/env 변경 시 필수).
- **프로젝트 디자인 규칙 체크리스트** (구현 시 강제할 것):
  - `@libs/cn` (`twMerge(clsx(...))`) 으로만 클래스 합성. template literal 금지.
  - zIndex 는 semantic token. `z-50` 같은 raw 금지.
  - 색은 `g.gray.*`, `g.orange.*`, `kakao.*`, `naver.*` 팔레트. raw hex 금지.
  - `console.*` 금지, `@libs/logger` (pino) 사용.
  - SVG 는 SVGR 컴포넌트 import.
  - `eqeqeq` 준수 (`===`).
  - `any` 금지, `unknown` + 타입 가드.
  - API 호출은 `src/api/<domain>/` 구조 따르고 axios config 에 `reqSchema`/`resSchema` 부착.
  - Toast 는 `createMutationMeta` → `ToastManager`. 훅 내부 직접 `toast()` 금지.
  - 서버 컴포넌트 `params` 는 Promise — `await params` 필수 (Next 15).
  - Form 은 `react-hook-form` + `zodResolver` + `mode: 'all', criteriaMode: 'all'`.

`/coding` 이 내부 Round Agent Protocol 로 병렬 구현 + 통합 + Static Analysis + 테스트 + 커버리지 + 병렬 리뷰 수행.

---

## Phase 4: 브라우저 실조작 검증 (필수)

**테스트 통과로 갈음 금지**. 실제 브라우저에서 조작한다. 프로젝트 `CLAUDE.md` 11-2 규정을 모든 세부 항목까지 준수.

### 4-1. Dev 서버 기동
```
yarn dev  # port 3000
```
백그라운드로 기동 후 port 3000 readiness 확인. 이미 3000 점유 시 사용자에게 알리고 kill 여부 확인.

### 4-2. Playwright / Chrome MCP 실조작

**사용 도구**: `mcp__playwright__browser_*` 우선 (프로젝트가 playwright 설정 보유). chrome-devtools MCP 는 network/console 세부 분석 시 보조.

실행 순서:
1. `browser_navigate` → 타겟 URL (로그인 필요하면 테스트 계정으로 선행 로그인).
2. `browser_snapshot` → 초기 DOM 확인.
3. **목업의 모든 인터랙션을 순차 실행**:
   - 버튼: `browser_click`.
   - 입력: `browser_type` / `browser_fill_form`.
   - 드래그/호버: `browser_drag` / `browser_hover`.
   - 키보드: `browser_press_key`.
   - 각 조작 후 `browser_wait_for` + `browser_snapshot` 으로 상태 전환 확인.
4. **반응형 검증**: `browser_resize` 로 아래 5개 viewport 에서 `browser_take_screenshot` 캡처:
   - 360×800 (2xs)
   - 520×900 (xs)
   - 640×960 (sm)
   - 768×1024 (md)
   - 1024×1366 (lg)
   결과는 `.claude/state/mockup-verify/{viewport}.png` 로 저장.
5. **콘솔**: `browser_console_messages` — error/warn 0. 기존 warning 은 baseline 대비 증가 없는지 확인.
6. **네트워크**: `browser_network_requests` — 4xx/5xx 0. 특히 axios Zod interceptor 의 `schema mismatch` 없음 확인.
7. **i18n (client-web)**: `?lang=en` 으로 재접속하여 동일 플로우 최소 골든 경로 1회. ko/en 양쪽 문자열이 올바르게 치환되는지 확인.
8. **에러 경계 / 로딩 / 빈 상태**: 변경 영향권에 해당하면 최소 1개씩 시나리오 시연.

### 4-3. 목업 vs 실제 시각 비교
- 각 viewport 별 실제 스크린샷과 목업 원본을 나란히 배치 (또는 목업이 HTML 이면 playwright 로 목업 자체도 렌더 후 캡처).
- 육안 diff 로 확인할 항목:
  - 전체 레이아웃 비율.
  - 주요 색상 재현.
  - 간격/정렬.
  - 반응형 전환 타이밍.
- 사용자 선택한 variant 가 제대로 반영되었는지 재확인.
- 불일치 발견 시 Critical 로 분류하고 다음 라운드에서 수정.

### 4-4. E2E 영향 범위면 playwright spec 실행
`yarn playwright test <spec>` 1회. 기존 spec 이 변경 화면을 커버하면 거기에 추가, 없으면 신규 spec 작성.

### 4-5. Dev 서버 정리
검증 완료 후 반드시 `lsof -i :3000` 확인 → 프로세스 kill. 누수 금지.

---

## Phase 5: 병렬 리뷰 라운드 루프

→ ~/.claude/rules/round-agent-protocol.md 적용.

Round Agent 는 매 라운드마다 fresh Agent 3명을 **병렬** 생성한다 (각 리뷰어에게 다른 리뷰어의 존재를 알리지 않는다).

### 5-1. 병렬 리뷰어 구성

**A. 디자인 일관성 리뷰어**
- 기준: 프로젝트 `tailwind.config` + `CLAUDE.md` §6/§7 + 이번 세션에서 Phase 2 에 확정된 variant 결정.
- 체크:
  - 팔레트 외 색상 사용 여부.
  - zIndex raw 숫자 사용 여부.
  - 간격 / 라운드 / 그림자 가 기존 패턴과 정합.
  - 폰트 패밀리 tailwind.config 등록 범위 내.
  - SVG import 방식 (SVGR vs `<img>`).
  - `@libs/cn` 사용.
  - 반응형 breakpoint 가 `2xs/xs/sm/md/lg/mobile` 체계.
  - Phase 4 스크린샷과 목업 간 육안 diff.

**B. 코드 구조 리뷰어**
- 기준: 프로젝트 `CLAUDE.md` §3/§4/§5 + client-web `CLAUDE.md` §1~§10 + ~/.claude/rules/principles.md.
- 체크:
  - `src/api/<domain>/` 구조 준수 (zod 스키마 선행, `keys.ts`, `hook/*`).
  - `reqSchema`/`resSchema` 부착.
  - `createQueryKeys` 사용, 문자열 배열 직접 조립 없음.
  - `MainContainer` 위치 (page.tsx 또는 Contents 최상단, 중첩 금지).
  - 권한: `await auth()` → `createPermissionGraph` → `AllowedFunctions` prop 전달 패턴.
  - 에러: `BaseError` 계층 사용, `instanceof` 분기.
  - `console.*` → `@libs/logger`.
  - `'use client'` / `'use server'` 명시.
  - 기존 `src/modules/*` 재사용 여부 (Popup, ToastManager, ImageUploader, Auth, Fetch 등).
  - DRY: 유사 로직 프로젝트 전역 탐색.
  - SOLID + LoD (`~/.claude/rules/principles.md`).
  - admin-web ↔ client-web parity 영향 (공통 `modules/` 수정 시).

**C. 반응형·접근성·상호작용 리뷰어**
- 기준: Phase 4 실조작 결과 + 목업의 인터랙션 명세.
- 체크:
  - 목업의 모든 인터랙션이 실제로 작동 (Phase 4 시연 결과 대조).
  - 5개 viewport 에서 UI 깨짐 없음 (오버플로, 잘림, 겹침, z-index 충돌).
  - 키보드 내비 (Tab 순서, Escape 로 modal close 등).
  - ARIA 롤/레이블 (button vs div-onclick 혼용 금지, role 적절성).
  - touch target 최소 크기 (mobile breakpoint 기준 44×44 권장).
  - `browser_console_messages` error/warn 0 유지.
  - `browser_network_requests` 4xx/5xx 0 유지.
  - Loading / empty / error 상태 존재 및 적절성.

### 5-2. 리뷰 통합
세 리뷰어의 결과를 통합. 심각도 기준은 ~/.claude/rules/review.md:
- **Critical**: 런타임 에러, 보안, 빌드/타입체크/린터 실패, 사용자 선택한 variant 미반영, 인터랙션 미작동.
- **Major**: 디자인 토큰 위반, 기존 모듈 미재사용(=DRY), principles 커버리지 미달, 반응형 깨짐.
- **Minor**: 네이밍, 중복, shadowing.
- **Nitpick**: 포매팅.

### 5-3. 라운드 결정
- Critical / Major 0 → **PASS** 반환. Phase 6 (보고) 로.
- 있음 → `modification_approaches` 를 상태 파일에 기록하고 **FAIL** 반환.
  - 메인은 Cross-Round Escalation 체크 (최근 2개 라운드의 approach 비교).
  - 같은 issue 에 같은 approach 반복 시 ~/.claude/rules/escalation.md 절차로 fresh 문제 해결 agent 재위임.
  - 그 외는 Phase 3 (구현) 으로 돌아가 수정 → Phase 4 → Phase 5 재실행.
- **Phase 5 의 병렬 리뷰는 라운드당 1회만 수행**. 재리뷰가 필요하면 FAIL 로 반환하고 새 라운드를 시작한다.

### 5-4. 상태 파일 갱신
~/.claude/rules/round-agent-protocol.md 형식에 따라:
- `rounds` 배열에 새 라운드 push (verdict, critical_issues, modification_approaches, round_summary_path).
- `artifact_paths.modified_files` 갱신.
- `artifact_paths.pre_existing_handled` 갱신.
- `artifact_paths.static_analysis_report` 갱신.
- `artifact_paths.coverage_report` 갱신.
- `artifact_paths.variant_decisions` — 디자인 충돌별 사용자 최종 선택 기록.
- `artifact_paths.browser_verification` — Phase 4 스크린샷/콘솔/네트워크 요약 경로.
- `current_verdict`, `critical_issues` 최신화.

---

## Phase 6: 완료 보고

프로젝트 `CLAUDE.md` §11-4 형식을 준수한다:

```
Lint: OK
Test: [파일/테스트명] — [pass/fail]
Build: OK | skipped (사유)
브라우저 검증:
  - URL: [경로]
  - 조작 요약: [목업 인터랙션 실행 결과]
  - 반응형: 2xs/xs/sm/md/lg 전부 통과 | 실패 항목
  - 콘솔: error 0, warn 0
  - 네트워크: 4xx/5xx 0
  - i18n: ko/en 전환 OK (client-web 만 해당)
E2E: [spec] — [pass] | skipped (사유)
```

추가 항목:
- 목업 요구사항 ↔ 구현 매핑 (미구현 있으면 사유).
- **디자인 충돌별 사용자 결정 요약** (conflict-id → 채택 variant).
- 변경된 파일 목록 + 핵심 변경.
- Phase 2 에서 추가된 i18n 키 목록 (ko/en).
- 재사용된 `src/modules/*` 목록 + 신규 생성 컴포넌트 목록.
- Pre-existing 이슈 처리 결과 (같은 커밋 / sub-task / sequential sprint / 사용자 제외 / 미처리).
- 중복 검출 결과 (0건 포함 명시).
- admin-web ↔ client-web parity 에 영향 있으면 명시 (공통 `modules/` 수정 시 반대쪽 앱 동기화 필요).

커밋 여부는 사용자에게 확인. 자동 커밋 금지. 커밋 시 conventional commits + 원자적 커밋 + 파일 지정 `git add`.

---

## 매몰 방지
→ ~/.claude/rules/round-agent-protocol.md Cross-Round Escalation + ~/.claude/rules/escalation.md.

특히 이 스킬에서 매몰되기 쉬운 지점:
- 디자인 충돌의 **반복 재생**: 사용자가 선택한 variant 가 구현에 제대로 반영되지 않아 매 라운드 같은 지적이 나오는 경우. 2회 반복 시 즉시 escalation — fresh subagent 에게 "사용자 결정: variant X" + "현재 구현 결과: variant Y" 사실만 전달하고 근본 원인(tailwind class 충돌 / specificity / 다른 컴포넌트 상속 등) 조사 위임.
- **반응형 breakpoint 뒤섞임**: 2회 같은 breakpoint 에서 깨짐 반복 시 tailwind screens 계약(`2xs/xs/sm/md/lg/mobile`) 이 코드에서 일관되게 쓰이는지 전체 스캔.

## 원칙
- 모든 변경은 ~/.claude/rules/principles.md 준수.
- 프로젝트 `.claude/rules/workflow.md` 가 있으면 해당 Git 워크플로우 준수.
- 기존 디자인 시스템/코드 구조를 최대 존중. 새 패턴 도입 시 사용자에게 근거 제시 후 승인 필요.
- 과도 설계 금지. 목업에 없는 기능 추가 금지.
- 모노레포 parity: `src/modules/` 공통 변경은 admin-web ↔ client-web 동시 반영. 사용자가 "한쪽만" 이라고 명시한 경우만 divergence 허용.
- Phase 간 전환 시 확정 산출물만 전달. 변이안/논쟁 과정 미전달.

## Worktree CWD 준수
~/.claude/rules/round-agent-protocol.md 의 Worktree 절차 준수. Phase 1 시작 시 `$WORKTREE_ROOT` 확정 → Phase 3 `/coding` 호출 시 요구사항 최상단에 `worktree_root: {절대경로}` 명시. Phase 4 dev 서버도 해당 worktree 에서 기동.
