---
rfc: 091
title: hexa cloud preflight v2 — DFT/HPC workload axis (sibling of RFC 088)
status: proposed
priority: medium
filed: 2026-05-24
filed_by: claude-code worktree agent-a81cebd8204c92922
target_ssot: stdlib/cloud/preflight.hexa · stdlib/cloud/cloud_cli.hexa (`hexa cloud preflight`)
unblocks:
  - cah6-dft-phonon-finding
sibling:
  - rfc_088
related:
  - docs/rfc/rfc_drafts_2026_05_24/rfc_088_hexa_cloud_preflight.md (sibling — LLM training axis · RFC 088 §2 schema 의 DFT 확장)
  - docs/notes/2026-05-24-cah6-dft-phonon-nan-wall-diagnosis.md (cycle 13 lane 2 finding — DFT/HPC axis 미흡수 명시)
  - archive/patches/cah6-dft-phonon-sternheimer-nan-wall-2026-05-24.md (source patch — QE ph.x NaN wall · MPI rank scaling)
  - memory [[reference_runpod_heavy_build]] (RunPod 운영 컨텍스트)
  - memory [[project_stdlib_cloud_cycle_a]] (6-PR 머지된 cloud verb 패턴)
  - commons.tape g8 (canonical `hexa cloud` form)
governance:
  - "@D g_cloud_no_raw_shell — DFT/HPC dispatch 도 hexa cloud verb 로만"
---

# RFC 091 — hexa cloud preflight v2 (DFT/HPC workload axis)

## §1 동기 (motivation)

RFC 088 (`rfc_088_hexa_cloud_preflight`) 는 hexa-cloud preflight 의 **LLM
training axis** 만 흡수했다 — `ModelSpec` · `OptimizerSpec` · `BatchSpec`
가 모두 transformer 가정으로 closed-form 이 짜여 있어 (n_params,
optimizer multiplier, activation envelope) DFT / phonon / MPI-scaled HPC
workload 의 입력 도메인을 받지 못한다.

