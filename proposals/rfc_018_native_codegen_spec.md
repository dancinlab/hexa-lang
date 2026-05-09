# RFC-018 — hexa native compiler 직접 codegen spec

- **상태**: **Spec draft** (2026-05-09) — 미구현
- **작성일**: 2026-05-09
- **선행 RFC**: RFC-017 (atlas 정적 내장 + native compiler 전환 결정)
- **결정 (2026-05-09)**: backend 후보 (LLVM / C-transpile / 직접 codegen) 중 **직접 codegen 채택**
- **영향 영역**: 신설 `compiler/` 트리, `stdlib/diagnostics/*`, `stdlib/rt/*`, 기존 `hexa_interp` 는 stage0 부트스트랩 용도로만 잔존

---

## 1. 동기 (Why 직접 codegen)

| 후보 | 장점 | 약점 | 채택? |
|---|---|---|---|
| LLVM | 최적화 강력, 멀티타겟 | 거대 의존 (수백MB), 빌드 시간 ↑, atlas-aware hook 어려움, AI-native 제어 약함 | ❌ |
| C-transpile | 빠른 부트스트랩 (`clang`만 있으면) | C 컴파일러 의존 사슬, 디버그 매핑 손실, atlas 임베딩 어색, 보안 surface ↑ | ❌ |
| **직접 codegen** | 제어권 100%, 의존 zero, atlas/diagnostic을 IR 모든 단계에서 인지, 결정적 | 초기 노력 大, 최적화 직접 작성 필요 | ✅ |

핵심 이유: hexa-lang은 **atlas SSOT + 수식 검증 + AI-native** 가 본질. 외부 toolchain은 이 인지를 IR 경계에서 잃음. 직접 codegen은 모든 단계가 atlas-aware.

---

## 2. 컴파일 파이프라인

```
.hexa source
   ↓ lex                      (tokens)
   ↓ parse                    (AST, atlas-tagged)
   ↓ resolve   (S0–S2)        atlas 노드 / scope binding
   ↓ check     (S3–S5, S8)    type / units / citation
   ────────────── ↑ 위반 시 abort, 바이너리 안 만듦
   ↓ lower                    HIR (typed)
   ↓ mono                     generic monomorphization
   ↓ ssa                      MIR (CFG, SSA)
   ↓ optimize                 const-fold, dce, inline (보수적)
   ↓ regalloc                 LIR (target-specific)
   ↓ emit                     asm text or machine code
   ↓ link                     ELF (Linux) / Mach-O (macOS)
```

각 단계는 hexa로 작성된 모듈. 모든 IR 노드는 atlas-aware (P/C/L 인용 정보를 IR 끝까지 보존).

---

## 3. 타겟 매트릭스

| Tier | Triple | 우선순위 | 비고 |
|---|---|---|---|
| T0 | `x86_64-linux-gnu` | 1차 | 대부분 dev / CI |
| T1 | `arm64-apple-darwin` | 1차 | Apple Silicon dev |
| T2 | `arm64-linux-gnu` | 2차 | docker/runners (`build/hexa_interp.linux` 후속) |
| T3 | `wasm32-unknown-unknown` | 후순위 | playground 용 |
| T4 | `riscv64-linux-gnu` | 보너스 | 검증용 |

크로스 컴파일은 stage1 정착 후 도입.

---

## 4. ABI / calling convention

| 타겟 | 규약 |
|---|---|
| x86_64 Linux | System V AMD64 (rdi, rsi, rdx, rcx, r8, r9, ...) |
| arm64 macOS | AAPCS64 (x0–x7, ...) |
| arm64 Linux | AAPCS64 (동일) |

규칙
- struct ≤ 16B by value, 그 이상 by reference
- 반환값 ≤ 16B by register, 그 이상 hidden first arg
- `extern "C" fn` 은 위 ABI 따름
- `extern "hexa" fn` (디폴트)도 같은 ABI로 시작 — 추후 hexa-내부 최적화 (closure 캡처 등) 가능성 열어둠

---

## 5. 메모리 / runtime (`hexa_rt`)

최소 runtime, 정적 링크.

| 모듈 | 책임 | 비고 |
|---|---|---|
| `rt/alloc` | mmap 기반 arena + bump | 1.x: gc 없음. 2.x: refcount (Swift/Rust Arc 모델) 검토 |
| `rt/syscall` | direct syscall (Linux x86_64), libSystem (macOS) | libc 의존 0 (선택 사항) |
| `rt/panic` | stderr 메시지 + exit | no unwinding 초기 |
| `rt/atlas` | 정적 atlas 인덱스 (binary embed) | hash 핀 검증 |
| `rt/diag` | runtime panic 메시지 (RFC-019 catalog 일부 포함) | binary embed |
| `rt/io` | print, read, file | 최소 |

크기 목표: stripped runtime ≤ **200 KB**. atlas 정적 임베드 포함 시 **2 MB** 이하.

---

## 6. atlas 임베딩 hook (RFC-017 § 4.5 구현)

