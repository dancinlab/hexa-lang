# hexa-lang `list` append/concat O(n²) — corpus build 30 MiB OOM (M3 saga, 2026-05-24)

**Status**: archived-already-resolved-2026-05-24 — `.push(x)` builtin 이 이미 amortised O(1) (`self/runtime.c:729` "geometric hexa_array_push growth"). Option A (vec primitive) 는 native list `.push()` 로 이미 ship 완료. 권장 migration = `out = out + [x]` → `out.push(x)`. Option C (streaming jsonl_writer) + Option D (M981b list-측 lint) 는 별도 RFC follow-up scope (이 patch 미포함).

## Triage 2026-05-24 (3-signal precheck)

1. `git log --grep="list.concat|list.quadratic|corpus.oom|array_concat"` → `hexa_array_concat` 은 runtime.c:4060 에 존재 (concat=두 array 끝붙임). copy-on-append O(n²) 는 `acc = acc + [x]` 표현형에서만 발생 — `.push()` 빌트인 경로는 무관.
2. `gh pr list --search "list concat O(N2)"` → sibling string-concat PR #684 만 hit. list 측 직접 fix PR 없음.
3. `grep "hexa_array_push" self/runtime.c` → runtime.c:729 "geometric hexa_array_push growth" 명시 — list `.push(x)` 는 이미 amortised O(1). Header-tracked realloc (cycle 잔여 #3 fix) 로 SIGSEGV 도 해결됨.

**결론**: `.push(x)` 빌트인 = 패치가 제안한 `vec_push` 와 동등. Migration path = source-level `+ [x]` → `.push(x)` 1줄 변경. strbuf 같은 신규 stdlib surface 불필요.

**Follow-up RFC scope** (이 patch 미포함):
- Option C — `jsonl_writer` streaming primitive (corpus-build domain 전용)
- Option D — `ai_native_pass.hexa` M981b 의 list-측 mirror lint (`x = x + [y]` in loop → `.push()` 권고)
- Option B — runtime in-place grow on refcount==1 (strbuf saga 와 동일하게 deferred)

원본 patch body (historical record, full design exploration) 는 아래 보존.

---

**Reporter**: anima (`dancinlab/anima` downstream consumer)
**Severity**: medium-high (list-heavy work load 가 corpus-build scale 에서 macOS OOM 트리거 — string strbuf 와 parallel structural trap)
**Affected**: `self/stdlib/core/lists.hexa` (추정) · 모든 list-heavy stream/aggregate work · corpus build / log aggregation / large script generation
**Sibling**: `string-concat-in-unbounded-loop-quadratic-rss.md` (VERIFIED-CLOSED 2026-05-20 — 이번은 list 측 같은 root-cause-class)

## Context — M3 corpus build saga 중 발견

anima HEXAD/PURE M3 (Phase D corpus build v2) 사이클 중 발견된 systemic trap. 30 MiB hexa corpus 빌드 시 list append/concat 누적이 macOS OOM 을 트리거. 14 MiB checkpoint 에서 OS-killed, 20 MiB attempt 도 동일 fate.

agent post-mortem (worktree recycle 직전 lost-work report) 인용:

> "Full 30MB build OOM'd on hexa list-concat O(n²); 20MB attempt killed by macOS OOM at 14 MB output. Builder at ~760 LoC `HEXAD/PURE/corpus/build_phase_d_corpus_v2.hexa` with multi-window + line-target balance + en fallback. Not salvageable — worktree gone."

worktree 가 사라져서 정확 hexa source 는 회수 불가. 그러나 string-concat sibling (closed) 과 거의 동일한 pattern 으로 추정되며, 별도 surface area 이므로 별개 inbox 로 file 한다.

## Finding — list append/copy-on-write O(n²)

추정되는 root cause:

- hexa-lang 의 `list_concat` / `list += [...]` / `list_push` 류가 immutable-style **copy-on-append** 로 구현되어 있을 가능성.
- iteration k 에서 `acc = acc + [x]` (또는 동등 표현) 하면, 매 iteration 마다 `k`-크기 list 를 fresh 할당 + copy.
- N 개 element 누적 시 total allocation = 1 + 2 + ... + N = **O(N²)** elements.
- string `strbuf` sibling 과 정확히 동일한 구조적 trap — 단지 element type 이 string → any list element 라는 차이.
- corpus build 의 경우 element = JSONL line (map / dict), 평균 ~300-500 byte payload 이므로 N=30 000 line 만 되어도 transient allocation ~140 GB scale. 4 GB arena cap (`self/runtime.c:285`) 가 가장 먼저 trip 하거나, arena uncapped 시 host OS (macOS) 가 OOM-kill.

## Repro path (best-effort)

⚠ 정확 source 는 worktree-gone. 추정 reproducer (작성 검증 미실시):

```hexa
// hypothesis-A — list of map (corpus build pattern)
fn build_corpus_v2(n_lines: int) -> list {
    let mut out: list = []
    let mut i = 0
    while i < n_lines {
        let line = #{
            "text": "어떤 corpus line content " + to_string(i),
            "src":  "phase_d_window_" + to_string(i % 8)
        }
        out = out + [line]   // ← O(n²) 의심 — list_concat copy-on-append
        // 또는 동등: out.push(line) — 실제 stdlib 구현에 따라 같은 trap
        i = i + 1
    }
    return out
}

fn main() {
    let corpus = build_corpus_v2(30000)  // ~30k lines × ~400 byte = 12 MiB final
    // 예상: OOM 또는 4 GB arena cap 도달 before 완료
}
```

reproducer 가 실제로 quadratic 인지 (vs. linear / vs. 다른 path) 확인하려면:

1. `time hexa run repro.hexa` with n_lines ∈ {1 000, 4 000, 16 000, 64 000}.
2. wall × 4 가 element-count × 4 마다 ~16× 증가하면 O(n²) 확정.
3. peak RSS 도 동일 trend 확인 — arena 누적 + 미해제 transient.

## Suggested fix

### Option A — `vec` / `arrlist` amortised-grow primitive (strbuf 와 parallel, 최저 surgical)

`self/stdlib/core/lists.hexa` (또는 신규 `self/stdlib/core/vec.hexa`):

```hexa
type Vec  // opaque; runtime 가 capacity doubling 으로 grow
fn vec_new() -> Vec
fn vec_with_capacity(n: int) -> Vec          // pre-size hint
fn vec_push(v: Vec, x: any) -> void          // amortised O(1)
fn vec_finish(v: Vec) -> list                // O(total); empties the vec
fn vec_len(v: Vec) -> int
```

저자 마이그레이션: `acc = acc + [x]` → `vec_push(acc, x)` + `let out = vec_finish(acc)`. strbuf 와 동일한 mechanical port.

### Option B — runtime in-place grow on `refcount==1` (list 측 mirror of string Option B)

`hexa_list_concat` 가 LHS 의 refcount==1 (또는 "builder" tag bit) 일 때 in-place grow. ALL existing call sites 자동 개선, source diff 0. allocator 변경 비-trivial (refcount discipline) → strbuf saga 의 Option B 와 동일하게 staged 후순위.

### Option C — streaming write API for corpus builds (concat 회피, semantic 변경)

corpus build 는 사실상 **streaming sink** 임. 전체 list 를 memory 에 들고 있을 필요 없음:

```hexa
type JsonlWriter
fn jsonl_writer_open(path: string) -> JsonlWriter
fn jsonl_writer_write(h: JsonlWriter, record: map) -> void   // O(|record|)
fn jsonl_writer_close(h: JsonlWriter) -> void
fn jsonl_writer_count(h: JsonlWriter) -> int
```

corpus builder 가 in-memory list 누적 대신 chunk-by-chunk fsync. memory 가 input window 크기 ~수 MB 로 cap. M3 같은 30+ MiB build 도 RSS flat.

### Option D — compile-time lint (M981b mirror for lists)

`self/ai_native_pass.hexa` 의 M981b string-concat lint 를 list 측으로 확장: `mut x: list ... x = x + [...]` 또는 `x = x + y` (where x, y are lists) inside while/for → `vec_push` + `vec_finish` 권고 emit. strbuf saga 와 동일 educational path.

### 권장

**A + C + D** — `vec` primitive (universal), `jsonl_writer` (corpus build domain 정합), lint (ecosystem migration nudge). B 는 allocator 변경 비용이 커서 후순위.

## Affected use cases

| Use case | Trap pattern | Mitigation priority |
|---|---|---|
| **corpus build (M3 직격)** | per-line `list_push` 누적 → 최종 jsonl serialise | **high** — Option C streaming write 가 가장 정합 |
| log aggregation | per-line append to `lines: list` | medium — vec_push 충분 |
| large hexa script generation | per-statement append to `stmts: list` | low-medium — vec_push |
| AST manipulation (compiler/lint) | child-list rebuild via `+ [new_child]` | medium — vec_push, refcount==1 일 때 B 자동 적용 시 best |
| corpus chunk concat (window assemble) | `windows = windows + window_chunk` (list of list) | high — vec_push of vec_finish |

## Cross-references

- **Sibling closed**: `string-concat-in-unbounded-loop-quadratic-rss.md` — string 측 동일 root-cause-class, Option A (strbuf) + Option C (M981b lint) shipped 2026-05-20. list 측은 별도 surface area, 이 patch 가 mirror filing.
- **anima M3 saga**: HEXAD/PURE M3 corpus build v2 — agent worktree recycled, builder source 회수 불가. PR #390 lineage 가 어떤 build path 가 작동했는지 carry.
- **BUG_POSTMORTEM**: anima 측 `HEXAD/PURE/BUG_POSTMORTEM.md` F (#378 saga lessons), 이번 OOM 은 신규 케이스 (E OOM addendum 과는 별개 — E 는 GPU mem leak, 이건 host CPU mem).
- **runtime cap**: `self/runtime.c:285` 4 GB default (history 768 → 2048 → 4096 MB) — list 측 trap 까지 합치면 cap 인상 압박이 또 올 수 있음. vec + jsonl_writer + lint 가 ecosystem 마이그레이션을 마치면 string-concat 측과 함께 cap **하향** 가능.
- **prior anima patches (this session)**:
  - `runpod-graphql-builtin-for-pure-dispatcher.md`
  - `hexa-cloud-pod-status-diagnose-verbs.md`
  - `hexa-cloud-dispatcher-bootstrap-wait-endpoint-2026-05-24.md` (#629)
  - `hexa-cloud-guard-ux-and-pod-lock-2026-05-24.md` (#646)
  - `hexa-cloud-copy-from-verify-local-2026-05-24.md` (#699)
  - **this patch** = 5th hexa-lang inbox of session (pattern stable).

## C3 — honest uncertainty

1. **정확 hexa source 미확인** — agent worktree recycled, builder `HEXAD/PURE/corpus/build_phase_d_corpus_v2.hexa` (~760 LoC) 직접 회수 불가. reproducer 는 corpus build pattern 일반 형태로부터의 inference.
2. **O(n²) 가정** — linear timing experiment 미실시. 14/20/30 MiB OOM threshold 는 quadratic curve 와 consistent 하지만, alternative root cause (예: 단순 large allocation > 4 GB cap on a single list) 도 배제 안됨.
3. **macOS-only 검증** — agent host 가 mac. linux 측 동일 trap 인지 (arena cap 같은지) 별도 검증 필요. runpod/H100 dispatch 측 corpus build 은 미시도 (M3 가 macOS local-build 우선이었음).
4. **threshold 추정** — "30 MiB OOM, 14 MiB checkpoint OOM" 는 agent post-mortem 의 자연어 인용 — 정확 byte count + RSS snapshot 미보유.
5. **Option A/B/C/D 권장은 strbuf saga의 parallel inference** — list 측 동일 trap 가정 시 동일 fix family 적용 가능하다는 추론. 실제 hexa-lang 의 list 구현이 string 과 다른 (e.g. 이미 amortised) 가능성 시 일부 option 불필요.
6. **`out.push(line)` 도 동일 trap 인지 미검증** — stdlib `list_push` 구현이 in-place vs. copy-on-append 인지 source 확인 필요. copy-on-append 이면 Option A `vec_push` 필수, in-place mutation 이면 Option C streaming 만으로 충분.
7. **list element type 영향** — list of `int` vs. list of `map` (corpus case) 의 per-element copy cost 가 다름 — map 의 경우 reference copy 인지 deep-copy 인지 미확인.

## Authority

anima governance `@D a_runpod_inbox` (runpod / hexa-lang trouble → hexa-lang inbox/patches) · commons `g11` (downstream → upstream handoff via inbox). anima 측 workaround (streaming write 직접 구현, list 회피) 가 단기 mitigation 이지만 ecosystem-level fix 가 SSOT-correct path.
