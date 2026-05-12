# `atlas.n6` Retirement Plan + nexus→hexa CLI 전환 검토

> 후속 문서: `doc/nexus_cli_audit.md` (2026-05-09, 9/12 흡수 매핑).
> 작성: 2026-05-12. 전제 — hexa CLI 가 `atlas.n6` + scrub 작업을 100% 흡수했다는 사용자 진술.

## 0. 현 상태 요약 (audit + grep 확인) — **historical, §0a 로 대체됨**

- atlas SSOT = `~/core/canon/atlas/` (owner canon, 2026-04-21 재결정). `data/n6/` = backward-compat symlink.
- `atlas.n6` + `atlas.append.*.n6` 는 컴파일 빌드 시점에 `compiler/atlas/embedded.gen.hexa` 로 baked, `ATLAS_HASH` pin, runtime cost 0ms (`SPEC.md` §2.2).
- hexa-lang 측 atlas runtime: `compiler/atlas/{static_index,parser,merger,embed,embedded.gen}.hexa`.
- hexa-lang 측 append/promote/tombstone cycle: `compiler/discover/{staging,promote,tombstone,retroactive_sweep,cascade}.hexa`.
- nexus 측 atlas.n6 file 직접 read: `engine/nexus_cli.hexa`, `tool/check_atlas.hexa`, `bin/atlas3d`, `tool/verify.hexa`.
- scrub 관련 출처: `doc/runbook/raw_determinism.md` Tier 1–4 (locale/clang/SOURCE_DATE_EPOCH/map-iter/fs-sort/strip/pid-hostname-user/random/endian).

---

## 0a. 현 상태 재확인 (2026-05-12 audit-redo)

§0 가 작성된 직후 grep 으로 4 액션 (Phase 0 인벤토리, dispatch 점검, scrub 범위, SSOT 위치) 을 모두 돌렸더니 §0 의 **두 핵심 전제가 깨짐**. §1–§5 는 §0a 기준으로 다시 읽어야 함.

### 0a.1 atlas SSOT 위치
- 실제 SSOT = `~/core/nexus/n6/atlas.n6` (3.0 MB, 2026-05-02 mtime) + `atlas.append.*.n6` 9 shard (2026-04-27).
- `compiler/atlas/merger.hexa:146` default root = `$HOME/core/nexus/n6` (canon 아님).
- `~/core/canon/atlas/` 디렉터리는 **존재하지 않음** — canon repo 가 2026-05-11 RETIRED (Wave 1–6 분산 이관, 잔여 `nexus/canon-infra/legacy-canon/`).
- `data/n6/` symlink 도 hexa-lang tree 에서 부재.
- **즉 SSOT 형태는 여전히 "단일 파일 + 데이트 shard"** (디렉터리 트리 아님).

### 0a.2 hexa CLI 흡수 실태
- audit 가 가정한 `compiler/cli/dispatch.hexa` 모듈은 **부재**.
- 실제 dispatch = `self/main.hexa:2164-2481` 의 flat `if sub == "..."` chain.
- 현 subcommand: help / version / status / cc / run / batch / bench / parse / lsp / build / check (= `@invariant` DSL, atlas 아님) / convergence / test / init / url.
- `hexa atlas` / `hexa bus` / `hexa discovery` / `hexa roadmap` / `hexa smash` / `hexa free` / `hexa thinking` / `hexa lens` 는 `self/main.hexa:2458` 에서 `$NEXUS/shared/bin/nexus-cli` 로 **PROXY** — 흡수 0%.
- `hexa scrub` / `hexa verify scrub` subcommand 도 **부재**.

### 0a.3 scrub 흡수 실태
- `tool/determinism_scan.hexa` **미존재** — `raw_determinism.md` §6 가 직접 "`.roadmap#18` 도입 예정" 명시.
- Tier 1 (locale / clang pin / `-O2` / `SOURCE_DATE_EPOCH`): 산발적 `LC_ALL=C` 호출만 존재, scanner 없음.
- Tier 2 (map iter / fs sort / strip): scanner 없음.
- Tier 3 (pid / hostname / user / random): scanner 없음.
- Tier 4 (endian): scanner 없음.
- `tool/{verify_fixpoint,fixpoint_check,fixpoint_compare,fixpoint_bisect,fixpoint_archive}.hexa` 5종 존재하나 단일 진입점 (예: `hexa verify`) 으로 통합 안 됨.

