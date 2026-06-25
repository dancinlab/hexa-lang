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

> 📍 구조/설계 SSOT: [ARCHITECTURE.json](ARCHITECTURE.json) — 디렉터리·모듈 트리 + dataflow 단일
> 원장 (JSON; 사람용 뷰어 `architecture.html` · `python3 serve.py`) · 거버넌스/규칙 SSOT: 아래
> 작업 규칙 (`harness.config.json` profile `hardcore` · stack `hexa` · vendored
> [dancinlab/harness](https://github.com/dancinlab/harness) `.harness-engine` submodule) · 이력:
> [CHANGELOG.md](CHANGELOG.md) (append-only). This file = entry pointer only (구 `project.tape` ·
> `ARCHITECTURE.md` · per-domain 트래킹 retired).

## 작업 규칙 (do / dont)

릴리스 무결성 · 셀프호스트 · 아틀라스 · 추월. 모든 규칙은 substantive — 빼지 말고 지킬 것.

### 릴리스 무결성 (절대 상위 가드레일)

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
- do: 릴리스 채널은 딱 둘 — **`stable`**(소비자 기본 · 검증된 `vX.Y.Z` Latest) 과 **`test`**(실험
  롤링 prerelease · `main` push 마다 갱신). 실험적 self-host 변경(byteeq · measure · RT-NATIVE ·
  zero-C · static-musl)은 `main` push → test prerelease 로 상시 흘린다(`HEXA_VERSION=test`). 구
  `edge` 채널은 **완전 폐기**됨 (install.sh alias · release.yml `edge` 태그 push · 원격 `edge` 태그 모두 제거).
- dont: **"x86 만 green" 으로 stable 승격 금지** (v0.241.0 arm64 asset 미발행 회귀 교훈 — 한 타깃
  그린은 전체 그린이 아니다). stable 승격은 3타깃 릴리스 잡 전부 GREEN + install.sh 소비자
  스모크(`hexa --version` + hello/exit42 run) GREEN 일 때만.
- do: 기계적 강제를 신뢰한다 — `release.yml` 의 각 플랫폼 잡은 asset 을 prerelease 로만 업로드하고
  Latest 를 마킹하지 않는다. `finalize` 잡(`needs:` 3타깃 전부)이 3/3 성공 시에만 태그를 stable
  Latest 로 flip 한다 (v0.241.0/.1 2/3-Latest 사고 차단).
- do: 신규 릴리스(`vX.Y.Z` 태그) 발행 직후 pool 공유 호스트(`aiden` · `summer`)에도 그 릴리스를
  `install.sh` 로 동기화한다 — `harness pool on <host> 'curl -fsSL .../hexa-lang/<tag>/install.sh | sh'`
  (pool 의 빌드·byteeq·measure 가 stale 바이너리/시드를 물지 않도록).

### 구현 규율 (implement-to-the-wall · reference-first)

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

### QA (지속 검증 · verify-done 상시화)

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
- do: QA 는 **native-canonical-default polarity 위반도 감사·교정**한다 — 기본 경로는 항상
  hexa-native/own/canonical 이고 외부의존(cuBLAS · 외부 BLAS · 벤더 라이브러리 · legacy fallback)은
  **opt-in 플래그로만** 존재해야 한다(아래 [native-canonical-default] 가드레일과 lockstep). QA 가
  역전된 polarity(native 를 플래그 뒤로 숨기고 외부의존을 기본으로 둠 · `HEXA_NO_<vendor>` 로 native
  를 opt-in · 손짜기 Taylor 등 codegen-fragile 대체)를 발견하면 **교정 PR 로 닫는다** — 플래그 명명이
  켜는 것이 "제약/외부의존 활성화"가 되도록 정렬(`HEXA_USE_<vendor>` · `HEXA_<feature>_FALLBACK` ○ /
  `HEXA_NO_<vendor>` ✗). 교정은 byteeq-safe(felt-default=native 유지)로, 빠른 외부의존 경로는 명시
  opt-in 으로 남긴다.

### native-canonical-default (polarity)

- do: 기본 경로는 **항상 hexa-native/own/canonical**. 외부 의존(cuBLAS · 외부 BLAS · 벤더
  라이브러리) · 비결정 · 실험 · legacy fallback 은 **플래그(env/컴파일 매크로)로 opt-in 하는
  "제약"으로만** 존재한다. 올바른 예 — forge GPU GEMM: own 커널이 default · cuBLAS 는
  `HEXA_USE_CUBLAS` opt-in.
- dont: **polarity 역전 절대 금지** — native 를 플래그 뒤로 숨기고 외부의존을 기본으로 두지 말
  것(잘못된 예 = `HEXA_NO_CUBLAS` 로 native 를 opt-in · #3742 교정 대상). 플래그 명명은 켜는 것이
  "제약/외부의존 활성화"여야 한다(`HEXA_USE_<vendor>` · `HEXA_<feature>_FALLBACK` ○ /
  `HEXA_NO_<vendor>` ✗).
- do: native-default 가 perf 회귀를 일으키면(예: consumer-GPU BF16 ~2× 느림) **polarity 는
  유지하되** 빠른 외부의존 경로를 opt-in 플래그로 남겨 선택 가능케 한다(felt-default = native ·
  빠른 길은 명시 opt-in). 느려지는 건 깨지는 게 아니며, 위 [릴리스 무결성]의 "사용자 경로를 깨지
  말라"와 양립한다.
- do: stdlib signal/math 모듈은 **native libm trig**(`cos`/`sin`/…)를 쓴다.
- dont: 손수 짠 Taylor series 금지 (codegen-fragile).

### 아틀라스 · 검증

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

### git · L0 · lockstep

- do: 가드 파일 변경 전 subagent 가 diff 한다(`git diff <baseline>...HEAD` · `.githooks/pre-commit`).
- dont: `stdlib`/`runtime`/`codegen`/`rt` 에서 >50줄 삭제를 scoped subject 나 `WIPE-OK:` trailer 없이
  커밋하지 말 것.
- do: L0 lockdown 파일(`harness.config.json` → `lockdown.files`) 편집 시 같은 변경에서
  `CHANGELOG.md` 를 갱신한다.
- do: `hexa`(릴리스/CLI) 업데이트 시 `hexa --help` · `hexa gpu` 출력을 **lockstep 갱신**한다 — 새
  GPU 능력 · 플래그 · 빌드변종 · dtype parity 변화가 나면 같은 변경에서 `cmd_help()`/
  `cmd_gpu_status()` 텍스트를 갱신한다(타 리포가 `hexa gpu` 를 GPU/flame/forge/cuda 상태 SSOT 로
  신뢰하므로 stale 금지).
- do: 모든 HuggingFace 업로드/Collections 는 `dancinlab` org 아래 둔다.

### CI · self-hosted runners

- do: 무거운 faithful/byteeq 빌드는 **self-hosted 러너**가 처리한다 — `ghost`(darwin-arm64 ·
  label `selfhost-gen2fix` · darwin byteeq) + `aiden`/`summer`(linux-x64 · label `hexa-build` ·
  12c/30G 공유 빌드 풀). 잡이 opt-in 하는 법: `runs-on: [self-hosted, Linux, X64, hexa-build]`
  (linux-x86_64 전용 · 예 `nobaseline-gate.yml` faithful-nobaseline linux-x86_64). **linux-arm64 ·
  darwin-arm64 · ephemeral 환경이 필요한 잡은 클라우드 러너 그대로 둔다** — arm64 self-hosted 호스트
  없음(honest, arm64 커버리지 주장 금지).
- do: public repo 라 **fork-PR 은 메인테이너 승인 후에만** self-hosted 러너가 집어간다(RCE 완화 ·
  ghost 선례와 동일). 필수 게이트(`selfhost-gates-summary`)를 **검증 안 된/오프라인 러너에 의존시키지
  말 것** — 러너에서 green 을 실측한 뒤에만 required 잡을 옮긴다.
- do: 러너는 systemd **서비스**로 등록(`~/actions-runner-hexa` · `sudo ./svc.sh install` · 재부팅
  생존 · 호스트당 단일 러너 — 풀 빌드 starve 금지 · 우리 빌드는 여전히 1-SSH 규율). 오프라인이면
  재등록: `gh api -X POST repos/dancinlab/hexa-lang/actions/runners/registration-token -q .token`
  →  호스트에서 `cd ~/actions-runner-hexa && ./config.sh --url … --token <tok> --labels
  self-hosted,Linux,X64,<host>,hexa-build --unattended --replace && sudo ./svc.sh start`. 상태는
  `gh api repos/dancinlab/hexa-lang/actions/runners`.

## Harness

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
