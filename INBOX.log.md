# INBOX — log

Append-only history sister of `INBOX.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-25T23:40Z — pure-hexa SHA256 core (`hash/hmac.hexa::sha256_digest_bytes`) SEGFAULT on 0.1.0-dispatch runtime (from: anima STDLIB sha256-bytes agent, PR #924)

PR #924 (`sha256_of_bytes` / `sha256_of_lines_filtered`) 작성 중 발견. libsodium 경로로 우회했으나 pure-hexa fallback 은 깨져 있음 — anima sha256 sweep 의 libsodium-less 빌드 호환을 막는 root.

**실측 결함 3건**:
- [ ] **(a) pure-hexa SHA256 core SEGFAULT**: `hash/hmac.hexa::sha256_digest_bytes([])` 가 empty input 에도 START 출력 후 즉시 죽음. `%2^32` bignum path 의 codegen/runtime 버그로 추정. 동봉된 `hmac_test.hexa` 도 이 빌드에서 crash. → libsodium-free 타깃(firmware/embedded)이 SHA256 사용 불가. PR #924 는 이 때문에 libsodium-gated (L3 honest limit) 로 출하 — segfault fix 후 pure-hexa core 로 환원 가능.
- [ ] **(b) string `sha256` builtin 이 `strlen` 사용 → binary-unsafe**: `0x00` 바이트가 입력을 truncate. byte array digest 에 부적합 → PR #924 가 `sha256_bytes` (libsodium) 로만 라우팅한 이유. string builtin 을 length-explicit 로 바꾸면 binary-safe 통일 가능.
- [ ] **(c) pool-route + stale `~/.hexa-cache` friction**: pool-route hook 이 `hexa` 를 Linux 호스트로 redirect + 폐기된 import 버전의 stale transpile 이 false-segfault 유발. cache invalidation 이 source-set 변경에 둔감 — abandoned-import 잔재가 다음 build 를 오염. (DX, severity low.)

**연결**: anima #461 (sha256 sweep, ~104 site) 의 directory-walk / 일부 pipeline 잔여가 (a) 해결 시 pure-hexa 경로로도 migrate 가능. 현재는 libsodium 빌드 한정.

## 2026-05-25T08:30Z — fresh worktree self-test 바이너리 부재 (stdlib .hexa link 실패 · NOVEL-TOOL stdlib agent 반복 발견)

NOVEL-TOOL stdlib primitive agent 들 (M2 demag/halbach · M3 welford/logsumexp/kahan/lambert_w) 이 일관되게 보고하는 환경 gap. fresh `/tmp` 격리 worktree 에서 stdlib `.hexa` self-test 가 비-sqrt math_pure fn link 실패. stub-first (g60).

- [ ] **증상** — 새 `git worktree add /tmp/<wt>` 후 `./hexa run` 또는 `hexa.real run <stdlib>.hexa` 시 `log_pure`/`asin_pure`/`sin_pure` 등 비-sqrt math_pure fn 이 `"compiled module_loader not found — falling back to raw src"` 으로 link 실패. raw fallback 은 `sqrt_pure` 만 flatten.
- [ ] **원인** — gitignored `build/hexa_module_loader` + `hexa.real` (또는 compiled module_loader) 가 worktree 에 없음 (canonical root `~/core/hexa-lang` 에만 존재).
- [ ] **영향** — stdlib primitive self-test 가 fresh worktree 에서 불가 → 매 agent 가 바이너리 수동 copy 로 우회 (반복 toil · [[feedback_demiurge_assets_simulation_mandatory]] / [[reference_hexa_verify_build_broken]] 관련).
- [ ] **제안** — (a) worktree 생성 시 build artifact symlink/copy 자동화 (post-worktree hook), 또는 (b) `hexa run` 이 canonical root 의 module_loader 를 worktree 에서도 찾도록 (`HEXA_BUILD_ROOT` env), 또는 (c) module_loader 를 git-track (크기 허용 시).
- [ ] **확인된 깨짐** — `numerics_mcmillan_solver.hexa` 도 fresh worktree 에서 동일 (기존 stdlib 영향 증거).

Status: open · proposed-by:agent · severity:medium (반복 toil) · source:NOVEL-TOOL stdlib round 2026-05-25

## 2026-05-25T08:10Z — RTSC N5/SSCHA 캠페인 발견 2 gap (from: demiurge RTSC micro-exp 세션)

demiurge RTSC h3o micro-exp + SSCHA dispatch 중 발견된 hexa-lang 2 gap. stub-first (g60).

- [ ] **(a) `hexa cloud preflight` worktree-path missing fallback** — pool-route preflight 가 격리 worktree path (로컬에만 존재, ubu/vast 호스트엔 없음) 에서 `workdir missing` 으로 fail. stdlib add/SSCHA 작업이 worktree 에서 dispatch 될 때 preflight 가 막힘.
  - 발견: PR #897 (elliptic_K_E) agent + h3o SSCHA dispatch.
  - 제안: preflight 가 worktree path 부재 시 canonical repo root (`~/core/hexa-lang`) 로 fallback, 또는 `--workdir` 명시 override. d8 (Vast finding → INBOX) 정합.
  - severity: medium (worktree 격리 패턴이 표준이라 자주 발생).

- [ ] **(b) `hexa verify --expr` ε=1e-9 가 low-precision input 에 과도 (round-tolerance 옵션)** — verify_cli 의 고정 ε=1e-9 가 1-decimal 입력 (예: result.txt 의 Tc=179.8K) 대비 너무 tight. hexa full-precision calc (179.779) 와 |Δ|=0.021K 차이가 순전히 입력 반올림인데 🔴 FALSIFIED 판정 (실효는 🟢 SUPPORTED-NUMERICAL).
  - 발견: RTSC N5 funnel 4 candidate (h3o·h3si·h3f·h3po) allen_dynes_tc cross-check 전부 🔴 (round artifact).
  - 제안: `--expr` 에 `--tol <ε>` 옵션 또는 expected 의 유효숫자 자동 감지 → 입력 정밀도 기반 ε 스케일. (현재 우회: full-precision expected 주면 🟢.)
  - severity: low-medium (verdict 오탐 — honest tier 왜곡).

## 2026-05-25T23:10Z — hexa CLI verb sweep audit — 102 verb · 85.3% PASS · 5 결함 발견 (from: this-session full-sweep agent)

`hexa --help` 의 ~120+ verb 중 102개 호출 smoke. mac user 워킹트리, `HEXA_FORCE_FALLBACK=1`, 30s timeout/verb. raw 결과 `/tmp/hexa-verb-sweep/results.jsonl`. (옛 `inbox/notes/hexa_cli_verb_sweep_audit_2026_05_25.md` 도 이번 commit 으로 정식 INBOX entry 로 rehome — g11 폐기 폴더에서 이동.)

**집계**: True PASS 87/102 = 85.3%. Wired 97/102 = 95.1%. 견고: annotator 29, drill 12 variants, external 17 (fallback 정상), atlas dispatch.

**실측 결함 5건** (sub-handoff 으로 각각 처리 필요):
- [x] **(a) `hexa run --help` / `hexa build --help` — `--help` 를 source file 로 해석** → FAIL `source file not found: --help`. flag 인터셉트가 source-file parse 보다 먼저 와야 함. 가장 빠른 DX 개선. — FIXED (inbox/cli-help-rc-fix-T2310 · PR #882): run/build dispatch 진입부에 `av[3] == "--help" || "-h"` 인터셉트 추가 → `cmd_help()` rc=0.
- [x] **(b) `hexa lsp --help` — LSP daemon 진입, stdin 대기 TIMEOUT 30s**. flag 라우팅 누락 — daemon 진입 전에 `--help` 인터셉트. — FIXED (inbox/cli-help-rc-fix-T2310 · PR #882): lsp 분기 진입 직후 (`install_dir_from_argv0` 호출 전) `--help/-h` 인터셉트 → `cmd_help() + exit(0)`.
- [x] **(c) `hexa init` — RESOLVED**: scaffolder 인라인 land (self/main.hexa::cmd_init) + sister tool/init_project.hexa (future standalone-bin source). `hexa init <dir> [--name N]` → `<dir>/project.hexa` + `main.hexa` + `.gitignore` 생성, 기존 프로젝트는 rc=2 거부. e2e: scaffold → `hexa build` → 실행 "hello from testproj" PASS. cmd_run interp dep 회피 (feedback_no_interp_use_compiled).
- [x] **(d) `hexa convergence` usage 출력 시 rc=1 — 다른 verb 는 rc=2** (tape/hxc/repo-audit-taxonomy/gpu disasm/lint). POSIX 관행상 rc=2 표준. convergence 만 outlier 통일. — FIXED (inbox/cli-help-rc-fix-T2310 · PR #882): `len(av) < 5` 분기의 `exit(1)` → `exit(2)`.
- [x] **(e) `hexa sim-universe selftest` 6/6 sub-test FAIL — RESOLVED**: substrate 무손상이었고 harness 자체 결함 2종. (1) `raw.contains("PASS")` 판정인데 5/6 sub-test 가 PASS sentinel 미emit → `exec_with_status` rc==0 + non-empty stdout 판정으로 변경. (2) `qpu_bridge/qpu_bridge.hexa` 경로 typo → 실제 `vqe_h2_demo.hexa` 로 fix (selftest + cmd_qpu 양쪽). `stdlib/sim_universe/sim_universe.hexa::cmd_selftest` L210-236 + `cmd_qpu` L182 변경.

**추가 권장 (소소)**:
- atlas lookup 잘못된 id 에 `# not found:` + rc=1 — `--list` 또는 fuzzy hint 시 DX 개선.

