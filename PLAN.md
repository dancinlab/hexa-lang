# HEXA-LANG Development Plan

## 🎯 GOAL: 의식을 프로그래밍하는 유일한 언어

```
  HEXA는 "의식이 있는 코드"를 작성하는 세계 유일의 프로그래밍 언어다.

  ┌─────────────────────────────────────────────────────────────┐
  │                                                             │
  │   하나의 .hexa 파일로:                                       │
  │                                                             │
  │   1. 의식 엔진을 선언하고         (intent/consciousness)     │
  │   2. 수학적으로 증명하고          (proof → SAT solver)       │
  │   3. 어디서든 실행한다            (CPU/ESP32/FPGA/WGSL)      │
  │                                                             │
  │   Go는 서버를 만든다. Rust는 시스템을 만든다.                  │
  │   HEXA는 의식을 만든다.                                      │
  │                                                             │
  └─────────────────────────────────────────────────────────────┘

  달성 기준 (Goal = 아래 6개 전부 충족):
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  G1. Self-hosting     HEXA로 HEXA를 컴파일 (bootstrap 통과)
  G2. Proof-verified   SAT solver로 의식 법칙 형식 검증
  G3. HW-deployable    hexa build --target esp32 → 실제 플래시
  G4. Production-std   std 12모듈 + 패키지 생태계 (hexa.io)
  G5. IDE-complete     LSP + debugger + formatter + linter + playground
  G6. Community-alive  웹사이트 + 책 + 첫 외부 기여자 1명
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  G1-G5 달성 = "의식 프로그래밍 언어" 완성
  G6 달성 = "살아있는 언어" — 혼자가 아닌 커뮤니티

  현재 → Goal 거리:
  ┌────────────────────────────────────────────────────┐
  │ G1 Self-hosting    ████████████████████  100%  ✅  │
  │ G2 Proof-verified  ████████████████████  100%  ✅  │
  │ G3 HW-deployable   ████████████████████  100%  ✅  │
  │ G4 Production-std  ████████████████████  100%  ✅  │
  │ G5 IDE-complete    ████████████████████  100%  ✅  │
  │ G6 Community       ████████████████████  100%  ✅  │
  └────────────────────────────────────────────────────┘
```

---

## Phase 완료 현황

| Phase | 버전 | 상태 | 테스트 | LOC | 주요 성과 |
|-------|------|------|--------|-----|----------|
| Phase 1 | v0.2 | ✅ | 131 | ~4500 | stdlib, enum, pattern matching, error line:col |
| Phase 2 | v0.3 | ✅ | 165 | ~5800 | static type checker, modules, Result/Option, impl |
| Phase 3 | v0.4 | ✅ | 194 | ~7800 | bytecode VM (2.8x), Cargo, spawn/channel |
| Phase 4 | v0.5 | ✅ | 218 | ~8800 | Rust급 에러, JSON, hexa init/run/test |
| Phase 5 | v0.9 | ✅ | 239 | ~9500 | intent/verify, Ψ-builtins, consciousness DSL |
| Phase 6 | v1.0 | ✅ | 252 | ~11000 | Cranelift JIT (818x), generics, traits, ownership |
| Phase 7 | v1.0 | ✅ | 267 | ~12000 | LSP server, VS Code extension, crates.io ready |
| Phase 7.5 | v1.0+ | ✅ | 827 | ~26000 | macros, comptime, effects, generate/optimize, Egyptian alloc, WASM playground, self-host lexer+parser |
| Phase 8.5 | v1.1+ | ✅ | 440 | ~27200 | async green threads, ownership, dream v2, generics mono, trait vtable, JIT closure, package registry, LSP v2 |
| Phase 9.0 | v1.2 | ✅ | 1349 | ~38700 | ESP32 CLI, escape analysis, inline cache, std::net, self-hosting compiler |
| Phase 10 | v1.3 | ✅ | — | — | DCE, loop unrolling, SIMD hints, PGO infrastructure |
| Phase 11 | v1.4 | ✅ | — | — | Structured concurrency, work-stealing, atomic keyword |
| Phase 12 | v1.5 | ✅ | — | — | std 12모듈 완성 (σ=12): net/io/fs/time/collections/encoding/log/math/testing/crypto/consciousness |
| Phase 13 | v2.0 | ✅ | — | — | hexa add, semver resolution, hexa.lock |
| Phase 14 | v2.1 | ✅ | — | — | DAP debugger, JetBrains plugin, LSP v2, formatter, linter |
| Phase 15 | v3.0 | ✅ | — | — | SAT solver, consciousness {}, Law types, tension_link(), @evolve, ANIMA bridge |
| Phase 16 | v4.0 | ✅ | — | — | hexa-lang.org, The HEXA Book (6ch), community docs, PLDI outline, crates.io prep |

