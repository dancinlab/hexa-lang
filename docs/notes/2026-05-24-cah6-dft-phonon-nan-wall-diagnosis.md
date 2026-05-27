# CaH₆ DFT phonon Sternheimer NaN wall — root-cause 진단 (finding note)

filed: 2026-05-24
related_patch: archive/patches/cah6-dft-phonon-sternheimer-nan-wall-2026-05-24.md
related_rfc:   docs/rfc/rfc_drafts_2026_05_24/rfc_088_hexa_cloud_preflight.md
status:        finding-only (no hexa-lang surgical fix)

## TL;DR (한 줄)

NaN wall 본체는 **downstream Quantum ESPRESSO `ph.x` Sternheimer
linear-response 수렴 실패** (b) 이고, 부차적으로 **hexa cloud preflight /
fail-fast watcher gap** (c) 가 cost burn 을 증폭시켰다. hexa-lang 내부
코드 버그 (a) 는 없다.

## root cause 분류

- **(a) hexa-lang 내부 버그** — 없음. patch 본문이 지목하는 대상은
  `tr2_ph` / `nmix_ph` / `electron_phonon` / Sternheimer 등 **Quantum
  ESPRESSO ph.x 입력 파라미터** 와 MPI rank scaling 이며, hexa-lang
  컴파일러 · runtime · stdlib 에는 해당 코드 경로가 없다.

- **(b) downstream 라이브러리** — **본체**. QE 7.0 (pool:ubu-1 apt) ·
  QE 7.5 (Vast conda) 두 버전 모두에서 small-cell (7-atom) + dense 6³q
  + 압력 응력 잔존 인풋 조합이 ph.x Sternheimer kernel 의 수치 발산
  (`thresh < NaN`) 및 MPI deadlock 을 유발. fix 는 QE 측 입력 튜닝
  (patch 의 breakthrough paths 1–5) 으로 demiurge 캠페인에서 처리.

- **(c) cloud preflight gap** — RFC 088 (`rfc_088_hexa_cloud_preflight`)
  이 이미 promote 되어 있고 본 patch 의 P0–P3 권고가 그 RFC scope 와
  **부분 겹침**:

  | patch P# | 권고 | RFC 088 흡수 여부 |
  |---|---|---|
  | P0 | Sternheimer NaN fail-fast (log grep watcher) | **미흡수** — RFC 088 은 LLM training (optimizer state) 위주, DFT log-pattern watcher 는 §2 schema 밖 |
  | P1 | small-cell `-np` sweet-spot preflight | **미흡수** — RFC 088 의 closed-form 은 GPU mem 만, MPI rank × atom-count 도메인은 별도 추정자 필요 |
  | P2 | done.flag dual-marker (`CAH6_DONE` + QE native `JOB DONE`) | **미흡수** — watcher 강화는 RFC 088 §2 의 `verify_env` 와 별도 축 |
  | P3 | dual-platform symptom diff auto-collect | **미흡수** — RFC 088 §외 |

  → RFC 088 v2 (또는 sibling RFC) 에서 **DFT/HPC workload axis** 추가가
  올바른 흡수 경로. 본 finding 만으로 즉시 fix 시도하지 않음.

## 왜 본 라운드에서 hexa-lang fix 시도를 보류하나

1. cycle 12 lane 3 가 "cloud_cli 에 preflight subverb 가 없네" 에서
   끊긴 정황은 정확하지만, 그 subverb 추가는 RFC 088 scope (LLM mem
   budget) 와 본 patch scope (DFT log-watcher / MPI rank) 가 **서로
   다른 도메인** 이라 단일 commit 으로 흡수할 수 없다.
2. RFC 088 본문 §2.2 schema (`ModelSpec` · `OptimizerSpec` · `BatchSpec`)
   는 transformer training 가정으로 closed-form 이 짜여 있어 DFT
   small-cell + q-grid 입력을 그대로 받지 못한다 — schema 확장 자체가
   RFC-level 결정.
3. P0 의 `grep -c "thresh < NaN" ph.out > 100` 같은 log-pattern
   watcher 는 `stdlib/cloud/` 의 어떤 verb 분기에도 표면이 없고,
   추가하려면 watcher 추상화 + plug-in 등 별도 설계가 필요. cycle 12
   원래 truncated scope 와 정합.

## 후속 권장 (carry-forward)

1. **demiurge 측**: patch §"breakthrough paths" 1–5 (tr2_ph 완화 ·
   nmix_ph 증가 · -np 8 재탐색 · vc-relax 선행 · interpolated recovery)
   를 다음 CaH₆ campaign 라운드에서 1-by-1 적용 · log diff 수집.
2. **hexa-lang RFC 088 follow-up**: §2.2 schema 에 `WorkloadKind`
   enum (`LlmTraining` | `DftPhonon` | `Md` | ...) 도입 검토 — DftPhonon
   variant 는 (atom-count, q-grid, plane-wave cutoff, MPI ranks) 를
   인풋으로 받는 별도 추정자.
3. **새 RFC 후보 (`rfc_NNN_cloud_log_watcher`)**: P0/P2 log-pattern +
   sentinel dual-marker watcher 추상화 — 본 patch + S187 typed env-var
   note + RTSC BEE-NET stub gap (`hexa-cloud-preflight-stub-...md`)
   세 source 가 watcher / verify-step 패턴 공유.

## 검증

본 finding 은 정적 분석만 수행했다 (외부 GPU/cloud 호출 없음):

- `stdlib/cloud/cloud_cli.hexa` grep: `preflight` keyword 미존재 (cycle
  12 발언 confirm).
- `docs/rfc/rfc_drafts_2026_05_24/rfc_088_hexa_cloud_preflight.md` 본문
  §1–§2 scan: LLM training mem-budget 도메인 한정 확인.
- 본 patch 본문 (`cah6-dft-phonon-sternheimer-nan-wall-2026-05-24.md`)
  의 모든 fix-target 이 QE ph.x 입력 또는 MPI rank scaling 임을 확인.

## 결론

본 patch 는 **filing-only** 로 inbox 에 보존하고, 분류표 (b downstream
+ c cloud-RFC follow-up) 를 patch 본문에 명시 (이번 PR 의 별도 edit).
즉시 hexa-lang 컴파일 surgical fix 는 없다.
