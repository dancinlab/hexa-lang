---
rfc: 086
title: Atlas memcap unblock — n6/atlas.n6 single SSOT 후속 AtlasView 물질화
status: proposed
priority: high
created: 2026-05-24
authors:
  - dancinlab
supersedes:
  - inbox/rfc_drafts_2026_05_20/rfc_066_atlas_memcap_unblock.md
unblocks:
  - rfc_066  # original draft now retrospectively SSOT-shifted
related:
  - rfc_065  # hexa loop (already closed 2026-05-20)
  - rfc_080  # hexa loop --dfs (already merged via PR #309)
governance:
  - "@D g_atlas_binary_builtin"
  - "@D h_atlas_single_export"  # 2026-05-22 — n6/atlas.n6 single artifact
  - "@D g6 citation-enforced-strict-lint"
---

# RFC 086 — Atlas memcap unblock (n6/atlas.n6 SSOT 시대의 stdlib AtlasView 물질화)

## §0 요약 (TL;DR)

원안 **RFC 066** (`inbox/rfc_drafts_2026_05_20/rfc_066_atlas_memcap_unblock.md`)
은 stdlib/* 가 `use "compiler/atlas/embedded.gen"` 을 통해 `AtlasView` 를
물질화할 때 hexa_v2 transpiler 가 **>4 GB memcap** 을 초과하는 문제를
A+B 하이브리드 (Option A 8 kinds × per-kind baked siblings + Option B
C kind HXC sidecar) 로 풀려 했고 — 그 land 자체는 **PR #136
(`ecd4d042`, 2026-05-20) + 직전 `7e6fa692` (B-1b C-kind HXC)** 로
**closure measured** 됐다.

그러나 **단 2일 후 (2026-05-22)** atlas SSOT 자체가 paradigm-shift 했다:
PR #312 `07c9819b atlas: retire hxc — n6/atlas.n6 single-artifact SSOT
(15,958 nodes)` → PR #314 → PR #315 → PR #316 (`374e0d8d`,
`dist/atlas.hxc` 물리 삭제, no-hxc closure final). 즉:

- RFC 066 의 Option B (HXC sidecar) 는 **전면 falsified** — HXC layer 자체가 retire 됨.
- RFC 066 의 Option A (per-kind baked siblings) 는 `compiler/atlas/by_kind/*.gen.hexa` 8개로 **여전히 main 에 존재**하나, `static_atlas()` 이 이제 `n6/atlas.n6` 를 직접 파싱(`load_atlas(env("HEXA_ATLAS_N6"))`)하므로 by_kind 의 역할은 **legacy 흔적** 으로 축소.

RFC 086 은 이 paradigm-shift 를 **공식 RFC 로 promote** 하고, 새 SSOT
하의 stdlib AtlasView 물질화 경로를 단일 RFC 로 통합한다. 코드 변경은
이미 main 에 land 됐으므로 (PR #312/#314/#315/#316), 이 RFC 는
**retrospective + forward-looking spec** 형태로 다음 4 가지를
명시한다:

1. **무엇이 RFC 066 의 의도였는지** (4 GB memcap 회피).
2. **왜 paradigm-shift 가 발생했는지** (HXC 사이드카가 RC3 lossy 압축 + sibling-CWD drift 로 SSOT 무결성을 해침).
3. **현 (2026-05-24) 의 실제 동작** (n6/atlas.n6 단일 텍스트 SSOT + `merger::load_atlas` 라인 파서).
4. **잔여 작업** (pool 재배포 후 by_kind/* 정리 · `tool/atlas_build_hxc.hexa` · `compiler/atlas/hxc_loader.hexa` 의 안전 삭제 sequencing).

---

## §1 motivation (배경 — 왜 이 RFC 가 필요한가)

### §1.1 RFC 066 원래 문제

`compiler/atlas/embedded.gen.hexa` 는 ~24 000 (현재는 ~15 952) `AtlasNode`
const-literal entry 를 캐리한다. stdlib/* 모듈이 `use
"compiler/atlas/embedded.gen"` 를 하면 hexa_v2 transpiler 가 모든
struct-literal 을 consumer 의 translation unit 에 flatten 하면서 macOS
4 GB user-time 아레나를 초과한다 (`rss=4166MB > cap=4096MB`).

이는 RFC 065 `hexa loop` Phase C-2 (`stdlib/loop/cycle.hexa::cycle_scan`)
의 직접 blocker 였다.

### §1.2 RFC 066 A+B 하이브리드 (closure measured 2026-05-20)

PR #136 (`ecd4d042`) 머지 시점에 다음이 land 됐다:

| component | path | status |
|---|---|---|
| Option A (per-kind split) | `compiler/atlas/by_kind/{p,l,e,f,r,s,x,q}.gen.hexa` (8 kinds, C 제외) | LANDED |
| Option B (C kind HXC sidecar) | `dist/atlas.hxc` + `compiler/atlas/hxc_loader.hexa::load_atlas_c_nodes()` | LANDED (`7e6fa692`) |
| `LensNode.kinds` metadata | `compiler/lenses/types.hexa::LensNode` | LANDED |
| `cycle_scan` lazy-load | `stdlib/loop/cycle.hexa::cycle_scan` 가 union of kinds 만 import | LANDED |

falsifier F2 (largest kind L 가 단독으로도 4 GB 초과) 는 측정 결과
**P=PASS · L=PASS · C=FAIL** 로 정확히 RFC 066 §5.1 표가 예측한 대로
fire 했고, fallback prescription (C-only Option B) 이 정확히 적용됐다.

### §1.3 2026-05-22 paradigm shift (HXC retire)

PR 시리즈 #312 → #314 → #315 → #316 가 다음을 단행했다:

- **#312 (`07c9819b`)** — `atlas: retire hxc — n6/atlas.n6 single-artifact SSOT (15,958 nodes)`
  - `n6/atlas.n6` (text, 15,952 nodes, 3.43 MB) 를 vendored 한다.
  - `static_atlas()` 가 `load_atlas(env("HEXA_ATLAS_N6"))` 를 호출하도록 rewire.
  - hxc_loader import 라인은 deprecation 주석과 함께 보존.
- **#314 (`85d029de`)** — anima append shard 들을 `n6/atlas.n6 + appends` 로 단일 consolidate.
- **#315 (`d72bce8f`)** — stale hxc 참조 sweep (`atlas.n6 is sole SSOT`).
- **#316 (`374e0d8d`)** — runtime fix (`hexa_list_dir segfault`) + `dist/atlas.hxc` 물리 삭제 (no-hxc closure final).

**왜 retire 됐는가** — incident-driven (요약, 자세히는 메모리
`project_atlas_hxc_irreplaceable_ssot` 참조):

1. **RC1**: `static_atlas` 의 hxc 경로가 sidecar CWD-relative 로
   풀려 다른 dir 에서 실행 시 "missing/empty" 로 보고.
2. **RC2**: fallback hint 가 lossy rebuild 를 유도.
3. **RC3**: `tool/atlas_build_hxc.hexa` 가 LEAN `embedded.gen`
   (~7 448 nodes) 만 읽어 canonical `dist/atlas.hxc` 를
   15 952 → 7 448 로 **silent shrink** (lost @F 1268 / @R 6315
   / @X 1574 / @S 6 / @Q 83).
4. **Deepest**: full hxc 에는 in-repo source 가 없었다 (`anima/n6/atlas.n6`
   은 deleted `~/core/nexus` 를 가리키는 symlink).

요컨대 **HXC sidecar 는 자체 lossy compression + dual-SSOT drift 로
SSOT 무결성을 위협** 했다. n6 text 가 ground truth 가 됨으로써 이
계급의 incident class 자체가 제거됐다.

### §1.4 후속 정리 (이 RFC 가 명시할 것)

- RFC 066 Option B (HXC sidecar) 는 **falsified** — 그러나 그 결정 자체는 당시 정보 하에서 옳았다.
- RFC 066 Option A (per-kind baked siblings) 는 **여전히 main 에 존재** 하지만 새 SSOT 하에서 **legacy** 로 분류 — `merger::load_atlas` 가 n6 를 직접 streams-parse 하므로 transpile-time flatten 문제 자체가 사라졌다.
- 새 SSOT 의 잔여 sequencing (메모리 §"Sequencing (still TODO — do NOT delete hxc out of order)") 이 이 RFC 의 phase plan §6 에 통합된다.

---

## §2 option survey (현재 시점에서 유효한 4 옵션)

원안 RFC 066 §4 는 A/B/C 3 옵션을 비교했지만, 2026-05-22 paradigm-shift
이후 옵션 landscape 가 재편됐다. 현재 (2026-05-24) 유효한 옵션은
다음 4 개다:

### Option A* — per-kind baked siblings (RFC 066 land 된 형태 유지)

`compiler/atlas/by_kind/{p,l,e,f,r,s,x,q}.gen.hexa` 8 파일은 그대로
유지하고, consumer 가 declared `kinds` 에 따라 lazy-import. C 는 HXC
sidecar 가 폐기됐으므로 별도 처리 필요.

- **Pros**: code 가 이미 land · `LensNode.kinds` 메타데이터 그대로 활용.
- **Cons**: 새 SSOT (`n6/atlas.n6`) 와의 dual-source drift 위험 (regen tool 이 어느 SSOT 에서 읽는가). C-kind 가 여전히 미해결.

### Option B* — n6/atlas.n6 streaming parse (현재 main 구현)

`merger::load_atlas(path)` 가 n6 텍스트를 **line-by-line streams-parse**
한다. transpile-time flatten 이 발생하지 않으므로 4 GB memcap 문제
자체가 **자연 소멸**.

- **Pros**: 무결성 보장 (single text SSOT, byte-grep 가능) · transpile cost 0 · stdlib consumer 가 자유롭게 `load_atlas` 호출 가능.
- **Cons**: startup 시 한 번 텍스트 파싱 — measured cost 는 §3.3 에 추가 필요. by_kind siblings 가 redundant 가 됨.

### Option C* — by_kind 정리 후 단일 n6 직접 사용 (Option B* + cleanup)

Option B* 를 채택하고 by_kind siblings 를 **단계적으로 retire**:
RC1/RC2/RC3 incident class 와 동일하게 dual-SSOT drift 위험을 제거.
sequencing: (a) pool 재배포, (b) 신규 binary 의 n6 path 검증,
(c) `compiler/atlas/by_kind/` + `tool/atlas_embed_gen.hexa` 의
`--split-by-kind` 플래그 + `compiler/atlas/embedded.gen.hexa` 삭제.

- **Pros**: SSOT 단일화 완성 · regen tool 단일화 (`hexa atlas pr` 가 n6 에만 append) · 사용자 mental model 명확화.
- **Cons**: pool 재배포 + 검증 단계 필요 · 거버넌스 (`@D g_atlas_binary_builtin`) 의 "binary built-in" 해석 명시 재진술 필요 (embedded.gen retire 시 atlas 가 더 이상 binary 의 rodata 가 아니므로).

### Option D* — n6 → embedded.gen 둘 다 유지 (dual SSOT, drift-guard 강화)

n6 를 ground truth 로 유지하고 embedded.gen 을 build-time mirror 로
재생성. drift 감지를 위한 hash 비교 CI step 추가.

- **Pros**: binary built-in 정신을 형식적으로도 유지.
- **Cons**: 정확히 RC1/RC3 incident 가 발생한 패턴의 회귀 — drift CI 가 perfect 가 아니면 silent shrink 가 다시 발생 가능.

---

## §3 design (선택된 옵션 + concrete API)

### §3.1 채택: Option C* (n6 single SSOT + 단계적 cleanup)

이미 2026-05-22 paradigm-shift 가 사실상 Option B* 까지 진행됐다.
이 RFC 는 Option C* 로 **closure 한다**:

1. **n6/atlas.n6 = single SSOT**. `merger::load_atlas` 가 stream parse.
2. `static_atlas()` 가 `env("HEXA_ATLAS_N6")` 를 읽고 미설정 시
   `~/core/hexa-lang/n6/atlas.n6` 로 fallback (메모리 정의대로 stable, NOT CWD-relative).
3. **모든 stdlib consumer** (`hexa loop`, `hexa atlas pr`, 미래 scanners) 는 동일 진입점 사용 — transpile-time flatten 부재 → 4 GB memcap 문제 자동 해소.
4. by_kind/* + embedded.gen + hxc layer 는 **deprecation queue** 에 등록 (phase plan §6).

### §3.2 concrete API (no code change — 이미 main 의 SSOT)

```hexa
// compiler/atlas/static_index.hexa  (현재 main)
fn static_atlas() -> AtlasIndex {
    let path = env("HEXA_ATLAS_N6")
    let resolved = if path == "" { default_n6_path() } else { path }
    return load_atlas(resolved)  // merger::load_atlas, streams-parse n6
}

// compiler/atlas/merger.hexa::load_atlas — line-by-line:
//   @P / @C / @L / @E / @F / @R / @X / @S / @Q 헤더 sigil 감지
//   _is_header_sigil() (parser.hexa:157,159) 으로 in-body @END/@META 제외
//   현재 15,952 source nodes (memory § "Static proof of merger correctness")
```

stdlib consumer 측:

```hexa
// stdlib/loop/cycle.hexa::cycle_scan  (already-landed shape)
use "compiler/atlas/static_index"
fn cycle_scan() {
    let view = static_atlas()  // 단일 진입점 — kinds 메타데이터 불필요
    for lens in active_lenses() { lens.apply(view) }
}
```

### §3.3 memory footprint 분석 (claim, 측정 필요)

- **현재 (2026-05-24, main)**: `n6/atlas.n6` = 3.43 MB text · 15,952 nodes.
- **load_atlas streams-parse**: per-line append to per-kind array; 가정 average node-size in-memory ≈ 250 B → ~4 MB resident steady-state.
- **transpile-time cost**: 0 (text 파일이라 const-literal flatten 미발생).
- **이 RFC 의 falsifier MEMCAP-LOAD-15K (§4) 가 위 가정 검증**.

기존 RFC 066 의 4 GB memcap 측정 표 (P=PASS · L=PASS · C=FAIL) 는
**superseded** — n6 streaming parse 하에서 모든 kind 가 동일 진입점을
거치므로 kind 별 차등이 의미 없어졌다.

---

## §4 falsifiers (5개)

### F1 — MEMCAP-LOAD-15K

`hexa run` (또는 컴파일된 stdlib consumer) 이 `static_atlas()` 를 한 번
호출하여 15,952 nodes 를 모두 in-memory 로 로드한 직후 resident set
size 가 **4 GB 를 초과하면 falsified**.

- 측정: `stdlib/loop/cycle.hexa::cycle_scan` 일 회 호출 후 `getrusage(RUSAGE_SELF).ru_maxrss`.
- 기대값: ≤ 100 MB (n6 text 3.43 MB + parsed struct in-memory ~4 MB + runtime overhead).

### F2 — ATLAS-VIEW-API

`static_atlas()` 가 반환하는 `AtlasIndex` 가 (a) 9 kind 모두에 대해
non-empty (P/L/C/E + 가능한 F/R/X/S/Q), (b) `lookup_static(kind, id)`
가 임의의 sampled 100 nodes 에 대해 **id 일치 + grade 일치 + edge-degree
일치** 를 만족해야 한다. 어느 하나라도 mismatch → falsified.

- 측정: byte-stable round-trip — `load_atlas(n6/atlas.n6)` →
  in-memory → 임의 100 node id 샘플링 → `lookup_static` 결과 vs
  text grep 으로 직접 추출한 raw column 일치.

### F3 — LAZY-FETCH

n6 streams-parse 가 **lazy 가 아니라 eager** 임을 명시한다 (전체 파일을
한 번에 로드). 만약 lazy access pattern 이 필요해진다면 (e.g.
stdlib/loop 가 P kind 만 필요), `load_atlas_kind(kind: string)` 진입점이
**별도** 로 추가돼야 한다. 이를 시도하면 hxc_loader 잔재가 재진입
하는 RC1 패턴이므로 falsified.

- 측정: `compiler/atlas/merger::load_atlas` 외 atlas-load API
  surface 가 추가됐는지 lint. (현재 main 기준 surface = 1.)

### F4 — STREAMING-MMAP

만약 n6/atlas.n6 가 향후 100 MB 이상으로 자라면 (e.g. anima 흡수
~100× 확장), full read-to-memory 전략이 깨질 수 있다. 이 RFC 는
**현 규모 (3.43 MB · 15,952 nodes)** 의 안전성만 보증한다. n6 가
50 MB 를 넘어선 시점에 mmap 기반 lazy-line iter API 가 필요해지면
이 RFC 는 retrospective falsified (후속 RFC 가 필요해진다).

- 측정: `wc -c n6/atlas.n6 > 52428800` 라면 RFC 086 후속 (RFC 087+) 트리거.

### F5 — BACKWARDS-COMPAT (by_kind retire sequencing breach)

`compiler/atlas/by_kind/*.gen.hexa` 의 단계적 retire (phase plan §6
참조) 는 **순서 보존** 이 필수다. pool 재배포 전에 by_kind 를
삭제하거나 `embedded.gen.hexa` 를 삭제하면 deployed `~/.hx/bin/hexa` 가
구 `static_atlas` 경로로 hxc/embedded.gen 을 읽으려 시도하다 fail.
이 순서가 깨지면 falsified.

- 측정: phase plan §6 step 사이의 git diff 가 명시된 순서대로 land 됐는지 audit.

---

## §5 cross-link

### §5.1 동시대 RFC 와의 관계

- **RFC 065** (`hexa loop` self-growing atlas cycle) — **CLOSED**
  measured 2026-05-20 (PR #136 `ecd4d042`, 91 candidate/cycle · 36/36
  lens body real). 본 RFC 086 의 직접 consumer.
- **RFC 066** (atlas memcap unblock, A+B hybrid) — **이 RFC 가 supersede**.
  A+B hybrid 자체는 closure measured 됐으나 즉시 paradigm-shift 됐다.
- **RFC 080** (`hexa loop --dfs` DFS+LLM atlas expansion) — **CLOSED**
  measured (PR #309 `1fa94066` + Phase K PR #317 `086ba046`). 본 RFC 의
  n6 SSOT 위에서 DFS 가 동작하므로 양립.

### §5.2 거버넌스 anchor

- `@D g_atlas_binary_builtin` — 원안: "atlas 는 binary built-in,
  PR-only". n6 single SSOT 시대의 재해석: "atlas 는 `~/core/hexa-lang/n6/`
  에 vendored single-text-artifact 로 ship, PR-only".
- `@D h_atlas_single_export` — 2026-05-22 PR #314 (`85d029de`) 에서 등록.
  "atlas append 은 n6/atlas.n6 또는 `n6/atlas.append.*.n6` shard 로만,
  embedded.gen 또는 hxc 직접 편집 금지".
- `@D g6 citation-enforced-strict-lint` — 영향 없음 (`@cite atlas_node_id`
  의 lookup 은 진입점에 무관).
- `@D g_interp_deprecated` — n6 text 파싱은 compiled path 에서만 발생
  (interp 에서는 stub).

### §5.3 SSOT 파일

- `n6/atlas.n6` (15,952 nodes, 3.43 MB, vendored). **ground truth**.
- `n6/atlas.append.*.n6` shards. **incremental append** (e.g.
  `anima-historical-absorption-2026-04-26`, `session-2026-04-28-raw-*`).
- `compiler/atlas/static_index.hexa` — `static_atlas()` 진입점.
- `compiler/atlas/merger.hexa` — `load_atlas()` 라인 파서.
- `compiler/atlas/parser.hexa` — `_is_header_sigil()` + `_first_token()` 라인 분류.

### §5.4 메모리 cross-link

- [[project_atlas_hxc_irreplaceable_ssot]] — 2026-05-22 paradigm-shift 의 incident chain + sequencing 원본.
- [[project_rfc065_self_growing_atlas]] — RFC 065 closure 의 36/36 · 91/cycle · A+B hybrid 사용 측정.
- [[project_runtime_md_step3_step4_progress]] — runtime build-shadow sync (n6 가 build/self/ 에 deploy 될 때의 staleness gotcha).
- [[feedback_runtime_c_deploy_regen_wipe]] — atlas-side regen 의 wipe 패턴 (n6 단일 SSOT 가 정확히 이 wipe class 를 막는다).

---

## §6 phase plan (이 RFC 의 잔여 작업 sequencing)

이미 land 된 paradigm-shift 의 follow-through 만 남았다.

| phase | deliverable | gate | status |
|---|---|---|---|
| **A** — 이 RFC | spec + retrospective + Option C* declaration | reviewable, 0 코드 변경 | 본 PR |
| **B-1** | pool (`mini`, `ubu-2`) 의 `~/.hx/bin/hexa` 재배포 — 신규 `static_atlas` (n6 path) 활성화 | pool host 에서 `hexa atlas verify` → 15,952 nodes 보고 | PENDING ([[atlas SSOT]] 메모리 §Sequencing step 1) |
| **B-2** | 재배포된 binary 의 startup parse cost 측정 (n6 3.43 MB read+parse) | 측정값 < 500 ms (claim, F1 falsifier 와 분리) | PENDING |
| **B-3** | `compiler/atlas/embedded.gen.hexa` 의 `use` 라인 + `compiler/atlas/embedded.gen.hexa` 자체 삭제 | grep audit clean · 모든 selftests PASS | PENDING |
| **B-4** | `compiler/atlas/by_kind/*.gen.hexa` 삭제 (RFC 066 Option A 흔적 정리) | `grep -r "by_kind" --include="*.hexa"` empty | PENDING |
| **B-5** | `tool/atlas_build_hxc.hexa` + `compiler/atlas/hxc_loader.hexa` + 모든 hxc 잔재 삭제 | `find . -name "*hxc*" -path "*atlas*"` empty | PENDING |
| **C-1** | `@D g_atlas_binary_builtin` 의 정의 갱신 — "binary built-in" → "vendored single-text-artifact PR-only" 표현 정련 | AGENTS.tape 1-line edit + 거버넌스 sweep | OPTIONAL (어휘 정련) |

순서 enforcement: **B-1 → B-2 → B-3 → B-4 → B-5**. B-3 이상이 B-1 보다
먼저 land 되면 F5 falsifier 가 fire 한다.

---

## §7 open questions (gating 아님)

- **OQ-1**: `n6/atlas.n6` 와 `n6/atlas.append.*.n6` shards 간 dedup
  semantic — append shard 가 atlas.n6 와 동일 id 를 다른 raw 로 정의
  하면? `merger::load_atlas` 가 last-writer-wins 인지 reject 인지 명시 필요.
- **OQ-2**: n6 가 50 MB → 100 MB 로 성장 시 mmap iter API 트리거
  (F4 falsifier 의 후속). 신규 RFC 가 필요할 수 있다.
- **OQ-3**: `hexa atlas pr` 의 n6-only emit path 가 모든 9 kind 에
  대해 byte-stable append 인지 (memory `project_atlas_hxc_irreplaceable_ssot`
  §"Cycle 2" 가 `append-witness` 9-kind 확장을 기록).

---

## §8 Sign-off checklist (Phase A landing)

- [x] RFC 065 closure 사실 명시 (§1.2 · §5.1)
- [x] RFC 066 supersede 명시 (frontmatter · §0 · §1.4)
- [x] paradigm-shift incident chain 재진술 (§1.3)
- [x] 5 falsifiers 정의 (§4)
- [x] cross-link 완성 (§5)
- [x] phase plan 의 sequencing enforcement 명시 (§6 · F5)
- [ ] reviewer 가 §3 Option C* 채택 + §6 sequencing 에 동의
- [ ] approved → 파일이 `inbox/rfc_landed/` 로 이동 + B-1 (pool 재배포) 트리거
