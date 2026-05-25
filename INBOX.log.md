# INBOX — log

Append-only history sister of `INBOX.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-26T00:30Z — atlas_cli.hexa recompute-dispatch drift (@D d4) · from ANTIMATTER atlas-fold #1132

**맥락**: ANTIMATTER 26 atom을 atlas fold(PR #1132)하던 중 발견. `tool/atlas_cli.hexa`가 `_recompute_register` 등 **별도 하드코딩 recompute dispatch 테이블**을 들고 있고 antimatter atom과 동기 안 됨 = @D d4 single-generic-dispatch 위반. 이번엔 `_adapt_verify_generic`이 `hexa verify --expr`로 delegate해서 fold는 됐지만, 근본은 drift.

- [ ] `tool/atlas_cli.hexa`의 `_recompute_register` 하드코딩 테이블 제거 → 공유 `compiler/atlas/symbolic` dispatcher로 통합 (파일 자체 TODO도 동일 지적)
- [ ] 관련: shipped `bin/hexa-{verify,atlas}` stale → install-sync 갭 (atom 추가 후 재빌드 강제됨)

repro: hexa atlas register --from-verify <antimatter fn> · PR #1132 설명에도 flag됨

## 2026-05-26T01:30Z — atlas register 가 `allen_dynes_tc` (RTSC 핵심 verify fn, 3-arg) 흡수 불가 — atlas_cli↔verify_cli desync + 3-arg register arm 부재 (#954 확장)

demiurge RTSC "atlas 흡수" 시도 중 발견 — RTSC 캠페인의 verify-able 결과(초전도 Tc)가 atlas 에 전혀 흡수되지 못함. 차단 2겹:

- [ ] **(1) verify_cli HAS · atlas_cli register mirror LACKS** — `hexa verify --expr allen_dynes_tc 0.6150 591.18 0.10 14.55` → calc=14.5511 (계산기 정상 작동). 그러나 `hexa atlas register --from-verify allen_dynes_tc 0.6150 591.18 0.10` → `🟠 INSUFFICIENT · reason="hexa verify --expr allen_dynes_tc has no calculator path" · gap="add allen_dynes_tc to tool/verify_cli.hexa"`. = #954 와 동일 class: register 는 verify_cli 로 shell-out 하지 않고 `atlas_cli.hexa` 의 자체 미러(`_recompute_float_register`)로 in-process recompute → allen_dynes_tc 가 그 미러에 부재. **RTSC 의 1순위 verify fn 이 atlas 흡수 불가**.
- [ ] **(2) 3-arg register arm 부재** — allen_dynes_tc(λ, ω_log, μ*) = **3-arg**. 현 register 는 1-op (`<fn> <n> <v>`) + 2-op (`<fn> <a> <b> <v>`) 만. 3-arg `_recompute3_register` 경로 자체가 없음 (#954 의 2-arg case 들과 별개의 NEW sub-gap). verify_cli `--expr` 는 3-arg 처리하므로(14.5511 계산 확인) verify↔register arity 불일치.
- [ ] **(3) ε=1e-9 round-tolerance 재확인** — 설령 register 가 동작해도, 로그/문헌 Tc(6자리 반올림, 예 14.55)는 calc(14.55109xx)와 |Δ|>1e-9 → 🔴 FALSIFIED. register 가 expected 없이 *자체 계산값*을 fold 하거나 `--tol` 옵션 필요 (기존 RTSC INBOX round-tolerance item 과 동일).
- [ ] **영향 범위** — allen_dynes_tc 뿐 아니라 RTSC magnet 16-fn(wheeler·solenoid_endleakage·mutual_M_coaxial·current_loop_offaxis·elliptic_K/E·…, #954 목록)도 동일 차단 → RTSC 캠페인 전 verify-able 결과가 atlas 미흡수. 우선순위 ↑ (atlas 가 RTSC SSOT 역할 못 함).
- [ ] **제안** — (a) `--from-selftest`/generic verify-delegation arm (#954 제안 a)이 이 3건 모두 우회 — register 가 verify_cli 로 직접 shell-out(또는 동일 dispatch 공유)하면 미러 desync + arity 불일치 소멸. (b) 차선: atlas_cli 미러에 allen_dynes_tc + 3-arg `_recompute3_register` 추가.

Status: open · proposed-by:agent · severity:high (RTSC SSOT 흡수 전면 차단, 1순위 verify fn) · source:demiurge RTSC atlas-absorb 세션 2026-05-26 (실증: verify 🟢-able vs register 🟠) · awaits:hexa-lang fix · #954 확장


## 2026-05-26 — inbox/patches/ 트리아지 3건 (anima 2-gap + flame V3 갭 + cloud Option A 후속 확인)

`inbox/patches/` 에 미트리아지 상태로 쌓인 anima handoff 를 INBOX.md 로 라우팅. 각 건 origin/main 코드 대조로 status 판정:

- [x] **`cloud-launch-trainer-script-arg-missing.md` Option A (anima-side argv 수정)** — anima repo 대조: `HEXAD/PURE/launchers/dispatch_p21h_v3.hexa` train_launch argv 가 이미 `[…/launch_trainer_p21h.sh, …/train_p21h_v3.py, …]` (script-path 포함). 버그 형태 `[…sh, init_variant, seed]` 는 anima 트리 전체 grep 0건. anima **PR #423** (`fix(PURE): dispatch_p21h_v3 train_launch full argv`) 로 closed, origin/main 조상 확인. → Option A·C 양쪽 닫힘 (C = hexa-lang #1120).
- [ ] **`anima-flame-v3-coverage-gaps.md` (2026-05-26)** — flame coverage 기능 갭 8건. INBOX.md 신규 open 항목. P1 둘(full-position CE · V3-extension backward)이 학습정확도 직접 영향 + RFC 059 정렬. 차단 아님(anima 포팅본이 fallback 으로 smoke PASS). one-shot 아님 — RFC/feature 트랙.
- [ ] **`anima-discovered-2gaps-2026-05-25.md` G1 (linux wrapper 깨짐 + `-D_GNU_SOURCE`)** — G1 절반(`-D_GNU_SOURCE`)은 **이미 canonical 레시피에 존재**: `self/main.hexa` (`hexa cc` 경로 L1188/1294/1304) + `tool/build_hexa_v2_linux.hexa:145` (`-O2 -std=gnu11 -D_GNU_SOURCE`). 패치가 본 누락은 "runtime.c 직접 recompile fallback" 경로 한정 — canonical `hexa cc` 쓰면 비-이슈. 나머지 절반(ubu wrapper 심링크 dangling/PATH 부재)은 기존 open "pool stale" 항목과 동일뿌리 → 그 항목에 corroboration 으로 fold ([[reference_ubu_hexa_install_paths]]).
- [ ] **`anima-discovered-2gaps-2026-05-25.md` G2 (import-time `main()` auto-invoke)** — 진짜 미해결 갭. 트리 grep: `__main__`/`no_auto_main`/`_selftest` 가드 컨벤션 전무(archive 의 .py-풍 fire 파일 외엔 0). import 가 모듈 `main()` 을 auto-fire → eval/probe 라이브러리화 차단. **언어-semantics 변경 (blast-radius)** → 반사적 구현 금지, 설계결정 필요. INBOX.md 신규 open 항목 (RFC 후보).


## 2026-05-25T15:29Z — `hexa verify --expr <fn> <n>` 에 value-less COMPUTE mode 부재 (catalogue sweep / O3 per-hit verify 차단)

OEIS O2 full sweep (PR pending · slug=oeis-full-sweep) 에서 발견. `hexa verify --expr <fn> <n> <v>` 는 expected value `<v>` 를 **3번째 인자로 사전요구** 하고 그 값과 calc 를 비교(re-confirm)만 한다 — **fresh 값을 emit 하는 경로가 없다**.

- 실증 (origin/main 빌드): `hexa verify --expr sigma 7` (2-arg, 값 생략) → `error: usage: hexa verify --expr <fn> <n> <v> | <fn> <a> <b> <v> [--absorb]` (compute mode 없음). `hexa verify --expr sigma 7 8` (3-arg) → `calc = 8 == expected 8 · 🔵` (값을 내부적으로 계산하지만 비교용으로만 쓰고 standalone emit 안 함).
- 영향: catalogue sweep / discovery loop 이 `σ(7)=?` 를 CLI 로 얻을 수 없음 → 값은 하드코드 하거나 외부 소스에서 가져와야 함. O2 는 OEIS catalogue-verbatim 테이블을 하드코드 해 우회 (offset-correct). **O3 (per-hit fresh verify) 와 모든 generative discovery 가 이 gap 에 막힘** — "compute-then-verify" loop 불가.
- **DISTINCT from** 2026-05-25T08:45Z verify_cli whitelist 항목 (L126-136): 그건 특정 fn (lambert_w/wheeler 등) 이 whitelist 밖이라 `--from-verify` recompute 불가 ("no calculator path"). **본 gap 은 whitelist 에 이미 있는 fn (sigma/tau/phi) 조차** value-less compute 경로가 없다는 점 — calculator 가 있어도 값을 안 내준다. 직교 gap.

- [ ] **제안 (a · 선호)**: `hexa compute <fn> <n>` verb 신설 — 계산된 값만 emit (verify 비교 없음). discovery loop 의 1급 입력.
- [ ] **제안 (b · 대안)**: `hexa verify --expr <fn> <n>` (2-arg) 가 계산값을 **print AND self-verify** (값 출력 + 🔵 self-consistent tier). 기존 3-arg 의미 보존, 2-arg 만 새 동작.
- [ ] 둘 중 어느 쪽이든 O3 의 "compute-then-verify" loop 을 unblock — sweep 이 K=10 hit 의 a(n) 을 CLI 로 직접 재계산 → OEIS dump 값과 대조 → 🔵/🟡 tier 자동 분류 가능.
- [ ] **Tier (honest)**: `🟠 INSUFFICIENT · gap="no value-less compute path in verify CLI"`. severity: medium (O3 + generative discovery 의 구조적 차단; O2 는 catalogue 하드코드로 우회 성공).
- [ ] cross-link: OEIS O2 (slug=oeis-full-sweep · `.verdicts/oeis-full-sweep/`) → O3 (per-hit verify, 본 gap 해소 후 진행). 출처: OEIS/OEIS.md O2/O3.
- [ ] Status: open · proposed-by:agent · awaits:hexa-lang fix


## 2026-05-25T23:30Z — `hexa cloud nohup --early-life-check` — 조기-사망 launch 감지 (anima cloud handoff Option C 해소)

anima patch `inbox/patches/cloud-launch-trainer-script-arg-missing.md` (PR #1110 으로 filing) 수신. F-CURRICULA-1 fire (A100 SXM $1.49/hr) 가 `dispatch_p21h_v3.hexa:365` 의 argv 누락으로 `launch_trainer_p21h.sh` 의 `exec python3 -u "$@"` 가 script-path 없이 `python3 -u qwen 1337` 실행 → 즉사. pod 는 RUNNING 유지·과금, train 0 → **158분 idle burn ($3.92)**. dispatcher 는 `cloud_nohup` 이 pid 만 반환하면 즉시 리턴해서 원격 즉사를 못 봄 = silent class-1 실패.

- [x] **Option C 구현 (hexa-lang canonical)**: `cloud nohup … --early-life-check <sec>` 플래그 추가 (`stdlib/cloud/cloud_cli.hexa`). launch 후 `<sec>`초 sleep → `cloud_poll_opts` 1회 → 살아있으면 exit 0, 이미 죽었으면 **exit 3** (usage 2·nohup 시작실패 1 과 구분되는 distinct code) + "tear the pod down" 메시지. 호출자가 watchdog 타임아웃 대신 즉시 teardown 가능.
- [x] **flag-scan helper** `_early_life_cli(av, start)` — `_max_wall_cli` 미러, `--` 구분자에서 정지(원격 argv 안의 동명 토큰 미소비). `_ssh_opts_cli` 에 skip 브랜치 추가(ssh_opts 오염 방지).
- [x] **검증**: parse-gate clean. 격리 logic test 6/6 PASS (absent→0·present→value·after-sep 미소비→0·mixed→30·dangling→0·offset→120). `_cloud_early_life_check` 의 I/O 경로는 이미 검증된 `cloud_poll_opts` 재사용 + trivial control-flow.
- [x] help/usage 3곳 갱신 (banner · nohup usage · flag explainer).
- [ ] **Option A (anima-local, 비-hexa)**: `dispatch_p21h_v3.hexa:365` 가 `train_p21h_v3.py` 경로를 argv 에 포함하도록 수정 — anima repo 소관, 본 패치 권고대로 anima 측 적용 권장.
- [ ] 후속(선택): anima dispatcher 가 nohup 대신 `--early-life-check` 를 채택하도록 wire — 모든 anima trainer 에 일반화되는 가드.


## 2026-05-25T18:00Z — atlas binary-builtin lookup vs source embedded.gen.hexa divergence

TECS-L 축 E E2 audit 발견. `hexa atlas register --from-verify` 가 source `compiler/atlas/embedded.gen.hexa` 에 직접 splice 하지만, installed `hexa atlas lookup` 은 **binary-builtin (frozen at last hexa build)** 을 읽음. 결과:

- source (origin/main:compiler/atlas/embedded.gen.hexa): E1-folded `verified-{tau-33550336,tau-496,tau-8128,is_perfect-8589869056,gamma0_genus-6,gamma0_cusps-6}` 6개 모두 존재
- binary lookup (hexa atlas lookup --prefix=verified-): 74 hits (타 에이전트분), 내 E1 6개 = **0 findable**
- audit (hexa atlas stats --audit): 16101 entries, merged·clean (binary 내부 정합성은 OK)

원인: 메모리상 atlas SSOT는 `compiler/atlas/embedded.gen.hexa` (TEXT-parse), HEXA_ATLAS_EMBED 로 overlay 가능하다 했으나 실제 lookup 은 binary-builtin 우선/단독. 결과: register fold 가 query 에 반영되려면 hexa 재빌드 필요.

- [ ] `hexa atlas lookup` 이 HEXA_ATLAS_EMBED env 또는 cwd `compiler/atlas/embedded.gen.hexa` 를 binary-builtin 보다 우선 읽도록 동작 명세 정리/수정
- [ ] OR `hexa atlas register --from-verify` 가 source fold 후 binary-builtin 상태에도 in-memory 반영 (현재는 source 만 갱신)
- [ ] OR register 가 자동으로 `hexa cc --regen` 트리거 옵션 제공 (heavy, off by default)
- [ ] 참고: `.verdicts/tecs-l-atlas-health/binary_vs_source_divergence.txt` — 정량 데이터
- [ ] cross-link: TECS-L 축 E E3 (register install-dir leak) 와 짝 — register hazard + query staleness 양면


## 2026-05-25T15:00Z — hexa `dim_cusp_forms(N,2)` 가 표준 dim S₂(Γ₀(N))=genus 와 불일치

TECS-L 축 A MF4 발견 (PR pending). 고전 정리 `dim S_2(Γ_0(N)) = genus(X_0(N))` 를 hexa 의 `dim_cusp_forms`/`gamma0_genus` 두 fn 으로 N=1..30 교차검증한 결과:

- `gamma0_genus(N)`: 22/22 고전 표와 일치 (MF3 — 15 classical genus-0 + 7 boundary)
- `dim_cusp_forms(N,2)`: N=1..10 일치(전부 genus=0 우연), **N=11..30 중 20개 mismatch** (~67%)
  - N=11: hexa=0, 고전=1   ·   N=14: hexa=2, 고전=1   ·   N=20: hexa=4, 고전=1   ·   N=30: hexa=6, 고전=3

→ `dim_cusp_forms` 가 표준 dim S_2(Γ_0(N)) 를 직접 제공하지 않음 (다른 정의/관례 또는 버그).

- [ ] `dim_cusp_forms(N, k)` 의 실제 계산 정의 명세 확인 (소스: `compiler/atlas/atlas_cli.hexa` `_recompute2` 또는 `static_atlas` 내부)
- [ ] 표준 dim S_k(Γ_0(N)) 와 다르다면 fn 명/시그니처 분리(가령 `dim_cusp_forms_standard` vs 현행)
- [ ] 또는 dim S_k 표준 정의로 수정 (genus + boundary 식)
- [ ] 참고 verdicts: `.verdicts/tecs-l-modform-dim-genus/dim_vs_genus_sweep.txt` (30-N 전수 비교)
- [ ] cross-link: TECS-L MF4 (`TECS-L/docs/mf4-dim-genus-mismatch.md`) · g59 upstream

## 2026-05-25T09:40Z — hexa cloud vast provisioning 3 구체 버그픽스 (rent 빈-offer · cpu_ram 단위 · direct-IP ssh identity · d8)

demiurge RTSC Mg₂XH₆/LaBeH₈ vast 캠페인(2 agent 실증, pod 37753444)에서 발견한 hexa cloud vast 경로의 구체적 결함 3건 + 수정. lifecycle 부재(#989)·오라우팅(#967)·ssh-255(#976)와 별개의 actionable 1-라인급 픽스.

- [ ] **(1) `cloud_cli.hexa rent vast` 가 항상 빈 offer 반환** — `stdlib/cloud/vast.hexa:138 _vast_build_query` 가 `reliability2>=0.95` 를 prepend 하는데 현재 vastai 가 `reliability2` 를 미인식 필드로 거부 → offer set 빈값 → rent 무조건 실패(이게 "rent 안 됨"의 1차 원인, 에이전트들이 raw `vastai create` 로 폴백한 이유). **FIX: `reliability` (no trailing `2`)**.
- [ ] **(2) cpu_ram 필터 단위 = GB (MB 아님)** — vast offer query 의 `cpu_ram` 은 **GB** 단위. 64GB 노리며 `cpu_ram>=64000` (MB 가정) 주면 0 offer. `cpu_ram>=64` 가 정답. rent query 빌더/문서가 MB 로 넘기면 빈 결과. (실증: `vastai search offers 'cpu_cores>=24 cpu_ram>=64 dph<0.30 rentable=true'` 정상; `>=64000` 빈값.)
- [ ] **(3) direct-IP ssh identity 미제시 → `Permission denied (publickey)`** — cloud-guard 가 `.vast.ai` proxy 호스트를 raw-ssh 로 오탐(#967)해 우회로 **direct IP** 를 쓰면, raw IP 가 `~/.ssh/config` 에 Host 블록이 없어 vast identity 키를 안 내밀어 `hexa cloud run` 이 publickey 거부로 실패. **FIX: rent/adopt 시 IP:port → `IdentityFile ~/.ssh/id_vast*` Host 블록 자동 주입**, 또는 `hexa cloud run --insecure` 가 vast identity 를 명시적으로 `-i` 로 제시. (실증: labeh8-paw pod 37753444 가 Host 블록 추가 후 정상 구동 — 키 지문 일치 확인.)
- [ ] **종합** — hexa cloud 의 vast provisioning(rent/adopt/run)이 위 3개를 내장 처리하면 raw vastai/수동 ssh-config 0 → lifecycle PR #989 와 합쳐 진짜 single-surface 완결. (1)(2)는 `vast.hexa` query 빌더 즉시 수정 가능.

Status: open · proposed-by:agent · severity:high ((1)은 정식 rent 경로 전면 차단 · 1-라인 픽스) · source:demiurge RTSC vast 세션 (2 agent · pod 37753444 실증) · awaits:hexa-lang fix

## 2026-05-25 — cloud INBOX FULL CLOSURE: pool-route 0.6.10 ships both cross-repo items

직전 entry 들에서 pool-route 플러그인 소관으로 재분류했던 2건이 실제로 shipped. cloud INBOX open = 0.

- [x] **06:37Z pool-route `hexa cloud` 오라우팅 — SHIPPED in pool-route 0.6.10** (`dancinlab/sidecar` `be00745`). classifier 가 `hexa cloud *` 를 `toks` 인접쌍 + substring 으로 조기 `_allow()` → 항상 로컬. cloud 의 `--` 뒤 remote argv heavy-word(nvidia-smi·train.log·make) 이중 라우팅 차단.
- [x] **08:10Z(a) preflight worktree fallback — SHIPPED in pool-route 0.6.10** (`be00745`). 정확한 fix locus = `_pool_route.hexa` workdir 해소부: `/tmp/wt-x` git worktree 가 `cwd outside $HOME` 로 거부되던 것을 `git worktree list --porcelain`(main 첫 줄)로 canonical-root 얻어 mirror (기존 deny 브랜치 내부에서만 → 회귀 0). `hexa cloud preflight`(preflight.hexa)는 path 의존 0 이라 무관했음이 확정.
- 검증 4 케이스 PASS: `hexa cloud exec`→allow(local) · `hexa kick`→여전히 라우팅(회귀 없음) · 비-git `/tmp`→deny 유지 · `/tmp` worktree→`~/core/sidecar` rescue + ubu-2 라우팅. cache sync HEAD `be00745` (0.6.10).

## 2026-05-25 — cloud INBOX all-closure: reconcile vast GHOST FIX + preflight 재분류

직전 triage(아래)에서 남긴 진짜-open 2건을 닫음.

- [x] **06:37Z reconcile vast GHOST 오분류 — FIXED (이 PR)**. `pod_registry.hexa::cloud_reconcile_print` 가 `runpod_list_pods().pod_ids` 만 cross-ref → vast pod 전부 GHOST 였음. fix = `vast_list_instances().instance_ids` 와 union (provider-agnostic). **Falsifier (live vast 데이터)**: INBOX 가 지목한 인스턴스 `37618320`·`37619639` 가 fix 전 GHOST → fix 후 **OK** (둘 다 `cloud list` 의 live vast set 에 존재). 진짜-gone pod(`37610503` 등)는 양쪽 set 부재로 GHOST 유지 = 정상. `reconcile_test.hexa` 7/7 PASS (provider-union 멤버십 contract guard).
- [x] **08:10Z(a) preflight worktree-path fallback → SHIPPED pool-route 0.6.10** (`be00745` · 위 FULL CLOSURE entry). `hexa cloud preflight`(preflight.hexa `preflight_run`)는 `--params/--gpu/...` 에 대한 순수 closed-form GPU-mem 예산 계산 — workdir/path 의존 0. 실 fix = `_pool_route.hexa` workdir 해소부의 worktree→canonical-root fallback. routing 건(06:37Z)과 동일 소관.

## 2026-05-25 — cloud INBOX 코드-대조 정정 (resolved-flip + awaits-타겟 교정 · this-session triage)

아래 미해소 cloud 항목들을 origin/main(47f5191d) 코드와 대조 → 일부가 이미 landed인데 `open`으로 남아 있어 정정. 표기만 갱신(코드 변경 없음).

- [x] **09:30Z ssh exit-255 fast-fail — RESOLVED by #976** (`9e3426a7`). `cloud.hexa` `_ssh_capture_status` 가 로컬 ssh exit-code 를 반환 + `ConnectTimeout=8` → 도달불가 호스트가 ~8s 만에 exit-255 로 fast-fail + precise diagnostic. 제안(a) landed; (b) auto-down·(c) reachability-probe 는 잔존(별 entry 유지).
- [x] **07:35Z / 06:37Z provider-truth·lifecycle verb — PARTIALLY RESOLVED by #798** (`4706d857`). `cloud_cli.hexa` 에 `rent`/`up`/`down`/`destroy`/`list`/`status` lifecycle verb landed (L542·561·580·592). `list`/`status` 가 `vast_list_instances`/`runpod_list_pods` wire → provider-truth 조회 verb 존재. 잔존 = 제안(b) installed-binary 승격(sign-gate 우회 self-provisioning).
- [x] **06:37Z pool-route 오라우팅 → SHIPPED pool-route 0.6.10** (`be00745` · 위 FULL CLOSURE entry). classifier `_pool_route.hexa` 는 hexa-lang repo 가 아닌 `~/.claude/plugins/cache/sidecar/pool-route/` 에 있음. 제안(a) `hexa cloud *` 조기 `_allow()` 가 그 플러그인 0.6.10 으로 landed.
- [x] **잔존 2건 → CLOSED (위 all-closure entry 참조)** — (1) 06:37Z reconcile vast GHOST → `cloud_reconcile_print` 가 vast+runpod union 으로 FIXED (live 37618320/37619639 GHOST→OK). (2) 08:10Z(a) preflight worktree fallback → pool-route 플러그인 소관으로 재분류 (hexa cloud preflight 는 path 의존 0).

## 2026-05-25T07:35Z — hexa cloud lifecycle verb 부재 → raw vastai/runpodctl 직접 호출 강제 (orphan 양산 근원 · d8)

demiurge RTSC micro-exp/agent provisioning 중 반복 발견 — `hexa cloud` 엔 transport/transfer verb (run·exec·nohup·poll·copy-to/from) 만 있고 **pod lifecycle verb (rent·list/ps·down·destroy) 가 부재**. pod 생성/라이브조회/종료를 하려면 raw `vastai create`·`vastai show instances`·`vastai destroy`·`runpodctl pod list` 를 직접 호출할 수밖에 없음. 이게 cloud-guard(g8) "hexa cloud 로만" 정책의 구멍이자 orphan 양산의 구조적 근원. 사용자 요청: vast/runpod CLI·API 를 직접 안 쓰게 hexa cloud 가 lifecycle 까지 일급 흡수.

- [ ] **증상 — lifecycle 구멍** — `hexa cloud` (installed cycle-A binary) verb = run/exec/nohup/poll/copy-to/copy-from/orphans/reconcile/adopt/forget 뿐. `rent`·`list`·`down`·`destroy` 없음. cloud-guard 는 raw vastai/runpodctl 의 exec/ssh/transfer 만 차단하고 lifecycle(create/show/destroy)은 **명시적으로 허용** → provisioning 이 정식 경로가 없어 raw CLI 로 샘.
- [ ] **실증 (이번 세션 4건)** — (1) micro-exp + 2 agent 가 `hexa cloud rent` 부재로 `vastai create` 직접 사용. (2) `vastai destroy` 는 인터랙티브 `[y/N]` 확인 → 비대화형에서 `Aborted` → **pod 살아있는데 forget 돼 orphan 화 실제 발생** (printf 'y' 파이프로 수동 강제 종료). (3) 라이브/과금 조회는 `vastai show instances`·`runpodctl pod list` 직접 (provider-truth verb 부재). (4) `stdlib/cloud/cloud_cli.hexa rent` 경로는 `hexa run` 이라 **local sign-gate (user-only)** 필요 → 에이전트 자가 provisioning 불가 (deck-ready YSbH₆ 에이전트가 토큰 대기 중 정지).
- [ ] **부가 — provider-truth 조회 공백** — `hexa cloud list/ps` (vast/runpod 라이브 인스턴스 + 과금 직접 조회) 부재. `reconcile` 의 GHOST 오분류(#967 동봉)와 함께, 정상 점검에 raw `vastai show`/`runpodctl pod list` 강제.
- [ ] **제안 (a · 핵심)** — hexa cloud 에 **lifecycle verb 일급 추가**: `rent <provider> [--query ...] [--owner ...]` (tracked → pods.jsonl) · `list`/`ps` (provider-truth 라이브+과금) · `down <pod>` (**비대화형** destroy + forget 원자적, `[y/N]` 프롬프트 없음) · `destroy <pod>`. 이로써 raw vastai/runpodctl/API 호출 0 → cloud-guard 가 lifecycle 까지 차단 가능 (진짜 single-surface).
- [ ] **제안 (b)** — `cloud_cli.hexa` 의 `rent` 를 **installed binary (cycle-D lifecycle)** 로 승격 → `hexa run` (sign-gate) 불필요. 에이전트가 자가 provisioning 가능해짐.

Status: PARTIALLY-RESOLVED 2026-05-25 · rent/up/down/destroy/list/status lifecycle verb landed (#798 · 4706d857) · provider-truth list/status verb 존재 · 잔존:제안(b) installed-binary 승격(self-provisioning sign-gate 우회) · source:demiurge RTSC micro-exp/Mg₂XH₆ 세션

## 2026-05-25T06:37Z — pool-route 가 `hexa cloud` 를 ubu 로 오라우팅 (remote argv heavy-word 트립 · cloud verb 는 Mac-local-only · d8)

죽은-맥 복구 세션(demiurge RTSC)에서 발견 — `hexa cloud exec/run <pod>` 의 **remote argv** 에 heavy-word 가 들면 pool-route(0.6.9) classifier 가 전체 명령을 heavy 로 판정 → ubu-1/ubu-2 로 ssh 라우팅. 그러나 `hexa cloud` 는 Mac-local-only (로컬 hexa 빌드 + `stdlib/cloud/cloud_cli.hexa` 필요) → ubu 에서 `unknown subcommand 'cloud'`(ubu-2) / `source file not found: stdlib/cloud/cloud_cli.hexa`(ubu-1) 로 실패. 위 09:30Z exit-255 와 별개 — 이건 라우팅이 애초에 잘못된 호스트로 가는 문제.

- [ ] **증상** — `hexa cloud exec <pod> -- ... nvidia-smi ...` 또는 `... tail .../train.log` 가 비결정적으로 ubu 로 라우팅돼 실패. 같은 점검 작업이 어떤 땐 로컬(성공) 어떤 땐 ubu(실패) — round-robin + argv 내용 의존.
- [ ] **원인** — classifier(`bin/_pool_route.hexa`)가 `hexa cloud ... -- <remote-argv>` 의 **remote argv 까지** heavy-word 스캔. `nvidia-smi`·`train`·`make` 등(heavy_words L521)이 argv 에 있으면 트립. 특히 `train` 은 word-bounded 라 `train.log`(앞 `/`·뒤 `.` 경계) 가 매칭됨 (`train_cell_off.log` 은 뒤 `_` 가 word-char 라 비매칭 → 비결정성의 정체). `hexa cloud` 는 heavy_pairs 에 없어 자체로는 안 트립하지만 argv 우연 매칭으로 샘.
- [ ] **영향** — vast/runpod pod 점검·harvest·재시작이 비결정적 차단. 죽은-맥 복구 시 GPU util(nvidia-smi)·train.log tail 이 반복 실패 → 우회(heavy-word 제거)로만 진행 가능. `hexa cloud` 가 원격 dispatch 도구인데 pool-route 가 이중 라우팅하는 구조적 모순.
- [ ] **제안 (a · 선호)** — pool-route 가 `hexa cloud *` (cloud/exec/run/nohup/poll/copy-*/reconcile/orphans) 를 **local-bound 로 조기 `_allow()`** (git/gh L421 와 동일 패턴). 이미 원격 dispatch 도구라 이중 라우팅 불가능 → 결정적·단순. toks[0]=="hexa" && toks[1]=="cloud" 체크 1줄.
- [ ] **제안 (b · 대안)** — classifier 가 `--` delimiter 이후 remote argv 를 heavy-word 스캔에서 제외 (delimiter-aware). cloud 외 다른 wrapper 에도 일반 적용되나 (a) 보다 복잡.
- [ ] **부가 gap — `hexa cloud reconcile` GHOST 오분류** — vast 라이브 인스턴스(37618320·37619639)를 `vastai show instances` 로 RUNNING 확인했으나 reconcile 은 둘 다 GHOST(=provider 부재)로 표기. reconcile 의 vast provider cross-ref 가 실제 조회를 못 하는 정황. provider-truth inventory verb (`hexa cloud list`/`ps` — vast/runpod 라이브+과금 직접 조회) 부재로 raw curl 우회 시 cloud-guard 가 차단 → 정상 점검 경로 공백. provider-direct list verb 필요.

Status: open · proposed-by:agent · severity:medium-high (복구·점검 작업 비결정적 차단) · source:demiurge 죽은-맥 RTSC 복구 세션 · awaits:**pool-route 플러그인** fix (classifier 가 hexa-lang repo 아님 — ~/.claude/plugins/cache/sidecar/pool-route/) · 부가 provider-list verb 는 #798 로 해소 · reconcile vast GHOST 만 잔존

## 2026-05-25T09:30Z — hexa cloud vast ssh-transport exit-255 outage 감지/fail-fast 부재 (h3o SSCHA · d8)

h3o SSCHA agent 가 발견 — vast pod 37670312 (+ 다른 2 pod) 전부 `hexa cloud run/exec/scp` 시 `ssh exit 255`. 3 pod 동시 실패 = tool-wide vast.ai transport outage (pod-specific 아님). pod 는 alive+billing 인데 usable connection 0. `hexa cloud` 가 ssh-transport 실패를 감지/재시도/fail-fast 못 함 (d8 — Vast finding → INBOX).

- [ ] **증상** — `hexa cloud run/exec/scp <vast-pod>` 전부 `ssh exit 255` (transport 실패). 3 pod 동시 발생 = tool-wide vast.ai transport outage · pod-specific 아님. pod 는 alive+billing 인데 connection 0.
- [ ] **영향** — pod ~9.2h billing 中 usable connection 0 → ≈$2.76 낭비 + 작업 차단. SSCHA agent 가 vast 포기 → pool ubu-1 으로 pivot ($0 으로 완주).
- [ ] **제안** — (a) `hexa cloud` 가 ssh exit-255 (transport 실패) 를 감지 → fast-fail + "vast outage" 진단 메시지 (현재는 무한 시도/모호 실패). (b) optional auto-down on N consecutive 255 (billing 보호). (c) `hexa cloud list` 에 reachability probe (alive≠reachable 구분).

Status: RESOLVED 2026-05-25 · #976 (9e3426a7) — _ssh_capture_status 가 로컬 ssh exit-code 반환 + ConnectTimeout=8 → exit-255 transport outage 가 ~8s fast-fail + precise diagnostic. 제안(a) landed · 잔존:(b) auto-down·(c) reachability-probe · source:h3o SSCHA agent (demiurge PR #141 · afe7b61)

## 2026-05-25T08:45Z — stdlib primitive atlas register path gap (`--from-selftest` arm 부재 · NOVEL-TOOL 13 primitive 발견)

NOVEL-TOOL 13 stdlib primitive (wheeler·elliptic·gauss_legendre·welford·logsumexp·kahan·lambert_w·demag·halbach·mutual_M·loop_offaxis·ks2·endleakage) 가 self-test 13/13 PASS (sentinel + FALSIFIER, libm-class numerical match) 인데 **atlas DB 등록 0/13** — register 메커니즘 부재.

- [ ] **`hexa atlas register --from-selftest <file>` arm 신설** (선호 · d4 single-generic-dispatch 부합)
  - 현재 `register --from-verify <fn>` 는 `tool/verify_cli.hexa::_recompute_float`/`_is_float_fn` 의 hardcoded whitelist (~67 closed-form fn) 만 recompute. stdlib primitive 13개 전부 whitelist 밖 → `🟠 INSUFFICIENT · gap="add <fn> to verify_cli"`.
  - 실증: `register --from-verify lambert_w 1.0 0.567...` → `🟠 · reason="hexa verify --expr lambert_w has no calculator path"`. wheeler 동일.
  - `--from-verify`·`--from-drill` 어느 arm 도 stdlib self-test sentinel (`__HEXA_STDLIB_<PATH>__ PASS` + `N/N checks passed`) 을 register 근거로 못 씀.
  - 제안 (a · 선호): `--from-selftest <stdlib-file>` arm — sentinel PASS + FALSIFIER 통과를 🟢 SUPPORTED-NUMERICAL 근거로 atlas DB 등록 (generic dispatch, primitive-name 하드코딩 X · d4).
  - 제안 (b · 대안): 13 primitive 를 verify_cli whitelist 에 일괄 등록 (g20 — 단 per-instance 추가라 d4 위반 소지).
  - severity: medium (NOVEL-TOOL primitive 가 self-test 🟢 이지만 atlas 미흡수 — verify ledger 와 atlas DB 괴리).
  - 출처: NOVEL-TOOL atlas tier 승급 (demiurge PR #135 · exports/sweep/novel_tool_atlas_tier_2026-05-25.json).
  - Status: open · proposed-by:agent · awaits:hexa-lang fix
- [ ] **ACK + 재확인 (2026-05-25 g62 register-debt sweep)** — 위 13 primitive 전부 origin/main (77333409) 에서 register-attempt 재실증 → `atlas register --from-verify <fn> 2 2` 16/16 `🟠 INSUFFICIENT · "has no calculator path"`, atlas hash 불변 (`663698a0…`, 16088 nodes · 0 fold, g63 정직). 정확한 16-fn 목록: `lambda_anharm_suppress` · `stability_coupling_margin` · `wheeler` · `solenoid_endleakage` · `mutual_M_coaxial` · `current_loop_offaxis` · `demag_factor` · `halbach_envelope` · `elliptic_K` · `elliptic_E` · `lambert_w` · `logsumexp` · `kahan_sum` · `gauss_legendre` · `ks_two_sample` · `welford` (이 중 `elliptic` 은 K/E 2 fn). 전부 self-test 🟢 이나 calculator-path 부재로 `--from-verify` 불가 → `--from-selftest` arm (제안 a) 가 16 전부의 단일 해법.
- [ ] **NEW sub-gap: PR #954 pair 는 verify_cli 엔 있으나 atlas_cli 미러에 미동기 (atlas_cli↔verify_cli desync)** — `lambda_anharm_suppress` · `stability_coupling_margin` (PR #954) 는 `tool/verify_cli.hexa::_recompute_float` (L1218/1248 + dispatch L1864-1870) 에 추가됨. 그러나 `atlas register` 는 verify_cli 로 shell-out 하지 않고 `tool/atlas_cli.hexa` 의 자체 병렬 미러 `_recompute_float_register`/`_recompute2_register` 로 in-process recompute → 이 미러엔 두 fn 부재 → register 가 여전히 `🟠 · "add to verify_cli"` 오진. 즉 verify_cli 에만 추가해도 atlas register 는 막힘 (이전 ssh_winding/PR #592 "atlas_cli register table not synced" 와 동일 class). 제안 (a) `--from-selftest` arm 이 이 desync 도 우회 (atlas_cli 미러 의존 제거). 차선 (c): atlas_cli 미러를 verify_cli 단일 home 으로 통합 (d4/g20 — 2 미러 자체가 desync 근원).
  - 실증: origin/main 빌드 atlas-bin 으로 `register --from-verify lambda_anharm_suppress 2 2` → `🟠 · "has no calculator path"`. atlas_cli.hexa `_recompute_float_register` body grep `lambda_anharm_suppress|stability_coupling_margin` = 0 hit.
  - 출처: g62 RTSC+NOVEL-TOOL register-debt sweep (PR #954 priority pair).

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

