# hexa-lang

Native compiler for the `.hexa` language with an embedded theorem **atlas** and the `hx`
package manager. No LLVM anywhere: source is lowered through the compiler's own IR to native
objects (ELF64 / Mach-O arm64) and linked with `hexa_ld` — a byte-identical self-host fixpoint
(`gen3 ≡ gen4`), default for `--emit`. Two C pieces still remain: a C-transpile fallback
delegate for some full `hexa build`/`run` flows, and the ~5.5k-LOC C runtime substrate (the
libc/syscall bootstrap floor, generated from `.hexa` emitters) — the floor RUNTIME-PORT is
still shrinking (M3 open), an irreducible-bootstrap assessment, **not** a permanence policy. See
[ARCHITECTURE.json](ARCHITECTURE.json) → Self-host status for the honest accounting (사람용 뷰어 `architecture.html`, `python3 serve.py`). Every
formula-bearing function must cite an atlas law (`@cite(L[id])`), carry an active `@verify`, or
declare a `@grace` — otherwise the build refuses to emit a binary (stage S8, fatal `HX8004`).
The full architecture SSOT is [ARCHITECTURE.json](ARCHITECTURE.json) (JSON 트리 — 사람은 `architecture.html` 뷰어로 봄, `python3 serve.py`); this file is the single governance SSOT (md 단일화 — `project.tape`·`ARCHITECTURE.md` retired). **Domains** are folded into ARCHITECTURE.json → `domains` section (final-form registry: `@goal` + status + remaining); the per-domain `*.md` snapshots, `*.log.md`/`*.tape` step-logs, and `DOMAINS.tape` roster are **retired** (2026-06-17) — ARCHITECTURE.json is now the sole domain record, milestone history lives in CHANGELOG.md + git.

## Structure

```
hexa-lang/
├─ compiler/        — the compiler: S0–S8 strict-lint gate + HIR/MIR/LIR lowering + native emit
│  ├─ lex/          — S0 lexer (.hexa → tokens)
│  ├─ parse/        — S0 parser (tokens → AST)
│  ├─ check/        — S1–S8 stages (resolve · bind · types · units · equational · citation)
│  ├─ atlas/        — embedded atlas (embedded.gen.hexa rodata) + static index + fold/merge
│  ├─ lower/        — AST → HIR → MIR (SSA) lowering
│  ├─ optimize/     — const-fold · DCE · inline (opt-level 0–3)
│  ├─ codegen/      — MIR → LIR per target (arm64-darwin · x86_64-linux · thumbv7em · nvptx)
│  ├─ emit/         — LIR → asm / direct Mach-O / ELF object serialization
│  ├─ diag/         — diagnostic catalog (HX0001–HX8004) + renderers
│  └─ main.hexa     — compiler driver entry point
├─ stdlib/          — runtime + domain modules (io · math · crypto · codec · bio · chem · flame · forge)
├─ self/            — self-hosting bootstrap (compiler written in .hexa that builds itself)
├─ tool/            — hx package manager (hx.hexa) · atlas CLI (atlas_cli.hexa) · linker (hexa_ld.hexa)
├─ bin/             — CLI front-end shims (hexa-run · hexa-fast · hexa-commit · hexa-push)
├─ ATLAS/           — `README.md` 단일 원장 = 수학 지도 (발견 엔진 · 거시↔양자) · 구 TECS-L/·atlas/(소문자) retired
├─ spec/            — language + format specification
├─ tests/, test/    — smoke · core-invariant · regression suites
├─ bench/           — performance benchmarks
├─ docs/            — supplementary documentation + logo
├─ ARCHITECTURE.json — architecture SSOT (JSON 트리, update in place) + architecture.html 뷰어 + serve.py
├─ CHANGELOG.md     — append-only history / decisions
├─ CLAUDE.md        — governance SSOT (this file — directives below)
└─ .harness-engine/ — vendored harness (submodule); gate engine behind .claude hooks
```

## Governance

This file is the single governance SSOT (md 단일화) — edit directives here, keep them concise:

- **diff-guard** — a subagent diffs guarded files (`git diff <baseline>...HEAD`) before staging
  (`.githooks/pre-commit`).
- **wipe-guard** — do not commit >50-line deletions in `stdlib`/`runtime`/`codegen`/`rt`
  without a scoped subject or a `WIPE-OK:` trailer.
- **atlas fold** — fold atlas nodes only into `compiler/atlas/embedded.gen.hexa` via
  branch → commit → PR (never elsewhere).
- **ATLAS math-map** — 발견 엔진(수론·물리·우주·생명)의 사람용 원장은 `ATLAS/README.md`
  **단일 SSOT** (n=6 축0 출발 · 거시↔양자 수학 지도 · 구 `TECS-L/` 에서 개명 2026-06-18).
  지도는 README.md 에 **점진적으로 그려나간다** (one-shot 아님 · 검증된 노드/다리를 계속
  채움). 검증 atom 의 기계 SSOT 는 `compiler/atlas/embedded.gen.hexa`, history 는 CHANGELOG +
  git. **수학 DFS 는 `hexa loop --dfs` 로 진행** (external-LLM 단일 surface · 예산캡 + verify
  게이트 · ad-hoc 스크립트 금지), 결과는 `ATLAS/README.md` 연대기 + `ATLAS/CLAUDE.md` 에 기록.
  **retired**: 구 `atlas/`(소문자) 폴더 · `TECS-L/` 명칭 · TECS-L 다문서(`TECS-L.md`·
  `TECS-L.log.md`·`n6.md`·`docs/`·`millennium/`·`.verdicts/`) · `.tape` 원장(CLAIMS 등).
  **n=6 은 지도 중심이 아니라 노드 1개** (lattice-as-tool · 외부 영역 anchor 금지) ·
  미판독·미검증·lattice-fit·미증명 conjecture 는 🔵 승격 금지(c2). · **atlas 거버넌스 단일 기록** — atlas 영역 규칙은
  이 루트 CLAUDE.md 가 단독 SSOT (별도 `atlas/CLAUDE.md` 파일 없음 · retired).
- **verify is ambient · atlas 2-layer 자동적재** — 아틀라스는 2층이다: **사람층** `atlas/README.md`
  + `atlas/hypotheses/*.md`(수학 지도), **기계층 SSOT** `compiler/atlas/embedded.gen.hexa`(verdict atom).
  적재는 **항상 둘 다**로 간다(사람층만 갱신하고 기계층 누락 금지 · c2). `🔵`/`🟢` `hexa verify`
  성공 시 atom 이 embedded.gen.hexa 로 **자동 fold**(verify = 단일 canonical 표면 · 별도 `atlas register`
  ceremony 없음). `hexa loop --dfs` 도 동일 경로(emit→verify-gate→absorb→fold · `PR if >0`). 빌드 불가
  환경(mini)에서 만든 DFS/fleet 검증 노드는 `state/novel-dfs/*_fold.py` 로 `@F` kind atom
  (`verified:false` · 고전이면 cite 명시 · 🔵 승격은 `hexa verify` 통과로만)을 embedded.gen.hexa 에
  **PR-fold** 해 기계층 적재를 보장한다.
- **domain audits** — land as `hexa verify --<axis> <domain>` subcommands (one CLI surface,
  no new top-level verbs).
- **stdlib trig = libm** — signal/math modules use native libm trig (`cos`/`sin`/…), never
  hand-rolled Taylor series (codegen-fragile).
- **external LLM** — invoke external LLMs only via `hexa loop --dfs` (budget cap + verify gate).
- **HF namespace** — all HuggingFace uploads/Collections live under the `dancinlab` org.
- **L0 edits** — editing a lockdown file (see `harness.config.json` → `lockdown.files`)
  requires updating `CHANGELOG.md` in the same change.
