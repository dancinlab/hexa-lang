# INBOX — log

Append-only history sister of `INBOX.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-25T17:20Z — codegen: cross-scope const-fold collision (silent wrong-answer) + anima M6 deferral 갭 (from: anima MODERNIZE M6)

anima의 interp-era `.hexa` build-modernize (M6) 중 발견. 6-agent 병렬 sweep + 회수로 58/72 build-fix 완료, 잔여 13개가 아래 upstream 원인에 막힘.

### ⚠ 핵심 codegen 버그 — cross-scope const-fold collision (silent 오답)
서로 다른 함수의 **동명 immutable `let`** 바인딩이 const-fold 단계에서 충돌. 한 함수의 리터럴-바운드 `let`이 다른 함수의 동명 `let`으로 접혀 들어감. **빌드 에러가 아니라 조용한 오답** — 가장 위험한 class.

- [ ] minimal repro (`hexa run` → `2147483648`, 기대 `10.0`):
  ```
  fn lcg_m() -> int { let m = 2147483648; return m }
  fn compute(h: float) -> float { let m = h * 2.0; return m }
  fn main() { print(compute(5.0)) }
  ```
  `compute`의 `m = h*2.0`이 `lcg_m`의 `m = 2147483648` 리터럴로 const-fold됨. 실측: anima `training/train_clm_emergent.hexa`에서 `m = vec_mean(h)`가 LCG modulus `2147483648`로 mis-fold (실데이터 silent 오류). 짧은 이름(`a`/`c`/`m`)일수록 빈발. anima측 임시 우회 = source 변수 rename(`lcg_a`/`lcg_c`/`lcg_m`) — **proper fix는 codegen scope 분리** (g11/g21: 우회는 anima에 잔존, 본 fix는 upstream).

### 부수 진단갭 — immutable `let` 재대입 → invalid C
- [ ] `let i = 0` 후 `i = i + 1` (interp-era 허용 패턴)이 hexa-strict에서 immutable `let`을 리터럴로 const-fold → `0 = 0 + 1` invalid C 생성 ("expression is not assignable"). **clear한 "cannot assign to immutable binding" 진단** 대신 C-codegen 단계 깨짐. anima측 proper fix = `let mut`로 마이그레이션 (M6 대다수 케이스, ~50 file). 진단을 parser/typecheck 단계로 올리면 마이그레이션 UX 개선.

### anima M6 deferral 13-file (upstream 원인별 — anima 자력 proper-fix 불가)
- [ ] **missing/removed builtin (현재 대체 불가)**: `tensor_randn(size,seed)` arity (native는 `(r,c)`) — `models/lm_head_uv.hexa` · `bytes_encode`/`bytes_decode` 제거 — `serving/kr_quality_{gate,score}.hexa` · `hex_byte`/`bytes_to_hex` 제거(소스 주석도 확인) — `tool/drill_self_ref_noise_probe.hexa` · `dir_exists` 제거(`file_exists`=S_ISREG) — `training/clm_r5_bundler.hexa` · `deref_i64` 제거(read-side i64 ptr-deref) — `training/nn_core.hexa` · `xavier_init`/`cosine_sim` 미존재 — `experiments/consciousness/consciousness_bridge.hexa`
- [ ] **runtime.h staleness** (`.o`엔 심볼 있으나 prototype 부재 → clang `-Werror=implicit-function-declaration`): `rt_read_bytes_at` — `training/alm_bf16_decode_probe.hexa` · `rt_read_lines` — `training/quadruple_cross_sweep.hexa`
- [ ] **parse feature gap (dead/미지원 syntax)**: `effect { fn … }` 대수효과 블록(repo 6-file 동일 FAIL) — `serving/consciousness_aware_refusal.hexa` · 이종 tuple return `-> [bool, float]` + `null` — `serving/consciousness_gate.hexa`
- [ ] **cross-module 미해결**: `xavier_init`/`zeros`가 in-file 미정의(자매 anima-core 파일에 정의) — `anima-core/trinity.hexa` (interp-era cross-module ref, import 배선 = 도메인 wiring 위험으로 anima측 deferred)

## 2026-05-25T00:50Z — [정정] 위 "빌드 회귀" 보고 RETRACT — worktree 아티팩트였음 (from: demiurge TTR-MN)

직전 엔트리(00:25Z)의 "빌드 회귀" 진단은 **오진**이었음 — origin/main 은 정상. 실제 원인: `hexa build` 의 use-확장(module-loader)이 **정식 repo 루트 `~/core/hexa-lang` 에서만** 작동하고, `/tmp` 의 detached git worktree 에선 건너뜀.
- [x] 정식 루트에서 `bash tool/build_hexa_verify.sh` → `[1/2]` 가 `hexa_build_expanded.<ts>.tmp.hexa`(use-inline 확장본) 컴파일 → **빌드·링크 성공**
- [x] `/tmp` worktree 에선 `[1/2]` 가 `verify_cli.hexa` 를 **직접** 컴파일(확장 생략) → `static_atlas` 등 미정의 링크 실패 (= 00:25Z 가 본 증상)
- [x] `cycles_to_target`/`compound_coverage` (PR #803) 정식 루트 빌드 → `hexa verify --expr cycles_to_target 0.12 0.1 19` = **🟢 SUPPORTED-NUMERICAL** (TTR-MN timeline 5/5 · 대조 18→🔴 FALSIFIED)
- [ ] (선택) `hexa build` 가 worktree(`.git` 가 dir 아닌 file)에서도 use-확장 하도록 project-root 탐지 보강 — 추정 원인, 미확정 · low-pri gotcha

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