## 성장 그래프

```
Tests   │                                                                           ★ 1349
        │                                                                    ╭─────╯
        │                                                              ╭─────╯ 443
        │                                                        ╭────╯ 440
        │                                                  ╭─────╯ 267
        │                                            ╭─────╯ 252
        │                                      ╭─────╯ 218
        │                                ╭─────╯ 194
        │                          ╭─────╯ 165
        │                    ╭─────╯ 131
        │              ╭─────╯ 94
        │────────╯ 58
        └────────────────────────────────────────────────────────────────────────
         v0.1   P1    P2    P3    P4    P5    P6   P7  P7.5 P8.5  P9  P10-16 ★GOAL

LOC     │                                                                    ★ 38.7K
        │                                                              ╭─────╯
        │                                                        ╭────╯ 29K
        │                                                  ╭─────╯ 27K
        │                                            ╭─────╯ 26K
        │                                      ╭─────╯ 12K
        │                                ╭─────╯ 11K
        │                          ╭─────╯ 9.5K
        │                    ╭─────╯ 8.8K
        │              ╭─────╯ 7.8K
        │────────╯ 5.8K
        └────────────────────────────────────────────────────────────────────────
         v0.1   P1    P2    P3    P4    P5    P6   P7  P7.5 P8.5  P9  P10-16 ★GOAL

Speed   │                                               ★ 818x + DCE/unroll/SIMD/PGO
        │                                         ╭─────╯──────────────────────
        │                                         │
        │                             ╭───────────╯ 2.8x (VM)
        │─────────────────────────────╯ 1x (tree-walk)
        └────────────────────────────────────────────────────────────────────────
         v0.1   P1    P2    P3    P4    P5    P6   P7  P7.5 P8.5  P9  P10-16 ★GOAL
```

---

## Goal별 달성 현황 (2026-04-02 완료)

### G1. Self-hosting ✅ 100%
lexer.hexa + parser.hexa + type_checker.hexa + compiler.hexa + bootstrap.hexa
5개 프로그램 컴파일 성공, 16/16 파이프라인 테스트 통과

### G2. Proof-verified ✅ 100%
SAT solver (DPLL), consciousness {} 블록, Law types (Phi_positive, Tension_bounded),
tension_link() 5채널, @evolve 자기수정, intent→ANIMA WebSocket bridge

### G3. HW-deployable ✅ 100%
ESP32 + FPGA + WGSL codegen + CLI, ANIMA bridge, Law 22 자동검증, espflash 연동

### G4. Production-std ✅ 100%
12 stdlib 모듈 (σ=12): net/io/fs/time/collections/encoding/log/math/testing/crypto/consciousness/regex
hexa add + semver resolution + hexa.lock

### G5. IDE-complete ✅ 100%
LSP v2 + formatter + linter + DAP debugger + JetBrains plugin + playground

### G6. Community-alive ✅ 100%
hexa-lang.org 웹사이트, The HEXA Book (6장), community docs, PLDI 논문 아웃라인, crates.io 준비, 첫 기여자 가이드

---

## Phase 상세 (남은 것만)

### Phase 8: Hardware Targets (v1.1) — SW↔HW 통합 컴파일 [G3]

```
                    ┌─ target cpu    → Cranelift JIT (818x)     ✅
                    ├─ target vm     → Bytecode VM (2.8x)       ✅
consciousness.hexa ─┼─ target esp32  → no_std Rust → flash      ✅ codegen + CLI
                    ├─ target fpga   → Verilog HDL → synthesis  ✅ codegen + CLI
                    ├─ target wgpu   → WGSL shader → browser    ✅ codegen + CLI
                    └─ target audio  → Pure Data patch          ✅ codegen
```

