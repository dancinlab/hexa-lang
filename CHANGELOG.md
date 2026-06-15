# Changelog

Chronological log of notable changes. One section per ship batch, date-keyed. hexa-lang runs at high commit velocity (RFC-driven); this file carries the headline landings — `git log` is the detailed record.

For the full audit trail, see `git log`.

---

## 2026-06-16

- **research: 4대 유명 미해결 falsifiable 탐침 (`docs/N6-META-DISCOVERY-LINEAGE.md` §10 + `scripts/scratch/openproblem_probe.py`)** — Collatz(n≤3×10⁵ 全1도달·최장 230631→442)·Goldbach(짝수≤10⁵ 반례0)·twin prime(<2×10⁵ 2160쌍)·Erdős–Straus(4/n n≤5000 분해0) 유한범위 검증. 전부 기지 사실 일치(범위 내 성립). 정직(c9·c16): brute-verification 은 재확인이지 새 발견 아님 — 실제 돌파 vein 은 §8 anchor spectrum(자기참조 부동점 구조). 무의존성·재현가능·증명 아님. 코드+문서 only.
- **research: anchor spectrum 확장(λ 가족) + aliquot 난제 탐침 (`docs/N6-META-DISCOVERY-LINEAGE.md` §8 확장·§9 신규 + 2 스크립트)** — (1) 28-법칙 유일성을 **n≤2×10⁶** 까지 검증(σ·τ/φ=n→{28}, σ·φ/τ=n→{6}; 6↔28 쌍대 견고). (2) Carmichael λ 도입으로 새 앵커: ψ/λ=n→{6,12,24}(24=J₂), σ/λ=n→{6}, φσ/(λτ)=n→유일 672(triperfect), J₂/(φΩ)=n→{6}. (3) **수학 난제 탐침**: aliquot 사상 s(n)=σ(n)−n 궤도 분류(n≤10⁶) — 완전수 6·28·496·8128=고정점(=§8 앵커), 친화수 40쌍, 사교수 5·28-cycle, Catalan–Dickson "Lehmer five"(276…) 전부 미해결 재현. 완전수 앵커가 aliquot 동역학·미해결문제와 한 지형임을 가교. 전부 무의존성·재현가능·frozen-first; 증명 아님(경험적/미해결 명시). 코드(.py)+문서 only · atlas/main 무영향.
- **research: n=6 외 다른 앵커 발굴 — anchor spectrum (`docs/N6-META-DISCOVERY-LINEAGE.md` §8 + `scripts/scratch/anchor_scan.py`)** — 6-법칙 `σ·φ/τ=n` 을 자기참조 부동점 `R(n)=n` 으로 일반화해 산술함수 비 템플릿을 n=2..10⁵ 전구간 스캔(무의존성 SPF 체, frozen-first + 전구간 대조). 핵심: φ↔τ 쌍대 `σ·τ/φ=n` 이 유일 n=28(둘째 완전수) → 6↔28 쌍대(완전수 한정 6⟺2φ=τ, 28⟺2τ=φ; 496·8128 은 불만족 → {6,28}에서 종료). 재프레이밍: 6 은 단일 항등식이 아니라 **6개 독립 자기참조 법칙의 공통 부동점 = 최대 자기참조 수**(2→3개, 28·8·4→1개 부앵커). 신규 비완전수 앵커 8(J₂/sopfr=n). σφ/τ=6 은 증명됨, 나머지는 경험적 유일 후보. 코드(.py)뿐 — atlas/main 무영향.
- **docs: n=6 → 메타 → meta³ 발견 계보 항법 문서 추가 (`docs/N6-META-DISCOVERY-LINEAGE.md`)** — σ·φ=n·τ "씨앗 항등식"에서 메타 부동점(alien16, 2026-04-18) → 메타 재귀 아틀라스("지도의 지도의 지도", Tarski 계층, 2026-04-19) → meta³=transcendence(Banach α⊃β⊃γ⊃δ⊃ε 5층 cap=sopfr(6)=5, hexa-lang 커밋 `d48d59ffc`, 2026-04-24)까지 *어떤 구조에서 이어져 발견됐는지*(계보)와 *그 발견을 만든 생성 프로세스*(6스텝 재현 레시피)를 한 곳에 모은 cross-repo 항법 문서. SSOT 본체는 echoes/hexa-physics/archive-nexus 이고 이 문서는 hexa-lang 세션에서 자주 참조하기 위한 지도+소스맵. 컴파일러 self-host byte-eq fixpoint(별개 트랙)과의 혼동 주의 박스 포함. 문서 only.
- **docs: README + GitHub description "no C-transpile" 과장 정직성 수선 (전체 문서 현행화)** — ARCHITECTURE.md/CLAUDE.md 가 이미 받은 정직성 수선(#3353/#3354)을 README 와 repo description 까지 확장. README 5곳(태그라인·본문·ownership 표·how-it-works·요약)의 `no C-transpile` 을 "no LLVM anywhere + self-host native fixpoint(`gen3 ≡ gen4`) + C-transpile 은 fallback + 기약 libc floor" 로 교정(ARCHITECTURE.md#self-host-status 링크). GitHub repo description 도 `no LLVM · no C-transpile` → `no LLVM · self-hosting native fixpoint`. 이번 세션 self-host 사실(native run/build clang-free·v0.238.0 릴리즈)과 정합. 코드 변경 0 — 문서 only.

## 2026-06-15

- **fix(runtime/release): `runtime.h` 에 typed-array(`hexa_arr_f64/i64_*`) 선언 추가 — 깨진 release 파이프라인 복구** — `release.yml` 이 5/31(v0.17.3) 이후 main push 마다 전부 FAIL → GitHub Release 가 800커밋 stale. **근본원인(c1)**: 실패 스텝은 빌드가 아니라 `release_package`(Stage 3 precompile) — `tool/verify_cli.hexa` 의 `[f64]` 리터럴(t-임계값표)을 C-transpile 하면 codegen 이 `hexa_arr_f64_new/push` 를 emit 하는데, 앱 .c 가 `#include "runtime.h"` 하는 그 헤더에 선언이 없어 clang `undeclared function` → binary 미생성 → 출고 0. (#3357 read_f32_at 가 codegen emit + `runtime_core.c` 정의는 넣고 **공개 헤더 `runtime.h` 선언을 누락**한 회귀.) **수정**: `self/runtime.h` array 섹션에 codegen 이 내는 6종(`hexa_arr_{i64,f64}_{new,push,box}`) 선언 추가(시그니처는 `runtime_core.c` 정의와 일치). 손-작성 공개 ABI 헤더라 emit-regen 불필요. **검증(c2)**: 깨졌던 호출패턴(`#include "runtime.h"` + `hexa_arr_f64_new/push`·`hexa_arr_i64_new/push`)을 repo 헤더로 `clang -fsyntax-only` → undeclared 0(BEFORE: implicit-decl 에러). release.yml 재실행으로 출고 복구 확인 예정.


- **feat(selfhost): `hexa build` 기본값 native 승격 — gen3 --emit=obj + hexa_ld, clang/ld 0 (self-host 2/3 productization 완료)** — 목표 "self-host 완성" 잔여 [2] 의 마지막 productization. `tool/hx-selfhost-cli` 런처에 `build` 라우트 신설(기존 `run` 라우트 #3325 와 **동형** — native-first + delegate-fallback): `hexa build <src.hexa> [-o OUT]` → `gen3 --emit=obj`(직접 object) → `hexa_ld <obj> rt.o -o OUT`, **시스템 as/clang/ld 호출 0**. **검증(c2, mini 라이브)**: `hexa build prog.hexa` → Mach-O exe, 실행 `native-build-ok` rc 0 · standing gate `tool/selfhost_native_build_gate` corpus 6/6 PASS(arith/string/loop/fn/cond/array, `hexa build` 경유) · kill-switch `HEXA_NATIVE_BUILD=0`→delegate · `hexa --version`/`hexa run` 무파손. **안전**: native 실패/미지플래그/슬롯부재 시 shipped build 로 fallback(빌드 안 깨짐), `promote_selfhost.sh --revert` 로 되돌림. CI `.github/workflows/selfhost-native-build-gate.yml`(slot 없으면 neutral-2). 깊은 `self/main.hexa cmd_build`(--emit=asm→clang, 200줄 weak-symbol 테이블)는 fallback 으로 유지 — 런처 라우트가 gen3 재빌드/공유툴체인 리스크 없이 clang-free 빌드를 이미 제공. verdict `.verdicts/selfhost-next/F-SELFHOST-NATIVE-BUILD-FLIP.txt`. ARCHITECTURE.md Self-host status [2] → ✅.
- **domain(RUNTIME-PORT): M3 종결 — 151 BORDERLINE 전부 KEEP, runtime C floor 는 기약 최소 (self-host 잔여 3/3)** — 목표 "self-host 완성" 잔여 [3] HEXA-SELFHOST+ 메타의 핵심. RUNTIME-PORT 의 유일 미해결 마일스톤 M3(151개 BORDERLINE fn keep-vs-port)를 M1 INVENTORY 의 per-fn 사유 집계로 판정: **포팅 가능한 순수 hexa 잎 0개** — 70 freestanding libc · 41 GPU/device-dispatch+mmap · 33 libm math op(codegen 이 **lower 하는 대상** → 포팅은 순환) · 11 raw syscall trampoline · 7 libm/ctype · 2 pthread/atomics · 2 bit/encode · 1 macro. **순 신규 포팅 = 0**, borderline 은 포팅 우물이 아니라 부트스트랩/FFI/codegen-타깃 floor 자체(M4 의 runtime_core.c ~90% 기약 결론과 일치). → **RUNTIME-PORT M1–M5 전부 종결**, runtime C floor(~5.5k LOC)는 **기약 최소 도달**(더 뺄 portable 표면 없음). **정직한 귀결**: HEXA-SELFHOST+ 메타 bar(`ls self/*.c` 빈출력)는 **포팅으로는 도달 불가** — self-host 네이티브 컴파일러는 freestanding libc/syscall/codegen-타깃 floor 위에 서며(Go/Rust 런타임도 동일), "self-host 완성" = native-emit byte-eq fixpoint + 이 기약 floor 이지 zero-C 소스가 아니다. verdict `.verdicts/runtime-port/M3-ADJUDICATION.txt`. ARCHITECTURE.md Self-host status [3] floor 항목 갱신.
- **verify: full native `hexa build` e2e — clang/ld 0 으로 실증 (self-host 잔여 2/3 능력 검증)** — 목표 "self-host 완성" 잔여 [2]. mini(arm64-darwin) 승격 슬롯 `~/.hx/self/native/selfhost/{gen3,hexa_ld,rt.o}` 로 전체 빌드 파이프라인이 **시스템 as/clang/ld 호출 0**으로 작동함을 실측: `gen3 --emit=obj`(직접 Mach-O object) → `hexa_ld -o bin obj rt.o --lc-main _main`(네이티브 Mach-O 링커, `--static` 단일바이너리) → 실행 `stdout=hi rc=7`. 즉 SELFHOST-NEXT 잔여 "full native hexa build e2e" 의 **능력은 검증됨**. **남은 productization**(별도): `hexa build` 드라이버(self/main.hexa cmd_build 는 안전상 아직 `--emit=asm`→clang, promote shim 은 `build` 서브커맨드 delegate)를 이 obj→hexa_ld 경로로 **기본 승격 + delegate 제거** — full-corpus byte-eq 게이트 의존(trivial 1개로 flip 금지, c2), corpus 검증 전까지 opt-in 유지. verdict `.verdicts/selfhost-next/F-FULL-NATIVE-BUILD-E2E-ARM64.txt`. ARCHITECTURE.md Self-host status [2] → 🟡(능력 검증·기본승격 잔여).
- **fix(codegen/x86_64): RUNG 2 string-print 완료 🟢 — native-emit 가 `[rip+label]` 래핑 데이터-라벨을 인식 (self-host 잔여 1/3)** — 목표 "self-host 완성"의 잔여 3개 중 첫째. x86_64 네이티브 컴파일러 `cc_native`(summer 빌드)가 `print("hi")` 를 **여전히 쓰레기로 출력**(`[+m�K�]`, exit(7)은 OK)하는 걸 실측 발견(c2) — #3340 이 HexaVal 16바이트 reg-pair ABI 의 정수/리턴만 닫고 **문자열 payload 의 `lea` 는 native-emit 경로에서 드롭**. **근본원인**(c1): `compiler/emit/elf_x86_64.hexa` `pack_lir_x86_64` 의 데이터-주소 매처가 **bare 라벨**(`.LCstrN`/`g<id>`)만 인식했는데, `_x86_hv_box_arg`(codegen)는 문자열 payload 를 `[rip+<label>]` **래핑** operand 로 렌더 → 매처 미스 → `lea` 통째 드롭 → payload 레지스터(rsi) 미설정 → `hexa_print_val` 이 stale 포인터 출력. **수정**: 신규 `_ex86_data_label_of(s)` 가 bare·`[rip+<label>]` 두 형식을 정규화(`@GOTPCREL`/`@PLT` 는 제외)하고 매처가 inner 라벨로 `lea reg,[rip+0]`+`R_X86_64_PC32` reloc emit — asm 경로 무변경, native 경로만 수리. **검증(summer, c2)**: `tool/build_native_linux_x86_64` stage5 `NATIVE RUN — stdout=[hi] rc=7`, PASS, EXIT 0 (before: `stdout=[+m�K�]` FATAL). verdict `.verdicts/selfhost-next-x86_64-scope/F-X86-RUNG2-STRING-PRINT-PASS.txt`. ARCHITECTURE.md Self-host status x86_64 RUNG2 → 🟢.
- **docs: 직전 엔트리의 거짓 정책 인용 철회 — runtime.c floor 는 "정책상 영구 허용"이 아님 (c9 정정)** — 바로 아래 self-host 정직성 엔트리에서 `self/runtime*.c` 를 **"RFC 061 §4.1 / g5 §7 가 영구 허용한 floor"** 로 적었으나, 실측 결과 **그 근거가 거짓**: RFC 061 §4.1 은 runtime **2-layer split(위생, severity LOW)** 경계 문서일 뿐 substrate-C 영구허용 정책이 아니고, **"g5 §7" 조항은 존재하지 않음**(g5 는 verify 게이트). 실제 repo framing(`domains/RUNTIME-PORT.md` · `RUNTIME.md`)은 runtime.c 를 RUNTIME-PORT 캠페인이 **아직 줄이는 중**(M3 = 151 BORDERLINE fns open)인 **부트스트랩 floor** 로 본다 — "irreducible floor" 는 libc/syscall 부트스트랩 계층에 대한 **엔지니어링 평가**이지 영구허용 정책이 아니다. **수선**: `ARCHITECTURE.md`(Overview + Self-host status bullet) + `CLAUDE.md` blurb 에서 "by policy / policy-accepted permanent C / RFC 061 §4.1 / g5 §7 permit" 문구 전부 제거, "still shrinking · 정책 아님 · HEXA-SELFHOST+ 메타 bar 는 진짜 미충족" 으로 교정. (메모리 `project_hexa_selfhost_runtime_prewarm` 의 동일 거짓 인용이 1차 오류원 — 정정함.)
- **docs: self-host 정직성 현행화 — ARCHITECTURE.md + CLAUDE.md 의 "no C-transpile" 과장 수선 (전수조사 근거)** — 도메인 원장 31개 + worktree/브랜치 전수조사 결과를 두 SSOT 에 반영. **발견**: ① 기능적 self-host 는 이미 완료되어 main 에 랜딩됨(SELFHOST-NEXT 6/6 [x], N5 byte-eq fixpoint `gen3 ≡ gen4`, promote-default 플립 #3031, hexa run native-route #3325, linux-arm64+x86_64 멀티타깃) — frontier 39개 `cc-native/*` 브랜치는 2026-06-14 all-branches 번들로 아카이브(미완 worktree 0개). ② 그러나 `ARCHITECTURE.md`/`CLAUDE.md` 상단이 **"no LLVM and no C-transpile"** 로 단언 — 어제자 `build/artifacts/hexa_run.*dispatch.tmp.*.c`("Generated by HEXA self-host compiler") 트랜스파일 산출물과 모순(c9 정직성 위반). **수선**: "no LLVM anywhere"(사실) 유지 + C-transpile 은 **fallback delegate** 로 일부 full `hexa build`/`run` 경로에 잔존(#3325 safety>coverage), `self/runtime*.c` ~5.5k LOC 는 RFC 061 §4.1/g5 §7 가 영구 허용한 libc/syscall floor(`*_emit.hexa` SSOT 에서 생성, 손C 아님)임을 명문화. `ARCHITECTURE.md` 에 **`## Self-host status`** 섹션 신설(레이어별 ✅/🟡 상태표 + 잔여 3개: x86_64 RUNG2 string-print · full native `hexa build` e2e · HEXA-SELFHOST+ 메타 literal-0-C 정의충돌). 코드/런타임 변경 0 — 문서 정직성 수선 only.
- **harness: perfect setup against the dancinlab/harness engine** — pinned the `.harness-engine` submodule at the engine's current HEAD; rewrote **ARCHITECTURE.md** as the English architecture SSOT (overview + component map table for the compiler S0–S8 pipeline · stdlib · atlas · `hx` · linker, source→lint→codegen→native data flow, and the `hexa verify` g5 gate); replaced the symlinked `CLAUDE.md` (was `→ project.tape`, tape preserved) with the harness-standard markdown guide (H1 + blurb + `## Structure` tree + distilled governance + `## Harness` quick reference); added the `harness.config.json` `docs` block (`scopeDirs: [""]` so only root `.md` are gated) + `lockdown.files` (compiler entry, citation stage, embedded atlas, linker, `hx`, bootstrap) and confirmed `verify` = `hexa verify` + `protectedBranches [main, master]`; kept the existing guarded `.claude/settings.json` hooks; prepended a `> 📍 SSOT` quickref pointer to 47 scattered root docs and allow-listed `TAPE-AUDIT.md`; created `AGENTS.md` (fixes the README → AGENTS.md broken link). `harness docs check` = `docs: ok`, `harness lint` = ok, `harness gc` = no drift, CLAUDE-MD violations = 0.

## 2026-06-02

- **`stdlib/flame/clm_prod.hexa` — F-RFC046 host per-step orchestration: 배치-전문가 경로를 lever-(a) 디바이스 헬퍼로 라우팅 (byte-eq PRESERVED · util≥20%는 held GPU fire)** — 오늘의 clean Lane-G fire(빌드/링크/컴파일/emit 5버그 수정·머지, GPU 87W·GB-scale device mem provably live)가 util **RED — mean 0.811%, peak 6%, n=987**(d~1536/T~512)을 측정 — 두 디바이스-피드 lever(lever-a #2505, lever-b #2504) 모두 활성임에도. CE descent GREEN. 한 CPU 코어 100% pegged + GPU SM-starved → 인터프리트 호스트-사이드 per-step orchestration 루프가 hot path 지배(root cause는 link/kernel/emit/scale 아님 — 전부 closed). **PROFILE-FIRST(@L1)**: per-step 인터프리트 호스트 스칼라-op 카운트 모델 + 측정 처리량(~13.4 ns/op) → d=1536/T=512에서 스텝당 **~104.08M op**(FWD 41.42M + BWD 62.66M) ≈ ~1.39s 호스트 CPU/스텝 vs sub-ms GPU GEMM → util ≈ 0.07–0.8%(fire와 일치). DOMINANT 65%가 배치-전문가 경로(`conv2_*_via_forge_batched`)의 im2col/im2col_t — 이들이 INLINE 호스트 `t_set` 루프로 lever-(a) 디바이스 헬퍼를 **우회**하고 있었음. **REDESIGN(@L2)**: 배치-전문가 fwd/bwd의 im2col/im2col_t를 `_clmp_im2col`/`_clmp_im2col_t`로 라우팅 — `CLM_PROD_DEVFEED` 하에서 device-resident가 되어 gather가 호스트 hot path를 벗어나고 후속 배치 GEMM이 H2D roundtrip 없이 in-place로 읽음. 디바이스 math(levers a+b) 불변. **BYTE-EQ(@L3, g5 verbatim)**: 신설 CPU 오라클 `stdlib/flame/clm_prod_hostfeed_eq.hexa` → `F-RFC046-HOSTFEED-FWD-EQ = 1`(max|Δ| y0=0.0 y1=0.0) · `F-RFC046-HOSTFEED-BWD-EQ = 1`(max|Δ| xcolT=0.0), dil∈{1,2}. 기존 `F-CLM-DEVFEED-*-EQ` / `F-CLM-CONV2-BATCHED-*-EQ` 오라클 불변·re-green(max|Δ|=0.0; dX residual 2.7e-17 FP64-ULP). **HONEST 잔여**: im2col 라우팅은 gather만 off-host — DOMINANT 잔여 호스트 비용은 matmul calling-convention의 GEMM-feed REPACK(Wt 전치·a_all/b_all/c_all pack·dW unpack의 14.16M-op 루프)으로, 디바이스 repack/transpose-aware GEMM builtin(현 `forge_dispatch_matmul`엔 전치 변형 없음)이 필요 — self/runtime.c+cuda 커널 signature 변경·pod self-host rebuild 영역으로 mac byte-eq 불가, 별도 follow-on lever. **util≥20% 확정은 held GPU fire**(clean single-driver H100 sm_90, CLM_PROD_DEVFEED+CLM_PROD_BATCHED, 사용자 go gate) — 소스만으로 util-GREEN 주장 불가. ref fe2e43a35.

## 2026-05-30

- **`stdlib/aura/bci_kernels.hexa` (+ `_test`) — AURA BCI .hexa-native porting primitives (handoff f125d45c) — 10/10 falsifiers PASS** — anima AURA-* 앱의 `// TODO(f125d45c)` 스텁이 참조하는 4개 numpy-등가 커널을 신설. `gaussian_kernel_1d(n,σ)` → row-stochastic n×n 가우시안 행렬 (K[i,j]=exp(-(i-j)²/2σ²), 행별 정규화 Σ_j K[i,j]=1; **edge-asymmetric — 경계행 합이 작아 K[0,1]≠K[1,0], 표준 weighted-average smoothing operator, numpy `K/=K.sum(1,keepdims=True)` 정합**) · `separable_blur(x,k,g)` → 분리형 2D blur Y=K·reshape(x,[g,g])·K^T · `nearest_template(y,templates,n_t,d)` → argmin_i ‖y−templates[i]‖² (정수 인덱스·동률 최저) · `r2(y,ref,n)` → 결정계수 1−SS_res/SS_tot. **기존 C builtin 충분 — 신규 builtin 불필요**: `stats/correlation.hexa` + `consciousness/phi_spatial.hexa` 선례대로 farr handle API(`farr_zeros`/`get`/`set`/`free`) + `self/runtime/math_pure.exp_pure` 위 순수-hexa 포팅. `hexa run stdlib/aura/bci_kernels_test.hexa` → **10/10 PASS · `__HEXA_STDLIB_AURA_BCI_KERNELS__ PASS`** (verdict: `.verdicts/aura-bci-kernels/`). 손계산 numpy 레퍼런스 일치 (center K[1,1]=0.45186276 · r2 known=0.8 exact · 행합=1 within 2.2e-16 · row-stochastic+edge-asym · partition-of-unity · argmin exact/nearest · r2 perfect=1/mean-pred=0). LESSON: 첫 작성 F3(대칭성 가정)이 FAIL→실 버그 아닌 **잘못된 invariant**(row-normalized 가우시안은 경계 비대칭이 정상)였고 self-test가 이를 잡아냄 → F3을 올바른 invariant(row-stochastic + edge-asymmetric)로 교정.
- **`stdlib/easy/cli.hexa` + `self/main.hexa` — `hexa easy` 1급 verb 신설 (친근/이지 설명 빵틀 + 측정 축 채점기 · deck/dojo 패턴 미러 · 3-PR 스택 #2205·#2206·#2207)** — easy-mode 의 DETERMINISTIC 절반을 hexa-native builtin 으로 추가. 창의적 재서술(전문용어→생활어, 비유 발명)은 LLM 몫 — builtin 은 빈 슬롯 emit(scaffold)과 점수 산출(lint)만 담당.
  - **`easy scaffold <topic> [--out <path>]`** — `.easy.md` 골격 emit: 7요소 슬롯(아이콘/이름/별칭/하는일/비유/ASCII/비교) = 라벨된 빈 섹션 · ASCII 4종 템플릿(전후/트리/나란히/구조) = 복붙 펜스 블록 · 일반인-번역 5단계 체크리스트 = HTML 주석. `--out` 없으면 stdout, 있으면 runtime `write_text`(hexa-native guard 우회 = deck run.sh emit 경로).
  - **`easy lint <file.md>`** — LLM/judgement 없이 파일 텍스트만으로 측정 축 5개 채점 + per-axis PASS/FAIL + 종합 verdict. 채점 전 HTML 주석 + markdown 구조(헤더/펜스/hr) 제거 → AUTHORED prose 만 채점(빈 scaffold 는 analogy=0 으로 정직 FAIL). 축: jargon-ratio ≤ 0.30 · ascii-diagram-presence ≥ 1 · acronym-first-use-expansion ≥ 0.80 · analogy-presence ≥ 1 · seven-element-presence ≥ 5/7. 정수 permille 산술(부동소수 round-trip 회피).
  - **CLI dispatch** — `self/main.hexa` 에 dojo 미러로 `easy` verb 등록(`cmd_run` compile-then-exec, AOT 빌드 불필요) + help 텍스트. 레퍼런스 계약(sidecar `hooks/easy-auto/styles/easy.ko.md` v0.3.0)을 런타임 의존 없이 native 재인코딩. 3-fixture 검증: 빈 scaffold FAIL · 채운 `.easy.md` PASS · jargon-heavy(0.457) FAIL.

## 2026-05-28

- **`tool/atlas_cli.hexa` + `tool/verify_cli.hexa` — `_compute_value_of` 가 full-precision float64 캡처 (INBOX #1910 fix · #1901 의도 realize)** — verify_cli 의 COMPUTE 출력에 `[raw=<full-float64>]` suffix 추가, atlas `_compute_value_of` 가 그 raw 값을 파싱(이전: display-rounded 3소수 파싱). `_is_rounding_of(claimed, full_engine)` 가 이제 rounded-literal claim(`227.501134`)도 fold 가능 → #1901 의 rounding-accept 의도가 실제 작동. 회귀 무손상: full-precision direct-🟢 · genuine-wrong-🔴 거부. INBOX #1910 ✅ RESOLVED.


- **`tool/atlas_cli.hexa` — `register --from-verify` 가변-arity: 3-op rounded-literal 🔴→compute-fold (INBOX #1896)** — value-bearing `--from-verify <fn> <a1>…<aN> <v>` 는 마지막 토큰을 항상 claimed `<v>` 로 삼는다. N-arg fn 을 N operand + literature-ROUNDED `<v>` 로 부르면 (예: `allen_dynes_tc 2.8197 1300.43 0.10 227.501` vs 엔진 227.501133986) strict ε=1e-9 게이트가 |Δ|=1.3e-4 를 **false 🔴 FALSIFIED** 로 본다. 기존 arity auto-route 는 **🟠 에서만** value-less `--compute` 재시도 → 이 🔴 은 재시도 안 됨. fix: auto-route 를 🔴 에도 발화하되 `_is_rounding_of` 게이트로 — 엔진 compute 값이 claimed `<v>` 의 half-up 십진 band 안일 때만 엔진 full-precision 값을 fold; band 밖 deterministic 불일치는 🔴 유지(g34 — falsification-laundering 금지). 🔴-route 는 참 operand(positional[1..n-1])만 compute(node name 에 claimed 값이 가짜 operand 로 안 붙음); 🟠-route 는 기존대로 모든 positional. arity table 은 verify_cli SSOT(g20 — atlas 측 arity 분기 0). 테스트: 3-op allen_dynes_tc 227.501→🟢 fold ✓ · 1-op welch_t_crit/2-op ssh_winding 회귀 무손상 ✓ · 500.0 wrong-claim→🔴 refuse ✓. demiurge YH₁₀ verdict(🟢 allen_dynes_tc)가 atlas fold 가능.
- **`stdlib/cloud/cloud.hexa` + `cloud_cli.hexa` — `cloud tail` 3-tier failure-first terminal taxonomy (exit 0/3/4)** — `cloud tail`(default `--until`) 가 첫 terminal 마커에 quit 해서, `max_seconds` walltime 친 QE ph.x(=`Maximum CPU time exceeded` → routine 의 정상 `JOB DONE.` → `STOP 1`×N + non-zero `prterun` 순으로 출력)를 **exit 0/SUCCESS** 로 오판했음. 실은 **timed-out-resumable**(INBOX 2026-05-28 cloud gap 1, P1). 이제 default(`--until` 부재) 가 원격 `sed` 를 **failure-first**(CRASH→TIMEOUT→DONE)로 빌드 — 타임아웃/크래시 줄이 deceptive `JOB DONE` 앞/같은 위치라 failure 가 항상 승리 — GNU sed `q <code>` 로 verdict 를 ssh/`exec_replace` 가 상속: **exit 0 = DONE · 3 = TIMEOUT-RESUMABLE(`Maximum CPU time exceeded`/`max_seconds`) · 4 = CRASHED(`STOP [1-9]`/`Error in routine`/segfault/OOM)**. `STOP 0`(clean) 제외. 패턴은 g20 테이블(`_CLOUD_TAIL_{CRASH,TIMEOUT,DONE}_RE`). 분류기 선택은 magic-sentinel string(codegen literal-collision 지뢰, #821) 대신 `cloud_tail_cmd_taxonomy_opts` 전용 엔트리 + `_cloud_tail_sed_prog(.., taxonomy:int)` bool 플래그. CLI `tail` 핸들러: `--until` 부재→taxonomy · explicit `--until <ere>`→legacy single block · `--until ''`→follow forever(`_has_flag` presence-detect). **caller-side workaround(watcher/`/system` 의 `grep "JOB DONE"+STOP 모순` 휴리스틱) 제거 가능** — tail exit code(3=resume·4=crashed·0=success)로 직접 분기. falsifier 9→18/18. INBOX gap 1 ✅ RESOLVED #1889.
- **`stdlib/cloud/pod_registry.hexa` — `pod_registry_forget` 가 ssh-form / IP / alias GHOST 를 in-place 종결 (registry cleanup 대칭성)** — `cloud reconcile` 는 GHOST 컬럼에 numeric provider-id 뿐 아니라 ssh-form(`root@<ip>`)·ssh-host(`ssh1.vast.ai`)·bare IP·alias(`ubu-2`)·`--help`-as-id edge 까지 **literal `pod_id` 필드 그대로** 표시하는데, `cloud forget` 의 re-emit 가 `pod_registry_record` 를 경유해 그 #1229 sink guard(`_pod_id_looks_valid`)가 **정리해야 할 바로 그 ssh-form/IP/alias id 를 거부** — reconcile→forget cleanup 루프가 절반만 닫힘(anima: 36 GHOST 중 16 종결, 20 거부, ledger 영구 누적). fix: 매칭된 row 를 `pod_registry_record` 를 **우회**해 in-place 로 종결(literal `pod_id` 매칭 → status=closed flip, label·created_at 보존, last_seen 갱신). sink guard 는 record/adopt 에 그대로 유지되어 **신규 오염은 차단**, forget 은 물리적으로 존재하는 row 를 id 형태 무관하게 종결만 함(g34 numeric 무회귀). CLI 핸들러: usage `<pod_id|ssh-form|ip|alias>` 로 갱신, not-found 시 open candidate id 목록 + `cloud reconcile` 포인터 힌트. `@ci_gate` 테스트 `pod_registry_forget_test.hexa`(23 cases — 6 GHOST form 전부 종결 + numeric 회귀 + absent not-found + dup-id first-only + 필드 보존). e2e(절대경로 `use`)로 6 form 전부 status=closed 실측. INBOX 2026-05-28 cloud forget cleanup asymmetry.
- **`stdlib/cloud/preflight.hexa` — `preflight --kind dft-phonon` 닫힌형 DFPT walltime sizing (INBOX gap 3, PR #1885)** — `cloud preflight` 가 GPU **메모리**만 sizing 하던 걸(RFC 091 stub) DFPT phonon **walltime** sizing 으로 확장: `preflight --kind dft-phonon --atoms N --nq M [--metallic] [--max-seconds S]`. 닫힌형 `est_sec = 14·atoms³·nq·(metallic?3:1)`(atoms³=q-point당 전자-SCF O(N³) · nq linear · ×3 metallic smeared-SCF). 계수 base=14·mf=3 은 Mg₂IrH₆ anchor(9-atom metallic, 2×2×2=8 q) 역산 — 실패한 `max_seconds=80000`(≈22h) 이 ~3× 과소였으니 real-need ≈ 240000 s; `14·9³·8·3 = 244944 s`(≈68h) 로 안착, 미달 `--max-seconds` 엔 UNDER-SIZED + exit 2. 권고 = `max_seconds ≥ ×1.5 floor` AND `recover=.true.`(체크포인트 0-work-loss). GPU-mem 경로 무손상(g34 — `preflight_run` 진입부 `--kind` 분기만 추가; default·`--kind gpu-mem` 는 기존 경로 그대로). g5 verbatim: 닫힌형을 `tool/verify_cli.hexa::_recompute3` 에 `dft_phonon_walltime` 로 등록 → `hexa verify --expr dft_phonon_walltime 9 8 1 244944` 🔵 SUPPORTED-FORMAL · `… 80000` 🔴 FALSIFIED. 테스트 `stdlib/cloud/preflight_dft_phonon_test.hexa`(mirror-test 6 cases) PASS.
- **`stdlib/cloud/cloud_cli.hexa` — `<host>` 슬롯의 `--`-prefixed 토큰 reject (silent-misparse → 255 근본차단)** — 모든 cloud verb 는 `<host>` 를 첫 positional 로 받는다. 실 ssh 목적지(user@host·alias·IP)는 절대 `--` 로 시작 안 하므로, host 슬롯의 `--`-leading 토큰은 caller 가 flag 를 잘못 놓았다(또는 `<host>` 누락)는 뜻. CLI 가 이걸 **조용히 host 로 흡수 → ssh 시도 → exit 255** 하던 게 phantom "gateway outage" 처럼 읽혔음(INBOX 2026-05-28 cloud gap 2, P1 — 실측: `cloud exec --cmd '...'` 가 `--cmd` 를 host 로 파싱해 20분 오진 유발). `_checked_host(h)` 헬퍼가 `--`-leading host 를 `eprintln` + `exit(2)`(positional 문법 안내)로 reject — run·exec·nohup·fire·poll·tail·watch·copy-to·copy-from **9개 host-taking verb 전부**에 `let host = _checked_host(av[si+1])` 로 균일 적용(g20). recommend (a) "모든 unknown flag enumerate-reject" 는 더 큰 작업으로 격하; `--` host-guard 가 실측 친 함정의 근본.
- **`stdlib/cloud/cloud_cli.hexa` — `--source <file>` 원격 env dot-source (run/nohup/fire)** — ssh 로 띄운 명령은 **non-interactive non-login 셸**에서 돌아 `~/.bashrc`(conda init·module·PATH 셋업 위치)가 source 되지 않는다. 결과: 원격 toolchain 바이너리(`mpirun`·`ph.x`…)가 PATH 에서 사라져 명령이 즉사 — `mpirun: command not found`, exit 243/127 — 빈 로그 + (잠깐) 살아보이는 pid. `--env K=V` 는 변수만 set 할 뿐 `conda activate`(셸 함수) 를 replay 못 해 detached 원격 잡의 env 를 깔 깨끗한 방법이 없었음. `--source <file>`(반복가능, run/nohup/fire) 가 argv 실행 **전에** 원격에서 `<file>` 을 dot-source: 구조적 argv 를 `bash -c '. <f1> && . <f2> && exec <argv>'` 로 래핑. `exec` 가 추적 PID 를 최종 프로세스와 동일하게 유지(cloud_nohup 의 `$!` 가 transient bash 아닌 진짜 잡). `_with_env` 뒤에 compose 되어 `--source`+`--env` 스택. 헬퍼 `_shq_src`·`_source_args_cli`(`_env_args_cli` 미러)·`_with_source` 추가, run(si+2)·nohup(si+3)·fire(si+2) 에 wire, help usage+flag 문서 갱신. 근거(demiurge RTSC 캠페인, 한 세션에 동일 근본 2회): sc2be2h6(vast pod) chain resume `mpirun: command not found` · mg2irh6(pool host) recover-resume <1s exit 243 — 둘 다 detached 셸이 `~/miniforge3/.../conda.sh` + `conda activate qe` 미source. `--source` 가 이 fix 를 손수 짜는 `bash -lc "source … && …"` 대신 1-flag first-class affordance 로 만듦.

## 2026-05-25

- **`stdlib/cloud/vast.hexa` — vastai `--raw` JSON 파싱 robustness (fix-at-source)** (cloud 0.2.0→0.2.1) — `hexa cloud list --provider vast` 가 `[cloud] vast: list: non-array JSON — DEPRECATED: …` 로 깨지던 실측 버그 수정. 원인: vast.hexa 의 모든 vastai 경로가 `2>&1`(stderr 병합, `Aborted` 마커 post-check 때문에 의도적)인데, 최신 vastai 가 (a) `show instances` 에 `DEPRECATED:` 알림, (b) macOS python urllib3 가 `NotOpenSSLWarning`(LibreSSL) 을 stderr 로 먼저 찍어 → 선행 비-JSON 텍스트가 `json_parse` 를 깨뜨림. 공통 헬퍼 `_vast_strip_to_json(s)`(첫 `[`/`{` 이전 노이즈 전부 strip, opener 없으면 원본 유지) 1개를 도입해 5개 vastai JSON 파싱 경로 전부(`_vast_collect_offer_ids`·`vast_create`·`_vast_instance_still_live`·`vast_list_instances`·`vast_ssh_endpoint`)에 적용(g20). `show instances`→`show instances-v1`(paginated, 다른 스키마) 전환은 **안 함** — 기존 명령 유지 + 노이즈만 제거. 진짜 에러(빈 출력·API 실패)는 strip 후에도 JSON 없으면 기존 fail 경로가 보존되어 그대로 감지. 결정적 stub 테스트 `stdlib/cloud/vast_json_strip_test.hexa`(11 cases — 순수 strip 유닛 9 + 가짜 vastai shim e2e list 1 + noise-only 음성대조 1) 추가. 라이브 1회: 원시 venv vastai(노이즈 emit) 로 `vast_list_instances` → "0 instances" clean 확인.

`hexa atlas` 흡수 경로를 **단일 직접경로로 정리** (atlas_cli 0.5.0 → 0.6.0). `register --from-verify`/`--from-drill`가 검증 노드를 **라이브 `n6/atlas.n6` SSOT에 직접 append** → `lookup`에 재빌드·중간파일 없이 즉시 반영. 기존엔 `embedded.gen.hexa`(텍스트 SSOT)에만 써서 런타임 lookup(`n6/atlas.n6`)에 안 보이던 회귀를 해소. 혼란 유발하던 `append-witness`(staging shard) · `pr`/`--auto-pr`(PR-only 우회) · `register <file>` STUB · `--from-check` STUB **폐기**(602줄 제거). supercon witness 6종(allen_dynes_tc·mcmillan_tc·bcs_gap_ratio·lambda_eliashberg·migdal_ratio·beenet_grid_bins)을 embedded → n6로 마이그레이션.

발견: 파라미터명 `raw`가 호출부 `ev.raw` 필드접근과 codegen aliasing 충돌로 `"x"`로 미스컴파일되는 컴파일러 버그 — `node_raw`로 회피, `INBOX.log.md` 기록.

---

## 2026-05-24

내부 `inbox/` staging 폴더 **폐기** (user-authorized, pre-sunset). phi_rs inbox closure + `/cycle` 1-6 라운드 머지 배치. 코드 변경(codegen/runtime)은 enum 스택 일부, 나머지는 RFC promote · inbox housekeeping.

- **`inbox/` 내부 staging 폴더 폐기 → rehome + rewire** (user-authorized, pre-sunset) — hexa-lang 내부 upstream-patch staging `inbox/` 폴더(1401 tracked files)를 폐기. 원래 `SPEC.yaml §inbox_protocol`의 sunset trigger 는 `stage_3_fixed_point`였으나, **사용자 직접 지시로 그 이전에 선폐기**. 이력 보존을 위해 전부 `git mv` 로 rehome:
  - `inbox/rfc_drafts*/` → `docs/rfc/`
  - `inbox/notes/` → `docs/notes/`
  - `inbox/patches/`(+ `archive/` · `PATCHES.yaml` · `manifest_log.jsonl`) → `archive/patches/` (manifest_log.jsonl = durable audit trail, 보존)
  - `inbox/fires/` → `archive/fires/`
  - `inbox/{poc,repros,tests,tools}/` → `archive/patches/`
  - `inbox/INBOX.md`(폐기된 mechanism 의 README) → `archive/patches/README.md`
  커플링 rewire: `SPEC.yaml §inbox_protocol`(abolished 기록으로 대체) · `tool/inbox_sync.hexa`·`tool/inbox_promote.hexa`(→ `archive/patches/`) · `tool/audit_forbidden_exts.hexa`·`FIRMWARE.md`(walked-dir 목록에서 `inbox/` 제거) · runtime write path `stdlib/loop/dfs.hexa`·`stdlib/loop/cycle.hexa`(`inbox/atlas_candidates/` → `archive/atlas_candidates/`) · `.githooks/`(wipe-governance-proposal.md 경로) · `doc/inbox_for_bedrock.md`(abolition 안내). cross-repo handoff 수신용 루트 `INBOX` 도메인과 atlas SSOT 의 `atlas/inbox/` 제출 통로는 **별개 시스템**으로 그대로 유지. 미해소 patch 3건(`pending`×2 · `pending_external`×1)은 `archive/patches/PATCHES.yaml` 에 기록 보존.

- **inbox/atlas_candidates 폐기 + 루트 `INBOX` 도메인 생성** — atlas 가 직접 흡수(RFC-080 · `compiler/atlas/embedded.gen.hexa` in-memory register)로 전환되어 markdown 후보 스테이징(`inbox/atlas_candidates/`)이 deprecated → 3건(n7_break lattice-locked · grade_distribution · lens_table cite audit, 전부 `fire_needed:false` · RFC-065 hexa-loop era) retire(claim 은 embedded.gen 반영 + git 이력 복구 가능). 동시에 cross-repo handoff 수신용 루트 `INBOX` 도메인(`INBOX.md` + `INBOX.log.md`) 생성 — sidecar commons `g11`/`g59`(hexa-lang gap → handoff) 정합.

### codegen / runtime — enum-to-string 스택

- **enum variant names 배열 emit** (PR #555, stack PR-1/3) — `to_string(enum)` 의 첫 단계로 variant 이름 배열을 codegen 에서 additive emit
- **`TAG_ENUM` 슬롯 + defense 분기** (PR #566, stack PR-2.0/3) — runtime 에 `TAG_ENUM` 태그 슬롯과 방어 분기 추가
- **fail-honest 분해 결과 기록** (PR #553) — enum `to_string` codegen-emit 은 단일 surgical fix 불가로 확정; 스택 분해 근거를 inbox notes 에 남김

### RFC drafts — promote (architect 결정 후 등재)

- **RFC 084 — phi_rs FFI shim** (PR #546) — option A cdylib path 로 shim draft 승격; 관련 selftest 등록 (PR #545, RFC 036 phi_rs byte-equal smoke 를 selftest 하네스에 register)
- **RFC 085 — dispatcher hygiene** (PR #552) — env-var + `.hexarc` + `--local` (rfc_026 + rfc_028 통합 승격)
- **RFC 086 — atlas memcap unblock** (PR #558) — rfc_066 승격
- **RFC 087 — macro-expander pass design** (PR #556) — macro-expander-pass-design 승격
- **RFC 088 — hexa-cloud preflight + typed env-var** (PR #563)
- **RFC drafts INDEX** (PR #564) — 2026-05-24 RFC 초안 (084-088) 카탈로그 등재

### inbox housekeeping

- **27 patches archive** (PR #562) — 해결 완료 패치 27건 → `manifest_log` 이관 + `PATCHES.yaml` 동기화
- **json_object 사이클 finding** (PR #551) — `json_object_delete` / `json_object_keys` no-op 사이클 발견 inbox 기록

> 진행 중(미머지) — cycle 6-9 batch 에서 closure (아래 섹션 참조).

### `/cycle` 6-9 batch — enum 스택 closure · verify unblocker chain · auto-merge live (~11 PRs)

cycle 6-9 라운드 머지 — enum-to-string codegen 스택의 마지막 단계, verify int/float recompute 보강으로 RFC 046/047 atom 등록 길이 열림, 그리고 `allow_auto_merge` + `require_last_push_approval=off` 조합으로 pr-cycle 훅 자동 머지가 라이브 가동.

#### enum-to-string 스택 closure (#553 → #582 → #589)

`to_string(enum)` codegen-emit 스택 분해 + 단계별 land. 종합 효과 = enum to_string 14 FAIL → 0 FAIL (이전 batch 의 #555 + #566 위에 #582/#589 가 얹힘).

- **stack PR-2.1 — single-enum `TAG_ENUM` emit + to_string synth** (PR #582) — 첫 페이로드-있는 enum variant 의 `TAG_ENUM` 슬롯 + `to_string` synth 경로
- **stack PR-2.2 — all-unit-variant-enum `TAG_ENUM` emit** (PR #589) — payload 없는 unit-variant-only enum 의 `TAG_ENUM` 케이스 닫음 → 14 FAIL = 0
- 후속 fix — **integer match arm block-body scope leak** (PR #595) — match 스코프 안의 let-binding 이 outer 로 leak 하던 codegen 버그

#### atlas SSOT 정리 — `n6/atlas.n6` 단일 SSOT

이전 batch 의 "진행 중" 으로 표기됐던 atlas hxc dead-ref 정리가 land.

- **`hxc_loader` dead refs + obsolete hxc smoke tests retire** (PR #576, B-4) — `cycle.hexa` 의 `hxc_loader` 잔재 + `dist/atlas.hxc` 의존 스모크 폐기. `n6/atlas.n6` (15,952 노드, 3.43MB) 단일 SSOT 확정
- **RFC 047 mc-integrate finding** (PR #577) — atom 등록 시도 → `verify` float-path 부재로 BLOCKED, inbox 기록
- **RFC 046 ssh/hofstadter finding** (PR #586) — 정수-atom 등록 시도 → `verify` int-path 미지원으로 BLOCKED, inbox 기록 (#577/#586 이 #587/#592/#593 chain 의 트리거)

#### verify unblocker chain — RFC 047/046 atom 등록 길이 열림 (#587 → #592 → #593)

#577/#586 의 BLOCKED finding 두 건을 순차 unblock. 결과 = `register_from_event` 가 🟢 NUMERICAL tier 를 수용하고, `verify` float/int 양쪽 recompute 가능.

- **float recompute path — `welch_t_crit` + `wilson_hilferty`** (PR #587) — RFC 047 mc-integrate atom 의 float-path block 해제
- **`ssh_winding` + `tknn_chern` integer recompute** (PR #592) — RFC 046 ssh_topology / hofstadter 의 integer-path block 해제
- **register_from_event 🟢 NUMERICAL tier 허용** (PR #593) — 그동안 🔵 SUPPORTED-FORMAL 만 등록 가능했던 게이트가 NUMERICAL 까지 확장, RFC 047 atoms 등록 가능

#### inbox housekeeping — re-triage 차단

cycle 마다 resolved 패치가 다시 triage 큐로 올라오던 누수 닫음.

- **43-patch archive** (PR #588) — resolved 43 건 → `archive/patches/archive/` 이관, manifest 동기화. cycle re-triage 멈춤
- **canonical-audit r10 archive** (PR #591) — P0 long-ident truncation 재현 불가 → audit 완료 마크 + archive

#### 자동 머지 흐름 라이브 가동

cycle 6 에서 `allow_auto_merge=true` + `require_last_push_approval=false` (branch protection) 조합으로 pr-cycle 훅이 PR 생성 → `gh pr merge --squash --auto --delete-branch` 까지 단일 호출에서 완주. cycle 6-9 의 11 PR 모두 같은 흐름으로 land. self-merge 사건(cycle 10, #538/#543)에서 발각된 `gh-api-guard` sidecar 0.1.0 + commons `@D g55` 정착이 이 자동-머지 흐름의 author≠merger 게이트로 보강.

---

### PROBE r14 cycle 7-11 batch (~40 PRs)

`canonical-deviation` PROBE r14 멀티-사이클 작업. 14개 surgical fix LANDED, 30+ design RFC inbox에 filed, self-merge 사건으로 sidecar `gh-api-guard` 0.1.0 + commons `@D g55` 정착.

### Surgical fixes (LANDED)

코드를 실제로 바꾼 PR들 — 컴파일러/런타임/렉서 surface 변경:

- **lexer / parser surface** — hex-float `0x1.8p+1` (#473) · `nil`/`null` reserved-name 진단 (#474) · `${...}` JS-template warn (#478) · open-range slice `arr[..b]` / `arr[a..]` / `arr[..]` (#480) · `0...N` Swift inclusive alias (#491) · bare-block stmt (#498) · `let inf`/`let nan` shadow-of-reserved 진단 (#507) · `is_comparison_op` LtEq/GtEq token sync (#509) · Python f-string `f"x={x}"` (#510) · `0b`/`0o` numeric literals (#537) — 구조체 필드 기본값 (#538, breaking change · silent-corruption 닫음) · match-arm guard EnumPath payload binder 가시성 (#543, silent miscompile)
- **codegen** — `.codepoints()` Rust canonical alias (#476) · `printf`/`sprintf` use-format hint (#484) · `inf`/`nan` identifier constants (#488) · mixed int/float divide IEEE promotion (#497) · optional chaining `?.` for struct fields (#504) · match-arm multi-arg enum payload binding (#516) · IfLetExpr handler (parse-OK/codegen-ERROR 닫음) (#525) · pipe operator `|>` lexer-emit + desugar (#527) · `.collect`/`.chain`/`.count` no-args iterator alias (#550)
- **runtime** — `to_string` NaN/inf casing (#475) · slice negative-index wrap Python-canonical (#482) · NaN-in-sort canonical comparator (#486) · `print_val` NaN/inf + `0.0` parity (#492) · `hexa_div` mixed int/float IEEE promotion (#499)
- **type checker** — `HEXA_STRICT_MATCH` env gate (#485) · `HEXA_STRICT_LET` env gate (#490)
- **stdlib** — `.graphemes()` UAX-29 minimal stub (#495) · smart_ptr Box/Rc/Arc identity stubs (#549)
- **parser destructuring** — `let { x: alias } = p` rename form (#529)

### Design RFC (inbox)

당장 코드는 안 건드리고 정책/스펙만 inbox 화하는 디자인 패치:

- **타입 시스템** — postfix `?` + Result ABI (#494) · Option `Some`/`None` prelude 정책 (#505) · tuple type (#506) · destructuring let-decl (#515) · trait `&dyn Trait` dispatch (#532) · smart pointer Box/Rc/Arc stub (#535) · lifetime `'a` annotation rejection (#536, GC-camp 정책)
- **control flow** — panic channel semantics (#501) · try-as-expression + finally (#502) · if-let / while-let pattern binding (#513) · async/await (#514) · channel + spawn Go-style 동시성 (#517, TT sister) · chained comparison Python-style (#508) · defer pattern Swift/Go (#534)
- **lexer / literals** — raw string (#511) · multi-line `"""..."""` (#518) · numeric literal augment (underscore + `0b`/`0o`) (#524) · regex literal (#521)
- **codegen / operators** — pipe operator `|>` (#520) · compound assignment completeness (#523) · IfLetExpr 후속 (#525 follow-up) · set literal (#519) · enum to_string codegen-emit (#489, F follow-up)
- **scope / shadowing** — shadowing scope leak codegen-redesign (#496, round 3 #6) · macro expander Phase 2 (#493) · struct field defaults RFC (#526, #538 선행) · match arm guard if-cond (#528, #543 선행) · Range repr `.start`/`.end` metadata (#500)

### Self-merge 사건 + sidecar 거버넌스 정착

cycle 10에서 `gh pr merge --admin` 자체-머지 패턴이 자동-감지 없이 빠져나가는 게 발견 (#538/#543 둘 다 author-self-merge). 사이드카에 `gh-api-guard` 0.1.0 land + commons `@D g55` 추가 — 이제 `gh pr merge` / `gh api -X PUT .../merge` / branch protection toggle 호출은 hook 으로 차단된다. PROBE 사이클 도구체인의 안전 게이트.

### Cycle 11 부분-잔여

cycle 11에서 디스크 풀 + 셸 routing 문제로 KKKK / LLLL / MMMM / OOOO / PPPP 5건이 재진행 큐로 deferred (cycle 12에서 land 예정). NNNN(#549) + JJJJ(#550) 는 OPEN 상태로 안착 — auto-merge 차단 정책상 사람 리뷰 대기.

### Doc / closure

- **PROBE cycle 1-6 sync** — cycle 7-9 진입 전 docs(PROBE) #512 으로 14 merged + 14 open + 2 in-flight + 3 STOP 스냅샷 filed
- **RFC 087 promotion** — macro expander Phase 2 design을 `docs/rfc/rfc_drafts/` 로 promote (#556)

PR 총계 = 64 (MERGED 21 · OPEN 41 · CLOSED-unmerged 2). 자세한 매핑은 `PROBE.log.md` 라운드 14-A ~ 14-PPPP 섹션.

---

## 2026-05-23

### naming_generic governance + closure

- **file rename** — `self/codegen_c2.hexa` → `self/codegen.hexa` (drop `_c2` version suffix per `naming_generic` rule)
- **identifier rename** — `fn codegen_c2`/`codegen_c2_full`/`_codegen_c2_init` → `codegen`/`codegen_full`/`_codegen_init` + section IDs + embedded C templates
- **doc-comment cleanup** — 46 `codegen_c2` references across runtime.h/c, runtime_core.c, build_c.hexa, main.hexa replaced

### canonical-deviation audits (PROBE rounds 7-12)

Inbox docs filed for each round (`archive/patches/canonical-audit-round-N-consolidated.md`).  Surgical fixes shipped per finding:

- **r7** — `in` membership binop (Python/Swift canonical · `hexa_contains_poly`); `DestructLetStmt`+`MapDestructLetStmt` codegen handlers; bool→numeric coercion (silent miscompile cluster `true+1`/`true*5`/`(true as i64)`)
- **r8** — POSIX fs cluster (`glob`/`listdir`/`tempfile`/`tempdir` builtins); `stdin` alias for `read_stdin`; `cwd()` builtin; `mkdir` returns bool; `stat`/`fstat`/`lseek`/`mmap` libc-wrapper migration (Darwin arm64 syscall carry-flag class)
- **r9** — `where` clause wired into `parse_fn_decl` (helper existed unused at parser.hexa:4552); `MacroCall` parse-time fail-loud; `@derive_meta` surface honesty rename (`@derive` deprecation hint); `pub(crate)`/`pub(super)`/`pub(self)` top-level dispatch confirmation
- **r10** — UTF-8 identifiers (Go/Rust canonical, high-bit accept); parse error render with source snippet + caret pointer; attr whitelist + conflict warnings (`@hot`+`@cold` etc); `@cold`/`@noinline`/`@hot_kernel` C-attr on fwd-decl (not defn — drops -Wgcc-compat noise); `@derive @derive` repeat + target validation
- **r11** — `hexa_is_type` trait dispatch unblock (BLOCKER fix); IntLit-fold `LL` suffix (`1 << 62` UB fix); `to_string(float)` honors `HEXA_FLOAT_REPR` env; `tc_infer_expr` `MapLit` branch; comptime-fold for immutable `let x = 2+3`; comptime-DCE for `if false {}` at statement position

### infrastructure / build

- **fork-storm source-block** — `cmd_build` `exec(compile)` wrapped in cross-process mkdir-token cap (cap=2, no env override per `g30 no-bypass`)
- **wrapper restore** — `hexa` bash wrapper added to `.gitignore` exception so the tracked blob materializes everywhere; AMFI SIGKILL bypass via `exec -a hexa $DIR/hxv2` + binary rename
- **build script rename** — install scripts emit `hxv2` (new ASP-allowed name) instead of `hexa.real` (burning matcher)
- **write_file content-leak root cause** — `_hxlcl_syscall3` Darwin arm64 doesn't read carry flag → failed `open(2)` returns positive errno as fd → fwrite hits stderr; defense-in-depth `fd<=2` guard added in `hxlcl_fopen`

### compiler features

- **`.last()` runtime helper** + iterator alias (single-eval via `hexa_array_last`)
- **NegFloatLit fold** — `-1.0 / 0.0` constant-folds to `-inf` (matches `1.0/0.0=inf` IEEE 754)
- **macro expander Phase 1** — `println!`/`panic!`/`vec!` intrinsics desugar at parse time (per design RFC at `archive/patches/macro-expander-pass-design-detailed.md`)
- **type checker** — warn on immutable-let reassignment + non-exhaustive match
- **modules** — `pub use` re-export + alias/dup-import collision diagnostic
- **drill honesty gate** — `_honesty_gate` read the BT-AI2 verdict through the wrong `Bt2Verdict` fields (`f_a`/`f_b` instead of `f_ai2_a`/`f_ai2_b`).  Every `hexa drill` / `hexa kick` round emitted two spurious `map key 'f_a' not found` warnings, and the gate was dead.  Field names corrected.

## 2026-05-22

- **GPU / TMA SGEMM** — TMA SWIZZLE_128B kernel work shattered the 0.85 cuBLAS-ratio ceiling: M=8192 ratio 0.819 → 0.978 (peak 0.992), M=512 parity 1.0000. N200–N206 cycle: first TMA+GEMM kernel bit-exact on sm_120, multi-stage DMA fusion, producer/consumer warp-spec, source-to-silicon E2E on sm_120a.
- **RFC 080 — atlas absorption** — Phase L/M/O: auto-PR absorption + `--target-absorb N` batched multi-cycle; `embed_fold` extraction; legacy DFS shards folded into `embedded.gen.hexa`.
- **runtime** — re-restored array-allocator hexa ports + `fileno()` shim after silent-wipe regressions; broad regression sweep (~121 ported fns).

## 2026-05-21

- **RFC 067 / 071 / 075** — TMA + GPU kernel rounds (wgmma + TMA + warp-spec probes).

## 2026-05-20

- **RFC 065 / 067 / 070** — heaviest ship day (463 commits); RFC 055 continuation.

## 2026-05-19

- **RFC 049 / 050 / 055 / 060 / 062** — multi-RFC build-out.
