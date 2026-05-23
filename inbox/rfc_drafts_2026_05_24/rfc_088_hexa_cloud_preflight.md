---
rfc: 088
title: hexa cloud preflight + typed env-var passing (closed-form GPU mem-budget · structured argv schema)
status: proposed
priority: high
filed: 2026-05-24
filed_by: claude-code worktree agent-a5371c476626f3f7c
target_ssot: stdlib/cloud/ · self/main.hexa (`hexa cloud` verb)
unblocks:
  - gap_cloud_preflight
  - gap_cloud_typed_env
related:
  - inbox/notes/2026-05-21-hexa-cloud-optimizer-mem-budget-preflight.md (source gap)
  - inbox/notes/2026-05-21-hexa-cloud-typed-env-var-passing.md (source gap)
  - inbox/patches/hexa-cloud-subcommand.md (cycle C preflight verb claim — source mismatch)
  - inbox/rfc_drafts_2026_05_24/rfc_085_dispatcher_hygiene.md (sibling — dispatcher cleanup; if numbering shifts the link should follow `dispatcher hygiene` SSOT)
  - memory [[project_stdlib_cloud_cycle_a]] (6-PR cycle A/B-1/B-2/B-2.1/B-3/B-2.2 — landed)
  - memory [[reference_runpod_heavy_build]] (RunPod CPU 재고 없음 · GPU SECURE for RAM · pod delete 필수)
  - commons.tape g8 (canonical `hexa cloud` form)
governance:
  - "@D g_cloud_no_raw_shell — 원격 dispatch는 hexa cloud verb로만 (raw ssh/scp/runpodctl/vastai 금지)"
---

# RFC 088 — hexa cloud preflight + typed env-var passing

## §1 동기 (motivation)

원격 GPU dispatch에서 두 부류의 사일런트-실패가 반복되어 cost-bearing fire 가
**신호 없는 비용**으로 소진된다. 두 gap 모두 `inbox/notes/2026-05-21-*` 에
filed 되었고 `stdlib/cloud/cloud_cli.hexa` (cycle A/B 머지 후) 의 verb
디스패치에 **아직 반영되지 않았다** (2026-05-24 기준 `run · nohup · poll ·
copy-to · copy-from · help · version` 만 존재).

### gap#1 — optimizer-state memory budget preflight 부재

anima S187 3B grid 사건 (`inbox/notes/2026-05-21-hexa-cloud-optimizer-mem-budget-preflight.md`)
에서 9차례 OOM 이 발생했다:

- 8개 pod 가 같은 `_foreach_sqrt` 위치에서 **byte-identical** OOM 으로 죽음
- 진짜 원인: `n_params=8.92B × torch.optim.AdamW (f32 m + f32 v) = 71.4 GiB`
  옵티마이저 state 가 H100 80 GiB 를 단독으로 거의 채움
- 비용: pod-spinup ($0.05) + boot/install ($0.50) + first-step attempt ($0.20)
  ≈ **$0.75/pod × N pods × M attempts**
- attempt 10 에서 `bitsandbytes.optim.PagedAdamW8bit` 로 swap → 58.39 GiB 로
  떨어지고 7/8 pod 가 step 200+ 통과

이 모든 OOM 은 closed-form 산식으로 **dispatch host 에서 <30s 에 사전
falsifiable**:

```
params      = n_params × bytes_of(param_dtype)
grads       = n_params × bytes_of(grad_dtype)
opt_state   = n_params × optimizer_state_multiplier(optimizer)
activations = bsz × seq_len × d_model × n_layer × envelope_factor (10–25)
temps       = overhead_envelope (8 GiB conservative)
total       = params + grads + opt_state + activations + temps + reserved_overhead

if total > gpu.mem_bytes - reserved_overhead:
    raise BudgetExceededError
```

### gap#2 — typed env-var / argv passing 부재

S187 attempt 7–8 (`inbox/notes/2026-05-21-hexa-cloud-typed-env-var-passing.md`)
에서 `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True` 가 SSH 셸 → nohup →
python 체인 어딘가에서 silently 탈락. `grep -l expandable_segments
/proc/$PID/environ` 로 사후 확인했지만 그때는 이미 4 회 잘못된 가설
(activation memory) 에 cost 가 burn 됨.