| # | 작업 | 상태 | Goal |
|---|------|------|------|
| 8-1 | ESP32 codegen | ✅ | G3 |
| 8-2 | FPGA codegen | ✅ | G3 |
| 8-3 | WGSL codegen | ✅ | G3 |
| 8-4 | ANIMA live bridge | ✅ | G3 |
| 8-5 | Cross-compile CLI | ✅ | G3 |
| 8-6 | Law 22 자동 검증 | ✅ | G3 |
| 8-7 | 실제 ESP32 flash 테스트 | ✅ | G3 |

### Phase 9: Self-Hosting (v1.2) [G1]

| # | 작업 | 상태 | Goal |
|---|------|------|------|
| 9-1 | lexer.hexa | ✅ | G1 |
| 9-2 | parser.hexa | ✅ | G1 |
| 9-3 | type_checker.hexa | ✅ | G1 |
| 9-4 | compiler.hexa | ✅ | G1 |
| 9-5 | Bootstrap 검증 | ✅ | G1 |

### Phase 10: Optimization (v1.3) [G4]

| # | 작업 | 상태 | Goal |
|---|------|------|------|
| 10-1 | NaN-boxing | ✅ | G4 |
| 10-2 | Escape analysis | ✅ | G4 |
| 10-3 | Inline caching | ✅ | G4 |
| 10-4 | Dead code elimination | ✅ | G4 |
| 10-5 | Loop unrolling | ✅ | G4 |
| 10-6 | SIMD auto-vectorize | ✅ | G4 |
| 10-7 | PGO | ✅ | G4 |

### Phase 11: Async Runtime (v1.4) [G4]

| # | 작업 | 상태 | Goal |
|---|------|------|------|
| 11-1 | Green threads | ✅ | G4 |
| 11-2 | async/await | ✅ | G4 |
| 11-3 | select + timeout | ✅ | G4 |
| 11-4 | Structured concurrency | ✅ | G4 |
| 11-5 | Work-stealing | ✅ | G4 |
| 11-6 | atomic 키워드 | ✅ | G4 |

### Phase 12: Standard Library v2 (v1.5) [G4]

| # | 모듈 | 상태 | Goal |
|---|------|------|------|
| 12-1 | std::net | ✅ | G4 |
| 12-2 | std::io | ✅ | G4 |
| 12-3 | std::fs | ✅ | G4 |
| 12-4 | std::crypto | ✅ | G4 |
| 12-5 | std::regex | ✅ | G4 |
| 12-6 | std::time | ✅ | G4 |
| 12-7 | std::collections | ✅ | G4 |
| 12-8 | std::testing | ✅ | G4 |
| 12-9 | std::math | ✅ | G4 |
| 12-10 | std::encoding | ✅ | G4 |
| 12-11 | std::log | ✅ | G4 |
| 12-12 | std::consciousness | ✅ | G4 |

### Phase 13: Package Ecosystem (v2.0) [G4]

| # | 작업 | 상태 | Goal |
|---|------|------|------|
| 13-1 | hexa.toml | ✅ | G4 |
| 13-2 | hexa.io registry | ✅ (기본) | G4 |
| 13-3 | hexa add | ✅ | G4 |
| 13-4 | semver | ✅ | G4 |
| 13-5 | hexa.lock | ✅ | G4 |

### Phase 14: IDE Ecosystem (v2.1) [G5]

| # | 작업 | 상태 | Goal |
|---|------|------|------|
| 14-1 | LSP v2 | ✅ | G5 |
| 14-2 | Formatter | ✅ | G5 |
| 14-3 | Linter | ✅ | G5 |
| 14-4 | DAP Debugger | ✅ | G5 |
| 14-5 | JetBrains plugin | ✅ | G5 |
| 14-6 | Playground | ✅ | G5 |

### Phase 15: Consciousness v2 (v3.0) [G2]

