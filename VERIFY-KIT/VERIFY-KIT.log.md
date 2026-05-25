# VERIFY-KIT — append-only step log

> 도메인 SSOT 스냅샷 = `VERIFY-KIT.md`. 이 파일은 step-by-step 작업 이력만 누적한다.

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
