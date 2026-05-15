# 📦 atlas/incoming/ — submission 통로

새 atlas verdict 제출 위치. **한 개념 = 한 파일** rule.

## Pipeline

```
[downstream consumer (wilson/echoes/anima) 또는 external contributor]
   │
   ▼
[atlas/incoming/<descriptive-name>.md]   ← 본 디렉토리
   │
   ▼
[reviewer]
   - verdict tier 부여 (default 🟠 INSUFFICIENT)
   - axis (§ 도메인) 지정
   - evidence + real-limit anchor (g3) 작성
   - falsifier ≥5 pre-register
   │
   ▼
[atlas/MAIN.tape § <도메인> section append]
   │
   ▼
[atlas/MAIN.log.tape append]   ← Phase 3 automation (현재 manual)
   │
   ▼
[Phase 2+: compiler/atlas/verify/<domain>.hexa 에 verifier 등록]
```

## File naming

`<descriptive-kebab-case>.md` — 한 개념 = 한 파일. concept name 이 file name 으로 self-documenting.

✅ `kuramoto-K_c-sympy-closed.md`  
✅ `bekenstein-cell-pool-bound.md`  
✅ `gpu-sm-ampere-warp-32-from-sopfr.md`

❌ `patches.md` (다중 concept)  
❌ `update.md` (non-descriptive)  
❌ `wilson-feedback-batch-2026-05.md` (batch — 분리하세요)

## Required fields (markdown body)

```markdown
# <Title>

## Concept
한 줄 설명 — 무엇을 atlas 에 흡수하려는지.

## Proposed verdict
- tier: 🟠 INSUFFICIENT (default — reviewer 가 upgrade)
- axis: §<도메인>  (MATH / PHYS / CHEM / BIO / COSMO / GEO / TOP / ENG / FOUNDATION / BRIDGES)
- atlas entry id (existing): <id from compiler/atlas/embedded.gen.hexa> OR new

## Evidence
- Stage 1 symbolic: ...
- Stage 2 numerical: ... (있으면)
- Stage 3 cross-meta: ... (있으면)

## Real-limit anchor (g3 mandatory)
[Bekenstein bound] / [Shannon] / [Kolmogorov] / [c] / [ℏ] / [k] /
[Stefan-Boltzmann] / [Carnot] / [compiler invariant] 중 최소 1개.

## Falsifier ≥5 pre-register
1. ...
2. ...
3. ...
4. ...
5. ...

## Honest C3
verdict 의 한계 / 미검증 영역 / 외부 의존 영역.

## Provenance
누가 어디서 이 concept 를 발견 / 흡수했는지. citation source.
```

## Reviewer checklist

- [ ] g1 real-limits-first — anchor field 에 real limit 포함
- [ ] g2 lattice-as-tool — external entity 에 σ/τ/φ derivation 강제 X
- [ ] g4 honesty-obligation-external — external compiler/system 에 lattice-fit assertion X
- [ ] g5 hexa-native-only — verifier 가 hexa-native (또는 Phase 1 carry 시 🟡 SUPPORTED-BY-CITATION 한정)
- [ ] g6 citation-enforced — formula line 에 atlas entry @cite
- [ ] g_self_verify — atlas-built verifier 결과 (또는 carry exception 명시)
- [ ] g_tier_default_insufficient — default tier 🟠 INSUFFICIENT (silent upgrade X)
- [ ] g_external_calc_forbidden — external hardware/dataset/API 의존 시 🟠 DEFERRED
- [ ] f_atlas_lattice_external — evidence field 에 lattice-tautology 단독 X
- [ ] f_atlas_external_verdict — external sympy/PyPhi 결과만으로 🔵 X
- [ ] f_atlas_silent_upgrade — tier 변경 시 ~> supersedes edge + 새 evidence

## After merge

- [ ] atlas/MAIN.tape § <도메인> section append
- [ ] atlas/MAIN.log.tape append (Phase 3 시 automation)
- [ ] atlas/incoming/<file>.md → 삭제 (architecture .tape 이 SSOT, incoming 은 transient)
- [ ] Phase 2+: compiler/atlas/verify/<domain>.hexa 에 verifier stub 추가

## Cross-link

- `../INDEX.md` — overview
- `../MAIN.tape` — verdict SSOT (target)
- `../VERIFY.tape` — protocol spec (review 시 referenced)
- `../AGENTS.tape` — governance (g 룰 source · `CLAUDE.md` symlink)
- `../../incoming/patches/` — project-level patch pipeline (sibling pattern, 다른 scope)