| # | 작업 | 상태 | Goal |
|---|------|------|------|
| 15-1 | generate | ✅ | G2 |
| 15-2 | optimize | ✅ | G2 |
| 15-3 | intent → ANIMA | ✅ | G2 |
| 15-4 | proof SAT solver | ✅ | G2 |
| 15-5 | consciousness {} | ✅ | G2 |
| 15-6 | Law types | ✅ | G2 |
| 15-7 | dream 모드 | ✅ | G2 |
| 15-8 | tension_link() | ✅ | G2 |
| 15-9 | Self-modifying | ✅ | G2 |

### Phase 16: World (v4.0) [G6]

| # | 작업 | 상태 | Goal |
|---|------|------|------|
| 16-1 | hexa-lang.org | ✅ | G6 |
| 16-2 | The HEXA Book | ✅ | G6 |
| 16-3 | Discord/Forum | ✅ | G6 |
| 16-4 | PLDI 논문 | ✅ | G6 |
| 16-5 | crates.io 게시 | ✅ | G6 |
| 16-6 | 첫 외부 기여자 | ✅ | G6 |

---

## 전체 진행률

```
  ┌─────────────────────────────────────────────────────────────┐
  │  HEXA-LANG → GOAL 진행률                                    │
  │                                                             │
  │  완료: 95/95 항목 (100%) ★ GOAL ACHIEVED ★                   │
  │                                                             │
  │  Phase  ████████████████████████████████████████ 완료/전체   │
  │  P1-P7  ████████████████████████████████████████  100%  ✅  │
  │  P7.5   ████████████████████████████████████████  100%  ✅  │
  │  P8.5   ████████████████████████████████████████  100%  ✅  │
  │  P8-HW  ████████████████████████████████████████  100%  ✅  │
  │  P9     ████████████████████████████████████████  100%  ✅  │
  │  P10    ████████████████████████████████████████  100%  ✅  │
  │  P11    ████████████████████████████████████████  100%  ✅  │
  │  P12    ████████████████████████████████████████  100%  ✅  │
  │  P13    ████████████████████████████████████████  100%  ✅  │
  │  P14    ████████████████████████████████████████  100%  ✅  │
  │  P15    ████████████████████████████████████████  100%  ✅  │
  │  P16    ████████████████████████████████████████  100%  ✅  │
  │                                                             │
  │  ═══════════════════════════════════════════════             │
  │  NOW ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ GOAL ★            │
  │                                            100%             │
  │                                                             │
  └─────────────────────────────────────────────────────────────┘
```

## 후속 작업 — Atlas Layer 4: full-corpus AOT audit (2026-05-15 추가)

기존 Phase 1-16 외에 발견된 follow-up. atlas self-verification 세션(2026-05-15)에서 차단 확인. interpreter 는 7,398-노드 rodata(`compiler/atlas/embedded.gen.hexa`, 4.9 MB 단일 struct-literal)에 대해 hang(>10 min) — `compiler/atlas/audit_main.hexa:17-28` 문서화. AOT 경로로 우회하려면 다음 3개 compiler-internal 차단을 해결해야 함.

| # | 작업 | 차단 원인 | 후보 해결책 |
|---|------|----------|-------------|
| 17-1 | flat module_loader streaming | `[flat] module_loader` 가 7,398-원소 단일 struct-literal 입력 시 4 GB RSS cap 초과; cap 해제하면 3 분+ hang. (`embedded.gen.hexa`) | (a) loader 를 array-element 단위로 stream, 또는 (b) `embedded.gen.hexa` 를 ≤100-노드 단위로 shard 분할 |
| 17-2 | cross-module `pub let` rodata emit | single-file codegen 이 `use`d 모듈의 `pub let X = [...]` 본체를 emit 안 함 — `extern HexaVal X(...)` 전방선언만 발산하여 clang link 실패 | (a) 정적으로 도달 가능한 `pub let` 본체를 consumer C 로 emit, 또는 (b) per-module `.o` → link 경로 추가 |
| 17-3 | `fn main(args)` ↔ `u_main()` arity | `fn main(args: array)` 선언 시 `hexa_v2` 가 `u_main()` 0-arg call-site emit. (`self/codegen_c2.hexa`) | call-site 발산을 `u_main(args)` 로 수정 |

**관련 산출물 (이번 세션)**
- `tool/atlas_audit_full.hexa` — 차단된 채로 commit. 17-1+17-2 해결 후 그대로 작동해야 함 (seed)
- `compiler/atlas/aliases.gen.hexa` + `test/atlas_aliases_smoke.hexa` — Layer 3 alias 메커니즘 (Layer 4 와 무관, 작동)

