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
- `.s` = **3** (3 irreducible boot-floor · B9.1a 로 dead fixture 1개 제거)
- `.c` = **226 → 99** (B9.6h 대량 삭제 후 · A merged #1823, B/C open). north-star
  충족 시 `find . -name '*.c' -o -name '*.s' -o -name '*.o'` 가 비어야 함.
  🎯 **세션 4개 단일삭제** — `crypto_blowfish.c` (B9.6c · #1816 · wire+regen) +
  `v565_grad_analysis.c` (B9.6d · #1818 · dead git-rm) + `hxtok.c` (B9.6e ·
  #1820 · dead git-rm) + `hxvocoder.c` (B9.6f · dead git-rm). 230→226.
  🎯🎯 **B9.6h 대량삭제** — 분포 스캔 결과 `.c` 카운트의 **대부분이 runtime/floor
  가 아니라 DEAD experiment scaffolding** 이었음 (아래 핵심 정정 ↓). archive/fires
  88 (A #1823) + tool/ probe-host 36 (B #1825) + 잡 3 (C #1826) = **127 삭제 →
  99**. findings(result.json/.verdicts/papers/.ptx) 전수 보존, harness `.c` 만.

⚠ **파일-수 vs 함수-수 구조 인사이트 (중요)**: `.c` *파일* 카운트는 파일 전체가
삭제될 때만 감소. `runtime.c`/`runtime_core.c` 는 각 1파일이지만 640/548 fn 을
**전부** 포팅해야 삭제 가능 (= FLOOR, multi-session). 따라서 단기 파일-삭제는
standalone `native/*.c` 에서만 나옴 — 그리고 그 중 **clean 케이스(blowfish 1-caller
wire · v565 dead-rm)는 이미 고갈**. 잔여 native/*.c 삭제는 전부 substantial port:

⚠ **핵심 정정 (2026-05-28 scoping 3/3 + dup-race precheck 후)**: `.c`-zero 의
진짜 병목은 reimpl 부재가 **아니다** — portable layer① 의 대부분(sha256·regex·
json·tokenizer·sha512·hkdf)은 **이미 hexa 로 존재**. `.c` 가 남는 이유는:
1. **codegen-wire 갭 (B9.6)** — 기존 hexa reimpl 이 machine-code 로 self-emit 안 됨
   → runtime 은 여전히 `.c` 버전 사용 (SERIAL · wipe-prone · 비병렬).
2. **GC/repr/arena FLOOR (B9.8)** — ~240 fn, irreducible bootstrap seed, infra-gated.
3. **vendor FFI (③)** — ~69 fn (native 19 + runtime 50), 포팅 ≠ 삭제 (영구 바닥).

→ **additive reimpl track 은 사실상 고갈** (blowfish 1개만 net-new). 남은 진짜 일은
B9.6 serial codegen-wire (~50-70 PR / 15-25 세션 · #1812 추정) + FLOOR infra.
병렬 fan-out 으로 닫히지 않음.

### B9.0 — scoping audits (wave 0 · DONE)

- [x] **B9.0a-native-c-audit** — `self/native/*.c` layer 분류 (#1809). 실측 32
      files = ①11 portable / ②2 floor / ③**19** vendor·kernel FFI. 현실 포팅
      대상 ~7 (`hxtok`·`sha256`·`blowfish`). 19/32 = honest FFI 바닥.
- [x] **B9.0b-asm-floor-audit** — `.s` 4개 분류 (#1810). 1 removable
      (`stage_1_forced.s` dead fixture) + 3 boot-floor (vector-table · RFC
      063/064 lowering gated). `@asm` 존재하나 codegen lowering no-op.
- [x] **B9.0c-runtime-c-fn-audit** — `runtime{,_core}.c` fn-level layer 분류
      (#1812). ~640 fn = ①120 portable(19%) / ②190 syscall(30%) / ③50 FFI(8%) /
      **GC-FLOOR 240(38%)**. 정직 추정: 전체 포팅 50-70 PR / 15-25 세션, FLOOR 가
      절반 + infra-gated.

### B9.1 — `.s` zero (4 → 0)

- [x] **B9.1a-stage1-forced-rm** — `tests/bootstrap/stage_1_forced.s` git rm
      DONE. dead fixture (실참조 0 · `as` reject · #1810 verdict). `.s` 4→3.
- [ ] **B9.1b-boot-rp2040-floor** — `boot_rp2040.s` (Cortex-M0+). irreducible
      vector-table boot-floor. RFC 063/064 `@interrupt`/`@target` lowering 전엔
      불가 → honest-floor 문서화 (closed-neg until RFC).
- [ ] **B9.1c-boot-stm32h7-floor** — `boot_stm32h7.s` (Cortex-M7 + FPU). 동상.
- [ ] **B9.1d-startup-stm32f429-floor** — `startup_stm32f429.s` (Cortex-M4
      CMSIS). 동상.

### B9.2 — runtime.c portable-fn hexa reimpl (layer ① · additive + oracle)

⚠ **DUP-RACE 발견 (2026-05-28 precheck · g61)**: portable layer① 의 상당수가 이미
hexa 로 존재 → reimpl 신규작성은 redundant. `.c` 가 남은 진짜 이유는 reimpl 부재가
**아니라** codegen-wire 갭 (B9.6). 따라서 B9.2 대부분은 reimpl 이 아닌 **wire 작업**
(B9.6) 으로 재분류.

- [⛔DUP] **B9.2c-regex-engine** — `stdlib/regex/mod.hexa`·`native.hexa` 이미 존재
      → 신규 reimpl 불필요. gap = codegen-wire (B9.6).
- [⛔DUP] **B9.2d-json-codec** — `self/rt/json.hexa`·`stdlib/alloc/json.hexa`·
      `self/runtime/json_mini_pure.hexa` 이미 존재 → wire 갭만.
- [ ] **B9.2a-array-ops** — `farr`/`hexa_array` (~98 fn) → `array_ops.hexa`.
      ※ 신규작성 전 dup 재확인 (다수가 codegen-emit 형태로 존재 가능).
- [ ] **B9.2b-string-ops** — `hexa_str` (~10 fn). ※ `stdlib/runtime/ctype.hexa`
      일부 커버 — 갭만 채움.
- [ ] **B9.2e-autodiff-tape** — `hexa_ad` (~12 fn). ※ `stdlib/flame/` autodiff
      존재 — dup 확인 필요.
- [ ] **B9.2f-safetensors-io** — `hexa_safetensors` (~16 fn). ※ flame safetensors
      reader 존재 가능 — dup 확인 필요.

### B9.3 — runtime.c layer-② svc surface (inline svc · kernel ABI)

- [ ] **B9.3a-process-svc** — `hexa_exec` process spawn (~24 fn) → `process_svc.hexa`
- [ ] **B9.3b-term-svc** — `hexa_term` ioctl (~26 fn) → `term_svc.hexa`
- [ ] **B9.3c-host-svc** — `hexa_host` env/host (~6 fn) → `host_svc.hexa`

### B9.4 — runtime_core.c portable subset (gated on B9.0c audit)

- [ ] **B9.4-expand** — `#B9.0c` audit 착지 후 portable bucket 을 atomic 으로
      분해 (~150 portable of 548; HexaVal repr·arena·GC 는 B9.8 FLOOR 제외).

### B9.5 — native/*.c layer-① port (gated on #1809 · dup-race 후 1 genuine)

⚠ **DUP-RACE (2026-05-28)**: ~7 realistic 중 2개가 이미 hexa 존재 → blowfish 만 net-new.

- [x] **B9.5a-tokenizer-bpe** — `self/ml/tokenizer_bpe.hexa`·`qwen_bpe.hexa`
      이미 존재. native `hxtok.c` = standalone dead shim (빌드/링크/FFI 호출 0건).
      **DELETED B9.6e (228→227)** — dead-file git-rm (v565 패턴), reimpl 아님.
- [⛔DUP] **B9.5b-sha256-core** — `stdlib/core/hash/sha256.hexa`·`stdlib/crypto/`
      이미 존재. wire 갭만.
- [x] **B9.5c-blowfish** — `crypto_blowfish.c` (pi-seeded bcrypt) →
      `stdlib/crypto/blowfish.hexa` DONE (#1814). 🟢 **RUNEQ 입증** — hexa
      `bcrypt_pbkdf` 가 C builtin `hexa_bcrypt_pbkdf` 와 byte-identical
      (`e0497b73…93f23f7c`). 17/17 KAT PASS · ssh/keyfile API 정확 일치 · no-DUP.
      (③19 = honest FFI floor · 포팅 대상 아님)

### B9.6 — codegen self-emit (genuine `.c`-delete route · SERIAL · non-parallel)

이게 진짜 `.c` 삭제 enabler — B9.2/B9.4/B9.5 reimpl 을 machine-code 로 self-emit
해야 runtime.c 가 dead. wipe-prone + rebuild + fixpoint 필요 → 격리-worktree 병렬
fan-out 불가, serial 진행.

- [x] **B9.6c-blowfish-c-delete** — 🎯 **첫 실제 `.c` 삭제 DONE (230→229 · #1816)**.
      7-surface 제거 (runtime.c #include · runtime.h decl · bind.hexa allowlist ·
      codegen.hexa emit+is_builtin · keyfile.hexa rewire · hexa_cc.c regen) +
      `crypto_blowfish.c` git rm. **fixpoint byte-identical (gen2≡gen3, 1851200 B)**
      · link clean · keyfile resolves via `use "stdlib/crypto/blowfish"`. wipe-prone
      runtime.c guard held. **codegen-wire 레시피 end-to-end 입증.**

      ⚠ **다음 후보 분석 (레시피 입증됐으나 clean 케이스는 제한적)**:
      - `exec_argv_sha256.c` → ❌ NOT clean: `sha256`/`sha256_file` builtin 을
        falsifier·hexa_ld·main·codegen 등 **핵심 컴파일러 다수**가 직접 호출 +
        stdlib 이름 불일치 (`sha256` vs `sha256_hex`) + exec-shim 번들. 무리한
        삭제 = 컴파일러 붕괴. 다중 rewire+rename 필요한 별도 큰 작업.
      - 나머지 native ③19 = vendor FFI (포팅≠삭제 · 영구 바닥).
      - blowfish 가 유일한 깔끔한 1-caller 케이스였음. 다음 `.c` 삭제는 per-file
        caller-count + name-match 분석 선행 必 (clean 케이스 추가 탐색 = B9.6d).
- [x] **B9.6d-next-clean-c-delete** — `v565_grad_analysis.c` 삭제 DONE (#1818 ·
      229→228). DEAD 1-off harness (only `main()`, dlopen consumer, 빌드 레시피
      無, 0 caller) → pure `git rm`, 가장 깔끔한 케이스. **이후 clean DEAD/1-caller
      파일-삭제 후보 고갈 확정.**

      **잔여 native/*.c 삭제 = 전부 substantial multi-session port (clean 아님)**:
      - ~~`hxtok.c`~~ — **B9.6e 에서 dead-file git-rm 으로 해결 (port 아님)** ↓
      - ~~`hxvocoder.c`~~ — **B9.6f 에서 dead-file git-rm 으로 해결 (port 아님)** ↓
        (audit 가 layer① port 후보로 분류했으나 정밀 재검증 결과 0-caller DEAD)
      - `hxflash_linux.c`/`hxlayer_linux.c`/`hxvdsp_linux.c` — ⛔ **PERF-FLOOR
        (B9.6g 검증 · port 불가)**. audit 가 "layer① portable" 로 오분류했으나,
        이들은 `@link(...)` FFI `.so` (H100 ML 학습 hot-path · `tool/deploy_h100`
        배포 · dlopen). pure-hexa 등가가 **이미 존재**(`hxlayer.hexa:ref_rmsnorm_silu`)
        하나 `bench_hxlayer_matrix.hexa` 측정 **C 가 285x 빠름** → 포팅 시 ML 학습
        285x 회귀 (perf-floor). + hexa `fn` 은 standalone `.so` 로 dlopen 불가
        (FFI deploy 모델 재현 불가). **vendor-FFI 와 동급 irreducible** — 삭제 X.
        (B9.6g 는 GO/NO-GO 게이트에서 편집 0건 honest-abort.)
      - `exec_argv_sha256.c` — sha256 builtin 다중 core-compiler caller + 이름불일치
        (대규모 rewire 트랙)
      - vendor FFI ③19 (CUDA/openssl/sodium/OS-ABI) — irreducible 영구 바닥
      - `runtime.c`/`runtime_core.c` — 640/548 fn FLOOR (전부 포팅해야 파일 삭제)
- [x] **B9.6e-hxtok-c-delete** — 🎯 **실제 `.c` 삭제 DONE (228→227)**. (B9.6d 의
      "hxtok = port 필요" 예측은 정밀 audit 으로 반증됨 — port 아닌 dead-file.)
      `self/native/hxtok.c`(750L)+`hxtok.h`(49L) Qwen2.5 BPE C 라이브러리 삭제.
      정밀 audit: standalone shim — `tool/`·`*.json`·`*.sh` 빌드 스크립트 0건,
      `.so`/`.dylib` 아티팩트 0건, 전 repo `HxTok`/`hxtok_*` FFI 호출 0건 (유일
      매치 = `compiler/roadmaps_archive/embedded.gen.hexa` 의 archived 텍스트
      리터럴, 코드 아님). 순수-hexa 등가(`qwen_bpe.hexa`·`tokenizer_bpe.hexa`)가
      8개 consumer 전수 서빙. **삭제 후 8/8 consumer `hexa parse` clean** — C
      lib 가 dead 였음을 입증 (RUNEQ moot: live caller 0). runtime.c 무관(미
      include). blowfish(#1816)·v565(#1818) 의 dead-file 패턴.
- [x] **B9.6f-dead-native-c-sweep** — 🎯 **실제 `.c` 삭제 DONE (227→226)**.
      `self/native/hxvocoder.c`(455L · HEXA-SPEAK 뉴럴 보코더) 삭제 — hxtok 패턴.
      audit `docs/runtime_native_c_layer_audit.md` 가 layer① "포팅 적격"
      으로 분류했으나 정밀 재검증 결과 8 export 심볼(`hxvocoder_decode_nv`/
      `_decode_wave`/`_linear_proj`/`_synth_additive`/`_tanh_vec`/`_vec_zeros`/
      `_version`/`_write_wav`) 전부 전 repo 코드 0-caller. 유일 빌드 참조 =
      `tool/build_native.hexa` 의 `file_exists` 가드 조건부 link (파일 삭제 시
      자동 skip → 그 dead 블록도 제거). `.h`/`.so`/`.dylib`/`.o` 아티팩트 0건,
      `build_toolchain.json` 항목 無, `dlopen` 0건. runtime.c 미 include.
      `clang -fsyntax-only self/runtime.c` EXIT 0. **4 PRIMARY 후보 중 hxvocoder
      만 DEAD; hxflash/hxlayer/hxvdsp 는 실제 FFI caller 보유 LIVE (위 B9.6d 표
      정정)**. 그 외 standalone native (gpu_codegen_stub·hxffi_slot·hxblas·hxccl
      ·hxlmhead·hxqwen14b/32b·lora_cuda_host·hexa_cc) 전수 재스캔 = 전부 LIVE
      caller/build-ref 보유 (PRESERVE). blowfish(#1816)·v565(#1818)·hxtok(#1820)
      의 dead-file 패턴 연장.
- [x] **B9.6g-hxlayer-port-attempt** — ⛔ **BLOCKED · perf-floor 확정** (편집 0건
      honest-abort). hxlayer_linux.c 는 CPU(GPU 아님)지만 `@link` FFI `.so` (H100
      배포) + pure-hexa 등가가 측정상 **285x 느림** → 포팅=ML 학습 285x 회귀. hexa
      `fn`→dlopen `.so` 재현 불가. → hxflash/hxlayer/hxvdsp 전부 perf-floor 재분류
      (위 B9.6d 표). harm-guard 가 정확히 작동 — perf-critical 커널 삭제 방지.

      🏁 **`self/native/*.c` 범위의 clean/safe single-file count-reduction 고갈**
      (세션 4건: blowfish wire + v565/hxtok/hxvocoder dead). 잔여 native 28 =
      perf-floor(hxflash/hxlayer/hxvdsp · 285x) + vendor-FFI③19 + sha256-entangled
      + runtime FLOOR — 전부 multi-session codegen self-emit(B9.6a/b) 또는
      irreducible.

      ⚠ **정정 (B9.6h 분포 스캔)**: 위 "고갈" 은 `self/native/` 만 본 **좁은 결론**
      이었음. 전-repo `.c` 226 의 **bulk 은 runtime/floor 가 아니라 archive/fires
      (87) + tool/ probe-host (68) = 155 의 DEAD experiment scaffolding** (GPU-fire
      host wrapper · cuBLAS baseline · transcendental probe). 단일-PR 안전 삭제
      가능한 죽은 harness 가 대량으로 남아있었음 → B9.6h 로 127 삭제. floor/wire
      트랙(B9.6a/b)과 무관한 별도 cleanup 레인.
- [x] **B9.6h-dead-experiment-scaffolding-sweep** — 🎯🎯 **대량 `.c` 삭제 (226→99 ·
      127 파일 · A merged #1823 / B #1825 / C #1826)**. 분포 스캔의 핵심 발견:
      `.c` 카운트의 **bulk 은 runtime/vendor floor 가 아니라 DEAD experiment
      harness** — `archive/fires/` 87 (GPU-fire host: cuBLAS baseline · wmma host
      · roofline · rfc067 sgemm host · rfc071 silicon) + `tool/` probe-host 68
      (adamw/exp/layernorm/logsumexp/probe_*/r067-r070/sweep). findings 는
      result.json/`.verdicts/`/papers/`.ptx` 에 보존, `.c` 는 harness 일 뿐.
      per-batch verify-dead (빌드 레시피 grep + `#include` 체크; provenance 주석
      참조는 live 아님):
      - **Batch A (#1823 MERGED)** — `archive/fires/*.c`+`.h` 88 git-rm.
        live-ref = `nvptx_*.hexa` 주석 + parse_only fixture 주석뿐. findings 515건
        보존. 226→139.
      - **Batch B (#1825 OPEN)** — dead `tool/*.c` 36 git-rm. KEPT-LIVE:
        `hexa_daemon_serve.c`(build.sh→bin), `gpu_standalone_cubin_host.c`+
        `fusion_epilogue_cublas_timed.c`+`gpu_multiarch_fatbin_host.c`(probe.hexa
        preflight), **flame_phase4* byte-eq battery 전체**(`verify_all.sh`
        `${leaf}`/`${bench}` 동적 루프 + `*_build.sh`/`dispatch_*.sh` 컴파일),
        `cuda_syntax_stub/*.h`(vendored allow-list), `tool/test/hexa_ld_*`
        링커 fixture 7(active linker dev · 보수적 KEEP). 226→190.
      - **Batch C (#1826 OPEN)** — isolated dead 3 git-rm (`exports/nvptx_math_fire/
        host_math.c` · orphan `poc_arena_bundle_caller.c` · `runtime_hexaval_
        sketch.c` "DESIGN SKETCH ONLY"). KEPT-LIVE (verify 결과 대부분 live):
        sscb firmware src 5(Makefile wildcard) · hal t3 harness 2(make+ELF
        assert) · hxpyembed/hxnccl(cmake/@link) · self/cuda runtime 2(CUDA
        bridge) · self/forge tier(build_hexa_cli shadow-sync) · state flame 2
        (dispatch) · poc_rt_exit_caller(drive.hexa) · example bench_*_native 3
        (C-ceiling baseline · 보수적 KEEP) · self/*nanbox* tests(live
        hexa_nanbox.h 검증). 226→223.
      smoke: `clang -fsyntax-only self/runtime.c` EXIT 0 · `self/native/*.c`(28
      floor) 무손상 · 삭제 심볼 live grep 0. **floor/codegen-wire(B9.6a/b) 와
      독립된 cleanup 레인** — git-recoverable.
- [ ] **B9.6a-hexaval-repr-emit** — HexaVal repr 생성자 codegen self-emit
      (`self/codegen/runtime_arm64.hexa` 확장; `rt_arena_*` 4 fn LANDED 패턴).
      ⚠ serial · regen+fixpoint · phase-h codegen 에이전트와 경합 · expert work.
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

### → 별도 도메인 split: `RUNTIME.floor.md`

B9.6 의 irreducible / perf-floor / multi-session 항목(perf-kernel 285x · vendor-FFI
③19 · runtime 640/548-fn FLOOR · sha256-entangled · `.s` boot-floor · bootstrap
seed)은 **`RUNTIME.floor.md`** 자매 도메인으로 분리(2026-05-28, 사용자 지시).
flip = quick-win 안전 삭제 캠페인(거의 종결), floor = 물리 바닥 전담. B9.6a/b
codegen self-emit 가 그 바닥의 단일 enabler.

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