### 0a.4 Phase 0 인벤토리 (in this commit)
- 산출: `state/atlas_n6_callers.tsv` — 13 hexa-lang 사이트 + nexus 측 50개 `*.hexa` mention 인덱스.
- 진짜 read/write 사이트는 hexa-lang 내 **8개** (`merger.hexa`, `tool/atlas_embed_gen.hexa`, `tool/atlas_append_check.hexa`, `discover/{promote,staging,tombstone,retroactive_sweep,cascade}.hexa`).
- **Bit-rotted callers 2건**: `tool/foundation_axiom_lock.hexa:31` (`/Users/ghost/core/canon/atlas/atlas.n6` 하드코딩, macOS 절대경로 + canon 폐기 이중 사망), `tool/drill_classify.hexa:36` (`ROOT/../canon/atlas/atlas.n6`). 둘 다 현 호스트에서 동작 불가 — atlas.n6 폐기 전에 우선 정리 후보.

### 0a.5 audit doc 정합성
- `doc/nexus_cli_audit.md` 가 surface 로 든 4개 중:
  - `engine/nexus_cli.hexa` ✓ 실존
  - `tool/check_atlas.hexa` ✗ nexus 트리에서 부재
  - `bin/atlas3d` ✗ 바이너리 부재, `docs/atlas3d.html` 만 잔존
  - `tool/verify.hexa` ✓ 실존
- 즉 audit 의 surface map 도 일부 stale.

### 0a.6 §1–§5 영향
- **§1 "흡수 매핑" 표**: 모든 행이 "사용자 진술: 흡수" 전제. 실측 0% → 표 자체가 aspirational. 흡수 작업이 plan 본체가 됨.
- **§2 Phase 1 "Generator 입력을 디렉터리 트리로"**: SSOT 가 디렉터리가 아니라 단일 파일. 이 단계는 **불필요** (또는 "단일 파일을 디렉터리로 reshape" 라는 별개 사전 작업 필요).
- **§2 Phase 3 "symlink 회수"**: symlink 부재 → no-op.
- **§3 ATLAS_HASH 안정성**: 디렉터리 walk 가 없으니 walk-order 게이트 자체가 적용 안 됨. 현재 merger 의 `list_dir + lexical sort` 가 단일 게이트.

---

## 0c. 2026-05-12 (session 2) — Phase 3 land + Phase 4–8 blocker

Second session same day (ubu-1 ControlMaster after ubu-2 auth fail). Added:

- **Phase 1.5 — re-regen on macOS-canonical source** (commit `b55b9f92`):
  the session 1 embed was built from Linux mirror (stale 10일 fork);
  session 2 found macOS `~/core/nexus/n6/atlas.n6` was actually canonical
  (4.2 MB vs Linux 3.0 MB, fork at byte 979,780). New embed: P=253 / C=5943
  / L=388 / E=10 (총 6594 노드, sha256 `663698a0bc6f967fa2855a77bc4e399aae465dda5ca948b3c7352dbf98ce7fb`).
- **Phase 2 — `hexa atlas` read-only CLI** (commit `a7d8aaa3`): hash /
  stats / lookup / dump, zero-I/O over `static_atlas()`. self/main.hexa
  wired `hexa atlas` → tool/atlas_cli.hexa (direct), 기존 nexus-cli proxy
  에서 atlas 만 분기.
- **Phase 3 — `hexa atlas append-witness`** (commits `336ed7bb` + `815d2354`):
  staging shard writer. Shard format = 5 `//` header lines + blank +
  body + blank + `// EOF —` terminator. The blank line is load-bearing
  due to a deployed-interp parser drift bug (see below).

### 2026-05-12 session 2 추가 — Phase 4 / 5 / 7 land, Phase 8 만 잔존

