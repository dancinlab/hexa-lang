# .verdicts — claim 검증 결과 영구 보존소

> `claim_verify` — `CLAIMS.tape` 의 각 claim 을 `hexa verify` (g5) 로 돌린
> **raw stdout 을 그대로** 보존한다. LLM 자가판정·paraphrase 금지.

## 레이아웃

```
.verdicts/
  <slug>/
    <claim-id>.txt      ← hexa verify / 빌드 fixpoint 원문 (verbatim)
    .gitkeep            ← 아직 verdict 미보존 stub slug 자리표시
  <slug>.tape           ← (선택) slug 전체 verdict 매트릭스 요약
```

## 규칙

- 파일명 = `CLAIMS.tape` 의 `raw =` 포인터와 1:1 일치.
- 내용 = 검증 명령의 **표준출력 원문**. 재가공·요약·의역 금지.
- 🟠 INSUFFICIENT / 🟡 citation-only / ⚪ fenced 는 게이트 통과 불가
  (`paper_gate`) — 보존은 하되 논문 섹션 링크로 쓰지 않는다.
- terminal (🔵 / 🟢 / 🔴 CLOSED-negative) 만 `PAPER/<slug>/` 섹션에 링크.
- hexa-lang 의 `g5` `hexa verify` 규율이 이 surface 의 SSOT — 아틀라스 정리는
  닫힌형/수치 재계산이 가능하므로 🔵/🟢 게이트와 정확히 맞물린다.

## 현 보존 상태 (seed)

| slug | claim | tier | 보존 |
|------|-------|------|------|
| `atlas-divisor-sum-sigma` | σ(6)=12 닫힌형 약수합 | 🔵 SUPPORTED-FORMAL | ✅ REAL (`atlas_sigma_six.txt`) |
| `canon-codegen-correctness` | CHSH Tsirelson 2√2 (ε=1e-9) | 🟢 SUPPORTED-NUMERICAL | ✅ REAL (`canon_chsh_tsirelson.txt`) |
| `compiler-selfhost-fixpoint` | gen1≡gen2 byte-identical .s | (미보존) | ⬜ STUB (`.gitkeep`) — md5 증거는 COMPILER.md S3, verdict 미작성 |
