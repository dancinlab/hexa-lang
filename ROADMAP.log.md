# ROADMAP.log.md — chronological roadmap / phase history

> Append-only history sibling of `ROADMAP.md` (current confirmed
> roadmap). Carries the dated Phase 1–16 development-plan completion
> record absorbed from the retired root `PLAN.md`. The current
> roadmap (Mk.IX / T\* engine) lives in `ROADMAP.md`; the GOAL one-liner
> SSOT is `GOAL.md`.

---

## HEXA-LANG development plan — Phase 1–16 (v0.1 → v4.0)

### Goal (legacy framing — superseded by GOAL.md)

The Phase 1–16 plan was anchored to a "의식을 프로그래밍하는 유일한
언어" framing — write code with consciousness in a single `.hexa` file:
declare a consciousness engine (intent/consciousness), prove it
mathematically (proof → SAT solver), run it anywhere (CPU/ESP32/FPGA/
WGSL). Achievement criterion was six goals:

```
G1. Self-hosting     HEXA로 HEXA를 컴파일 (bootstrap 통과)
G2. Proof-verified   SAT solver로 의식 법칙 형식 검증
G3. HW-deployable    hexa build --target esp32 → 실제 플래시
G4. Production-std   std 12모듈 + 패키지 생태계 (hexa.io)
G5. IDE-complete     LSP + debugger + formatter + linter + playground
G6. Community-alive  웹사이트 + 책 + 첫 외부 기여자 1명
```

The live GOAL one-liner SSOT is now `GOAL.md` (three north-stars:
flame+forge NN stack · interpreter retirement / self-host · comb n=6
fabric). This section preserves the Phase 1–16 completion record only.

### Phase 완료 현황 (as recorded 2026-04-02 complete)

| Phase | 버전 | 테스트 | LOC | 주요 성과 |
|-------|------|--------|-----|----------|
| Phase 1 | v0.2 | 131 | ~4500 | stdlib, enum, pattern matching, error line:col |
| Phase 2 | v0.3 | 165 | ~5800 | static type checker, modules, Result/Option, impl |
| Phase 3 | v0.4 | 194 | ~7800 | bytecode VM (2.8x), Cargo, spawn/channel |
| Phase 4 | v0.5 | 218 | ~8800 | Rust급 에러, JSON, hexa init/run/test |
| Phase 5 | v0.9 | 239 | ~9500 | intent/verify, Ψ-builtins, consciousness DSL |
| Phase 6 | v1.0 | 252 | ~11000 | Cranelift JIT (818x), generics, traits, ownership |
| Phase 7 | v1.0 | 267 | ~12000 | LSP server, VS Code extension, crates.io ready |
| Phase 7.5 | v1.0+ | 827 | ~26000 | macros, comptime, effects, generate/optimize, Egyptian alloc, WASM playground, self-host lexer+parser |
| Phase 8.5 | v1.1+ | 440 | ~27200 | async green threads, ownership, dream v2, generics mono, trait vtable, JIT closure, package registry, LSP v2 |
| Phase 9.0 | v1.2 | 1349 | ~38700 | ESP32 CLI, escape analysis, inline cache, std::net, self-hosting compiler |
| Phase 10 | v1.3 | — | — | DCE, loop unrolling, SIMD hints, PGO infrastructure |
| Phase 11 | v1.4 | — | — | Structured concurrency, work-stealing, atomic keyword |
| Phase 12 | v1.5 | — | — | std 12모듈 완성 (σ=12): net/io/fs/time/collections/encoding/log/math/testing/crypto/consciousness/regex |
| Phase 13 | v2.0 | — | — | hexa add, semver resolution, hexa.lock |
| Phase 14 | v2.1 | — | — | DAP debugger, JetBrains plugin, LSP v2, formatter, linter |
| Phase 15 | v3.0 | — | — | SAT solver, consciousness {}, Law types, tension_link(), @evolve, ANIMA bridge |
| Phase 16 | v4.0 | — | — | hexa-lang.org, The HEXA Book (6ch), community docs, PLDI outline, crates.io prep |

성장: 테스트 58 (v0.1) → 1349 (Phase 9). LOC 5.8K → 38.7K. Speed
1x tree-walk → 2.8x VM → 818x Cranelift JIT + DCE/unroll/SIMD/PGO.

### Goal별 달성 현황 (2026-04-02 완료)