세션 2 후반에 nexus repo 측 (별도 PR 트랙, push 미실시) 마이그레이션 작업:

| Phase | nexus commit | 내용 |
|---|---|---|
| 4 | `6b5d4626` | `omega_cycle_atlas_ingest._absorb_shard_to_main` 호출 제거 (dual-write retire) |
| 5 w1/3 | `2f395618` | `n6/hub_leaf_promote.hexa` → shard emit (edges) |
| 5 w2/3 | `d8b9d748` | `tool/bt_atlas_pipe.hexa` `_guarded_append_atlas` → `_emit_atlas_shard` |
| 5 w3/3 | `04b7e3db` | `n6/scripts/atlas_phase46_canonical_nodes.hexa` 제안 텍스트 갱신 |
| 6 | — | scripts/n6_ops 가 이미 nexus 측 commit `68acce70` 에서 삭제됨 (auto-effective) |
| 7 r1/3 | `083c41b3` | `mk2_hexa/mk2/src/atlas/lookup.hexa` grep target 에 shard 추가 |
| 7 r2/3 | `7a269f3a` | `cli/blowup/todo.hexa` line_count + 4-pattern awk 가 shards 도 read |
| 7 r3/3 | `36df4643` | `cli/blowup/compose.hexa` init gate 가 shard-only state 허용 |

이 변경들은 모두 write_file / exec(shell) 만 사용 → 어떤 것도 buggy interp 의 parser 호출 안 함 (parser drift 영향 0).

### Phase 8 (atlas.n6 + shards 실제 삭제) — CLOSED 2026-05-12 (session 3)

**완료 상태:** nexus `2df92aed` — `n6/atlas.n6` + 409 shards 삭제 (96551 줄, 7.4 MB). hexa-lang `d2c5af7b` 의 깨끗한 embed (sha256 663698a06bc6...) 가 유일한 source-of-truth.

#### 정정 진단 (root cause 확정)

이전 §0c 의 "`use "compiler/atlas/parser"` module-loader parity drift" 진단은 **잘못된 추론**이었다. 실제 원인:

> stage0 `hexa_interp` 의 `continue` 가 nested `if { if { continue } }` 에서
> outer if 의 다음 statement 를 skip 하지 못함. parser.hexa 의 `c0 != "@"`
> branch 가 ws-push + fallback-push 를 모두 실행 → continuation 라인 odd-dup.

상세 minimal repro 와 fix 경로: [RFC-029](../incoming/rfc_drafts_2026_05_12/rfc_029_continue_scope_nested_if.md).
memory entry: `feedback_hexa_interp_nested_continue.md`.

#### 적용된 fix (최종 형태 — RFC-029 Phase 1/2/3 모두 완료)

- **interp 진짜 fix (`94fbbc19`)**: `self/hexa_full.hexa::eval_body` 에 `break_flag`/`continue_flag` 추가 → nested-if continue 가 정상 동작.
- **parser.hexa**: 원본 `if { continue }` early-exit 형태로 복귀 (간결성 회복). Phase 3a 에서 workaround 제거.
- **`tool/atlas_embed_gen_inline.hexa`**: 삭제. 원본 `tool/atlas_embed_gen.hexa` 가 canonical (use-based).
- **embed 파일 (`compiler/atlas/embedded.gen.hexa`)**: 그대로 — n6/ source 가 nexus `2df92aed` 에서 삭제되어 regen 불가. 본 embed 가 frozen SSOT.

#### 결과 (2026-05-12 session 3)

```
1. inline gen 재실행:                           PASS (load 119s, emit 218s, total 337s)
2. embed sha256:                                663698a06bc6...(content fingerprint 동일)
3. embed file size:                             2916436 → 3266142 (dup 제거 + 누락 복원)
4. psi_alpha 'ln(2)/2^5.5' continuation:        복원 (이전 embed 에서 누락)
5. ANIMA-psi-alpha-corrected node:              복원
6. compiler/atlas/static_index_test.hexa:       9/9 PASS
```

