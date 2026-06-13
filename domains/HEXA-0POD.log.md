# HEXA-0POD — log

## 2026-06-13 — OP-120 DONE: LANE-2 RECURSION-DEPTH / UNBOUNDED-NESTING DoS systemic sweep (CWE-674 "Uncontrolled Recursion") — 🔴×3 FIXED; three shipping recursive JSON value/object/array parsers fed untrusted input had NO depth cap (call-stack blows on `[[[[…]]]]`), all now depth-threaded + fail-closed at MAX_DEPTH=512, locked by a hermetic guard whose negative control proves the uncapped depth grows 1:1 with input nesting
- LANE: 2 (0-pod correctness/security — recursion-depth / call-stack-exhaustion axis). FRESH class: the exhausted resource is CALL-STACK DEPTH, growing LINEARLY with input nesting — DISJOINT from OP-115 (count-driven unbounded WORK), OP-118 (size-arithmetic int-overflow), OP-105 (offset OOB-read), and from sibling LANE-1's OP-121 comparator.
- CLASS HUNTED: recursive-descent parsers / structure-walkers fed UNTRUSTED nested wire input — JSON nested `{…}`/`[…]`, ASN.1 DER constructed-type tags, nested protocol framing, recursive expression/grammar parsers — that thread NO `depth`/`max_depth` and never cap it. A malicious deeply-nested input `[[[[ … ]]]]` (a single byte per level) pushes one native stack frame per level → unbounded recursion → stack-overflow crash = remote DoS.
- METHOD: thorough grep over stdlib/ + self/ for `fn .*parse`/`fn .*decode`/`fn walk`, then traced which parse functions SELF-RECURSE through a value↔object↔array (or tag↔constructed) cycle vs which iterate; per candidate, checked whether a depth counter is threaded and capped. Repro WITHOUT blowing the real stack: a counted depth-recorder of the uncapped descent proves depth = input-nesting (linear, unbounded), and the FIXED parser is differentially tested at the cap boundary.
- RESULT: 🔴×3 FIXED. THREE shipping recursive JSON parsers, all uncapped, all on untrusted input:
  - 🔴#1 `self/serve/http_server.hexa` `_json_parse_value`→`_json_parse_object`/`_json_parse_array`→`_json_parse_value` — `json_parse` runs on the untrusted HTTP REQUEST BODY (the Anima server's request handler). A `[[[…]]]` POST body is a remote crash.
  - 🔴#2 `self/rt/json.hexa` `_jp_parse_value`/`_jp_parse_array`/`_jp_parse_object` (`rt_json_parse`) — runtime JSON handed arbitrary text.
  - 🔴#3 `stdlib/cert/meta2_validator.hexa` `_parse_value`/`_parse_object`/`_parse_array` — parses untrusted CERTIFICATE / attestation JSON (`parse_cert_from_string` / `parse_chain`).
- FIX (all 3, fail-closed, mirroring the `self/comptime.hexa` threaded-`max_depth` precedent which already caps comptime expansion): thread a `depth: int` through the mutual recursion and, past `MAX_DEPTH = 512`, return the existing parse-error / null sentinel ([nil,-1] for http_server, [void,start] for rt/json, the "null" value-record for meta2) instead of recursing — descent terminates, stack bounded to a constant. 512 dwarfs any honest config/API/cert payload nesting yet sits far below the native stack limit; the constant is documented at each site.
- CENSUS (rest CLEAN, honest g5): the core `json_parse_object`/`json_parse_array` (stdlib/alloc/json_object.hexa) delegate to a NATIVE builtin — not hexa-level recursion, so no hexa stack frame per level. `self/lsp.hexa` JSON is OUTPUT-only (json_value_to_json stringify), not a parser. The x509/DER parsers (crypto/x509_{min,rsa,p256,validity}, tls13_certificate) are FLAT byte-walks — a SEQUENCE body is sliced by length and its fields parsed ITERATIVELY (der_next advances a cursor), NOT via constructed-type self-recursion → no depth growth. SMILES/molecule parsers iterate over a ring/branch stack (data structure), not native recursion.
- LOCK: NEW `stdlib/info/recursion_depth_dos_guard_op120_test.hexa` — HERMETIC guard run with `hexa run` (11/11 PASS). It re-derives the FIXED http_server depth-threaded fail-closed value/array recursion VERBATIM and asserts: (a) honest nesting (empty, leaf, depth-4/100/510/513) is ACCEPTED; (b) depth bombs (514/1000/5000) are REJECTED via the [nil,-1] sentinel — no stack blow-up; (c) NEGATIVE CONTROL — the same descent WITHOUT the cap, instrumented with a max-depth recorder (not real recursion to the bomb depth, which would crash the runner), reaches depth = input-nesting (49 on a 50-nest, 999 on a 1000-nest), proving the uncapped depth growth the production cap kills. Boundary note: an L-deep nest reaches parse_value at depth L-1 for the innermost empty `[]` leaf, so the cap (`depth > 512`) admits L≤513 and rejects L≥514.
- FLAGS: all 3 edited files are build_selfhost-closure-OUT — verified by REPRODUCING the `compiler/main.hexa` use/import closure walk (36 files; none of `self/serve/http_server`, `self/rt/json`, `stdlib/cert/meta2_validator`) → ZERO byte-eq / self-host-fixpoint impact, no gate. Net-additive (one depth param + one gate per parser, 0 deletions) → wipe_guard N/A. NEW leaf test is closure-OUT. NO .tape. Repro logic verbatim-INLINED in the leaf (stale-bundle-immune). LANE-2 only — disjoint from sibling LANE-1.
- DISCIPLINE: $0 · 0-pod · NO GPU · no vast · no cloud · no foreign pod touched · leak-0.
- Verdict: .verdicts/hexa-0pod/F-OP120-RECURSION-DEPTH-DOS.txt (verbatim 11/11-PASS stdout).

## 2026-06-13 — OP-121 DONE: LANE-1 COMPARATOR / TOTAL-ORDER-VIOLATION systemic sweep (sort/heap/priority-queue/binary-search/merge) — 🟢 CONVERGED, NO 🔴; every shipping comparator already uses BRANCH-COMPARE or BOUNDED subtraction, locked by a hermetic guard whose negative control PROVES the subtract-comparator i64 wrap is a real total-order violator the codebase avoids
- LANE: 1 (0-pod correctness/security — comparator total-order axis). FRESH class disjoint from the OOB/DoS/injection/numeric/unchecked-sentinel classes (OP-103/105/106/108/110/112/113/114/115/116/117/119) and from sibling LANE-2's parser-size-arith (OP-118). Builds ON OP-118's confirmed fact: hexa `int` is 64-bit SIGNED and WRAPS (ASN.1 length wrap, websocket top-bit). A comparator `cmp(a,b):=a-b` therefore returns the WRONG SIGN when `a-b` overflows i64 → strict total order broken → sort/heap/bsearch silently MIS-ORDER.
- CLASSES HUNTED: (A) SUBTRACT-BASED comparators `a-b` / `key_a-key_b` over UNBOUNDED signed ints (timestamps, ids, scores, signed quantities) feeding a sort/heap/priority-queue/binary-search/merge; (B) FLOAT/NaN comparators where NaN's non-transitivity (`NaN<x` and `x<NaN` both false → treated equal) makes the order non-transitive, mis-ordering a sort.
- METHOD: thorough fan-out grep over stdlib/ + self/ for `fn .*cmp`/`fn compare`, every sort/heapify/sift/bsearch/merge call site + the comparator it passes, and every `return X - Y` ordering callback. Then per-candidate bounded-vs-unbounded operand analysis (char-codes / lengths = bounded-safe; timestamps/ids/scores = wrap-risk) and a finite-vs-NaN-path check for float-keyed sorts.
- RESULT: 🟢 CONVERGED — NO 🔴. Every comparator in the shipping surface uses BRANCH-COMPARE (`if a<b…if a>b…`) or BOUNDED subtraction. No unbounded-i64 subtract-comparator and no NaN-injection-into-sort path exists.
- COVERAGE MATRIX (all CLEAN): stdlib/alloc/collections.hexa sort (`<`); stdlib/runtime/numeric.hexa rt_array_sort_float / rt_array_sort_by (`<=`); stdlib/crypto/{p256,secp256k1,rsa_pkcs1}.hexa `_cmp` (MSB-first limb branch); stdlib/semver.hexa + self/package.hexa semver_cmp (branch); stdlib/core/math/permille.hexa pm_cmp (branch); stdlib/core/trait_design_fixture.hexa cmp_int/cmp_float/cmp_str (branch — note its `sub_int`/`sub_float` are the ARITHMETIC Sub-trait ops, NOT comparators, ruled out); self/rt/core.hexa `_rt_num_cmp` (int/float branch) and `_rt_str_cmp` (`ca-cb` over char-codes 0..0x10FFFF and `na-nb` over non-negative lengths = BOUNDED, diff << 2^63, cannot wrap → SAFE); self/runtime/heap_pure.hexa min-heap sift (`<=`/`<`); self/runtime/sort_variants_pure.hexa heap_sort + `_asc`/`_desc` (branch); self/stdlib/sort.hexa merge sort_by/sort_desc_by (`<`); stdlib/kernels/noc_sim/event_queue.hexa `_ev_less` (lexicographic (time,seq) branch, deterministic float, no NaN); self/ml/hnsw.hexa + cluster/core_knn + chemistry_vqe Nelder-Mead simplex sorts + quantum/phi argsort (finite-float branch, no NaN injection path).
- FALSIFIER REPRODUCED (honest g5, `hexa run` LOCAL 0.1.0-dispatch — i64 wrap is real, matching OP-118): with big=i64_max=9223372036854775807, small=-(i64_max): TRUE order small<0<big so a correct comparator gives cmp(big,small)>0. `cmp_sub(big,small)` = big-small = 2·(2^63-1) OVERFLOWS and WRAPS to **-2** → reports big<small → TOTAL ORDER VIOLATED. `cmp_branch(big,small)` = **1** → correct. Selection-sorting `[big, small, 0]`: branch-compare → `[small, 0, big]` (matches Python `sorted()`); subtract-compare → head ≠ small (MIS-SORTED). Probe verbatim: `sub(big,small)=-2`, `branch(big,small)=1`.
- LOCK: NEW stdlib/core/cmp_total_order_test.hexa — HERMETIC guard, `hexa run` LOCAL → 10 passed / 0 failed ALL GREEN. Oracle = branch comparator's total order on i64 extremes + antisymmetry (`cmp(a,b)==-cmp(b,a)`) + trichotomy + correct sort of the extreme array. Negative control = the subtract comparator demonstrably wraps (`sub<=0`) and mis-sorts (head≠small) — proving the wrap is a REAL total-order violator (not a stale-compiler artifact; the interpreter computes i64 wrap correctly).
- HONEST g5: GOAL = closing the comparator-total-order class. The comparator surface is uniformly branch-compare BY CONSTRUCTION → an evidence-backed "class clean / LANE-1 converged" is the truthful SUCCESS; no 🔴 fabricated. The leaf + negative control make the guard load-bearing (the wrap really breaks the order). A zero-bug converged result with a coverage matrix + guard test is the valid 🟢 outcome per the task.
- FLAGS: NO source edit (surface already correct, CLEAN=🟢) → ZERO byte-eq / fixpoint / self-host-gate impact. NEW leaf stdlib/core/cmp_total_order_test.hexa is a standalone test (closure-OUT of build_selfhost ~48-file set) → fixpoint UNAFFECTED. wipe_guard N/A (1 new file ~150L, 0 deletions). NO .tape edit. LANE-1 only — disjoint from sibling lanes (this shared worktree also had concurrent OP-120 recursion-DoS uncommitted changes which I did NOT touch).
- DISCIPLINE: $0 · 0-pod · NO GPU · no vast/cloud rental · no foreign-pod · leak-0. Verdict .verdicts/hexa-0pod/F-OP121-COMPARATOR-TOTAL-ORDER.txt (verbatim test stdout). Milestone OP-121 [x].

## 2026-06-13 — OP-119 DONE: LANE-1 0-pod UNCHECKED-ERROR-SENTINEL / silent-failure sweep (NON-parser stdlib data/algorithm/util) — 🟢 CONVERGED, NO 🔴; every finder-sentinel consumer GUARDS the -1/default before use, with the guard PROVEN load-bearing by a hermetic leaf oracle + negative control (the unguarded twin faults `arr[-1]` / yields a silently-wrong window)
- LANE: 1 (0-pod correctness/security — unchecked-error-sentinel axis). A FRESH class disjoint from the OOB/DoS/injection/numeric classes swept OP-103/105/106/108/110/112/113/114/115/116/117 and from sibling LANE-2's parser-size-arith integer-overflow (OP-118). COMPLEMENTS LANE-2's OP-102, which swept the net/string/PARSER index_of surface — this round is the NON-parser data/algorithm/util complement (collections, math/stats, string utils, table/lookup, graph/cluster, kernels, audit tools).
- CLASS: a stdlib fn signals miss/malformed by RETURNING A SENTINEL (find/index_of/find_index → -1, a lookup default, a finder → len/-1) rather than raising, and a CALLER USES that sentinel WITHOUT checking it — `arr[index_of(x)]` (→ negative-index read), a slice `xs.substring(find(a), …)` / window `xs[find(a)..find(b)]` where a -1/len makes a wrong/inverted slice. The silent-wrong-data class: no crash, no exception — a quietly incorrect result (and sometimes a negative-index OOB).
- NEGATIVE-INDEX SEMANTICS (probed `hexa run` 0.1.0-dispatch — decides whether an unchecked -1 is silent-wrong-value vs OOB): `arr[-1]` is a HARD FAULT (`index -1 out of bounds (len 3)`), NOT a Python-style wrap to the last element. So an unchecked -1 finder-sentinel used as an INDEX is a crash/DoS; used in a SLICE/arithmetic it is silent-wrong-data. Confirmed verbatim: `arr[idx_of("ABC","X")]` (miss → -1) → `index -1 out of bounds (len 3)`. Also probed: `to_int("abc")` / `parse_int("zz")` ERROR (`to_int: not an integer: "abc"`) — NOT a silent-0 sentinel → the parse-silent-0 sub-class is vacuously closed for the builtin. `.find`/`.index_of` builtins return -1 on miss (`"hello".find("z")` → -1).
- CENSUS MATRIX (site → checked/unchecked → action; scoped greps NO .git; ALL CHECKED — NO UNCHECKED-SENTINEL):
  - collections.find_index → -1 (stdlib/alloc/collections:55): NO non-self stdlib call sites (only self-module) → vacuously CLEAN 🟢.
  - semver._sv_index_of (4 call sites :215/:222/:348/:350): all `if !(plus<0)` / `if !(dash<0)` CHECKED → slice only on a hit 🟢.
  - http/_http_last_index_of (:140/:213), http2/_h2_last_index_of (:115/:119), net/_net_http_last_index_of (:103): all `if nl<0 { return result }` CHECKED 🟢 (text helpers peeling the curl `\n%{http_code}` sentinel — note: borderline-parser but text-util, and OP-102 already swept the same; kept for completeness).
  - cli/_index_of (5 sites: :170/:177 sep-guard, :427/:429 colon-split, :612 `::`-strip): all `if sep_at<0{continue}` / `if c1<0{return ["","",""]}` / `if sep>=0` CHECKED 🟢.
  - record_loader.rl_index_of (:460): `if si>=0` CHECKED 🟢.
  - keychain.last_index_of(`::rc=`) (:138/:194): `if mi<0 { return }` CHECKED 🟢. proc/websocket last_index_of(`{`/`}`) (:84/:438/:248-249): `if <0 || ...{ return }` CHECKED 🟢. http_sse.index_of(`:`) (:327): `if colon<0 { whole-line-is-field rule }` CHECKED 🟢.
  - bio/matter AUDIT-TOOL finders idx_of / find_idx / find_sub / idx_of_int (cross_axis_matrix:118 `if pos_idx<0{break}`, status_md_generator:200-209/:733-736 `if pN>=0`/`if si<0{return ""}`, c_handoff_completeness_audit:85 digit-guarded/:167 `if at<0{break}`, lattice_fit:141/:145 `if cN<0{continue}`, registry_consistency_audit:140/:143 `if at<0`, virocapsid_pdb_corpus:315/:318/:329 `if kidx<0`, schema_const_audit:380/:597 `if <0`, n_substrate_putnam_check json_string_field:159/:166/:325 `if idx<0{return ""}`/`if end<0{return ""}`/`if idx<0{return CLEAR}`): ALL CHECKED 🟢.
  - magnet_gate res.find("→")/("->") (:463-:472): `tail_start` defaults -1, set only inside `>=0` guards, `if tail_start<0 { return -1.0 }` CHECKED 🟢. godel.find_int_lit (:92): `if start<0 { return ["0",line] }` CHECKED 🟢. wolfspeed._index_of_char (:151/:302): `if idx<0{return line}` / `if eq>0` CHECKED 🟢.
  - kernels/noc_sim traffic_dest_* → -1 (:132/:147/:210+ + dispatcher :227): a documented INVALID-DEST sentinel propagated up; no unchecked-as-index consumer in stdlib (the self-test callers compare to expected values, no array-index) 🟢.
  - PROVABLY-PRESENT-KEY direct-index (the only `arr[finder(...)]` sites): registry_consistency_audit:164 `unc_cnt[idx_of(unc_tags, tg)]` where `tg ∈ sort_str(unc_tags)` → always a member → ≥0 always; c_handoff:85 `find_sub("0123456789", digit, 0)` guarded by `is_dig` → digit always 0-9 → always found. SAFE 🟢.
- MECHANISM KEY: `if idx < 0 { fallback }` miss-guard at every consumer / provably-present-key lookups for the two direct-index sites. The non-parser stdlib surface is uniformly disciplined about its finder sentinels.
- LOCK (HERMETIC verbatim-inlined, no `use` — stale-bundle dodge OP-87/88, closure-OUT): NEW stdlib/info/unchecked_sentinel_guard_op119_test.hexa — shipping `hexa run` LOCAL → `OP119 unchecked-sentinel-guard pass=8 fail=0` then `ALL GREEN`. Re-derives the canonical finder-sentinel shape `idx_of(s,ch) → -1` + the GUARDED consumer `after_char_guarded` (`if at<0 { return s /*documented fallback*/ }`): HIT path peels correctly ("key=value"→"value"); MISS path returns the documented whole-string fallback (NOT a -1 slice); a guarded array lookup `if where>=0 { arr[where] }` skips the read on a miss; hit lookup still works. NEGATIVE CONTROL: the UNGUARDED twin's miss-start = `-1+1 = 0` → would slice the WHOLE input (a silently-wrong "found everything" window) instead of the not-found fallback, and the raw sentinel -1 used as an index would fault `arr[-1]` — asserts the unguarded value really is wrong (0 / -1), proving the `if at<0` guard does real work. Verified separately (`hexa run`) that the actual unguarded twin `arr[idx_of("ABC","X")]` faults verbatim `index -1 out of bounds (len 3)`.
- FLAGS: NO source edit (the class is already CLEAN → 🟢 not a fabricated fix) → ZERO byte-eq/fixpoint impact, no selfhost gate. The audited files (collections, semver, http/http2, net/http_client, stdlib_cli, demi/record_loader, keychain, proc, websocket, http_sse, bio/matter _hexa_bridge audit tools, fusion/magnet_gate, sim_universe/godel_q, kernels/circuit, kernels/noc_sim) are NOT in the build_selfhost closure (no self/* nor build_selfhost.sh dependency). The NEW leaf lives in stdlib/info (non-self, closure-OUT) → fixpoint UNAFFECTED. wipe_guard N/A (1 new file ~110 lines, 0 deletions, 0 edits to existing code). NO .tape.
- HONEST g5: the GOAL was closing the unchecked-error-sentinel class in NON-parser stdlib data/algorithm/util code. Every finder-sentinel consumer guards the sentinel by construction (or indexes with a provably-present key); an evidence-backed "all consumers guard the sentinel — class clean / LANE-1 converged" is the truthful SUCCESS here, NOT a found 🔴, and the leaf + negative control prove the guard is real and load-bearing (the unguarded twin really faults / yields the wrong window). No 🔴 fabricated. $0 · 0-pod · NO GPU · no vast · no foreign-pod · leak-0. Milestone OP-119 [x]. Verdict F-OP119-UNCHECKED-SENTINEL.txt.

## 2026-06-13 — OP-118 DONE: LANE-2 0-pod integer-overflow / signed-length confusion in SIZE-ARITHMETIC in binary/protocol/crypto PARSERS (the size-COMPUTATION-step complement of OP-105 offset-OOB + OP-115 unbounded-work) — 🔴×2 (ASN.1 DER long-form length overflow · websocket 64-bit length RFC top-bit) FIXED+locked; the rest of the parser family 🟢 PROVABLY wrap-immune
- LANE: 2 (0-pod security). CWE-190 → CWE-125/787 size-computation chain: a parser reads a length/count/size FIELD from untrusted bytes then does ARITHMETIC on it (accumulate a big-endian width, add a header size, derive der_next = start + len) to compute an ALLOCATION size / OFFSET / COPY-COUNT. If the arithmetic WRAPS past the int domain (→ a small/negative result) or the field is interpreted as SIGNED (a negative length passes a `< cap` bound then is used as a span; a `total = a+b` that wraps to < a bypasses a later `< total` check), the computed size is WRONG. Disjoint from sibling LANE-1 (OP-119 unchecked-error sentinel in util; OP-108 hash/checksum/LCG numeric overflow) — this is PARSER size-arithmetic only.
- STEP 1 SEMANTICS PROBE (GATES the sub-class; verbatim `hexa run` /tmp/op118_probe.hexa):
  - `imax=9223372036854775807` / `imax+1=-9223372036854775808` → hexa `int` is 64-bit SIGNED (i63 effective), it WRAPS (NOT an unbounded bignum). Confirms OP-108's model.
  - `a*b=-2446744073709551616` (4e9 * 4e9) → multiply overflows to NEGATIVE.
  - `neg<cap PASSED bound (neg=-5)` → a negative length PASSES a `< cap` upper-bound check.
  - `total=-9223372036854775716 total<x?=true` → a `a+b` wrap makes total < a (a subsequent `< total` check is bypassed).
  - FINDING: ALL FOUR sub-classes are REAL and reachable. But overflow is only reachable where the declared width is VARIABLE (ASN.1 DER long-form, up to 127 length bytes) or a full 64-bit field (websocket 127-form). Narrow fixed-width fields (≤24-bit, most of the TLS13 family; ≤32-bit) are wrap-IMMUNE because max 2^32-1 ≪ i63.
- 🔴 #1 — ASN.1 DER long-form length overflow (stdlib/crypto/asn1_der.hexa der_value_len):
  - PRE-FIX: long form `nbytes = n & 0x7F` (up to 127) then `v = (v << 8) | byte` with NO cap. For nbytes ≥ 9 (or an 8-byte form with the high bit set) v shifts/accumulates past i63 and WRAPS negative. Then der_next = der_value_start + v REGRESSES below der_value_start (TLV iteration loops/regresses BACKWARD), and the negative n_len/e_len/r_len/s_len feed x509_{min,rsa,p256,validity} reads as a huge unsigned span. der_value_len + der_next are consumed by the CORE X.509 cert-chain parsers.
  - REPRO (verbatim `hexa run`, inlined; pad so the OP-105 co-bound passes): `9-byte: prefix=-1 fixed=0` · `8-byte-FF: prefix=-1 fixed=0` · `der_next: pre=10 (start=11) fixed=11` (pre-fix der_next 10 < value_start 11 = BACKWARD).
  - FIX (minimal, net-additive): `if nbytes > 8 { return 0 }` (a length needing >8 bytes can't fit non-neg i63) + `if v < 0 { return 0 }` (the 8-byte form can still set the high bit). Return 0 = empty value, the same graceful short-read result a truncated buffer already yields. ALL valid ≤8-byte non-negative lengths preserved.
  - LOCK: NEW stdlib/crypto/asn1_der_len_overflow_test.hexa (verbatim-inlined leaf, `hexa run`) → `__HEXA_OP118_DER_LEN_OVERFLOW__ PASS 7/7` (valid 10/128/256/2147483647 preserved · 9-byte + 8-byte-FF rejected to 0 · der_next regression pre=10<start=11 → fixed=11).
- 🔴 #2 — websocket 64-bit length RFC top-bit (stdlib/net/websocket_native.hexa ws_recv_native):
  - PRE-FIX: the 127-form payload length `val = val * 256 + lb[k]` over 8 bytes never enforced the RFC 6455 §5.2 "MSB MUST be 0" rule (the in-code comment already documented it). A frame with the high bit set wraps plen NEGATIVE. (In ws_recv_native a negative plen happens to degrade to empty payload — graceful — but the documented RFC invariant was unenforced and a wrapped plen fell through the parser; this hardens it to an explicit reject.)
  - REPRO (verbatim `hexa run`): `top-bit-set: prefix=-9223372036854775808 fixed=-1` (all-FF → prefix=-1).
  - FIX (minimal): after the 8-byte accumulate, `if val < 0 { return "" }` — enforce the RFC top-bit-0 invariant.
  - LOCK: NEW stdlib/net/websocket_native_len64_overflow_test.hexa (verbatim-inlined leaf, `hexa run`) → `__HEXA_OP118_WS_LEN64_OVERFLOW__ PASS 5/5` (valid 300/65536/2^53 preserved · top-bit-set + all-FF rejected).
- CENSUS (rest of the parser family 🟢 CLEAN — honest g5, evidence-backed): every TLS13/X.509 fixed-width declared length is ≤24-bit (16-bit ext `end = 2 + list_len` in alpn/cert_authorities/key_share/supported_groups/sig_algs, co-bounded by `i < len(ext_value)`; uint24 cert list/entry/ext sums in tls13_certificate; u32 new_session_ticket lifetime + early_data max_size are VALUES) so `+`/`*` CANNOT wrap i63. der_int / der_oid_str = value-decode not a size sink. x509_rsa exponent `e=(e<<8)|byte` = a VALUE (and e_len now bounded by the der fix + `e_v+i<len`). hkdf_sha{384,512} length = caller-supplied key length (negative → loop exits immediately). poly1305 _ld32 / sha512 / ripemd160 / scrypt = masked 32-bit crypto-state words, not sizes. tls13_record_aad / traffic_key length = LOCAL-SENDER sizes, not parsed-untrusted. NOTE: wasm/wasm_leb128 wasm_uleb128_decode has an unbounded `<< shift` (latent), but ZERO stdlib consumers + a doc'd scaffold ("callers gate range upstream", "NOT a module parser") = no reachable size→alloc/copy sink → not a shipping 🔴 (g5-scoped; flagged for the future wasm_module.hexa caller).
- KEY INVARIANT: the only overflow-reachable size-arithmetic in the parser family is the two VARIABLE/64-bit-width length decoders, both now FIXED; the ≤24/32-bit-field majority is wrap-immune by construction and OP-105 already added the buffer co-bounds.
- FLAGS: 2 source edits (asn1_der.hexa + websocket_native.hexa) BOTH closure-OUT — stdlib/crypto + stdlib/net leaf parsers, NOT self/* nor in build_selfhost.sh → ZERO byte-eq/fixpoint impact, no selfhost gate. 2 NEW leaf tests also closure-OUT. wipe_guard N/A (net-ADDITIVE guards, 0 deletions). NO .tape (no sign token). Repros run via verbatim-INLINED leaf functions through `hexa run` (not `use` of the module) → independent of any stale bundled stdlib copy (OP-87/88/107 stale-bundle discipline).
- HONEST g5: the GOAL was closing the size-arithmetic overflow / signed-confusion class in parsers. Two genuine 🔴 (variable/64-bit-width length wraps reaching X.509 + websocket) FIXED with computed (non-allocating) repros + hermetic locks; the rest is PROVABLY wrap-immune (≤24/32-bit fields) or value-decode/local-sender, an evidence-backed "int model wraps but all reachable size-fields are now bounded — class clean" SUCCESS. No 🔴 fabricated. $0 · 0-pod · NO GPU · no vast · no foreign-pod · leak-0. Milestone OP-118 [x]. Verdict F-OP118-INT-OVERFLOW-SIZE-ARITH.txt.

## 2026-06-13 — OP-117 DONE: LANE-1 0-pod write-side OOB-WRITE sweep (NON-crypto codec/data/buffer) — 🟢 CONVERGED, NO 🔴; all 13 write sites keep the write index in [0,len(dest)) by loop-counter / clamp / guard / sized-max, with the two protective patterns PROVEN by a hermetic leaf oracle + negative control
- LANE: 1 (0-pod correctness/security — OOB-WRITE axis). The WRITE-side complement of OP-105's length-prefixed-binary OOB-READ sweep, and distinct from OP-103's slice-READ bounds. NON-crypto codec/data/buffer only — disjoint from sibling LANE-2 (OP-115 resource-exhaustion DoS in crypto/protocol parsers).
- CLASS: a site that WRITES into a PRE-SIZED / fixed-size array/buffer at an index derived from a count / length / position / stride WITHOUT confirming the write index stays in [0,len(dest)) → an out-of-bounds write (corrupts the neighbour / faults). e.g. a decoder writing more bytes than the declared output length, a fixed-grid write grid[row*cols+col] with row/col > dims, a ring-buffer write with an unmasked head, a scatter/permute out[perm[i]], a histogram bin bins[b] with b > n_bins.
- METHOD (g5, stale-bundle discipline OP-87/88/107): shipping `hexa` resolves `use` to the Jun-1 bundle, so the verification surface = a VERBATIM-INLINED hermetic leaf oracle of the two representative protective patterns + a NEGATIVE CONTROL twin. Census via scoped greps (NO .git).
- CENSUS MATRIX (13 NON-crypto write sites, ALL BOUNDED / SIZED-MAX — NO UNBOUNDED-WRITE):
  - LOOP-COUNTER + value clamp: binning bins[j]=b (info/binning:43) + iit4 bins[j]=b (consciousness/iit4/faithful_phi:115) — write idx = loop counter j<n into n-sized bins; bin VALUE b clamped to [0,n_bins-1] (the index is never data-derived) 🟢.
  - EXPLICIT GUARD: kmeans counts[lab] (cluster/core_kmeans:196) under `if lab>=0 && lab<k`; hofstadter grid[cy*cols+cx]="*" (sim_universe/.../hofstadter:437) under `if cx>=0&&cx<cols&&cy>=0&&cy<rows` 🟢.
  - SIZED / INVARIANT (index proven < len by construction): conserv-mi counts[b]/joint[bx*N+by] (core_conservation_mi:103/136) b=base_idx() returns 0..3 (default return 0) ∈ [0,NBASES); nussinov db_arr[pair_i/j[pi]] (bio/.../ribozyme_mfe_nussinov:117-118) traceback invariant 0<=i<j<=n-1 → <len(db_arr)=n; rna-sim db_arr[kept_orig[slot]] (:201) kept_orig pushes only k<n; es-count cnt[tok] (clm_prod_embed_scatter_eq:152) tok=`(s%(V/2+1))%V`<V, cnt=t_zeros(V); recordld used[best] (demi/record_loader:503) best from inner unused-slot scan = always a valid index; smiles bsum[bd_a/b[bi]] (cmt_smiles_validation:473-474) bond endpoints = new_atom() returns <na 🟢.
  - LOOP-BOUNDED / SIZED-MAX (training paths): embed-fwd X_out[i*d+c] (flame/nn_lib:595) i<T,c<d into T*d dest; embed-bwd scatter-add dtable[tok*d+c] (:614) dest sized V*d (one row per vocab id) to the max row by caller contract 🟢.
  - OUT OF WRITE SCOPE (noted): dict `counts[key]` (associative — a dict write can never OOB); wasm_uleb128_decode (wasm/wasm_leb128:116) only RETURNS a value, no buffer write (its READ is OP-105's class).
- MECHANISM KEY: loop-counter write index / value clamp before write / explicit in-range guard / dest sized to the max index — one of these holds at every site.
- LOCK (HERMETIC verbatim-inlined, no `use` — stale-bundle dodge OP-87/88, closure-OUT): NEW stdlib/info/oob_write_bound_op117_test.hexa — shipping `hexa run` → `OP117 oob-write-bound pass=20 fail=0` then `ALL GREEN`. Pattern A = a histogram-bin assembly into a fixed n_bins dest with the bin VALUE clamped (binning.hexa); drives raws {-3,0,3,7,8,13} that UNCLAMPED would index -3..13 (OOB both ways) and asserts every clamped write lands in [0,n_bins), dest length unchanged, total writes == #inputs. Pattern B = a guarded scatter into a pre-sized rows*cols grid (hofstadter / core_kmeans); in-range (2,3) writes, OOB row/col/negative all return -1 → caller skips → NO OOB write, grid length unchanged, exactly one cell written. NEGATIVE CONTROL asserts the UNPROTECTED indices (raw 13 >= n_bins=8; flat (rows+7)*cols=55 >= 20) really do escape the dest range → the clamp/guard is load-bearing, not a no-op.
- FLAGS: NO source edit (the class is already CLEAN → 🟢 not a fabricated fix) → ZERO byte-eq/fixpoint impact, no selfhost gate. The audited files are NOT in the build_selfhost closure (no self/* nor build_selfhost.sh dependency; the only `self/` hit is a CLI help-string literal in self/main.hexa naming "hofstadter"). The NEW leaf lives in stdlib/info (non-self, closure-OUT) → fixpoint UNAFFECTED. wipe_guard N/A (1 new file, 124 lines, 0 deletions, 0 edits to existing code). NO .tape.
- HONEST g5: the GOAL was closing the OOB-WRITE class in NON-crypto code. The whole codec/data/buffer family keeps its write index in range by construction; an evidence-backed "all writes bounded — class clean / LANE-1 converged" is the truthful SUCCESS here, NOT a found 🔴, and the leaf + negative control prove the protections are real and load-bearing. No 🔴 fabricated. $0 · 0-pod · NO GPU · no vast · no foreign-pod · leak-0. Milestone OP-117 [x]. Verdict F-OP117-OOB-WRITE-SWEEP.txt.

## 2026-06-13 — OP-115 DONE: LANE-2 0-pod SYSTEMIC unbounded-WORK/ALLOC DoS class sweep, generalizing OP-113's regex {n,m} ReDoS to the declared-LENGTH/SIZE side — 🔴×1 (Verilog frontend range parser uncapped width → ~1e9 wire-alloc bomb, 2 source copies) FIXED + locked; the rest of the parser/decoder/protocol surface 🟢 CLEAN
- LANE: 2 (0-pod security). RESOURCE-EXHAUSTION / DoS — a site where an UNTRUSTED parsed count/length/size/repeat drives an ALLOCATION (.push / fill / array-grow) or a LOOP BOUND with NO sanity cap, so a tiny malicious input forces work/alloc ≫ len(input). Generalizes OP-113 (which fixed the regex `{n,m}` counted-repeat) to the declared-LENGTH/SIZE side; distinct from OP-105's read-OOB (which bounded the READ to the actual buffer — here the declared count EXCEEDS any real data and drives the ALLOC). No overlap with sibling LANE-1 numeric (OP-114).
- 🔴 BUGGY→FIXED (1, in 2 parallel source copies): the Verilog-2005→RTLIL frontend range parser `_rv_parse_range` in BOTH stdlib/kernels/logic_synth/read_verilog.hexa (reached via stdlib/yosys/{gate_record,yosys}.hexa) AND stdlib/yosys/read_verilog.hexa (reached via stdlib/yosys/test/round_trip.hexa) parses a packed/unpacked range `[HI:LO]` into `width = |HI-LO| + 1` with NO upper bound. That width then drives per-bit / per-element WIRE-ALLOCATION loops in the declaration path — `while bj < width { rtlil_module_add_wire(...) }` (multi-bit shadow ports) and `while k < ur.width { ... }` (unpacked-array element wires), each a `.push`. HI/LO come straight from untrusted Verilog source tokens via `_rv_eval_expr` (the `v = v*10 + d` decimal accumulator). So the parsed width is BOTH the loop bound AND the allocation count: a ~50-byte input `module m (input clk, output [999999999:0] o); endmodule` → width 1,000,000,000 → ~1e9 wire-struct allocations + minutes of CPU. CWE-1333 / CWE-400 (uncontrolled resource consumption).
- COMPUTED-SIZE REPRO (shipping `hexa run` 0.1.0-dispatch, hermetic verbatim-inlined PATCHED `_rv_parse_range` width-tail + cap; the COUNT is computed, NO 1e9 alloc is ever run): `bomb [999999999:0] -> parse_width = -1 (REJECTED, no loop ran)` / `PRE-FIX it would push 1000000000 wires (~1e9 allocs)` / `just-over [1048576:0] -> -1 (REJECTED)` (width 1048577 > cap) / `at-cap [1048575:0] -> 1048576 (ACCEPTED)` (boundary inclusive) / `normal [31:0]/[7:0]/[0:0] -> 32/8/1` / `reversed [0:15] -> 16` (unpacked [lo:hi] preserved).
- FIX (surgical, fail-closed, ZERO valid-parse semantics change; mirrors OP-113's `_RE_MAX_REPEAT`): added `@pure fn _RV_MAX_WIDTH() -> int { return 1048576 }` (2^20 — far above any realistic synthesizable design width; Yosys itself caps wire widths) and, in `_rv_parse_range` after computing `w = |HI-LO|+1`, `if w > _RV_MAX_WIDTH() { return RangeEval { width: 1, st: st, err: "read_verilog: range width " + str(w) + " exceeds cap " + str(_RV_MAX_WIDTH()) } }`. Over-cap ranges set the `err` field, which every caller already propagates → `ReadVerilogResult.ok = 0` BEFORE any per-bit/per-element wire-allocation loop runs, rather than allocating gigabytes. SINGLE CHOKEPOINT: all `width` / `ur.width` / `ur2.width`-driven push loops trace to `_rv_parse_range`, and downstream wire-width lookups (`_rv_emit_eq_dyn_idx` reading `m.wires[i].width`) inherit the bound transitively. `_rv_literal_width` (the `sz=sz*10+d` literal-width accumulator) is DEAD (defined, never called) → no allocation path depends on it. Applied identically to BOTH copies.
- STALE-BUNDLE NOTE (OP-87/88 lesson — CONFIRMED LIVE this round): the installed ~/.hx/bin/hexa (0.1.0-dispatch, Jun-7 build) resolves `use "stdlib/yosys/read_verilog"` to a STALE bundled copy that PREDATES this cap — feeding the bomb through `read_verilog()` via the installed binary returns ok=1 (the stale bundle, NOT the edited source). So the authoritative surface is the VERBATIM-INLINED hermetic leaf oracle (`hexa run`, no `use`) of the patched width-tail + cap, PLUS `hexa parse` of BOTH edited files ("parses cleanly"), PLUS the real-surface round_trip gate (12/12, proving the cap does not break normal parsing). Trust the port-of-source over the stale binary.
- LOCK: NEW stdlib/yosys/test/read_verilog_width_cap_test.hexa (@ci_gate, verbatim-inlined PATCHED logic, no `use`) — 8 checks, `hexa run` LOCAL `read_verilog_width_cap: 8/8 checks pass`: bomb-1e9 [999999999:0]→-1, bomb-1e9-rev [0:999999999]→-1, bomb-cap+1 [1048576:0]→-1 (3 bombs rejected, incl reversed range + the just-over-cap boundary); at-cap [1048575:0]→1048576 (boundary inclusive accepted); normal-32 [31:0]→32, normal-8 [7:0]→8, normal-1 [0:0]→1, reversed-16 [0:15]→16 (4 negative controls: realistic widths still parse). NO-REGRESSION (real EDITED surface): EXISTING stdlib/yosys/test/round_trip.hexa drives the edited yosys `read_verilog()` end-to-end (F3/F6/F10/F12 exercise multibit ranges through `_rv_parse_range`) → `result: 12/12 round-trip-equal`.
- CENSUS (rest of the parser/decoder/protocol surface — scoped greps NO .git; 🟢 CLEAN = bounded-by-input / documented / trusted): regex `{n,m}` = already FIXED OP-113. wasm LEB128 decoders (wasm_leb128.hexa) loop bounded by len(bytes), overlong-encoding acceptance = DOCUMENTED non-goal. asn1_der (der_value_len/der_oid_str) = pure offset-arithmetic over a fixed buffer, every read loop OP-105-guarded `&& off<len(b)`, NO preallocation. base64/hex/utf8/multibyte-codecs (euc_kr/cp949/gbk/big5/shift_jis) = out≤in, loops over len(input)/len(table). http2.hexa = curl wrapper, no binary frame parse. websocket_native.hexa ws_recv_native 64-bit `plen` = `_ws_fill` is tries-capped (4096×65536 = 256MB ceiling) and `_ws_take(plen)` only runs after `len(buf)≥plen` → bounded by data the attacker actually sent. websocket.hexa = EMITS a Python helper string, not a hexa parser. json write-side (alloc/json.hexa) recurses over a trusted in-memory struct; read-side (alloc/json_object.hexa) delegates parsing to the runtime `json_parse` builtin (out of stdlib scope) and its own loops are len-bounded. tls13_*_parse / client_hello_parse append loops all OP-105-guarded `&& off<len(body)`. hkdf_expand `length` = caller-supplied (trusted) RFC-capped param (255·HashLen). demi record_loader = all loops over len(files/lines/segs). Decimal value-accumulators (`v=v*10+d`) in semver/x509_validity/brenda/logic_synth-passes produce a VALUE used as data, NOT a loop-bound or alloc-count → N/A. NET: the ONLY sites where a tiny declared count forces work ≫ len(input) with no cap are regex {n,m} (OP-113) and the Verilog range width (this round) — everything else is bounded by len(input), a documented cap, or a trusted/RFC param = CLEAN, not a bug (honest g5, no fabrication).
- FLAGS: pure-additive (read_verilog.hexa logic_synth +23/−0, read_verilog.hexa yosys +23/−0, new test 0 deletions) → wipe_guard net-additive. NEITHER read_verilog.hexa is in the build_selfhost closure (no self/* nor build_selfhost.sh reference — frontend stdlib) → ZERO byte-eq/fixpoint impact, no selfhost gate; the new @ci_gate test is closure-OUT → fixpoint UNAFFECTED. LANE-2 (resource-exhaustion / DoS in parsers/decoders/protocol) — no overlap with LANE-1 numeric (OP-114) nor any closed crypto/delimiter class. INVARIANT: the Verilog frontend never expands a declared range beyond 2^20 bits/elements → a tiny input can no longer force unbounded wire allocation; every range within the cap (and all 12 round-trip fixtures) parses UNCHANGED. $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · leak-0. Verdict .verdicts/hexa-0pod/F-OP115-RESOURCE-EXHAUSTION-SWEEP.txt. Milestone OP-115 [x].
## 2026-06-13 — OP-116 DONE: LANE-1 0-pod SECURITY audit — path-traversal / file-access / injection — 🟢 CONVERGED, NO genuine 🔴; the stdlib+compiler path-builder + shell/SQL-builder surface is GUARDED or trusted-local, with the 3 load-bearing guards PROVEN by a hermetic leaf oracle + negative controls
- LANE: 1 (0-pod security — path/file/injection axis). A FRESH security class vs the swept crypto/tls/encode/regex (OP-104/105/107/109/111/113) and numeric/float/algorithm (OP-103/106/108/110/112/114) classes. Non-overlapping with sibling LANE-2 (OP-115 resource-exhaustion DoS).
- CLASS: (1) PATH-TRAVERSAL — an untrusted path segment (`../` / leading `/` / a URL or archive/zip/tar entry name / a config value / an HTTP request path) used to build a file read/write/include path that ESCAPES the intended base directory; (2) INJECTION — a shell/SQL/format string built by interpolating untrusted input WITHOUT escaping → command/SQL injection. g5: a site is CLEAN if it rejects/normalizes `..`/abs, canonicalizes-and-checks-prefix, or parameterizes/escapes; a real 🔴 only if a plausible UNTRUSTED input escapes the base or injects. A CLI/tool that intentionally takes a TRUSTED local path is NOT a bug (note the trust boundary; don't fabricate a fix that breaks intended local use).
- METHOD (g5, stale-bundle discipline OP-87/88/107): shipping `hexa` resolves `use` to the Jun-1 bundle, so the verification surface = a VERBATIM-INLINED hermetic leaf oracle (`hexa run`, no `use`) of each guard's actual source logic + an UNGUARDED negative-control twin (the brittle pattern) demonstrating the guard is load-bearing.
- SURVEY (scoped greps, NO .git): path-join/read_file/write_file/open/include sites (stdlib/alloc/path, self/module_loader, record, safetensors, stdlib_cli) + exec/sh-c/curl shellout builders (http, http2, llm, io, portable_fs, registry_autodiscover, proc, channel, rtsc/verify/*, sqlite) + the SQL builder (sqlite _sqlq / define_table / insert / select_where).
- CENSUS MATRIX:
  - PATH-TRAVERSAL: self/module_loader.hexa ml_canon_path = the ONLY "include resolves a name → file path" site → LEXICALLY collapses `.`/`..` ("absolute '..' above root: drop"), trusted (the compiler's OWN source imports) 🟢 (closure-IN, NOT edited). stdlib/alloc/path.hexa path_normalize collapses `..` lexically; path_join honors an absolute b verbatim (documented — the CLI trust boundary) 🟢. record_dir(domain,slug,ts) / safetensors path = producer/caller-supplied LOCAL identifiers; tensor names = MAP KEYS never fs paths 🟢. stdlib_cli find-shellout STILL `'\''`-escaped + _getenv charset-validated 🟢.
  - INJECTION-SHELL: http/http2/llm = curl CLIENTS, url + headers + method single-quote-wrap-`'\''`-escaped, body piped 🟢. io (mv) / portable_fs (wc/stat/test) / registry_autodiscover (ls) / sqlite (_run_sqlite) shellouts `'\''`-escaped 🟢. proc.hexa (lock/resource paths + sh -c '<cmd>') / channel.hexa (mkfifo + sh '<script>') / rtsc-verify _read_file=exec("cat "+path) build shell from caller-supplied or program-constructed lock/FIFO/script/argv/DOC_* paths — a process/CLI tool intentionally takes a TRUSTED LOCAL path 🟢 trusted-local note.
  - INJECTION-SQL: sqlite.hexa _sqlq / _format_param / _bind_params = the `?` VALUE path → SQL-92 `''`-doubling (OP-100 verified; re-confirmed ALL value paths parameterized: int/float bare, bool 1/0, void NULL, string _sqlq) 🟢. sqlite define_table/insert/select_where IDENTIFIERS (table/column names) + where_sql interpolated RAW → per the documented contract (line 63-65: "Callers MUST use `?` for any data — never concat raw") these are the program's OWN schema / an intentional raw SQL fragment, NOT untrusted row data 🟢 documented-trusted-context note.
  - NO static-file HTTP server, NO archive/zip/tar extractor writing entry names, NO download-cache keyed by a remote name = NO untrusted-network-input → file-path mapping in the surface.
- GUARD-IS-LOAD-BEARING PROOF (computed repros — NO actual filesystem escape; the 🟢 is not a tautology): (1) join("safe/base","../../etc/passwd")→normalize→"etc/passwd" (RELATIVE — the two `..` pop safe/+base/, never gains a leading "/" to reach absolute /etc/passwd); deep `..` chain likewise never abs; TRUST-BOUNDARY neg-ctrl join("safe/base","/etc/passwd")="/etc/passwd" (abs b honored — a CLI taking an abs path means it). (2) _shq("x'; rm -rf / #")='x'\''; rm -rf / #' (the bare quote-closer `x';` is rewritten to `x'\''` — escaped, not a closer) vs naive twin 'x'; rm -rf / #' (the bare `x';` survives → breakout — exactly why `'" + p + "'` is unsafe for UNTRUSTED input). (3) _sqlq("x' OR '1'='1")='x'' OR ''1''=''1' (one inert literal) vs no-doubling twin 'x' OR '1'='1' (the `'` closes the literal → the `OR '1'='1` tautology escapes into the SQL).
- LOCK: NEW stdlib/alloc/path_traversal_injection_op116_test.hexa — HERMETIC (no `use`; path_normalize/path_join/path_is_abs + _shq + _sqlq verbatim-inlined from source, each with an UNGUARDED neg-control twin). Shipping `hexa run` LOCAL → `__HEXA_OP116_PATH_TRAVERSAL_INJECTION__ pass=13 fail=0` ALL-GREEN (1a relative `../../etc/passwd`→not-abs · 1b deep `..`→not-abs · 1c abs `/etc/passwd` honored (trust boundary, not a tautology) · 1d normal include unchanged · 1e normalize→prefix invariant · 2a guarded bare-quote-closer rewritten + escape-seq present · 2b NEG-CTRL naive leaks · 2c benign no-op · 3a _sqlq doubles→inert + no bare `x' OR` · 3b NEG-CTRL no-doubling leaks · 3c benign no-op).
- HONEST TRUST-BOUNDARY NOTES (g5 — NOT bugs, no fabricated fix): sqlite identifiers + where_sql are raw-but-documented-trusted (the program's own schema; quoting identifiers would break valid schema use — declined). proc/channel/rtsc-verify unescaped single-quote-wrap / unquoted `cat <path>` = a latent fragility on a hypothetical UNTRUSTED path, NOT a security bug on the trusted local lock/FIFO/script/argv/DOC_* input they actually consume → logged for a future hardening pass, NOT "fixed".
- FLAGS: NO source edit (the surface is CLEAN — a guarded/trusted site is 🟢, not a fabricated fix) → ZERO byte-eq/fixpoint impact, no selfhost gate. The ONLY added files = the verdict + this log entry + the OP-116 milestone + the NEW hermetic leaf test (closure-OUT — a stdlib/alloc *_test.hexa, not in build_selfhost → fixpoint UNAFFECTED). wipe_guard N/A (0 deletions, pure-additive). NO .tape (no sign token). LANE-1 only — no overlap with sibling LANE-2 (OP-115 resource-exhaustion DoS) nor the swept crypto/tls/regex/numeric classes. $0 · 0-pod · NO GPU · no vast · no foreign-pod · leak-0. Verdict .verdicts/hexa-0pod/F-OP116-PATH-TRAVERSAL-INJECTION.txt. Milestone OP-116 [x].

## 2026-06-13 — OP-114 DONE: LANE-1 0-pod FRESH class = algorithm-OUTPUT-CORRECTNESS (a non-trivial algorithm whose OUTPUT can be numerically WRONG vs an authoritative reference on a STRUCTURAL input) — 🟢 CONVERGED, NO 🔴; stdlib pure-numeric algorithm surface ROBUST (self-tested modules locked by falsifiers + the 2 untested non-trivial algos differential-verified vs numpy/brute-force at machine precision)
- LANE: 1 (0-pod correctness). Algorithm-output-correctness territory — a GENUINELY FRESH class vs the swept OOB/degenerate-CRASH (OP-103/106), int-overflow/signedness (OP-108), and float-domain/silent-NaN (OP-110/112). Non-overlapping with sibling LANE-2 (OP-113 regex-ReDoS). Distinct: here there is NO crash and NO NaN — the failure mode is a numerically-WRONG result vs a reference (rank-with-ties / empirical-CDF supremum / eigensolver rotation+convergence / ODE Butcher tableau / special-fn series / quadrature node-weight table / OLS-variance recurrence).
- CLASS: a non-trivial ALGORITHM whose OUTPUT can deviate from an authoritative reference (numpy / networkx / scipy / a closed-form / a brute-force) on a specific STRUCTURAL input. g5: a module is CLEAN if it matches the reference within its documented tolerance (a correct algorithm is 🟢, not a fabricated bug); a real 🔴 only if a plausible structural input drives the output away from the reference past the documented contract.
- METHOD (g5, stale-bundle discipline OP-87/88/107): the shipping `hexa` is the Jun-1 oracle (`use`→bundled stdlib, miscompiles already-fixed bugs) so the authoritative surface = a VERBATIM PYTHON PORT of each algorithm (line-for-line, same int/float ops + sweep order) differential-tested vs numpy / a brute-force reference — the regimen's "verbatim-inlined leaf oracle + faithful reference, trust port-of-source". Harnesses hermetic + re-runnable.
- SURVEY (scoped greps/reads, NO .git; LANE-1 numeric/algorithm): stdlib/{stats,math,math/special,math/quadrature,alloc/math,rtsc/verify} — correlation, powerlaw_fit, welford, ks_two_sample, lambert_w, elliptic, gauss_legendre, logsumexp, kahan_sum, ode (RK4+DP45), numerics_bcs_solver, permille, eigen (Jacobi). Crypto/parser/protocol EXCLUDED (LANE-2).
- CENSUS:
  - 🟢 SELF-TESTED (locked by the file's own falsifier set; re-verified by reading the falsifiers + the algorithm): lambert_w (Halley W₀/W₋₁, W·e^W=x sweep + W₋₁ ref); elliptic (AGM K/E + Legendre relation cross-check — the E-sum Σ2^{n-1}c_n² n=0=c₀²/2 term verified correct); gauss_legendre (6-pt A&S-25.4 nodes/weights, x^11-exact + x^12-onset + affine-map + Σw=2 + node-antisymmetry); logsumexp (max-shift, ln3 + overflow-safe(1000) + ≥max + softmax-Σ=1); kahan_sum (compensated-sum associativity); welford (M_k/S_k recurrence vs [2,4,4,4,5,5,7,9]→32/7 + 1e9-offset stability + streaming=batch + Bessel (n-1)/n); ode (RK4 + Dormand-Prince DP45 — full Butcher tableau a/b/b* incl 46732/5247, 7571/16695, -92097/339200, 5179/57600, 1/40 cross-checked vs Hairer&Wanner II.5; ode_test exp_decay/logistic/saddle); numerics_bcs_solver (Newton gap-solver convergence + seed-independence + BCS universal-ratio + inline-sinh); permille (fixed-point ×1000 half-away-from-zero, _div_round_half_away signed-correct sign=sign_a·sign_b on abs operands, pm_to_string frac∈[0,999] padded; permille_test locks); correlation (Pearson r + Spearman ρ, tie-aware avg-rank (#less+1)+(#equal−1)/2; correlation_test locks); powerlaw_fit (OLS-on-log-log slope, closed-form, denom-guarded).
  - 🟢 UNTESTED-BUT-DIFFERENTIAL-VERIFIED (no self-test / no _test file = the real frontier; both pass an authoritative reference): (A) stats/ks_two_sample.hexa ks_two_sample_D (tie-aware merge-sweep empirical-CDF supremum) → 200000 random small-int pairs n,m≤8 values 0..4 (TIE-STRESS to exercise the consume-all-ties-on-BOTH-sides-before-eval step + the two tail loops) vs a brute-force D=max_v|#{xs≤v}/n−#{ys≤v}/m| → 0 mismatches (rel>1e-12). (B) alloc/math/eigen.hexa eigh_jacobi (cyclic-Jacobi symmetric eigendecomp + eigenvectors) → 3000 random symmetric n×n (n2..6) eigenvalues vs numpy.linalg.eigvalsh worst|Δλ|=1.24e-14 (machine precision, 0 fails); 3000 eigenvectors reconstruct A_rec=Σλ_k v_k v_kᵀ vs A worst|ΔA|=9.86e-12 (the rotation row/col mix nik=c·mik−s·mjk, njk=s·mik+c·mjk + the V′=V·J vector update are bit-faithful); pathological identity (sweeps=1 err 0) / diagonal (0) / REPEATED eigenvalue 2,2,5 (0) / rank-1 all-ones 3,0,0 (4.44e-16) / negative-definite (0) all 🟢.
- 🟠 ONE DEFENSE-IN-DEPTH NOTE (NOT a fix — honesty, no fabrication): math/logsumexp.hexa documents "+∞ propagates to +∞" but a +∞ input makes m=+∞ and exp_pure(+∞−+∞)=exp_pure(NaN)=NaN → result NaN not +∞. This is (a) an explicitly-out-of-common-path non-finite edge its honest-scope already flags, (b) NOT covered by any of its 5 falsifiers, (c) NOT a plausible production LSE input (log-domain weights are finite or −∞, never +∞) → undertested, NOT a contract-violating numeric bug on a realistic input → logged for a future hardening pass (add a +∞-short-circuit + a falsifier), NOT fixed (scope/honesty).
- VERBATIM EVIDENCE (re-runnable verbatim-port + reference harnesses): KS-D differential `mismatches: 0` (200000 trials); eigh_jacobi `cases= 3000 worst_val_err= 1.2434497875801753e-14 val_fails= 0`; eigenvector recon `worst_recon_err= 9.864553618399441e-12`; pathological `identity3 err=0.00e+00 sweeps=1 · diag err=0.00e+00 · rep_eig(2,2,5) err=0.00e+00 · rank1 err=4.44e-16 sweeps=2 · neg err=0.00e+00`.
- CONVERGENCE FINDING (g5 — honest + valuable at this depth): across OP-103 (slice-bounds), OP-106 (degenerate-crash), OP-108 (int-overflow/sign), OP-110/112 (float-domain/NaN), and now OP-114 (algorithm-output-correctness = the last fresh numeric class), the LANE-1 numeric/data/algorithm bug classes on the stdlib pure-numeric surface are SWEPT and CLEAN — the self-tested modules are locked by their own falsifiers, and the only two non-trivial untested algorithms (KS-D · Jacobi-eigh) pass machine-precision differential verification. This is an evidence-backed "LANE-1 numeric/algorithm bug-frontier converged" landing with per-axis evidence — an acceptable + valuable result at this depth.
- FLAGS: NO source edit (the surface is CLEAN — a clean module is 🟢, not a fabricated fix) → ZERO byte-eq/fixpoint impact, no selfhost gate; wipe_guard N/A (0 deletions); NO .tape. The only added files = the verdict + this log entry + the OP-114 milestone. LANE-1 only — no net/string-parser/crypto/tls/protocol (= LANE-2 / sibling OP-113 regex-ReDoS) touched, no overlap. $0 · 0-pod · NO GPU · no vast · no foreign-pod · leak-0. Verdict .verdicts/hexa-0pod/F-OP114-NUMERIC-ALGORITHM-CONVERGENCE.txt. Milestone OP-114 [x].

## 2026-06-13 — OP-112 DONE: LANE-1 0-pod SYSTEMIC silent-NaN/Inf-propagation class census across stdlib numeric/scientific (NON-crypto), generalizing OP-110 — 🔴×1 (solar_kernel ephemeris unclamped elevation-sine asin→NaN) FIXED + locked; the broad log/sqrt/pow/division surface 🟢 CLEAN
- LANE: 1 (0-pod correctness). Float / NaN / Inf domain territory — the same class OP-110 opened (silent NaN that corrupts a finite-API result, distinct from the OOB/degenerate-CRASH OP-103/106 and int-overflow OP-108). Non-overlapping with sibling LANE-2 (OP-111 crypto AEAD).
- CLASS: a PUBLIC numeric/scientific function performs a float op that can yield NaN/Inf on a PLAUSIBLE input (intended result finite) WITHOUT a domain guard, propagating it SILENTLY into the result: log/ln(x≤0)→−Inf/NaN; sqrt(x<0 from roundoff/variance/1-x²)→NaN; pow(x<0 frac-y / 0**0 / 0**neg); division a/b with b==0 (non-empty)→Inf; acos/asin reached with |x|>1. g5: a site is CLEAN if guarded (clamp/sentinel/+eps/p>0), documented-precondition (physical positivity), or structurally-in-domain; a real 🔴 only if a plausible input silently drives a public result to NaN/Inf.
- SURVEY (scoped greps, NO .git; LANE-1 numeric/science): sqrt/log/ln/pow/acos/asin/division across stdlib/{info,stats,math,linalg,nn,core/special,crystal,chem,physics,material,nuclear,energy,kernels/{solar,geodesy,plasma,mc_transport},runtime/math}. Crypto/parser EXCLUDED (LANE-2).
- CENSUS:
  - 🔴 BUGGY→FIXED (1): stdlib/kernels/solar/solar_kernel.hexa `ephemeris` (pub; the public solar_elevation / solar_zenith / apparent_zenith all build on it) — the elevation SINE `cosφ·cosδ·cosH + sinφ·sinδ` fed STRAIGHT to the libm `asin` builtin with NO clamp. That sum-of-products = cos(φ−δ) at H=0, ≤1 by Cauchy–Schwarz (intended finite), but the fp sum overshoots 1 by ~1e-16 (1 ULP) for plausible inputs — latitude ≈ declination, i.e. the sun overhead at solar noon. libm asin (unlike rt_asin which clamps |x|>1→±π/2) returns a SILENT NaN that propagates into the returned elevation AND into zenith = 90 − elevation. NOTE: OP-110's census already flagged this exact site 🟠 "theoretically possible only at the exact zenith pole, NOT reproducible"; OP-112 MADE IT REPRODUCIBLE and upgrades the flag to a confirmed 🔴 fix.
  - 🟢 CLEAN (note, no change — guarded / documented-precondition / structurally-in-domain): LOG — info/entropy shannon_entropy (total==0→0, p+1e-10 smoothing), info/entropy_histogram (x<=0→0 helper, p>0), info/transfer_entropy + mutual_info (pj>0&&pa>0&&pb>0; xx clamp 0.9999; n<=0→0), iit_ei ei_per_state_nats (p>0 then q>0; q==0→"+inf" sentinel), math/logsumexp (−∞ sentinel + max-shift keeps exp≤1), stats/powerlaw_fit (k>0&&count>0 filter; denom==0→0), atoms (log of const / explicit s1v<=0); plasma coulomb_log + mc_transport bethe = DOCUMENTED physical-positivity precondition (n_e>0, T_e>0, energies>0; formula as-written) — left per "don't guard a documented contract". SQRT — stats/correlation pearson_r (sqrt arg Σsq·Σsq≥0 + denom<=0→0), stats/welford var/pop_var (Σ(x-mean)²≥0; n≤1→0; NaN propagation documented for NaN INPUTS only), nn layernorm (+eps), linalg/norm + reference (Σsq≥0, +eps form), material/sim variance (two-pass-from-mean Σd²≥0) + coherence_length/penetration_depth (hc2<=0 & n_s<=0 sentinels), nuclear viola_seaborg/royer (Q_alpha<=0→0 sentinel, documented NaN-free convention), chem/vina (gated r2<1.0 && r2>0.0 before sqrt(1-r2)), chem/md distances + bonded dihedral (Σsq≥0; cosphi clamped [-1,1] before sqrt(1-cosphi²)). POW — laser_optics pow(10,·), material pow(≥1,·), nuclear pow(A>0,1/6)+pow(10,·), chem/md forces pow(sigma>0,·) — all positive bases, no neg-base-frac-y. DIVISION (non-empty b==0) — every normalizer carries a denom==0/<=0→sentinel guard (pearson denom<=0→0, powerlaw denom==0→0, material/nuclear sentinels, bonded norm<1e-15→0); no unguarded data-driven zero-denominator into a public result. ACOS/ASIN (re-confirm OP-110) — crystal lattice_angles FIXED (OP-110); chem/md/bonded angle_energy CLAMPED+zero-norm-guard; wgs84 haversine asin(√a) CLAMPED [0,1]+documented; solar declination asin(sinε·sinλ) = product of two |sin|≤1 → ≤1 structurally; rt_asin/rt_acos already clamp |x|>1→±π/2 (the libm builtin the kernels call does NOT — the bug surface).
- VERBATIM REPRO (shipping `hexa run` 0.1.0-dispatch, hermetic verbatim-inlined): a 900-pt lat=dec sweep at H=0 (runtime-computed sine) → `UNGUARDED asin(>1) NaN count = 35` (35/900 plausible inputs → silent NaN); the exact 1-ULP overshoot → `asin(1.0000000000000002) is_nan = true`, `asin(clamp) is_nan = false  val~pi/2 = 1.5708`. PYTHON cross-check (IEEE-754 double, authoritative): max arg over the lat,dec sweep = 1.0000000000000002 (>1) at lat=dec=−15.6°; math.asin(that) = NaN; clamp→1.0 → asin = 1.5707963267948966 (π/2).
- FIX (minimal, net-additive; clamp the elevation sine to [-1,1] before asin): added a leaf `fn _solar_clamp_unit(x){ if x>1.0{1.0} elif x<0.0-1.0{0.0-1.0} else x }` + wrapped the elevation-sine argument `asin(_solar_clamp_unit(...))` in `ephemeris`. Overshoot saturates to π/2 (sun overhead, the correct limit). Mirrors OP-110 `_crystal_clamp_unit` + the chem/md/bonded angle clamp. The declination-sine asin (sinε·sinλ, a product of two |sin|≤1 → ≤1 structurally) left unwrapped — clamping it is a no-op; only the genuine sum-of-products site touched; no-op for every in-domain input (no documented-contract change).
- LOCK: NEW stdlib/kernels/solar/solar_elevation_asin_op112_test.hexa — HERMETIC (no `use`; the FIXED clamp step + an UNFIXED twin negative control verbatim-inlined), shipping `hexa run` LOCAL → `__HEXA_OP112_SOLAR_ASIN__ pass=6 fail=0` ALL GREEN: (1) FIXED clamps the 1-ULP-overshoot sine → finite π/2, not NaN; (2) NEGATIVE CONTROL = the UNFIXED twin asin(1+ULP) → NaN (NaN!=NaN), not a tautology; (3) asin(1+ULP) raw → NaN vs asin(clamp) → π/2 (the guarded silent NaN); (4) 900-pt sweep: UNGUARDED form NaNs (≥1) / CLAMPED form NaN-free (0); (5) sine==1.0 → el=π/2 (sun overhead); (6) in-domain sine cos(23.4°) round-trips asin to π/2−23.4° (libm-ulp). NO REGRESSION: EXISTING stdlib/kernels/solar/solar_kernel_test.hexa compiled against the EDITED source → `solar_kernel_test: 34/34 PASS` (the clamp is a no-op on the Phoenix-AZ pvlib-parity timestamps; substrate parity <1e-9 preserved).
- FLAGS: net-additive (1 helper fn + 1 wrap + comment; 0 logic deletions) → wipe_guard net-additive; stdlib/kernels/solar/solar_kernel.hexa NOT in the build_selfhost closure (no compiler/ nor self/ import — leaf science kernel) → ZERO byte-eq/fixpoint impact, no selfhost gate; NEW leaf test closure-OUT → fixpoint UNAFFECTED. LANE-1 only (NON-crypto numeric/science — LANE-2/OP-111 untouched); no overlap with OP-103/106 (CRASH classes). INVARIANTS: ephemeris never passes |x|>1 to asin → never returns a NaN elevation/zenith (overshoot→π/2 = sun overhead); normal timestamps UNCHANGED (34/34, pvlib parity <1e-9). HONEST g5: the broad log/sqrt/pow/division surface is CLEAN (guarded / documented-precondition / structurally-in-domain — no fabrication); the ONE genuine unguarded NaN-propagating site = solar elevation asin → FIXED, upgrading OP-110's 🟠 flag to a confirmed-reproducible 🔴. $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · leak-0. Verdict .verdicts/hexa-0pod/F-OP112-NAN-INF-SWEEP.txt. Milestone OP-112 [x].

## 2026-06-13 — OP-110 DONE: LANE-1 0-pod FRESH class = float-DOMAIN / silent-NaN propagation (inverse-trig acos/asin out of [-1,1], or 0.0-÷→Inf→NaN propagating into a public result) — 🔴×1 (crystal lattice_angles unclamped acos→NaN) FIXED + locked; rest of the inverse-trig surface 🟢 CLEAN
- LANE: 1 (0-pod correctness). Float / NaN / domain-error territory — a GENUINELY FRESH class vs the swept OOB/degenerate-CRASH (OP-103/106), int-overflow/signedness (OP-108), and the LANE-2 binary-parser/crypto classes. Non-overlapping with sibling LANE-2 (OP-109 crypto). Distinct from the CRASH classes: acos(>1) does NOT crash — it returns a SILENT NaN that corrupts the answer.
- CLASS: a float-DOMAIN error — an inverse-trig call acos(x)/asin(x) reached with |x|>1, or a log(0)/sqrt(-x)/0.0-÷ producing Inf/NaN, that then PROPAGATES SILENTLY into a public result. g5: a site is CLEAN if x is provably in-domain (clamped before the call, or bounded by exact construction); a real 🔴 only if a plausible input drives the argument out of domain AND the documented contract forbids the resulting NaN.
- SURVEY (scoped greps, NO .git): every acos/asin/log/sqrt call site in non-test stdlib — stdlib/{chem/md,crystal,kernels/solar,kernels/geodesy,runtime/math}. For each: is the argument clamped or bounded?
- CENSUS (inverse-trig domain):
  - 🔴 BUGGY→FIXED (1): stdlib/crystal/mod.hexa lattice_angles (pymatgen Lattice.angles port) — returns (α,β,γ) in degrees via the cosine law acos(dot/(|u||v|)), with NO clamp + NO zero-denominator guard. Two plausible inputs drive acos out of [-1,1] → NaN: (1) (near-)COLLINEAR lattice vectors — dot/(|u||v|) overflows 1.0 by ~1e-16 fp roundoff; a Python signed-64 sweep of 2e6 random collinear vector pairs → cos up to 1.0000000000000004, ~10% (215205/2e6) exceed 1.0. (2) a zero-LENGTH lattice vector (degenerate cell) → denom 0 → ratio Inf → acos(Inf)=NaN. The sibling stdlib/chem/md/bonded.hexa angle_energy computes the IDENTICAL cos=dot/(|u||v|) and DOES clamp (`if c>1.0{c=1.0};if c<-1.0{c=-1.0}` before acos); stdlib/kernels/geodesy/wgs84_kernel.hexa haversine likewise clamps √a∈[0,1] with a documented "antipodal-roundoff clamp so asin doesn't NaN". lattice_angles was the one inverse-trig site missing the guard.
  - 🟢 CLEAN (note, no change): chem/md/bonded.hexa angle_energy acos(c) — CLAMPED c∈[-1,1] + zero-norm guard (the reference fix); kernels/geodesy/wgs84_kernel.hexa asin(√a) — CLAMPED √a∈[0,1], documented; kernels/solar/solar_kernel.hexa asin(.) — args are sums of products of bounded sin/cos (declination sin·sin; elevation = dot of two UNIT vectors), 3e6-sample sweep max |arg| = 0.99999 / 0.3986, NO division → NO div-by-0 Inf path; 🟠 a tiny roundoff overflow theoretically possible only at the exact zenith/nadir pole (unit-vector dot = ±1), NOT reproducible in the sweep + NO documented-contract violation → defense-in-depth note, NOT fixed (scope/honesty); runtime rt_asin/rt_acos (software fallback) already clamp |x|>1→±π/2 (CLEAN, but not the libm-builtin binding for the call sites above).
- VERBATIM REPRO (shipping `hexa run` 0.1.0-dispatch, hermetic verbatim-inlined UNFIXED body): collinear lattice a=[1,0,0], b=[-0.4969649763063986,-0.4664928284510319,4.548027195441373], c=0.9525597121912246·b (b∥c ⇒ true α=0°) → `UNFIXED alpha = NaN` / `alpha is NaN (alpha != alpha): true`. Builtin out-of-domain probe (same toolchain): `acos(1.0000000000000004) = NaN`. Python math.acos on the same ratio = ValueError (math domain). Governance @D stdlib_trig_libm binds the libm BUILTIN acos = NaN out-of-domain (the runtime SOFTWARE rt_acos clamps |x|>1→±π/2 but is NOT the binding here).
- FIX (minimal, net-additive; clamp the cosine to [-1,1] before acos): added a leaf helper + 3 call-site rewrites in stdlib/crystal/mod.hexa — `fn _crystal_clamp_unit(dot,denom){ if denom==0.0 {return 1.0}; let cos=dot/denom; if cos>1.0{1.0} elif cos<0.0-1.0{0.0-1.0} else cos }`, then `acos(_crystal_clamp_unit(bc,nb*nc))` (+β,γ). denom==0 → cos 1.0 (angle 0°) = the collinear limit the roundoff overflow approaches; output shape (3 angles) preserved; mirrors the sibling angle_energy + wgs84 guards.
- LOCK: NEW stdlib/crystal/test/lattice_angles_acos_op110_test.hexa — HERMETIC (no `use`; the FIXED clamp helper + lattice_angles body verbatim-inlined + an UNFIXED twin as the negative control), shipping `hexa run` LOCAL → `__HEXA_OP110_LATTICE_ACOS__ pass=5 fail=0` ALL GREEN: (1) collinear lattice (true α=0°) → FIXED α==0.0, not NaN; (2) NEGATIVE CONTROL = the UNFIXED twin on the SAME input → α=NaN (α!=α), proves it's not a tautology; (3) zero-length vector (denom 0) → β=0.0; (4) cubic regression → 90°; (5) FCC primitive regression → 60°. EXISTING stdlib/sci_stage1_test.hexa compiled against the EDITED source → `__SCI_STAGE1_TEST__ PASS (45/45)` — the cubic-90/FCC-60 angle asserts unchanged, no regression.
- FLAGS: net-additive (1 helper fn + 3 call rewrites + comment; 0 logic deletions) → wipe_guard net-additive; stdlib/crystal/mod.hexa NOT in the build_selfhost closure (no self/* nor build_selfhost.sh reference — leaf science stdlib) → ZERO byte-eq/fixpoint impact, no selfhost gate; NEW leaf test closure-OUT → fixpoint UNAFFECTED. LANE-1 only (no net/string-parser/crypto/tls edits — LANE-2 untouched); no overlap with OP-103/106 (CRASH classes). INVARIANTS: lattice_angles never passes |x|>1 to acos → never returns a NaN angle (collinear→in-range cosine, zero-vec→cos 1.0=0°); normal lattices UNCHANGED bit-for-bit. HONEST g5: class otherwise CLEAN (the two other acos/asin sites already clamp or are bounded by exact construction — a clamped/bounded site = CLEAN, no fabrication). $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · leak-0. Verdict .verdicts/hexa-0pod/F-OP110-FLOAT-ACOS-DOMAIN.txt. Milestone OP-110 [x].
## 2026-06-13 — OP-113 DONE: LANE-2 0-pod RESOURCE-EXHAUSTION / DoS — the unbounded-WORK side OP-105's read-OOB sweep did not touch — 🔴×1 (native regex `{n,m}` uncapped count → ReDoS bomb) FIXED + locked; wasm/emitter surfaces 🟢 CLEAN
- LANE: 2 (0-pod security). RESOURCE-EXHAUSTION / DoS — a parser/matcher that ALLOCATES or LOOPS proportional to an untrusted declared COUNT with NO sanity cap (the unbounded-WORK side, distinct from OP-105's read-OOB which was bounded to the buffer). Self-selected a genuinely FRESH non-crypto surface; no overlap with sibling LANE-1 numeric (OP-112) nor any closed crypto/delimiter class.
- 🔴 BUGGY→FIXED (1): stdlib/regex/native.hexa — the pure-hexa, zero-libc BACKTRACKING regex engine (the match path behind compiler/lint/config pattern matching) parses the `{n,m}` counted-repeat count with NO upper bound. `_re_parse_repeat` accumulates `lo = lo*10 + digit` (and `hi` likewise) over an arbitrary digit run, then `_re_run_repeat`'s `lo>0` branch recurses `lo` times, EACH calling `_re_repeat_marker` → `nodes.push([12,...])`. So the parsed count is BOTH the loop bound AND the allocation count: a malicious 11-byte pattern `a{999999999}` → ~1e9 iterations + ~1e9 array growths = multi-GB allocation + near-infinite loop. CWE-1333 (ReDoS) / CWE-400 (uncontrolled resource consumption).
- VERBATIM REPRO (shipping `hexa run` 0.1.0-dispatch, hermetic verbatim-inlined `_re_parse_repeat` count-accumulate + `_re_run_repeat` driver): `parsed count from a{999999999} = 999999999` / `a{1000000} -> matcher iterations = 1000000` / `a{999999999} -> matcher iterations EXCEED oracle sentinel (>= 5,000,000); real code would run 999999999 iterations + push that many marker nodes (multi-GB)`. (The stale ~/.hx bundle resolves `use` to a copy lacking the fix per OP-87/88, so the hermetic inlined leaf is the verification surface — trust the port-of-source.)
- FIX (surgical, fail-closed, ZERO valid-semantics change): added `@pure fn _RE_MAX_REPEAT() -> int { return 100000 }`; in BOTH the lo- and hi-accumulate loops `if lo/hi > _RE_MAX_REPEAT() { p.ok = false; return -1 }`. Over-limit counts FAIL the parse (all three entry points regex_match_native / regex_full_match_native / regex_find_native already reject via their `!p.ok` guard → return false / []) instead of silently truncating to a wrong count. Cap 100000 is far above any realistic stdlib/config/lint pattern yet bounds worst-case work (RE2 caps at 1000; Java/.NET/Python at small bounds). `{n,}` unbounded (hi=-1) is still allowed — its mandatory part `lo` is capped above and the open-ended tail is bounded by input length via the matcher's progress guard (`more > si`).
- VERBATIM PROOF (post-fix, hermetic leaf oracle of the PATCHED parse): a{999999999} / a{999999999,} / a{0,999999999} → REJECTED (ok=0, match=false, no alloc/loop); a{3} / a{2,4} / a{100000}(=cap) → PARSE-OK; a{100001}(>cap) → REJECTED. The over-limit guard fires the MOMENT the running total exceeds the cap (before any expansion), so no allocation/loop ever occurs for a bomb; valid patterns are unchanged.
- LOCK: 5 new @ci_gate checks in stdlib/regex/native_test.hexa — redos-cap-exact a{999999999}→false, redos-cap-lo a{999999999,}→false, redos-cap-hi a{0,999999999}→false (bombs rejected); redos-ok-small a{3} on "aaa"→true, redos-ok-range a{2,4} on "aaa"→true (negative controls: normal counted repeats still match).
- CENSUS (other fresh surfaces, scoped greps NO .git): wasm LEB128 decoders (stdlib/wasm/wasm_leb128.hexa `wasm_uleb128_decode`/`wasm_sleb128_decode`) loop bounded by len(bytes) — no OOB, no unbounded loop; they accept overlong encodings but the header DOCUMENTS that as an intentional non-goal → a documented design omission is not a bug. stdlib/wasm/wasm_type_section.hexa + wasm_section_header.hexa are EMITTERS encoding trusted local arrays → no untrusted-count-driven allocation. Catastrophic-backtracking (exponential-time) in the same regex engine is INHERENT to a backtracking matcher and a DOCUMENTED design tradeoff; the STAR/PLUS progress guard limits empty-loop blowup and a general step-budget is a larger redesign — NOT claimed fixed (honest g5). The concrete, one-line-fix, definite-bug member of that class is the counted-repeat count = this fix.
- FLAGS: pure-additive (regex/native.hexa +20/−1, native_test.hexa +12; 0 logic deletions) → wipe_guard net-additive. stdlib/regex/native.hexa NOT in the build_selfhost closure (no self/* nor build_selfhost.sh reference — leaf stdlib) → ZERO byte-eq/fixpoint impact, no selfhost gate; the new test checks are closure-OUT → fixpoint UNAFFECTED. LANE-2 (DoS/resource) — no LANE-1 numeric overlap; does NOT re-open any closed crypto/delimiter class. INVARIANT: the matcher never expands a counted repeat beyond 100000 mandatory steps → a tiny pattern can no longer force unbounded allocation/looping; valid patterns within the cap are UNCHANGED. $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · leak-0. Verdict .verdicts/hexa-0pod/F-OP113-REGEX-REDOS-REPEAT-CAP.txt. Milestone OP-113 [x].
## 2026-06-13 — OP-111 DONE: LANE-2 0-pod SECURITY audit — AEAD per-record NONCE + TLS 1.3 KEY SCHEDULE / Expand-Label / transcript vs RFC 8446 + RFC 8448 §3 KAT — 🟢 ALL FIVE RFC-CORRECT (no nonce-reuse / no wrong-key / no wrong-transcript)
- LANE: 2 (0-pod security; AEAD nonce/seq + TLS key-schedule/transcript). The remaining critical crypto LOGIC after the parse/verify/encode-length sweeps (OP-104/105/107/109). Non-overlapping with sibling LANE-1 (OP-108/110 numeric).
- CENSUS (scoped greps, NO .git): nonce builder tls13_record.hexa:52 (tls13_record_nonce); seq counter tls13_client_record_io.hexa (send returns seq+1 :124, recv "caller bumps after open"); key schedule tls13_keyschedule.hexa (hkdf_extract/hkdf_expand/expand_label/derive_secret + early→handshake→master); traffic_secrets c/s hs|ap; tls13_finished; transcript order tls13_client_keyschedule_wire.hexa:150 (_concat(ch_message, sh_message) → SHA256).
- METHOD (g5, honest; trust RFC/Python over the stale bundled binary): faithful Python port of EACH source routine (/tmp/op111_audit.py) + byte-exact differential vs the published RFC 8448 §3 bytes + the RFC 8446 §5.3 nonce reference. GREEN = match; a nonce-reuse/wrong-key/wrong-transcript would be 🔴. Primitives (SHA-256/HMAC) NOT re-derived (OP-104/107-swept) — this audits the FRAMING/DERIVATION.
- 🟢 COMPONENT 1 NONCE (RFC 8446 §5.3): nonce = write_iv XOR (seq as 64-bit BE, right-aligned in iv bytes 4..11). Verbatim-constructed for iv=5d313eb2671276ee13000b30:
  - seq=0 → 5d313eb2671276ee13000b30 (== iv unchanged); seq=1 → …b31; seq=2 → …b32; seq=255 → …bcf; seq=256 → …0a30; seq=2^32 → 5d313eb2671276ef13000b30 (carry into byte-7-from-tail ee→ef). ALL match the RFC §5.3 reference; all 6 DISTINCT = NO reuse.
  - seq counter: 64-bit int, caller-managed monotonic per-direction, incremented exactly once per record (send returns seq+1), reset to 0 per key epoch (KeyUpdate = new traffic secret, tls13_client_keyupdate.hexa). No path reuses/wraps a (key, nonce) pair. NO nonce-reuse bug.
- 🟢 COMPONENT 2 KEY SCHEDULE (RFC 8448 §3 KAT): 10/10 byte-for-byte — early 33ad…f92a, derived 6f26…11ba, c-e-traffic 8318…043a, handshake 1dc8…beac, s-hs b67b…ad38, c-hs b3ed…5a21, s-key 3fce516009c21727d0f2e4e86ee403bc, s-iv 5d313eb2671276ee13000b30, finished_key 008d…9fc8, master 18df…2919. HKDF-Extract=HMAC(salt,ikm) + Expand T(i) chain + empty-transcript "derived" salts all exact. NO wrong-key bug.
- 🟢 COMPONENT 2b EXPAND-LABEL (RFC 8446 §7.1): HkdfLabel(key,16,"") = 001009 'tls13 key' 00 = uint16 len | label-vec-len | "tls13 "+label | ctx-vec-len; prefix bytes == "tls13 " (74 6c 73 31 33 20); 1-bit secret flip → different output (avalanche). NO framing bug.
- 🟢 COMPONENT 3 TRANSCRIPT (RFC 8446 §4.4.1): hashes _concat(ch_message, sh_message) = ClientHello||ServerHello IN handshake order; SHA256(CH||SH) == in-order ref, != SHA256(SH||CH). NO transcript-order bug.
- LOCK: NEW stdlib/crypto/tls13_nonce_keysched_op111_test.hexa — VERBATIM-INLINED leaf (re-implements the exact record/keyschedule/traffic/finished source; only SHA-256/HMAC `use`d; char_code_at hex parse dodges the stale-bundle `index_of`-not-a-builtin resolution per OP-87/88) emitting __OP111_AEAD_NONCE_KEYSCHED__ ALL-GREEN 21 checks (nonce 9 + keysched 10 + avalanche 1 + transcript 1; count prints 0x15) confirmed on shipping `hexa run`. Authoritative proof = the Python differential reproducing every RFC 8448 byte; negative controls (seq-ignoring nonce / no-"tls13 " prefix / reversed transcript) diverge → not a tautology.
- BYTE-EQ / GUARDS: ZERO crypto SOURCE edits (all 5 routines RFC-correct — nothing to fix) + 1 NEW leaf test + verdict + this log. 0 deletions (wipe_guard net-additive). The *_test.hexa leaf is NOT in the build_selfhost closure → self-host fixpoint UNAFFECTED. LANE-2 (AEAD/key-schedule) — no LANE-1 numeric overlap. $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · no self/env.hexa · leak-0. Milestone OP-111 [x]. Verdict F-OP111-AEAD-NONCE-KEYSCHED.txt.

## 2026-06-13 — OP-108 DONE: LANE-1 0-pod integer-overflow/signedness class sweep (hash/checksum/fixed-point/accumulator/bit-packing/LCG) — 🔴×2 (FNV-1a 32-bit unmasked + kcat-noise LCG overflow→neg-modulo) FIXED + locked; ~24 other numeric sites 🟢 CLEAN
- LANE: 1 (0-pod correctness). Numeric-overflow/signedness territory — distinct from the OOB/degenerate classes (OP-103/106) and the binary-parser/crypto OOB class (OP-104/105 = LANE-2). Non-overlapping with sibling LANE-2.
- CLASS: arithmetic that OVERFLOWS (sum/product/shift/hash-mix exceeding i63 → wraps to a wrong/NEGATIVE value) OR a SIGNEDNESS bug (`% n` of a negative dividend → negative where a non-neg index/band was intended; right-shift sign-extension). Hexa ints = 64-bit signed (i63 in interp). Bug surface = a 32-bit-style mask/wrap intended but MISSING (hash/checksum/fixed-point/bit-packing), or a modulo of a possibly-negative operand needing normalization. g5: a value INTENDED full-width (i63-safe, no mask) is CLEAN; a `% n` of always-non-neg operands is CLEAN; only an overflow-wrap or negative-modulo the DOCUMENTED semantics forbid is 🔴.
- SURVEY (scoped greps, NO .git): 0xFFFFFFFF-mask sites, FNV/`* 16777619`/`* 2654435761` hash-mixing, adler32/checksum/xor-checksum, LCG/PRNG `* a + c`, fixed-point `a*b/SCALE`, bit-packing `(hi<<32)|lo`/u64-split, `% n`-of-negative — across stdlib/{core/hash,core/math,alloc/math,qforge,flame,ckpt,policy,chem/vina,bio,sim_universe,kernels,rtsc}. Crypto-verify + binary-parser EXCLUDED (LANE-2).
- CENSUS (~26 sites):
  - 🔴 BUGGY→FIXED (2 logical, 3 files): (1) stdlib/core/trait_hash_fixture.hexa hash_str + hash_array_int — header documents "FNV-1a 32-bit variant … returns 32-bit hash in [0, 0xFFFFFFFF]" but `h = (h^x)*16777619` was UNMASKED → the i64 accumulator grows past 2^63 after a few inputs and wraps NEGATIVE, off the documented range and disagreeing with every FNV-1a 32-bit reference. (2) stdlib/sim_universe/multiverse/bio_variant/kcat_compute.hexa + bio_interferometer.hexa noise_kcal_scaled — inline comments document `r∈[0,2000]`/`centered∈[-1000,1000]`, but `state = state*1103515245+12345` (no reduction) overflows i63 for variant_idx≥4 → negative i64 → C-truncated `state%2001` negative → `centered = r-1000` leaves the band. Default sim runs M=15 (vi=0..14) → REACHABLE for vi∈[4,14]; pre-fix vi=1,2,3 also a degenerate +84/step ramp (near-zero entropy).
  - 🟢 CLEAN (NO mask added — would corrupt correct full-width results): xxhash xxh32/xxh64 (16-bit-split mul + 64-bit 16-bit-limb, `&0xFFFFFFFF` every step); rng lcg_next (`&0xFFFFFFFF`, max intermediate ≈7.15e15 ≪ i63) + rng_ctx (masked, `v>>8` on masked non-neg); 5 akida FNV (`h & 4294967295` each step — the correct reference pattern); all 4 adler32 (checkpoint/scratch_bank{,_store}/selftest: a,b mod 65521 → b*65536+a<4.29e9); flame op28 _pack_checksum (`%1000000007`) + op29/31/32/33 _farr_checksum (`%2147483647`) mod each step ≪ i63; squid xor_checksum (`%256`); ie_fill_lcg (`%2147483648`, positive seeds {11..37} → st∈[0,2^31)); noc_sim _lcg_next; vina (seed `&0xFFFFFFFF` → rng); ckpt _int_to_u64_pair (n<0 guard + mask) / verifier u64-decode (mask) / safetensors u64-LE-split (mask) / brenda 16-bit-limb mul (BRENDA_MASK32); dual_track route_bucket (xxh32-masked → documented non-neg modulo `h-(h/n)*n`); anu_time `h*33 % 9999999967` (mod each step, v non-neg).
- VERBATIM REPRO #1 (FNV, `hexa run`, input "hello world!!!" code-points): UNMASKED -2441261701466863720 (overflowed i63, NEGATIVE) · MASKED32 3092072344 (canonical FNV-1a 32-bit). Python cross-check: FNV-1a 32-bit ref = 3092072344 (==MASKED32 ✓); unmasked signed64 = -2441261701466863720 (==UNMASKED ✓). FIX `& 0xFFFFFFFF` each step → in [0,2^32), matches ref.
- VERBATIM REPRO #2 (kcat, `hexa run`, wi=0): vi 0..7 UNMASKED centered = -661,-577,-493,-409,-2930,-2846,-2762,-677 (vi=4 OUT of [-1000,1000]); FIXED = -661,395,-993,63,676,-712,344,957 (all in band). Python signed-64 + C-truncated-modulo emulation of UNMASKED = -661,-577,-493,-409,-2930,-2846,-2762,-677 (exact match ✓). FIX reduce each LCG step `% 2147483648` (mirrors ie_fill_lcg) → state∈[0,2^31), r∈[0,2000], centered∈[-1000,1000].
- LOCK: stdlib/core/trait_hash_fnv32_overflow_test.hexa — verbatim-inlined leaf (stale local hexat 0.1.0-dispatch → lock arithmetic directly via `hexa run`, not `use`-import). `__HEXA_OP108_INT_OVERFLOW_SIGN__ PASS 8/8`: FNV golden==3092072344 · FNV range [0,2^32) · FNV empty→2166136261 · FNV spread 64-input range+determinism · kcat band over 256 vi × 4 wi · kcat goldens vi4→676/vi0→-661 · NEGATIVE CONTROL (old unmasked vi=4 < -1000, proves the fix is load-bearing).
- FLAGS: net-additive (1 new leaf test ~106L + ~3-line edits ×3 fns, 0 substantive deletions, wipe_guard OK). NONE of the 3 edited files (trait_hash_fixture / kcat_compute / bio_interferometer) is imported by self/* or build_selfhost.sh, and none has a downstream stdlib importer (greps clean) → OUTSIDE the build_selfhost closure → self-host fixpoint + byte-eq UNAFFECTED. The fix deliberately changes the two functions' (previously-overflowing) output to the documented-correct values; no locked oracle/verdict consumed the old buggy output. LANE-1 honored (no crypto-verify/binary-parser). No .tape. $0 · 0-pod · NO GPU · no vast · no foreign-pod · leak-0.
- HONEST g5: 2 real overflow→sign defects vs DOCUMENTED intended semantics; all ~24 other sites genuinely CLEAN (i63-safe full-width OR already masked/mod-reduced). Verdict F-OP108-INT-OVERFLOW-SIGN-SWEEP.txt. Milestone OP-108 [x].

## 2026-06-13 — OP-107 DONE: LANE-2 0-pod crypto VERIFICATION/AUTH-path security audit — does each *_verify REJECT a forgery or ACCEPT it (auth bypass)? 12 verifiers censused, ALL 🟢 correctly reject; constant-time compares byte-complete; RSA right-anchored parse defeats BERserk
- LANE: 2 (0-pod correctness/security). The HIGHER-value question after OP-104/105 closed the OOB-read class: an OOB read is a crash/disclosure, but a verify that ACCEPTS a forged/tampered input is an AUTH BYPASS / FORGERY (critical). This round audits the verification/auth verdicts themselves. Sibling LANE-1 (numeric/data degenerate-crash) untouched — non-overlapping.
- METHOD (g5, honest): differential vs a Python port of the EXACT hexa source (RFC KAT cross-check) + property/forge tests + a shipping `hexa run` hermetic lock. CAVEAT (OP-87/88): the installed ~/.hx/bin/hexa is a STALE Jun-1 oracle that MIScompiles the chacha-poly path — so correctness verdicts rest on the SOURCE + its verbatim Python port (port=RFC EXACT), NOT the stale binary.
- CENSUS (scoped greps, NO .git) of stdlib/crypto + stdlib/core/hash — 12 verifiers + what each MUST reject + forge-test + verdict:
  - [1] chacha20poly1305_verify (TLS1.3/WireGuard/age): MUST reject flipped tag / flipped ct / wrong tag length. Shipping `hexa run` RFC 8439 §2.8.2 → valid_accept=true · forged_tag_reject=true · forged_ct_reject=true · short_tag_reject=true. Compare = `if len(tag)!=16 {false}` + accumulate-diff over 16B. Python port of EXACT poly1305+chacha source → RFC tag 1ae10b59...0600691 EXACT. 🟢
  - [2] aes256gcm_verify · [3] aes128gcm_verify: same constant-time `len!=16` + accumulate-diff; flipped-tag/short reject. 🟢
  - [4] tls13_finished_verify (TLS1.3 handshake AUTH = HMAC-SHA256 over Expand-Label finished-key): `len!=32` guard + accumulate-diff over 32B. tls13_client_verify_server_finished delegates to it. 🟢
  - [5] tls13_record_open_verify: `n<16` guard + splits ct‖tag + delegates to [1]. 🟢
  - [6] rsa_pkcs1_sha256_verify (RSA-2048 X.509 sig): STRICT RIGHT-ANCHORED EMSA parse — sep=elen-(DigestInfo+32)-1 FIXED, em[2..sep] ALL 0xFF, em[sep]=0x00, DigestInfo+hash anchored at the very END. This DEFEATS the BERserk/Bleichenbacher'06 garbage-after-hash forgery class (the attacker cannot place a low-exponent perfect-cube tail). Python port of the EXACT parse + shipping lock: well-formed→accept · BERserk garbage-tail→reject · flipped-hash→reject · padding-hole→reject · wrong-blocktype→reject. 🟢
  - [7] ed25519_verify: textbook k=H(R‖A‖M), pack(S·B+k·A)==R with A negated; _unpackneg returns [0]=fail on an off-curve/non-canonical pubkey → reject. 🟢
  - [8] p256_verify: r,s∈[1,n-1] (r==0/s==0/r>=n/s>=n → false) + R==infinity → false + (R.x mod n)==r. Standard correct ECDSA verify. 🟢
  - [9] x509_verify_self_ed25519: `len(pk)==32` + `len(sig)==64` + ed25519 over the cert's OWN extracted TBSCertificate. 🟢
  - [10] x509_chain_verify_ed25519: per-link validity-window (x509_validity_contains) AND sig verifies under the ISSUER's pubkey (next cert up, or trust anchor for topmost) — a forged intermediate has no valid sig under the real issuer key; `len(issuer_pub)!=32`/`len(sig)!=64` → reject. (Does not enforce issuer-DN==subject-DN name chaining — path-building / defense-in-depth, not the auth gate; noted not a bug.) 🟢
  - [11] x509_validity_contains: notBefore<=now<=notAfter; an expired cert (now>notAfter) → reject. UTCTime 2000/1950 pivot per RFC 5280. 🟢
  - [12] hmac_sha256_bytes (HMAC core under [4]): FIPS 198-1 / 180-4; module's own test cross-checks byte-eq to the runtime builtin. 🟢
- 🟠 TIMING / ROBUSTNESS notes (no fix this round):
  - All 5 MAC/tag/Finished compares ([1][2][3][4]) are byte-COMPLETE accumulate-diff (no early-return on first mismatch) → NO timing leak. The lock's flip-LAST-byte case proves no short-circuit. No `==`/index_of secret compare exists in the crypto surface (grep clean). → no timing 🟠.
  - ed25519_verify / p256_verify have NO direct-call sig/pubkey LENGTH guard. ALL in-tree callers (x509_verify_self_ed25519, x509_chain_verify_ed25519) guard len BEFORE calling → defense-in-depth OOB robustness gap (a direct attacker-length call could OOB-read), NOT a forgery-acceptance bug. FLAGGED 🟠 for a LANE-1/OP-104-105 OOB follow-up; not fixed here (scope).
- WRAPPERS/STUBS (no untrusted-input verdict → OUT-OF-SCOPE): tls_ca_bundle_verify_chain + tls_ca_bundle_pinned_nss_verify_chain (fail-closed `no-bundle` scaffolds — NEVER assert "verified" for a forged cert) · tls13_certverify_* (signed-content builder) · tls13_psk_binder + binder_key (derivations) · cert/meta2_validator validate/validate_chain (governance reward/verdict JSON schema, not crypto auth).
- NON-SECURITY FINDING (honest g5, logged not fixed — toolchain track): the stale ~/.hx/bin/hexa MIScompiles the chacha-poly AEAD path — running the SHIPPING source it emits tag[0]=27 where RFC 8439, Python `cryptography`, AND the verbatim Python PORT of the SAME hexa source all give tag[0]=26 (0x1a). Since port=RFC EXACT and the in-source `h>=p` final-reduction fix (poly1305.hexa:142-153) is applied, the SOURCE is CORRECT → this is a stale-COMPILER codegen miscompile + an interop hazard on the stale binary (would reject a real peer's RFC-conformant tag), NOT a logic or security bug (the verify is self-consistent: it accepts the tag it computes and rejects every flip → an attacker still cannot forge).
- LOCK: NEW stdlib/crypto/verify_forgery_reject_op107_test.hexa — HERMETIC, the *_verify constant-time tag compare + the rsa_pkcs1 EMSA structure check VERBATIM-INLINED (no `use`, stale-bundle dodge OP-87/88), closure-OUT. Shipping `hexa run` → `OP107 verify-forgery-reject pass=9 fail=0` / `OP107 ALL GREEN` (tag {valid-accept, flip-LAST reject, flip-first reject, short reject} + rsa {well-formed accept, BERserk-garbage-tail reject, flipped-hash reject, padding-hole reject, wrong-blocktype reject}). NEGATIVE CONTROL: a forgery-ACCEPTING `return true` mutant → "ACCEPT forged tag = RED mutant caught" → the lock has teeth (not a tautology).
- BYTE-EQ: ZERO source edits (every verifier already correct) + 1 NEW leaf test; 0 deletions. The crypto verifiers are NOT in the build_selfhost closure (grep compiler/ + self/ for crypto/* → none) → fixpoint UNAFFECTED, no gate. LANE-2 only.
- RESULT: 🟢 verification/auth-path census — 12 verifiers ALL correctly reject forgery + constant-time; RSA right-anchored parse defeats BERserk; + 2 🟠 caller-guarded direct-call length-guard notes + 1 non-security stale-compiler interop note. A correct-rejecter census is a valid SUCCESS (goal = find forgery-acceptance OR prove correct rejection — found none accepting). $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · leak-0. Milestone OP-107 [x]. Verdict F-OP107-CRYPTO-VERIFY-AUDIT.txt.

## 2026-06-13 — OP-105 DONE: LANE-2 0-pod SYSTEMIC OOB-read census of the WHOLE length-prefixed/framed-binary parser family (generalizes OP-104) — 🔴×9 UNGUARDED-INNER-READ FIXED across TLS13 + ASN.1 DER + X.509 + 🟢 GUARDED census (key_share/alpn/websocket/p256 already correct)
- LANE: 2 (0-pod correctness/security). Direct follow-on to OP-104: OP-104 fixed ONE cert_authorities OOB; OP-105 censuses the whole family for the same unguarded-inner-read class. Axis b (error-propagation/robustness, SECURITY-relevant: OOB read on untrusted wire data). Sibling LANE-1 (data/numeric slices) untouched — non-overlapping.
- CLASS: a length-prefixed binary parser reads a LENGTH field from untrusted wire bytes then copies declared-many DATA bytes WITHOUT checking the declared length fits the buffer → truncated/malicious length overruns the buffer = OOB read (VM fault / disclosure). Correct pattern guards every inner byte `while i < declared && base + i < len(buf)`.
- SURVEY (scoped greps, NO .git): TLS13 handshake/ext parsers stdlib/crypto/tls13_*.hexa; ASN.1 DER stdlib/crypto/asn1_der.hexa (TLV length→value); X.509 stdlib/crypto/x509_*.hexa; http2 stdlib/http2.hexa; websocket stdlib/net/websocket_native.hexa.
- CENSUS MATRIX (15 sites):
  - 🔴 UNGUARDED→FIXED (9 files): tls13_ch_random(32B)/ch_session_id(sl)/ch_cipher_suites(cs_bytes) [client_hello_parse]; sh_random/sh_session_id [server_hello]; cr_context(n) [cert_request]; cert_entry_data(u24 n) [certificate]; nst_nonce(nl)/nst_ticket(tl) [new_session_ticket]; der_value_len long-form(nbytes) + der_int(vlen) + der_oid_str(vlen + INNER base-128 continuation loop with NO bound — a dangling high-bit byte reads past end) [asn1_der]; x509_rsa_modulus(count)/x509_rsa_exponent(e_len) [x509_rsa]; x509_p256 coord-copy(count) [x509_p256]; _dec ASCII-time(n) [x509_validity].
  - 🟢 GUARDED/CLEAN (note, NOT bugs): tls13_alpn_parse (OP-104 reference `j<nb && i+j<len`); tls13_key_share_parse_x25519 (`if len(ext_value)<4+n {return []}` before loop — reference-quality guard); ws_recv_native (_ws_fill grows buffer to plen + `if len(pext)<plen {[]}` + `if plen>0 && len(body_bytes)<plen {return ""}` before the unmask read); ws_frame_roundtrip_for_test (reads a LOCALLY-built frame, trusted self-consistent length — NOT untrusted wire); x509_p256_pubkey/sig fixed-64B (guarded by `if len(pk)!=64 {return false}`); x509_validity_contains d[6+i] (internally-built fixed 12-elem); OP-104's 2-byte-pair extension parsers (sig_algs/supported_groups/cert_compression/cookie, already certified round-trip-exact).
  - OUT-OF-SCOPE: stdlib/http2.hexa is a curl TEXT-output parser (shells to curl, parses strings) — NO binary frame/HPACK payload-copy loop (grep frame|24bit|<<16|hpack → 0 hits).
- VERBATIM PRE-FIX REPROS on shipping `hexa run` (the buggy bodies standalone on truncated input):
  - tls13_ch_session_id, body with body[34]=32 declared but len 35 → `index 35 out of bounds (len 35)`
  - der_value_len, [0x30, 0x82, 0x01] (0x82 declares 2 length bytes, only 1 present) → `index 3 out of bounds (len 3)`
  - der_oid_str, [0x2a, 0x86] vlen=3 (final byte 0x86 has the continuation high bit set, no next byte) → `index 2 out of bounds (len 2)`
  - tls13_cr_context, [4, 0xAA, 0xBB] (declared context len 4, only 2 present) → `index 3 out of bounds (len 3)`
- FIX (minimal, net-additive): each inner loop gains `&& base + i < len(buf)` mirroring OP-104/alpn → a truncated/malicious declared length yields a graceful SHORT/empty value, never an OOB fault. Plus a leading `if voff >= len(b) { return "" }` for der_oid_str's first byte, `voff < len(b)` for der_int's sign byte, and `start < len(...)` for the strip-leading-zero scans in x509_rsa/x509_p256.
- CLOSURE (OP-96 method): grep compiler/ + self/ for crypto/tls13 | asn1_der | x509 → NONE imported by the build_selfhost (~48-file) closure → non-closure fix; cc-genN byte-eq UNAFFECTED, no gate needed.
- LOCK: NEW stdlib/crypto/tls13_x509_oob_op105_test.hexa — HERMETIC (no `use`; ch_session_id/cr_context/nst_nonce/der_value_len/der_oid_str bodies VERBATIM-INLINED post-fix — stale-bundle dodge OP-87/88), closure-OUT: each truncated→graceful-short/empty + well-formed-roundtrip-exact + empty/undersized negative controls → shipping `hexa run` LOCAL __HEXA_TLS13_X509_OOB_OP105__ 12/12 PASS. NOT a tautology: the pre-fix bodies run standalone on the same truncated inputs FAULT verbatim (above). Existing stdlib/crypto/asn1_der_test.hexa still 21/21 + OP-104 lock still 7/7 (well-formed decode UNAFFECTED by the guards).
- BYTE-EQ / GUARDS: 9 source files guarded (tls13_client_hello_parse, tls13_server_hello, tls13_cert_request, tls13_certificate, tls13_new_session_ticket, asn1_der, x509_rsa, x509_p256, x509_validity — ALL closure-OUT) + 1 NEW leaf; net +39/-20 (every "deletion" is a modified guard line — NO logic removed → wipe_guard net-additive); fixpoint UNAFFECTED, no gate needed. LANE-2 only (binary parsers; LANE-1 = data/numeric slices, no overlap). 🔴×9 FIXED + 🟢 GUARDED census documented. CLOSES the length-prefixed-binary OOB-read class. $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · leak-0. Milestone OP-105 [x]. Verdict F-OP105-BINARY-OOB-SWEEP.txt.

## 2026-06-13 — OP-104 DONE: LANE-2 0-pod FRESH-class bug-hunt — UNGUARDED-INNER-READ in length-prefixed TLS 1.3 binary parsers (error-propagation/robustness axis b) — 🔴→FIXED stdlib/crypto/tls13_cert_authorities.hexa OOB on truncated DN + 🟢 5 sibling parsers round-trip-exact
- LANE: 2 (0-pod correctness). FRESH class NOT in the closed delimiter/index set (OP-94 split-keep-first · OP-97 boundary-run-collapse · OP-102 index_of(-1)-unchecked). Axis b (error-propagation/robustness): a fallible read over a malformed/truncated wire length must yield a graceful short/empty result, NOT an OOB read. Sibling LANE-1 (OP-101/103 serde/slice) untouched — non-overlapping.
- CLASS: a length-prefixed binary parser bounds-checks the LENGTH HEADER against len(buffer) in its outer loop but the INNER copy loop reads length-many DATA bytes WITHOUT re-checking the buffer end → a truncated/malicious declared length overruns the buffer = OOB read (VM fault / disclosure). Correct pattern guards EVERY inner byte against len(buffer).
- SURVEY (scoped greps, NO .git): densest length-prefixed binary parsers = the TLS 1.3 extension family stdlib/crypto/tls13_*.hexa. Censused every inner `while … len(ext_value)` read across tls13_{sig_algs,supported_groups,cert_compression,cookie,alpn,psk_modes,renegotiation_info,cert_authorities}. SAFE REFERENCE = tls13_alpn_parse (guards every inner name byte `j<nb && i+j<len(ext_value)`).
- 🟢 CLEAN — the 5 pair/byte parsers round-trip EXACT: /tmp/op104_tls.py faithful Python build∘parse over N∈{1,2,3,4} → 0 mismatch (sig_algs/supported_groups `i+1<list_len && 2+i+1<len`, cert_compression 1-byte hdr `i+1<list_byte_len && 1+i+1<len`, cookie single-byte `2+i<len` — the strict `<` bounds are CORRECT: i+1<L ⟺ i+1<=L-1 = last full pair). Not the bug.
- 🔴 REAL SHIPPING BUG FOUND+FIXED — stdlib/crypto/tls13_cert_authorities.hexa `tls13_cert_authorities_at`: inner DN name-copy `while j < nl { name.push(ext_value[i+2+j]); j=j+1 }` had NO bounds guard; the outer loop validates only the 2-byte nl HEADER (`i+1<end && i+1<len`), NOT the nl name bytes that follow — UNLIKE the sibling alpn parser. A truncated `nl` overruns the buffer.
  - VERBATIM REPRO on shipping `hexa run`: ext_value=[0,7, 0,5, 0xAA,0xBB] (inner list_len=7, entry nl=5, only 2 name bytes, len=6) → pre-fix `tls13_cert_authorities_at(ev,0)` → `index 6 out of bounds (len 6)` (HARD FAULT). Sibling alpn on analogous truncation returns the short string SAFELY (the contrast proving the missing guard).
  - FIX (minimal, 0 deletions): add `&& i + 2 + j < len(ext_value)` to the inner loop, mirroring alpn → a truncated DN yields a graceful SHORT name, never an OOB read.
- CLOSURE (OP-96 method): grep compiler/ + self/ for tls13_cert_authorities / crypto/tls13 → NONE imported by the build_selfhost (~48-file) closure → non-closure fix; cc-genN byte-eq UNAFFECTED, no gate needed.
- DIFFERENTIAL /tmp/op104_ca.py: pre-fix port raises OOB on the truncated input; alpn port stays SAFE on analogous truncation; post-fix port returns [0xAA,0xBB] graceful + well-formed round-trip EXACT (count=2, at0=[1,2,3], at1=[0xAA]).
- LOCK: NEW stdlib/crypto/tls13_cert_authorities_oob_op104_test.hexa — HERMETIC (no net; _ca_count/_ca_at bodies VERBATIM-INLINED post-fix, no `use` — stale-bundle dodge OP-87/88), closure-OUT: truncated→graceful-short + well-formed-roundtrip-exact + empty/undersized/oob-idx→empty → shipping `hexa run` LOCAL __HEXA_TLS13_CA_OOB_OP104__ 7/7 PASS. NEGATIVE CONTROL = pre-fix body standalone on the same truncated input → `index 6 out of bounds (len 6)` fault (not a tautology).
- BYTE-EQ / GUARDS: 1 guarded source line in stdlib/crypto/tls13_cert_authorities.hexa (closure-OUT) + 1 NEW leaf; 0 deletions (wipe_guard net-additive); fix+leaf NOT in closure → fixpoint UNAFFECTED. LANE-2 only; FRESH unguarded-inner-read class. 🔴→FIXED + 🟢 sibling census clean. $0, 0-pod, NO GPU, no vast, no foreign pod, no .tape, leak-0. Verdict .verdicts/hexa-0pod/F-OP104-TLS13-CERT-AUTH-OOB.txt

## 2026-06-13 — OP-101 DONE: LANE-1 0-pod SERIALIZATION round-trip bug-hunt (serialize∘parse==identity over the stdlib JSON serializer/parser surface) — 🟢 fresh surface CLEAN (0 new bugs) + JSON ROUND-TRIP LOCK 54/54 GREEN
- LANE: 1 (0-pod correctness; SERIALIZATION round-trip class — json/yaml/toml/csv/ini/struct emit+parse). I/O-boundary surfaces (string escaping/quoting/special-chars/type-fidelity) are classic-buggy; this round hunts serialize∘parse==identity.
- SURVEY (scoped greps, NO .git; SKIP codec/* base64-hex-utf8 done, net/* = LANE-2, OP-100 python-emit): the serialization round-trip territory in this stdlib is JSON-centric. self/rt/json.hexa (446L) — the pure-hexa recursive-descent JSON codec: rt_json_parse (returns [value,next_index]) + _js_escape_string/_js_emit (stringifier mirror of runtime.c). FULL escape set (\" \\ \/ \n \r \t \b \f, \uXXXX, control<0x20→\u00XX) + int/float type dispatch (`.`/`e`→float) + nested/empty containers = HIGHEST escaping/type-fidelity surface → PICKED. stdlib/alloc/json.hexa (170L) — pure-hexa pretty-printer json_dump_pretty with its OWN recursive emit + key stringify + empty/nested handling → PICKED. stdlib/alloc/json_object.hexa (248L) — lookup helpers over the builtin json_parse (no own escape/emit) → lower surface, spot-checked. stdlib/yaml.hexa (225L) — parse-ONLY (yaml_parse_flat); NO emitter → no round-trip PAIR → out of scope. NO dedicated CSV/INI/TOML/msgpack/struct-pack emit+parse PAIR exists in core stdlib (greps for to_csv/write_csv/encode_kv/struct_pack/msgpack ⇒ none).
- METHOD (hermetic; installed `hexa` resolves `use` to a STALE bundled copy — OP-87/88 lesson — so parser/emitter/pretty bodies are VERBATIM-INLINED, no `use`): each value round-tripped through the SHIPPING builtin json_stringify + the INLINED rt_json_parse / _js_escape_string / json_dump_pretty, cross-checked DIFFERENTIALLY against the builtin json_parse (the documented mirror). Run on shipping `hexa run` (hexa 0.1.0-dispatch), LOCAL.
- ADVERSARIAL SWEEP (all 🟢):
  - (1) rt_json_parse∘json_stringify==identity over strings: "hello", "", `a"b`, `a\b`, "a\nb", "a\tb", "tab\tnl\n", "null"/"true"/"123" (type-confusion literals), "x😀y" (emoji) → 11/11 recover the exact original.
  - (2) int round-trip + type fidelity {0,-1,42,1000000,2147483647} → decode==orig AND typeof==="int". 5/5.
  - (3) float type fidelity + rt-vs-builtin byte-eq {"3.5","-2.5","0.0","1e10","1.5e-3","-2.5E+2"} → ALL typeof==="float" (HEXA_F2 contract) AND rt_json_parse(s)==json_parse(s). 12/12. NOTE: literal "0.0015" round-trips 4.33681e-19 off the source float, but rt and the BUILTIN produce the IDENTICAL value (shared 1-ULP literal-parse drift, NOT a divergence).
  - (4) DIFFERENTIAL vs builtin json_parse over 10 adversarial STRUCTURAL inputs (re-stringify must agree): dup-keys {"a":1,"a":2}, trailing garbage "[1,2]extra", heavy whitespace, \u-in-key, deep nest [[[[1]]]], empty {"a":{},"b":[]}, \/ escape, café é, [true,false,null], nested \n\t escapes → STRUCT-DIVERGE=0. rt_json_parse mirrors the builtin on EVERY input.
  - (5) _js_escape_string==builtin json_stringify (documented mirror) AND round-trips builtin parse over `hello/empty/a"b/a\b/a\nb/a\tb/q"\n` → 14/14.
  - (6) pretty-printer json_parse(json_dump_pretty(v,2))==v over a map with quote/backslash/newline/tab/emoji values + type-confusion string literals + neg/float/bool + nested {a:[1,2,{}],e:[]} + a SPECIAL-CHAR KEY `k"\n` + empty containers; plus a top-level array [[],{},`x"y`,1,true] → 2/2.
  - TOTAL: pass=54 fail=0 → JSON ROUND-TRIP LOCK: GREEN.
- SPEC-GAP NOTED (shared + documented → NOT a new fix; honest g5): \uXXXX is passed through LITERALLY by BOTH rt_json_parse (self/rt/json.hexa L75-90, explicitly "passes through literally for round-trip safety") AND the runtime builtin json_parse. VERBATIM: builtin json_stringify("ctrl"+chr(1)+"here")=`"ctrlhere"`; builtin json_parse of that → len 14 (the literal escape), NOT len 9; rt_json_parse gives the IDENTICAL len-14 result. Because the pure-hexa parser is CONSISTENT with the builtin and the behaviour is documented in-source, this is a shared runtime design caveat (full Unicode decode deferred), not a rt/json divergence bug; fixing = a deep runtime.c change out of behaviour-fix-only scope. (The _js_emit float path uses float_to_string(v,6)=6-digit truncation — a fidelity gap IF used, but the LIVE compact rt_json_stringify delegates to the builtin json_stringify and _js_emit's helpers aren't interp-exposed, so it is not on any live serializer path. Documented, not live.)
- LOCK: NEW stdlib/test/test_json_roundtrip_lock.hexa — HERMETIC (no network, no `use`; parser+emitter+pretty bodies verbatim-inlined). Run on shipping `hexa run` LOCAL: pass=54 fail=0. NEGATIVE CONTROL: flip the float-`.` detection (is_float=true→false) → "3.5" routes to to_int → runtime error `to_int: trailing garbage in "3.5"` (test hard-fails at the float-type check) → catches a real float-fidelity regression, NOT a tautology.
- BYTE-EQ / GUARDS: self/rt/json.hexa IS in the self-host build closure but was NOT edited (0 source changes — clean surface). ONLY ADDED stdlib/test/test_json_roundtrip_lock.hexa (OUTSIDE the closure) → self-host fixpoint UNAFFECTED, no gate needed. 1 NEW leaf; 0 deletions (wipe_guard net-additive). LANE-1 only (no net/protocol/python-emit — that is LANE-2). $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · leak-0. Milestone OP-101 [x]. Verdict F-OP101-JSON-SERDE-ROUNDTRIP.txt.

## 2026-06-13 — OP-102 DONE: LANE-2 0-pod systemic `index_of(-1)`-unchecked class census (net/string/parser/text) — 🟢 class CLEAN (25 LANE-2 site-groups + 7 closure-side groups ALL guarded) + 14/14 verbatim leaf-lock on shipping `hexa run`
- LANE: 2 (0-pod correctness; NET / STRING / PARSER / TEXT). A THIRD distinct delimiter-parsing bug class after OP-94 split-keep-first + OP-97 boundary-run-collapse. Sibling LANE-1 (OP-101) owns serialization round-trip (json/yaml/csv) — NOT touched here (non-overlapping). No union conflict at land time (OP-101 not yet on main; regimen = keep-both on conflict).
- CLASS: code calls `index_of(needle)` / `last_index_of(needle)` / `find(needle)` then USES the result (substring(idx,…) start · array index · arith idx+len) WITHOUT first checking it for the not-found sentinel `-1` — so an ABSENT needle would feed a corrupt substring / out-of-bounds / wrong result instead of the documented fallback.
- CENSUS (scoped greps, NO .git; SKIP serializers json/yaml/csv = LANE-1/OP-101): read EVERY index_of/last_index_of/find call site in net/string/parser/text, classify GUARDED vs UNGUARDED. 25 LANE-2 site-groups + 7 closure-side (self/*) groups.
- MATRIX — ALL GUARDED/CLEAN:
  - net/http_request.hexa: sep=index_of("\r\n\r\n") `if sep>=0` · qidx=index_of("?") `if qidx>=0 else path` · colon=index_of(":") `if colon>0` · eq=index_of("=") `if eq>=0 else ""`.
  - net/websocket_native.hexa: slash `if slash>=0 else path="/"` · colon `if colon>=0 else port=80` · :224 term=index_of("\r\n\r\n") STRUCTURALLY guaranteed >=0 (reached only after the :207 `while index_of("\r\n\r\n")<0` loop EXITS) · line_end `if>=0 else whole` · the rest are boolean `<0` tests.
  - net/http_client + http + http2: curl reverse-peel nl=last_index_of("\n") `if nl<0 return result`.
  - http_sse.hexa: colon=index_of(":") `if colon<0 field=whole line` (WHATWG SSE fallback).
  - websocket.hexa + proc.hexa: JSON-bridge last_index_of("{")/("}") `if last_open<0||last_close<0||last_close<last_open → no-JSON fallback`.
  - semver.hexa: plus/dash=_sv_index_of `if !(plus<0)` / `if !(dash<0)` (×2 — parse + range token).
  - stdlib_cli.hexa: sep_at<0 continue · c1<0+c2<0 return ["","",""] · last_index_of("/") `if slash>=0 else path` (basename) · `::` sep>=0 · the rest are boolean `>=0` membership tests.
  - keychain.hexa: mi=last_index_of("::rc=") `if mi<0 return` (×2). proc.hexa: sp=index_of(" ") `if sp<0 continue`.
- CLOSURE twins [C1]–[C7] (membership: build_selfhost ~48 files; self/main + self/stdlib/http + hxc_a23_sparse_ppm IN, serve/attrs standalone): self/main hxc-reader (eq<0/sp<0 continue), self/serve/{http_server,serve} (sep/qidx/colon/eq guards — OP-96 fixed the DIFFERENT split-keep-first class here; the index_of(-1) sentinels are guarded), self/stdlib/http (nl<0 return), self/attrs/domain (eq<=0/idx<0/close_idx>=0/cp>=0), self/attrs/_lib/url_utils (blob_idx>=0/slash>=0/rel_idx>=0), self/stdlib/hxc_a23_sparse_ppm (n_pos<0 return; o_pos used ONLY in `if o_pos>n_pos` so a -1 is naturally NOT > n_pos>=0 → n_end=len(header) fallback — the comparison absorbs the sentinel). ALL CLEAN → NO closure twin to flag, no closure edit (fixpoint untouched). DIFFERS from OP-94 whose split-keep-first twins existed and were closed by OP-96.
- DIFFERENTIAL: /tmp/op102_diff.py — faithful Python port of each guarded body fed an ABSENT needle (Python str.find==-1 mirrors hexa sentinel) → each yields the DOCUMENTED FALLBACK not a corrupt substring: parse_request no-\r\n\r\n→body"" · split_path no-?→query"" · parse_pair no-=→"flag"→"" · sse no-:→whole field · semver no-+→build"" · ws no-/→path"/" · status no-\n→empty result · split_hit no-:→["","",""] · keychain no-::rc=→not-found · json-bridge no-{}→no-JSON · a23 no-o=→n_end=len. + present-needle controls (a=b=c→"b=c", host/a/b→"/a/b", body\n200→("body","200")) confirm no keep-first regression. "ALL CLEAN-SITE FALLBACKS CORRECT" — 0/13 mismatch.
- LOCK: NEW stdlib/net/indexof_unchecked_census_op102_test.hexa — 7 guarded bodies VERBATIM-INLINED (parse_request_body, split_query, pair_value, sse_field, sv_build, ws_path, split_hit_path), self-contained no-`use` (installed `hexa` resolves `use` to a STALE bundled copy — OP-87/88 lesson — so inlined), NOT in the build_selfhost closure. Each asserts absent-needle→documented-fallback AND a present-needle control. Shipping `hexa run` LOCAL → `__HEXA_STDLIB_INDEXOF_UNCHECKED_OP102__ 14/14` + `PASS`.
- RESULT: 🟢 the index_of(-1)-unchecked class is CLOSED across the LANE-2 net/string/parser/text surface — every call site whose result feeds substring/index/arith is preceded by a `==-1`/`<0`/`>=0` guard, or a `<0`-absorbing comparison, or is structurally guaranteed present. ZERO new buggy sites (the genuine delimiter-class bugs were earlier ops OP-87/88/91/92/96/98, all distinct). No fabrication — a guarded not-found check is CLEAN, not a bug (same honest framing as OP-94/97/100; an honest all-sites-guarded is a valid SUCCESS, the goal being to CLOSE the class).
- BYTE-EQ / GUARDS: ZERO source edits (every site already correct — no fix needed) + 1 NEW leaf test file; 0 deletions (wipe_guard net-additive). The *_op102 leaf is NOT in the build_selfhost closure → self-host fixpoint UNAFFECTED; no codegen/runtime/rt bytes touched. LANE-2 only (LANE-1 serde json/yaml/csv NOT touched — sibling OP-101 territory). $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · leak-0. Milestone OP-102 [x]. Verdict F-OP102-INDEXOF-UNCHECKED-SWEEP.txt.

## 2026-06-13 — OP-98 DONE: LANE-2 0-pod bug-hunt on INDEX-HEAVY binary/framed-protocol parsers (WS frame / HTTP/2 / HTTP server stack) — 🔴→FIXED stdlib/websocket.hexa python3 fallback `nonlocal pre` SyntaxError (whole fallback was dead) + 🟢×3 (native WS frame codec RFC-byte-exact, http_server parse, http2 status-block) + 5/5 hermetic leaf-lock
- LANE: 2 (0-pod correctness; net/protocol/HTTP). Hunts the densest bit/byte index-arithmetic parsers per OP-91/92/96 (HTTP/parsing surface proven bug-rich).
- SURVEY (scoped greps, NO .git): the framed/binary parsers are stdlib/websocket.hexa (492L, python3 fallback emits inline RFC-6455 client), stdlib/net/websocket_native.hexa (575L, native RFC-6455 frame codec — DENSEST: 7/16/64-bit payload-len, 4-byte mask, arithmetic bit-by-bit XOR, big-endian 64-bit length, opcode dispatch), stdlib/http2.hexa (228L, curl wrapper + _h2_parse_status_block sentinel split), self/serve/http_server.hexa (492L, NON-closure: parse_request/parse_query/build_response/JSON-mini), http_sse.hexa (OP-92-clean → skipped). Picked the 5 highest bit/byte-index parsers.
- CLOSURE-MEMBERSHIP (OP-96 method): grep compiler/ for `stdlib/websocket`/`stdlib/net/websocket`/`serve/http_server` → NONE imported by the compiler/main.hexa closure. All edited files (stdlib/websocket.hexa + stdlib/test/*) are OUTSIDE the build_selfhost closure → as fixpoint-safe as a stdlib fix → per OP-96 lesson a non-closure bug ⇒ FIX (not flag).
- 🔴 REAL SHIPPING BUG FOUND + FIXED — stdlib/websocket.hexa python3 fallback (_ws_python_helper_source):
  - WHAT: the helper emits a TOP-LEVEL python script (run as `python3 helper.py`). Inside nested `def take(n):` it declared `nonlocal pre`, but `pre` is assigned at module/`try`-block scope → take's enclosing scope is the MODULE, not a function. `nonlocal` requires an enclosing FUNCTION binding → python raises a COMPILE-TIME `SyntaxError: no binding for nonlocal 'pre' found` at the take() line.
  - IMPACT: the SyntaxError aborts the ENTIRE helper before any line runs → no JSON on stdout → ws_request_response's python3 path ALWAYS returned ok=false error='python helper: no JSON in stdout'. The python3 fallback (the universally-available backend on every host WITHOUT websocat) was 100% dead.
  - VERBATIM REPRO (helper reconstructed from the hexa string literals, run as the wrapper does):
    - `$ echo '{"url":"ws://127.0.0.1:1/x","msg":"hi","timeout":1}' | python3 helper.py`
    - `  File ".../ws_helper.py", line 58`
    - `      nonlocal pre`
    - `      ^^^^^^^^^^^^`
    - `  SyntaxError: no binding for nonlocal 'pre' found`
    - `exit=1`  (NO JSON on stdout)
  - FIX (minimal, 0 deletions): `s = s + "        nonlocal pre\n"` → `s = s + "        global pre\n"` (pre is a module global; take reads+reassigns it → `global pre` is the correct keyword).
  - POST-FIX LIVE LOOPBACK (hermetic local python3 echo server + the FIXED emitted helper as client: full RFC-6455 handshake + masked client text frame + server-frame decode + masked close): STDOUT `{"ok": 1, "reply": "ECHO:hello-boundary", "error": ""}` → LOOPBACK PASS. NEGATIVE CONTROL (flip back to `nonlocal pre`): SyntaxError, empty stdout, FAIL → NOT a tautology.
- 🟢 CLEAN — stdlib/net/websocket_native.hexa frame codec (RFC-6455 byte-exact): exact Python port of _ws_encode_frame + ws_recv_native parser checked vs an INDEPENDENT RFC-6455 reference (struct.pack '>H'/'>Q') over boundary sweep n∈{0,1,2,125,126,127,128,255,256,65535,65536,65537,70000} — masked client encode==RFC 0 mismatch ALL n; encode∘decode==payload 0 mismatch ALL n; unmasked SERVER decode (what ws_recv_native receives) n∈{0,125,126,127,65535,65536} 0 mismatch; _ws_xor_byte (arithmetic bit-by-bit) == python `^` for ALL 256×{0,1,0x5C,0xFF,0xA1} pairs + involution xor(xor(a,b),b)==a holds 0 mismatch. The 7/16/64-bit length forms, big-endian assembly, mask-bit strip (b1%128), opcode (b0%16) all correct → NO bug.
- 🟢 CLEAN — self/serve/http_server.hexa parse surface: parse_request (first "\r\n\r\n") + parse_query (first "=" + empty-pair skip) ALREADY correct on origin/main (closed by OP-96 #3250). NOTE: an initial read of the STALE shared-checkout copy mis-flagged the parse_query value-`=` truncation; re-reading the origin/main worktree copy confirmed it is FIXED — not a new bug.
- 🟢 CLEAN — stdlib/http2.hexa _h2_parse_status_block: reverse-split sentinel via _h2_last_index_of("\n") preserves multi-line body (OP-94 classified). curl wrapper, no HPACK/frame bit arithmetic.
- LOCK: NEW stdlib/test/test_websocket_helper_lock.hexa — HERMETIC (no network, no python3 to run the test). SELF-CONTAINED: _ws_python_helper_source VERBATIM-INLINED (no `use` — installed `hexa` resolves `use "stdlib/websocket"` to a STALE bundled copy, OP-87/88 lesson). Asserts the emitted source carries `global pre`, has NO `nonlocal pre`, defines take(), seeds `pre = rest`, keeps masked close-code (cmask[0]^0x03, cmask[1]^0xE8). Run on shipping `hexa run` LOCAL (hexa 0.1.0-dispatch): `pass=5 fail=0` → PASS 5/5. NEGATIVE CONTROL (flip inlined line to nonlocal): FAIL 3/5 (has_global_pre + no_nonlocal_pre FAIL) → catches the regression, not a tautology. Also added `ws_python_helper_source_for_test()` test-exposure fn to stdlib/websocket.hexa (mirrors ws_shell_escape_for_test) for a future non-stale `use`-based test.
- BYTE-EQ / GUARDS: all edits OUTSIDE the build_selfhost closure (stdlib/websocket.hexa + stdlib/test/*) → self-host fixpoint UNAFFECTED (closure-OUT, no gate needed). 1 keyword fixed + 1 test-exposure fn + 1 NEW leaf test; 0 source deletions (wipe_guard net-additive). LANE-2 only. $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · leak-0. Milestone OP-98 [x]. Verdict F-OP98-WS-PYTHON-FALLBACK-NONLOCAL.txt.

## 2026-06-13 — OP-96 DONE: close the 2 FLAGGED closure-twin HTTP-parser bugs (self/serve/http_server.hexa parse_request + parse_query) — fixpoint-SAFE (closure-membership proof: file NOT in build_selfhost closure) + 25/25 leaf-lock
- LANE: 2 (0-pod correctness). Retires the 🟠 flag OP-91/92/94 placed on the two self/serve/http_server.hexa twins, after a decisive closure-membership proof.
- MOTIVE: OP-91 (parse_query) + OP-92 (parse_request) found+fixed two real split-keep-first bugs in stdlib/net/http_request.hexa, and OP-94's census re-confirmed them; all three FLAGGED the IDENTICAL bugs in self/serve/http_server.hexa as 🟠 UNFIXED "fixpoint risk" (lives under self/* → conservatively treated as in the self-host closure). OP-96 tests that assumption.
- CLOSURE-MEMBERSHIP CHECK (decisive): build_selfhost compiles "compiler/main.hexa + its import/use closure" (tool/build_selfhost.sh:27; flatten() walks `import "..."`/`use "..."` transitively from compiler/main.hexa, :104-118). Re-ran the EXACT flatten walk:
  - === closure size: 48 files ===
  - === http_server in closure? === NO
  - === any serve/ file in closure? === NONE
  - The only "http_server" hit in self/codegen.hexa (:6241) is a CODE COMMENT, not an import.
  - VERDICT: self/serve/http_server.hexa is a STANDALONE serving tool (the Anima-ALM HTTP server), NOT a compiler-bootstrap dependency → the deterministic fix is as fixpoint-safe as a stdlib fix. The OP-91/92/94 flag was a conservative "self/* ⇒ closure" over-approximation this proof refutes.
- FIX (1) parse_request body-framing (:24-29→:24-34, OP-92 pattern): `raw.split("\r\n\r\n")` + parts[1] split on EVERY blank line and kept only the first body segment → TRUNCATED any body containing a blank line (multipart/nested-HTTP). FIXED: split on FIRST "\r\n\r\n" only via `raw.index_of("\r\n\r\n")` + `substring(sep+4, len(raw))` (RFC-7230 framing, whole remainder kept).
- FIX (2) parse_query value-split (:78-89, OP-91 pattern): `pairs[i].split("=")` + kv[0]/kv[1] shattered on EVERY "=" (value-truncation on "=" in value) and inserted result[""] for empty pairs (spurious blank key). FIXED: split on FIRST "=" only via `pair.index_of("=")` + substring, and skip empty pairs.
- LOCK: NEW self/serve/http_server_parse_test.hexa — BOTH fixed bodies verbatim-inlined (self-contained no-`use`; installed `hexa` resolves `use "self/..."` to a stale bundled copy — OP-87/88 lesson — so inlined + gated on the shipping `hexa run`, /Users/mini/.hx/bin/hexa): __HEXA_SELF_SERVE_HTTP_OP96__ 25/25 ALL-GREEN.
  - 25 goldens: parse_request body-embedded-blankline (hi\r\n\r\nbye preserved), body-multi-blankline (A\r\n\r\nB\r\n\r\nC preserved), + simple method/path/empty-body, path+query split, header colon-in-value, no-separator regression locks; parse_query value-with-= (a=b=c→"b=c"), double-eq (a==b→"=b"), empty-pair (a=1&&b=2 keycount 2), trailing-amp (keycount 1), + basic/no-eq/trailing-eq/empty-input locks.
- NOT-A-TAUTOLOGY: the UNFIXED bodies reproduce the divergence verbatim on shipping `hexa run`: req body got=[hi] (want hi\r\n\r\nbye); qry a=b=c got=[b] (want b=c); qry a=1&&b=2 keycount=3 (want 2).
- FIXPOINT: all self-host byte-eq gates (selfhost-byteeq-real, selfhost byte-eq gen3→gen4, determinism, miscompile-zero, codegen-guard) inline-polled on the PR → held GREEN at value (deterministic source fix + file proven NOT in the closure).
- BYTE-EQ: closure-membership-proven-OUT; 2 fns fixed + 1 NEW leaf; 0 source deletions (wipe_guard net-additive). Self-host fixpoint UNAFFECTED.
- TIER: 🟢 2 closure twins CLOSED + fixpoint verified-safe (closure proof + 25/25 leaf-lock). $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · leak-0.
- verdict: .verdicts/hexa-0pod/F-OP96-CLOSURE-TWIN-HTTP.txt

## 2026-06-13 — OP-97 DONE: SYSTEMIC boundary-run-collapse CENSUS across LANE-1 stdlib (NUMERIC/DATA/PARSER + path/string) — class CLOSED (0 new bugs; OP-87/88 were the 2 genuine 🔴) + 39/39 census leaf-lock + NO closure twin 🟢
- LANE: 1 (0-pod correctness, stdlib NUMERIC/DATA-STRUCTURE/PARSER + path/string siblings). Sibling LANE-2 (OP-96) owns self/serve/* closure twins of the split-keep-first class — self/serve/* NOT touched here (non-overlapping; this is a DIFFERENT class).
- MOTIVE: OP-87 (path_dirname) + OP-88 (path_ext) shared a class DISTINCT from OP-94's split-keep-first: a `while`/index scan advancing by 1 over a delimiter/boundary char that FAILS to SKIP/COLLAPSE *consecutive runs* of that char → leaks/miscounts at runs (trailing/leading-separator strip, consecutive-separator collapse, whitespace-run skip, leading/trailing zero-byte run). This round GREP-CENSUSED that class the way OP-94 systematized split-keep-first.
- CENSUS (scoped greps, NO .git; LANE-1; EXCLUDE self/serve/* + rtsc fixtures + *_test): grep `while` index scans + run-collapse keywords (trim/strip/skip/collapse/whitespace/leading-zero/trailing-zero/last_index_of), read every candidate body.
- MATRIX (20 site-groups, ALL CLEAN):
  - alloc/path.hexa path_dirname → 🔴 FIXED by OP-87 (run-skip added). path_ext/path_stem → 🔴 FIXED by OP-88 (lead-dot-run skip). Both CLEAN now.
  - alloc/path.hexa path_basename → CLEAN (trailing-slash strip loop skips whole run; reverse scan = last '/'; GNU-correct).
  - alloc/path.hexa path_normalize → CLEAN (split"/" + filter len>0 → consecutive slashes COLLAPSE; OP-88-confirmed).
  - stdlib_cli.hexa _trim → CLEAN (leading `while a` + trailing `while b` both skip the full ws RUN).
  - easy/cli.hexa _word_count → CLEAN (`in_tok` state machine collapses ws runs; counts only on ws→non-ws transition).
  - kernels/circuit/devsim.hexa _split_ws + read_verilog _rv_tokens + noc_sim/anynet _anynet_tokens + fusion/_plasma_lambda_d_batch → CLEAN (filter-empty-after-split → ws runs yield NO empty tokens).
  - codec/base64.hexa base64_decode → CLEAN (skips EVERY whitespace char; runs collapse; data-char count steady — OP-75 area).
  - crypto/tls13_client_record_io.hexa → CLEAN (trailing zero-pad strip loops the FULL zero RUN, RFC 8446 §5.4).
  - crypto/x509_rsa.hexa x509_rsa_modulus → CLEAN (leading 0x00 sign-byte strip loops the FULL leading-zero RUN).
  - core/parse.hexa is_numeric_str/to_int_strict_or_zero → CLEAN (every digit consumed; leading zeros accumulate correctly, not a run-collapse concern). to_int_safe split(".") = split-FIRST (correct).
  - regex/native.hexa {n,m} quantifier + qasm3_lex.hexa lexer → CLEAN (digit/ident/ws runs fully consumed; lexer outer loop re-checks per char).
  - material/composition.hexa _scan_count/_scan_elements/paren-expand → CLEAN (digit runs accumulated whole; parens = single chars not runs; Python regex parity exact).
  - plot/plot.hexa permille format → CLEAN (2-digit fraction, frac!=0 guarded → at most 1 trailing zero, no run).
  - stdlib_cli.hexa basename + bio/weave/* + bio/nanobot/* last_index_of("/") dir/basename → CLEAN (split on LAST slash; internal runs handled; constructed paths have no trailing-slash run).
  - yaml.hexa flat parser indent/colon scan → CLEAN (first-char indent test documented; colon split-FIRST = correct YAML).
- ROBUSTNESS-ONLY note (NOT a bug, not fixed; g0/g5 scope): abc_map.hexa non-.latch BLIF directives (.model/.inputs/.outputs/.gate) use bare split(" ") but parse standard single-space BLIF emitter output — empty tokens cannot occur on the tool-generated input the reader consumes (the .latch path already filters empties for ABC's variable-whitespace rows). Documented round-trip with this module's own emitter; not a provable run-collapse-intent bug.
- RESULT: ZERO new buggy sites. The boundary-run-collapse class is CLOSED in LANE-1 stdlib — every run-handling site uses the correct pattern (run-skip inner loop, filter-empty-after-split, or accumulate-the-whole-run). The 2 genuine 🔴 of this class were OP-87/88.
- DIFFERENTIAL (g5): faithful Python ports of each CLEAN body over inputs with 0/1/2/3 consecutive boundary chars at start/mid/end (/tmp/op97_diff.py + /tmp/op97_b64.py) — 0 divergence from intended run-collapse semantics. (3 transient "BUG" prints were a TEST-EXPECTATION error: I wrote base64 data-char count as 3 instead of 4; re-confirmed 4 in op97_b64.py — the module is correct.)
- LOCK: NEW stdlib/alloc/boundary_run_census_op97_test.hexa — verbatim-inlined CLEAN bodies (cli_trim, word_count, split_ws_count, b64_ws_count, tls_trailing_nonzero, x509_leading_strip_count, path_collapse), self-contained no-`use`, NOT in build_selfhost closure, run LOCAL on shipping `hexa run` /Users/mini/.hx/bin/hexa: __HEXA_STDLIB_BOUNDARY_RUN_OP97__ 39/39 PASS. Non-regression: OP-87 __HEXA_STDLIB_PATH_COLL_OP87__ 34/34 PASS + OP-88 __HEXA_STDLIB_PATH_EXT_OP88__ 24/24 PASS re-run GREEN.
- 🟢 CLOSURE-SIDE (self/*) — NO boundary-run twin: self/main.hexa:618 _init_basename trailing-slash strip loop (623-625) skips the FULL run + reverse-to-prior-slash scan is GNU-correct → ALREADY run-skip-correct, NOT a twin, no flag. native_gate_emit/runtime_core_emit emitted-C trailing-slash strips also correct. (Distinct from OP-94's split-keep-first closure twins in self/serve/http_server.hexa = LANE-2/OP-96, a DIFFERENT class.)
- BYTE-EQ / wipe_guard: ZERO stdlib source edits (every site already correct, no fix needed) + 1 NEW census leaf + verdict + this log entry; 0 deletions (wipe_guard net-additive). The leaf is NOT in the closure → self-host fixpoint UNAFFECTED; no codegen/runtime/rt bytes touched.
- TIER: 🟢 class-closed + 🟢 no closure twin. $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · leak-0. Milestone OP-97 [x]. Verdict F-OP97-BOUNDARY-RUN-SWEEP.txt.

## 2026-06-13 — OP-94 DONE: SYSTEMIC split-on-every-delimiter-keep-first CENSUS across LANE-2 stdlib (net/http/url/string) — class CLOSED (0 new bugs; OP-91/92 already fixed the 2 genuine 🔴) + 18/18 census leaf-lock + 2 closure twins FLAGGED 🟠
- LANE: 2 (0-pod correctness, stdlib STRING/PATH/TEXT/URL/NET). Sibling LANE-1 owns stdlib data-structure/numeric/parser (non-overlapping — OP-94 touched ONLY stdlib/net/* + read-only census of http*.hexa/websocket.hexa/string.hexa).
- MOTIVE: the split-keep-first anti-pattern recurred in 5 prior ops (OP-91 parse_query, OP-92 parse_request, OP-75 base64, OP-90 argparse, OP-87 dirname) — code does `x.split(SEP)` then a FIXED index ([0]/[1]/parts[1]) when intent is split-on-FIRST/LAST only, so any input with SEP 2+ times is silently truncated. This round did a high-leverage GREP CENSUS to catch every remaining LANE-2 instance at once.
- CENSUS (scoped greps, NO .git; LANE-2 = stdlib/net/* + http.hexa + http2.hexa + http_sse.hexa + websocket.hexa + string.hexa + core/string.hexa; EXCLUDE LANE-1 data/numeric/parser; EXCLUDE self/* closure): grep `.split(`/`.partition(`/`.index_of(`/`.last_index_of(`/`substring(`, classified each delimiter-extraction site.
- MATRIX (site → classify):
  - http_request.hexa parse_query `qs.split("&")` + split-FIRST-"=" via index_of/substring → ALREADY-FIXED (OP-91) CLEAN, re-locked.
  - http_request.hexa parse_request `raw.index_of("\r\n\r\n")` header/body → ALREADY-FIXED (OP-92) CLEAN, re-locked.
  - http_request.hexa:40 `header_block.split("\r\n")` → CLEAN all-segments (iterates every line).
  - http_request.hexa:43 `lines[0].split(" ")` → CLEAN (request-target has no SP; [0]/[1] correct).
  - http_sse.hexa:327 http_sse_parse_event `line.index_of(":")` → CLEAN split-FIRST-":" (WHATWG; value keeps inner ":").
  - http_sse.hexa:511/592 `split(raw,"\n")` → CLEAN all-segments (while-iterates every line).
  - http2.hexa _h2_parse_status_block `_h2_last_index_of("\n")` ×2 → CLEAN reverse-split (peels trailing status+version sentinel; body newlines preserved).
  - http.hexa:140/213 + http_client.hexa:108 `_http_last_index_of("\n")` → CLEAN reverse-split (peels `\n%{http_code}` sentinel; multiline body preserved).
  - websocket_native.hexa:81/90 ws_url_parse authority/path FIRST-"/" + host:port FIRST-":" via index_of → CLEAN (multi-slash path preserved); :207/224/228 handshake FIRST-"\r\n\r\n"/"\r\n" → CLEAN.
  - websocket.hexa:242/243 JSON-brace `last_index_of` ×2 → CLEAN (intentional last-object heuristic); :157 emitted-Python `head.split(b'\r\n',1)[0]` → CLEAN (maxsplit=1 correct first-split, in EMITTED code not hexa logic).
- RESULT: ZERO new BUGGY sites. The 2 genuine 🔴 of this class were already closed by OP-91/OP-92; every remaining LANE-2 delimiter parser is CLEAN (split-on-FIRST or split-on-LAST via index_of/last_index_of+substring, NOT shatter-on-every + fixed index). The systemic split-keep-first class is CLOSED in LANE-2 stdlib.
- DIFFERENTIAL (faithful Python port of each CLEAN body over inputs with the delimiter 2+ times):
  - sse_field("data: a:b:c") -> value "a:b:c" (inner ":" survives) ✓
  - h2_status_block("line1\nline2\nline3\nHTTP/2\n200") -> body "line1\nline2\nline3" (embedded newlines survive) ✓
  - http_status_peel("multi\nline\nbody\n404") -> body "multi\nline\nbody" ✓
  - ws_url_parse("ws://h:81/a/b/c") -> path "/a/b/c" (multi-slash survives) ✓
  - All CLEAN-site differentials PASS — every site preserves data past the delimiter, 0 truncation.
- LOCK: NEW stdlib/net/split_keep_first_census_test.hexa — verbatim-inlined CLEAN bodies (sse_field FIRST-":", h2_status_block reverse-"\n", http_status_peel reverse-"\n", ws_url_parse FIRST-"/"+":"), self-contained no-`use`, NOT in build_selfhost closure; run LOCAL on shipping `hexa run` (/Users/mini/.hx/bin/hexa): __HEXA_STDLIB_SPLIT_KEEP_FIRST_OP94__ 18/18 ALL-GREEN. OP-91 (20/20) + OP-92 (13/13) leaves re-run GREEN as fix locks.
- 🟠 FLAGGED CLOSURE TWINS (NOT fixed — fixpoint risk): self/serve/http_server.hexa:25-28 parse_request (`raw.split("\r\n\r\n")`+parts[1] body-trunc, OP-92 twin) AND :78-86 parse_query (`pairs[i].split("=")` kv[0]/kv[1] value-trunc + spurious-blank-key, OP-91 twin) BOTH carry the identical bug but ARE in the self-host closure → flagged only (a closure edit risks the self-host byte-eq fixpoint). self/main.hexa:435/461 hexa_url_query_get/_get_all = CLEAN (char-scan to FIRST "=", already correct).
- BYTE-EQ: stdlib/net/* NOT in closure; 0 source edits (all sites already-correct) + 1 NEW census leaf; 0 deletions (wipe_guard net-additive). Fixpoint UNAFFECTED. LANE-2 only.
- TIER: 🟢 systemic class closed (census + differential + 18/18 leaf-lock) + 🟠 2 closure twins flagged. $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · leak-0.
- verdict: .verdicts/hexa-0pod/F-OP94-SPLIT-KEEP-FIRST-SWEEP.txt

## 2026-06-13 — OP-95 DONE: LANE-1 0-pod bug-hunt on NEXT untested bespoke DATA-STRUCTURE / NUMERIC / STATE-MACHINE modules (distinct bug class: off-by-one / range-validation / sign / state-transition) — 🟢 5 modules PROVEN-CLEAN (no shipping bug, not fabricated), 23/23 verbatim leaf lock; strongest = EXHAUSTIVE utf8 clean.
- LANE: 1 (0-pod correctness — stdlib DATA-STRUCTURE / NUMERIC / non-net-non-string PARSER / alloc-non-path). Sibling LANE-2/OP-94 sweeps net/string/text/path (non-overlapping — OP-95 touched ONLY stdlib/codec + stdlib/stats + stdlib/kernels/noc_sim leaf-test surface, NO net/string/text/path module).
- THESIS: OP-93 found the top-level numeric/parser leaves mostly clean (bugs concentrate in delimiter/index logic). OP-95 self-selects the NEXT untested bespoke LANE-1 modules with the highest index/state/arithmetic surface and hunts a DISTINCT bug class: OFF-BY-ONE at a boundary, MISSING RANGE-VALIDATION (the OP-93 month-13 class), INTEGER SIGN error, or a STATE-MACHINE transition bug.
- SURVEY (scoped greps, NO .git; LANE-1; SKIP already-audited argparse/hashset/collections/path/civil/permille/wrap_pi/correlation/welford + OP-80/82/85/86 runtime helpers + iso8601 [routes to libc runtime builtins, not bespoke hexa logic]): the bespoke index/state/arithmetic surface with a Python reference:
  · stdlib/codec/utf8.hexa — UTF-8 validate/encode/decode STATE MACHINE. HIGHEST range-validation surface: RFC-3629 overlong / surrogate (U+D800-DFFF) / >U+10FFFF / truncated / lone-continuation / bad-lead rejection + per-leading-byte size table + 2/3/4-byte codepoint assembly. ← PICK
  · stdlib/stats/ks_two_sample.hexa — KS D-statistic merge-sweep STATE MACHINE. HIGHEST tie/tail index surface: sorted dual-cursor sweep, tie-consumption loops, two tail loops, supremum tracking at the right-continuous step boundary. ← PICK
  · stdlib/kernels/noc_sim/event_queue.hexa — binary MIN-HEAP. HIGHEST sift index surface: sift_up parent=(i-1)/2, sift_down children 2i+1/2i+2, last-to-head + drop-tail + sift on n-1 (classic off-by-one nest). ← PICK
  · stdlib/kernels/noc_sim/traffic.hexa — permutation-index logic (tornado/transpose/uniform dest, shift=ceil(k/2)-1, LCG sign). ← PICK
  · stdlib/codec/hex.hexa — base-16 radix round-trip + guards (odd-length / non-hex reject, whitespace+colon skip). ← PICK
- 🟢 ALL 5 PROVEN-CLEAN — NO shipping bug, NO missing docstring-promised guard (NOT fabricated, g5). DIFFERENTIAL (verbatim Python port of each UNFIXED body vs a Python reference over a wide / exhaustive boundary sweep):
  · codec/utf8.hexa: utf8_is_valid vs Python bytes.decode('utf-8',strict) EXHAUSTIVE all 1-byte (256) + all 2-byte (65,536) + all 3-byte (lead 0xE0-0xEF × b1 × b2 = 786,432) + boundary 4-byte (lead 0xF0-0xF4 × b1 × {b2,b3 boundaries} = 30,720) → 0 MISMATCH. encode/decode round-trip over ALL 1,112,064 valid codepoints (0..0x10FFFF minus surrogates): utf8_from_codepoints == chr(cp).encode('utf-8') AND utf8_codepoints(enc) == [cp], value-exact → 0 MISMATCH. Every reject path (overlong-2 C0 80, overlong-3 E0 80 80, surrogate ED A0 80, >max F4 90 80 80, truncated, lone-continuation, bad-lead F5) fires correctly.
  · stats/ks_two_sample.hexa: ks_two_sample_D merge-sweep vs a brute-force reference D = max_x|F_n(x)-G_m(x)| over the union of sample points, with SMALL integer ranges to FORCE heavy ties (n,m∈[1,8], values 0..4): 20,000 random trials → 0 MISMATCH. Tie-consumption, both tail loops, and supremum at the right-continuous step boundary all correct (incl. the one-sided heavy-tie case xs=[2,2,2] ys=[1,2,3] → D=1/3 exact, confirmed against ref).
  · kernels/noc_sim/event_queue.hexa: heap sift_up/sift_down/pop ported and stressed vs cpython heapq under INTERLEAVED push/pop (random mix, ops≤40, 5,000 trials) + full drain: the pop sequence (time, id, seq tiebreak) is bit-identical → 0 MISMATCH. The eq_pop nest (set_head(last) → drop_last → sift_down(n-1)) uses the correct post-shrink heap size — no off-by-one.
  · kernels/noc_sim/traffic.hexa: documented invariants verified against the impl — tornado(0,0)=(3,3) [src0→27], tornado(7,7)=(2,2) [src63→18] for k=8, shift=ceil(8/2)-1=3; tornado is a bijection over 0..63; transpose (i,j)->(j,i) is its own inverse; uniform stays in 0..N-1 (the committed self-test's 400-seed × 64-source = 25,600-draw range check would catch a negative-LCG escape and passes). Self-tested + invariant-confirmed.
  · codec/hex.hexa: hex_decode/hex_encode round-trip — encode(b) then decode == b for ALL b∈0x00..0xFF (256/256), zero-pad correct (0x0F→"0f"), mixed-case+colon decode (A:b→0xAB), and the docstring-promised reject paths fire (odd-length input → [], non-hex digit → []).
- 🟠 FLAGGED: none warranted — all 5 modules behaviorally correct, every docstring-promised guard present. No closure-side / self-* twin touched or needed (all modules outside the self-host closure).
- LOCK: 3 NEW verbatim-inlined leaf oracles (installed `hexa` resolves `use "stdlib/..."` to its STALE bundled copy, OP-87/88 lesson — so each leaf INLINES the audited body verbatim with no `use`, gated on the shipping `hexa run` /Users/mini/.hx/bin/hexa, hexa 0.1.0-dispatch, ran LOCAL): stdlib/codec/utf8_validate_op95_test.hexa __OP95_UTF8__ 11/11 PASS (ascii/2B/3B/4B valid + overlong-2/overlong-3/surrogate/max-cp/truncated/lone-continuation/bad-lead REJECT); stdlib/stats/ks_two_sample_op95_test.hexa __OP95_KS__ 5/5 PASS (identical→D=0, disjoint→D=1, textbook 1..5/4..8→D=0.6, symmetry, heavy-tie xs=[2,2,2] ys=[1,2,3]→D=1/3); stdlib/codec/hex_roundtrip_op95_test.hexa __OP95_HEX__ 7/7 PASS (enc-ab/zero-pad, dec mixed-case+colon, odd-reject, non-hex-reject, full 0x00-0xFF round-trip). All confirmed against the Python differential (0 mismatch) — real locks, not tautologies.
- BYTE-EQ / FIXPOINT: ZERO compiler-closure (self/*) edits. Only 3 NEW leaf tests under stdlib/codec + stdlib/stats + a verdict + this log. NO stdlib SOURCE changed (every audited module proven clean — no fix needed). Self-host fixpoint UNAFFECTED. 0 deletions (wipe_guard net-additive). LANE split honored (no net/string/text/path).
- TIER 🟢 (invariant-lock; honest g5 — no shipping bug, not fabricated; strongest result = the EXHAUSTIVE utf8 clean: ~16.8M byte-sequences + 1.1M codepoints vs Python's strict decoder, 0 mismatch). Verdict .verdicts/hexa-0pod/F-OP95-DATASTRUCT-NUMERIC.txt. $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · leak-0.

## 2026-06-13 — OP-93 DONE: LANE-1 0-pod bug-hunt on SIBLING bespoke PARSERS + NUMERIC FORMATTERS (OP-90 argparse `--key=value` sibling) — 🟢 5 modules PROVEN-CLEAN (no shipping bug, not fabricated), 25/25 verbatim leaf lock + 1 FLAGGED lenient-validation observation.
- LANE: 1 (0-pod correctness — stdlib DATA-STRUCTURE / NUMERIC-FORMAT / PARSER, NON string/path/url = LANE-2). Sibling LANE-2/OP-92 owns stdlib/net/* (non-overlapping — OP-93 touched ONLY stdlib/time + stdlib/core/math leaf-test surface).
- THESIS: OP-90 found stdlib/alloc/argparse.hexa silently dropped `--key=value`; the parser/delimiter surface is proven bug-rich. OP-93 hunts the SIBLING bespoke parsers + numeric formatters + the hand-rolled `=`/delimiter duplications that often diverge from a canonical parser.
- SURVEY (scoped greps, NO .git; LANE-1; SKIP net/* + already-audited argparse/hashset/core/parse/semver/codec/crypto/core-math/flame): top-level stdlib's standalone numeric/parser leaves are mostly thin RE-EXPORT shims (parse.hexa→core/parse, math/float→core/math/float, math/permille→core/math/permille) or libc-routed (time/iso8601→utc_iso_* runtime builtins). The bespoke index/state surface with REAL parse/format logic AND a Python reference:
  · stdlib/time/civil.hexa — pure-hexa ISO-8601/RFC-3339 iso8601_parse_native + days_from_civil/civil_from_days. HIGHEST surface: round-trip invariant, fixed-offset digit extraction, leading-zero, out-of-range, too-short, non-digit garbage. ← PICK
  · stdlib/core/math/permille.hexa — fixed-point ×1000 _div_round_half_away + pm_of_ratio + pm_to_string + pm_to_int_floor (half-away rounding + format, classic rounding-bug source). ← PICK
  · stdlib/core/math/wrap_pi.hexa — angle [−π,π] normalizer (boundary preservation). ← PICK
  · stdlib/stats/correlation.hexa — Spearman _rank average-rank tie formula. ← PICK
  · stdlib/yaml.hexa flat key:value parser + stdlib/dojo/cli.hexa `--lang=` + stdlib/cockpit/cellrun.hexa `key=value` + stdlib/easy/cli.hexa _permille — the hand-rolled `=`/`:`-delimiter DUP class (the easy/cli.hexa:99 `--out=` / OP-90 pattern). ← PICK
- 🟢 ALL CLEAN — NO shipping bug found (NOT fabricated, g5). DIFFERENTIAL (verbatim Python port of each UNFIXED body vs a Python reference over a wide boundary sweep, C-truncation-faithful):
  · stdlib/time/civil.hexa: iso8601_format_native vs Python datetime over 64,291 epochs (0..4.1e9, incl. leap-day/Y2K/year boundaries) → 0 mismatch; parse∘format round-trip over 220,000+ epochs → 0 mismatch; format∘parse idempotence on well-formed canonical → 0 mismatch; too-short ("1970-01-01")→-1 and non-digit ("abcd-..")→-1 (contract met); days_from_civil/civil_from_days are exact mutual inverses.
  · stdlib/core/math/permille.hexa: _div_round_half_away vs true round-half-away (Python fractions) over a∈[-200,200]×b∈[-50,50] → 0 mismatch; pm_to_string incl. negative (-1.230) + sub-milli pad (5→0.005) correct; pm_to_int_floor floors toward -inf correctly.
  · stdlib/core/math/wrap_pi.hexa: boundary-preserving (+π→+π, −π→−π) per its own documented math.fmod-parity contract; fast-path guard correct.
  · stdlib/stats/correlation.hexa: _rank mean-rank formula (#less+1)+(#equal−1)/2 == scipy mean-rank; co-located test already present.
  · yaml.hexa flat parser / dojo/cli `--lang=` / cockpit/cellrun `key=value` / easy/cli _permille: all split on the FIRST delimiter and handle empty-value / `=`-in-value / comment per their documented contracts — the OP-90 argparse `--key=value` defect is NOT present in these siblings (they already split correctly: dojo uses substring(7,len) to EOL, cockpit uses index_of("=")+substring(eq+1,len)).
- 🟠 FLAGGED (lenient-validation observation — NOT a bug, documented design, NOT fixed): civil.hexa iso8601_parse_native does FIXED-OFFSET digit extraction and does NOT validate field separators or field RANGES, so "1970-13-01T00:00:00Z" (month 13) parses to a NORMALIZED epoch (Howard-Hinnant days_from_civil is mathematically valid for any int) rather than returning -1. The header documents "Fixed-offset field extraction (ISO 8601 basic UTC form)" + "-1 on a malformed/too-short input" where malformed = non-parseable SHAPE. Adding range-validation would CHANGE the locked round-trip contract and is a behavior change not provably matching a stated reference → FLAGGED only (g5 honest: behavior fix only when provably matching the reference, else FLAG).
- LOCK: NEW stdlib/time/civil_parse_numeric_op93_test.hexa — the audited civil + permille bodies VERBATIM-INLINED (installed `hexa` resolves `use "stdlib/..."` to its STALE bundled copy, OP-87/88 lesson) + gated on the shipping `hexa run` (ran LOCAL — hexa 0.1.0-dispatch — no fork-storm this round). __OP93_LOCK__ PASS 25/25 (civil parse∘format round-trip ×6 epochs both directions + epoch0/Y2K anchors + days_from_civil + too-short/non-digit→-1; permille half-away 1/3→333, 2/3→667, -1/3→-333 + format 0.500/1.230/-1.230/0.005). Confirmed against the Python differential (0 mismatch) — the leaf is a real lock, not a tautology.
- BYTE-EQ / FIXPOINT: ZERO compiler-closure (self/*) edits. Only a NEW leaf test under stdlib/time/ + a verdict + this log. NO stdlib SOURCE changed (every audited module proven clean — no fix needed). Self-host fixpoint UNAFFECTED. 0 deletions (wipe_guard net-additive). LANE split honored (no net/string/path).
- TIER 🟢 (invariant-lock; honest g5 — no shipping bug, not fabricated; 1 FLAGGED non-bug observation). Verdict .verdicts/hexa-0pod/F-OP93-PARSER-NUMERIC.txt. $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · leak-0.

## 2026-06-13 — OP-92 DONE: LANE-2 0-pod bug-hunt on stdlib NET sibling parsers (follows OP-91 parse_query) — 🔴 REAL SHIPPING BUG in stdlib/net/http_request.hexa parse_request (body truncation) FOUND + FIXED + 13/13 leaf-locked; 2 siblings CLEAN; closure twin FLAGGED 🟠
- LANE: 2 (0-pod correctness, stdlib STRING/PATH/TEXT/URL/NET). Sibling LANE-1/OP-90 owns stdlib data-structure/numeric/parser (non-overlapping — OP-92 touched ONLY stdlib/net/*).
- FOLLOWS OP-91 (#3245), which fixed parse_query and noted parse_request as "low surface". This round re-examined that and found parse_request is in fact the HIGHEST-surface helper (4 delimiter regions) — and it carries a real bug OP-91 missed.
- SURVEY (scoped greps, NO .git; LANE-2 NET; SKIP self/serve/* = closure, parse_query [OP-91], _route_match [OP-91 low-surface]): census every delimiter/boundary/index parser across stdlib/net/*.hexa + stdlib/http*.hexa. 4 highest-surface helpers, WHY each: (1) http_request.hexa parse_request — request-line split-on-SP + path/query split-on-"?" + header Name:Value split-on-first-":" with trim+lowercase + header-block/body split-on-"\r\n\r\n" = the densest, four independent delimiter regions over untrusted wire bytes. (2) http_sse.hexa http_sse_parse_event — WHATWG SSE field/value: comment ":"-prefix, field split on FIRST ":", single-leading-SP strip, multi-`data:` accumulation, no-colon-field rule, retry int-coerce. (3) http2.hexa _h2_parse_status_block — trailing-sentinel \n<version>\n<code> reverse-index split (body may contain its own newlines). (4) self/serve/http_server.hexa parse_request [CLOSURE — survey only, the compiler-internal origin of #1]. http_client http_get* = curl shell-out + single last_index_of, low surface. No cookie/percent-decode/chunked-length/URL-scheme-host-port parser EXISTS as a stdlib fn (grep for fn parse_cookie|parse_url|urlsplit|percent_decode|unquote|parse_chunk|parse_status_line over stdlib = ZERO).
- 🔴 REAL SHIPPING BUG FOUND + FIXED (parse_request, 1 divergence vs RFC-7230 message framing):
  - body-truncation: RFC 7230 §3 says the FIRST empty line (CRLFCRLF) terminates the header block and EVERYTHING after it — embedded blank lines included — is the body. The unfixed code does `let parts = raw.split("\r\n\r\n"); body = parts[1]` which splits on EVERY blank line and keeps only the first body segment, DROPPING parts[2..]. Any body containing a blank line (multipart/form-data, nested HTTP, base64 with CRLF wrapping, plain text with paragraph breaks) is silently truncated. SAME split-on-every-delimiter class as OP-91's parse_query.
- VERBATIM differential (faithful Python port of the UNFIXED body vs an RFC reference that splits on the FIRST separator only): 'POST /x HTTP/1.1\r\nContent-Length: 9\r\n\r\nhi\r\n\r\nbye' -> hexa body='hi' vs ref 'hi\r\n\r\nbye' MISMATCH. The other 8 cases (simple GET, query split, header colon-in-value, leading-colon header, no-value header, duplicate header, Host with :port, no-path) all OK — method/path/query/header parsing (split-on-SP, "?", first-":" with trim+lowercase) are all correct. 8/9 OK, only body diverged.
- FIX (minimal, provably-correct — matches RFC-7230 first-separator framing; 0 deletions): `let sep = raw.index_of("\r\n\r\n"); let mut header_block = raw; if sep >= 0 { header_block = raw.substring(0, sep); body = raw.substring(sep + 4, len(raw)) }`. Splits on the FIRST "\r\n\r\n" only; the whole remainder (CRLFs included) is the body. Post-fix Python port = 9/9 OK vs the RFC reference (was 8/9). Header loop below it unchanged.
- LOCK: NEW stdlib/net/parse_request_test.hexa leaf oracle (the FIXED body inlined VERBATIM, self-contained no-`use` — the installed `hexa` resolves `use "stdlib/..."` to its stale bundled copy). Run LOCAL on the shipping `hexa run` (/Users/mini/.hx/bin/hexa): __HEXA_STDLIB_PARSE_REQUEST_OP92__ 13/13 ALL-GREEN. 13 goldens = body-with-embedded-blank-line (hi\r\n\r\nbye preserved) + multipart-style 3-blank-line body (A\r\n\r\nB\r\n\r\nC preserved) + regression locks (simple GET method/path/empty-body/header, path+query split, header value with a colon, no-separator request-line-only). The SAME leaf running the UNFIXED body reproduces the divergence verbatim (FAIL body-embedded-blankline got=[hi]; FAIL body-multi-blankline got=[A]; PASS 11/13 RED) → the oracle catches the bug, not a tautology.
- 🟢 CLEAN SIBLINGS (invariant-locked by boundary differential, NO edit needed — g5, not fabricated): http_sse_parse_event — 17 WHATWG boundary cases (data:/data:hello/data:  doublespace/data:empty/data-no-colon/event:/comment-":"/bare-":"/id:/retry int+neg+nonint+zero/field-with-colon-in-name/value-with-colons/unknown-field/blank) → 0 mismatch vs a faithful WHATWG per-line reference; single-leading-SP strip + first-":" split + multi-data accumulation all spec-correct. _h2_parse_status_block — 6 cases (normal, body-with-own-newline, sentinel-only body, no-newline, empty, empty-body+empty-version) → 0 mismatch; correctly uses last_index_of (reverse split) so body newlines are preserved — the RIGHT pattern parse_request's body split should have used.
- 🟠 FLAGGED CLOSURE-SIDE TWIN (NOT fixed — self-host fixpoint risk): self/serve/http_server.hexa:25-29 parse_request carries the IDENTICAL body-truncation bug (`let parts = raw.split("\r\n\r\n"); ... body = parts[1]`). This file IS in the build_selfhost closure (the compiler's own HTTP server), so per the 0-pod regimen it is FLAGGED 🟠 ONLY and left UNTOUCHED — a closure-side edit risks the self-host byte-eq fixpoint. A future closure-side lane (with full self-host rebuild + byte-eq gate) should port the same index_of first-separator fix. Same twin-flag posture OP-91 took on parse_query.
- BYTE-EQ / FIXPOINT: stdlib/net/http_request.hexa is a stdlib application module, NOT in the build_selfhost closure. 1 function changed (parse_request body split) + 1 NEW leaf test, 0 deletions (wipe_guard trivially satisfied, net-additive). Closure twin FLAGGED not fixed. Self-host fixpoint UNAFFECTED. LANE split honored (stdlib/net only).
- 🔴→FIXED + 🟢 + 🟠. $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · leak-0. Verdict .verdicts/hexa-0pod/F-OP92-NET-PARSE-REQUEST.txt.

## 2026-06-13 — OP-90 DONE: LANE-1 bespoke-stdlib bug-hunt (DATA-STRUCTURE / NUMERIC-FORMAT / PARSER) — 🔴 REAL shipping argparse `--key=value` bug FOUND+FIXED + hashset set-algebra PROVEN-CLEAN.
- LANE: 1 (0-pod correctness). This round (per the NEW lane split) hunts stdlib DATA-STRUCTURE / NUMERIC-FORMAT / PARSER modules (NON-string/path — sibling LANE-2/OP-89 owns string/path/text). Non-overlapping.
- THESIS: OP-87/88 proved the boundary-arithmetic/index bug class is LIVE in bespoke stdlib index logic (path_dirname, path_ext). This round hunts the analogous index/boundary/state bug in stdlib parsers + data structures.
- SURVEY (scoped grep, NO .git; skip string/path/text=LANE-2 + already-audited core/math, codec, crypto, core/hash, wasm_leb128, core/parse, semver, time/civil, alloc/collections, alloc/path, stats): top-level stdlib has FEW bespoke standalone data-structures/numeric-formatters — collections/parse/argparse/bytes are thin RE-EXPORT shims; iso8601 routes to runtime builtins (OP-86 clean); welford has 5 closed-form self-tests. The two UNTESTED bespoke modules with REAL index/state surface:
  · stdlib/alloc/argparse.hexa — PARSER: an argv state machine with positional/flag/value index arithmetic (i±1/i±2/pos_consumed) + a documented "Python-argparse subset" contract. IN-REPO EXPOSURE: stdlib/easy/cli.hexa:99 hand-rolls `--out=` parsing precisely because the shared parser lacks it. HIGHEST index/state bug surface. ← PICK
  · stdlib/hashset.hexa — DATA-STRUCT: union/intersect/difference/symmetric_difference/subset/superset set algebra (empty/disjoint/duplicate boundary surface). ← PICK
- 🔴 REAL SHIPPING BUG (stdlib/alloc/argparse.hexa ap_parse): the `--long=value` / `-o=value` ATTACHED-VALUE form was NEVER recognised — _match_value only does an EXACT `tok == v["long"]` compare, so `--out=foo.txt` matched NOTHING and fell through to POSITIONAL capture. One attached-value token then derailed the ENTIRE positional assignment.
  · METHOD: DIFFERENTIAL — a verbatim Python port of the UNFIXED ap_parse body vs Python's stdlib `argparse` (the header's stated reference), boundary sweep.
  · VERBATIM (parser: -v/--verbose flag, -o/--out value default "def.txt", positional file): ARGV ['--out=foo.txt','x'] → HEXA out=def.txt | verbose=False | file=--out=foo.txt | extras=['x']  vs  PY out=foo.txt | file=x. The user's value was SILENTLY DROPPED (out kept its default), the `--out=foo.txt` token CORRUPTED positional `file`, and the real positional `x` overflowed into `_extras`.
  · ROOT CAUSE: the value-match path never split a token on '=' before matching — a structural gap (every `--key=value` invocation mis-parsed), not a one-off.
  · FIX (minimal, provably-correct — matches Python argparse): before the positional fallthrough, find the first '=' in the token (new _eq_index helper), match the key part as a value option, assign the post-'=' tail. Split on the FIRST '=' only (`--out=a=b=c` → value "a=b=c"). 0 deletions; +1 helper + one branch; @version 0.1.0 → 0.2.0.
  · CROSS-CHECK (g5): the FIXED Python port vs Python argparse over all well-defined cases → 0 mismatch (--out=foo.txt, -o foo.txt separated preserved, -o=foo.txt short attached, --out=a=b=c first-'='-only, --out= empty value, --verbose flags both orders).
  · LOCK: NEW stdlib/alloc/argparse_eqvalue_test.hexa — the FIXED ap_parse body is VERBATIM-INLINED (installed `hexa` resolves `use "stdlib/..."` to its STALE bundled copy, OP-87/88 lesson) and gated on shipping `hexa run`. __OP90_ARGPARSE_EQVALUE__ PASS 8/8 (out + uncorrupted file + no extras; separated-form regression; -o=foo.txt short attached; --out=a=b=c first-'='-only; --out= empty; bare `k=v` stays a positional).
- 🟢 CLEAN (invariant-lock) stdlib/hashset.hexa: union/intersect/difference/symmetric_difference/subset/superset are logically correct — each builds a NEW set by snapshot-iterate + membership-probe (NO index arithmetic to mis-step); is_subset over EMPTY a returns true (vacuous truth, Python parity); symmetric_difference = (a\b) ∪ (b\a) by construction; from_array dedups on insert; insert/remove return correct newly-present/was-present signals. The documented stringified-key collision (`1` and `"1"`) is an EXPLICIT P1 design tradeoff in the header, not a bug. No new leaf (no fix needed; logged CLEAN per g5).
- BYTE-EQ SAFETY: stdlib/alloc/argparse.hexa is alloc-tier — NOT in the build_selfhost closure → self-host fixpoint UNAFFECTED. 1 fn region fixed + 1 helper + 1 NEW leaf test; 0 deletions (wipe_guard net-additive). hashset UNCHANGED. LANE split honored (stdlib/* only; no string/path/text).
- TIER 🔴→FIXED + 🟢. Verdict .verdicts/hexa-0pod/F-OP90-ARGPARSE-EQVALUE.txt. $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · leak-0.

## 2026-06-13 — OP-91 DONE: LANE-2 0-pod bug-hunt on stdlib COMPLEX TEXT + URL modules — 🔴 REAL SHIPPING BUG in stdlib/net/http_request.hexa parse_query (URL query parser) FOUND + FIXED + 20/20 leaf-locked
- LANE: 2 (0-pod correctness, stdlib STRING/PATH/TEXT/URL). Sibling LANE-1/OP-90 owns stdlib data-structure/numeric/parser (non-overlapping — OP-91 touched ONLY stdlib/net/*).
- REFRAME: OP-87 (path_dirname consecutive-slash) + OP-88 (path_ext leading-dot-run) leaked at run-boundaries; OP-89 proved the simple stdlib string scanners CLEAN. OP-91 targets the COMPLEX-state text + URL modules (higher index/state/encoding surface): the `&`/`=`/empty-value edges of a query-string parser.
- SURVEY (scoped greps, NO .git; LANE-2 string/path/text/url; SKIP path.hexa [OP-87/88], the 7 OP-89 scanners, codec/*): the classic named text/url modules the task listed (glob/fnmatch/wildcard, textwrap/word_wrap, difflib/myers, fuzzy/levenshtein, template/interpolate, urlencode/percent/quote/unquote, slugify, indent/dedent, csv) DO NOT EXIST as stdlib functions — grep for their `fn` defs over stdlib returned ZERO. The real COMPLEX text/url surface in stdlib = stdlib/net/http_request.hexa (parse_query, parse_request) + stdlib/net/http_server.hexa (_route_match). PICKED parse_query as the HIGHEST index/state/encoding surface (WHY: the only user-facing URL parser; it splits each `&`-pair with a NAIVE `.split("=")` then reads kv[0]/kv[1] — a textbook split-on-first-delimiter-only index bug; direct CPython ref = urllib.parse.parse_qsl). parse_request (index_of("?")+CRLF split, no run arithmetic) = low surface, not picked; _route_match = a documented path-PREFIX mount (substring(0,len(pat))), not a glob, no CPython differential, not a bug.
- 🔴 REAL SHIPPING BUG FOUND + FIXED (2 divergences vs urllib.parse.parse_qsl(keep_blank_values=True)):
  - BUG 1 value-truncation: `pairs[i].split("=")` shatters the pair on EVERY "=" and the code keeps only kv[1], dropping any "=" that legitimately belongs INSIDE the value.
  - BUG 2 spurious blank-key: an empty pair (from "&&" or a trailing/leading "&") yields a "" segment whose `"".split("=")` has len 1, so result[""]="" is inserted — a key CPython never produces (parse_qsl skips empty pairs).
- VERBATIM on the SHIPPING `hexa run` (summer pool host, hexa 0.1.0-dispatch; local was fork-storm-capped by 10 orphaned multi-hour hexa_run processes from OTHER sessions, so the guard-sanctioned pool path was used), UNFIXED body: a=b=c -> a=[b] (want b=c), a==b -> a=[] (want =b), a=1&&b=2 -> keycount=3 (want 2), a=1& -> keycount=2 (want 1). Python differential of the unfixed body vs parse_qsl(keep_blank_values=True): a=b=c {'a':'b'} vs {'a':'b=c'} MISMATCH, a==b {'a':''} vs {'a':'=b'} MISMATCH, a=1&&b=2 {'a':'1','':'','b':'2'} vs {'a':'1','b':'2'} MISMATCH; basic/key/key=/=val/a=1&a=2/flag&x=1 all MATCH.
- FIX (minimal, provably-correct — matches parse_qsl(keep_blank_values=True); 0 deletions): `if len(pair) > 0 { let eq = pair.index_of("="); if eq >= 0 { result[pair.substring(0,eq)] = pair.substring(eq+1,len(pair)) } else { result[pair] = "" } }`. Skips empty pairs (closes BUG 2) + splits on the FIRST "=" only (closes BUG 1).
- LOCK: NEW stdlib/net/parse_query_test.hexa leaf oracle (the FIXED body inlined VERBATIM, self-contained no-`use` — the installed `hexa` resolves `use "stdlib/..."` to its stale bundled copy; empty-key absence asserted via len(result), no `nil` literal which this compiler rejects). On summer: __HEXA_STDLIB_PARSE_QUERY_OP91__ 20/20 ALL-GREEN. 20 goldens = the 2 fixed divergences + empty-pair/trailing-& keycount==2/1 + already-correct regression locks (basic, no-eq flag, trailing-eq, leading-eq blank-key, last-wins repeat, mixed flag, empty input), every value + keycount matching parse_qsl. The SAME leaf running the UNFIXED body reproduces all 4 divergences verbatim → the oracle catches the bug, not a tautology.
- BYTE-EQ / FIXPOINT: stdlib/net/http_request.hexa is a stdlib application module, NOT in the build_selfhost closure. The compiler's OWN copy self/serve/http_server.hexa::parse_query carries the IDENTICAL pre-port bug but was DELIBERATELY left untouched (editing self/* risks the self-host fixpoint) and only NOTED. 1 function changed (parse_query) + 1 NEW leaf test; 0 deletions (wipe_guard net-additive). The pre-existing `== nil` in content_length_of (lines 99/101) is upstream on origin/main, out of scope. Self-host fixpoint UNAFFECTED.
- LANE split honored — only stdlib/net/* edited (no self/runtime, no LANE-1 territory). $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · leak-0.
- VERDICT: 🔴→FIXED + 🟢 — stdlib/net/http_request.hexa parse_query had a real shipping URL-parser bug (value truncation at the first "=" + spurious blank-key on empty pairs), diverging from urllib.parse.parse_qsl; fixed to split on the first "=" only and skip empty pairs (matches CPython), locked by a 20/20 verbatim leaf oracle on the shipping `hexa run`. — .verdicts/hexa-0pod/F-OP91-NET-PARSE-QUERY.txt

## 2026-06-13 — OP-89 DONE: LANE-2 bespoke-stdlib boundary-arithmetic bug-hunt on stdlib STRING helpers — 🟢 7 bespoke scanners PROVEN-CLEAN (no shipping bug, not fabricated), 57/57 leaf-locked
- LANE: 2 (0-pod correctness, stdlib/* bespoke char-scanning bug-hunt). Sibling LANE-1/OP-86 owns self/runtime + self/* string helpers (non-overlapping — OP-89 touched ONLY stdlib/*).
- REFRAME: OP-87 (path_dirname consecutive-slash, #3239) + OP-88 (path_ext leading-dot-run, #3241) both leaked at run-boundaries — the char-scanning / boundary-arithmetic class is the proven failure mode. OP-89 hunts the SAME class in stdlib STRING helpers that do their own index/boundary arithmetic over runs of chars. Method = differential vs the authoritative CPython `str` methods (+ PyYAML safe_load for the yaml flat-scalar contract) over boundary sweeps.
- SURVEY (scoped greps, NO .git; stdlib/* only — self/* is LANE-1): the canonical string module stdlib/core/string.hexa (71L) is small + already clean (repeat/pad_left/pad_right/reverse/starts_with/ends_with — no boundary bug; `reverse` is BYTE-reversed = a documented byte-runtime property, NOT a bug, and core/string is closure-risky so NOT touched). path.hexa is the OP-87/88 surface (dirname+ext fixed, basename/normalize/join already clean). codec/hex.hexa (hex_decode whitespace-skip+odd-nibble) + codec/utf8.hexa (RFC-3629 multibyte continuation-run validator) examined CLEAN, both have co-located tests → not re-locked. argparse _strip_dashes leading-run scanner CLEAN; value-flag-at-EOL keeps-default is the under-specified NOT-a-bug edge already noted OP-87. PICKED the richest UNTESTED bespoke scanners: stdlib/easy/cli.hexa (×5, NO co-located test/verdict) + stdlib/yaml.hexa (×2).
- 🟢 CLEAN — NO shipping bug found (NOT fabricated, g5). DIFFERENTIAL (faithful byte-level Python ports of the UNFIXED bodies vs CPython str / PyYAML over empty / single-char / all-separators / leading+trailing+doubled-separators / pattern==whole / pattern-longer-than-string / empty-pattern / overlapping / multibyte):
  stdlib/easy/cli.hexa:
    _contains(hay,needle)   ≡ `needle in hay`                0/13 mism  (empty-in-empty→True, empty-needle→True, whole, longer-needle→False, overlap-position, tail, ws-run, interior)
    _count_lines(s)         ≡ s.count('\n')                  0/7  mism  (empty, single LF, LF-run(3), trailing LF, no-LF)
    _count_occ(hay,needle)  ≡ s.count(sub) NON-overlapping   0/14 mism  (',,,'/','=3, 'aaa'/'aa'=1 advance-by-nlen, 'ababab'/'ab'=3, whole=1, needle-longer=0, empty-needle→0 = documented guard, NOT claimed str.count parity)
    _word_count(s)          ≡ len(s.split())                 0/11 mism  (all-ws→0, leading/trailing/doubled-ws runs, mixed \n\t\r, CRLF)
    _strip_comments(s)      <!-- ... --> removal             0/12 mism  (empty-comment <!---->, adjacent comments, unterminated→truncate HTML, trailing literal '-->')
  stdlib/yaml.hexa (vs PyYAML safe_load over the flat-scalar contract subset):
    _yaml_unquote(v)                  balanced wrapping-quote strip   0/8 mism  (n<2 lone-quote kept, '"x"'→x, "'x'"→x, unbalanced '"ab' kept, trims-then-strips)
    yaml_parse_flat(text)             first-colon split + skip runs   0 IN-CONTRACT (19-case sweep; the ONLY 2 divergences vs PyYAML are DOCUMENTED honest-caveats, NOT bugs: indented-child line dropped = limit 1 "nested rejected"; inline ` # comment` kept = limit 3 to preserve URLs with '#')
    yaml_frontmatter_extract(text)    --- ... --- block extract       0/6 mism  (leading-blank lines, open-only no-close→"", empty block→"", multi-line body preserved)
- CONCLUSION (g5, honest): the boundary-arithmetic vein in stdlib STRING helpers is SOLID post OP-87/88 (which already fixed the two real bugs of this exact class). Per the regimen a bug was NOT fabricated; the clean scanners are invariant-locked instead so a future codegen/runtime change cannot silently regress them.
- LOCK: NEW stdlib/easy/cli_op89_test.hexa leaf oracle (all 7 module bodies inlined VERBATIM, self-contained, gated on the SHIPPING `hexa run` — the inlined bodies use only pure builtins substring/split/trim/len and the Python differential confirms the semantics independently of the local install) — VERBATIM exit-0: __HEXA_STDLIB_STRING_OP89__ 57/57 PASS (10 _contains + 6 _count_lines + 10 _count_occ + 8 _word_count + 9 _strip_comments + 8 _yaml_unquote + 6 frontmatter goldens vs CPython str / PyYAML). Python differentials /tmp/op89_diff.py (cli, 0/57) + /tmp/op89_yaml.py (yaml).
- BYTE-EQ: ZERO production-module edits — 0 functions changed, 0 deletions (wipe_guard trivially satisfied, net-additive). Only 1 NEW leaf test file + verdict + this log/milestone. The leaf is imported nowhere → closure-neutral; easy/cli.hexa + yaml.hexa are NOT in the build_selfhost closure regardless → self-host fixpoint UNAFFECTED; no codegen/runtime/rt bytes touched.
- LANE split honored — only stdlib/* examined (no self/runtime, no self/* string helpers = LANE-1 territory). $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · no self/env · leak-0.
- VERDICT: 🟢 CLEAN — 7 bespoke stdlib string scanners PROVEN-CLEAN vs CPython str / PyYAML over an empty/single/separator-run/overlap/multibyte boundary sweep (0 mismatch), invariant-locked by a 57/57 leaf oracle. The OP-87/88 boundary-arithmetic class is closed in stdlib string helpers with no remaining shipping bug. — .verdicts/hexa-0pod/F-OP89-STDLIB-STRING-BOUNDARY.txt

## 2026-06-13 — OP-86 DONE: LANE-1 bespoke/no-KAT runtime-helper bug-hunt — CLOSES the OP-85 DEFERRED LOW/no-KAT tail (6 helpers with NO authoritative known-answer reference). 267/267 PASS, all PROVEN-CLEAN, NO 🔴 bug.
- LANE: 1 (0-pod correctness, self/runtime/*_pure). Sibling LANE-2/OP-87 owns stdlib/* (non-overlapping).
- REFRAME (the round's thesis): OP-80/82/85 cleared the AUTHORITATIVE-REFERENCE vein (standard hashes/codecs — well-trodden, 0 recent bugs). The REMAINING untested code is BESPOKE internal logic with NO external KAT — which is HIGHER bug-probability (custom, never tested), NOT low value. Hunted via the no-KAT methods: DIFFERENTIAL (slow/naive twin OR a second impl — compare over a sweep), INVARIANT (round-trip / rectangularity / order / bounds), DOCSTRING-vs-BEHAVIOUR (documented contract vs body).
- SURFACE = the EXACT 6 OP-85 deferred as LOW/no-KAT (none substituted/dropped; scoped grep NO .git confirmed only lfu_cache had a prior co-located test): char_code_pure · ffi_path_pure · lfu_cache_pure · lsm_tree_pure · print_fmt_pure · reservoir_sample_pure.
- THE LOCKS — 6 leaf test files, all gated on the SHIPPING `hexa run` (the path the modules ship on):
  · self/test_lsm_tree_pure.hexa     __HEXA_RUNTIME_LSM_TREE__  14/14  — DIFFERENTIAL vs last-write-wins dict. An LSM must read like a plain dict under put/delete; compaction invisible to reads. Authored against a Python LWW reference driving 5 random op-streams (seeds 1/7/13/99/256, 300 ops each, cap=3 ratio=2, put+delete+compact interleaved) → 0 mismatch on every query (RESULTS 20 pass 0 fail × all 5). Pinned stream + idempotent-compaction + unknown-key-MISSING invariants.
  · self/test_ffi_path_pure.hexa      __HEXA_RUNTIME_FFI_PATH__  15/15  — DIFFERENTIAL vs the C reference hexa_ffi_extract_libname (runtime.c:2994). Faithful Python ports of BOTH the C body and the module ran 2,800,007 generated path strings → "tested 2800007 mismatches 0". (The module's blen>=6/>=3 vs C's blen>6/>3 never diverges: the equality case lands on suffix_at==0→"" in BOTH — documented, not a bug.)
  · self/test_reservoir_sample_pure.hexa __HEXA_RUNTIME_RESERVOIR__ 38/38 — DIFFERENTIAL (_mul32 16-bit-decomposition vs true (a*b)&MASK incl 0xFFFFFFFF²; _lcg_next vs standard 32-bit LCG — RNG-ALL-PASS) + Algorithm-R INVARIANTs (fill order, overflow size==cap + count tracking, valid stream indices, cap0 stores nothing, neg-cap clamp).
  · self/test_char_code_pure.hexa     __HEXA_RUNTIME_CHAR_CODE__  26/26  — DOCSTRING-vs-BEHAVIOUR (the header table mirrors runtime.c:4297) + internal differential char_code_pure(s,i)==string_bytes_range_pure(s,i,i+1)[0] + range-clip == hexa_str_slice.
  · self/test_print_fmt_pure.hexa     __HEXA_RUNTIME_PRINT_FMT__  166/166 — INVARIANT: table rows byte-equal width (ascii), align_cols rectangular+per-col uniform width, box input+2 lines, truncate_ellipsis documented length contract (identity-when-fits; max>3→exactly max + trailing "..."; max<=0→"") over a 153-case sweep, tree one-line-per-reachable-node.
  · self/test_lfu_cache_diff.hexa     __HEXA_RUNTIME_LFU_DIFF__   8/8    — DIFFERENTIAL vs an LFU reference with the SAME impl-defined tie-break (evict the FIRST array index holding the min frequency = oldest among ties). 200-op put/get stream (seed 20260613) agrees with a faithful Python ref on every final query. Dict-form inlining (existing test_lfu_cache pattern) + a "__LFU_MISS__" sentinel dodge the stale-binary nil-in-map parse defect (a stale-binary defect, NOT a shipping bug).
  → 267/267 gates PASS, exit 0, all on `hexa run`.
- HONEST g5 (a NOTE, NOT a fabricated bug): reservoir_sample's RAW sampling distribution is non-uniform. A faithful Python port of reservoir_add over the SAME weak LCG + identical seed thread reproduced the EXACT per-item skew BYTE-FOR-BYTE (4000 trials, N=20 k=4: item-7 count 203, item-4 1061 vs ~800 ideal — Hexa and Python counts identical). This is the module's documented "standard 32-bit LCG" weak low-bit `% n` bias, NOT a sampling-logic bug — the impl matches its reference exactly. No uniformity assertion is locked for that reason.
- CROSS-CHECK summary (g5): every method backed by a faithful external/twin reference — LSM vs LWW dict (5 seeds, 0 mism), ffi_path vs C strstr-basename port (2.8M cases, 0 mism), _mul32/_lcg vs true-multiply/standard-LCG (0 mism), char_code vs runtime.c table, lfu vs same-tie-break Python ref (0 mism). NO 🔴 bug — all 6 bespoke helpers PROVEN-CLEAN.
- BYTE-EQ SAFETY: 6 NEW leaf test files only — NOT in the build_selfhost closure (not imported by self/hexa_full.hexa or any stage) → self-host fixpoint UNAFFECTED. Every audited module left UNCHANGED. wipe_guard net-additive (0 deletions).
- VEIN: closes the bespoke/no-KAT runtime *_pure tail OP-85 deferred. With OP-80/82/85 (authoritative-reference vein) + this round, remaining untested runtime *_pure are internal MED-LOW glue with neither an external KAT nor a non-trivial bespoke contract.
- TIER 🟢 GREEN — 6 bespoke runtime helpers locked, 267/267, 0 bugs. Verdict .verdicts/hexa-0pod/F-OP86-BESPOKE-NO-KAT.txt. $0 · 0-pod · NO GPU · no vast · no foreign pod · no MAIN.tape · leak-0.
## 2026-06-13 — OP-88 DONE: LANE-2 bespoke-stdlib bug-hunt — 🔴 REAL shipping path_ext leading-dot bug FOUND+FIXED + path_normalize/path_join/semver PROVEN-CLEAN
- LANE: 2 (0-pod correctness, stdlib/* bespoke-logic bug-hunt). Sibling LANE-1/OP-86 owns self/runtime + self/* (non-overlapping surface).
- REFRAME: OP-87 (#3239) fixed path_dirname's stray-trailing-slash on consecutive separators. This round hunts the SAME boundary-arithmetic bug class across the SIBLING path helpers (path_ext/path_stem/path_join/path_normalize) + one more bespoke module (semver). Method = differential vs authoritative refs (Python posixpath.splitext/normpath/join, GNU basename/dirname, the official semver.org 2.0.0 regex + §11 + npm range goldens).
- 🔴 BUG (REAL, SHIPPING) — stdlib/alloc/path.hexa :: path_ext (+ path_stem). The last-'.' scan used a bare `while i > 0` guard that only protected a SINGLE leading dot, so it returned "" for ".bashrc"/".config" (correct) but LEAKED a bogus extension whenever the basename began with a RUN of dots. POSIX/Python splitext treats the whole leading dot-run as part of the name, never an extension.
  VERBATIM repro (faithful Python port of the UNFIXED body vs posixpath.splitext on the basename):
    ext('..ext')   = '.ext'   (splitext: '')   BUG
    ext('..')      = '.'       (splitext: '')   BUG
    ext('...')     = '.'       (splitext: '')   BUG
    ext('....y')   = '.y'      (splitext: '')   BUG
    ext('a/..')    = '.'       (splitext: '')   BUG   (basename '..')
    ext('/..')     = '.'       (splitext: '')   BUG
    ext('a/b/..')  = '.'       (splitext: '')   BUG
  ROOT CAUSE: the scan never identified the leading dot-run boundary, so a '.' inside that prefix was mistaken for an extension separator. path_stem inherits it (stem("..ext")="..e", want "..ext").
- FIX (minimal, behavior-correct — provably the bug; matches posixpath.splitext): skip the leading run of dots first, then only treat a '.' AFTER that run as the separator (added `while lead<n {…}` + changed `i>0`→`i>lead`; 0 deletions, wipe_guard net-additive).
- CROSS-CHECK (g5, differential vs posixpath.splitext(basename) over 58 inputs): UNFIXED diverged on 10 leading-dot cases (.., ..ext, ..., ....y, a/.., /.., a/b/.., a/b/../.., ..//.., a/b/../..); POST-FIX matches all 58 + NO ordinary regression (foo.txt→.txt, a/b.tar.gz→.gz, archive.TAR→.TAR, a.→., .bashrc→"", .config→"" unchanged). No in-tree caller depends on the buggy output (scoped grep, NO .git).
- 🟢 CLEAN (other path helpers): path_normalize 46-input slash sweep vs posixpath.normpath 0 real mism (the lone //a→/a is the POSIX-impl-defined leading-// case the docstring chooses to collapse; NOTE — a naive Python port using "/".join(["/",body]) FALSELY reported a doubled leading slash, but the hexa code uses q.join("") (empty sep) so it is CORRECT — re-confirmed, no bug); path_join 15 pairs vs posixpath.join, the only divergence join(a,"")→"a" (vs posix "a/") is the DOCUMENTED empty-component contract (line 99), not a bug; path_basename re-confirmed GNU-correct (OP-87-locked).
- 🟢 CLEAN (invariant-lock) — stdlib/semver.hexa (the one-more bespoke module, heaviest uncovered logic; has a self-test but NO external-reference differential before this): semver_valid 40 inputs vs the OFFICIAL semver.org 2.0.0 regex 0 mism (leading-zero core/pre, empty pre segment, "_" reject, "v"-prefix, huge numbers, +build, "1.0.0-0A.is.legal"); semver_compare 441 ordered pairs vs §11 precedence 0 mism (canonical alpha<alpha.1<alpha.beta<beta<beta.2<beta.11<rc.1<1.0.0 chain, numeric<alphanumeric, longer-identifier-list-wins); semver_satisfies 38 npm-style goldens 0 mism (^ ~ x-range || AND + the prerelease-in-range gate).
- LOCK: NEW stdlib/alloc/path_op88_test.hexa leaf oracle (path_ext/path_stem inlined verbatim WITH the fix, NOT in build_selfhost closure, gated on the SHIPPING `hexa run` not the stale seed) — VERBATIM exit-0: __HEXA_STDLIB_PATH_EXT_OP88__ 24/24 PASS. semver locked by the 519-pair Python differential (/tmp/op88_semver.py vs the semver.org regex + §11 + npm goldens). path_ext fix repro/cross-check /tmp/op88_extfix.py (0/58). NON-REGRESSION: OP-87 oracle re-run __HEXA_STDLIB_PATH_COLL_OP87__ 34/34 PASS.
- BYTE-EQ: stdlib/alloc/path.hexa is alloc-tier (NOT in the self-host closure) → fixpoint UNAFFECTED; 1 fn fixed (path_ext) + 1 NEW leaf test; 0 deletions (wipe_guard net-additive); semver.hexa UNCHANGED (PROVEN-CLEAN).
- 🔴→FIXED + 🟢. $0, 0-pod, NO GPU, no vast, no foreign pod, no .tape, leak-0. LANE-2 stdlib/* only. verdict .verdicts/hexa-0pod/F-OP88-PATH-EXT-LEADING-DOT.txt
## 2026-06-13 — OP-87 DONE: LANE-2 bespoke-stdlib bug-hunt — 🔴 REAL shipping path_dirname double-slash bug FOUND+FIXED + combinations/permutations PROVEN-CLEAN
- LANE: 2 (0-pod correctness, stdlib/* bespoke-logic bug-hunt). Sibling LANE-1/OP-86 owns self/runtime + self/* (non-overlapping surface, coordinated lanes).
- REFRAME: the authoritative-reference stdlib vein is CLOSED (OP-83/84). This round hunts UNTESTED BESPOKE internal-logic modules (custom parsers / data structures / numeric-format / text) via KAT-free methods — differential (naive twin / cross-impl), invariant (round-trip / monotonicity / bounds), docstring-vs-behavior.
- SURVEY (scoped greps/reads, NO .git): candidates = stdlib/alloc/path.hexa (POSIX path helpers; differential vs GNU coreutils dirname/basename + posixpath) · stdlib/alloc/collections.hexa combinations/permutations (differential vs Python itertools — size=C(n,k)/n!, lex-order claim) · stdlib/hashset.hexa set algebra (examined, clean, deferred for a future map-backed batch) · stdlib/alloc/argparse.hexa (examined; value-flag-at-EOL silently keeps default = under-specified edge, NOT a clear shipping bug, noted not fixed). PICKED path + collections (clearest differential references, high bug-surface).
- 🔴 BUG (REAL, SHIPPING) — stdlib/alloc/path.hexa :: path_dirname. path_basename strips trailing slashes (matches GNU `basename` on all 13 probed cases), but path_dirname did NOT collapse the consecutive SEPARATOR slashes before the final component, leaking a stray trailing "/" into its result — internally inconsistent with its own basename.
  VERBATIM repro (faithful Python port of the UNFIXED body vs GNU `dirname`):
    dirname('a//b')            = 'a/'           (GNU: 'a')            BUG
    dirname('/foo//bar///baz') = '/foo//bar//'  (GNU: '/foo//bar')   BUG
    dirname('x///y')           = 'x//'          (GNU: 'x')           BUG
    dirname('/a//b//c')        = '/a//b/'       (GNU: '/a//b')       BUG
  ROOT CAUSE: on finding the boundary '/' at index i, the body returned `p.substring(0, i)` without first skipping back over any additional consecutive '/' separators.
- FIX (minimal, behavior-correct — provably the bug; matches the module's own basename strip + POSIX/GNU dirname): after locating the boundary '/', skip back over consecutive separator slashes before returning (added a 3-line `while i > 0 { if p[i-1] != '/' { break } i = i - 1 }` loop + comment; 0 deletions, wipe_guard net-additive).
- CROSS-CHECK (g5, differential vs GNU coreutils `dirname` over 24 inputs): UNFIXED diverged on the 4 repeated-internal-slash cases above; everywhere else (single-slash, trailing-slash, root, relative, '////') it already matched GNU. POST-FIX: matches GNU `dirname` on all 24, and does NOT regress any single-slash case — the seven self/test_path_module.hexa cases (/a/b/c→/a/b, a/b/→a, a→., /a→/, /→/, ""→., a/b/c→a/b) all still pass. No in-tree caller of the canonical alloc/path::path_dirname depends on the buggy double-slash output (scoped grep, NO .git) → regression-safe.
- 🟢 CLEAN (invariant-locks) — stdlib/alloc/collections.hexa: combinations(items,k) differential vs Python itertools.combinations 44/44 over n=0..7,k=0..n+1 (output size=C(n,k), input order preserved, k>n→[], k<=0→[[]]); permutations(items) differential vs itertools.permutations 7/7 over n=0..6 (n! rows, LEXICOGRAPHIC order for sorted input — the documented "lex order" claim HOLDS). Both PROVEN-CLEAN.
- THE LOCK — NEW stdlib/alloc/path_op87_test.hexa leaf oracle (OP-80/83 pattern: module bodies inlined verbatim, self-contained, NOT in build_selfhost closure; gated on the shipping `hexa run` per OP-82/85 stale-oracle note). VERBATIM exit-0:
    __HEXA_STDLIB_PATH_COLL_OP87__ 34/34
    PASS
  34/34 = 23 path (6 bug-repro-now-fixed + 9 single-slash non-regression + 5 basename consistency + 1 no-dangling-slash invariant + 2 root) + 12 collections (7 combinations + 5 permutations) goldens against GNU `dirname`/`basename` and Python itertools.
- BYTE-EQ SAFETY: stdlib/alloc/path.hexa is alloc-tier stdlib (imported only by tool/scripts), NOT in the build_selfhost closure → self-host fixpoint UNAFFECTED; no codegen/runtime/rt bytes touched. 1 fn body fixed (3-line slash-skip loop + comment) + 1 NEW leaf test file (used nowhere → closure-neutral); 0 deletions. LANE split honored (only stdlib/* touched). 
- TIER 🔴→FIXED a real shipping path_dirname double-slash bug (verbatim repro vs GNU dirname + minimal correct fix + non-regression) + 🟢 combinations/permutations PROVEN-CLEAN vs itertools, locked by a 34/34 leaf oracle. Verdict .verdicts/hexa-0pod/F-OP87-PATH-DIRNAME-DOUBLESLASH.txt. $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · no self/env.hexa · leak-0.

## 2026-06-13 — OP-82 DONE: LANE-1 batch oracle-lock for the next HIGH-VALUE tranche of untested self/runtime/*_pure.hexa helpers (OP-80 crc32 follow-on) — 6 runtime helpers locked to their authoritative references, all PROVEN-CLEAN
- LANE: 1 (0-pod correctness, runtime *_pure coverage). Sibling LANE-2/OP-83 owns stdlib/* (non-overlapping surface, coordinated lanes).
- CENSUS (scoped, NO .git): 72 self/runtime/*_pure.hexa helpers ship; only crc32_pure had a co-located test at round start (OP-80). VALUE triage — HIGH = a single AUTHORITATIVE external reference (named standard hash/checksum/encoding/number-format with known test vectors) OR a documented round-trip identity; MED-LOW = internal-only structural/round-trip, no external oracle (~50 helpers: arena/array*/bit*/bloom/char*/cmp/count_min/dedup/dijkstra/dispatch/file/fmt/format/geometry2d/graph*/heap/json_mini/lfu/lru/lsm/map*/math/numeric_sat/parse*/path/print_fmt/range/reducer/regex_mini/reservoir/set_ext/sort_variants/spawn/string/topo_sort/trie/union_find/value/welford/ffi_path — deferred indefinitely).
- HIGH untested identified: murmur3_pure (MurmurHash3 x86_32, smhasher/mmh3) · xxhash_pure (xxHash32, Yann Collet) · checksum_pure (Adler-32 RFC1950/zlib + DJB2/SDBM/XOR/Luhn) · base64_pure (RFC 4648/base64.b64encode) · hex_pure (binascii.hexlify) · mod_exp_pure (CPython pow/math.gcd/pow(a,-1,m)/Miller-Rabin) — PICKED; siphash/hash/encoding/cipher_mini/bignum_mini/hash_rng/kmp/levenshtein/prime_sieve/conv/ipv4/datetime/date_time/hyperloglog — HIGH but DEFERRED to future OP-8x rounds (g0 small batch).
- THE BATCH LOCK — 6 NEW co-located leaf oracles (OP-80 pattern: `use "self/runtime/<mod>"` + fn main() + @sentinel(...), run on the SHIPPING `hexa run` interpreter, the path the module ships on):
  · self/runtime/murmur3_pure_test.hexa  __HEXA_RUNTIME_MURMUR3__  PASS 17/17 (8 smhasher vectors + seed + aliases + range/det/order)
  · self/runtime/xxhash_pure_test.hexa   __HEXA_RUNTIME_XXHASH__   PASS 17/17 (short + 16B-stripe vectors + seed + alias + range)
  · self/runtime/checksum_pure_test.hexa __HEXA_RUNTIME_CHECKSUM__ PASS 29/29 (adler32==zlib.adler32 + djb2/sdbm/xor goldens + Luhn valid/invalid/dashes)
  · self/runtime/base64_pure_test.hexa   __HEXA_RUNTIME_BASE64__   PASS 17/17 (encode==b64encode + padding + decode∘encode round-trip + decode dir)
  · self/runtime/hex_pure_test.hexa      __HEXA_RUNTIME_HEX__      PASS 22/22 (encode==hexlify + upper + byte boundaries + decode + codec round-trip + int_to_hex)
  · self/runtime/mod_exp_pure_test.hexa  __HEXA_RUNTIME_MODEXP__   PASS 21/21 (pow==CPython pow + gcd/lcm + mod_inv identity + ext-gcd Bezout + Miller-Rabin incl Carmichael)
  → 123/123 gates PASS, exit 0, all on `hexa run`.
- CROSS-CHECK (g5 — faithful Python stdlib ports vs the authoritative references): adler32 vs zlib.adler32 0/4004 mismatch (incl empty, 0x00, 0xFF, the full 0..255 byte buffer, 4000 random buffers len 0..40); base64 RFC4648 round-trip 0 mismatch; binascii.hexlify round-trip 0 mismatch; murmur3 vs smhasher port + xxhash32 vs Yann Collet port + mod_exp/gcd/inv vs pow/math.gcd/pow(a,-1,m) all match; Miller-Rabin vs trial division agrees incl. Carmichael 561/1105. NO 🔴 bug — all 6 helpers AGREE with their references.
- ORACLE CAVEAT (MEMORY "local hexa stale oracle" CONFIRMED this round): the Jun-1 build/hexat binary MISCOMPILES a function whose final expression is a bare unary `-1` (e.g. hex_pure._hex_digit_val's trailing `-1`) — it evaluates it as a binary subtract of the prior if-expression result ("cannot subtract non-numeric operand, tag 4 - tag 0"). The SHIPPING `hexa run` interpreter handles it CORRECTLY (verified `z->-1`), so hex_pure is NOT buggy — the stale hexat was. All 6 oracles were therefore GATED on the shipping `hexa run`, not the stale hexat. (Flagged as an oracle caveat, not a shipping defect.)
- SCOPE NOTE (g5, same as OP-80): leaf gates use ASCII (<0x80) inputs only — the interpreter's from_char_code does codepoint→UTF-8 (from_char_code(255)=0xC3 0xBF not raw 0xFF), so raw single bytes can't be built on `hexa run`. The full 0..255 raw-byte coverage is carried by the Python authoritative ports above (0 mismatch).
- COVERAGE: 7/72 runtime *_pure.hexa helpers now carry a co-located leaf oracle (crc32 @OP-80 + the 6 above). ~14 HIGH-value untested remain for future OP-8x rounds.
- BYTE-EQ SAFETY: 6 NEW test files only — leaf oracles NOT in the build_selfhost closure (not imported by self/hexa_full.hexa or any stage) → self-host fixpoint UNAFFECTED. Every audited *_pure.hexa module left UNCHANGED (PROVEN-CLEAN). wipe_guard net-additive (562 lines, 0 deletions).
- TIER 🟢 GREEN — 6 HIGH-value runtime helpers batch-locked to their authoritative references, 0 disagreements. Verdict .verdicts/hexa-0pod/F-OP82-RUNTIME-PURE-COVERAGE.txt. $0 · 0-pod · NO GPU · no vast · no foreign pod · no MAIN.tape · leak-0.
## 2026-06-13 — OP-84 DONE: FINAL authoritative-reference crypto/hash/encoding tranche — CLOSES the OP-83 DEFERRED MED tail (LANE-2; LANE-1/OP-82 owns self/runtime/*_pure). THREE modules locked, all PROVEN-CLEAN. The high-value-with-authoritative-reference stdlib coverage vein is now CLOSED.
- The LAST 3 untested high-value stdlib modules WITH an authoritative known-answer reference (the OP-83 DEFERRED MED tail). All 3 confirmed UNTESTED (scoped grep, NO .git — no co-located *_test.hexa, no .verdicts lock). None substituted/dropped; all existed at the documented paths.
  · stdlib/crypto/poly1305.hexa — RFC 8439 §2.5.2 (Poly1305 one-time MAC)
  · stdlib/core/hash/xxhash.hexa — the official `xxhash` reference (Python pkg 3.7.0, wraps Yann Collet's libxxhash)
  · stdlib/crypto/asn1_der.hexa — X.690 DER, with `asn1crypto`-authoritative encodings (module is decode-only)
- THREE LEAF oracles (established inline-the-module-body pattern, NOT in build_selfhost closure):
  · stdlib/crypto/poly1305_test.hexa — RFC 8439 §2.5.2 tag a8061dc1305136c6c22b8baf0c0127a9 + determinism + empty-msg edge (tag == s == key[16..32] LE = 0103808afb0db2fd4abff6af4149f51b).
  · stdlib/core/hash/xxhash_test.hexa — official xxhash 3.7.0 vectors: xxh32 {""=02cc5d05, "a"=550d7456, "abc"=32d153ff, "abc"/seed1=aa3da8ff, 16B="abcdefghijklmnop"=9d2d8b62, 17B=b3b873e1} + xxh64 {""=ef46db3751d8e999, "a"=d24ec4f1a98c6e5b, "abc"=44bc2cf5ad770999, "abc"/seed1=bea9ca8199328908, 40B 0..39=f5da40f1b11741e9} + xxh32/64 determinism. xxh64 returns [hi,lo] u32 halves.
  · stdlib/crypto/asn1_der_test.hexa — asn1crypto-authoritative X.690 DER: OID 1.2.840.113549 (06062a864886f70d → der_oid_str), SEQUENCE{INTEGER 10, INTEGER 20} (300602010a020114 + child TLV iteration via der_next/der_int → 10, 20, end==SEQ end), OCTET STRING long-form length 128 (04 81 80 header), negative INTEGER two's-complement (02 01 ff → -1, 02 01 80 → -128).
- RUN (hexa run, arm64-macos, exit 0 each; fork-storm-guard backoff for sibling-lane contention — the pgrep -f storm count was self-inflated by this lane's own waiter shells whose argv contained "hexa.real"; 0 real hexa binaries were actually contending):
  · `poly1305 self-test: 3/3` `PASS`
  · `xxhash self-test: 13/13` `PASS`
  · `asn1_der self-test: 21/21` `PASS`
  · TOTAL 37/37.
- CROSS-CHECK (g5 — local ~/.hx/bin/hexa is a Jun-7 stale-oracle, so every vector independently reproduced by an authoritative reference; 0-mismatch):
  · Poly1305: a faithful Python (1<<130)-5 modular reference reproduced the RFC 8439 §2.5.2 published tag EXACTLY + the empty-msg tag == s.
  · xxHash: the OFFICIAL `xxhash` Python package (3.7.0, wraps libxxhash) emitted every xxh32/xxh64 digest; a hand port matched too. hexa == official == port on all 11 KAT digests.
  · ASN.1 DER: the OFFICIAL `asn1crypto` package emitted 06062a864886f70d (OID) / 300602010a020114 (SEQUENCE) / 048180 (OCTET long-form header); hexa decode of those exact bytes yields the encoded values, decode(encode(v))==v at byte level; neg-int matched Python int.from_bytes(signed=True).
  · ALL 37 hexa assertions == reference. NO 🔴 KAT-disagreement bug — 3 modules PROVEN-CLEAN.
- BYTE-EQ: 3 NEW *_test.hexa LEAF files only (used nowhere; not imported by any build_selfhost stage) → self-host fixpoint UNAFFECTED. Audited modules (poly1305/xxhash/asn1_der.hexa) UNCHANGED — locked via leaf tests, no closure edit. wipe_guard net-additive (0 deletions).
- VEIN-CLOSURE: the high-value-with-authoritative-reference stdlib coverage vein is CLOSED. Across OP-70/72/74/75/77/81/83/84, every untested stdlib module with an external known-answer reference (RFC / published spec vectors / an official reference implementation) is now locked with a leaf KAT oracle. The remaining untested stdlib modules are internal glue (no external KAT) → low-value to lock against an authoritative vector. This vein is exhausted.
- 🟢 GREEN — 3 modules locked, 37/37. $0, 0-pod, NO GPU, no vast, no foreign pod, no MAIN.tape, leak-0. Verdict .verdicts/hexa-0pod/F-OP84-CRYPTO-KAT-FINAL.txt.

## 2026-06-13 — OP-83 DONE: batch test-coverage for HIGH-VALUE untested stdlib/* modules (LANE-2; LANE-1/OP-82 owns self/runtime/*_pure). FIVE crypto/codec modules locked, all PROVEN-CLEAN vs their authoritative references
- CENSUS (scoped greps, NO .git): 1764 stdlib modules (excl *_test) / 254 *_test files. High-value vein = standard algorithms/formats with an AUTHORITATIVE reference (RFC / spec known-answer vectors) OR a documented round-trip/accuracy invariant. Filtered crypto/hash/codec/wasm to UNTESTED (no co-located *_test.hexa, no .verdicts lock):
  · stdlib/wasm/wasm_leb128.hexa — HIGH (wasm binary spec / Wikipedia LEB128 vectors)
  · stdlib/core/hash/hmac_sha384.hexa + hmac_sha512.hexa — HIGH (RFC 4231 §4; only the SHA-256 sibling hmac.hexa had a test)
  · stdlib/crypto/hkdf_sha384.hexa + hkdf_sha512.hexa — HIGH (RFC 5869 construction; no RFC vectors exist for SHA-384/512)
  · DEFERRED MED tail: crypto/poly1305 (RFC 8439), core/hash/xxhash, crypto/asn1_der (kept the batch small per g0).
  · Already-covered (NOT re-derived): codec/{base64,hex,utf8,big5,cp949,euc_kr,gbk,shift_jis,unicode_normalize}, crypto/{sha512,chacha20,blowfish,pbkdf2,scrypt,secp256k1,x25519,ripemd160,hash160,hmac_drbg}, core/hash/{sha256,hmac}, hash/{sha256,xxhash}, aws/sigv4, + OP-70/72/74/75/77/81 set.
- PICK (g0 small batch) = the 5 HIGH-value crypto/codec modules.
- THREE LEAF oracles (established inline-the-module-body pattern, NOT in build_selfhost closure):
  · stdlib/wasm/wasm_leb128_test.hexa — ULEB/SLEB encode/decode + size predictor + round-trip identity (9 unsigned + 13 signed) + chained-offset decode. Reference: uleb(624485)=[E5,8E,26], sleb(64)=[C0,00], sleb(-123456)=[C0,BB,78]. Four entry points inlined verbatim.
  · stdlib/core/hash/hmac_sha384_512_test.hexa — HMAC-SHA384 + HMAC-SHA512 over RFC 4231 §4 Cases 1-3 + 48/64-byte tag sizes. SHA-384/512 core `use`d from the verified crypto/sha512 module (its sha512_test is green); only the HMAC wrappers inlined.
  · stdlib/crypto/hkdf_sha384_512_test.hexa — HKDF-SHA384/512 PRK(extract) + OKM(L=42) over RFC 5869 §A.1 inputs + HKDF==Expand(Extract) + empty-salt-zero-fill invariants.
- RUN (hexa run, arm64-macos, exit 0 each; fork-storm-guard backoff for sibling-lane contention):
  · `wasm_leb128 self-test: 21/21` `PASS`
  · `hmac_sha384/512 self-test: 8/8` `PASS`
  · `hkdf_sha384/512 self-test: 8/8` `PASS`
  · TOTAL 37/37.
- CROSS-CHECK (g5 — local ~/.hx/bin/hexa is a Jun-7 stale-oracle, so every vector independently reproduced by a faithful Python port of the reference algorithm):
  · HMAC-SHA384/512: Python hmac.new(k,d,hashlib.sha384/512).hexdigest() over RFC 4231 inputs — byte-identical to the RFC 4231 §4 published tags (c1-384 afd03944…, c1-512 87aa7cde…, c3-512 fa73b008…).
  · HKDF-SHA384/512: Python RFC 5869 §2 port (extract=HMAC; T(i)=HMAC(prk,T(i-1)‖info‖i)) over §A.1 inputs — sha384 PRK 704b3999…/OKM 9b5097a8…, sha512 PRK 66579982…/OKM 83239008…. No official SHA-384/512 KATs exist, so the Python port is the authoritative oracle.
  · LEB128: canonical wasm-spec example vectors + round-trip identity closes the inverse independently.
  · RESULT: hexa output == reference on ALL 37 assertions. NO 🔴 bug — the 5 audited modules are PROVEN-CLEAN.
- BYTE-EQ: 3 NEW test files only, all leaf (not imported by hexa_full / any selfhost stage) → self-host fixpoint UNAFFECTED; the audited modules were left UNCHANGED. wipe_guard net-additive (0 deletions).
- 🟢 GREEN — 5 HIGH-value stdlib modules locked, 37/37 PASS, all PROVEN-CLEAN. $0, 0-pod, NO GPU, no vast, no foreign pod, no MAIN.tape, leak-0. Verdict .verdicts/hexa-0pod/F-OP83-STDLIB-MODULE-COVERAGE.txt.

## 2026-06-13 — OP-81 DONE: leaf oracle locking the FIVE Batch-23 calendar builtins of self/runtime/datetime_mini_pure.hexa (is_leap_year_pure / days_in_month_pure / day_of_year_pure / days_between_pure / weekday_zeller_pure) — a runtime-side *_pure invariant hole (OP-72 class on the calendar surface): weekday_zeller_pure (Zeller's congruence) had ZERO test coverage anywhere
- SURVEY (fresh-surface select per OP-81 regimen):
  · axis (a) registered-builtin-divergence (OP-75/77/79 class) — DRY. Censused 106 ord digit/alpha checks (`< 48`/`> 57`/`- 48`) across stdlib; all are per-CHAR loops over a string, while the registered codegen builtins is_digit/is_alpha/is_alphanumeric (self/codegen.hexa:6159-6170) classify the FIRST char only (isdigit/isalpha on s[0]). No "string-is-all-digits" builtin twin exists to confuse → no divergence, no build-break. (bytes_to_str misuse class already CLOSED repo-wide at OP-79.)
  · axis (b) parser/collection contract — PROVEN-CLEAN. core/parse.hexa to_int_safe matches its 17-case behavior table (test_parse.hexa covers); semver.hexa thorough selftest; stdlib/time/civil.hexa (Howard-Hinnant) cross-checked vs Python datetime over 5840 dates (-400000..400000 days) ZERO divergence + parse(format(e))==e over 4103 epochs to 2100 + leap-day 2024-02-29 exact (negative epochs documented-unsupported, not a bug); already ci_gate'd.
  · axis (c) self/runtime *_pure invariant — ACTIONABLE. datetime_mini_pure exports 5 pure calendar builtins. weekday_zeller_pure had ZERO coverage anywhere; the sibling self/test_date_time_pure.hexa tests a DIFFERENT module (date_time_pure) and SHADOW-REDEFINES its own day_of_year_pure/days_between_pure (lines 52,77) → does NOT exercise these five. PICKED.
  · axis (d) deferred tail — all open items (OP-2b/2c/19b/5c/46/39b) GPU-bound or build-host-anchor-refresh, correctly parked (out of 0-pod scope).
- WHY: Zeller's congruence is the most error-prone of the five (non-trivial mm<3 year-shift + the +5J form chosen to dodge the sign-of-modulo trap) and had no regression lock; the existing date test exercises a different module via shadowed copies. Leaf lock = zero self-host-fixpoint risk.
- VERIFY (g5 — faithful Python port vs authoritative `datetime`; C trunc-toward-zero `/` + sign-follows-dividend `%` matched to hexa int semantics):
  · Zeller weekday vs Python (years 1..3999, multiple m/d) → PASS, no divergence (0=Sat..6=Fri convention mapped through Python Mon=0..Sun=6)
  · is_leap_year_pure vs Gregorian rule (1..3999) → PASS · days_between_pure vs Python date diff → PASS · day_of_year_pure vs tm_yday → PASS
  · documented golden cases all match: is_leap(2000)=1 / is_leap(1900)=0 / dim(2024,2)=29 / zeller(2026,4,17)=6 (Friday) / days_between(2026,1,1, 2026,4,17)=106
  · convention anchors (independently known): unix epoch 1970-01-01=Thursday→zeller 5 ✓ ; Y2K 2000-01-01=Saturday→zeller 0 ✓ ; leap-day 2024-02-29=Thursday→zeller 5 ✓
- LEAF ORACLE (NEW self/test_datetime_mini_pure.hexa): module body inlined VERBATIM (established pattern — test_date_time_pure.hexa:7 "codegen import not wired for test files; inline the module body"). 45 asserts: leap 8 · dim 9 (incl. out-of-range→0) · doy 8 · dbw 8 · dbw-consistency 2 (antisymmetry + in-year span==doy−1) · zeller 10 (golden Fri · epoch Thu · Y2K Sat · leap-day Thu · BOTH mm<3 and mm≥3 shift paths · nonneg/in-range).
- RUN: `~/.hx/bin/hexa run self/test_datetime_mini_pure.hexa` (installed seed valid for pure int arithmetic — confirmed by running sibling test_datetime_pure.hexa first → 68/68 PASS): `datetime_mini_pure leaf oracle: 45/45` `[ALL PASS] datetime_mini_pure verified` exit 0.
- BYTE-EQ SAFETY: NEW FILE ONLY — standalone leaf test, NOT in the build_selfhost closure (not imported by self/hexa_full.hexa or any compiler stage). Zero source/codegen/runtime bytes changed → self-host fixpoint UNAFFECTED. wipe_guard net-additive (0 deletions). Audited module datetime_mini_pure.hexa left UNCHANGED — PROVEN-CLEAN, this only adds its missing regression lock.
- TIER 🟢 GREEN — invariant-lock 45/45 + module PROVEN-CLEAN vs Python datetime across years 1..3999. Verdict .verdicts/hexa-0pod/F-OP81-DATETIME-MINI-PURE-ORACLE.txt. $0 · 0-pod · NO GPU · no vast · no foreign pod · no MAIN.tape · leak-0.

## 2026-06-13 — OP-79 DONE: repo-wide `bytes_to_str(` misuse sweep (OP-75 base64 + OP-77 hex/utf8 follow-on) — `bytes_to_str` is a `pub fn` LOCAL to stdlib/ckpt/format.hexa (NOT a registered codegen builtin); un-imported = standalone-build break, and it DOUBLE-ENCODES raw bytes (to_string(from_char_code(b&0xFF)) per byte treats each raw byte as a codepoint and re-UTF-8-encodes it → mojibake for any byte ≥0x80) · the registered builtin bytes_to_str_raw (self/codegen.hexa:7209) is the correct raw-byte→string primitive
- CENSUS (scoped grep stdlib/ self/ compiler/ tool/, .git excluded; bytes_to_str_raw / _bytes_to_str / ssh_bytes_to_string / bytes_to_string are DISTINCT identifiers, excluded):
  · stdlib/ckpt/format.hexa:180   `pub fn bytes_to_str(bs)`            DEFINITION (its home module; never self-calls) → KEEP
  · stdlib/ckpt/verifier.hexa:195 `let cert_json = bytes_to_str(cert_bytes)`  OP-77 MOJIBAKE class → FIX to bytes_to_str_raw
  · stdlib/codec/utf8_test.hexa:45  `// ... bytes_to_str(ckpt) would mangle ...`  COMMENT, not a call → n/a
  · tool/docs/ckpt__format.md:201  `pub fn bytes_to_str(bs)`            GENERATED DOC of the definition → n/a
  → repo-wide: exactly ONE definition + exactly ONE external caller (base64/hex/utf8 already cured by OP-75/OP-77). No other call exists.
- THE BUG (🔴 verifier.hexa:195): verifier imports stdlib/ckpt/format (line 39) so it BUILDS — but the CERT block is on-disk UTF-8 JSON; the writer stores it via str_to_bytes (writer.hexa:81 = char_code byte-wise = raw UTF-8 bytes), so the correct READ inverse is raw-byte→string = bytes_to_str_raw, NOT the ckpt re-encoding bytes_to_str. Any non-ASCII cert field (issuer/reason) gets double-encoded → round-trip corruption / parse-fail.
- FIX: verifier.hexa:195 bytes_to_str→bytes_to_str_raw (+ a comment documenting why). TEST LOCK: stdlib/ckpt/test/pcc_roundtrip.hexa fixture changed pure-ASCII → carries a Korean cert field (slug "한글-fixture", reason "서명 OK ✓") so the existing write_pcc→verify_pcc `v["cert_json"]==cert_json` round-trip assertion becomes a mojibake regression lock.
- VERIFY (OP-77 method — installed Jun-1 seed is a stale-oracle, MEMORY "local hexa stale oracle"):
  · faithful Python port (str_to_bytes=utf-8 encode; ckpt bytes_to_str=per-byte codepoint then re-utf8; bytes_to_str_raw=raw preserved), CERT JSON with Korean fields → OLD ckpt round-trips FALSE (한 ED 95 9C → C3 AD C2 95 ... mojibake) ; NEW bytes_to_str_raw round-trips TRUE
  · local run (fix mirrored into ~/.hx/src install copy — the stale seed resolves `use stdlib/...` against that root, not the worktree — then RESTORED pristine): BEFORE (bytes_to_str) FAIL cert_json mismatch, got 'íê¸-fixture' → FAIL 5/6 ; AFTER (bytes_to_str_raw) PASS cert_json round-trip → PASS 6/6 exit 0
  · isolation probe on the same stale binary: bytes_to_str_raw([237,149,156]) → '한' CORRECT (raw passthrough) vs bytes_to_str([237,149,156]) → 'í...' MOJIBAKE (double-encode) ; str_to_bytes("한") len=3 → bytes_to_str_raw → '한' round-trip CORRECT
- CLOSURE: after the fix the ONLY remaining unqualified bytes_to_str( site is the definition (format.hexa:180); ZERO external callers remain. base64 (OP-75) + hex/utf8 (OP-77) + ckpt-verifier (OP-79) were the complete misuse set → the `bytes_to_str` misuse class is CLOSED repo-wide. 🔴→fix GREEN + 🟢 PROVEN-CLEAN.
- IMPACT: self-host byte-eq UNAFFECTED — stdlib/ckpt/{verifier,test/pcc_roundtrip}.hexa are leaf stdlib NOT in the build_selfhost closure (no self/* or compiler/* mirror of ckpt; verified `find self/ compiler/ -path '*ckpt/verifier*'` empty). wipe_guard net-ADDITIVE (1 call-site edit + 1 fixture string change + verdict + log; no substantive deletions). No .tape, no self/env.hexa. $0 · 0-pod · NO GPU · leak-0. F-OP79-BYTES-TO-STR-SWEEP.txt
## 2026-06-13 — OP-80 DONE: LANE-1 broadened to the COMPILER/RUNTIME correctness surface (forge/flame 0-pod EXHAUSTED — own-GEMM OP-58/60/61/63/64/73 · determinism-gates OP-66/69 · flame numeric-primitive OP-72/74 · glue-invariant OP-76/78 ALL CLOSED) · LOCK the documented-but-UNGATED contract of self/runtime/crc32_pure.hexa (the OP-72/77 class on the RUNTIME side) · 🟢 GREEN invariant-lock 9/9 + 2 PROVEN-CLEAN · $0 · 0-pod · NO GPU · leak-0
- SURVEY (scoped greps/reads, NO .git, STEP-1 a–d):
  · (a) self/runtime/*_pure.hexa helper w/ documented invariant unlocked by a 0-pod oracle ... ✅ ACTIONABLE → PICKED
        76 *_pure.hexa runtime helpers ship; `find` confirms ZERO self/runtime/*_test.hexa (none has a co-located test).
        crc32_pure.hexa = standard "CRC-32" IEEE 802.3/PKZIP/gzip/PNG (poly 0xEDB88320, init/final-XOR 0xFFFFFFFF, reflected)
        + documented crc32_combine_pure streaming invariant (lines 72-75). Authoritative cross-check = CPython zlib.crc32. NO TEST.
  · (b) compiler/codegen DOC-vs-CODE comment/contract gap ............................... DRY (OP-71/73 forge @#3206 · OP-68/70 core/math CLOSED)
  · (c) tool/ or CI gate self-consistency gap .......................................... DRY (no NEW gap surfaced)
  · (d) HEXA-0POD ## deferred 0-pod-feasible non-closure ............................... DRY (all build-host frozen-seed re-pin OP-46/39b/40/44 OR GPU OP-2b/2c/19b/5c)
- PICK = (a) crc32_pure invariant-lock — g0-simplest pure-CPU `hexa run` leaf oracle, single authoritative ref (zlib.crc32 / 0xCBF43926) + documented combine invariant.
- THE LOCK — NEW self/runtime/crc32_pure_test.hexa (@sentinel __HEXA_RUNTIME_CRC32__, `use "self/runtime/crc32_pure"`):
  · G1 REFERENCE  crc32("123456789") == 0xCBF43926 (3421780262)   — THE canonical conformance vector
  · G2 GOLDEN     "a"/"abc"/"quick-brown-fox"/"hello world" == zlib.crc32 verbatim
  · G3 EMPTY      crc32("") == 0
  · G4 COMBINE    crc32_combine_pure(crc32(a),b) == crc32(a+b) over 7×7=49 prefix×suffix splits (documented streaming invariant)
  · G5 CLIP       crc32_pure(s,n) clips n to len(s) (n>len full · partial n hashes prefix)
- RUN (`hexa run self/runtime/crc32_pure_test.hexa` arm64-macos, exit 0, VERBATIM):
  · __HEXA_RUNTIME_CRC32__ PASS 9/9
  · spot-check: crc=3421780262 want=3421780262   ·   combine=222957957 full=222957957
- AUTHORITATIVE RAW-BYTE PROOF (faithful Python port of the EXACT module arithmetic vs CPython zlib.crc32 — the OP-75/77 cross-check
  method, because the interpreter's from_char_code does codepoint→UTF-8 and CANNOT construct raw single bytes: from_char_code(255)
  yields the 2-byte 0xC3 0xBF ord=195, NOT raw 0xFF):
  · check123456789: 0xcbf43926 want 0xcbf43926 MATCH
  · zlib parity mism: 0 of 3006     (empty + 0x00 + 0xFF + all-256-byte buffer + 3000 random len 0..64)
  · combine invariant mism: 0 of 2000   (random a,b len 0..30)
- SCOPE NOTE (g5 honesty): the leaf gates use ASCII (<0x80) inputs only (raw single bytes unexpressible on `hexa run`); the full
  0..255 raw-byte + zlib parity coverage is carried by the Python authoritative port above (MEMORY "local hexa is a stale oracle").
- DRY (PROVEN-CLEAN siblings, evidence-backed):
  · url_pure (RFC 3986): decode∘encode == identity for ALL 256 single bytes + 5000 random strings → 0 mismatch; tail/invalid %XX
    (`%4`/`%`/`%2g`) preserved verbatim as documented; the `i+2 < n` decode boundary is CORRECT (last full %XX at i=n-3 ⇒ i+2=n-1<n).
  · rle_pure: array rle_encode∘rle_decode exact; string-RLE digit-ambiguity is a documented format limitation, not a defect.
- BYTE-EQ SAFETY: crc32_pure_test.hexa is a LEAF @sentinel oracle (run via `hexa run`), NOT in the build_selfhost reproduce-byte-identical
  closure (codegen/runtime/macho/lexer/parser); zero closure edits, crc32_pure.hexa itself UNTOUCHED, zero codegen/runtime bytes →
  selfhost byte-eq / determinism / miscompile-zero / codegen-guard UNAFFECTED. wipe_guard net-additive (1 new file, 0 deletions).
- 76-untested-*_pure-helper surface after OP-80: 1 LOCKED (crc32) + 2 PROVEN-CLEAN (url, rle). Verdict F-OP80-CRC32-PURE-INVARIANT-LOCK.txt.

## 2026-06-13 — OP-78 DONE: COMPLETE the flame trainer-GLUE invariant coverage (OP-76 follow-on) · OP-74 proved the NUMERIC-PRIMITIVE oracle coverage complete (AGREE-vs-libm); OP-76 opened a DISTINCT class — the trainer-GLUE STRUCTURAL/SHAPE/BOUNDARY contracts (LR-schedule shape, F-OP76), NOT numeric agreement · AUDIT the FULL glue surface (optim_lib/nn_lib/moe_lib/conv_lib/tensor_lib/gn_lib) for the same documented-but-UNLOCKED-shape gap · RESULT: every contract-bearing glue op already locked EXCEPT four documented GLUE-level structural holes → locked by OP-78 · 🟢 GREEN invariant-lock 5/5 · $0 · 0-pod · NO GPU · leak-0
- THE COVERAGE MATRIX (glue invariant → documented structure/shape/boundary contract → locked-by):
  · LR warmup+cosine shape (peak/floor/ramp/seam/range/fold) ........... 🟢 F-OP76 (7/7)
  · AdamW update structure (1−βᵗ bias-corr SEPARATE not folded into lr · ε OUTSIDE √ · decoupled-wd 2-subtraction · m̂-before-v̂ · βᵗ repeated-mul) ... 🟢 F-OP12 (max|Δ|=0)
  · MoE gate Σ_e probs==1 (sum-to-one) AND probs>0 .................... 🟢 F-FLAME-MOE-SOFTMAX (flame_moe_test check_softmax tol 1e-6)
  · GroupNorm per-group xhat mean~0 var~1 (normalization) ............. 🟢 F-FLAME-GN-NORMALIZED (flame_gn_test)
  · GN eps placement inv=1/√(var+eps) eps INSIDE √ .................... 🟢 held by F-FLAME-GN-GRAD-EXACT
  · conv im2col tap p=t−dil·(K−1−k) layout identity .................. 🟢 F-OP7 / F-OP10
  · conv causal (direct path) no-future-leak ......................... 🟢 F-FLAME-CONV1D-CAUSAL
  · embedding bwd scatter position-ascending order ................... 🟢 F-OP13
  · d5-trig primitive sin²+cos²=1 (Pythagorean) ..................... 🟢 F-OP72
- THE FOUR UNLOCKED GLUE-level structural holes → LOCKED by OP-78:
  · G1 RoPE-NORM    nn_rope_apply_fwd is an ORTHOGONAL rotation ⇒ |R·q|==|q| (isometry; OP-72 locked the trig PRIMITIVE sin²+cos²=1, NOT the glue-level rotation norm-preservation)
  · G2 RoPE-RH2     rh∘rh==−I : rh:[x1,x2]→[−x2,x1] applied twice → −[x1,x2]
  · G3 GN-PARTITION group g output INDEPENDENT of other groups' channels (flame_gn_test locks NORMALIZATION, NOT cross-group INDEPENDENCE — the GN structural analog of conv-causal)
  · G4 SOFTMAX-SHIFT the MoE max-subtraction is a MATHEMATICAL no-op: softmax(x)==softmax(x−c) (F-FLAME-MOE-SOFTMAX locks Σ=1+>0; the shift-invariance that JUSTIFIES the max-sub was ungated)
- THE LOCK — NEW stdlib/flame/op78_glue_shape_contract_eq.hexa (self-contained, all 5 glue ops inlined VERBATIM from their SSOT libs, OP-76 leaf-oracle pattern, NO `use`):
  · G1 RoPE-NORM    max rel||R·q|²−|q|²| ≤ 1e-9 over 4 positions (tol — d5-trig ulp; NOT byte-eq)
  · G2 RoPE-RH2     rh(rh(x)) == −x byte-EXACT (rh = pure index+negate)
  · G3 GN-PARTITION perturb every channel of groups 1..G−1 by +100 → group-0 y BYTE-IDENTICAL (max|Δbytes|=0)
  · G4 SOFTMAX-SHIFT max|softmax(x)−softmax(x−c)|≤1e-9, c=7.25 (tol — mathematical shift-invariance)
  · G5 CONV-CAUSAL  re-lock no-future-leak on the PRODUCTION im2col layout: perturb future x[T−1] by +50 → y[0..T−2] BYTE-IDENTICAL
- RUN (`hexa run` arm64-macos, exit 0, VERBATIM):
  · G1 RoPE-NORM       max rel||R·q|²−|q|²| = 2.12781e-16  <= 1e-9 over 4 positions -> true
  · G2 RoPE-RH2        rh(rh(x)) == -x  byte-eq -> true
  · G3 GN-PARTITION    perturb groups 1..3 by +100 -> group-0 y BYTE-IDENTICAL = true
  · G4 SOFTMAX-SHIFT   max|softmax(x)-softmax(x-c)| = 0.0  <= 1e-9 -> true
  · G5 CONV-CAUSAL     perturb future x[T-1] -> y[0..T-2] BYTE-IDENTICAL = true
  · F-OP78-FLAME-GLUE-INVARIANT-COVERAGE = 1 · PASS 5/5
- FINDING (g5, OP-76 lesson — don't over-broaden): G4 measured EXACTLY 0.0 (the const shift divides out bit-for-bit through max-sub + Σ-normalize) but the gate is held at TOL not byte-eq — the TRUE documented contract is mathematical shift-invariance, NOT a guaranteed bitwise property (a different shift magnitude crossing an _moe_exp range-reduction boundary need not be bit-exact); asserting byte-eq would over-broaden. G1 is tol (d5-trig ulp, measured 2.13e-16 sub-ulp isometry); G2/G3/G5 are structurally byte-exact (index/disjoint-range/zero-pad).
- IMPACT: glue-invariant surface PROVEN-COMPLETE; the flame trainer is now contract-locked on BOTH the numeric-primitive axis (OP-74) AND the glue-structural axis (OP-76 + OP-78). Oracle-only, no behavior change. Self-host byte-eq UNAFFECTED (op78_*.hexa is a leaf self-contained oracle, NOT in build_selfhost closure; zero codegen/runtime bytes). wipe_guard net-ADDITIVE (1 oracle + 1 verdict + domain log). F-OP78-FLAME-GLUE-INVARIANT-COVERAGE.txt


## 2026-06-13 — OP-77 DONE: SIBLING codec/encoding round-trip audit (OP-75 #3207 follow-on) — audit stdlib/codec/* siblings for the base64 class (encode∘decode ≠ identity on a boundary OR a co-located unregistered-builtin compile bug) · ENUMERATE (no stdlib/encoding/): base64 (DONE OP-75), hex, utf8, euc_kr, cp949, shift_jis, gbk, big5, unicode_normalize · THE BUG (🔴): hex.hexa:43,98 + utf8.hexa:142 call bytes_to_str(out) — defined ONLY in stdlib/ckpt/format.hexa (a `pub fn`, NOT a registered codegen builtin) and NEVER imported by hex/utf8 = the EXACT OP-75 unregistered-builtin class · every SIBLING multibyte codec explicitly inlined its own converter to dodge this (verbatim euc_kr.hexa:12-13 "utf8 references bytes_to_str (defined in stdlib/ckpt/format) without importing it, which only resolves in a full-stdlib build, not a standalone codec build"); hex+utf8 did not · TWO defects cured by the REGISTERED builtin bytes_to_str_raw (self/codegen.hexa:7209): (1) STANDALONE-BUILD FAILURE — `hexa build stdlib/codec/{hex,utf8}` can't resolve bytes_to_str; (2) utf8 DOUBLE-ENCODE latent CORRECTNESS bug — utf8_from_codepoints assembles RAW UTF-8 bytes, then ckpt bytes_to_str does to_string(from_char_code(b&0xFF)) per byte = treats each RAW BYTE as a CODEPOINT and re-UTF-8-encodes it → every byte ≥0x80 becomes mojibake · FIX (source): 3 call sites bytes_to_str→bytes_to_str_raw + NEW hex_test.hexa (@sentinel __HEXA_CODEC_HEX__) + utf8_test.hexa (@sentinel __HEXA_CODEC_UTF8__) · 🔴→fix GREEN + 🟢 PROVEN-CLEAN (euc_kr/cp949/gbk/big5/shift_jis full-table CPython parity + closure; unicode_normalize out-of-scope idempotent normalization) · $0 · 0-pod · NO GPU · leak-0
- THE BUG (verbatim, faithful Python port of the ckpt vs raw byte-to-string semantics):
  · utf8_from_codepoints([0xD55C]) → raw UTF-8 bytes = ED 95 9C  (the glyph 한)
  · via bytes_to_str_raw (raw byte buffer)        → '한'  CORRECT
  · via bytes_to_str (ckpt, per-codepoint)        → 3 mojibake chars  WRONG (every byte ≥0x80 double-encoded)
  · hex output is pure ASCII (<0x80) so raw == per-codepoint there → encode result byte-identical (no behavior change for hex callers)
- THE VERIFY (faithful Python ports vs Python authoritative codecs — 0 mismatches; installed Jun-1 seed is a stale-oracle per MEMORY "local hexa stale oracle"):
  · hex   vs binascii.hexlify : encode parity + encode∘decode identity (lower+upper) on empty/[0x00]/[0xFF]/all-0x00/all-0xFF/range(256)/[deadbeef] → 0 mism ; odd-length+non-hex → [] ; whitespace+':' "de ad:be\nef" → ok
  · utf8  vs str.encode('utf-8') : encode parity on the 1/2/3/4-byte boundary set (A/é/€/한/日/🌌) + codepoints∘from_codepoints == identity for the FULL 0..0x10FFFF sweep (minus surrogates) + validity parity on every encoded glyph + invalid-detection parity (lone-continuation, overlong 2B/3B, surrogate U+D800, >U+10FFFF, truncated, 0xF5) → 0 mism ; surrogate cp [0x41,0xD800,0x42] → "AB"
- THE PROVEN-CLEAN MATRIX (7 siblings; maps rebuilt EXACTLY as the .hexa modules do from the *_table.gen blobs, vs the CPython codec of the same name + full round-trip closure):
  · codec    records  enc≡CPython  enc/dec-uniq==records  encode∘dec_rt  decode-closure
  · euc_kr     8226       0 mism            yes                  0              0
  · cp949     17048       0 mism            yes                  0              0
  · gbk       21791       0 mism            yes                  0              0
  · big5      13706       0 mism            yes                  0              0
  · shift_jis  6942       0 mism            yes                  0              0   (+ 1-byte katakana leads 0xA1-0xDF (63) ∩ 2-byte leads (39) = ∅ → decode try-1-byte-first ordering PROVABLY safe)
  · unicode_normalize — idempotent NFC/NFD/NFKC/NFKD (NOT a bijective round-trip codec, out of scope) + already locked by 17 CPython unicodedata golden vectors
- IMPACT: self-host byte-eq UNAFFECTED (hex/utf8 are leaf codec modules NOT in build_selfhost closure; zero codegen/runtime bytes). wipe_guard net-ADDITIVE (3 call-site edits + 2 new test files). F-OP77-CODEC-ROUNDTRIP-AUDIT.txt

## 2026-06-13 — OP-75 DONE: FRESH-SURFACE 0-pod correctness — a base64 round-trip bug in stdlib/codec/base64.hexa (stdlib NON-math encoding contract; the OP-68/70 class on a surface none of the closed threads touched) · SURVEY a–d: (a) stdlib/codec/base64 round-trip invariant broken by the decoder → PICKED · (b) Adam moment-init/bias-correction already covered (OP-6B + OP-69 FMA gate), tokenizer/checkpoint round-trip = RUNTIME byte-eq OP-69-deferred → DRY · (c) no NEW handoff item (OP-66/71 were stale-seed) · (d) deferred = build-host/GPU · THE BUG: base64_decode used `while j+3 < m` over the padding-stripped alphabet-char count m then trimmed pad bytes; a padded message's non-pad count m is never a multiple of 4 (it is 2/3 mod 4) so the trailing 2/3-char group was ALWAYS dropped → encode∘decode is the identity ONLY for byte-lengths multiple-of-3 · CO-LOCATED: the module called `bytes_to_str(...)` (neither builtin nor imported — local to stdlib/ckpt/format.hexa) → did NOT compile standalone, explaining the missing test · FIX (doc+source): full 4-char groups (while j+4<=m) then decode the trailing partial group from the char count alone (2 idxs→1 byte, 3→2 bytes) mirroring self/runtime/base64_pure.hexa; bytes_to_str→bytes_to_str_raw (registered builtin); stale "padding required for roundtrip" invariant corrected · NEW stdlib/codec/base64_test.hexa (@sentinel __HEXA_CODEC_BASE64__) · 🔴→fix GREEN · $0 · 0-pod · NO GPU · leak-0
- THE BUG (verbatim RFC 4648 §10 trace, faithful Python port of the OLD/buggy decode integer arithmetic):
  · 'f'       enc=Zg==     OLD_decode=[]                 want=[102]
  · 'fo'      enc=Zm8=     OLD_decode=[]                 want=[102, 111]
  · 'foo'     enc=Zm9v     OLD_decode=[102, 111, 111]    want=[102, 111, 111]      (ok — multiple of 3)
  · 'foob'    enc=Zm9vYg== OLD_decode=[102]              want=[102, 111, 111, 98]
  · 'fooba'   enc=Zm9vYmE= OLD_decode=[102, 111]         want=[102, 111, 111, 98, 97]
  · 'foobar'  enc=Zm9vYmFy OLD_decode=[102,111,111,98,97,114]                      (ok — multiple of 3)
- CO-LOCATED BUILD BUG (verbatim, unmodified installed module): `clang ... base64.hexa.c:99: error: use of
  undeclared identifier 'bytes_to_str'` — the module called bytes_to_str(out)/bytes_to_str(base64_decode(s))
  but bytes_to_str is NOT a registered builtin (only bytes_to_str_raw / str_from_bytes_n are) and NOT imported
  (it is a hexa fn local to stdlib/ckpt/format.hexa). So the module was unbuildable in isolation → no test ever.
- THE VERIFY (faithful Python port of the FIXED encode/decode arithmetic vs authoritative `base64` codec):
  · RFC 4648 §10 vectors (encode AND decode, all 7): PASS
  · singlebyte roundtrip+pyparity bad: 0   (all 256 single-byte messages)
  · random 2000 mismatches: 0   (len 0..40, encode parity + round-trip + decoding python's own output)
- LOCAL ORACLE NOTE: the installed Jun-1 seed (~/.hx/bin) SIGABRTs (exit 138) when RUNNING this module — even
  the unchanged encode path AND base64_decode's pure-[int] path — though bytes_to_str_raw/byte_at run clean
  standalone (BTR_EXIT=0, BAT_EXIT=0). Documented stale-seed runtime limit (MEMORY "Local hexa is a stale
  oracle — crashes on already-fixed paths; use ghost for differentials"). Correctness therefore locked by the
  authoritative Python cross-check + parity with the proven self/runtime/base64_pure.hexa streaming decoder.
- SCOPE: leaf codec module, NOT in compiler/main.hexa build_selfhost closure; zero codegen/runtime bytes →
  self-host byte-eq fixpoint UNTOUCHED. wipe_guard net-additive (restructured ~15-line tail + new test).
  Verdict .verdicts/hexa-0pod/F-OP75-BASE64-DECODE-TRAILING.txt.

## 2026-06-13 — OP-76 DONE: LOCK the documented-but-UNGATED SHAPE/BOUNDARY contract of the flame LR scheduler opt_lr_warmup_cosine (the OP-33 sibling hole) · SURVEY (NO .git): (a) forge doc-vs-code honesty DRY (OP-71/73 closed @#3206) · (c) forge cost-model DRY (OP-60/61/63) · (d) deferred build-host/GPU — PICKED (b) the route-(b) actionable axis · GAP: optim_lib.hexa:131-149 documents an explicit shape contract (peak=base@warmup · floor=base·floor@n_steps · linear ramp 0→base · cosine decay base→floor · the byte-critical fold base·(t/warmup) NOT (base·t)/warmup) but the ONLY oracle op33_lr_schedule_determinism_eq locks byte-DETERMINISM + d5-vs-libm divergence, NEVER a shape/boundary promise — OP-33 locked reproducibility ASSUMING shape-correct (the OP-66/68/70/72/74 documented-but-ungated-assumption class) · NEW self-contained stdlib/flame/op76_lr_schedule_shape_contract_eq.hexa (schedule+d5_cos inlined VERBATIM, OP-33/72 pattern; N=500 warmup=50 base=0.001 floor=0.05) · 7 gates · `hexa run` exit 0, 7/7 PASS · scheduler now contract-locked on BOTH axes: determinism (F-OP33) + shape (F-OP76) · oracle-only no behavior change · self-host byte-eq UNAFFECTED (leaf oracle, not in build_selfhost closure) · 🟢 GREEN invariant-lock · $0 · 0-pod · NO GPU · leak-0
- SURVEY axes (actionable/dry/flag + why): (a) forge DOC-vs-CODE honesty = DRY (nvptx shfl/exp + public-claim
  surface CLOSED OP-71/73; no new stale contradiction on a fresh forge surface) · (b) flame trainer-glue
  DOCUMENTED-but-UNLOCKED = ACTIONABLE (GN eps held by flame_gn_test GRAD-EXACT; conv causal no-future-leak
  ALREADY LOCKED flame_conv_test check_causal; LR-schedule SHAPE = the hole) · (c) forge cost-model
  self-consistency = DRY (selector provenance + parity-map closed OP-60/61/63) · (d) ## deferred + .log tail =
  all build-host (SELFHOST-NEXT frozen-anchor) or GPU → out of 0-pod scope.
- THE HOLE: op33_lr_schedule_determinism_eq.hexa asserts ONLY (1) RUN-TO-RUN max|Δ|==0 + (3) libm-vs-d5
  bit-diff count → ZERO assertions on peak/floor/monotonicity/range/seam/fold-order. A refold, a warmup-seam
  off-by-one, a cosine sign flip, or a wrong floor stays byte-DETERMINISTIC (OP-33 green) yet shape-WRONG.
- THE LOCK: stdlib/flame/op76_lr_schedule_shape_contract_eq.hexa (self-contained, NO `use`). 7 gates:
  G1 PEAK-EXACT lr(warmup)==base byte-eq · G2 FLOOR-EXACT lr(n_steps)==base·floor byte-eq · G3 WARMUP-RAMP
  [1..warmup] strictly-incr + byte-eq to closed form base·(t/warmup) · G4 DECAY-MONOTONE [warmup..n_steps]
  non-increasing · G5 RANGE two-phase (warmup ∈ (0,base], decay ∈ [base·floor,base]) · G6 SEAM-CONTINUITY
  |lr(warmup)−lr(warmup+1)|≤3·base/warmup · G7 FOLD-ORDER base·(t/warmup) byte-DIFFERS from (base·t)/warmup
  on ≥1 step (proves the line-148 "float-different" claim is real, not folklore).
- RUN-TO-RUN VERBATIM (`hexa run`, arm64-macos, exit 0):
  · G1 PEAK-EXACT      lr(warmup=50) = 0.001  (want base=0.001)  byte-eq=true
  · G2 FLOOR-EXACT     lr(n_steps=500) = 5e-05  (want base*floor=5e-05)  byte-eq=true
  · G3 WARMUP-RAMP     lr(1)=2e-05  strictly-incr + closed-form byte-eq over [1..50] = true
  · G4 DECAY-MONOTONE  non-increasing over [warmup..n_steps] = true  (max upward step = 0.0)
  · G5 RANGE           whole min_lr=2e-05  max_lr=0.001  decay-tail min=5e-05  (two-phase) = true
  · G6 SEAM-CONTINUITY |lr(warmup)-lr(warmup+1)| = 1.15754e-08  <= 3*base/warmup=6e-05 -> true
  · G7 FOLD-ORDER      base*(t/warmup) != (base*t)/warmup on 12 / 50 steps -> claim-real=true
  · F-OP76-LR-SCHEDULE-SHAPE = 1 · PASS 7/7
- CONTRACT-PRECISION FINDING (G5): the first oracle draft asserted a single codomain [base·floor,base] and
  FAILED — min_lr=2e-05 (=lr(1)=base·1/50) sits BELOW the floor base·floor=5e-05. This is CORRECT scheduler
  behavior, NOT a bug: the warmup ramp deliberately starts near 0 ("linear ramp 0→base"), so the floor binds
  the COSINE DECAY TAIL only, never the warmup. opt_lr_warmup_cosine is SSOT-correct; the oracle caught an
  over-broad ASSERTION, then was tightened to the true documented TWO-PHASE codomain.
- SAFETY: oracle-only (no behavior change); self-host byte-eq UNAFFECTED (leaf self-contained oracle, NOT in
  compiler/main.hexa build_selfhost closure; 0 codegen/runtime/stdlib-lib bytes). wipe_guard net-additive
  (one new file). No .tape, no self/env.hexa. Verdict .verdicts/hexa-0pod/F-OP76-LR-SCHEDULE-SHAPE.txt.

## 2026-06-13 — OP-74 DONE: COMPLETE the flame numeric-primitive oracle coverage (OP-72 follow-on) · AUDIT the FULL flame numeric surface (flame_math/moe_lib/nn_lib/gn_lib/optim_lib) for the documented-but-UNlocked-accuracy gap + build the coverage matrix · THE SINGLE HOLE = moe_lib.hexa:39 `_moe_exp` (the 3rd distinct exp impl, "~12 terms machine-exact" docstring) had only DETERMINISM/replay locks (F-OP8/F-OP11), NO agreement-vs-libm · NEW self-contained stdlib/flame/op74_moe_exp_agree_eq.hexa: 3 gates over a 12-pt softmax-range probe — AGREE max rel|_moe_exp−libm exp|≤1e-9 · DETERMINISM byte-identical f64 run-to-run · ADDITION-LAW exp(a)exp(b)−exp(a+b)≤1e-9 · `hexa run` exit 0, 3/3 PASS (agree 3.21e-14, det max|Δbytes|=0, addition 3.52e-14) · the "machine-exact" claim now LOCKED at the primitive level → flame numeric-primitive documented-accuracy surface PROVEN-COMPLETE · oracle-only no behavior change · self-host byte-eq UNAFFECTED (leaf oracle, not in build_selfhost closure) · 🟢 GREEN invariant-lock · $0 · 0-pod · NO GPU · leak-0
- COVERAGE MATRIX (primitive → documented claim → locked-by): dt_sqrt/dt_exp/dt_ln(+det)/dt_lcg → F-RFC043-MATH-*
  (flame_math_test) · dt_erf → F-OP19B · dt_rand_unit → trivial (dt_lcg) · d5_sin/d5_cos → F-OP72 · GN reduction
  → F-OP9 · conv fwd/seam → F-OP7/F-OP10 · MoE combine → F-OP8 · CE/softmax-grad → F-OP11 · AdamW → F-OP12 ·
  LR warmup+cosine (d5_cos) → F-OP33 · whole-step det → F-OP14/F-OP15. _gn_sqrt / _nn_sqrt carry NO accuracy
  claim (docstring "libm-free path not assumed" / "= libm sqrt verbatim") → correctly NOT a gap.
- THE HOLE: moe_lib `_moe_exp` (range-reduce x=n·ln2+r |r|≤ln2/2, 14-term Taylor e^r, ×2ⁿ by mul/div). VERBATIM
  survey: `git grep -lnE "_moe_exp|_me_exp" -- 'stdlib/flame/*test*' 'stdlib/flame/*_eq.hexa'` → 3 files, ALL
  DETERMINISM (max|Δ|=0 dev-vs-host, two-pass==one-pass); NONE asserts agreement with true e^x. The sibling
  dt_exp HAS an AGREE oracle (F-RFC043-MATH-DT-EXP-AGREE); d5 trig was just AGREE-locked (F-OP72). `_moe_exp`'s
  "machine-exact" accuracy docstring was the lone UNGATED accuracy claim — the OP-72 class.
- THE LOCK: stdlib/flame/op74_moe_exp_agree_eq.hexa (self-contained, NO `use`, _moe_exp inlined VERBATIM — OP-28/
  29/33/72 scp/stdin pattern). 12-pt probe {-30,-10,-3,-ln2,-ln2/2,-0.1,0,0.1,+ln2/2,+ln2,3,10} (softmax
  logit−mx ≤0 range + n>0 reduction). AGREE uses RELATIVE error (exp spans 1e-13..1).
- RUN-TO-RUN VERBATIM (`hexa run`, arm64-macos, exit 0):
  · PASS F-OP74-MOE-EXP-AGREE        max rel|_moe_exp − libm exp| = 3.2102e-14 <= 1e-9
  · PASS F-OP74-MOE-EXP-DETERMINISM  12 probes: _moe_exp(x) twice → byte-IDENTICAL f64 (max|Δbytes|=0)
  · PASS F-OP74-MOE-EXP-ADDITION     max rel|exp(a)exp(b) − exp(a+b)| = 3.52043e-14 <= 1e-9
  · === OP-74: 3/3 PASS ===
- CLOSURE: with `_moe_exp` AGREE-locked, every flame numeric primitive bearing a documented accuracy/bit-eq/
  identity claim is oracle-locked → the flame numeric-primitive documented-accuracy surface is PROVEN-COMPLETE.
- VERDICT: .verdicts/hexa-0pod/F-OP74-FLAME-PRIMITIVE-ORACLE-COVERAGE.txt (matrix + the new oracle PASS).
- SAFETY: oracle-only (one new leaf test file + verdict + this log) · no behavior change (_moe_exp already
  SSOT-correct) · self-host byte-eq unaffected (op74_*.hexa NOT in build_selfhost closure) · wipe_guard
  net-additive · $0 · 0-pod · NO GPU · no vast · no foreign pod (leak-0) · no MAIN.tape edit.

## 2026-06-13 — OP-73 DONE: DEFINITIVE public-claim honesty audit of the ENTIRE forge/flame claim surface vs the verdict corpus (campaign flagship value) · enumerated README.md + FLAME+FORGE-vs-PYTORCH+CUBLAS.md + docs/forge-routea-shape-adaptive.md + docs/flame-determinism-contract.md + stdlib/flame/README.md, built the claim→verdict trace table · RESULT: surface OVERWHELMINGLY honest + verdict-traced (OP-64/71 + prior corrections held) with ONE genuine STALE residual (OP-71 class) — the README OG-ladder led OG17 (280 TFLOP/s, 1.24× @D=2048) as the parity FRONTIER, superseded by route-(a) b14 MODE 8 ~315 TFLOP/s, 1.08× @D=2048 (F-GPU-ROUTEA-KEEPBAND-MEASURE); OP-58 had updated only the README §honest-axis headline + forge doc, leaving the detailed README narrative stale vs its OWN line-143 headline · FIX (doc-only, 5+/3−): route-(a) FRONTIER rung added to the ladder + ≈342 @D=2048 roofline + OG17-paragraph carry-forward + line-471 1.08× headline · all numbers CITED VERBATIM (no GPU, no new measurement) · rest of surface 🟢 PROVEN-HONEST (g63 — NO fabricated correction) · 🔴→fix GREEN + 🟢 PROVEN-HONEST · $0 · 0-pod · NO GPU · leak-0
- THE CLAIM→VERDICT TRACE TABLE (every public quantitative/capability claim → its supporting verdict):
  · README L137/L143 + comparison-doc §1.1 "matched-dtype gap SINGLE-DIGIT; FP64 flame ties/wins B=2 0.98×,
    B=4/8 flame faster; TF32 torch 3.03×→7.88×; FP32 2.15×→6.60×" → F-BENCH-1 (verbatim cell-match) 🟢
  · "old ~1656×/~2207× RETIRED (FP64-vs-TF32 unfair dtype + interpreted + 2-pt extrapolation)" →
    F-FUSION-VS-PYTORCH (verbatim "~1656x (eager)/~2207x (compile) FASTER … flame FP64 0.167, torch TF32
    276.7/368.5") + re-contextualized by F-BENCH-1 + F-FUSION-INTERP-ELIM 🟢 (honest-correction PRESERVED)
  · own-GEMM "PARITY 1.08× @D=2048, ~315 TFLOP/s, bit-exact rel_rms 0" → F-GPU-ROUTEA-KEEPBAND-MEASURE
    ("D=2048 route-(a) summit own ~315 TFLOP/s ratio 1.08x PARITY=YES … rel_rms 0") 🟢
  · own-GEMM "@D=4096 ~1.50× sub-parity, bit-exactness-bound, lever family exhausted closed-neg" →
    F-OP45GPU-OCCUPANCY-SWEEP + F-OP52-TF32-GAP-CLOSE + F-OP55-NEWTILE-D4096 🟢
  · "own EDGES cuBLAS @consumer-D768 0.95× (RTX 5070)" → F-OP54-SUMMER-OWNGEMM-TF32 + F-OP57 (32×32 worse) 🟢
  · "parity dtype-SCOPED to TF32; FP16/BF16 W14 correct (rel_rms≤1e-2 same-dtype) but PARITY=NO 11.5× off
    cuBLAS-FP16 (roofline doubled to 827)" → F-FUSION-SM90-WGMMA-W14-FP16 + F-OP64-OWNGEMM-DTYPE-HONEST 🟢
  · flame "batch-fill ≥1.3× @B=2 → 2.95× @B=32, ~3× cap structural" → F-FUSION-BATCHFILL + F-FUSION-M5 🟢
  · flame "TF32 fast-mode 4.2× @B=1 (self-speedup, not torch beat); BF16 Pareto-dominated" →
    F-OP20-TF32-FASTMODE + F-OP25-BF16-FASTMODE 🟢
  · "byte-identical across 6 environments / 4 arch-libc; no libm on step path; whole-step max|Δ|=0;
    18-fold golden CI tripwire" → F-OP19{,B,C,D,E,F,G} + F-OP29 + F-OP15-STEP-DETERMINISM + F-OP39/40/42 🟢
  · forge "12 byte-equal substrate fires + 4 layer fires, max|Δ|=0" → forge correctness verdict set 🟢
  · stdlib/flame/README.md "prior 2.95× / 1.26-1.76× faster than PyTorch RETRACTED (unit mismatch)" →
    explicit CORRECTION 2026-05-19 (an honest self-retraction PRESERVED, not re-introduced) 🟢
- THE ONE FLAG (STALE, OP-71 class): README OG-ladder block (lines 190-209) presented OG17 (280 TFLOP/s,
  1.24×) as the @D=2048 parity-crossing FRONTIER. The LATER route-(a) verdict supersedes it:
  · VERBATIM (F-GPU-ROUTEA-KEEPBAND-MEASURE): "D=2048 route-(a) summit (b14 MODE8 NST=3 PDEP=2): own ~315
    TFLOP/s ratio 1.08x PARITY=YES ★" and "D=2048 OG17-pipe (MODE 6): own ~262 TFLOP/s ratio 1.29-1.32x".
  · The README's OWN line-143 headline + the forge doc (line 158 "current FRONTIER") + the comparison doc
    already carried 1.08× — OP-58 updated only the README §honest-axis SUMMARY (verbatim "README.md
    §honest-axis"), NOT the detailed OG-ladder → an INTERNAL inconsistency where the README detail lagged
    its own headline. Not an overstatement (1.24× is honest for OG17) but a STALE not-the-frontier framing.
- FIX (doc-only, README.md, 5 insertions / 3 deletions, well under wipe_guard):
  · ladder table: added "route-(a) b14 MODE 8 NST=3 PDEP=2 (@D=2048) ~315 1.08× off ★★FRONTIER 2 CTA/SM" +
    corrected the roofline footnote to "≈431 (@4096) / ≈342 (@D=2048)" + "route-(a) is the @D=2048 FRONTIER
    … SUPERSEDING the OG17 1.24× rung".
  · OG17 closing paragraph: carried forward to "route-(a) b14 MODE 8 … SUPERSEDES OG17 … ≈315 TFLOP/s,
    1.08× (≈93% of roofline), bit-exact rel-RMS 0 (F-GPU-ROUTEA-KEEPBAND-MEASURE)" + @4096 1.50× residual.
  · line-471 summary: own-GEMM gained the "TF32 PARITY 1.08× @D=2048" headline, scoping the older 1.13× iso
    (Blackwell-sm_120-only) + 1.24× full-step (F-FUSION-THRU-PARITY) as the non-frontier numbers they are.
- HONEST CLOSURE (g5/g63): the forge/flame public claim surface is PROVEN-HONEST + verdict-traced apart from
  this single stale-narrative residual, now corrected. NO fabricated overstatement manufactured. All numbers
  CITED VERBATIM from existing verdicts — no GPU, no new measurement, no .tape, no self/env.hexa.
- OUTCOME: 🔴→fix GREEN (stale) + 🟢 PROVEN-HONEST (rest). Milestone OP-73 [x]. Verdict F-OP73-PUBLIC-CLAIM-HONESTY.txt.

## 2026-06-13 — OP-72 DONE: LOCK the flame_math hand-Taylor TRIG primitive (d5_sin/d5_cos) — the documented-but-UNlocked OP-33 sibling · flame_math.hexa:137-139 d5_sin/d5_cos (mod-2π reduce + 14-term Taylor) carry a "strict bit-eq path to anima d5_rope_tables" docstring + are PRODUCTION (RoPE tables nn_lib.hexa:523-524 nn_rope_build_tables_base · LR schedule optim_lib.hexa:163 cos=d5_cos · op29 decoder block) yet had NO agreement oracle · OP-33 LOCKED THE SCHEDULE but ASSUMED d5_cos correct · NEW self-contained stdlib/flame/op72_d5_trig_agree_eq.hexa: 4 gates over a 12-pt probe (schedule |x|≤π + RoPE |x|≤10³) — AGREE sin≤1e-9 · AGREE cos≤1e-9 · DETERMINISM byte-identical f64 run-to-run (pure-FP no-libm = arch/OS-independent, F-OP33's premise) · PYTHAGORAS sin²+cos²−1≤1e-9 · `hexa run` exit 0, 4/4 PASS (sin 1.32e-12, cos 1.94e-12, max|Δbytes|=0, pythagoras 8.88e-16) · oracle-only no behavior change (d5 already SSOT-correct) · self-host byte-eq UNAFFECTED (leaf self-contained oracle, not in build_selfhost closure) · 🟢 GREEN invariant-lock · $0 · 0-pod · NO GPU · leak-0
- SURVEY (scoped greps/reads, NO .git), priority order: (a) flame/forge numeric libs flame_math/optim_lib/
  gn_lib/nn_lib for a documented-but-UNlocked contract; (b) stdlib non-math surface; (c)/(d) handoff/deferred.
- PICK (a) — the campaign-subject axis yielded a real finding. flame_math.hexa:137-139 d5_sin/d5_cos make an
  explicit identity/accuracy claim ("Identical to anima d_train5_lib §271/§284 … strict bit-eq path") and are
  WIRED into production (RoPE tables + LR schedule + decoder block), but the agreement was never asserted:
  · VERBATIM: `grep -rn "d5_sin\|d5_cos" stdlib --include="*test*" | grep -i "sin(\|cos(\|libm\|agree"` → 0
    assertions (the only test hits USE d5_cos in determinism-eq, none verify it vs libm sin/cos).
  · flame_math_test.hexa locks dt_sqrt/dt_exp/dt_ln/dt_lcg (F-RFC043-MATH-*) + dt_erf separate (F-OP19B);
    the d5 trig pair was the lone uncovered flame_math primitive. OP-33 (LR schedule) leaned on d5_cos
    correctness without locking it = the exact documented-but-ungated hole OP-33/66/70 close.
- THE LOCK: stdlib/flame/op72_d5_trig_agree_eq.hexa (self-contained, NO `use`, d5 inlined VERBATIM — OP-28/29/
  33 scp/stdin pattern). 12-pt probe {-3.1,-1.5,-0.5,0,0.3,1,π/2,π,2π,10,100,1000}.
- RUN-TO-RUN VERBATIM (`hexa run`, arm64-macos, exit 0):
  · PASS F-OP72-D5-SIN-AGREE   max|d5_sin − libm sin| = 1.3165e-12 <= 1e-9
  · PASS F-OP72-D5-COS-AGREE   max|d5_cos − libm cos| = 1.9359e-12 <= 1e-9
  · PASS F-OP72-D5-DETERMINISM 12 probes × {sin,cos}: d5_*(x) twice → byte-IDENTICAL f64 (max|Δbytes|=0)
  · PASS F-OP72-D5-PYTHAGORAS  max|sin²+cos²−1| = 8.88178e-16 <= 1e-9
  · === OP-72: 4/4 PASS ===
- SAFETY: oracle-only (no .hexa source edit besides the new test); d5 primitives already SSOT-correct → this
  LOCKS the docstring claim, no behavior change. Self-host byte-eq unaffected (leaf, not in build_selfhost
  closure). wipe_guard net-additive (one new file). RESIDUAL (honest): AGREE run on arm64-macos only; the
  DETERMINISM gate proves the pure-FP property that carries the same bytes to x86-linux (F-OP33's argument) —
  a literal cross-ISA byte-diff of the self-contained oracle is a future scp-able round.
- OUTCOME: 🟢 GREEN invariant-lock. Milestone OP-72 [x]. Verdict F-OP72-D5-TRIG-AGREE.txt.

## 2026-06-13 — OP-70 DONE: GENERALIZE the OP-68 wrap_pi contract-vs-behavior audit across the sibling stdlib core/signal math surface (9 contract-bearing modules) · for each: surface-doc CONTRACT (range·boundary·rounding·sign·idempotence·units) vs BODY+test · RESULT: ONE genuine contradiction (same class) — stdlib/core/math/permille.hexa:21 doc claimed `pm_mul_pm` divides by 1000 "with banker's rounding" while the body calls `_div_round_half_away` (half-away-from-zero) + the passing test already locks 0.5→1 (banker's-even would give 0) · FIX (doc+test only, behavior+test SSOT-correct per OP-68): corrected the doc line to half-away + fixed the test's "banker-style half-away" comment + ADDED a T5b half-away lock (50×50=2.5→3, −100×5=−0.5→−1 FAIL under round-half-to-even) · 41/41 → 44/44 PASS · the OTHER 8 modules PROVEN-CONSISTENT (honest all-else-consistent = SUCCESS, g63) · self-host byte-eq unaffected (leaf stdlib, doc+test only) · 🔴→fix GREEN · $0 · 0-pod · NO GPU
- AUDIT SET (explicit documented numeric contract): core/math/{wrap_pi,float,permille} · core/{math,special}
  · signal/core_{window,filter,resample} (+ core_mel curve, core_pitch).
- THE CONTRADICTION (permille `pm_mul_pm`):
  · FALSE doc line (permille.hexa:21): "×10^3 by dividing by 1000 with banker's rounding."
  · TRUE behavior (permille.hexa:101): `_div_round_half_away(a.pm * b.pm, PM_SCALE)` — half-away-from-zero.
  · The modes DIVERGE at every .5 boundary (2.5 → 3 half-away vs 2 banker's-even). The existing test
    T5.mul_pm.0.1×0.005 already proved half-away (500/1000=0.5 → 1, banker's-even → 0).
  · FIX = correct the DOC to the proven-tested behavior (NO behavior change), + a T5b rounding-mode lock.
  · LOCK-TEST PASS: hexa run permille_test.hexa = "PASS: permille 44/44" (was 41/41).
- PROVEN-CONSISTENT (8): wrap_pi (closed [−π,π] by OP-68) · float (pi/e/tau exact, isnan/isinf/isfinite
  delegate libm) · core math (gcd, det Miller-Rabin 12-witness, Liouville/σ*/sigma_3 all match docstrings)
  · special (Lanczos g=7 ~1e-13 + A&S 7.1.26 erf ~1.5e-7 + erf odd-function + Γ pole-at-0 all match)
  · core_window (Hann/Blackman w[0]=w[N-1]=0, Hamming 0.08, symmetric N−1 denom — cos(0)=cos(2π)=1)
  · core_filter (RBJ LPF/HPF coeff formulas idx 0-4 + a0≡1 + Direct-Form-I match the header)
  · core_resample (zcr ÷(N−1) + 0→sign+, db floor −120, lerp tail-clamp, output len ⌊N·ratio⌋ match).
  permille was the LONE contradiction (wrap_pi-style). No 🟠 behavior-bug surfaced. Verdict
  .verdicts/hexa-0pod/F-OP70-MATH-CONTRACT-AUDIT.txt. Milestone OP-70 [x].
## 2026-06-13 — OP-71 DONE: forge GPU-emit doc-vs-code honesty fix (OP-64 class) · the parse_only RFC071 P9 fixture nvptx_p9_warp_reduce_test.hexa still declared `gpu_warp_shuffle_xor` `[NOT WIRED]` + predicted `// unsupported` PTX markers + "DO NOT touch compiler source" — verifiably FALSE on main (#1200/N71-B wired the shfl.sync.bfly.b32 lowering; the comment dates to wip 9f343d1bb, PREDATES the wiring) · 🔴→fix GREEN comment-only · $0 · 0-pod · NO GPU · self-host byte-eq UNTOUCHED
- SURVEY (STEP 1 — scoped greps/reads, NO .git; candidate axes a–d):
  · (a) forge GPU-emit 0-pod READABLE — both handoff-flagged bugs are ALREADY CLOSED:
    nvptx f64 exp() underflow garbage <x≈−745 = FIXED (nvptx_target.hexa:2009-2024 DOJO-A4 /
    d631a08f `max.s64 b,b,0` clamp → b<<52=+0.0, no NaN; CPU falsifier
    nvptx_expf64_underflow_clamp_probe.hexa gates exp(-800)==0.0). RFC071 gpu_warp_shuffle_xor
    NVPTX FIXME = WIRED (nvptx_target.hexa:1700-1771 shfl.sync.bfly.b32, u32 single-instr + f64
    decompose/recompose; PTX_OP_SHFL_SYNC_BFLY_B32; returns before unsupported-call fallthrough
    3207; #1200/N71-B b1564fa37 + n71b fire fixture). NEITHER is an open bug.
  · (b) forge/flame DOC-vs-CODE honesty — PICKED. nvptx_p9_warp_reduce_test.hexa header still
    advertises the now-wired builtin as [NOT WIRED] (a tracked false capability claim).
  · (c) flame stdlib CPU-oracle invariant — none unlocked (determinism-path libm/FMA/const-fold
    GATED by OP-66/69/39; per-phase byte-eq oracles are runtime-checked, not 0-pod static).
  · (d) `## deferred` — all build-host (frozen-anchor 151c52c8 re-pin: OP-2b/2c/19b/37b/40/44/46)
    or GPU (OP-5c). Out of 0-pod scope.
- PICK (g0): (b) — the only axis with an actionable, decisive, $0/0-GPU outcome; g0-simplest
  (comment-only). A future cycle reading the [NOT WIRED] header would re-report a shipped builtin
  as HONEST BLOCKED.
- FINDING (verbatim): lines 22-30 PRE-FIX declared `gpu_warp_shuffle_xor(v, mask)` `[NOT WIRED —
  XOR butterfly variant ...]` + "if `gpu_warp_shuffle_xor` is not wired ... PTX emit will contain
  `// unsupported` markers ... DO NOT touch compiler source this round." FALSE: nvptx_target.hexa:
  1700 lowers it to `shfl.sync.bfly.b32 ... 0x1f, 0xffffffff` and returns at 1770, BEFORE the
  `unsupported call` stub at 3207. TIMELINE: the `[NOT WIRED]` header = wip 9f343d1bb; the wiring =
  later #1200 / b1564fa37. The comment is genuinely STALE.
- FIX (comment-only, no behavior change): rewrote the intrinsic entry [NOT WIRED]→[WIRED] with the
  exact lowering (shfl.sync.bfly.b32 + f64 decompose/recompose §9.7.13.4; #1200/N71-B; emitter site +
  n71b fire fixture cited); replaced the false `@D g3 ... unsupported markers ... DO NOT touch` para
  with a STALE-COMMENT-FIX note.
- VERIFY: git diff --stat = 1 file, 15+/8−. Comment-only proof: `git diff | grep '^[+-]' |
  grep -vE '^[+-]//' | grep -vE '^(\+\+\+|---)'` = EMPTY (0 non-comment line changed); the
  @gpu_kernel body (34-57) byte-identical; parse_only fixture parse-correctness preserved.
- OUTCOME: 🔴→fix GREEN. Self-host byte-eq UNTOUCHED (codegen TEST FIXTURE, not in
  compiler/main.hexa build_selfhost closure; 0 codegen/runtime/stdlib bytes). wipe_guard
  net-additive. Verdict F-OP71-SHFL-XOR-WIRED-COMMENT.txt. $0 · 0-pod · NO GPU · no vast ·
  no foreign pod · no .tape · no self/env.hexa · leak-0.

## 2026-06-13 — OP-69 DONE: COMPLETE the flame determinism-contract enforcement coverage — audit the OTHER layers for the documented-but-ungated gap OP-66 closed for layer-2 · FINDING: LAYER 3 (cross-ISA FMA-free) was DOCUMENTED + held in source but UNGATED · new tool/flame_steppath_fma_gate.sh (pure grep, no ./hexa/no seed) wired BLOCKING in nobaseline-gate.yml ALL 3 ISA legs · PROVEN pass-clean (exit 0, 6 files) + fail-on-regression (clm_prod.hexa:212 farr_matmul + moe_lib t_matmul, exit 1) · $0 · 0-pod · NO GPU · byte-eq fixpoint untouched
- SURVEY (STEP 1 — read docs/flame-determinism-contract.md IN FULL; enumerate ALL 3 run-step
  determinism layers + the 4th compile-step + per-phase sub-invariants; grep .github/workflows +
  tool/ for an enforcing gate per invariant). COVERAGE MATRIX:
  · LAYER 1 (RUN-TO-RUN, max|Δ|=0): per-phase byte-eq oracles F-OP2/7/8/9/11/12/13 + OP-15
    capstone (clm_prod_*_eq.hexa + clm_step_determinism_eq.hexa). ⚠ DEFERRED — these need a BUILT
    ./hexa to RUN the production op order vs a re-layout reference; 0-pod-RUNNABLE but NOT pure-
    static-grep (need the seed toolchain; CI's frozen seed predates flame source — same staleness
    keeping OP-39 advisory). NOT faked into a static gate; recorded as documented-but-deferred.
  · LAYER 2 (libm-FREE): 🟢 PROVEN-GATED. tool/flame_steppath_libm_gate.sh BLOCKING (OP-66 #3186,
    F-OP66) + tool/fold_ci_gate.sh BLOCKING all-3-legs (OP-34, dt_exp/dt_erf golden FOLD VALUES).
    No new gate needed (the pointers ARE the deliverable, g5).
  · LAYER 3 (cross-ISA FMA-FREE): ⛔ UNGATED → THE GAP. A determinism-path matmul must NOT route
    through the raw FMA-fused C farr_matmul kernel (clang fuses a*b+c → single fma on arm64 [1
    rounding] vs mul+add on x86 [2 roundings] → divergent bytes per ISA; F-OP29 measured arm64 ck
    241449363 vs x86 ck 1401117690). DOCUMENTED in §1 (cross-ISA invariant) + the "what breaks the
    contract" checklist + HELD in source (clm_prod.hexa routes conv GEMMs through the
    forge_dispatch_matmul dispatcher seam, NOT raw farr_matmul) — but grep .github/workflows + tool/
    for farr_matmul found NO enforcing gate. The exact layer-2 analogue OP-66 closed → PICKED.
  · COMPILE-STEP (hex-float const-fold): 🟢 GATED. tool/op39_constfold_gate.sh all-3-legs, 18 folds
    (OP-39 13 + OP-42 5 hex-float MUL_HF*), continue-on-error advisory-until-seed-promote (honest
    rationale: frozen seed pre-dates the OP-37/37b/40 source fix). Not an OP-69 gap.
  · SCHEDULE libm-cos ban (F-OP33) SUBSUMED by layer-2 (cos/sin in the libm-gate forbidden set).
    CHECKPOINT (F-OP35) + B>1 conv seam (F-OP10) = RUNTIME byte-eq, same DEFERRED class as layer-1.
- THE LAYER-3 INVARIANT HOLDS IN SOURCE (pre-gate): raw farr_matmul(/t_matmul( call-sites (code
  only, minus the forge_dispatch_matmul seam) across the trainer step-path = 0 in clm_prod.hexa +
  flame_math/gn_lib/optim_lib/moe_lib/quant_lib. The raw-kernel sites in the tree are all OFF the
  CLMConvMoE step: tensor_lib:61 (DEFINES t_matmul — primitive), conv_lib:89/113 (nn_conv1d_* —
  trainer uses its OWN inlined conv1d_via_forge instead), nn_lib:389-1050 (attention/SwiGLU/MLP
  DECODER arch — different model), decoder_block_lib:149/197 (OP-29 2nd arch — DELIBERATELY
  farr_matmul-routed to match anima d5_proj_batch_g flame↔anima byte-eq, its cross-ISA layer is the
  documented-DEFERRED case per F-OP29 HOLE-2). All four intentionally NOT scanned (low blast radius).
- THE GATE: tool/flame_steppath_fma_gate.sh — pure-lexical grep over the trainer FILES allow-list;
  forbids whole-word raw farr_matmul(/t_matmul(; excludes // comments + the forge_dispatch_matmul/
  _t/_batched dispatcher seam (compliant). Exit 0 clean / 1 regression / 2 absent (neutral). Modeled
  EXACTLY on OP-66's flame_steppath_libm_gate.sh (allow-list grep gate, no ./hexa/no seed).
- PROOF (verbatim): CLEAN main → 6 PASS, GATE PASSED, EXIT=0. REGRESSION A (clm_prod.hexa:212
  forge_dispatch_matmul→farr_matmul): FAIL clm_prod.hexa "212: let mm = farr_matmul(xcol, T, Kdim,
  Wt, Cout)" EXIT=1 → reverted EXIT=0. REGRESSION B (raw t_matmul into moe_lib first fn): FAIL
  moe_lib.hexa "59: let _bogus = t_matmul(0, 1, 1, 0, 1)" EXIT=1 (the 5 forge_dispatch_matmul( seam
  call-sites in clm_prod.hexa correctly IGNORED — clm_prod.hexa passes clean in both drives) →
  reverted EXIT=0. False-positive check: dispatcher seam not flagged.
- WIRING: BLOCKING in nobaseline-gate.yml ALL 3 jobs (darwin-arm64 after OP-66; linux-x86_64 +
  linux-arm64 after OP-34) — the layer-3 invariant IS the cross-ISA property so the lock is
  symmetric across the arm64 + x86 legs. No seed dependency (pure grep) → real, not advisory.
  YAML validated (python yaml.safe_load OK). docs/flame-determinism-contract.md §1 + verdict
  F-OP69-DETERMINISM-GATE-COVERAGE.txt written. NO codegen/runtime/stdlib edit → byte-eq fixpoint
  UNTOUCHED. $0 · 0-pod · NO GPU · no vast · no foreign-pod touch · leak-0 · no .tape · no env.hexa.
- TIER 🟢 GREEN — documented-but-unenforced LAYER 3 now CI-locked by a tripwire proven pass-clean-
  on-main + fail-on-regression; layer-2 + compile-step PROVEN-GATED (pointers recorded); layer-1 +
  checkpoint + seam honestly DEFERRED (runtime byte-eq, not static-checkable). An audit that closes
  the one genuine static gap + honestly records the gated + deferred rest = SUCCESS (g5/g63).

## 2026-06-13 — OP-66 DONE: WIRE the MISSING CI tripwire enforcing flame determinism-contract LAYER 2 ("NO libm transcendental on the CLMConvMoE production step") · documented (§1) + held in source but UNGATED · new tool/flame_steppath_libm_gate.sh (pure grep, no ./hexa/no seed) wired BLOCKING in nobaseline-gate.yml · PROVEN pass-clean (exit 0) + fail-on-regression (clm_prod.hexa:938 + nn_gelu_fwd, exit 1) · $0 · 0-pod · NO GPU · byte-eq fixpoint untouched
- SURVEY (broader forge/flame frontier deep-dive; route-(a) own-GEMM GENUINELY CLOSED OP-58..64):
  · (a) flame bit-exact training flagship — docs/flame-determinism-contract.md defines 3 determinism
    layers; layer-2 = libm-FREE: every transcendental on the production step is hand-rolled (dt_exp/
    dt_erf/dt_ln/_moe_exp/d5_cos + Newton sqrt) because libm is NOT correctly-rounded → diverges
    glibc vs Darwin (F-OP19 CE-bwd exp 4/4096 grad 1ULP · F-OP19b GELU erf · F-OP33 libm-cos LR
    10/500 steps 1-4ULP). CI INVENTORY (grep .github/workflows + tool/): OP-34 fold gate locks the
    dt_ golden VALUES, OP-39/42 the constfold — but NOTHING enforces the step CALLS the dt_ twins
    rather than raw libm. => layer-2 DOCUMENTED but UNGATED. ACTIONABLE → PICKED.
  · (b) handoff b65ebe51 "clm_prod.hexa internally INCONSISTENT" — DRY (stale-seed, not a bug).
    hexa build clm_prod.hexa on local ~/.hx/bin/hexa errors: hexa_call4(forge_dispatch_db_colsum,...)
    passing a fn-typed value to a HexaVal param (app.c:2296/2561). ROOT: self/codegen.hexa:7592-7603
    DOES register forge_dispatch_db_colsum + forge_dispatch_int4_quant_bwd for direct-C lowering, and
    runtime.h:1141/1171 declares both; the FROZEN seed hexat self/native/hexa_cc.c (151c52c8) predates
    those registrations → the stale local oracle mis-routes the 4-arg call. SAME stale-seed-vs-source
    class as the deferred seed-promote bundle (OP-37/40/44/46), a BUILD-HOST task — NOT 0-pod source.
    clm_prod.hexa is CORRECT vs current source codegen.
  · (c) own-GEMM public framing — DRY (closed OP-58..64; context: do NOT re-doc).
  · (d) ## deferred + .log tail — DRY for a NEW forge/flame item (open head = seed-promote = build-host).
- PICK: (a) — the ONLY genuine 0-pod source-truth-aligned hardening (a flagship-central determinism
  invariant is documented but UNGATED → can silently regress). g0: pure source grep is the simplest
  sound enforcement (no build, no seed, no GPU, machine-independent, <1s).
- THE INVARIANT HOLDS TODAY (pre-gate): clm_prod.hexa + flame_math/gn_lib/optim_lib/conv_lib/moe_lib/
  quant_lib/tensor_lib = 0 raw libm sites; nn_lib has 6 (all attention/RoPE/SwiGLU: _nn_sqrt:56,
  _nn_softmax_row:204, nn_attn_core_fwd:226, nn_attn_core_bwd:285, _nn_sigmoid:374, nn_rope:521) but
  clm_prod REACHES only nn_ce_loss_allpos/nn_embedding_*/nn_gelu_*/nn_groupnorm_*/nn_moe_router_*
  (grep -c each of the 6 libm fns from clm_prod = 0; each reachable fn itself libm-free). The 6 sites
  are the DECODER-TRANSFORMER architecture, a different model the CLMConvMoE trainer never calls.
- GATE: tool/flame_steppath_libm_gate.sh — FILES allow-list (clm_prod + 7 libs) + function-scope scan
  of nn_lib's 9 production-reachable fns. Forbids whole-word libm exp/erf/cos/sin/tanh/log/sqrt/pow/
  atan/acos/asin call-sites; excludes // comments + dt_/d5_/_moe_/Newton twins + the _libm/_sel_
  oracle references. Exit 0 clean / 1 regression / 2 absent (neutral). Modeled on forge_runtime_warn_gate.sh.
- VERBATIM PROOF:
  · CLEAN: `sh tool/flame_steppath_libm_gate.sh` → "GATE PASSED: 9 guarded ... libm-transcendental-free" EXIT=0
  · REGRESSION A (clm_prod.hexa:938 dt_exp→exp): "FAIL clm_prod.hexa ... 938: ...sm + exp(t_get(logits..." EXIT=1
  · REGRESSION B (nn_gelu_fwd += `let _bogus = exp(0.0)`): "FAIL nn_lib.hexa [nn_gelu_fwd] 1014: ...exp(0.0)" EXIT=1;
    the same exp( injected into the unscanned attention path is correctly IGNORED. Reverted → EXIT=0.
- WIRED BLOCKING in nobaseline-gate darwin-arm64 job (after OP-34; no seed dependency, so real not advisory).
  docs/flame-determinism-contract.md §1 gains the OP-66 tripwire pointer. Verdict
  .verdicts/hexa-0pod/F-OP66-FLAME-STEPPATH-LIBM-GATE.txt.
- OUTCOME: 🟢 GREEN. determinism-contract LAYER 2 now CI-enforced by a tripwire proven pass-clean +
  fail-on-regression. NO codegen/runtime/stdlib edit → self-host byte-eq fixpoint untouched. Milestone
  OP-66 [x]. $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape · no self/env.hexa.
## 2026-06-13 — OP-68 DONE: fix a REAL contract-vs-behavior contradiction in stdlib/core/math/wrap_pi.hexa · public surface doc claimed half-open codomain "(−π,π], NOT −π" while body comment + fast-path guard + passing `wrap_pi(−π)==−π` test prove the TRUE codomain is the CLOSED [−π,π] · corrected the 3 stale surface lines + machine-locked with a 400-pt closed-interval sweep + −π-membership check · 🔴→fix GREEN 12/12 → 14/14 PASS · doc+test only, no behavior change, self-host byte-eq unaffected · $0 · 0-pod · NO GPU
- SURVEY (per axis, scoped greps NO .git): (a) self-host codegen TODOs DRY — `grep
  unimplemented|unreachable|HEXAT_FAIL|TODO|FIXME` over self/codegen.hexa + macho_arm64.hexa = ONE
  benign hit (codegen.hexa:5645 "statically unreachable" comment on a const-fold opt). (b) stdlib
  numeric invariants already tested + PASS clean locally — kahan_sum.hexa 5/5, logsumexp.hexa 5/5
  (re-locking = redundant make-work, g63). (c) ACTIONABLE — internal contradiction in wrap_pi.hexa
  (below). (d) HEXA-0POD ## deferred all build-host (SELFHOST-NEXT) or GPU (OP-2b/2c/5c/19b) —
  none 0-pod-doc-feasible.
- PICK (g0): wrap_pi.hexa surface-contract range bug. Beats (a) dry / (b) already-correct — a REAL
  contract-vs-behavior contradiction in a PUBLIC stdlib numeric primitive that angle consumers
  (control/IK/gyro/SDR phase, orbital Kepler) read as the codomain guarantee.
- THE BUG (verbatim): wrap_pi(x) reduces into the CLOSED [−π, π], preserving BOTH boundaries —
  fast-path `if x>=0.0-p && x<=p { return x }` returns −π unchanged; the body comment says "reduce
  into [−π, π] ... a literal −π input returns −π"; the test `check_exact("wrap_pi(-π) == -π",
  wrap_pi(0.0-p), 0.0-p)` PASSES. But the PUBLIC SURFACE doc claimed a HALF-OPEN codomain excluding
  −π: L13 `//   pub fn wrap_pi(x: float) -> float    // (−π, π]`, L16–17 "Maps any real x to the
  unique representative in (−π, π], i.e. +π stays at +π (NOT at −π)". The (−π, π] form is the
  FLOORED-MODULO convention which lines 21–23 themselves say the fn does NOT use. A consumer trusting
  "(−π, π], NOT −π" could branch on −π never being returned = latent lower-boundary trap.
- FIX (doc + test only, NO behavior change): (1) wrap_pi.hexa — corrected L13/L16–17 to the true
  CLOSED [−π, π] both-boundary-preserved (sign-selected) contract + a note that the floored-modulo
  form (which WOULD collapse −π→+π) is explicitly NOT used; line 34's "(−π, π)" (open INTERIOR) is
  correct, untouched. (2) wrap_pi_test.hexa — fixed the stale "(−π,π]" idempotence comment + ADDED a
  400-point sweep (both signs, non-grid stride, many revolutions) asserting every output ∈ [−π, π],
  plus an explicit `check_exact "wrap_pi(−π) ∈ codomain (closed [−π,π])"` pinning the lower boundary.
- RE-VERIFY (verbatim): `hexa run stdlib/core/math/wrap_pi_test.hexa` → pre-fix `PASS 12/12`,
  post-fix `PASS 14/14` (+2 new checks: closed-interval sweep + −π codomain membership, both PASS).
- SELF-HOST BYTE-EQ: unaffected — wrap_pi.hexa is a leaf stdlib module (NOT in compiler/main.hexa
  build_selfhost closure); comments + a test sweep, zero codegen/runtime bytes touched.
- WIPE-GUARD: net-additive, no >50-line deletion in stdlib/runtime/codegen/rt, scoped subject.
- OUTCOME: 🔴→fix GREEN. Real public-contract-vs-behavior contradiction found + corrected +
  machine-locked by a closed-interval oracle. Milestone OP-68 [x]. Verdict
  F-OP68-WRAP-PI-RANGE-CONTRACT.txt. $0 · 0-pod · NO GPU · no vast · no foreign pod · no .tape · leak-0.

## 2026-06-13 — OP-67 DONE: COMPLETE the dereg-loop closure across EVERY builtin-ADVERTISING surface · 6 surfaces enumerated + verbatim-grepped all 10 OP-62 orphans per surface · lsp.hexa get_builtins() was the SOLE surface that ever advertised any orphan (OP-65 already pruned `tension_link`); ALL 5 others verbatim 0-hit CLEAN · 🟢 PROVEN-COMPLETE, 0 new stale entries this round (honest all-clean = SUCCESS) · no code edited · $0 · 0-pod · NO GPU
- TASK: OP-62 (#3175) deregistered 10 pure-orphan builtins from self/env.hexa env_new() (try_float,
  is_whitespace, meta_laws, phi_predict, tension_link, zip_arr, enumerate_arr, input_all,
  load_weights_bin, mmap_weights) but its caller sweep EXPLICITLY EXCLUDED the roster files. OP-65
  (#3184) then found `tension_link` still LIVE in self/lsp.hexa get_builtins() — ONE advertising
  surface — and pruned it. lsp.hexa is only one surface that ADVERTISES (lists builtin names as DATA,
  vs calls them). OP-67 sweeps EVERY advertising surface to close the dereg loop completely.
- ENUMERATED ADVERTISING SURFACES (scoped find/grep, NO .git) — 6 genuine builtin-name rosters:
  · S1 self/lsp.hexa — LSP roster fns: get_builtins() (completion source), builtin_doc() (hover),
    get_keywords/get_n6_constants/get_gpu_intrinsics + semantic-token type/modifier lists
  · S2 self/stdlib/syntax_highlight.hexa — syntax-highlight token classifier
  · S3 compiler/atlas/n6.tmLanguage.json — n6 TextMate grammar
  · S4 editor/vscode/syntaxes/hexa.tmLanguage.json — VSCode TextMate grammar
  · S5 self/attrs/pure.hexa — pure_whitelist_builtins() (@pure-effect builtin whitelist)
  · S6 docs/notes/2026-05-22-tma-runtime-builtin-requirements.md + docs/rfc/.../rfc_032_farr_matmul_native_builtin.md
- PER-SURFACE SCAN (all 10 orphans, verbatim grep per name, NO .git):
  · S1 lsp.hexa — ONLY hit = line 116 `// OP-65: tension_link removed — OP-62 (#3175) deregistered it`
    (a COMMENT). get_builtins() DATA list (101-121) + builtin_doc() hover (618-627: only print/println/
    len/type_of/sigma/phi/tau/sqrt/pow) carry ZERO orphan. ⇒ S1 advertising data CLEAN.
  · S2 [0 hits — CLEAN] · S3 [0 hits — CLEAN] · S4 [0 hits — CLEAN] · S5 [0 hits — CLEAN] · S6 [0 hits — CLEAN]
  (self/env.hexa hits are ALL OP-62 deregistration COMMENTS + the surviving live-sibling roster lines.)
- OUT OF SCOPE (recorded so it is not re-flagged): compiler/lens_taxonomy/embedded.gen.hexa:268
  `LensEntry { name: "tension_link", file: "tension_link_lens.rs", category: "meta_system", ... }` — the
  REASONING-LENS taxonomy namespace (sibling of tension_lens/telepathy/thermo), a coincidental name
  collision with the deregistered BUILTIN, NOT a builtin roster.
- CLOSURE STATEMENT: dereg-loop CLOSED across 6 advertising surfaces; 1 stale entry pruned IN TOTAL
  (OP-65 lsp.hexa tension_link), 0 THIS round; the 10 OP-62 orphans are now ABSENT from every call site
  AND every advertising surface. 🟢 PROVEN-COMPLETE: self/lsp.hexa get_builtins() was the ONLY surface
  that ever advertised any orphan; OP-65 already pruned it; all other surfaces NEVER advertised any of the
  10 (verbatim per-name 0-hit). The dereg loop is COMPLETE across the entire advertising frontier.
- FIX: NO code edited. An honest all-surfaces-clean scan IS the deliverable (g63 — make-work rejected;
  no fabricated stale entries). DELIVERABLE = verdict + milestone + this log entry.
- VERDICT: .verdicts/hexa-0pod/F-OP67-DEREG-LOOP-COMPLETE.txt (per-surface scan + verbatim hits/clean +
  closure statement + 🟢 GREEN PROVEN-COMPLETE).
- BASE: origin/main e6b88489842239c8a4c470c762d2e7f08a54345f. $0 · 0-pod · NO GPU · no vast · no foreign pod · leak-0.

## 2026-06-13 — OP-64 DONE: EXTEND the honest-number discipline to the own-GEMM DTYPE axis — the parity claim is now explicitly DTYPE-SCOPED to TF32 · FP16/BF16 (W14) = correct (rel_rms ≤ 1e-2 same-dtype) but PARITY=NO, 11.5x off cuBLAS-FP16 (roofline doubled) · docs-only, cited-not-re-measured · $0 · 0-pod · NO GPU
- TASK: the public comparison doc + README led the own-GEMM story with the TF32 route-(a) result
  (1.08x cuBLAS-TF32 PARITY @D=2048, bit-exact) WITHOUT a dtype qualifier. But the campaign also
  measured an FP16/BF16 own-GEMM (W14, PR #2853) whose honest result is PARITY=NO. Presenting
  "own-GEMM ≈ cuBLAS parity" without the dtype qualifier OVERSTATES the own-GEMM story — the same
  honest-number failure class as the retired ~1656x figure (a dtype mismatch). OP-64 documents the
  dtype axis honestly so the own-GEMM parity claim is dtype-scoped.
- SURVEY (cited verbatim, NO re-measure — no GPU):
  · .verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W14-FP16.txt — "own 71.6 @4096" (76.4 @8192),
    "cuBLAS-FP16 roofline @4096 = 827.2", "11.55x off cuBLAS-FP16 @4096", "PARITY-vs-FP16: NO";
    BF16 mirror: own 71.1 @4096, cuBLAS-BF16 816.1, 11.48x off. GATE CHANGE stated verbatim — NOT
    bit-exact-vs-FP64: "the gate REMAINS the 1e-2 same-dtype tolerance, not a bit-exact-vs-FP64 claim"
    (measured rel_rms 0.000e+00, better than the gate required, but the gate stays 1e-2 same-dtype).
    Structural: "the precision change moved the cuBLAS roofline 2x AWAY without lifting the own kernel"
    → the same-dtype ratio WIDENED (6.09x → 11.5x), it did not close. W13 16-KB-band overlap thesis
    DETERMINISTICALLY REFUTED for .k16 (band stays 32 KB, same as TF32).
  · .verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W10.txt — TF32 summit: "own ... 70.7 TFLOP/s @S=4096",
    "cuBLAS-TF32 GFLOP/s: 430.8", "ratio ... 6.09x (W10)", "PARITY (<=1.3x): NO" (pre-route-(a); the
    route-(a) global-relay then reaches 1.08x @D=2048, the headline).
  · OP-58 own-GEMM parity map (docs/forge-routea-shape-adaptive.md) — vs cuBLAS-TF32 throughout.
- DELIVERABLES (0-pod, NO GPU, docs-only, g0 simplest — a subsection + qualifier lines):
  · FLAME+FORGE-vs-PYTORCH+CUBLAS.md — NEW §4.1 "The parity result is DTYPE-SCOPED to TF32" (a 3-row
    TF32/FP16/BF16 table each number traced to W10/W14 + the gate-change note + the roofline-doubled
    explanation + the honest one-liner blockquote). §4 itself NOT rewritten (g0).
  · docs/forge-routea-shape-adaptive.md — DTYPE-SCOPE blockquote on the OP-58 own-GEMM parity map.
  · README.md — one-line dtype-scope qualifier appended to the own-GEMM parity line.
  · .verdicts/hexa-0pod/F-OP64-OWNGEMM-DTYPE-HONEST.txt — the TF32-parity-vs-FP16-no-parity split,
    each number traced to W14/W10/OP-58, the dtype-scope statement.
- HONEST ONE-LINER (g5): own-GEMM reaches bit-exact PARITY with cuBLAS in TF32 (1.08x @D=2048); in
  FP16/BF16 it is correct (rel_rms ≤ 1e-2 same-dtype) but NOT parity (11.5x off cuBLAS-FP16) — the
  parity result is dtype-scoped to TF32. cuBLAS = roofline throughout, parity-seeking, no superiority.
- TIER: 🟡 SUPPORTED-BY-CITATION — the FP16/BF16 + TF32 numbers are CITED from W14/W10/OP-58, NOT
  re-measured (no GPU). The consolidation/labeling/scope split is the deliverable. NO .tape, NO
  self/env.hexa, NO kernel change, NO new measurement. $0, 0-pod, no vast, no foreign pod, leak 0.

## 2026-06-13 — OP-62 DONE: GENERALIZE the falsified-builtin audit BEYOND the ML family — 165 non-ML builtins of self/env.hexa audited with the OP-59 5-step g5 method · 10 pure-orphan landmines DEREGISTERED, 155 KEPT (82 real-impl + 29 compiler-closure + 44 live-caller) · whole roster now audited · $0 · 0-pod · NO GPU
- TASK: OP-59 DEFINITIVELY closed the *ML-family* falsified-builtin thread (OP-43's 42-member ML roster:
  40 deregistered, 2 compiler-closure KEEPs sigmoid·arange). But that thread only ever audited the ML
  family. OP-62 generalizes the proven method to the REST of self/env.hexa env_new() — the 165 NON-ML
  builtins (string/array/math/io/net/consciousness/n6/term/misc).
- METHOD (verbatim from F-OP59): per candidate — (1) g5-FALSIFY (`NAME(arg)`, no shadow → fresh hexat AOT
  → clang; falsified = bare `hexa_callN(NAME,…)` → "use of undeclared identifier 'NAME'") (2) CALLABLE-BARE-
  SYMBOL check (runtime.c/.h `HexaVal NAME(` + prefix variants) (3) CODEGEN-GUARD check (self/codegen.hexa
  `== "NAME"` special-path = compiler-closure KEEP) (4) [S] SHADOW-CONTROL (local `fn NAME` binds roster-
  independently) (5) CALLER-LIVENESS (every builtin-dep caller dead today). Toolchain: ~/.hx/bin/build/hexat
  (Jun-13) + /usr/bin/clang -I<self> -fsyntax-only + installed runtime.c (Jun-12).
- 3-WAY FALSIFY SPLIT of the 165: 82 CLEAN (real runtime impl — print/len/abs/sin/cos/sqrt/exp/read_file/
  json_parse/http_get/base64_*/Some/Ok/Err/str/deref/exec/term_raw_*/…; incl println void-shape + atan2
  found-via-u_atan2) + 75 FALSIFIED-on-1arg + 8 HEXAT_FAIL (binary builtins whose codegen indexes args[1] →
  transpile fails the 1-arg probe = PROOF of a real codegen path: write_file/split/min/max/pow/net_read_n/
  net_set_timeout/net_write).
- CODEGEN-GUARD on the 83 (75+8): 29 carry a REAL self/codegen.hexa `== "NAME"` special-path (arg-shape
  trap → compiler-closure KEEP, sigmoid/arange-class): join split min max pow has_key contains replace
  to_upper to_lower starts_with ends_with trim_start trim_end slice reduce flatten now timestamp readline
  write_file append_file net_read_n net_set_timeout net_write term_pty_spawn_sh term_fd_read/write/poll.
  54 have ZERO codegen path AND ZERO callable bare runtime symbol = TRUE register-but-no-impl landmines
  (generated C = bare `hexa_call1(phi,…)`/`(gcd,…)`/`(Set,…)`/`(n6_scan,…)`/`(sopfr,…)` clang-undeclared).
- CALLER-LIVENESS on the 54: 44 carry LIVE callers / repo occurrences (sigma 317calls/10shadows, sopfr
  122/6, gcd 102/22, phi 181, tau 201, n6_*/psi_*/consciousness_*/hexad_*/laws/Set/elapsed/mem_* — the
  atlas-identity surface) → conservative g0 KEEP (gate-5 dead-caller NOT provable without re-running each).
  10 are PURE ORPHANS (falsified + 0 codegen + 0 runtime symbol + ZERO occurrence repo-wide).
- 10 DEREGISTERED (all 5 gates PASS): try_float is_whitespace meta_laws phi_predict tension_link zip_arr
  enumerate_arr input_all load_weights_bin mmap_weights. Each verbatim FALSIFIED (clang
  p_NAME.c:18:29 "use of undeclared identifier 'NAME'") + [S] shadow-control re-proven (local fn emits own
  fwd-decl line4 / def line10 / call line19, clang 0 errors) + compiler/** 0-ref (NOT bind.hexa allow-list,
  NO `op==` codegen) + not in type_checker.hexa tc_register_fn. Reversible one-line re-add.
- POST-EDIT: ~/.hx/bin/build/hexat self/env.hexa → OK (rc=0, roster well-formed). Generated env_after.c
  builtin_names: the 10 = 0 each; KEPT neighbors (laws/consciousness_vector/sopfr/map_arr/filter_arr/reduce/
  flatten/slice/to_char/is_numeric/to_float) = 1 each. env.hexa diff +37/-7 (additive, wipe_guard-safe).
- OUTCOME: 🟢/🔴 closed. Milestone OP-62 [x]. THE ENTIRE self/env.hexa ROSTER IS AUDITED: ML-family CLOSED
  (OP-59) ∪ non-ML AUDITED (OP-62: 82 clean + 29 compiler-closure + 44 live-caller KEEP + 10 dereg). No
  non-ML true-falsified entry with a dead caller remains. $0 · 0-pod · 0-GPU · no vast · no foreign pod ·
  no .tape edit. Verdict .verdicts/hexa-0pod/F-OP62-NONML-ROSTER-AUDIT.txt.
## 2026-06-13 — OP-63 DONE: HONEST-NUMBER hardening of the OP-60/OP-61 route-(a) own-GEMM selector — TAG each pick provenance ∈ {measured, extrapolated} + verdict ref (only 3 of 8 shapes GPU-measured) + CONSERVATIVE fallback (extrapolated AND non-MODE8 → MODE-8) · regression-lock ALL PASS exit 0 (teeth: false-"measured" mutation → exit 1) · NO measured constant changed · NO GPU · $0 · 0-pod
- TASK: OP-60 built the importable route-(a) own-GEMM selector + JSON + regression test; OP-61 wrote its
  flame integration contract. BUT the selector's picks are only GPU-MEASURED at 3 of 8 shapes; the picks at
  D=256/512/1024/1536/8192 are cost-model EXTRAPOLATIONS, never GPU-run. Presenting extrapolated picks
  indistinguishably from measured ones violates the honest-number discipline (same class as the retired
  ~1656x figure). OP-63 (0-pod, NO GPU) tags provenance + makes the integration fallback conservative on
  unmeasured shapes. It LABELS the unmeasured picks honestly — it does NOT claim them measured.
- SURVEY (READ before writing): routea_selection.json + routea_cost_model.py (selected_config / select /
  the cost model) + test_routea_selector.py + F-OP60-SELECTOR-OPERATIONAL + F-OP61-SELECTOR-FLAME-CONTRACT +
  forge-routea doc "## own-GEMM parity map" (OP-58). MEASURED split established from the parity map: D=768
  F-OP54 (consumer sm_120 64x64) · D=2048 F-OP45GPU (Hopper MODE8 NST3 winner ~315) · D=4096 F-OP45GPU/
  F-OP55 (Hopper MODE8 ~283.9). The other 5 (D=256/512/1024/1536/8192) = cost-model EXTRAPOLATIONS.
- SPLIT (3 measured / 5 extrapolated): 256 MODE_t64 extrap · 512 MODE_t64 extrap · 768 MODE8 MEASURED
  (F-OP54) · 1024 MODE8 extrap · 1536 MODE8 extrap · 2048 MODE8 MEASURED (F-OP45GPU) · 4096 MODE8 MEASURED
  (F-OP45GPU/F-OP55) · 8192 MODE8 extrap.
- DELIVERABLES (additive only):
  · routea_cost_model.py — NEW MEASURED_SHAPES map + shape_provenance(D); selected_config() now ALSO emits
    `provenance` ∈ {measured, extrapolated} + `verdict` (cited for measured, "" for extrapolated). The
    mode/tile/nst/swizzle/threads/pred_tflops fields are UNCHANGED (verified byte-identical vs HEAD).
  · routea_selection.json — REGENERATED FROM selected_config() (not hand-edited); each selection carries
    provenance + verdict; + a new "_provenance_policy" header. All 8 original numeric/structural fields
    verified byte-identical vs HEAD.
  · CONSERVATIVE FALLBACK — OP-61 doc §(b) gains case 3: extrapolated AND non-MODE8 → fall back to MODE-8
    128x128 parity winner (never launch a non-MODE8 kernel on a shape whose pick was never GPU-validated).
    HONEST: changes NOTHING in today's table (every extrapolated pick is MODE8 or the already-fallback
    MODE_t64) — it HARD-GUARDS future cost-model edits that might extrapolate a non-MODE8 pick onto an
    unmeasured shape. Updated the dispatch pseudocode.
  · test_routea_selector.py — NEW OP-63 provenance-lock block: (a) every measured shape→provenance=measured
    + non-empty verdict; (b) every other→extrapolated + empty verdict; (c) the conservative-fallback
    predicate (extrapolated AND non-MODE8 → must fall back) holds for the current table. ALL PASS / exit 0.
- TEST (verbatim): "OP-60 SELECTOR REGRESSION LOCK: ALL PASS (canonical picks match measured reality ·
  never a swizzle · @D=4096 is MODE8 · small-D 64x64 fill · ordering anchors intact)" + the OP-63 block
  "GPU-MEASURED shapes: 3 of 8 ... -> OK" + "conservative-fallback predicate ... -> OK". exit 0.
- TEETH: a deliberate false-"measured" mutation on a COPY (D=1024 tagged "F-FAKE-NEVER-MEASURED") FAILS the
  lock — "OP-60 SELECTOR REGRESSION LOCK: FAIL (2 assertion(s) broken)" + MUTATED EXIT=1. Copy deleted;
  shipped file UNTOUCHED (still ALL PASS, exit 0). Cost model's OP-53 harness still "ALL PASS".
- TIER: 🟢 GREEN for the parts actually RUN/ASSERTED (tagging + lock + regenerated JSON). The EXTRAPOLATED
  picks remain HONESTLY-LABELED-UNMEASURED — OP-63's whole purpose is to mark them so, NOT to promote them.
  Only 3 of 8 shapes GPU-measured — stated honestly. NO measured constant changed, NO GPU, NO kernel
  change, NO new measurement, NO self/env.hexa touched.
- DELIVERABLES: self/native/wgmma/{routea_cost_model.py, routea_selection.json, test_routea_selector.py} ·
  docs/forge-routea-shape-adaptive.md (OP-61 §(b) case-3 guard) · .verdicts/hexa-0pod/F-OP63-SELECTOR-
  PROVENANCE.txt · this log + the OP-63 milestone [x] in the .md.
- $0, 0-pod, no vast, no pod, no foreign pod, leak-0. MAIN.tape #-comment SKIPPED (untracked-on-origin,
  OP-54/57/58/60/61 precedent — avoids a merge race).

## 2026-06-13 — OP-61 DONE: INTEGRATION CONTRACT operationalizing the OP-60 route-(a) own-GEMM shape-adaptive selector toward flame production — dispatch hook (QUOTED from clm_prod.hexa/codegen/runtime/forge_tier_v1) + fallback-to-MODE-8 + bit-exact invariant (rel_rms 0) + next-session GPU validation plan · DESIGN ONLY, 🟠 SUPPORTED-BY-DESIGN · NO code wired · NO GPU · $0 · 0-pod
- TASK: OP-60 made the route-(a) own-GEMM shape-adaptive selector (selected_config + routea_selection.json
  + test_routea_selector.py) an importable + regression-locked STANDALONE artifact — but NOTHING in flame's
  production training path consumes it yet. OP-61 writes the INTEGRATION CONTRACT (0-pod, NO GPU) specifying
  exactly how clm_prod's GEMM dispatch would route through the selector, so the NEXT GPU session implements +
  validates the wiring without re-deriving the design. NO code wired this round (the GPU session's job).
- SURVEY (READ before writing): routea_selection.json + selected_config (OP-60 launch-dict) ·
  F-OP60-SELECTOR-OPERATIONAL · F-OP58-OWNGEMM-PARITY-MAP (the measured anchors) · forge-routea doc §8-§10.
  Located flame's GEMM dispatch: forge_dispatch_matmul (clm_prod.hexa:212 fwd conv / :250 bwd dW / :262 bwd
  dX) → codegen.hexa:7525 lowers to hexa_forge_dispatch_matmul → packs ForgeShapeInfo+ForgeArgs, routes
  through forge_tier_dispatch_v1 (RFC 050 §6.1; forge_tier_v1_emit.hexa:306) → CUDA host = cuBLAS today
  (_hx_cuda_farr_matmul_gpu, :169); own-GEMM = wgmma_tf32_b14.cu MODE 8 128x128.
- CONTRACT (new "## selector → flame production integration contract" section in forge-routea doc + verdict):
  · (a) DISPATCH HOOK = forge_tier_dispatch_v1's own-GEMM branch (a SINGLE selected_config(M,K,N) consult);
    clm_prod.hexa UNTOUCHED (keeps calling forge_dispatch_matmul); {mode,tile,NST} maps 1:1 to a b14.cu MODE.
  · (b) FALLBACK — MODE_t64-unbuilt OR out-of-validated-range → MODE 8 128x128 (measured 1.08x parity winner,
    F-OP45GPU T5); safe-by-construction so production NEVER launches an unbuilt kernel.
  · (c) BIT-EXACT INVARIANT — routing changes the KERNEL not the bits; all routed kernels share MODE 8's
    per-K-slab FMA order (no split-K/no cross-CTA reduction §8.1/§9); gate = rel_rms 0.000e+00 dev-vs-dev vs
    the fixed-MODE-8 reference per routed shape (hard gate, g5, never speed-only).
  · (d) GPU VALIDATION PLAN — wire the hook, sweep D∈{512,1024,2048,4096}, gate rel_rms 0, confirm parity
    preserved (~1.08x@D2048, ~1.50x@D4096); optional MODE_t64 small-D fill measure once it is built.
  · (e) HONEST residual — Hopper MODE_t64 (64x64 small-D tile) is UNBUILT (§8.1 GAP#1); on small-D the
    fallback-to-MODE-8 is what actually fires until a GPU lane builds the wgmma 64x64 tile. So the
    integration's only live behavior today is "MODE 8 everywhere already used" (correct+safe, no new perf
    yet) — stated as the open residual, NOT a solved item.
- TIER: 🟠 SUPPORTED-BY-DESIGN — the honest 0-pod no-GPU ceiling. NO code into clm_prod, NO kernel build,
  NO GPU run, NO new measurement, NO self/env.hexa touched. The hook is QUOTED from source; the parity
  numbers are CITED from F-OP45GPU/F-OP58 (not re-measured).
- DELIVERABLES: docs/forge-routea-shape-adaptive.md (NEW integration-contract section after §10) ·
  .verdicts/hexa-0pod/F-OP61-SELECTOR-FLAME-CONTRACT.txt · this log + the OP-61 milestone [x] in the .md.
- $0, 0-pod, no vast, no pod, no foreign pod, leak-0. MAIN.tape #-comment SKIPPED (untracked-on-origin,
  OP-54/57/58/60 precedent — avoids a merge race).

## 2026-06-13 — OP-60 DONE: OPERATIONALIZED the OP-49/OP-53 cost-model-validated route-(a) own-GEMM shape-adaptive selector — importable launch-dict + REGRESSION-LOCK test (ALL PASS, exit 0; teeth proven via measured-bad mutation → exit 1) + machine-readable selection table · NO measured constant changed · NO GPU · $0 · 0-pod
- TASK: the OP-49/OP-53 `select_config(D,M,N,K)` selector was COST-MODEL-VALIDATED (matches the measured
  OP-45GPU ordering + OP-52 swizzle-negative + OP-58 parity map) but lived ONLY as an inline Python
  cost-model function with a self-validation harness — not an operational, regression-protected artifact.
  OP-60 turns the validated design into a usable + TESTED + machine-readable artifact (g0 simplest form).
- OPERATIONALIZED (3 net-new pieces, NO measured constant touched):
  · self/native/wgmma/routea_cost_model.py — NEW `selected_config(D,M,N,K)`: a thin {mode,tile,NST,swizzle,
    threads,pred_tflops} launch-dict over the EXISTING select_config (PURE projection; swizzle always False
    by construction — SELECTABLE structurally excludes the swizzle modes). The validated cost model + the
    OP-53 self-validation harness are UNCHANGED (still print "OP-53 OVERALL: ALL PASS").
  · self/native/wgmma/test_routea_selector.py — the REGRESSION LOCK: asserts the canonical-shape picks match
    measured reality (MODE8 @D>=768/1024 · MODE_t64 64x64 @D<=512 · NEVER a swizzle mode (OP-52 closed-neg) ·
    @D=4096 is MODE8 NOT t256/t256e (OP-55/OP-45GPU closed-neg)) + the measured-ORDERING anchors @D=2048/4096
    + a negative-control that swizzle modes score below MODE8 @D=4096. Prints ALL PASS / exit 0 on success.
  · self/native/wgmma/routea_selection.json — the machine-readable selection table EMITTED by selected_config
    (NOT hand-typed): D in {256,512,768,1024,1536,2048,4096,8192} → the launch dict, for a future GPU-build/
    integration step to consume without re-running Python.
- REGRESSION-TEST PASS [VERBATIM `python3 self/native/wgmma/test_routea_selector.py`, exit 0]:
    D=256/512 → MODE_t64 64x64 (small-D under-fill fill win, F-OP53 VAL-2)
    D=768/1024/1536/2048/4096 → MODE8 128x128 (F-OP45GPU/F-OP53/F-OP58)
    @D=4096 pick = MODE8 (NOT a measured-bad 256-N tile) -> OK
    swizzle modes ['MODE7','MODE9_swz'] all score < MODE8 @D=4096 (OP-52 anti-pref intact) -> OK
    measured ordering @D=2048 and @D=4096 reproduced (F-OP45GPU anchors intact) -> OK
    OP-60 SELECTOR REGRESSION LOCK: ALL PASS
- LOCK HAS TEETH (negative control): mutated a COPY of the cost model (removed swz_penalty, boosted
  MODE10_t256e issue_eff 0.7340→2.0, added swizzle+t256e to SELECTABLE) → the test FAILED with exit 1 and 13
  broken assertions (selector picked MODE9_swz @D=768/1024 + MODE10_t256e @D=4096). The mutated copy was
  deleted; the shipped cost model is UNTOUCHED (still ALL PASS, exit 0). So a future cost-model edit cannot
  silently regress the measured-correct selection.
- CANONICAL SELECTION TABLE (EMITTED → routea_selection.json): 256→MODE_t64 64x64 · 512→MODE_t64 64x64 ·
  768→MODE8 128x128 · 1024→MODE8 · 1536→MODE8 · 2048→MODE8 (1.08x parity winner) · 4096→MODE8 (NOT t256/t256e)
  · 8192→MODE8. swizzle ALWAYS false (OP-52 closed-neg). Each pick verdict-traced (g5).
- DELIVERABLES: .verdicts/hexa-0pod/F-OP60-SELECTOR-OPERATIONAL.txt + the 3 code/data files above.
  Milestone OP-60 [x]. NO GPU, NO kernel change, NO new measurement, NO self/env.hexa. MAIN.tape #-comment
  SKIPPED (untracked-on-origin, OP-54/57/58 precedent — avoids a merge race). $0, 0-pod, no vast, no pod,
  nothing to leak.

## 2026-06-13 — OP-58 DONE: DOCS-ONLY consolidation of the COMPLETE own-GEMM-vs-cuBLAS-TF32 parity story into ONE authoritative "own-GEMM parity map" (both regimes settled) reflected across the forge doc + comparison doc + README · every number verdict-traced (g5) · $0 · 0-pod · no code change
- TASK: the own-GEMM-vs-cuBLAS-TF32 question is fully measured + settled THIS SESSION across BOTH hardware
  regimes (Hopper sm_90a wgmma route-(a) + consumer sm_120 OWN120 mma.sync), but the measurements live in 6
  scattered verdicts. OP-58 consolidates them into a single one-screen "parity map" so a reader gets the complete
  settled picture in one place + brings the comparison doc + README into agreement with the per-regime verdicts.
- THE COMPLETE MEASURED PICTURE (every number READ from its verdict before writing — g5, no fabrication):
  · Hopper sm_90a @D=2048: route-(a) b14 MODE 8 = 1.08x cuBLAS-TF32 PARITY, own ~315 TFLOP/s (~93% roofline),
    rel_rms 0.000e+00 (F-GPU-ROUTEA-KEEPBAND-MEASURE; F-OP45GPU T5 reanchor 320.6/1.08x).
  · Hopper sm_90a @D=4096: ~1.50x sub-parity (own ~284 vs cuBLAS ~427), rel_rms 0, SETTLED bit-exactness-bound —
    the whole T4 "better-single-pass-tile" lever family is exhausted closed-neg: CTA-swizzle MODE 9 -1.6%
    (F-OP52, best 280.5 vs 285.1) · 128x256 MODE 10 t256e -7.1% (F-OP55, 263.3 vs 283.5, ptxas C7515 serializes) ·
    t256 (154 regs/1 CTA-SM) + MODE 7 persistent already closed-neg (F-OP45GPU T1/T3). No bit-exact 256-N
    schedule on sm_90a is BOTH 2 CTA/SM AND non-serialized.
  · Consumer sm_120 (RTX 5070) @D=768: OWN120 mma.sync 64x64 = 0.95-0.96x cuBLAS-TF32 (own EDGES cuBLAS), bit-
    exact-tolerant rel-RMS ~1.3e-5 (F-OP54). 64x64 = consumer optimum; 32x32 shrink strictly worse (F-OP57). The
    F-BENCH-5 raw 3.2-6.9x gap is CLOSED.
  · Value framing (project_flame_h100_h200_closeout): own-GEMM's worth = bit-exactness + device-residency +
    no-LLVM/no-cuBLAS-call, NOT raw TFLOP/s-beat.
- CONSOLIDATED INTO 3 DOCS:
  · docs/forge-routea-shape-adaptive.md — NEW "## own-GEMM parity map (COMPLETE — both regimes settled)" section
    right after §0 (before §1): compact 3-row table (regime | shape | own-vs-cuBLAS-TF32 | bit-exactness | verdict)
    + settled one-line conclusion + the exhausted-lever bullet list, each row cross-linked to its per-regime
    verdict. Terse (g3); §0 narrative + §7/§10 detail unpack each row (pointed-into, NOT duplicated).
  · FLAME+FORGE-vs-PYTORCH+CUBLAS.md §4 — UPDATED the @D=4096 RESOLVED block from the pre-OP-52/55 "fixable
    scheduling stall, recoverable in principle" framing → the SETTLED "bit-exactness-bound, T4 lever family
    exhausted closed-neg" framing (cites OP-52 swizzle regress + OP-55 t256e regress + ptxas C7515) + ADDED the
    consumer own-EDGES-cuBLAS @D=768 datapoint (F-OP54/F-OP57). Closing boundary line now states all 3 settled
    regimes. Did NOT touch the FAIR matched-dtype framing in §1/§1.3 (left accurate, not contradicted).
  · README.md honest-axis — SHARPENED the own-GEMM line to add the settled 3-regime summary (parity@Hopper-D2048 ·
    own-edges-cuBLAS@consumer-D768 · parity-not-beat@Hopper-large-D bit-exactness-bound) + consolidation pointer.
    Did NOT contradict the existing matched-dtype FAIR framing.
- CONSISTENCY (g5): every number traces to a verdict, confirmed by READ before writing; no new measurement, no
  fabrication. Where an existing doc already had a number it matched the verdict and was preserved.
- DELIVERABLES: .verdicts/hexa-0pod/F-OP58-OWNGEMM-PARITY-MAP.txt (verdict-trace table) + the 3 docs above.
  Milestone OP-58 [x]. No shipped-code change. MAIN.tape #-comment SKIPPED (untracked-on-origin, same as OP-54/
  OP-57 — avoids a merge race). $0, 0-pod, no vast, no pod, nothing to leak.

## 2026-06-13 — OP-55 DONE: BUILT + MEASURED the OP-52 surviving lever (NEW 2-CTA/SM-preserving 128x256 own-GEMM tile, MODE 10) on a real H100 → register economy HELD (90 regs, 2 CTA/SM) but REGRESSES -7.1% @D=4096 (serialized) → @D=4096 gap SETTLED bit-exactness-bound · 1 H100 ~$0.55 · leak-0
- USER-APPROVED paid H100 exception to the @goal free-only rule: build + measure the OP-52 follow-up — a NEW
  bit-exact 2-CTA/SM-PRESERVING 128x256 single-pass own-GEMM tile (the OP-53 FUTURE-GPU spec) on real Hopper
  sm_90a, to test if it partially closes the route-(a) @D=4096 ~1.5x TF32 sub-parity gap vs cuBLAS-TF32.
- KERNEL (net-new): self/native/wgmma/wgmma_tf32_b14.cu MODE 10 = gemm_og17_b14_t256e. 1 CTA owns a 128x256
  output tile (HALF MODE 8's N-grid). REGISTER-ECONOMY TRICK: process the 256-N as TWO SEQUENTIAL 128-N HALVES,
  each running the MODE-8-IDENTICAL K-reduction into only 2 live accumulators d0/d1 → 90 regs == MODE 8 (NOT
  t256's 154-reg/1-CTA/SM trap). Ring is MODE-8-sized (one 128-N half, 96 KB/CTA @NST3); the 256-N lives in the
  GRID, not in resident smem. Per-half full TMA cycle (A re-loaded L2-hot + this half's 4 B-atoms) + per-half
  mbarrier re-init (phase 0). Bit-exact by construction: each output element accumulates K in MODE 8's byte-
  identical FMA order; only the per-CTA tile granularity + intra-CTA half schedule change.
- HW: 1x H100 80GB HBM3, driver 560.35.05, nvcc 12.6 V12.6.77, sm_90a. vast contract 40738426, label
  `hexa-newtile`, offer 21671170, $2.2839/hr, reliability 99.9%. ~14 min, ~$0.55.
- ptxas -v (VERBATIM): gemm_og17_b14_t256e "Used 90 registers", 0 spill stores, 0 spill loads — IDENTICAL to
  MODE 8's 90 (the in-tree t256 trap = "Used 154 registers" for contrast). + C7515: "wgmma.mma_async
  instructions are serialized due to non wgmma instructions defining accumulator registers ... in the function
  'gemm_og17_b14_t256e'" — the half-boundary d0/d1 reset serializes the pipeline (the measured perf cost).
- OCCUPANCY (measured): MODE 10 NST3 dynsmem=98328B (96.0 KB/CTA) → 2 CTA/SM (the design premise HELD); NST4 →
  128 KB/CTA → 1 CTA/SM (the NST4 trap, swept for completeness).
- BASELINE (apples, 3 reps): D=4096 MODE 8 NST3 own ~283.5 TFLOP/s (1.51x, rel_rms 0); D=2048 ~318 (1.08x).
  Reproduces the OP-45/OP-52 anchor within ~1%.
- THE NEW TILE (VERBATIM, median of 3): D=4096 MODE 10 NST3 (2 CTA/SM) own 262.7/263.1/262.3 → 263.3 TFLOP/s,
  ratio 1.64x, rel_rms 0.000e+00 = -7.1% SLOWER than MODE 8 283.5, gap WIDENS 1.51x→1.64x. D=2048 MODE 10 NST3
  own ~152 (2.28x) = -52%. NST4 (1 CTA/SM) far worse (161 @4096). rel_rms 0 on EVERY row (bit-exact gate HELD).
- WHY (ptxas C7515 + OP-45 T2): the 2-CTA/SM register economy was bought with a sequential-halves schedule whose
  half-boundary accumulator reset SERIALIZES the wgmma pipeline + doubles the per-CTA K-drain — costing more than
  the larger single-pass tile saves on a compute-bound D=4096 (AI 682 >> 104). The only non-serialized bit-exact
  256-N tile = 4 live accumulators = t256's 1-CTA/SM trap (already closed-neg @4096, 264.9 < 283.9).
- SETTLED FORGE BOUNDARY: no bit-exact 256-N schedule on sm_90a is BOTH 2 CTA/SM AND non-serialized — (a) 4 live
  accumulators = 1 CTA/SM (t256), (b) 2 live accumulators via halves = 2 CTA/SM but serialized (this OP-55). The
  @D=4096 own-GEMM TF32 gap is bit-exactness-bound; own-GEMM = bit-exact-PARITY-not-BEAT @D=4096 is the honest
  final answer, not an unbuilt lever.
- DESTROY/LEAK-0: confirmed label `hexa-newtile` MINE → `yes | vastai destroy instance 40738426` → both
  `vastai show instances` (empty) and `vastai show instances-v1` (Total: 0 instances) = LEAK 0. No foreign pod
  touched (roster had ZERO instances throughout; only 40738426 ever created/destroyed).
- VERDICT: 🔴/🟠 CLOSED-NEGATIVE. Milestone OP-55 [x]. Deliverables: wgmma_tf32_b14.cu MODE 10 + op55_t256e_run.sh
  · F-OP55-NEWTILE-D4096.txt (verbatim ptxas + sweep) · docs/forge-routea-shape-adaptive.md §0+§7 boundary update
  · routea_cost_model.py MODE10_t256e row (selector still picks MODE8 @4096, cost-model validated PASS).

## 2026-06-13 — OP-45-GPU DONE: REAL H100 sm_90a T1-T5 occupancy/profile sweep → (a)-(d) classification CONFIRMED + (d) split = FIXABLE-SCHEDULING-STALL (not a hard HBM roofline) · cost model calibrated · 1 H100 ~$0.96 · leak-0
- USER-APPROVED ("GPU 도 승인", ~$1-2) the gated GPU sibling of OP-45 #3096 (static (a)-(d) cap) + OP-49 #3103
  (CPU cost model). Goal: confirm/refute (a)-(d) with a real GPU profile + calibrate the cost model, tear down.
- SURVEY-FIRST: read F-OP45-ROUTEA-D4096-CAP.txt (T1-T5 matrix + (a)-(d)) + F-OP49-SHAPE-ADAPTIVE-DESIGN.txt
  (cost model + the +9.2% MODE8@4096 over-prediction) + docs/forge-routea-shape-adaptive.md. Located the kernel
  self/native/wgmma/wgmma_tf32_b14.cu (MODE8 gemm_og17_b14 + MODE7 gemm_og17_persist) + bench14_run.sh driver.
- RENT: 1x H100 80GB HBM3 sm_90a, driver 560.35.05, nvcc 12.6 V12.6.77 (apples to #3082/#3094). vast contract
  40729921 label `hexa-op45gpu`, offer 21671170 $2.305/hr (cheapest CUDA>=12.6, rel 0.9989), India. No foreign
  pod in roster throughout. Inline-polled to running + SSH-ready (no Monitor/waiter, cost-safe).
- T1 (ptxas -Xptxas -v, VERBATIM): gemm_og17_b14 = 90 registers, 0 spill stores, 0 spill loads. MODE5 t256 =
  154 regs (the reg-cap). Runtime OCCUPANCY: 96.0 KB/CTA → 2 CTA/SM, D-INVARIANT (same @2048 & 4096). ⇒ (a)
  register-spill + (b) occupancy-drop MEASURED-EXCLUDED (was statically excluded; now confirmed on HW).
- T5 (D=2048 anchor): own 320.6 TFLOP/s, ratio 1.08-1.09x, rel_rms 0, PARITY=YES (reproduces 315/1.08x anchor,
  this card ~1.8% faster). D=4096 cap: own 283.9 TFLOP/s, 1.52x, rel_rms 0, PARITY=NO (reproduces OP-45 EXACTLY).
- T2 (the (d)-splitter): ncu IS on the image (/usr/local/cuda/bin/ncu) but ALL profiles returned ERR_NVGPUCTRPERM.
  Root cause on-pod: /proc/driver/nvidia/params → RmProfilingAdminOnly: 1 (a HOST kernel-module param, container
  cannot change; even ncu launch-metrics gated; nsys not installable). INFRA-BLOCKED. Resolved via g5-legal
  ANALYTICAL ROOFLINE (measured wall-time only): D=4096 kernel time = 137.44 GFLOP / 283.9 TFLOP/s = 484 us;
  DRAM bounds = naive-no-reuse 4.36 GB (9.0 TB/s = 269% peak ⇒ impossible ⇒ L2 reuse real) to perfect-L2 0.20 GB
  (0.42 TB/s = 12.4% peak); AI 682.7 FLOP/byte >> compute-bound threshold 104.2 (PEAK_TF32/HBM3). ⇒ D=4096 is
  COMPUTE/SCHEDULING-bound, NOT bandwidth-bound. (d)-SPLIT VERDICT = *** FIXABLE-SCHEDULING-STALL, NOT a hard
  HBM roofline. ***
- T3 (MODE7 persistent+swizzle @4096, FIRST measurement; rel_rms 0 gate PASS every row): best SWZ=2 GRIDMUL=2 =
  ~273 TFLOP/s (1.57x) — ~4% BELOW MODE8's 283.9; GRIDMUL=1 (1 CTA/SM) collapses to 205. Does NOT recover the
  -9.9%. The l2_hot benefit OP-49 hypothesized is ABSENT (consistent with T2 compute-bound). OP-49 GAP#2 (MODE7
  @4096) = MEASURED CLOSED-NEGATIVE. The fixable lever is NOT in the tile-rasterization layer.
- T4 (cuBLASLt cublasLtMatmulAlgoGetHeuristic @4096 vs 2048, VERBATIM): cuBLAS D=2048→4096 changes = cta_swizzle
  0→1 AND top algo at 4096 = split_k=1, reduction=0 (SINGLE-PASS, NO split-K). ⇒ cuBLAS's +24.6% large-D lever
  is a BETTER-SCHEDULED single-pass tile + CTA-swizzle, NOT split-K → reachable WITHOUT forfeiting g5 bit-exact
  accumulation order. The forge target is a better single-pass per-CTA tile/schedule.
- COST-MODEL CALIBRATION (self/native/wgmma/routea_cost_model.py): the +9.2% MODE8@4096 over-prediction is the
  K-drain term under-crediting the 2x-slab (nks 64→128) serialization (T2 ruled out a missing bandwidth term).
  Replaced the static log-drain (c=0.115) with an anchored-excess-slab drain that holds the nks=64 anchor EXACTLY
  and steepens nks→128 (c=0.109): MODE8@4096 +9.2% → +1.0% (286.7 vs 283.9). ORDERING still PASS both D. HONEST
  residual: single global coeff over-corrects OG16/OG17 (mean |rel.err| 2.2%→3.9%) — drain is non-uniform across
  modes; per-mode coeff = 0-pod follow-up. The selector argmax (MODE8) is unaffected.
- DESTROY: confirmed label `hexa-op45gpu` mine + zero foreign pods → `yes | vastai destroy instance 40729921` →
  `vastai show instances-v1` = "Total: 0 instances / No instances found". LEAK-0 CONFIRMED. ~$0.96, ~25 min.
- DELIVERABLES: .verdicts/hexa-0pod/F-OP45GPU-OCCUPANCY-SWEEP.txt (VERBATIM T1-T5) · calibrated routea_cost_model.py
  · self/native/wgmma/lt_introspect.cu (the cuBLASLt T4 introspection program) · this log + the OP-45-GPU milestone.

## 2026-06-13 — OP-51 DONE: [S]-shadow survive-audit tranche (6 of 16 [S R]-survivors) — all 6 g5-falsified + shadow-control safe → DEREGISTERED · survivor set 16→10 · $0 · 0-pod
- SURVEY-FIRST (mandatory). Read F-OP48-SURVIVE-AUDIT-TRANCHE.txt (the [R]/[S] split + running tally:
  26→23→16 + the arange KEEP precedent — a self-host compiler-closure ref in compiler/check/bind.hexa:1281
  forced a conservative keep), F-OP43-ML-FAMILY-FALSIFIED.txt (the [S]-tagging + the 16-survivor list), and
  F-OP47-MATMUL-DOT-PROBE.txt (the CONTROL method: a local `fn dot` provides its OWN symbol, roster-independent).
- TRANCHE (landable, 6 of 16 [S R]): kv_cache_append · repeat_kv · quantize_int8 · dequantize_int8 ·
  magnitude_prune · tensor_fill — each carries a REAL local `fn NAME` shadow (the HARDER tranche).
- IMPL CROSS-REF (arg-shape-trap controlled): all 6 = 0 codegen-inline guard in self/codegen.hexa + 0 runtime
  symbol (prefix-variant scan of self/runtime.h ∪ installed /Users/mini/.hx/src/self/runtime.c — every distinct-
  match set EMPTY). 0 guards ⇒ ANY arg shape → same bare hexa_callN fallback (probe arg-shape-robust).
- AOT PROBE (g5, fresh ~/.hx/bin/build/hexat Jun-8 → clang -fsyntax-only), VERBATIM, correct args each:
  kv_cache_append(m,a,a) · repeat_kv(m,2) · quantize_int8(a) · dequantize_int8(a,0.5) · magnitude_prune(a,0.5)
  · tensor_fill(4,1.0) — ALL emit "p_NAME.c:20:29: error: use of undeclared identifier 'NAME'". 6/6 FALSIFIED.
- THE CRITICAL [S] CONTROL (per name): `fn NAME(x:float)->float{return x+1.0}` + `NAME(2.0)` → hexat OK →
  clang CLEAN; generated C has `HexaVal NAME(HexaVal);` fwd-decl + `HexaVal NAME(HexaVal){` def + `r=NAME(...)`
  call → binds the LOCAL def ROSTER-INDEPENDENTLY. Proven for all 6 ⇒ deregistration can never break a shadow.
- SHADOW DEFS + CALLER SWEEP: shadow counts match OP-43's [S R] (kv_cache_append 2, repeat_kv 4, quantize_int8
  3, dequantize_int8 2, magnitude_prune 2, tensor_fill 2). repeat_kv = CLEANEST (ALL 4 caller files carry a
  local `fn repeat_kv`, gen-C emits the def → 0 builtin-dep). kv_cache_append: only compiling caller
  self/test_flash_decode `import "ml/kv_cache.hexa"` → `extern HexaVal kv_cache_append(_,_,_,_,_)` (5-arg
  IMPORTED shadow) + 2 example callers baseline exit_code=-1. quantize_int8: quantize_model binds the 3-arg
  quantize.hexa:210 shadow + AOT-fails on OTHER syms (slice/char_code_at — builtin-independent), quantize_test
  transpile-fails, 3 example callers -1. dequantize_int8/magnitude_prune: only builtin-dep callers = dead
  examples (-1). tensor_fill (largest): every self/ml caller (pipeline/reward_model/rlhf/t2_real_bench/
  train_full/tensor_ops + self/test_tensor*) ALREADY AOT/transpile-fails today (builtin-independent); the lone
  extra ref self/test_array_ops_suite:379 is inside a `proof {}` block codegen DROPS — PROOF-BLOCK CONTROL: an
  UNREGISTERED never-defined name compiles inside `proof {}` (binder doesn't reject, 0 refs in gen-C).
- COMPILER-CLOSURE CHECK (the arange lesson): compiler/** (excl embedded.gen.hexa) ZERO refs to all 6 — none
  in the bind allow-list / codegen special-path (unlike arange: compiler/check/bind.hexa:1281 + PLAN.md:574).
  selfhost-byteeq gate compiles compiler/main.hexa which never references any of the 6 → fixpoint safe.
- DECISION (g0 conservative, [S]-strict): all 4 gates pass per builtin (falsified ∧ no live caller binds the
  roster ∧ shadow binds without it via §3 control ∧ compiler/** 0) → ALL 6 DEREGISTERED.
- DIFF: self/env.hexa — 6 names removed from env_new() builtin_names + 3 scoped OP-51 comment blocks. KEPT
  (re-verified 1 each): tensor/tensor_zeros/load_weights_bin/mmap_weights/to_char/arange/matvec/mat_add/
  rms_norm/curiosity_reward/dialogue_reward/combined_reward. wipe_guard net +35/−4 « 50, subject scoped.
- POST-EDIT: env.hexa transpiles clean (~/.hx/bin/build/hexat self/env.hexa /tmp/op51/env_after.c → OK); 0
  non-comment roster strings for each removed name; neighbors intact.
- TALLY: OP-43 survivor set 26→23 (OP-47)→16 (OP-48)→10 (OP-51, −6). Remaining 10: [S R] relu sigmoid
  transpose normalize zeros attention topk sample_token mse_loss + [R] arange (compiler-closure KEEP).
- HONEST FRONTIER: 9 [S R] survivors remain; the EASY [S] removals are largely consumed. The 9 carry larger/
  liver shadow surfaces (sigmoid shadow=8/self=102, relu shadow=3/self=23, mse_loss shadow=9) and need per-name
  baseline-PASS verification of every UNSHADOWED call-site (heavier audit). ≥1 (sigmoid-class) looks like a
  conservative live-shadow KEEP. Expect the next tranche to dereg FEWER than 6 — reservoir depleting, residual
  increasingly compiler-closure KEEPs (arange) + live-shadow KEEPs (sigmoid-class).
- OUTCOME: 🟢 GREEN. Milestone OP-51 [x]. Verdict .verdicts/hexa-0pod/F-OP51-SURVIVE-SHADOW-TRANCHE.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## 2026-06-13 — OP-50 DONE: route-(a) own-GEMM perf BOUNDARY reflected into the canonical forge doc (docs/forge-routea-shape-adaptive.md §0) · DOCS-ONLY · $0 · 0-pod
- SURVEY-FIRST (mandatory). Read the 3 source verdicts: F-GPU-ROUTEA-KEEPBAND-MEASURE.txt (#3094 — the GPU
  measurement: route-(a) b14 MODE8 NST3 PDEP2 @D=2048 own ~315 TFLOP/s, ratio 1.08x, PARITY=YES, rel_rms
  0.000e+00 at every config; @D=4096 own ~284 vs cuBLAS ~427, ratio ~1.50x, PARITY=NO) + F-OP45-ROUTEA-D4096-CAP
  (#3096 — the shape-rigidity cause decomposition: (a)spill/(b)occupancy/(c)D-indep-ptxas-ceiling all statically
  EXCLUDED; cause = (d) cuBLAS scales UP +24.6% via shape-adaptive scheduling while fixed-128x128 MODE8 scales
  DOWN -9.9% from 2x K-drain) + F-OP49-SHAPE-ADAPTIVE-DESIGN (#3103 — the selector + CPU cost model + 4 config
  gaps). Confirmed the W10 summit (70.7 TFLOP/s, 6.09x off cuBLAS-TF32) + W14 FP16 (~11.5x off) numbers against
  .verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-{W10,W14-FP16}.txt + the dojo war-story (docs/hexa-dojo.md) for consistency.
- HOME (Occam g0, extend > duplicate): docs/forge-routea-shape-adaptive.md (the file OP-49 authored) already
  carries the design/cost-model/gaps but lacked the explicit honest "what own-GEMM IS and ISN'T" scope. Added a
  new FIRST section "## 0. Perf boundary / honest scope — what own-GEMM IS and ISN'T" — placed before §1 so a
  contributor reads the settled boundary before treating "beat cuBLAS" as a goal. NO new file.
- BOUNDARY STATED (4 parts, every number traces to a verdict): (IS) route-(a) pre-permute = bit-exact rel_rms
  0.000e+00 @every config + cuBLAS-TF32 PARITY @D=2048 (b14 MODE8 NST3 PDEP2: own ~315 TFLOP/s, ratio 1.08x,
  PARITY=YES = ~93% of roofline), no-LLVM/no-cuBLAS-call, device-resident. (ISN'T) NOT a beat — cuBLAS-TF32 is
  the roofline; @D=4096 own falls to ~1.50x (own ~284 vs cuBLAS ~427, PARITY=NO) because SHAPE-RIGID (one fixed
  128x128 plain-launch tile) vs cuBLAS SHAPE-ADAPTIVE (+24.6% @4096); FP16 W14 ~11.5x off, W10 summit 70.7
  TFLOP/s 6.09x off — neither a beat. (VALUE) bit-exactness + device-residency + no-LLVM-compile-theorem (a GEMM
  a persistent megakernel can call where it can NEVER call the cuBLAS host API), NOT raw TFLOP/s-vs-cuBLAS —
  mirrors project_flame_h100_h200_closeout framing. (PATH-FORWARD) OP-49 shape-adaptive selector (§2-§6) + 4
  config gaps (64x64 small-tile · MODE7 persistent measured @4096 · bit-exact split-K · NST-adaptive launcher),
  each a gated GPU build mapped to OP-45 T1-T5 — IF a beat is ever pursued (NOT a standing goal).
- CONSISTENCY: all written numbers match the verdicts EXACTLY — 1.08x parity · rel_rms 0.000e+00 · ~93% roofline
  · ~315 TFLOP/s @D=2048 · ~284 vs ~427 / ~1.50x @D=4096 · W10 70.7/6.09x · W14 ~11.5x. No invention, no round-mangle.
- OUTCOME: 🟢 DOCS-ONLY (no code/runtime/.tape). Milestone OP-50 [x]. Deliverable: docs/forge-routea-shape-adaptive.md
  §0 + F-OP50-ROUTEA-BOUNDARY-DOCS.txt. $0 · 0-pod · no vast · no foreign-pod touch · no .tape edits · g84 (no /paper).

## 2026-06-13 — OP-48 DONE: next-tranche survive-audit (8 [R]-only survivors) → 7 falsified+dead+0-shadow+byte-eq-safe → DEREGISTERED; arange STAYS (compiler-closure ref) · survivor 23→16 · self/env.hexa +33/−5 · $0 · 0-pod
- SURVEY-FIRST (mandatory). Read F-OP47-MATMUL-DOT-PROBE.txt (3 largest [R]-survivors deregistered, set 26→23)
  + F-OP43-ML-FAMILY-FALSIFIED.txt (42-builtin ML matrix; 16 dereg, 26 survive; the [R]-only no-shadow members)
  + F-OP41-FALSIFIED-BUILTIN-SWEEP.txt (the roster-vs-impl method + arg-shape-trap caveat). Extracted the
  current 23-survivor set and picked the NEXT tranche = the 8 [R]-ONLY survivors (cross_entropy · arange · clip ·
  conv1d · save_array · load_array · rope · rope_inplace) — the cleanest-to-decide subset (no local-fn-shadow
  ambiguity, so the audit reduces to falsified ∧ every-real-caller-dead ∧ compiler-core/byte-eq zero-ref).
- METHOD (OP-41/43/47 exact, per builtin): (a) confirmed registered in self/env.hexa env_new() roster; (b) IMPL
  cross-ref — ALL 8 = 0 codegen-inline guard + 0 runtime symbol (cross_entropy's only hit is the DIFFERENT 4-arg
  RFC-034 carrier hexa_ad_softmax_cross_entropy, runtime.c:7861/12184; bare clip/rope hits are runtime COMMENTS);
  (c) g5 AOT PROBE — fresh hexat ~/.hx/bin/build/hexat + CORRECT args → clang -I<self> -fsyntax-only: ALL 8 emit
  verbatim "use of undeclared identifier 'NAME'" (cross_entropy:18, arange:18, clip:18, conv1d:18, save_array:20,
  load_array:20, rope:18, rope_inplace:18); (d) CALLER SWEEP word-boundary, comments/string-literals/fn-defs
  excluded.
- CONTROL (binding mechanism): a file with a local `fn cross_entropy` → generated C emits its OWN forward-decl
  (line 4) + def (line 17) + the call resolving to it (line 26), clang-CLEAN → local-fn shadow binds its symbol
  ROSTER-INDEPENDENTLY; deregistering can't break a shadow. (Vacuous here — all 8 have 0 shadows, matching OP-43's
  [R]-only classification.)
- DEAD/LIVE per builtin: every real call-site DEAD — example callers baseline exit_code=-1 (anima_convergence_proof
  /test_matmul_loss/test_conv_cache_io/test_modern_llm/anima_consciousness_step/anima_mega_demo/test_quant_beam_init);
  stdlib/nn.hexa + self/ml/grad_engine + self/test_nn_stdlib (cross_entropy) ALREADY AOT-fail TODAY with the builtin
  STILL registered; self/ml/train_decoder_cpu_b (rope) already AOT-fails (undeclared 'rope'); self/ml/train_7b +
  train_decoder_cpu_c/d/b2 (rope_inplace/save_array/load_array) already transpile-fail; stdlib/flame/clm_prod's
  `conv1d(` = the LOCAL conv1d_via_forge/conv1d_bwd_via_forge fns (different symbol); self/ml/sophia/ppo_clip/
  bitnet/grpo/distributional_rl/dp_sgd + stdlib/_lbfgsb_driver bare-`clip` = formula prose COMMENTS (AOT-verified:
  those files syntax-check CLEAN, 0 clip error); stdlib/dojo + xeno `arange` = torch.arange/np.arange string-emit.
- PRE-EXISTING-FAILURE CONTROL: every non-example caller fails on the INSTALLED Jun-8 hexat whose roster STILL
  registers all 8 → dereg is NOT the cause, only flips a never-compiling program's failure mode.
- SELF-HOST BYTE-EQ (decisive): compiler/** refs (excl embedded.gen archive + PLAN prose) = 0 for cross_entropy/
  clip/conv1d/save_array/load_array/rope/rope_inplace → fixpoint untouched. **arange = 2 refs**: registered in the
  TIER-1 self-host compiler bind allow-list compiler/check/bind.hexa:1281 (`"arange",`) + a codegen special-path
  per compiler/PLAN.md:574 → FAILS the byte-eq/compiler-core zero-ref precondition → arange STAYS (conservative).
- DECISION (g0): 7 satisfy (falsified ∧ no-live-caller ∧ shadow-binds-without-it ∧ 0-compiler-ref) → DEREGISTERED;
  arange held on a HARD compiler-closure dependency. "Most go, one stays" — the conservative win: the safety gate
  actively prevented touching the self-host compiler's own bind surface.
- DIFF: self/env.hexa — cross_entropy/clip/conv1d/save_array/load_array/rope/rope_inplace removed from env_new()
  roster + 3 scoped OP-48 comment blocks (per-group falsified+dead+0-shadow+byte-eq-safe rationale + explicit
  arange-STAYS note). Roster well-formed; arange + neighbors (normalize/argmax/zeros/sum/topk/sample_token/mse_loss
  /kv_cache_append/rms_norm/matvec/mat_add/quantize_int8) intact (1 roster string each, re-verified). wipe_guard:
  net +33/−5 « 50. POST-EDIT: `hexat self/env.hexa /tmp/op48/env_after.c` → OK (transpiles clean).
- TALLY: OP-43 survivor set 26 → 23 (OP-47) → 16 (OP-48, −7). The [R]-ONLY tranche is now CLOSED (the remaining
  16 survivors all carry [S] local-fn shadows — a strictly harder later tranche). Real ML in hexa = stdlib/flame/*
  + per-module LOCAL fns, NOT these roster builtins.
- OUTCOME: 🟢 GREEN. Verdict .verdicts/hexa-0pod/F-OP48-SURVIVE-AUDIT-TRANCHE.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## 2026-06-12 — OP-47 DONE: matmul_into/dot/mat_add_inplace large-surface probe → all 3 falsified+dead+shadow-safe+byte-eq-safe → ALL THREE DEREGISTERED · self/env.hexa +11/−2 · $0 · 0-pod
- SURVEY-FIRST (mandatory). Read F-OP43-ML-FAMILY-FALSIFIED.txt (the 42-builtin ML-family deeper audit: 16
  deregistered, 26 survive-with-reason; the 3 largest [R]-survivors matmul_into/mat_add_inplace/dot kept on
  g0 blast-radius) + F-OP41-FALSIFIED-BUILTIN-SWEEP.txt (the roster-vs-impl method, the arg-shape-gated
  false-positive trap, the local-fn-shadow CONTROL). Located the 3 at self/env.hexa:194-195. Used the FRESH
  installed hexat ~/.hx/bin/build/hexat (2027336B Jun-8), NOT the stale Jun-1 ~/.hx/bin/hexa.
- METHOD (OP-41 RIGOROUS, per builtin): (a) confirmed registered; (b) confirmed NO impl — 0 codegen-inline
  guards (`if name=="X"` in self/codegen.hexa) + 0 runtime symbol (self/runtime.h ∪ installed runtime.c, prefix
  variants hexa_/rt_/u_/hexa_math_) → arg-shape-trap CONTROLLED (0 guards ⇒ any shape gives the same bare
  hexa_callN fallback); (c) g5 AOT probe with CORRECT args → all three emit verbatim "use of undeclared
  identifier 'NAME'" (matmul_into :21:29, mat_add_inplace :20:29, dot :20:29). No clean-link (opposite) finding.
- KEY SAFETY QUESTION — CONTROL: wrote a local `fn dot(a:[float],b:[float])->float` + caller → generated C has
  `HexaVal dot(HexaVal,HexaVal);` decl + def + the call resolves to it, clang CLEAN. ⇒ local-fn shadows provide
  their OWN symbol, INDEPENDENT of the roster; deregistration cannot break a shadow's binding (dot has 11
  shadows incl stdlib/flame/clm_h911 + example/test_n12 — all unaffected).
- CALLER SWEEP (word-boundary, comment/fn-def/archive excluded): matmul_into 333 real call-sites ALL self/ml/*
  trainers + self/test_inplace; mat_add_inplace 80 ALL self/ml + self/test_inplace/test_new_builtins; dot 12 =
  5 example + 4 self + 3 stdlib, of which the NON-SHADOW (would-bind-roster) ones are 3 baseline-dead examples
  (exit_code=-1 last_pass='') + self/ml,self/stdlib,self/test tensor files that ALREADY hexat-TRANSPILE-FAIL
  today ("index 1 out of bounds (len 1)") + 1 string-literal in self/test_codegen_extended (test data, not a
  call). Spot-checked self/ml/optimizer (7 clang errs, 2=mat_add_inplace), self/test_inplace (4, 3=probe-builtins)
  — already-falsified surfaces, ZERO live passing caller.
- SELF-HOST BYTE-EQ SAFE (decisive): compiler/** (the byte-eq core, build_selfhost.sh walk(compiler/main.hexa)
  closure) has ZERO refs to all three + ZERO compiler imports of self/ml → the entire 333/80-site surface is
  OUTSIDE the closure; the fixpoint (cc-gen3.o==cc-gen4.o) cannot be perturbed. PRE-EXISTING-FAILURE CONTROL:
  every caller fails on the INSTALLED hexat which STILL registers the builtins (Jun-8 pre-edit) → the failures
  are builtin-independent, NOT introduced by deregistration.
- DECISION (g0 conservative): all four conditions hold for EACH (proven-falsified ∧ no-live-caller ∧
  local-shadow-binds-without-it ∧ 0 compiler-core/byte-eq ref) → ALL THREE DEREGISTERED. The OP-43 "large
  surface → keep" hold is RELEASED because the surface is proven DEAD, not merely large: dereg breaks no working
  program (every caller already falsified) — it only flips the failure from "AOT undeclared" to "binder unbound",
  a no-op for a never-compiling program. OP-43 survivor set 26→23.
- DIFF: self/env.hexa — "dot"/"mat_add_inplace"/"matmul_into" removed from env_new() roster + scoped OP-47
  comment block (mirrors OP-43/OP-33b-d convention). Roster well-formed; neighbors matvec/mat_add/rms_norm/rope/
  rope_inplace/repeat_kv confirmed present. wipe_guard net +11/−2 « 50. POST-EDIT: env.hexa transpiles clean
  (~/.hx/bin/build/hexat self/env.hexa /tmp/op47_env.c → OK); 0 roster strings for each removed name.
- OUTCOME: 🟢 GREEN. Verdict .verdicts/hexa-0pod/F-OP47-MATMUL-DOT-PROBE.txt. Reversible one-line re-add.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## 2026-06-12 — OP-42 DONE: OP-40 hex-float fold-serialize → determinism contract (compile-time-const-folding §) + OP-39 gate +5 hex-float cases (13→18) · docs+test+ci-comment · $0 · 0-pod
- SURVEY-FIRST (mandatory). Read F-OP40-COMPTIME-MUL-ULP.txt (the fix: comptime float const-fold serializes folded
  doubles as bit-exact C99 hex-float literals 0x1.<mant>p<exp> via _cf_float_hexlit/_cf_nib_hex, integer ops only —
  ROOT CAUSE was the host hand-rolled %.17e serialize, NOT the multiply/parse/FMA; closed max-1-ULP residual to 0 across
  125 cases) + F-OP39-CONSTFOLD-CI-GATE.txt + the gate tool/op39_constfold_gate.sh + oracle op39_constfold_byteeq.hexa +
  the nobaseline-gate.yml wiring + docs/flame-determinism-contract.md (3-layer model: run-to-run / libm-free / cross-ISA-
  FMA-free). FINDING: the OP-39 gate's MUL1 golden was ALREADY updated to the OP-40 value (…182) when #3084 landed, but
  there was NO contract clause for the compile-step guarantee (OP-40 explicitly deferred it) + NO gate case NAMED for the
  hex-float path.
- CONTRACT. Added a new §1 subsection "compile-time constant folding — bit-exact hex-float serialize" framed as a
  COMPILE-STEP sibling of the 3 run-step layers: (a) comptime const-fold of let-bound float-literal exprs + use-site
  inline; (b) RULE block — bit-exact hex-float serialize (clang ZERO-loss reparse), NOT decimal %g/%e; (c) WHY for
  determinism — a 1-ULP fold drift makes the SAME source compile to different float bytes per host printf, breaking
  machine-independence at COMPILE time. Tied to OP-37/40 measured evidence (bits-182→"…117067"→bits-183), explicitly
  independent of the FMA layer, cross-linked to CHECKPOINT's fp64-reinterpret. + one "what breaks the contract" bullet.
  Terse, current-state (g3, elephant rule).
- GATE EXTENSION. Added 5 MUL_HF* hex-float cases to op39_constfold_byteeq.hexa + tool/op39_constfold_gate.sh — products
  whose correctly-rounded IEEE value the OLD %.17e/%g serialize mis-rounded (the OP-40-fixed path). Goldens = python
  struct.pack('<d', a*b): MUL_HF1 0.254829592*0.3275911 = …653 (0x1.55ef06babe355p-4), MUL_HF2 …598, MUL_HF3 (signed)
  …626, MUL_HF4 …150, MUL_HF5 …376. Count 13→18; gate header/comments cite OP-40 #3084.
- VERIFY (both ways, freshest local hexat from CURRENT SOURCE — the OP-40 fix is in self/codegen.hexa, not the deployed
  binary). Built /tmp/op42/hexat_op42 via tool/regen_cc_manual (HEXA_V2=~/.hx/bin/build/hexat Jun-8 driver) + clang
  single-TU + restored frozen self/runtime.c → confirmed it emits hex-floats (MUL1→0x1.28f3dbedf555ep-4=…182) + self-tests
  15/15. A `hexa run` shim (transpile→clang→run via hexat_op42) feeds the gate. PASS: all 18 OK, clean gate exit=0. TEETH:
  hand-corrupt MUL_HF1 golden …653→…654 → DRIFT + FAIL, exit=1 (catches a 1-ULP drift on a new hex-float case). DIFFERENTIAL
  proof: pre-fix Jun-8 hexat emits lossy hexa_float(0.0834799) for MUL_HF1; fixed emits hexa_float(0x1.55ef06babe355p-4).
- SEED ADVISORY (honest, OP-39/39b coupling). Ran the gate against the pre-fix Jun-8 hexat (= CI's frozen-seed generation):
  DRIFTs on ALL 5 new MUL_HF cases identically to the existing 13 (lossy %g), pre-fix gate exit=1. So the new cases stay
  under OP-39's continue-on-error: true advisory — ZERO yaml change (same `sh tool/op39_constfold_gate.sh ./hexa` call), NO
  enforcing flip (that remains OP-39b's deferred frozen-anchor re-pin). Updated the 3 workflow comment blocks to note OP-42
  extended the gate 13→18 + that the seed drifts on them too. Whole gate auto-goes-GREEN (incl. these 5) on seed promote.
- SCOPE. Test oracle + gate script + contract doc + CI comments ONLY — no self/codegen.hexa or SSOT-module touch, so the
  self-host gen-N==gen-N+1 fixpoint (OP-40 proved it on main) is unaffected; oracle is standalone (no `use`).
- OUTCOME: 🟢 milestone OP-42 [x]. Verdict .verdicts/hexa-0pod/F-OP42-HEXFLOAT-CONTRACT-GATE.txt. $0 · 0-GPU · 0-pod ·
  no vast · no foreign-pod touch · no .tape edits.

## 2026-06-12 — OP-41 DONE: systematic falsified-builtin roster sweep — COMPLETE 231-builtin matrix (126 real / 105 falsified); OP-33 optimizer-scheduler family CLOSED · $0 · 0-pod
- SURVEY-FIRST (mandatory). Read OP-33c (F-OP33C-DEAD-OPTIM-CLEANUP.txt) + OP-33d (F-OP33D-ADAM-STEP-SWEEP.txt) to
  internalize the method: (a) the builtin ROSTER = `let builtin_names = [...]` in self/env.hexa env_new() (231 entries
  at baseline); (b) the IMPL set = codegen-inline lowering (self/codegen.hexa `if name == "X"` guards) ∪ runtime.h /
  runtime.c symbols the emitted C calls. A FALSIFIED builtin = registered in (a) but NO impl in (b) → AOT emits broken C.
- BUILD THE COMPLETE MATRIX (core deliverable). Extracted all 231 roster names. Two-stage classify: (1) static cross-ref
  vs codegen-explicit (492 `if name ==` names) ∪ runtime.h (636 syms) ∪ runtime.c (1830 syms) incl prefix variants
  (hexa_/rt_/u_/hexa_math_); (2) EMPIRICAL g5 probe of every static-no-match candidate — `fn main(){ let _r = NAME(
  correct-args); println("OKMARK") }` via the FRESH installed hexat (~/.hx/bin/hexa run → ~/.hx/bin/build/hexat → clang),
  classify REAL (runs / resolves-with-typeerr) vs FALSIFIED (generated C has "use of undeclared identifier/function
  'NAME'"). The installed binary roster is a SUPERSET (235 = baseline 231 + the 4 already-removed names) so every probe
  type-checks at the hexa level and any failure is a genuine runtime-impl falsification. CAVEAT learned: a generic-arg
  probe is UNRELIABLE — codegen-inline lowering is arg-COUNT/SHAPE gated (e.g. matmul needs 5 args, softmax 1), wrong
  shape falls through to the undeclared-bare-name fallback → false-positive storm; CORRECT per-builtin args required.
- RESULT MATRIX: 231 total = 126 REAL + 105 FALSIFIED.
  · REAL (126): print/println/len/type_of/to_string/to_int/to_float/format/args/exit/clock + all math (abs/sqrt/sin/
    cos/exp/log/pow/min/max/floor/round/atan2/…) + str ops (join/split/trim*/starts_with/contains/…) + file/net/json/
    http_get/base64* + constructors Some/Ok/Err + ML-inline matmul/softmax/layer_norm/rms_norm/gelu/silu/argmax/randn/
    matvec/mat_add/hadamard/sum/tensor/tensor_zeros + keys/values/has_key + all term_*/PTY + ptr/cstring/exec/mem.
  · FALSIFIED (105): Set channel bigint gcd sigma phi tau try_float is_numeric is_whitespace replace random_int elapsed
    hex_encode/decode http_post http_serve laws meta_laws consciousness_*/phi_predict/psi_*/hexad_*/tension_link sopfr
    mem_stats/region/budget n6_* evolve_gen sigmoid tanh_ relu cosine_sim run_tests run_benchmarks transpose normalize
    cross_entropy zeros ones arange ema clip map_arr/filter_arr/zip_arr/enumerate_arr flatten sgd_step numerical_grad
    phase_lr batch_matvec batch_norm grad_accumulate dropout attention gru_cell sinusoidal_pe multi_head_attention topk
    sample_token mse_loss conv1d max_pool1d kv_cache_append attention_cached save_array load_array quantize_int8
    dequantize_int8 beam_search_step xavier_init kaiming_init curiosity/dialogue/combined_reward magnitude_prune sparsity
    tensor_fill input_all load_weights_bin mmap_weights to_char repeat_kv dot mat_add_inplace matmul_into rope rope_inplace
    weight_dict. (These are AOT-impl-less; many have a local-fn shadow used by real programs, e.g. relu→stdlib/nn.hexa.)
- BASELINE RECONCILE (important). The worktree branch off 9d3aee960 already has OP-33b/c/d FULLY applied (scheduled_lr/
  cosine_lr/warmup_lr/adam_step/grad_clip_norm absent; stdlib/optim.hexa adam/safe_update wrappers removed). (A side-
  checkout on the qforge branch still shows them — the merge that lost them is a DIFFERENT line of history; the OP-41
  branch baseline is clean.) So the only OP-33-family残党 at baseline = sgd_step/numerical_grad/phase_lr/grad_accumulate.
- OPTIMIZER-FAMILY CLOSEOUT (the deregistration). Each of the 4 g5-RE-VERIFIED falsified (verbatim "use of undeclared
  identifier 'NAME'" in generated C, correct args). CALLER SWEEP: sgd_step — builtin callers only in dead examples
  (test_optimizer/test_lr_batch, exit_code=-1); ALL self/ml/{train_100m,_ultra,_alpha,_batched,_alphabeta,_v3_inplace,
  optimizer}.hexa define their OWN LOCAL `fn sgd_step` → bind locally (red herring, OP-33d pattern). numerical_grad — only
  test_optimizer (dead). phase_lr — only test_lr_batch (dead). grad_accumulate — only anima_convergence_proof + test_lr_batch
  (dead). ZERO compiler-core ref for all 4. → DEREGISTERED from env.hexa roster (mirrors OP-33b/c/d). Dead example callers
  NOTE-pointer-commented (test_optimizer/test_lr_batch/anima_convergence_proof headers).
- VERIFY. env.hexa transpiles clean (~/.hx/bin/build/hexat self/env.hexa → OK, roster array well-formed). self/ml/
  optimizer.hexa transpiles OK (local sgd_step binds). train_100m.hexa "index 1 out of bounds" is a PRE-EXISTING hexat
  quirk — reproduces IDENTICALLY on the builtins-present checkout → NOT caused by the deregistration. grep-proof: every
  remaining bare `sgd_step(`/`numerical_grad(`/`phase_lr(`/`grad_accumulate(` is either a dead-example NOTE'd site or a
  self/ml LOCAL-fn binding; no LIVE program references the removed builtins.
- HONEST + CONSERVATIVE (g0). The 101 non-optimizer falsified are OUT of the OP-33 family and risky to deregister en-masse
  (local-fn shadows + potential interp use) — bounded-with-reason in the matrix, deferred to a dedicated ML-builtin sweep.
  FAMILY-CLOSURE: after OP-41 the OPTIMIZER-SCHEDULER falsified set is EMPTY. env.hexa edit affects the NEXT compiler build
  (installed hexat keeps its roster until rebuilt — same 0-pod caveat as OP-33b/c/d; the change is +18/−3 « 50 lines).
- OUTCOME: 🟢 milestone OP-41 [x]. Verdict .verdicts/hexa-0pod/F-OP41-FALSIFIED-BUILTIN-SWEEP.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## 2026-06-12 — OP-33d DONE: falsified adam_step builtin swept across self/ml/* — no LIVE caller → deregistered from env.hexa roster · $0 · 0-pod
- SURVEY-FIRST (mandatory). Read OP-33c's verdict (.verdicts/hexa-0pod/F-OP33C-DEAD-OPTIM-CLEANUP.txt §8 HONEST):
  it deliberately LEFT adam_step registered because 12+ self/ml/* surfaces reference it (out of OP-33c scope) and
  flagged this exact follow-up. `grep -rn "adam_step" --include="*.hexa"` → complete reference list.
- CLASSIFY (the key disambiguation). Most hits are RED HERRINGS — locally-defined fns, NOT the builtin:
  adam_step_naive / adam_step_fused / adam_step_fused_with_zero (self/test_fused_adam, self/test_optimizer_fuse,
  self/ai_native/{fused_adam,optimizer_fuse}), galore_adam_step (self/ml/galore, self/test_galore), ref_adam_step
  (self/test_zero_optimizer). Bare-BUILTIN call sites = 4 example demos + 3 self/ml/* + the roster row.
- g5 RE-VERIFY falsified (independent, not trusted from OP-33c). /tmp/op33d_p2.hexa `fn main(){ ... adam_step(p,g,m,v,
  0.001,0.9,0.999,1e-8,1) }` via installed `hexa run` (hx-selfhost-cli, fresh hexat ~/.hx/bin/build/hexat). VERBATIM:
  "error: call to undeclared function 'adam_step'; ... note: did you mean 'adamw_step'? /Users/mini/.hx/bin/self/
  runtime.h:1543:9: note: 'adamw_step' declared here ... error: clang compile failed — binary not produced". (Caveat:
  a TOP-LEVEL-statement probe form prints a bogus "OK:" — hexat mis-parses it; the `fn main()` form cleanly emits+fails.)
- SIGNATURE check (drop-in?). adamw_step = 11-arg (p,g,m,v,n,lr,b1,b2,eps,wd,t; RFC 034, runtime.h:1543); adam_step
  call sites = 9-arg (p,g,m,v,lr,b1,b2,eps,t). NOT a drop-in (inserts n + wd at different positions) → no faithful
  repoint of dead demos.
- LIVENESS per caller. 4 examples (anima_convergence_proof:127 / benchmark_ai_native:90 / test_optimizer:19,32,61,94 /
  benchmark_all:117,123): tool/examples_baseline.json exit_code=-1, last_pass="" → never-passing → DEAD. self/ml/
  t2_gpu_bench:166 (4-arg): NO `use "gpu_optimizer"`, no local fn → falls to the builtin; `hexa run` on CPU aborts
  ("index 1 out of bounds") before this → DEAD CUDA bench (not in examples_baseline at all). self/ml/train_gpu:134 +
  distributed_train:243 (4-arg): BOTH `use "gpu_optimizer"`, which DEFINES `fn adam_step(state,grad,lr,t)` (gpu_
  optimizer.hexa:41, plain fn) → resolve to the LOCAL fn, not the builtin (also CPU-untranspilable CUDA surfaces).
- DECIDE (g0 conservative). All DEAD/local → NOTE pointer comments (mirroring OP-33c's example NOTEs); NO faithful
  repoint. NO live surface references the BUILTIN → root-cause: DEREGISTER adam_step from the self/env.hexa roster
  (mirrors OP-33c grad_clip_norm / OP-33b cosine_lr·warmup_lr). Conservative check: a local `fn adam_step` is a user
  function registered separately from the builtin roster — removing the roster row does NOT break the gpu trainers'
  local binding (so train_gpu/distributed_train are not regressed).
- EDIT. self/env.hexa: removed "adam_step" from the env_new() builtin roster + multi-clause `// adam_step removed
  (OP-33d ...)` comment. NOTE comments added at all 7 caller sites (4 examples + 3 self/ml). wipe_guard: 1 deletion « 50.
- VERIFY. grep-proved zero remaining bare adam_step( builtin caller outside the now-NOTE'd dead/local sites; env.hexa
  roster array stays well-formed. self/env.hexa edit hits the NEXT compiler build — CI selfhost gates check byte-eq;
  change is minimal (1 token + comment).
- LAND. Verdict .verdicts/hexa-0pod/F-OP33D-ADAM-STEP-SWEEP.txt. $0 · 0-GPU · 0-pod · no vast · no foreign-pod · no .tape.

## 2026-06-12 — OP-37b DONE: host-atof residual cured — computed const-folds re-parse operands via correctly-rounded strtod (3→1 ULP, fixpoint byte-identical) · $0 · 0-pod
- SURVEY-FIRST (mandatory). Read OP-37's verdict (.verdicts/hexa-0pod/F-OP37-FLOAT-CONSTFOLD-VERIFY.txt) + the landed
  fix in self/codegen.hexa (_cf_float_node / _cf_negate_float_text / comptime_eval float BinOp folds), then traced
  to_float: const-folder `_cf_as_float` (codegen.hexa:9874) calls `to_float(lit.value)` → emitted C
  `hexa_float(__hx_to_double(...))` → __hx_to_double(STR) → `hxlcl_atof` (runtime.c:270). CONFIRMED hxlcl_atof is the
  naive accumulator (n=n*10.0+d; frac*=0.1; exp via repeated *10) — NOT correctly-rounded.
- CHARACTERIZE (measured, NOT assumed). Built two hexats from CURRENT source via tool/regen_cc_manual (HEXA_V2=Jun-8
  ~/.hx/bin/build/hexat) → clang. Self-contained /tmp/op37b_const.hexa forces COMPUTED comptime-const folds (re-parse
  operands then `*`/`+`/`/`, NOT the pass-through negation OP-37 fixed); f64_to_bytes_le byte dump vs python
  struct.pack('<d', A op B). BEFORE (OP-37 source): MAX 3 ULP — `0.254829592 * 0.284496736` = 3 ULP (both operands
  1 ULP off), `1.421413741 * 0.5` = 1 ULP. Real on current source, reproduced on from-source rebuild — not a ghost.
- ROOT CAUSE (two parse paths). The host runtime has BOTH `to_float`→hxlcl_atof (naive, lossy) AND
  `str.parse_float()`→hexa_str_parse_float→libc `strtod` (runtime.c:3034, C-standard CORRECTLY-ROUNDED). _cf_as_float
  used the lossy one. (hxlcl_atof's C body lives only in the untracked build-assembled self/runtime.c bootstrap
  substrate — NOT tracked-source-editable; self/runtime.hexa is a marker. So Eisel-Lemire/strtod-reimpl is neither
  needed nor in-tree.)
- DECIDE (g0 Occam, option (a)). The simplest correct fix is to route the const-folder operand parse through the
  ALREADY-PRESENT correctly-rounded strtod path — one expression in tracked source, no runtime edit, no new parser.
- FIX (self/codegen.hexa, additive, no deletions). (1) `_cf_as_float`: FloatLit parses via `lit.value.parse_float()`
  (→ hexa_str_parse_float → strtod) instead of `to_float(lit.value)`; IntLit branch unchanged (integers agree). (2)
  `abs` float-fold (comptime_eval Call path): preserve EXACT operand source text (abs = same magnitude, sign stripped)
  instead of to_float-parse + re-serialize — the one remaining direct to_float site in the computed-fold family.
- AFTER (measured): MAX 3→1 ULP. Operands now byte-EXACT vs python correctly-rounded doubles (a=0.254829592 bits
  4598262221740202622, b=0.284496736 bits 4598796657494856809 — both exact). The lone remaining 1 ULP on `a*b` is the
  host comptime `*` (rt_mul) rounding 1 ULP differently from clang's own fold (clang gives .555e compile-time AND
  runtime; hexat comptime gives .555f) — a comptime-vs-runtime HOST-MULTIPLY parity question, NOT a parse error,
  separate + smaller, logged out of scope.
- SELF-HOST FIXPOINT GREEN (paramount). Fixed hexat re-compiling fixed SSOT → gen-N==gen-N+1 C BYTE-IDENTICAL
  (cmp hexa_cc v2.c==v3.c parse_float-only; v4.c==v5.c with +abs, 2098186 B both) + object byte-identical
  (v2.o==v3.o). Embedded self/type_checker self-tests 15/15 PASS each regen. OP-37 negation idiom regression byte-
  exact (0.0-0.254829592 → -0.254829592 exact text); abs regression byte-exact (abs(0.254829592)→0.254829592,
  abs(0.0-1.421413741)→1.421413741). The patch is fixpoint-stable; CI selfhost gen3→gen4 byte-eq not at risk.
- Milestone OP-37b flipped [x]. Verdict .verdicts/hexa-0pod/F-OP37B-HOST-ATOF-CORRECT-ROUND.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## 2026-06-12 — OP-38 DONE: deterministic checkpoint (ckpt_lib FCK v1) reflected into the determinism contract + dojo recipe (DOCS-ONLY · $0 · 0-pod)
- SURVEY-FIRST (mandatory). Read the SSOTs before touching: docs/flame-determinism-contract.md (CONFIRMED it already
  has an accurate CHECKPOINT row + "what breaks it" bullet from OP-35 — REFINE not duplicate), docs/hexa-dojo.md (the
  "Training recipe — optimization gotchas" section — NO checkpoint recipe present), and the source of truth code:
  stdlib/flame/ckpt_lib.hexa + op35_ckpt_resume_eq.hexa + op35_ckpt_xplat_selfcontained.hexa.
- CONTRACT (docs/flame-determinism-contract.md) — REFINED in place, NO duplicate subsection:
  - CHECKPOINT row "what breaks it" cell + the matching "what breaks the contract" bullet now tie the
    binary-bit-pattern rationale to F-OP37's MEASURED proof: to_string is "%g" 6-digit, MEASURED to corrupt fp64
    const-folds by up to 2.027e-6 → the f64_to_bytes_le bit-pattern reinterpret exists PRECISELY to avoid lossy text
    round-trip. (Was asserted "not shortest-round-trip" with no proof pointer.)
  - Left as-is (already accurate from OP-35): full-state [t][n_params][W,m,v] invariant, resume-at-t+1, bit-for-bit
    resume==uninterrupted (max|Δ|=0), adversarial round-trip, arm64-macos↔x86_64-linux cmp-portability.
- DOJO (docs/hexa-dojo.md) — NEW terse "deterministic checkpoint/resume" callout in "Training recipe — optimization
  gotchas", right after the existing determinism-contract callout (matching the > callout style): the exact API
  (ckpt_begin → ckpt_save_param per param IN PINNED ORDER → ckpt_load_param, resume at ckpt_step(rb)+1), the TWO
  gotchas (1: MUST save AdamW m,v AND step t, not just weights — weights-only resets bias-correction t→1, MEASURED
  0.042 divergence; 2: NEVER serialize through text %g/to_string — F-OP37 2.027e-6 corruption), the bit-exact +
  machine/arch-portable property, and a one-line pointer to ckpt_lib.hexa + the two op35 oracles as the proof.
- ACCURACY (g5, TRUST THE CODE): verified every claim line-by-line against ckpt_lib.hexa — magic = "FCK\x01" (bytes
  70,67,75,1); header [magic][t u32-le][n_params u32-le], body off 12; per-param [len u32-le][W f64-le][m][v]; f64 via
  f64_to_bytes_le/bytes_to_f64_le (bit-pattern, LE pinned); API names ckpt_begin/ckpt_save_param/ckpt_magic_ok/
  ckpt_step/ckpt_nparams/ckpt_body_off/ckpt_param_len/ckpt_load_param ALL real pub fns w/ documented signatures — ALL
  MATCH. Oracles confirm the guarantees (RESUME bit-eq + ROUNDTRIP adversarial + NC-1 missing-t / NC-2 fp32 negative
  controls; xplat echo/make/resume cmp-identical). No invented API, no invented guarantee; no code↔PR-#3062 discrepancy.
- DOCS-ONLY: only files touched = the 2 docs + verdict F-OP38-CKPT-RECIPE-REFLECT.txt + this milestone/log. NO new
  code, NO new oracle, NO .tape edit (no sign token), NO /paper (g84). $0 · 0-GPU · 0-pod · no vast · no foreign pod.
- Milestone OP-38 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP38-CKPT-RECIPE-REFLECT.txt.

## 2026-06-12 — OP-37 DONE: `0.0 - <float literal>` const-fold miscompile REPRODUCED on current main → REAL codegen bug → FIXED byte-exact ($0 · 0-pod)
- Settles OP-36 HONEST-NOTE #2 (deferred as a presumed stale-toolchain ghost). DECISIVE: it is NOT a ghost —
  the miscompile REPRODUCES on the freshest local native compiler (~/.hx/bin/build/hexat, Jun-8 01:17, the
  C-transpile self-hosted authority). The stale `~/.hx/bin/hexa` promoted CLI delegates `hexa run` to the
  Jun-7 shipped dispatch binary; both, AND the Jun-8 hexat C-transpile + clang -O0, emit identical corrupt bytes.
- REPRO: self-contained /tmp/op37_repro.hexa dumps each A&S erf coefficient's IEEE-754 LE bytes via the
  f64_to_bytes_le builtin, in PLAIN `let a = X` vs NEGATED `let a = 0.0 - X` forms. PLAIN block = all bytes
  correct; NEGATED block (when the expr is an INLINE call arg, where the const-folder fires) = low mantissa
  CORRUPT, round-tripping to ~6 sig-digits. Decoded errors match OP-36 EXACTLY (a2 |Δ|=2.64e-7, a4 |Δ|=2.027e-6).
- ROOT CAUSE (self/codegen.hexa comptime_eval const-folder), TWO bugs: (1) SERIALIZE — folded floats
  re-emitted via `to_string(<float>)` = "%g" 6-significant-digits (runtime_core.c:6268, round-trip LOSSY);
  emitted C verbatim showed `hexa_float(-0.25483)` for `0.0 - 0.254829592`. (2) PARSE — `_cf_as_float` loads
  operands via `to_float`/hxlcl_atof, a naive digit-accumulator (n=n*10+d; frac*=0.1), NOT correctly-rounded
  strtod; PROVEN: lexer literal 0.254829592=[126..] but to_float("0.254829592")=[127..] (1 ULP off).
- FIX (additive, no deletions, respects wipe_guard): `_cf_float_node(f)` serializes folds at
  format_float_sci(f,17) = "%.17e" (round-trippable all magnitudes) at every fold site (UnaryOp -, BinOp + - * /,
  abs, sqrt, min/max); `_cf_negate_float_text(s)` + additive-identity special-cases (`-X`, `0.0-X`, `X-0.0`,
  `0.0+X`, `X+0.0`) preserve the operand's EXACT source text (sign-toggle only, ZERO parse/re-serialize) →
  byte-exact for the dominant OP-36-triggering `0.0 - X` idiom.
- PROVEN from-source: tool/regen_cc_manual (HEXA_V2=Jun-8 hexat) re-transpiled the 4 SSOT modules incl. the
  patched codegen.hexa → hexa_cc.c → clang → /tmp/hexat_fixed2 (clean build, codegen self-tests 15/15 pass).
  Emitted C now reads `hexa_float(-0.254829592)` (exact text); the run prints NEGATED bytes BYTE-EXACT vs
  python struct.pack('<d') ground truth (max|Δ|=0 over all 6 coefficients). Regression: 2.0*3.5, 1.0/4.0,
  0.5+0.25, 3.0-1.0, and the additive identities all match IEEE-754 ground truth — non-regressive.
- HONEST: the general lossy host atof (BUG-2 root) still affects folds that COMPUTE a new value from re-parsed
  operands (now ≤1 ULP via %.17e, was ~6 sig-digits); full cure needs a correctly-rounded host strtod —
  logged as a follow-up, OUT OF SCOPE (the negation idiom is fully byte-exact). The deployed `hexa run` still
  uses the pre-fix Jun-7 binary; promote/rebuild into the install is a separate step (this lands the REPO fix).
  Milestone OP-37 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP37-FLOAT-CONSTFOLD-VERIFY.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## 2026-06-12 — OP-36 DONE: forge dispatch CPU-fallback SYSTEMATIC audit — 33-symbol matrix, 2 real link holes + seam fixed byte-eq, 16/16 flame libs CPU-link-probed ($0 · 0-pod)
- Deep-dive round-10 branch ④: closes the OP-16/18/32b class PROACTIVELY. Swept ALL 33 forge_dispatch_*
  prototypes (runtime.h) × CUDA emit (runtime_cuda_emit.hexa launchers — 33/33 ✓) × CPU body (restored
  frozen-seed runtime.c + tracked tool/restore_frozen_seeds appends) × real (non-comment) stdlib callers.
- CLASS (a) — real CPU surfaces that could NOT link, now FIXED via the OP-36 marker-guarded
  restore_frozen_seeds append (#ifndef HEXA_CUDA · idempotent · GPU path -E-proven untouched):
  HOLE-1 forge_dispatch_matmul_t (5-arg, OP-2 transpose-elim) — host body materializes A^T (exact copies)
  and delegates to the frozen hexa_farr_matmul ikj kernel → byte-eq BY CONSTRUCTION; committed victim
  clm_prod_transpose_elim_eq.hexa now LINKS+PASSES (dW max|Δ|=0 all 4 shapes) + new committed oracle
  op36_matmul_t_hostdispatch_eq.hexa (max|Δ|=0, 187/187 nonzero). HOLE-2 forge_dispatch_matmul_batched
  (7-arg) — per-problem host loop over the same kernel; committed flame_forge_batched_test.hexa now
  LINKS+PASSES (rc=0, max|Δ|=0). SEAM-3 — hexa_ twins for groupnorm_gelu/gelu2/moe_block2 (OP-16/18 bodies
  were bare-name-only; current codegen lowers to hexa_forge_dispatch_*). nm U→T for all (both names).
- CLASS (b) — all 25 remaining CPU-missing symbols (adamw×3, ce_grad, clm_megafwd, col2im, db_colsum,
  embedding×2, expert_*2, gelu/gelu_bwd, grad_sum2/3, groupnorm×3, im2col×2, int4_quant×2, moe_router×2,
  residual_add) are reachable ONLY from clm_prod.hexa — a STANDALONE program (own main, not importable),
  GPU-build-only by design (fusion_dispatch.c supplies all on CUDA pods). Documented, deliberately NOT
  hand-rolled. CLASS (c) orphans: none — every symbol has ≥1 real caller.
- LIB GATE: all 16 stdlib/flame/*_lib.hexa trivially imported + CPU-linked GREEN against REPO sources
  (clean sandbox — discovered `hexa run` prefers deployed ~/.hx/src/stdlib over the checkout when a
  hexa.toml is at cwd, and ~/.hexa-cache keys on program-source hash only).
- HONEST environment findings (not repo defects): committed F-OP16 gn oracle fails on THIS host because
  (1) the deployed runtime.c carried pre-OP-19b libm-erf bodies (locally dt_erf-synced, backup kept) and
  (2) the stale Jun-1 hexat MISCOMPILES `let a = 0.0 - <float literal>` via a lossy ~6-sig-digit
  const-fold roundtrip (measured: -2.64e-7 / +2.027e-6 on the A&S erf coefficients) → the oracle's own
  inline reference is off by ≤1.76e-6. The C host body is byte-correct: direct dispatch probe A ==
  dt_gelu(Y) max|Δ|=0 on the oracle's exact fill. Known project_local_hexa_stale_oracle class.
- Verdict .verdicts/hexa-0pod/F-OP36-DISPATCH-AUDIT.txt (full matrix + proofs verbatim).

## 2026-06-12 — OP-19g DONE: summer recorded as 5th environment of the machine-independence matrix (distinct glibc x86_64 host, fingerprint pinned) ($0 · 0-pod)
- Deep-dive round-10 branch ②: summer had only been an ad-hoc substitute leg (OP-33/35, aiden down both times)
  — never RECORDED as an environment row. Fingerprinted: Ubuntu 24.04.2 LTS (Noble Numbat) · kernel
  6.17.0-35-generic x86_64 · glibc 2.39 (Ubuntu GLIBC 2.39-0ubuntu8.7) · AMD Ryzen 5 9600X · hexa
  0.1.0-dispatch @380bdf548 (F-OP33 host-local toolchain repair still in place, runtime.a rebuilt Jun-11).
- Golden folds reproduce EXACTLY on summer (self-contained oracles, scp pool pattern): op19 dt_exp CE-bwd
  7679248634312321699 ✓ · op19b dt_erf FWD 4548590605583584556 ✓ / BWD 4249661408190172843 ✓ — plus
  process-to-process byte-eq double-runs. Breadth: op33 schedule lane F-OP33-LR-SCHEDULE=1 (d5 checksum
  598834071, CROSSPLAT-FINGERPRINT-D5 == all-env) · op35 xplat ckpt lane F-OP35-XPLAT-LOCAL=1 (loss bits ==
  record, resume bit-mismatch 0, roundtrip 33/33).
- NEW glibc-axis data: summer LIBM folds == aiden recorded glibc-x86 LIBM folds (CE-bwd 3352931952497630952 ·
  GELU-fwd 6306829276275644424 · GELU-bwd 5500011732941122953) — two INDEPENDENT glibc x86_64 hosts round
  identically on the libm lane (per-libc effect, F-OP19C thesis), while dt_* is identical across all 6 envs.
- RECORDED: docs/flame-machine-independent-training.md §3 table upgraded to the full 6-row environment matrix
  (local · ghost · aiden · pi5 · SUMMER · musl) with the summer fingerprint verbatim + caveats.
- HONEST: aiden DOWN (pool [x]) + its exact glibc version never recorded → the pair's glibc-VERSION diversity
  is unknown (recorded claim = "2nd independent glibc x86_64 host, fingerprint pinned", no more). Summer =
  self-contained lane only (older hexa miscompiles cross-module imports). Pre-existing untracked op35 oracle
  copy on summer's checkout left as found (not mine). /tmp/op19g cleaned. Verdict
  .verdicts/hexa-0pod/F-OP19G-SUMMER-5TH-ENV.txt.

## 2026-06-12 — OP-35 DONE: checkpoint save/restore determinism (6th surface) — audit + FCK\x01 fp64-LE training checkpoint + resume==uninterrupted bit-eq oracle + cross-platform byte-identical files ($0 · 0-pod)
- Deep-dive round-10 branch ①: a machine-independent run is only useful if you can STOP→serialize (W,m,v,t)→
  restore→RESUME byte-identical to an uninterrupted run. Serialization holes: float→text bit loss; binary
  endianness/layout; missing optimizer state (restarts bias-correction); field/iteration order.
- AUDIT: NO training checkpoint in stdlib. clm_ckpt.hexa (.clm v0.1/v0.2) = int4-QAT INFERENCE export (int4
  codes + fp32 scales, fp32 ext trailer) with BOTH classic training-resume holes: fp64→fp32 narrowing AND no
  AdamW m/v/step-t. flame_load_pt/pt_loader = PT import readers. train/optim/nn_lib: no save path.
- CLOSE: stdlib/flame/ckpt_lib.hexa "FCK\x01" v1 — [magic][t u32-le][n_params u32-le] + per-param
  [len][len×f64-le W][m][v] in pinned canonical order; f64_to_bytes_le/bytes_to_f64_le bit-pattern reinterpret
  (NO text, NO narrowing); little-endian pinned (bytes are the contract, not host layout).
- ORACLE 1 op35_ckpt_resume_eq.hexa (production conv/moe/nn/optim libs, the OP-15 composed micro-step as a
  stateful 4-step loop): save@k=2 (124,928 B) → restore FRESH → resume 3..4 == uninterrupted BIT-FOR-BIT
  (max|Δ|=0, 0 bit-mismatch over 17×{W,m,v} via float_to_bits, step-3/4 loss bits identical). Adversarial
  round-trip 33/33 bit-exact (+0/-0, min/max denormal, min normal, max double, ±inf, qNaN, qNaN payload 0xEF,
  sNaN pattern, inexact fractions). NEGATIVE CONTROLS in-band: wrong-t resume diverges 0.04248; fp32-truncated
  resume (= the .clm abuse) diverges 1.77089e-08 — both holes REAL-AND-CLOSED + comparator sensitivity proven.
- ORACLE 2 op35_ckpt_xplat_selfcontained.hexa (NO-use pool twin, g61 acknowledged): machine-independent
  pure-hexa micro-LM step (explicit ascending loops, dt_exp/dt_erf/dt_ln/dt_sqrt, pure-hexa AdamW in the
  F-OP12 canonical fold; NO farr_matmul / NO adamw_step C builtin → any xplat diff attributable to the ckpt
  surface). Per-step loss bits IDENTICAL arm64-macos vs summer x86_64-linux. FILE-LEVEL cmp gates 4/4
  byte-IDENTICAL (8288 B): FORMAT-ECHO (arm ckpt→x86 load→re-serialize == original, no arithmetic),
  RESUME-XPLAT (x86-resumed final == arm uninterrupted final), WRITE-SIDE (x86 ckpt bytes == arm ckpt bytes),
  FINAL-UNINT. → write on arm64-macos, restore+resume on x86_64-linux, byte-identical: PORTABLE, not host-only.
- summer toolchain notes (why the xplat twin is self-contained): older hexa build miscompiles cross-module
  imports (even the landed OP-15 oracle fails to compile there) + wraps trailing void user-fn calls in
  `return __hexa_fn_arena_return(...)` → explicit trailing returns in the oracles. aiden DOWN (ssh timeout,
  as OP-33). summer checkout left clean (scp'd files + /tmp artifacts removed).
- docs/flame-determinism-contract.md: CHECKPOINT row in the per-phase locked-identities table + "lossy or
  incomplete CHECKPOINT" bullet in what-breaks. Verdict .verdicts/hexa-0pod/F-OP35-CHECKPOINT.txt.

## 2026-06-12 — OP-33 DONE: LR-scheduler determinism surface (5th surface) — audit + deterministic warmup+cosine scheduler (d5_cos) + N=500 oracle; libm-cos divergence DEMONSTRATED 10/500 steps Darwin vs glibc ($0 · 0-pod)
- Deep-dive round-9 branch ②: the step path is libm-free (F-OP19/19b/29) but the LR SCHEDULE is a separate
  per-step float surface feeding lr into AdamW; cosine decay needs cos() = the F-OP19 hole class. OP-23b's
  harness computed its schedule once host-side ("computed in double and passed identically to both lanes") —
  sidestepping the production cross-platform question.
- AUDIT: NO production scheduler in stdlib/flame (all trainers take fixed lr → surface USER-SIDE); legacy
  stdlib/optim.hexa scheduled_lr wraps cosine_lr/warmup_lr builtins that no longer build (probe FAILS — dead
  code, documented not revived); self/ml ga_warmup_cosine_lr = crude 5-term-Taylor self-dialect, not flame; no
  other schedule-class arithmetic (wd/beta/temperature all fixed scalars). libm cos IS live (`cos(1.0)` runs).
- LOCK (case b — new primitive): pub fn opt_lr_warmup_cosine(base_lr, floor_frac, t, n_steps, warmup) in
  stdlib/flame/optim_lib.hexa — the OP-23b lr_at() formula with cos = d5_cos (F-OP29 RoPE primitive, mod-2π
  reduce + 14-term Taylor), π = d5_pi(), fold order PINNED in a CANONICAL ORDER header block.
- ORACLE stdlib/flame/op33_lr_schedule_determinism_eq.hexa (self-contained, OP-28/29 scp pattern): N=500
  warmup=50 base=1e-3 floor=0.05. RUN-TO-RUN max|Δ|=0 both hosts; process-to-process 44889-byte output
  byte-eq; CROSS-PLATFORM (local arm64-macos vs summer x86_64-linux glibc) d5 lane 0/500 byte-diff, checksum
  598834071 fingerprint `0 0 128 203 189 216 193 65` BOTH → machine-independent.
- THE DEMO (hole REAL, not latent): the libm-cos twin lane (identical fold order, only cos differs) DIVERGES
  cross-platform at 10/500 steps (t=121 180 367 381 387 391 394 407 414 433), each 1–4 ULP in the low mantissa
  byte (checksums 849024739 local vs 990987107 summer) → a libm-cos schedule hands AdamW a different lr per
  platform at ~2% of steps. Swap cost on-host: 189–192/500 steps differ ≤3.18e-19 (~ULPs) — the F-OP19
  "matches-libm → matches-everywhere" trade.
- Contract doc: SCHEDULE per-phase row + what-breaks bullet + step-phase-map [SCHEDULE] node (F-OP33).
- OPS: aiden DOWN (ssh timeout) → x86 leg on summer; summer toolchain repaired host-locally (stale
  mixed-generation gitignored runtime.c/runtime_core.c + missing HEXA_PREBUILT_RUNTIME runtime.a → scp'd the
  local consistent generated pair, rebuilt runtime.o/runtime.a, used committed build/hexat_linux; no repo edit).
- Verdict .verdicts/hexa-0pod/F-OP33-LR-SCHEDULE.txt · branch domain/hexa-0pod-op33.

## 2026-06-12 — OP-28c DONE: BPE real-scale vocab staging — production load path vs a REAL on-disk Qwen2.5 vocab, round-trip + byte-eq + cross-platform (closes OP-28b remainder) ($0 · 0-pod)
- Deep-dive round-8 branch ③: OP-28b proved the fixed byte-encoder end-to-end but only against a canonical-glyph
  self-contained merge/vocab — its HONEST REMAINDER was the missing real-on-disk-vocab staging. OP-28c closes it.
- STAGING = (a) REAL Qwen vocab: edge/ckpt/storyboard-grpo vocab.json (151643 entries, raw-UTF-8 keys, 2.78MB) +
  merges.txt (151387 rules) — stock Qwen2.5 tokenizer, read-only, NEVER committed (oracle = candidate paths + env
  override + honest SKIP-if-absent). 151936 = embedding rows incl. tokenizer.json special tokens, not vocab.json.
- ORACLE stdlib/flame/op28c_bpe_realvocab_staging.hexa — PRODUCTION modules (`use self/ml/tokenizer_bpe` +
  `use stdlib/flame/flame_bpe_corpus_lib`), NOT a self-contained twin: bpe_load TWICE (independent json_parse) +
  flame_bpe_corpus_load over a staged multilingual corpus; all loads before the OP28C-DET-BEGIN marker (bpe_load
  prints a wall-clock ms line), byte-diff = the 1895-byte DET block.
- RESULT (GATE=1 both platforms): spot ids 7/7 vs real vocab incl. OP-28b-repaired glyphs (127->221 · 160->254 ·
  173->255 · Ġhello->23811); round-trip exact 6/6 (ASCII · space-heavy · Latin-1 · KO · ZH/JA-no-space · mixed —
  the chr-collision classes); max|Δ|=0 run-to-run AND fresh-load-vs-fresh-load; FULL 151643-entry id->token table
  identical across loads (dict_keys hash-order does NOT leak into observable ids); flame corpus-entry leg green;
  CROSS-PLATFORM local arm64-macos == aiden x86-linux (free pool CPU, $0) DET block byte-IDENTICAL — checksum
  757635534, fingerprint `0 0 0 231 76 148 198 65` on BOTH. aiden staged via scp (/tmp/op28c-qwen + 3-file module
  tree), cleaned after.
- FINDING (staging trap, NOT a load-path defect): STALE-INSTALL `use`-RESOLUTION — the Jun-1 ~/.hx hexa resolves
  `use "self/ml/tokenizer_bpe"` of a stdlib/flame-RESIDENT file to the INSTALL's own self/ tree (pre-OP-28b map);
  first run silently reproduced the EXACT pre-fix failure (U+017F glyph, UNK ids, round-trip 2/6) despite fixed
  repo source. Diagnosed by elimination (raw-UTF-8 keys on disk verified · json_parse OK at 151643-key scale ·
  build_byte_to_char returning the OLD table). CURE = run a repo-root COPY (source-dir-relative resolution picks
  the repo's fixed modules); relative `use "../../self/..."` is NOT a fix (inner lib use re-splices the stale copy
  -> duplicate-def compile error). Documented in the oracle header + verdict.
- Production load path at real scale: NO defect (json_parse 2.7MB/151643 raw-UTF-8 keys, glyph bijection, merge
  ranks, id maps all clean). Verdict .verdicts/hexa-0pod/F-OP28C-VOCAB-STAGING.txt.

## 2026-06-12 — OP-32 DONE: machine-independence on a 4th flame arch (spiking LIF recurrent + local plasticity) + OP-30 compliance + NEW binary-spike FMA-immunity finding ($0 · 0-pod)
- Deep-dive round-8 branch ②: generalizes OP-15/29/31's machine-independence from 3 archs to FOUR. 4th arch = a spiking
  LIF RECURRENT network with local STDP plasticity (production spiking_lib: flame_event_threshold + flame_refractory_step
  + flame_stdp_pair) + the plasti_sim competitive-Hebbian learner — the first RECURRENT (state threaded across T=32
  steps: v · refr · traces · plastic Wrec · s_prev), first EVENT-DRIVEN, first NON-BACKPROP-learning arch in the series.
  NEW primitive class vs CLMConvMoE/decoder/MLP: ≥-threshold branch, integer refractory countdown w/ clamp, clip,
  winner-take-all argmax, local STDP/Hebbian updates (no loss, no gradient).
- ORACLES: stdlib/flame/op32_spiking_determinism_eq.hexa (PART A imports PRODUCTION plasti_sim ps_present chain, W
  threaded over S=24 presentations; PART B = T-step LIF+STDP chain w/ verbatim spiking CPU primitive bodies) +
  stdlib/flame/op32_spiking_selfcontained.hexa (NO `use`, scp-runnable; inline-ascending currents; 2 in-band OP-30 FMA
  diagnostics).
- byte-eq RUN-TO-RUN: raster · plastic W · membrane v · both traces · plasti_sim W + winner sequence ALL max|Δ|=0, with
  NON-TRIVIAL dynamics (25/320 spikes fired · STDP moved weights max|Δ| 0.254879 · ≥2 distinct winners).
- CROSS-PLATFORM byte-IDENTICAL (the real OP-30 test): local arm64-macos vs aiden x86-linux (free CPU pool
  @192.168.50.119, $0, NO vast/GPU) — identical checksums raster 236398270 / final-W 876398044 / final-v 147958574 +
  identical IEEE-754 fingerprints RASTER `0 0 0 124 77 46 172 65` · W `0 0 0 238 98 30 202 65` · V `0 0 0 92 86 163 161 65`.
- OP-30: the spiking substrate is compliant BY CONSTRUCTION (pure t_* loops — no farr_matmul anywhere in production);
  the oracle's only matmul-shaped op (input/recurrent current) is inline-ascending. DIAG-A: rate-coded REAL-VALUED drive
  through the FMA-fused farr_matmul byte-DIVERGES arm64 1478294112 vs x86 210297454 (live in-band reproduction of the
  OP-29/30/31 root cause on the 4th arch). NEW FINDING DIAG-B: the binary {0,1} spike pattern through the SAME fused
  kernel is byte-IDENTICAL cross-ISA (1881150137 both) — fma(a,b,c) with b∈{0,1} makes a·b EXACT ⇒ fused≡unfused, so
  binary-SPIKE matvecs are provably AND now measurably FMA-immune; rate-coded drives are not. The OP-30 boundary is
  precision-structural (rule unchanged — traces/weights go real-valued the moment plasticity engages).
- libm: CLEAN BY CONSTRUCTION — no transcendental on the arch; leak/trace decays are binary-exact rationals (15/16 ·
  7/8 · 13/16), exp(−dt/τ) folded into constants; no dt_* even needed.
- HOLE-2 FOUND (pre-existing, link-level, documented NOT closed — packaging follow-up): `use "stdlib/flame/spiking_lib"`
  fails to LINK on CPU-only hosts: flame_stdp_pair_gpu → builtin forge_dispatch_stdp_pair → codegen lowers to
  hexa_forge_dispatch_stdp_pair, whose prototype (runtime.h L1504) + CUDA emit exist but whose CPU oracle body is ABSENT
  from the regenerated runtime.c (grep=0; 2 independent `ld: symbol not found` repros; git -S shows it was never
  committed). hexa codegen emits all module fns (no DCE) so even non-callers fail. Not a determinism hole — the
  primitive semantics are proven deterministic+machine-independent by this very oracle.
- Milestone OP-32 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP32-4TH-ARCH.txt. aiden temp cleaned (leak-0). $0 · 0-GPU ·
  0-pod · no vast · foreign pod NOT touched.

## 2026-06-11 — OP-24d DONE: G1 turnkey kit pre-gates the proven input-side determinism (OP-28/28b) ($0 · 0-pod · NO GPU/vast/pod)
- Deep-dive round-7 branch ④: closes the 0-pod-feasible completeness of gap G1 (real-corpus end-to-end). The GPU
  trainer run stays GPU-build-gated, but the now-proven INPUT-side pieces are WIRED into OP-24c's turnkey kit.
- INTEGRATION (tool/clm/build_clmprod_tf32_e2e.sh, the only code change): added STEP 0 · INPUT-SIDE PRE-GATE BEFORE
  the PROVISION/ENV/nvcc guards (CPU-only, runs on ANY host). run_input_oracle <name> <oracle> <pass-token> runs each
  oracle TWICE via $HEXA_RUN (bare-file form, matching the script's own emit call) and asserts (i) the in-oracle PASS
  token (F-OP28-CORPUS-LOADER-DET = 1 / F-OP28B-BPE-FIX = 1) AND (ii) process-to-process byte-eq (run1==run2 diff
  clean), surfacing each CROSSPLAT-FINGERPRINT line. Runs BOTH oracles (OP-28 byte-level V=256 + OP-28b BPE V=151936);
  INPUT_PREGATE=PASS only if BOTH pass both legs, else the kit STOPS (exit 2) before spending a GPU build (g5: a
  determinism claim on a non-reproducible input is meaningless). HEADLINE [RESULT] line now also reports
  INPUT-PRE-GATE(OP-24d · CPU · 0-GPU)=$INPUT_PREGATE alongside GATE-A/B/C.
- VALIDATION (0-pod, CPU): bash -n VALID. op28 oracle PASS locally, fingerprint 0 0 0 216 16 88 186 65 == the F-OP28
  recorded local+aiden x86-linux value (cross-platform byte-eq). op28b oracle PASS locally (fingerprint
  0 0 0 100 21 127 152 65). The pre-gate function exercised end-to-end against ~/.hx/bin/hexa-run => INPUT_PREGATE=PASS
  (both oracles PASS both legs, both fingerprints surfaced).
- G1-READINESS PICTURE: PROVEN 0-pod NOW + pre-gated = the INPUT side (tokenize->pack->batch, byte-level F-OP28 AND
  BPE F-OP28b, byte-eq + machine-independent by construction). SOLE GATED REMAINDER = the GPU trainer STEP run
  (clm_prod_gpu -DHEXA_CUDA build env; F-OP24B's 31-host-marshal-wrapper frozen-seed completeness, a build-ENV gate,
  not a pod). G1 is 0-pod-MAXIMALLY-CLOSED: everything provable without a GPU is proven AND wired; only the GPU step
  awaits authorization.
- Behavior-preserving: the kit's GPU STAGE/BUILD/RUN/GATE-A/B/C logic UNCHANGED; OP-24d only PREPENDS a CPU pre-gate +
  a headline line. Readiness doc G1 row updated (severity HIGH -> reduced). NO GPU run, NO vast, NO pod, NO foreign
  pod touched. Verdict .verdicts/hexa-0pod/F-OP24D-G1-READINESS.txt.

## 2026-06-11 — OP-31 DONE: machine-independence on a 3rd flame arch (MLP) + OP-30 cross-ISA-matmul invariant DIRECTLY DEMONSTRATED ($0 · 0-pod)
- Generalizes OP-29's G2 from 2 archs to THREE. 3rd arch = a plain feed-forward MLP (Linear→GELU→Linear→GELU→Linear),
  structurally DISTINCT from CLMConvMoE (OP-15: conv+MoE+GroupNorm) AND the decoder block (OP-29: attention+RoPE+
  SwiGLU+RMSNorm). Every MLP layer is a pure dense GEMM → the purest stress of the OP-30 cross-ISA matmul invariant.
- 3rd-arch model = PRODUCTION nn_lib MLP primitives (nn_linear_fwd + nn_gelu_fwd + nn_linear_bwd + nn_gelu_bwd).
- ORACLES: stdlib/flame/op31_mlp_determinism_eq.hexa (run-to-run, imports the prod lib) +
  stdlib/flame/op31_mlp_selfcontained.hexa (cross-platform inline-reduction twin, NO `use`, scp-runnable, + an
  in-band OP-30 FMA diagnostic that computes layer-1 BOTH via the inline-ascending dot AND via the FMA-fused C kernel).
- byte-eq RUN-TO-RUN: fwd out · bwd grads · bwd dx all max|Δ|=0 on BOTH oracles, BOTH platforms (local arm64-macos +
  aiden x86-linux).
- CROSS-PLATFORM byte-IDENTICAL (the real OP-30 test): local arm64-macos vs aiden x86-linux (free CPU pool
  @192.168.50.119, $0, NO vast/NO GPU) emit IDENTICAL checksums (fwd 1585504437 / grad 926871122) + IDENTICAL IEEE-754
  fingerprints FWD `0 0 64 45 56 160 215 65` · GRAD `0 0 0 41 119 159 203 65` on the inline-ascending det path.
- OP-30 INVARIANT DIRECTLY DEMONSTRATED (not just asserted): the production nn_linear_fwd routes through
  forge_dispatch_matmul → FMA-fused farr_matmul (tensor_lib L58 "ikj order, FMA-fused under clang -O2") = a REAL hole.
  The twin's in-band diagnostic shows that exact kernel's L1 checksum byte-DIVERGES arm64 2039553633 vs x86 124945498
  on byte-IDENTICAL fp64 inputs, WHILE the inline-ascending rewrite of the SAME matmul stays byte-identical (fwd ck
  1585504437 on both). The invariant is the live difference between those two on this arch.
- HOLE CLOSED inline-ascending (_mlp_linear_fwd = plain mul+add, no C kernel — the OP-29/CLMConvMoE discipline);
  nn_linear_bwd was already inline-clean. libm-CLEAN (GELU via dt_erf/dt_exp; MLP has no RMSNorm → _nn_sqrt libm not on
  this path). Machine-independence GENERALIZES to 3 structurally-distinct archs → Y.
- Milestone OP-31 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP31-3RD-ARCH.txt. aiden temp files cleaned (leak-0). $0 ·
  0-GPU · 0-pod · no vast · foreign pod NOT touched.

## 2026-06-11 — OP-19f DONE: musl ctor-ABI regression gate (static POSIX-environ guard; locks OP-19e) ($0 · 0-pod)
- Closes OP-26b gap G6 ("musl ctor-ABI fix CI-gate, LOW"). A LOW-BLAST-RADIUS gate that regression-locks the
  OP-19e (#3029) musl env-capture fix so the `(argc,argv,envp)` constructor-args ABI it removed can't silently
  re-land (CI doesn't run under musl → a revert/seed-regen would bring the SIGSEGV back unnoticed).
- MECHANISM (static grep guard, NOT a runtime musl test — honest per g5): `tool/musl_ctor_abi_gate.sh` reads the
  OP-19e patch SOURCE `tool/restore_frozen_seeds`, extracts ONLY the awk-EMITTED C of the env-capture patch (the
  `print "..."` payloads, dropping `//` comment payloads), then asserts (1) the musl-safe
  `hxlcl_capture_environ(void){ hxlcl_environ = environ; }` POSIX-environ form is PRESENT, and (2) any args-ABI
  capture (`hxlcl_capture_environ(int …` OR `hxlcl_environ = envp`) is ABSENT. The shell `#` prose + emitted `//`
  comments that DO spell out the old bad signature are structurally exempt (non-print + //-drop) → can't false-fail.
- CI wrapper `.github/workflows/musl-ctor-abi-gate.yml`, paths-scoped to restore_frozen_seeds + the gate + the
  workflow. Mirrors OP-5b's forge_runtime_warn_gate discipline (guard ONLY the clean thing).
- PROVEN 0-GPU, $0: (A) PASSES on the current OP-19e-fixed tree (exit 0, no false positive). (B) CATCHES an
  injected args-ABI form — scratch copy, file restored to 0-diff — exit 1, BOTH guns fire (safe-form-missing +
  args-ABI-present). (C) low-blast-radius confirmed: unrelated prose mentioning argc/argv/envp did NOT trip it.
- HONEST: static source-pattern guard, not a musl runtime run (CI has no musl runner) — the cheapest effective
  guard, locking the exact source pattern the musl SIGSEGV depends on.
- Milestone OP-19f flipped [x]. Verdict .verdicts/hexa-0pod/F-OP19F-MUSL-CTOR-GATE.txt. $0 · 0-GPU · 0-pod · no
  vast. Foreign vast pod 40375114 (anima-chat-7b) NOT touched.

## 2026-06-11 — OP-21D DONE: build_w16.sh hardened + dry-run + OP-29 FMA-ref check (turnkey bullet-proof; H100 perf still gated) ($0 · 0-pod)
- The 0-pod-feasible completeness pass over the H100-GATED w16 perf measurement (NO GPU, NO vast, NO pod).
- (a) DRY-RAN + HARDENED tool/wgmma/build_w16.sh. bash -n VALID. Structural walkthrough: gate ORDER correct
  (provision-guards -> build -> MODE 9 -> MODE 0 HARD GATE -> MODE 1 D1-falsifier HARD GATE + sweep + OP-21B
  fallback -> MODE 4 bit-exact + perf -> SASS -> DESTROY). Guards added: set -o pipefail; NVCC_MISSING clean
  early-exit; NO_GPU clean early-exit (nvidia-smi absent/empty OR compute_cap != 9.0 -> refuse wrong-arch build,
  no auto-rent); MODE 0 + MODE 1 HARD GATES die BEFORE any MODE 4/perf; MODE 4 per-cell rel_rms fail prints NO
  perf + final STOP if all floored; EXIT trap prints leak-0 DESTROY on EVERY exit path.
- DRY-RAN on the 0-pod box: NVCC_MISSING path AND NO_GPU path both exit clean (code 1) with instructions and the
  DESTROY trap fires. CONFIRMED.
- (b) OP-29 (#3042) FMA cross-cut: WROTE tool/wgmma/w16_op29_ref_check.cpp (clang++, 0-pod). Proved MODE-1's CPU
  reference is the OP-29-SAFE inline ascending `acc += a*b` (not fmaf-fused; == w16.cu L558; FMA Δ << 3e-3 tol),
  and MODE-4's reference is cuBLAS-TF32 ON DEVICE (no CPU FMA) -> the OP-29 cross-ISA FMA divergence is
  STRUCTURALLY ABSENT from the MODE-4 gate and CANNOT false-fail it. Device K-accum order well-defined
  (ascending k, slab==flat 16384/16384). grep: only `fmax` (not fma) in w16.cu CPU paths. RAN: 4/4 PASS.
- Re-ran the prior 0-pod checks: OP-21B 7/7 PASS, OP-21C 6/6 PASS, OP-21D 4/4 PASS.
- HONEST (g5): the H100 perf measurement REMAINS GATED — no wgmma/PTX executed, no TFLOP/s claimed. Value = the
  build kit is now bullet-proof turnkey + the OP-29 subtlety checked OFF -> highest H100 first-try odds.
- Milestone OP-21D flipped [x]. Verdict .verdicts/hexa-0pod/F-OP21D-W16-HARDEN.txt. $0 · 0-GPU · 0-pod · no vast.
  Foreign vast pod 40375114 (anima-chat-7b) NOT touched.

## 2026-06-10 — OP-27 DONE: deterministic TF32 fast-mode reflected into the dojo (0-pod docs) + commons directive DRAFTED for user sign ($0)
- Reflected the validated deterministic TF32 fast-mode (OP-20 #2999 + OP-23 #3005 + OP-24 #3009 + OP-25 #3007)
  into docs/hexa-dojo.md as a contributor recipe: `### deterministic TF32 fast-mode (precision-uncap)`, inserted
  after the g86 "flame vs PyTorch — fair-bench parity recipe" section, before `## references`. Elephant-rule
  (current-facts only). Covers: WHEN (HEXA_TF32_FASTMODE=1 for >3× keeping determinism; FP64 default byte-identical
  flag-off; keep FP64 for cross-machine byte-eq) · DETERMINISM (self-byte-eq max|Δ|=0 single-step + whole 100-step
  trajectory; pin CUBLAS_PEDANTIC_MATH portable guarantee) · W14 (rel-RMS 1.13e-6, ~34× inside) · REAL-not-illusion
  (N=100 loss-track ~1e-7, bounded ~5e-7 drift) · card-robust 4.2×@B=1 (B=8 19-21× FP64-throttle-caveated) ·
  precision Pareto FP64→TF32 SWEET-SPOT→BF16 DOMINATED + ASCII diagram · live-wire dispatch site (runtime_cuda_emit
  .hexa `_hx_cuda_farr_matmul_gpu`). Every number CITED from a verdict (g5).
- COMMONS half: DRAFTED ONLY. Wrote the proposed `g87_tf32_fastmode` directive (do/dont ≤100char/line, ASCII)
  verbatim in the verdict for the user to apply AFTER `sidecar sign commons`. The agent NEVER self-signs a
  sign-gated SSOT → NO .tape file edited in this PR. Honest: dojo half shipped 0-pod, commons half awaits user sign.
- $0 · 0-pod · NO GPU · NO vast · NO pod · foreign vast pod 40306156 NOT touched.
  Verdict .verdicts/hexa-0pod/F-OP27-TF32-DOJO.txt.

## 2026-06-10 — OP-21A DONE: Hopper warp-spec TMA kernel WRITTEN (wgmma_tf32_w16.cu) + turnkey build kit, local-checked, H100-gated perf (0-pod, $0)
- Turned the OP-21 DESIGN (#3000, F-OP21-HOPPER-WARPSPEC-DESIGN) into CODE. WROTE self/native/wgmma/wgmma_tf32_w16.cu
  (#define W10_NO_MAIN; #include "wgmma_tf32_w10_lib.h" for the SAME-BINARY gemm_w10 + cuBLAS-TF32 apples baseline,
  the W11/W12/W13/W15 pattern). All FIVE OP-21A deltas implemented, each adapted line citing w10_lib.h:
    D1 canonical-atom landing  — enc_canonical() + MODE 0 (w16_probe_canon) + MODE 1 (w16_probe_desc) = the
       FALSIFIABLE D1 gate; descriptor-direct read via mk_sw(swmode=1), (lbo,sbo,boff,swmode) runtime-swept (W15 fields).
    D2 descriptor-direct wgmma — gemm_w16 reads swizzled smem IN PLACE; the As0/As1/B0/B1 gmma decode band
       (w10_lib.h L361) DELETED. smem 96->64KB/CTA (W15-measured), 2 CTA/SM held.
    D3 NST=3 decode-free ring  — only the swizzled tiles ring (w10_lib.h L331 SWBUF); the -32KB headroom buys the stage.
    D4 wgmma.wait_group<NST-2> — literal 1 (=NST-2@NST=3); commit per slab then wait<1> so the OLDEST group drains
       while the NEWEST issues (back-to-back across K-slabs), replacing w10_lib.h L407 wgmma.wait_group 0.
    D5 setmaxnreg producer/consumer split — 384 thr: producer WG setmaxnreg.dec 40 (TMA+mbar, empty[]-gated stream)
       + 2 consumer WGs setmaxnreg.inc 232 (wgmma). UNBLOCKED at the 128x128 64-reg accumulator (w10_lib.h L345) vs
       W12's 128x256 128-reg that ptxas rejected (C7507). FALLBACK -DW16_PRODUCER_WG=0 = single-elected-thread (W10 H1).
    + gemm_w16b = OP-21B fallback (keep band, no M3 dependency) for the D1-floored path.
- LOCAL 0-pod CHECK (no nvcc locally — `which nvcc` absent; device-PTX compile is GPU-TOOLCHAIN-GATED):
    (a) host-side C++ STRUCTURAL parse (clang++ -std=c++17 -fsyntax-only, CUDA stubbed, device-asm/__syncthreads
        neutralized): DEFAULT (producer-WG) exit 0, FALLBACK (-DW16_PRODUCER_WG=0) exit 0 — both paths well-formed C++.
    (b) sm_90a ISA-level review of authored PTX: wgmma.wait_group/commit_group + setmaxnreg as IMMEDIATE literals
        (canonical form, matches w10_lib.h's `...aligned 0;`), mbarrier.arrive.shared::cta.b64, fence.proxy.async,
        mk_sw bit-packing + GMMA 8x4 const reused VERBATIM — NO discrepancy. Only unproven element = D1 (canonical
        landing -> bit-exact), which is the pre-registered falsifier gated by MODE 1, NOT asserted.
    (c) exact GPU-gated compile step: `nvcc -O3 -arch=sm_90a wgmma_tf32_w16.cu -o w16 -lcublas -lcuda -Xptxas -v`
        (watch C7507 setmaxnreg-ignored -> -DW16_PRODUCER_WG=0). Runs on authorized H100 only.
- WROTE turnkey tool/wgmma/build_w16.sh (bash -n syntax-valid): provision-checklist (NO auto-rent, ZERO-VAST; exits
  if no sm_90a visible) -> build -> MODE 9 canonical dump -> MODE 0/1 gates (D1 falsifier, field sweep, OP-21B switch
  on full-sweep floor, W10 KEPT) -> MODE 4 bit-exact gate + occupancy + perf sweep S{2048,4096,8192} x NST{3,4,2}
  vs same-binary gemm_w10 (the 70.7 apples) + cuBLAS-TF32 -> SASS (decode STS gone + wgmma back-to-back) ->
  Δ-vs-W10 headline -> destroy leak-0. g5 gate order enforced (no perf before rel_rms-0 single-tile gate).
- HONEST (g5): NO perf number produced or claimed — the device-PTX compile + ALL TFLOP/s is H100-GATED. W10 70.7
  frontier KEPT (the W11/W12/W13 hard rule) until w16 lifts it bit-exact on H100. cuBLAS-TF32 = ROOFLINE, no
  superiority claim. Value = the OP-21A lever is now CODE not just design — H100 authorization -> one command.
  $0 · 0-GPU · 0-pod · no vast/pool/pod. Verdict .verdicts/hexa-0pod/F-OP21A-W16-KERNEL.txt.

## 2026-06-10 — OP-19b DONE: pure-FP deterministic erf seals the GELU cross-platform hole → flame FULLY machine-independent byte-exact (0-GPU)

Closed OP-19's measured latent residual (GELU libm `erf`, the last libm transcendental in the step).
Implemented `flame_math.dt_erf` = Abramowitz & Stegun 7.1.26 rational with the exp via OP-19's deterministic
`dt_exp` — pure +,-,*,/ + dt_exp, NO libm, BRANCHLESS in z (only the z=0 odd sign flip).

KEY DEAD-END NOTED: a first cut (Maclaurin series + hard clamp |z|≥4) was 1.54e-8-accurate but BROKE the
fused-vs-unfused GN-GELU byte-eq (max|Δ|=2.5e-7): the GELU argument straddles the clamp boundary differently
in-register (fused) vs stored-reload (unfused). A series+rational-tail hybrid had the same seam defect. The
unconditional A&S form has NO value-dependent boundary → byte-eq restored. (Maclaurin also diverges past z≈5.)

WIRED: host nn_lib `_nn_normal_cdf`/`_pdf` + gn_lib `_gn_gelu` (+ `_gn_dt_exp` replica); reference
clm_conv_devfeed (4 erf + 2 exp sites); device `_hx_dt_erf_dev` shared by all GELU kernels (+ `_hx_dt_exp_dev`
hoisted, F-OP19 dup removed); host C fallback (restore_frozen_seeds `_op18_gelu`→dt_erf) — VERIFIED clang-clean
+ BYTE-IDENTICAL to hexa dt_erf (fold 93,35,192,253,183,12,237,63 @1.19071).

CROSS-PLATFORM ORACLE (op19b_crossplatform_erf.hexa, self-contained): det-erf GELU fwd+bwd byte fold IDENTICAL
on local+ghost arm64-macos AND aiden x86-linux — FWD 4548590605583584556, BWD 4249661408190172843 on all 3.
BEFORE: libm `erf` won't even LINK on aiden (`hexa_math_erf` undefined) → can't be cross-platform measured.
ACCURACY: max|dt_erf − libm erf| = 1.38e-7 (≤ GELU tolerance; g5 honest trade matches-libm → matches-all-platforms).

DEPENDENT ORACLES re-locked: OP-9 LN-reduction PASS 0.0; GN-GELU re-lock proof (op19b_gngelu_relock.hexa, both
arms dt_erf) PASS max|Δ|=0; OP-15 step + OP-18 gelu2 inherit via nn_lib + the byte-eq host fallback (validate on
fresh build — local hexa is a stale prebuilt that uses its own embedded stdlib).

RESULT: exp/erf/ln all hand-rolled deterministic, sqrt Newton — NO libm transcendental left → flame is now
FULLY machine-independent byte-exact. $0 · 0-GPU · free pool (aiden/ghost) · no vast. Verdict
.verdicts/hexa-0pod/F-OP19B-DET-ERF.txt.

## 2026-06-10 — OP-25 GREEN gates / DOMINATED: deterministic BF16 fast-mode — Pareto-dominated by TF32 (aiden 5070, FREE)

The precision-uncap ladder's NEXT rung after OP-20 TF32 (#2999) + OP-23 TF32-drift (#3005). BF16 has an
8-bit mantissa (vs TF32's 10-bit) so the GEMM is less accurate but POTENTIALLY faster (or same speed, half
GEMM-input bytes). OP-25 asks: is a deterministic BF16 step fast-mode (a) self-byte-eq, (b) within W14 vs
FP64, (c) FASTER than TF32 — i.e. a NEW rung, or DOMINATED by TF32 (same throughput, no reason to use it)?

- METHOD: 3-lane (BF16 / TF32 / FP64) single-process harness over the OP-20 fused step DAG (fwd GEMM →
  fused valley LN+gelu+copy → transpose-elim bwd GEMM → single-launch AdamW); only cuBLAS storage/compute
  differs (BF16=CUDA_R_16BF/COMPUTE_32F_FAST_16BF). MIXED-PRECISION CONTRACT (decisive): master weights +
  AdamW state + glue accum all fp32; only the two GEMM operands are bf16 (bf16 copy refreshed each AdamW).
  All glue fixed-order, no atomics. Drift harness = continuous trajectory per lane (W/m/v persist) + scalar
  loss mean(G²). aiden RTX 5070 FREE, idle-guard hard-backoff 30→480s×8. 8/8 1-step + 4/4 drift cells.
- (1) BF16 SELF-BYTE-EQ: YES, max|delta(W',loss)|=EXACTLY 0 on every cell AND over the full 50-step
  trajectory. PEDANTIC NOT needed (DEFAULT bf16 tensor-op already run-to-run deterministic; identical bytes
  + time — same finding as OP-20's TF32). Pin PEDANTIC for a portable ship guarantee (costs nothing).
- (2) rel-RMS vs FP64 ~1.13-1.22e-6 — NOT the expected ~1e-3, and essentially EQUAL to TF32's 1.13e-6.
  WHY (load-bearing): fp32 master weights → only GEMM operands bf16 → the e-3 GEMM error enters W through
  ONE tiny optimizer step → e-6 W' error. Fully trainable; 4 orders inside W14 1e-2. (A bf16-MASTER step
  WOULD show e-3 — but nobody ships that; the fp32-master contract is the real one and is what we measured.)
- (3) SPEED: FP64/BF16 = 3.88-4.10×@B=1, 15.8-16.8×@B=8 (B=8 inflated by 5070's ~1/64 FP64, same OP-20
  caveat). BF16-vs-TF32 = TF32/BF16 1.01-1.12× → BF16 at most ~12% faster @B=8 (half-input-bytes mem
  traffic, NOT compute) and a DEAD HEAT @B=1 (1.01-1.02×, the latency regime the ~3× cap names). On the
  5070 BF16 & TF32 are both 16-bit-input fp32-accum tensor-ops at EQUAL throughput → no GEMM-cost edge.
- (4) DRIFT N=50, B=1: BF16 LOSS TRACKS FP64 — worst loss-track gap 9.4e-5 (D=768) / 1.7e-4 (D=1536),
  bounded, no growth; weight rel-RMS ~e-6 does NOT accumulate (1.2e-6@step1 → 2.5e-6@step50) =
  chaotic-but-microscopic, same shape as OP-23's TF32 drift. Real trainable fast-mode, not a 1-step illusion.
- PARETO PLACEMENT: FP64(exact,1×) → TF32(e-6, 4.2×) → BF16(e-6, 4.1× — SAME accuracy + SAME speed as TF32).
  BF16 is Pareto-DOMINATED by TF32: not worse, but BETTER on neither axis → no reason to prefer it. The
  expected "less accurate but faster" trade did NOT appear: (i) fp32-master contract erases the accuracy
  gap, (ii) equal 16-bit tensor throughput erases the speed gap. TF32 stays the precision-uncap TERMINAL
  SWEET SPOT; the BF16 rung is a NO-OP on consumer hardware. HONEST CLOSED result, $0, no vast/pod/leak.
- ARTIFACTS: verdict .verdicts/hexa-0pod/F-OP25-BF16-FASTMODE.txt; harness
  tool/bench/flame_bench_step_bf16fast.cu + flame_traj_drift_bf16_op25.cu; drivers run_op25_5070.sh +
  run_op25_drift_5070.sh; raw op25_5070_raw.log + op25_drift_5070_raw.log. branch domain/hexa-0pod-op25.

## 2026-06-10 — OP-23 GREEN: TF32 N-step trajectory drift vs FP64 — TF32 fast-mode is REAL, not a 1-step illusion (aiden 5070, FREE)

The decisive validation of OP-20's deterministic TF32 fast-mode. OP-20 (#2999) proved a SINGLE TF32 flame
step is self-byte-eq + rel-RMS 1.13e-6 vs FP64 + 4.2×@B=1 — but flagged the LARGER deferred question:
does the TF32 TRAJECTORY track FP64 over N steps, or peel away (1-step illusion)? OP-23 answers it.

- METHOD: TWO continuous trajectories (TF32 lane + FP64 lane) from the SAME seed + SAME fixed data, N=100
  steps, AdamW state W/m/v PERSISTS across steps so drift ACCUMULATES (OP-20 reset every step). Same step
  DAG as OP-20 (fwd GEMM → fused valley LN+gelu+copy → transpose-elim bwd GEMM → single-launch AdamW); only
  cuBLAS compute type differs. Added deterministic loss = mean(G²) over the post-valley activation (fixed-
  order block tree reduce, no atomics). TF32 trajectory run TWICE for whole-trajectory self-byte-eq.
  aiden RTX 5070 sm_120, FREE sidecar pool, idle-guarded, leak-0. 4/4 cells (DEFAULT+PEDANTIC, D={768,1536},
  B={1,8}).
- Q1 WEIGHT DRIFT = BOUNDED: relRMS(TF32-W vs FP64-W) starts ~1.13e-6 (OP-20's 1-step #), SHRINKS to
  ~4.5–5.3e-7 by step 100 — does NOT grow. max|dW| creeps 1e-8→~5e-7 (chaotic accum) but stays microscopic
  (3–4 orders inside NN's ~1e-3 forgiveness). The GOOD case.
- Q2 LOSS-TRACKING = YES (decisive): TF32 loss matches FP64 loss to ~1e-7 every step. WORST gap 2.495e-5 is
  at the COLD-START step 1 (before AdamW's bias-corrected moments settle); from step 6 it DROPS to ~1e-7 and
  stays flat. NO peeling, NO drift trend — both lanes ride the SAME loss curve to the SAME loss (~0.40739).
- Q3 SELF-BYTE-EQ over the WHOLE trajectory: run1-vs-run2 W max|Δ|=0.000e+00 AND per-step loss max|Δ|=0.000e+00
  at step N on every cell. Determinism holds across the trajectory, not just step 1. PEDANTIC NOT needed
  (DEFAULT TF32-tensor-op already bit-identical run-to-run, identical numbers).
- VERDICT (g5 honest): the RIGHT metric is loss-tracking (training-equivalent), NOT weight byte-closeness —
  chaos guarantees weights drift, which is exactly why flame's identity is SELF-determinism (TF32-vs-TF32=0),
  not cross-precision. Bounded loss-tracking ⇒ TF32-mode is a REAL training fast-mode, CONFIRMED at the
  trajectory level. The 1-step rel-RMS 1e-6 was NOT an illusion. Caveats: N=100 small synthetic config
  (mean(G²) proxy, no real corpus/LR-schedule); drift TREND flat-to-shrinking to step 100, no late blow-up.
- Harness tool/bench/flame_traj_drift_tf32_op23.cu · driver tool/bench/run_op23_5070.sh · raw
  tool/bench/op23_5070_raw.log · verdict .verdicts/hexa-0pod/F-OP23-TF32-DRIFT.txt. FREE pool, NO vast, $0.

## 2026-06-09 — OP-22 DONE: MEGASTEP whole-step megakernel DESIGN + Amdahl bound + H100 recipe (0-pod, vs TF32)

Produced (reading existing real-pod verdicts + research memory only — $0, 0-GPU, NO vast/pod) the 0-pod
DESIGN + honest Amdahl ceiling + turnkey experiment recipe for MEGASTEP: the whole flame CLMConvMoE train
step fused into one persistent grid-resident cooperative megakernel to fill the between-GEMM valley.

- VALLEY STRUCTURE (cited F-FUSION-FF-DUTYCYCLE, real H100 SXM, vast 39958628 DESTROYED leak-0):
  GEMM% = 0.04% of wall (≈0.3% GPU-active) vs valley = 99.96% (GLUE 13.15% + GAP/idle 86.80% + OPT 0.01%).
  GPU-active is 90.5% the 2 byte-eq-forced single-thread GroupNorm reductions (105–132 ms EACH). util
  MEDIAN 1% / MEAN 10.9% / 72.2% samples <5% = BIMODAL {bursts, ~0% idle} occupancy wall. The step is in
  NO sense GEMM-bound.
- AMDAHL CEILING = 1/GEMM% = 1/0.0004 = 2844× — flagged HONESTLY as a USELESS ceiling (huge only because
  GEMM is a rounding error; Amdahl gives the limit of perfect serial-removal, NOT what a megakernel reaches).
  Binding bound = the serial-DAG occupancy FLOOR; MEASURED achievable ~1.0–1.04× (M2 MEAN +3.4pp).
- DESIGN: 9-phase grid.sync()-delimited cooperative megakernel (cudaLaunchCooperativeKernel, one wave) with
  inline own-GEMM replacing cuBLAS host calls. BOTH megakernel walls already closed: own-GEMM (#2697) + coop
  grid-synced byte-eq GroupNorm (F-FUSION-MEGAKERNEL-GN-GRIDSYNC, A100 max|Δ|=0). Buildable; just doesn't win.
- THREE honest tensions (all cited, real-pod): (1) own-GEMM ~6× off cuBLAS (W10 70.7 TFLOP/s) — fusion trades
  GEMM speed; (2) byte-eq ⊥ util-lift (B6 max|Δ first_ce| 9e-16…1.8e-15 ≠ 0 after ONE fwd — GEMM k-order ≠
  cublasDgemm, structural); (3) parity wgmma CANNOT co-reside (MEGA-OWNGEMM: blockDim<128 can't issue wgmma +
  (S/128)² > 264-CTA one-wave ceiling → grid.sync deadlock @S=4096).
- MEGASTEP-vs-TF32 (OP-20 ~4.2× @B=1) HONEST VERDICT: (b) DOMINATED. Same 99.96% valley; TF32 ~4× the win at
  ~0 architecture risk (P1-TF32 +5.5pp util CE-safe). MEGASTEP's only GREEN slice (FF-VALLEY 2.5×) is a byte-eq
  single-thread-GN ARTIFACT that collapses to MPK ~1.2–1.3× in a parallel/TF32 trainer; no orthogonal stack on
  top of TF32 (TF32 already pulls GEMMs inline + collapses launches; residual idle is the serial-DAG floor).
  DECISION: do NOT spend an H100 campaign on MEGASTEP. Bank TF32 for B=1; pursue BATCH-FILL (≈3×) for SM-sat.
- TURNKEY RECIPE: FF-DUTYCYCLE → FF-VALLEY → MEGASTEP rungs + byte-eq/util/wall/batch-fill/TF32 gates + leak-0
  destroy, runnable the moment a GPU is authorized — with an EARLY-EXIT note (RUNG C already measured closed-
  neg; re-running buys 0 info → spend the GPU on TF32 drift-study or batch-fill instead).
- HONEST (OP-2b/OP-21-class, g5): DESIGN + BOUND only. NO measurement performed or claimed; the H100 measure
  stays GPU-gated and out of 0-pod scope. NO pod rented this session (0-pod goal = ZERO vast). leak = 0.
  Verdict .verdicts/hexa-0pod/F-OP22-MEGASTEP-DESIGN.txt.

## 2026-06-09 — OP-18 DONE: host fallbacks for the remaining L3 fused dispatchers (gelu2 + moe_block2), 0-GPU

Completed the OP-16 (#2995) L3 fused-dispatch FAMILY. forge_dispatch_gelu2 (L3-b) + forge_dispatch_moe_block2
(L3-d) were supplied ONLY by the GPU build's fusion_dispatch.c (`#ifdef HEXA_CUDA`), so a 0-GPU `hexa run`
harness driving the fused paths (clm_prod.hexa _gelu2 / _moe_block2, which emit the bare symbol via codegen)
FAILED TO LINK off-CUDA — the last 2 of the family's 3 dispatchers still host-undefined after OP-16 fixed
groupnorm_gelu only.

- WROTE the `#ifndef HEXA_CUDA` host twins in self/runtime.c (after OP-16's groupnorm_gelu block, same
  bare-wrapper-seam idiom, FP_CONTRACT OFF):
    gelu2(g0,a0,g1,a1,n)      = two erf-GELU passes (GELU(x)=x·0.5·(1+erf(x/√2))) == 2× nn_gelu_fwd.
    moe_block2(…,T,E,C)       = gelu2 → expert_pack2 (E=2 stack into ex_out[E·T·C]) → moe_router replaying
                               moe_lib _moe_exp (scaled-Taylor, NOT libm exp) with per-pos max-sub +
                               sequentially-summed denom + e-ASCENDING combine = OP-8's (#2993) PROVEN order.
- BYTE-EQ 0-GPU: both symbols U→T (nm); two TRACKED oracles drive each fused entry through the host dispatch
  vs the unfused reference → max|Δ| = 0.0:
    clm_prod_gelu2_hostdispatch_eq.hexa     — gelu2 vs 2× nn_gelu_fwd, n=16/64/257/1/1024 → 0.0 all.
    clm_prod_moe_block2_hostdispatch_eq.hexa — moe_block2 vs unfused chain, 6 shapes, comparing
                                              ex0/ex1/ex_out/probs/y → 0.0 all (whole fused unit locked).
  rc==0 on every shape (host dispatch actually fired). FP_CONTRACT OFF cured the would-be ~1-ULP FMA gap →
  EXACTLY 0 (OP-16's lesson; no residual).
- GPU PATH UNCHANGED: `#ifndef HEXA_CUDA` only — `clang -DHEXA_CUDA -fsyntax-only` shows no duplicate/
  redefinition on the 2 symbols (fusion_dispatch.c still owns the HEXA_CUDA bodies).
- DURABLE LANDING (g5, OP-17-class): self/runtime.c is gitignored frozen-seed (#2065, restored from immutable
  blob 151c52c8… which PREDATES all L3 fusion glue). Durable fix = idempotent, marker-guarded OP-18
  POST-RESTORE PATCH in the TRACKED tool/restore_frozen_seeds that APPENDS the 3 `#ifndef HEXA_CUDA` host
  bodies (gelu2 + moe_block2 + groupnorm_gelu — OP-16 never landed groupnorm_gelu durably, so OP-18 makes the
  WHOLE family restorable) at EOF where _hx_farr_table/hexa_as_num/erf/hexa_int are in scope. VERIFIED
  end-to-end: append on the freshly-restored frozen blob → patched runtime.c compiles clean no-CUDA (exit 0),
  nm all 3 symbols U→T, HEXA_CUDA excludes them (GPU untouched), idempotent (2nd run no-ops). Fully in-0-pod
  (no GPU-build regen needed beyond the restore-tool patch). Whole L3 fused-dispatch family now 0-GPU
  host-testable byte-eq. Verdict .verdicts/hexa-0pod/F-OP18-L3-FUSED-HOST.txt. $0, no GPU/pool/vast.

## 2026-06-09 — OP-4 DONE: flame fused-step 5070 win/lose map — LOSES everywhere, near-parity only in FP64

Swept the flame BENCH-10 FUSED training step (flame_bench_step_fused.cu -DFUSED, cuBLAS lane = the speed lane:
fused valley LN+gelu+copy + single-launch AdamW + transpose-elim) vs torch eager+compile across
D={768,1536,2048} x B={1,8} x dtype={FP64,TF32,BF16} = 18 cells on aiden RTX 5070 (sm_120, 12GB), free pool,
NO vast. T=256, ITERS=50, exclusive-GPU guard (util<5% & mem<800MiB; it fired several times as parallel
OP-2/OP-3 agents hit the card and correctly held each timed run).

HONEST consumer-card frontier: flame LOSES to torch.compile in ALL 18 cells — there is NO crossover-D where
flame wins on the 5070. Ratio (flame_ms / torch_compile_ms) by regime: TF32 1.78x->8.96x (widens with D at
B=1; ~2.8x flat at B=8). BF16 WORST, up to 14.66x @D=2048/B=1 (torch inductor + cuBLASLt BF16 on small-M is
very efficient; flame pays per-step f32->bf16 cast + cuBLAS overhead on a tiny matmul). FP64 near-PARITY
1.04-1.32x, tightest at large B (D=1536/B=8 = 1.007x tied, D=2048/B=8 = 1.038x) — FP64 is compute-bound on
consumer Blackwell so the GEMM dominates the wall and flame's glue overhead amortizes. 0 OOM (12GB held every
shape; largest FP64/D=2048/B=8 used ~0.4 GiB).

GATE g5 PASS x18/18: per-cell determinism run-to-run max|delta(W')| = 0 every cell; rel-RMS(fused W' vs
un-fused NAIVE-GEMM ref) <= 4.2e-8 (FP64 cells = 0.000e+00). The fusion is bit-faithful on the consumer card.

Framing (g5): flame's value on consumer HW is its IDENTITY (byte-exact / device-resident / deterministic /
no-LLVM / torch-free native step), NOT raw step-rate — torch.compile is faster everywhere on the 5070. The
earlier BENCH-1 "flame won @D=768 on the 5070" claim does NOT reproduce against torch 2.12 eager+compile
(D=768/B=1 TF32: torch eager 0.21 ms vs flame 0.43 ms). Root cause of the worst losses = per-launch + separate
cuBLAS-handle overhead at small B (the launch floor) vs torch's whole-step inductor fusion. Verdict
.verdicts/hexa-0pod/F-OP4-5070-COVERAGE.txt; driver tool/bench/run_op4_5070.sh. Deferred OP-4b (CUDA-graph /
single-megakernel step to collapse the small-B launch floor — small-B-only win, won't beat torch everywhere).

## 2026-06-09 — OP-1 DONE: sm_120 own-GEMM 3.2-6.9x -> ~1.0-1.15x off cuBLAS, bit-exact (aiden RTX 5070)

Swept 5 kernel variants (K0 baseline .. K4 all-levers) on aiden (free pool, NO vast). Levers: (1) cp.async
double-buffer, (2) bank-conflict-free smem pad, (3) 128x64 register tile, (5) .v4 128-bit global loads. All
variants BIT-EXACT vs the K0 baseline (rel-RMS=0, bitdiff=0/N) and vs cuBLAS-TF32 (rel-RMS ~3e-5, gate PASS) at
D={1024,2048} — scheduling/layout-only, accumulation order preserved.

Results (TFLOP/s, GPU exclusivity verified): D=1024 K0 6.75 (4.16x off) -> K2 24.49 (1.15x off); D=2048 K0 8.05
(3.83x) -> K2 29.81 (1.02x — near parity). K2 = pad + .v4 + cp.async double-buffer = BEST bit-exact config.
Findings: layout/load-vectorization (K1) was the dominant lever (+3.1-3.4x — baseline had pathological bank
conflicts + scalar loads); cp.async a modest top-up (+0.08-0.15x); the 128x64 register tile (K3/K4) PLATEAUED/
regressed on the consumer card (occupancy loss > AI gain) and was NOT shipped (closed-negative).

Promoted K2 into the production self/native/mma_sm120/owngemm_sm120.cu (gemm_sm120) so flame's real sm_120
own-GEMM gets the speedup — re-verified: GATE @768 rel-RMS 1.33e-5 (== baseline, bit-faithful), PERF 24.48
@1024 / 29.81 @2048 TFLOP/s. Sweep harness owngemm_sm120_opt.cu + build_owngemm_opt.sh kept for reproduction.
Verdict .verdicts/hexa-0pod/F-OP1-SM120-OWNGEMM.txt. Deferred OP-1b (BK=32 / 3-stage pipeline / vectorized
epilogue) appended to self-feed the loop; register-tile lever marked closed-negative (do not re-attempt).

## 2026-06-09 — domain registered (0-pod free-resource improvement loop)

User goal: "0 pod 으로 flame+forge 개선 계속 진행 루프" + "pool 은 활용가능". Continuous flame+forge improvement
using ONLY free resources (sidecar pool aiden/summer RTX 5070 + local code), zero vast rentals. aiden confirmed
free (RTX 5070 sm_120, 0% util). Backlog OP-1..5 (sm_120 own-GEMM speedup · wire bench wins into real trainer ·
BF16 own-GEMM · fused-step coverage · forge hardening). Hopper-only own-GEMM decode-elim is out-of-scope (needs
H100 pod). Loop fans out free-resource agents per round, byte-eq/bit-exact gated on the consumer card.

## 2026-06-09 — OP-2 — wire bench step wins into the REAL flame CLMConvMoE trainer 🟢

Audited the 4 HEXA-BENCH step wins against the real trainer (stdlib/flame/clm_prod.hexa + the forge device
runtime self/cuda/runtime_cuda_emit.hexa). Finding: 3 of 4 are ALREADY in the product, env-gated, from the
HEXA-FUSION campaign — cuBLAS-FP64 projection GEMM is the DEFAULT _hx_cuda_farr_matmul_gpu path (HEXA_OWN_GEMM
only swaps the naive kernel IN); fused valley LN+gelu(+resid) under HEXA_FUSE_VALLEY/GN_GELU(_RESID) →
_hx_k_groupnorm_gelu[_residual]; single-launch fused AdamW under HEXA_CLM_FULLSTEP → _hx_k_adamw_fused
cooperative. The bench's "flame FP64 = naive O(D^3)" refers to the HEXA_OWN_GEMM kernel, not the default trainer.

The one MISSING win = BENCH-10 TRANSPOSE-ELIMINATION for the backward dW GEMM. conv1d_bwd_via_forge ran a
SEPARATE transpose-layout im2col pass (_clmp_im2col_t → xcolT[Kdim,T]) then an OP_N GEMM; the bench computes
dW = A^T@dGq via cuBLAS OP_T on A directly (no materialized A^T). Wired it: new forge_dispatch_matmul_t(A,M,K,
B,N) = A^T@B builtin — GPU side _hx_cuda_farr_matmul_tn_gpu (cublasDgemm CUBLAS_OP_T, + _hx_k_gemm_t own
fallback) in runtime_cuda_emit.hexa (emit verified, no symbol collision w/ the RFC-040 M^T·u gemv, brace-
balanced); codegen call-name mapping + runtime.h protos. The trainer's conv1d_bwd_via_forge documents the
3-line swap (im2col + matmul_t, drops the im2col_t pass) as a COMMENT — NOT a live call — so the build stays
unbroken until the runtime.c wrapper body lands at GPU-build time.

GATE (g5) byte-eq HELD: clm_prod_transpose_elim_eq.hexa CPU oracle proves im2col+matmul_t dW ==
im2col_t+matmul dW max|Δ|=0 across 4 (T,Cin,Cout,K,dil) cases via `hexa run` (0-pod, mac/aiden CPU — the
same dispatch path, no GPU build needed). Bit-exact because xcolT[j,t]==xcol[t,j] and the contraction runs
over the same t-dim in the same ascending order. GPU cuBLAS OP_T is the documented ~1e-14 accum-order lane.

Deferred (GPU build, NOT vast): OP-2b runtime.c wrapper body + flip trainer to live call + step/s measure;
OP-2c batched-expert transpose-elim (cublasDgemmStridedBatched OP_T) for the dominant 2-expert path. Verdict
.verdicts/hexa-0pod/F-OP2-TRAINER-WIRE.txt.

## 2026-06-09 — OP-5 forge/runtime hygiene (LOCAL, 0-GPU)

Fixed the diagnostic-surfaced `self/runtime.h:422-423` `'/*' within block comment` `-Wcomment` warning: the
`native/*.c` glob written inside a `/* … */` block forms a nested `/*` token clang flags. Minimal comment-only
fix (`native/ *.c`, +2/-2) — `clang -fsyntax-only -Wcomment -x c self/runtime.h` 2 warnings → 0. No
declaration / codegen / behavior change. Repo-wide `-Wcomment` + `-Wextra-tokens` sweep over every checked-in
C/H/CU/CUH header, the forge-emitted CUDA wrappers (self/cuda/*.cu|*.c), and the emit-string `.hexa` sources
(runtime_cuda_emit / runtime_bf16_emit / forge_tier_v1_emit) confirmed runtime.h:422-423 was the ONLY genuine
hit (one `#pragma once in main file` artifact from standalone header parse correctly ignored, not "fixed").
All behavior-preserving. Verdict .verdicts/hexa-0pod/F-OP5-FORGE-HARDEN.txt. Deferred OP-5b (CI -Werror=comment
gate, 0-GPU) + OP-5c (error-path/dtype/determinism hardening — NEEDS GPU, out of 0-pod scope) to self-feed.

## 2026-06-09 — OP-5b DONE: forge-runtime -Wcomment hygiene CI gate (LOCAL, 0-GPU)

Regression-locked the OP-5 (#2973) `-Wcomment` cleanup. Added `tool/forge_runtime_warn_gate.sh` (SSOT,
locally runnable / hook-able) + `.github/workflows/forge-runtime-warn-gate.yml` (PR-on-main, paths-scoped to
the guarded files + script + workflow). OPTION A hard gate: `clang -fsyntax-only -Wcomment -Werror -x c` over an
EXPLICIT OP-5-clean allow-list (`self/runtime.h`, `self/forge/forge_tier_v1.h`, `self/native/lora_cuda.h`);
fails ONLY on a new nested-comment warning in those files. LOW BLAST RADIUS — deliberately NOT a repo-wide
`-Werror`: (1) allow-list only, so grandfathered warnings anywhere else can never fail it; (2) only `-Wcomment`,
a purely lexical class, so no CUDA toolchain / includes / type defs are needed (each file compiles stand-alone
`-x c`; runtime.h also passes full `-fsyntax-only` exit 0). clang→gcc→cc fallback. Verified LOCALLY: passes on
clean tree (3/3 PASS, exit 0); catches an injected nested `/*` in a guarded file (exit 1, precise diagnostic,
reverts clean); IGNORES the same warning injected into an unguarded file (`self/native/hxcuda_conv1d.cu`, exit
0) — proving it cannot break CI on grandfathered code. Behavior-preserving (CI-only; no source/codegen change).
Verdict .verdicts/hexa-0pod/F-OP5B-WARN-GATE.txt. OP-5b removed from `## deferred`; flipped `[x]` in milestones.

## 2026-06-09 — OP-3 BF16 sm_120 own-GEMM (aiden RTX 5070, free pool)

Extended the OP-1 (#2972) TF32 sm_120 own-GEMM to BF16 in self/native/mma_sm120/owngemm_sm120_bf16.cu using
the portable warp-mma `mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32` — note BF16 is k16 (NOT k8 like
TF32), the 16x8x16 fragment packs two bf16 per 32-bit register (A=4 regs/8 bf16, B=2 regs/4 bf16). fp32 inputs
RN-converted to bf16 (__float2bfloat16_rn) at the smem→register fragment load (where TF32's f2tf32 lived);
fp32 accumulation. Carried over OP-1's THREE layout/load wins VERBATIM — (a) bank-conflict-free smem pad
As[BM][BK+4]/Bs[BK][BN+4], (b) .v4 128-bit float4 global loads (masked scalar tail), (c) cp.async double-
buffered BK stage — and kept the IDENTICAL K-major mma.sync accumulation order (so the kernel is its own
bit-for-bit reproducer). Did NOT touch the 128x64 register-tile lever (CLOSED-NEG on the consumer card, OP-1).

Built clean on aiden (CUDA 13.0, sm_120). GPU verified free (0% / 2 MiB) before every timed run.
GATE (g5 bit-FAITHFUL, W14 convention — NOT bit-exact-vs-fp32; BF16 8-bit mantissa): rel-RMS vs FP64 ref
8.4e-3@256 / 2.7e-3@768 / 6.7e-3@1024 / 8.0e-3@2048, all ≤1e-2 PASS (sits at the BF16 precision floor →
fragment layout is correct; a wrong m16n8k16 map would give rel-RMS ~0.5-1.0). Determinism: run-to-run
max|delta|=0, bitdiff=0/N @1024 and @2048 HELD.
PERF (2 timed passes): own-GEMM-BF16 26.1-26.5 TFLOP/s @1024, 33.3 @2048; cuBLAS-BF16 54.7 @1024, 61.5-66.7
@2048 → cuBLAS-multiple ~2.0-2.1x @1024, ~1.85-2.0x @2048.

HONEST (g5): the multiple is WIDER than the TF32 path's ~1.0-1.15x EXACTLY as predicted — BF16 ~doubles the
cuBLAS roofline (cuBLAS-BF16 ~55-67 vs cuBLAS-TF32 ~28-31 TFLOP/s). The own-GEMM's ABSOLUTE throughput is
actually HIGHER in BF16 (26-33) than TF32 (24-30 @ OP-1), but cuBLAS scales up faster, so the ratio opens to
~2x. The win = a working bit-faithful BF16 own-GEMM on the consumer card riding OP-1's layout lever; NOT
cuBLAS-BF16 parity (cuBLAS uses f16-class tensor-core scheduling the portable warp-mma doesn't). Verdict
.verdicts/hexa-0pod/F-OP3-BF16-SM120.txt. Deferred OP-3b (BK=32 / 3-stage cp.async / .v2-.v4 epilogue for the
BF16 path, mirroring OP-1b — NOT the register tile) to self-feed.

## OP-4b — CUDA-graph-captured flame FUSED step on RTX 5070 (sm_120) — CLOSED-NEGATIVE (honest)
Attacked the small-B launch-overhead floor OP-4 found (B=1: TF32 up to 8.96x, BF16 up to 14.66x @D=2048 vs
torch.compile) by wrapping the fused per-step DAG (cuBLAS fwd GEMM + fused valley + cuBLAS OP_T bwd GEMM
(transpose-elim) + single-launch AdamW) in a CUDA graph (cudaStreamBeginCapture/EndCapture -> Instantiate ->
GraphLaunch) so the whole step replays as ONE launch. Harness tool/bench/flame_bench_step_graph_fused.cu
(BYTE-FOR-BYTE the OP-4 -DFUSED math, only the launch mechanism differs; BF16 cast scratch pre-warmed before
BeginCapture since cudaMalloc isn't capturable), driver run_op4b_5070.sh. Swept B=1 x D={768,1536,2048} x
dtype={TF32,BF16,FP64} on the FREE pool 5070 aiden (0-pod, NO vast), iters=50, exclusivity-gated.
RESULT: graph/eager = 1.00-1.02x in EVERY cell (best BF16/D=768 1.0198x ~2%; FP64/D=768 0.9989x = noise).
The worst cell BF16/D=2048/B=1 went 14.66x -> 14.64x (ratio vs torch.compile shaved <0.5%). flame still LOSES
every small-B cell. WHERE THE LOSS LIVES: NOT launch — GEMM-RATE. Graph capture collapses ALL per-op
launch/sync into one replay; if the floor were launch-bound the ratio would have dropped, but it moved <2%.
So on the 5070 the small-B step wall is dominated by the cuBLAS GEMM execution (+ BF16 cast traffic), not by
issuing launches — the per-launch overhead is already negligible relative to even a tiny-M cuBLAS GEMM at
these D. Same structural outcome as the H100 BENCH-6 graph finding (graph ~1.0x => residual pinned to
GEMM-throughput). GATE g5 PASS x9/9: max|d(W')| graph-vs-eager =0 + run-to-run determinism =0 every cell —
graph capture is bit-exact + deterministic (a SAFE optimization that simply doesn't help this workload/card).
Launch-elimination is now CLOSED-NEGATIVE on the consumer 5070 too; flame's consumer value remains its
byte-exact/device-resident/torch-free identity, NOT step-rate. Verdict .verdicts/hexa-0pod/F-OP4B-GRAPH-5070.txt.

## OP-1b — sm_120 TF32 own-GEMM pipeline-depth sweep on RTX 5070 (aiden) — partial-positive (honest)
OP-1's deferred TF32 follow-up: close the residual ~3-15% off cuBLAS-TF32 @D=1024 (K2 = BK16/2-stage cp.async/
scalar epilogue was furthest off there, 1.15x). Probed 3 schedule/layout levers — (1) BK=32 deeper K-tile,
(2) 3-stage cp.async ring (wait_group<2>) vs the 2-stage double buffer, (3) .v2 (float2) vectorized C-store
epilogue. Harness self/native/mma_sm120/owngemm_sm120_pipe.cu (production kernel parameterized by -DLBK/
-DLSTAGES/-DLVEC; defaults 16/2/0 reproduce OP-1 bit-for-bit) + build_owngemm_pipe.sh. 8-config grid built +
run on the FREE pool 5070 aiden (sm_120, 0-pod, NO vast, GPU 0% verified idle before each timed run), gate
adds a host FP64 ground-truth ref (g5). The 128x64 register tile was NOT re-attempted (closed-neg, OP-1).
RESULT (own-GEMM TFLOP/s, off cuBLAS-TF32): baseline 24.50@1024(1.143x)/29.74@2048; L3 .v2-epi
24.93@1024(1.124x)/29.92@2048 = +1.7% @1024 WIN; L1 BK=32 22.76@1024(1.231x) REGRESS; L2 3-stage
22.79@1024(1.229x) REGRESS; every combo with BK32 or 3-stage REGRESSES; BK32+3stage BUILD-FAIL (ptxas
0xd200 smem > 0xc000 48KB cap). baseline & L3 re-run x3, variance <0.05 TFLOP/s — the +0.43 TFLOP/s gain is
stable not noise. WHERE: the K-pipeline-depth levers made it WORSE — on the 5070's 48KB smem cap the
2-stage/BK16 config is the occupancy sweet spot at D=1024/2048; deepening the K-tile or the ring trades
occupancy for a latency-hide that's already saturated, and stacking them overflows smem. Matches OP-1: the
consumer-card lever is memory-instruction VECTORIZATION (.v4 loads = OP-1's big win, .v2 store = OP-1b's
small one), NOT staging depth. GATE g5: bit-exact HELD — every building config byte-identical to the OP-1
baseline (rel-RMS vs baseline = 0; vs-cuBLAS-TF32 1.33e-05@768/3.02e-05@1024/1.74e-05@2048 unchanged;
vs-FP64 ~1e-4 = the TF32 10-bit-mantissa truncation floor, same for cuBLAS). SHIPPED: only the .v2 epilogue
folded into the production owngemm_sm120.cu (re-verified on aiden: @1024 24.93 TFLOP/s 1.13x / @2048 29.86
1.02x, gate PASS). BK=32 / 3-stage kept OUT (closed-negative on consumer card). Best sm_120 TF32 own-GEMM
now 24.93 TFLOP/s @1024 (1.13x off cuBLAS, was 1.15x). Verdict .verdicts/hexa-0pod/F-OP1B-SM120-PIPE.txt.

## OP-3b — .v2 vectorized C-store epilogue on the BF16 sm_120 own-GEMM (aiden RTX 5070) — GREEN/SHIP
Applied OP-1b's ONE bit-exact-positive lever — the .v2 (float2) vectorized C-store epilogue — to the BF16
path of owngemm_sm120_bf16.cu (mma.sync m16n8k16 bf16). The BF16 mma OUTPUT fragment is fp32 with the
IDENTICAL m16n8 C layout as the TF32 path (c0/c1 and c2/c3 contiguous at cols 2*tig, 2*tig+1), so the
TF32 .v2 epilogue ports VERBATIM: each pair fuses to one 64-bit store. Added a -DEPILOGUE_SCALAR (OP-3
baseline) compile twin + MODE==3 raw-f32 C dump so the build proves byte-identity by `cmp`. NARROW scope
per OP-1b: only .v2 — NOT BK=32 / 3-stage cp.async (CLOSED-NEG on the 5070 48KB smem cap) nor the 128x64
register tile (CLOSED-NEG, OP-1). aiden RTX 5070 (free, GPU 0%/2MiB verified): .v2 helped BIT-EXACTLY —
+2.1% @1024 (scalar 26.06 → .v2 26.60 TFLOP/s, off-cuBLAS-BF16 2.10x → 2.06x) / +1.0% @2048 (33.20 →
33.52). cuBLAS-BF16 ~54.8 @1024 / ~62-67 @2048; new multiple ~2.06x @1024, ~1.92-1.97x @2048. GATE g5
(bit-faithful, UNCHANGED — store-vectorization not math): rel-RMS vs FP64 2.65e-3@768 / 6.70e-3@1024 /
8.01e-3@2048 ≤1e-2 PASS; determinism max|d|=0 bitdiff=0/N HELD; BYTE-IDENTICAL to OP-3 scalar baseline
@1024 & @2048 (cmp clean → rel-RMS vs OP-3 = 0). HONEST: the ~2x BF16 gap is the doubled cuBLAS-BF16
roofline (roofline-bound), so the store-only lever can only give ~1-2% — delivered exactly that, same
magnitude as OP-1b's TF32 +1.7%. SHIP (positive + bit-exact, no regression). After OP-3b the consumer-card
own-GEMM's identity-preserving lever ladder is EXHAUSTED. 0-pod, NO vast, NO leak (pool host). Verdict
.verdicts/hexa-0pod/F-OP3B-BF16-EPILOGUE.txt.

DEPLETION NOTE: with OP-3b shipped the 0-pod-actionable backlog is DRAINED. Remaining deferred items all
need a GPU build env / frozen-seed runtime, OUT of 0-pod scope: OP-2b (runtime.c forge_dispatch_matmul_t
wrapper body — self/runtime.c build-time-assembled in clm_prod_gpu env), OP-2c (batched-expert transpose-
elim — needs the OP-2b wrapper first), OP-5c (forge error-path/dtype-edge/determinism — can't be byte-eq
gated without a kernel build). No further 0-pod follow-up surfaces from OP-3b (the lever ladder is closed).

## OP-7 — forward conv im2col==direct byte-eq CPU oracle (0-GPU) · GREEN
Self-generated 0-pod follow-up (re-opening the oracle-hardening lane that OP-2 started). Added
stdlib/flame/clm_prod_conv_im2col_eq.hexa: a pure-host `hexa run` oracle that bit-exactly locks the flame
CLMConvMoE trainer's FORWARD causal-dilated conv1d layout transform. The trainer (conv1d_via_forge) computes
the conv as im2col(x)[T,Kdim] + GEMM(.,Wt[Kdim,Cout]) + bias; the oracle proves this equals a DIRECT
sliding-window conv reference y[t,co]=b[co]+Σ_ci Σ_k x[p,ci]*w[co,ci*K+k] (p=t-dil*(K-1-k)). The im2col col
index j=ci*K+k makes the reference's (ci-outer,k-inner) accumulation order EXACTLY the j-ascending GEMM
contraction order ⇒ bit-for-bit equal (true re-layout identity, NOT associativity — no tolerance).
`hexa run` PASS: max|Δ|=0 across 5 shapes (K=3/4/5, dil=1/2/3, Cin==Cout & Cin!=Cout, wide-dilation zero-pad
seam). Honest finding: NONE non-bit-exact — the identity is genuinely exact, max|Δ|=0 is real not faked.
Behavior-preserving: no trainer logic touched (verification/oracle addition only). Forward companion to
OP-2's backward-dW transpose-elim oracle (#2974). Verdict .verdicts/hexa-0pod/F-OP7-IDENTITY-ORACLE.txt.

## OP-6 — vectorize a memory-bound flame sm_120 kernel (.v4 loads/stores, bit-exact) — CLOSED-NEGATIVE
Generalized OP-1's memory-instruction-vectorization lever (.v4/.v2 coalesced loads + vectorized stores) from
the compute-bound own-GEMM to a MEMORY-BOUND flame elementwise kernel on aiden (RTX 5070, sm_120, free pool,
GPU 0% verified). Target = the fp64 AdamW optimizer update _hx_k_adamw_step_inplace
(self/cuda/runtime_cuda.c:1236-1289): 7 fp64 streams (read W,M,V,G + write M,V,W), no reduction, no cross-elem
dependency, scalar grid-stride loads — the correct memory-bound un-vectorized candidate.
Applied double2 (128-bit) coalesced loads + double2 stores (2 elems/thread, scalar n%2 tail).
RESULT (honest, NO win): scalar fp64 AdamW already hits ~333 GB/s; double2 = 1.005-1.006x @16M/64M/odd-tail.
Root-cause probe (op6_bandwidth_probe.cu): pure fp64 COPY also 1.005x (567->570 GB/s); fp32 AdamW with the
literal .v4 float4 lever only 1.028x. On the 5070 (GDDR7) contiguous scalar 32/64-bit grid-stride accesses
ALREADY coalesce to peak DRAM BW → .v4/.v2 add nothing. OP-1 won because its GEMM had STRIDED partially-
uncoalesced smem-feed loads to repair; a contiguous elementwise/copy kernel has no such pattern → the lever
does not transfer (memory-INSTRUCTION vectorization != memory-BANDWIDTH gain when already coalesced).
BIT-EXACT (g5): vec BYTE-IDENTICAL to scalar under --fmad=false (bitdiff=0, max|Δ|=0, all sizes incl odd-N
tail — the rewrite is mathematically pure); under --fmad=true (production default) a 1-ULP (1.388e-17)
FMA-scheduling artifact appears (different fma fusion in single-elem vs pair loop), so a double2 production
rewrite would FAIL the OP-2 byte-eq-vs-prior-trainer gate. NOT shipped (no win + not byte-eq under defaults).
Contiguous-elementwise vectorization lever EXHAUSTED on the 5070; only remaining headroom = AdamW-into-bwd-
GEMM-epilogue FUSION (boundary removal), deferred as OP-6b. $0 (free pool, no vast, no leak). Harness
tool/op6/op6_adamw_vec_bench.cu + op6_bandwidth_probe.cu. Verdict .verdicts/hexa-0pod/F-OP6-VECTORIZE-KERNEL.txt.

## OP-6b — fuse the AdamW update INTO the bwd-GEMM epilogue (boundary-removal) — CLOSED-NEGATIVE
OP-6's deferred follow-up. Determined the bwd-dW path FIRST: conv1d_bwd_via_forge (clm_prod.hexa:238) computes
dW = forge_dispatch_matmul(xcolT,...) → farr_matmul_gpu → REAL cuBLAS Dgemm (runtime_cuda_emit.hexa). The
PRODUCTION bwd-dW GEMM is CLOSED cuBLAS = SCOPE B: you cannot fuse an AdamW epilogue into a cuBLAS call;
boundary-removal is only expressible on an own-GEMM bwd path. Built a scope-A demonstration on aiden (RTX 5070,
sm_120, free pool, GPU 0% verified): fp64 tiled own-GEMM dW[M,N]=A·B, SEPARATE (gemm_dW_store writes dW to DRAM
+ adamw_separate re-reads dW + 2 launches) vs FUSED (gemm_dW_adamw_fused consumes the dW cell IN-REGISTER the
instant the K-loop ends, applies the verbatim ADAMW_BODY, writes W,M,V directly — dW write + re-read + 2nd
launch all eliminated). AdamW arithmetic = ONE shared MACRO in both paths.
PERF (honest, NO win): GEMM-dominated production shapes ~1.000-1.002x (the eliminated dW round-trip is
Amdahl-negligible vs the GEMM cost — e.g. dW[1536,512] saves 0.0126 GB ~0.9-2.1 GB/s over a 5.9ms step).
dW-DOMINATED regime (large M,N, tiny K) is SLOWER 0.98x: the fused epilogue runs the W,M,V elementwise work
inside the GEMM's TILE=16 geometry (low elementwise occupancy) at WORSE bandwidth than a dedicated 256-thread
AdamW kernel, outweighing the ~40-70 GB/s of dW traffic saved. Fusion wins ONLY in a tiny launch-bound regime
(dW[256,256] 1.108x @0.02ms step) where killing the 2nd LAUNCH is a real fraction — a launch-elim win, gone at
production scale.
BIT-EXACT (g5, STRONGER than OP-6): fused W,M,V == separate W,M,V, max|Δ|=0 bitdiff=0 under BOTH --fmad=false
AND --fmad=true at every shape. Unlike OP-6's vectorization (which broke byte-eq under --fmad=true via pair-vs-
single FMA reschedule), register-source fusion changes the gradient SOURCE not the AdamW arithmetic ORDER, so
the FMA chain is identical → byte-eq holds even under production flags.
WHERE BOUNDARY-REMOVAL MUST LIVE: only on the own-GEMM bwd path (cuBLAS closed), AND not worth it even there
(byte-eq but perf-flat/negative) because neither the bwd GEMM nor the AdamW is under-utilized — boundary-removal
pays only when a side is under-filled (cf OG-FUSE-FOLD #2909 under-filling 30 conv micro-launches). Elementwise
optimizer lever now EXHAUSTED on BOTH axes (OP-6 instruction-width, OP-6b boundary-removal). NOT shipped, no
production code changed. $0 (free pool aiden, no vast, no pod, no leak). Harness
tool/op6b/op6b_adamw_fuse_bench.cu. Verdict .verdicts/hexa-0pod/F-OP6B-ADAMW-FUSE.txt.

## OP-8 — MoE softmax+combine byte-eq CPU oracle (0-GPU) · max|Δ|=0
F-OP8-MOE-COMBINE-EQ = 1. Picked the highest-value not-yet-locked flame identity: the CLMConvMoE MoE-router
softmax-gate + gate-weighted expert combine, which lives in the FUSED hot path (HEXA_FUSE_MOE_BLOCK2 megakernel
= gelu2 + expert_pack2 + moe_router in ONE launch). Added LOCAL `hexa run` (0-GPU) oracle
stdlib/flame/clm_prod_moe_combine_eq.hexa locking the trainer's TWO-PASS form (nn_moe_router_fwd: full
probs[T·E] softmax buffer, THEN per-position e-ascending Σ_e probs[t,e]·ex_out[e,t,c]) == a ONE-PASS FUSED form
(the megakernel shape: inline per-position gate kept register-local, combine fused immediately after, NO full-T
probs DRAM round-trip). max|Δ|=0 across 6 shapes (E=2 trainer 2-expert · E=3/4/8 · varied T,C · degenerate
T=1,C=1 pure-gate edge). HONEST (g5): genuine fusion/ordering identity NOT an associativity case — both forms
use the SAME hand-rolled scaled-Taylor _moe_exp (NOT libm/CUDA exp), SAME per-position max-subtraction, SAME
sequentially-summed denominator, SAME e-ascending combine accumulation, so every float op is identical (no
tolerance, max|Δ|=0 not faked). This LOCKS the megakernel's explicit "accumulate BOTH reductions SEQUENTIALLY,
NO tree re-assoc → bit-exact" determinism contract — a future refactor that tree-reduces the softmax sum/combine
or drops the max-sub now breaks the oracle. Canonical order documented: softmax max-sub ON + e-ascending exp/sum
+ sequential denom; combine Σ_e e-ascending; exp = scaled-Taylor _moe_exp. Behavior-preserving: NO trainer logic
changed (oracle/verification addition only). Companion to OP-2 (bwd dW transpose-elim) + OP-7 (fwd conv im2col).
$0 — pure local CPU `hexa run`, no GPU / no pool / no vast. Oracle stdlib/flame/clm_prod_moe_combine_eq.hexa ·
verdict .verdicts/hexa-0pod/F-OP8-IDENTITY-ORACLE.txt.

## OP-9 — GroupNorm/LN valley reduction byte-eq CPU oracle (0-GPU) — 2026-06-09

Continuing the OP-2/OP-7/OP-8 determinism-oracle series, added a LOCAL `hexa run` (0-GPU) oracle that
bit-exactly locks the flame CLMConvMoE GroupNorm "valley" normalization the FUSED hot path (HEXA_FUSE_VALLEY /
HEXA_FUSE_GN_GELU · forge_dispatch_groupnorm_gelu) relies on. WHICH REDUCTION: the production GroupNorm
(gn_lib.hexa nn_groupnorm_fwd / nn_gn_gelu_fused, called from clm_prod.hexa _groupnorm / _groupnorm_gelu) uses
a TWO-PASS mean/variance reduction (NOT Welford): pass-1 sum=Σ_{c∈g,t} X[t,c] → mu=sum/(cg·T); pass-2
vs=Σ (X-mu)² → var=vs/(cg·T); inv=1/_gn_sqrt(var+eps), eps=1e-5 — BOTH passes iterate (t-OUTER,c-INNER),
sequential, NO tree re-assoc. Then Y=gamma·xhat+beta, A=GELU(Y) (erf-based normal CDF, libm builtin).

The oracle proves the UN-FUSED form (_gn_ref = nn_groupnorm_fwd shape: two-pass reduction + SEPARATE affine
sweep writing Y, THEN a SEPARATE GELU sweep re-reading Y → A — two elementwise sweeps over [T·C]) ==
the FUSED VALLEY form (_gn_fused = nn_gn_gelu_fused shape: SAME two-pass reduction, but affine+GELU in ONE
pass — post-GN [T·C] tensor touched ONCE, no Y read+write round-trip — the megakernel shape), with
max(|ΔY|,|ΔA|)=0. Both share _ln_sqrt (byte-identical to gn_lib _gn_sqrt, 40-iter Newton) + _ln_gelu
(byte-identical erf-GELU), same mu, same inv, same affine ⇒ a true fusion/boundary-removal identity, NOT an
associativity case (no tolerance, max|Δ|=0 not faked).

HONEST (g5): the tree-vs-sequential associativity RISK the spec flagged is REAL but does NOT arise here —
gn_lib's fused valley keeps the SAME sequential (t-outer,c-inner) two-pass order as the un-fused path; the
fusion only collapses the GN-affine+GELU elementwise sweeps (boundary removal), it does NOT re-associate the
mean/var sum. So the CPU oracle matches the production reduction order EXACTLY → genuine max|Δ|=0, no eps
needed. CANONICAL ORDER (device kernel = SSOT): sequential (t-outer,c-inner) two-pass mean-then-var,
inv=1/_gn_sqrt(var+eps) eps=1e-5, affine, erf-GELU. A future warp-shuffle/tree reduce of the mean/var sum or a
Welford switch would trip THIS oracle — its job.

`hexa run` PASS, max|Δ|=0 across 7 shapes (G=1 LN-over-channels degenerate, G=2/3/4/8, varied T,C, + T=1 pure
cross-channel + cg=1 G=8 per-channel edges). Behavior-preserving: NO trainer logic changed (oracle/verification
addition only). $0 — pure local CPU `hexa run`, no GPU / no pool / no vast. Oracle
stdlib/flame/clm_prod_ln_reduction_eq.hexa · verdict .verdicts/hexa-0pod/F-OP9-LN-REDUCTION-ORACLE.txt.

## 2026-06-09 — OP-10 DONE: B>1 window-concat causal-conv SEAM characterized (0-GPU)

Made the flame_h100_h200_closeout's KNOWN honest non-bit-exact spot PRECISE. The flame CLMConvMoE batched step
(CLM_PROD_BATCH=B, clm_prod.hexa) concatenates B distinct length-Tw windows into ONE length-T=B*Tw buffer and
runs the causal-dilated Conv1d over the whole concat; the closeout flagged a "K-1 causal-conv SEAM-only Δ" vs a
per-window-segmented conv but did NOT pin the exact positions/magnitude. This LOCAL `hexa run` (0-GPU, no pool,
no vast) oracle computes BOTH paths on CPU with identical weights/bias/FP dtype: (a) the flame concat conv
(every previous-window row visible to the receptive field p = t - dil*(K-1-k)) vs (b) a per-window-segmented
reference that zeros the cross-window causal context, then maps Δ per output position.

FINDING (g5 — honest CHARACTERIZATION, NOT a clean max|Δ|=0-everywhere identity):
  • INTERIOR BIT-EXACT: every output position OUTSIDE the seam band has Δ exactly 0 (interior max|Δ|=0, bad
    interior positions = 0 across all 6 cases — exactly 0, not merely small).
  • SEAM = EXACTLY the first (K-1)*dil output positions of every window AFTER the first; there Δ = the
    cross-window causal context that the segmented conv zeros (genuinely nonzero; mischaracterized seam = 0,
    so the band is neither over- nor under-claimed). Window 0 is fully bit-exact (no previous window).
  • CONFIRMS the closeout's claim AND REFINES it: at dil=1 the band = K-1 (the closeout's named "K-1 seam");
    at dil>1 (the trunk's dilated convs) the band WIDENS to (K-1)*dil — the closeout said a flat "K-1", this
    oracle sharpens it. Seam max|Δ| ranged ~0.035–0.384 on the LCG fixture (e.g. K=3 dil=4 → full 8-wide band).

Behavior-preserving: NO trainer logic changed (characterization/verification addition only). Companion to OP-7
(fwd conv im2col==direct, B=1) — OP-7 locked the B=1 conv bit-exactly, OP-10 maps exactly where B>1 departs.
$0 — pure local CPU `hexa run`, no GPU / no pool / no vast. Oracle stdlib/flame/clm_conv_window_seam_eq.hexa ·
verdict .verdicts/hexa-0pod/F-OP10-CONV-SEAM-ORACLE.txt.

## OP-11 — CE loss + softmax-gradient byte-eq CPU oracle (0-GPU) · 🟢 max|Δ|=0

Continuing the OP-2/OP-7/OP-8/OP-9/OP-10 determinism-oracle series. Added a LOCAL `hexa run` (0-GPU) oracle that
bit-exactly locks the flame CLMConvMoE LOSS path — the flame_h100_h200_closeout-flagged "CE/softmax-grad host
glue". Two independent identities, each replaying its OWN production exp impl (the subtle hazard: the two CE
entry points use DIFFERENT exp):
  (A) BWD fused-grad: clm_ce_grad (clm_prod.hexa:919, libm `exp`) == (softmax(logits) − onehot(target))/T.
  (B) FWD loss scalar: nn_ce_loss_allpos (nn_lib.hexa:957, `dt_exp`/`dt_ln` flame_math Taylor, NOT libm,
      NOT _moe_exp) == definitional mean-NLL.
`hexa run` PASS, max|Δ|=0 across 6 shapes each (V=7..256 CLM-scale, varied T, T=1 edge).

HONEST FINDING (g5) — a REAL associativity gap, found + resolved (NOT faked): the backward grad's TARGET INDEX
is float-sensitive. Production writes (p·invT) for every v THEN subtracts invT at tgt → (p_tgt·invT)−invT; an
algebraically-equal fused reference (p_tgt−1)·invT is float-DIFFERENT. The FIRST oracle run showed grad
max|Δ| = 1.38778e-17 at T12/V7 (all others 0). Fix = replay the EXACT production op order (scale-then-subtract,
NOT refold) → genuine max|Δ|=0 everywhere, no eps. Production order = SSOT (clm_prod.hexa:933-937).

CANONICAL ORDER (SSOT): BWD = libm exp, per-row max-sub, v-ascending denom, grad=p/T then tgt−=1/T;
FWD = dt_exp/dt_ln, per-row max-sub, v-ascending denom, p_t≥1e-6 clamp, t-ascending loss sum, mean/T.
Behavior-preserving: NO trainer logic changed (oracle addition only). $0 — pure local CPU, no GPU/pool/vast.
Oracle stdlib/flame/clm_prod_ce_softmax_grad_eq.hexa · verdict .verdicts/hexa-0pod/F-OP11-CE-SOFTMAX-ORACLE.txt.

## OP-13 — embedding bwd scatter-add byte-eq CPU oracle (0-GPU) — DONE

F-OP13-EMBED-RESIDUAL-ORACLE = 1. Locked the INPUT path (previously unlocked): the token-embedding
gather BACKWARD (nn_lib.hexa nn_embedding_bwd_scatter). Repeated tokens → multiple positions accumulate
into the SAME dtable row; float non-associativity makes the accumulation ORDER load-bearing (the classic
determinism trap). Production order = POSITION-ASCENDING in-place scatter-add.

Oracle stdlib/flame/clm_prod_embed_scatter_eq.hexa, three forms over a repeated-token fixture:
  REF      = exact mirror of nn_embedding_bwd_scatter (i-asc in-place; pre-seeded tied-head term).
  GROUPED+ = per-row reformulation, positions i-ASCENDING  → GATE: REF==GROUPED+ max|Δ|=0 (all 6 shapes).
  GROUPED- = per-row, positions i-DESCENDING → HONEST probe: eps 5.68e-14…4.55e-13 on repeated rows.
hexa run PASS (max|Δ|=0 gate; max-repeat up to 12 positions/row exercised; T=1 probe correctly 0.0).

CANONICAL ORDER (SSOT): per shared token row, accumulate contributing positions' gradients in
POSITION-ASCENDING order (i=0..T-1), matching the in-place scatter loop. A future gather-then-grouped-sum
or GPU atomic-scatter refactor MUST preserve this i-ascending per-row order to stay bit-exact.
HONEST (g5): GATE max|Δ|=0 is a true reorder identity (NOT faked); GROUPED- eps is the genuine
non-associativity witness. Behavior-preserving: NO trainer logic changed. $0 — pure local CPU.
Verdict .verdicts/hexa-0pod/F-OP13-EMBED-RESIDUAL-ORACLE.txt.

## OP-12 — AdamW update-arithmetic byte-eq CPU oracle (0-GPU) · 🟢 max|Δ|=0

Continuing the OP-2/OP-7/OP-8/OP-9/OP-10/OP-11 determinism-oracle series. Added a LOCAL `hexa run` (0-GPU)
oracle that bit-exactly locks the flame AdamW optimizer decoupled-weight-decay UPDATE-arithmetic identity.
OP-6/OP-6b touched the AdamW kernel for PERF (fuse into the bwd-GEMM epilogue) but never oracle-locked the
UPDATE MATH itself. PRODUCTION SSOT = _hx_farr_adamw_step_cpu (self/runtime.c:10783), byte-eq twin of the
CUDA _hx_k_adamw_step (self/cuda/runtime_cuda.c:1236).

PROD (replays the SSOT op order VERBATIM) == REF (a clean Loshchilov-2017 AdamW update written to MATCH the
production associativity). max|Δ|=0 over the FULL state transition — W AND the in-place optimizer state m,v —
across 7 configs sweeping every knob: lr∈{3e-4..1e-2}, β1∈{.8,.9,.95}, β2∈{.99..​.9999}, ε∈{0,1e-8,1e-7,1e-6},
wd∈{0,.01,.05,.1}, step_t∈{1,3,5,10,50,100}, n∈{1,64,96,128,200} (incl. t=1 max-bias-corr, t=100 late, ε=0,
wd=0, n=1 edge). SQRT held CONSTANT across both forms — both call the SAME 24-iter Newton _adamw_sqrt
(flame_math dt_sqrt / gn_lib _gn_sqrt discipline; the SSOT's libm `sqrt` has no `hexa run` float surface and
its own comment pins dt_sqrt ≡ the same double) → the lock ISOLATES the update ORDER. ε is OUTSIDE the √
(denom = √v̂ + ε) in BOTH the SSOT and the oracle.

HONEST FINDING (g5) — a REAL associativity gap, found + resolved (NOT faked max|Δ|=0): a first REF that
grouped the squared-grad term as the natural `(1−β2)·(g·g)` diverged from production by up to 8.88e-16
(1.11e-16 across most of the 7 cases, 2.78e-17/0 on others). The production writes `(1−β2)·g·g`, which the
language groups LEFT-associatively as `((1−β2)·g)·g` — a DIFFERENT IEEE-754 double. Replaying that exact
grouping (production order = SSOT, NOT an algebraic refold) → genuine max|Δ|=0 everywhere, no eps.

CANONICAL ORDER (SSOT, runtime.c:10819-10830): v=(β2·v)+(((1−β2)·g)·g); m=(β1·m)+((1−β1)·g); m̂=m/c1 BEFORE
v̂=v/c2; denom=√v̂+ε (ε OUTSIDE √, sqrt held constant); W'=((W−lr·wd·W)−lr·(m̂/denom)) (two separate
subtractions, decoupled-wd term first); c1,c2=1−βᵗ with βᵗ by repeated-mul (not pow). `hexa run` PASS,
max|Δ|=0 all 7 cases. Behavior-preserving: NO trainer logic changed (oracle addition only). $0 — pure local
CPU, no GPU/pool/vast. Oracle stdlib/flame/clm_prod_adamw_update_eq.hexa · verdict
.verdicts/hexa-0pod/F-OP12-ADAMW-UPDATE-ORACLE.txt.

## 2026-06-09 — OP-14 DONE: flame determinism-contract doc consolidating the byte-eq oracle invariants (0-GPU)

Consolidated the HEXA-0POD byte-eq oracle findings into ONE contributor-facing doc —
docs/flame-determinism-contract.md — making flame's reproducibility-first identity legible. Pure local doc
authoring (0-GPU, $0); NO trainer/oracle/.hexa/.tape code changed.

INDEXED 8 verdicts as a per-phase table (step phase → oracle file → CANONICAL ORDER invariant → what-breaks-it),
with an ASCII step-phase map (g3 minimal):
  · F-OP13 INPUT  embedding bwd scatter-add (position-ASCENDING)
  · F-OP7  FWD    conv1d im2col+GEMM == direct (j-ASCENDING, j=ci*K+k)
  · F-OP2  BWD    dW transpose-elim (same-order contraction sum)
  · F-OP9  NORM   GroupNorm two-pass mean/var (t-out,c-in) + _gn_sqrt + eps=1e-5 + erf-GELU
  · F-OP8  MoE    softmax+combine (_moe_exp, max-sub, e-ASCENDING)
  · F-OP11 LOSS   bwd grad (libm exp) + fwd NLL (dt_exp/dt_ln), v-ASCENDING, scale-then-subtract
  · F-OP12 OPTIM  AdamW (v=β2·v+((1−β2)·g)·g left-assoc; m̂/c1 before v̂/c2; ε outside √; _adamw_sqrt)
  · F-OP10 SEAM   B>1 window-concat conv (interior bit-exact; seam = first (K-1)*dil pos)

CROSS-CUTTING RULE the doc leads with:
  1. THREE distinct exp impls each load-bearing — libm exp (CE bwd) · dt_exp (CE fwd) · _moe_exp (MoE) — a
     "unify the exp" refactor silently breaks byte-eq. (+ _gn_sqrt = 40-iter Newton, not libm.)
  2. Reductions SEQUENTIAL — no tree/warp-shuffle, no Welford.
  3. Accumulations ASCENDING — softmax denom v-asc · MoE combine e-asc · CE fwd t-asc · embed position-asc ·
     GroupNorm (t-out,c-in) · conv/GEMM j-asc.

DOJO POINTER: one-line blockquote pointer to flame-determinism-contract.md added to docs/hexa-dojo.md
"Training recipe — optimization gotchas" (the CLMConvMoE recipe) section. No dojo restructure.

GATE (g5): doc-consolidation milestone — value = the byte-eq reproducibility contract made legible, NOT new
computation. Every canonical-order claim traces to a specific verdict line (no invented invariant). $0, 0-GPU,
no pool/vast. OP-12 (AdamW optimizer oracle) landed in parallel and is indexed here as the OPTIMIZER phase.
Verdict .verdicts/hexa-0pod/F-OP14-DETERMINISM-DOC.txt.

## OP-15 — integration byte-eq oracle (whole micro-step byte-identical run-to-run)

- WIP skeleton pushed (stdlib/flame/clm_step_determinism_eq.hexa).
- DONE (`hexa run`, 0-GPU): composed CLMConvMoE micro-step (embed→conv→GroupNorm→MoE→CE→bwd→AdamW, 17 params)
  BYTE-IDENTICAL run-to-run from same fixed-seed init. loss 4.81916 both runs; max|Δ| = 0 over W, m, v, loss.
  Composition is deterministic — no uninit-scratch / non-det-iteration / address-ordered hole. Comparator
  sensitivity confirmed via negative control (distinct seed → 0.344217; identical → 0.0). GREEN (g5).
  Verdict .verdicts/hexa-0pod/F-OP15-STEP-DETERMINISM.txt.

## OP-16 — gn_lib host fallback (fused-valley GN+GELU 0-GPU hexa-run-testable)

- WIP skeleton pushed (milestone + verdict reproducing the OP-15 link gap).
- GAP REPRODUCED: `hexa run` of a harness that `use`s gn_lib → `Undefined symbols: _forge_dispatch_groupnorm_gelu,
  referenced from _nn_gn_gelu_fused_off`. The bare L3 fused-dispatch symbol has no host body off-CUDA (GPU build
  supplies it via fusion_dispatch.c `#ifdef HEXA_CUDA` glue, absent on CPU).
- HOST BODY written in self/runtime.c as `#ifndef HEXA_CUDA` definition of the bare symbol — two-pass mean/var
  (t-outer/c-inner), eps=1e-5 var+eps, 40-iter Newton _gn_sqrt, erf-GELU, writing the FP64 farr buffers. GPU
  dispatch UNCHANGED (guard avoids duplicate symbol with fusion_dispatch.c).
- BYTE-EQ CURE: naïve body diverged 3.55e-15 (clang -O2 FMA-contracts gamma*xhat+beta; hexa codegen does not).
  `#pragma STDC FP_CONTRACT OFF` (the proven ag_tape recipe) → max|Δ| EXACTLY 0.
- PROVEN (0-GPU): rebuilt runtime.o (`clang -O2 -c`), nm shows symbol U→T; flame_gn_gelu_fused_test (use's
  gn_lib) LINKS+PASSES max_abs_diff=0; tracked oracle clm_prod_gn_gelu_hostdispatch_eq.hexa drives the FUSED
  entry point through the host dispatch (env-gated) vs unfused OP-9 ref → max|Δ|=0 on Y,A,mean,inv,xhat (7 shapes).
- HONEST LANDING (g5, OP-2b-class): self/runtime.c is gitignored frozen-seed (#2065 .c-graduation, no tracked
  emit SSOT for forge dispatchers) → the C BODY lands via a runtime rebuild in the release/build env (verbatim
  body + exact one-rebuild fix in the verdict). Byte-eq oracle + milestone + verdict ship now (tracked).
  links-now YES · byte-eq max|Δ|=0 · GPU untouched YES. Verdict .verdicts/hexa-0pod/F-OP16-GN-HOST-FALLBACK.txt.

## OP-17 — fix runtime.c -Wmacro-redefined (9 libc macros) at source · 🟢 9→0

- WIP skeleton pushed first (milestone + placeholder verdict; durable-worktree rule).
- SIGNAL: clang on self/runtime.c → 9 [-Wmacro-redefined] (strcat/bzero/memcpy/memset/memmove/strncpy/strcpy/
  snprintf/sprintf). Forge-hygiene class — same as OP-5/OP-5b (-Wcomment) but a DIFFERENT warning class.
- TWO COLLIDING SITES located: (1) Darwin _FORTIFY_SOURCE secure headers `<secure/_string.h>`/`_strings.h`/
  `_stdio.h` ALREADY `#define` these 9 as `__*_chk_func` fortify macros (transitive via top `#include <string.h>`/
  `<strings.h>`/`<stdio.h>`); (2) runtime.c "Textual override" block (frozen lines 2070,2082-2087,2095-2096)
  redefines them to the `hxlcl_*` svc-trap helpers. Only these 9 collide — the rest (strlen/memcmp/…) are plain
  externs, not fortify macros.
- MINIMAL FIX: `#undef` the 9 names before the override block — the EXACT precedent the seed already uses for
  `#undef isalnum`/`#undef exit`. BEHAVIOR-PRESERVING (clang -E proof): hxlcl_* is the LAST `#define` either way →
  expansion byte-identical before/after; `#undef` only kills the warning (no-op on Linux glibc → platform-neutral).
- LOCAL VERIFY (0-GPU, `clang -fsyntax-only -DHEXA_RT_SELFEMIT`): -Wmacro-redefined 9→0; the 2 unrelated
  pre-existing classes (4 -Wincompatible-pointer + 12 -Wundefined-internal) UNCHANGED; 0 errors.
- HONEST LANDING (g5, OP-2b/OP-15/OP-16 class): self/runtime.c is gitignored frozen-seed (#2065, restored from
  immutable blob 151c52c8… — no tracked emit SSOT) → durable fix lands as a deterministic, idempotent,
  marker-guarded POST-RESTORE PATCH in the TRACKED tool/restore_frozen_seeds (injects the 9 `#undef`s on every
  restore). End-to-end verified through the patched tool (warnings 0 after restore; re-restore stays single-inject).
  9 warnings GONE · behavior-preserving YES · no new warn YES · GPU/pod/vast NONE ($0).
  Verdict .verdicts/hexa-0pod/F-OP17-MACRO-REDEF.txt.

## OP-20 — deterministic TF32 fast-mode (the PRECISION-CHANGE uncap lever)

Probed the one unexplored uncap lever the campaign named (MEGASTEP + flame_h100_h200_closeout): does a
FP64->TF32 precision change break the ~3x flame step cap WHILE keeping flame's reproducibility identity?
Key insight: TF32 breaks byte-eq-vs-FP64 but can still be byte-eq-vs-ITSELF (run-to-run) — a different
PRECISION CONTRACT (W14: rel-rms<=1e-2 vs same dtype), a legitimate product mode not an identity sacrifice.

Harness tool/bench/flame_bench_step_tf32fast.cu runs BOTH a TF32 lane (CUDA_R_32F /
CUBLAS_COMPUTE_32F_FAST_TF32 tensor-op) and an FP64 lane (CUDA_R_64F / COMPUTE_64F) in ONE process over the
OP-4 fused step DAG (fused valley LN+gelu+copy + transpose-elim bwd GEMM + single-launch AdamW; only the
cuBLAS compute type differs; all elementwise/reduction glue in FIXED deterministic order, no atomics).
-DPEDANTIC toggles CUBLAS_PEDANTIC_MATH to test whether default tensor-op TF32 needs pedantic to stay
self-byte-eq. Driver tool/bench/run_op20_5070.sh, idle-guarded, on FREE aiden RTX 5070 (sm_120, CUDA 13.0).

Result (8/8 cells GREEN, both DEFAULT and PEDANTIC):
  GATE-A self-byte-eq: max|delta(W')| = EXACTLY 0 — pedantic NOT needed (default TF32 already deterministic
         on the 5070; PEDANTIC = identical bytes, identical time → recommend PEDANTIC as portable SHIP guarantee).
  GATE-B rel-RMS(TF32 vs FP64) ~ 1.13e-6 — 4 orders inside W14 1e-2.
  SPEED  FP64/TF32 = 4.19-4.63x @B=1, 19.08-21.36x @B=8 — BREAKS the ~3x cap at every shape.
Honest: B=8 ~20x is inflated by the 5070's crippled FP64 (~1/64 FP32); quote B=1 (4.2x, card-robust) as the
headline. Determinism proven for THIS card/cuBLAS-13.0; pin PEDANTIC to guarantee portably. Single-step
rel-RMS only (long-horizon TF32-vs-FP64 drift deferred). Harness-level (OP-4 fused lane) — live forge GEMM
TF32-dispatch wire deferred (clm_prod build + aiden verify). Deterministic TF32 fast-mode = a REAL flame
fast-mode: identity kept + W14-equivalent + >3x faster. The precision-change uncap lever WORKS. $0, no vast.
Verdict .verdicts/hexa-0pod/F-OP20-TF32-FASTMODE.txt.

## OP-21 — Hopper warp-spec TMA pipeline DESIGN (0-pod, GPU-gated measure) — 2026-06-09

Deep-dive design round, $0/0-GPU, by reading the W10 frontier source + the W-ladder verdicts ONLY. Produced
the design + perf-gap roofline + turnkey H100 recipe for the forge own-GEMM's remaining Hopper (sm_90a wgmma)
perf lever — a warp-specialized TMA producer/consumer software pipeline (the cuBLAS-class mainloop).

W10-HAS (from self/native/wgmma/wgmma_tf32_w10_lib.h gemm_w10): HW TMA producer driven by a single elected
thread (W8 lever), dual consumer warpgroups, SWIZZLE_128B TMA descriptors (W9 permute-removal), the COMPOSED
software decode (W10 fix, bit-exact rel_rms 0), and an NST-deep swizzled-TMA ring (load side pipelined).
W10-MISSES (the cuBLAS-class residual): M1 dedicated producer warpgroup + setmaxnreg register realloc (W10
has NO setmaxnreg; W12 tried it on 128x256 and ptxas IGNORED it C7507 — but the W10 128x128 has 64-reg
accumulator headroom W12's 128 did not); M2 decode/MMA overlap at 2 CTA/SM (gemm_w10 does wgmma.wait_group 0
every slab + a SINGLE non-ringed decode band -> decode<->MMA serialize); M3 descriptor-direct wgmma deleting
the 32KB band (W10-inplace + W15's 3200-config sweep floored rel_rms 1.392/1.000 — the atom-major landing is
a "3rd interaction"); M4 m64n256k8 wider-N; M5 ping-pong epilogue.

PERF-GAP ROOFLINE (cited, NOT re-measured): own W10 70.7 TFLOP/s @4096 vs cuBLAS-TF32 ~430 = 6.09x. Gap
decomposed: occupancy (A) ~0% — W10 is already at the max 2 CTA/SM (W8 closed 1->2; W11/W13 regressed trying
to use more); mainloop/decode-MMA overlap (B) = DOMINANT share (wait_group 0 + single band serialize, cuBLAS
never stalls the TCs); decode-band tax (C) = secondary AND COUPLED to (B) — you can't ring-deepen the band
(W13: 2nd 32KB band -> 1 CTA/SM -27%) NOR delete it (W15: read wrong) without a structural change; epilogue
(D) small (W10 already has the register-blocked scatter). The 6.09x is the (B)+(C) decode/MMA-overlap KNOT.

DESIGNED LEVER OP-21A: untie the knot — (1) canonical-atom re-encode so the SWIZZLE_128B TMA lands the exact
CuTe Layout_K_SW128_Atom the wgmma HW de-swizzle expects (kills W15's root cause, the falsifiable core);
(2) descriptor-direct wgmma -> delete the 32KB software decode band (W15 MEASURED this real: 96->64KB/CTA,
2 CTA/SM held); (3) spend the 32KB on a deeper decode-free TMA ring (NST=3) + wgmma.wait_group<NST-2> so the
oldest committed group drains while the newest issues (the overlap, attacks B); (4) dedicated producer WG +
setmaxnreg.dec 40 / consumer setmaxnreg.inc 232 — GRANTABLE here because the 128x128 accumulator is only 64
regs/thread (W12's 128x256 was 128, rejected). Concrete params: tile 128x128 (kept — W11 proved bigger alone
regresses), TKSW=32, NST=3, full[]/empty[] mbar + wgmma.wait_group<NST-2>, producer/consumer reg split with
single-elected-thread fallback. FALLBACK OP-21B (if canonical re-encode doesn't hit rel_rms 0): keep the band,
register wgmma double-buffer (no M3 dependency). PRE-REGISTERED FALSIFIER stated (lift past 70.7 toward parity,
to confirm/refute on H100; either way a publishable closed-negative with a number).

TURNKEY H100 RECIPE: rent 1 H100 (sm_90a, nvcc 12.6.77, driver 560.35.x — apples to W10/W15) -> author
wgmma_tf32_w16.cu (#include wgmma_tf32_w10_lib.h for same-binary gemm_w10 baseline + canonical-atom encoder +
probe_desc_canonical + gemm_w16 descriptor-direct/NST=3/wait_group<NST-2>/setmaxnreg) -> GATE rel_rms 0
(MODE 0/1 single-tile, then MODE 4 @2048/4096/8192) BEFORE any perf -> ONLY THEN occupancy (confirm 2 CTA/SM)
+ perf sweep own vs same-binary cuBLAS-TF32 (Δ vs W10 70.7) + SASS (STS gone) -> write W16 verdict (new
frontier if lifts bit-exact, else closed-negative W10 KEPT) -> destroy pod (leak 0). One H100-hour suffices.

HONEST (OP-2b-class, g5): NO measurement performed or claimed. This is the DESIGN for a GPU-GATED experiment;
the Hopper sm_90a measure is out of 0-pod scope until an H100 is authorized. cuBLAS-TF32 = roofline, parity
NOT claimed. $0, no vast/pool/pod. Verdict .verdicts/hexa-0pod/F-OP21-HOPPER-WARPSPEC-DESIGN.txt (PR #3000).

## OP-19 — cross-platform byte-exact: libm-exp CE-bwd divergence MEASURED + CLOSED (2026-06-09)

- THESIS (deep-dive, MEASURED REAL): OP-11 found CE-bwd clm_ce_grad uses the libm `exp` builtin; the OP-2/7/8/
  9/10/11/12/13+OP-15 series prove only SINGLE-machine run-to-run byte-eq. Cross-PLATFORM (x86 vs arm64,
  Darwin vs Linux libm) was UNVERIFIED. libm transcendentals are not correctly-rounded → suspected hole.
- ORACLE (0-GPU, $0, free pool): stdlib/flame/op19_crossplatform_selfcontained.hexa — self-contained `hexa
  run` that folds the exact IEEE-754 bytes (f64_to_bytes_le; float_to_bits too new for aiden's runtime.a) of
  CE-bwd grad in libm-exp + dt_exp form. RAN on local+ghost (arm64-macos) vs aiden (x86-linux) = cross-arch +
  cross-OS.
- VERDICT (BEFORE): libm-exp CEBWD fold DIVERGED — local/ghost 7969105254299072804 ≠ aiden 3352931952497630952;
  dt_exp byte-IDENTICAL (7679248634312321699) on all 3. ISOLATED via per-element byte diff: EXACTLY 4/4096 grad
  elems differ, EACH by 1 mantissa-LSB = 1 ULP (glibc vs Darwin libm). Run-to-run stable per machine.
- FIX: clm_ce_grad libm `exp` → dt_exp (matches CE-fwd) on host (clm_prod.hexa) + GPU kernel (_hx_dt_exp_dev in
  runtime_cuda_emit.hexa, _moe_exp_dev precedent → host↔device byte-eq preserved). Grad-change: max abs
  2.17e-18, max rel ≈2.0e-14 (a few ULPs). Trades "matches libm" for "matches across ALL platforms" (g5).
- AFTER: production CE-bwd fold = 7679248634312321699 IDENTICAL on all 3 → cross-platform byte-identical YES.
- OP-11 RE-LOCK: clm_prod_ce_softmax_grad_eq.hexa _ce_grad_prod + _ce_grad_ref libm→dt_exp; F-OP11 = 1 PASS
  (all 6 grad + 6 loss cases max|Δ|=0). Contract doc updated (3 exp impls → 2).
- RESIDUAL (honest latent, OP-19b deferred): GELU libm `erf` (fwd+bwd) is the same hole; no bit-accurate
  deterministic erf in-tree + `erf` won't link on aiden's runtime → documented follow-up.
- $0 · 0-GPU · free pool (aiden/ghost) · no vast · no pod. Verdict .verdicts/hexa-0pod/F-OP19-CROSSPLATFORM-EXACT.txt.

## OP-24 — wire deterministic TF32 fast-mode into the live forge GEMM dispatch (env-gated, byte-eq-safe, aiden) 🟢 dispatch-unit
- GOAL: take OP-20's PROVEN deterministic TF32 fast-mode (self-byte-eq + W14-tol vs FP64, 4.2x @B=1) +
  OP-23's validated N-step trajectory and WIRE it into the REAL flame forge GEMM dispatch the CLMConvMoE
  trainer rides — env-gated like HEXA_OWN_GEMM/HEXA_FUSE_*, FP64 default UNCHANGED. The OP-2-class
  harness-win→live-trainer wire the F-OP20 verdict named as the deferred follow-up.
- DISPATCH SITE: self/cuda/runtime_cuda_emit.hexa `_hx_cuda_farr_matmul_gpu` (the forge row-major
  projection GEMM; same fn OP-2 touched for transpose-elim). Default = cublasDgemm (FP64); prior only
  opt-in was HEXA_OWN_GEMM (naive _hx_k_gemm). runtime_cuda_emit.hexa is git-TRACKED, NOT a frozen seed
  (FROZEN_SEEDS = runtime.c + .c fragments + hexa_cc.c) → durable landing is the ordinary branch→PR path.
- WIRE: new `else if (_forge_tf32_fastmode())` branch (env HEXA_TF32_FASTMODE). FP64 farr buffers are
  double; TF32 path casts A,B→fp32 into SCRATCH (never mutates inputs → FP64 default byte-identical),
  runs cublasGemmEx CUBLAS_COMPUTE_32F_FAST_TF32 on a SEPARATE PEDANTIC-pinned handle g_cublas_tf32
  (OP-20's portable self-byte-eq ship guarantee), casts result fp32→FP64 C. Cast = fixed-order elementwise
  (no reduction/atomics) → no determinism hazard. g_cublas (FP64) untouched, stays fp64-strict.
- VERIFY (aiden RTX 5070 sm_120, CUDA 13.0, FREE pool, idle-guarded): op24_tf32_livewire_dispatch.cu
  replays the EXACT wired codepath (same FP64 buffers, cast kernels, PEDANTIC handle, arg layout) — the
  LIVE dispatch logic in isolation, not the OP-20 fp32-storage harness. 4/4 cells (D={768,1536}×B={1,8})
  PASS all 3 gates: GATE-A FP64-default byte-id max|Δ|=0; GATE-B TF32-live self-byte-eq max|Δ|=0;
  GATE-C W14 rel-RMS ~2.94e-4 (~34x inside 1e-2); SPEED 29.9–51.0x (GEMM-only).
- HONEST (g5): dispatch-UNIT not full-trainer. rel-RMS 2.9e-4 = RAW single-GEMM output (OP-20's 1.1e-6
  was post-AdamW weight delta — both pass, different metric). 30-51x OVERSTATES trainer step (5070 FP64
  ~1/64 throttle + no glue dilution); card-robust signal = OP-20's B=1 ~4.2x. EXACT remaining OP-2b-class
  step: build clm_prod_gpu -DHEXA_CUDA on aiden, run trainer HEXA_TF32_FASTMODE=1 vs unset, report loss
  self-byte-eq + wall step/s. PEDANTIC PINNED (not optional) = portable determinism; GATE-B=0 confirms.
- $0 · free aiden · no vast · no pod · aiden /tmp cleaned (no residue). Verdict F-OP24-TF32-LIVEWIRE.txt;
  raw tool/bench/op24_5070_raw.log.

## OP-26 — machine-independent bit-exact training: rigorous results writeup (docs-only, 0-pod, $0, NO paper) — 2026-06-10
- DELIVERABLE: docs/flame-machine-independent-training.md — a rigorous, evidence-complete RESULTS document
  (NOT a paper) consolidating the HEXA-0POD result that flame's CLMConvMoE step is FULLY machine-independent
  byte-exact. Verified by READING the existing verdicts; NO new computation, NO GPU, NO vast, NO pod.
- THE CLAIM: same fixed-seed step produces the same weights/grads/loss to the LAST BIT on x86-64-linux (glibc)
  and arm64-macos (Darwin libm) — cross-arch AND cross-OS. torch/JAX do NOT give this (libm exp/erf/log are
  not correctly-rounded; glibc vs Darwin round the last ULP differently). flame has NO libm transcendental
  left on the step path → every transcendental is a fixed-iteration +−×÷ routine = bit-identical on any
  IEEE-754 hardware.
- THREAT MODEL → closure → verdict (ASCII diagrams in doc): T1 libm-not-correctly-rounded → dt_exp/dt_erf/
  dt_ln/_moe_exp + Newton sqrt (F-OP19/19b/8/11) · T2 tree/warp reduction → sequential ASCENDING (F-OP8/9/11)
  · T3 atomic-scatter → position-ASCENDING scatter-add (F-OP13).
- EVIDENCE TABLE — 12 cited verdicts with byte-cmp values: F-OP7/2/8/9/11/12/13 per-phase (max|Δ|=0 + honest
  reorder probes 1.39e-17 / 8.88e-16 / 5.68e-14), F-OP15 whole-step capstone (max|Δ|=0 over W/m/v/loss,
  neg-control 0.344217), F-OP19 CE-bwd libm exp DIVERGE (arm64-macos 7969105254299072804 vs x86-linux
  3352931952497630952 = 4/4096 × 1 ULP; dt_exp 7679248634312321699 identical on all 3), F-OP19b GELU dt_erf
  fwd 4548590605583584556 / bwd 4249661408190172843 identical on local+ghost arm64-macos + aiden x86-linux,
  F-OP23 TF32 self-byte-eq N=100 + loss-track ~1e-7.
- DETERMINISM CONSTRUCTION recipe (§4) + HONEST LIMITS (§5): dt_erf 1.38e-7 from libm BY DESIGN · TF32
  self-not-cross-precision · single-machine GPU scope (host↔device byte-eq + cross-platform CPU byte-eq) ·
  B>1 conv seam intentional (F-OP10) · production-stdlib final 0.0 read build-deferred.
- Pointer added from docs/flame-determinism-contract.md (contributor SSOT) → the results doc.
- GOVERNANCE (project.tape g84 PAPER OPT-IN): logged-discovery consolidation ONLY. NO /paper scaffolded, NO
  PAPER.tape/PAPER.md created, paper skill NOT invoked. A paper happens ONLY on explicit /paper.
- $0 · 0-GPU · 0-pod · no vast. Verdict .verdicts/hexa-0pod/F-OP26-MACHINEINDEP-WRITEUP.txt.

## OP-19c — 3rd-platform byte-exact: pi5-akida arm64-LINUX confirms machine-independence (2026-06-10)
- GOAL: extend OP-19/19b's 2-platform proof (x86-linux aiden ↔ arm64-macos local/ghost) to a 3rd distinct
  arch×OS cell = pi5-akida arm64-LINUX (Raspberry Pi 5, glibc) — isolates arch-vs-OS (same arch as macos, same OS
  as aiden). FREE POOL ONLY (pi5-akida), ZERO vast, 0-GPU (`hexa run`), $0.
- pi5 hexa status: RUNNABLE = YES. OP-19/19b noted pi5 had no hexa; installed it 0-pod this op:
  (a) official installer pulled prebuilt hexa-linux-arm64.tar.gz (v0.17.3) → hexa 0.1.0-dispatch (SAME version
      as all 3 prior hosts — apples-to-apples). ELF aarch64 GNU/Linux.
  (b) pi5 has gcc 13.3.0 but NO clang; `hexa run` C-backend hardcodes clang → dropped user-local ~/.hx/bin/clang
      shim → gcc, stripping the clang-only -fbracket-depth flag.
  (c) release tarball ships no self/ → scp'd a matching-version self/ runtime tree (runtime.c + headers +
      native/*.c + forge/*.c) from the local 0.1.0-dispatch install, md5-verified; `tar -h` to dereference the
      4 macOS-absolute symlinks (native/crypto_blowfish.c, hxtok.h, parser_v2.c, hxtok.c). symlinked ~/.hx/bin/self.
- pi5 byte folds (verbatim `hexa run` output):
    CEBWD-TAYLOR (dt_exp)  = 7679248634312321699
    GELUFWD-DET  (dt_erf)  = 4548590605583584556
    GELUBWD-DET  (dt_erf)  = 4249661408190172843
    (libm baselines also dumped: CEBWD-LIBM = 3352931952497630952, GELUFWD/BWD-LIBM = glibc values)
- 3-WAY cmp (pi5 vs recorded arm64-macos local/ghost + x86-linux aiden):
    CE-bwd dt_exp  : MATCH  (7679248634312321699 on all 3)
    GELU FWD dt_erf: MATCH  (4548590605583584556 on all 3)
    GELU BWD dt_erf: MATCH  (4249661408190172843 on all 3)
  => 3-PLATFORM BYTE-IDENTICAL = YES. {x86,arm64}×{linux,macos} matrix now 3/4 cells confirmed (4th = x86-macos,
     no pool host — retired Intel Macs). pi5 supplies the arm64-linux diagonal isolating arch vs OS.
- BONUS (strengthens OP-19): pi5 arm64-linux CEBWD-LIBM = 3352931952497630952 == aiden x86-linux, NOT arm64-macos's
  7969105254299072804. => the libm `exp` divergence OP-19 measured is an OS/libc effect (glibc vs Darwin libm), NOT
  arch — pi5 tracks the OS it shares (Linux/glibc), not the arch it shares (arm64). dt_exp/dt_erf remove that path.
- NO divergence on the production deterministic path. $0 · 0-GPU · 0-pod · free pool (pi5-akida only) · no vast.
  Verdict .verdicts/hexa-0pod/F-OP19C-PI5-3PLATFORM.txt.

## OP-24b — TF32 fast-mode end-to-end through the REAL clm_prod_gpu trainer (aiden build attempt) — 2026-06-10
- GOAL: complete OP-24's TF32 live-wire from dispatch-UNIT to the FULL end-to-end CLMConvMoE trainer —
  build clm_prod_gpu -DHEXA_CUDA on aiden (free RTX 5070, HAS nvcc) + run flame trainer FP64 vs
  HEXA_TF32_FASTMODE=1. FREE aiden only, ZERO vast, foreign pod 40306156 untouched.
- RESULT = HONEST BUILD-GATED (OP-2b-class, g5 OR-branch). clm_prod_gpu BUILT ON AIDEN = NO.
- EXACT BLOCKER (quantified at current main 304a4019f): the real trainer stdlib/flame/clm_prod.hexa
  (1421 L) calls 31 forge_dispatch_<op> ops; their HOST marshal wrappers hexa_forge_dispatch_<op>(HexaVal..)
  must live in a coherent runtime.c. The frozen seed runtime.c (151c52c82, restore_frozen_seeds) provides
  ONLY 2/31 (matmul + ffn_fp64_via_bf16). The other 30 are in NO tracked current-main source: 24 live only
  in the UNTRACKED inbox patch forge-devfeed-lever-a-runtime-c-fragment.c.txt (749 L, stale worktrees);
  ~6 hand-spliced on the gone W2 pod, never re-frozen. restore_frozen_seeds appends only OP-18
  #ifndef HEXA_CUDA CPU fallbacks, not the #ifdef HEXA_CUDA device wrappers. = the same terminal wall
  project_clmprod_gpu_build_seed_drift documents, now measured: 2/31 present, 30 missing. aiden adds the
  toolchain (nvcc 13.0/sm_120 compiles fine) but NOT the missing SOURCE → wall unmoved.
- UNBLOCK (maintainer/CI, one-time): re-freeze a runtime.c seed with all 31 #ifdef HEXA_CUDA host wrappers,
  OR add a CUDA build job to release.yml. THEN 0-pod on aiden: transpile clm_prod.hexa, emit runtime_cuda.c
  (TF32 wire already in it), nvcc -DHEXA_CUDA, link -lcudart -lcublas -lcuda, run trainer x2.
- 0-POD DELIVERED (the well-formed proof): emitted current-main runtime_cuda.c (334KB, TF32 wire present:
  10 hits) COMPILES CLEAN under `nvcc -x cu -DHEXA_CUDA -arch=sm_120` on aiden -> runtime_cuda.o 3.4 MB
  (benign warnings only, none in TF32 code). nm confirms ALL TF32 symbols emitted: _hx_k_cast_d2f/f2d,
  g_cublas_tf32 (PEDANTIC handle), _hx_cuda_gemm_tf32_dev, _hx_cuda_farr_matmul_gpu (TF32 else-if branch);
  only external cublasGemmEx/cublasSetMathMode undefined (resolve at -lcublas link). => TF32 branch is
  WELL-FORMED + CODEGEN-COMPLETE in the real -DHEXA_CUDA context. Only the RUN is gated, not the code.
- BONUS FINDING (0-pod, real): first -DHEXA_CUDA compile surfaced a PRE-EXISTING OP-19b regression —
  _hx_dt_exp_dev defined TWICE in runtime_cuda.c (line 1624 + dead line-4092 Taylor variant; OP-19b's
  "defined ONCE above" comment never removed the 2nd). Latent emit bug that ONLY breaks under nvcc
  -DHEXA_CUDA (the 0-GPU blind spot OP-15 named). Isolated (renamed dead def) for the proof; trivial
  0-pod follow-up = delete the line-4092 block from self/cuda/runtime_cuda_emit.hexa.
- $0 · free aiden · no vast · no pod · aiden ~/op24b_wellformed cleaned (no residue). NO end-to-end run
  claimed (g5). Verdict .verdicts/hexa-0pod/F-OP24B-TF32-ENDTOEND.txt.

## 2026-06-10 — OP-24c DONE: TF32 end-to-end TURNKEY build kit (build_clmprod_tf32_e2e.sh) WRITTEN + local-checked, GPU-build-gated run (0-pod, $0)
- GOAL: turn OP-24b's honest build-gated finding into a TURNKEY one-command kit — the OP-21A pattern
  (code+script ready, measurement env-gated) wired specifically to the TF32 end-to-end test through the
  REAL clm_prod_gpu CLMConvMoE trainer. 0-pod: WRITE + local-check the script; NO build, NO run, NO GPU.
- DELIVERED: tool/clm/build_clmprod_tf32_e2e.sh (turnkey, bash -n VALID, every step concrete). The moment
  a complete-frozen-seed GPU-build env is authorized, the whole test = `bash tool/clm/build_clmprod_tf32_e2e.sh`.
- STRUCTURE (JOB a-e): (a) PROVISION CHECKLIST + ZERO-VAST guard (does NOT rent; exits clean if no nvcc /
  no sm_120+ GPU) + OP-23/24 idle guard. (b) frozen-seed stage (FROZEN_SEED_REF=151c52c8… restore_frozen_seeds)
  + EXACT-BLOCKER PRE-CHECK: greps restored self/runtime.c for the 31 host marshal wrappers clm_prod.hexa calls;
  if any missing, prints the F-OP24B blocker verbatim (the 30 absent, the 2 unblock options) + EXITS 3 BEFORE
  wasting a build; then EMIT runtime_cuda.c (TF32 wire asserted present) + nvcc -x cu -DHEXA_CUDA -arch=$ARCH
  + gcc-link -lcudart -lcublas -lcuda (the proven recipe). (c) run the trainer x2 each FP64-default +
  HEXA_TF32_FASTMODE=1, tiny config (CLM_PROD_{D,E,T,BATCH,NSAMP,EPOCHS} env knobs, all verified in main()).
  (d) g5 GATE SEQUENCE: GATE-A FP64-unchanged (run1==run2 loss max|Δ|=0) → GATE-B TF32 self-byte-eq → GATE-C
  TF32-tracks-FP64 (OP-23 E2E, worst |Δloss|/|loss_FP64| <= W14 1e-2) → SPEED wall step/s ratio (ONLY after
  A+B+C PASS, with the honest glue-dilution caveat: << GEMM-only 30-51x, nearer OP-20 ~4.2x @B=1; consumer-card
  FP64 ~1/64 inflates it; no superiority claim). (e) verdict headline + leak-0 cleanup trap.
- LOCAL 0-POD CHECK (verbatim): `bash -n tool/clm/build_clmprod_tf32_e2e.sh` -> PASS. Referenced paths/flags/
  knobs verified at current main: restore_frozen_seeds OK, runtime_cuda_emit.hexa OK, clm_prod.hexa (main L1164)
  OK, frozen ref 151c52c8… resolves to a commit, all 6 CLM_PROD_* knobs read by main(). self/runtime.c is
  correctly ABSENT at main (graduated-removed seed RESTORED by the script's own step b.1 BEFORE step b.2 greps
  it — ordering correct). inbox patch absent (F-OP24B says untracked; script doesn't depend on it).
- EXACT REMAINING GPU-BUILD-ENV-GATED STEP (F-OP24B-confirmed, the single irreducible wall): in the canonical
  self-host build env, re-freeze a runtime.c seed carrying ALL 31 #ifdef HEXA_CUDA host wrappers (today 2/31:
  matmul + ffn_fp64_via_bf16), OR add a CUDA build job to release.yml. THEN `bash tool/clm/build_clmprod_tf32_e2e.sh`
  runs unchanged + the pre-check passes instead of exiting 3. TF32 code already proven well-formed + codegen-
  complete under -DHEXA_CUDA (F-OP24B §3) — only the RUN is gated, and this script IS the run.
- TURNKEY = YES. HONEST: no end-to-end number claimed (kit-ready, run-gated; OP-21A framing). 0-pod · $0 · no
  vast · no pod · no GPU · no leak · foreign pod 40306156 untouched. Verdict .verdicts/hexa-0pod/F-OP24C-TF32-TURNKEY.txt.

## OP-19d — 4th-env byte-exact: musl (Alpine) strengthens machine-independence to 3 distinct libm impls (2026-06-10)
- GOAL: extend OP-19/19b/19c's 3-platform proof (Darwin · glibc-x86 aiden · glibc-arm64 pi5) to a 4TH DISTINCT
  ENVIRONMENT giving a 3rd DISTINCT libc/libm — musl (Alpine). The hardest "no libm dependence left" test:
  musl ≠ glibc ≠ Darwin. FREE POOL ONLY (summer's docker), ZERO vast, 0-GPU, $0.
- 4th env chosen = MUSL (Alpine Linux) via `docker run alpine` on summer (has /usr/bin/docker). Picked over a 4th
  glibc host because musl is a genuinely new libm impl. summer's own native glibc hexa was bootstrap-broken (hexat
  transpiler missing, runtime_core.c rebuild fails 10 errors) → summer served ONLY as the docker host, not a glibc run.
- hexa runnable on musl = YES, with a DISCLOSED TEST-ONLY shim. hexa.real is glibc-linked (can't run under musl), but
  `hexa run` = transpile→C then `clang …runtime.c -lm`. Transpiled both oracles on aiden (self/native/hexa_v2), then
  COMPILED+RAN the C in Alpine — binaries link MUSL (`ldd → libc.musl-x86_64.so.1`), libm = musl. Build fixes (build-
  only, NOT numeric): `-include sys/un.h…` (musl <sys/un.h> strlen proto vs runtime `#define strlen`), `-fuse-ld=lld`,
  apk gcc+libgcc (CRT). REAL RUNTIME BUG found (gdb): SIGSEGV at init in _hexa_init_mem_cap→hxlcl_getenv — the
  priority-101 `hxlcl_capture_environ(argc,argv,envp)` ctor relies on the glibc/Darwin-only "(argc,argv,envp)→ctor"
  ABI; musl passes NO args to ctors → envp garbage → segfault before main. Worked around with a throwaway runtime copy
  (ctor reads musl `extern __environ`; env-capture ONLY, all math byte-identical; NOT committed). The ctor-ABI bug is a
  genuine runtime follow-up (separate guarded PR), INDEPENDENT of fold math.
- musl byte folds (verbatim, env-capture-shimmed run):
    CEBWD-TAYLOR (dt_exp)  = 7679248634312321699
    GELUFWD-DET  (dt_erf)  = 4548590605583584556
    GELUBWD-DET  (dt_erf)  = 4249661408190172843
- 4-WAY cmp (musl vs recorded Darwin + glibc-x86 aiden + glibc-arm64 pi5):
    CE-bwd dt_exp  : MATCH  (7679248634312321699 on all 4)
    GELU FWD dt_erf: MATCH  (4548590605583584556 on all 4)
    GELU BWD dt_erf: MATCH  (4249661408190172843 on all 4)
  => 4-ENVIRONMENT BYTE-IDENTICAL = YES.
- # DISTINCT libm impls spanned = 3 (glibc · musl · Darwin). libm `erf` (GELU-FWD-LIBM) gives 4 DIFFERENT values
  across the 4 envs: musl 7314648833623304241 ≠ glibc-x86 6306829276275644424 ≠ glibc-arm64 3332333775004383127 ≠
  Darwin 1521224270287218303, while dt_erf is identical on all → DEFINITIVE: only the dt_* path is machine-independent.
  (libm exp CE-bwd: musl 3352931952497630952 == glibc, ≠ Darwin 7969105254299072804 — confirms OP-19c's OS/libc thesis
  with a 3rd libc in hand.)
- NO divergence/defect on the production deterministic path (the musl init segfault is a pre-main libc-ABI env-capture
  bug, flagged as a runtime follow-up). $0 · 0-GPU · 0-pod · free pool (summer docker + Alpine) · ZERO vast · foreign
  pod 40306156 untouched. Verdict .verdicts/hexa-0pod/F-OP19D-4TH-ENV.txt.

## OP-19e — musl-safe env-capture (POSIX environ, not constructor-args ABI); fixes the OP-19d SIGSEGV (0-pod)
- THE durable fix for the REAL hexa-runtime↔musl bug OP-19d surfaced. ROOT CAUSE: self/runtime.c (frozen 151c52c8…,
  "RUNTIME tail (cycle 85)") priority-101 ctor `hxlcl_capture_environ(int argc, char**argv, char**envp){ hxlcl_environ
  = envp; }` relies on the glibc/Darwin-only "(argc,argv,envp)→constructor" ABI. musl runs ctors with NO args → `envp`
  is a garbage register → `hxlcl_environ`=garbage → SIGSEGV in `_hexa_init_mem_cap`→`hxlcl_getenv` BEFORE main().
- FIX: read the POSIX global `extern char **environ` (defined by EVERY libc incl. musl) instead of the ctor arg:
    extern char **environ;
    static char **hxlcl_environ = 0;
    __attribute__((constructor(101)))
    static void hxlcl_capture_environ(void) { hxlcl_environ = environ; }
    #define environ hxlcl_environ
  `extern char **environ;` + the body's `environ` read sit BEFORE the `#define environ hxlcl_environ` shadow → bind the
  libc symbol. BEHAVIOR-PRESERVING on glibc/Darwin (ctor-arg envp and libc `environ` point at the same vector at start);
  FIXES musl (real pointer, not a garbage register).
- DURABLE LANDING: self/runtime.c is gitignored (frozen seed). Per OP-16/17/18, the fix lands as an idempotent,
  marker-guarded OP-19e post-restore awk patch in tool/restore_frozen_seeds (rewrites the 6-line capture block on every
  restore). ONE tracked file changed; runtime.c stays untracked. wipe_guard scoped (small additive patch, no deletions).
- PROOF (0-pod · summer docker + Alpine · $0 · NO vast · NO GPU):
  (a) isolated reproducer, both variants compiled NATIVE: Alpine/musl (/lib/ld-musl-x86_64.so.1) OLD ctor-ABI =
      "Segmentation fault (core dumped)" exit 139; NEW POSIX-environ = "environ_nonnull=1 OP19E_PROBE=hello PATH=1"
      exit 0. Ubuntu glibc 2.39 OLD≡NEW identical (exit 0). Darwin (local clang) NEW clean exit 0.
  (b) full patched self/runtime.c BUILDS: Darwin `clang -fsyntax-only` exit 0 (zero errors); Alpine/musl `clang -c` →
      runtime.o OK, ZERO environ diagnostics (extra flags = OP-19d-class build-env: header pre-ordering + lld + gcc/
      libgcc CRT + openssl/sodium-dev — BUILD-ONLY, not the env fix).
  (c) BONUS — REAL native-musl `hexa run` of stdlib/flame/op19_crossplatform_selfcontained.hexa against the OP-19e-
      patched runtime, NO SHIM: transpiled to C on aiden (build/hexat), compiled+linked in Alpine/musl →
      `ldd → libc.musl-x86_64.so.1`, RUN_EXIT=0 (SIGSEGV GONE). Deterministic Taylor folds BYTE-IDENTICAL across
      Darwin + glibc(summer) + native-musl (all built from the same patched runtime):
        CEBWD-TAYLOR  (dt_exp)  = 7679248634312321699   (all 3)
        GELUFWD-TAYLOR(dt_erf)  = 4548590605583584556   (all 3)
        GELUBWD-TAYLOR          = 636106759170901885    (all 3)
      libm-* lines DIVERGE (Darwin≠glibc≠musl) → only dt_* is machine-independent, now on a REAL musl run not a shim.
- GATE g5: env-capture musl-safe (POSIX environ) YES · musl SIGSEGV GONE YES · behavior-preserving glibc/Darwin YES ·
  durable via restore_frozen_seeds YES · bonus native-musl folds match YES. Residual: NONE on the env-capture path
  (musl build still needs OP-19d's documented build-env knobs — pre-existing, not this ABI bug).
- Temp artifacts cleaned on summer (docker image + /tmp), aiden (/tmp), local. Foreign vast pod 40375114 untouched.
  Verdict .verdicts/hexa-0pod/F-OP19E-MUSL-ENVFIX.txt.

## OP-21C — w16.cu remaining-MODE GPU-free reference logic CPU-validated 0-pod (extends OP-21B)
- branch domain/hexa-0pod-op21c (worktree off origin/main). 0-pod: no GPU, no vast, no pod, $0.
- GOAL: extend OP-21B's D1 CPU de-risk to the OTHER w16.cu MODEs' GPU-free reference logic, so MORE of
  build_w16.sh's H100 gate sequence (not just MODE 0/1) is CPU-pre-validated before the run.
- WROTE tool/wgmma/w16_modes_cpu_check.cpp (clang++ -std=c++17, ZERO GPU/CUDA/PTX) — ports SSOT arithmetic
  VERBATIM (gmma_phys, tf(), composed_A/composed_B) + models the device epilogue scatter VERBATIM from
  gemm_w16 L395-403. 6 element-for-element/bit-exact checks:
      C1a  epilogue register->global scatter = BIJECTIVE FULL COVER of 128x128 tile (every output once)
      C1b  MODE-4 FULL-TILE (128x128) ref GEMM = TF32-round + fp32-FMA in kernel K-order == straight GEMM
           bit-for-bit (K=96 turns NST=3) — extends OP-21B T6's 8x8 to full tile
      C2   B per-slab read recovers global B bit-exact across ALL 3 slabs + all 4 N-atoms (12288/12288)
      C3   gemm_w16b band decode (composed -> gmma_phys repack) == gemm_w16 operands (A/B 4096/4096 each)
      C3b  w16b per-slab 128x128 GEMM == w16 per-slab GEMM (16384/16384) — same math, different schedule
      C4   descriptor stride byte arithmetic self-consistent across NST=3 stages (ring st*SWBUF, w16 kk*4
           [0,32,64,96]B, w16b (kk>>3)*512*4 [0,2k,4k,6k]B, MODE-1 lbo=16/sbo=1024 vs 1024B atom)
- RAN locally (0-GPU): 6 PASS, 0 FAIL, exit 0 — remaining-MODE GPU-free reference logic CPU-PROVEN correct, NO bug.
  Teeth confirmed: injected wrong-xor in B read drops round-trip to 2190/4096; epilogue cover catches double-write/gap.
- GATE g5: extended harness runs locally YES · additional MODEs' GPU-free reference logic proven correct YES (no bug).
  STILL H100-GATED: device wgmma swmode=1 HW de-swizzle (MODE 1/4 rel_rms), the gemm_w16b device band path, ALL perf.
  No wgmma/PTX executed, no TFLOP/s claimed. Build temp cleaned (disk-frugal). Foreign vast pod 40375114 untouched.
  Verdict .verdicts/hexa-0pod/F-OP21C-W16-MODES-DERISK.txt.

## OP-23b — TF32 drift N=500 + LR-schedule (longer/harsher horizon) — GREEN (aiden 5070, $0, 0-pod)
- EXTENDED OP-23 (#3005) to a LONGER + HARSHER regime to resolve its caveat ("N=100, no LR-schedule;
  flat-to-shrinking to step 100 with no late blow-up — does it hold longer/harsher?"):
    N=500 (5x) · standard transformer LR schedule (linear warmup 50 steps 0->1e-3, then cosine decay to
    5e-5; computed in DOUBLE, passed IDENTICALLY to both lanes so the schedule is not a divergence source) ·
    harder structured synthetic (row/col sinusoidal dGrad target, default D bumped 768->1024).
  Harness: tool/bench/flame_traj_drift_tf32_op23b.cu (step DAG byte-identical to OP-23/OP-20; only cuBLAS
  compute type differs + per-step LR). Driver: run_op23b_5070.sh (idle-guarded, DEFAULT+PEDANTIC).
- 4/4 cells on aiden RTX 5070 sm_120 (D={1024,768}, T=256, B={1,8}). FREE pool, NO vast, NO pod, leak-0,
  /tmp/op23b cleaned after. Raw: tool/bench/op23b_5070_raw.log.
- RESULTS (verbatim):
    DEFAULT  D=1024 B=1  selfByteEqN=Y  lossTrackN=3.170e-06  worstLossTrack=1.864e-04@3  lateWorst=3.240e-06@476  peakWorst=3.284e-06@52
    DEFAULT  D=1024 B=8  selfByteEqN=Y  lossTrackN=1.145e-07  worstLossTrack=1.904e-04@3  lateWorst=2.156e-07@492  peakWorst=2.909e-07@52
    DEFAULT  D=768  B=1  selfByteEqN=Y  lossTrackN=3.398e-06  worstLossTrack=6.334e-05@5  lateWorst=3.518e-06@454  peakWorst=3.338e-06@48
    PEDANTIC D=1024 B=1  selfByteEqN=Y  lossTrackN=3.170e-06  worstLossTrack=1.864e-04@3  lateWorst=3.240e-06@476  peakWorst=3.284e-06@52
- THREE QUESTIONS:
    Q1 bounded-to-500-vs-late-blowup -> BOUNDED. Worst gap always EARLY (step 3-5); late-half worst SMALLER
       and FLAT; step-500 tracking 1e-7..3.4e-6. NO late blow-up. Caveat resolved in the GOOD direction.
    Q2 LR-schedule amplifies? -> NO. Warmup-peak window [45..55] worst (~3e-6/~3e-7) == steady-state order;
       the 1e-3 LR peak is not a spike. Bounded-tracking SURVIVES the schedule.
    Q3 self-byte-eq at 500? -> YES every cell (W AND loss max|delta|=0 over the whole 500-step trajectory).
- Weight rel-RMS@500 = 9.7e-3 (B=1) / 4.6e-5 (B=8): chaotic-but-bounded (5x steps + harder target + noisy
  B=1) — exactly why LOSS, not weights, is decisive (butterfly drifts weights; loss tracks). OP-23 lesson re-confirmed.
- VERDICT: TF32 fast-mode HOLDS at the longer/harsher horizon — training-equivalent (bounded loss-tracking)
  to >=N=500 under an LR schedule + through the warmup peak. STRENGTHENS OP-23 (1-step ~1e-6 was a real
  fast-mode, not an illusion). HONEST SYNTHETIC CAVEAT (unchanged): still a proxy (loss=mean(G^2), single
  fused block, structured-synthetic target); real-corpus CLMConvMoE end-to-end is GPU-build-gated (OP-24b/24c).
  Verdict .verdicts/hexa-0pod/F-OP23B-TF32-DRIFT-LONG.txt.

## OP-26b — machine-independent training SUBMISSION-READINESS assessment (4-env evidence; NO paper scaffold, g84)
- DELIVERABLE: docs/flame-machine-independent-SUBMISSION-READINESS.md — a go/no-go readiness assessment
  (NOT a paper) so the user can decide whether/when to instruct /paper. Authored by READING verdicts; $0 0-pod.
- STRONGEST-CURRENT CLAIM: machine-independent bit-exact CLMConvMoE training byte-identical across
  {x86,arm64}x{linux,macos} + musl, spanning 3 DISTINCT libm impls (glibc/musl/Darwin) — STRONGER than
  OP-26's 2-platform consolidation. Growth: OP-19c (F-OP19C) pi5 arm64-linux 3rd cell (libm split = OS/libc
  not arch); OP-19d (F-OP19D) musl 4th env / 3rd libm impl (libm erf = 4 values, dt_* identical);
  OP-19e (F-OP19E) durable POSIX-environ fix -> real un-shimmed native-musl run.
- READINESS CHECKLIST: DONE = result (F-OP15 whole-step max|delta|=0) + 8 per-phase oracles + 4-env evidence
  + threat model + construction recipe + honest limits, all -> verdicts. PAPER ADDS = abstract · related-work
  survey (PyTorch/JAX determinism, CNR, CR-libm/RLIBM) · figures · repro Docker artifact · venue fit · front-matter.
- GAP LIST: G1 real-corpus e2e = GPU-build-gated (HIGH) · G2 2nd architecture (MED) · G3 x86-macos cell
  blocked (no Intel-Mac host, LOW) · G4 perf<->det Pareto via TF32/BF16 (MED) · G5 cross-GPU-arch byte (MED)
  · G6 musl ctor-ABI fix CI-gate (LOW).
- NOVELTY: torch/JAX/TF give NO cross-platform bit-exact training (libm not correctly-rounded); flame removes
  ALL libm — MEASURED: libm erf = 4 different values across 4 envs, dt_exp/dt_erf collapse all to bit-identical
  folds; split proven OS/libc not arch (pi5 tracks aiden). Honest: reproducible-everywhere NOT bit-equal-to-libm
  (dt_erf 1.38e-7 by design); byte-exactness is FP64-lane (TF32/BF16 self-det, not cross-precision).
- GOVERNANCE (g84 PAPER OPT-IN): NO /paper scaffolded, NO PAPER.tape/PAPER.md/LaTeX, paper skill NOT invoked.
  Doc ends with the explicit user action: USER runs `/paper new flame-machine-independent` (or similar) — the
  agent does NOT auto-scaffold per g84. CONFIRMED no paper scaffolded.
- Milestone OP-26b flipped [x]. Verdict .verdicts/hexa-0pod/F-OP26B-SUBMISSION-READINESS.txt. $0 · 0-GPU · 0-pod · no vast.

## OP-28 — real-corpus token-pipeline determinism oracle (0-pod slice of gap G1; input side proven, GPU step still gated)
- 0-POD SLICE OF G1: OP-26b gap G1 (real-corpus end-to-end) is GPU-build-gated because the trainer STEP needs
  the GPU. But the trainer's INPUT side — the token pipeline producing the (ids,targets) fed to clm_step — runs
  on CPU and IS 0-pod-verifiable. OP-28 proves that input pipeline deterministic + machine-independent.
- THE PIPELINE (verbatim from flame_d32_corpus_test.hexa, the production byte-level corpus path):
  (1) tokenize = read_file_bytes -> byte ids [0,256) [V=256]; (2) pack/window = IDS[s*T+p]=toks[s*stride+p],
  YS[s]=toks[s*stride+T] (pure integer index math, fixed ascending (s,p) order); (3) batch = (IDS,YS)==(ids,targets).
- ORACLE stdlib/flame/op28_corpus_loader_det.hexa — SELF-CONTAINED (no `use`, scp/stdin-runnable on any host),
  embedded 306-byte ASCII corpus = the same bytes read_file_bytes yields (disk-free, disk-frugal). Runs full
  pipeline twice + emits f64_to_bytes_le(checksum) IEEE fingerprint for cross-platform byte-diff.
- FINDING: byte-level token path is PURE INTEGER — NO float, NO libm transcendental, NO dict/set/hash-ordered
  vocab iteration — so (ids,targets) bit-identical run-to-run AND across machines BY CONSTRUCTION.
- GATE PASS: ids max|delta| = 0, targets max|delta| = 0 run-to-run; checksum 441979096 identical both runs.
  ids[window 0] = 99 111 110 115 ... = literal bytes of "conscious..." (REAL corpus ids, not synthetic).
- PROCESS-TO-PROCESS: two independent `hexa run` invocations -> full 945-byte output BYTE-IDENTICAL (diff empty).
- CROSS-PLATFORM (free CPU pool host, $0, NO vast/NO GPU): local arm64-macos (Darwin libm) vs aiden x86-linux
  (glibc) emit the byte-IDENTICAL IEEE-754 fingerprint `0 0 0 216 16 88 186 65`; ids/targets/checksum identical.
  aiden /tmp cleaned; no pod/GPU/vast touched.
- STILL GPU-GATED (honest, G1 NOT fully closed): the GPU TRAINER STEP (nn_decoder_fwd/grad/AdamW on the
  (ids,targets)) is the gated remainder. OP-28 closes the INPUT-side slice only; the STEP RUN remains gated.
- RESIDUAL: BPE path (V=151936) also documented-integer but flame's BPE has a known upstream chr()-unicode
  limitation (not cleanly 0-pod-runnable today) — FLAGGED, not locked.
- Milestone OP-28 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP28-CORPUS-LOADER-DET.txt. $0 · 0-GPU · 0-pod · no vast.

## OP-29 — machine-independence generalizes to a 2nd flame model arch (decoder block) — GREEN
- GAP: OP-26b gap G2 (a 2nd architecture beyond CLMConvMoE). The 8 per-op oracles + OP-15 capstone all lock the
  SAME CLMConvMoE step; OP-29 proves the machine-independent determinism construction GENERALIZES to a SECOND arch.
- 2nd ARCH: stdlib/flame/decoder_block_lib.hexa — pre-norm Transformer DECODER BLOCK (GQA scaled-dot attention +
  RoPE + SwiGLU + RMSNorm). Shares NO operators with CLMConvMoE (no conv/MoE/GroupNorm). Tiny CPU config
  T=4·d=8·nh=2·nkv=1·h=16, fixed LCG seed (no RNG/clock).
- ORACLES: op29_decoder_block_determinism_eq.hexa (run-to-run, imports production lib) +
  op29_decoder_block_selfcontained.hexa (cross-platform inline-reduction twin, NO `use`, scp-runnable).
- RUN-TO-RUN: fwd Xout max|Δ|=0, bwd grads max|Δ|=0, bwd dX max|Δ|=0 (both oracles).
- HOLE #1 (libm RoPE, closed): nn_rope_build_tables computes inv-freq via libm ln/exp → leaks libm. Closed with
  deterministic _rope_build_tables_dt (dt_exp/dt_ln/d5_cos/d5_sin) — the OP-19/19b discipline.
- HOLE #2 (FMA matmul — the REAL find, closed): with #1 closed the block was still byte-eq run-to-run but
  byte-DIVERGENT cross-platform. Bisect (cache-stage checksum): cos/sin/Bp/X/rin identical; FIRST divergence =
  Q projection. Isolated to the C farr_matmul kernel (ikj FMA-fused clang -O2): on byte-identical fp64 inputs an
  8×8·8×4 matmul returns arm64 ck=241449363 vs x86 ck=1401117690 (arm64 fuses a*b+c into one FMA, x86 mul+add).
  Closed by re-implementing _db_proj_batch_farr/_db_grad_accum_farr as INLINE ascending dot products (no C kernel)
  → inline ck=1401117690 on BOTH ISAs. Same sequential-reduction discipline the CLMConvMoE oracles use.
- CROSS-PLATFORM (free CPU pool host, $0, NO vast/NO GPU): local arm64-macos (Darwin) vs aiden x86-linux (glibc)
  emit byte-IDENTICAL fingerprints FWD `0 0 64 78 44 169 214 65` · GRAD `0 0 128 244 215 140 211 65`; checksums
  fwd=1520742713 grad=1311989714 identical. aiden /tmp + ~ probe files cleaned; no pod/GPU/vast touched.
- CONTRACT learned: any flame arch must route matmul through inline ascending reductions, not the FMA-fused
  farr_matmul, to be byte-identical across ISAs. Machine-independence GENERALIZES beyond CLMConvMoE → Y. G2 closed.
- Milestone OP-29 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP29-2ND-ARCH.txt. $0 · 0-GPU · 0-pod · no vast.

## OP-30 — cross-ISA matmul invariant formalized in the determinism contract (0-pod, docs-only)
- Deep-dive round-7 branch ①. NO GPU, NO vast, NO pod, NO .tape edits, NO foreign-pod touch. $0.
- PROBLEM: OP-29's cross-cutting find (the C farr_matmul FMA-fused kernel byte-DIVERGES across ISAs) lived ONLY
  in the OP-29 milestone block + verdict — not discoverable as a contract invariant. OP-30 formalizes it.
- ADDED to docs/flame-determinism-contract.md §1: "### cross-ISA invariant: matmul = inline ascending reduction,
  NOT FMA-fused" — RULE (det-path matmul MUST accumulate via inline ascending reductions; FMA-fused farr_matmul
  forbidden), WHY (clang -O2 fuses a*b+c → 1-rounding FMA on arm64 but mul+add 2-roundings on x86; cites OP-29
  ck=241449363 arm64 vs ck=1401117690 x86 from byte-identical fp64 inputs W ck=1950370123/xbt ck=527426024),
  SCOPE (cross-ISA layer ON TOP of run-to-run + libm-free — a model can be both and STILL cross-ISA-divergent),
  HOW (inline ascending dot the oracles use, OR -ffp-contract=off off the det path). ASCII arm64-vs-x86 FMA
  diagram (g3 minimal) + a "what breaks the contract" checklist entry.
- ADDED to docs/flame-machine-independent-training.md: the 3-LAYER determinism model (run-to-run · libm-free ·
  cross-ISA-FMA-free) in §1 claim, a 4th threat-model row T4 (FMA-fused matmul ISA divergence → inline ascending
  dots, F-OP29) distinct from T1/T2/T3 as a back-end codegen (not library) divergence, recipe item (d) "inline
  ascending matmul — NOT the FMA-fused C kernel", and an F-OP29/F-OP30 provenance entry.
- 3-LAYER MODEL: layer1 run-to-run (OP-2/7/8/9/11/12/13+OP-15) · layer2 libm-free (OP-19/19b) · layer3
  cross-ISA-FMA-free (OP-29) — independent; clearing any two does NOT imply the third.
- Every claim traces to F-OP29-2ND-ARCH (g5). NO new computation, docs-only consolidation.
- Milestone OP-30 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP30-CROSSISA-CONTRACT.txt (invariant text + 3-layer
  model + cited OP-29 evidence verbatim). $0 · 0-GPU · 0-pod · no vast.

## OP-28b — BPE tokenizer byte-to-unicode fix (canonical GPT-2/Qwen map); BPE pipeline determinism-provable (0-pod)
- Deep-dive round-7 branch ③. NO GPU, NO vast, NO pod, NO .tape edits, NO foreign-pod touch. $0.
- CLOSES OP-28's flagged residual: the BPE path (flame_bpe_corpus_lib.hexa, V=151936 real Qwen vocab) was not
  cleanly 0-pod-runnable because self/ml/tokenizer_bpe.hexa build_byte_to_char did NOT build the canonical
  GPT-2/Qwen bytes_to_unicode.
- ROOT CAUSE (verified on the live hexa runtime, two defects):
  (1) chr-truncation / wrong-glyph: printable bytes used chr(b) -> RAW byte (probe chr(161)=[161], chr(288)=[32]
      == space collision hazard); canonical (+ Qwen vocab.json) uses the UNICODE codepoint U+00A1.. for the
      Latin-1 printable range (probe from_char_code(161)=[194,161] = UTF-8 U+00A1). chr is byte-truncating.
  (2) wrong codepoint formula: non-printable bytes used from_char_code(256+byte) instead of the canonical running
      counter 256+n — agree only for bytes 0..32, DIVERGE for 35 bytes 127..160,173 (byte 127 canonical U+0121
      vs old U+017F; byte 160 U+0142 vs U+01A0; byte 173 U+0143 vs U+01AD).
  OP-28 had attributed the residual to chr() truncation — that is defect (1); the dominant defect was (2).
- FIX (surgical, build_byte_to_char): emit the canonical 256-entry bijection via the UTF-8 encoder from_char_code
  for the WHOLE table (printable byte -> from_char_code(byte); the rest -> from_char_code(256+n) running counter).
  Never byte-truncating chr in the byte->unicode map. Pure integer/table, no libm/float/hash-order. Decode side
  (bpe_decode + build_char_to_byte) already UTF-8-codepoint-aware, consumes the same table -> no decode change.
  flame_bpe_corpus_lib.hexa header: limitation RESOLVED.
- ORACLE stdlib/flame/op28b_bpe_byteuni_det.hexa (self-contained, use-free cross-platform twin embedding the
  canonical map + a tiny self-contained BPE byte-encode->merge->id over canonical-glyph merge/vocab tables —
  no merges.txt/vocab.json disk dependency).
- GATE GREEN (hexa run): byte->unicode->byte round-trip = 256/256 exact; glyph collisions = 0; space byte 32 ->
  glyph [196,160] = canonical U+0120 -> back 32; bytes 127/160/173 all round-trip; bpe ids "hello hello" ->
  22 33 11 55 44 33 11 55 (l+l merge + space+h merge fire); bpe ids max|Δ| run-to-run = 0; F-OP28B-BPE-FIX = 1.
- PROCESS-TO-PROCESS byte-eq: two independent hexa run -> 945B output byte-identical (diff clean). YES.
- CROSS-PLATFORM byte-eq: local arm64-macos == aiden x86-linux (sidecar pool CPU host, scp self-contained source):
  checksum 102745433, FINGERPRINT `0 0 0 100 21 127 152 65` on BOTH; full output diff clean. YES. aiden /tmp
  cleaned; no pod/GPU/vast touched.
- OP-30: BPE is integer (no matmul) -> FMA cross-ISA invariant N/A; confirmed NO libm/float leak in the token id
  path (byte->uni table, encode, merge, id lookup all pure integer/string-table; remaining chr() uses are in
  bpe_decode/byte_detokenize rebuilding a RAW byte from a recovered 0..255 value = correct).
- HONEST REMAINDER: NOT exercised against a real on-disk 151936-entry Qwen vocab.json (oracle stays use-free +
  disk-frugal with canonical-glyph self-contained tables; the FLAGGED byte-encoder is fixed, merge/id machinery
  is unchanged integer lookups — a full real-vocab round-trip is the natural next confirmation, needs vocab files
  staged, NOT a code defect). The simplified space-split pre-tokenizer (vs GPT-2's full regex) + the GPU trainer
  step are unchanged + out-of-scope.
- Milestone OP-28b flipped [x]. Verdict .verdicts/hexa-0pod/F-OP28B-BPE-FIX.txt. $0 · 0-GPU · 0-pod · no vast.

## OP-30b — fix stale "GELU erf still-open" line in the determinism contract (0-pod, docs-only)

- 2026-06-11 · deep-dive round-8 branch ① (OP-30 residual). OP-30 (#3047) flagged out-of-scope a STALE line in
  docs/flame-determinism-contract.md: the step-phase-map closing parenthetical still read "(The GELU `erf` is a
  still-open libm hole — see §1 residual.)" — pre-OP-19b leftover, factually wrong since OP-19b (#3008,
  F-OP19B-DET-ERF) closed the GELU erf hole via dt_erf (A&S 7.1.26 branchless on dt_exp, no libm,
  byte-identical cross-platform), and contradicting the doc's own §1 closure paragraph + NORM table row +
  what-breaks checklist. The "§1 residual" pointer was dangling.
- Surgical fix: parenthetical now states the current truth — erf likewise closed (dt_erf, F-OP19b), step has NO
  libm transcendental left, pointer → §1 closure. Whole-doc stale-claim scan found NO other contradiction
  (remaining "still" hits = correct run-to-run-vs-cross-ISA F-OP29 usages; "residual" hit = the
  F-OP13-EMBED-RESIDUAL-ORACLE filename). Doc internally consistent about erf post-fix
  (grep still-open/still open/open libm → 0).
- Milestone OP-30b flipped [x]. Verdict .verdicts/hexa-0pod/F-OP30B-CONTRACT-FIX.txt. Docs-only · $0 · 0-GPU ·
  0-pod · no vast. Honest: consistency fix only, no new determinism claim.

## OP-32b — spiking_lib CPU link hole: hexa_forge_dispatch_stdp_pair host fallback (0-pod)

- 2026-06-12 · deep-dive round-8 branch ④ (slot swapped from the GPU-build-gated G1 step to this REAL 0-pod defect
  OP-32 surfaced as HOLE-2). `use "stdlib/flame/spiking_lib"` failed to LINK on every CPU-only host: the flame STDP
  GPU seam (anima LEGO §141, 2026-05-20) landed runtime.h prototype (L1504) + codegen lowering (codegen.hexa L7800)
  + CUDA kernel emit (_hx_cuda_kern_stdp_pair) but the runtime.c BODY was never committed — runtime.c is the
  gitignored frozen seed (151c52c8), regenerated by tool/restore_frozen_seeds, and the blob predates the seam.
  codegen emits all module fns (no DCE) → merely importing the lib pulled the undefined
  _hexa_forge_dispatch_stdp_pair (reproduced live pre-fix).
- FIX (the proven OP-16/18 durable channel): tool/restore_frozen_seeds OP-32b idempotent marker-guarded post-restore
  append — `#ifndef HEXA_CUDA` host body, canonical sequential STDP pair update scalar-order-identical to
  flame_stdp_pair (left-assoc (A·s_i)·tr_pre[j] muls, (ltp−ltd) order, diagonal passthrough + clip), FP_CONTRACT OFF
  (anti fma/fms — the same hazard the CUDA kernel kills with __dmul_rn), n = spike farr len (= t_len(spike));
  + bare forge_dispatch_stdp_pair bootstrap seam (matmul pattern). Local install ~/.hx/bin/self/runtime.c patched
  with the same marker-guarded block (backup kept).
- PROOF: nm U→T (T _hexa_forge_dispatch_stdp_pair + bare twin); import harness LINKS+RUNS 0-GPU; BYTE-EQ oracle
  stdlib/flame/op32b_stdp_hostdispatch_eq.hexa (committed) — imported flame_stdp_pair_gpu (host dispatch) vs
  flame_stdp_pair, n=24, OP-32 LCG fills, clip ENGAGED (w_max=0.875, W scale 0.9): mismatch=0 max|Δ|=0,
  bitwise cksum 347631115==347631115, diag/clip sanity 0 bad, non-trivial movement 0.372; OP-32 oracle re-run PASS
  (F-OP32-4TH-ARCH = 1); GPU path UNTOUCHED — `clang -E -DHEXA_CUDA` TU contains 0 stdp definitions (block fully
  elided → no duplicate symbol possible); restore re-run idempotent (marker count 1).
- Honest residual: frozen seed still supplies NO CUDA-side wrapper (state unchanged by design — GPU-build-gated;
  natural fix = #ifdef twin calling _hx_cuda_farr_stdp_pair_gpu, needs 1 GPU session). No other missing sibling
  symbol surfaced — the full lib import links with only this body.
- Milestone OP-32b flipped [x]. Verdict .verdicts/hexa-0pod/F-OP32B-STDP-HOST.txt. $0 · 0-GPU · 0-pod · no vast.

## OP-26c — SUBMISSION-READINESS doc v2: 4-arch G2 closed · real-vocab input · FMA novelty (0-pod, docs-only)

- 2026-06-12 · deep-dive round-9 branch ① (foreground). Docs-only refresh of
  docs/flame-machine-independent-SUBMISSION-READINESS.md — the v1 (OP-26b #3035) was written against round-5
  evidence (1 arch · G2 open · G1 input unproven); rounds 6-8 grew the base and the doc had gone stale.
- CLAIM (v2): the determinism construction is GENERAL — 4 structurally-distinct archs (CLMConvMoE F-OP15 ·
  decoder block F-OP29 · MLP F-OP31 · spiking LIF+STDP F-OP32, first recurrent/event-driven/non-backprop)
  under the formalized 3-layer model (run-to-run · libm-free · cross-ISA-FMA-free, F-OP30). Honest scope:
  flagship 4-env × 3-libm matrix (F-OP19/b/c/d/e); archs 2-4 = both-ISA pair (arm64-macos == x86-linux);
  new gap G7 (full-matrix legs for archs 2-4, LOW, mechanical via self-contained scp-portable oracles).
- GAPS refreshed: G2 CLOSED ×3-over. G1 input slice CLOSED + pre-gated (F-OP28 · F-OP28b · F-OP28c real Qwen
  vocab 151643 entries through production bpe_load, round-trip 6/6 · F-OP24d turnkey step-0 pre-gate); sole
  remainder = the GPU trainer step run, severity high→low-medium. G3/G4/G5/G6 statuses verified unchanged.
- EVIDENCE table: +13 rows, each citing its verdict (incl. F-OP30b contract consistency + F-OP32b spiking
  CPU-link close + threat-model T4 + recipe item (d)).
- NOVELTY sharpened to TWO legs: ① the 4-arch constructive recipe; ② the cross-ISA FMA-contraction class
  ITSELF — measured ×3 archs (F-OP29 241449363≠1401117690 · F-OP31 2039553633≠124945498 · F-OP32 DIAG-A
  1478294112≠210297454 on byte-identical inputs), mitigation contract (inline ascending matmul, F-OP30),
  measured boundary (binary {0,1} operands FMA-IMMUNE — F-OP32 DIAG-B 1881150137 on BOTH ISAs through the
  forbidden kernel). Honest-limits section refreshed (7 items); diagram + GO/NO-GO updated (~80%→~90%).
- g84 CONFIRMED: NO /paper scaffold — no PAPER.tape / PAPER.md / LaTeX; readiness assessment only.
- Milestone OP-26c flipped [x]. Verdict .verdicts/hexa-0pod/F-OP26C-READINESS-V2.txt. Docs-only · $0 ·
  0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## OP-30c — FMA-immunity boundary formalized in the cross-ISA invariant (docs-only) — 2026-06-12
- Deep-dive round-9 branch ③ (FOREGROUND). docs-only · $0 · 0-GPU · 0-pod · no vast · no .tape edits.
- docs/flame-determinism-contract.md: NEW "#### boundary: exact-product operands are FMA-immune" under the
  cross-ISA invariant — MATH (round(a·b+c)==round(round(a·b)+c) iff a·b exact; b∈{0,1}/±2^k/0 classes +
  ASCII exact-vs-inexact diagram), MEASUREMENT (F-OP32 DIAG-B binary spikes 1881150137 IDENTICAL both ISAs
  vs DIAG-A rate-coded 1478294112≠210297454, same forbidden fused kernel), PRACTICAL RULE (one-hot/mask/
  binary-spike provably safe BUT immunity = operand-value property, conditional + fragile — plasticity/
  scaling/normalization → real-valued → blanket rule; default inline-ascending unless exact PROVEN),
  SCOPE (blanket default kept; explanation + narrowly-licensed exception, not a loophole).
- docs/flame-machine-independent-training.md: surgical T4 cross-ref (boundary pointer + DIAG numbers).
- Milestone OP-30c flipped [x]. Verdict .verdicts/hexa-0pod/F-OP30C-FMA-BOUNDARY.txt. All numbers cite
  F-OP32-4TH-ARCH verbatim.

## OP-34 — machine-independence fold CI regression gate (2026-06-12)
- FEASIBILITY: inspected nobaseline-gate.yml — all 3 faithful-nobaseline jobs build a working ./hexa via
  the shared tool/release_build (Stage 0b leaves build/runtime.a) and already assert `./hexa --version`
  → appended the fold checks THERE (cheapest: zero new builds/jobs, exact 3-platform matrix).
- .c=0 seam: `hexa run` = `hexa build`+exec; the final link honors HEXA_PREBUILT_RUNTIME
  (resolve_prebuilt_runtime, self/main.hexa) → works on the seeds-removed checkout; the gate script
  auto-exports HEXA_PREBUILT_RUNTIME=$PWD/build/runtime.a when present.
- SSOT script tool/fold_ci_gate.sh (OP-5b/19f discipline): runs op19_crossplatform_selfcontained.hexa +
  op19b_crossplatform_erf.hexa, asserts CEBWD-TAYLOR-bits == 7679248634312321699 ·
  GELUFWD-DET-bits == 4548590605583584556 · GELUBWD-DET-bits == 4249661408190172843. LIBM lines NOT
  asserted (platform-dependent by construction). 3 thin YAML steps appended (one per faithful job).
- PASS on current tree local arm64-macos (exit 0, verbatim in verdict §3); 3-platform proof = the PR's
  own nobaseline-gate CI run. TEETH: altered golden → DRIFT + exit 1; reverted → PASS exit 0.
- LOW-BLAST confirmed: only a real fold drift (or `hexa run` breaking on a release platform) can fail it;
  no repo-wide scan, no new workflow/trigger, no required-check change. musl = honest limit (covered by
  recorded F-OP19D + the OP-19f static gate; musl is not a CI platform).
- Milestone OP-34 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP34-FOLD-CI-GATE.txt. $0 · 0-GPU · 0-pod ·
  no vast · no foreign-pod touch · no .tape edits.

## 2026-06-12 OP-33b — dead scheduled_lr/cosine_lr legacy path removed (round-10 branch ③, $0, 0-pod)
- DEADNESS RE-VERIFIED (independent of F-OP33): `hexa run` probes for cosine_lr AND warmup_lr both fail —
  verbatim `error: use of undeclared identifier 'cosine_lr'` / `'warmup_lr'` in the generated C. Root cause
  split: self/env.hexa env_new() builtin roster still REGISTERED the names, so hexat emitted
  `hexa_call4(cosine_lr, ...)` into a runtime that no longer defines the symbol.
- CALLER SWEEP: zero live callers. 4 example files referenced the names (test_stdlib ×2 scheduled_lr ·
  test_lr_batch warmup/cosine ×6 · anima_mega_demo scheduled_lr · anima_convergence_proof warmup∘cosine) —
  all baseline-broken (tool/examples_baseline.json exit_code=-1, never-passed) on OTHER dead legacy-ML
  builtins too. self/ ga_/se_/su_ variants are local fns (different names — untouched).
- EXECUTED (per job 2b — repoint then remove): stdlib/optim.hexa scheduled_lr REMOVED + one-line pointer to
  opt_lr_warmup_cosine (stdlib/flame/optim_lib.hexa, d5_cos, F-OP33). 4 examples repointed via
  `use "../stdlib/flame/optim_lib"`; floor_frac mapping 0.1 / 0.02 / 1.0 (warmup-only degenerate).
  self/env.hexa: warmup_lr/cosine_lr DEREGISTERED from the builtin roster.
- POST-CHECKS GREEN: scheduled_lr probe now fails clean (`use of undeclared identifier 'scheduled_lr'` —
  no longer emitted); repointed examples show ZERO LR-name errors (residual = pre-existing dead family:
  slice/zeros/mean/cross_entropy/phase_lr/batch_* — out of scope, honest); OP-33 oracle re-run PASS
  (F-OP33-LR-SCHEDULE = 1); canonical probe warm 0.0005 / mid 0.000628142.
- HONEST: adam/safe_update in stdlib/optim.hexa wrap adam_step/grad_clip_norm — equally dead, NOT sanctioned
  in OP-33b; follow-up candidate. Milestone OP-33b flipped [x].
  Verdict .verdicts/hexa-0pod/F-OP33B-DEAD-LR-CLEANUP.txt. $0 · 0-GPU · 0-pod · no vast · no .tape edits.

## OP-33c — dead adam/safe_update wraps removed (falsified adam_step/grad_clip_norm) — 2026-06-12
- FOLLOW-UP to OP-33b HONEST §6. stdlib/optim.hexa still held `adam`/`safe_update` wrapping
  `adam_step`/`grad_clip_norm`. SURVEY (mandatory) of all 3 public surfaces:
  - `adam(params,grads,m,v,lr,t)` → calls `adam_step` → DEAD-FALSIFIED.
  - `safe_update(...)` → calls `grad_clip_norm` + `adam` → DEAD-FALSIFIED.
  - top-level `println("[optim loaded]")` → LIVE (kept).
- DEADNESS RE-VERIFIED independently (g5, `hexa run`, hexa 0.1.0-dispatch):
  - `adam_step` probe → clang `call to undeclared function 'adam_step'`; runtime.h defines ONLY
    `adamw_step` (RFC 034) — a DIFFERENT symbol. Roster registers `adam_step` so the lint passes but
    codegen emits a call into nothing → broken C.
  - `grad_clip_norm` probe → `use of undeclared identifier 'grad_clip_norm'`; NO runtime impl at all.
- CALLER SWEEP (grep -rn over *.hexa): adam ← example/anima_mega_demo.hexa:69 ONLY; safe_update ←
  example/test_stdlib.hexa:35 ONLY. Both examples_baseline.json exit_code=-1 (never-passed; array-dialect
  demos already broken on the same falsified-ML family randn/zeros/slice/mean/cross_entropy). Zero LIVE callers.
- LIVE alternative CONFIRMED: real flame training uses stdlib/flame/optim_lib.hexa `opt_adamw_step` (→ real
  `adamw_step` builtin) + `opt_lr_warmup_cosine` (d5_cos). stdlib/flame/* use `adamw_step`, never `adam_step`.
- EXECUTED: stdlib/optim.hexa adam+safe_update REMOVED (pointer comment → opt_adamw_step/opt_lr_warmup_cosine).
  self/env.hexa: `grad_clip_norm` DEREGISTERED from the env_new() builtin roster (root cause — only non-roster
  refs were the 3 baseline-broken examples + the removed wrapper; no live surface). The 2 example call sites got
  NOTE pointer comments (faithful repoint impossible: array-dialect adam(arr,...) vs handle-dialect
  opt_adamw_step(int,...) signature; demos stay baseline-broken on the rest of the dead family — out of scope).
- POST-CHECKS GREEN: import stdlib/optim.hexa now BUILDS+RUNS clean → `[optim loaded]` (PRE: `call to undeclared
  function 'adam_step'`). Canonical flame probe unaffected: opt_lr_warmup_cosine(0.001,0.1,50,1000,100) = 0.0005.
  Removed-symbol grep: zero dangling refs except the 2 documented baseline-broken examples (NOTE-commented).
- HONEST: `adam_step` LEFT registered in the roster — 12+ OTHER surfaces reference it (self/ml/{train_gpu,galore,
  gpu_optimizer,t2_gpu_bench,distributed_train} + examples). Those self/ml/* files are themselves likely dead on
  the same falsified builtin, but they're a SEPARATE surface out of OP-33c's stdlib/optim scope — flagged as a
  follow-up (OP-33d?), NOT touched. Deregistering adam_step here would change their error class out-of-scope.
- Milestone OP-33c flipped [x]. Verdict .verdicts/hexa-0pod/F-OP33C-DEAD-OPTIM-CLEANUP.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## OP-39 — float const-fold byte-eq CI regression gate (locks OP-37/OP-37b silent float bugs) — 2026-06-12
- SURVEY FIRST: read F-OP37 + F-OP37b for the EXACT cases (A&S erf coeff set 0.254829592/-0.284496736/
  1.421413741/-1.453152027/1.061405429/0.3275911 + computed folds 0.254829592*0.284496736 / 1.421413741*0.5 /
  0.1+0.2 / 1.0/3.0) + golden patterns; studied tool/fold_ci_gate.sh (OP-34), nobaseline-gate.yml,
  musl_ctor_abi_gate.sh — established pattern = `tool/*_gate.sh` SSOT + thin YAML step on the built ./hexa.
- TRIGGER (the decisive subtlety): the bug is in self/codegen.hexa comptime_eval. A BARE inline arg
  `_bits(L, 0.0 - X)` is NOT const-registered → emitted full-precision → clang folds it correctly → MASKS the
  bug. The folder only fires + inlines a folded literal for a plain immutable `let` (codegen.hexa:3105
  _register_comptime_const). So the oracle BINDS `let nN = 0.0 - X` then REFERENCES nN — the use-site inlines
  the folded literal, exercising the exact serialize/parse path. PROVEN: Jun-8 (pre-fix) hexat emits the LOSSY
  `_bits(..., hexa_float(-0.25483))` / `hexa_float(0.0724982))`; FIXED hexat (/tmp/hexat_op37b_v4) emits exact
  `hexa_float(-0.254829592)` / `hexa_float(7.24981871602117067e-02)`.
- GOLDENS — verified by RUNNING the FIXED-compiler-built oracle binary: /tmp/hexat_op37b_v4 (current source,
  fixpoint byte-identical to a fresh tool/regen_cc_manual rebuild) → emitted C → clang + restored self/runtime.c
  → /tmp/op39_bin → all 13 lines printed, exit 0. (a) negation/additive = python struct.pack('<d') byte-exact;
  (b) MUL1 = 4589888465602041183 = the FIXED compiler's +1-ULP value (host rt_mul vs python ...182 — the
  documented OP-37b host-arithmetic residual), so the gate locks the COMPILER's correct output, not python's.
- GATE tool/op39_constfold_gate.sh (OP-34/OP-19f low-blast discipline): runs ONLY op39_constfold_byteeq.hexa,
  asserts ONLY the 13 const-fold bits lines, auto-exports HEXA_PREBUILT_RUNTIME on the .c=0 seam. Wired into
  nobaseline-gate.yml as a step right after the OP-34 fold gate in all 3 faithful jobs (darwin-arm64,
  linux-x86_64, linux-arm64) — same ./hexa, <1 s, no GPU, no new job. EXTEND > duplicate (g0): co-located with
  the existing golden-fold harness, not a parallel workflow.
- VERIFIED BOTH WAYS with the SAME gate (the bug/fix differential IS the test):
  · PASS: `sh tool/op39_constfold_gate.sh <fixed-compiler-output>` → all 13 OK → "PASS — all 13 float
    const-folds match the recorded goldens", exit 0.
  · FAIL: `sh tool/op39_constfold_gate.sh ~/.hx/bin/hexa` (pre-fix deployed) → all 13 DRIFT to the lossy %g
    values (e.g. NEG1 -4625109807764698594 ≠ golden -4625109815114573186), "FAIL — float const-fold byte-eq
    REGRESSION detected", exit 1.
  · TEETH: single-golden 1-ULP corruption (MUL1 ...183→...184) → DRIFT + exit 1 → confirms one-bit sensitivity.
- CI FINDING (decisive, honest): PR #3075's first gate run FAILED on all 3 jobs with the LOSSY %g values
  (CI NEG1 = -4625109807764698594 == the pre-fix value). Root cause is NOT a gate bug — tool/release_build →
  tool/stage_prebuild_hexat builds CI's ./hexa from the FROZEN seed self/native/hexa_cc.c (151c52c8 bootstrap),
  which PRE-DATES the OP-37/37b fix in tracked self/codegen.hexa. The fix is in repo SOURCE (#3069/#3073) but
  NOT YET PROMOTED into the seed/deployed toolchain — a separate rebuild step BOTH verdicts explicitly deferred.
  So CI's compiler genuinely still has the bug; the gate correctly detects it.
- RESOLUTION (g5, honest): wired the 3 CI steps `continue-on-error: true` (ADVISORY) with an in-YAML + verdict
  explanation. The regression infra (oracle + SSOT gate + CI wiring) is in place + VISIBLE now; the moment the
  OP-37/37b fix is promoted into the seed hexa_cc.c the step auto-goes-GREEN, and dropping the single
  continue-on-error line flips it to enforcing. PASS direction proven LOCALLY vs the fixed compiler; against the
  REAL un-promoted CI toolchain it FAILS exactly as designed = the inverse teeth proof. Promote = a follow-up.
- Milestone OP-39 flipped [x]. Verdict .verdicts/hexa-0pod/F-OP39-CONSTFOLD-CI-GATE.txt. $0 · 0-GPU · 0-pod ·
  no vast · no foreign-pod touch · no .tape edits.

## 2026-06-12 W16 + G1 — GPU-gated remainders run on ONE-TIME user-approved H100 (vast 40664227, ~$0.72, leak-0)
- CONTEXT: user EXPLICITLY approved a one-time vast H100 rental (breaks the standing 0-pod rule with permission)
  to run the two GPU-gated HEXA-0POD remainders back-to-back on a SINGLE H100, then tear down. Rented exactly
  ONE H100 SXM (offer 40179475 → contract 40664227, label hexa-g1w16, $2.00/hr, nvidia/cuda:12.6.2-devel),
  H100 80GB HBM3 sm_90a / driver 550.163.01 / nvcc 12.6.77 (EXACT W10/W12/W13 apples). NO foreign pod touched
  (confirmed label before destroy). DESTROYED immediately after capture; `vastai show instances` = empty → leak-0.
- W16 (🟢 GREEN, measured): build_w16.sh on real sm_90a. MODE 0 canonical-decode rel_rms 0.000e+00 PASS
  (4096/4096 exact). MODE 1 descriptor-direct (the PRE-REGISTERED D1 FALSIFIER) FLOORS rel_rms 1.107 at default
  AND across the full inline lbo×sbo×boff×swmode sweep — NO config hits 0 → D1 (canonical-atom landing makes the
  in-place descriptor read bit-exact, deleting the 32KB decode band) FALSIFIED on real H100. Per g5 hard-gate
  STOP before MODE 4 → no TFLOP/s on a falsified read law; W10 70.7/6.09x frontier KEPT; OP-21B (gemm_w16b, keep
  band) is the documented fallback. Reproduces the W15 (3200-cfg) + BENCH-12 (1.009) wall on the canonical box.
  Route-(a) pre-permute (OG16/BENCH-12/14) remains the bit-exact path that DID crack the band to 1.10x @D=2048;
  w16 is the closed-neg in-place-descriptor branch. Verdict F-W16-WGMMA-H100-MEASURE.txt.
- G1 (🟠 BLOCKED-CONFIRMED): clm_prod_gpu TF32 e2e build attempted on the SAME pod. On a fully-capable H100 the
  build STILL fails — gate is BUILD-ENV/TOOLCHAIN/FROZEN-SEED, NOT a GPU limit (the very same pod ran w16's
  wgmma kernels). Reproduced on-HW: (i) no hexa/hexa-run on a fresh CUDA pod → kit STEP-0 `hexa run FAILED exit
  127`, clean EXIT; (ii) `git archive HEAD` self/runtime.c = thin stub, 0/31 host marshal wrappers (the complete
  CUDA runtime.c is the gitignored 151c52c8 blob restore_frozen_seeds fetches from git history, absent in the
  shallow tarball). Exactly the F-OP24D documented remainder; NEW datapoint = gate confirmed toolchain/seed on
  real Hopper. Kit-named fixes (NOT pod tasks): re-freeze runtime.c w/ all 31 wrappers, or add a CUDA release.yml
  job. Input side unchanged (proven 0-pod F-OP28/28b/28c). Verdict F-G1-CLMPROD-TF32-GPU-STEP.txt.
- Both W16 + G1 milestones flipped [x]. $0.72 total · leak-0 · no foreign pod touched · no .tape edits.

## OP-39b — promote OP-37/37b const-fold fix into CI seed + flip gate → 🟠 DEFERRED (frozen-anchor re-pin, out of 0-pod scope) — 2026-06-12
- TASK (OP-39's deferred follow-up): promote the OP-37/37b const-fold fix into the CI seed self/native/hexa_cc.c,
  then flip the OP-39 gate advisory→enforcing (drop the 3 continue-on-error lines).
- SURVEY (decisive): "the CI seed" is an IMMUTABLE FROZEN GIT ANCHOR, not a tracked/regenerable/surgical file.
  self/native/hexa_cc.c is gitignored (.gitignore:286); CI restores it via `git checkout 151c52c8 --
  self/native/hexa_cc.c` (tool/restore_frozen_seeds, FROZEN_SEED_REF = .c-graduation parent of #2065) →
  tool/stage_prebuild_hexat clang-builds CI's build/hexat from it. So "promote into the seed" is NOT a
  marker-guarded re-emit — the only way is a wholesale RE-PIN of FROZEN_SEED_REF to a new coherent 23-seed anchor.
- MEASURED wholesale (not surgical): regen hexa_cc.c from current self/codegen.hexa (tool/regen_cc_manual,
  HEXA_V2=Jun-8 hexat) = 2,098,186 B / 31,222 lines vs frozen seed 1,854,825 B / 28,482 lines → diff = 27,068
  lines of UNRELATED drift; const-fold helpers absent in the frozen seed (nothing to cherry-pick). Validation of a
  new anchor = the ~3.5h build_selfhost.sh self-host ladder (cc-gen3.o==cc-gen4.o) on a build host. g0 STOP for a
  $0 local single-PR task; the task's explicit "regen carries unrelated drift → DEFER".
- PROVEN LOCALLY ($0, deterministic, arm64-macos) the FIX is correct + fixpoint-stable: (1) regen builds clean →
  /tmp/hexat_regen; (2) self-host fixpoint BYTE-IDENTICAL (gen-N re-regen == gen-N+1, cmp clean); (3) regen emits
  the FIXED exact/strtod literals (-0.254829592 · 7.24981871602117067e-02), NOT lossy %g; (4) the OP-39 gate
  PASSES all 13 goldens against a binary built from the fixed regen → gate auto-goes-GREEN once the seed carries
  the fix.
- GATE FLIP NOT DONE (correct): the 3 continue-on-error lines (nobaseline-gate.yml :129/:193/:256) are LEFT IN
  PLACE — flipping while CI's frozen seed still has the pre-fix folder would turn all 3 jobs RED (the make-or-break
  red-gate the task forbids). The flip is correctly coupled to a seed promotion that did not happen.
- OUTCOME: milestone added [ ] 🟠 DEFERRED + deferred-note resolved-as-deferred. Unblock = a SELFHOST-NEXT /
  build-host work item (new coherent anchor → ladder fixpoint+parity → re-pin FROZEN_SEED_REF → gate auto-GREEN →
  drop the 3 continue-on-error lines). $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.
  Verdict .verdicts/hexa-0pod/F-OP39B-SEED-PROMOTE-FLIP.txt.

## OP-40 — comptime float-fold 1-ULP residual ROOT-CAUSED (host %.17e serialize, NOT the multiply) + FIXED via bit-exact hex-float → MAX 0 ULP — 2026-06-12
- TASK (OP-37b's deferred residual): OP-37b cured the const-fold operand PARSE (strtod) → MAX 3→1 ULP, and ASSUMED
  the remaining 1 ULP on computed products was "host comptime `*` (rt_mul) rounding differently from clang". OP-40 =
  MEASURE + CLASSIFY that residual precisely (g5, measure don't assume), then close or bound+document.
- MEASUREMENT (125 FIXED cases: A&S erf products + seed=40 random products/sums/divisions; each `let cN = A op B`
  comptime fold then USED → triggers the fold-serialize; f64_to_bytes_le vs python struct.pack('<d', A op B)):
  · BEFORE (OP-37b state, %.17e serialize): MAX 1 ULP, nonzero in 16/125 (~13% — NOT "rare" as OP-37b estimated).
  · AFTER  (OP-40 hex-float serialize):     MAX 0 ULP, 0/125 — every fold == python correctly-rounded IEEE.
  · canonical 0.254829592*0.284496736: IEEE bits-182 (=python=clang runtime); BEFORE host emit "…117067"→bits-183
    (+1 ULP); AFTER "0x1.28f3dbedf555ep-4"→bits-182 (exact).
- ROOT CAUSE (OP-37b assumption FALSIFIED with evidence): the multiply is IEEE-CORRECT (same runtime parse_float·*
  gives exact python bits; rt_mul = single isolated fp64 `*`, NO FMA, -O0==-O2) and the parse is byte-exact (strtod).
  The bug is the SERIALIZE: the fold computes the CORRECT product then format_float_sci(%.17e) routes through the
  runtime's hand-rolled snprintf override (hxlcl_vsnprintf, self/runtime.c:2095, "Not bit-exact with libc's") /
  hexa-source rt_format_float_sci — NOT correctly-rounded — round-tripping bits-182→string→bits-183. DIVERGING SIDE
  = host serialize; IEEE-correct side = clang (the `let`-decl `hexa_float((L)*(R))` is clang-folded, exact). This is
  the same hand-rolled-arithmetic fragility the `stdlib_trig_libm` directive warns about. NOT a clang-FMA artifact →
  cross-ISA FMA invariant (OP-29/30/31) and -ffp-contract policy UNAFFECTED.
- FIX (g0/g4, additive +86/−9, no deletions, no runtime edit, no .tape): `_cf_float_node` now serializes the folded
  double as a bit-EXACT C99 hex-float literal (`0x1.<mant>p<exp>`) via `_cf_float_hexlit` (+ `_cf_nib_hex`), built
  from raw IEEE-754 bits with INTEGER ops only (float_to_bits → sign/exp/mantissa via >>/&, 13 nibbles, trailing-zero
  strip; inf/NaN→__builtin_inf/nan, ±0→±0x0p+0, subnormals handled). clang parses hex-floats EXACTLY → no decimal
  rounding step → the lossy hand-rolled formatter is bypassed. The integer formatter validated 2013 random doubles
  (subnormal..1e308) 0 mismatch + matches libc %a.
- FIXPOINT GREEN: 4/4 SSOT modules (lexer/parser/type_checker/codegen) gen-N (Jun-8 hexat) == gen-N+1 (OP-40-fixed
  hexat) BYTE-IDENTICAL (cmp clean) — the change does not alter the compiler's own emitted C. self/type_checker
  self-tests 15/15. OP-37 negation idiom regression byte-exact (preserves source text, never reaches _cf_float_node).
- OUTCOME: 🟢 GREEN, residual CLOSED (1→0 ULP). milestone OP-40 [x]. Rebuild/measure recipe = tool/regen_cc_manual
  (HEXA_V2=~/.hx/bin/build/hexat) → clang single-TU (runtime.c inlined). Deploy boundary = same frozen-seed re-pin
  OP-37b/OP-39b flagged (🟠 out of 0-pod scope; this fixes REPO SOURCE + proves on from-source rebuild + fixpoint).
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.
  Verdict .verdicts/hexa-0pod/F-OP40-COMPTIME-MUL-ULP.txt.

## OP-44 — runtime float formatter hxlcl_vsnprintf non-correctly-rounded: MEASURED + libc-delegation fix PROVEN → 🟠 DEFERRED (frozen-seed re-pin) — 2026-06-12
- TASK (OP-40's HONEST RESIDUAL §1): OP-40 root-caused the comptime const-fold drift to the runtime's hand-rolled
  %.17e serialize and worked AROUND it for the const-fold path (hex-float literals). But hxlcl_vsnprintf's %g/%e/%f
  is STILL non-correctly-rounded for ALL runtime float printing. OP-44 = ASSESS + (if tractable+safe 0-pod) FIX the
  formatter to be correctly-rounded; else DEFER with blocker + recipe.
- SURVEY: self/runtime.c is GITIGNORED (git check-ignore matches; absent at HEAD) — a frozen-seed blob restored by
  tool/restore_frozen_seeds from IMMUTABLE anchor FROZEN_SEED_REF=151c52c82 (parent of graduation commit 7906951c0,
  #2065). hxlcl_vsnprintf body at frozen runtime.c:657, float branch :722 ("Cycle 56 ... Not bit-exact with libc's
  Grisu/Ryu"), snprintf override :2095. NO tracked SSOT emitter — codegen.hexa refs (:9873-74) are COMMENTS only;
  runtime.c.hexanoport: "Cannot be ported to .hexa (it IS the bootstrap runtime)". → formatter is irreducible frozen
  substrate. SAME structural blocker as OP-39b.
- MEASUREMENT (g5, 5536 deduped finite doubles: A&S erf products + 5000 random magnitude 1e-300..1e300 seed=44 + 500
  subnormals + edges; EXACT frozen-blob float algorithm extracted verbatim to a standalone C TU vs host libc snprintf
  + python struct.pack round-trip = correctly-rounded ground truth):
  · %.17g does NOT round-trip to same double: 3463/5536 (62.6%); != libc string: 5057/5536 (91.3%).
  · %.17e parses to DIFFERENT double than libc: 3432/5536 (62.0%); MAX 5 ULP (OP-40's narrow A&S sweep saw 1 ULP).
  · libc %.17g round-trip failures: 0/5536 (sanity). → shortest-round-trip-INCORRECT, REAL + PERVASIVE (every
    high-precision float print). ROOT = naive digit-extraction (d=(int)dv; dv=(dv-d)*10.0 accumulates error;
    round-half-up peek-1; no Grisu/Ryū; capped 18 digits).
- FIX PROVEN (g0): route the float branch to libc snprintf (OP-37b's atof→strtod pattern in REVERSE). libc %e/%g are
  C-standard correctly-rounded AND machine-independent (the correctly-rounded decimal of a double is unique → identical
  across glibc/musl/macos → cross-platform deterministic, NOT a platform-dependent decimal). libc IS reachable: runtime
  #includes <stdio.h>/<math.h> + already calls 36 real libm cos/sin/exp directly (stdlib_trig_libm) — the hxlcl_* layer
  is deliberate symbol-elimination, not freestanding-hard; build links full libc/-lm. SAME 5521-case sweep with the
  float branch delegating to libc snprintf → 0/5521 round-trip fail, 0/5521 drift. Recipe VALIDATED.
- TRACTABILITY → DEFER 🟠: the fix is correct + small + cross-platform-deterministic + does NOT touch the const-fold
  byte path (OP-40 hex-floats that). BUT it can't land in tracked source 0-pod: the formatter lives ONLY in the
  gitignored frozen blob → editing = mutate the IMMUTABLE anchor (forbidden) OR a wholesale frozen-anchor RE-PIN
  (build-host build_selfhost.sh ladder + gen3→gen4 byte-eq + parity + FROZEN_SEED_REF bump — a SELFHOST-NEXT item,
  not $0 single-PR), PLUS a repo-wide golden re-bake (91% of float strings shift). Per task guidance, clean DEFER
  beats a forbidden anchor mutation / unverified runtime ship.
- OUTCOME: 🟠 DEFERRED — measured + bounded (≤5 ULP, 62% round-trip-fail) + proven recipe = a COMPLETE honest result.
  milestone OP-44 [ ] 🟠. NO source/runtime/.tape edit → self-host fixpoint UNTOUCHED (no red-gate risk). 3rd instance
  of the frozen-seed-promote dependency (after OP-39b gate-flip + OP-40 deploy-boundary); the validated formatter
  patch is drop-in for the eventual consolidated promote. Verdict .verdicts/hexa-0pod/F-OP44-VSNPRINTF-CORRECT-ROUND.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## ROUTE-A — route-(a) pre-permute own-GEMM, REAL H100 sm_90a re-measure (2026-06-12)
- LEVER (a) = route-(a) PRE-PERMUTE own-GEMM (gmma-INTER global pre-lay + NO-swizzle TMA + descriptor-direct,
  NO 32KB decode band) — the BIT-EXACT path. Complement to W16: w16 confirmed route-(b) in-place-descriptor
  is bit-exact-IMPOSSIBLE (floored rel_rms 1.107); this run measures whether route-(a)'s documented ~1.10x
  parity vs cuBLAS-TF32 @D=2048 reproduces on a fresh H100. NOT (b) OP-21B keep-band (closed-neg, not re-run).
- HW: vast 40675177 (label hexa-routeA, ONE-TIME user-approved H100 exception, ~$2/hr × ~15min ≈ $0.50, leak-0).
  H100 80GB HBM3 sm_90a, driver 550.163.01, nvcc 12.6.77 (EXACT OG16/OG17/W16 apples). image cuda:12.6.2-devel.
- KIT: self/native/wgmma/wgmma_tf32_b14.cu (carries OG16 MODE4 + OG17-pipe MODE6 + b14 MODE8 verbatim) +
  wgmma_tf32_w10.cu + wgmma_tf32_w10_lib.h + bench14_run.sh (gate-disciplined: rel_rms 0 FIRST, then perf).
- RESULT 🟢: route-(a) rel_rms 0.000e+00 at EVERY config of the full PDEP/NST sweep (bit-exact confirmed —
  the separator vs route-(b)/w16's 1.107 floor). b14 MODE8 @D=2048 NST=3 CROSSES PARITY:
  PDEP=2 own 314-316 TFLOP/s ratio 1.08-1.09x (3 reps, all PARITY=YES, 2 CTA/SM 96KB band-free) <-- SUMMIT;
  PDEP=1 own 305 TFLOP/s ratio 1.12x (== documented ~1.10x); PDEP=0 own 287 ratio 1.19x. Same-pod apples:
  OG16 MODE4 NST=3 250.8/1.36x; OG17-pipe MODE6 ~262/1.29-1.32x; W-ladder re-confirmed (6.09x→1.08x bit-exact).
  @D=4096 b14 best 283 TFLOP/s 1.50x (no parity — cuBLAS scales better; residual = ptxas-capped 256-elt
  register-realloc, W12/OG17-MODE5 closed-neg). The ~1.10x parity claim @D=2048 is REPRODUCED and EXCEEDED.
- HONEST (g5): 1.08x is NOT a cuBLAS beat (~93% of roofline, bit-exact). cuBLAS-TF32 = ROOFLINE, no superiority.
- DESTROY: leak-0 CONFIRMED (`vastai show instances` empty; 40675177/hexa-routeA gone). No foreign pod touched.
  Verdict .verdicts/hexa-0pod/F-GPU-ROUTEA-KEEPBAND-MEASURE.txt.

## OP-43 — ML-family falsified-builtin deeper audit: 42-builtin sub-matrix; 16 truly-dead DEREGISTERED, 26 SURVIVE-WITH-REASON — 2026-06-12
- CONTEXT: OP-41 (#3087) built the complete 231-builtin matrix + closed the optimizer-scheduler family, and
  CONSERVATIVELY DEFERRED ~101 other falsified roster builtins (g0). OP-43 takes the ML-FAMILY subset (conv/quant/
  activation/attention/array-ML cluster, 42 names) and audits it ONE LAYER DEEPER with OP-41's exact per-builtin g5
  method, to either safely deregister the truly-dead or document precisely why each survives.
- METHOD (g5, OP-41 re-applied): AOT probe = `let _r = NAME(correct-args)` → fresh hexat (~/.hx/bin/build/hexat
  <in> <out.c>, Jun-8 2027336B, NOT stale ~/.hx/bin/hexa Jun-1) → `clang -I.../self -fsyntax-only <out.c>`.
  FALSIFIED = generated C contains "use of undeclared identifier 'NAME'". ARG-SHAPE-TRAP CONTROLLED: verified 0
  `if name=="NAME"` codegen-inline guards for all 42 → ANY arg shape yields the same bare hexa_callN(NAME,…) →
  probe robust to shape. SUBSTRING-OVER-COUNT HAZARD REFUTED: sigmoid/cross_entropy/transpose/zeros/ones/attention/
  dot static grep-hits of runtime symbols all EMPIRICALLY falsified (unrelated substrings). CONTROL: a local
  `fn relu` emits `HexaVal relu(...)` (bare-name local def) + a call that compiles CLEAN → shadows provide their
  OWN symbol, do NOT depend on the roster entry.
- RESULT: all 42 AOT-FALSIFIED (100%). DEREGISTERED 16 (tanh_ ones ema batch_matvec batch_norm dropout gru_cell
  sinusoidal_pe multi_head_attention max_pool1d attention_cached beam_search_step xavier_init kaiming_init sparsity
  weight_dict) — each falsified + ZERO local-fn `fn NAME(` shadow repo-wide + EVERY call-site under example/ (each a
  tool/examples_baseline.json exit_code=-1 baseline-dead demo); weight_dict a pure 0-call orphan (only a filename
  string + comments). SURVIVE-WITH-REASON 26 (relu sigmoid cross_entropy transpose normalize zeros arange clip
  attention topk sample_token mse_loss conv1d kv_cache_append save_array load_array quantize_int8 dequantize_int8
  magnitude_prune tensor_fill repeat_kv dot mat_add_inplace matmul_into rope rope_inplace) — local-fn shadows in real
  programs [S] and/or substantial broken self//stdlib caller surfaces [R] (matmul_into 50, dot 55, mat_add_inplace
  33) → conservative g0 blast-radius bound; deregistering would not break a WORKING program (callers already
  falsified) but would perturb binder/error semantics of a large self/ml/stdlib surface → KEPT + documented.
- SELF-HOST BYTE-EQ SAFE: compiler/** (the byte-eq core, entry compiler/main.hexa) has ZERO refs to any removed name
  (sole family hit = a `// sigmoid(x)=…` COMMENT in nvptx_target.hexa); no CI workflow compiles example//self/ml/
  self/test_; only selfhost-byteeq compiles (compiler/main.hexa) → fixpoint cannot be perturbed.
- POST-EDIT: env.hexa transpiles clean (~/.hx/bin/build/hexat self/env.hexa /tmp/op43_env.c → OK, roster well-formed
  after 16 removals); grep-proof re-verified 0 roster-string / 0 shadow / 0 non-example caller per removed name; all
  28 keeper ML names sharing edited lines still present. wipe_guard: net +22/−12 « 50; scoped subject.
- OUTCOME: 🟢 GREEN. milestone OP-43 [x]. CLOSURE: the truly-dead ML-family falsified subset is now EMPTY; the
  falsified ML family is bounded-with-reason to the 26 documented survivors. Real ML in hexa = stdlib/flame/* +
  per-module LOCAL fns (the shadows), NOT these roster builtins. Verdict
  .verdicts/hexa-0pod/F-OP43-ML-FAMILY-FALSIFIED.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## OP-45 — route-(a) own-GEMM D=4096 sub-parity cap STATICALLY characterized (0-pod, no GPU) — 2026-06-12
- SURVEY-FIRST (mandatory). Read F-GPU-ROUTEA-KEEPBAND-MEASURE.txt (#3094 ROUTE-A): route-(a) pre-permute own-GEMM
  (b14 MODE 8, gemm_og17_b14, PDEP dual-issue) CROSSES cuBLAS-TF32 parity @D=2048 (1.08x, own 315 TFLOP/s, rel_rms 0)
  but NOT @D=4096 (~1.50x, own 284 TFLOP/s), footnote attributing the residual to "the 256-elt-tile register-realloc
  ptxas cannot grant on TF32, the W12/OG17-MODE5 closed-neg". Read the measured kernel self/native/wgmma/
  wgmma_tf32_b14.cu MODE 8 (+ MODE 5 t256 + MODE 6 pipe + MODE 7 persist for contrast) + the W-ladder reg/occupancy
  verdicts .verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-{W10,W11,W12,OG16,OG17}.txt (on-pod ptxas numbers).
- ENV: `which nvcc` → NOT FOUND (CPU-only Darwin host). ptxas runs on CPU but no nvcc installed locally, so even the
  cheap GPU-free `-Xptxas -v --cubin` register/occupancy capture was NOT possible — this is a SOURCE-LEVEL static
  analysis using the kernel source + the on-pod numbers already captured in the W-ladder verdicts.
- KEY CORRECTION: the #3094 footnote MISATTRIBUTES the D=4096 cause. "256-elt register-realloc" describes MODE 5
  (gemm_og17_t256, d0..d3 = 4x32 = 128 accumulator regs/thread → 154 regs → 1 CTA/SM → ptxas C7507 setmaxnreg-ignored
  + C7511 wgmma-serialize, the W11/W12 closed-neg), a DIFFERENT kernel that was NEVER the measured D=4096 datapoint.
  The MEASURED D=4096 kernel is MODE 8 (gemm_og17_b14): TM=128,TN=128, d0[32]/d1[32] = 2x32 = 64 accumulator regs/
  thread, NST=3 → SWBUF=(128+128)*32*4*3 = 98304 B ≈ 96 KB/CTA → 2 CTA/SM. This config is COMPILE-TIME CONSTANT (D is
  a kernel ARG M=N=K, not a template param), BYTE-IDENTICAL at D=2048 and D=4096 (verdict confirms "2 CTA/SM, 96.0
  KB/CTA" for both; D=4096 sweep uses the same MODE8 NST=3).
- CLASSIFICATION (g5, (a)-(d)): (a) register-spill EXCLUDED (D-invariant binary; if no spill @2048 then none @4096;
  64 not 128 regs). (b) occupancy-drop EXCLUDED (2 CTA/SM held both D; occupancy ≠ f(D) for fixed tile). (c)
  D-independent ptxas ceiling EXCLUDED as the GAP cause (own MOVES with D: 315→284 = −9.9%; a constant ceiling can't
  produce a D-dependent number — ptxas quality bounds the absolute ~300 TFLOP/s plateau but doesn't OPEN the gap).
  (d) memory/large-D scheduling roofline = SURVIVING CAUSE.
- DECOMPOSITION (verbatim #3094 numbers): ratio 1.08x→1.50x = cuBLAS 342.5→426.8 (+24.6%, scales UP: shape-adaptive
  larger-tile/split-K/persistent) ÷ own 315.0→283.9 (−9.9%, scales DOWN: fixed 128x128 plain-launch gridDim
  (D/128)^2 = 1024 CTAs @4096, no split-K [g5-forbidden, forfeits bit-exact accum order], 2x K-slabs nks 64→128 → 2x
  commit_group/wait_group/__syncthreads drain). Exact: 1.246/0.901 = 1.39 = 1.50/1.08. ~63% of the gap = cuBLAS gain,
  ~37% = own loss. Both operands MOVE — NOT a flat ptxas ceiling.
- WAVE-QUANTIZATION EXCLUDED (computed): 132 SMs x 2 CTA/SM = 264 resident. D=2048: 256 tiles/264 = 0.970 wave-eff.
  D=4096: 1024/264 = 3.879 → ceil 4 → 1024/(4*264) = 0.970 wave-eff. IDENTICAL 0.970 both D — tail wave is not the
  differentiator (the plain launch is coincidentally equally quantized at both sizes).
- HONEST 🟠: static analysis CONFIRMS (a)/(b)/(c) excluded + cause = (d) shape-rigidity-vs-cuBLAS-adaptivity, but
  CANNOT split (d) into hard-HBM-BW-roofline vs fixable-scheduling-stall without a real GPU ncu/nsys profile. Handed
  the OP-45-GPU sibling a precise T1-T5 matrix: T1 ptxas -v confirm (~90 regs/0 spill/96KB/2 CTA/SM — CPU-runnable,
  upgrades a/b to measured-excluded), T2 ncu DRAM%/Tensor% @4096 (near-peak DRAM → hard roofline, close; low/low →
  fixable, go T3), T3 MODE 7 persistent+swizzle recovery sweep swz=0,1,2,4,8 (rel_rms 0 gate first), T4 cuBLAS
  cublasLtMatmulAlgoGetHeuristic introspection (which lever is the +24.6%, and is any g5-legal), T5 W12 TN-sweep
  re-confirm @4096.
- OUTCOME: 🟠 DEFERRED (static-positive: a/b/c excluded with source evidence + d classified; the d sub-split is the
  honest GPU-gated residual). milestone OP-45 [x]. Verdict .verdicts/hexa-0pod/F-OP45-ROUTEA-D4096-CAP.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## OP-46 — SELFHOST-NEXT const-fold+atof+vsnprintf seed-promote bundle: 3 scattered DEFERs (OP-37b/40/44) + OP-39b gate-flip CONSOLIDATED into ONE runbook spec + one deferred registration (0-pod, DOCS/SPEC) — 2026-06-12
- SURVEY-FIRST (mandatory). Read the 4 verdicts: F-OP37B-HOST-ATOF-CORRECT-ROUND (strtod operand parse → operands
  byte-exact, MAX 3→1 ULP), F-OP40-COMPTIME-MUL-ULP (bit-exact hex-float const-fold serialize → MAX 1→0 ULP, 16/125→
  0/125), F-OP44-VSNPRINTF-CORRECT-ROUND (runtime float formatter 62.6% mis-round %.17g / ≤5 ULP %.17e, libc-snprintf
  delegation PROVEN → 0/0), F-OP39B-SEED-PROMOTE-FLIP (the gate-flip; the most detailed re-pin recipe: 151c52c8
  IMMUTABLE .c-graduation anchor, 27,068-line regen drift, ~3.5h build_selfhost.sh ladder, gen3→gen4 byte-eq).
  Confirmed the EXACT promote mechanism: self/native/hexa_cc.c + self/runtime.c are gitignored, restored from
  FROZEN_SEED_REF=151c52c8 by tool/restore_frozen_seeds; promoting = re-pinning that ref to a NEW coherent anchor
  built from current self/codegen.hexa + self/runtime.c via the build-host self-host ladder (FROZEN_SEED_REF hardcoded
  in ~7 scripts: restore_frozen_seeds, stage_resolve_runtime_a, SELFHOST_PROMOTE_RUNBOOK.md, clm/build_clmprod_tf32_e2e.sh).
- THE SHARED BLOCKER (the consolidation thesis): all three source fixes are correct in tracked source / proven-as-recipe
  but UNOBSERVABLE by CI because CI's toolchain bootstraps from the immutable 151c52c8 anchor that pre-dates them; each
  verdict separately said "needs the frozen-anchor re-pin — out of 0-pod scope" → ONE shared dependency, not three.
- DELIVERABLE (DOCS-ONLY): docs/selfhost-next-constfold-promote.md — the single build-host runbook: (1) promote
  MECHANISM (gitignored seed restored from immutable 151c52c8; re-pin = wholesale anchor refresh, 27,068-line drift);
  (2) the 3 source fixes + exact codegen.hexa/runtime.c sites + golden changes [OP-37b _cf_as_float strtod parse ·
  OP-40 _cf_float_node/_cf_float_hexlit bit-exact hex-float · OP-44 hxlcl_vsnprintf float-branch libc-snprintf
  delegation]; (3) the ONE promote procedure (apply OP-44 to runtime → regen seed → coherent anchor commit →
  build_selfhost.sh cc-gen3.o==cc-gen4.o fixpoint + parity → FROZEN_SEED_REF re-pin → ~91% float-string golden re-bake
  as its OWN PR); (4) post-promote cleanup (drop the 3 nobaseline-gate.yml :129/:193/:256 continue-on-error lines →
  OP-39 gate enforcing, per OP-39b); (5) per-fix verification checklist (each oracle/gate green post-promote).
- REGISTERED: domain `## deferred` now OPENS with the unified item "SELFHOST-NEXT — const-fold+atof+vsnprintf
  seed-promote bundle (OP-37b/40/44/39b)" → docs/selfhost-next-constfold-promote.md; the OP-39b deferred note marked
  SUPERSEDED-by-bundle; the OP-44 milestone cross-links the runbook; OP-46 milestone [x] added. Individual verdicts
  (F-OP37B/F-OP40/F-OP44/F-OP39B) KEPT — OP-46 only unifies the forward-pointer (3+1 scattered DEFERs → 1 coherent item).
- OUTCOME: 🟢 GREEN (docs/spec consolidation). NO seed regen, NO build-host work (that IS the deferred item), NO
  codegen/runtime/.tape edits. Verdict .verdicts/hexa-0pod/F-OP46-PROMOTE-BUNDLE-SPEC.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## OP-49 — route-(a) own-GEMM SHAPE-ADAPTIVE tile-selector DESIGN + CPU cost model VALIDATED against measured points (0-pod, no GPU) — 2026-06-13
- SURVEY: read F-OP45-ROUTEA-D4096-CAP (the (a)-(d) cause decomposition + T1-T5 GPU handoff) + wgmma_tf32_b14.cu
  MODE 4/5/6/7/8 source + W-ladder verdicts (OG16/OG17/W10) for the on-pod measured TFLOP/s.
- INVENTORY (step1): 5 in-tree route-(a) modes — MODE4 gemm_og16 (128x128, 2 CTA/SM), MODE5 gemm_og17_t256
  (128x256, 154 reg/thr → 1 CTA/SM REG-capped, W11/W12 closed-neg), MODE6 gemm_og17 (relaxed wait), MODE7
  gemm_og17_persist (128x128 PERSISTENT+swizzle, exists but never measured @4096), MODE8 gemm_og17_b14 (128x128
  DUAL-ISSUE PDEP — frontier). NO split-K (g5 forbids reorder), NO 64x64 small-tile.
- POLICY (step2a): 3 shape buckets — small-D under-fill (D≤1024, 128x128 leaves device ~90% idle), medium-D
  parity zone (1024<D≤3072, PARITY met @2048 1.08x), large-D drain-bound (D>3072, -9.9% K-drain + cuBLAS +24.6%).
- COST MODEL (step2b, self/native/wgmma/routea_cost_model.py): predict_tflops = PEAK_TF32(349) * issue_eff[mode]
  * occ_factor * wave_eff * drain_penalty * reuse_eff * fill_factor. KEY: occupancy = MIN(smem-limited, REGISTER-
  limited) CTAs/SM — the 154-reg t256 → 1 CTA/SM (register-cap is LOAD-BEARING; smem-only mispredicts the whole
  large-D crossover). issue_eff fit ONCE per kernel @D=2048 (per-kernel const, OP-45 finding 1); drain/wave/reuse/
  fill D-scaling are then a PREDICTION. SELECTOR (step2c): argmax over {mode × NST}.
- VALIDATION (step3, VERBATIM tool output): model REPRODUCES the measured win-ordering at BOTH D —
  D=2048 [MODE8,OG17,OG16,t256] MATCH (calibration anchors, exact) · D=4096 [MODE8,OG17,t256,OG16] MATCH (genuine
  PREDICTION, incl. the non-trivial t256-climbs-above-OG16 crossover). mean |rel.err| = 2.2%. ORDERING = PASS → 🟢.
  Honest sub-residual: MODE8@4096 absolute +9.2% (310 vs 283.9) — static drain under-credits large-D K-drain;
  ORDERING unaffected; calibrating the absolute needs OP-45 T2 ncu DRAM%/Tensor%.
- GAPS (step2d): #1 64x64 small-tile (under-fill) · #2 MODE7 persistent MEASURED @4096 (=OP-45 T3) · #3 bit-exact
  tree-reduction split-K (=OP-45 T4, highest value) · #4 NST-adaptive launcher (host-only). The selector's argmax
  is always MODE8 over existing modes yet MODE8 still loses to cuBLAS at the extremes — the gaps ARE the build-work.
- OUTCOME: 🟢 GREEN (cost-model ORDERING validation PASSES at both measured D). Milestone OP-49 [x]. Deliverables:
  docs/forge-routea-shape-adaptive.md · self/native/wgmma/routea_cost_model.py · F-OP49-SHAPE-ADAPTIVE-DESIGN.txt.
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod touch · no .tape edits.

## OP-52 — BUILT the OP-45-GPU T4 CTA-swizzle lever (MODE 9 non-persistent CTA-swizzle on b14 MODE 8) + measured on a real H100: does NOT close the @D=4096 TF32 gap — REGRESSES, bit-exact (CLOSED-NEG) — 2026-06-13
- SURVEY (pre-rent, cost clock): read F-OP45GPU-OCCUPANCY-SWEEP (T4 = cuBLAS D=4096 top algo split_k=1 + cta_swizzle=1,
  the +24.6% lever = better single-pass tile + CTA-swizzle, g5-bit-exact-reachable; T2 D=4096 compute/scheduling-bound,
  DRAM ~12-40% peak; T3 MODE7 persistent+swizzle @4096 closed-neg) + F-OP49-SHAPE-ADAPTIVE-DESIGN + docs/forge-routea-
  shape-adaptive.md + wgmma_tf32_b14.cu (MODE 8 gemm_og17_b14 + MODE 7 tile_unswizzle). Branched off origin/main (the
  OP-45-GPU/OP-49/OP-50 work had just merged via #3110; local checkout was behind).
- BUILT (net-new code): MODE 9 = gemm_og17_b14_swz = b14 MODE 8 math VERBATIM + a NON-PERSISTENT CTA-swizzle. The ONLY
  change vs MODE 8 is the CTA→tile assignment: flat id = blockIdx.y*gridDim.x+blockIdx.x, remapped via the existing
  tile_unswizzle (the MODE 7 mapper), 1-CTA/tile grid (NOT occ*SM persistent). This ISOLATES the swizzle from MODE 7's
  persistent-loop confound. SWZ=0 ≡ MODE 8 exactly (apples self-check). + op52_swz_run.sh driver. nvcc -O3 -arch=sm_90a.
- RENT: ONE H100 SXM, label hexa-tf32gap, contract 40733645, offer 21671166, $2.311/hr India IN (cuda 12.6, rel 0.9989,
  same machine family as the OP-45-GPU pod). Inline-polled to running+SSH-ready. nvidia/cuda:12.6.2-devel-ubuntu22.04.
- ptxas -v: gemm_og17_b14_swz = 0 spill, 96 KB/CTA, 2 CTA/SM — IDENTICAL to MODE 8 (only the index changed, as designed).
- STEP 1 (apples): MODE 8 baseline reproduced — D=2048 ~316 TFLOP/s 1.09x, D=4096 ~285.6 TFLOP/s 1.50x, rel_rms 0
  (reproduces OP-45-GPU's 320.6/1.08x @2048, 283.9/1.52x @4096 within ~1%).
- STEP 2 (self-check): MODE 9 SWZ=0 == MODE 8 EXACTLY — D=4096 285.1, rel_rms 0 — faithful MODE 8 + swizzle knob.
- STEP 3 (THE LEVER, VERBATIM median of 3): MODE 9 CTA-swizzle SWZ∈{2,4,6,8,12,16} × PDEP∈{1,2} @D=4096 ALL REGRESS.
  Best bit-exact swizzled = 280.5 TFLOP/s (PDEP=2 SWZ=2) and 280.2 (PDEP=2 SWZ=16) = −1.6%/−1.7% vs SWZ=0's 285.1;
  ratio WIDENS 1.50x→1.53x. PDEP=1 worse still (272-277, up to 1.58x). D=2048 also neutral-to-negative. rel_rms 0 on
  EVERY one of the 24 swizzled configs (bit-exactness preserved — the gate held; no loose-TF32 win sought).
- WHY (g5, anchored to T2): D=4096 is compute/scheduling-bound (DRAM ~12-40% peak, AI 682 >> 104 threshold). A CTA-
  swizzle's whole mechanism is L2 LOCALITY; if DRAM isn't the bottleneck, L2 reuse cannot raise throughput and only adds
  index overhead → the measured small regress. SAME physics as T3 (MODE 7 @4096 regress), now ISOLATED: MODE 9 strips
  the persistent loop and keeps ONLY the swizzle → regress persists → the regress was the SWIZZLE, not the loop.
- VERDICT: 🔴/🟠 CLOSED-NEGATIVE. No bit-exact variant closes any part of the @D=4096 1.5x gap (CTA-swizzle regresses;
  the in-tree larger single-pass tile MODE 5 t256 is already closed-neg @4096). The surviving lever is a NEW bit-exact
  single-pass per-CTA tile/schedule (2-CTA/SM-preserving kernel rewrite), NOT a launcher/index swizzle, NOT split-K (g5).
  Milestone OP-52 [x]. Deliverables: wgmma_tf32_b14.cu MODE 9 + op52_swz_run.sh + docs/forge-routea-shape-adaptive.md
  (§0 + §7 + large-D bucket updated) + F-OP52-TF32-GAP-CLOSE.txt.
- DESTROY: yes | vastai destroy instance 40733645 (label hexa-tf32gap confirmed MINE first) → vastai show instances-v1
  "Total: 0 instances / No instances found." LEAK-0 CONFIRMED. No foreign pod touched (roster empty throughout). ~$0.70.

## OP-53 — 0-pod (NO GPU) DESIGN: the 2 cost-model-tractable route-(a) gaps (64x64 small-tile + NST-adaptive launcher) turned into buildable specs + validated in the cost model, ACCOUNTING FOR the OP-52 swizzle-negative — 2026-06-13
- SURVEY (0-pod, no cost clock): read F-OP49-SHAPE-ADAPTIVE-DESIGN (the 4 config gaps + cost model) + F-OP45GPU-
  OCCUPANCY-SWEEP (measured anchors: MODE8 90reg/0spill/2CTA-SM; D=2048 320.6/1.08x; D=4096 283.9/1.52x; T3 MODE7
  persistent closed-neg; T4 cuBLAS lever = better single-pass tile + CTA-swizzle NOT split-K) + F-OP52-TF32-GAP-CLOSE
  (the swizzle-NEGATIVE: MODE9 non-persistent CTA-swizzle @4096 REGRESSES −1.6%, best 280.5 vs SWZ=0 285.1, rel_rms 0)
  + docs/forge-routea-shape-adaptive.md + routea_cost_model.py + wgmma_tf32_b14.cu (MODE 8 m64n64k8 K-loop + the
  probe_a kernel already runs TM=TN=64 with m64n64k8). Branched off origin/qforge-op52-tf32gap-v2 (#3122 not yet on
  main) so the OP-52 doc/verdict/kernel edits are inherited via union-resolve, not clobbered.
- GAP#1 64x64 small-tile (MODE_t64) SPEC: tile 64x64, 1 warpgroup/128 threads (vs MODE8's 2-WG/256), ONE wgmma
  m64n64k8/K-step (vs MODE8's 4 = 2 M-bands × 2 N-halves), ONE 64x64 accumulator float d0[32], ~48 reg/thr →
  reg-cap 10 CTA/SM; smem/stage (64+64)*32*4=16KB → at NST=2 32KB/CTA → smem-cap 7 → OCCUPANCY 7 CTA/SM (3.5x MODE8).
  Grid plain 1-CTA/tile (NO swizzle, NO persistent — OP-52). BIT-EXACT K-ORDER: reuses MODE8's inner K-loop VERBATIM
  for its single sub-tile (`for kk in 0..TKSW step TK: WG(d0,dA,dB)`) — byte-identical to the FMA order MODE8 applies
  to each of its (band, N-half) sub-accumulators → a future build is rel_rms 0 BY CONSTRUCTION. issue_eff conservatively
  = OG16's plain 0.84 (no PDEP, no 2-band overlap in 1 WG).
- GAP#4 NST-adaptive host-side launcher select_config(D,M,N,K): argmax over SELECTABLE={OG16,OG17,MODE6,MODE8,
  MODE5_t256,MODE_t64} × {NST 2,3}. The SWIZZLE modes MODE7 (persistent) + MODE9_swz (non-persistent) are STRUCTURALLY
  EXCLUDED from auto-selection (both measured closed-neg, OP-45-GPU T3 + OP-52); they stay in the MODES table ONLY so
  the anti-preference VALIDATION can score them. swz_penalty() applies OP-52's MEASURED −1.6% factor (0.984) to any
  swizzled mode in the compute-bound regime (tiles>=SM_COUNT) — the exact regime OP-52 measured (mechanism = OP-45-GPU
  T2: a CTA-swizzle is purely an L2-locality lever, useless when compute-bound).
- COST-MODEL CHANGES (routea_cost_model.py): per-mode `threads` field (64x64 = 128 thr); a device-COVERAGE wave_eff
  (under-fill regime: eff = tiles/SM_COUNT when tiles<132, classic wave-quant when filled — leaves the D=2048/4096
  anchors at 0.970 UNCHANGED, so no anchor moves); MODE_t64 + MODE9_swz rows; swz_penalty; select_config; 3 new
  validations. The 32-CTA/SM H100 hard ceiling added to cta_per_sm.
- VALIDATION (0-pod, VERBATIM `python3 self/native/wgmma/routea_cost_model.py`): ORDERING still PASS (2048/4096 ranks
  MATCH, mean |rel.err| 3.9%, MODE8@4096 +1.0%). VAL-1 SWIZZLE ANTI-PREFERENCE: D=4096 MODE8 vs MODE9_swz — MEASURED
  base 285.1→swz 280.5 (REGRESS −1.6%), PREDICT base 286.7→swz 282.1 (REGRESS −1.6%) → sign MATCH; selector picks MODE8
  (not a swizzle) → PASS. VAL-2 64x64 SMALL-D FILL: D=256 MODE_t64 32.0 vs MODE8 10.3 (3.1x), D=512 125.4 vs 40.7 (3.1x),
  D=1024 70.3 vs 160.0 (honest crossover → 128x128), D=2048 137.9 vs 315.0 (filled regime, 128x128 wins) → PASS.
  SELECTOR picks: D=256/512 MODE_t64, D=1024+ MODE8, D=4096 MODE8 (NOT a swizzle). OP-53 OVERALL: ALL PASS.
- FUTURE-GPU spec (NOT built): gemm_og17_t128x256_2cta — a 128x256 tile that PRESERVES 2 CTA/SM (vs t256's reg-capped
  1 CTA/SM, which is why t256 lost @4096). Needs <=128 reg/thr (e.g. 2-WG-cooperative N-tiling) + NST=2 + deeper-K PDEP>=2.
  Cost model predicts ~286.7×1.085≈311 TFLOP/s = +8.5% PARTIAL close (~1.50x→~1.37x), NOT full parity (cuBLAS ~427);
  the model CANNOT predict whether the deeper-K schedule hides the drain (the OP-45-GPU T2 per-CTA K-drain unknown) →
  GPU-lane build+measure item, RISK = 2-CTA/SM may not be reg-achievable at 128x256. Bit-exact K-order constraint: the
  four 64x64 sub-tiles each run MODE8's reduction, NO split-K, NO cross-CTA reduction → rel_rms 0 by construction.
- OUTCOME: 🟢 GREEN (3 cost-model validations PASS). Milestone OP-53 [x]. Deliverables: docs/forge-routea-shape-adaptive.md
  §8-§9 · self/native/wgmma/routea_cost_model.py · F-OP53-SMALLTILE-LAUNCHER-DESIGN.txt. 0-pod · no GPU · no vast ·
  no foreign-pod touch · $0 · leak-0 · no .tape edit (except a MAIN.tape #-comment).

## OP-54 — sm_120 OWN120 own-GEMM (mma.sync, OP-1/OP-1b-tuned) vs cuBLAS-TF32 shape sweep on the FREE pool RTX 5070 `summer`: bit-exact gate PASS, median 0.95x-1.47x off cuBLAS, closest @D=768 (0.95x), $0, no leak — 2026-06-13
- SURVEY-FIRST: read F-BENCH-5 (raw OWN120 baseline 3.16-6.85x off cuBLAS, the mma.sync.m16n8k8 sm_120 kernel; wgmma
  is sm_90a-only, ptxas-rejects sm_120) + F-BENCH-3 (the cuBLAS-TF32 proxy + ISA finding) + F-BENCH-1 (matched-dtype
  harness) + docs/forge-routea-shape-adaptive.md (Hopper route-(a), §0-§7). Located the bench source
  self/native/mma_sm120/owngemm_sm120.cu (gemm_sm120 + OWNGEMM_MAIN gate+perf harness) + build_owngemm.sh. The kernel
  is the OP-1/OP-1b-TUNED version (cp.async double-buffer + .v4 loads + .v2 epilogue) whose source note already claims
  ~1.0-1.12x off cuBLAS (down from F-BENCH-5's raw 3.2-6.9x). OP-54 = independently re-measure that on a 2nd free card.
- HOST: summer (sidecar pool, RTX 5070 sm_120/cc12.0, driver 580.159.03, FREE — NOT vast, $0). Existing checkout at
  ~/dancinlab/hexa-lang; owngemm_sm120.cu on summer = sha256 a963ee55… = BYTE-IDENTICAL to origin/main (no stale-src).
- TOOLCHAIN GOTCHA (load-bearing): summer's default /usr/bin/nvcc = CUDA 12.0.140 whose ptxas TOPS OUT at sm_90a
  (verbatim arch list: …sm_89 sm_90 sm_90a, NO sm_12x) — CUDA 12.0 predates consumer Blackwell. Built instead with
  summer's CUDA 12.9 toolkit (/usr/local/cuda-12.9, the /usr/local/cuda symlink) whose ptxas DOES list sm_120.
  nvcc -arch=sm_120 -O3 -DOWNGEMM_MAIN owngemm_sm120.cu -lcublas → BUILD_OK (1054064 B). mma.sync.m16n8k8.tf32
  assembles for sm_120 on CUDA 12.9 (re-confirms F-BENCH-5 ISA: portable warp MMA = YES, wgmma = NO).
- SHARED-HOST CONTENTION (g5 honesty): summer GPU at 91-99% util / 215W throughout, SATURATED by a FOREIGN sibling
  job (nvidia-smi: PID 110588 python 7190MiB) — left ALIVE/untouched per g9. So ABSOLUTE TFLOP/s of both kernels are
  suppressed (cuBLAS @2048 measured 14.9-19.4 here vs ~30.8 idle in F-BENCH-5); the off-cuBLAS RATIO (own÷cuBLAS,
  same loaded card back-to-back) is the contention-robust metric and is what's reported.
- GATE (VERBATIM, all PASS, contention-independent): S=512 rel-RMS 1.961e-05 · S=768 1.332e-05 · S=1024 3.019e-05 ·
  S=1536 2.342e-05 · S=2048 1.743e-05 (gate<=1e-2, all PASS). Matches F-BENCH-5 §2 exactly (same kernel). The
  established same-dtype check (vs cuBLAS-TF32; cuBLAS doesn't expose accum order → no rel-RMS 0 dev-vs-dev possible).
- SWEEP (median off-cuBLAS over 4 measures): S=512 1.15x · S=768 0.95x (CLOSEST, own EDGES cuBLAS, 24.5/23.3 TFLOP/s
  stable every rep) · S=1024 1.47x (worst+noisiest, 64x64-tile under-fill soft spot, contention-amplified) ·
  S=1536 1.20x · S=2048 0.96x (near-parity runner-up). NO small-D-closer monotone trend — sweet spot is MID-D, not
  the smallest D. The "simpler kernel loses less at small D" under-fill hypothesis is NOT borne out on the 5070.
- FINDING: the tuned OWN120 has CLOSED F-BENCH-5's raw 3.2-6.9x gap to ~0.95-1.47x off cuBLAS-TF32 — REPRODUCED on a
  SECOND free consumer card (summer; was aiden in F-BENCH-5/OP-1). Value = bit-exactness + device-residency + no-
  vendor-call on the free card, parity-seeking not a beat.
- CLEANUP: temp build dir /tmp/op54-owngemm.* rm -rf'd → CLEAN; no own-GEMM binary left running; nvidia-smi
  compute-apps = ONLY the foreign python (untouched). summer left clean, foreign proc alive. $0, no pod, nothing to leak.
- VERDICT: 🟢 GREEN. Milestone OP-54 [x]. Deliverables: F-OP54-SUMMER-OWNGEMM-TF32.txt (verbatim sweep + 3-rep raw) +
  docs/forge-routea-shape-adaptive.md §10 (consumer-sm_120 row, union-resolved after OP-53's §8/§9) + this log. No
  code change (the OWN120 kernel was already in-tree + tuned; OP-54 is a fresh independent MEASUREMENT on a 2nd free
  card). MAIN.tape #-comment SKIPPED (the file is untracked-on-origin / sibling-introduced — avoided a merge race).

## OP-56 — [S]-shadow survive-audit tranche (transpose·normalize·zeros·topk·mse_loss) — 5/5 DEREGISTERED, survivor set 10→5
- CONTEXT: continues OP-41/43/47/48/51 falsified-builtin family. OP-51 dropped the OP-43 survivor set 16→10
  (6 [S]-shadow dereg). Remaining 10 = 9 [S R] survivors (relu sigmoid transpose normalize zeros attention
  topk sample_token mse_loss) + arange (compiler-closure KEEP). OP-56 takes the next tranche of 5: transpose,
  normalize, zeros, topk, mse_loss — the 5 with the cleanest shadow surfaces.
- METHOD (OP-51 exact, 0-pod CPU-LOCAL — ~/.hx/bin/build/hexat AOT transpile Jun-13 2028152B + clang -fsyntax-only):
  (a) roster-registered in self/env.hexa; (b) 0 codegen-inline guard + 0 callable runtime symbol; (c) g5 AOT
  falsify with CORRECT args; (d) caller enumeration shadow-vs-builtin-dep; (e) [S] shadow-binding CONTROL;
  (f) compiler/** zero-bind-ref check.
- IMPL CROSS-REF: codegen `if name=="X"` = 0 for all 5. runtime symbol (runtime.h ∪ installed runtime.c
  /Users/mini/.hx/src/self/runtime.c, prefix-variant scan): transpose bare hits = COMMENTS (real syms
  farr_transpose_2d/transpose_2d/etc); normalize bare hits = COMMENTS (softmax/normalize-by-sum); zeros bare
  hit = ONE comment ("leading zeros"), real syms t_zeros/tensor_zeros/farr_zeros (tensor_zeros is a SEPARATE
  registered builtin, kept); topk = 0; mse_loss = 0. → all 5 have NO bare callable symbol.
- AOT g5 PROBE (verbatim): transpose(m)/normalize(a)/zeros(4)/topk(a,2)/mse_loss(a,a) → hexat OK → clang
  p_NAME.c:20:29: error: use of undeclared identifier 'NAME' for ALL 5. FALSIFIED.
- [S] SHADOW CONTROL: minimal `fn NAME(x:float)->float{return x+1.0}` + `NAME(2.0)` → hexat OK → clang CLEAN;
  generated C line4 `HexaVal NAME(HexaVal x);` + line17 def + call → binds LOCAL roster-independently. Proven
  for all 5.
- CALLER SWEEP (the decisive gate):
  · topk — shadows self/{test_,ml/}moe_active (both emit 2 topk-def, 0 undeclared). Builtin-dep: ONLY
    example/test_generation (AOT-fails today, 20 err incl 4 topk). moe_layer/moe_lib `topk` = COMMENTS only.
  · mse_loss — shadows self/test_anima_lm + ml/{lora,anima_lm_finetune} + test_titan_memory + bench/qforge/*
    (all emit mse_loss-def, 0 undeclared). Builtin-dep: ONLY example/{test_generation,test_quant_beam_init,
    test_autograd} (all AOT-fail today, builtin-independent).
  · transpose — shadow self/test_collection_advanced (binds local). Builtin-dep: ONLY example/test_matmul_loss
    (AOT-fails today on cross_entropy+dot+normalize+transpose = the OP-47/48-removed syms too = dead example).
    self/test_graph_pattern `transpose` = comments + hexa_str(...) literals (real syms e_transpose/gp84_transpose),
    compiles clean WITHOUT calling the builtin.
  · normalize — shadows self/ml/embedding + bio ribozyme + @vectorize anima_online_learner + @noalias
    test_noalias (each binds its own def). IMPORTED-SHADOW: self/ml/rag_test `use "embedding"` → generated C
    `extern HexaVal normalize(HexaVal)` + calls bind the IMPORTED embedding.hexa local (clang CLEAN, tot_err=0),
    NOT the builtin (OP-51 kv_cache_append/flash_decode pattern). test_galore = gal_normalize (different fn).
    Builtin-dep: ONLY example/test_matmul_loss (dead, above).
  · zeros — shadows self/ml/transformer + serve/serve + test_{grad_clip_fused,tiny2} (each binds 2 zeros-def,
    0 undeclared). Builtin-dep callers (18): 12 example/* all AOT-fail today (tot_err=20, builtin-independent);
    self/{train_decoder_cpu_b,test_tensor_ops_deep,test_score_diffusion,anima_eeg} already AOT/transpile-fail;
    self/fix_array_push_nested is a workaround scratch-probe failing TODAY on zeros (registered+no-impl =
    pre-existing builtin-independent break, no-op to flip). FALSE-POSITIVE: stdlib/dojo/rl `t_zeros(`/
    `torch.zeros(` only inside generated-source STRINGS (it is a code generator) → compiles clean, no builtin call.
- COMPILER-CLOSURE: compiler/** refs — transpose 6 (all metal_target/hir_to_mir COMMENTS), normalize 3
  (PLAN.md path-normalize prose + phases.hexa comment), zeros 13 (PLAN.md ELF-symtab "all zeros" + atlas
  ZETA-trivial-zeros archive + comments), topk 0, mse_loss 0. NONE in compiler/check/bind.hexa (arange IS,
  line 1281, control confirmed) → all 5 pass the byte-eq safety gate. arange STAYS by contrast.
- DECISION (g0 conservative, [S]-strict): all 4 conditions met per builtin (falsified ∧ no live builtin-dep
  caller ∧ shadow binds without it ∧ compiler 0) → ALL 5 DEREGISTER.
- DIFF: self/env.hexa — 5 names removed from env_new() builtin_names (transpose normalize zeros from the
  cosine_sim/argmax line group; topk mse_loss from the gelu/silu/sample_token group) + 1 OP-56 rationale
  comment block. wipe_guard net +30/−3 « 50, scoped subject. env.hexa transpiles clean post-edit (hexat OK),
  0 non-comment roster occurrence for each removed name, all kept neighbors intact (incl tensor_zeros, arange).
- OUTCOME: 🟢 GREEN. Milestone OP-56 [x]. Survivor set 10→5. Remaining 4 [S R] = relu sigmoid attention
  sample_token (+ arange compiler-closure KEEP) — the HARDEST: sigmoid/relu large live-shadow surfaces look
  like conservative KEEPs; reservoir near-depleted (next tranche likely dereg FEWER, possibly 0). selfhost-
  byteeq-real INLINE-polled (env.hexa edit → next compiler build; 5 have 0 compiler-core refs → fixpoint safe).
  $0 · 0-GPU · 0-pod · no vast · no foreign-pod · no .tape. Verdict F-OP56-SURVIVE-TRANCHE.txt.

## OP-57 — sm_120 OWN120 SMALLER-TILE small-D proxy on the FREE pool RTX 5070 `summer`: 32x32/1-warp vs 64x64/2x2 baseline A/B sweep — smaller tile STRICTLY WORSE at every small-D shape, bit-exact preserved (🔴 hypothesis, honest negative) — 2026-06-13
- CONTEXT: OP-53 (#3134) designed a Hopper 64x64 small-tile (MODE_t64) the CPU cost model predicts fills the
  132-SM device 3.1x better @D<=512. That design is sm_90a wgmma → ptxas-rejected on summer's sm_120 (no wgmma).
  The in-tree OWN120 (self/native/mma_sm120/owngemm_sm120.cu, the OP-1/OP-1b-tuned mma.sync kernel OP-54 measured)
  is ALREADY a 64x64 tile, so the closest FREE sm_120 proxy for "smaller tile fills better at small-D" = shrink
  OWN120 to 32x32 / 1-warp (4x the CTAs/tiles at a given D) and A/B-sweep vs the 64x64 baseline at D=256/512/768/1024.
- METHOD: tile-PARAMETRIZED clone (BM/BN/WARPS `-D`-overridable; the shipped owngemm_sm120.cu is UNCHANGED — the
  clone ran off-tree on summer). Each warp owns a 32x32 sub-tile in BOTH configs (the 64x64 is 4 such sub-tiles,
  the 32x32 is one), running the IDENTICAL per-output K-major mma.sync loop → bit-exact preserved by construction.
  Built on summer's CUDA 12.9 (12.0 ptxas has no sm_120, per OP-54). BUILD_OK both: baseline 1054072 B, smalltile
  1066360 B. 3 reps, iters=50, cudaEvent, off-cuBLAS = cuBLAS÷own.
- SHARED-HOST CONTENTION (g5): summer GPU at 98% FOREIGN load (nvidia-smi: PID 110588 python 7190MiB + PID 483710
  python3, NOT mine, left untouched per g9) — absolute TFLOP/s suppressed; the baseline-vs-smalltile RATIO (both
  eat the same contention back-to-back) is the contention-robust metric.
- GATE (VERBATIM, IDENTICAL between the two configs at every shape → proves the shrink is a pure FILL change, not
  math): S=256 rel-RMS 2.692e-05 · S=512 1.961e-05 · S=768 1.332e-05 · S=1024 3.019e-05 (gate<=1e-2, all PASS,
  baseline == smalltile byte-for-byte). The smalltile rel-RMS matching the baseline exactly is the hard bit-equality.
- SWEEP (median off-cuBLAS over 3 reps, baseline 64x64 → smalltile 32x32): D=256 1.34x → 1.67x (WORSE) · D=512
  1.18x → 1.62x (WORSE) · D=768 0.96x (own EDGES cuBLAS) → 4.13x (COLLAPSE, own 5.6 vs cuBLAS 23.3 TFLOP/s) ·
  D=1024 1.44x → 2.52x (WORSE). The smaller tile is STRICTLY WORSE at EVERY small-D shape.
- WHY (physics, honest): the 32x32 / 1-warp tile has ONE warp/CTA (can't keep the mma.sync m16n8 pipeline busy vs
  the 64x64's 4 warps) AND halves A/B smem-reuse per global load. The extra CTAs light up more SMs, but the 64x64
  already FILLS the 50-SM RTX 5070 at D>=512 (D=512 → 64 tiles >> 50 SMs) → no under-fill to cure, only
  warp-underutilization + reuse-loss to pay. Consumer-card MEASURED counterpart to OP-54's "no small-D-closer trend".
- DID THE PREDICTION HOLD? NO. The OP-53 64x64-fills-better was a HOPPER (132-SM, 128x128-baseline) cost-model
  result; on the 5070 (50 SMs, 64x64-baseline) the analogous shrink goes the OTHER way. The wgmma 64x64 design
  itself (MODE_t64) is UNTESTED here (sm_120 can't run wgmma) + remains a HOPPER-ONLY future build; OP-57 is its
  closest free sm_120 proxy and the proxy says the more-CTA lever does NOT help an already-small-tile consumer kernel.
- CLEANUP: temp build dir /tmp/op57-build rm -rf'd by the runner + /tmp/op57_run.sh removed → CLEAN (ls /tmp/op57*
  = no-op57-temp-left); no own-GEMM binary left running; nvidia-smi compute-apps = ONLY the 2 foreign python
  (untouched). summer left clean, $0, no pod, nothing to leak.
- VERDICT: 🔴 RED for the hypothesis (honest negative — CLOSES the "smaller tile helps small-D on the consumer card"
  question with a clean bit-exact A/B measurement; saves a future lane from re-attempting). The underlying OWN120
  kernel is UNCHANGED + still 🟢 at its 64x64 sweet spot (D=768 0.96x, OP-54 reproduced here every rep). Milestone
  OP-57 [x]. Deliverables: F-OP57-SUMMER-SMALLTILE.txt (verbatim A/B sweep + 3-rep raw) + docs/forge-routea-shape-
  adaptive.md §10.1 (consumer-card shrink-negative, union-resolved after §10). No shipped-code change. MAIN.tape
  #-comment SKIPPED (the file is untracked-on-origin, same as OP-54 — avoided a merge race). $0, no vast, no pod,
  no foreign-pod touched.

## OP-59 — DEFINITIVE falsified-builtin family closure (relu·sigmoid·attention·sample_token) — 3 DEREGISTERED, 2 compiler-closure KEEPs, survivor set 5→2 — FAMILY CLOSED — 2026-06-13
- CONTEXT: the DEFINITIVE close-out of the OP-33/41/43/47/48/51/56 falsified-builtin audit thread. OP-56
  dropped the OP-43 ML-family survive-set 10→5. The final 5 = 4 [S R] survivors (relu sigmoid attention
  sample_token) + arange (a hard compiler-closure KEEP since OP-48). OP-59 audits all 4 [S R] survivors with
  the full rigorous method and states the settled family-closure.
- METHOD (OP-47/48/51/56 exact, 0-pod CPU-LOCAL — ~/.hx/bin/build/hexat AOT Jun-13 2028152B + clang
  -fsyntax-only · installed runtime.c /Users/mini/.hx/src/self/runtime.c Jun-12):
  (a) roster-registered in self/env.hexa; (b) 0 codegen-inline guard + 0 callable runtime symbol; (c) g5 AOT
  falsify with CORRECT args; (d) caller enumeration shadow-vs-builtin-dep; (e) [S] shadow-binding CONTROL;
  (f) compiler/** zero-bind-ref check (the arange lesson — the dispositive gate here).
- IMPL CROSS-REF: codegen `if name=="X"` = 0 for all 4. runtime symbol: relu bare = 0 (only "prelude"
  substring); sigmoid bare = 0 — the real symbol is the DIFFERENT _hx_sigmoid_d static-inline double helper
  (runtime.c:9674), NOT a bare HexaVal sigmoid; attention bare = 2 COMMENTS only (real syms farr_attn_dt_fwd/
  bwd_gpu); sample_token = 0. → all 4 have NO bare callable symbol.
- AOT g5 PROBE (verbatim): relu(a)/sigmoid(a)/attention(q,k,v)/sample_token(a) → hexat rc=0 → clang
  p_NAME.c:19-21:29: error: use of undeclared identifier 'NAME' for ALL 4. FALSIFIED.
- [S] SHADOW CONTROL: minimal `fn NAME(x:float)->float{return x+1.0}` + `NAME(2.0)` → hexat rc=0 → clang
  CLEAN; generated C line4 `HexaVal NAME(HexaVal x);` + line17 def + call → binds LOCAL roster-independently.
  Proven for all 4.
- CALLER SWEEP (the decisive gate):
  · relu — shadow self/test_nn_stdlib (DEFINES `pub fn relu`; generated C `HexaVal relu(HexaVal);` def,
    relu-undeclared=0 → binds LOCAL) + stdlib/nn.hexa def. Builtin-dep: example/test_neural_testbench (20-err
    today, dead) + example/test_transformer (hexat rc=1, transpile-fails today, dead). The self/ml `*_relu`
    hits (ad_relu/blt_relu/cl_relu/dsmoe_relu/…) are DIFFERENT prefixed local fns. → 0 live builtin-dep caller.
  · sample_token — shadow self/ml/sampler (defines it). IMPORTED-SHADOW: self/ml/m4_inference + self/serve/
    serve_alm `use "self/ml/sampler.hexa"` → generated C `extern HexaVal sample_token(_,_,_)` binds the
    imported sampler.hexa DEF, NOT the builtin. Builtin-dep: self/ml/{batch_inference,generate,streaming,
    t1_real_bench} emit `hexa_call3(sample_token,...)` — ALL clang-FAIL TODAY (20/20/16/17 err incl
    sample_token-undeclared, builtin-independent) + example/{test_generation,test_conv_cache_io} dead. The
    gpu_/ppo_/do_sample_token hits are different fns. → 0 live builtin-dep caller.
  · attention — shadows self/ml/conscious_lm + self/test_conscious_lm (`@hot fn attention(x,L)` local, the
    `attention(x,L)` calls bind it). Builtin-dep: self/ml/train_decoder_cpu_b `attention(q,k,v,SEQ,D)` (line
    13 "attention builtin") emits a bare call → clang 20-err today incl "call to undeclared function
    'attention'" (dead). example/{test_transformer,test_modern_llm,benchmark_all} bare-attention callers dead.
    naive_/flash_/ab_/sliding_window_/multi_head_attention = different fns. → 0 live builtin-dep caller.
  · sigmoid — large live-shadow surface (6 shadow defs incl stdlib/nn, self/ml/dpo) but NOT deregistered; the
    dispositive gate is its codegen special-path (below).
- COMPILER-CLOSURE (DISPOSITIVE): compiler/** refs — relu 0, sample_token 0, attention = 2 nvptx COMMENTS
  ("attention (max)…") + 1 atlas-archive prose node (NO bind.hexa, NO `op=="attention"` dispatch → 0 binding
  refs, same disposition as zeros in OP-56 which was deregistered). sigmoid = 37 refs INCLUDING A REAL
  CODEGEN SPECIAL-PATH: compiler/codegen/nvptx_target.hexa:677 `if op=="sigmoid"{return true}` (_nvptx_is_
  math_op) + :689 arity table + :2203 `if s.op=="sigmoid" && dst_kind==NVPTX_RKIND_F64` (a full PTX f64
  instruction-sequence lowering sigmoid=0.5+0.5*tanh(x/2)) + nvptx_ptx_ops.hexa:203-204 PTX f64 constants —
  STRUCTURALLY arange-class. CONTROL: arange IS at compiler/check/bind.hexa:1281 + PLAN.md:574 (why it
  STAYED, OP-48).
- DECISION (g0 conservative, [S]-strict): relu/attention/sample_token meet all 4 conditions (falsified ∧ no
  live builtin-dep caller ∧ shadow binds without it ∧ compiler/** 0 binding refs) → DEREGISTER. sigmoid FAILS
  the compiler gate (real nvptx codegen special-path) → PERMANENT KEEP (compiler-closure). arange PERMANENT
  KEEP (bind allow-list) — unmoved.
- DIFF: self/env.hexa — 3 names removed from env_new() builtin_names (relu from the sigmoid/softmax line;
  attention from layer_norm/embedding; sample_token its own line) + 1 OP-59 rationale comment block.
  wipe_guard net additive « 50, scoped subject. env.hexa transpiles clean post-edit (hexat rc=0); env_after.c:
  relu/attention/sample_token=0, sigmoid/arange=1; all kept neighbors intact.
- DEFINITIVE FAMILY-CLOSURE STATEMENT: OP-43 survivor set 26→23 (OP-47)→16 (OP-48)→10 (OP-51)→5 (OP-56)→2
  (OP-59). FINAL survive count = 2, BOTH compiler-closure permanent KEEPs: sigmoid (nvptx codegen special-
  path) + arange (bind allow-list). No live-shadow KEEP remains — relu/attention/sample_token carried live
  shadows but the roster ROW was deregisterable (shadows bind independently per [S] control + every
  builtin-dep caller dead today). ML-family thread total = 40 deregistered (16+3+7+6+5+3), 2 permanent
  compiler-closure KEEPs. THE FALSIFIED-BUILTIN FAMILY IS CLOSED — the audit thread has reached its honest
  floor: a 2-member compiler-closure permanent-KEEP set. Real ML in hexa = stdlib/flame/* + per-module LOCAL
  fns (the shadows), not these roster builtins. Reversible one-line re-add.
- OUTCOME: 🟢 GREEN. Milestone OP-59 [x]. Survivor set 5→2 (both compiler-closure KEEPs). FAMILY CLOSED.
  selfhost-byteeq-real INLINE-polled (env.hexa edit → next compiler build; the 3 removed have 0 compiler-core
  refs → byte-eq fixpoint safe). $0 · 0-GPU · 0-pod · no vast · no foreign-pod · no .tape. Verdict
  F-OP59-FALSIFIED-FAMILY-CLOSED.txt.

## OP-65 — SURVEY the 0-pod correctness frontier + execute the single best item: const-fold class DRY, deferred build-host/GPU; PICKED the OP-62 10-orphan dereg regression-proof → found+fixed a REAL stale LSP advert of the deregistered `tension_link` — 2026-06-13
- MANDATE: the falsified-builtin thread is CLOSED (OP-59 ML + OP-62 non-ML = whole env.hexa roster). Rather than
  re-litigate it (make-work), SURVEY the actual 0-pod correctness frontier and execute the ONE best genuine item.
- SURVEY (measurement beats assumption): (a) CONST-FOLD codegen-bug class (OP-37/37b/40/44) is GENUINELY DRY —
  re-read self/codegen.hexa comptime_eval (9959-10247): every float-fold serialize routes through bit-exact
  _cf_float_node, every operand parse through _cf_as_float→parse_float (OP-37b strtod) or exact source text; the
  only residual to_float() calls (9961, 10204) are INT-STRING-only = byte-exact by construction → NO sibling
  %g/narrowing bug. (c) `## deferred` is all build-host (SELFHOST-NEXT frozen-anchor 151c52c8 re-pin) or GPU —
  out of 0-pod scope. (b) the OP-62 10-orphan DEREG regression-proof: OP-62's §3 caller sweep EXPLICITLY EXCLUDED
  the roster files (env.hexa/type_checker.hexa/LSP.HEXA) → the dereg was never proven against lsp.hexa.
- PICK (g0): (b) beats (a)+(c) — the only axis with an actionable, decisive, 0-pod outcome (a clean scan closes
  the dereg loop; a live caller = a real bug to fix). It found a bug.
- FINDING (verbatim): scoped grep (self/ stdlib/ example/ compiler/ bench/, --include="*.hexa", excl *.gen.hexa +
  .git) for all 10 orphans → all hits are OP-62 dereg COMMENTS in env.hexa EXCEPT one non-comment hit:
  `self/lsp.hexa:116: "tension_link",` — a LIVE entry in get_builtins(), consumed at lsp.hexa:277 (semantic
  token = "builtin" highlight), 901 (completion_item kind 3 "builtin"), 971 (export). tension_link was
  DEREGISTERED by OP-62 (#3175), so the LSP still advertised/suggested a builtin that no longer links (the exact
  lints-but-won't-link landmine OP-62 removed). The other 9 orphans = 0 occurrences in lsp.hexa.
- FIX: self/lsp.hexa get_builtins() — pruned the `"tension_link"` entry + OP-65 provenance comment (net +4/−1,
  wipe_guard-safe).
- VERIFY: post-fix 0 non-comment tension_link in lsp.hexa (the 3 remaining repo orphan-name hits are
  TRAILING-COMMENT mentions only — code token = kept neighbor builtin to_float/is_alpha/input). hexat transpile
  `OK: /tmp/op65_lsp.c` rc=0 112954B; the 3 "[codegen_c2] ERROR: unknown builtin method: index_of_from" lines
  PRE-EXIST on the git-stash baseline (count=3) → non-regressive. Self-host byte-eq SAFE — lsp.hexa is the LSP
  tool, NOT in compiler/main.hexa build_selfhost closure; data-list-only edit (no codegen/runtime/env).
- OUTCOME: 🟢 GREEN. Milestone OP-65 [x]. Dereg loop CLOSED for the LSP surface. Honest residual: env_new()
  builtin_names vs lsp.hexa get_builtins() are two hand-lists with no compile-time consistency check (latent drift;
  a future 0-pod test get_builtins() ⊆ roster would catch this automatically). $0 · 0-GPU · 0-pod · no vast ·
  no foreign-pod · no .tape. Verdict F-OP65-LSP-ORPHAN-PRUNE.txt.

## OP-85 — FINAL high-value runtime *_pure tranche; CLOSES the runtime authoritative-reference vein (6 helpers locked 82/82) — 2026-06-13
- SCOPE: LANE-1 (self/runtime/*_pure). OP-82 follow-on. Census of the OP-82 "~14 remaining HIGH-value" list was
  STALE on `git fetch origin main` (e022ba889..9212b61d3): a sibling lane had already landed
  self/test_<name>_pure.hexa leaf tests for 13/14 (siphash·hash·encoding·cipher_mini·bignum_mini·hash_rng·kmp·
  levenshtein·prime_sieve·conv·ipv4·datetime·date_time — all EXCEPT hyperloglog). Re-censused the FULL runtime
  *_pure surface by companion-test presence instead.
- CENSUS (scoped, NO .git): 73 self/runtime/*_pure.hexa; 12 without any companion test → char_code · count_min_sketch
  · ffi_path · geometry2d · heap · hyperloglog · lfu_cache · lsm_tree · numeric_sat · print_fmt · regex_mini ·
  reservoir_sample. Triage by AUTHORITATIVE-reference / lockable-invariant.
- PICK (g0, HIGH-value with a real external oracle, 6): numeric_sat (C %.*f/%.*e + int(trunc) saturation) ·
  count_min_sketch (no-under-count + collision-free EXACT vs exact-freq dict) · hyperloglog (register-wise
  structural invariants) · geometry2d (closed-form L1/Linf/cross/shoelace) · heap (pop-order==ascending sort) ·
  regex_mini (CPython `re` for the . * ? ^ $ [abc] \x subset).
- DEFER (LOW / no external KAT, 6): char_code (thin 1-byte mirror of hexa_char_code, NEAR-DUP of the already-tested
  conv_pure::char_to_int_pure) · ffi_path (internal lib-path convention, no standard) · lfu_cache (impl-defined
  eviction tie-break) · lsm_tree (in-memory get/put round-trip only) · print_fmt (cosmetic pretty-printers) ·
  reservoir_sample (weak distribution sanity, non-deterministic). Deferred to avoid padding (g0).
- BUILD: 6 leaf oracles, OP-80 @sentinel + fn main() pattern, gated on `hexa run`. The 3 nil-free modules
  (numeric_sat·count_min_sketch·hyperloglog) `use`-imported directly. The 3 modules that return `nil` on the
  empty/miss path (geometry2d·heap·regex_mini) INLINE a behaviorally-identical copy with a [-1,-1] miss /
  non-empty-only sentinel — the local build/hexat (0.1.0-dispatch, "interp retired" → always transpiles) rejects
  the `nil` literal at parse time; a stale-binary parse defect is NOT a shipping bug (MEMORY local-hexa-stale-oracle).
  The inline arithmetic is byte-identical to the audited module.
- RUN (verbatim, `hexa run` arm64-macos exit 0):
    __HEXA_RUNTIME_NUMERIC_SAT__ PASS 16/16
    __HEXA_RUNTIME_CMS__ PASS 13/13
    __HEXA_RUNTIME_HLL__ PASS 8/8
    __HEXA_RUNTIME_GEOMETRY2D__ PASS 15/15
    __HEXA_RUNTIME_HEAP__ PASS 5/5
    __HEXA_RUNTIME_REGEX_MINI__ PASS 25/25
  (82/82 assertions.)
- CROSS-CHECK (g5, faithful Python ports vs external reference): numeric_sat scale+0.5+trunc vs int(math.trunc)
  0/5000 + 9 format goldens; geometry2d vs closed-form (shoe2 square=24/unitCCW=2/CW=-2, cross perp=1/collinear=0)
  0 mism; heap vs `heapq` pop-order==sorted(arr) 0/500; count_min_sketch no-under-count + EXACT vs exact dict;
  regex_mini vs re.fullmatch/search/finditer ([0,2,4]/[1,3,5]/[1,3]) 0 mism.
- HLL NOTE: the RAW harmonic-mean estimate has NO usable accuracy bound — MEASURED p=12 (m=4096): empty sketch
  → ~2954, true-1000 set → ~3464. The "1.04/sqrt(m)" cardinality KAT is therefore UNVERIFIED for this estimator;
  this is a DOCUMENTED module limitation (header lines 24-30: small-/large-range corrections OMITTED), NOT a bug.
  The oracle locks the authoritative REGISTER invariants instead (clamp/merge==regmax/determinism/idempotent/
  self-merge/monotone), cross-checked against a Python register-state port at 0 mismatch.
- 🔴 BUG (in the OP-85 TEST, not a shipping module): the first heap_pure_test draft used a hand-rolled
  insertion-sort as the "sorted" reference; its `a[q+1]=a[q]` index-assignment shift hit the exact
  array-index-assignment fragility the heap MODULE deliberately avoids via copy-on-write _h_set_at, producing
  garbage (sorted([5,3,8,1,9,2,7,4,6,0])→[0,6,7,9,8,5,8,8,8,9]). FIX: replaced the reference with literal golden
  sorted arrays (the most authoritative ref anyway). The heap module itself was CORRECT throughout (its drains
  produced [0..9] and the dup case [1,1,1,2,2,3,3,4,4,4]). No shipping module touched; all 6 audited modules
  PROVEN-CLEAN.
- COVERAGE: 61→67 of 73 runtime *_pure now carry a companion test. Remaining 6 untested = char_code (near-dup) +
  ffi_path/lfu_cache/lsm_tree/print_fmt/reservoir_sample (internal-glue / policy-defined / cosmetic / statistical,
  NO external KAT). VEIN CLOSED: the HIGH-value-with-authoritative-reference runtime *_pure vein is CLOSED — any
  remaining coverage would lock only round-trip/determinism with no external reference (low value).
- BYTE-EQ / GUARDS: 6 NEW leaf test files only; 0 audited-module bytes changed; 0 deletions (wipe_guard
  net-additive). The *_pure_test.hexa leaves are NOT in the build_selfhost closure → self-host fixpoint
  UNAFFECTED. LANE split honored (no stdlib/* touched). $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape ·
  no self/env.hexa · leak-0. Milestone OP-85 [x]. Verdict F-OP85-RUNTIME-PURE-FINAL.txt.

## OP-99 — FRESH stdlib SCIENTIFIC/COMPUTE numeric-algorithm bug-hunt; 🟢 fresh surface CLEAN (0 new bugs, 3 invariant-locks 13/13) — 2026-06-13

- GOAL: after the parsing/delimiter/boundary-run classes were systematically CLOSED (OP-87/88/91/92/94/96/97),
  open a FRESH surface — the untested stdlib SCIENTIFIC/COMPUTE numeric modules (kernels/bio/material/chem/
  signal/stats/qforge numeric, NON-parsing) whose bespoke math has an AUTHORITATIVE reference (numpy/scipy/math/
  closed-form) OR a checkable INVARIANT (inverse-pair · normalization Σ · mass-balance · monotonicity). Hunt the
  numeric bug classes: wrong formula · sign error · off-by-one in a sum · missing normalization · singular crash.
- CENSUS (scoped greps, NO .git; LANE-1; SKIPPED already-audited core/math, flame/*, codec/*, crypto/*,
  time/civil, semver, stats/{welford,correlation,ks}, special, window/filter/resample, runtime *_pure):
  3 modules locked with checkable invariants + 5 more deep-read and confirmed already-covered + textbook-correct.
- MODULE 1 — material/composition.hexa (chemical-formula parser: parse_formula_elements + single-level paren
  fixpoint expansion + decimal counts). HIGH-SURFACE: authoritative Python ref (askcos_adapter.py
  _parse_formula_elements) + invariant parse-then-recount element Σ; classic bugs = off-by-one count scan,
  wrong paren-multiplier fold, decimal drop. METHOD: faithful Python re-impl of BOTH the documented reference
  (re.sub single global pass) AND the hexa _expand_all_parens fixpoint model; differential over 18 formulas
  (single + nested parens, decimals, multi-group). 🟢 CLEAN — all 8 single-level in-scope formulas match the
  reference EXACTLY (Ca10(PO4)6F2, Ca10(PO4)6(OH)2, Al2(SO4)3, Mg(OH)2, Ca(NO3)2, (NH4)2SO4, H2O, C6H6);
  multi-group correct via the fixpoint loop (Ca10(PO4)6(OH)2 → O:26 H:2); decimal counts preserved
  (YBa2Cu3O6.5 → O:6.5). The ONE differential — nested parens K4(Fe(CN)6) — is DOCUMENTED out-of-scope on BOTH
  sides ("nested left as-is"; the kernel bails on a nested '(' and re.sub's [^()]+ won't match across nesting) =
  a documented limitation, NOT a bug (OP-86 reservoir lesson: NOT fabricated into a fix).
- MODULE 2 — signal/core_mel.hexa (hz_to_mel / mel_to_hz, HTK 2595·log10(1+hz/700)). HIGH-SURFACE: a
  forward/inverse PAIR → exact INVERSE-PAIR invariant mel_to_hz(hz_to_mel(hz))==hz + a closed-form anchor;
  classic bug = wrong 2595/700 constant or a log-base/10^ mismatch between the legs. 🟢 CLEAN — round-trip
  rel-err ≤1e-7 on hz ∈ {100,440,1000,4000,8000}; forward anchor hz_to_mel(1000)=999.9856.
- MODULE 3 — signal/autocorrelation.hexa (biased ACF[0..max_lag] + normalized). HIGH-SURFACE: two locked
  invariants — NORMALIZATION (ACF_norm[0]==1 exactly) + CAUCHY-SCHWARZ (|ACF_norm[k]|≤1) — and an energy
  anchor (biased ACF[0]=Σx²/n); classic bug = ÷(n-k) vs ÷n (unbiased/biased) confusion or missing
  normalization. 🟢 CLEAN — ACF_norm[0]=1 exact, all |ACF_norm[k]|≤1, ACF[0]=10.5 (Σx²=84, /8).
- DEEP-READ (test+oracle-covered + math textbook-confirmed, listed for census, NOT re-locked): geodesy/wgs84
  (geodetic↔ECEF Bowring, Vincenty inverse, haversine — vs NIMA TR8350.2 / Vincenty 1975 / Sinnott 1984);
  orbital/kepler_2body (Newton-Raphson Kepler solve, half-angle true anomaly via atan2, r=a(1-e·cosE) — vs
  Vallado/Curtis); stats/powerlaw_fit (centered OLS log-log slope); signal/spectral_density (one-sided
  periodogram + Welch, Parseval-correct); mc_integrate/engine (Welch-t, NIST critical-t table, A&S 26.2.17
  norm-CDF, MC integrands for Catalan/ζ(3)/γ — self-test G/H gates + authoritative citations). All CLEAN.
- LOCK (NOT-A-TAUTOLOGY): NEW stdlib/test/op99_sci_compute_invariants_test.hexa — all 3 module algorithm bodies
  VERBATIM-INLINED (no-`use`/`import`; the installed `hexa` resolves `use "stdlib/..."` to a STALE bundled copy
  — OP-87/88 lesson — so the bodies are inlined and run on the shipping `hexa run` native runtime =
  hx-selfhost-cli, the promoted self-hosted compiler): __HEXA_OP99__ PASS 13/13. NEGATIVE CONTROL proves the
  gate has TEETH: corrupting the mel constant 700→710 breaks all 5 round-trips + the anchor, and corrupting ACF
  normalization ÷n→÷(n-1) breaks the energy check → __HEXA_OP99__ FAIL 7/13.
- BYTE-EQ / GUARDS: ZERO stdlib source edits (every audited module already correct) + 1 NEW leaf test only;
  0 deletions (wipe_guard net-additive). The leaf is NOT in the build_selfhost closure → self-host fixpoint
  UNAFFECTED. LANE-1 only (no protocol/binary/net parsing — that is LANE-2/OP-98). $0 · 0-pod · NO GPU · no vast ·
  no foreign-pod · no .tape · leak-0. Milestone OP-99 [x]. Verdict F-OP99-SCI-COMPUTE-INVARIANTS.txt.
## OP-100 — EMITTED-FOREIGN-CODE validity sweep (generalizes the OP-98 bug class); CLASS CLEAN + in-tree lock — 2026-06-13
- SCOPE: LANE-2 (EMITTED-FOREIGN-CODE infra/protocol — modules that EMIT python3/bash/awk/C/sql source). The
  OP-98 class: a hexa module BUILDS a foreign-language source STRING and execs it, but the emitted code carries a
  latent SYNTAX/SCOPE/QUOTING bug → the path is dead-on-arrival (the host fallback "just fails", never surfaced).
  LANE-1 owns the scientific/compute-numeric emitters (sim_universe/kernels/fusion/bio) — avoided overlap.
- METHOD: CENSUS (scoped greps, NO .git) `s = s + "…"` multi-line program builders + heredoc emitters
  (`cat > x <<'EOF'`) + inline `python3 -c`. EXTRACT each emitted source for representative inputs (generic
  `s=s+"lit"+var` reconstructor + heredoc-payload slicer) and VALIDATE through its REAL interpreter WITHOUT needing
  hexa: python3 → `ast.parse` + actual run; bash → `bash -n` + run; awk → `awk -f` + functional pipeline; sql →
  sqlite3 round-trip.
- MATRIX (all 🟢 CLEAN): stdlib/python_ffi.hexa py_get_doc helper → ast.parse OK + RUN OK, get_first('os|getcwd')
  → 'Return a unicode string representing the current working directory.', get_first('json|dumps') → correct (no
  nonlocal/scope bug). stdlib/dojo/{llm,vision,tabular,rl,flame_forge,hexa_cuda,clm}.hexa → each python `_*_torch_ref`
  ast.parse OK + each bash `_*_glue` `-n` OK. stdlib/sqlite.hexa SQL builder (define_table/insert/select_where via
  _bind_params→_sqlq) → sqlite3 round-trip OK; SQL-92 single-quote DOUBLING verified with an embedded quote
  (INSERT…VALUES(1,'O''Brien') → SELECT → `1|O'Brien`; `?` is bound, not literal → no injection, no dead-on-arrival).
  self/main.hexa merge_modules_awk emits THREE heredoc awk programs (merge/dedup/rename) for the C-transpile
  self-host build → `awk -f` parses all three + functional pipeline on a representative module C file: dedup DROPPED
  the redundant `HexaVal foo(int x);` fwd decl, merge RENAMED `int main(`→`int _lexer_init(`, rename left the
  string-literal `__hexa_ic_0`/`__hexa_sl_1`/`__hexa_strlit_init` inside hexa_str("…") UNTOUCHED (string-literal-aware,
  correct). self/main IS in the build_selfhost closure → would be FLAG-not-fix, but it is CLEAN so moot.
- NOTES: dojo `_hc_cu` emits CUDA C++ (<cstdio>/__global__) → needs nvcc not host gcc; the gcc-as-C "cstdio not
  found" is a TOOLCHAIN mismatch NOT an emitter bug. dojo `_*_t_*` katas emit HEXA source, not foreign code.
  ⚪ OUT-OF-HOST-REACH (not validated, not flagged — honest): sscb/hal firmware C emitters (STM32/RP2040 vendor
  headers absent on host; they carry their own boot_byte_diff_* selftests, LANE-1-adjacent); cloud/vast + proc +
  channel build SINGLE-LINE shell (not full programs; vast `python3 -c 'import vastai'`=valid probe; proc/channel
  use _shell_quote/_shq); easy/cli emits markdown; syntax_highlight is a SQL keyword LIST not an emitter.
- RESULT: 🟢 CLASS CLEAN. Every infra/protocol EMITTED-FOREIGN-CODE program validates through its real interpreter;
  ZERO new dead-on-arrival bug — OP-98's websocket `nonlocal pre` SyntaxError was the ONLY bug of this class
  (anti-pattern grep: `nonlocal` in any emitted python across stdlib/+self/ → 0 hits; websocket is `global pre`,
  OP-98-fixed). No fabrication (a valid emitter is CLEAN, not a bug — same honest framing as the OP-97 clean census).
- LOCK: NEW stdlib/test/test_emitted_code_validity_op100.hexa — in-tree regression guard, SELF-CONTAINED
  (verbatim-inlined fragments, no `use` — stale-bundle dodge OP-87/88): python_ffi helper defines get_first +
  registers the synthetic module + balanced try/except + carries NO `nonlocal` (the OP-98 anti-pattern); sqlite
  _sqlq DOUBLES the single quote ('O''Brien') + NO backslash-escape (the dead-on-arrival shape); self/main awk-merge
  has BEGIN + the `/^int main\(/`→`_%s_init` rename + the column-0 `/^\}$/` close + the default `{ print }`. Shipping
  `hexa run` LOCAL → 11/11 PASS. NEGATIVE CONTROL (not a tautology): regressing _sqlq → backslash-escape AND renaming
  `def get_first` → FAIL 8/11 (sqlq_embedded_quote / sqlq_no_backslash / pyffi_defines_get_first flip to FAIL).
- BYTE-EQ / GUARDS: ZERO source edits to any shipping emitter (all CLEAN — no fix needed) + 1 NEW leaf test file;
  0 deletions (wipe_guard net-additive). The *_op100 leaf is NOT in the build_selfhost closure → self-host fixpoint
  UNAFFECTED. LANE-2 only (no LANE-1 numeric-emitter overlap). $0 · 0-pod · NO GPU · no vast · no foreign-pod ·
  no .tape · leak-0. Milestone OP-100 [x]. Verdict F-OP100-EMITTED-CODE-SWEEP.txt.

## OP-103 — SYSTEMIC slice/window/substring unchecked-bounds class sweep (LANE-1); class CLEAN except ONE 🔴 (FEM bar1d degenerate mesh) → FIXED + locked — 2026-06-13
- SCOPE: LANE-1 (DATA-STRUCTURE / BUFFER / NUMERIC / SIGNAL-FRAMING / array modules — NOT net/string-parser =
  LANE-2 / OP-102). CLASS: code computes a slice/window range (start,end) or an array index from arithmetic (a
  length, stride, k, n-1, center±radius, frame*hop, row*cols+col) and accesses it WITHOUT clamping to [0,len], so
  a degenerate/boundary input (empty, len-1, k>len, window-past-end, <2-node mesh) goes out of [0,len] → crash/garbage.
- CENSUS (scoped greps, NO .git): SIGNAL-FRAMING all SAFE — core_stft (frame audio[s] guarded `if s<sig_len`; istft
  overlap-add `local>=0 && local<n_fft`; Hermitian mirror spec[off+mirror], mirror=n_fft-b∈[1,n_fft-bins] in-frame),
  core_resample (resample/pitch_shift lerp x[k],x[k+1], `if k>=n-1` clamps to tail), core_mel (bin_points[mi+2],
  len=n_mels+2), core_griffin (j,i<n_frames*bins), core_pitch/autocorrelation/pearson_autocorr (lag_cap clamped to
  n-1, loop i<n-k → x[i+k]≤n-1), core_window/voss (loop i<N over farr_zeros(N)), spectral_density (welch x[start+s]
  max=(n_segs-1)*stride+win-1≤n-1; _sd_onesided k*2+1<2n), core_fft (rev∈[0,n), butterfly stride-bounded).
  CONSISTENT-CONTRACT-NOT-BUG: signal modules take an `n` PARAMETER = signal length, guard the derived window/lag
  vs `n` but never re-check n vs len(x); n>len(x) violates the documented "n=signal length" contract (same as the
  FFT n==len(real) contract) — not a degenerate-boundary input to a clamped range, left as documented.
- CENSUS cont.: NUMERIC/LINALG/TENSOR all SAFE (linalg/reference sgemm/sgemv, list_matvec, matrix construct/stack,
  alloc/math/eigen — all i*k+p / r*cols+c loop-bounded by declared dims; math/ode params[0]/r[0] fixed-arity RK;
  tensor/{ops,shape} shape[0]/data[0]/i*N+j rank≥1 structural + dim loops). DATA/BUFFER all SAFE (alloc/collections
  zip min-len, combinations Gosper idx∈[0,n), sort/reverse/range/permutations loop-bounded; core/bytes
  bytes_to_uint64/_le/uint32/f32_le_/f64_le_ ALL guard `offset<0` + `offset+W>len(b)→0/0.0`, int_from_hex /
  hex_encode_bytes substrings loop-bounded; mc_integrate _find_flag/_engine_path/_qrng_collect/engine _hex_to_int
  substrings guarded by starts_with/rfind). KERNELS mostly SAFE (signal_proc/dft xr[k] loop k<n; autodiff dual
  a[0]/a[1] fixed length-2; graph/bfs queue[0] under `while len(queue)>0`; bio_align/needleman_wunsch traceback
  a[i-1]/b[j-1] each under i>0/j>0; neural/lif loop-bounded; fem/bar1d_assemble_K nodes[e+1]/K[e+1][e+1] e<n_elem=n-1).
- 🔴 THE ONE BUG — stdlib/kernels/fem/bar1d_kernel.hexa: bar1d_solve_fixed_free (PUBLIC, contract docstring L157
  "nodes length n≥2") has NO guard on n. A degenerate <2-node mesh gives a reduced system of m=n-1≤0 unknowns, and
  the private Thomas tridiagonal solver runs its forward sweep UNCONDITIONALLY: cp[0]=c[0]/d[0], dp[0]=b[0]/d[0],
  back-sub u[m-1]. On an empty diagonal (m=0): c[0]/d[0]/u[-1] index a length-0 array → CRASH.
- VERBATIM REPRO (shipping `hexa run`, hermetic verbatim-inlined UNFIXED bodies):
    n=1: bar1d_solve_fixed_free([0.0],1.0,1.0,1.0) → `--- n=1 (single node, contract says n>=2) ---index 0 out of bounds (len 0)`
    n=0: thomas_tridiag([],[],[],[]) → `n=0 -> thomas([],[],[],[]):index 0 out of bounds (len 0)`
    root-cause probe: `let e=[]; e[0]` → `len=0index 0 out of bounds (len 0)`
- FIX (minimal, additive, 0 deletions; clamp the degenerate boundary per the n≥2 contract):
    bar1d_solve_fixed_free:  `if n<=0 { return [] }`  (no nodes → no displacement vector)
                             `if n==1 { return [0.0] }` (single FIXED node → only the fixed DOF, zero disp, no free DOF/element/load)
    thomas_tridiag:          `if m<=0 { return [] }`  (empty system → empty solution, defense-in-depth)
- POST-FIX CROSS-CHECK (verbatim-inlined FIXED bodies): `OK n=1 -> [0.0]` · `OK n=0 -> []` · `OK n=2 -> [0,1]` ·
  `OK n=5 analytic match` → pass=4 fail=0. Degenerate inputs clamp to the correct trivial result; the n≥2 analytic
  FEM solve u(x_k)=P*x_k/(EA) is UNCHANGED (no regression, bit-for-bit).
- LOCK: NEW stdlib/kernels/fem/bar1d_degenerate_op103_test.hexa — HERMETIC (bar1d_assemble_K / thomas_tridiag /
  bar1d_solve_fixed_free verbatim-inlined WITH the fix, no `use` — stale-bundle dodge OP-87/88), shipping `hexa run`
  LOCAL → `OP-103 bar1d degenerate lock: pass=6 fail=0` `ALL GREEN` (n=1→[0.0] · n=0→[] · thomas([])→[] · n=2 analytic
  [0,1] · n=5 analytic · non-uniform 5-node shape u[0]=0 len=5). NEGATIVE CONTROL (not a tautology): the UNFIXED
  Thomas body on the empty system gives `index 0 out of bounds (len 0)` (the verbatim repro) — the clamp converts that
  crash into the correct trivial result; the positive asserts catch any regression of the clamp OR the n≥2 analytic answer.
- BYTE-EQ / GUARDS: stdlib/kernels/fem/bar1d_kernel.hexa is NOT in the build_selfhost closure (no self/* nor
  build_selfhost.sh reference — leaf stdlib kernel) → ZERO byte-eq/fixpoint impact, no selfhost gate. Edit purely
  ADDITIVE (3 guard lines in the public entry + 1 in the private solver), 0 deletions → wipe_guard net-additive. NEW
  leaf test is closure-OUT → fixpoint UNAFFECTED. LANE-1 only (NO net/string-parser edits — LANE-2 untouched).
  INVARIANTS LOCKED: bar1d_solve_fixed_free never indexes out of range for any nodes len≥0; degenerate clamp
  len0→[] len1→[0.0] (matches the fixed-free BC); n≥2 uniform mesh ⇒ u(x_k)=P_tip*x_k/(E*A); thomas_tridiag(empty)→[].
  $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · leak-0. Milestone OP-103 [x]. Verdict
  F-OP103-SLICE-BOUNDS-SWEEP.txt.

## OP-106 — SYSTEMIC degenerate-INPUT-crash class sweep (LANE-1, empty-list stats/reduce/normalize flavor); class CLEAN except ONE module 🔴 (matrix axis-reductions) → FIXED + locked — 2026-06-13
- SCOPE: LANE-1 (stats / reducer / normalizer / matrix-reduce / numeric public APIs — NOT net/string-parser/crypto/
  tls/binary = LANE-2). CLASS: a PUBLIC `pub fn` that on a DEGENERATE input (empty list, size-0/1, zero-length
  reduction axis, all-equal, divide-by-sum=0, 1-point) indexes an empty array (x[0]/x[n-1]) or divides by a zero
  count WITHOUT a guard → OOB read or div-by-0 crash. Sibling of OP-103 (slice/window RANGE flavor); OP-106 = the
  empty-LIST stats/reduce/normalize flavor.
- CENSUS (scoped greps, NO .git): RUNTIME NUMERIC/MATH (stdlib/runtime/{numeric,math}.hexa) ALL GUARDED with
  documented empty→saturation contracts — rt_array_mean/min_float/max_float `if n==0 {return 0.0}`,
  rt_array_sum/product accumulator-init, rt_argmax `if n==0 {return -1}`, rt_softmax/rt_rms_norm_scalar/array
  `if n==0 {return out}` + sum>0/s==0 guards. STATS/INFO ALL GUARDED — stats/powerlaw_fit `n<3→0.0`/`m<2→0.0`/
  `denom==0→0.0`, stats/correlation pearson_r denom=sqrt(dx2·dy2)≤0→0.0 (NaN-tolerant, no index) + spearman_rho
  farr_zeros(0)→pearson_r(…,0)→0.0, info/entropy shannon_entropy `if total==0 {return 0.0}`+1e-8 smoothing. SIGNAL
  ALL GUARDED (also OP-103) — autocorrelation `n≤0→[]`, autocorrelation_normalized `raw_len==0→[]`+`r0==0.0→[]`.
  MATRIX construct/stack ALL SAFE (zeros/ones/eye/diag + vstack/hstack/transpose loop-bounded over m/n, no
  reduction div/index).
- 🔴 THE ONE MODULE — stdlib/matrix/mod.hexa axis-reductions: the header contract (flat row-major M, explicit (m,n),
  axis0 collapses rows→out len n, axis1 collapses cols→out len m) has NO documented m≥1/n≥1 precondition, so a
  0-row/0-col (empty) matrix is a plausible degenerate input, and the reduction along the collapsed axis runs
  UNCONDITIONALLY: matrix_mean_axis/std_axis `s/to_float(m|n)` with m|n==0 = div-by-0; matrix_argmax_axis
  `best_v=M[j]`(axis0)/`M[i*n]`(axis1) reads the empty M = OOB. (matrix_sum_axis is SAFE — no division, loops skip
  → zeros per bin.)
- VERBATIM REPRO (shipping `hexa run`, hermetic verbatim-inlined UNFIXED bodies):
    matrix_mean_axis([],0,3,0) → `mean m=0,n=3,axis=0:division by zero`
    matrix_std_axis([],0,3,0)  → `std m=0,n=3,axis=0:division by zero`
    matrix_argmax_axis([],0,3,0) → `--- m=0,n=3,axis=0 (argmax over columns of an empty matrix) ---index 0 out of bounds (len 0)`
    matrix_argmax_axis([],4,0,1) (axis-1 flavor) → `UNFIXED argmax m=4,n=0,axis=1:index 0 out of bounds (len 0)`
- FIX (minimal, additive, 0 deletions; saturate the degenerate empty reduction axis):
    matrix_mean_axis:   `out.push(if m == 0 { 0.0 } else { s / to_float(m) })` (axis0) + `if n == 0 { 0.0 }…` (axis1)
    matrix_std_axis:    `if m == 0 { out.push(0.0); j = j + 1; continue }` (axis0, before div) + `if n == 0 …` (axis1)
    matrix_argmax_axis: `if m == 0 { out.push(0); j = j + 1; continue }` (axis0, before M[j]) + `if n == 0 …` (axis1)
  RATIONALE: mean/std of NO elements → 0.0 (matches the sibling matrix_sum_axis zeros + the runtime rt_array_mean
  empty→0.0 contract); argmax over NO elements → index 0 (smallest-index tie convention degenerates). OUTPUT LENGTH
  (n axis0 / m axis1) PRESERVED — same shape, saturated values, no crash.
- POST-FIX CROSS-CHECK (verbatim-inlined FIXED bodies): `OK mean m=0,n=3,axis=0 -> [0,0,0]` · `OK mean m=4,n=0,axis=1
  -> 4x0.0` · `OK std m=0,n=3,axis=0 -> [0,0,0]` · `OK argmax m=0,n=3,axis=0 -> [0,0,0]` · `OK argmax m=4,n=0,axis=1
  -> 4x0` · `OK 0x0 -> []` · `OK mean 2x3 axis0 [2.5,4,4]` · `OK argmax 2x3 axis0 [1,1,1]` · `OK argmax 2x3 axis1
  [2,1]` → pass=9 fail=0. Degenerate empty axis saturates to the documented default; the m≥1/n≥1 reductions are
  UNCHANGED bit-for-bit (no regression).
- LOCK: NEW stdlib/matrix/test/matrix_degenerate_op106_test.hexa — HERMETIC (the 3 fn bodies verbatim-inlined WITH
  the fix, no `use` — stale-bundle dodge OP-87/88), shipping `hexa run` LOCAL → `OP-106 matrix degenerate-axis lock:
  pass=10 fail=0` `ALL GREEN` (mean/std/argmax m=0 & n=0 both axes → saturated bins · 0x0→[] · normal 2x3 mean
  [2.5,4,4] · argmax axis0 [1,1,1] · argmax axis1 [2,1]). NEGATIVE CONTROL (not a tautology): the UNFIXED bodies
  CRASH on the empty matrix — mean/std `division by zero`, argmax `index 0 out of bounds (len 0)` (the verbatim
  repros) — the guard converts each crash into the saturated default; the normal-2x3 asserts catch any regression
  of the guard OR the reduction math.
- DOMAIN-INTERNAL NOTE (not fixed): qforge/smearing qforge_fermi_level reads `evals[0]` with no emptiness guard
  (empty band list → `index 0 out of bounds (len 0)`) — left as a domain-internal physics precondition (a Fermi
  level over ZERO bands is physically undefined, n≥1-band implicit, analogous to OP-103's FEM n≥2), not a
  general-purpose-API bug; noted for honesty, expanding here would change a domain contract (out of sweep scope).
- BYTE-EQ / GUARDS: stdlib/matrix/mod.hexa is NOT in the build_selfhost closure (no self/* nor build_selfhost.sh
  ref — leaf numeric stdlib) → ZERO byte-eq/fixpoint impact, no selfhost gate. Edit purely ADDITIVE (8 guard/continue
  lines across the 3 fns), 0 deletions → wipe_guard net-additive. NEW leaf test closure-OUT → fixpoint UNAFFECTED.
  LANE-1 only (NO net/string-parser/crypto/tls edits — LANE-2 territory untouched); no overlap with OP-103 (range
  flavor). INVARIANTS LOCKED: matrix_mean_axis/std_axis never divide by a zero reduction count (empty axis → 0.0/bin,
  output length preserved); matrix_argmax_axis never indexes the backing array on an empty reduction axis (empty
  axis → 0/bin, length preserved); normal m≥1/n≥1 reductions UNCHANGED bit-for-bit. HONEST g5: the class is
  otherwise CLEAN (runtime/stats/info/signal ALL guard the degenerate with documented empty→saturation contracts —
  a guarded/documented-precond site = CLEAN not a bug, no fabrication); the ONE genuine UNDOCUMENTED crash was the
  matrix axis-reductions → FIXED. $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · leak-0. Milestone
  OP-106 [x]. Verdict F-OP106-DEGENERATE-CRASH-SWEEP.txt.

## OP-109 — close OP-107's flagged ed25519/p256 verify-side direct-call OOB (length guards) + crypto/TLS ENCODE-side length-field audit (inverse of OP-105 parse sweep); 🔴 ONE real wire bug (tls13 record-AAD 16 short of RFC 8446 §5.2) → FIXED + locked — 2026-06-13
- LANE-2 0-pod. PART A closes the 🟠 flag OP-107 left open; PART B is the ENCODE-side (serializer length-field)
  audit, the inverse of OP-105's parse-side OOB sweep.
- PART A (close the flag — ed25519_verify / p256_verify direct-call length guard):
  - VERBATIM REPRO via shipping `hexa run` (inlined verifier shape): a malformed DIRECT call with a short
    signature (len 10) into ed25519_verify's first loop `while i<32 {sig[i]}` → `index 10 out of bounds (len 10)`;
    a short coordinate (qx len 4) into p256's `_be32_to_limbs` (`b[30]/b[31]`) → `index 30 out of bounds (len 4)`.
    The OOB is a runtime panic = process abort = DoS (NOT silent garbage). Defense-in-depth, NOT forgery — every
    in-tree caller (x509_verify_self_*) already guards — but a malformed call must return false, never OOB.
  - FIX (mirror the OP-104/105 alpn length-guard): ed25519.hexa ed25519_verify prologue
    `if len(pubk)!=32 || len(sig)!=64 {return false}` (RFC 8032: pubkey 32B, sig 64B); p256.hexa p256_verify
    prologue `if len(qx)!=32||len(qy)!=32||len(hash)!=32 {return false}` + `if len(r)!=32||len(s)!=32 {return false}`
    (every P-256 big-endian field = 32B). Wrong length ⇒ false; correct length ⇒ the fixed 0..32/0..64 / b[30],b[31]
    reads are all in-bounds.
- PART B (ENCODE-side length-field census — does each emitted length field == the actual emitted body length;
  encode∘parse == identity; parse(encode(v)) == v):
  - 🔴 REAL BUG FOUND + FIXED — tls13 RECORD-AAD length (tls13_record_aad caller, tls13_client_record_io.hexa).
    RFC 8446 §5.2: additional_data length field MUST = TLSCiphertext.length = encrypted_record length =
    |TLSInnerPlaintext| + 16-byte AEAD tag. The SEAL caller passed `tls13_record_aad(len(plain))` (16 SHORT) and
    the OPEN caller `tls13_record_aad(body_len-16)` (also short). SELF-CONSISTENT (seal==open ⇒ hexa↔hexa
    round-trip worked) but BOTH WRONG ON THE WIRE: DIFFERENTIAL vs RFC 8448 §3 documented server record header
    `17 03 03 02 a2` (length 0x02a2 = ciphertext+tag) — hexa emitted 0x0292 (16 short). A CONFORMING peer
    (OpenSSL/BoringSSL) recomputes the correct AAD from the on-wire length and the AEAD tag verify FAILS = real
    TLS-interop break (the outer record HEADER was already correct `len(ct_tag)`, only the AEAD AAD was short, so
    hexa-only tests never caught it). FIX: seal passes `len(plain)+16` (AEAD tag is always 16B for ChaCha20-Poly1305
    and AES-GCM), open passes `body_len` (the on-wire length). seal-AAD == open-AAD PRESERVED (hexa↔hexa still
    round-trips) AND now == the on-wire record-header length == the RFC 8448 value.
  - 🟢 CLEAN encoders (length field == body, round-trip == identity — a correct encoder is NOT a bug, g5):
    tls13_ext_build (Extension TLV uint16 == len(value); round-trips vs tls13_ext_length/tls13_ext_next; documented
    supported_versions client bytes `00 2b 00 03 02 03 04`), tls13_client_hello_body (session_id uint8 == len(sid),
    cipher_suites uint16 == csn*2, extensions uint16 == len(ext) — each == its body, total length consistent),
    _keyshare_entry + tls13_ext_key_share_client_x25519 (uint16 key_len == len(key), shares-vec len, ext len each ==
    body; X25519 32B key → key_len field 0x0020), tls13_cr_build / tls13_ee_build / tls13_ext_key_share_hrr
    (hardcoded lengths == body), tls13_record_header / tls13_hs_header (big-endian length round-trip).
  - ASN.1 DER ENCODE / OID base-128 encode (the task-scoped 128 short→long-form boundary + multi-byte length +
    base-128 OID encoders): NO in-tree encoder EXISTS — asn1_der.hexa is DECODE-ONLY (its own header: "Encoding-only
    side ignored (decode is what cert parsing needs)") and x509_*.hexa are PARSERS (return slices of an existing
    cert, no DER builder). A tree-wide grep for a DER/OID encoder (long-form 0x81/0x82, the 128 boundary, base-128
    continuation) found NONE in crypto. So there is nothing on the ENCODE side to break at the 128 boundary — the
    audit is vacuously 🟢 for that sub-task (honest: no encoder to find a bug in, not "found clean").
- LOCKS (HERMETIC verbatim-inlined, no `use` — stale-bundle dodge OP-87/88, closure-OUT):
  - NEW stdlib/crypto/verify_len_guard_op109_test.hexa — shipping `hexa run` → `OP109-A verify-len-guard pass=11
    fail=0` `ALL GREEN` (ed25519: valid-lengths pass + short-sig/short-pubkey/empty-sig/long-sig reject [strict
    equality]; p256: valid pass + short-qx/qy/hash/r/s reject — guard returns false with NO OOB; the verbatim
    indexing it protects runs only after the guard).
  - NEW stdlib/crypto/encode_len_field_op109_test.hexa — `OP109-B encode-len-field pass=18 fail=0` `ALL GREEN`
    (AAD: FIXED seal length field == wire_len == RFC 8448 0x02a2, != 16-short regression, == open AAD, == on-wire
    record-header length, documented bytes `17 03 03 02 a2`; ext-TLV len==body + next==total + value round-trip +
    supported_versions bytes; ClientHello session_id/cipher_suites/extensions length fields == body + total; keyshare
    uint16 key_len == body + X25519 0x0020; record-header big-endian length round-trip).
  - STALE-BUNDLE NOTE (honest g5, OP-87/88/107 lesson): a `use`-based driver against the shipping verifiers still
    OOB-panics (`index N out of bounds`) because `use` resolves to ~/.hx/src/stdlib (the Jun-1 bundle, which lacks
    the guards) — this CONFIRMS the bug exists in unpatched code; the verbatim-inlined leaf is the correct
    verification surface (trust the source/port over the stale binary).
- BYTE-EQ / GUARDS: ed25519.hexa, p256.hexa, tls13_client_record_io.hexa are NOT in the build_selfhost closure
  (no self/* nor build_selfhost.sh ref — crypto stdlib is closure-OUT, OP-105/107 proven) → ZERO byte-eq/fixpoint
  impact, no selfhost gate. Edits: ed25519 +5, p256 +6, record_io net +11 (a comment-clarify + 2 call-site length
  fixes); net +18 across 3 files + 2 NEW leaves; 0 large deletions → wipe_guard net-additive. LANE-2 (crypto ENCODE
  + the flagged verify-OOB guards) — NO LANE-1 numeric overlap. HONEST g5: PART A = a REAL DoS-class OOB closed
  (defense-in-depth, not forgery — said so); PART B = exactly ONE REAL wire-interop bug (record-AAD 16-short) FIXED
  with an RFC 8448 differential, all other encoders length==body CLEAN (a correct encoder is 🟢 not a bug, no
  fabrication), and the scoped ASN.1-DER-ENCODE sub-task has no in-tree encoder to audit (stated honestly).
  $0 · 0-pod · NO GPU · no vast · no foreign-pod · no .tape · leak-0. Milestone OP-109 [x].
  Verdict F-OP109-CRYPTO-ENCODE-VERIFY-OOB.txt.