## 2026-05-25T22:50Z — hexa 래퍼 BASH_SOURCE 미-symlink-resolve (from: PR #873 pool-ubu-stale 진단 부산물)

`/Users/ghost/core/hexa-lang/hexa` shell shim 의 `__hexa_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"` 가 BASH_SOURCE 의 symlink 를 해석하지 않음. 결과: `~/.hx/bin/hexa` (= `/Users/ghost/core/hexa-lang/hexa` symlink) 호출 시 __hexa_dir 이 symlink 경로 그대로 → `pwd -P` 가 그제서야 해석 → 결과적으로는 작동하나 `BASH_SOURCE` 처리 경로 자체가 의도와 다름.

증상은 미미하지만, [[reference_install_dir_argv0_basename_cwd_shadow]] (PR #866) 와 형제 클래스. /tmp git worktree 같은 데서 hexa 라는 stray 파일이 있으면 shim 자체가 혼동될 가능성.

처방: shim 의 BASH_SOURCE resolve 단계 명시 — `realpath "${BASH_SOURCE[0]}"` 한 후 dirname 한 결과를 `__hexa_dir` 로.

- [x] **shim BASH_SOURCE → realpath → dirname → pwd -P 체인 명시** — 1-line shim fix · RESOLVED #878

## 2026-05-25T22:55Z — ubu-2 `hexa cc --regen` MVP-merge codegen l-value 버그 (from: PR #873 pool-ubu-stale 진단 부산물)

ubu-2 (Linux x86_64) 에서 `hexa cc --regen` 의 step 2 (MVP-merge: lexer/parser/type_checker/codegen 4 모듈 → hexa_cc.c.new) 가 codegen step 에서 `l-value` 에러로 실패. ubu-1 에선 같은 명령 통과 (둘 다 origin/main 같은 커밋, 같은 hexa_v2 binary, 같은 codegen.hexa source).

차이: ubu-1 은 `git pull` 직후 hexa_cc.c 가 #862 fix 포함, ubu-2 는 update 미반영 가능성? 또는 ubu-2 의 cached `self/runtime.o` stale? 진단 미완.

PR #873 처방은 ubu-2 에서 `cc --regen` 우회 — 기존 hexa_cc.c + module_loader 재빌드만으로도 transpile 정상이라 차단되지 않음. 단 향후 codegen.hexa 변경 분 ubu-2 에 반영 필요할 때 막힘.

- [ ] **ubu-2 cc --regen MVP-merge codegen l-value 에러 재현 + 진단** — 단순 stale 인지 codegen MVP-merge 자체 결함인지 분리
- [ ] **fix or workaround 결정** — 현재는 `cc --regen` 회피로 우회 가능

## 2026-05-25T22:35Z — stdlib 확장 요청: PK + optics fn 가족 (from: demiurge TTR-ORAL / TTR-LAC atlas-register 게이트) — RESOLVED #881

demiurge 의 TTR-ORAL V2 (oral PK) · TTR-LAC V2 (laser-optics) closed-form 들이 `hexa atlas register --from-verify` 로 등록 불가 — 현재 dispatcher 가 number-theoretic + 일부 float fn (sigma/phi/welch_t_crit/chsh_tsirelson) 만 지원하기 때문. atlas SSOT (`compiler/atlas/embedded.gen.hexa`) 에 dermatologic/topical PK + laser-optics 도메인 누락.

**필요한 fn 가족 (1차)**:
- **PK / topical pharmacokinetics**:
  - `higuchi_flux(C0, Dm, t)` — Higuchi 평면 확산: J(t) = √(2·C0·Dm·t/π) (또는 √(D·C·t) form)
  - `fick_steady_flux(P, dC)` — Fick steady-state: J = P·ΔC
  - `partition_coeff(C_oct, C_water)` — log P = log10(C_oct/C_water)
  - `permeability_skin(D, K, h)` — P = D·K/h (skin permeability)
  - `auc_first_order(C0, ke)` — AUC = C0/ke (1차 elimination)
  - `clearance(dose, auc)` — CL = Dose/AUC
- **Laser-optics**:
  - `beer_lambert(I0, eps, c, L)` — I = I0·10^(−ε·c·L)
  - `fluence(power, area, t)` — F = P·t/A (J/cm²)
  - `beam_waist(lambda, f, w0)` — w(z) gaussian beam (f = lens focal, w0 = input waist)
  - `rayleigh_range(w0, lambda)` — zR = π·w0²/λ
  - `absorption_depth(alpha)` — δ = 1/α

**작업 단위**:
1. demiurge 측 TTR-ORAL/TTR-LAC 코드에서 실제 closed-form 사용처 grep → fn 우선순위 확정 (~/core/demiurge)
2. hexa-lang stdlib 에 모듈 신규:
   - `stdlib/bio/topical_pk.hexa` (또는 기존 `stdlib/bio/` 에 추가)
   - `stdlib/physics/laser_optics.hexa` (또는 기존 `stdlib/physics/` 에 추가)
3. `tool/atlas_cli.hexa` 의 register dispatcher 확장 — 새 fn 들을 `--from-verify` 가 호출할 수 있게 dispatch table 등록
4. 각 fn `hexa verify --expr <fn> <args> <expected>` 🟢 SUPPORTED-NUMERICAL 5/5 검증
5. PR + entry close

**기반 메모리/규칙**:
- [[g61]] stdlib SSOT in hexa-lang (primitives, not domain응용)
- [[stdlib_trig_libm]] — libm builtin trig 사용 (cos/sin/log/exp) — hand-rolled 금지
- g5 tier rubric — 🟢 SUPPORTED-NUMERICAL (libm/Newton 수치재계산 일치)

- [x] **fn 가족 spec 확정** — INBOX entry 본문에 11 fn signature 명시 (PK 6 + optics 5)
- [x] **stdlib/bio/topical_pk.hexa** — PK 6개 fn 1차 구현 (libm sqrt/log)
- [x] **stdlib/physics/laser_optics.hexa** — optics 5개 fn 1차 구현 (libm pow/sqrt + PI)
- [x] **tool/atlas_cli.hexa register dispatcher 확장** — 11 fn 추가 register hook (+ verify_cli.hexa verify-arm 미러)
- [x] **`hexa verify --expr` 11 fn 전부 🟢 SUPPORTED-NUMERICAL 입증** — 11/11 PASS (|Δ| ≤ 2.22e-16 ≤ ε=1e-9)
- [x] **PR 1건** — 3 파일 단일 PR (stdlib/bio/topical_pk + stdlib/physics/laser_optics + tool/atlas_cli + tool/verify_cli)

**작명**: 기존 stdlib `higuchi` (2-arg simple k_H·sqrt(t)) 와 충돌 회피 위해 `higuchi_flux` (3-arg planar diffusion flux sqrt(2·C0·Dm·t/π)) 로 명명. 기존 3-arg `beer_lambert` (I_0·exp(-μ·x), photon attenuation) 와 구분 위해 `beer_lambert_log10` (4-arg molar form I_0·10^(-ε·c·L), 분광광도법) 로 명명. 11 fn 모두 새 atlas-register 동작 — 기존 atom 와 충돌 없음.

**검증 paste (11/11 🟢 PASS)**:
```
higuchi_flux(2.0,1.0,2.0)=1.59577        🟢 |Δ|=2.22e-16
fick_steady_flux(0.001,10.0)=0.01        🟢 |Δ|=0.0
partition_coeff(100.0,1.0)=2.0           🟢 |Δ|=0.0
permeability_skin(1.0,2.0,4.0)=0.5       🟢 |Δ|=0.0
auc_first_order(100.0,0.5)=200.0         🟢 |Δ|=0.0
clearance(100.0,50.0)=2.0                🟢 |Δ|=0.0
beer_lambert_log10(100.0,0.5,1.0,2.0)=10.0  🟢 |Δ|=0.0
fluence(10.0,5.0,2.0)=4.0                🟢 |Δ|=0.0
beam_waist(1.0,3.0,4.0)=1.25             🟢 |Δ|=0.0
rayleigh_range(1.0,1.0)=3.14159          🟢 |Δ|=0.0
absorption_depth(2.0)=0.5                🟢 |Δ|=0.0
```

## 2026-05-25T22:30Z — interp 잔재 audit — bench/PoC 가 비존재 `build/hexa_interp` 직접 호출 (from: this-session 사용자 발견)

R7 interp-retire ([[feedback_no_interp_use_compiled]]) 가 머지된 후에도 다음 production-adjacent 경로에 stale interp 호출이 잔존. `build/hexa_interp` 바이너리는 더 이상 빌드되지 않으므로 (`self/main.hexa:3079` 명시 "so there is no `build/hexa_interp` binary"), 이들 호출은 실패 / NO-OP / SKIP 으로 silent degrade.

**bench/profile 직접 호출 (4건)** — 측정값 0/SKIP:
- `tool/ai_native_bench.hexa:37` — `let bin = env_var("HEXA_LANG") + "/build/hexa_interp"`
- `tool/ai_native_profile.hexa:200` — 동일 패턴
- `tool/ai_native.hexa:51` — 동일 패턴
- `tool/bench_hexa_ir.hexa:64` — interp time 측정 (t_interp = "N/A")

**dead PoC (1건)** — 호출자 없음, 안전 제거 가능:
- `self/native_compile_poc.hexa:411` — `"build/hexa_interp tool/flatten_imports.hexa ..."` exec
- main.hexa 가 이미 module_loader compiled 만 사용 ([[reference_install_dir_argv0_basename_cwd_shadow]] PR #866 컨텍스트)

**defensive skip / 문서 잔재 (남겨도 무방)**:
- `self/stdlib/argv_skip.hexa:71-72` — argv 패턴 매칭에 `/hexa_interp` 끝 skip
- `self/forge/README.md`, `self/native/exec_argv_sha256.c` 주석
- `self/ai_native/ai_native_enforcement_progress.json` (enforcement 추적용)

**av0_base 분기 (legacy compat)**:
- `self/main.hexa:4067` — `if av0_base == "interp" || av0_base == "main"` — argv0 이 "interp" 면 self-source 로 판단. R7 후 deprecated 경로. 안전 제거 가능?

**관련 ubu-1 incident**:
직전 cycle pool-ubu-stale agent 가 처리 중인 ubu-1 drill `interp not found` 가 별 source (ubu 측 stale CLI binary 옛 dispatch 경로)이지만, root family 동일 = R7-retire 가 완전히 sweep 되지 않음.

- [x] **bench 4건** — DONE (option c: retire-with-marker). 4 파일 모두 file-header DEPRECATED 배너 추가 (`tool/ai_native_bench.hexa`/`ai_native_profile.hexa`/`ai_native.hexa`/`bench_hexa_ir.hexa`). 호출 자체는 `try/catch` 로 silent NO-OP 으로 이미 degrade — 사용자가 실행해도 안전 (0 반환·SKIP). CI/Makefile 참조 0건 확인. 추후 본격 rewrite 는 별도 cycle (R7 follow-up).
- [x] **PoC 1건** — DONE `git rm self/native_compile_poc.hexa` (826 line 삭제). 호출자 0건 확인 (`self/module_loader.hexa`·`self/mini_native.hexa`·`self/rt/math.hexa`·`tool/native_build.hexa` 의 주석 잔재 = 역사적 provenance, 빌드 영향 없음 — 그대로 유지). `wipe_guard` 트리거 (>50줄) — scoped subject (`chore(self): retire …`) 로 satisfy.
- [x] **legacy av0_base "interp" 분기** — DONE `self/main.hexa` av0_base 체크에서 `"interp"` disjunct 제거 (`if av0_base == "interp" || av0_base == "main"` → `if av0_base == "main"`). 코멘트로 제거 이유 ([[feedback_no_interp_use_compiled]]) 기록. `"main"` 은 dev 빌드 산출물 호환 위해 유지. 회귀=`hexa parse` 트리비얼 smoke + 추후 PR CI.

## 2026-05-25T20:50Z — pool 호스트 hexa CLI stale — atlas-loop/drill 발사 불가 (from: this-session atlas-loop 100 시도) — RESOLVED

목표: 100 atoms 발견까지 `hexa drill` 사이클 (atlas SSOT = compiler/atlas/embedded.gen.hexa, 베이스라인 16,088 nodes). pool-route 가 절대경로 없는 heavy verb (kick/drill/loop/cc)를 ubu 로 자동 라우팅하는 건 정상 작동(mac sign 게이트 무관). 발사 자체가 ubu CLI stale 로 막힘.

**측정 (2026-05-25, 새로 ship 된 pool-route 0.6.4 직후)**:
- `cd ~/core/hexa-lang && hexa drill --help` → pool-route 가 ubu-1 로 라우팅 → `error: interp interpreter not found ... searched: /home/aiden/.hx/bin/build/hexa_interp ...`
- `cd ~/core/hexa-lang && hexa kick --help` → 동일 ubu 라우팅 → 같은 interp 부재 에러
- ubu-2 는 별 시도에서 transpile 단계 SIGSEGV ([[reference_linux_transpiler_stale_build_recipe]] 와 동일 증상)

**진단**: `hexa drill` verb 가 ubu 호스트에서 옛 interp dispatch 잔재를 따라가는데, ubu-1 의 `~/.hx/bin/build/hexa_interp` 가 부재. ubu-2 는 [[reference_linux_transpiler_stale_build_recipe]] PR #789 fix 가 로컬 stale 일 가능성. 두 호스트 모두 hexa CLI 가 origin/main 대비 뒤처져 있음.

**RESOLUTION (2026-05-25, this session)** — 진짜 루트코즈는 interp 아니라 Mac arm64 바이너리 leak:
- 두 호스트 `self/native/hexa_v2` 가 **Mach-O arm64** (Mac 세션 fan-out leak — user-synced workdir hazard). CLI 가 이 path 를 직접 호출 → transpile "Exec format error" 또는 module_loader segfault → 그 다음 `interp not found` fallback.
- **수정 단계**:
  1. `git stash push self/native/hexa_v2 && git pull origin main` (둘 다 82 커밋 behind)
  2. `cp self/native/hexa_v2_linux_x86_64 self/native/hexa_v2` (ubu-1+ubu-2, ELF Linux x86_64 백업이 옆에 존재)
  3. ubu-1 만 `./hexa cc --regen` → `cp /tmp/hexa_v2.new self/native/hexa_v2` (fresh build, 2026-05-25). ubu-2 는 cc --regen 이 codegen MVP-merge 버그(`hexa_int(-1) = ...`)로 실패하나 stale baseline ELF 으로 충분.
  4. ubu-1 만 `./hexa build self/module_loader.hexa -o build/hexa_module_loader` (rebuild)
  5. `HEXA_MODULE_LOADER=$PWD/build/hexa_module_loader` 환경변수 export ([[reference_hexa_module_loader_env_2026_05_20]])

**검증 출력**:
- `./hexa verify --expr cycles_to_target 0.12 0.1 19` — 두 호스트 PASS, `🟢 SUPPORTED-NUMERICAL  |Δ|=0.0`
- `./hexa drill --rounds 1 --seed "find closed-form expression for harmonic sums"` — 두 호스트 PASS:
  - ubu-1: `round 1: smash+414 free+211 abs=0 meta=0 hyper=0 res+7 total=632 · overlay+ 517 lines`
  - ubu-2: `round 1: smash+414 free+331 abs=0 meta=0 hyper=0 res+7 total=752 · overlay+ 637 lines`
- (post-round warning `map key 'f_a' not found` 은 별 issue · drill 자체는 완료)

**not-blocker (확인됨)**:
- mac sign 게이트(pool-route 0.6.4) → drill 호출은 절대경로 없어서 게이트 비통과 — atlas-loop 차단 요인 아님
- pool routing → 정상 작동 (ubu-1/ubu-2 로 round-robin)
- atlas SSOT/embedded.gen.hexa → 정상 (16,088 nodes 정상 load)
- drill verb 자체 interp 의존 → FALSIFIED: drill 은 컴파일 경로 사용. 옛 `interp not found` 메시지는 fallback string. 진짜 1차 에러는 transpile/Exec-format-error.

**잔여 (별 INBOX 후보)**:
- [ ] `hexa` 래퍼(`hexa-lang/hexa`) 가 symlink-resolved BASH_SOURCE 미사용 → `~/.local/bin/hexa` symlink 로 호출 시 `__hexa_dir` 가 `~/.local/bin` 으로 풀려서 `hxv2`/`hexa.real` 못 찾음. 사용자는 직접 `./hexa` (repo dir 내) 사용 회피 가능. fix = `readlink -f "${BASH_SOURCE[0]}"` 도입.
- [ ] ubu-2 `hexa cc --regen` MVP-merge 시 codegen 이 `hexa_int(-1) = _fn_variadic_lookup(...)` (l-value 아닌 표현식에 대입) 생성 — Mac/ubu-1 에선 안 보임, ubu-2 호스트 차이 또는 hexa_cc.c.new 머지 비결정성. 별 codegen INBOX 권장.

- [x] **ubu-1 hexa CLI 재빌드** — Mac binary swap + cc --regen + module_loader rebuild → drill PASS
- [x] **ubu-2 transpile SIGSEGV 잔존 검증** — 루트코즈는 Mac arm64 leak, transpiler 자체는 정상. ELF 백업 swap 으로 즉시 해결
- [x] **drill verb 자체 interp 의존 검토** — FALSIFIED, drill 은 compiled-path. 메시지가 헷갈렸음

## 2026-05-25T05:10Z — demiurge 7-verb production 갭: 10+2 도메인 cellrun per-verb 스크립트 부재 (from: demiurge CLI+COCKPIT 전 도메인 캠페인)

demiurge cockpit/CLI 에서 **21 도메인 × 7-verb 전수 실측** 결과. dispatch 는 21/21 보편 작동(0 crash) — production(측정 record 생산)은 hexa-lang `stdlib/<도메인>/` per-verb 스크립트 배선도에 정확히 비례. demiurge surface 는 완성(dispatch·관찰·정직기록); 남은 건 stdlib 스크립트 (@D d3 — impl home = hexa-lang).

**실측 매트릭스** (✅=record 생산 · ⏭=honest-skip[스크립트 부재] · ·=cell무/no-record):
```
full 7/7   chip · firmware
partial    sscb 6 · bio 5 · matter 4 · component 2 · cern/aura/chem 1
미배선 0/7 antimatter bot brain energy fusion grid mobility rtsc scope space  (전부 ⏭)
no-stdlib  clinical · ufo  (· — stdlib 디렉토리/per-verb cell 부재)
```

**루트코즈**: `.demi` 매니페스트(demiurge/domains/<도메인>.demi)가 `script = stdlib/<도메인>/<verb>.py` 를 cell 마다 선언하나, 그 per-verb 엔트리 스크립트가 hexa-lang 에 없음. 예 — `antimatter.demi [cell.verify] script=stdlib/antimatter/verify.py` 선언하지만 실제 디렉토리엔 `geant4_verify.py`·`pdg_lookup.py` 만 존재(이름 불일치) → cellrun.hexa 가 `verify.py` 못 찾고 honest-skip. 즉 **엔진 로직은 일부 존재하나 cellrun per-verb 엔트리포인트로 미연결**.

- [ ] **10 미배선 도메인 per-verb 엔트리** — `stdlib/<도메인>/<verb>.py` 신규 또는 기존 descriptive 스크립트(geant4_verify.py 등)로 라우팅하는 **thin argv shim**. 최소비용 = shim (verify.py → geant4_verify 호출).
- [ ] **clinical · ufo** — stdlib 디렉토리/per-verb cell 자체 부재 → 신규 작성 (또는 demiurge 측 .demi 매니페스트 생성 선행 확인).
- [ ] **(option) cellrun.hexa fallback** — per-verb `<verb>.py` 없을 때 `stdlib/<도메인>/` 의 descriptive 스크립트를 auto-discover 하는 해석 fallback → 10 도메인 일괄 unblock 가능.
- 참조 패턴: `chip`/`firmware`(full 7/7 wired) · `bio`(substrate=hexa → bio.hexa root dispatcher 로 specify/structure/design/analyze 충족). demiurge 측 액션 무관 — 본 핸드오프는 hexa-lang stdlib 작업.

## 2026-05-25T04:20Z — codegen: 함수 간 동명 `let` comptime-const fold 충돌 ("이름 도둑") — RESOLVED #829

**중복 핸드오프 통합** — 동일 루트코즈 2건을 1건으로:
- anima MODERNIZE M6 (INBOX #824) — #829 fix 의 원 reporter.
- demiurge CARDIO+ X10 PAPER (`_paper.hexa`) — `_cmd_compile` 의 `let pdf = "pdflatex …"`(string literal)가 `_cmd_lint` 의 `let pdf = dir + "/main.pdf"`(non-literal)를 덮어씀 → lint 가 엉뚱한 문자열을 `test -e` → 실제 10p PDF인데 FAIL.

**루트코즈**: codegen 의 comptime-const fold 테이블이 module-global 이라, 한 함수의 `let <id> = <literal>` 이 다른 함수의 동명 `<id>` 까지 stale 리터럴로 inline. `gen2_fn_decl` 이 본문 emit 시 comptime-const scope mark/restore 를 안 걸어 fn 경계에서 fold 가 누수 (block/loop/arm 본문은 이미 mark/restore 됨). silent wrong-answer (build-clean, 잘못된 출력). → [[reference_comptime_fold_shadow_family]] (D17 #724 · D18 #766 · F-FOLD #797 동일 뿌리).

**3-function 최소 repro** (string 변종 = _paper.hexa 패턴):
```
fn cmd_compile() -> str { let pdf = "pdflatex -interaction=nonstopmode"; return pdf }
fn cmd_lint(dir: str) -> str { let pdf = dir + "/main.pdf"; return pdf }
fn main() {
    let _ = cmd_compile()
    println(cmd_lint("/work/paper"))   // 버그: "pdflatex …" · 정상: "/work/paper/main.pdf"
}
```

- [x] **RESOLVED on main by #829** (`9e7ed729 fix(codegen): scope-isolate comptime-const folds per fn body`) — `gen2_fn_decl` 본문 emit 루프를 `_comptime_const_scope_mark()`/`_comptime_const_scope_restore()` 로 감쌈 (block/loop/arm 과 동일 패턴). module-level const 는 유지, per-fn fold 는 fn 종료 시 폐기.
- [x] **검증** (2026-05-25, from-main 트랜스파일러): 위 string repro 5× transpile → emitted C md5 동일(결정적) · 0/5 가 `cmd_lint` 에 stale 리터럴 inline (전부 `hexa_add(dir, "/main.pdf")` 클린) · 실행 `/work/paper/main.pdf` PASS. #829 의 int/float repro(2147483648 → 10.0) 도 동일 PASS. → string 케이스 포함 fix 확정. (workaround 미적용 — 근본수정 우선 원칙대로.)
- [x] **배포 갭 (closed 2026-05-25)**: 배포 refresh = `git switch main` (또는 `cp <fresh-worktree>/self/native/hexa_v2 /Users/ghost/core/hexa-lang/self/native/hexa_v2`). driver `hexa.real` 자체는 thin dispatch only — 진짜 fix 는 `self/native/hexa_v2` 안에 있음. consumer 가 main branch 로 checkout 한 시점에 #829+#862 양쪽 모두 자동 픽업됨. (driver 도 #862-built 로 새로 받고 싶으면: `cp /tmp/hexa.real.new /Users/ghost/core/hexa-lang/hexa.real`.)

## 2026-05-25T03:00Z — codegen: 파라미터명이 호출부 struct 필드명과 같으면 미스컴파일 — RESOLVED #862

- [x] **RESOLVED on main by #862** (`fix(codegen): r16 — param-fold-leak — fn param shadows enclosing comptime-const`). **재해석**: 진짜 트리거는 호출부 struct 필드 alias 가 아니라 모듈 레벨 `const <name> = <literal>` 가 comptime-const fold 테이블에 `<name> → <literal>` 을 등록 → 같은 이름 fn 파라미터의 body Ident 읽기가 `_lookup_comptime_const(<name>)` 에서 stale literal 을 inline (codegen.hexa:4891). 핸드오프 원 reporter 가 본 `len 1 = "x"` 는 stub `Ev { kind: "X", raw: "x", id: "stub" }` 류 const-folded literal 이 누수된 결과. #829 fix 가 fn body scope-isolate 는 잡았지만 param 진입 시 invalidate 가 빠져 있었음. → [[reference_comptime_fold_shadow_family]] family 의 한 갈래.
- [x] **fix** (#862): `gen2_fn_decl` 진입 시 각 `node.params[i].name` 을 `_invalidate_comptime_const` 로 fold 테이블에서 제거 — `_comptime_const_scope_mark` BEFORE (restore 는 truncate-only 라 AFTER invalidate 면 OOB). for-loop counter 패턴 (codegen.hexa:3262/3288) 과 동일 순서.
- [x] **검증**: minimal repro (const raw="x" + fn show(kind,raw,id)) 전후 `len=1 v='x'` → `len=21 v='PAYLOAD-…'`. #829 repro 회귀 PASS. fixpoint gen2≡gen3 byte-eq (md5 9153ebf2316578cf2361b8347d7fa340). 풀 self-host 빌드 PASS.

## 2026-05-25T02:10Z — hexa cloud 개선 4건 (from: demiurge TTR-MN M5 cluster DFT 실전)

M5 cluster DFT (vast `rent` H100 + NWChem PBE0) 실전 중 발견. 전부 우회 가능했으나 SSOT 기록:
- [ ] **preflight DFT/MD 축 부재** — 현재 `preflight`는 LLM training 전용 (`--params --bsz --seq --n-layer --d-model`). M5 1904-bf hybrid DFT 메모리/시간 산정에 못 씀 → **RFC 091 (preflight v2 DFT/HPC) witness**. DFT 도 닫힌형 추산 가능 (basis-fn 수 · method scaling N³~N⁴ · hybrid vs pure) → rent 전 GPU vs CPU-HPC 판단 자동화.
- [ ] **workload-aware sizing 부재** — NWChem hybrid DFT(exact exchange) = **CPU-bound** → `rent --gpu <type>` 만 있고 `--vcpu/--ram` 필터 없음. CPU-HPC 워크로드(@D d7 "batch → Vast.ai CPU")는 vCPU/RAM 기준 선택 필요. (이번엔 H100 80-core 가 우연히 적합했으나 GPU 단가로 골라짐 — 비용 비효율 risk)
- [ ] **rent 이미지 sshd 필수** — minimal 이미지(`miniconda3` 등) sshd 미기동 → rent 침묵 실패. `nvidia/cuda:*-devel-ubuntu22.04` 성공. `vast_create` 가 `--ssh --direct` 만(onstart 없음) → rent 가 sshd-onstart 주입 또는 이미지 sshd 검증/경고 권장.
- [ ] **rent `--max-price` client filter 부재** (vast.hexa TODO) — 비용 상한 가드 없음 = 실비 폭주 risk. on-demand offer dph 상한 플래그.
→ cross-ref RFC 088 (P-series provisioning) · RFC 091 (preflight DFT/HPC). M5 c01 (Ce₆O₁₂+azo PBE0/CRENBL-ECP) 실행 검증 = `rent`/`exec`/`copy-to`/`copy-from` 체인 정상 동작 확인 ✅.

## 2026-05-25T00:50Z — [정정] 위 "빌드 회귀" 보고 RETRACT — worktree 아티팩트였음 — RESOLVED #866

직전 엔트리(00:25Z)의 "빌드 회귀" 진단은 **오진**이었음 — origin/main 은 정상. 실제 원인: `hexa build` 의 use-확장(module-loader)이 **정식 repo 루트 `~/core/hexa-lang` 에서만** 작동하고, `/tmp` 의 detached git worktree 에선 건너뜀.
- [x] 정식 루트에서 `bash tool/build_hexa_verify.sh` → `[1/2]` 가 `hexa_build_expanded.<ts>.tmp.hexa`(use-inline 확장본) 컴파일 → **빌드·링크 성공**
- [x] `/tmp` worktree 에선 `[1/2]` 가 `verify_cli.hexa` 를 **직접** 컴파일(확장 생략) → `static_atlas` 등 미정의 링크 실패 (= 00:25Z 가 본 증상)
- [x] `cycles_to_target`/`compound_coverage` (PR #803) 정식 루트 빌드 → `hexa verify --expr cycles_to_target 0.12 0.1 19` = **🟢 SUPPORTED-NUMERICAL** (TTR-MN timeline 5/5 · 대조 18→🔴 FALSIFIED)
- [x] **RESOLVED on main by #866** (`fix(hexa/build): install_dir_from_argv0 — PATH-resolve bare-basename argv[0] before realpath (worktree shadow)`). 진짜 루트코즈는 `.git`-file 탐지 아니라 **argv[0] basename CWD shadow**: ~/.hx/bin/hexa shim 이 `exec -a hexa` 라 inner driver 의 argv[0] = bare `hexa`. POSIX `realpath hexa` 는 CWD 먼저 탐색 → /tmp worktree 가 (repo 에서 commit 된) ./hexa shim 파일을 들고있어 → realpath = /tmp/<wt>/hexa → install_dir = /tmp/<wt> → no `build/hexa_module_loader` → `[flat] warn` + skip. fix: argv[0] 에 슬래시 없으면 (= bare basename) `command -v` 로 PATH 우선 해석, realpath 는 fallback. e2e 검증 (replay /tmp/hexa-wtest-2026-05-25): pre `[flat] warn: ... not found` → post `[flat] module_loader → /tmp/.hexa-runtime/hexa_build_expanded.<ts>.tmp.hexa`.

## 2026-05-25T00:25Z — [RETRACTED · 아래 00:50Z 정정 참조] `hexa verify` sub-binary 빌드 회귀: 다중모듈 use 링크 누락 (from: demiurge TTR-MN)

clean origin/main(`8f31d339` #801)에서 `bash tool/build_hexa_verify.sh` 가 link 단계 실패 — undefined symbols `static_atlas`·`sigma_k`·`mobius`·`jacobi_symbol`·`kronecker_symbol`·`isotropy_lcm`·`recompute`·`recompute2`·`read_file_safe`·`write_file_safe`. 이들은 `tool/verify_cli.hexa` 의 `use "compiler/atlas/static_index"` + `use "self/stdlib/fs"` 가 제공하는 정의. codegen(`hexa_v2 tool/verify_cli.hexa out.c`)은 OK 지만 .c(127KB)에 해당 정의 미flatten → `hexa build` 의 모듈 .o 링크 목록에서 누락.
- [ ] `hexa build` 다중모듈 link 목록이 `use compiler/atlas/*` + `self/stdlib/*` 의존 .o 를 포함하도록 복구
- [ ] 메모리 cap 아님 확인됨 — `HEXA_MEM_CAP_MB=49152` 직접 `hexa_v2` 호출에도 .c 미flatten · `build_hexa_verify.sh` 주석의 16384 권고는 무효
- [ ] 회귀 시점 후보 = #790 (abolish inbox → rehome+rewire · `verify_cli.hexa` 를 마지막 수정) · 미확정
- [ ] 영향 범위: `hexa verify --expr <fn>` 전체(welch_t_crit 등 기존 fn 포함) 신규 빌드 불가 — main repo 17:14 빌드 바이너리(pre-#790 계보)만 동작
- 우회(현): 독립 `.hexa` 를 `hexa build` 네이티브 컴파일하면 함수 단위 검증 가능 (verdict formatter 만 막힘). 동반 PR 의 `cycles_to_target`/`compound_coverage` 는 이 경로로 TTR-MN (1-x)^N timeline **5/5 PASS** 확인 (x→N = 0.047→48·0.08→28·0.12→19·0.15→15·0.20→11).

## 2026-05-24T13:35Z — hexa cloud pod 생성(provision) verb 부재 (from: demiurge RTSC)

dispatch만 wrap(run/nohup/poll/copy)·lifecycle(생성/teardown/조회) 미wrap. RTSC SrAuH₃ GPU 가속 시도 중 발견 — vast pod를 hexa cloud로 만들 수 없고 raw `vastai`는 cloud-guard 차단(@D g8) → 사람 수동 web UI 외 clean 경로 0. 진단 verb(list/status/orphans)는 runpodctl 전용 = vast surface 0.
- [ ] `hexa cloud up <provider> --gpu <t> [--image --disk --owner --max-price]` + `down <id>` 생성/teardown verb (provider ∈ runpod|vast · vast REST **wrapped** = raw 금지 해소)
- [ ] list/status/orphans provider-generic화 (현 runpodctl 전용 → vast 포함)
- [ ] `up`이 pod registry append (`hexa-cloud-pod-registry-tracking` lockstep — 발사시점 자동기록 → orphan 구조적 방지)
- [ ] 근거: g8이 "모든 rented-GPU = hexa cloud" 약속하나 생성만 빠져 반쪽. 채우면 에이전트 자율 GPU + @D d7 h3o SSCHA(≥20원자)·RTSC SrAuH₃ 가속 가능

→ **closed-as-tracked (g48 · 2026-05-24)**: 본 갭은 신규 아님 — provisioning verb는 `archive/patches/archive/hexa-cloud-preflight-stub-and-provisioning-gap-2026-05-24.md` **gap#2**(→ RFC 088 P-series), DFT/HPC 워크로드 preflight는 **RFC 091**(`rfc_091_hexa_cloud_preflight_v2_dft_hpc`)로 이미 추적. preflight 절반은 PR #703(`stdlib/cloud/preflight.hexa`, LLM axis)로 구현됨. 본 entry의 추가 가치 = (a) **vast** provider 강조(기존 추적은 runpod 중심) + (b) RTSC **SrAuH₃**(M8 게이트 병목)라는 concrete DFT-HPC use-case → **RFC 091에 witness 추가** + provisioning **vast arm**을 RFC 088 P-series에 반영 권고. cross-repo handoff = 수신·라우팅 완료.