#### Phase 8 closure 실행 기록

```
[1] hexa-lang d2c5af7b  ✓ parser workaround + clean embed + RFC-029
[2] nexus    58e7c930   ✓ dirty pre-rm commit (ANIMA-psi-alpha-corrected)
[3] nexus    2df92aed   ✓ rm n6/atlas.n6 + 409 shards (96551줄, 7.4MB)
```

보존:
  - `n6/atlas.n6.bak.pre-promote-20260421_173217` (백업)
  - `n6/atlas.millennium.n6`, `n6/atlas.signals.n6` (별개 데이터셋, 무관)
  - `n6/_absorbed/2026-05-06/atlas.append.*.n6` (archive, 무관)

Blocker #3 (ubu-1 SSH) 무관해짐 — Mac local 에서 모든 검증 완료.

### Phase 7 잔여 미세 readers (낮은 우선순위)

대부분 dead code 또는 진단용:
- `discovery/_h3_probe.hexa` — wc -l 진단 (HOME path 도 stale `$HOME/Dev/nexus`)
- `n6/atlas_3d_node_sync.hexa` — atlas.n6 → mirror sync; atlas.n6 사라지면 자연스럽게 무용
- `n6/atlas_shard_gc.hexa` — manifest mtime 만 봄, content read X
- `cli/run.hexa` — 다른 tool 의 console output parse, atlas.n6 직접 read X
- `cli/blowup/seed/seed_dna.hexa` — path 변수 선언만 (line 21), 실제 read 사용처 추가 audit 필요

이들은 Phase 8 이후 (또는 atlas.n6 삭제와 함께) cleanup.

---

### Phase 4–8: BLOCKED on deployed-interp parser drift

Phase 3 dogfood revealed a **deployed hexa_interp parser-state bug** that
makes any further automated absorption unsafe:

1. **Leading-comment count parity**: `parse_atlas_file` returns 0 nodes
   when the body `@` header is preceded by an odd number of `//` comments
   (0,2,4,6 → 1 node; 1,3,5,7 → 0 nodes). Workaround: blank line between
   header and body (resets parser state). Encoded into shard emit format.

2. **Continuation-line corruption** (worse): when parser DOES return a
   node, the `.raw` is mangled — odd-indexed continuation lines
   duplicate, even-indexed drop. Dogfood input of 5 continuation lines
   (`<-`, `->`, `=>`, `==`, `|>`) parsed to 6 lines with `->` and `==`
   dropped, the others doubled.