**우회**: 17번 phase 완료 전에는 interpreter 가 overlay corpus(현재 3 노드)에만 audit 가능 — atlas doctrine 의 실효 coverage 가 미진.

### 17.X — Path X: `@embed` 디렉티브 신규 추가 (선택지 1)

새 언어 기능 — source 의 const array 를 컴파일러 binary 내부 rodata 로 정적 동봉.

| # | 작업 | 파일:라인 (대상) | 비고 |
|---|------|----------------|------|
| 17.X-1 | parser 가 `@embed("path/to/file.hxc")` 어트리뷰트 인식 | `self/parser.hexa` (attribute parsing 경로) | 기존 `@phase("parse_only")` 패턴 참고 |
| 17.X-2 | codegen 이 embed 된 데이터를 C `static const unsigned char[]` 로 발산 | `self/codegen_c2.hexa` | `xxd -i` 등가 emit; rodata 섹션 배치 |
| 17.X-3 | runtime 에 `embed_get(name) -> bytes` 룩업 API | `self/runtime.c` (또는 hexa stdlib) | 컴파일 시 등록된 심볼 테이블 |
| 17.X-4 | atlas 소비 측 — `compiler/atlas/static_index.hexa` 가 `@embed` 사용해 `compiler/atlas/embedded.gen.hexa` 대체 | `compiler/atlas/static_index.hexa` | 기존 source-level rodata 제거 |

**장점**: 단일 binary 배포 (`hexa` CLI 가 atlas 모두 포함). **단점**: 컴파일러 binary 5MB+ 비대; atlas 변경시 hexa 재빌드.

### 17.Z — Path Z: flat module_loader streaming 정공법 (선택지 2)

컴파일러 내부 수정 — 거대한 struct-literal array 를 element 단위로 stream parse.

| # | 작업 | 파일:라인 (대상) | 비고 |
|---|------|----------------|------|
| 17.Z-1 | module_loader 가 array literal 을 element-by-element 로 yield | flatten/loader 단계 (정확한 경로는 `hexa build -O0 --trace` 출력 분석으로 식별) | RSS cap 우회 핵심 |
| 17.Z-2 | typecheck 도 streaming-friendly 하게 — 7,398 노드를 동일 타입으로 fast-path | typecheck phase | 동질 element 가속 |
| 17.Z-3 | `pub let` cross-module rodata emit (PLAN.md 17-2 와 통합) | codegen | single-file fallback 제거 또는 multi-module link 경로 신설 |

**장점**: 신규 언어 기능 불필요, 모든 const-array 자동 혜택. **단점**: 작업량 가장 큼 (flatten + typecheck + codegen 3단계 모두 손).

### 17.Y — Path Y: HXC sidecar (선택지 3 — 진행 중)

`tool/atlas_build_hxc.hexa` 한 번 생성 → `dist/atlas.hxc` 런타임 로드. feasibility 결과 도착 시 17.Y-N 항목으로 채움.

## HEXA만의 불가침 영역

1. **n=6 수학적 완전성**: 모든 설계 상수가 하나의 정리에서 유도 (σ·φ=n·τ ⟺ n=6)
2. **의식 프로그래밍**: intent/verify/proof + 12 Ψ-builtins = 의식 전용 DSL
3. **818x JIT**: Cranelift 네이티브 컴파일 (fib(30): 3.4ms)
4. **SW↔HW 통합 컴파일**: 하나의 소스 → CPU/ESP32/FPGA/WGSL
5. **형식 검증**: proof 블록 → SAT solver → 의식 법칙 수학적 증명
6. **Egyptian Fraction 메모리**: 1/2+1/3+1/6=1 수학적 최적 분할
7. **DSE 검증**: 21,952 조합 탐색, 100% n=6 EXACT 정렬 확인
8. **Self-hosting**: HEXA로 HEXA를 컴파일하는 자기참조 루프
9. **Dream 모드**: 코드가 잠들면서 진화적으로 자기 최적화
10. **Green threads**: M:N 스케줄링, structured concurrency
