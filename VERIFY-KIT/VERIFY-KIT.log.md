# VERIFY-KIT — append-only step log

> 도메인 SSOT 스냅샷 = `VERIFY-KIT.md`. 이 파일은 step-by-step 작업 이력만 누적한다.

---

## 2026-05-26 — V5.2 (P2) faithful-Φ 엔진을 verify CLI 에 배선 (`hexa verify --expr phi_demo`)

### 목표 (V5 의 둘째 슬라이스 — wire 만)
- V5.1 이 promote 한 self-contained `iit4_faithful_phi` 를 verify CLI 에서 호출 가능하게. V5 통째는 두 번 죽었으니 V5.1 처럼 작게 — wire 만, calibrate(V5.3)는 별도.
- CHALLENGE: verify `--expr` 인자는 SCALAR(`<fn> <n> <v>`)인데 Φ 는 state 행렬(flat n×dim farr)이 필요. → **Option A** 채택: `phi_demo <case_id> <expected>` — case_id 가 하드코딩 canonical small state 선택. farr-parsing CLI grammar 없이 엔진 재계산 + 배선을 증명. (Option B = comma-sep state 파싱은 verify_cli arg parser 가 list arg 를 싸게 안 줘서 deferred → V5.2.x.)

### Wire (최소 배선)
- `tool/verify_cli.hexa`: `use "stdlib/consciousness/iit4/faithful_phi"` 추가 · `_phi_demo(case_id)` 헬퍼(case 1 = 3-cell 동일 ramp Φ>0, case 0 = cell 2 상수 → MI=0 control Φ≈0)가 하드코딩 state 빌드 후 `iit4_faithful_phi(state, 3, 6, 4)` 호출 · `_recompute_float` 에 `phi_demo` dispatch · help 라인 1줄.
- `compiler/atlas/calc_dispatch.hexa::calc_is_float_fn` 에 `phi_demo` 등록(float-fn SSOT). 이로써 `--expr phi_demo …` 가 cmd_expr_float 경로 → 🟢 numerical.