빌드 타임
```
컴파일러 빌드 시 (one-time per compiler version):
  1. ~/core/nexus/n6/atlas.n6 + atlas.append.*.n6 머지
  2. dedup, schema check, P/C/L hash 계산
  3. packed binary form 생성 (~1–2 MB)
  4. 컴파일러 바이너리 .rodata 섹션에 정적 임베드
  5. atlas SHA256 = ATLAS_HASH 상수
```

사용자 빌드 시
```
hexa build x.hexa
  → 컴파일러가 메모리 안 atlas 인덱스로 즉시 P[*]/C[*]/L[*] 검증
  → 사용자 코드가 인용한 atlas 노드들만 dead-code elim 후
     사용자 바이너리에 임베드 (reflect / `hexa explain` 용)
  → atlas 미사용 시 사용자 바이너리에 atlas 0 byte 포함
```

drift 감지
- `hexa.toml [atlas] hash = "a3f9..."` 명시 시: 컴파일러 atlas hash와 mismatch → 빌드 실패
- 미명시 시: 컴파일러에 박힌 hash 사용

override (외부 사용자)
- `hexa.toml [atlas] path = "..."` → 컴파일러 빌드 시 다른 atlas 머지
- 단, 컴파일러 자체 재빌드 필요

---

## 7. bootstrap 시퀀스

| Stage | 산출물 | 빌드 도구 |
|---|---|---|
| Stage 0 | hexa로 작성된 minimal native compiler 소스 | 기존 `hexa_interp` (인터프리터) 가 빌드 |
| Stage 1 | stage0가 인터프리트해서 emit한 native 컴파일러 바이너리 | stage0 |
| Stage 2 | stage1 컴파일러가 자기 자신 소스를 native 컴파일 | stage1 |
| Stage 3 | stage2 컴파일러가 자기 자신 — **self-hosted 정착** | stage2 |

검증
- `bytewise(stage2_binary, stage3_binary) == match` → fixed point 도달
- 일치 시 stage1, stage2 폐기 가능

회귀
- `bench/bootstrap_e2e.hexa` — 매 PR에서 stage0→3 전체 재현
- atlas hash drift, 컴파일러 hash drift 모두 회귀 detect

---

## 8. 디버그 정보

| 타겟 | 형식 |
|---|---|
| Linux | DWARF v4 (라인 매핑 + 변수 + types) |
| macOS | DWARF in `__DWARF` segment + dsym 옵션 |

추가 hexa-specific 섹션
- `.hexa.atlas` — 사용된 atlas 노드 hash 리스트
- `.hexa.diag` — 컴파일 시 emit된 hint 메시지 (실행 시 panic에 동봉)
- `.hexa.spec` — `@law`/`@implements` 어노테이션 메타

→ `hexa explain <binary>` 가 binary 자체에서 정보 추출.

---

## 9. 최적화 1차 범위 (보수적)

| 단계 | 도입 |
|---|---|
| const folding | 1차 |
| dead code elimination | 1차 |
| inlining | 1차 (작은 함수만) |
| common subexpression elim | 2차 |
| loop invariant motion | 2차 |
| SROA (struct decompose) | 2차 |
| auto-vectorization | 후순위 |
| LTO | 후순위 |
| PGO | 후순위 |

목표: 1차 hexa 컴파일러는 "정확하고 작고 디버깅 가능한 코드 생성" 우선. -O2 수준은 stage3 정착 후.

---

## 10. linker

| 단계 | 전략 |
|---|---|
| 1차 | system `ld` / `lld` 호출 (가장 빠른 부트스트랩) |
| 2차 | 자체 정적 링커 `hexa_ld` — ELF/Mach-O minimal emitter |
| 3차 | 자체 동적 링커도 검토 (hexa runtime 없는 환경용) |

하이브리드: `hexa build --linker=system|hexa` 플래그.

---

## 11. FFI

- `extern "C" fn`: System V/AAPCS 그대로
- `extern "py" fn` (RFC-016 import py): native 컴파일러 + Python embedded — `libpython3.so` 동적 링크 또는 subprocess
- atlas 노드 인용은 FFI 경계에서 보존 (debug section 통해)

---

## 12. 미해결 / 후속

1. inline asm 문법 (Rust `asm!` 매크로 모델? hexa-native?)
2. generic monomorphization vs dyn dispatch 디폴트
3. async runtime (tokio 모델 vs go-routine 모델)
4. lifetime / borrow check (Rust strict vs gc-light)
5. effect system (atlas L[*] 와 결속해 effect를 law로?)
6. linker 자체 작성 시점
7. wasm32 backend 우선순위
8. 자체 어셈블러 vs `as` 외부 호출

---

## 13. 한 줄 결론

직접 codegen — **AST → HIR → MIR → LIR → mach** 5단 IR, 1차 타겟 x86_64-linux + arm64-darwin, runtime ≤2MB (atlas 포함), bootstrap 4-stage (interp → self-host). 모든 IR 단계가 atlas-aware, 외부 toolchain 의존 zero.
