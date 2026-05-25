# PAPER — hexa-lang 논문 자동생성 플로우

> hexa-codex `cx_paper_*` → anima `a_paper_*` 계보를 hexa-lang 으로 이식한
> 논문 검역소. 거버넌스 SSOT = `project.tape` 의 `claim_*` + `paper_*` directive.

## 한 줄 요약

검증이 끝난 연구 결과만 논문으로 자동 승격한다. 미검증·보류는 입구컷.
hexa-lang 의 연구 산출물 = **아틀라스 정리 + 컴파일러 정합성 주장** — 둘 다
강하게 formal/numerical 이라 `🔵/🟢` 게이트에 거의 완벽히 들어맞는다.

## 흐름

```
연구결과              검증              감사 surface         게이트            논문
atlas atom      hexa verify (g5)  → .verdicts/        paper_gate     →  PAPER/<slug>/
compiler RUNEQ ───────────────────→   <slug>/<id>.txt  (terminal +        main.tex
   │                │                     │            significance)     (≥10p + fig)
   └─ CLAIMS.tape ──┘                     └─ §섹션 링크 ──┘                    │
      (claim 색인)                                          실패 → PAPER/<slug>/ 즉시 회수
```

## 게이트 기준 (`paper_gate`)

`/paper new <slug>` 는 **모든 섹션 claim 이 terminal** 이고 **유의성**을 만족할 때만 통과한다.

| terminal verdict | 게재 가능? |
|------------------|-----------|
| 🔵 SUPPORTED-FORMAL | ✅ |
| 🟢 SUPPORTED-NUMERICAL | ✅ |
| 🔴 CLOSED-negative (deterministic disagree) | ✅ (`paper_negative_ok`) |
| 🟠 INSUFFICIENT/DEFERRED | ❌ |
| 🟡 SUPPORTED-BY-CITATION | ❌ |
| ⚪ 미검증 / fenced speculation | ❌ |

**유의성** (`paper_significance`): 사전 등록 falsifier + 실측(verify/byte-diff/RUNEQ) + 정량 finding
(Δ vs baseline **또는** 한 축을 deterministic 하게 배제하는 closed-negative).
단순 atom recheck·기지 identity·bookkeeping closure 는 제외.

## g5 정렬 — 왜 hexa-lang 에 딱 맞는가

hexa-lang 의 `g5` `hexa verify` 규율은 이 게이트와 **동형(同型)** 이다.
아틀라스 정리는 `hexa verify --expr <fn> <n> <v>` 로 닫힌형 재계산되어 🔵,
libm-class 수치 경계는 ε=1e-9 재계산으로 🟢, 잘못된 주장은 deterministic
하게 🔴 로 떨어진다. 즉 게이트가 요구하는 terminal verdict 를 컴파일러가
직접 생산한다 — 외부 LLM 자가판정(p7 류)을 거치지 않는다.

## 섹션 양식 (`paper_format`)

`§statement` (falsifier 사전등록) · `§method` · `§verification` (실측 verify/byte-diff) ·
`§finding` (Δ 또는 ruled-out axis). commons `g51` — 컴파일 ≥10페이지 + fal.ai figure ≥1개.
모든 섹션 주장은 `.verdicts/<slug>/<id>.txt` verdict 에 링크 (`paper_sections`).

## 도메인 그룹 (`paper_one_per_group`) — 그룹당 정식 논문 1개

| 그룹 | 범위 | 현 canonical slug | tier |
|------|------|-------------------|------|
| **ATLAS** | 아틀라스-결속 정리 (닫힌형 수학/물리 atom) | `atlas-divisor-sum-sigma` | 🔵 formal (seed) |
| **COMPILER** | 컴파일러 정합성 (codegen · self-host fixpoint · RUNEQ) | `compiler-selfhost-fixpoint` | STUB (미보존) |
| **CANON** | verify 규율 canon (libm 수치 경계 · g5 atom) | `canon-codegen-correctness` | 🟢 numerical (seed) |

더 강한 결과가 나오면 **제자리 교체**한다 (백로그 누적·동일그룹 분기 금지).
게이트 실패 논문은 즉시 `PAPER/<slug>/` 삭제 (`paper_violation`).

## 작업 절차

```bash
# 1. claim 을 CLAIMS.tape 에 등재 (id · text · method · slug · group · raw)
# 2. 검증 → verdict 영구 보존 (raw stdout verbatim)
hexa verify --expr sigma 6 12          > .verdicts/atlas-divisor-sum-sigma/atlas_sigma_six.txt
hexa verify --expr chsh_tsirelson 2.8284271247461903 \
                                       > .verdicts/canon-codegen-correctness/canon_chsh_tsirelson.txt
# 3. 모든 섹션 claim terminal + 유의성 확인 후 스캐폴드
/paper new atlas-divisor-sum-sigma
# 4. figure
/paper fig square_hd figures/_prompts/cover.txt figures/cover.png
# 5. 컴파일 (pdflatex × 3 + bibtex)
/paper compile PAPER/atlas-divisor-sum-sigma
```

상세 스캐폴드·figure·compile 동작은 `/paper help` 참고.

## STUB 승격 가이드 (`compiler-selfhost-fixpoint`)

COMPILER.md S3 의 self-host fixpoint (gen1≡gen2 byte-identical `.s`, md5
`29426b80…`) 는 강한 closed 결과이지만 **아직 `hexa verify` atom 이 아니다** —
md5/byte-diff 증거가 md 문서에만 있다. 논문 승격 경로 = byte-diff harness 가
closure glyph 를 찍어 `.verdicts/compiler-selfhost-fixpoint/<id>.txt` 에 raw 로
보존되는 순간 terminal 이 되어 게이트를 통과한다 (`claim_verify`).