근본 원인: `$SSH "cd $DIR && ENV=val nohup python3 ..."` 가 **unstructured
bash 문자열**. 컴파일타임 검증 0건, 런타임 assert 0건, OOM-time 에야 표면화.

### §1 RunPod 운영 컨텍스트

메모리 `[[reference_runpod_heavy_build]]` 의 운영적 사실:

- RunPod CPU pod 재고 거의 없음 → GPU SECURE pod 를 RAM 용도로 잡아야 함
- ubuntu2404 base
- **pod 종료 후 `runpodctl remove pod <id>` 필수** (방치 burn 사례 다수)

preflight 가 closed-form 으로 **pod-spinup 전** 실패하면 위 비용 0원. preflight
가 verify-step 으로 step 1 직후 실패하면 spinup + 1-step ≈ $0.75 burn 후
**자동 teardown 트리거** 가능.

## §2 design — preflight (gap#1)

### §2.1 verb 확장

`stdlib/cloud/cloud_cli.hexa::_cloud_help` 의 verb 목록에 `preflight` 추가:

```
hexa cloud preflight <spec.toml | spec.hexa>    # 또는 --inline 옵션
```

스펙 파일은 §2.2 의 typed record 직렬화. 메모리
`[[project_stdlib_cloud_cycle_a]]` 의 cycle A 패턴 (structured-argv, no shell
string class) 유지 — preflight verb 도 **순수 closed-form 계산** 만 수행,
SSH/POD 호출 0건.

> 부가: `inbox/patches/hexa-cloud-subcommand.md` 가 "cycle C 에서 preflight verb
> wired" 라고 적어두었지만 현 source (cloud_cli.hexa) 의 verb 분기에는 부재.
> 본 RFC 가 그 claim 의 **canonical 진입점** (notes → RFC 088 → 머지) 역할.

### §2.2 typed record schema

```hexa
struct CloudJob {
    host: str,                    // "runpod://h100-80gb" | ssh alias
    cwd:  str,                    // "/workspace/s187r"
    model: ModelSpec,
    optimizer: OptimizerSpec,
    batch: BatchSpec,
    gpu: GpuSpec,
    env: [(str, EnvType, str)],   // (name, type, default) — §3
    argv: [str],                  // POSIX-quoted on emit (cycle A 기본)
    verify_env: [str],            // post-launch grep /proc/PID/environ
    pre_flight: bool,             // true = budget check 강제
}

struct ModelSpec {
    n_params: u64,                // measured, not declared (§2.5)
    param_dtype: DType,           // bf16 | f16 | f32 | f64
    grad_dtype: DType,
}

enum OptimizerSpec {
    Sgd,                                            // multiplier = 0
    SgdMomentum,                                    // 4
    AdamW { betas: (f32, f32), wd: f32 },           // 8
    AdamWAmpFp16 { ... },                           // 12
    AdamW8bit { ... },                              // 2.1
    PagedAdamW8bit { ... },                         // 2.1
    Lion { ... },                                   // 4
    LoraAdamW { rank: u32, base_d: u32 },           // 8 × (rank/base_d)
    Zero2 { n_gpu: u32 },                           // 8 / n_gpu
    Zero3 { n_gpu: u32 },                           // 8 / n_gpu (param/grad 도 shard)
}

struct BatchSpec {
    bsz: u32,
    seq_len: u32,
    n_layer: u32,
    d_model: u32,
    n_head: u32,
    n_kv_head: u32,                // GQA → cheaper KV cache
    grad_checkpoint: bool,
}

struct GpuSpec {
    kind: str,                     // "H100-80GB-HBM3"
    mem_bytes: u64,
    reserved_overhead: u64,        // CUDA context + driver + temps; 4 GiB 기본
}
```

### §2.3 closed-form budget calculator

