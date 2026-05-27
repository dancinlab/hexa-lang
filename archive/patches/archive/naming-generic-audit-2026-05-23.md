# naming-generic audit — 2026-05-23

`@D naming_generic` (PR #384) governance landing 직후의 전수조사 결과.
첫 rename PR #387 (`codegen_c2.hexa` → `codegen.hexa`) 외 후속 후보는
모두 legitimate versioning 으로 판명.  다음 cycle 이 이 audit 을 재실행
하지 않도록 결과를 기록.

## TL;DR

**1 개** rename LANDED · **8 개** legitimate-skip · **3 개** time-gated defer.

| status | count |
|---|---:|
| ✅ renamed | 1 |
| ⏭ legitimate (no rename) | 8 |
| ⏳ time-gated (re-audit after gate) | 3 |

## ✅ Renamed (PR #387)

| from | to |
|---|---|
| `self/codegen_c2.hexa` | `self/codegen.hexa` |
| `self/test_codegen_c2_extended.hexa` | `self/test_codegen_extended.hexa` |

5 build-critical path strings updated in `main.hexa` ·
`self_hosting_scaffold.hexa` · `test_ic_slot_regen.hexa` ·
`test_codegen_extended.hexa`.

## ⏭ Legitimate (do NOT rename)

| path | reason | evidence |
|---|---|---|
| `self/forge/forge_tier_v1.{c,h}` | RFC 050 §6.7 ABI lock — "any ABI change requires a _v2 bump" | `self/forge/forge_tier_v1.h` 파일 header L4-6 |
| `self/stdlib/hxc_composite_chain_v2.hexa` | wire-format version lock (v1 coexists; per-format-version isolation) | `inbox/patches/hxc-v2-no-downstream-library-api.md` |
| `self/ml/react_v2_agent.hexa` | distinct ML artifact (#220) ≠ `react_agent.hexa` (#116) — parallel design exploration | both file headers list distinct ML IDs |
| `attr_format/module/attr_v{1..5}.hexa` | evolutionary spec snapshots (all 5 are deliverables) | dir structure: 5 parallel modules, none supersede |
| `grammar_format/module/grammar_v{1..5}.hexa` | same | same pattern |
| `self/ml/t1_v{2..16}_*.hexa` | ML experiment ladder — each version = distinct ablation | 15 parallel experiment files |
| `self/cuda/experiments/*_v{2,3}*.cu` | CUDA experiment ladder | dir name = `experiments` |
| `firmware/boards/*/RELEASE_NOTES_v*.md` | legitimate hardware release tags | `RELEASE_NOTES` filename = release-tagged by design |

## ⏳ Time-gated (re-audit when gate fires)

| path | gate | doc |
|---|---|---|
| `self/native/codegen_c2_v2.{c,hexanoport}` | ROI #153 P7-7 v3==v4 fixpoint closure | `doc/plans/runtime_c_purge.md` Phase C |
| `self/native/{lexer,parser,type_checker}_v2.c` | same | same |
| `build/hexa_v2_linux`, `dist/linux-x86_64/hexa_v2`, build script `tool/build_hexa_v2_linux.hexa` | ROI #18 `aprime_cc` self-host (drops `hexa_v2` dependency) | `compiler/PLAN.md` L45 |

`hexa_v2` binary 는 곧 retire 예정인 bootstrap transpiler — rename 보다
retirement 가 먼저.  Retirement 시 build/ + dist/ + tool/ 의 모든 ref 가
자연 제거됨.

## 적용 원칙

`naming_generic` 의 dont 는 `bake version in filenames (`_c2` · `_v2` ·
`_v1` · `_old` · `_legacy`); supersede by overwriting` — 핵심은
**supersede by overwriting**.  공존하는 ABI / wire-format / experiment
ladder 처럼 "각 버전이 독립 deliverable" 인 경우는 적용 대상 아님.

| 패턴 | 적용? |
|---|---|
| `_v2` 가 `_v1` 을 대체할 의도 (drift) | ✅ rename |
| `_v1`/`_v2` 가 영구 coexist (ABI · wire-format) | ⏭ keep |
| 단일 release tag (`RELEASE_NOTES_v1.0.0.md`) | ⏭ keep |
| experiment ladder (`t1_v2..v16`) | ⏭ keep |
| 곧 retire 예정 (`hexa_v2` → `aprime_cc`) | ⏳ defer (retire 가 cleanup) |

## 다음 audit trigger

- ROI #153 fixpoint closure → `_v2.c` quintet purge cycle.
- ROI #18 `aprime_cc` self-host → `hexa_v2` retirement cycle.
- 새 `_v?` 파일 작성 시 — `naming_generic` 위반 여부 즉시 판정.