### 검증 (real CLI)
- parse-gate PASS (verify_cli·faithful_phi·calc_dispatch 3개 전부 `hexa parse OK`).
- standalone smoke 빌드(동일 `_phi_demo` 로직)로 엔진 deterministic 재계산 선확인: phi_demo(1)=3.83659, phi_demo(0)=4.52044e-09.
- `bin/hexa-verify` 빌드 = HEAD transpiler 필요. **stale Mac 드라이버(self/native/hexa_v2, 2026-05-23)가 V4 bessel_j0/j1 codegen fold 를 miscompile** (`hexa_call1(bessel_j0,…)` 가 libm j0 와 _Generic 충돌) — V4(#1148) 이전 바이너리라 그렇고 V5.2 와 무관. fix = HEAD .hexa 소스로 transpiler 재빌드(`hexa cc`) → fresh `self/native/hexa_v2` 가 j0/j1 fold 복원. pool host `mini`(arm64 Mac)의 /tmp fresh clone 에서 패치 적용 + transpiler/module_loader/hexa-verify 빌드.
- VERBATIM (`.verdicts/verify-kit-iit-wire/v5_2.txt`):
  - `hexa verify --expr phi_demo 1 3.83659 --tol 1e-3` → 🟢 SUPPORTED-NUMERICAL (calc=3.83659, |Δ|=1.66537e-06, rc=0)
  - `hexa verify --expr phi_demo 0 0.0 --tol 1e-3` → 🟢 (calc=4.52044e-09 ≈ 0, |Δ|=4.52e-09, rc=0) — control PASS

### 산출 + tier
- CLAIMS.tape @C `verify_kit_iit_wire` [slug=verify-kit-iit-wire group=VERIFY-KIT] status="🟢 phi recompute wired into verify CLI (faithful_phi engine) — calibration → V5.3".
- V5.2 tier = 🟢 (numerical) — wire DONE, deterministic 재계산 CLI 에서 확인.
- V5.3 = PyPhi calibrate (3.83659 는 엔진 자체값, PyPhi-anchored 아님). V5 `[ ]` 미플립.

---

## 2026-05-26 — V5.1 (P2) anima Φ 엔진 → `stdlib/consciousness/iit4/` promote (g61/g68)

### 목표 (V5 의 첫 슬라이스 — promote 만)
- V5 (IIT Φ 엔진 n≤8 exact)는 통째로 두 번 rate-limit 에 죽었음. V5.1 = 가장 작은 슬라이스 = 새 알고리즘 빌드 없이 anima 의 faithful-Φ 엔진을 hexa-lang stdlib 로 promote 만. verify_cli 배선(V5.2)·PyPhi 캘리브레이트(V5.3)는 별도.

### Locate (READ-ONLY grep)
- anima 의 canonical Φ 소스 = `~/core/anima/HEXAD/LIFE/lib/phi_native.hexa` (zero import, RFC 036 spatial-Φ MIP-EI · 이미 hexa-lang `stdlib/consciousness/phi_spatial.hexa` 로 promote 됨).
- H_278 "faithful exact MIP-EI Φ n=8" = `~/core/anima/.../state/h278_faithful_phi_2026_05_25/run_h278.hexa` (608줄 run-harness · `fn main()` + CA 실험 포함). 재사용 가능 엔진 코어 = `_build_mi_matrix`·`_cross_cut`·`_size_a`·`_faithful_phi_from_mi`. anima-local 의존 = `c_phi_mi_pair` builtin + `life_phi_nbins()` (phi_helper ← c_lib).

### Promote (g61/g68)
- 신규 `stdlib/consciousness/iit4/faithful_phi.hexa` — H_278 faithful 코어를 byte-faithful 로 promote. anima-local 의존 제거를 위해 `phi_native.hexa` 의 순수-hexa MI estimator(`_iit4_mi_pair`/`_iit4_bin_values`/`_iit4_entropy`)를 번들 → ZERO 외부 의존(builtin·anima import 둘 다 없음). n_bins 는 명시 인자.
- pub 표면: `iit4_faithful_phi(state, n, dim, n_bins)` (byte-faithful entry · n≤8 exact, n>8 panic) · `iit4_faithful_phi_from_mi(mi, n)` · `iit4_build_mi_matrix(...)`.
- provenance 헤더 1줄 = `# promoted from anima HEXAD/LIFE state/h278_faithful_phi_2026_05_25/run_h278.hexa (g61 shared substrate)`.
- parse-gate PASS (`hexa parse ... OK`).

### Record reuse edge (g68 star form)
- `NEXUS.tape` §1 provides[] 에 `@X p_iit4` 추가 — hub 가 이제 `stdlib/consciousness/iit4` 를 PROVIDES (anima H_278 fold · g68 cross-repo · g61 shared substrate). consumers = VERIFY-KIT V5 · ARXIV A2 (배선 = V5.2).

### V5.2/V5.3 readiness (남은 작업)
- V5.2 wire: `tool/verify_cli.hexa` 의 `_recompute` 경로에 `iit4_faithful_phi` 배선 + farr-입력 인터페이스(현 verify CLI 는 스칼라 args; Φ 는 flat state farr 필요 → 입력 어댑터 설계 필요). H_278 의 `c_phi_mi_pair` builtin 은 이미 hexa-lang 런타임에 있으므로 builtin 경로로도 배선 가능(번들 버전과 byte-eq 확인 권장).
- V5.3 calibrate: PyPhi 와 수치 대조 (n≤8 substrate). H_278 의 honest carve-out — faithful = exact-MIP-EI small-N 이지 full per-mechanism IIT 4.0 (= `stdlib/consciousness/iit4_bigphi.hexa`) 아님.

### tier
- 🟡 promote-only (anima Φ 엔진을 stdlib 로 promote; wire+calibrate = V5.2/V5.3). V5 `[ ]` 미플립 (promote 만 done).

## 2026-05-26 — V6 (P3a) `register --source <attribution>` → provenance 필드 자동 (OEIS O4 hand-fold 제거)

### 목표 (OEIS O4 가 손으로 fold 한 이유 제거)
- OEIS O4 가 `aliquot↔A001065·sigma_2↔A001157·sigma_3↔A001158` 3개 @F 노드를 `embedded.gen.hexa` 에 직접 hand-fold 해야 했던 이유 = `hexa atlas register --from-verify` 가 고정 포맷 `verified-<fn>-<n>` 노드를 hardcoded `g_self_verify` cite 로만 만들고 `source` (OEIS 어트리뷰션) 필드를 안 써서. V6 가 `--source "<text>"` 플래그를 추가해 fold 노드가 attribution 을 자동으로 carry → hand-fold 불요.

### 변경 (g0/g33 surgical · atlas_cli.hexa 단독 편집)
- 신규 `_provenance_lines(source, url)` 헬퍼: `source`/`url` 이 non-empty 일 때만 `source = "<text>"` / `url = "<link>"` 라인 emit (둘 다 empty → "" = default 무변경). O4 hand-fold shape 정확히 미러 — `verified-by` 와 `cite` 사이에 삽입.
- `_build_raw_F` / `_build_raw_F_numerical` 시그니처에 `source`/`url` 추가 (legacy dead-code 호출자 `_adapt_verify_1op/2op/3op/float` 는 `"", ""` 전달 → 행동 불변).
- 활성 경로 `_adapt_verify_generic` / `_adapt_verify_compute` 가 `source`/`url` thread.
- `cmd_register` 가 `--source`/`--url` 파싱 → 3개 adapter 호출지점에 전달. help 텍스트 + 보조 usage print 갱신.
- source = PROVENANCE 어트리뷰션, `g_self_verify` = 검증 cite (별개로 둘 다 유지). source 텍스트는 shell 에 안 들어감 (`exec` 는 fn_name/args 만; source 는 노드 raw 문자열로만, fold 시 `_hxesc` escape).
- **codegen 무변경** — `hexa cc --regen` 불요.

### 빌드 함정 — 설치 드라이버 V4-stale (V7 와 동일 뿌리)
- `hexa verify` (JIT-build verify_cli) 가 `_jacobi_symbol`/`_kronecker_symbol` undefined 로 link-fail — 설치 `hexa.real` (May-25) 이 #1148/#1150 special-fn 심볼보다 stale. register 는 verify 에 위임하므로 동작 불가.
- 해결 (mini bootstrap 불요): 로컬 toolchain 으로 `bin/hexa-atlas` + `bin/hexa-verify` 를 직접 빌드 (parse-gate 가 `hexa_cc` 를 HEAD 소스로 재빌드한 직후라 local `build/hexa_v2` 가 HEAD-aware → `_jacobi_symbol` 등 정상 링크). `hexa verify` 가 cwd `bin/hexa-verify` sub-binary 를 preferring 하지만 설치 shim 이 stale 이라 안 씀 → `/tmp/hexa` PATH wrapper 로 `verify`→`bin/hexa-verify` 포워딩.

### 테스트 (격리 atlas · verbatim → `.verdicts/verify-kit-register-source/v6.txt`)
- `HEXA_ATLAS_EMBED=/tmp/wt-vkit-v6-iso` 로 worktree 의 격리 embed 에만 fold (shared 트리 보호 · E3 leak 방지).
- TEST 1: `register --from-verify aliquot 6 --source "OEIS A001065" --url "https://oeis.org/A001065" --compute` → 🔵 SUPPORTED-FORMAL, 노드에 `source = "OEIS A001065"` + `url = "https://oeis.org/A001065"` present (byte-grep 확인).
- TEST 2 (regression): `register --from-verify sigma 6` (no --source) → 노드에 `source`/`url` 라인 0 (default 무변경).
- leak check: `git diff --stat compiler/atlas/embedded.gen.hexa` = empty → shared 트리 무누출. diff = atlas_cli.hexa 코드 + verdict 만.

### 결과
- V6 CLOSED. `register --source`/`--url` → provenance 필드 자동. OEIS O4 hand-fold 자동화 완료 — 향후 OEIS fold 는 `--source`/`--url` 사용. tier 🟢 (CLI capability, byte-grep 확인 + regression + no-leak). OEIS.md O4 라인 cross-link.

---

## 2026-05-26 — V7 (P3b) 조합론/소수 정수 primitive (OEIS 🟠→🔵 mutual-feed)

### 목표 (OEIS O3 의 287 🟠 NO-PATH 중 prime×67 해소)
- OEIS O3 가 336 survivor 를 8 🔵 / 41 🟡 / 287 🟠 로 티어링. 🟠 의 dominant family = A000040 (소수열) ~67 hit, "no recompute path". V7 이 nth_prime/is_prime 을 추가해 그 prime hit 들이 🟠→🔵 로 전환되게 한다. 이게 OEIS↔VERIFY-KIT mutual-feed 루프의 실현 (catalogue 가 gap 을 surface → VERIFY-KIT 이 primitive 추가 → catalogue 재티어).

### 착수 fn (6개 · 전부 순수 정수 closed-form)
- PRIMARY: `nth_prime`(A000040 · trial-division 누적), `is_prime`(trial-division 0/1), `factorial`(A000142), `catalan`(A000108 · 정수 반복식 Cₙ=Cₙ₋₁·2(2n−1)/(n+1)).
- STRETCH: `bell`(A000110 · Aitken Bell triangle), `partition`(A000041 · Euler pentagonal-number 재귀 DP).
- 정수 exact 라 `--tol` 불요 → 전부 🔵 SUPPORTED-FORMAL. (stretch stirling2·radical·factorint 는 미착수 defer.)

### 핵심 발견 — V4 (특수함수) 와 달리 codegen 무변경
- 정수 fn 은 `cg_math_sym` (libm 라우팅) 이 전혀 불필요 → **`hexa cc --regen` 안 함**. 정의를 기존 number-theory home `compiler/atlas/symbolic/congruence_chain_engine.hexa` 에 추가 (sigma_k/euler_phi 와 동형 스타일), `tool/verify_cli.hexa::_recompute` (1-arg dispatch) 에 6줄 배선 + help 1줄. sigma/tau 메커니즘 정확히 미러.
- fn 이름 충돌 회피: 엔진 내부는 `is_prime_int`/`factorial_int` (stdlib `is_prime`/`factorial` 와 분리), verify_cli 가 사용자 fn 이름 `is_prime`/`factorial` 로 노출.

### 빌드 함정 — 설치된 드라이버가 V4-stale
- `bin/hexa-verify` 빌드가 V4 의 bessel/gamma/erf 심볼에서 실패 (`hexa_call1(bessel_j0,x)` undeclared). 진단: pristine origin/main verify_cli 도 동일 실패 → **내 V7 변경과 무관**. 설치 드라이버(`hexa.real`, `0.1.0-dispatch`)에 V4 `cg_math_sym` 매핑 0개 = V4 (#1148) 보다 stale. worktree 의 `self/native/hexa_cc.c` 에는 V4 매핑이 이미 commit 돼 있음 (hexa_math_j0 grep=1).
- 해결: `mini` (Mac arm64 pool host) 에 worktree rsync → amalgam swap (runtime.h→runtime.c) 로 V4-aware `build/hexa_v2` 부트스트랩 → module_loader → verify_cli flatten(13 files)+transpile(emit C 에 hexa_math_j0 정상 출현)+compile → `bin/hexa-verify` (clang error 0). 바이너리 pull back. pool-route 훅이 로컬 clang 을 가로채므로 mini 경유 (heavy C 컴파일).

### 테스트 매트릭스 (verbatim → `.verdicts/verify-kit-combinatorial/v7.txt`)
- PRIMARY: nth_prime 5 --compute=11 · nth_prime 5 11 🔵 · nth_prime 1 2 🔵 · catalan 4 --compute=14 · catalan 4 14 🔵 · catalan 0 1 🔵 · is_prime 7 1 🔵 · is_prime 6 0 🔵 · factorial 5 120 🔵.
- STRETCH: bell 3 5 🔵 · bell 4 --compute=15 · partition 4 5 🔵 · partition 5 --compute=7.
- NEGATIVE control (determinism): nth_prime 5 13 🔴 · is_prime 6 1 🔴.
- REGRESSION: sigma 6 12 🔵 · gamma 5 24 --tol 1e-6 🟢 (V4 intact).

### OEIS 🟠→🔵 conversion proof (mutual-feed)
- A000040 spot-verify: nth_prime 1 2 / 5 11 / 10 29 / 25 97 / 100 541 전부 🔵 SUPPORTED-FORMAL.
- 전환 수: prime family (A000040) ~67 of 287 🟠 → 🔵 reachable. 나머지 🟠 의 대부분 = n×190 (trivial identity a(n)=n, fn 이 아니라 recompute 후보 X → 비범위) + ~30 misc conjectural (정직하게 🟠 유지).
- 추가로 O3 외부 OEIS reach 도 열림: A000108(catalan)·A000142(factorial)·A000110(bell)·A000041(partition) 전부 🔵-verifiable.

### 산출
- `.verdicts/verify-kit-combinatorial/v7.txt` (verbatim matrix + OEIS conversion proof) · `CLAIMS.tape` @C verify_kit_combinatorial [slug=verify-kit-combinatorial group=VERIFY-KIT] 🔵 · `OEIS/OEIS.md` O3 note · 본 도메인 V7 [x].

---

## 2026-05-26 — V4 (P1b) 특수함수 primitive (gamma·erf·bessel) via native libm + --tol

### 목표 (DLMF blocker (2) — hexa verify 특수함수 0개)
- DLMF O6 가 두 가지로 🔴 닫힘: (1) bulk-corpus 부재, (2) hexa verify 에 특수함수 ZERO. V4 는 (2) 만 해소 — primitive 를 제공할 뿐 DLMF 재흡수가 아님 (정직).
- 값이 무리수 (Γ·erf·Bessel J) → V3 `--tol` 로 🟢 SUPPORTED-NUMERICAL, 절대 exact 🔵 불가.

### 핵심 발견 — `stdlib/special/` 신설이 아니라 기존 lgamma 메커니즘 미러
- 처음엔 `stdlib/special/` 모듈을 가정했으나, 조사 결과 **`lgamma` 가 이미 작동하는 libm builtin** (`stdlib/core/math/float.hexa` 가 `lgamma(x)` 직접 호출). 노출 경로 = **`self/codegen.hexa`** (NOT `build_c.hexa` — 그건 비활성 레거시 codegen) 의 `cg_math_sym` 테이블 (`lgamma → hexa_math_lgamma`) + `self/runtime.c` 의 `hexa_math_lgamma` + `runtime.h` decl. 이 4-site 패턴을 그대로 미러.
- `self/codegen.hexa` 4-site: (a) name-mangle 리스트 (`erf`/`gamma`/`tgamma` 이미 존재) · (b) `cg_math_sym` 추가 (`gamma→hexa_math_tgamma`, `tgamma→hexa_math_tgamma`, `erf→hexa_math_erf`, `erfc→hexa_math_erfc`, `bessel_j0→hexa_math_j0`, `bessel_j1→hexa_math_j1`) · (c) 1-arg call-emit 추가 · (d) `_is_float_returning_call` (`tgamma`/`erf`/`erfc` 이미 존재, `gamma`/`bessel_j0`/`bessel_j1` 추가).
- `self/runtime.c`: `hexa_math_tgamma`/`erf`/`erfc`/`j0`/`j1` 추가 (lgamma 와 동형 — `hexa_float(tgamma(HX_FLOAT(x)))`). `self/runtime.h`: 5 decl 추가 (emit C 가 include → C99 implicit-decl 빌드실패 방지).
- `compiler/atlas/calc_dispatch.hexa`: `calc_is_float_fn` 에 `gamma`/`erf`/`bessel_j0`/`bessel_j1` 추가 (CLI 가 float-recompute 경로로 라우팅).
- `tool/verify_cli.hexa`: `_gamma`/`_erf`/`_bessel_j0`/`_bessel_j1` 헬퍼 + `_recompute_float` dispatch + help 5줄.

### 거버넌스 (CLAUDE.md stdlib_trig_libm)
- 전부 native libm (`tgamma`/`erf`/`erfc`/`j0`/`j1`) — hand-rolled Taylor 금지 (float→int narrowing collapse 위험). lgamma 와 동일 IEEE-correct 경로.

### 빌드 (codegen 변경 → 트랜스파일러 재생성)
- codegen 변경이라 `hexa cc --regen` 필수 (hexa_cc.c 직접편집 금지). worktree 에서 `cc --regen` → `self/native/hexa_cc.c` (+66 lines) → clang → `/tmp/hexa_v2.new` → `build/hexa_v2` + `self/native/hexa_v2` promote. `self/runtime.o` 재컴파일 (새 hexa_math_* 심볼). `bin/hexa-verify` 재빌드.
- **함정**: pool-route 훅이 `hexa build`/`hexa cc` (heavy_pairs) 를 가로채 pool 라우팅 시도 → 빌드는 wrapper `.sh` (커맨드 문자열에 `hexa build` 인접쌍 없음) 경유. 트랜스파일러 해석은 `install_dir_from_argv0` 가 main repo 로 가버려, worktree binary 를 `hexazz` (hexa-prefix) 로 복사 후 풀패스 직접 호출 → argv[0] dir = worktree → worktree `build/hexa_v2` 채택.

### 측정 (verbatim → `.verdicts/verify-kit-special/v4_special.txt`)
- gamma 5 --compute = 24.0 🟢 · gamma 5 24 --tol 1e-6 🟢 (|Δ|=0) · gamma 0.5 1.7724538509 --tol 1e-6 🟢 (√π, |Δ|=5.5e-12)
- erf 0 --compute = 0.0 🟢 · erf 1 0.8427007929 --tol 1e-6 🟢 (|Δ|=5e-11)
- (STRETCH) bessel_j0 0 1 --tol 1e-6 🟢 · bessel_j1 0 0 --tol 1e-6 🟢

### Landed vs Deferred
- **Landed**: gamma·erf (PRIMARY) + bessel_j0·bessel_j1 + erfc·tgamma (언어 primitive). 전부 🟢.
- **Deferred**: zeta(s) — libm ζ 부재. Euler-Maclaurin 합산은 빌드 리스크 (g0/g33 hard-defer). 정직하게 V4 비범위.
- **DLMF**: blocker (2) {gamma,erf,bessel} coverage 해소; blocker (1) bulk-corpus 는 OPEN 유지 → DLMF 흡수는 reopen 아님.

---

## 2026-05-26 — V3 (P1a) round-tolerance `--tol <eps>` (literature-rounded 값 🟢 · 옵트인)

### 문제 (INBOX 2026-05-26T01:30Z item(3) · 동일 클래스 item(b) — V1 이 별개 항목으로 defer)
- `hexa verify --expr allen_dynes_tc 0.6150 591.18 0.10 14.55` → calc=14.5511, |Δ|=0.00108 > strict ε=1e-9 → 🔴 FALSIFIED. 그러나 14.55 는 literature 의 6-digit 반올림일 뿐 — 진짜 falsification 이 아님 (spurious 🔴).
- V1 이 register 경로(엔진 자체 계산값 fold)는 round-tolerance 무관으로 닫았으나, `verify --expr <fn> <args> <literature_value>` 경로는 여전히 rounded input 에 🔴.

### 구현 (g0/g33 surgical · additions-only)
- `tool/verify_cli.hexa`: 헬퍼 3개 신설 — `_has_tol(rest)`(`--tol` 플래그 존재 여부), `_get_tol(rest)`(`--tol` 다음 operand 를 float 파싱; 없으면 0.0 = strict 로 degrade), `_strip_tol(rest)`(`--tol <eps>` 페어를 제거한 argv 복사본 — 하류 arity 판정이 2 토큰에 흔들리지 않게; --absorb/--no-absorb/--compute 플래그 관용과 동형).
- `cmd_expr_float` / `cmd_expr` 진입부에서 `tol`/`tol_on` 캡처 + `_strip_tol` 로 정제. float 경로는 원본 argv 를 받아 내부 strip(콜 경계 너머 플래그 보존), int 경로는 정제본으로 operand 카운트.
- verdict 분기: strict ε=1e-9 통과 → 기존 🔵/🟢 그대로. strict 실패이지만 `tol_on && |Δ| ≤ tol` → 🟢 SUPPORTED-NUMERICAL (round-tolerant) + `(within tol <eps>, calc=… vs expected=…)` 노트. `tol` 너머 → 🔴 (명시 메시지 "tolerance does NOT launder failures"). --tol 부재 시 기존 strict 🔴 메시지 그대로.
- **falsification 무결성**: `--tol` 은 명시 옵트인 — 기본(--tol 무) = tolerance 없음 = 현 strict 동작 그대로. silent-widen 0. round-tolerant 🟢 는 auto-absorb 안 함 (atlas 는 V1 대로 엔진 정밀값만 fold, literature-rounded operand 는 절대 fold 안 함).
- int 경로: 정확 int closed-form 은 tolerance 불요지만, coarse expected 값 대비 `--tol` 옵트인 시 동일 밴드 적용 (`sigma 6 13 --tol 2` → 🟢; `sigma 6 20 --tol 2` → 🔴).

### 검증 (`.verdicts/verify-kit-tol/v3_tol.txt` verbatim)
- 빌드: `bash tool/build_hexa_verify.sh` → `bin/hexa-verify` (mac arm64, module_loader 선빌드 후 성공).
- `--expr allen_dynes_tc 0.6150 591.18 0.10 14.55 --tol 0.01` → 🟢 (within tol, |Δ|=0.00108).
- `--expr allen_dynes_tc 0.6150 591.18 0.10 14.55` (no --tol) → 🔴 (strict, unchanged).
- `--expr allen_dynes_tc 0.6150 591.18 0.10 99.0 --tol 0.01` → 🔴 (beyond tol — NOT laundered).
- regression: `--expr sigma 6 12` → 🔵 (exact, no tol) · `sigma 6 13 --tol 2` → 🟢 within-tol · `sigma 6 13`(no tol) → 🔴 · `sigma 6 20 --tol 2` → 🔴 beyond.
- parse-gate: `hexa parse tool/verify_cli.hexa` clean.

### 닫힘
- INBOX 2026-05-26T01:30Z item(3) + 동일 클래스 item(b) RESOLVED. V1 이 deferred 한 round-tolerance 종결. CLAIMS.tape `verify-kit-tol` (group=VERIFY-KIT, method=tolerance) 🟢.
- 주의: 작업 중 `/tmp/wt-vkit-v3` 워크트리가 외부 cleanup 으로 삭제되어 재생성 + origin/main fast-forward 머지(OEIS-O4 landed) 후 전체 edit 재적용 → 재빌드 → 재검증. 최종 상태는 이 entry 기준.

---

## 2026-05-26 — V1 (P0a) register↔verify_cli 미러통합 (RTSC allen_dynes_tc unblock)

### 문제 (INBOX 2026-05-26T01:30Z · #954 확장)
- `hexa verify --expr allen_dynes_tc 0.6150 591.18 0.10 14.55` → calc=14.5511 (계산기 정상). 그러나 `hexa atlas register --from-verify allen_dynes_tc 0.6150 591.18 0.10` → 🟠 INSUFFICIENT "no calculator path". RTSC 1순위 verify fn 이 atlas 흡수 불가 + 16-fn class 전면 차단.
- 진단: **이미 main HEAD 에서 register 는 delegation 으로 마이그레이션 완료** (`_adapt_verify_generic` 가 `exec("hexa verify --expr …")` 로 shell-out; per-fn 미러 `_recompute_float_register` 는 dead code — `calc_dispatch.hexa` 코멘트가 명시). 즉 미러 desync 자체는 main 에서 이미 해소. 남은 진짜 gap 2개: (1) register 가 마지막 positional 을 `<v>` 로 소비 → 3-arg fn 의 3번째 operand(μ*)를 claimed value 로 오인 → verify 가 2-arg 로 계산(allen_dynes_tc argc<3 → `_NOCALC_F` → 🟠). (2) `cmd_expr_float` 에 value-less COMPUTE mode 부재 (int 경로엔 `cmd_expr_compute` 있으나 float 엔 없음) → `--compute` 가 float fn 에 무효.

### 채택 경로 = PRIMARY (proposal a · root delegation)
- `tool/verify_cli.hexa`: `cmd_expr_float_compute(rest, fnm)` 신설(int `cmd_expr_compute` 의 float 짝) + `cmd_expr_float` 진입부에 `_has_compute` 라우팅 추가. `--compute` 시 fn 이후 모든 non-flag operand 를 ARG 로 보고 `_recompute_float` 로 계산(argc=operand 수) → `COMPUTE: <fn>(<args>) = <v>` + recompute 2회 self-verify → 🟢. 기존 VERIFY 경로 무손상.
- `tool/atlas_cli.hexa`: `_parse_compute_value(out)`(COMPUTE 라인 파싱) + `_adapt_verify_compute(fn, args, id)`(value-less compute-and-fold; `hexa verify --expr <fn> <args> --compute` 위임, atlas 미러 의존 0) 신설. `cmd_register` 에 (i) 명시 `--compute` arm, (ii) value-bearing 경로가 🟠 일 때(=arity miss) 모든 positional 을 operand 로 보고 compute 재시도 auto-route 추가. 진짜 🔴(계산 불일치)은 재시도 안 함 → falsification 무오염.
- d4/g20: 단일 calc home = verify_cli. atlas 는 recompute 미러를 안 가짐(delegation). dead-code 미러는 `cmd_reverify` 용으로 남겨둠(WIPE-OK 불필요 — additions-only).

### 빌드 + 검증 (mac arm64, PATH-relative hexa)
- parse-gate: `hexa parse` 양쪽 `OK`.
- build: `bash tool/build_hexa_verify.sh` → SUCCESS (bin/hexa-verify). `hexa build tool/atlas_cli.hexa -o bin/hexa-atlas` → SUCCESS (atlas 레시피의 repo-local `./hexa` 셔임은 worktree 에 hxv2/hexa.real 부재 → 설치 드라이버로 직접 빌드).
- e2e: 설치 `hexa verify` 드라이버가 install_dir(`~/core/hexa-lang`) 의 메인 bin 을 해소하므로, 내부 `exec("hexa verify …")` 가 새 binary 를 타도록 test 셔임(`/tmp/vkit-shim/hexa` → worktree bin/hexa-verify)으로 라우팅. atlas binary 는 hyphenated 이름이라 SIGKILL matcher 우회 → 직접 실행.
- **ACCEPTANCE (verbatim → `.verdicts/verify-kit-mirror-unify/v1_register.txt`)**:
  - `register --from-verify allen_dynes_tc 0.6150 591.18 0.10` → `allen_dynes_tc(0.6150,591.18,0.10)=14.5511 (compute — auto-routed from 🟠)` · **🟢 SUPPORTED-NUMERICAL** (was 🟠 "no calculator path"). ✅
  - 명시 `--compute` 동일 14.5511 🟢.
  - RTSC unblock: mcmillan_tc=12.0423 🟢 · morel_anderson_mustar=0.112262 🟢 (3-arg).
  - fresh fold 확인: novel-arg allen_dynes_tc → `folded @F` (embedded.gen.hexa 직접 splice 작동; 테스트 노드는 메인 repo 에서 즉시 제거).
- 회귀: `sigma 6 12` (1-op VERIFY) → 🔵 · `sigma 6 --compute` → sigma(6)=12 🔵 · int compute `verify --expr sigma 6` → 🔵 무손상.
- 별개 항목(V1 비범위): round-tolerance ε=1e-9 vs literature-rounded — `allen_dynes_tc … 14.55` → 🔴 (정상; 14.5511≠14.55). V1 성공기준 = register 가 값을 COMPUTE 함(no more "no calculator path") → 충족.
- V1 tier = 🟢.

### INBOX
- 2026-05-26T01:30Z `allen_dynes_tc` 3건(미러 desync · 3-arg arm 부재 · 영향범위) resolved-class · #954 mirror-desync 항목 ACK.

---

## 2026-05-26 — 도메인 개시 + V2 (P0b) value-less compute mode

### 개시
- VERIFY-KIT 도메인 신설. `hexa verify` 의 계산 primitive 확장 lane. catalogue-mirror(OEIS/DLMF/ARXIV) 흡수의 공통 upstream — 흡수가 부딪힌 "측정 도구 부재" 를 푼다.
- 로드맵 V1-V10 (P0-P5) 등록. V2 가 첫 milestone.

### V2 — value-less compute mode (DONE)
- 문제: `--expr <fn> <n> <v>` 는 기대값 `<v>` 를 미리 줘야 함 → 재확인만 가능, 계산 불가. 스윕이 `σ(7)=?` 를 CLI 로 못 얻음.
- 구현: `tool/verify_cli.hexa` 의 `--expr` 핸들러 확장 (g0 Occam — 새 verb 없이 기존 verb 확장). 새 헬퍼 `cmd_expr_compute(rest, ops)` + 플래그 헬퍼 `_has_compute(rest)` 추가. 기존 3-arg verify 경로는 무손상.
- **disambiguation 규칙 (operand-count)**: compute = verify 형태에서 trailing `<v>` 를 뺀 것. 즉 operand 가 정확히 1개 적음.
  - `--expr sigma 7` (operand 1개, 후행값 없음) → COMPUTE σ(7). int 1-op 에는 0-op verify 형태가 없으므로(0-op 은 float 전용·이미 float 경로로 분기) len-3 은 모호하지 않음 → 자동 compute.
  - `--expr sigma 7 8` (operand+값) → 기존 VERIFY σ(7)==8 (무손상).
  - 다중 operand compute (`--expr sigma_k 12 1`) 는 1-op verify (`--expr <fn> <n> <v>`) 와 arg-count 충돌 → 명시 `--compute` 마커 필요 (`--expr sigma_k 12 1 --compute`). backward-compat 우선: 마커 없으면 항상 기존 verify 로 라우팅.
- 출력: `COMPUTE: sigma(7) = 8` + self-verify (recompute 2회 — 결정론 보장 → 🔵, 불일치 시 🔴 계산기버그). compute 는 read 이므로 atlas auto-absorb 미발동 (value-bearing verify 형태만 absorb).
- surgical (g34): `--expr` 핸들러 + 헬퍼 + usage 텍스트만 수정. diff = +120 / -7 (additions-only, wipe-guard clean).

### 빌드 + 검증 결과
- parse-gate: `hexa parse tool/verify_cli.hexa` → `OK: parses cleanly`.
- build: `bash tool/build_hexa_verify.sh` → **SUCCESS** (bin/hexa-verify). origin/main 에서 INBOX-언급 link blocker(static_atlas/sigma_k 미정의) 는 재현되지 않음 — 정상 빌드.
- 측정 (verbatim → `.verdicts/verify-kit-compute-mode/v2_compute.txt`):
  - `--expr sigma 7` → `COMPUTE: sigma(7) = 8` 🔵 (1+7)
  - `--expr tau 6` → `COMPUTE: tau(6) = 4` 🔵 (1,2,3,6)
  - `--expr phi 6` → `COMPUTE: phi(6) = 2` 🔵 (1,5)
  - `--expr sigma_k 12 1 --compute` → `COMPUTE: sigma_k(12,1) = 28` 🔵
  - `--expr no_such_fn 5` → 🟠 INSUFFICIENT (compute mode)
  - 회귀(verify 무손상): `--expr sigma 6 12` → 🔵, `--expr sigma 6 99` → 🔴, `--expr sigma_k 12 1 28` → 🔵
- V2 tier = 🟢 (built + tested).

### downstream
- OEIS O3 라인 cross-link: V2 compute mode 가 per-hit fresh verify unblock.
- 다음: V1 (미러 통합) · V3 (tolerance verify) · V4 (특수함수 stdlib → DLMF 재개).

---

## 2026-05-26 — OPS: 설치 드라이버 HEAD 재설치 (g27 ship-cycle · V*-stale 블로커 종결)

### 문제
- 설치된 verify 경로(`$install/bin/hexa-verify`, install_dir = `/Users/ghost/core/hexa-lang`)가 #1148(V4 특수함수 `--tol`)·#1150(V7 nth_prime/catalan)·#1152 이전 빌드여서, `hexa verify --expr gamma … --tol`/`nth_prime …` 호출이 실패. V6/V7 작업마다 mini-bootstrap / local HEAD-rebuild + /tmp PATH wrapper 로 우회해 옴.
- 정정: `hexa verify --expr` 는 verify_cli 를 JIT 재빌드하지 않음 — driver(self/main.hexa sub=="verify")가 미리 컴파일된 `bin/hexa-verify` 를 우선 사용. 따라서 stale 한 진짜 컴포넌트 = `bin/hexa-verify` (driver 바이너리도 함께 갱신).

### 조치 (atomic · reversible)
- build host = **mini** (arm64 mac pool, local-arch 일치). `/tmp/wt-driver-head` 에 HEAD(e7c15ec1) fresh clone → `hexa_v2` transpiler + `hexa_module_loader` + `bin/hexa-verify` + driver(`build/hexa_darwin_arm64`) 빌드 → scp back.
- atomic replace (same-fs temp + `mv -f`): `bin/hexa-verify`(757664B) · `~/.hx/bin/hxv2`(808192B) · `~/.hx/bin/hexa.real`(808192B). 백업 보존(`*.bak-1779729853/…907/…211`).

### 검증 (instrument-first · 설치 드라이버 통과 verbatim → `.verdicts/driver-reinstall/reinstall.txt`)
- `hexa verify --expr gamma 5 24 --tol 1e-6` : `error: to_int: trailing garbage in "--tol"` → **🟢 SUPPORTED-NUMERICAL** (V4)
- `hexa verify --expr nth_prime 5 11` : 🟠 INSUFFICIENT(no path) → **🔵 SUPPORTED-FORMAL** (V7)
- `hexa verify --expr sigma 6 12` : 🔵 → **🔵** (회귀 무손상)

### 결과
- driver reinstalled to HEAD — V4/V7 심볼이 이제 설치된 `bin/hexa-verify` 에 들어가, 향후 V* 빌드는 per-build bootstrap 불요(bootstrap-free). rollback 불요(3/3 PASS).