```hexa
fn mem_budget_check(job: &CloudJob) -> Result<MemBudgetBreakdown, BudgetExceededError> {
    let p_bytes  = bytes_of(job.model.param_dtype)
    let g_bytes  = bytes_of(job.model.grad_dtype)
    let n        = job.model.n_params as u64

    let params      = n * (p_bytes as u64)
    let grads       = n * (g_bytes as u64)
    let opt_state   = (n as f64 * optimizer_state_multiplier(&job.optimizer)) as u64
    let activations = activation_envelope(&job.batch, &job.model)
    let temps       = 8_u64 * GIB                            // conservative
    let total       = params + grads + opt_state + activations + temps + job.gpu.reserved_overhead

    let cap = job.gpu.mem_bytes
    let breakdown = MemBudgetBreakdown { params, grads, opt_state, activations, temps, total, cap }

    if total > cap {
        return Err(BudgetExceededError {
            breakdown,
            suggest: optimizer_downgrade_path(&job.optimizer),
        })
    }
    // headroom guard — 15% 미만이면 경고하되 통과
    if total > cap * 85 / 100 {
        warn("preflight: budget within 15% of cap — high OOM risk")
    }
    Ok(breakdown)
}

fn optimizer_state_multiplier(o: &OptimizerSpec) -> f64 {
    match o {
        Sgd                => 0.0,
        SgdMomentum        => 4.0,
        AdamW{..}          => 8.0,
        AdamWAmpFp16{..}   => 12.0,
        AdamW8bit{..}      => 2.1,
        PagedAdamW8bit{..} => 2.1,
        Lion{..}           => 4.0,
        LoraAdamW{rank, base_d} => 8.0 * (rank as f64 / base_d as f64),
        Zero2{n_gpu}       => 8.0 / (n_gpu as f64),
        Zero3{n_gpu}       => 8.0 / (n_gpu as f64),
    }
}

fn activation_envelope(b: &BatchSpec, m: &ModelSpec) -> u64 {
    let base = (b.bsz as u64) * (b.seq_len as u64) * (b.d_model as u64) * (b.n_layer as u64)
    let factor: f64 = if b.grad_checkpoint { 2.0 } else { 18.0 }  // 10-25 envelope, midpoint
    let bytes_f = factor * (bytes_of(m.param_dtype) as f64)
    (base as f64 * bytes_f) as u64
}
```

`optimizer_downgrade_path` 는 source note 의 ladder 그대로 (`AdamW → AdamW8bit
→ PagedAdamW8bit → Lion → ZeRO-2 → ZeRO-3 → grad_checkpoint → smaller_bsz`).

### §2.4 falsifiers (5)

| # | id | claim | verify |
|---|---|---|---|
| 1 | F-PREFLIGHT-OOM-CATCH | S187 3B + AdamW + bsz=4 spec 입력 시 BudgetExceededError 반환 (cap=80 GiB) | spec fixture commit + unit test |
| 2 | F-PREFLIGHT-PASS-VALID | S187 3B + PagedAdamW8bit + bsz=2 spec → Ok(breakdown), total ≤ 58 GiB ± 10% | spec fixture commit + unit test |
| 3 | F-CLOSED-FORM-ACCURATE | breakdown.total prediction vs `nvidia-smi memory.used` at step 5 within ±15% | post-spinup verify-step harness |
| 4 | F-NO-LLM-NO-POD | preflight 실행 중 외부 LLM 호출 0건, pod-spinup 0건 (network egress 0) | tcpdump / strace harness |
| 5 | F-DETERMINISTIC | 같은 spec → 같은 breakdown bytes-identical (random seed 영향 없음) | 100회 반복 byte-eq |

## §3 design — typed env-var (gap#2)

### §3.1 schema

```hexa
enum EnvType {
    Str,         // plain string
    Int,         // 정수 (parse failure = reject)
    Path,        // 파일/디렉터리 (spaces 허용, escape 강제)
    Secret,      // log 에 redact, $(secret get ...) 로만 resolve
    MultiLine,   // \n 포함 허용, base64 transport
}

// env field of CloudJob:
//   env: [(str, EnvType, str)]   // (name, type, default)
//
// e.g.
//   env: [
//     ("PYTORCH_CUDA_ALLOC_CONF", Str, "expandable_segments:True"),
//     ("CUDA_VISIBLE_DEVICES",    Str, "0"),
//     ("WANDB_API_KEY",           Secret, ""),                  // $(secret get wandb.api_key)
//     ("DATA_DIR",                Path,   "/workspace/data"),
//   ]
```

