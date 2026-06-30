# hexa-lang

Native compiler for the `.hexa` language with an embedded theorem **atlas** and the `hx`
package manager. No LLVM anywhere: source is lowered through the compiler's own IR to native
objects (ELF64 / Mach-O arm64) and linked with `hexa_ld` — a byte-identical self-host fixpoint
(`gen3 ≡ gen4`), default for `--emit`. Two C pieces still remain: a C-transpile fallback
delegate for some full `hexa build`/`run` flows, and the ~5.5k-LOC C runtime substrate (the
libc/syscall bootstrap floor, generated from `.hexa` emitters) — the floor RUNTIME-PORT is
still shrinking (M3 open), an irreducible-bootstrap assessment, **not** a permanence policy.
Every formula-bearing function must cite an atlas law (`@cite(L[id])`), carry an active
`@verify`, or declare a `@grace` — otherwise the build refuses to emit a binary (stage S8,
fatal `HX8004`). **Domain tracking is fully retired** (2026-06-20): the per-domain `*.md`
snapshots, `*.log.md`/`*.tape` step-logs, `DOMAINS.tape` roster, **and the ARCHITECTURE.json
`domains` section itself** are gone — domain/milestone status + history live in CHANGELOG + git
only (no domain registry).

> ### ⚡ 성능 정답지 — 프론티어 언어/프레임워크 기준 (최우선 구현 렌즈 · 2026-06-29 오너)
> hexa-lang 구현은 **Go · Rust · PyTorch 를 reference-match 정답지(gold standard)**로 삼아 우선 구현한다 (commons `reference-match`·`native-canonical-first` 강화 · 기존 '추월(overtake)' 규율과 정합 — 프론티어가 어떻게 하는지 먼저 보고 맞춘다).
> - **성능 바 = Rust 동등 이상 (≥ Rust).** Rust 가 1차 성능 기준 — 컴파일러·런타임·생성코드·커널은 Rust 와 동등하거나 그 이상이어야 한다. **단 no-LLVM(LLVM-free)·byte-exact 는 양보 없는 핵심 불변(초월 축)으로 *유지*** — 이를 유지한 채로 Rust 성능에 닿는다(드롭/우회 아님). "LLVM-free 라서 느려도 OK"식 자족만 금지(불변 유지 ≠ 느림 정당화) — Rust 에 성능으로 지면 미완이되, **LLVM 도입으로 이기는 건 정답 아님**(no-LLVM 직접 native-emit codegen 으로 이긴다).
> - **수치/ML throughput 축 = PyTorch(+cuBLAS) 동등 이상.** flame/forge GEMM·학습·디코드 throughput 은 PyTorch 를 정답지로 측정·대조.
> - 정답지가 오픈소스면 그 구현을 **직접 보고 맞춘다**(소스 파일:라인 → 성분 1:1 대조 → 첫 발산점 정렬), parity 후 hexa 고유 '초월 축'(byte-exact·vendor-free·no-LLVM·device-residency)으로 전진. 성능 주장은 **실측이 증거**(c2 · measure-or-it-didn't-happen).
> - **정석성 = 성능 parity 뿐 아니라 표면/관용(API·idiom)도 정답지에 맞춘다.** reference 생태계의 **1차 표면**(torch `use_deterministic_algorithms()` 같은 런타임 API · cargo/pip/go-mod 관행)을 그대로 따르고, bespoke env-flag/wrapper/shim 으로 대체하지 않는다. 성능이 동등해도 *표면이 비정석*(env-only·손수 우회)이면 미완. **commons `native-canonical-first` 는 성능 배너와 동급 1차 렌즈** — 성능·표면 둘 다 reference-match.
> - **실증(#4214):** 결정성 모드 표면 = env-only `HEXA_DET` 는 torch canon 의 절반(env=escape-hatch 수준) → 네이티브 API `set_deterministic(true/false)` 1차 + env escape-hatch 로 교정(PR #4214). = "표면도 정답지" 원칙의 첫 적용 — eval/verdict/decode 진입점이 `set_deterministic(true)` 인-프로세스 직접 호출로 결정성 강제 가능(구 `HEXA_DET` setenv 불가 caveat 해소).

> 📍 구조/설계 SSOT: [ARCHITECTURE.json](ARCHITECTURE.json) — 디렉터리·모듈 트리 + dataflow 단일
> 원장 (JSON; 사람용 뷰어 `architecture.html` · `python3 serve.py`) · 거버넌스/규칙 SSOT: 아래
> 작업 규칙 (`harness.config.json` profile `hardcore` · stack `hexa` · vendored
> [dancinlab/harness](https://github.com/dancinlab/harness) `.harness-engine` submodule) · 이력:
> [CHANGELOG.jsonl](CHANGELOG.jsonl) (append-only). This file = entry pointer only (구 `project.tape` ·
> `ARCHITECTURE.md` · per-domain 트래킹 retired).

### 작업 규칙 개요 (do / dont)

릴리스 무결성 · 셀프호스트 · 아틀라스 · 추월. 모든 규칙은 substantive — 빼지 말고 지킬 것. 아래
`## ` 섹션들이 거버넌스 SSOT (각 섹션 = slug-keyed do/dont).

### Harness

This repo is governed by the vendored [dancinlab/harness](https://github.com/dancinlab/harness)
engine, pinned as the `.harness-engine` git submodule and wired through `.claude/settings.json`
hooks (guarded: each hook is a no-op when the submodule binary is absent). Config lives in
`harness.config.json` (profile `hardcore`, stack `hexa`). The harness enforces single-document
discipline (architecture SSOT + append-only log + quickref pointers), L0 lockdown reminders,
the changelog gate for `.hexa` changes, and protected branches (`main`, `master`).

```sh
git submodule update --init --recursive          # activate (hooks no-op until present)
.harness-engine/bin/harness <cmd>                 # via wrapper
```

#### Quick reference

| Command | Purpose |
|---------|---------|
| `harness docs check` | single-doc discipline: architecture SSOT + log + quickref pointers |
| `harness lint` | staged-L0 + freshness + convergence gate |
| `harness verify` | run configured verification (`hexa verify`) |
| `harness audit` | 6-axis self-scorecard |
| `harness gc` | broken markdown links in guides |
| `hexa verify` | g5 gate: S6 equational + S8 citation + atlas reverify/auto-fold |
| `hx commit` / `hx push` | SSOT-attested git wrappers (re-run lint gate) |

## 릴리스 무결성 — 절대 상위 가드레일

- do: self-host 작업(byteeq `gen3≡gen4` · measure · RT-NATIVE · zero-C)은 **실제 사용 릴리스를
  망가뜨리지 않는 선에서만** 진행한다. 회귀 위험이 있으면 릴리스 그린을 먼저 보장한 뒤 진행하고,
  위험하면 self-host 진척을 미룬다 — **릴리스 무결성 > self-host 진척**.
- dont: 출하 바이너리(`hexa`/`hexa.real`) · `hexa build`/`run` · stdlib · C-transpile fallback
  등 **사용자 사용 경로를 깨는 변경**을 self-host 게이트(native arena · `#else` drop · substrate
  바이트감소)를 위해 머지하지 말 것.
- do: 코드젠/런타임 변경은 **byteeq 3타깃(x86_64-linux · arm64-linux · darwin-arm64) GREEN +
  출하 smoke 통과**를 확인한 뒤에만 머지한다. 비트동일 개선은 게이트 없이 기본빌드로(예: gemm-perf
  #3636 무게이트 2.4×), 비트변경·환경의존 개선만 opt-in 토글로 격리한다(예: gemm-omp #3634
  `HEXA_OMP=1`).
- do: 릴리스 채널은 **`stable` 단일** — 소비자 기본 · 검증된 `vX.Y.Z` Latest. 구 `edge`·`test`
  롤링 prerelease 채널은 **모두 완전 폐기**됨 (`edge` 2026 초 · `test` 2026-06-30). `test` 폐기
  = release.yml `on.push.branches:[main]` 트리거 제거 + setup `release_tag=test` 분기 제거 +
  `test` 태그 force-move 스텝 제거 + install.sh `HEXA_VERSION=test` 경로 제거 + 원격 `test`
  릴리스·태그 삭제. 실험적 self-host 변경(byteeq · measure · RT-NATIVE · zero-C · static-musl)의
  검증은 **PR CI(Blacksmith 3타깃 byteeq) + pool 빌드**로 받는다 — 상시 흐르는 prerelease 채널 없음.
  static-musl·cuda 보조 자산은 이제 매 `vX.Y.Z` 태그 릴리스에 동봉(install.sh 가 없으면 glibc 폴백).
- dont: **"x86 만 green" 으로 stable 승격 금지** (v0.241.0 arm64 asset 미발행 회귀 교훈 — 한 타깃
  그린은 전체 그린이 아니다). stable 승격은 3타깃 릴리스 잡 전부 GREEN + install.sh 소비자
  스모크(`hexa --version` + hello/exit42 run) GREEN 일 때만.
- do: 기계적 강제를 신뢰한다 — `release.yml` 의 각 플랫폼 잡은 asset 을 prerelease 로만 업로드하고
  Latest 를 마킹하지 않는다. `finalize` 잡(`needs:` 3타깃 전부)이 3/3 성공 시에만 태그를 stable
  Latest 로 flip 한다 (v0.241.0/.1 2/3-Latest 사고 차단).
- do: 신규 릴리스(`vX.Y.Z` 태그) 발행 직후 pool 공유 호스트(`aiden` · `summer`)에도 그 릴리스를
  `install.sh` 로 동기화한다 — `harness pool on <host> 'curl -fsSL .../hexa-lang/<tag>/install.sh | sh'`
  (pool 의 빌드·byteeq·measure 가 stale 바이너리/시드를 물지 않도록).

## 구현 규율 — implement-to-the-wall · reference-first

- do: 모든 구현·개선·조사는 **벽(🧱)에 닿을 때까지** 민다. 한 라운드가 끝나면 honest next
  round(r2 · r3…)를 명명하고, 멈추는 건 오직 ⓐ 목표 달성(🏁) 또는 ⓑ **측정된** 닫힌-음성
  벽(🧱: 효율 roofline · 정확성 · 기능에서 더 나아갈 honest 다음 단계 부재)일 때뿐이다. 근본원인을
  **머지까지** 끌고 간다.
- dont: 중간에 "발견/진단만 하고 STOP" 금지 (punt 금지). 증상 패치 · shadow 가드 금지. filler
  라운드를 지어내지 말 것.
- do: 벽은 **캡처된 수치**로 증명한다(roofline % · byte-eq Δ · measured GFLOP/s). LLM
  자가판정으로 벽/이득을 주장하지 말 것.
- do: 알려진 알고리즘을 from-scratch 구현·개선할 때는 **타 언어·패키지의 검증된 코드를
  정답지(reference)로 펼쳐 보고 전략을 차용**한다. white-box 차분: ⓐ reference 소스 정독 →
  알고리즘·검증상수 추출(파일:라인 인용) ⓑ reference 중간값 실행 덤프 ⓒ 내 구현의 같은 양과
  성분별 1:1 대조 → 발산점 수치 특정 ⓓ **그 지점만** 정렬. 정답지 못 보는 경우(closed · 덤프불가)에만
  black-box. 정답지 정확복제 후 잔차는 강제로 맞추지 말고 출처(pseudo · grid · precision) 정직 기록.
- dont: 목표 수치를 좇아 파라미터(타일 · 언롤 · 블로킹 상수 · 튜닝값)를 흔드는 **black-box 추측
  sweep 금지** (compute 낭비 + tune-to-green 위험). reference 매핑 실증: GEMM/farr_matmul perf
  → OpenBLAS/BLIS microkernel(BLIS GEBP MR6 NR8 MC72 KC256 NC4080 packing+3단 캐시블로킹 = 62~79%
  OpenBLAS roofline · r4 #3652, 플래그 튜닝 ~10–24% 천장의 반례) · LLM decode/weight 적재 →
  llama.cpp/ggml(mmap+contiguous unboxed tensor) · QFORGE el-ph 물리 재현 → Quantum ESPRESSO 중간값
  덤프 대조 · 수치 커널 → numpy/scipy/LAPACK.
- do: parity 는 출발점이지 종착점이 아니다 — reference 차용으로 동등(parity)에 도달하면
  **reference 가 못 가진 hexa 고유 강점으로 뛰어넘는(beyond-parity)** 방향을 honest next round 로
  탐색한다. hexa 추월 레버: ⓐ byte-eq 결정성(gen3≡gen4 fixpoint) ⓑ no-LLVM 직접 네이티브
  emit(codegen 이 커널 직접 빚어 fusion/arena 특화 · 호출경계 제거) ⓒ device-resident · @cite 검증
  학습(flame/forge) ⓓ 도메인 융합. 추월도 **측정 수치로 증명**(roofline % · GFLOP/s · byte-eq Δ).
  실증: GEMM+epilogue(bias/residual) fusion = large +20%(max|Δ|=0) · prefill +3.3% · MLP +5.5%(r5
  #3656) · cuBLAS 호출 7→0(FP64 own 1.15~1.24× 빠름 byte-neutral + TF32 mma.sync m16n8k8 parity ·
  default-ON `HEXA_OWN_GEMM`/`HEXA_TF32_OWN` 로 opt-OUT · #3718/#3727). 다음 추월 = chained-GEMM
  fusion(`gelu(x@W1)@W2` 중간 activation DRAM 미실체화).
- dont: 아무거나 융합 ≠ 이득 — memory-bound epilogue(bias/residual)만 융합한다. compute-bound
  epilogue(gelu 등) 융합은 closed-neg(연산비용 > 왕복절감). byte-eq 결정성은 추월 레버 아님
  falsified(OpenBLAS 도 같은 빌드서 thread-무관 비트동일 · r5 측정).

## HEXA-UNBOX — "박스 벗기기" (런타임 속도 캠페인 · 호출 트리거)

- do: 사용자가 **"박스 벗기기"**(`HEXA-UNBOX`)라 하면 이 캠페인을 잇는다 — native boxed-HexaVal 16B 세금을 커널마다 벗겨 raw native 직결 → **실제 런타임 가속**(k1 2.95×·k2/k4 4.48×·k3 9.78×). SSOT=memory `project_hexa_runtime_gap_allclosure`.
- do: 측정-우선 — `tool/measure_codegen_perf.sh`(isolated 교대 median-7); in-harness back-to-back ratio=오염(9.78×→1.000 가린 전례 3회)→isolated reversed-order 재측정; reference-match=gcc magic-reciprocal·V8 PACKED_SMI.
- do: 머지 레버=default-OFF env opt-in(`HEXA_PACK_ARRAY` 등·byte-neutral); escape-lattice=alias-set 전이 void(escape-stress 9커널 OFF==ON #4121); honest-next=default-ON·타커널·array wire-to-prod·f64/f32 packed.
- dont: tune-to-green · 오염 ratio 천장박제 · escape per-local void(aliasing miscompile) · 측정못한 inert 레버 머지 · default-ON 을 정규 CI byteeq 3타깃+nvptx GREEN 전 flip(Blacksmith 아님·#4016 revert).

## QA — 지속 검증 · verify-done 상시화

- do: 모든 fix·기능·측정은 **measure → root-cause → build-verify → 머지** 한 루프로 닫는다.
  검증은 **캡처된 출력**으로 한다(LLM 자가판정 금지) — 코드젠/런타임 변경은 byteeq 3타깃 + 관련
  config 전수(예: REF · DEVRESIDENT · DEVFEED) byte-eq 실측, 측정 주장은 reference-match
  (roofline % · cuBLAS · nsys 커널 귀속)로 정답지에 대조해 증명한다.
- do: QA 는 **세션 상시 루프** — 한 fix 가 닫히면 다음 QA 라운드(인접 op · 엣지케이스 · 회귀)를
  명명하고 잇는다. 멈추는 건 🏁(목표 달성) 또는 측정된 벽(🧱)일 때뿐. falsified/음성도 결과로
  보고하고 **자기수정 궤적을 정직히** 남긴다(예: "launch-bound" → nsys 귀속 → memory-bandwidth-bound
  로 정정).
- do: 측정 노이즈가 크면 **더 낮은 레벨의 안정 신호로 귀속**한다(하네스 wall-clock 노이즈 → nsys
  커널 median). 절대수치 주장 전 metric 의미를 코드로 확인한다(층위 혼동 금지 — SM-util ≠ FLOP-효율).
- dont: 미검증 "완료" · 한 config/한 타깃만 green 으로 머지 · per-op 단위테스트만 하고 "됐다"(전수
  config QA · production 배선 누락) · 측정 아티팩트를 과학 천장으로 박제 · tune-to-green.
- do: QA 산출(verdict · 측정 수치)은 memory/CHANGELOG/state 로 박제하고, cross-repo 측정은
  `ing add --to <repo>` 로 relay 한다. 빌드/측정은 aiden/summer/vast pool(mini=git/gh only ·
  akida 금지). 자세한 의무는 commons `verify-done` · `break-walls` · `reference-match` 와 lockstep.
- do: **forge/flame GPU 성능 측정은 반드시 "현행 main hexat"으로 한다** — 풀에 깔린 stock 릴리스
  hexat(예 v0.442.0)은 main 의 `forge_dispatch_*` builtin 을 모를 수 있어 그 심볼을 `hexa_call3/4`
  값-디스패치로 잘못 lowering → 컴파일 실패(타입에러) 또는 **느린 CPU 폴백으로 측정**(75331ms 류
  bad-hexat 아티팩트 → phantom 4750× 박을 뻔한 2026-06-29 교훈). `test` 롤링 채널 폐기(2026-06-30)
  후 현행 hexat 확보 = **pool 호스트(aiden/summer)에서 main 체크아웃을 직접 빌드한 hexat**(`tool/release_build`
  또는 `./hexa install.hexa`)으로 측정한다. 측정 전 ⓐ pool 에서 현행 main 빌드 → ⓑ `hexa gpu` 로
  cuda_available + 버전 현행 확인 → ⓒ bench 실행 시 `[OWN-GEMM-FIRED] DEVICE path` 발화 확인. SSOT =
  convergence `bench-hexa-clm-step-hexa-1`.
- dont: 풀 hexat 현행성 확인 없이 forge 벤치 절대시간 측정·박제(bad-hexat 폴백을 진짜 perf 로 오판) ·
  builtin 부족을 per-op `hexa cc --regen` 으로 우회(공유 툴체인 오염 = 후속 측정 전부 무효) · stable
  릴리스를 벤치 한 건 때문에 컷(release-integrity 과함 — pool 에서 main 직접 빌드가 정석 unblock) ·
  폐기된 `HEXA_VERSION=test` 경로에 의존(채널 없음).
- do: QA 는 **native-canonical-default polarity 위반도 감사·교정**한다 — 기본 경로는 항상
  hexa-native/own/canonical 이고 외부의존(cuBLAS · 외부 BLAS · 벤더 라이브러리 · legacy fallback)은
  **opt-in 플래그로만** 존재해야 한다(아래 [native-canonical-default] 가드레일과 lockstep). QA 가
  역전된 polarity(native 를 플래그 뒤로 숨기고 외부의존을 기본으로 둠 · `HEXA_NO_<vendor>` 로 native
  를 opt-in · 손짜기 Taylor 등 codegen-fragile 대체)를 발견하면 **교정 PR 로 닫는다** — 플래그 명명이
  켜는 것이 "제약/외부의존 활성화"가 되도록 정렬(`HEXA_USE_<vendor>` · `HEXA_<feature>_FALLBACK` ○ /
  `HEXA_NO_<vendor>` ✗). 교정은 byteeq-safe(felt-default=native 유지)로, 빠른 외부의존 경로는 명시
  opt-in 으로 남긴다.

## native-canonical-default — polarity

- do: 기본 경로는 **항상 hexa-native/own/canonical**. 외부 의존(cuBLAS · 외부 BLAS · 벤더
  라이브러리) · 실험 · legacy fallback 은 **플래그(env/컴파일 매크로)로 opt-in 하는
  "제약"으로만** 존재한다. 올바른 예 — forge GPU GEMM: own 커널이 default · cuBLAS 는
  `HEXA_USE_CUBLAS` opt-in.
- do: **⚠️ determinism 축은 명시적 예외(owner 결정 2026-06-28)** — GPU 수치 determinism 은 위
  "비결정=opt-in" 규칙에서 빠진다. torch/JAX 정석(non-det 기본 + `use_deterministic_algorithms`
  opt-in)을 따라 **fast non-det 가 default · det 가 opt-in(`HEXA_DET`)**. 단 이 예외는 **오직
  determinism 한 축**에만 적용되고 **own/vendor polarity 는 불변** — fast-default 도 **own-native
  비결정 커널**(atomic split-K own-GEMM · own scatter · own batched)이 canonical default 이고,
  vendor cuBLAS-TC 는 여전히 opt-in(`HEXA_USE_CUBLAS`, cuBLAS-independence 캠페인 정합). 상세 =
  아래 [flame/forge determinism].
- dont: **polarity 역전 절대 금지** — native 를 플래그 뒤로 숨기고 외부의존을 기본으로 두지 말
  것(잘못된 예 = `HEXA_NO_CUBLAS` 로 native 를 opt-in · #3742 교정 대상). 플래그 명명은 켜는 것이
  "제약/외부의존 활성화"여야 한다(`HEXA_USE_<vendor>` · `HEXA_<feature>_FALLBACK` ○ /
  `HEXA_NO_<vendor>` ✗).
- do: native-default 가 perf 회귀를 일으키면(예: consumer-GPU BF16 ~2× 느림) **polarity 는
  유지하되** 빠른 외부의존 경로를 opt-in 플래그로 남겨 선택 가능케 한다(felt-default = native ·
  빠른 길은 명시 opt-in). 느려지는 건 깨지는 게 아니며, 위 [릴리스 무결성]의 "사용자 경로를 깨지
  말라"와 양립한다.
- do: **개발자경험(DX) 표면 전체가 native-canonical install 경로여야 한다 — 위 polarity(커널 default)
  와 별개의 *툴체인/패키징 층* 정석성.** 적용 범위 = 패키지/라이브러리 관리(`hx install`·의존성 해결·
  lockfile·버전 핀·registry) · 설치/갱신(`hx install`·`hexa self-update`) · 빌드변종(CPU/GPU·target)
  · GPU 활성화 · 환경 부트스트랩. **각 표면은 기성 생태계의 정석을 그대로 따른다** — `pip`/`cargo`/`npm`/
  `go mod`(install·add·lock·resolve) · `pip install torch`(호스트 맞춤 GPU wheel 자동) · `rustup`/
  autotools(toolchain·feature·`nvcc` 감지). **hexa 제작자가 타 언어 native 관행에 익숙지 않을 수 있으므로,
  에이전트가 native-canonical-first 판단으로 그 정석을 *알아서 강제·교정*한다**(creator 가 모르는 관행을
  에이전트가 채움 — 묻어두지 말 것). 새 DX 표면은 "이게 cargo/pip/npm 이라면 어떻게 동작하나"를 먼저 묻고
  그 관행으로 설계.
- do: **GPU 활성화 = 위 원칙의 첫 구체 인스턴스.** canonical 설치/갱신 명령이 CUDA 호스트(nvcc+GPU 감지)에서
  `cuda_available()=1` 런타임을 **자동 산출**해야 한다 — 감지→cuda 자산 빌드/페치→`~/.hx/bin/build/runtime.a`
  배선까지 한 번에, 끝에 `hexa gpu` 가 cuda_available 1 을 보고(`pip install torch` 가 GPU wheel 자동 받듯).
- dont: DX 표면을 **비정석으로 방치 금지** — 사용자가 손으로 빌드/swap/우회해야 쓸 수 있으면 그건
  packaging 결함이다. GPU 실측 결함(2026-06-26 anima clm303 GPU 측정 중 발견):
  ① `tool/build_cuda_runtime` 가 `ar x` 로 전체추출 후 링크는 `*_native.o` CORES 만 →
  `undefined reference hexa_array_push/hexa_sub/hexa_str_join`(비-native 오브젝트 누락) ·
  ② `stage_resolve_runtime_a` CUDA-R1 이 frozen seed 로 돌아도 링크된 runtime.a 는 cuda syms 3개뿐 →
  `cuda_available()=0` 잔존 · ③ stock 릴리스에 `-cuda` 자산 미배포 + `hx install` 에 GPU 감지 경로 없음.
  → GPU 박스(nvcc+GPU 확인됨)에서도 한 명령으로 GPU 가 안 켜지는 건 결함이지 사용자 잘못이 아니다.
  같은 잣대로 다른 DX 표면(라이브러리 관리·의존성·설치)도 정석 대비 갭이 보이면 그 자리에서 교정.
- do: stdlib signal/math는 **native libm trig** 기본권장 · self-host(zero-c libm native-emit)·정확도 필요 시 **손수 수학 커널 허용**(fdlibm/musl minimax·Taylor · byteeq+reference-match 게이트).
- dont: 정답지(fdlibm/musl) 무시 추측계수 fudge · reference-match 없는 정확도 주장 금지.
- do: **cross-target libc-floor(`hxlcl_*`) native-emit 의 정석 = codegen per-fn C-ABI
  calling-convention** (Route C). `_is_cabi(fname)`(`hxlcl_` 프리픽스/whitelist) hook 이 codegen
  3 경계(param-ingress · return · call-boundary)×2 백엔드(x86_64·arm64)에서 PAIR-MODEL
  HexaVal`{tag,payload}` 를 **single-register C-ABI**(SysV `rdi`/`rsi`/… · return `rax` /
  AAPCS64 `x0`/… · return `x0`)로 lowering 한다(C-ABI 헬퍼 `_x86_64_arg_reg_seq` 기존 재사용).
  reference-match: GCC `sysv_abi`/`regparm` · rustc `extern "C"` · zig `callconv(.C)` · Go
  `ABI0` — 모든 주요 컴파일러의 정석. **한 codegen 기능이 전 `hxlcl_*` 심볼 × 3 타깃을 일괄
  cross-target dissolve** (default-OFF whitelist · byteeq-neutral · DEFAULT shim.o sha 불변).
  SSOT: 메모리 `project_hexa_rfc061_hxlcl_crosstarget_abi_wall`.
- 상태(RFC061 #29 Route C 캠페인 · 측정종착): syscall/2nd-return-reg/named-data/environ/FILE*/
  file-local-static family + ELF cross-target member-swap mem/str pure-leaf 10/10(strlen·memcpy·
  memset·memcmp·strcmp·strncmp·strcpy·strncpy·strcat·strchr) + pipe/fork/getenv/setenv/popen 등
  dissolve(전부 default-OFF·byteeq-neutral·admin-merge). 잔여 = 측정벽 3개 — varargs-ABI
  (`hxlcl_fprintf` · va_list 가 frozen runtime.c 거주 → frozen blob 편집 불가 = release-integrity
  하드라인 🧱) · svc-remainder(getrusage/time = frozen floor inert stub이라 native-emit 해도
  floor-reduction 0 = investment-poor 🧱) · **hxlcl_signal = SA_RESTORER/raw-fn-address codegen 벽 🧱**
  (ING#29 측정교정: literal-∅ 렌즈로 재점검 — shim 멤버 −1 은 달성 57→56·DEFAULT byte-identical·
  rt_sigaction install 은 OK·old disposition SIG_DFL 반환·raise→handler 발화 OK, **but SIGSEGV on
  return RC=139** — x86_64 커널이 sa_restorer 진짜 기계어 fn(`mov rax,15;syscall`=rt_sigreturn) 요구·
  codegen 에 raw-fn-address intrinsic 부재(fn-address 는 TAG_FN box 로만 존재·struct 필드에 못 넣음)·
  libc signal() control 은 동일호스트서 RC=0). reopen = raw-fn-address codegen intrinsic OR
  restorer-trampoline emit mechanism. **주의: "floor-reduction 0" 은 signal 의 wall 근거가 아님**
  (직전 agent 가 frozen floor TU 와 drop-ON shim TU 를 혼동 — literal-∅≠floor-reduction, convergence
  `runtime-core-hxlcl-shim-c-1` 재확정). arm64 leg 은 restorer 불필요(커널이 trampoline 제공)하나
  Route C emit 이 x86_64-linux-only 라 미측정. reopen 조건: hexa IR raw-fn-address 추상 OR frozen
  re-baseline OR floor-meaningful syscall leaf 출현.
- dont: 심볼당·타깃당 **hand-assembled machine-byte 배열**로 cross-target 확장 금지
  (non-canonical · O(symbols×targets) 노동 · 유지보수 폭발 — `test/native_build/emit_hxlcl_*_o.hexa`
  darwin Mach-O 손-assemble 은 codegen C-ABI 모드 부재 시의 임시 우회였고 Route C 로 승계).
  새 `@<attr>`/키워드/builtin **허용**(no-LLVM 외 모두 허용) — frozen blob 151c52c8 파서 미지면
  frozen re-baseline 동반 OR name-prefix/whitelist hook 으로 byteeq-safe 도입(faithful build-break 회피).

## flame/forge determinism — API 1차 + env escape-hatch / fast-nondet DEFAULT

- do: flame/forge GPU 수치는 **2 경로**, fast non-det DEFAULT(owner 2026-06-28 · torch/JAX 정석). (A) DEFAULT = own-native atomic kernels (split-K GEMM/GEMV · atomic-scatter · atomic embed-bwd; + vendor cuBLAS-TC via `HEXA_USE_CUBLAS`). (B) det OPT-IN = fixed-order non-atomic (byte-exact cross-host).
- do: #4214 **det 표면 = API 1차 + env escape-hatch** (torch `use_deterministic_algorithms()` ref-match). API = `set_deterministic(true/false)` / `is_deterministic()` (`stdlib/flame/forge_det.hexa`). env = `HEXA_DET=1` (shell/CI escape-hatch). precedence: API > env.
- do: `set_deterministic` 구현 = `hexa_forge_set_deterministic(int)` C (`runtime_cuda.c` `_hx_forge_det_mode` process-global; `runtime.h` non-CUDA inline stub). `_forge_det_on()` = API mode 우선, fallback env.
- do: eval/verdict/decode 안전핀 = 진입점이 `set_deterministic(true)` 직접 호출(API 1차). 구 HEXA_DET setenv 불가 caveat 해소. CI byteeq/오라클 잡은 `HEXA_DET=1` env(escape-hatch) 유지 가능.
- do: 소비자(anima) = 학습 fast non-det default · eval/verdict/decode det(`set_deterministic(true)`). ckpt 품질 = held-out DESCENT(bit-det 불요). own/vendor polarity 불변 — own-native canonical, cuBLAS opt-in. GPU det 축은 selfhost-determinism-gate 와 별개.
- dont: 안전핀 우회(eval/verdict/decode det 없이 채점·박제) · vendor cuBLAS fast-default 승격 · CI det 강제 누락 · det default 복귀 · HEXA_DET env 를 API 보다 우선순위 승격 금지.

## 아틀라스 · 검증

- do: 발견 엔진(수론 · 물리 · 우주 · 생명)의 사람용 원장은 **`ATLAS/README.md` 단일 SSOT**(n=6 축0
  출발 · 거시↔양자 수학 지도 · 구 `TECS-L/` 에서 개명 2026-06-18). 지도는 README.md 에 **점진적으로
  그려나간다**(one-shot 아님 · 검증된 노드/다리를 계속 채움).
- do: 아틀라스는 2층이다 — **사람층** `atlas/README.md` + `atlas/hypotheses/*.md`, **기계층 SSOT**
  `compiler/atlas/embedded.gen.hexa`(verdict atom). 적재는 **항상 둘 다**로 간다. `🔵`/`🟢`
  `hexa verify` 성공 시 atom 이 embedded.gen.hexa 로 **자동 fold**(verify = 단일 canonical 표면 ·
  별도 `atlas register` ceremony 없음). atlas 노드 fold 는 `compiler/atlas/embedded.gen.hexa` 에만,
  branch → commit → PR 경로로(다른 곳 금지).
- dont: 사람층만 갱신하고 기계층(embedded.gen.hexa) 누락 금지. 미판독 · 미검증 · lattice-fit ·
  미증명 conjecture 는 🔵 승격 금지. **n=6 은 지도 중심이 아니라 노드 1개**(lattice-as-tool · 외부
  영역 anchor 금지).
- do: 수학 DFS 는 **`hexa loop --dfs` 로 진행**(external-LLM 단일 surface · 예산캡 + verify
  게이트), 결과는 `ATLAS/README.md` 연대기 + `ATLAS/CLAUDE.md` 에 기록. 빌드 불가 환경(mini)에서
  만든 DFS/fleet 검증 노드는 `state/novel-dfs/*_fold.py` 로 `@F` kind atom(`verified:false` ·
  고전이면 cite 명시 · 🔵 승격은 `hexa verify` 통과로만)을 embedded.gen.hexa 에 **PR-fold** 한다.
- dont: external LLM 을 `hexa loop --dfs`(budget cap + verify gate) 밖에서 호출하지 말 것. ad-hoc
  스크립트 금지.
- dont: retired 잔재 사용 금지 — 구 `atlas/`(소문자) 폴더 · `TECS-L/` 명칭 · TECS-L
  다문서(`TECS-L.md` · `n6.md` · `millennium/` · `.verdicts/`) · `.tape` 원장(CLAIMS 등) · 별도
  `atlas/CLAUDE.md`(atlas 거버넌스는 이 루트 CLAUDE.md 단독 SSOT).
- do: domain audits 는 `hexa verify --<axis> <domain>` 서브커맨드로 land 한다(one CLI surface · 새
  top-level verb 금지).

## git · L0 · lockstep

- do: 가드 파일 변경 전 subagent 가 diff 한다(`git diff <baseline>...HEAD` · `.githooks/pre-commit`).
- dont: `stdlib`/`runtime`/`codegen`/`rt` 에서 >50줄 삭제를 scoped subject 나 `WIPE-OK:` trailer 없이
  커밋하지 말 것.
- do: L0 lockdown 파일(`harness.config.json` → `lockdown.files`) 편집 시 같은 변경에서
  `CHANGELOG.jsonl` 를 갱신한다.
- do: `hexa`(릴리스/CLI) 업데이트 시 `hexa --help` · `hexa gpu` 출력을 **lockstep 갱신**한다 — 새
  GPU 능력 · 플래그 · 빌드변종 · dtype parity 변화가 나면 같은 변경에서 `cmd_help()`/
  `cmd_gpu_status()` 텍스트를 갱신한다(타 리포가 `hexa gpu` 를 GPU/flame/forge/cuda 상태 SSOT 로
  신뢰하므로 stale 금지).
- do: 모든 HuggingFace 업로드/Collections 는 `dancinlab` org 아래 둔다.

## CI · self-hosted runners

- do: **클라우드 CI = Blacksmith** — ephemeral·멀티타깃 잡(예 `release.yml`)은 **Blacksmith 호스티드
  러너**로 돈다: `blacksmith-6vcpu-macos-15`(darwin) · `blacksmith-4vcpu-ubuntu-2204`(linux-x64) ·
  `blacksmith-4vcpu-ubuntu-2404-arm`(linux-arm64). 즉 **self-hosted 풀(ghost/aiden/summer)이 다운이어도
  PR 게이트(selfhost-byteeq·determinism·codegen-guard·miscompile-zero·nobaseline 등)는 Blacksmith에서
  돈다** → 릴리스무결성 검증(byteeq 3타깃 + 출하 smoke)은 로컬 SSH 풀이 막히면 **PR 열어 Blacksmith CI**로
  받는다(로컬 풀 SSH 불안정 시 정석 경로). self-hosted 러너는 아래처럼 일부 무거운 faithful/byteeq 잡만
  opt-in으로 집어가는 보조 풀이다.
- do: 무거운 faithful/byteeq 빌드는 **self-hosted 러너**가 처리한다 — `ghost`(darwin-arm64 ·
  label `selfhost-gen2fix` · darwin byteeq) + `aiden`/`summer`(linux-x64 · label `hexa-build` ·
  12c/30G 공유 빌드 풀). 잡이 opt-in 하는 법: `runs-on: [self-hosted, Linux, X64, hexa-build]`
  (linux-x86_64 전용 · 예 `nobaseline-gate.yml` faithful-nobaseline linux-x86_64). **linux-arm64 ·
  darwin-arm64 · ephemeral 환경이 필요한 잡은 클라우드 러너 그대로 둔다** — arm64 self-hosted 호스트
  없음(honest, arm64 커버리지 주장 금지).
- do: public repo 라 **fork-PR 은 메인테이너 승인 후에만** self-hosted 러너가 집어간다(RCE 완화 ·
  ghost 선례와 동일). 러너에서 green 을 실측한 뒤에만 required 잡을 옮긴다.
- dont: 필수 게이트(`selfhost-gates-summary`)를 **검증 안 된/오프라인 러너에 의존시키지 말 것** —
  required 잡은 러너에서 green 을 실측한 뒤에만 옮긴다.
- do: 러너는 systemd **서비스**로 등록(`~/actions-runner-hexa` · `sudo ./svc.sh install` · 재부팅
  생존 · 호스트당 단일 러너 — 풀 빌드 starve 금지 · 우리 빌드는 여전히 1-SSH 규율). 오프라인이면
  재등록: `gh api -X POST repos/dancinlab/hexa-lang/actions/runners/registration-token -q .token`
  →  호스트에서 `cd ~/actions-runner-hexa && ./config.sh --url … --token <tok> --labels
  self-hosted,Linux,X64,<host>,hexa-build --unattended --replace && sudo ./svc.sh start`. 상태는
  `gh api repos/dancinlab/hexa-lang/actions/runners`.

## 거버넌스 기준 — no-LLVM 외 모두 허용 (사용자 standing 2026-06-29)

- do: **유일 불가침 = no-LLVM**(소스→컴파일러 IR→네이티브→`hexa_ld`). 그 외 모든 구현기법 허용 — 손수 수학커널·새 키워드/`@<attr>`/builtin·frozen re-baseline·va_list/setjmp ABI 전부 가능(과거 "기법 금지"=영구금지 아닌 측정비용 권고).
- dont: no-LLVM 깨기(LLVM 백엔드/IR 경유) 절대금지 · 그리고 4규율(release-integrity·byteeq 3타깃 검증·reference-match·git-safety) 건너뛴 미검증 머지 금지(허용 기법도 게이트는 통과).