Source `compiler/atlas/parser.hexa` is correct. The drift is in
`~/.hx/packages/hexa/build/hexa_interp` (Mac arm64 stage1 binary built
from older sources). Same root cause family as memory entry
`project_sh3_phase2f_interp_drift` ("fn-arg map TAG_MAP not incref'd in
env_define").

**Consequence for Phase 4+:** every nexus writer migration via `hexa atlas
append-witness` would produce shards whose data is silently corrupted on
the next regen (which itself runs through the buggy interp).

**Required prerequisite cycle:** `build(stage0): re-promote hexa_interp`
from current `self/hexa_full.hexa`. Same cycle that needs to land the
`file_size` portability fix (`150e0220`). Until then Phase 4–8 stays
parked.

### Note on currently-shipped `compiler/atlas/embedded.gen.hexa`

The `b55b9f92` embed (sha256 `663698a0…`, 6594 nodes) was produced by
the same buggy interp. **Node counts and the file digest are correct**
(parser handles node-boundaries fine — only continuation accumulation
drifts), but the `raw` field of every multi-line P/C/L/E node has the
duplicate/drop pattern in its continuation lines. Smoke `hash` / `stats`
PASS because they don't inspect `.raw` semantics. Downstream consumers
that only need `(kind, id, [11*]-tier, source_file)` are unaffected;
consumers that read `raw` for the `<-` / `->` / `==` / `|>` body
relations get corrupted data.

The re-promote cycle should be followed by a fresh regen against current
macOS-canonical atlas.n6 to land a clean embed.

Detailed session log: `incoming/notes/2026-05-12-atlas-absorption-phase3-and-interp-drift.md`.

---

## 0b. 2026-05-12 absorption closure (commit `0db952a2` + `150e0220`)

§4 의 #5 단계가 본래 의도였음 — "atlas.n6 지도파일이 별도 필요없게 hexa-lang atlas 시스템에 흡수" (operator clarification). §0a 발견과 합치면:

- **RFC-017 §4.5 + SPEC.md §2.2 의 흡수 scaffold 는 이미 land 됨** (`compiler/atlas/embed.hexa` + `static_index.hexa` + `embedded.gen.hexa` + `tool/atlas_embed_gen.hexa`). 누락은 데이터뿐 — `embedded.gen.hexa` 가 8-노드 FIXTURE (`ATLAS_GENERATED_AT = "fixture"`) 상태였음.
- 이 commit (`0db952a2`) 에서 `tool/atlas_embed_gen.hexa` 를 실제 `~/core/nexus/n6` 에 대해 실행 → `embedded.gen.hexa` 가 **P=255 / C=5424 / L=392 / E=10 (총 6081 노드, sha256 `2efce3bba0c39ea2095caf67b289b1386b9a079cc865f6af0764296d16b575ad`)** 로 재생성. 2,489,881 bytes (2431 KB).
- 다운스트림 hot-path consumer (`compiler/main`, `compiler/check/types`, `compiler/daemon/server`) 는 이미 `static_atlas()` 경유. 잔여 `load_atlas()` 직접 콜러는 `compiler/discover/{promote,promote_smoke,tombstone_smoke}.hexa` (스테이징 shard promotion 경로, runtime SSOT 와 분리됨) + `tool/atlas_embed_gen.hexa` (regen driver 자체).
- Smoke: `compiler/atlas/static_index_test.hexa` — 9/9 PASS (fixture-only ID `alpha`/`addition-commutative` → 실제 stable 앵커 `n` (foundation [11*] axiom) + `consciousness_structure` 로 재핀).

### regen 친화도 friction (2026-05-12, 후속 fix `150e0220`)

Linux GNU 호스트에서 `hexa run tool/atlas_embed_gen.hexa` 실행 시 3 false start. Root cause: `self/hexa_full.hexa::file_size` 빌트인이 BSD `stat -f %z` 먼저 시도 → GNU `stat -f` 는 filesystem-info 모드라 `%z` 가 undefined → locale-formatted 메타데이터를 **STDOUT** 에 emit ("`  파일: ...\n    ID: ...`") → `2>/dev/null` 로 못 막음 → `to_int` 가 진짜 garbage 처리. `150e0220` 에서 GNU-first 순서로 뒤집고 `LC_ALL=C` 가드 추가. 단 deployed `~/.hx/packages/hexa/build/hexa_interp` 바이너리는 다음 re-promote 사이클까지 구 로직 유지 → 그 동안 Linux 사용자는 여전히 `env LC_ALL=C PATH=<stat shim>:$PATH` 워크어라운드 필요. 세부는 `incoming/notes/2026-05-12-atlas-n6-absorption-session.md` §B.

### 폐기 가능성 — 즉시 가능한 것 vs 후속

**즉시 가능** (이 commit 이후):
- `~/core/nexus/n6/atlas.n6` 외부 파일은 hexa 컴파일러 runtime 에서 **read 되지 않음**. 컴파일러 바이너리가 atlas 데이터를 자체적으로 휴대 (embedded const arrays).
- 클린 체크아웃 → 클린 빌드 시퀀스에서 외부 atlas 파일 0 의존.

**후속 사이클 필요** (이번 범위 밖):
- **§4 #1 bit-rotted caller 정리** — `tool/foundation_axiom_lock.hexa:31`, `tool/drill_classify.hexa:36` 의 `/Users/ghost/core/canon/atlas/atlas.n6` 하드코딩. 사용자가 1차 시도를 revert 했으므로 별도 협의 필요.
- **§2 Phase 2** — append/promote 의 외부 shard 경로 (`compiler/discover/promote.hexa::promote_to_atlas`) 는 staging 흐름이 atlas.n6 와 별개로 운영되는지 재확인 필요.
- **§2 Phase 4** — nexus 측 `~/core/nexus/n6/atlas.n6` 파일은 hexa 외 호출자 (nexus CLI, viewer, archival) 가 read 할 가능성. 1주 read-only tombstone 관찰 후 삭제 단계는 operator 결정.
- **§2 Phase 5** — `README.md`/`SPEC.md`/`SPEC.yaml` 의 "compiler build time merge" 문장은 흡수 후 그대로 정확 (정의 갱신 불요), 다만 RFC-017 cross-ref 갱신은 미정.
- **interp re-promote** — `150e0220` 의 file_size 패치가 deployed binary 에 land 되어 Linux 사용자도 워크어라운드 없이 regen 가능해질 것. 별도 build(stage0) 사이클.

### §4 step 매핑 (재정렬)

§4 의 5-step 원안에서:
- #1 (bit-rotted caller) — **deferred**, operator-revert 후 미진행.
- #2 (compiler/cli/dispatch.hexa 모듈 분리) — **deferred**, 흡수 본체가 아니라 별개 리팩터.
- #3 (`hexa atlas` 최소 surface) — **deferred**, 흡수 본체 외 새 CLI 추가.
- #4 (`hexa scrub` / determinism scan) — **deferred**, raw_determinism Tier 1 의 별도 surface.
- #5 (§2 Phase 0–5 재설계) — **본 commit 으로 in spirit 종결**. Phase 1 의 "디렉터리 트리 전환" 전제가 §0a 에서 깨졌고, 실제로는 단일 파일 SSOT 에 대해 기존 generator 를 실행하는 것이 closure 였음. 명시적 doc 재설계 (Phase 1–5 의 redrafted 본문) 는 별도 PR.

---

## 1. 계획 검토 ① — nexus atlas / atlas CLI → hexa CLI 전환

### 흡수 매핑 (audit 대비, 현 상태)

| nexus surface | hexa CLI 흡수 | 비고 |
|---|---|---|
| `atlas search/lookup/audit/query/diff/snapshot/publish/serve` | likely 흡수 (사용자 진술) | audit P0–P2 전부 |
| `check atlas`, `verify atlas`, `discovery query` | likely 흡수 | `compiler/check/*` + `compiler/discover/*` 기반 |
| `atlas append` | L effort, P2 | write policy 위험 — 단독 확인 필요 |
| `verify v-const`, `verify sync-diff` | partial (lint.hexa / sync.hexa 의존) | hexa 내재 lint 흡수 여부 확인 필요 |

### 검토 포인트 (커밋 전 점검)

1. **dispatch 진입점**: audit §5 의 `compiler/cli/dispatch.hexa` 가 실제 land 됐는지, 아니면 `compiler/main.hexa` 의 argv-scan 위에 inline 라우팅이 붙었는지. 후자라면 subcommand 가 늘수록 `main.hexa` 가 비대해진다 — 별도 dispatch 모듈로 분리 권고.
2. **atlas append write policy**: audit 에서 단독으로 P2 caution. nexus 의 lock/order/dedupe 로직이 그대로 옮겨졌는지, `compiler/discover/staging.hexa` 의 staged-then-promote 흐름으로 대체됐는지 확인.
3. **`atlas3d publish/serve/snapshot`**: 3D coord / HTTP server 는 컴파일러 core 책임이 아님. 흡수했다면 `tool/` 분리 또는 외부 viewer 로 재분리 권고. 컴파일러 바이너리에 HTTP listener 들어가지 않도록 경계 점검.
4. **shadow 기간**: `nexus/bin/` 의 atlas/atlas3d 래퍼를 즉시 삭제하지 말고 `exec hexa atlas "$@"` thin shim 으로 1–2주 유지 → 외부 호출자 (shell, cron, doc 예제) 누락 식별.
5. **scrub 100% 흡수 검증**: `raw_determinism.md` Tier 3 rule #8 (pid/hostname/user) + Tier 1–2 의 locale/clang/SOURCE_DATE_EPOCH/map-iter/fs-sort scanner 가 `hexa scrub` (또는 `hexa verify scrub`) 하나로 다 도달 가능한지. `tool/verify_fixpoint.hexa`, `tool/fixpoint_check.hexa`, `tool/fixpoint_compare.hexa` 가 그 안에 통합됐는지 확인.

---

## 2. 계획 ② — `atlas.n6` 파일 완전폐기 (5 단계)

전제: hexa CLI 가 atlas SSOT 를 `~/core/canon/atlas/` 디렉터리 트리에서 직접 읽어 embed 생성 가능. `atlas.n6` 단일 파일은 nexus 잔재.

### Phase 0 — 인벤토리 (1일)

- `atlas.n6` / `atlas.append.*.n6` 를 **파일로 read 하는 코드** 전수 grep:
  - `compiler/atlas/parser.hexa`
  - `tool/atlas_embed_gen.hexa`
  - `tool/atlas_append_check.hexa`
  - nexus 측 모든 `*.hexa` / `bin/*`
- **내용으로만 언급** 하는 doc/paper (`firmware/boards/**`) 와 구분 — 후자는 폐기 영향 없음 (lore 용어로 유지 OK).
- 출력: `state/atlas_n6_callers.tsv`.

### Phase 1 — Generator 입력 전환 (S, P0)

- `tool/atlas_embed_gen.hexa <root>` 가 `<root>/atlas.n6` 대신 `~/core/canon/atlas/` 디렉터리 트리를 읽도록 전환.
- `compiler/atlas/parser.hexa` 도 동일.
- `embedded.gen.hexa` 결과물의 `ATLAS_HASH` 가 전환 전/후 **byte-identical** 한지 검증 (canonical sort/dedupe 유지). 다르면 폐기 금지.
- gate: `hexa build` fixpoint v3==v4 streak 유지.

### Phase 2 — append/promote 경로 전환 (M, P0)

- `compiler/discover/{staging,promote,tombstone}.hexa` 가 `atlas.append.{date}.n6` 파일 대신 `canon/atlas/` 의 dated shard 로 write (이미 그러하면 skip).
- `hexa atlas append` (audit 의 P2 caution) 도 같은 sink 사용.

### Phase 3 — symlink 회수 (S, P1)

- `data/n6/` symlink 의 inbound caller 가 0 임을 grep 으로 확인 후 제거.
- `hexa.toml [atlas] path = "..."` override 의 의미를 디렉터리 경로로 재정의 (`SPEC.md` §2.2 "Override" 갱신).

### Phase 4 — nexus 측 file 폐기 (S, P1)

- nexus 의 `atlas.n6` 원본 파일을 read-only tombstone (헤더에 "moved to `~/core/canon/atlas/`, generated artifact only, do not edit") 으로 1주 유지 → 무 read 확인 → 삭제.
- nexus CLI 의 atlas 진입점은 shim (`exec hexa atlas "$@"`) 만 남기거나 같이 제거.

### Phase 5 — 문서 정리 (S, P2)

- `README.md`, `SPEC.md`, `SPEC.yaml`, `ROADMAP.md` 의 "atlas.n6 + atlas.append.*.n6 are merged at compiler build time" 문장을 디렉터리 기반 설명으로 갱신.
- RFC-017 (atlas n6 embedding) 에 "후속: RFC-XXX atlas directory SSOT" cross-ref 추가, RFC-017 자체는 historical 로 freeze.
- 보드 페이퍼 (`firmware/boards/**`) 의 "atlas.n6 [N?] 7 entries" 같은 **개념적 표기는 그대로 유지** — 파일이 아니라 dictionary 라는 의미이므로 폐기 무관.

---

## 3. 주의 / 결정 필요

- **ATLAS_HASH 안정성**: Phase 1 의 byte-identical 검증이 가장 큰 게이트. 디렉터리 walk 순서, file enumeration sort 가 `LC_ALL=C` 로 고정되어 있는지 (raw_determinism Tier 1 #1 과 직결).
- **atlas append write policy**: nexus 의 lock 로직 이전 형태 미확인. concurrent `hexa atlas append` 안전성 별도 검증.
- **atlas3d 분리 여부**: 컴파일러 본체에 HTTP server 포함은 RFC-018 zero-external-dep 정신에 어긋날 소지. `hexa-atlas3d` 별도 바이너리 / `tool/` 으로 둘지 결정 필요.

---

## 4. 다음 액션 (2026-05-12 audit-redo 기준 재작성)

### 완료 (이번 audit 사이클)
- [x] Phase 0 인벤토리 → `state/atlas_n6_callers.tsv` 산출 (hexa-lang 13 + nexus 50)
- [x] dispatch 진입점 실태 확인 → `self/main.hexa:2164-2481` flat chain, `compiler/cli/dispatch.hexa` 부재
- [x] scrub 흡수 범위 검증 → 0% (determinism_scan.hexa + hexa scrub 모두 부재)
- [x] atlas SSOT 위치 재확인 → `~/core/nexus/n6/` 단일 파일 SSOT, canon 폐기

### 다음 (선후관계 정렬)

순서가 중요. 흡수가 0% 인 상태에서 파일 폐기 (§2) 부터 들어가면 의존자가 깨짐.

1. **bit-rotted caller 정리 (S, P0, 즉시)**
   - `tool/foundation_axiom_lock.hexa:31` 의 `/Users/ghost/core/canon/atlas/atlas.n6` 하드코딩 → `$HOME/core/nexus/n6/atlas.n6` 로 교체 또는 tool 전체 폐기 검토.
   - `tool/drill_classify.hexa:36` 의 `ROOT/../canon/atlas/atlas.n6` → 동일 처리.
   - 둘 다 현 호스트에서 이미 작동 불가이므로 사용자/CI 영향 없이 정리 가능.

2. **`compiler/cli/dispatch.hexa` 모듈 분리 (M, P0)**
   - audit §5 가 권고한 모양 — `self/main.hexa` 의 2164-2481 if/else chain 을 별도 모듈로 추출.
   - 새 subcommand (atlas/check/verify/discover/scrub) land 전에 분리해 두지 않으면 `main.hexa` 가 비대화.
   - 분리 후에는 stage1 → stage2 fixpoint v3==v4 streak 유지가 ATLAS_HASH 안정성보다 우선 게이트.

3. **`hexa atlas` 최소 surface land (S, P0)**
   - `hexa atlas lookup <query>` — `static_atlas()` 인덱스 grep, fs 무접근, 외부 의존 0. audit doc §"first ship" 과 동일.
   - 흡수 매핑 표 1행 채우는 첫 dot — 이후 audit/snapshot/diff 가 같은 패턴.
   - nexus-cli proxy 라인 (`self/main.hexa:2458`) 에서 `atlas` 만 분기해 새 cmd 로 이관.

4. **`tool/determinism_scan.hexa` MVP + `hexa scrub` subcommand (M, P1)**
   - Tier 1 의 4개 rule 만 — `LC_ALL`, clang version, `-O2`, `SOURCE_DATE_EPOCH` — grep 기반 단일 scanner.
   - `hexa scrub` 진입점은 dispatch 분리 (#2) 후 추가.
   - Tier 2–4 는 별도 사이클.

5. **§2 Phase 0–5 재설계 (L, P2 — #1–#4 land 후)**
   - 디렉터리 트리 전환 단계는 삭제 또는 "사전 reshape" 로 별도 RFC.
   - Phase 1 의 핵심은 generator 입력 path 가 아니라 **nexus 측 read caller 제거**.
   - Phase 3 symlink 회수는 부재 — 삭제.
   - Phase 4 "nexus 파일 폐기" 는 #3 (`hexa atlas`) 가 nexus-cli 의존을 끊은 뒤에만 가능.

### 게이트
- 각 step 후 `hexa build` v3==v4 fixpoint streak 1회 이상 유지.
- bit-rotted caller 정리는 fixpoint 영향 없음 (dead callsite).