### §3.2 pre-dispatch validation

1. 각 `(name, type, default)` 에 대해 type-specific lint:
   - `Int` → `_atoi(v)` round-trip 가능해야 함
   - `Path` → ASCII or UTF-8 only, NUL 금지, ASCII control 금지
   - `Secret` → empty 면 `secret get <key>` 시도, 미존재 시 reject
   - `MultiLine` → base64 wrap 강제, raw newline 금지

2. shell escape 검증 (cycle A 의 POSIX-quote 와 정합):
   - 모든 value 는 `_posix_quote()` 통과 후 ssh argv 에 삽입
   - `"` `'` `$` `\`` `\\` 가 raw 로 나가지 않음을 byte-eq assert
   - multi-line 은 base64 → 원격에서 `base64 -d` (수신측 helper)

3. `verify_env` post-launch:
   - `ssh pod 'grep -lZ "<name>=" /proc/$PID/environ'` 가 non-empty 보장
   - 실패 시 job abort, pod teardown 트리거

### §3.3 escape rules

| 입력 | EnvType | 변환 | 송출 |
|---|---|---|---|
| `expandable_segments:True` | Str | POSIX-quote | `'expandable_segments:True'` |
| `/path with spaces/data` | Path | POSIX-quote (single-quoted, 공백 허용) | `'/path with spaces/data'` |
| `xoxb-...` | Secret | `secret get` resolve + POSIX-quote + log redact | `'***REDACTED***'` (log) |
| `line1\nline2` | MultiLine | base64 encode | `'bGluZTEKbGluZTI='` (decode by remote helper) |

### §3.4 falsifiers (5)

| # | id | claim | verify |
|---|---|---|---|
| 1 | F-ENV-REACHED | dispatch 후 원격 `/proc/$PID/environ` 에 `name=value` byte-eq 존재 | grep round-trip unit |
| 2 | F-ENV-QUOTE-ROBUST | `"`, `'`, `$`, backtick, `\\`, newline 포함 value 도 escape 무사 통과 (round-trip eq) | fuzz fixture |
| 3 | F-ENV-TYPE-REJECT | type-mismatch (`Int` 에 `"abc"`) 는 pre-dispatch 에서 reject, pod-spinup 0건 | unit test |
| 4 | F-ENV-SECRET-REDACT | `Secret` value 가 stdout/stderr/log 어디서도 plain text 노출 없음 | log scrape harness |
| 5 | F-ENV-MULTILINE-ROUNDTRIP | `MultiLine` value 가 base64 round-trip 후 원격 byte-eq (newline 포함) | unit test |

## §4 cross-link

- **RFC 085 (sibling)** — dispatcher hygiene (worktree branch parity, deploy-regen
  wipe 방지). 본 RFC 가 새 verb 를 추가하므로 dispatcher hygiene 의 wipe-guard
  대상 (`stdlib/cloud/cloud.hexa`, `cloud_cli.hexa`) 에 자연히 포함.
- **stdlib/cloud** — `cloud.hexa` (lib), `cloud_cli.hexa` (verb 분기), 본
  RFC 의 `mem_budget_check`, `optimizer_state_multiplier`, `activation_envelope`
  는 새 모듈 `stdlib/cloud/preflight.hexa` 로 분리, `cloud_cli.hexa::main` 에서
  `preflight` 분기 시 호출.
- **`hexa cloud` verb** — `self/main.hexa:4693` (subcommand dispatch entry).
  `_cloud_help` 의 verb list 갱신 + `preflight` 분기 추가 필요.
- **commons.tape g8** — 본 RFC 머지 후 sidecar `commons.tape` g8 의 canonical
  form 예시에 `hexa cloud preflight <spec>` 추가 권고 (sidecar PR 별도).