- **release → pool 동기화** — 신규 릴리스(`vX.Y.Z` 태그 발행) 직후 pool 공유 호스트
  (`aiden`·`summer`)에도 그 릴리스를 `install.sh` 로 세팅(동기화)한다 —
  `harness pool on <host> 'curl -fsSL https://raw.githubusercontent.com/dancinlab/hexa-lang/<tag>/install.sh | sh'`.
  pool 의 빌드·byteeq·measure 가 stale 바이너리/시드를 물지 않도록(자기복제 측정 신뢰성·c2),
  릴리스마다 공유자원을 최신 prebuilt 로 맞춘다.
- **self-host ≠ release 회귀** — self-hosting 완성(byteeq `gen3≡gen4`·measure·RT-NATIVE·zero-C)
  작업은 **절대 실제 사용 릴리스를 망가뜨리지 않는 선에서** 진행한다. 출하 바이너리(`hexa`/`hexa.real`)·
  `hexa build`/`run`·stdlib·C-transpile fallback 등 **사용자 사용 경로를 깨는 변경은 금지** — 셀프호스트
  게이트(native arena·#else drop·substrate 바이트감소 등)를 위해 릴리스를 회귀시키지 않는다. **릴리스
  무결성 > self-host 진척**: 회귀 위험이 있으면 릴리스 그린을 먼저 보장한 뒤 진행하고(코드젠/런타임
  변경은 byteeq + 출하 smoke 통과 확인 후 머지), 위험하면 self-host 진척을 미룬다.
- **릴리스 채널 규율 (edge=실험 · stable=승격)** — self-host 진척(byteeq·measure·RT-NATIVE·zero-C·
  static-musl 등 실험적 변경)은 `main` push → **edge prerelease**(`HEXA_VERSION=edge` 로 설치)로 상시
  흘린다. 소비자 기본 경로(`install.sh` → 최신 stable `vX.Y.Z`)는 **3타깃(x86_64-linux·arm64-linux·
  darwin-arm64) 릴리스 잡 전부 GREEN + install.sh 소비자 스모크(`hexa --version` + hello/exit42 run)
  GREEN** 일 때만 새 stable 태그로 승격한다. **"x86 만 green" 은 승격 불가**(v0.241.0 arm64 asset 미발행
  회귀 교훈 — 한 타깃 그린이 전체 그린 아님). 즉 실험은 edge 에서 검증·soak, stable 은 전타깃 green
  승격 — 이것이 [self-host ≠ release 회귀]의 운영 방식이다(소비자=stale-but-stable, 실험=edge).
  **기계적 강제**: `release.yml` 의 각 플랫폼 잡(x86_64·arm64·darwin)은 asset 을 **prerelease 로만**
  업로드하고 Latest 를 마킹하지 않는다 — `finalize` 잡(`needs:` 3타깃 전부)이 3/3 성공 시에만 태그를
  stable Latest 로 flip 한다. 한 타깃이라도 실패하면 finalize 가 skip 돼 릴리스가 prerelease 로 남고
  `install.sh` 의 stable 해석이 그 부분(2/3) 릴리스를 건너뛴다(v0.241.0/.1 2/3-Latest 사고 차단).
- **implement-to-the-wall (벽까지 구현)** — 모든 구현·개선·조사는 **벽(🧱)에 닿을 때까지**
  민다 — 중간에 "발견/진단만 하고 STOP" 금지(c1·c3 punt 금지). 한 라운드가 끝나면 honest
  next round(r2·r3…)를 **명명**하고, 멈추는 건 오직 ⓐ 목표 달성(🏁) 또는 ⓑ **측정된**
  닫힌-음성 벽(🧱: 효율 roofline·정확성·기능에서 더 나아갈 honest 다음 단계 부재)일 때뿐이다.
  근본원인을 **머지까지** 끌고 간다(증상 패치·shadow 가드 금지). 벽은 **캡처된 수치**로
  증명한다(LLM 자가판정 금지·c2 — 예: roofline %·byte-eq Δ·measured GFLOP/s). filler 라운드를
  지어내지 않는다(g0). **가드레일은 위 [self-host ≠ release 회귀] 가 절대 상위** — byteeq 3타깃
  GREEN + 출하 smoke 통과 전에는 머지 금지(릴리스 무결성 > 진척). 비트동일 개선은 게이트 없이
  기본빌드로(예: gemm-perf #3636 무게이트 2.4×), 비트변경·환경의존 개선만 opt-in 토글로 격리한다
  (예: gemm-omp #3634 `HEXA_OMP=1`).
- **reference-first 구현 (정답지 펼쳐 차용 · commons c23 의 hexa 적용)** — 알려진
  알고리즘을 from-scratch 구현·개선할 때는 **타 언어·패키지가 이미 구현해 검증한 코드를
  정답지(reference)로 펼쳐 보고 그 전략을 차용**한다. 목표 수치를 좇아 파라미터(타일·언롤·
  블로킹 상수·튜닝값)를 흔드는 **black-box 추측 sweep 금지**(compute 낭비 + tune-to-green
  위험·c2). white-box 차분: ⓐ reference 소스 정독→알고리즘·검증상수 추출(파일:라인 인용)
  ⓑ reference 중간값 실행 덤프 ⓒ 내 구현의 같은 양과 **성분별 1:1 대조**→발산점 수치 특정
  (c1 root-cause) ⓓ **그 지점만** 정렬(정렬이지 fudge 아님). 정답지 못 보는 경우(closed·
  덤프불가)에만 black-box. 정답지 정확복제 후 잔차는 강제로 맞추지 말고 출처(pseudo·grid·
  precision) 정직 기록. **hexa 정답지 매핑**: GEMM/farr_matmul perf → **OpenBLAS·BLIS**
  microkernel(packing+register-tiling+캐시블로킹) — **측정 실증**(aiden Zen5): FMA/march 플래그
  만지기는 roofline **~10–24% 천장**(r3 #3644 — "플래그 함정") · 검증된 **BLIS GEBP 알고리즘
  차용**(MR6 NR8 MC72 KC256 NC4080 packing+3단 캐시블로킹 + separate restrict 마이크로커널)으로
  **62~79% OpenBLAS roofline**(r4 #3652 — 83~107 GFLOP/s, 135 GFLOP/s 베이스라인 **실측**, i6
  대비 **3.5~4.5× 도약**) → **reference 알고리즘을 펼쳐
  차용하는 것이 파라미터 튜닝보다 압도적 레버**임을 수치로 증명(black-box sweep 의 반례) ·
  LLM decode/weight 적재(boxing·KV-cache) → **llama.cpp·ggml**(mmap+contiguous
  unboxed tensor) · QFORGE el-ph |g|² 등 from-scratch 물리 재현 → **Quantum ESPRESSO** 중간값
  덤프 대조 · 수치 커널 → **numpy·scipy·LAPACK**. **동등 도달은 출발점이지 종착점이 아니다
  (parity→beyond-parity 탐색 · implement-to-wall 과 결합)** — reference 차용으로 **동등 수준
  (parity)** 에 도달하면 거기서 멈추지 말고, **reference 가 못 가진 hexa 고유 강점으로 그것을
  뛰어넘는(beyond-parity) 방향을 honest next round 로 탐색**한다. parity 는 "빠르게 벽까지
  도달"하는 수단(추격자 비용 절감)이고, 추월이 진짜 목표다. **hexa 추월 레버**(reference 가
  구조적으로 안 하는 것): ⓐ **byte-eq 결정성**(gen3≡gen4 fixpoint·검증가능 재현 — BLAS/ggml
  은 비결정 reduction 허용) ⓑ **no-LLVM 직접 네이티브 emit**(codegen 이 커널을 직접 빚어
  fusion/arena 특화 — 범용 라이브러리가 못 하는 호출경계 제거) ⓒ **device-resident·@cite 검증
  학습**(flame/forge) ⓓ **도메인 융합**(예: GEMM+conv 단일 saturating 커널 — cuDNN/cuBLAS 가
  못 주는 3rd option). 단 추월도 **측정 수치로 증명**(roofline %·GFLOP/s·byte-eq Δ — LLM
  자가판정 금지·c2), filler 추월 주장 금지(g0). **추월 실증·정직**(r5 #3656): ⓑ+ⓓ **GEMM+
  epilogue(bias/residual) fusion** — BLAS 가 별도 패스로 강제하는 것을 codegen 이 타일-hot 시
  융합해 메모리 왕복 제거 → **+20%**(large, max|Δ|=0)·prefill +3.3%·MLP +5.5%. **그러나 측정이
  레버를 가린다**(아무거나 융합 ≠ 이득): ⓐ byte-eq 결정성은 추월 레버 **아님 falsified**
  (OpenBLAS 도 같은 빌드서 thread-무관 비트동일, r5 측정) · **gelu 같은 compute-bound epilogue
  융합은 closed-neg**(연산비용 > 왕복절감, 스칼라-tail de-vectorize) → bias/residual 같은
  memory-bound epilogue 만 융합. 다음 추월 r6 = **chained-GEMM fusion**(`gelu(x@W1)@W2` 의 중간
  activation 을 DRAM 에 미실체화 — FlashAttention 정신, cuBLAS 가 호출경계 때문에 못 하는 것).
  즉: reference 로 parity 까지 빠르게 → 측정된
  parity 확인 → reference 의 미탐색/비결정 영역을 hexa 강점으로 추월하는 r(n+1) 명명·진행.
  **cuBLAS 독립 실증**(2026-06-20 · #3718 FP64 + #3727 TF32 · #3721 close): forge production
  GEMM(`self/cuda/runtime_cuda_emit.hexa`)의 cuBLAS 호출 **7→0** — FP64 6지점(own 1.15~1.24×
  빠름)+TF32 1지점(own mma.sync m16n8k8 production-path **0.85~0.97× parity**·relRMS==cuBLAS)
  own-kernel 대체, opt-in(`HEXA_OWN_GEMM`/`HEXA_TF32_OWN`)·OFF 비트동일. census r3 'TF32
  0.2~0.3× 속도천장 🧱' 는 **잘못된 커널(WMMA 고수준 API) 측정 오류로 falsified** —
  reference-first parity 커널(`owngemm_sm120.cu` mma.sync)이 이미 in-tree 였고 production 배선만
  누락이던 것(c23 ⓑ no-LLVM 직접 emit 으로 cuBLAS 의존 제거 실증 · byte-eq 결정성 = cuBLAS 미제공 moat).
  **가드레일은 위 [self-host ≠ release 회귀]
  가 절대 상위**(reference 차용도 byteeq 3타깃 GREEN 전 머지 금지·비트변경은 opt-in 격리).

## Harness

This repo is governed by the vendored [dancinlab/harness](https://github.com/dancinlab/harness)
engine, pinned as the `.harness-engine` git submodule and wired through `.claude/settings.json`
hooks (guarded: each hook is a no-op when the submodule binary is absent). Config lives in
`harness.config.json` (profile `hardcore`, stack `hexa`). The harness enforces single-document
discipline (architecture SSOT + append-only log + quickref pointers), L0 lockdown reminders,
the changelog gate for `.hexa` changes, and protected branches (`main`, `master`).

Run the engine:

```sh
git submodule update --init --recursive          # activate (hooks no-op until present)
.harness-engine/bin/harness <cmd>                 # via wrapper
```

### Quick reference

| Command | Purpose |
|---------|---------|
| `harness docs check` | single-doc discipline: architecture SSOT + log + quickref pointers |
| `harness lint` | staged-L0 + freshness + convergence gate |
| `harness verify` | run configured verification (`hexa verify`) |
| `harness audit` | 6-axis self-scorecard |
| `harness gc` | broken markdown links in guides |
| `hexa verify` | g5 gate: S6 equational + S8 citation + atlas reverify/auto-fold |
| `hx commit` / `hx push` | SSOT-attested git wrappers (re-run lint gate) |
