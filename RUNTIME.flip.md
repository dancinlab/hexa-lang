# 🛸 RUNTIME.flip — atomic milestone backlog (cycle-bg ready)

> Atomic decomposition of `RUNTIME.md` frontier next-list (PR #1682 18-list +
> PR #1753 12-list). Each item:
> - **single-PR** (<200 LOC per g4 · 1 logical concern)
> - **file-conflict-FREE within batch** (each item targets a NEW file or a
>   DIFFERENT existing file from siblings)
> - **cycle-bg friendly** — `/cycle-bg <batch>` fans out one Agent per item
> - **parse-clean acceptance** (`hexa parse <file>` exit 0 = minimum bar)

## Batch index (8 batches · 47 items · ~9400 LOC budget)

| batch | concern | items | est. LOC each | target dir |
|---|---|---|---|---|
| B1 | TLS 1.3 client expansion (post-#4/5/6) | 7 | ~150 | stdlib/crypto/ |
| B2 | CA bundle policy options (post-#9 stub · 100% hexa-self) | 4 | ~120 | stdlib/crypto/ |
| B3 | POSIX syscall ABI tables (post-#3) | 5 | ~100 | stdlib/posix/ |
| B4 | Option/Result combinators (post-#7) | 6 | ~80 | stdlib/core/ |
| B5 | trait fixture expansion (post-#8) | 6 | ~90 | stdlib/core/ |
| B6 | DFT preflight v2 sibling (post-#18) | 4 | ~140 | stdlib/cloud/ |
| B7 | WebAssembly target scaffold (new C1) | 6 | ~150 | stdlib/wasm/ + compiler/codegen/ |
| B8 | LSP completion + cross-domain handoff (B+C residual) | 8 | ~100 | stdlib/lsp/ + INBOX entries |

Total **46 atomic items** (~9280 LOC) — depletion-grade brainstorm. **All 46 are 100% hexa-self** (no FFI, no C-runtime dep). 1 layer-③ FFI option moved to `## deferred` below.

## How to use

```bash
# fan out one batch (parallel · background)
/cycle-bg B1   # Agent per item in batch B1 (7 parallel)

# or pull one item inline
/cycle-fg B1.tls13-1a-alert-handler
```

Each item id format: `B<n>.<slug>` — `B1.tls13-1a-alert-handler` etc.

---

## B1 — TLS 1.3 client expansion (7 items)

post-#1724/1725/1726/1728 — TLS 1.3 client wire-complete; this batch adds
state-handlers + extension wires the round-trip driver doesn't cover yet.

- [ ] **B1.tls13-alert-handler** — `stdlib/crypto/tls13_client_alert_handler.hexa`:
      receive ALERT record (content_type=21), parse level+description, return
      `Tls13AlertOutcome` discriminator. RFC 8446 §6.
- [ ] **B1.tls13-close-notify** — `stdlib/crypto/tls13_client_close_notify.hexa`:
      build + send close_notify ALERT, half-close handling. RFC 8446 §6.1.
- [ ] **B1.tls13-keyupdate** — `stdlib/crypto/tls13_client_keyupdate.hexa`:
      KeyUpdate msg builder + traffic-key rotation (next-secret derivation).
      RFC 8446 §4.6.3.
- [ ] **B1.tls13-session-resume** — `stdlib/crypto/tls13_client_session_resume.hexa`:
      NewSessionTicket parse + cache + PSK extension build for resumption.
      RFC 8446 §4.6.1 + §4.2.11.
- [ ] **B1.tls13-record-size-negotiation** —
      `stdlib/crypto/tls13_client_record_size_negotiation.hexa`: parse server's
      record_size_limit extension, enforce on send/recv. RFC 8449.
- [ ] **B1.tls13-zero-rtt-data** — `stdlib/crypto/tls13_client_zero_rtt_data.hexa`:
      early-data send (PSK-only path) + state-machine guard. RFC 8446 §4.2.10.
- [ ] **B1.tls13-post-handshake-auth** —
      `stdlib/crypto/tls13_client_post_handshake_auth.hexa`: CertificateRequest
      handling + cert+CertVerify response. RFC 8446 §4.6.2.

## B2 — CA bundle policy options (4 items · 100% hexa-self)

post-#9 — `tls_ca_bundle.hexa` API stub landed (kind="none"). 3 policy options
(A pinned · C caller-supplied · D hybrid) + 1 test scaffold — all hexa-self.
Option B (system trust store FFI) moved to `## deferred` (layer ③ vendor FFI ·
D2+ if Option B is chosen).

- [ ] **B2.ca-pinned-nss** — `stdlib/crypto/tls_ca_bundle_pinned_nss.hexa`:
      Mozilla NSS PEM subset (compact, e.g. 30-40 ISRG/DigiCert/Let's Encrypt
      roots). pinned implementation; the bundle bytes go in a sibling .pem-like
      data file. **Option A — 100% hexa-self**.
- [ ] **B2.ca-caller-supplied** — `stdlib/crypto/tls_ca_bundle_caller_supplied.hexa`:
      reads bundle from a caller-passed path. PEM parser + slot-loader.
      **Option C — 100% hexa-self**.
- [ ] **B2.ca-hybrid** — `stdlib/crypto/tls_ca_bundle_hybrid.hexa`: composes
      pinned-as-default + caller-supplied-as-override. delegates to A + C.
      **Option D — 100% hexa-self**.
- [ ] **B2.ca-test-vectors** — `stdlib/crypto/tls_ca_bundle_test_vectors.hexa`:
      Known-good test PEM strings (1 self-signed ISRG-Root-X1 sample · 1
      tampered) for offline verify_chain testing. **100% hexa-self**.

## B3 — POSIX syscall ABI tables (5 items)

post-#3/#1738/#1743 — syscall number tables landed. These add the calling
conventions + errno encoding so a future codegen-emit pass can use them.

- [ ] **B3.posix-cc-arm64** — `stdlib/posix/posix_calling_convention_arm64.hexa`:
      `posix_cc_arm64_arg_register(idx)` + `posix_cc_arm64_result_register()` +
      `posix_cc_arm64_syscall_number_register()` constants.
- [ ] **B3.posix-cc-x86-64** — `stdlib/posix/posix_calling_convention_x86_64.hexa`:
      SysV ABI: rdi/rsi/rdx/r10/r8/r9 + rax + rax-result. Linux x86_64 uses
      r10 not rcx for arg 4 (kernel-specific).
- [ ] **B3.posix-errno-encoding** — `stdlib/posix/posix_errno.hexa`: errno
      number table (EAGAIN/ENOENT/EINVAL/EBADF/ENOMEM/EACCES/EPERM/EIO/ENXIO/
      EFAULT/EEXIST/EISDIR/ENOTDIR/EMFILE) for both Linux + Darwin (different
      values).
- [ ] **B3.posix-signal-numbers** — `stdlib/posix/posix_signal_numbers.hexa`:
      SIGHUP/INT/QUIT/ILL/TRAP/ABRT/BUS/FPE/KILL/USR1/SEGV/USR2/PIPE/ALRM/TERM
      Linux + Darwin tables.
- [ ] **B3.posix-resource-limits** — `stdlib/posix/posix_rlimit.hexa`: RLIMIT_*
      constants (CORE/CPU/DATA/FSIZE/NOFILE/STACK/AS) + getrlimit/setrlimit
      syscall wrappers.

## B4 — Option/Result combinators (6 items)

post-#7 — `option_result.hexa` enum + 8 helper landed. These add functional
combinators (map · and_then · or_else) + collection chaining.

- [ ] **B4.option-map** — `stdlib/core/option_result_map.hexa`: `opt_map(o, f)`
      / `res_map(r, f)` / `res_map_err(r, f)` combinators.
- [ ] **B4.option-and-then** — `stdlib/core/option_result_chain.hexa`:
      `opt_and_then` / `res_and_then` (monadic bind).
- [ ] **B4.option-or-else** — `stdlib/core/option_result_or_else.hexa`:
      `opt_or_else` / `res_or_else` (fallback chains).
- [ ] **B4.option-collect** — `stdlib/core/option_result_collect.hexa`:
      `collect_results([Result, ...])` → `Result<[T], E>` (first-Err short-circuit).
- [ ] **B4.option-to-bool** — `stdlib/core/option_result_predicates.hexa`:
      `opt_eq(o, value)` / `opt_contains` / `res_eq_ok`.
- [ ] **B4.option-iter-adapter** — `stdlib/core/option_result_iter.hexa`:
      `opt_iter(o)` → 0-or-1 length array; `res_iter(r)` → 0-or-1 length array.

## B5 — trait fixture expansion (6 items)

post-#8 — `trait_design_fixture.hexa` 4 traits × 3 types landed. These add
sibling traits + impls for additional types.

- [ ] **B5.trait-mul-div** — `stdlib/core/trait_mul_div_fixture.hexa`:
      `mul_int/float`, `div_int/float`, `rem_int` monomorphic.
- [ ] **B5.trait-clone** — `stdlib/core/trait_clone_fixture.hexa`: `clone_int/
      float/str/array_int/array_float` deep-copy fixture.
- [ ] **B5.trait-default** — `stdlib/core/trait_default_fixture.hexa`:
      `default_int() = 0`, `default_float() = 0.0`, `default_str() = ""`,
      `default_array_int() = []`.
- [ ] **B5.trait-iter** — `stdlib/core/trait_iter_fixture.hexa`: `iter_next`
      pattern for array iteration without index variable.
- [ ] **B5.trait-hash** — `stdlib/core/trait_hash_fixture.hexa`: `hash_int(n)`
      / `hash_str(s)` (FNV-1a) / `hash_array_int(a)` for collection backing.
- [ ] **B5.trait-display** — `stdlib/core/trait_display_fixture.hexa`:
      `to_str_int/float/bool/array_int` — separate from `to_string` runtime fn.

## B6 — DFT preflight v2 sibling (4 items)

post-#18 — `preflight_dft.hexa` closed-form landed. These add CLI wire +
workload kind enum + symptom watcher (per RFC 091 §2.1/2.4/2.5).

- [ ] **B6.preflight-workload-kind** — `stdlib/cloud/preflight_workload_kind.hexa`:
      `WorkloadKind` enum (LLM / DFT / MD / WEB_SMOKE / BUILD_BENCH) +
      dispatcher.
- [ ] **B6.preflight-sentinel-marker** —
      `stdlib/cloud/preflight_dual_marker_sentinel.hexa`: pre-job sentinel +
      post-job watcher RFC §2.4 pattern.
- [ ] **B6.preflight-log-pattern-watcher** —
      `stdlib/cloud/preflight_log_pattern_watcher.hexa`: OOM / NaN / deadlock
      pattern matchers (cah6-class diagnostics).
- [ ] **B6.preflight-symptom-diff** — `stdlib/cloud/preflight_symptom_diff.hexa`:
      cross-backend symptom comparison (RFC 091 §2.5).

## B7 — WebAssembly target scaffold (6 items · new C1 frontier)

new domain — current targets are NVPTX + arm64-Darwin + x86_64-Linux. wasm32
opens browser/edge. Each item independent.

- [ ] **B7.wasm-leb128** — `stdlib/wasm/wasm_leb128.hexa`: ULEB128 / SLEB128
      encode/decode (RFC: LEB128 unsigned + signed for wasm sections).
- [ ] **B7.wasm-section-header** — `stdlib/wasm/wasm_section_header.hexa`:
      magic 0x6d736100 + version + section ids (Type=1 / Import=2 / Function=3 …).
- [ ] **B7.wasm-opcode-table** — `stdlib/wasm/wasm_opcode_table.hexa`:
      core opcode constants (i32.add=0x6a · local.get=0x20 · i32.const=0x41 …).
- [ ] **B7.wasm-type-section** — `stdlib/wasm/wasm_type_section.hexa`: function
      type emitter (0x60 + param vec + result vec).
- [ ] **B7.wasm-export** — `stdlib/wasm/wasm_export.hexa`: export entry
      (name + kind=0/1/2/3 + index).
- [ ] **B7.wasm-vec-add-fixture** — `stdlib/wasm/wasm_vec_add_fixture.hexa`:
      First end-to-end smoke — emit a wasm module that exports `add(i32, i32) → i32`.
      Validates the prior 5 pieces together.

## B8 — LSP + cross-domain handoff (8 items)

C-frontier residual + B (cross-domain) translates to INBOX handoff entries.

- [ ] **B8.lsp-completion-pub-fn-index** —
      `stdlib/lsp/completion_pub_fn_index.hexa`: walk stdlib `**/*.hexa`, index
      `pub fn` sigs + first-line docstring.
- [ ] **B8.lsp-completion-signature-render** —
      `stdlib/lsp/completion_signature_render.hexa`: render `fn name(param: T, …)
      → R` for textDocument/completion response.
- [ ] **B8.lsp-completion-doc-extract** —
      `stdlib/lsp/completion_doc_extract.hexa`: first `///` comment after `pub
      fn` line = the LSP doc.
- [ ] **B8.distributed-cache-fingerprint** —
      `stdlib/build/cache_fingerprint.hexa`: SHA-256 of (source + flags +
      compiler version) → cache key.
- [ ] **B8.distributed-cache-lookup-remote** —
      `stdlib/build/cache_lookup_remote.hexa`: thin client for HTTP GET
      remote cache slot (no actual server impl).
- [ ] **B8.hx-semver** — `stdlib/hx/semver.hexa`: semver parse + compare
      (`1.2.3` < `1.2.4` < `1.3.0` < `2.0.0`).
- [ ] **B8.hx-lockfile** — `stdlib/hx/lockfile.hexa`: lockfile read/write
      (TOML-like simple format: `name = "X" version = "Y" hash = "Z"`).
- [ ] **B8.hx-bundle-sign** — `stdlib/hx/bundle_sign.hexa`: Ed25519-sign a
      tarball checksum (reuses stdlib/crypto/ed25519); manifest format.

---

## Batch B9 — `.c`-zero north-star campaign (atomic · multi-wave)

post-B1-B8 stdlib expansion 100% closure 이후, RUNTIME.md 의 north-star
("`.hexa`-ONLY · zero `.c`/`.o`/`.s`") 달성을 위한 실제 C-floor 제거 작업. 5개
coarse item 을 audit-grounded atomic 으로 분해 (2026-05-28).

실측 현재 상태 (2026-05-28, origin/main):
- `.o` = **0** ✅ (#1808 build-artifact 제거로 달성)
- `.s` = **4** (1 removable + 3 irreducible boot-floor · #1810 audit)
- `.c` = **230** (`self/*.c` 44 + `self/native/*.c` 32 + 기타). north-star
  충족 시 `find . -name '*.c' -o -name '*.s' -o -name '*.o'` 가 비어야 함.

⚠ 정직 명제: `.c`-zero 의 *진짜* enabler 는 **B9.6 codegen self-emit** — hexa
reimpl (B9.2/B9.4/B9.5) 은 source 일 뿐, codegen 이 machine-code 로 self-emit
해야 `.c` 가 dead 가 되어 삭제 가능. 일부(arena/GC/HexaVal repr)는 irreducible
bootstrap FLOOR (B9.8 terminal). 따라서 본 batch 는 *additive reimpl wave* (병렬
안전) + *serial codegen-wire wave* (B9.6, 비병렬) 2-track.

### B9.0 — scoping audits (wave 0 · DONE)

- [x] **B9.0a-native-c-audit** — `self/native/*.c` layer 분류 (#1809). 실측 32
      files = ①11 portable / ②2 floor / ③**19** vendor·kernel FFI. 현실 포팅
      대상 ~7 (`hxtok`·`sha256`·`blowfish`). 19/32 = honest FFI 바닥.
- [x] **B9.0b-asm-floor-audit** — `.s` 4개 분류 (#1810). 1 removable
      (`stage_1_forced.s` dead fixture) + 3 boot-floor (vector-table · RFC
      063/064 lowering gated). `@asm` 존재하나 codegen lowering no-op.
- [ ] **B9.0c-runtime-c-fn-audit** — `runtime{,_core}.c` fn-level layer 분류
      (running). B9.4 atomic 분해의 입력.

### B9.1 — `.s` zero (4 → 0)

- [ ] **B9.1a-stage1-forced-rm** — `tests/bootstrap/stage_1_forced.s` git rm.
      dead fixture (실참조 0 · `as` reject · #1810 verdict). quick win → `.s` 4→3.
- [ ] **B9.1b-boot-rp2040-floor** — `boot_rp2040.s` (Cortex-M0+). irreducible
      vector-table boot-floor. RFC 063/064 `@interrupt`/`@target` lowering 전엔
      불가 → honest-floor 문서화 (closed-neg until RFC).
- [ ] **B9.1c-boot-stm32h7-floor** — `boot_stm32h7.s` (Cortex-M7 + FPU). 동상.
- [ ] **B9.1d-startup-stm32f429-floor** — `startup_stm32f429.s` (Cortex-M4
      CMSIS). 동상.

### B9.2 — runtime.c portable-fn hexa reimpl (layer ① · additive + oracle)

NEW `stdlib/runtime/*.hexa` 파일 = conflict-free fan-out. 각 항목 = reimpl +
byte/value oracle fixture. 실제 삭제는 B9.6 wire 후.

- [ ] **B9.2a-array-ops** — `farr`/`hexa_array` (~98 fn) → `array_ops.hexa`
- [ ] **B9.2b-string-ops** — `hexa_str` (~10 fn) → `string_ops.hexa`
- [ ] **B9.2c-regex-engine** — `hexa_regex` (~6 fn) → `regex_engine.hexa`
- [ ] **B9.2d-json-codec** — `_js`/`_jp` serialize/parse (~14 fn) → `json_codec.hexa`
- [ ] **B9.2e-autodiff-tape** — `hexa_ad` (~12 fn) → `autodiff_tape.hexa`
- [ ] **B9.2f-safetensors-io** — `hexa_safetensors` (~16 fn) → `safetensors_io.hexa`

### B9.3 — runtime.c layer-② svc surface (inline svc · kernel ABI)

- [ ] **B9.3a-process-svc** — `hexa_exec` process spawn (~24 fn) → `process_svc.hexa`
- [ ] **B9.3b-term-svc** — `hexa_term` ioctl (~26 fn) → `term_svc.hexa`
- [ ] **B9.3c-host-svc** — `hexa_host` env/host (~6 fn) → `host_svc.hexa`

### B9.4 — runtime_core.c portable subset (gated on B9.0c audit)

- [ ] **B9.4-expand** — `#B9.0c` audit 착지 후 portable bucket 을 atomic 으로
      분해 (~150 portable of 548; HexaVal repr·arena·GC 는 B9.8 FLOOR 제외).

### B9.5 — native/*.c layer-① port (gated on #1809 · ~7 realistic)

- [ ] **B9.5a-tokenizer-bpe** — `hxtok.c` BPE 토크나이저 (libc-only pure) →
      `stdlib/runtime/tokenizer_bpe.hexa`
- [ ] **B9.5b-sha256-core** — `exec_argv_sha256.c` (FIPS 180-4) →
      `stdlib/crypto/sha256_core.hexa`
- [ ] **B9.5c-blowfish** — `crypto_blowfish.c` (π-seeded bcrypt) →
      `stdlib/crypto/blowfish.hexa`
      (③19 = honest FFI floor · 포팅 대상 아님)

### B9.6 — codegen self-emit (genuine `.c`-delete route · SERIAL · non-parallel)

이게 진짜 `.c` 삭제 enabler — B9.2/B9.4/B9.5 reimpl 을 machine-code 로 self-emit
해야 runtime.c 가 dead. wipe-prone + rebuild + fixpoint 필요 → 격리-worktree 병렬
fan-out 불가, serial 진행.

- [ ] **B9.6a-hexaval-repr-emit** — HexaVal repr 생성자 codegen self-emit
      (`self/codegen/runtime_arm64.hexa` 확장; `rt_arena_*` 4 fn LANDED 패턴)
- [ ] **B9.6b-runtime-primitive-emit** — 잔여 runtime primitive self-emit
      (chunk-A wire-plan)

### B9.7 — self-host linker (phase-H · cross-ref only · 다른 에이전트 활성)

- [ ] **B9.7-phase-h-linker** — `tool/hexa_ld` phase-h-inc4 (dyld bind #1348
      LANDED). 활성 브랜치 `phase-h-inc4-dyld-write` 진행중 → 여기서 land 안 함,
      cross-ref pointer only.

### B9.8 — irreducible bootstrap FLOOR (terminal closed-negative)

- [x] **B9.8-bootstrap-floor** — HexaVal repr core · GC · arena 의 seed 는
      irreducible bootstrap FLOOR (CLOSED-NEG-TERMINAL). self-hosting 컴파일러는
      SOME machine-code seed 필요 — B9.6 self-emit 가 닫지 못하는 잔여는 honest
      floor. memory `project-runtime-md-step3-step4-progress` step-4
      "irreducible-core FLOOR" terminal 과 일치. 미래 codegen 이 100% self-emit
      하면 re-open.

## cross-domain handoff (B-갈래 → 별도 도메인)

The B-갈래 (HEXA-LANG · GPU · TECS-L · PROBE · ARXIV) handoff items DO NOT
land here — they need each domain's owner to register milestones. RUNTIME.md
references them as cross-ref pointers only. INBOX entries (a follow-up PR) =
the canonical handoff surface.

## bg-fanout policy

- **per-batch**: `/cycle-bg B<n>` fans out M Agents for batch B<n>.
- **per-item**: `/cycle-fg B<n>.<slug>` runs one inline.
- **acceptance**: `hexa parse <file>` exit 0; verify via PR + auto-merge gate.
- **conflict-policy**: each item creates a NEW file (no edits to existing
  shared files) — guarantees fan-out safety.
- **commit-immediate**: durable-worktree rule (commit + push per item to
  survive `git worktree prune`).

## depletion criterion

**B1-B8** = 46 atomic items (all SHIPPED · stdlib expansion closure).

**B9** = `.c`/`.o`/`.s`-zero north-star, atomic-decomposed (2026-05-28):
- wave 0 scoping: 3 audits (2 DONE #1809/#1810 · 1 running)
- `.s`: 4 items (1 quick-rm + 3 boot-floor)
- runtime.c portable: 6 (B9.2) + svc 3 (B9.3)
- native layer①: 3 (B9.5)
- runtime_core.c: 1 expand-stub (B9.4 · gated)
- codegen self-emit: 2 (B9.6 · SERIAL)
- linker: 1 cross-ref (B9.7) · FLOOR: 1 terminal (B9.8)

≈ 23 atomic. **2-track depletion**:
1. *additive reimpl track* (B9.1a · B9.2 · B9.5) — 병렬 fan-out 안전, 고갈까지 진행.
2. *serial codegen-wire track* (B9.6) — wipe-prone + fixpoint, 비병렬. 이게 실제
   `.c` 삭제 enabler. additive track 이 source 를 채운 뒤 wire.
3. *honest-floor* (B9.1b-d boot-floor · B9.7 cross-ref · B9.8 bootstrap-FLOOR) —
   terminal 또는 외부 트랙. 여기서 land 안 함.

**진짜 depletion** = track-1 전부 ship + track-2 가 runtime.c 를 dead 로 만들어
`find . -name '*.c'` 가 honest-floor (B9.8) 만 남을 때. track-2 는 multi-session.
이후 `/mining` 차기 divergence round 또는 도메인 pivot.

## deferred — RESOLVED (CLOSED-NEGATIVE · A/C/D coverage 충족)

레이어 ③ FFI 항목이 deferred 로 분리됐었으나, B2 batch 의 Option A/C/D 가
모두 LANDED 하여 CA bundle 정책 표면 전체가 hexa-self 로 충분히 커버됨.
Option B (system trust store FFI) 는 **추가 가치 없음** — A (pinned NSS) +
C (caller-supplied) + D (hybrid composition) 가 모든 use case 를 cover.

- [x] **B2.ca-system-fficacert** — **CLOSED-NEGATIVE** (2026-05-28). A/C/D
      충분 — Option B 는 layer ③ vendor FFI 카테고리 (`#1674` multi-dylib
      closed-neg pattern 과 동일), A/C/D 의 hexa-self 표면이 trust store
      lookup 의 모든 deployment scenario 를 커버하므로 추가 impl 불필요.
      만약 미래에 OS-native SecTrust integration 이 필요하면 별도 layer ③
      FFI 트랙으로 재오픈 (closed-neg-future flag).

      **LANDED A/C/D coverage**:
      - PR #1765 — `tls_ca_bundle_pinned_nss.hexa` (Option A · 100% hexa-self)
      - PR #1766 — `tls_ca_bundle_caller_supplied.hexa` (Option C · 100% hexa-self)
      - PR #1767 — `tls_ca_bundle_hybrid.hexa` (Option D · 100% hexa-self)
      - PR #1768 — `tls_ca_bundle_test_vectors.hexa` (test fixture)

      → deferred 섹션 zero open · all-46-active + 1-closed-deferred 모두 closure.