- **`@D g_atlas_absorb_direct`** — 본 RFC 가 머지되면 atlas 자동 흡수 후보
  (preflight family, env-typing family). embed_fold direct splice 경로.

## §5 implementation plan (선언적 — 본 RFC 는 코드 0)

P0 — typed records 선언 (`stdlib/cloud/preflight.hexa` 신규).
P1 — `mem_budget_check` + 5 falsifier unit test (F1–F5).
P2 — `verify_env` SSH 후-launch 어설션 (gap#2 의 P1 ladder).
P3 — `cloud_cli.hexa::main` 에 `preflight` 분기 + `_cloud_help` 갱신.
P4 — `self/main.hexa` 의 `hexa cloud` 자체 verb 가 새 `preflight` subverb 인지 (이미 cycle B-3 에서 verb 디스패치는 wire 됨, 도움말만 갱신).
P5 — sidecar `commons.tape` g8 canonical 예시 갱신 (별도 sidecar PR).

각 P 는 독립 PR. 메모리 `[[project_stdlib_cloud_cycle_a]]` 의 6-PR 패턴 그대로
A → B-1 → B-2 → B-2.1 → B-3 → B-2.2 처럼 점진 land.

## §6 honest carve-out

- **활성 영역 envelope ±2×**: §2.3 의 `activation_envelope` factor=18 은
  10–25 envelope 의 midpoint. Flash Attention vs vanilla, SDPA vs eager,
  KV-cache reuse 에 따라 실측 ±2×. budget check 는 **lower bound 추정** 으로
  취급, 15% 헤드룸 강제 (§2.3 warn 분기).
- **PagedAdamW8bit paging**: CPU paging 은 transient peak 보험이지 steady-state
  reducer 가 아님. preflight 는 steady-state 만 검증, dynamic allocator 폭주는
  out-of-scope (F-CLOSED-FORM-ACCURATE 가 ±15% 안에서만 책임).
- **`n_params` 은 measured 여야 함**: 선언값이 아니라 모델 빌드 후 측정값. 본
  RFC 의 schema 는 `n_params: u64` 를 받지만 dispatch tooling 에서 `hexa
  model-introspect <model.hexa>` (별도 verb, RFC 088 범위 밖) 로 채워야 함.
  workaround: dispatch 스크립트 헤더 코멘트에 `print(sum(p.numel() for p in
  model.parameters()))` 출력 직후 hand-fill.
- **Secret 의 `secret get` 의존성**: macOS Keychain 백엔드는 dispatch host
  로컬. 원격 pod 에는 transport via env (이미 redact 처리됨). `secret get` 미설치 host 는
  reject — sidecar `skills/secret` 플러그인 필수 의존.
- **`hexa cloud preflight` 는 cost-bearing 아님**: 외부 LLM 0건, pod-spinup 0건,
  network egress 0 — F-NO-LLM-NO-POD falsifier 가 이를 강제.

## §7 워크어라운드 (RFC 머지 전)

§2 까지 land 되기 전, dispatch 스크립트는:

1. `n_params` 를 optimizer 빌드 **전** 출력 (S187 attempt10 `train_s187_3b.py:247` 패턴)
2. dispatch.sh 헤더에 `state_mem = n_params × multiplier` hand-compute 후 30% 헤드룸 미만이면 refuse
3. `bsz ≥ 1B param × 80 GB 단독` 인 경우 기본 `PagedAdamW8bit`
4. `nvidia-smi memory.used` step 5/50/200 polling, 90% cap 넘으면 OOM 임박
5. env-var 는 dispatch 스크립트 안에 `echo $VAR` 라인 + 원격 `grep /proc/PID/environ` 사후 확인

attempt 10 (S187, 2026-05-21) 가 위 5 단계 모두 수행 → $4 burn 으로 7/8 pod
step 200+ 통과 (vs $40+ budget cap).

## §8 acceptance summary

- 5 + 5 = 10 falsifier 모두 PASS 시 RFC 088 closure.
- 본 RFC 는 **inbox doc only** — 코드 변경 0건.
- 머지 후 별도 PR 체인 (P0–P5) 으로 실제 wiring. 각 PR 은 독립 falsifier.

(끝.)