`docs/notes/2026-05-24-cah6-dft-phonon-nan-wall-diagnosis.md`
(cycle 13 lane 2 #624) 의 분류표가 이를 명시한다:

| patch P# | 권고 | RFC 088 흡수 여부 |
|---|---|---|
| P0 | Sternheimer NaN fail-fast (log grep watcher) | **미흡수** — DFT log-pattern watcher 는 §2 schema 밖 |
| P1 | small-cell `-np` sweet-spot preflight | **미흡수** — RFC 088 closed-form 은 GPU mem 만, MPI rank × atom-count 별도 추정자 필요 |
| P2 | done.flag dual-marker (`CAH6_DONE` + QE native `JOB DONE`) | **미흡수** — `verify_env` 와 별도 축 |
| P3 | dual-platform symptom diff auto-collect | **미흡수** — RFC 088 §외 |

→ finding 의 결론: **RFC 088 v2 또는 sibling RFC 에서 DFT/HPC workload axis
추가가 올바른 흡수 경로**. 본 RFC 가 그 sibling.

### §1.1 cah6 NaN wall — 비용 메커니즘

CaH₆ DFT phonon campaign (demiurge) 에서 다음이 측정됐다:

- QE 7.0 (pool:ubu-1 apt) · QE 7.5 (Vast conda) 두 버전 모두 small-cell
  (7-atom) + dense 6³q + 압력 응력 잔존 입력 조합에서 `ph.x` Sternheimer
  kernel 이 `thresh < NaN` 발산 또는 MPI deadlock
- pod-spinup ($0.05) + boot ($0.50) + Sternheimer step attempt ($0.30+)
  → **$0.85+/pod × N attempts** burn 후 사후 grep `ph.out` 로만 표면화
- attempt 10 회 이상에서야 hand-tuning (tr2_ph 완화 · nmix_ph 증가 · -np 8
  재탐색) 으로 통과

핵심: 모든 wall 은 **dispatch host 에서 사전 falsifiable** —
- log-pattern (e.g. `thresh < NaN`, `convergence NOT achieved`) watcher 가
  step-0 이후 N 초 안에 grep 가능
- MPI rank sweet-spot 은 Amdahl + atom-count + memory budget 의 closed-form
- cell size × q-grid 결합으로 NaN 임박을 dual-marker 사전 신호

### §1.2 LLM axis 와의 차이

RFC 088 의 closed-form 은 (params, grads, opt_state, activations, temps)
의 정적 mem-budget. DFT/HPC 는 다음이 다르다:

- **mem-budget 단위가 GPU 단독이 아니라 MPI rank × per-rank memory**
- **수치 발산이 step-1 OOM 이 아니라 N step 후 Sternheimer 수렴 실패**
- **backend 다양성** — QE (`ph.x`) · VASP (`vasp_std`) · ABINIT (`abinit`)
  · CP2K 등 각자 다른 log convention
- **failure mode 가 log-grep 으로만 표면화** — exit code 0 인데 결과 NaN

이 모든 차이가 §2 schema 와 §3 falsifier 의 별도 축을 요구.

### §1.3 RunPod 운영 컨텍스트 (RFC 088 §1 와 공유)

메모리 `[[reference_runpod_heavy_build]]`:
- RunPod CPU pod 재고 거의 없음 → MPI CPU job 도 GPU SECURE pod 에서 SECURE
  for RAM 으로 잡아야 함
- ubuntu2404 base
- pod 종료 후 `runpodctl remove pod <id>` 필수

본 RFC 의 preflight 가 pod-spinup 전 falsify 하면 비용 0원. step-0 후
log-watcher 가 일찍 신호하면 spinup + 1-step ≈ $0.85 burn 후 **자동
teardown** 트리거 가능.

## §2 design — DFT/HPC preflight 게이트

### §2.1 verb 확장 (RFC 088 §2.1 와 정합)

`stdlib/cloud/cloud_cli.hexa::_cloud_help` 의 verb 목록에 이미 RFC 088
이 추가하는 `preflight` 가 있다. 본 RFC 는 **그 verb 의 spec schema 를
DFT/HPC variant 로 확장** 하는 것이지 새 top-level verb 를 추가하지 않는다.

```
hexa cloud preflight <spec.toml | spec.hexa>
# spec.workload 가 DftPhonon | Md | Hpc 면 §2 의 DFT axis 평가
# spec.workload 가 LlmTraining 이면 RFC 088 §2 의 LLM axis 평가 (그대로)
```

watcher (§2.4) 는 별도 subverb 또는 `preflight --watch` flag.

### §2.2 typed record schema — WorkloadKind enum 도입

RFC 088 의 `CloudJob` 에 `workload: WorkloadKind` 필드 추가, 도메인별
별도 spec 분기:

```hexa
enum WorkloadKind {
    LlmTraining(LlmSpec),           // RFC 088 §2.2 schema 그대로
    DftPhonon(DftPhononSpec),       // 본 RFC
    Md(MdSpec),                     // 후속 RFC scope (skeleton 만)
    Hpc(HpcSpec),                   // 후속 RFC scope (skeleton 만)
}

struct DftPhononSpec {
    backend: DftBackend,            // Qe70 | Qe75 | Vasp64 | Abinit95 | Cp2k90
    atoms: AtomSpec,
    qgrid: (u32, u32, u32),         // e.g. (6,6,6)
    plane_wave_cutoff_ry: u32,      // Ry
    sternheimer: SternheimerSpec,
    mpi: MpiSpec,
    convergence: ConvergenceSpec,
}

enum DftBackend {
    Qe70,   Qe75,
    Vasp64,
    Abinit95,
    Cp2k90,
}

struct AtomSpec {
    n_atoms: u32,                   // 7 for CaH₆
    cell_volume_a3: f64,            // Å³
    has_residual_stress: bool,      // vc-relax 미선행 시 true
}

struct SternheimerSpec {
    tr2_ph: f64,                    // threshold (default 1e-12; relax to 1e-10 for small cell)
    nmix_ph: u32,                   // mixing history (default 4; increase to 8)
    alpha_mix: f64,                 // 0.7 default
    max_iter: u32,                  // 100 default
}

struct MpiSpec {
    n_ranks: u32,
    ranks_per_node: u32,
    bind_to: str,                   // "core" | "socket" | "none"
    per_rank_mem_gib: u32,          // measured at probe step
}

struct ConvergenceSpec {
    watch_patterns: [LogPattern],   // §2.4
    timeout_s: u32,
    dual_marker: bool,              // CAH6_DONE + native JOB DONE
}
```

### §2.3 closed-form: MPI rank sweet-spot 계산기

Amdahl + memory budget 기반:

```hexa
fn mpi_sweet_spot(spec: &DftPhononSpec, gpu_or_cpu_node: &NodeSpec) -> Result<u32, MpiRangeError> {
    // 1. atom-count lower bound — 너무 적은 atom 에 너무 많은 rank 는 communication overhead
    let min_atoms_per_rank: u32 = 1
    let upper_by_atoms = spec.atoms.n_atoms / min_atoms_per_rank   // 7-atom → ≤7 ranks 권장
    // 실측: 7-atom + np=16 → comm-bound deadlock, np=8 sweet spot

    // 2. per-rank memory bound — plane-wave cutoff × atom-count
    let est_per_rank_mem_gib = estimate_qe_rank_memory(spec)
    let upper_by_mem = gpu_or_cpu_node.total_mem_gib / est_per_rank_mem_gib

    // 3. Amdahl 직렬 fraction — Sternheimer 의 ~15% 은 직렬
    let serial_fraction = 0.15_f64
    let speedup_at = |np: u32| -> f64 {
        1.0 / (serial_fraction + (1.0 - serial_fraction) / np as f64)
    }
    // Amdahl 점근 한계는 1/serial_fraction = 6.67×

    let upper_bound = min(upper_by_atoms, upper_by_mem)
    if upper_bound < 2 {
        return Err(MpiRangeError::TooFewRanks { atoms: spec.atoms.n_atoms })
    }

    // 4. sweet spot — efficiency ≥ 70% 이상에서 최대 np
    let mut best = 1_u32
    for np in 1..=upper_bound {
        let eff = speedup_at(np) / np as f64
        if eff >= 0.70 { best = np }
    }
    Ok(best)
}
```

cah6 finding 의 실측 (7-atom · np=16 deadlock · np=8 통과) 와 정합 —
`upper_by_atoms = 7`, sweet spot ≤ 7 (실측 8 은 hyper-thread 1-rank 여유분).

### §2.4 dual-marker sentinel + log-pattern watcher

NaN wall 사전 감지를 위한 watcher 추상화 (cycle 13 lane 2 finding 의 P0/P2 통합):

```hexa
struct LogPattern {
    needle: str,                    // grep needle
    severity: PatternSeverity,      // Info | Warn | Wall
    action: WatchAction,            // Continue | Abort | Teardown
    threshold_count: u32,           // N matches → trigger
}

enum PatternSeverity { Info, Warn, Wall }

enum WatchAction { Continue, Abort, Teardown }

// QE Sternheimer 표준 wall patterns (backend = Qe70 | Qe75)
fn qe_default_walls() -> [LogPattern] {
    [
        LogPattern { needle: "thresh < NaN",            severity: Wall, action: Teardown, threshold_count: 1 },
        LogPattern { needle: "convergence NOT achieved", severity: Wall, action: Teardown, threshold_count: 1 },
        LogPattern { needle: "Error in routine",         severity: Wall, action: Abort,    threshold_count: 1 },
        LogPattern { needle: "kpoint not found",         severity: Warn, action: Continue, threshold_count: 5 },
    ]
}

// dual-marker — campaign-side sentinel + backend-native done marker
fn dual_marker_check(stdout: &str, campaign_sentinel: &str, backend_done: &str) -> JobStatus {
    let campaign_done = stdout.contains(campaign_sentinel)   // e.g. "CAH6_DONE"
    let native_done   = stdout.contains(backend_done)         // e.g. "JOB DONE."
    match (campaign_done, native_done) {
        (true,  true)  => JobStatus::Complete,
        (true,  false) => JobStatus::CampaignFraudulent,      // 캠페인 측 마킹은 됐는데 backend 안 끝남
        (false, true)  => JobStatus::IncompleteHarness,       // backend 끝났는데 캠페인 sentinel 없음
        (false, false) => JobStatus::Running,
    }
}
```

watcher 는 `hexa cloud preflight --watch <pod-id>` 또는
`hexa cloud poll --watch-patterns` flag 로 step-0 후 polling.

### §2.5 cross-backend symptom diff

같은 spec 을 두 backend (e.g. QE 7.0 vs QE 7.5) 에 동시 dispatch 후
log-pattern hit 의 byte-eq 비교 — backend-version-specific 회피 가능
여부를 자동 진단:

```hexa
fn cross_backend_diff(spec: &DftPhononSpec, backends: &[DftBackend]) -> CrossBackendReport {
    let mut hits: Map<DftBackend, Vec<PatternHit>> = Map::new()
    for b in backends {
        let spec_b = spec.with_backend(*b)
        let log = dispatch_probe(&spec_b)                     // 짧은 probe — 30s timeout
        hits.insert(*b, scan_patterns(&log, &qe_default_walls()))
    }
    diff_pattern_hits(&hits)                                  // 어느 backend 만 wall hit 인지
}
```

이 verb 는 cost-bearing (probe 가 실제 pod 사용) 이지만 1-step 짜리
preflight 보다도 짧음 (~$0.1/backend), 본격 dispatch 전 적합한 backend
선정.

## §3 falsifiers (5)

| # | id | claim | verify |
|---|---|---|---|
| 1 | F-NAN-WALL-CATCH | cah6 spec (7-atom · 6³q · default tr2_ph) → watcher 가 `thresh < NaN` 1회 grep 후 1초 안에 `Teardown` 시그널 | log fixture + watcher unit test |
| 2 | F-MPI-SWEET-SPOT | 7-atom DftPhononSpec → `mpi_sweet_spot` 가 np ∈ [4, 8] 반환 (np=16 reject) | unit test |
| 3 | F-MEM-BUDGET-DFT | (cell=120Å³ · pw_cutoff=80Ry · n_ranks=8) → per-rank mem-budget 추정 vs `ph.x` step-0 의 `MemoryStatus` MB 출력 ±20% | post-spinup verify-step harness |
| 4 | F-CONVERGENCE-PROBE | dual-marker `CAH6_DONE` + native `JOB DONE.` 가 둘 다 발견 → `Complete`, 하나만 발견 → 해당 분기 fault 반환 | log fixture |
| 5 | F-CROSS-BACKEND | QE 7.0 vs QE 7.5 둘 다 같은 wall pattern hit → version-specific 회피 불가, 한쪽만 hit → workaround 가능 분류 | log fixture (cah6 wall hit on both confirmed) |

## §4 cross-link

- **RFC 088 (sibling)** — LLM training axis. 본 RFC 의 `WorkloadKind`
  enum 이 RFC 088 의 `CloudJob` 에 새 필드 `workload` 로 추가됨. RFC 088
  §2.2 의 `ModelSpec` / `OptimizerSpec` / `BatchSpec` 는 `LlmTraining`
  variant 의 payload 로 이동, 본 RFC 의 `DftPhononSpec` 는 새 variant.
  RFC 088 P0–P5 implementation plan 과 RFC 091 P0–P5 는 **공유
  `stdlib/cloud/preflight.hexa` 모듈** 에서 enum dispatch.
- **cah6 finding note** — `docs/notes/2026-05-24-cah6-dft-phonon-nan-wall-diagnosis.md`
  의 후속 권장 §2 (`WorkloadKind` enum 도입) 와 §3 (새 RFC 후보) 가 본
  RFC 로 직접 흡수.
- **cah6 patch** — `archive/patches/cah6-dft-phonon-sternheimer-nan-wall-2026-05-24.md`
  의 breakthrough paths 1–5 는 demiurge campaign-side (QE 입력 hand-tuning),
  본 RFC 는 그 burn 을 사전 falsify 하는 hexa-lang side preflight 추상화.
- **stdlib/cloud** — `cloud.hexa` (lib), `cloud_cli.hexa` (verb 분기),
  본 RFC 의 `mpi_sweet_spot`, `dual_marker_check`, `cross_backend_diff`,
  `qe_default_walls` 는 RFC 088 의 `stdlib/cloud/preflight.hexa` 동일
  모듈에 합류 (enum dispatch 로 분기). 메모리
  `[[project_stdlib_cloud_cycle_a]]` 의 6-PR 패턴 그대로 점진 land.
- **`hexa cloud` verb** — `self/main.hexa` 의 subcommand dispatch entry.
  RFC 088 가 추가하는 `preflight` 분기 안에서 `spec.workload` enum
  dispatch — 새 verb 추가 없음.
- **`@D g_atlas_absorb_direct`** — 본 RFC 머지 후 atlas 자동 흡수 후보
  (DFT preflight family, MPI sweet-spot family, dual-marker family).

## §5 implementation plan (선언적 — 본 RFC 는 코드 0)

P0 — `WorkloadKind` enum + `DftPhononSpec` 선언 (`stdlib/cloud/preflight.hexa`,
RFC 088 P0 와 합류 PR).
P1 — `mpi_sweet_spot` + F-MPI-SWEET-SPOT 단위 test.
P2 — `qe_default_walls` + `LogPattern` watcher + F-NAN-WALL-CATCH 단위 test.
P3 — `dual_marker_check` + F-CONVERGENCE-PROBE 단위 test.
P4 — `cross_backend_diff` + F-CROSS-BACKEND fixture-based test (실제
backend 호출은 별도 verify-step).
P5 — `mem_budget_check` DFT 분기 + F-MEM-BUDGET-DFT post-spinup harness.

각 P 는 독립 PR. 메모리 `[[project_stdlib_cloud_cycle_a]]` 의 6-PR 패턴.

## §6 honest carve-out

- **DftPhononSpec 만 covers — Md / Hpc 는 skeleton 만**: `WorkloadKind`
  enum 에 `Md(MdSpec)` · `Hpc(HpcSpec)` variant 자리 잡되 payload struct
  본문은 후속 RFC scope. 현재 RFC 091 의 acceptance 는 DftPhonon variant
  closure 만.
- **Amdahl serial_fraction 0.15 는 QE Sternheimer 추정치**: backend
  별로 달라질 수 있음. cah6 finding 의 실측 (np=16 deadlock · np=8 sweet)
  는 QE 7.0/7.5 specific. VASP / ABINIT 별도 calibration 필요.
- **per-rank memory estimator 는 plane-wave 기준 only**: PAW augmentation,
  ultrasoft pseudopotential, hybrid functional 등은 ±20% envelope 내에서만
  honest — F-MEM-BUDGET-DFT 도 ±20% 만 강제.
- **dual-marker 는 campaign-side cooperation 필요**: backend 가 native
  done marker 만 출력하면 `IncompleteHarness` 분류 — 캠페인 script 가
  `CAH6_DONE` 같은 sentinel 을 명시 출력해야 `Complete` 도달.
- **cross-backend diff 는 probe cost 있음** (per-backend ~$0.1):
  F-NO-LLM-NO-POD (RFC 088 falsifier 4) 와 달리 본 verb 는 의도된
  probe-cost 허용. doc 에 명시.
- **WorkloadKind enum 도입은 RFC 088 의 spec breaking change**:
  RFC 088 의 `CloudJob` 에 `workload` 필드 추가 → 기존 RFC 088 fixture 는
  `workload: LlmTraining(...)` 로 wrapping migration 필요. 두 RFC
  머지 순서는 (RFC 088 base → RFC 091 enum 확장) 권고.

## §7 워크어라운드 (RFC 머지 전)

§2 까지 land 되기 전 demiurge cah6 campaign 은:

1. `ph.x` dispatch 시 hand-set tr2_ph=1e-10 · nmix_ph=8 (cah6 patch
   breakthrough path 1–2)
2. small-cell (7-atom) 은 np ≤ 8 강제, np 검색은 [4, 6, 8] 만
3. step-0 후 10s polling 으로 `ph.out` 에 `thresh < NaN` 또는
   `convergence NOT achieved` grep → 발견 시 `runpodctl remove pod <id>`
   즉시 teardown
4. campaign script 끝에 `echo CAH6_DONE` + 별도 `grep -c "JOB DONE." ph.out`
   검사를 hand-roll
5. QE 7.0 (ubu-1 apt) 와 QE 7.5 (Vast conda) 두 환경에 같은 spec dispatch
   → 한쪽만 통과하면 그 version 으로 lock

attempt 10 (CaH₆, 2026-05-23) 가 위 5 단계 모두 hand-roll 로 수행 →
~$0.85 burn 으로 통과. 본 RFC 머지 후 5 단계 모두 declarative.

## §8 acceptance summary

- 5 falsifier (F-NAN-WALL-CATCH · F-MPI-SWEET-SPOT · F-MEM-BUDGET-DFT ·
  F-CONVERGENCE-PROBE · F-CROSS-BACKEND) 모두 PASS 시 RFC 091 closure.
- 본 RFC 는 **inbox doc only** — 코드 변경 0건.
- 머지 후 별도 PR 체인 (P0–P5) 으로 실제 wiring. RFC 088 의 P0–P5 와
  공유 `stdlib/cloud/preflight.hexa` 모듈에서 enum dispatch.
- RFC 088 와 RFC 091 의 머지 순서는 (RFC 088 base → RFC 091 enum 확장)
  권고 — `WorkloadKind` enum 도입이 RFC 088 spec 의 breaking change 이므로.

(끝.)
