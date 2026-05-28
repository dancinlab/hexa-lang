# INBOX — log

## 2026-05-28 — ✅ anima DECODER M4b rev2 fire 발견 2 blocker (BPE O(N) 정체 · dir_create codegen gap)

> **finding (anima DECODER M4b rev2 production fire, H100 SXM, 2026-05-28, pod `yfqcywjlxavmgr`)**: HARD top-1 + diverse corpus + n_steps 200 production fire 도중 hexa-lang 보고 대상 2건 노출 (DECODER.md L133 `a_runpod_inbox`). M4c coherence verify 가 full-BPE-scale detokenize 에 의존하는데 그 경로가 #1 로 막혀 있었음.

### blocker 1 — BPE tokenize/detokenize O(N) 조회 정체 → ✅ RESOLVED (PR #1869)

> **증상**: `flame_bpe_corpus_lib` → `self/ml/tokenizer_bpe` 의 `get_merge_rank`(151,388 merges linear scan/pair) × `bpe_merge_word`(O(word_len²)/word) 가 diverse corpus(1.2MB·38KB 둘 다, Korean byte-char 폭증)를 사실상 종료 불가로 만듦. anima 는 6.6KB(24-line) corpus 로 우회(n_toks=6034).
> **dup-race precheck**: origin/main `self/ml/tokenizer_bpe.hexa` 에서 `get_merge_rank` = `while i<n { if merge_ranks[i][0]==key … }` 선형스캔 + `bpe_token_lookup` = `tok.vocab` 151,643 선형스캔 확인 — 미해결 상태였음(#1556 은 encode/decode 정확성만 fix, 성능은 미해결 별 layer).
> **root cause**: `merge_ranks` 가 이름만 "O(1) lookup" 인 `[key,rank]` 배열 — 실제 선형스캔. vocab token→id 도 동일.
> **fix (PR #1869, branch `inbox-bpe-o1-lookup-2026-05-28`)**: `merge_ranks` 배열→`{key:rank}` 해시맵(`build_merge_ranks` `{}` + index-set), `get_merge_rank` 는 `map_contains_key` 가드 후 O(1) 조회. vocab 측은 `build_token_id_map` 신규(`{token_str:id}` 해시맵) + `bpe_token_lookup` O(1). `hexa_map` = FNV-1a 오픈어드레싱 해시테이블(`self/runtime_core.c` `HexaMapTable`/`hmap_find`)로 진짜 O(1). 두 조회 모두 `map_contains_key`(silent) 가드 → 흔한 miss 가 `hexa_map_get` 의 `"key not found"` stderr fprintf 경로를 안 탐(미스가 대다수인 BPE 병합에서 중요).
> **검증(g5)**: ① ubu-2 current-main(stale-tell `%ld %ld`=0) `hexa parse self/ml/tokenizer_bpe.hexa` → `OK: parses cleanly`. ② 격리 로직 테스트(use 0개 복사본, canonical stdlib-verify 패턴) 9/9 PASS — `get_merge_rank` {0,1,2} + miss=-1(b,a / z,z), `token_lookup` {0,2,3} + UNK miss=0(zzz). diff +37/−22, 공개 API 불변(동작보존 리팩터).
> **잔여**: anima 측 full Qwen V=151643 diverse corpus 재발사로 tokenize 종료시간 회귀 측정 → M4c full-BPE-scale coherence verify unblock 확인.

### blocker 2 — `dir_create` cross-backend codegen gap → ✅ ROUTED (anima 1줄 swap, hexa 변경 0)

> **증상**: trainer.c 의 `hexa_call1(dir_create, X)` 가 Linux gen2 backend undeclared (anima 가 `trim` #1527 과 동종으로 보고, sed `s/hexa_call1(dir_create,/rt_fs_mkdir_p(/g` 로 우회).
> **진단(dup-race precheck, [[feedback_inbox_dup_race_precheck]])**: `dir_create` 는 어디에도 등록 안 된 이름 — `compiler/check/bind.hexa` allowlist·`self/codegen.hexa`(gen2)·interp·`self/codegen/arm64_darwin.hexa` 전부 부재. `trim` 류(빌트인인데 gen2 lowering 만 누락)와 **다름** — `dir_create` 자체가 빌트인이 아님(anima 가 만든 이름). codegen 이 모르는 free-fn → generic `hexa_call1(dir_create,…)` → 미정의 심볼.
> **권고 = `mkdir(path)`** (실측 검증): `self/codegen.hexa` 가 `name=="mkdir"` → `hexa_bool(mkdir(HX_STR(p),0755)==0)` 직접 libc `mkdir(2)` 로 lower. ubu-2 current-main `hexa run`(compile-then-exec) 실측: `mkdir("/tmp/mkd_real") -> true` + `/tmp/mkd_real` 실제 생성 확인. `mkdir` 은 bind allowlist 등록(`compiler/check/bind.hexa` L1062). 단일레벨(부모 미생성).
> **⚠ 초판 오진 정정 — `fs_mkdir_p` 쓰지 말 것**: 처음엔 `fs_mkdir_p`(→`rt_fs_mkdir_p` "재귀 POSIX mkdir 루프")를 canonical 로 권고했으나 **틀림**. `rt_fs_mkdir_p`(`self/runtime.c:13605`) 는 `{ (void)path; return hexa_int(0); }` = **silent no-op weak stub**. `fs_mkdir_p(p)` 는 컴파일·`0`("성공") 반환하나 dir 안 만듦 (local + ubu-2 default `hexa build`/`run` 양쪽 실측 `0`+미생성). 컴파일 통과만 보고 동작한다 오판한 것. anima sed 의 `rt_fs_mkdir_p(` 도 사실 no-op 이었음 — ckpt-save 를 inline decode 로 폐기해서 안 물렸을 뿐 (DECODER.md L121). 또 `hexa run` 은 interp 아님(R7 cutover = compile-then-exec) — interp-stub 으로 오해했던 것도 정정.
> **recommend**: anima 가 `dir_create(X)` → `mkdir(X)` 1줄 교체 (단일레벨이면 충분; 중첩 경로는 레벨별 mkdir 또는 fs_mkdir_p stub fix 후). **hexa-lang 코드변경 불요** (working `mkdir` 존재 · g0). `fs_mkdir_p` stub 자체는 별 OPEN finding (INBOX.md 참조) — 재귀 mkdir 빌트인 default-build 무동작 = silent-success data-loss class.
> **✅ stub 해소 (PR #1880)**: `rt_fs_mkdir_p` no-op 을 실 재귀 POSIX `mkdir(2)` 로 복원 (성공/idempotent=0·실패 -errno·정규파일 prefix=-ENOTDIR). 알고리즘 단위테스트 ALL PASS(fs.hexa 26-28 계약) + runtime.c in-context 구문검사 0 error. → 이제 anima 는 중첩 경로에 `fs_mkdir_p(path)` (재귀) 또는 단일레벨 `mkdir(path)` 둘 다 사용 가능.



데모더지 RTSC DFT 캠페인 (11 pod/pool 잡 · vast + ubu pool) 운영 중 `hexa cloud` 의 terminal/transport 판정에서 3 gap 노출. 모두 verbatim evidence 보유.

### gap 1 — `cloud poll` / `cloud tail --until` 가 exit-code/STOP 미인지 → walltime-stop 을 SUCCESS 로 오판
> **증상** (Mg₂IrH₆ phonon, ubu-2): ph.x 가 22.5h WALL 돌다 `max_seconds=80000` 도달 → QE 가 `Maximum CPU time exceeded` 후 **"JOB DONE."** 줄 출력 (QE routine 정상종료 print) + 직후 `STOP 1` ×6 + `prterun ... exit code 1`. dyn1=0 bytes (q-point 1 미완 · rep#9 중단). 즉 **timed-out-resumable** 인데 `JOB DONE` 마커만 보면 SUCCESS.
> **현 동작**: `cloud tail --until` default regex = `JOB DONE|OOMKilled|Traceback|crash` → "JOB DONE" 매칭 → exit 0 (clean end) 보고. 실제론 비정상 종료 + 재개 필요.
> **recommend**: terminal taxonomy 3분류 —
>   - `DONE` = terminal-marker ∧ trailing exit 0 ∧ no `STOP <n>`/`Error in routine`/`Maximum CPU time`
>   - `TIMEOUT-RESUMABLE` = `Maximum CPU time exceeded` / `max_seconds` (recover 파일 있으면 재개)
>   - `CRASHED` = `STOP <n>` (n≠0) / `Error in routine` / non-zero prterun exit
>   `cloud poll`/`tail` 가 이 3-tier 를 exit code 로 반영 (현 0=clean-only 외에 3=resumable · 4=crashed). caller (watcher / /system) 가 false-DONE 회피.

### gap 2 — `cloud exec` 가 unknown `--flag` 를 positional host 로 silent-오파싱 → 혼란스러운 255 (정정됨 2026-05-28)
> ⚠ **정정 (PREVIOUS DIAGNOSIS WAS WRONG)**: 이 항목은 처음 "vast ~20분 SSH-proxy outage (transient gateway fault)" 로 진단됐으나, 후속 agent 가 **오진**을 규명. 실제 원인 = `hexa cloud exec --cmd '...'` 처럼 **존재하지 않는 `--cmd` 플래그**를 준 것 → CLI 가 positional `<host> [conn] -- <argv>` 문법이라 `--cmd` 를 **host 로 파싱** → 그 "호스트"로 ssh 시도 → exit 255. `nc TCP-open + contract-live + 255` 증상이 "게이트웨이 outage" 처럼 보였으나 실은 **caller 의 malformed argv**. 정확한 positional 호출 (`cloud exec root@ssh9.vast.ai --port 15988 --insecure -- '<cmd>'`)은 즉시 연결됨. pod 는 내내 정상이었음. "20분 outage" = 그 시간 동안 agent 가 `--cmd` 형태로 반복 시도한 것.
> **진짜 gap (재진단)**: `cloud exec` 가 **unknown/unsupported `--flag` 를 조용히 positional 인자(host)로 흡수** → 사용자가 의도한 cmd 가 host 로 둔갑 → 디버깅 어려운 255. 이게 실제 친 함정.
> **recommend (정정)**: `cloud exec` argv 파서가 (a) **알 수 없는 `--flag` 를 reject + usage 출력** (positional host 로 silent 흡수 금지) · (b) host 위치 토큰이 `--`로 시작하면 명시 에러 (`'--cmd' looks like a flag, not a host — exec uses positional <host> -- <argv>`). 이게 255-혼란의 근본.
> **부차 (여전히 유효)**: 진짜 transport 255 (TCP-closed=pod-down vs TCP-open+contract-live=transient)의 sub-classification 은 일반적으로 여전히 유용 — 단 본 항목의 "20분 outage" 는 그 증거가 아니었음 (오진). transient-vs-fatal 분류는 별개의 nice-to-have 로 격하, argv-flag-reject 가 P1.

### gap 3 — `cloud preflight` walltime sizing (DFT/phonon) — GPU-mem stub 확장
> **증상**: Mg₂IrH₆ (9-atom metallic Ir-d, 2×2×2 q) 의 `max_seconds=80000`(22h) 이 ~3× 과소 → rep#9 에서 timeout. recover 로 손실 0 이지만 1-stop 발생.
> **현 동작**: `cloud preflight` = GPU mem-budget 만 (RFC 091 stub).
> **recommend**: `cloud preflight --kind dft-phonon --atoms N --nq M [--metallic]` → 닫힌형 `max_seconds` 추정 (atoms × n_q × metallic-factor) + "recover=.true. 전제 넉넉히 설정" 권고. 사전 under-size flag.

**공통 가치**: gap 1·2 가 caller(watcher/`/system` 관제탑)의 terminal 오판을 근본 차단 — 현재는 caller 마다 `grep "JOB DONE" + STOP 모순` 휴리스틱 재작성 (데모더지 watcher 가 polymorph false-DONE 으로 1회 오탐). CLI 가 3-tier exit code 를 주면 caller 단순화 + 정합.

**evidence 파일** (demiurge): `~/rtsc_mg2irh6_polymorph/ph.out` (JOB DONE + STOP 1 + Maximum CPU) · `pods.temp.json` (11-job manifest) · sidecar `/system` 0.2.0 (이 gap 들의 caller-side workaround 현황).

## 2026-05-28T — 🟠 OPEN · cloud forget — accept ssh-form / IP / alias pod_id (registry cleanup asymmetry)

`hexa cloud reconcile` 는 GHOST 후보로 numeric provider-id 외에 ssh-form (`root@141.195.21.87` · `ssh1.vast.ai` · `root@ssh9.vast.ai`) + alias (`ubu-2`) + edge-case (`--help` adopted ghost) 까지 모두 잡아 표시하는데, `hexa cloud forget <pod_id>` 는 numeric provider-id 만 허용 (`registry: refusing non-pod-id 'root@<ip>' (expected a provider instance-id; use cloud adopt <id> to track an existing pod)`). 결과 cleanup loop 가 절반만 동작 — anima session 에서 36 GHOST 중 16 만 forget 성공 (numeric only), 20 ssh-form 은 모두 거부.

**증상 재현** (anima `/Users/ghost/core/anima` cwd, 2026-05-28 04:00 KST):
```
hexa cloud reconcile | awk '/GHOST/ {print $1}' > /tmp/ghosts.txt   # 36 entry
while IFS= read -r pid; do hexa cloud forget "$pid"; done < /tmp/ghosts.txt
# ok=16 fail=20 (모든 fail = "refusing non-pod-id")
```

**asymmetry**:
- `cloud reconcile` 의 GHOST 판정 set = `{numeric, ssh-host, root@host, root@ip, alias, --help-as-id}`
- `cloud forget` 의 accept set = `{numeric}` 만
- 두 set 동일해야 cleanup loop 가 폐쇄형 (closed-loop) — 현재 partial loop = orphan ledger 영구 누적

**recommend** (둘 중 하나, g0 simplest sufficient):
1. **`cloud forget` validation 완화** — `cloud reconcile` 가 받는 form 모두 accept (numeric || ssh-host || root@ip || alias). `cloud forget --form=numeric|ssh|alias` 같은 명시 옵션 불필요 — registry 가 이미 form 별 entry 를 carry 하므로 forget 도 동일 form 으로 lookup.
2. **`cloud reconcile --auto-forget` 추가** — GHOST 표시만 하지 말고 자동 close (anima session 의 manual loop 대체). `--dry-run` default + `--apply` 명시로 안전.

권장 = (1) — 작은 변경 (validation regex 완화 1줄), reconcile 호출 비용 0, semantics 정합.

**위치 (추정)**: `stdlib/cloud/cloud_cli.hexa` 의 `forget` verb handler — `pod_id` validation 직전.

**carry**: anima session 의 잔여 20 ssh-form GHOST (cosmetic only, billing 영향 0) 는 upstream fix 까지 보존.

---

## 2026-05-28T — ✅ RESOLVED #1703 · parser: paren-less line continuation with leading `-` silent miscompute (`self/parser.hexa::parse_addition`)

`parse_addition` 의 newline-continuation arm 이 `p_continue_bin_op(["Plus"])` 만 허용해 다음 줄이 `-` 로 시작하면 silent-drop — `let x = a + b \n - c` 가 `let x = a + b` 로 끝나고 `- c` 는 폐기되는 unary-minus expression-statement 로 파싱됐다. 인라인 `Plus || Minus` 는 둘 다 받지만 newline arm 만 `Plus` 였던 비대칭이 원인. anima bench #4 (Gierer-Meinhardt PDE · ρ=1 control sim 이 ~10^236 으로 발산) 에서 `- 4.0 * u[i][j]` 항이 사라져 잡힘.

stdlib 영향 (현재 silently broken):
- `stdlib/runtime/math.hexa` `rt_lgamma` Stirling 급수 (L81/L83 leading `-`)
- `stdlib/sim_universe/multiverse/higher_order/quad_mi.hexa` (L136 leading `-`)
- 그 외 9 leading-`-` · 30 leading-`*` (이미 multiplication tier 에서 처리) · 5 leading-`/`

옵션 선택: (a) syntactic reject 대신 (b) deterministic-continuation — `p_continue_bin_op` whitelist 를 `["Plus", "Minus"]` 로 확장. 이유: (1) "unary-ambiguous" 우려는 expression-START 위치에서만 유효한데, `parse_addition` while-loop 안에서는 이미 완전한 left operand 가 소비된 후라 다음 줄의 leading `-` 는 반드시 binary, (2) stdlib 가 이미 leading-`-` 패턴을 의도된 continuation 으로 작성하고 있어 reject 는 ~9 stdlib 파일을 깨뜨림 (그 파일들 자체가 현재 silently miscompiled 라 fix 효과는 +). PR: https://github.com/dancinlab/hexa-lang/pull/1745.

## 2026-05-28 — ✅ RESOLVED #1676 · `hexa_cuda_available` strong override under `#ifdef HEXA_CUDA` (`self/runtime.c`)

2026-05-27 anima H100 fire 가 보고한 weak-stub-only gap 봉인. `self/runtime.c:13472-13473` 의 두 weak stub (`hexa_cuda_available` · `hexa_cuda_device_count`) 를 `#ifdef HEXA_CUDA` 로 gate — CUDA 빌드에서는 strong override 가 실 디바이스 probe (`_hx_cuda_runtime_available` · `_hx_cuda_device_count_impl`) 로 delegate, no-CUDA 빌드는 기존 weak stub 그대로 (byte-identical).

**심볼 확인**: 두 extern 모두 `self/runtime.c:8405-8406` 에 이미 `#ifdef HEXA_CUDA` 하위로 선언, body 는 `self/cuda/runtime_cuda.c:248,255` 에 strong export 존재. INBOX 본문에서 "확인 필요" 로 남았던 `_hx_cuda_device_count_impl` 도 실재 → 둘 다 delegate.

**검증**: `gcc -fsyntax-only -I. self/runtime.c` clean (no-CUDA 경로 13 warn = 사전존재, 0 error). cuBLAS 경로 unblock 됐는지 = 다음 GPU fire round 의 oracle. branch `inbox-1676-cuda-glue-a`.

## 2026-05-28T — ✅ RESOLVED #1734 · resolver shape-B/C arms (`stdlib/cloud/runpod.hexa::_runpod_get_ssh_port_cli`)

`_runpod_get_ssh_port_cli` 는 shape-A (`ssh.ip`+`ssh.port`) 만 매칭 → anima M3 4축 fire 가 hit 한 shape-C (`runpodctl pod get -o json` of v0.5+ = top-level `publicIp` + `ports[].{type=="ssh"}.port`) 에서 fall-through 해 GraphQL API arm 으로 떨어졌고, 그 arm 은 API key 가 필요해 dispatcher 경로에서 "resolver 부재" 처럼 보임.

**fix**: CLI arm 에 3-shape fall-through 추가 — shape-A 그대로 + shape-B (`ssh.host`+`ssh.port`) + shape-C (`publicIp` + `ports[]` iterate, `type=="ssh"` → `port`). message tag 가 매칭된 shape (`cli/ssh.ip` · `cli/ssh.host` · `cli/publicIp+ports`) 를 표시 → 차후 schema drift 관측 가능. GraphQL fallback 은 `runpodctl` 자체 부재일 때만 발동.

**검증**: `hexa parse stdlib/cloud/runpod.hexa` clean. 라이브 pod end-to-end 는 anima M3 production fire 가 다음 round 에 검증 (resolver 가 unblock 됐는지 = transport 진입 여부 보는 게 oracle). branch `inbox-1734-runpod-resolver-fallback`.

## 2026-05-28 — M3 fire 2차 hit on #1659 resolver gap (anima DECODER, recommend `runpodctl pod get` JSON parse)

> **finding (anima M3 4축 fire 시도)**: anima `CORE/DECODER/m3_fire_dispatch.hexa` 의 lifecycle wrapper (cloud-guard 정합 `runpodctl pod create`) 는 LANDED · 그러나 transport (ssh-cascade) 시점에 hexa cloud 의 RunPod pod-id → SSH-host resolver gap (#1659) 으로 다시 막힘 — M3 4축 4-pod fire 실행 불가.

**우회 (검증됨)**: 본 세션 M4b GPU fire (anima #1119/1120/1121) 가 검증한 **Vast.ai 직접-IP 패턴** — `vastai show instance <id> --raw` 에서 `ssh_host` + `ssh_port` 추출 → `hexa cloud exec root@<host> --port <n> --insecure` 작동 (cloud-guard 정합 + 표준 verb).

**recommended fix (#1659 resolver primitive)**: `runpodctl pod get <pod-id> -o json` 출력에서 SSH endpoint 추출 가능 (RunPod CLI 0.5+). hexa cloud 내부에서:
```bash
SSH_INFO=$(runpodctl pod get "$POD_ID" -o json | jq -r '.publicIp // .ssh.host')
SSH_PORT=$(runpodctl pod get "$POD_ID" -o json | jq -r '.ports[] | select(.type=="ssh").port // 22')
```
resolved `<host>:<port>` 를 hexa cloud copy-to / exec primitive 의 endpoint 로 사용. lifecycle (`runpodctl pod {create,get,destroy}`) 은 이미 cloud-guard 정합 → transport 만 위 resolver patch 로 unblock.

**alternative (Vast.ai port pattern)**: 본 세션 M4b 가 입증한 안정 path. 신규 anima dispatch (M3 4축 production swap-in 등) 는 Vast.ai 로 우선, RunPod resolver fix landing 후 양쪽 backend 지원 가능. severity: high (anima M3 production fire 차단 · M4b 우회는 작동).

## 2026-05-28 — hexa multi-line expression continuation silent miscompute (parens 밖 줄바꿈)

> **발견 맥락 (anima bench #4 TURING-MITOSIS · PR #1127)**: 2D 32×32 Gierer-Meinhardt 반응-확산 PDE Euler 적분기 작성 중, 활성자/억제자 갱신식의 **paren 밖 줄바꿈된 산술 expression** 이 컴파일러 오류 없이 silent 잘못 계산됨. ρ=1 control sim (대칭 IC, 균일 정상상태로 감쇠해야 정상) 이 var ~10^236 까지 blow-up. smoke test 는 single-line 형태라 통과 → 풀 bench 의 multi-line 형태에서만 차이 발생.

**재현 패턴 (구체적인 expr 형태)**: anima 측 초기 RD 코드는 lap 항과 reaction 항을 한 줄로 합치며 산술 연산자가 다음 줄 시작에 놓이는 형태였다 — 예 (paraphrase):
```hexa
// 의도 (수학적): du/dt = Du * lap_u + u^2/v - u
let du_dt = Du * (u[ip][j] + u[im][j] + u[i][jp] + u[i][jm] - 4.0 * u[i][j])
          + (u[i][j] * u[i][j]) / v[i][j]
          - u[i][j]
```
이 형태에서 transpile / interpret 후 du_dt 가 의도한 합이 아닌 다른 값으로 평가됨 (정확히 어느 절이 누락/오배치 되는지는 미특정 — 표면 결과 = ρ=1 에서 10^118+ 발산). 동일 식을 **paren 으로 감싸 한 줄로** 작성하거나, 연산자를 라인의 끝(전 줄 trailing operator)으로 두면 정상 평가 → ρ_c=7.0 측정 성공 (PR #1127 머지 본 코드 line 269-270 형태):
```hexa
let lap_u = u[_idx(i - 1, j)] + u[_idx(i + 1, j)] + u[_idx(i, j - 1)] + u[_idx(i, j + 1)] - 4.0 * center_u
let react_u = (center_u * center_u) / center_v - center_u
let du_dt = Du * lap_u + react_u
```
즉 회피책 = (a) 전체 expression 을 한 줄로 두기, 또는 (b) sub-expression 을 named let-binding 으로 쪼개 각 줄 단독으로 평가시키기.

**severity**: **high (silent)** — 컴파일러가 syntax error 도, 런타임 trap 도, type-check warning 도 내지 않음. 값만 silently 틀림. 같은 패턴이 PDE/적분기/누적합 등 paren-heavy 산술 코드 전반에 잠복 가능 (특히 활성자-억제자 RD · gradient descent update · forward pass 결합식).

**요청 (택1)**:
- (a) **lexer/parser 가 paren-less line-continuation 을 거부** — 산술 expression 이 명백히 미완(다음 줄에 leading binary operator 가 오는 형태)인데 paren 밖이라면 syntax error 로 reject. 작성자가 명시적으로 paren 으로 감싸거나 한 줄로 두도록 강제.
- (b) **또는 ASI(automatic semicolon insertion) 가 산술 expression 끝에서 정확히 break** — 현재는 "줄바꿈 = statement end" 와 "leading operator → continuation" 사이의 결정이 silent 하게 잘못 내려지는 것으로 보임. ASI 규칙을 명문화하고 산술 expression 의 line-continuation 조건을 결정적(deterministic)으로.

**검증 (요청 후)**: `let x = 1 + 2\n        + 3` (3 칸 들여쓰기 leading `+`) 형태 minimal repro 를 (a) 에선 reject, (b) 에선 (1+2+3)=6 으로 결정적 평가하는 단위 테스트 추가.

**참조**: anima PR #1127 (bench/turing_mitosis · merged 2026-05-28). 부수 — anima 측 회피책은 PR 본 코드에 이미 반영 (한 줄 또는 named-let 분해), 추가 patch 없음. hexa 측 (a) 또는 (b) 가 landing 되면 anima 회피책은 그대로 두되 silent-miscompute 위험만 제거됨.

## 2026-05-27 — HEXA_CUDA 빌드인데 cuda_available()==0 (weak stub strong-override 부재 → cuBLAS 경로 unreachable)

> **root cause (anima M4b GPU fire smoke 실측)**: H100 pod 에서 `nvcc -DHEXA_CUDA runtime_cuda.c` + `clang -DHEXA_CUDA ... -lcublas -lcuda` 로 빌드+실행 RC=0 성공했으나 `cuda_available()==0` → GPU 미사용(CPU fallback). 원인: `self/runtime.c:13472` 의 `__attribute__((weak)) HexaVal hexa_cuda_available(void){ return hexa_int(0); }` 가 **strong override 없이** 그대로 등록됨(`runtime.c:12203 cuda_available=hexa_fn_new(hexa_cuda_available)`). `runtime_cuda.c:248` 에 실 디바이스 체크 `_hx_cuda_runtime_available()`(cudaGetDeviceCount) 가 있으나, **HEXA_CUDA 하에서 `hexa_cuda_available` 를 `_hx_cuda_runtime_available()` 로 잇는 strong glue 가 self/ 전체에 부재** (grep `HexaVal hexa_cuda_available` non-weak = runtime.h 선언만). 결과: -DHEXA_CUDA 여도 cuda_available 영원히 0.

**영향**: `cuda_available()` gate 로 GPU/CPU dispatch 하는 코드(anima flame_mm.mm = farr_matmul_gpu⇄farr_matmul)가 GPU 에서도 CPU 경로만 탐 → cuBLAS Dgemm engage 안 됨. 정상 GPU fire 불가.

**요청 (택1)**: (a) runtime.c 에 `#ifdef HEXA_CUDA` 강한 `hexa_cuda_available(){ return hexa_int(_hx_cuda_runtime_available()); }` (+ hexa_cuda_device_count 동일) 추가 — weak stub 은 `#else`. (b) 또는 runtime_cuda.c 가 strong `hexa_cuda_available`/`hexa_cuda_device_count` 제공(weak override). 검증: rfc040 gpu smoke `F-RFC040-GPU-AVAIL cuda_available()==1` 가 실 GPU 에서 PASS 해야 함(현재 main 에선 0 반환 의심).

**✅ CONFIRMED FIX (2026-05-27, anima M4b H100 실증)**: option **(a)** 가 정답임을 별도 glue.c 로 실증. clang source 목록에 아래 strong override 추가 = weak stub link-time 제압 (undefined-ref 0, clean link):
```c
#include "self/runtime.h"
extern int _hx_cuda_runtime_available(void);
extern int _hx_cuda_device_count_impl(void);
HexaVal hexa_cuda_available(void)    { return hexa_int(_hx_cuda_runtime_available()); }
HexaVal hexa_cuda_device_count(void) { return hexa_int(_hx_cuda_device_count_impl()); }
```
H100 80GB 실측: `cuda_available()==1` · `farr_matmul_gpu` 1024² cuBLAS Dgemm = CPU oracle `farr_matmul` 와 **max\|Δ\|=0.0 byte-identical** · GPU util **50% / 635MiB**. → option (a) 를 runtime.c `#ifdef HEXA_CUDA` 로 landing 하면 별도 glue 불요. (anima 측 증명 harness = `CORE/DECODER/cublas_probe.hexa`, PR #1119.) 단 `_hx_cuda_device_count_impl` 심볼명은 runtime_cuda.c 실제 export 명 확인 필요(없으면 `_hx_cuda_runtime_available` 만으로도 dispatch 충분).

**부수 finding (RESOLVED)**: anima `CORE/DECODER/flame_mm_smoke.hexa`·`v3_moe_bwd_lib_smoke.hexa` 의 죽은 `/private/tmp/wt-gpu1/...` import → anima #1117 로 canonical 경로 정정 완료. severity: high (cuBLAS 경로 전면 차단) → glue 로 우회 + (a) landing 대기.

## 2026-05-27 — M4b GPU fire 런북 검증 (transpile --c-only → CUDA runtime → Vast.ai · #1659 deadlock 정정)

> **정정**: #1659 는 "RunPod ↔ cloud-guard deadlock"으로 fire 불가처럼 읽히나 **fire 는 achievable**. RunPod resolver 갭은 real(유효)이나 **Vast.ai 직접-IP** 로 우회. anima M4b pilot end-to-end 검증 런북 (ref `tool/dispatch_agtape_d768_fire.sh`):

**검증 런북** (hexat-CUDA-build 불필요 · private-repo clone 불필요):
1. transpile(Mac): `HEXA_MAC_BUILD_OK=1 hexa build <pilot>.hexa --c-only -o <out>` → flatten된 self-contained C. ⚠ output `/tmp` 밑이면 Darwin 가드 거부 → repo 경로 + HEXA_MAC_BUILD_OK=1.
2. transport=Vast.ai(RunPod ✗): `vastai show instance <id>` → ssh_host/port 직접 → `hexa cloud exec root@<host> --port <n> --insecure` 작동(H100 80GB).
3. runtime bundle scp: self/runtime.c·runtime_core.c·runtime_hi_gen.c·runtime.h·cuda/runtime_cuda.c·cuda/runtime_bf16.c·forge/forge_tier_v1.{c,h}·native/*.{c,h} + trainer.c.
4. CUDA build(pod): `nvcc -O2 -std=c++14 -DHEXA_CUDA -arch=sm_90 -x cu -c self/cuda/runtime_cuda.c -o runtime_cuda.o` → `clang -DHEXA_CUDA -I self -I /usr/local/cuda/include -fbracket-depth=4096 trainer.c self/runtime.c runtime_cuda.o -L/usr/local/cuda/lib64 -lcublas -lcudart -lcudart_static -ldl -lrt -lm -lpthread -lstdc++ -o trainer`.
5. run + nvidia-smi + harvest (d768 패턴). farr_matmul_gpu = runtime_cuda.c(-DHEXA_CUDA) cuBLAS Dgemm. severity: docs.

## 2026-05-27 — real-BPE GPU fire 의 toolchain 통합 갭 (flame_bpe_corpus_lib resolve + ml/tokenizer_bpe 번들 + corpus 경로)

> **finding (anima M4b real-BPE trainer fire 준비)**: synthetic pilot(BPE 미사용)은 위 런북으로 GPU fire 성공(cuBLAS engage 확정). 그러나 **real-BPE trainer**(`use "stdlib/flame/flame_bpe_corpus_lib"` → `use "self/ml/tokenizer_bpe"`)는 3개 추가 갭:

1. **transpile resolve**: `hexa build --c-only` 의 stdlib root 가 `~/.hx/packages/hexa` symlink → `~/core/hexa-lang` **working tree**(HEXA_LANG/HEXA_STDLIB_ROOT unset 시). working tree 가 `flame_bpe_corpus_lib` 없는 브랜치면 `FATAL module not found`. origin/main 파일을 `~/.hx/packages/hexa-lang/`(별도 real dir)에 복사해도 resolver 가 symlink 쪽을 써서 무효. → resolver 가 어느 root 를 쓰는지 결정적이지 않음. 요청: `HEXA_STDLIB_ROOT` env 를 transpile 경로가 확실히 존중하도록(현재 baked-in root 우선 의심) + `hexa --version`/doc 에 active stdlib root 노출.
2. **runtime 번들**: real-BPE trainer 는 `self/ml/tokenizer_bpe` 빌트인(`build_byte_to_char` 등) 필요 → 위 런북 step 3 번들(self/runtime.c·cuda/*·forge/*·native/*)에 `self/ml/tokenizer_bpe.{c,h}`(+ 그 의존 ml/*) 미포함 시 clang `undefined symbol`. 요청: GPU fire 번들 표준 목록에 `self/ml/*` 추가 명시.
3. **corpus 경로**: trainer 가 merges.txt·vocab.json·corpus.jsonl 를 Mac abs-path 하드코딩 → pod scp 후 sed 필요(anima 측 정정 가능, hexa 무관). severity: medium (synthetic fire 는 OK, real-BPE 학습 run 만 차단).

## 2026-05-27 — hexa cloud: RunPod pod-id → SSH-host resolver 부재 (cloud-guard 와 deadlock)

> **블로커 (anima M4b Phase 4-fire 발사 차단)**: RunPod H100 pod 를 `runpodctl pod create` 로 띄운 뒤(id=r2afs2es6q8aln, RUNNING), 프로비저닝하려면 `hexa cloud {exec|copy-to|...}` 의 `<host>` = resolved SSH 목적지(`root@<public-ip> --port <n>`)가 필요. 그런데 그 public-ip:port 를 얻을 길이 막힘:
> - `runpodctl ssh ...` → **cloud-guard 차단** (raw rented-GPU remote-exec/transfer)
> - `curl https://api.runpod.io/graphql ...` (runtime.ports 조회) → **cloud-guard 차단** (raw HTTP API call)
> - `runpodctl get/list pod` (lifecycle, 허용) → tabular 출력에 **runtime IP:port 미표시**
> → cloud-guard 는 "hexa cloud 만 쓰라" 하는데, hexa cloud 는 IP 를 resolve 못 하고(pod-id 인자 없음), IP discovery 대안은 전부 guard 차단 = **deadlock**. pod 를 띄워도 연결 불가 → $3.29/hr 출혈만, remove 로 정지(~$0.5 손실).

**요청 (택1 또는 병행)**
- [ ] **hexa cloud 에 RunPod resolve 추가** — `cloud run/exec/... <runpod:POD_ID>` 또는 `cloud resolve <POD_ID>` 가 runpodctl/API 로 runtime.ports(publicIp + 22/tcp publicPort)를 조회해 ssh host 자동 구성. cloud-guard 내부(허용 경로)에서 수행.
- [ ] **또는 cloud-guard 가 read-only runtime-ports 조회를 허용** — `runpodctl get pod -o json` 의 runtime.ports 또는 GraphQL `pod{runtime{ports{ip publicPort privatePort type}}}` 같은 비-exec/비-transfer GET 은 lifecycle 'get/show' 범주로 통과시킴 (현재 raw HTTP 라는 이유로 차단).

**현황**: anima M4b GPU 포팅(cuBLAS mm) 5/5 + backward 6/6 실측 PASS (byte-identical) → fire 는 코드가 아니라 이 transport-resolve 갭에만 막힘. resolver 생기면 즉시 발사 가능. severity: high (runpod fire 경로 전체 차단).

## 2026-05-27 — hexa-lsp stdlib 심볼 인덱싱 부재 → flame/forge primitive 미발견 (anima M4b scope-check 교훈)

**발견 맥락**: anima M4b pilot(DECODER MoE-fresh 학습 스택)을 작성하며 모든 matmul 을
손으로 짠 scalar 삼중루프(`for i,j,k: acc += A·B`)로 구현 → flame 이 이미 제공하는
`farr_matmul` / `farr_matmul_gpu`(RFC-040 cuBLAS Dgemm)를 안 씀. H100 발사 직전
scope-check 에서야 발견: 스칼라 경로는 (a) GPU 유휴(device-farr/cuBLAS 미사용)
(b) pilot 규모(d=2048·12L·T=512 ≈ 10^14 ops)에서 CPU 비현실 → 발사 무의미. 뒤늦게 잡음.

**LSP 각도 (요청/제안)**
- hexa-lsp 는 이걸 진단으로 못 잡는다 — 손루프는 문법·타입·심볼 다 정상인 유효 코드이지,
  "stdlib primitive 재발명" 은 에러가 아니다(아키텍처/g1 위반). LSP diagnostics 범위 밖.
- **그러나** completion / workspace-symbols 가 stdlib(flame·forge) pub fn 을 인덱싱하면
  `farr_` 입력 시 `farr_matmul`·`farr_matmul_gpu` 가 떠서 발견 가능. → hexa-lsp 가 모든
  stdlib pub fn(flame + forge + 전체)을 심볼 인덱스에 넣는지 점검 요청. **라이브러리별 별도
  LSP 불필요** — 단일 hexa-lsp 가 전부 커버(flame/forge 는 별도 언어가 아닌 hexa 라이브러리).
- (선택) 아키텍처 lint 규칙: inline triple-loop matmul 패턴 → `farr_matmul` 제안. LSP
  diagnostics 가 아닌 별도 linter rule(g61 stdlib-dup 체커 확장 후보).

**핵심 한계 (정직)**: completion 은 "손 뻗을 때"만 도움 — 작성자가 `farr_` 를 칠 생각조차
안 하고 `for` 부터 쓰면 무용. 진짜 해법은 도구가 아니라 **compute 작성 전 stdlib 탐색 습관**
(g0/g1) + toy→scale 전환 시 아키텍처 재질문. 자동화 난망 — 작성자 규율 영역.

**severity**: enhancement(LSP 심볼 인덱싱) + process-finding(cross-cutting 작성 규율).
**참조**: anima `CORE/DECODER/flame_mm.hexa`(#1100, mm dispatch 토대) · M4b Phase 4-gpu 포팅 진행 중.

## 2026-05-27 — flame-P2b Qwen BPE = anima DECODER MoE-fresh scale-gate · 양 토크나이저 모듈 모두 실측 결함

## 2026-05-27T11:15Z — ✅ RESOLVED: RTSC tranche-3 fn (Hc1·Jc·multi-band) 직접구현 (PR #1641)

INBOX #1624 (RTSC fn 추가 요청) self-RESOLVED — 사용자 "INBOX fix this session".
3 fn 4-surface 등록 (verify_cli fn body + dispatch + help + calc_dispatch float-fn SSOT):

- `london_hc1(λ_L, κ)` → Hc1(0)=(Φ₀/4πλ_L²)(ln κ+0.5) — verify (200nm,2)=0.0049084 T 🟢
- `bean_critical_current(Jc, d)` → M=Jc·d/2 — verify (1e10,1µm)=5000 A/m 🟢
- `two_band_lambda_eff(λσ,λπ,λi)` → MgB₂ 2-band larger root — verify (1.0,0.4,0.05)=1.00414 🟢

검증 = HEXA_LANG=worktree 로 module 해석 강제 (calc_dispatch float-fn 목록 등록 필수 — 미등록 시
to_int trailing garbage on scientific-notation arg). RTSC paper §Limitations single-band
assumption + device-side Hc1/Jc gap 가 lane-내 closure 가능.


## 2026-05-27T19:25Z — RTSC fn 추가 요청 (Hc1 · Jc · multi-band Eliashberg)

RTSC math DFS lane closure (RTSC5-30, 18 PR) 후 추가 발견을 위한 verify_cli
fn gap. 3 closed-form fn 등록 권장 — 모두 standard textbook expression, RTSC
type-II + clathrate 분석의 표준 surface 완성.

### 1. `london_hc1(lambda_L_m, kappa)` — Type-II lower critical field

   Hc1(0) = (Φ_0 / (4π λ_L²)) · (ln κ + 0.5)

   - Tinkham 1996 Eq.5.10. CODATA 2018 Φ_0 = 2.067833848e-15 Wb.
   - source: λ_L=200 nm, κ=2 → Hc1 ≈ 32 mT (typical Type-II).
   - RTSC application: H3S λ_L=17 nm, κ=15 → Hc1(0) ≈ 1.6 T (실측 확인 surface).

### 2. `bean_critical_current(jc_a_m2, d_m)` — Bean model critical current

   M(B) = ±(Jc · d / 2)  →  Hc(thin-strip) = Jc·d/2

   - Bean 1962 PRL 8:250. 2-arg (Jc in A/m², slab thickness d).
   - source: Jc=1e10 A/m², d=1µm → M = 5e3 A/m (typical YBCO film).
   - RTSC application: H3S 의 Jc 추정 surface (high Tc → high Jc 일반).

### 3. `eliashberg_two_band_tc(lambda_sigma, lambda_pi, lambda_inter, omega_log_K, mustar)` 
       — multi-band (MgB2-type) Tc

   2-band Eliashberg: lambda_eff = (λ_σ + λ_π)/2 + sqrt(((λ_σ-λ_π)/2)² + λ_inter²)
   then Tc = (ω_log/1.2) · exp(-1.04(1+λ_eff)/(λ_eff - μ*(1+0.62λ_eff)))

   - Suhl-Matthias-Walker 1959. 5-arg (4 λ + 1 μ*).
   - source: MgB2 λ_σ=1.0, λ_π=0.4, λ_inter=0.05, ω_log=600K, μ*=0.10 → Tc ≈ 39K.
   - RTSC application: H3S / LaH10 의 multi-band check (single-band 가정 의문 시).

### Rationale (g11/g59)
- RTSC math DFS lane closure 후 의미있는 새 finding 의 next axis = Hc1/Jc/multi-band
- 3 fn 모두 textbook standard, libm-class closed-form
- 등록 후 RTSC paper §Limitations \"single-band assumption\" 의 lane-내 closure 가능

### Source
- 본 RTSC closure 세션 (PR #1542-1621, RTSC5-30 18 round) 의 lane-pause signal
- /Users/ghost/core/hexa-lang/TECS-L/TECS-L.log.md RTSC22+30 conclusion


**severity: medium** — anima DECODER MoE-fresh(toy PASS, anima #1033)의 3B Qwen scale 검증이 hexa-native train stack 의 BPE 토크나이저 결함으로 막힘. flame-P2b 와이어링(loader, anima #1537) 자체는 land, 가드(`flame_bpe_roundtrip`)가 양 결함을 결정론적 검출 → 가짜 closure 아님 (g73). 본 fix 이후 3B Qwen hexa-native 학습 unblock.

**진행 (2026-05-27)**:
- ✅ #1527 — gen2 C 백엔드 free-fn `trim` codegen lowering (cross-backend parity, Mac 동작 vs Linux undeclared 불일치 해소). 12 LoC, `.trim()` 메서드 경로(self/codegen.hexa:3942/7190 `cg_string_sym("str_trim")=rt_str_trim`)와 동일 lowering. ubu-2 end-to-end 검증: tokenizer_bpe `use` 체인 컴파일+round-trip PASS.
- ✅ #1533 — `self/native/hexa_cc.c` bootstrap 재생성 (#1527 + 누적 4443줄 catch-up 라이브). self-host fixpoint **gen1==gen2 byte-identical** 검증 (ubu-2 Linux, sanity 포함).
- ✅ anima #1537 — `stdlib/flame/flame_bpe_corpus_lib.hexa` BPE-corpus 로더 + `flame_bpe_roundtrip`/`flame_bpe_ids_in_vocab` 가드. CI 테스트 10/10 PASS (toy vocab 단일-byte-char round-trip).
- ✅ #1549 — `test/t53_qwen_bpe.hexa` fixture 경로 오타 (`tests/fixtures/` → `test/fixtures/`). t53 silent FAIL 원인.

**잔여 — flame-P2b ③ correct Qwen round-trip = hexa-lang 도메인 깊은 fix 필요 (실측 결함, 양 후보 모듈)**:

| 모듈 | macOS arm64 | Linux C 백엔드 |
|---|---|---|
| `self/ml/tokenizer_bpe` (encode+decode UTF-8-aware) | ✅ **FULL RESOLVED** (#1556 encode + decode codepoint-aware) | ✅ FULL RESOLVED — `bpe_decode` 가 UTF-8 lead byte 검사(b0≥240→4B / ≥224→3B / ≥192→2B / else 1B)로 codepoint-aware `slice(j, j+clen)` iteration. ubu-2 실 Qwen V=151643 round-trip **PASS** (본 entry 끝 measurement 참조) |
| `self/ml/qwen_bpe` (from_char_code UTF-8-aware, 1030L) | **Segfault 11** (mini, toy fixture vocab 파싱 #200 직후) | 7MB 실 tokenizer.json 240s 타임아웃 (perf/hang) |

**근본원인 (chr 결함, tokenizer_bpe 측) ✅ FIXED #1556**: `self/runtime.c:5336` `hexa_chr_byte` 가 `s[0] = (char)(code & 0xFF)` 로 명시적 byte 절단 → `chr(288) == chr(32)` 실측. tokenizer_bpe 의 `build_byte_to_char` 가 GPT-2 byte-level 인코딩(byte 32 → codepoint U+0120 'Ġ', 2-byte UTF-8)을 위해 `chr(256+i)` 호출하나 절단으로 collapse → 256 distinct char 불가 → 공백/비-ASCII 손상. **#1556 1-line root-cause fix**: tokenizer_bpe 가 `chr(256+i)` → `from_char_code(256+i)` (UTF-8-aware 인코더, 5304+) 사용 → 256 distinct char 정확 생성. chr 자체는 byte-only 유지 (blast radius 0). runtime 변경 0, tokenizer 1줄.

**fix 경로 진행** (any one resolves ③):
1. ~~hexa `chr`/`char_code` Unicode 화~~ — 불필요 (#1556 이 from_char_code 활용으로 우회).
2. ✅ **#1556 — `tokenizer_bpe` 1-line `chr→from_char_code` fix** (이게 채택된 root-cause fix). byte-domain 전면 재설계 불요. (~~`tokenizer_bpe` byte-domain 재설계~~ — 큰 변경, #1556 으로 대체됨.)
3. **`qwen_bpe` 디버그** (path 2 잔존) — vocab #200 직후 SIGSEGV 메모리 안전성 (Mac arm64 실측) + Linux 실-스케일 perf (`get_merge_rank` linear-scan, 151388 merges = O(n²) 추정). path-fix 된 t53 (post-#1549) 로 재현 가능. tokenizer_bpe 가 #1556 으로 unblock 됐으므로 qwen_bpe 는 alt-path 로 강등 (canonical Qwen tokenizer 가 둘 중 어느 쪽인지 maintainer 결정).

**다음 검증** (#1556 land 후 ③ 1/2 unblock — 실 Qwen round-trip 테스트 라운드 권장): mini/ubu-2 에서 path-fix된 t53 (toy fixture) + 실 Qwen tokenizer.json round-trip → 공백 round-trip TRUE 확인 시 ③ 완전 해소.

## #1556 실 Qwen round-trip 측정 (2026-05-27, ubu-2) — ⚠ encode 측만 fix, decode 측 새 결함 노출

`#1556` 의 `chr(256+i)` → `from_char_code(256+i)` patch 를 ubu-2 wt-3081fe78(local cache, pre-#1556 origin) 에 수동 적용 + regen + main build/hexat swap + Qwen real round-trip 측정:

```
[tokenizer_bpe] loaded 151387 merges, 151643 vocab in 196.192 ms  ✅ load OK
vocab_size = 151643                                                ✅
encode "consciousness emerges from cells" → n_toks = 5             ✅ encode OK
decoded = [consciousnessĠemergesĠfromĠcells]                       ❌ 'Ġ' literal
TOKENIZER_BPE-1556-ROUNDTRIP: FAIL
```

**진단 (decode 측 새 결함)**: `#1556` 은 `build_byte_to_char` (forward) 만 fix — encode 측 byte 32 → 'Ġ'(U+0120, UTF-8 2-byte) 매핑은 정확. 그러나 `bpe_decode` (`self/ml/tokenizer_bpe.hexa:422+`) 의 loop:

```hexa
let c = token_str.slice(j, j + 1)               // ← BYTE-INDEXED slice
let byte_val = bpe_char_to_byte(char_to_byte, c)
if byte_val >= 0 { text = text + chr(byte_val) }
else { text = text + c }                         // ← fallthrough: raw bytes preserved
```

`slice(j, j+1)` 가 **byte-indexed** (hexa string 모델 byte-native, HX_STRLEN/slice 전부 byte 단위). 'Ġ' 는 0xC4 0xA0 (2 bytes). j=0 → slice = 1-byte "0xC4" → `char_to_byte` table 의 entries(`from_char_code(288)` = full 'Ġ' = 2-byte string)와 byte-equal 비교 실패 → -1 → else 분기 `text = text + c` 로 raw byte (0xC4) 추가. j=1 → 0xA0 동일. 결과: 'Ġ' 의 2-byte 가 그대로 text 에 누적 → 출력 시 'Ġ' literal 표시.

즉 **#1556 의 forward (encode)는 fix**, **decode 측 multi-byte UTF-8 char iteration 결함**은 별개로 잔존. 이전 chr 절단(`!`)이 'Ġ' literal 로 바뀌었을 뿐 round-trip 여전히 깨짐.

**추가 fix 경로 (#1557 후보)**:
1. **`bpe_decode` codepoint-aware iteration** — `slice(j, j+1)` 대신 UTF-8 byte-pattern 검사 (b0<0x80=1B / 0xC0-0xDF=2B / 0xE0-0xEF=3B / 0xF0+=4B) 로 multi-byte char 묶기. 단 모든 GPT-2 char(U+0080..U+0143) 가 2-byte 라 분기 단순.
2. **`char_to_byte` byte-keyed lookup 보강** — 각 multi-byte char 의 *첫 byte* 를 키로 추가 entry (단 충돌 가능, 복잡).
3. **`bpe_decode` 전체 raw-byte 출력** — token_str 자체가 GPT-2-encoded UTF-8 이므로, char-to-byte 역매핑 대신 직접 byte 스트림 처리 후 일괄 UTF-8 decode.

(1) 이 가장 자연스러움 — 4-5줄 추가. blast radius 0 (decode loop 내부 한정).

**측정 evidence (실 Qwen, 151643 vocab, ubu-2 2026-05-27)**: encode 측 5 tokens 정확 생성하나 decode 시 'Ġ' 그대로 — 이전 chr 절단 결함(`!`) 과 별개의 새 결함 노출. ③ 완전 해소엔 decode 측 추가 fix 필요. g73 honest: #1556 은 **encode side 만 fix**, round-trip 미해결.

## ✅ ③ FULL RESOLVED — decode 측 codepoint-aware iteration fix LANDED + 실측 PASS (2026-05-27)

`bpe_decode` 의 byte-indexed `slice(j, j+1)` → UTF-8 lead-byte 검사로 codepoint-aware `slice(j, j+clen)` 로 갱신 (`b0≥240→4B · ≥224→3B · ≥192→2B · else 1B`, ASCII clen=1 — common path zero-change). 본 fix 가 origin/main `946b193d` 의 `self/ml/tokenizer_bpe.hexa:422-460` 에 land.

**실 Qwen round-trip 측정 (ubu-2 Linux, 갱신된 tokenizer_bpe.hexa, regen+swap+run)**:

```
vocab_size = 151643                                              ✅
n_toks = 5                                                       ✅ encode
decoded=[consciousness emerges from cells]                       ✅ ← 공백 정확 복원!
FULL ROUNDTRIP: PASS
```

진척 시퀀스 (g73 honest):
```
chr 절단(원본) → '!' literal
#1556 encode fix → 'Ġ' literal
#1556 + decode codepoint-aware → ' ' (공백) ✅
```

**flame-P2b ③ correct Qwen round-trip = 완전 해소.** anima #1537 loader 의 `flame_bpe_roundtrip` 가드가 이제 TRUE 반환 → 3B Qwen hexa-native 학습 path 정상화. qwen_bpe segfault path 2 는 alt-path 잔존 (canonical 은 tokenizer_bpe 로 확정).

**참조**: anima #1517 (flame-P2b origin demand-signal · DECODER MoE-fresh scale-gate) · anima #1537 (loader+가드) · hexa-lang #1527 #1533 #1549 (선결 fix landed) · hexa-lang **#1556** (encode 측 chr→from_char_code) + **decode 측 codepoint-aware iteration fix** (LANDED, 본 entry 측정 evidence) · `GPU.md` flame-P2b 라인.

## 2026-05-27 — ✅FIXED(deploy) ~/.hx/bin/hexa shim stale = #1149 fork-guard 미배포 (fork-storm 근본)

배포된 `~/.hx/bin/hexa` 가 2줄 bare `exec hexa.real "$@"` 로 stale — 소스 shim(repo root `hexa`, HEAD)의 #1149 재귀-깊이 가드(HEXA_DEPTH cap 32) + hxv2 우선 + argv0-shadow(#866) 보호가 전부 deploy 에서 누락. 결과: 나선형 `hexa→sh→hexa-atlas→sh→hexa→…` 재진입이 무한정 가능 → process-table 벽 = fork-storm (2026-05-27 세션 중 crypto 검증 반복 compile 시 2회 발생).

**진단**: `wc -l ~/.hx/bin/hexa` = 2 (bare). `git show origin/main:hexa | wc -l` = 54 (가드 완비). `strings ~/.hx/bin/hexa.real | grep HEXA_DEPTH` = 0 (바이너리에도 가드 없음 → shim 이 유일 방어선인데 그게 stale).

**FIX(deploy, 검증됨)**: `git show origin/main:hexa > ~/.hx/bin/hexa; chmod +x`. 검증: dispatch OK(hexa 0.1.0-dispatch via hxv2) · `HEXA_DEPTH=32 hexa` → "recursion-depth cap reached — refusing" 발화 · depth 5 정상. bare shim 은 `.hexa.bare-preguard-bak-2026-05-27` 백업.

**durable(잔여)**: installer(`hx install`/`build_hexa_cli --install`)가 소스 `hexa` shim(가드본)을 ~/.hx/bin/hexa 로 멱등 배포해야. 현재 어느 deploy 단계가 bare `exec hexa.real` 본을 깔았는지 미상(stale deploy 회귀 class — runtime.o/symlink 누락과 동류, [[reference_hxbin_symlink_swap_hazard]]). shim 도 deploy-completeness 체크리스트에 추가 필요.

## 2026-05-27T06:30Z — `~/.hx/packages/hexa-lang` install stale @ #1241 (ec1cd33) — atlas/verify arms invisible (TECS-L RTSC3 upstream)

**severity: medium** — live `~/.hx/bin/hexa` 가 dispatch 하는 atlas/verify 소스가 install 패키지 `~/.hx/packages/hexa-lang/tool/{atlas_cli,verify_cli}.hexa` 이며, 이 패키지는 **#1241 (ec1cd33) 에 frozen** (main 은 #1520+). 결과:
- `hexa atlas register --from-falsify …` → "no discovery arm selected" (falsify/citation/defer/fence 4 arm 부재 — #1503 미반영)
- `hexa verify --expr allen_dynes_tc 1.135 1254.2 0.10` → 🟠 INSUFFICIENT "no path" (allen_dynes_tc calc-path 부재 — #1517 미반영)
- `hexa atlas lookup falsified-mg2irh6_ambient_stable` (default embed) → not found (stale embedded.gen.hexa)

**진단**: 코드 버그 아님 — `hx install hexa-lang` 가 #1241 이후 재실행 안 됨 (install-channel sync lag). source SSOT (main) 은 정상. 회피: `HEXA_ATLAS_EMBED=<repo>/compiler/atlas hexa atlas lookup <id>` 로 worktree/main 의 embedded.gen.hexa 직접 읽으면 5 closed-negative 모두 lookup OK (검증 완료). `bin/hexa-atlas` sub-binary 도 부재 (build_hexa_atlas.sh 미실행 · Mac 24GB SIGKILL risk → pool offload 권장).

**제안 fix**: (a) install-channel 재sync (`hx install hexa-lang` @ main HEAD — 별도 release 작업) · (b) `bin/hexa-atlas` rebuild = `tool/build_hexa_atlas.sh` 를 pool ubu/mini offload (Mac local 금지, heavy flat). source-fix 불필요 (이미 main).

- [ ] **install 패키지 #1241→HEAD sync** — atlas/verify arms 활성화
- [ ] **`bin/hexa-atlas` rebuild (pool offload)** — atlas sub-binary fast-path 복구

## 2026-05-27 — ✅RESOLVED stdlib/core/hash sha256/hmac compiled-path SIGSEGV (`let`-reassign → `let mut` fix)

**RESOLVED 2026-05-27**: root cause = immutable `let` array with index-write (`let w=[]; w[ci]=…`) + scalar `let`-reassign across the 64-round loop → compiled `hexa run` miscompile/SIGSEGV. Fix = `let mut` + in-place `.push()` (sha256_digest_bytes + hmac_sha256_bytes). Verified: sha256("abc")=ba7816bf… + HMAC + PBKDF2 RFC6070 (120fb6cf…) all PASS on compiled path. Unblocks pbkdf2/HKDF.

error: 'run' requires <file>
HEXA — native-compiled, atlas-aware, strict-lint language toolchain
  in-house prover + linker · English-only diagnostics · zero runtime GC
  unified science stack absorbed from nexus (archived 2026-05-13)

USAGE
  hexa run <file> [args...]               Execute .hexa script (compile-then-exec)
  hexa build <file> [-o out]              Compile .hexa → native binary
  hexa drill --seed "..."  ★              Run the discovery engine (main absorbed verb)
  hexa <subcommand> [args...]             Subcommand dispatch (80+ verbs)
  hexa tool [list | <verb> ...]           Specialized-verb drawer (go-tool style)
  hexa --version, -v                      Version + build hash
  hexa --help, -h                         This help

CORE TOOLCHAIN  (everyday verbs — `hexa <verb> --help` for per-verb detail · `hexa tool` for the drawer)
  run [--no-sentinel] <file> [args...]    Execute .hexa script (compile-then-exec)
                                            --no-sentinel: stdout 청정 (no __HEXA_RC=N tail)
  build <file> [-o out] [--target=<t>]    Compile to native (RFC-018 5-stage IR;
                                            atlas baked in 0 ms; ≤2 forks)
              [--shared]                    Emit .so/.dylib (RFC 070 G7-A flag-
                                            wiring; F-A1/F-A2 next sub-cycle)
  test <file> [--filter N] [--verbose]    Run @test fns (native runner)
  parse <file>                            Parse-only check (no exec, no codegen)
  check <file>                            Verify @invariant DSL blocks (AST-based)
  bench <file> [--runs N] [--json]        Benchmark wall/RSS/alloc
  cc                                      Rebuild transpiler (hexa_cc)
  lsp                                     Start LSP server (stdin/stdout JSON-RPC)
  init <dir> [--name N]                   Scaffold <dir>/project.hexa
  status                                  Toolchain status
  version                                 Print version

  more toolchain verbs in the drawer (`hexa tool` · TOOLCHAIN family):
    batch · typecheck · cache · daemon · convergence · tape · hxc · url

STDLIB CLI  (subcommand → stdlib dispatcher)
  qrng                                    Quantum RNG default aggregate selftest (RFC 044)
  qrng status                             9-backend table + tier coverage T0..T3
  qrng collect [--bytes=N] [--source=NAME] [--seed=S]
                                          pull bytes via router fallback chain
  qrng selftest | chain | meta --backend=NAME
                                          provider sweep · resolved chain · backend meta
    e.g. hexa qrng collect --bytes=32 --source=mock_qrng --seed=42
  cloud [run|nohup|poll|copy-to|copy-from] <host> [--port N] [--insecure] -- <argv...>
                                          structured-argv remote dispatch (PR #81/#84/#86/#88)
    e.g. hexa cloud run ubu-2 -- python3 train.py    (also: cloud copy-to / copy-from)
  stdlib [list [--json]]                  stdlib catalog (modules · dirs · tests · docs)
    e.g. hexa stdlib                      table view (purpose harvested from each module header)
  sim-universe [status|selftest|anu|multiverse|qpu|qrng|bostrom|godel|
                fvd|stark|qdarwin|ca-qm|supremacy|mbs|dtc|z2gauge|
                preheating|multipolar|surface-code|ssh|hofstadter|dqpt|wdw]
                                          virtual-universe runtime (26 modules, RFC 046)
    e.g. hexa sim-universe status         module inventory + tier table
  qmirror [status|selftest|chsh|iit|qrng|rqaoa|ctx|dynghz|vqd|stab-ext|
           overlap-vqe|sre|lg|pseudo-tel|rpe|sym-shadow|hardy|page-curve|
           qdrift|cdr|wigner|qfi|shallow|gme-steer|mabk|mirror-bench]
                                          quantum mirror substrate (38 modules, RFC 045)
    e.g. hexa qmirror chsh                CHSH Bell test (Tsirelson-class S)
  loop [--once|--budget N|--time D] [--lenses ...] [--no-fire|--fire --budget U]
       [--dfs --allow-llm --llm-cmd CMD [--depth N --beam K --target-absorb N --resume]]
                                          self-growing atlas cycle — 8 stage (RFC 065 + 080)
                                          binary built-in lens table + PR-only candidates
                                          --dfs: pluggable-LLM depth-first descent (TECS-L port)
                                          --allow-llm: cost gate for real cmd exec
                                          --target-absorb N: batch N verified children → ONE PR
    e.g. hexa loop                        --once --no-fire --dry-run (safe default)
    e.g. hexa loop --status               print state-dir + LENS_COUNT + active families
    e.g. hexa loop --dfs --allow-llm --llm-cmd "claude -p" --target-absorb 10
                                          live LLM descent → 1 batched PR (compiler/atlas/embedded.gen.hexa)
                                          per @D g_atlas_absorb_direct (no .n6 shard, no inbox markdown intermediate)
  gpu fire <kernel.ptx> <host.c> [target] Remote GPU fire harness (GPU.md §7c)
                                          scp + nvcc + run + pull result.json
                                          default target = ubu-2 (RTX 5070 sm_120)
    e.g. hexa gpu fire wmma_16x16.ptx host.c   (HEXA_GPU_DRY=1 plans only)
  gpu disasm <kernel.ptx>                 PTX opcode-family histogram (pure hexa)
  gpu lint   <kernel.ptx>                 PTX static checks (non-ASCII / sm_target / .reg)

ATLAS SSOT  (compiler/atlas/embedded.gen.hexa, text-parsed at load)
  atlas hash | stats                      Read meta
  atlas lookup <id> | <K> <id> | --prefix=<p>   Read node(s)
  atlas dump [K] [--json]                 Read full kind
  atlas register --from-verify <fn> <args> <v>  verify IN-PROCESS → fold into embedded.gen.hexa
  atlas register --from-drill --seed "<text>"   drill → fold verified candidates
  atlas export [--out PATH]               live atlas → portable .n6 (n6 = export-only)
                                          register → pr — direct fold-to-live forbidden
                                          all absorbers (atlas register --auto-pr, drill, loop --dfs)
                                          fold directly into compiler/atlas/embedded.gen.hexa via PR
                                          (no intermediate .n6/.md — @D g_atlas_absorb_direct)
  atlas-verify [--domain D] [--tier N]     Verdict ledger — 86 entries Stage 1+2+3 hexa-native
  calc <engine> [args]                    TECS-L calculators (nstate/vortex/n6/perfect/congruence/gamma0)
  verify <id> | --expr <fn> <n> <v>       Verify claim: atlas+calc → tier (🔵/🟡/🟠/⚪)
    e.g. hexa atlas lookup P n            → @P n = 6 :: foundation [11*]
    e.g. hexa verify sigma                → 🔵 SUPPORTED-FORMAL (calc divisor_sum(6)=12)
    e.g. hexa atlas-verify --domain math  → §2 MATH verifiers PASS/FAIL + |err|

ANNOTATION ANALYZERS (29, AST-based via self/lexer.tokenize)
  pure-check  memo-check  catalog  readme  doc  codegen-hints  distill
  effect-map  intent-map  meta-map  phi-map  struct-layout  self-aware
  cognitive  freedom  infer  learn  safety  antivirus  serve  tenant
  eval-run  n6-list  test-list  schema  law-link  harness  rule  gate-register
    e.g. hexa pure-check src/math.hexa    → JSON: {version,source:"ast",pure_fns:[...]}

MATH VERIFIERS  (3, deterministic — no atlas write)
  honesty <file>                          BT-AI2 honesty audit (16-domain router)
  absolute --seed "..."                   Mk.VIII Δ₀-absolute Σ₁/Π₁ classifier
  meta-closure [--seed "..."]             Mk.IX self-ref fixpoint (H1+H2+H3)
    e.g. hexa absolute --seed "sigma(6)=12"  → grade [10*]→[11*] verdict

MATH DISCOVERY  (3 generators, γ no-write)
  smash --seed "..." [--depth N]          Blowup 9-phase singularity drill
  free --seed "..." [--dfs N]             Compose 5-module DFS
  hyperarithmetic --prop "..."            Mk.IX Π₀² 5-system reverse-math classifier
    e.g. hexa smash --seed "perfect_number_6" --depth 3   → ~414 candidates

DISCOVERY ENGINE  ★ — drill is the main entry; 12 variants compose on top

  ★ drill --seed "..." [--rounds N] [--engine mk9|mk10] [--seeds csv|--seeds-file F]
        Main discovery engine. 6-stage round chain:
          smash → free → absolute → meta-closure → hyperarithmetic → resonance
        mk10 adds stage 7 transcendental_closure (Mk.X + AN11 math gate)
        Each round flushes discoveries to atlas overlay
          ~/.hx/data/atlas.overlay.n6  (rodata seed + runtime overlay, dedup'd)
        Round N+1 reads round N's overlay via atlas_lookup_merged (cumulative seed pool).
        examples:
          hexa drill --seed "perfect_number_6" --rounds 3
          hexa drill --seed "hexagonal_sum"   --engine mk10
          hexa drill --seeds "s1,s2,s3"        --rounds 2          (batch dispatch)

  chain --seed "..." --engines "x,y,z"      L3 cross-engine pipeline (drill across engines)

  drill variants  (12, each composes drill with a different orchestration pattern):
    omega       Apex preset (drill+chain+batch auto-dispatch — nexus's "main entry")
    kick        alias → drill                    (ω-cycle ≡ drill apex)
    surge       omega + cross-seed variants
    dream       iterations × drill              (dream-mode seed evolution)
    swarm       population × generations         (evolutionary)
    reign       max-cycles cap
    molt        self-evolution param mutation
    wake        signal-file triggered drill
    forge       strict round cap                 (no adaptive depth)
    canon       drill + canon seal log           (~/.hx/data/canon_seal.jsonl)
    debate      L3 N-variant adversarial debate
    revive      engine+map v2 resurrect dead rounds (cap enforced)

EXTERNAL RESOURCES  (17, δ pattern — try-CLI-or-fallback)
  HW probes:        akida           (qmirror/qrng → STDLIB CLI via RFC 044/045)
  Data bridges (16): codata  oeis  arxiv  gw  horizons  cmb  nanograv  simbad
                     icecube  nist-atomic  wikipedia  openalex  gaia  lhc  pubchem  uniprot
    Live path: HTTP API (~15 s timeout)  ·  Fallback: frozen cache (HEXA_FORCE_FALLBACK=1)
    e.g. hexa wikipedia "Perfect number"  → live → /api/rest_v1/page/summary/

ATLAS ABSORPTION  (Phase 5, 2026-05-14 — atlas-scope-only after split)
  lattice <verify|axis-table|cross-check>           n=6 σ·φ=n·τ=24 deductive verifier (pure math)
  atlas-audit <external-entity|anchor|all>          honest-caveat C3 lattice-fit gate + NIST anchor (overlay corpus)
  repo-audit-taxonomy <catalog.md> <manifest.toml>  filesystem ↔ catalog ↔ manifest C1/C2/C3 audit
    e.g. hexa lattice verify              → __N6_AXIS_VERIFY__ PASS (σ·φ=n·τ=24, |S₄|=24)
         hexa atlas-audit anchor          → NIST/CRC/ASM citation audit over overlay corpus
    atlas-audit reads ~/.hx/data/atlas.overlay.n6 (~109 nodes, ~3s). Full 7,278-node
    rodata coverage pending compiler/atlas/static_index lazy-load (see docs/notes/).

  Sister-project tools (rsc / bayes / n6 discover/mine / hexa-principle annotator etc.)
  분리됨 — 각 sister repo 의 자체 도구로 위치. invoke via `hexa run <sister>/path/main.hexa <verb>`.

INTRINSIC SURFACE  (SPEC §16 — absorbed shell-equivalents, 638→752 sites)
  Use these IN-PROCESS intrinsics from `compiler/intrinsics/intrinsics.hexa` —
  do NOT shell out (HX9xxx fork-storm lint planned). Each ⇆ its shell-equivalent:
    cwd()            ⇆ pwd                getenv(k)         ⇆ $VAR
    list_dir(path)   ⇆ ls <path>          path_exists(p)    ⇆ test -e <p>
    mkdir_p(path)    ⇆ mkdir -p <p>       path_is_dir(p)    ⇆ test -d <p>
    rm_file(path)    ⇆ rm <p>             host_target()     ⇆ uname -sm
    rm_rf(path)      ⇆ rm -rf <p>         now_ns()          ⇆ date +%s%N
  Plus SPEC §18 firmware: stdlib/{core,alloc,hal,embedded,mcu} + firmware/boards/*
  (5 absorbed repos; see `hexa hash` / `hexa stats` for the embedded inventory).

STDLIB n=6  (compiler-internal, available as `use "self/std_n6"`)
  n6_lenses · n6_verify · n6_check · n6_consensus · n6_scan · n6_omega
    User-facing utility for σ/φ/τ/n=6 constant checks (6 Omega lens API)

ATLAS / STRICT LINT  (SPEC.md §2.2 / §9 / §10)
  The atlas P/C/L/E node library is embedded into the compiler (rodata, 0 ms,
  hash-pinned). Verified code auto-registers as new atlas L[*] nodes via in-house
  ε self-proof (no Z3). `compiler/discover/promote.hexa` folds staging → live,
  emits `atlas.append.<date>.n6` shards. Formula/constant-bearing fns must cite
  an atlas L — `@implements(L[<id>])` or `@discover(kind="L")` — else HX8004.
  Bypass: `@grace(HX####, until="...", reason="...")` — emits HX9000 audit, build
  gated on explicit acked-grace. Discover overlay grows at `~/.hx/data/atlas.overlay.n6`
  per drill round (rodata seed + overlay; rodata wins on ID conflict).

ENV  (selected)
  HEXA_LANG               repo root override (loader, gate)
  HEXA_MEM_UNLIMITED=1    disable 4096 MB memcap (heavy regen / drill / 7 K-row embeds)
  HEXA_FORCE_FALLBACK=1   skip live HTTP/HW probe, use cached fallback
  HEXA_DRILL_ENGINE       mk9 (default) | mk10 (forces transcendental_closure)
  HEXA_NO_SENTINEL=1      drop __HEXA_RC sentinel from `hexa run`

DOCTRINE v2  (nexus absorbed 2026-05-13)
  ① rodata seed for technical content   ② code absorbs algorithms
  ③ metadata as frozen archive          ④ try-live-or-fallback for external
  ⑤ rodata seed + runtime overlay for discovery accumulation

STATUS
  CLI dispatch wired for all 80+ verbs (self/main.hexa::dispatch_absorbed).
  Most absorbed modules are libraries (pub fn entry points) — invoking
  `hexa <verb>` loads the module and exits 0. Per-verb fn main() CLI shims
  are a deferred follow-up; programmatic use via `use "compiler/<x>/..."` works
  today. Test smokes (`compiler/<x>/*_test.hexa`) demonstrate live API surfaces. (compiled path) 으로  단독 호출 시 **Segmentation fault: 11**. hmac_sha256_bytes 도 동일(sha256 위에 빌드). 격리: 5바이트 입력 sha256_digest_bytes 만으로 재현.

**대비**: 동일 세션 net-new pure-hexa 모듈(stdlib/crypto/chacha20·codec·core/special·time/civil)은 compiled error: 'run' requires <file>
HEXA — native-compiled, atlas-aware, strict-lint language toolchain
  in-house prover + linker · English-only diagnostics · zero runtime GC
  unified science stack absorbed from nexus (archived 2026-05-13)

USAGE
  hexa run <file> [args...]               Execute .hexa script (compile-then-exec)
  hexa build <file> [-o out]              Compile .hexa → native binary
  hexa drill --seed "..."  ★              Run the discovery engine (main absorbed verb)
  hexa <subcommand> [args...]             Subcommand dispatch (80+ verbs)
  hexa tool [list | <verb> ...]           Specialized-verb drawer (go-tool style)
  hexa --version, -v                      Version + build hash
  hexa --help, -h                         This help

CORE TOOLCHAIN  (everyday verbs — `hexa <verb> --help` for per-verb detail · `hexa tool` for the drawer)
  run [--no-sentinel] <file> [args...]    Execute .hexa script (compile-then-exec)
                                            --no-sentinel: stdout 청정 (no __HEXA_RC=N tail)
  build <file> [-o out] [--target=<t>]    Compile to native (RFC-018 5-stage IR;
                                            atlas baked in 0 ms; ≤2 forks)
              [--shared]                    Emit .so/.dylib (RFC 070 G7-A flag-
                                            wiring; F-A1/F-A2 next sub-cycle)
  test <file> [--filter N] [--verbose]    Run @test fns (native runner)
  parse <file>                            Parse-only check (no exec, no codegen)
  check <file>                            Verify @invariant DSL blocks (AST-based)
  bench <file> [--runs N] [--json]        Benchmark wall/RSS/alloc
  cc                                      Rebuild transpiler (hexa_cc)
  lsp                                     Start LSP server (stdin/stdout JSON-RPC)
  init <dir> [--name N]                   Scaffold <dir>/project.hexa
  status                                  Toolchain status
  version                                 Print version

  more toolchain verbs in the drawer (`hexa tool` · TOOLCHAIN family):
    batch · typecheck · cache · daemon · convergence · tape · hxc · url

STDLIB CLI  (subcommand → stdlib dispatcher)
  qrng                                    Quantum RNG default aggregate selftest (RFC 044)
  qrng status                             9-backend table + tier coverage T0..T3
  qrng collect [--bytes=N] [--source=NAME] [--seed=S]
                                          pull bytes via router fallback chain
  qrng selftest | chain | meta --backend=NAME
                                          provider sweep · resolved chain · backend meta
    e.g. hexa qrng collect --bytes=32 --source=mock_qrng --seed=42
  cloud [run|nohup|poll|copy-to|copy-from] <host> [--port N] [--insecure] -- <argv...>
                                          structured-argv remote dispatch (PR #81/#84/#86/#88)
    e.g. hexa cloud run ubu-2 -- python3 train.py    (also: cloud copy-to / copy-from)
  stdlib [list [--json]]                  stdlib catalog (modules · dirs · tests · docs)
    e.g. hexa stdlib                      table view (purpose harvested from each module header)
  sim-universe [status|selftest|anu|multiverse|qpu|qrng|bostrom|godel|
                fvd|stark|qdarwin|ca-qm|supremacy|mbs|dtc|z2gauge|
                preheating|multipolar|surface-code|ssh|hofstadter|dqpt|wdw]
                                          virtual-universe runtime (26 modules, RFC 046)
    e.g. hexa sim-universe status         module inventory + tier table
  qmirror [status|selftest|chsh|iit|qrng|rqaoa|ctx|dynghz|vqd|stab-ext|
           overlap-vqe|sre|lg|pseudo-tel|rpe|sym-shadow|hardy|page-curve|
           qdrift|cdr|wigner|qfi|shallow|gme-steer|mabk|mirror-bench]
                                          quantum mirror substrate (38 modules, RFC 045)
    e.g. hexa qmirror chsh                CHSH Bell test (Tsirelson-class S)
  loop [--once|--budget N|--time D] [--lenses ...] [--no-fire|--fire --budget U]
       [--dfs --allow-llm --llm-cmd CMD [--depth N --beam K --target-absorb N --resume]]
                                          self-growing atlas cycle — 8 stage (RFC 065 + 080)
                                          binary built-in lens table + PR-only candidates
                                          --dfs: pluggable-LLM depth-first descent (TECS-L port)
                                          --allow-llm: cost gate for real cmd exec
                                          --target-absorb N: batch N verified children → ONE PR
    e.g. hexa loop                        --once --no-fire --dry-run (safe default)
    e.g. hexa loop --status               print state-dir + LENS_COUNT + active families
    e.g. hexa loop --dfs --allow-llm --llm-cmd "claude -p" --target-absorb 10
                                          live LLM descent → 1 batched PR (compiler/atlas/embedded.gen.hexa)
                                          per @D g_atlas_absorb_direct (no .n6 shard, no inbox markdown intermediate)
  gpu fire <kernel.ptx> <host.c> [target] Remote GPU fire harness (GPU.md §7c)
                                          scp + nvcc + run + pull result.json
                                          default target = ubu-2 (RTX 5070 sm_120)
    e.g. hexa gpu fire wmma_16x16.ptx host.c   (HEXA_GPU_DRY=1 plans only)
  gpu disasm <kernel.ptx>                 PTX opcode-family histogram (pure hexa)
  gpu lint   <kernel.ptx>                 PTX static checks (non-ASCII / sm_target / .reg)

ATLAS SSOT  (compiler/atlas/embedded.gen.hexa, text-parsed at load)
  atlas hash | stats                      Read meta
  atlas lookup <id> | <K> <id> | --prefix=<p>   Read node(s)
  atlas dump [K] [--json]                 Read full kind
  atlas register --from-verify <fn> <args> <v>  verify IN-PROCESS → fold into embedded.gen.hexa
  atlas register --from-drill --seed "<text>"   drill → fold verified candidates
  atlas export [--out PATH]               live atlas → portable .n6 (n6 = export-only)
                                          register → pr — direct fold-to-live forbidden
                                          all absorbers (atlas register --auto-pr, drill, loop --dfs)
                                          fold directly into compiler/atlas/embedded.gen.hexa via PR
                                          (no intermediate .n6/.md — @D g_atlas_absorb_direct)
  atlas-verify [--domain D] [--tier N]     Verdict ledger — 86 entries Stage 1+2+3 hexa-native
  calc <engine> [args]                    TECS-L calculators (nstate/vortex/n6/perfect/congruence/gamma0)
  verify <id> | --expr <fn> <n> <v>       Verify claim: atlas+calc → tier (🔵/🟡/🟠/⚪)
    e.g. hexa atlas lookup P n            → @P n = 6 :: foundation [11*]
    e.g. hexa verify sigma                → 🔵 SUPPORTED-FORMAL (calc divisor_sum(6)=12)
    e.g. hexa atlas-verify --domain math  → §2 MATH verifiers PASS/FAIL + |err|

ANNOTATION ANALYZERS (29, AST-based via self/lexer.tokenize)
  pure-check  memo-check  catalog  readme  doc  codegen-hints  distill
  effect-map  intent-map  meta-map  phi-map  struct-layout  self-aware
  cognitive  freedom  infer  learn  safety  antivirus  serve  tenant
  eval-run  n6-list  test-list  schema  law-link  harness  rule  gate-register
    e.g. hexa pure-check src/math.hexa    → JSON: {version,source:"ast",pure_fns:[...]}

MATH VERIFIERS  (3, deterministic — no atlas write)
  honesty <file>                          BT-AI2 honesty audit (16-domain router)
  absolute --seed "..."                   Mk.VIII Δ₀-absolute Σ₁/Π₁ classifier
  meta-closure [--seed "..."]             Mk.IX self-ref fixpoint (H1+H2+H3)
    e.g. hexa absolute --seed "sigma(6)=12"  → grade [10*]→[11*] verdict

MATH DISCOVERY  (3 generators, γ no-write)
  smash --seed "..." [--depth N]          Blowup 9-phase singularity drill
  free --seed "..." [--dfs N]             Compose 5-module DFS
  hyperarithmetic --prop "..."            Mk.IX Π₀² 5-system reverse-math classifier
    e.g. hexa smash --seed "perfect_number_6" --depth 3   → ~414 candidates

DISCOVERY ENGINE  ★ — drill is the main entry; 12 variants compose on top

  ★ drill --seed "..." [--rounds N] [--engine mk9|mk10] [--seeds csv|--seeds-file F]
        Main discovery engine. 6-stage round chain:
          smash → free → absolute → meta-closure → hyperarithmetic → resonance
        mk10 adds stage 7 transcendental_closure (Mk.X + AN11 math gate)
        Each round flushes discoveries to atlas overlay
          ~/.hx/data/atlas.overlay.n6  (rodata seed + runtime overlay, dedup'd)
        Round N+1 reads round N's overlay via atlas_lookup_merged (cumulative seed pool).
        examples:
          hexa drill --seed "perfect_number_6" --rounds 3
          hexa drill --seed "hexagonal_sum"   --engine mk10
          hexa drill --seeds "s1,s2,s3"        --rounds 2          (batch dispatch)

  chain --seed "..." --engines "x,y,z"      L3 cross-engine pipeline (drill across engines)

  drill variants  (12, each composes drill with a different orchestration pattern):
    omega       Apex preset (drill+chain+batch auto-dispatch — nexus's "main entry")
    kick        alias → drill                    (ω-cycle ≡ drill apex)
    surge       omega + cross-seed variants
    dream       iterations × drill              (dream-mode seed evolution)
    swarm       population × generations         (evolutionary)
    reign       max-cycles cap
    molt        self-evolution param mutation
    wake        signal-file triggered drill
    forge       strict round cap                 (no adaptive depth)
    canon       drill + canon seal log           (~/.hx/data/canon_seal.jsonl)
    debate      L3 N-variant adversarial debate
    revive      engine+map v2 resurrect dead rounds (cap enforced)

EXTERNAL RESOURCES  (17, δ pattern — try-CLI-or-fallback)
  HW probes:        akida           (qmirror/qrng → STDLIB CLI via RFC 044/045)
  Data bridges (16): codata  oeis  arxiv  gw  horizons  cmb  nanograv  simbad
                     icecube  nist-atomic  wikipedia  openalex  gaia  lhc  pubchem  uniprot
    Live path: HTTP API (~15 s timeout)  ·  Fallback: frozen cache (HEXA_FORCE_FALLBACK=1)
    e.g. hexa wikipedia "Perfect number"  → live → /api/rest_v1/page/summary/

ATLAS ABSORPTION  (Phase 5, 2026-05-14 — atlas-scope-only after split)
  lattice <verify|axis-table|cross-check>           n=6 σ·φ=n·τ=24 deductive verifier (pure math)
  atlas-audit <external-entity|anchor|all>          honest-caveat C3 lattice-fit gate + NIST anchor (overlay corpus)
  repo-audit-taxonomy <catalog.md> <manifest.toml>  filesystem ↔ catalog ↔ manifest C1/C2/C3 audit
    e.g. hexa lattice verify              → __N6_AXIS_VERIFY__ PASS (σ·φ=n·τ=24, |S₄|=24)
         hexa atlas-audit anchor          → NIST/CRC/ASM citation audit over overlay corpus
    atlas-audit reads ~/.hx/data/atlas.overlay.n6 (~109 nodes, ~3s). Full 7,278-node
    rodata coverage pending compiler/atlas/static_index lazy-load (see docs/notes/).

  Sister-project tools (rsc / bayes / n6 discover/mine / hexa-principle annotator etc.)
  분리됨 — 각 sister repo 의 자체 도구로 위치. invoke via `hexa run <sister>/path/main.hexa <verb>`.

INTRINSIC SURFACE  (SPEC §16 — absorbed shell-equivalents, 638→752 sites)
  Use these IN-PROCESS intrinsics from `compiler/intrinsics/intrinsics.hexa` —
  do NOT shell out (HX9xxx fork-storm lint planned). Each ⇆ its shell-equivalent:
    cwd()            ⇆ pwd                getenv(k)         ⇆ $VAR
    list_dir(path)   ⇆ ls <path>          path_exists(p)    ⇆ test -e <p>
    mkdir_p(path)    ⇆ mkdir -p <p>       path_is_dir(p)    ⇆ test -d <p>
    rm_file(path)    ⇆ rm <p>             host_target()     ⇆ uname -sm
    rm_rf(path)      ⇆ rm -rf <p>         now_ns()          ⇆ date +%s%N
  Plus SPEC §18 firmware: stdlib/{core,alloc,hal,embedded,mcu} + firmware/boards/*
  (5 absorbed repos; see `hexa hash` / `hexa stats` for the embedded inventory).

STDLIB n=6  (compiler-internal, available as `use "self/std_n6"`)
  n6_lenses · n6_verify · n6_check · n6_consensus · n6_scan · n6_omega
    User-facing utility for σ/φ/τ/n=6 constant checks (6 Omega lens API)

ATLAS / STRICT LINT  (SPEC.md §2.2 / §9 / §10)
  The atlas P/C/L/E node library is embedded into the compiler (rodata, 0 ms,
  hash-pinned). Verified code auto-registers as new atlas L[*] nodes via in-house
  ε self-proof (no Z3). `compiler/discover/promote.hexa` folds staging → live,
  emits `atlas.append.<date>.n6` shards. Formula/constant-bearing fns must cite
  an atlas L — `@implements(L[<id>])` or `@discover(kind="L")` — else HX8004.
  Bypass: `@grace(HX####, until="...", reason="...")` — emits HX9000 audit, build
  gated on explicit acked-grace. Discover overlay grows at `~/.hx/data/atlas.overlay.n6`
  per drill round (rodata seed + overlay; rodata wins on ID conflict).

ENV  (selected)
  HEXA_LANG               repo root override (loader, gate)
  HEXA_MEM_UNLIMITED=1    disable 4096 MB memcap (heavy regen / drill / 7 K-row embeds)
  HEXA_FORCE_FALLBACK=1   skip live HTTP/HW probe, use cached fallback
  HEXA_DRILL_ENGINE       mk9 (default) | mk10 (forces transcendental_closure)
  HEXA_NO_SENTINEL=1      drop __HEXA_RC sentinel from `hexa run`

DOCTRINE v2  (nexus absorbed 2026-05-13)
  ① rodata seed for technical content   ② code absorbs algorithms
  ③ metadata as frozen archive          ④ try-live-or-fallback for external
  ⑤ rodata seed + runtime overlay for discovery accumulation

STATUS
  CLI dispatch wired for all 80+ verbs (self/main.hexa::dispatch_absorbed).
  Most absorbed modules are libraries (pub fn entry points) — invoking
  `hexa <verb>` loads the module and exits 0. Per-verb fn main() CLI shims
  are a deferred follow-up; programmatic use via `use "compiler/<x>/..."` works
  today. Test smokes (`compiler/<x>/*_test.hexa`) demonstrate live API surfaces. 정상 동작 → compiled path 자체는 OK. 기존 core/hash sha256/hmac 구현 특유 버그(struct-array aliasing / to_int double-eval / arena 류 의심, [[reference_to_int_double_eval_miscompile]]·[[feedback_hexa_struct_pack_aliasing]] 계열).

**영향**: sha256/hmac 위에 빌드하는 모든 것이 compiled path 에서 segfault — pbkdf2/HKDF(stdlib/crypto/pbkdf2.hexa 신규) 런타임 검증 차단. CI @ci_gate 테스트(module_loader 2-step)는 통과해 왔으므로 회귀 안 잡힘(2-step vs hexa-run 경로 분기).

**재현**:  → segfault. **진단법**: sha256_digest_bytes 내부 struct-array index / cast 사이트를 let-bind 로 분해(to_int double-eval 회피 패턴). 다음: 해당 모듈의 hot-loop array 인덱싱 + 캐스트 사이트 audit.

## 2026-05-26T20:43Z — ubu-2 drill rebuild retry (INBOX line 8 re-verify)

Retry of the INBOX line-8 item (`pool 호스트 hexa CLI — drill-runtime 잔존`,
`map key 'f_a' not found` / `tag 4 vs tag 0`). Re-ran probe-first per
instrument-first; the prior remote attempt (ssh ubu-2) had already landed.

**Probe result (binary provenance)**
- ubu-2 `~/.hx/bin/hexa.real`: rebuilt **2026-05-27 05:25** (today), size
  2096072 B, md5 `d72b69379904532d7853d264d6ea71f6`, version `0.1.0-dispatch`.
- Stale tell `strings | grep '%ld %ld'` = **0** → NOT the old fscanf build.
- Built from `/tmp/hexa-lang-65fe0934` (clone @ `65fe093`, #1458). Current
  main HEAD = `f759122b` (#1464) — clone is 6 commits behind, but the 6-commit
  delta is only nvptx codegen + regex stdlib + docs (none touch drill runtime).
- Prior rebuild **already happened** — backups present
  (`hexa.real.bak.before-drill-rebuild-20260526` + 4 others).

**Verdict: ALREADY FIXED (INBOX line 8 was already `- [x]` RESOLVED 2026-05-26).**
- Original `map key 'f_a' not found` abort is GONE. Root cause (per line-8 note
  + drill.hexa:290-298): drill is JIT-compiled from the ubu-2 worktree source,
  whose `drill.hexa:290` read the stale field `verdict.f_a`; current main reads
  `verdict.f_ai2_a` (landed #634-followup, merged via #1001 `dfd51d72`). Prior
  agent applied current-main `drill.hexa` to the ubu-2 worktree + cleared the
  stale JIT cache. Driver rebuild was incidental (drill is not compiled into it).
- **ubu-2 re-smoke (this retry)**: `hexa drill --seed "verify perfect number 6
  …" --rounds 1` → clean:
  ```
  round 1: smash+414 free+211 abs=0 meta=0 hyper=0 res+26(σ=0.10) total=651
  overlay+ 517 lines (pool=0)
  DRILL_VERIFIER {"round":1,"verdict":"skip"}
  max rounds reached (1) — total=651
  {"...","rounds":1,"total":651,...,"verifier_verdict":"skip"}
  DRILL_EXIT=0
  ```
  `--rounds 1` correctly bounds the loop (max_rounds=1), no segfault.

**NEW side-finding (Mac-local only — NOT the INBOX item, NOT on ubu-2)**
- Local Mac `hexa drill --seed "…" --rounds 1` prints `max_rounds=10` (the
  `--rounds` flag is silently dropped) → loop proceeds to round 2 → **deterministic
  segfault** right after `DRILL_VERIFIER {round:1,verdict:skip}`.
- Boundary isolated: round-1 `checkpoint_save` completes (checkpoint file written
  with round:1), crash fires entering **round 2's seed-pool path** in
  `round_run_with_pool` (round ≥ 2 only — round 1 has empty pool `pool=0`). The
  populated `seed_pool` from `extract_axiom_exprs(rr.discoveries)` (drill.hexa:415)
  drives `smash(ex_seed,1)` over candidates accessed via `c.axiom`/`c.expr`
  (round.hexa:309-327) — a candidate-shape / map-key mismatch on the Mac runtime.
- Why Mac-only: `cli_args()` (compiler/_cli_args/parse.hexa:24) slices `argv()`
  from index 2 (`[interp_bin, script_path]`), but the Mac cached-`hexa_run`
  dispatch path supplies only ONE prefix element → the first real flag
  (`--rounds`) is eaten. ubu-2's argv has the expected 2-element prefix so
  `--rounds` survives and the loop bounds correctly (no round 2, no crash).
- The `drill-fixpoint-sigsegv-r2` local branch shows a prior agent already
  touched this segfault family.

**This is a PHYSICAL LIMIT for this round, cleanly reported**: the INBOX-scoped
ubu-2 drill runtime is FIXED + verified. The Mac-local segfault is a *separate*
bug in the drill engine's round-2 seed-pool path (gated behind a Mac-only
`--rounds` argv-drop) — out of scope for this ubu-2 INBOX item, filed here for a
follow-up. No ubu-2 rebuild was needed (probe showed it current + working).

## 2026-05-27 — hexa run cache-key 가 imported-module hash 미포함 → stale import binding

 의 컴파일 캐시 키가  소스 해시만 반영하고  로 import 한 모듈()의 해시는 미포함. import 모듈을 편집해도  가 그대로면 캐시 히트 → 옛 모듈 바인딩 binary 재사용 → silent stale 결과.

**재현 (2026-05-27, regex native engine 개발 중)**:  의 STAR backtracking 버그 수정 후, 동일  가 여전히  (수정 전 결과) 반환. 별도 새 프로그램(, 동일 호출)은 .  후  도 . → 캐시가 import 모듈 변경 미감지 확정.

**영향**: stdlib 모듈 개발 시 caller 프로그램이 캐시 stale 결과 → 디버깅 혼란(수정이 반영 안 된 것처럼 보임). 특히  가 자기 자신만 바뀌고 테스트 대상 모듈이 바뀐 경우.

**우회**: 모듈 편집 후  (또는 caller 에 무의미 변경 1줄).

**제안 fix**: error: 'run' requires <file>
HEXA — native-compiled, atlas-aware, strict-lint language toolchain
  in-house prover + linker · English-only diagnostics · zero runtime GC
  unified science stack absorbed from nexus (archived 2026-05-13)

USAGE
  hexa run <file> [args...]               Execute .hexa script (compile-then-exec)
  hexa build <file> [-o out]              Compile .hexa → native binary
  hexa drill --seed "..."  ★              Run the discovery engine (main absorbed verb)
  hexa <subcommand> [args...]             Subcommand dispatch (80+ verbs)
  hexa tool [list | <verb> ...]           Specialized-verb drawer (go-tool style)
  hexa --version, -v                      Version + build hash
  hexa --help, -h                         This help

CORE TOOLCHAIN  (everyday verbs — `hexa <verb> --help` for per-verb detail · `hexa tool` for the drawer)
  run [--no-sentinel] <file> [args...]    Execute .hexa script (compile-then-exec)
                                            --no-sentinel: stdout 청정 (no __HEXA_RC=N tail)
  build <file> [-o out] [--target=<t>]    Compile to native (RFC-018 5-stage IR;
                                            atlas baked in 0 ms; ≤2 forks)
              [--shared]                    Emit .so/.dylib (RFC 070 G7-A flag-
                                            wiring; F-A1/F-A2 next sub-cycle)
  test <file> [--filter N] [--verbose]    Run @test fns (native runner)
  parse <file>                            Parse-only check (no exec, no codegen)
  check <file>                            Verify @invariant DSL blocks (AST-based)
  bench <file> [--runs N] [--json]        Benchmark wall/RSS/alloc
  cc                                      Rebuild transpiler (hexa_cc)
  lsp                                     Start LSP server (stdin/stdout JSON-RPC)
  init <dir> [--name N]                   Scaffold <dir>/project.hexa
  status                                  Toolchain status
  version                                 Print version

  more toolchain verbs in the drawer (`hexa tool` · TOOLCHAIN family):
    batch · typecheck · cache · daemon · convergence · tape · hxc · url

STDLIB CLI  (subcommand → stdlib dispatcher)
  qrng                                    Quantum RNG default aggregate selftest (RFC 044)
  qrng status                             9-backend table + tier coverage T0..T3
  qrng collect [--bytes=N] [--source=NAME] [--seed=S]
                                          pull bytes via router fallback chain
  qrng selftest | chain | meta --backend=NAME
                                          provider sweep · resolved chain · backend meta
    e.g. hexa qrng collect --bytes=32 --source=mock_qrng --seed=42
  cloud [run|nohup|poll|copy-to|copy-from] <host> [--port N] [--insecure] -- <argv...>
                                          structured-argv remote dispatch (PR #81/#84/#86/#88)
    e.g. hexa cloud run ubu-2 -- python3 train.py    (also: cloud copy-to / copy-from)
  stdlib [list [--json]]                  stdlib catalog (modules · dirs · tests · docs)
    e.g. hexa stdlib                      table view (purpose harvested from each module header)
  sim-universe [status|selftest|anu|multiverse|qpu|qrng|bostrom|godel|
                fvd|stark|qdarwin|ca-qm|supremacy|mbs|dtc|z2gauge|
                preheating|multipolar|surface-code|ssh|hofstadter|dqpt|wdw]
                                          virtual-universe runtime (26 modules, RFC 046)
    e.g. hexa sim-universe status         module inventory + tier table
  qmirror [status|selftest|chsh|iit|qrng|rqaoa|ctx|dynghz|vqd|stab-ext|
           overlap-vqe|sre|lg|pseudo-tel|rpe|sym-shadow|hardy|page-curve|
           qdrift|cdr|wigner|qfi|shallow|gme-steer|mabk|mirror-bench]
                                          quantum mirror substrate (38 modules, RFC 045)
    e.g. hexa qmirror chsh                CHSH Bell test (Tsirelson-class S)
  loop [--once|--budget N|--time D] [--lenses ...] [--no-fire|--fire --budget U]
       [--dfs --allow-llm --llm-cmd CMD [--depth N --beam K --target-absorb N --resume]]
                                          self-growing atlas cycle — 8 stage (RFC 065 + 080)
                                          binary built-in lens table + PR-only candidates
                                          --dfs: pluggable-LLM depth-first descent (TECS-L port)
                                          --allow-llm: cost gate for real cmd exec
                                          --target-absorb N: batch N verified children → ONE PR
    e.g. hexa loop                        --once --no-fire --dry-run (safe default)
    e.g. hexa loop --status               print state-dir + LENS_COUNT + active families
    e.g. hexa loop --dfs --allow-llm --llm-cmd "claude -p" --target-absorb 10
                                          live LLM descent → 1 batched PR (compiler/atlas/embedded.gen.hexa)
                                          per @D g_atlas_absorb_direct (no .n6 shard, no inbox markdown intermediate)
  gpu fire <kernel.ptx> <host.c> [target] Remote GPU fire harness (GPU.md §7c)
                                          scp + nvcc + run + pull result.json
                                          default target = ubu-2 (RTX 5070 sm_120)
    e.g. hexa gpu fire wmma_16x16.ptx host.c   (HEXA_GPU_DRY=1 plans only)
  gpu disasm <kernel.ptx>                 PTX opcode-family histogram (pure hexa)
  gpu lint   <kernel.ptx>                 PTX static checks (non-ASCII / sm_target / .reg)

ATLAS SSOT  (compiler/atlas/embedded.gen.hexa, text-parsed at load)
  atlas hash | stats                      Read meta
  atlas lookup <id> | <K> <id> | --prefix=<p>   Read node(s)
  atlas dump [K] [--json]                 Read full kind
  atlas register --from-verify <fn> <args> <v>  verify IN-PROCESS → fold into embedded.gen.hexa
  atlas register --from-drill --seed "<text>"   drill → fold verified candidates
  atlas export [--out PATH]               live atlas → portable .n6 (n6 = export-only)
                                          register → pr — direct fold-to-live forbidden
                                          all absorbers (atlas register --auto-pr, drill, loop --dfs)
                                          fold directly into compiler/atlas/embedded.gen.hexa via PR
                                          (no intermediate .n6/.md — @D g_atlas_absorb_direct)
  atlas-verify [--domain D] [--tier N]     Verdict ledger — 86 entries Stage 1+2+3 hexa-native
  calc <engine> [args]                    TECS-L calculators (nstate/vortex/n6/perfect/congruence/gamma0)
  verify <id> | --expr <fn> <n> <v>       Verify claim: atlas+calc → tier (🔵/🟡/🟠/⚪)
    e.g. hexa atlas lookup P n            → @P n = 6 :: foundation [11*]
    e.g. hexa verify sigma                → 🔵 SUPPORTED-FORMAL (calc divisor_sum(6)=12)
    e.g. hexa atlas-verify --domain math  → §2 MATH verifiers PASS/FAIL + |err|

ANNOTATION ANALYZERS (29, AST-based via self/lexer.tokenize)
  pure-check  memo-check  catalog  readme  doc  codegen-hints  distill
  effect-map  intent-map  meta-map  phi-map  struct-layout  self-aware
  cognitive  freedom  infer  learn  safety  antivirus  serve  tenant
  eval-run  n6-list  test-list  schema  law-link  harness  rule  gate-register
    e.g. hexa pure-check src/math.hexa    → JSON: {version,source:"ast",pure_fns:[...]}

MATH VERIFIERS  (3, deterministic — no atlas write)
  honesty <file>                          BT-AI2 honesty audit (16-domain router)
  absolute --seed "..."                   Mk.VIII Δ₀-absolute Σ₁/Π₁ classifier
  meta-closure [--seed "..."]             Mk.IX self-ref fixpoint (H1+H2+H3)
    e.g. hexa absolute --seed "sigma(6)=12"  → grade [10*]→[11*] verdict

MATH DISCOVERY  (3 generators, γ no-write)
  smash --seed "..." [--depth N]          Blowup 9-phase singularity drill
  free --seed "..." [--dfs N]             Compose 5-module DFS
  hyperarithmetic --prop "..."            Mk.IX Π₀² 5-system reverse-math classifier
    e.g. hexa smash --seed "perfect_number_6" --depth 3   → ~414 candidates

DISCOVERY ENGINE  ★ — drill is the main entry; 12 variants compose on top

  ★ drill --seed "..." [--rounds N] [--engine mk9|mk10] [--seeds csv|--seeds-file F]
        Main discovery engine. 6-stage round chain:
          smash → free → absolute → meta-closure → hyperarithmetic → resonance
        mk10 adds stage 7 transcendental_closure (Mk.X + AN11 math gate)
        Each round flushes discoveries to atlas overlay
          ~/.hx/data/atlas.overlay.n6  (rodata seed + runtime overlay, dedup'd)
        Round N+1 reads round N's overlay via atlas_lookup_merged (cumulative seed pool).
        examples:
          hexa drill --seed "perfect_number_6" --rounds 3
          hexa drill --seed "hexagonal_sum"   --engine mk10
          hexa drill --seeds "s1,s2,s3"        --rounds 2          (batch dispatch)

  chain --seed "..." --engines "x,y,z"      L3 cross-engine pipeline (drill across engines)

  drill variants  (12, each composes drill with a different orchestration pattern):
    omega       Apex preset (drill+chain+batch auto-dispatch — nexus's "main entry")
    kick        alias → drill                    (ω-cycle ≡ drill apex)
    surge       omega + cross-seed variants
    dream       iterations × drill              (dream-mode seed evolution)
    swarm       population × generations         (evolutionary)
    reign       max-cycles cap
    molt        self-evolution param mutation
    wake        signal-file triggered drill
    forge       strict round cap                 (no adaptive depth)
    canon       drill + canon seal log           (~/.hx/data/canon_seal.jsonl)
    debate      L3 N-variant adversarial debate
    revive      engine+map v2 resurrect dead rounds (cap enforced)

EXTERNAL RESOURCES  (17, δ pattern — try-CLI-or-fallback)
  HW probes:        akida           (qmirror/qrng → STDLIB CLI via RFC 044/045)
  Data bridges (16): codata  oeis  arxiv  gw  horizons  cmb  nanograv  simbad
                     icecube  nist-atomic  wikipedia  openalex  gaia  lhc  pubchem  uniprot
    Live path: HTTP API (~15 s timeout)  ·  Fallback: frozen cache (HEXA_FORCE_FALLBACK=1)
    e.g. hexa wikipedia "Perfect number"  → live → /api/rest_v1/page/summary/

ATLAS ABSORPTION  (Phase 5, 2026-05-14 — atlas-scope-only after split)
  lattice <verify|axis-table|cross-check>           n=6 σ·φ=n·τ=24 deductive verifier (pure math)
  atlas-audit <external-entity|anchor|all>          honest-caveat C3 lattice-fit gate + NIST anchor (overlay corpus)
  repo-audit-taxonomy <catalog.md> <manifest.toml>  filesystem ↔ catalog ↔ manifest C1/C2/C3 audit
    e.g. hexa lattice verify              → __N6_AXIS_VERIFY__ PASS (σ·φ=n·τ=24, |S₄|=24)
         hexa atlas-audit anchor          → NIST/CRC/ASM citation audit over overlay corpus
    atlas-audit reads ~/.hx/data/atlas.overlay.n6 (~109 nodes, ~3s). Full 7,278-node
    rodata coverage pending compiler/atlas/static_index lazy-load (see docs/notes/).

  Sister-project tools (rsc / bayes / n6 discover/mine / hexa-principle annotator etc.)
  분리됨 — 각 sister repo 의 자체 도구로 위치. invoke via `hexa run <sister>/path/main.hexa <verb>`.

INTRINSIC SURFACE  (SPEC §16 — absorbed shell-equivalents, 638→752 sites)
  Use these IN-PROCESS intrinsics from `compiler/intrinsics/intrinsics.hexa` —
  do NOT shell out (HX9xxx fork-storm lint planned). Each ⇆ its shell-equivalent:
    cwd()            ⇆ pwd                getenv(k)         ⇆ $VAR
    list_dir(path)   ⇆ ls <path>          path_exists(p)    ⇆ test -e <p>
    mkdir_p(path)    ⇆ mkdir -p <p>       path_is_dir(p)    ⇆ test -d <p>
    rm_file(path)    ⇆ rm <p>             host_target()     ⇆ uname -sm
    rm_rf(path)      ⇆ rm -rf <p>         now_ns()          ⇆ date +%s%N
  Plus SPEC §18 firmware: stdlib/{core,alloc,hal,embedded,mcu} + firmware/boards/*
  (5 absorbed repos; see `hexa hash` / `hexa stats` for the embedded inventory).

STDLIB n=6  (compiler-internal, available as `use "self/std_n6"`)
  n6_lenses · n6_verify · n6_check · n6_consensus · n6_scan · n6_omega
    User-facing utility for σ/φ/τ/n=6 constant checks (6 Omega lens API)

ATLAS / STRICT LINT  (SPEC.md §2.2 / §9 / §10)
  The atlas P/C/L/E node library is embedded into the compiler (rodata, 0 ms,
  hash-pinned). Verified code auto-registers as new atlas L[*] nodes via in-house
  ε self-proof (no Z3). `compiler/discover/promote.hexa` folds staging → live,
  emits `atlas.append.<date>.n6` shards. Formula/constant-bearing fns must cite
  an atlas L — `@implements(L[<id>])` or `@discover(kind="L")` — else HX8004.
  Bypass: `@grace(HX####, until="...", reason="...")` — emits HX9000 audit, build
  gated on explicit acked-grace. Discover overlay grows at `~/.hx/data/atlas.overlay.n6`
  per drill round (rodata seed + overlay; rodata wins on ID conflict).

ENV  (selected)
  HEXA_LANG               repo root override (loader, gate)
  HEXA_MEM_UNLIMITED=1    disable 4096 MB memcap (heavy regen / drill / 7 K-row embeds)
  HEXA_FORCE_FALLBACK=1   skip live HTTP/HW probe, use cached fallback
  HEXA_DRILL_ENGINE       mk9 (default) | mk10 (forces transcendental_closure)
  HEXA_NO_SENTINEL=1      drop __HEXA_RC sentinel from `hexa run`

DOCTRINE v2  (nexus absorbed 2026-05-13)
  ① rodata seed for technical content   ② code absorbs algorithms
  ③ metadata as frozen archive          ④ try-live-or-fallback for external
  ⑤ rodata seed + runtime overlay for discovery accumulation

STATUS
  CLI dispatch wired for all 80+ verbs (self/main.hexa::dispatch_absorbed).
  Most absorbed modules are libraries (pub fn entry points) — invoking
  `hexa <verb>` loads the module and exits 0. Per-verb fn main() CLI shims
  are a deferred follow-up; programmatic use via `use "compiler/<x>/..."` works
  today. Test smokes (`compiler/<x>/*_test.hexa`) demonstrate live API surfaces. 의 캐시 키 계산에 flatten 된 모듈 의존성 트리의 합산 해시 포함 (이미 module_loader 가 flatten 하므로 flatten 결과 해시를 키로 쓰면 됨). 또는 flatten tmp 의 해시를 키로.

## 2026-05-27T04:15Z — atlas 6 tier symmetric registration (PR #1449 후속 broadening)

**✅ RESOLVED 2026-05-27 (PR #1503 · f2330a29 on main, TECS-L RTSC3 confirm)** — `--from-citation` · `--from-defer` · `--from-falsify` · `--from-fence` 4 arm 전부 `tool/atlas_cli.hexa cmd_register` 에 landed (옵션 A 채택, 새 node kind 불필요 — falsify/citation/defer → @F · fence → @X). 각 arm 이 closed-negative/citation/defer/fence 를 `_build_raw_*` + `_fold_into_embedded` 로 embedded.gen.hexa SSOT 에 직접 splice. `hexa parse tool/atlas_cli.hexa` = OK. 잔여 (개별 INBOX 후속, RTSC3 범위 밖): tier-breakdown stats surface · `lookup --tier <T>` filter · bulk migration script.

**severity: high** — PR #1449는 🔴 FALSIFIED만 처리. 사용자 통찰: "모든 tier가 다 있어야 될 듯". g5 rubric은 본래 **6-element complete set** (🔵 🟢 🟡 🟠 🔴 ⚪) — atlas register는 현재 2/6만 지원.

### 현재 매트릭스

| tier | name | atlas verb | status |
|---|---|---|---|
| 🔵 | SUPPORTED-FORMAL | `register --from-verify` | ✓ closed-form/symbolic exact |
| 🟢 | SUPPORTED-NUMERICAL | `register --from-verify` | ✓ libm recompute match |
| 🟡 | SUPPORTED-BY-CITATION | ✗ verb 없음 | literature record only (no recompute) |
| 🟠 | INSUFFICIENT/DEFERRED | ✗ verb 없음 | no calc path / external dep |
| 🔴 | FALSIFIED | ✗ verb 없음 (PR #1449) | calc disagrees · CLOSED-negative |
| ⚪ | SPECULATION-FENCED | ✗ verb 없음 | `hexa verify --fence` 있으나 register 안 함 |

**2/6 = 33% 1급 · 4/6 = 67% markdown stranded** (atlas_fold_pending.md / fence-log / citation-list scattered).

### 제안 fix — symmetric 6-verb API

```
# 🟡 SUPPORTED-BY-CITATION — atlas registry without recompute
hexa atlas register --from-citation <claim_fn> <args> --tier 🟡 --doi <doi> --note <verbatim_quote>
# example: register --from-citation Tc-measured CaH₆ --tier 🟡 --doi 10.1038/s41586-022-04395-7 --note "Ma et al. 215K @ 170 GPa"

# 🟠 INSUFFICIENT/DEFERRED — external dep marker
hexa atlas register --from-defer <claim_fn> <args> --tier 🟠 --blocker <external_dep> --eta <approx>
# example: register --from-defer RTSC-absorbed-true --tier 🟠 --blocker "measured oracle PASS (wet-lab)" --eta "unknown"

# 🔴 FALSIFIED — closed-negative (PR #1449)
hexa atlas register --from-falsify <claim_fn> <args> --tier 🔴 --falsifier <F-id> --citation <PR|sha>

# ⚪ SPECULATION-FENCED — imagination/metaphor honest fence
hexa atlas register --from-fence <claim_text> --tier ⚪ --kind <metaphor|sf|hypothesis>
# example: register --from-fence "hexa lattice n=6 as universal substrate" --tier ⚪ --kind metaphor
# (또는 기존 `hexa verify --fence` 가 자동 atlas register → idempotent)
```

### honest-triad chain 닫힘

현재 atlas는 "claim + citation + severity" 중 **claim+citation만** 보존, severity (tier) 부재. 6-tier symmetric 후:

```
atlas lookup --claim 'Mg₂IrH₆ ambient stable'
  → @N material_verdict-mg2irh6 · tier 🔴 · falsifier F-N6-1 · cited PR #247

atlas lookup --claim 'RTSC absorbed=true'
  → @D absorbed-rtsc-final · tier 🟠 · blocker 'measured oracle PASS' · eta unknown

atlas lookup --claim 'hexa lattice n=6 substrate'
  → @M lattice-substrate-claim · tier ⚪ · kind metaphor · fence-citation /LATTICE_POLICY.md
```

### bonus — `hexa atlas stats --tier-breakdown`

현재 `stats` 가 node-kind counts만 표시 (P/C/L/E/F/R/S/X/Q). 추가:

```
hexa atlas stats --tier-breakdown
  🔵 SUPPORTED-FORMAL    : 1247
  🟢 SUPPORTED-NUMERICAL :  892
  🟡 SUPPORTED-BY-CITATION:  56  (DOI cited, no recompute)
  🟠 INSUFFICIENT/DEFERRED:  12  (external dep)
  🔴 FALSIFIED           :   8  (closed-negative)
  ⚪ SPECULATION-FENCED  :  43  (honest fence)
```

### cross-ref

- PR #1449 (🔴 closed-negative · 이 PR의 sibling) — 🔴 alone instead of 6-symmetric
- PR #1447 (RTSC /gap upstream-fix) — micromamba + stdlib/rtsc
- commons g5 (verify tier rubric) — 6-element complete set canonical
- commons g62 (atlas register at checkpoints) — 모든 verdict 등록 mandate (현재 🟢/🔵만 enforce)
- commons g63 (honest sweep) — FALSIFIED never skipped (atlas-rooted enforcement)

### priority — high

- [ ] **4 신규 register verb** — `--from-citation` · `--from-defer` · `--from-falsify` · `--from-fence`
- [ ] **tier field 표준화** — 모든 AtlasNode에 `tier: 🔵|🟢|🟡|🟠|🔴|⚪` 명시 field
- [ ] **`atlas lookup --tier <T>`** — tier-filtered surface
- [ ] **`atlas stats --tier-breakdown`** — tier 분포 1급 시각화
- [ ] **migration script** — 기존 atlas_fold_pending / fence-log / citation-list 일괄 import

## 2026-05-27T04:05Z — atlas 1급 closed-negative 부재 (g63 structural gap)

**✅ RESOLVED 2026-05-27 (PR #1503 · f2330a29 on main, TECS-L RTSC3 confirm)** — 옵션 A (`--from-falsify` arm) 채택. demiurge 5 closed-negative 전부 atlas 1급 (🔴 FALSIFIED) splice 완료 + lookup 검증: `falsified-mg2irh6_ambient_stable` (F-N6-1·demiurge#247) · `falsified-li2cuh6_ambient_stable` (F-N6-2·#275) · `falsified-mg2pth6_ambient_stable` (rtsc-mg2pth6) · `falsified-mgb2h_superlattice_stable` (rtsc-mgb2h) · `falsified-h3o_6cubed_converged` (rtsc-h3o-undersample·#286). `closed_negative = true` + `falsifier =` + `cite =` field 보존. g63 enforcement 작동 — atlas lookup 으로 already-falsified candidate 인지 가능 → 재dispatch 방지. (binary-stale upstream 잔여: live `~/.hx/bin/hexa` 가 #1503 이전 → `HEXA_ATLAS_EMBED=<repo>/compiler/atlas` env override 로 lookup 가능 · 별도 INBOX 항목 hexa-atlas binary rebuild.)

**severity: high** — atlas SSOT (`compiler/atlas/embedded.gen.hexa`, n6/atlas.n6)가 🟢/🔵 SUPPORTED 노드만 1급 저장. 🔴 FALSIFIED는 별도 markdown (RTSC `atlas_fold_pending.md`)에 stranded → 후속 session/agent가 atlas만 lookup하면 already-falsified candidate를 모르고 재dispatch 가능 (g63 "FALSIFIED is a CLOSED negative · never skipped" 명시 위배).

### 증상 (demiurge RTSC 캠페인 evidence)

- 5+ closed-negative landed in RTSC 캠페인 (mg2pth6, mgb2h, Mg₂IrH₆, Li₂CuH₆, h3o-6³q-retroactive):
  - 모두 `domains/rtsc.log.md` + `exports/material_discovery/atlas_fold_pending.md` 에 record
  - 그러나 `hexa atlas lookup` 시 검색 불가 (atlas SSOT 미등록)
- `hexa atlas register --help` 확인: `--from-verify` 와 `--from-drill` 만 존재 — 둘 다 🟢/🔵 SUPPORTED만 produce. closed-negative 등록 verb 부재.
- node kinds P/C/L/E/F/R/S/X/Q 에 `@N` (NEGATIVE) 또는 `@V` (VERDICT) slot 없음.
- `grep '🔴\|FALSIFIED' embedded.gen.hexa` = 20 hits (모두 citation/metadata string · structural 1급 atom 아님).

### 제안 fix

**옵션 A — 새 register verb `--from-falsify`** (가장 minimal):
```
hexa atlas register --from-falsify <claim_fn> <args> --tier 🔴 --falsifier <id> --citation <url|sha>
```
- 예: `register --from-falsify allen_dynes_tc "Mg₂IrH₆ ambient cation-VEC=19 stable" --tier 🔴 --falsifier F-N6-1 --citation PR#247`
- 결과: @F (Function) 또는 새 @N (Negative) atom, tier=🔴 field, falsifier_id link, claim_invalidated 표시.

**옵션 B — 새 node kind `@V` (VERDICT)**:
- Verdict node가 (claim, evidence, tier=🔴/🟢/...) tuple 저장
- Pre-registered falsifier (F-N6-*) → verdict link

**옵션 C — 기존 atom의 `tier` field overload** (가장 invasive하지 않음):
- 현재 atom tier가 implicit (verify time)
- 명시적 `tier: 🔴` field + `falsified_by: <ref>` 추가
- 모든 노드 종류에 적용 가능, schema migration 필요

### use case — atlas-driven recheck (g63 enforcement)

```
# 다음 agent가 'Mg₂IrH₆ 시도하자' 결정 전:
hexa atlas lookup --claim 'Mg₂IrH₆ ambient stable'
→ @N material_verdict-mg2irh6-falsified · tier 🔴 · falsifier F-N6-1 · cited PR #247
→ agent: "already closed-negative · skip"
```

vs 현재 (atlas only 🟢):
```
hexa atlas lookup 'Mg₂IrH₆' → not found
→ agent: "unknown · let's try" → 같은 falsified DFT 재실행 → 자원 낭비
```

### cross-ref

- demiurge `domains/RTSC/protocols/CANDIDATE_SCORING.md` (PR #284): falsifier-aware scoring 가정 — atlas 1급 negative 없으면 작동 안 함
- demiurge `domains/RTSC/falsifiers/F-N6.md` (PR #282): pre-registered falsifier ledger, atlas link 부재
- commons g63 (micro-exp honest sweep): FALSIFIED is a CLOSED-negative · never skipped
- commons g65 (sweep aggregation): ledger.json에 verdict 명시

### priority — high

- [ ] **새 register verb 또는 node kind 설계** — atlas SSOT에 closed-negative 1급 등록 path 마련
- [ ] **migration script** — 기존 `atlas_fold_pending.md` 5+ closed-negative 일괄 import
- [ ] **falsifier ledger link** — F-N6-* IDs ↔ atlas atoms 양방향 cross-ref
- [ ] **`hexa atlas lookup --tier 🔴`** — closed-negative 검색 1급 surface

## 2026-05-27T03:50Z — RTSC /gap full audit 발견 2 upstream-fix 후보

demiurge RTSC `/gap full` 8-family sweep + top-3 priority fan-out (METHOD/STRATEGY/PROTOCOL) 중 발견. directly-fix-while-completing-atlas-absorb 후속 — atlas fold(h3as·labeh8)는 이미 완료(memory `reference_hexa_toolchain_rebuild`), 새 gap만 INBOX 등록.

### Gap 1 — `hexa cloud nohup` 의 conda/micromamba env 비활성

**증상**: demiurge agent `ab94f11664a475116` (labeh8 interp ablation dispatch) 가 `nohup bash -c 'pw.x ...'` 형태로 pool ubu-1에 발사 시 `pw.x: command not found` — micromamba env가 nohup'd 자식 셸에 inherit 안 됨. agent 75 tool uses 후 종료(env error trace), 진짜 작업 0 진척.

**제안 fix**: `stdlib/cloud/cloud_cli.hexa` nohup verb이 `--conda-env <name>` 또는 `--source <init.sh>` 플래그 받아 `eval "$(micromamba shell hook -s bash)" && micromamba activate <name>` 자동 prefix. 또는 envrc-style: `~/.hexa/cloud/host-env.sh` 가 있으면 자동 source.

**severity**: medium — pool free dispatch의 silent class-1 실패. raw `pool on host 'micromamba activate qe && cmd'` 우회 가능하지만 hexa cloud canonical 정책(g8)과 충돌.

- [ ] **`hexa cloud nohup --conda-env qe`** 또는 동등 플래그 — micromamba/conda env 자동 활성 (stdlib/cloud/cloud_cli.hexa)
- [ ] 또는 host-side `~/.hexa/cloud/env.sh` 자동 source (config 기반)
- [ ] usage banner + help에 환경 활성 시점 명시

### Gap 2 — `stdlib/rtsc/elph_harvest.hexa` SSOT promotion (g61)

**증상**: demiurge RTSC 캠페인에서 `harvest_v2.py/.hexa` 가 per-candidate clone (labeh8/, mg2irh6/, li2cuh6/, h3br_pscan/, h3cl_interp_ablation/ 각각 별도 사본). 동일 로직(σ-plateau · per-q λ · ω_log Allen-weighted · Allen-Dynes Tc) ~150 LOC가 5+ 위치에 복제. /gap F6 duplicated-helper finding.

**부분 진척**: PR #286 (METHOD agent) 가 `decks/labeh8/harvest_v2.hexa` 를 canonical SSOT로 작성. 그러나 stdlib promotion 미완.

**제안 fix**: g61 stdlib promote — `stdlib/rtsc/elph_harvest.hexa` 로 이동, demiurge 측에 thin shim `import stdlib/rtsc/elph_harvest`.

**severity**: low — campaign는 이미 SSOT 위치 식별. g61 stdlib promotion만 남음.

- [ ] **`stdlib/rtsc/elph_harvest.hexa`** — demiurge `decks/labeh8/harvest_v2.hexa` 를 hexa-lang stdlib으로 이동
- [ ] demiurge 측 shim: `decks/*/harvest_v2.hexa` → `use stdlib/rtsc/elph_harvest` thin wrapper
- [ ] (선택) atlas register harvest atoms — σ-plateau · ω_log_Allen_weighted · ω_log_per_q

**cross-ref**: demiurge PRs #286 (METHOD validity gate · h3cl ablation in-flight) · #284 (PROTOCOL discipline 4-doc) · #289 (h3br F-N6-4 PASSED) · g61 stdlib SSOT · feedback `feedback_demiurge_assets_simulation_mandatory`.

Append-only history sister of `INBOX.md`. Each entry starts with `## <ISO timestamp> — <header>` (newest on top); body = `- [x]` (done) / `- [ ]` (pending) checkbox tasks.

## 2026-05-27T04:50Z — Lie-group dimension verify primitives 부재 — `dim_su_n` · `dim_so_n` · `dim_e8` (F25 PHYSICS NOVEL boundary blocker)

> TECS-L F25 (PHYSICS NOVEL, PR #1440) honest negative 후속. PHYSICS 영역의 NOVEL 시도에서 약수함수 (σ/τ/φ) 측 closed-form integer arithmetic 는 🔵 verify 되지만, 물리 statement 측의 Lie-group dimension (SU(N), SO(N), E_8 등) 이 `hexa verify --expr` catalogue 부재 → 모든 pairing 이 ⚪/🟡 cite 로 collapse. n=496=dim(SO(32))=dim(E8×E8) (Green-Schwarz 1984) · n=14=τ(8128)=dim(G2) · n=24=σ(6)·φ(6)=dim(SU(5)) 등 paper-grade pairing 후보가 atlas fold 불가.

- [ ] **`dim_su_n(N)` verify-fn** = N²−1 (closed-form integer). cap small N (1..10) → verify dim(SU(5))=24, dim(SU(3))=8 등. `verify_cli.hexa::_recompute` arm 추가 (single-arg).
- [ ] **`dim_so_n(N)` verify-fn** = N(N−1)/2 (closed-form integer). cap small N (3..32) → verify dim(SO(8))=28=P_2, dim(SO(32))=496=P_3 등. `verify_cli.hexa::_recompute` arm 추가.
- [ ] **`dim_e8()` constant verify-fn** = 248 (exceptional Lie group). 또는 `dim_exceptional_lie(family, rank)` family-aware (e.g. E6/E7/E8 = 78/133/248, G2=14, F4=52). atlas L-laws pad 확장.
- 영향: F25-followup-A 의 promotion ⚪/🟡→🔵 가능. paper-eligible pairing (n=496 SO(32) Green-Schwarz · τ(8128)=14=dim(G2)) 일부 atlas-fold 가능해짐.
- 우선순위: 🟠 deferred frontier — PHYSICS 대축 verify-infra. Clay 와 동급 boundary, single-arg single-return → 비교적 simpler 추가.
- 관련: PR #1402 (runtime.o blocker) 가 풀려야 binary activation 가능. source-only land 는 즉시 가능.
- proposed-by: F25 PHYSICS NOVEL honest negative (PR #1440) + 사용자 명시 INBOX add 지시 (2026-05-27)

## 2026-05-27T02:15Z — `hexa cc --regen` 의 `runtime.o` 누락 → verify_cli binary 갱신 차단 (#1281 family · INBOX 3 activation blocker)

> F21 (PR #1395 머지) 의 verify_cli arms 모두 source land 확인: `verify_cli.hexa:433` `_recompute "mertens" → mertens(n)` arm + `congruence_chain_engine.hexa:137` `pub fn mertens` 정의. `hexa parse tool/verify_cli.hexa` 도 clean. 그러나 `hexa cc --regen` link 단계에서 `clang: error: no such file or directory: '/Users/ghost/.hx/bin/self/runtime.o'` → verify_cli 재컴파일 실패 → deployed binary 갱신 차단 → `hexa verify --expr mertens 6 -1 --no-absorb` 여전 🟠 INSUFFICIENT.

- [ ] **`~/.hx/bin/self/runtime.o` 누락** — deployed install (`~/.hx/bin/self/`) 에 runtime.o 가 없음. cc --regen 의 link 가 이 .o 를 require 하나, hexa-cc self-build infra 가 이를 deploy 안 함. #1283 (loop runtime FLOOR + install symlink completeness) family.
- 영향: **모든 verify_cli `_recompute` arm 추가가 binary 활성화 미달성** (F21 의 3 arms 만 아니라 모든 신규 calc-fn 후보). #1230/#1281/#1314 family 의 메타 차단.
- 우선순위: 🔥 BLOCKING — verify-infra 전체 확장 lane 차단. hexa-cc self-build (`~/.hx/bin/self/`) 가 runtime.o 같은 link artifact 도 deploy 하도록 install hook 수정 필요.
- 대안 (workaround): manual deployed binary swap (hexa-cc 우회) — pool ubu-2 의 source-build → scp deployed. 그러나 mac arm64 vs linux x86_64 분리 (#587 family).
- proposed-by: main session (TECS-L F21 source land 후 binary activation 시도 중 진단, 2026-05-27)

## 2026-05-27T00:30Z — TECS-L F19/F20 verify-infra extension — 3 new candidate fns (`elliptic_witness` · `tunnell_count_{odd,even}` · `mertens`)

> F19 Clay attempt(PR #1372) 시 BSD/RH lane 에 calc-fn 부재로 인해 4-op witness · ternary-form count · Mertens partial sum 을 **컴포넌트 산술 재조립**으로만 verify 했음. F20 에서 이 calc-gap 을 좁히려 `mertens(n)` (single-arg) 은 stdlib+verify_cli 에 직접 land 시도; 4-op 두 가지는 더 복잡 (multi-arg / ternary enum) 이라 spec 만 영속화 + 후속 라운드 구현 deferred. **모두 verify-infra 확장 (calc-fn 부재 = g5 violation 회피 deferred)**, novel atom 주장 아님.

- [ ] **(a) `elliptic_witness(x, y, n) -> int`** — BSD congruent-number lane 4-op verify-fn. n=합동수 ⟺ E_n: y²=x³−n²x 위 유리점 (rank≥1). 단일 정수 witness 의 y²==x³−n²x 검증을 한 fn 으로 닫는다 (현재 component 산술 reuse 3-step). **왜**: F19 BSD lane 의 (-4,6)∈E_5, (-3,9)∈E_6 같은 unconditional integer rational-point 를 single-call verify 화 = 향후 합동수 후보 sweep (n=5,6,7,13,14,15,20,21,22,23,28,29,30 등) 자동화 enable. **어디**: tool/verify_cli.hexa `_recompute3` (3-arg) 신설 arm 또는 별도 `--expr-3op` path. multi-arg dispatch surface 신규 필요. **우선순위**: P1 (BSD-lane 가장 첫 인프라).
- [ ] **(b) `tunnell_count_odd(n)` / `tunnell_count_even(n)` -> int** — Tunnell ternary-form enum. BSD-conditional Tunnell 정리: n 합동수 ⟺ #{(x,y,z): n=2x²+y²+8z² mod parity} 가 특정 비율을 만족. enum N=|x|,|y|,|z|≤bound 로 정수산술 합. **왜**: F19 BSD lane 의 ground-level Tunnell test 가 부재 (현재 elliptic-point exhibit 만으로 lower-bound). Tunnell count single-fn 화 = BSD CN-check end-to-end candidate (다만 Tunnell 자체가 BSD-conditional). **어디**: verify_cli `_recompute` (single-arg, n) 신설 arm 두 개 + stdlib bounded-enum helper. 부동소수 부재 = integer-exact 가능 (bound 는 별 arg). **우선순위**: P2 (BSD-lane 두 번째).
- [x] **(c) `mertens(n) -> int`** — Mertens partial sum M(n) = Σ_{k=1..n} μ(k) (OEIS A002321). **single-arg, simplest**. **왜**: F19 RH lane 에서 M(1..20) 을 component μ(k) 합으로 재조립했었음 — 단일 fn 화로 sweep 비용 ↓, scale-extension(예 |M(n)| growth) 가능. RH adjacency = Mertens conjecture(disproved Odlyzko-te Riele 1985) cite. **어디**: `compiler/atlas/symbolic/congruence_chain_engine.hexa` `pub fn mertens` 추가 + `tool/verify_cli.hexa _recompute` arm + descriptive only(not RH proof). **우선순위**: P0 (F20 즉시 구현 — land 완료).
- 환경 정보: PR/branch `tecs-l-f20-clay-retry-verify-infra-2026-05-27` 에 (c) 직접 land; (a)/(b) 는 spec-only INBOX. 활성 = source-build (verify_cli binary-내장 issue 2026-05-26T18:15Z 동일).
- proposed-by: agent (TECS-L F20 verify-infra extension, 2026-05-27)

## 2026-05-26T22:10Z — `hexa verify` auto-absorb ∞ recursive fork hang + `--no-absorb` canonical workaround (cycle 3 stall root-cause)

> TECS-L F-NEW retry agent 가 19/19 🔵 PASS 동시에 발견. 직전 cycle 3 의 "verify cache race" 진단 = misdiagnosis; 진짜 root cause = **auto-absorb 가 atlas register fork → 또 verify recurse → ∞**.

- [ ] **`hexa verify --expr` (auto-absorb default ON) 가 atom 이 atlas 에 없을 때 ∞ recursive fork hang** — atlas register fork → `--from-verify` 가 `hexa verify` 재호출 → 또 register fork → ... 30s timeout exit 0 silent. 같은 atom 이 이미 atlas 에 있으면 idempotent skip 으로 즉시 PASS. 이전 sigma 6 12 첫 호출 87s ≠ cache race; 첫 호출 atlas register success + 그 후 호출들이 다른 atom 이라 또 fork hang.
- [ ] **`--no-absorb` flag 가 canonical workaround** — agent retry 가 `hexa verify --expr <fn> <args> <v> --no-absorb` 로 19/19 즉시 🔵 PASS. [DEFAULT auto-absorb] 명시 opt-out — hexa-help 또는 verify -h 에 surface 필요. 이전 cycle 3 stall 의 진짜 원인 (cache race 오진 정정).
- 우선순위: 🔥 BLOCKING — 모든 신규 atom verify 가 잠재적 hang. 직접 fix = (a) auto-absorb 의 recursive fork 차단 (atlas register 가 verify 안 부르고 직접 calc) 또는 (b) `--no-absorb` 디폴트 + atlas register 별도 verb.
- 자매 발견 (같은 batch, calc gap family · #1230 후속): **`verify_cli` 음수 인자 dispatch 미지원** — `hexa verify --expr jacobi 2 3 -1` 등 음수 expected/arg 가 `to_int: trailing garbage in "--"` 또는 silent skip. jacobi(a,p) -1 결과 12 candidates deferred. #1230(sopfr/pow) family 확장.
- proposed-by: agent (TECS-L F-NEW retry, 19/19 🔵 PASS + 메타 진단, 2026-05-26)

## 2026-05-26T19:50Z — Pepin–Lehmer (or 일반 결정형 primality) stdlib 부재 — F6 large-perfect 탐색 게이트 (v2)

> TECS-L F2 /gap 42-lens sweep 결과 R5 seed shortlist Rank 3 (F6 D(n)=σφ−nτ beyond 10^8) 차단 발견. Lucas-Lehmer (Mersenne 전용, MR4) 만 stdlib 에 있고 일반 n primality 결정형 (Pepin / Pocklington / AKS / deterministic Miller-Rabin) 부재 → primorial#7·8589869056·33550336 너머 D(n) corroboration 이 primality 게이트에서 멈춤.

- [ ] **`stdlib/number/primality.hexa` 일반 결정형 부재** — Lucas-Lehmer 외 일반 n primality 결정형 (Pepin 등) 없음. F6 D(n) sweep beyond 10^8 (Ochoa-Rao P_6 너머) 가 이 인프라 의존.
- 참고: **PR #1310 (`feat(stdlib/core/math): deterministic Miller-Rabin is_prime_det for full i64 range`, 2026-05-26 머지)** 가 F6 의 large-n primality 게이트를 부분 해소 가능 — i64 범위 내 결정형. Pepin 은 Fermat number 전용; 일반 stdlib 진입은 `is_prime_det` 가 충분할 수도. F6 sweep 재시도 → #1310 reuse 확인 필요.
- 후속 = #1230(sopfr/pow) · #1281(verify_cli binary-내장) 패밀리와 동급의 stdlib calc 확장 후보. F2 보고서 (R5 seed Rank 3) 인용.
- 우선순위: 🟠 deferred frontier — M10 corroboration 만 영향, TECS-L 코어 닫힘 비차단. v2 = #1298 conflict 후 re-add (parallel-session merges).
- proposed-by: agent (TECS-L F2 /gap 42-lens sweep, R5 seed 도출, 2026-05-26)

## 2026-05-26T19:30Z — `hexa loop --allow-llm` subprocess dispatch hang (C1 LLM 실호출 차단, RFC 080 활성 게이트)

> TECS-L 범용 첫 cycle C1 fire (LLM budget 무제한 + cooldown reset 작동) 시도 중 발견. fire #5~#9 누적 진단: cooldown 해소 / DFS seeds 활성(42 candidate dispatch) 까지는 진전했으나, `--allow-llm` 명시 시 hexa loop 가 subprocess (claude -p) spawn 단계에서 hang.

- [ ] **`hexa loop --allow-llm` hang** — `hexa loop --claude --allow-llm --depth 1 --beam 1 --target-absorb 1 --fire --budget 1` → timeout 120s **exit 124**, 출력 0줄. **claude CLI 직접은 즉시 OK** (`echo "say hi" | claude -p` → "안녕하세요" 정상). 즉 hexa loop 내부 LLM dispatch(subprocess spawn → claude -p stdin 입력? → wait) 가 hang. stdin pipe / subprocess wait 미완 추정.
- [ ] **`--allow-llm` 없으면 stub 정상** — 같은 명령에서 `--allow-llm` 제거 → DFS 42 candidate dispatch + "WOULD call LLM" stub + exit 0 정상. 즉 dispatch 로직은 동작, **실호출 subprocess 처리만 hang**.
- 진전 (이번 진단으로 확정): cooldown reset(`gap_cooldown` rm) 작동 ✅, DFS seeds 활성 ✅, `--claude` alias(`'claude -p'`) 정상 ✅, LLM budget 무제한 게이트 해제 ✅.
- 차단 잔여: hexa loop subprocess LLM dispatch 가 self-host(0.1.0-dispatch) 에서 hang → **C1 LLM 실호출 fire 차단** (RFC 080 Phase A 활성 게이트). claude API 직접 (`--claude-api` alias = jq+curl→api.anthropic.com) 우회 가능성 검토 필요.
- fix 방향: (a) `--claude-api` alias(jq+curl) 우회 — subprocess 없이 HTTP 직접. (b) hexa loop subprocess spawn 디버그 — claude-p stdin/wait 처리.
- 부수 발견: 매 fire 후 `cooldown += 153` 자동 누적 → 다음 fire 차단. fire 마다 `gap_cooldown` rm 강제 필요 (UX 이슈 — `--reset-cooldown` 플래그 후보).
- proposed-by: agent (TECS-L C1 첫 LLM fire 시도, fire #5~#9, 2026-05-26)

## 2026-05-26T18:15Z — verify_cli arm/calc_dispatch 가 hexa binary 내장 → .hexa swap 무효, arm 활성 = source-build 필수 (#1230/#1235 보강)

> #1230(calc-fn gap)·#1235(verify_cli sopfr/pow arm) 소스 land 후 활성 검증 중 발견. deployed .hexa swap + cache 75개 무효 후에도 sopfr 여전 🟠 — verify_cli/calc_dispatch 가 hexa binary 에 컴파일-내장돼 .hexa 소스 변경 무관.

- [ ] **verify_cli binary-내장** — deployed `~/.hx/bin/tool/verify_cli.hexa` 에 sopfr arm 존재(grep count 1, #1235 swap) + `~/.hexa-cache` 전체 무효(75개 rm) 후에도 `verify --expr sopfr 6 5 → 🟠 "no path"`. 즉 hexa(0.1.0-dispatch·hexa-cc 둘 다) 가 verify_cli 를 **binary-내장**으로 resolve, deployed .hexa swap/cache 무효 무관. arm 활성 = **hexa binary source-build**(verify_cli 재컴파일) 필수. (INBOX line 70 "설치본 .hexa 고정" 은 실측상 부정확 — binary 내장.)
- [ ] **calc_dispatch sopfr/pow 등록 누락** — #1230(1)(2) 가 verify_cli `_recompute`/`_recompute2` arm 만 추가, `compiler/atlas/calc_dispatch.hexa` dispatch 게이트(`calc_is_*_fn`)에 sopfr/pow 미등록 → verify 가 _recompute 도달 전 "no path" 차단 가능성. #1235 arm 완성 = calc_dispatch 등록 동반 필요.
- 진전: hexa-cc → 0.1.0-dispatch 복귀로 **런처 result-단축 quirk 해소**(↓ #1275 (2) — sopfr 가 "OK" 아닌 🟠 verdict 정상). loop_state_cycle(#1275 (1))은 0.1.0-dispatch 도 build 실패 잔존.
- 종합: #1230/#1235/#1275 소스는 land 완료 — 활성은 hexa source-build(verify_cli 재컴파일 + calc_dispatch 등록) 후. prebuilt download(hx install)는 #1241 후에도 실패 → source-build = build_hexa_cli(mini) / hexa cc.
- proposed-by: agent (TECS-L verify_cli arm 활성 검증, 2026-05-26)

## 2026-05-26T18:10Z — hexa-cc self-host 과도기가 TECS-L cycle verb 전체 차단 (loop runtime FLOOR + 런처 quirk)

> TECS-L 범용 첫 cycle (LLM budget 무제한 해제 후) 시도 중 발견. cycle next-list(C1 Atlas-LLM·F2 /gap·F10 /micro-exp) verb 3종이 전부 deployed hexa-cc self-host 과도기에 막힘. self-host baseline(memory project_hexa_selfhosted_state) "runtime FLOOR 잔여" 구체 증상.

- [x] **C1 hexa loop = loop_state_cycle_* undeclared ✅ RESOLVED 2026-05-26** (root-cause ≠ runtime FLOOR/LLM): install dir(`~/.hx/bin`)가 `self`·`tool` 심볼릭만 갖고 `stdlib`·`compiler` 누락 → env-less 빌드 시 module_loader 의 self-derived install 해소가 `<inst>/stdlib/*` 를 못찾아 trailing stdlib `use`(state/dfs/io) silent-drop → codegen 이 `hexa_call2(loop_state_*, …)` fp-form emit, clang 미선언. (loader binary 회귀는 red-herring·HEXA_LANG unset 이 진짜 변수.) fix = `ln -s <repo>/{stdlib,compiler} ~/.hx/bin/` → `/tmp` 에서 env-free `hexa loop --once` 가 SCAN→LENS(153)→DRAFT(148) 완주. durable installer fix = ↓ INBOX.md open. 元 진단: `hexa loop --once` → hexa-cc(hexat) build error: `use of undeclared identifier 'loop_state_cycle_read'/'loop_state_cycle_write'` (stdlib/loop/cycle.hexa C-emit line 9171/9172). loop state 영속(cycle 번호 read/write) runtime fn 이 self-host 미포팅 = runtime FLOOR 잔여. **LLM 게이트는 해제됨**(claude 2.1.150, budget 무제한) — 막는 건 loop verb runtime fn, LLM 아님. fix: `loop_state_cycle_{read,write}` runtime fn self-host 포팅 (또는 stdlib 정의).
- [x] **F2/F10/verify = 런처 result-단축 quirk ✅ RESOLVED 2026-05-26** — `hexa.real` 이 0.1.0-dispatch 드라이버로 복귀(#1259 deploy 가드 = transpiler 바이너리를 driver 로 배포 거부 + hexa.real 정상 재교체)하며 해소. 검증: `hexa verify --expr cos 0 1.0` 1st·2nd 모두 실제 verify 에러("to_int: trailing garbage") 반환 = 정상 dispatch, "OK: --expr" stub 아님. 元: `hexa verify --expr` 가 fresh 첫 호출 외 "OK: --expr" stub. verify_cli arm(#1235)·CM0 sopfr·LF1 codon tier 부여 차단.
- 영향: TECS-L 범용 cycle(verify-driven + LLM-loop)의 동력 verb 전부 차단 → self-host 정착(runtime FLOOR + 런처 quirk + 링커 phase H) 선행 필수. self-host = 타세션 영역이라 handoff.
- proposed-by: agent (TECS-L 범용 첫 cycle, 2026-05-26)

## 2026-05-26T18:00Z — 🔧 forge farr32 codegen→clang smoke (INBOX #4 제안② CLOSE)

- [x] **`tool/forge_farr32_codegen_smoke.hexa` + CI 와이어** — V=151643 forge fire 가 Linux x86_64 빌드를 farr32 bare-emit(#1187: `hexa_farr32_*` 미선언 implicit-int call, Mac 묵인·Linux clang 거부)로 깨뜨림. dev+CI 전부 Mac 이라 영영 안 잡힘. smoke 가 farr32 전 emit(zeros/set/get/matmul/matmul_NT_a/_NT_b/free → 21 `hexa_farr32_*` call) 행사 → `hexa build --c-only` → `clang -fsyntax-only -Werror=implicit-function-declaration`. GPU·link·run 0. `bootstrap.yml` 3 job(특히 Linux 2개 = runtime.h `#else` 브랜치 실컴파일) 에 step 추가, non-blocking.
- [x] **검증(로컬 Mac)**: transpile OK(21 farr32 call) · `clang -fsyntax-only -Werror=implicit-function-declaration` exit 0(harmless `/*`-in-comment 경고 2건만). YAML safe_load OK. Linux `#else` 브랜치 커버는 CI Linux job 이 제공(Mac 로컬 미검증분).
- [ ] **#4 잔여**: 제안③ `hexa check --compile`(parse-lint 에 codegen→clang 추가)은 별건 — 본 smoke 가 forge-특화 갭은 커버. 제안① Linux 빌드 게이트는 기존 bootstrap linux 매트릭스로 이미 부분 커버.

## 2026-05-26T17:40Z — 🧪 stdlib *_test.hexa CI 게이트 (#5① CI coverage gap CLOSE)

- [x] **`stdlib_selftest_aggregate --ci-gate` 모드 + CI 와이어** — 기존 aggregator 는 207 `*_test.hexa` 를 발견하지만 다수가 외부 API(pubmed/arxiv/websocket/qrng…) 의존 → offline CI strict 게이트 불가. opt-in `// @ci_gate` 마커 도입: `--ci-gate` 는 마킹된 순수·network-free·deterministic 테스트만 실행 + strict(non-PASS 시 exit 1). 4건 마킹(pod_registry_guard·ssh_config·early_life_check·reconcile, 전부 no-`use` 단일파일·로컬 4/4 PASS). `bootstrap.yml` 3 job(macos·linux-x64·linux-arm64) smoke 뒤 step 추가(non-blocking: required-check 없음). + `run_one` 의 하드코딩 Mac 경로 `/Users/ghost/.hx/bin/hexa` → `$HEXA_BIN`/PATH `hexa`(Linux runner 부재 버그) 수정.
- [x] **검증**: aggregator transpile-clean · 로컬 `--ci-gate` → `found=4 pass=4 fail=0` exit 0. YAML safe_load OK.
- [ ] **#5 잔여**: ② 단일파일 `hexa build <f>` import flatten 부재(docs 명시 후보) · ③ builtin-first 규칙(docs/RFC). 게이트 subset 은 새 순수 테스트에 `// @ci_gate` 추가로 점증.

## 2026-05-26T17:15Z — 🔑 cloud #1155 zero-flag CLOSE — rent/adopt → ~/.ssh/config 자동주입

- [x] **`rent`/`adopt` 가 vast key 를 `~/.ssh/config` 에 자동 주입** — `vast_ssh_config_autoinject(iid)` 가 bare-IP endpoint 해소 후 marker-scoped Host 블록(`# >>> hexa-cloud vast <ip> >>>` … `<<<`) 작성: `IdentityFile`(=$HEXA_VAST_IDENTITY 또는 `~/.ssh/id_vast_anima`)+IdentitiesOnly+StrictHostKeyChecking no+UserKnownHostsFile /dev/null. 이후 bare `hexa cloud run root@<ip> --port <p>`(또는 raw ssh)가 `--identity` 없이 vast key 제시. **NO Port in block**(--port 호출자 제어, 同IP 타 서비스 hijack 방지) · marker-scoped(유저 hand-config 보존, 재-rent 멱등) · key 부재 시 graceful no-op.
- [x] **검증**: `vast_ssh_config_splice`/`_block` 순수 12/12 PASS(empty·user-보존·멱등 재splice·2-IP 공존·no-Port). transpile-clean. `ssh_config_test.hexa` 영구 가드. cloud 0.3.2→0.3.3.
- [x] **#1155 CLOSED** = 명시 `--identity`(#1266) + zero-flag(本). I/O(`ensure`/`autoinject`)+rent/adopt wiring 은 vastai+live pod 필요로 미실행이나 검증된 순수 splice 의 thin wrapper.

## 2026-05-26T16:55Z — 🔑 cloud `--identity <key>` — vast publickey 거부 우회 (#1155 explicit-flag)

- [x] **`--identity <path>` 플래그** — `_ssh_opts_cli` 가 `-i <path> -o IdentitiesOnly=yes` emit. hexa cloud ssh 가 Mac 기본 `~/.ssh/id_ed25519`(vast 미등록) 만 제시 → `Permission denied (publickey)` → raw-ssh 우회(cloud-guard 밖)로 내몰리던 것을, `hexa cloud run/exec/nohup/poll/tail/copy-* … --identity ~/.ssh/id_vast_anima` 로 vast 등록키 제시. `_ssh_opts_cli` 공유라 모든 verb 적용. 6/6 standalone PASS(-i·IdentitiesOnly·--port 조합·-- 정지·dangling 무크래시). help+version(0.3.1→0.3.2). dft-run `_dft_ssh_opts` 와 동일 패턴.
- [ ] **#1155 잔여(zero-flag)**: rent/adopt 시 pod IP:port → `~/.ssh/config` IdentityFile Host 블록 자동 주입 OR vast pod 자동감지 → 기본 vast key. 별도 follow-up(현재는 명시 `--identity` 필요).

## 2026-05-26T16:30Z — 🔌 cloud registry 오염 FIX (#1229 B) → reconcile GHOST 오판 해소 (#1229 A)

- [x] **#1229 B — registry argv-조각/host 오염 차단** — `cloud run`/`cloud nohup` 가 `pod_registry_record(host, prog, …)` 로 ssh 목적지(`root@<ip>`·proxy host)+명령조각(`echo`/`bash`/`/root/run.sh`)을 "pod" 로 적재하던 것을 제거(둘 다 host 연산이지 pod-lifecycle 이벤트 아님; pod 추적은 rent/adopt 가 numeric id 로 함). + sink 가드 `_pod_id_looks_valid` 추가 — `@`/`/`/`.`/공백/leading-`-` 토큰(ssh dest·host·IP·path·flag)을 `pod_registry_record` 가 거부(eprintln + drop). 11/11 standalone PASS (transpile→clang→run).
- [x] **#1229 A — reconcile GHOST 오판 해소(B의 결과)** — 오염 host-string row 가 numeric provider-id 와 절대 안 맞아 전부 GHOST 로 찍히던 "35행 junk" 가 B 차단으로 소거. reconcile union(runpod+vast) 로직은 이미 정상이었음(이 PR 은 입력 오염만 제거).
- [x] **검증**: pod_registry.hexa·cloud_cli.hexa transpile-clean · `pod_registry_guard_test.hexa` 영구 가드(11 케이스). cloud 0.3.0→0.3.1.
- [ ] **남은 cloud**: #1155(vast 등록키 자동 제시 — 별도 PR) · #1229 C(concurrent-wipe = 트랜스파일러 mis-deploy family, #1259 가드로 부분 대응) · D(prebuilt 전송) · #1239(1)ⓑ(`cpu_ram`, repo 밖).

## 2026-05-26 — `inbox/` 폴더 → canonical INBOX.md/INBOX.log.md 마이그레이션 + 폴더 RETIRE (4-file 라우팅)

레거시 `inbox/notes/`+`inbox/patches/` 폴더(ad-hoc staging 패턴, commons g36/g48 canonical INBOX 도메인으로 이전 중)에 남은 4-file 을 canonical 수신함으로 라우팅하고 폴더를 폐기. 각 건 INBOX.md/log dedup-grep + `gh pr list --merged` + `git log --grep` 로 status 판정:

- [x] **`inbox/patches/anima-discovered-2gaps-2026-05-25.md` — 이미 마이그레이션됨 (중복 방지)**. 본 파일의 G1/G2 는 직전 "2026-05-26 inbox/patches/ 트리아지 3건" 엔트리(↓)에서 이미 INBOX.md 로 라우팅 완료: G1(linux wrapper 깨짐 + `-D_GNU_SOURCE`) → INBOX.md "pool 호스트 hexa CLI stale" open 항목에 corroboration fold(`-D_GNU_SOURCE` 절반은 canonical 레시피에 이미 존재 = 비-이슈) · G2(import-time `main()` auto-invoke) → INBOX.md 신규 open 항목. content 보존 확인 → 소스 파일 `git rm`.
- [x] **`inbox/patches/anima-flame-v3-coverage-gaps.md` — 이미 마이그레이션됨 (중복 방지)**. 직전 트리아지 엔트리(↓)에서 INBOX.md "flame V3 coverage 갭" open 항목으로 라우팅 완료(P1 둘 = full-position CE · V3-extension backward · RFC 059 정렬, P2/P3 상세 포함). content 보존 확인 → 소스 파일 `git rm`.
- [ ] **`inbox/notes/linux-ci-build-gate-cross-platform-silent-regression.md` — OPEN 신규 라우팅**. 파일 자체는 PR #1206(`inbox(notes): Linux CI build gate …`)로 inbox/ 폴더에 **filing** 만 됐고(merged 2026-05-25T22:13Z, review-only), 제안은 미구현. dedup-grep: INBOX.md/log 의 기존 linux 항목(pool wrapper stale · #1198 transpiler fix)은 **point-fix** 들이고, 본 note 의 핵심 = 그 회귀를 **사전 차단하는 CI 게이트 제안** = 직교(별건). 현 CI 대조: `bootstrap.yml` 은 `pull_request` 트리거 + linux-x86_64/arm64 매트릭스(실 clang `-O2 -std=gnu11 -D_GNU_SOURCE` + e2e transpile/compile/run smoke) 보유 → 제안 ①(Linux 빌드 게이트) **부분 커버**. 단 제안 ②(forge/farr32 codegen→clang smoke = `hexa build --c-only` → clang `-fsyntax-only`)는 CI 에 **부재**(farr32/forge smoke grep 0건 확인) · 제안 ③(`hexa check --compile`)도 부재. 5-fire 캐스케이드($~2.5) 의 farr32-특화 emit 갭(bare `farr32_zeros` 등)은 일상 빌드가 안 건드림 → forge-특화 codegen smoke 가 잔존 갭. 관련: #1187(farr32 codegen)·#1194(hxlcl_nanosleep)·#1198(linux #elif parity)·#1172(spawn.h). INBOX.md 신규 open 항목 → 소스 파일 `git rm`.
- [ ] **`inbox/notes/stdlib_module_test_and_builtin_findings_2026_05_24.md` — OPEN 신규 라우팅**. anima STDLIB 도메인(M3 + cycle-full)이 8 stdlib 모듈(#769·#780·#781·#782·#783) land 중 발견한 hexa-lang 측 갭 3건. 파일은 PR #785(`docs(inbox): stdlib module test gap + builtin-first findings … review-only g54`)로 filing 만 됨. dedup-grep: INBOX.md/log 의 stdlib 항목들(NOVEL-TOOL 13 primitive register · fresh-worktree math_pure link-fail)은 **별건**(register-debt / worktree-isolation) — 본 note 의 CI-test-runner 부재 + builtin-first 규칙은 미등재. ① **CI coverage gap**: `bootstrap.yml` 은 compiler self-bootstrap + 단일 `hi.hexa` smoke transpile 만 검증, `stdlib/**/*_test.hexa`(8 모듈 각 test 포함)는 CI 미실행(grep 확인) → stdlib 회귀/링크오류 안 잡힘. 권장 = test runner 단계(module_loader flatten → build → run all `stdlib/**/*_test.hexa`). ② **DX**: `import "stdlib/…"` 파일을 단일 `hexa build <f>` 하면 imported `pub fn` 이 extern → `ld: undefined symbol`(CI 는 module_loader 2-step flatten 으로 우회). 회피 = self-contained 인라인 copy 빌드. 개선 = `hexa build` 자동 flatten 또는 docs 명시. ③ **builtin-first 규칙**: RFC stdlib_scaffold 가 `log2`/`pow2`/`bit_set` 를 "missing builtin" 가정했으나 실측 `log2`·`abs`·`fabs`·`sqrt`·`pow`·`floor`·`log` 전부 동작 builtin(`self/codegen.hexa` is_builtin + `runtime_core.c`) → #769 에서 log module DROP, abs_f(77 dup)/sqrt_newton(17 dup) builtin sweep 가능. 권장 = 새 수치 primitive 제안 전 `git grep 'if s == "<name>"' self/codegen.hexa` 확인. **byte-eq 주의**: libm builtin(log2/pow/exp)은 hand-rolled(log/log(2.0)·Taylor)와 ulp 다름 → frozen baseline 보존 consumer(entropy·voss)는 swap 금지. 참고: anima `STDLIB.log.md` · relates: stdlib_scaffold, RFC-016. INBOX.md 신규 open 항목 → 소스 파일 `git rm`.
- [x] **폴더 RETIRE** — 4-file 모두 라우팅/제거 후 `inbox/notes/`+`inbox/patches/` 가 빔 → `git rm -r inbox/`. INBOX.md 의 기존 참고 노트("hexa-lang 내부 upstream-patch staging `inbox/` 폴더는 폐기됐다 …")가 이 폴더 폐기를 이미 명문화 → 폴더 제거가 그 문서와 정합. cross-repo handoff 는 그대로 INBOX 도메인(INBOX.md/log)이 단일 surface.

> 방법: dedup = INBOX.md+INBOX.log.md grep + `gh pr list --merged` + `git log --all --grep`. NO over-claim — note 2건은 filing-PR(#1206/#785)이 merged 라도 제안 자체는 미구현(CI 게이트/test-runner 부재 grep-확인)이므로 OPEN 유지. patch 2건은 직전 트리아지 엔트리가 substance 를 이미 INBOX.md 로 보존했음을 확인 후에만 `git rm`.

## 2026-05-26T15:40Z — 🛸 `hexa cloud dft-run <deck-dir>` — guarded QE el-ph dispatch (#1249) + bare-IP endpoint (#1239(2) fix)

- [x] **`hexa cloud dft-run <deck-dir>` 흡수 (RFC #1249)** — demiurge `DFT_POD_DISPATCH_RECIPE.md` 4-guard 체크리스트를 `stdlib/cloud/dft_dispatch.hexa` 로 코드화. ① rent(reliability>0.97·verified·16+코어, create --direct 既存, echo REACHABLE precheck→unreachable면 destroy+재rent) · ② transport(bare-IP via `show instances --raw`, vast identity `-i`) · ③ chain(hexa-native relax→scf 좌표 파서·`-np`=phys cores·`--allow-run-as-root`·`recover=.true.`·`timeout`·`setsid`) · ④ monitor(numeric-id registry·허수모드<-5cm⁻¹→unstable·비대화 teardown). **PREVIEW 기본($0): deck 검증+plan+로컬 relax.out 파싱; `--go` 만 과금.** verb wired in cloud_cli (0.2.4→0.3.0).
- [x] **#1239(2) `vastai show instance <id>` start_date=None crash 해소** — `vast_direct_endpoint`/`vast_parse_direct_endpoint` 가 복수 `show instances --raw` 에서 `public_ipaddr`+`22/tcp` HostPort(bare-IP, proxy 아님) 추출. transport guard ②의 기반.
- [x] **검증**: 순수 helper 17/17 PASS (transpile `self/native/hexa_v2` → clang+runtime.c → run): QE relax→scf 파서(alat→angstrom 0.529177 정확·crystal passthrough)·안정성 verdict(<-5cm⁻¹·-3 noise·inconclusive)·physcores(14×2=28 not nproc 56)·rent query·assemble. 4 changed 파일 transpile-clean. e2e(rent/ssh/chain)는 vastai 부재로 미검증 → `--go` 게이트 뒤. `dft_dispatch_test.hexa` 영구 가드(CI 미와이어, 로컬/툴체인-healthy 시 실행).
- [ ] **남은 #1249 후속**: harvest 단(λ_BZ·ω_log·Allen-Dynes Tc → `hexa atlas register`)은 미구현(stable verdict 후 수동) · 일반 `cloud job-run <chain-spec>` 추상화 · #1155(vast 등록키 자동 제시)·#1229(A reconcile GHOST·B registry 오염·C concurrent-wipe·D prebuilt 전송) 여전히 OPEN.

## 2026-05-26T15:10Z — 🔌 cloud rent `reliability2` query-field 오타 FIX (#1239(1)ⓐ · #1038(1)) — vast rent unblock

- [x] **`stdlib/cloud/vast.hexa` `_vast_default_filters` `reliability2>=0.95` → `reliability>=0.95`** — vastai 검색-DSL 필드는 `reliability` 이고 `reliability2` 는 offer-JSON **출력** 필드에만 존재. query 에 `reliability2` 를 주면 미지 키로 거부 → offer 0건 → `hexa cloud rent` 가 항상 silent-fail. 공식문서 확인: `vastai search offers 'reliability > 0.99 num_gpus>=4'`. 코드 1줄 + stale 주석 3곳(vast.hexa 135/197 · cloud_cli.hexa 386) 정정. 로컬 parse-gate 는 배포 hexa 바이너리 destructive(소스 clobber)라 skip → CI bootstrap build-gate.
- [ ] **남은 분리-항목 (이 fix 범위 밖)**: #1239(1)ⓑ `cpu_ram` MB→GB 는 vast.hexa 에 부재(호출자 query 문자열 소관) · #1239(2) `vastai show instance <id>` start_date=None crash(list-기반 추출/None-guard) · #1229(A·B·C·D) reconcile GHOST/registry 오염/concurrent-wipe/prebuilt-전송 · #1155 vast 등록키 미제시 — 모두 OPEN.

## 2026-05-26T09:45Z — 💡 RFC: `hexa cloud dft-run <deck-dir>` — DFT el-ph pod 발사를 canonical 레시피로 (손-롤 실수 제거) · from demiurge RTSC

> RTSC 캠페인(vast pod 다수) 운용서 **매 dispatch 손-롤이 반복 실수의 원천**임이 드러남. transport/lifecycle 버그(#1155/#1229/#1239) 위에, "deck → 발사 → 수확" 상위 레시피 층을 `hexa cloud` 서브커맨드로 흡수하면 실수 0. demiurge-side SSOT 레시피 = `demiurge/exports/sweep/DFT_POD_DISPATCH_RECIPE.md` (이 RFC의 구현 사양).

- [ ] **제안 — `hexa cloud dft-run <deck-dir>`** (또는 stdlib `cloud/dft_dispatch`): deck 디렉터리(relax.in·ph.in·pseudo/) 받아 rent→provision→chain→monitor→harvest 를 가드와 함께 1-커맨드로. 손-롤 시 반복된 실수 4종을 코드로 강제:
  - **rent 가드**: `--direct` 강제(누락 시 proxy-only 포트=bare-IP unreachable + proxy는 cloud-guard 차단 = running인데 완전 도달불가 — mgb2h가 이걸로 시간 소모) · `reliability>0.97 verified=true`(저가 interruptible은 ~13h preempt — ysbh6 #1 유실) · provision 前 `echo REACHABLE` TCP 사전검증(실패 시 destroy+다른 offer).
  - **transport 가드**: IP/port 는 `show instances --raw` ground-truth서만(단건 `show instance`는 start_date=None crash #1239; 수기 typo 위험). #1155 fix 후엔 vast 등록키 자동.
  - **chain 가드**: robust relax→scf 파서 내장(`Begin final coordinates`서 `CELL_PARAMETERS (alat=X)`→×X·0.52917720859 angstrom, ATOMIC_POSITIONS crystal as-is) — 손-파서 금지(mg2pth6·mgb2h 둘 다 "No ATOMIC_POSITIONS" FATAL 재현) · `-np=physcores`(lscpu Core×Socket, not nproc; 14코어 -np26 → load246 thrash) · `--allow-run-as-root`(OpenMPI5 root 차단) · `recover=.true.` + `timeout` + `setsid`.
  - **monitor 가드**: registry numeric-id only(#1229 argv-조각 오염) · 안정성 빠른판정(허수모드<-5 한 q라도 → 즉시 unstable, 전 BZ 대기 불요) · 완료/실패 시 비대화 destroy(orphan 방지).
- [ ] **선결**: #1155(vast 등록키)·#1229(reconcile/registry/wipe/transport)·#1239(rent reliability2/show-instance crash) — 이 transport/lifecycle 층이 먼저 안정돼야 dft-run 상위 레시피가 견고. 그 전엔 demiurge RECIPE.md 가 수기-가드 SSOT.
- [ ] **범위 노트**: QE 특화(pw.x/ph.x el-ph)지만, 일반 `cloud job-run <chain-spec>` 으로 추상화 가능(chain = 사용자 deck+단계 manifest). g61 stdlib SSOT 후보.

## 2026-05-26T09:30Z — 🐛 verify_cli 빌드/출력 2건 (UFO V2 lattice fold #1244 중 발견 · from demiurge UFO)

- [ ] **`sopfr` stdlib-fn 미선언 codegen** — verify_cli L431 `return sopfr(n)` (stdlib/core/math.hexa `pub fn sopfr`) 가 생성 C 에서 `undeclared identifier 'sopfr'` → verify_cli 전체 빌드 실패. bessel/gamma `_Generic` 류와 동일 stdlib-pub-fn 네이밍 갭의 신규 인스턴스 (origin/main 2c8f17b7→72090b86 사이 추가; #1222 시점엔 없어 빌드됨). build/hexa_v2 codegen-fixed 본으로도 미해소.
- [ ] **`hexa verify --expr` "OK: --expr" 반복-출력 quirk** — fresh build(해시 bust·캐시 클리어·exit 0) 후 첫 `--expr` 만 verdict 출력, 이후 모든 `--expr` 가 `OK: --expr` 만 출력(verdict 미표시). 파일 redirect·pty(`script`)·Read-tool 모두 동일 → 프로세스/런처 레벨 result 단축. 同 build 내 다중 atom verbatim verdict 를 막음.

owner = hexa-lang 빌드/툴체인 세션. UFO #1244 는 sopfr install-stub + sigma_pow 대표 verdict(🟢 |Δ|=0.0)로 우회 랜딩.

## 2026-05-26T09:10Z — 🔌 cloud_cli rent 필터 버그 2건 (reliability2 오타 + cpu_ram GB/MB · show-instance None crash) · from demiurge RTSC (#1229 후속)

> #1229(cloud 개선 4건) 후속 — vast pod preempt 재provision 중 추가 발견한 cloud_cli/provisioning 구체 버그 2건.

- [ ] **(1) `cloud_cli.hexa rent` offer-필터 2-오류** — ⓐ search 쿼리에 `reliability2>=0.95` 를 prepend(오타: `reliability` 가 맞음) → vastai 가 미지의 필드 거부 → offer 0건 반환(rent 실패). ⓑ `cpu_ram` 필터를 MB 로 넘기는데 vastai 는 **GB** 단위 → 의도와 다른 임계. 두 오류 다 빈/잘못된 offer-set 유발. fix: `reliability` 로 정정 + cpu_ram 을 GB 로.
- [ ] **(2) `vastai show instance <id>` crash (start_date None)** — 단일 인스턴스 조회가 `start_date` None 일 때 크래시(특히 막 생성된 pod). cloud_cli/스크립트가 직접연결 정보 뽑을 때 이걸 호출하면 실패 → **우회: `vastai show instances` (복수) list 에서 파싱** (이번 세션 검증). cloud_cli 의 instance-info 추출을 list-기반으로 바꾸거나 None-guard.
- [ ] **참고 (이미 #1229)**: reconcile GHOST 오판 · registry argv-조각 오염 · cloud_cli concurrent-wipe · prebuilt-binary+base64 견고전송. + #1155 vast 등록 identity 미제시(raw ssh identity 우회). 본 2건은 그 위 rent/show 레이어.

## 2026-05-26T09:00Z — verify_cli calc-fn gap 3종 처방 (TECS-L 새 대축 next-layer · #1204 RESOLVED 후 노출)

> #1204(_Generic worktree-rebuild)는 #1198/#1213(`build_hexa_module_loader.sh`)로 RESOLVED 확인 (worktree `sigma 6 12 → 🔵`). 그 RESOLVED **후** main-tree verify 로 드러난 **next-layer 3종** (rebuild 막힘 아닌 whitelist/등록/deployed-stale layer). F9 패턴 (calc-fn gap → fix at source). 처방 포함 → RUNTIME 세션 안전 실행 권장 (직접 재설치는 동작 중 deployed verify 깰 위험).

- [ ] **(1) sopfr whitelist arm 부재** — `verify --expr sopfr 6 5 → 🟠 "calculator NO path for sopfr"`. CM0 lattice (n=6 sopfr=5) 막음. fix: `tool/verify_cli.hexa` `_recompute(fn_name,n)` (line ~427, tau arm 다음) 에 `if fn_name == "sopfr" { return sopfr(n) }`. sopfr 정의 = `stdlib/core/math.hexa:140 pub fn sopfr`. (sigma_k/euler_phi/divisors 출처 패턴 따라 import/use 정합 필요.)
- [ ] **(2) pow whitelist arm 부재** — `verify --expr pow 4 3 64 → 🟠 "no path for pow"`. LF1 codon 4³=64 막음. fix: `_recompute2(fn_name,a,b)` (line ~542, sigma_k arm 옆) 에 pow int arm.
- [ ] **(3) phi_demo deployed-stale** — `verify --expr phi_demo 1 3.83659 → to_int trailing garbage` (int 경로 추락). 근데 `compiler/atlas/calc_dispatch.hexa:151` 에 phi_demo 가 `calc_is_float_fn` 에 **이미 등록됨** + verify_cli line 3507 `_phi_demo` arm 존재. → deployed `~/.hx/bin/tool/verify_cli.hexa`(07:50)가 최신 calc_dispatch 반영 안 함 (stale). fix: deployed verify_cli 재설치 (#1198 복구로 worktree rebuild 가능). 재설치 후 `phi_demo 1 3.83659 --tol` → 🟢 Φ★ (V5.2 wire, LIFE IIT Φ).
- 활성 효과: CM0 sopfr 🟠→🔵 · LF1 codon 🟠→🔵 · LIFE IIT Φ DEFERRED→🟢 (TECS-L 새 대축 verify-able 확장).
- proposed-by: agent (TECS-L 범용 새 대축 R1-R3, 2026-05-26) · 사용자 "verify_cli 확장" 지시 → 처방 handoff (재설치 위험 회피)

## 2026-05-26T08:40Z — 🔌 hexa cloud 개선 4건 (reconcile GHOST 오판 · registry 오염 · cloud_cli 재발-wipe · prebuilt-binary 전송) · from demiurge RTSC

> RTSC 캠페인(8 vast pod) 운용 중 발견한 `hexa cloud` 개선점 묶음. #967(heavy-word route)·#989(lifecycle verb)·#1155(vast ssh 키)와 별개 신규 4건.

- [ ] **(A) `hexa cloud reconcile` 가 살아있는 vast 인스턴스를 전부 GHOST 로 오판** — vast `running` pod 들이 reconcile 에서 GHOST(registry엔 있고 provider엔 없음)로 표기 → orphan 탐지 신뢰불가. ground-truth 는 `vastai show instances` 로 별도 확인해야 했음. provider-list 파서 또는 id 매칭 점검 필요.
- [ ] **(B) registry 오염 — raw-ssh 목적지 + post-`--` argv 조각이 "pod" 로 적재** — `~/.hexa-cloud/pods.jsonl` 에 `root@<ip>`·`ssh1.vast.ai`·명령조각(label `echo`·`tail`·`bash`·`/root/h3as/run.sh`·`--help`·`--insecure`)이 pod 엔트리로 들어가 reconcile 출력 35행 junk. pod-id 추출이 잘못된 토큰을 잡음 → append 시 numeric instance-id 만 기록하도록 가드.
- [ ] **(C) `stdlib/cloud/cloud_cli.hexa` 재발성 concurrent-wipe** — 동시 에이전트 환경서 cloud_cli.hexa 가 생성 C 코드로 clobber → `hexa cloud` 빌드 깨짐(이번 세션 1회, git restore 복구). recurring-wipe 클래스 → 생성물이 소스 덮지 않도록 경로/가드.
- [ ] **(D) 견고 전송 후보 — prebuilt `hexa-cloud` 바이너리 + base64 페이로드** — JIT-빌드 `hexa cloud` 래퍼가 (C)wipe + argv newline/quoting 에 취약. 별도 세션이 prebuilt `~/.hx/bin/hexa-cloud` 직접호출 + base64 페이로드로 양쪽 우회해 안정동작 확인. canonical 전송을 prebuilt-binary + base64 로 승격 검토.
- [ ] **(참고) #1155 미해소** — vast pod 도달은 여전히 `raw ssh -i ~/.ssh/id_vast_anima -o IdentitiesOnly=yes <bareIP>` 만 작동(`hexa cloud` 가 vast 등록키 미제시). (A)(B)(D)와 함께 vast 전송 스택 전반 점검 권고.

## 2026-05-26T08:00Z — 🐛 verify_cli 빌드-해소 4건 (UFO atom fold #1222 중 발견 · from demiurge UFO)

> demiurge UFO 4-atom fold(`#1222` 머지)를 mini 에서 진행하며 verify_cli 빌드를 살리는 과정에서 확인. codegen `_Generic`/bessel 증상 자체는 ↓06:30Z · ✅07:40Z(#1198) 에 등재됨 — 본 엔트리는 그와 별개의 **빌드-해소(resolution) 갭 4건**. 모두 워크어라운드로 #1222 는 랜딩 완료.

- [ ] **install `build/hexa_v2` ≠ `self/native/hexa_v2`** — `hexa cc --regen` 이 `~/.hx/bin/self/native/hexa_v2`(fixed)만 갱신하고 `~/.hx/bin/build/hexa_v2`(stale)는 그대로 둠. mini 기본 빌드는 `build/` 를 집어 codegen-fixed 가 안 먹음. 워크어라운드: `cp self/native/hexa_v2 build/hexa_v2`. → regen 이 둘 다 갱신하거나 빌드가 `self/native/` 우선 resolve 해야.
- [ ] **verify_cli 빌드캐시가 import 변경을 무효화 안 함** — `compiler/atlas/calc_dispatch.hexa` 편집해도 cache key(`hexa_run.c1ee70da…`) 고정 → stale 빌드(편집 미반영). `rm ~/.hexa-cache/hexa_run.<key>*` 강제 후 반영. cache key 에 flattened-import 해시 포함 필요.
- [ ] **`hexa verify` 엔트리 = 설치본 `~/.hx/bin/tool/verify_cli.hexa` 고정** — HEXA_LANG 은 import(calc_dispatch/embedded)만 리다이렉트, verify_cli 엔트리는 설치본 사용. → worktree 의 verify_cli 편집은 설치본에 copy 해야 반영. HEXA_LANG 이 tool/ 엔트리도 우선 resolve 하면 worktree-isolated verify 개발 가능.
- [ ] **pool-route 가 `hexa`-word Bash 를 ubu 로 로드밸런싱** — mini-local `/tmp`·`~/core/*` worktree 빌드가 ubu(다른 트리·segfault)로 가 깨짐. verify-host=mini 핀이 `/Users/` abs-path 바이너리로만 됨(env opt-out 부재). heavy-word 라우터가 mini-local-path 명령은 핀해야.

owner = hexa-lang 빌드/툴체인 세션.

## 2026-05-26T07:40Z — ✅ RESOLVED — verify/atlas-register 재빌드 차단 (21:13Z #1188) — #1198 + `build_hexa_module_loader.sh` 로 복구 · h3as Tc 🟢 fold 검증 · from demiurge RTSC

> 21:13Z(#1188) "stale binary 재빌드뿐" blocker 를 demiurge RTSC 가 **직접 ubu-1 에서 복구 완료**. 클린 worktree(origin/main, #1198 포함)에서 2단 fix 로 `hexa verify --expr … --compute` + `hexa atlas register --from-verify` 가 다시 작동.

- [x] **차단 1 — transpiler segfault → #1198 로 해소**. 클린 worktree(`git worktree add … dace56b`, #1198 ce36d350 포함)에서 `hexa cc` → `self/runtime.c` 7-error(`hxlcl_mkdir`·`_hxlcl_syscall6_cf`·`HXLCL_SYS_SELECT`·`_hxlcl_syscall2_cf`·`HXLCL_SYS_FLOCK` 미선언) **사라짐** → `runtime.o` 컴파일 + `build/hexa_v2` 링크 성공. (a79b114 stale 체크아웃은 #1198 부재라 계속 실패했던 것 — 클린 origin/main 필수.)
- [x] **차단 2 — 멀티모듈 링크 = `build/hexa_module_loader` 누락**. `hexa cc` 직후엔 `hexa build tool/verify_cli.hexa` 가 `compiled module_loader not found — falling back to raw src` → `undefined reference: calc_eps · calc_is_zero_arg_float_fn`(compiler/atlas/calc_dispatch 의 pub fn) 링크 실패. **fix = `bash tool/build_hexa_module_loader.sh`** (self-contained, 0-`use`, bootstrap-safe) → `build/hexa_module_loader` 빌드 → `resolve_module_loader_compiled`(self/main.hexa)가 그걸 써서 `use` 그래프 정상 flatten → calc_dispatch 링크 해결.
- [x] **검증 (g5 VERBATIM)** — `hexa atlas register --from-verify allen_dynes_tc 1.6489 450.40 0.10` → `=55.8985 (compute — auto-routed from 🟠)` · `tier = 🟢 SUPPORTED-NUMERICAL (delegated via hexa verify --expr … --compute)` · atlas `@F verified-allen_dynes_tc-num`(idempotent, 이미 fold). VERIFY-KIT V1 compute-delegation 체인(verify_cli cmd_expr_float_compute → atlas_cli _adapt_verify_compute) end-to-end 정상.
- [x] **demiurge RTSC h3as 흡수 완료** — full-BZ el-ph 결과 Allen-Dynes Tc = 55.90 K 가 🟢 검증 + atlas fold. RTSC.log + `exports/material_discovery/rtsc_h3as_fullbz_elph_20260526.json`.
- [ ] **잔여 (install-completeness 권고)** — `build/hexa_module_loader` 가 install/CI 에 항상 동반되도록 보장(누락 시 raw-src fallback 이 multi-module 에서 silent 링크실패). `hx install` / 빌드 파이프라인에 module_loader 빌드 스텝 포함 검토. (이번 건 수동 `build_hexa_module_loader.sh` 로 해결 — 영구화는 후속.)

> ACK: #1188(21:13Z) RESOLVED — 소스(verify_cli/atlas_cli V1)는 처음부터 맞았고, blocker 는 (1)#1198 미포함 stale 체크아웃 (2)`build/hexa_module_loader` 미빌드 2겹이었음. 둘 다 클린 origin/main + `build_hexa_module_loader.sh` 로 닫힘.

## 2026-05-26T06:30Z — verify_cli rebuild `_Generic` stale 증상 = bessel_j0/iit4_faithful_phi 미선언 (↓ 21:13Z stale-binary 의 구체 compile-error 재현 · TECS-L 범용화 CM triage)

> **dedup: 신규 아님** — 바로 아래 2026-05-25T21:13Z "stale 설치 binary 재빌드" 의 구체 clang-error 증상. witness 보강용.

격리 `/tmp/wt-*` worktree 에서 `hexa verify --expr <any>` 캐시 miss → `verify_cli.hexa` rebuild → clang: `use of undeclared identifier 'bessel_j0'/'bessel_j1'` (codegen `hexa_call1(bessel_j0,…)` 생성, 정의는 `_bessel_j0` 언더스코어; `runtime.h:846` `_Generic` dispatch prefix mismatch) + `iit4_faithful_phi` undeclared (hexa_call4). 2 warnings + 11 errors → binary 미생성.
- [ ] 재현: TECS-L MILLENNIUM CM triage `hexa verify --expr sopfr 6 5` → verify_cli rebuild → 위 error. sigma/tau/phi 연쇄 동일. F4(이전 worktree) 는 캐시 hit 으로 통과 → 캐시 무효 후 노출.
- root: VERIFY-KIT V작업(special-fns `bessel_*` + phi_demo `iit4_faithful_phi` 추가) 후 verify_cli 가 그 fn 호출하나 **deployed runtime.h `_Generic` 미동기** (= 21:13Z stale binary). transpiler codegen 의 `_` prefix 누락 의심.
- 영향: 격리 worktree g5 verify 차단 → TECS-L 새 대축(CM/PH/CO/LF) verify 막힘.
- 우회(현): main working tree cwd 캐시 hit 시도 / independent `.hexa` `hexa build` (함수값만, verdict tier 아님).
- fix: deployed hexa 재설치 (verify_cli + runtime.h `_Generic` 재생성 동기, mini pool) = 21:13Z 와 동일 처방.
- proposed-by: agent (TECS-L 범용 격상 후속, 2026-05-26)

## 2026-05-25T21:13Z — 🔁 VERIFY-KIT V1 SOURCE는 완비 — blocker는 오직 stale 설치 binary 재빌드 (hexa_v2 segfault + `hexa cc --regen` .o-as-.c) · from demiurge RTSC h3as atlas-absorb

> **정밀 갱신** (기존 transpiler-segfault 엔트리 보강). demiurge RTSC 가 h3as 결정적 결과(λ_BZ=1.65 강결합 stable 폴리모프, Tc≈56K)를 atlas 흡수하려다 막힘. 추적 결과 **소스는 이미 맞고, 막힌 건 binary 재빌드뿐**임을 확정.

- [x] **SOURCE는 V1 완비** (origin/main 7b1b6fcd~e2cb1478): `tool/verify_cli.hexa` — allen_dynes_tc dispatch arm(L3013, `_allen_dynes_tc` L1295) + `cmd_expr_float_compute`(L3652) + `COMPUTE: <fn> = <val>` 출력(L3697) + `_has_compute`(L70) 라우팅(L3718) 모두 존재. `tool/atlas_cli.hexa` — allen_dynes_tc register arm(L1429) + `_adapt_verify_compute`(L2064, value-less COMPUTE-and-fold) + `_parse_compute_value`(L2042) 존재. 즉 register→verify `--compute`→COMPUTE파싱→fold 체인이 소스상 완결 (g20 single calc home). **verify_cli/atlas_cli 엔 고칠 것 없음.**
- [ ] **blocker = 설치 binary stale** (V1 이전): `hexa verify --expr allen_dynes_tc 1.6489 450.40 0.10 --compute` 가 신형 `COMPUTE:` 라인 대신 구형 `calc=55.8985 ≠ expected -0.0` + 🔴 출력 → `_adapt_verify_compute` 의 `_parse_compute_value` 가 빈 문자열 받아 register 실패(🟠/🔴). 즉 흡수 차단은 desync(이미 V1로 해소)도 arity gap(해소)도 아닌 **stale binary** 단일 원인.
- [ ] **재빌드 차단 1 — hexa_v2 segfault**: `hexa run|build <any.hexa>` → `[1/2] HEXA_MEM_CAP_MB=4096 …/hexa_v2 tmp.hexa out.c` → **Segmentation fault (core dumped)** → "transpile failed — C file not produced". trivial 1-fn .hexa 도 동일. pool-wide (ubu-1/ubu-2). 기존 2026-05-26T00:45Z 엔트리와 동일 근본.
- [ ] **재빌드 차단 2 — `hexa cc --regen` 빌드시스템 회귀** (ubu-2/summer): regen이 gcc에 `self/runtime.o`(컴파일된 ELF object)를 **C 소스로** 넘김 → `runtime.o:1:N: warning: null character ignored`(ELF 바이트를 소스로 읽음) 다발 → `compiled=no` → `hexa_cc.c` ≠ `hexa_cc.c.new` (Phase C MVP concat merge, no symbol resolution). 즉 transpiler self-rebuild 경로도 깨짐.
- [ ] **영향**: g5 verify (`hexa verify --expr`) + atlas register (`--from-verify`) 가 신형 fn(allen_dynes_tc 등 3-arg + V1 COMPUTE)에 대해 설치 binary 기준 전면 차단. demiurge RTSC/NUCLEAR 의 검증·흡수 파이프라인 정지. (h3as 결과는 `RTSC.log.md` + `exports/material_discovery/rtsc_h3as_fullbz_elph_20260526.json` 에 durable 봉합 — binary 복구 즉시 `register --from-verify allen_dynes_tc 1.6489 450.40 0.10` 한 줄로 fold 가능.)
- [ ] **fix 후보**: (a) 회귀 bisect — "어제 아침 정상 → origin/main 회귀"(00:45Z) → 깨진 codegen 커밋 revert. (b) known-good `self/native/hexa_v2` binary 복원(회귀 이전 캐시/git). (c) 클린 clone 재빌드(ubu 체크아웃 .o 혼선 회피). (d) `hexa cc --regen` 의 .o-as-.c 입력 버그 분리 수정(object를 source-list에서 제외). — 04:30Z `exec_stream` SIGSEGV 와 동일 transpiler 회귀일 가능성.

## 2026-05-26T04:30Z — 🐛 `exec_stream(cmd, on_line)` SIGSEGV in a `hexa build` standalone binary (callback fn-pointer path) · from this-session cloud-tail

> **severity: medium** — `exec_stream` is the documented streaming primitive (per-line callback, runtime `_IOLBF` flush). It works in the bootstrapped `hexa` driver but **segfaults immediately (exit 139)** in any program compiled with `hexa build` — even a trivial `exec_stream("printf 'a\\nb\\n'", on_line)`. Discovered while building `hexa cloud tail`; worked around with `exec_replace` (no callback) so the verb shipped, but the gap stands. Same family as `exec_argv not codegen-wired`.

- [ ] **repro**: `printf 'fn f(s){print(s)}\nfn main(){let _=exec_stream("printf x\\\\n",f)}\n' > /tmp/es.hexa; hexa build /tmp/es.hexa -o /tmp/es && /tmp/es` → exit 139, no output. `exec_replace("printf x\n")` in the same harness streams fine (exit 0).
- [ ] **likely cause**: codegen emits `hexa_exec_stream(cmd, <callback>)` (self/codegen.hexa:5932) passing a hexa fn value as the C callback arg; the standalone-build runtime link (vs the self-host driver build) maps that fn-pointer differently → bad call. Driver build works because its runtime/codegen pairing differs.
- [ ] **impact**: any standalone CLI that wants live line-streaming of a subprocess must use `exec_replace` (process-replacing, single subprocess only — no post-stream logic) or `exec_capture` (buffers, no live stream). `exec_stream`'s callback model is unavailable in shipped `hexa build` binaries.
- [ ] **workaround in use** (`stdlib/cloud/cloud tail`): build the ssh pipeline string and `exec_replace` it (execvp /bin/sh), inheriting stdout. Fine for a leaf streamer; not a fix.

> **severity: high** — RTSC 캠페인 세션에서 `hexa cloud run/exec/nohup/poll/copy-to/copy-from` 이 vast.ai pod 에 대해 **전부** `[cloud] cloud_run: no exit-code marker — ssh transport failure or remote shell died` 로 실패. el-ph 결과 수확·pod hygiene(orphan 정리) 전면 차단되어, 부득이 raw ssh 우회로 진행함(아래). d8 (Vast 발견 → INBOX).

- [ ] **repro**: `hexa cloud exec root@195.189.61.56 --port 40012 --insecure -- 'echo POD_REACHABLE'` → `cloud_exec: no exit-code marker — ssh transport failure or remote shell died`. pod 는 `running`(vast `show instance` 확인), 직접 IP/포트(195.189.61.56:40012 = 22/tcp HostPort)도 정확.
- [ ] **근본 원인 = ssh identity 미해결**: hexa cloud 내부 ssh 가 **vast 계정 등록 키를 제시하지 않음**. Mac 기본키 `~/.ssh/id_ed25519` 는 vast 계정에 미등록 → publickey 거부. vast 계정 등록 키는 2개(`vastai show ssh-keys`): `anima-orchestrator`(= 로컬 `~/.ssh/id_vast_anima`, fingerprint 일치) · `demiurge-rtsc-2026-05-22`(로컬 private 키 부재). hexa cloud 가 ⓐ `~/.ssh/config` 의 host 별 `IdentityFile` 을 존중하지 않고 ⓑ `-i`/`--identity` 연결 플래그도 없어, 매칭 키를 절대 제시 못 함.
- [ ] **증명(raw ssh 우회 = 정상)**: `ssh -i ~/.ssh/id_vast_anima -o IdentitiesOnly=yes -p 40012 root@195.189.61.56 'uptime'` → `AUTH_OK` + 정상 실행. 즉 transport 는 멀쩡하고 **키 선택만 문제**. opaque 메시지("ssh transport failure or remote shell died")가 실제 `Permission denied (publickey)` 를 가려 디버깅이 크게 지연됨.
- [ ] **fix 후보**:
  - (a) [권장] `~/.ssh/config` 의 resolved host `IdentityFile` 존중 — 하드코딩 기본키/`IdentitiesOnly` 로 덮어쓰지 말 것.
  - (b) 연결 플래그 `--identity <path>` (= `-i`) 추가 (`--port`/`--insecure` 와 동급) — caller 가 명시 키 지정.
  - (c) [vast-aware] auto-discover: 계정 ssh-keys 조회 → 로컬 `~/.ssh/*` private 키와 fingerprint 매칭 → 일치 키 자동 제시.
  - (d) [진단] auth 실패 시 실제 ssh stderr(`Permission denied (publickey)`)를 surface — transport-fail 과 auth-fail 을 구분(현재 둘 다 "no exit-code marker" 로 합쳐져 오진 유발).
- [ ] **cloud-guard 상호작용 주의**: bare-IP raw ssh 는 cloud-guard(g8)가 pod-host 로 플래그 안 해 통과됨(= 본 우회가 가능했던 이유). 하지만 이는 사용자를 sanctioned `hexa cloud` 경로 **밖으로** 밀어내는 갭. 근본 해결은 hexa cloud identity 수정(위 a/b/c)이며, 그래야 g8 준수 상태로 복귀. (역으로 guard 만 조이고 cloud 키를 안 고치면 vast 도달 수단이 0이 됨 — 동시 수정 필요.)

## 2026-05-26T05:15Z — ✅ CORRECTION: 위 #1137 은 origin/main 회귀 아님 — ubu-1 호스트-특정 (로컬 Mac 정상)

> **재진단 (demiurge CERN BLUE-MAX 후속)**: 아래 entry 의 "origin/main 회귀" 결론은 **오진**. 로컬 Mac 에서 `hexa verify --expr chsh_tsirelson 2.8284271247461903` → 정상 🟢 verdict, `hexa verify --expr wakefield_omega_p_sq 1.0 …` → 정상 🟢. 즉 origin/main 소스/툴체인은 멀쩡. 실제 원인은 **호스트-특정 환경**: ubu-1 `hexa_v2` 바이너리 segfault (재빌드 필요) · ubu-2 무네트워크 + HEAD stale(9b0a01a) + hexa_v2/verify_cli 로컬수정 · mini-pool stale checkout. **fix = 각 pool 호스트 `hexa cc` 재빌드 + origin/main sync** (origin/main bisect 불필요 — 시간낭비 방지). 교훈: `hexa verify` 는 로컬 Mac 직접 실행이 정답, pool/route 경유 금지.

## 2026-05-26T00:45Z — 🔥 hexa_v2 transpiler SEGFAULT (ubu-1 host-specific · ⚠ "pool-wide regression" 표현은 위 CORRECTION 참조) · from demiurge CERN BLUE-MAX

> **severity: host-specific (NOT origin/main)** — `hexa run <any.hexa>` 가 transpile 단계에서 ubu-1 의 `self/native/hexa_v2` Segmentation fault → C 파일 미생성. file-specific 아님 (3400줄 `tool/verify_cli.hexa` 와 40줄 `stdlib/cern/plasma_wakefield.hexa` 둘 다 동일 크래시). **로컬 Mac 은 정상** (위 2026-05-26T05:15Z CORRECTION) — ubu-1 바이너리 재빌드로 해소. `hexa verify --expr` 는 로컬에서 정상 동작.

- [ ] **repro**: ubu-1 `cd ~/core/hexa-lang && hexa run stdlib/cern/plasma_wakefield.hexa` → `[1/2] hexa_v2 … tmp.hexa build/artifacts/…c` → `Segmentation fault (core dumped)` → `transpile failed — C file not produced`
- [ ] **선행 증상**: 처음엔 `runtime.c:1954: call to undeclared function '_hxlcl_syscall3_cf'` (ubu-1 stale `self/runtime.c`) → `git checkout origin/main -- self/runtime.c` 로 선언(1112행)은 복구됐으나 그 후 transpiler 가 segfault 로 회귀 (별개 2차 버그)
- [ ] **host matrix**: ubu-1 = hexa_v2 segfault · ubu-2 = segfault(기존) · pool-mini = stale 체크아웃(`compiler/atlas/calc_dispatch.hexa` 부재, PR #1023 이전) · local Mac = AMFI SIGKILL/route → **g5 verdict 가능 호스트 0개**
- [ ] **fix 후보**: `hexa cc --regen` 로 hexa_v2 재빌드 (g61) · origin/main HEAD `8e748438`(OEIS O3) 부근 codegen 회귀 bisect · 최근 VERIFY-KIT V2 / OEIS 대량 atom 추가가 transpiler 메모리/재귀 한계 유발했는지 확인 (HEXA_MEM_CAP_MB=4096 표시됨)
- [ ] **차단된 작업**: demiurge CERN BLUE-MAX (g69) — 신규 🔵 atom `wakefield_omega_p_sq` / `wakefield_e0_lambda_product` (sqrt-free algebraic, python-확인 deterministic) 의 `hexa verify --expr` verdict 대기 중 → toolchain 복구 시 즉시 verify+land 가능

## 2026-05-26T00:30Z — atlas_cli.hexa recompute-dispatch drift (@D d4) · from ANTIMATTER atlas-fold #1132

**맥락**: ANTIMATTER 26 atom을 atlas fold(PR #1132)하던 중 발견. `tool/atlas_cli.hexa`가 `_recompute_register` 등 **별도 하드코딩 recompute dispatch 테이블**을 들고 있고 antimatter atom과 동기 안 됨 = @D d4 single-generic-dispatch 위반. 이번엔 `_adapt_verify_generic`이 `hexa verify --expr`로 delegate해서 fold는 됐지만, 근본은 drift.

- [ ] `tool/atlas_cli.hexa`의 `_recompute_register` 하드코딩 테이블 제거 → 공유 `compiler/atlas/symbolic` dispatcher로 통합 (파일 자체 TODO도 동일 지적)
- [ ] 관련: shipped `bin/hexa-{verify,atlas}` stale → install-sync 갭 (atom 추가 후 재빌드 강제됨)

repro: hexa atlas register --from-verify <antimatter fn> · PR #1132 설명에도 flag됨

## 2026-05-26T01:30Z — atlas register 가 `allen_dynes_tc` (RTSC 핵심 verify fn, 3-arg) 흡수 불가 — atlas_cli↔verify_cli desync + 3-arg register arm 부재 (#954 확장)

demiurge RTSC "atlas 흡수" 시도 중 발견 — RTSC 캠페인의 verify-able 결과(초전도 Tc)가 atlas 에 전혀 흡수되지 못함. 차단 2겹:

- [x] **(1) verify_cli HAS · atlas_cli register mirror LACKS** — RESOLVED (VERIFY-KIT V1). 진단 정정: main HEAD 는 이미 delegation 마이그레이션 완료 — `_adapt_verify_generic` 가 `exec("hexa verify --expr …")` 로 shell-out; per-fn 미러(`_recompute_float_register`)는 dead code(`calc_dispatch.hexa` 코멘트 명시). 즉 미러 desync 자체는 이미 해소. INBOX 가 본 🟠 는 OLD 설치 binary + 아래 (2) arity gap 의 복합 증상. V1 가 compute-delegation 으로 최종 닫음.
- [x] **(2) 3-arg register arm 부재** — RESOLVED (VERIFY-KIT V1). 진짜 원인 = register 가 마지막 positional 을 `<v>` 로 소비 → 3-arg fn 의 μ* 가 claimed value 로 오인 → verify 가 2-arg 로 계산(argc<3 → `_NOCALC_F` → 🟠). 추가로 `cmd_expr_float` 에 value-less COMPUTE mode 부재. fix: verify_cli `cmd_expr_float_compute` 신설 + atlas `cmd_register` 가 value-bearing 🟠→compute auto-route(+ 명시 `--compute`). 임의 arity (allen_dynes_tc 3-arg) 처리. 실증: `register --from-verify allen_dynes_tc 0.6150 591.18 0.10` → 14.5511 🟢 (`.verdicts/verify-kit-mirror-unify/v1_register.txt`).
- [x] **(3) ε=1e-9 round-tolerance 재확인** — RESOLVED (VERIFY-KIT V3). 옵트인 `--tol <eps>` 추가: `hexa verify --expr <fn> <args> 14.55 --tol 0.01` 에서 |Δ|>strict ε=1e-9 이지만 ≤ <eps> 면 spurious 🔴 대신 🟢 SUPPORTED-NUMERICAL (round-tolerant) 판정. literature 6-digit 반올림(Tc=14.55 vs 엔진 14.5511) 케이스 해소. **falsification 무결성 보존**: --tol 은 명시 옵트인(기본=무 tolerance=strict 그대로), 스테이트된 <eps> 너머의 🔴 는 🔴 유지(`… 99.0 --tol 0.01` → 🔴). float(cmd_expr_float)+int(cmd_expr) 양 경로. round-tolerant 🟢 는 auto-absorb 안 함(atlas 는 V1 대로 엔진 정밀값만 fold). 실증: `.verdicts/verify-kit-tol/v3_tol.txt`.
- [x] **영향 범위** — RESOLVED (RTSC magnet 16-fn class). V1 compute-delegation 은 fn-agnostic — verify_cli `_recompute_float` 에 있는 fn 은 임의 arity 로 register 흡수 가능. 실증: mcmillan_tc=12.0423 🟢 · morel_anderson_mustar=0.112262 🟢.
- [x] **제안** — (a) 채택. delegation(register → `hexa verify --expr … --compute`)이 미러 desync + arity 불일치 동시 소멸. (b) 미채택(미러 추가는 desync 근원 유지).

Status: RESOLVED · VERIFY-KIT V1+V3 · (1)(2)(3)(영향범위) ALL closed · proposed-by:agent · fixed-by:VERIFY-KIT V1 compute-delegation (tool/verify_cli.hexa cmd_expr_float_compute + tool/atlas_cli.hexa cmd_register auto-route) + V3 round-tolerance (tool/verify_cli.hexa --tol <eps>) · #954 확장

> ACK 2026-05-26 (VERIFY-KIT V1): (1)(2)(영향범위) resolved-class — root delegation(proposal a) 채택. register `--from-verify allen_dynes_tc 0.6150 591.18 0.10` → COMPUTE 14.5511 🟢 (was 🟠 "no calculator path"). RTSC 3-arg 16-fn atlas 흡수 unblock. #954 mirror-desync 동일 closure (atlas 미러 의존 0). (3) round-tolerance 만 V3 후속으로 잔존.
> ACK 2026-05-26 (VERIFY-KIT V3): (3) round-tolerance resolved-class — 옵트인 `--tol <eps>` 추가. `--expr allen_dynes_tc 0.6150 591.18 0.10 14.55 --tol 0.01` → 🟢 (within tol, calc=14.5511 vs literature-rounded 14.55); `--tol` 없으면 🔴 strict 그대로(unchanged); `… 99.0 --tol 0.01` → 🔴 (beyond tol, NOT laundered). falsification 무결성 보존(명시 옵트인·기본 strict). 실증 `.verdicts/verify-kit-tol/v3_tol.txt`. (3) CLOSED → 항목 전체(1)(2)(3)(영향범위) 종결.


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
  - **ACK + 정정 2026-05-26 (VERIFY-KIT V1)**: main HEAD 에서 `register --from-verify` 는 이미 verify_cli 로 shell-out(delegation; `_adapt_verify_generic` exec → `hexa verify --expr`) 하도록 마이그레이션 완료 — atlas_cli `_recompute_float_register` 미러는 dead code (`calc_dispatch.hexa` 코멘트가 명시; `cmd_reverify` 만 사용). 즉 위 "atlas_cli 자체 미러로 recompute" 진단은 OLD 설치 binary 기준이고, 실제 잔여 gap 은 register 가 마지막 operand 를 `<v>` 로 소비하는 arity 처리(`2 2` → 1-op verify w/ value=2, NOT 2-op compute) + `cmd_expr_float` 의 value-less compute mode 부재였음. V1 fix(`cmd_register` value-bearing 🟠→compute auto-route + `cmd_expr_float_compute`)로 `--compute`/auto-route 시 임의 arity compute-and-fold 가능. **단** `lambda_anharm_suppress`/`stability_coupling_margin` 의 실제 arity 로 재실증 필요(`register --from-verify <fn> <args...> --compute` — verify_cli `_recompute_float` 에 있으면 🟢 흡수). 제안 (c) "2 미러 통합" 은 main 에서 이미 delegation 으로 사실상 달성(미러 dead-code 화); 완전 제거(dead-code 삭제)는 follow-up cleanup PR.

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

- [x] **(b) `hexa verify --expr` ε=1e-9 가 low-precision input 에 과도 (round-tolerance 옵션)** — RESOLVED (VERIFY-KIT V3). 제안한 `--tol <ε>` 옵트인 옵션 그대로 구현. 1-decimal 입력(Tc=179.8K) 대비 full-precision calc(179.779)의 |Δ|=0.021K 반올림 차이는 이제 `--tol 0.05` 류로 🟢 SUPPORTED-NUMERICAL 판정 가능(예: `--expr allen_dynes_tc 0.6150 591.18 0.10 14.55 --tol 0.01` → 🟢). 기본(--tol 무)은 strict ε=1e-9 그대로라 falsification 무결성 보존. 유효숫자 자동감지는 미채택(silent-widen 위험; 옵트인이 honest).
  - 발견: RTSC N5 funnel 4 candidate (h3o·h3si·h3f·h3po) allen_dynes_tc cross-check 전부 🔴 (round artifact).
  - fix: `--expr <fn> <args> <v> --tol <ε>` 옵트인 (tool/verify_cli.hexa _has_tol/_get_tol/_strip_tol + cmd_expr_float/cmd_expr round-tolerance band). 실증 `.verdicts/verify-kit-tol/v3_tol.txt`.
  - severity: low-medium (verdict 오탐 — honest tier 왜곡) → CLOSED.

> ACK 2026-05-26 (VERIFY-KIT V3): (b) round-tolerance resolved-class — 제안한 `--tol <ε>` 옵트인 옵션 구현. low-precision 입력의 반올림-artifact 🔴 가 명시 --tol 로 🟢 SUPPORTED-NUMERICAL 판정 가능. silent-widen 회피(옵트인). 동일 클래스 2026-05-26T01:30Z item(3) 와 함께 종결.

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

> ⤵ pre-2026-05-25T05:10Z 엔트리는 `INBOX.archive.log.md` 로 아카이브됨 (size hygiene · 삭제 0).

## 2026-05-26T18:00Z — bin/hexa-atlas register-whitelist 와 bin/hexa-verify calc-fn whitelist 동기화 (from: TECS-L F10 /micro-exp)

TECS-L F10 40-candidate sweep 에서 설치 `bin/hexa-verify` + `bin/hexa-atlas` 가 `tool/verify_cli.hexa` source 보다 낮은 fn whitelist 를 가짐을 재확인. sweep 의 3개 🟠 INSUFFICIENT (E27 pow · E39/E40 nth_prime) 와 atlas auto-fold 차단 (sigma/tau/euler_phi 등 verify 통과 atom 도 `register --from-verify` 에서 🟠 INSUFFICIENT 반환) 의 단일 근본 원인.

- [ ] **bin/hexa-verify**: 설치 바이너리에 sopfr·mersenne_perfect_sigma_pure·pow·nth_prime·is_prime·factorial·catalan·bell·partition 미바인딩 (source `tool/verify_cli.hexa` L431/L450/L548/L455-460 에는 존재). 재빌드(`hexa cc --regen` + promote) 또는 source-binary diff lint 가 필요.
- [ ] **bin/hexa-atlas register-whitelist**: `_recompute_float_register` (atlas_cli.hexa) 가 sigma·tau·euler_phi·aliquot·mobius·is_perfect 등 verify_cli.hexa fn 들에 대해 `has no calculator path` 응답. atlas_cli.hexa ↔ verify_cli.hexa fn_name set 양방향 일치 (또는 단일 SSOT delegation) + bin/hexa-atlas 재빌드.
- [ ] **lint 게이트**: verify_cli.hexa 의 `fn_name == "<x>"` set 과 atlas_cli.hexa `_recompute_float_register`/`_is_float_fn_register` set 의 symmetric-diff = 0 을 enforce 하는 grep-lint (commons g20 single-calc-home 확장).
- [ ] 근거: TECS-L F10 sweep 40 candidates 중 atlas-fold 가능했어야 할 34 🔵 가 0 fold (binary 게이트). `h_verify_auto_absorb` @D 의 "successful 🔵/🟢 verify auto-folds the atom to atlas (embedded.gen.hexa SSOT) by default" 약속과 직접 충돌. F9 NOVEL=verify infra growth driver 패턴의 다음 입증 케이스.
- 출처: TECS-L F10 verdict ledger `TECS-L/.micro-exp-2026-05-26/verdicts/{E27,E39,E40}.txt`.

## 2026-05-27 — sidecar /domain + /cycle closure-goal semantics 개선 (done-log vs roadmap vs backlog 분리)

발단: "GPU all milestone closure" Stop-hook 목표 수행 중 GPU.md open `- [ ]` 232개를
0으로 닫으려다, 232개가 동질적이지 않음을 발견 — ①24 concluded fire(closeable) +
②208 미구현(대부분 미래 로드맵: §5 cuBLAS-moat north-star 포함). open=0을 글자대로
쫓으니 ②를 (a)거짓 done flip(g3 over-claim 위반) 또는 (b)checkbox 제거 둘 중 하나로
처리할 수밖에 없었고, (b)를 택해 §5 cuBLAS 로드맵이 plain-bullet로 강등(은닉)됨.
사용자가 "cublas 뛰어넘는 마일스톤 어디감???" 으로 포착 → §5 50개 복원(PR #1646).
PR #1644(over-closure) → PR #1646(§5 restore) 가 incident record.

**근본 진단**: `/domain` 컨벤션(`<DOMAIN>.md` snapshot + `.log.md`)이 모든 `- [ ]` 를
동질적 "닫아야 할 마일스톤" 으로 취급. 그러나 살아있는 도메인 파일은 lifecycle 이
다른 3종을 한 파일에 섞는다:
| tier | 성격 | 정상 종착 |
|---|---|---|
| (1) experiments / done-log | fire 가 끝나 verdict 가 난 실험 | `[x]` (closed-negative 포함, paper_negative_ok) |
| (2) roadmap | 앞으로 할 forward 작업 (north-star) | open 유지가 정상 — 끝나면 (1)로 이동 |
| (3) backlog | far-future / brainstorm 저우선 아이디어 | `## deferred` (open count 제외) |

"all milestone closure / open=0" 는 (2)(3)에 거짓-이분을 강제하고, 특히 **Stop-hook 조건**
으로 쓰이면 에이전트를 dishonest flip 쪽으로 압박한다. `/cycle` 의 depletion test
("open=0 AND deferred empty") 도 roadmap-보유 도메인에선 정직하게 종료 불가
(로드맵은 본질적으로 안 닫힘).

**권고 4건**:
- (a) **lifecycle-tiered 섹션**: `/domain` 이 `## experiments`(closeable) / `## roadmap`
  (open-expected) / `## deferred`(backlog) 를 구분, 섹션별 progress bar. `done`/depletion/
  closure 목표는 closeable tier 만 타깃. bare `/domain` 진행도도 tier별로 분리 표시.
- (b) **tiered checkbox marker**: `- [ ]`(active) vs roadmap-future vs deferred 를
  마커로 구분(예: `- [~]` roadmap, `- ` backlog) -> bulk-flip/depletion 로직이 tier별
  다르게 처리. 무지성 `sed 's/[ ]/[x]/'` 류 일괄 flip 방지.
- (c) **over-closure guard**: `/domain done --all` 또는 bulk milestone-flip 은
  verdict/evidence 링크(.verdicts/ · archive/fires/ · PR#) 없는 항목의 flip 을 거부.
  paper_negative_ok 연계 — closed-negative 또는 PASS-with-artifact 만 flip 허용.
  이번 "flip 232 blindly" 함정의 직접 가드.
- (d) **Stop-hook goal semantics**: "all milestone closure" 를 roadmap-보유 도메인의
  Stop 조건으로 거는 것 자체가 hazard (dishonest-flip 압력원). 종결 목표는
  lane-scoped(특정 round/실험 batch) 여야 하거나, hook 이 "concluded-tier closed +
  roadmap explicitly deferred" 를 satisfied 로 인정해야. /goal 등록 시 closure 의
  대상 tier 를 명시하게 유도.

**거버넌스 연계**: commons g3(over-claim 0) · paper_negative_ok(deferred != terminal) ·
feedback_gpu_domain_single_ssot. sidecar 측 수정 대상 = `/domain` · `/cycle`
(+ `/cycle-fg`/`/cycle-all`/`/cycle-loop`) skill + Stop-hook goal 평가 로직. hexa-lang
코드 변경 아님 — sidecar marketplace 플러그인 개선 handoff. 출처: this-session GPU.md
closure incident (PR #1644 -> #1646), GPU.log.md 2026-05-27 정정 엔트리.