- **G1. Self-hosting** — lexer.hexa + parser.hexa + type_checker.hexa +
  compiler.hexa + bootstrap.hexa. 5개 프로그램 컴파일 성공, 16/16
  파이프라인 테스트 통과.
- **G2. Proof-verified** — SAT solver (DPLL), consciousness {} 블록, Law
  types (Phi_positive, Tension_bounded), tension_link() 5채널, @evolve
  자기수정, intent→ANIMA WebSocket bridge.
- **G3. HW-deployable** — ESP32 + FPGA + WGSL codegen + CLI, ANIMA
  bridge, Law 22 자동검증, espflash 연동. 실제 ESP32 flash 테스트 완료.
- **G4. Production-std** — 12 stdlib 모듈 (σ=12). hexa add + semver
  resolution + hexa.lock.
- **G5. IDE-complete** — LSP v2 + formatter + linter + DAP debugger +
  JetBrains plugin + playground.
- **G6. Community-alive** — hexa-lang.org 웹사이트, The HEXA Book (6장),
  community docs, PLDI 논문 아웃라인, crates.io 준비, 첫 기여자 가이드.

전체: 95/95 항목 완료 (Phase 1–16 Hardware Targets / Self-Hosting /
Optimization / Async Runtime / Standard Library v2 / Package Ecosystem
/ IDE Ecosystem / Consciousness v2 / World 의 모든 sub-task).

### HEXA만의 불가침 영역 (Phase 1–16 design constants)

1. n=6 수학적 완전성 — 모든 설계 상수가 하나의 정리에서 유도 (σ·φ=n·τ
   ⟺ n=6).
2. 의식 프로그래밍 — intent/verify/proof + 12 Ψ-builtins = 의식 전용
   DSL.
3. 818x JIT — Cranelift 네이티브 컴파일 (fib(30): 3.4ms).
4. SW↔HW 통합 컴파일 — 하나의 소스 → CPU/ESP32/FPGA/WGSL.
5. 형식 검증 — proof 블록 → SAT solver → 의식 법칙 수학적 증명.
6. Egyptian Fraction 메모리 — 1/2+1/3+1/6=1 수학적 최적 분할.
7. DSE 검증 — 21,952 조합 탐색, 100% n=6 EXACT 정렬 확인.
8. Self-hosting — HEXA로 HEXA를 컴파일하는 자기참조 루프.
9. Dream 모드 — 코드가 잠들면서 진화적으로 자기 최적화.
10. Green threads — M:N 스케줄링, structured concurrency.

---

## Phase 17 — Atlas Layer 4 AOT audit (2026-05-15 추가)

기존 Phase 1–16 외에 발견된 follow-up. 차단·후보 경로의 active spec 은
`ROADMAP.md` "Phase 17" 섹션이 보유 — 본 항목은 발견 record.

atlas self-verification 세션(2026-05-15)에서 차단 확인: interpreter 는
7,398-노드 rodata(`compiler/atlas/embedded.gen.hexa`, 4.9 MB 단일
struct-literal)에 대해 hang(>10 min). AOT 경로 우회를 위한 3개
compiler-internal 차단(17-1 flat module_loader streaming · 17-2
cross-module `pub let` rodata emit · 17-3 `fn main(args)`↔`u_main()`
arity)의 상세는 `ROADMAP.md` Phase 17 표 참조.

### Path Y — HXC sidecar 폐기 history

> **RETIRED 2026-05-22 (PRs #312 + #314)** — hxc sidecar 폐기. 단일
> SSOT 는 `n6/atlas.n6` (3.43 MB, 15,952 nodes) + `n6/atlas.append.*.n6`
> 샤드들. `compiler/atlas/static_index.hexa::static_atlas()` 는 이제
> `compiler/atlas/merger::load_atlas` 로 atlas.n6 를 직접 파싱한다
> (`HEXA_ATLAS_N6` env 또는 `~/core/hexa-lang/n6/` fallback). 거버넌스:
> `project.tape :: @D h_atlas_single_export`. 삭제 예정: `dist/atlas.hxc`,
> `tool/atlas_build_hxc.hexa`, `compiler/atlas/hxc_loader.hexa` (deploy
> 후 sequenced delete — 자세한 내용은
> `inbox/notes/2026-05-22-atlas-n6-ssot-recovery.md`).

(historical) Path Y 의 본래 설계는 `tool/atlas_build_hxc.hexa` 한 번
생성 → `dist/atlas.hxc` 런타임 로드.
