---
name: paper_review
description: 논문 분석/리뷰. 요약, 비평, 풀리뷰 깊이 조절 가능.
argument-hint: [요약|비평|풀리뷰]
context: fork
agent: general-purpose
model: opus
effort: medium
allowed-tools: Read, Glob, Grep
disable-model-invocation: false
---

# Paper Review

논문 분석/리뷰 스킬. `/paper_review 요약`, `/paper_review 비평`, `/paper_review 풀리뷰`로 깊이 조절.

## 스케일링
- **요약**: 핵심 기여 + 결과 중심, 비평 최소화.
- **비평**: methodology + experimental design 중심 비판.
- **풀리뷰**: 아래 전체 프레임워크 적용.

## 분석 프레임워크

### 1. Problem & Positioning
- 어떤 gap을 다루는가. 선행 연구 대비 위치.

### 2. Novelty 평가 (4단계)
- **Incremental**: 기존 방법의 소폭 개선.
- **Moderate**: 기존 프레임워크 내 의미 있는 새 접근.
- **Significant**: 새 프레임워크 또는 패러다임 제시.
- **Fundamental**: 분야의 기본 가정을 재정립.

### 3. Contribution 분해
- 이론 / 방법론 / 실험(데이터셋·벤치마크) / 시스템·아티팩트.
- 각 축의 기여 수준을 개별 평가.

### 4. Methodology
- 실험 설계의 적절성.
- Baseline 선정 근거와 공정성.
- Ablation study 유무 및 충분성.
- 재현 가능성 (코드/데이터 공개 여부, 하이퍼파라미터 명시).
- 통계적 유의성 보고 여부. 미보고 시 주의 표시.

### 5. Limitations
- 저자가 밝힌 한계.
- 저자가 누락한 한계 (별도 지적).

### 6. Verdict
- Accept / Weak Accept / Borderline / Weak Reject / Reject.
- 판정 근거를 2~3문장으로.

## 논문 유형별 가중치
| 평가 축 | Empirical | Theoretical | System | Survey |
|---------|-----------|-------------|--------|--------|
| Novelty | ●●●○ | ●●●● | ●●○○ | ●○○○ |
| Methodology | ●●●● | ●●○○ | ●●●○ | ●●○○ |
| Contribution | ●●●○ | ●●●● | ●●●● | ●●●○ |
| Reproducibility | ●●●● | ●○○○ | ●●●○ | N/A |

## 규칙
- 모든 평가에 근거 인용: (Section X, Table Y, Figure Z).
- 객관적 분석과 주관적 의견을 `[객관]` `[주관]`으로 명시 구분.
- 수식/용어는 원문 notation 유지 + 직관적 설명 병기.
- 한국어 분석 시 학술 용어는 영어 병기: 주의 메커니즘(attention mechanism).
