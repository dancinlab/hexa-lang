# Frontier next-round designs (2026-07-10 · workflow wf_1c1fb1b6)

4 read-only design/analysis agents while L1-B byteeq (#4813) ran. L1-A=SOUND (impl-clear), R1c-stage=implemented here, R1b/L2=designs banked.

---

# L1-A field-key interning — SOUNDNESS pre-review (read-only)

VERDICT: SOUND. All key-free sites are covered (exactly 4 = 2 logical × 2 copies, verified exhaustively), hexa_intern_owns() is an exact pointer-identity test given the never-moving/never-freed intern buckets, and mixed ownership resolves correctly per-key. No missed free site, no false-positive/false-negative in the guard. Proceed with 3 non-blocking caveats to bake into the implementation.

## exact_plan
HUNT (1) — free-site completeness: CONFIRMED exactly 4, no others. Emitter cites (origin/main self/runtime_core_emit.hexa):
• F1 hexa_map_remove_impl :4722 `free(t->slots[si].key);` — NO from_arena guard.
• F2 hexa_val_free_tree TAG_MAP :6096 `if(t->slots[i].key) free(...)` — inside `if(t && !t->from_arena)` guard (:6093).
• F1' mirror self/native/rtcore_collection-mutate_emit.hexa:216 (byte-identical body).
• F2' mirror self/native/rtcore_runtime-misc_emit.hexa:296 (guarded by !from_arena :293).
Ruled OUT as free sites by reading full bodies: hmap_grow :3670-3692 moves keys by struct-copy `new_slots[idx]=old_slots[i]` (:3682) and frees ONLY old_slots/old_vals arrays (:3689-3690), never a key. hmap_heapify :5634-5655 is CREATE-only (`dst->slots[idx].key=hxlcl_strdup(k)` :5649), frees no src key. map_set UPDATE branch :3983-3993 writes only vals/order_vals, key untouched. sort_by :7433 frees temp HexaVal arrays (`keys`=sort-keys, not slot keys). order_keys[i] aliases slots[si].key (shared, :4039) so free happens once via the slot loop; the array is freed separately (:6107) — no double-free.

HUNT (2) — owns() exactness: EXACT. Buckets never move/free — hexa_intern_grow (:806-826) reallocs only the bucket ARRAY and re-hashes the SAME dup pointers; strings via hexa_strbuf_dup_n (:997) are never freed. owns() recomputes hexa_fnv1a + mask=(cap-1) identically to hexa_intern (:954-955), so its linear probe reaches any interned p before an empty slot (load<75% guarantees a terminator) ⇒ NO false-negative (no free-of-interned). owns()==1 requires bucket[idx]==p literally; an hxlcl_strdup/heapify dup is a distinct LIVE allocation that cannot alias a live bucket ⇒ NO false-positive (no leak). Length guard consistent: interned ⇒ len<INTERN_MAX_LEN=64 (:945), owned≥64 ⇒ owns returns 0 ⇒ freed, matching C1's `intern?:strdup` fallback (:4011). NULL/pre-init handled by the plan's `if(!p||!__hexa_intern.buckets)`.

HUNT (3) — mixed ownership per-key: WORKS. C1 :4011 interns-or-dups PER KEY (<64→shared bucket, ≥64→owned dup). A struct-pack map (C2/C3 interned) later map_set with a new heap key ⇒ each slot key is an independent ownership class; F1/F2 test owns(k) PER SLOT (not a per-table flag), skip interned, free owned. UPDATE reuses the existing key (no free/no recreate) so class is stable across mutation.

HUNT (4) — mirror lockstep: REQUIRED and COVERED. Main hexa_map_remove_impl is #if'd to EXTERN under `HEXA_RT_SELFEMIT || HEXA_RT_CORE_COLLECTION_MUTATE_NATIVE` (:4697-4698) ⇒ on the self-emit/native lane the SHARD body (:216) is the LIVE free site, so editing only main would leave the byteeq self-emit lane with an unguarded free-of-shared-interned = double-free/corruption. Plan edits F1/F1'/F2/F2' in lockstep. Shards declare hexa_map_set_impl/remove_impl extern (:131-132) — no separate intern table, keys created by main map_set's __hexa_intern ⇒ owns() (extern, defined in runtime_core.c beside the file-local static __hexa_intern) reads the one shared table. Correct.

## risk
Three non-blocking caveats the implementation must honor (none invalidate the design):
(A) F1 (map_remove :4722) has NO `from_arena` guard, so the plan's `if(!owns(k))free(k)` also does NOT protect an arena kdup on the remove path — owns(arena_kdup)=0 ⇒ free(arena_mem) still called = UB. This is PRE-EXISTING (arena+map.remove already free()'d arena keys) and INERT on the self-emit lane (census arena_live=0), so interning neither creates nor fixes it. Guard: do NOT let the plan claim it makes arena sound; keep C4/C5 arena lanes explicitly out of scope (plan §8 already does).
(B) Byte-identity between the shard bodies and the main #else arms is asserted "SSOT byte-identical" — the inserted text `if (!hexa_intern_owns(k)) free(k);` must be char-for-char identical at all four sites (it is, since surrounding code matches); a stray whitespace diff could trip a shard-parity check. Also add `extern int hexa_intern_owns(const char*);` prototype to BOTH shards (owns() lives only in runtime_core.c) — plan implies but should list it as an explicit step.
(C) HEXA_RT_INTERN_NATIVE lane: hexa_intern delegates its find-probe to a native body, but owns() does its OWN direct linear probe over the shared global __hexa_intern (storage NOT relocated by that flag) ⇒ sound, but plan doesn't mention this flag; add a one-line confirmation that owns() is intern-flag-agnostic.
All guarded by the plan's own gate: pin self.o sha 165ffa6f (6,869,920 B) + byteeq 3-target + ASAN soundness smoke (short/≥64B keys, remove-all→reinsert→free_tree) before merge.

## recommendation
proceed — design is sound as written; implement after PR #4813 (L1-B) merges. Bake caveats A/B/C into the implementation checklist. Mandatory gate before merge (default-safe, no flag needed by construction, but VERIFY not trust): self.o sha pin + byteeq 3-target GREEN + the §6.5 ASAN standalone-runtime smoke (must show no free-of-interned and no leak-of-owned across short<64B, ≥64B, and mixed struct-pack+dynamic-key maps with remove/reinsert). Land commit-B (right-sizing) and commit-A (interning) separately as the plan specifies so a byteeq trip is bisectable.
---

# R1b strtod-anomaly — exact-parser differential oracle (pre-flip gate design)

VERDICT: SOUND to design. The missing gate is a variant of scripts/scratch/rt_native/float_dtoa_shortest_gate.c that swaps the round-trip checker from rt_parse_float_native (Clinger, sentinel→strtod) to rt_str_parse_float_exact and asserts, per native %g-candidate string, that (a) the exact parser NEVER declines (TAG_VOID) on finite input and (b) its bits == strtod's bits — plus final-string byte-identity vs the C snprintf%.*g+strtod path. This closes the "compose two separate proofs, no gate runs them together" hole the review flagged. Design-only; the flip stays a separate held PR.

## exact_plan
NEW FILE: scripts/scratch/rt_native/float_dtoa_shortest_exact_gate.c (sibling of float_dtoa_shortest_gate.c). It is that gate with the checker swapped + two per-candidate assertions added. Full content:

/* float_dtoa_shortest_exact_gate.c — R1b EXACT-parser differential oracle.
 * @state-ok: sibling of float_dtoa_shortest_gate.c; regenerable C differential
 * gate kept beside its peers in rt_native. This is the PRE-FLIP gate for
 * HEXA_RT_NUM_PARSE_FLOAT_EXACT (the flip stays a separate held PR).
 *
 * float_dtoa_shortest_gate.c checks the round-trip with rt_parse_float_native
 * (Clinger, sentinel->strtod) — it does NOT exercise rt_str_parse_float_exact,
 * the parser the EXACT-substituted shipping path uses (site A
 * self/runtime_emit_full.hexa:14574, design edits B/C runtime_core_emit.hexa
 * :8030/:8043). This gate mirrors site A's native round-trip EXACTLY, using
 * rt_str_parse_float_exact as the value checker over the full finite corpus,
 * and asserts 0-diff vs the C snprintf %.*g + strtod default on all 3 targets.
 *
 * Build (opt-in; pool only — mini is git/gh/read):
 *   aprime_cc _drv.hexa --emit=obj --target=<T> -o num_float_core.o \
 *       stdlib/runtime/num_float_core.hexa
 *   aprime_cc _drv.hexa --emit=obj --target=<T> -o float_parse_exact.o \
 *       stdlib/runtime/float_parse_exact.hexa
 *   clang -O2 -std=gnu11 float_dtoa_shortest_exact_gate.c num_float_core.o \
 *       float_parse_exact.o ~/.hx/bin/build/runtime.a -lm -o g && ./g
 *   (<T> in x86_64-linux-gnu | aarch64-linux-gnu | arm64-apple-darwin)
 * Exit 26 = full pass. 1 = a byte / decline / value divergence.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

typedef enum { TAG_INT=0, TAG_FLOAT, TAG_BOOL, TAG_STR, TAG_VOID } HexaTag;
typedef struct HexaVal_ { HexaTag tag; union { int64_t i; double f; char* s; void* p; }; } HexaVal;
#define HX_TAG(v)   ((v).tag)
#define HX_STR(v)   ((v).s)
#define HX_FLOAT(v) ((v).f)

/* the two seeds the EXACT shipping path composes (site A) */
extern HexaVal rt_format_float_native(HexaVal v, HexaVal sig);
extern HexaVal rt_str_parse_float_exact(HexaVal s);   /* NOT rt_parse_float_native */

static long fails=0, declines=0, parse_diff=0, total=0;

static HexaVal hxf(double d){ HexaVal v; v.tag=TAG_FLOAT; v.f=d; return v; }
static HexaVal hxi(int64_t n){ HexaVal v; v.tag=TAG_INT; v.i=n; return v; }
static HexaVal hxs(char* p){ HexaVal v; v.tag=TAG_STR; v.s=p; return v; }
static double frombits(uint64_t u){ double d; memcpy(&d,&u,8); return d; }
static uint64_t bits(double d){ uint64_t u; memcpy(&u,&d,8); return u; }

/* C reference = site A #else (runtime_emit_full.hexa:14590-14594): the canonical
 * default byte target. Loop 1..16 then explicit 17, matching the shipping shape. */
static void cshortest(double f, char* out, size_t cap){
    for(int p=1;p<17;p++){
        snprintf(out,cap,"%.*g",p,f);
        if(strtod(out,NULL)==f) return;
    }
    snprintf(out,cap,"%.17g",f);
}

/* EXACT native arm = faithful mirror of site A (runtime_emit_full.hexa:14571-14588).
 * Selection uses the EXACT parser's returned value; the per-candidate cross-check
 * IS the differential oracle the review requires. finite==1 gates the decline
 * assertion (inf/nan never reach _shortest_double; the exact parser declines on
 * them by design, float_parse_exact.hexa:373/:395/:403). */
static void natshortest_exact(double f, char* out, size_t cap, int finite){
    uint64_t fb = bits(f);
    for(int p=1;p<17;p++){
        HexaVal r = rt_format_float_native(hxf(f), hxi(p));
        if(HX_TAG(r)!=TAG_STR || !HX_STR(r)) break;
        HexaVal pv = rt_str_parse_float_exact(r);
        /* ORACLE 1 — never-decline on a native %g candidate (finite only) */
        if(finite && HX_TAG(pv)!=TAG_FLOAT){
            declines++;
            if(declines<=40) fprintf(stderr,"[exact] DECLINE on %%g cand \"%s\" (f bits=0x%016llx)\n",
                                     HX_STR(r),(unsigned long long)fb);
        }
        /* ORACLE 2 — exact value == strtod value on that same candidate string */
        if(HX_TAG(pv)==TAG_FLOAT){
            double sd = strtod(HX_STR(r),NULL);
            if(bits(HX_FLOAT(pv))!=bits(sd)){
                parse_diff++;
                if(parse_diff<=40) fprintf(stderr,"[exact] VALUE cand=\"%s\" exact=0x%016llx strtod=0x%016llx\n",
                    HX_STR(r),(unsigned long long)bits(HX_FLOAT(pv)),(unsigned long long)bits(sd));
            }
            if(bits(HX_FLOAT(pv))==fb){ snprintf(out,cap,"%s",HX_STR(r)); return; }
        }
    }
    { HexaVal r = rt_format_float_native(hxf(f), hxi(17));
      if(HX_TAG(r)==TAG_STR && HX_STR(r)){ snprintf(out,cap,"%s",HX_STR(r)); return; } }
    snprintf(out,cap,"%.17g",f);
}

static void chk(double d){
    char cref[64], cnat[64];
    int finite = isfinite(d);
    cshortest(d,cref,sizeof cref);
    natshortest_exact(d,cnat,sizeof cnat,finite);
    total++;
    /* ORACLE 3 — final selected string byte-identical to the C default path */
    if(strcmp(cref,cnat)){
        fails++;
        if(fails<=40) fprintf(stderr,"[exact] STRING bits=0x%016llx exact=\"%s\" cref=\"%s\"\n",
                              (unsigned long long)bits(d),cnat,cref);
    }
}

int main(void){
    if(sizeof(HexaVal)!=16){ fprintf(stderr,"sizeof(HexaVal)!=16\n"); return 2; }
    /* corpus IDENTICAL to float_dtoa_shortest_gate.c (apples-to-apples full finite corpus) */
    double reps[] = {
        0.0,-0.0,0.5,-0.5,0.25,0.125,2.5,3.5,
        0.1,0.2,0.3,0.30000000000000004,1.0/3.0,
        1.0,-1.0,42.0,100.0,3.0,9999.0,
        1e21,1e-7,1e308,1e-308,1e22,1e-22,1e23,1e-23,
        1.7976931348623157e308,2.2250738585072014e-308,
        9007199254740992.0,9007199254740994.0,
        123.456,-123.456,12345.6789,6.022e23,6.626e-34,
    };
    for(size_t k=0;k<sizeof reps/sizeof reps[0];k++) chk(reps[k]);
    /* specials — format-only (finite=0 => decline assertion skipped) */
    chk(frombits(0x7FF0000000000000ULL)); chk(frombits(0xFFF0000000000000ULL));
    chk(frombits(0x7FF8000000000000ULL)); chk(frombits(0xFFF8000000000000ULL));
    /* finite boundaries — subnormal path (float_parse_exact.hexa:465-478) + tie path (:451/:470) */
    chk(frombits(0x0000000000000001ULL)); chk(frombits(0x000FFFFFFFFFFFFFULL));
    chk(frombits(0x0010000000000000ULL)); chk(frombits(0x7FEFFFFFFFFFFFFFULL));
    /* deterministic full-bit-space sweep (xorshift64, 2,000,000) — exercises round-half-even ties */
    uint64_t st=0x243F6A8885A308D3ULL;
    for(long n=0;n<2000000;n++){ st^=st<<13; st^=st>>7; st^=st<<17; chk(frombits(st)); }
    /* dense small ints + simple decimals (low-p shortest selection) */
    for(int n=-100000;n<=100000;n++) chk((double)n);
    for(int n=1;n<5000;n++){ chk(n/7.0); chk(n/3.0); chk(n*1.0/1000.0); }

    long bad = fails+declines+parse_diff;
    printf("[float_dtoa_shortest_exact] %s — total=%ld string_fails=%ld declines=%ld value_diff=%ld "
           "(EXACT-parser round-trip vs C snprintf%%.*g+strtod byte-id)\n",
           bad?"FAIL":"PASS", total, fails, declines, parse_diff);
    return bad?1:26;
}

WHY THIS CLOSES R1b (review §RISK, verdicts.md:21-27): the review's failure scenario is "an exact-parser bug on a %g-candidate string silently picks a different precision → different JSON/print bytes", and the only existing gate checks with rt_parse_float_native not rt_str_parse_float_exact. This gate (1) uses rt_str_parse_float_exact as the checker exactly as site A does (runtime_emit_full.hexa:14574); (2) ORACLE 2 directly asserts rt_str_parse_float_exact == strtod on every actual native %g candidate — the "two proofs run together" the review says no gate does; (3) ORACLE 1 asserts the "never declines on %g output" premise (float_parse_exact.hexa comment/:373/:395/:403) that byte-identity rests on; (4) ORACLE 3 asserts final-string byte-identity vs the canonical C default. Any tie-mis-round (:451-454 / :470-473) or sub-selection divergence fails at least one oracle.

ASSERTION (the pass line): exit 26 iff string_fails==0 AND declines==0 AND value_diff==0, on all 3 targets. This is the pre-flip gate. It joins the R1b step-2 recipe (rfc061-r1b-strtod-anomaly-plan.md:30) alongside the existing float_dtoa_shortest_gate.c + float_dtoa_core_gate.c + num_float_core_gate.c 0-fail, and gates: nm runtime.a|grep strtod → 0/3 (requires the design's site-A #else conversion + edits B/C, currently unimplemented per verdicts.md:23) + byteeq 3-target GREEN + install smoke.

POOL vs MINI: mini = git/gh/read only. The gate build+run (aprime_cc compile of num_float_core.hexa + float_parse_exact.hexa, clang link vs runtime.a, ./g) is POOL — x86_64-linux + arm64-linux on aiden/summer (arm64 via native/qemu), darwin-arm64 on ghost (darwin arm64 selfhost). Writing the .c and committing the branch is mini. Do NOT report PASS from a mini/local run.

SEPARATION: this design adds only the gate (a scripts/scratch tool, byteeq-neutral, no self/ import — safe to land now). The default flip HEXA_RT_NUM_PARSE_FLOAT_EXACT 0→1 AND the design's source edits (site-A #else conversion at runtime_emit_full.hexa:14589-14594, edits B/C at runtime_core_emit.hexa:8030/:8043) stay a SEPARATE held PR gated on this gate GREEN 3-target + byteeq + install smoke.

## risk
Correctness/soundness risks the gate itself must not trip on: (1) inf/nan are NON-finite and the exact parser declines on them by design (float_parse_exact.hexa:373/:395/:403) — the decline assertion MUST be gated on isfinite(d) (ORACLE 1 `finite` flag), else the 4 specials produce 4 false declines. Both format paths still emit "inf"/"nan" so ORACLE 3 byte-check is valid for them. (2) -0.0: bit-compare (not ==) is used throughout (bits()), so -0.0 vs 0.0 is distinguished exactly as site A does (fb==rb on raw bits). (3) The C reference must mirror site A's #else shape (loop 1..16 then explicit 17, runtime_emit_full.hexa:14590-14594), NOT the p<=17 form the older gate uses, so cref is a faithful byte target. (4) Link BOTH objects: rt_format_float_native (num_float_core_native.o) AND rt_str_parse_float_exact (float_parse_exact_native.o, U hexa_bits_to_float resolved from runtime.a) — a missing float_parse_exact object is an unresolved-symbol link error, not a silent pass. (5) The gate proves the EXACT path only for site A's SHORTEST loop; edits B/C (runtime_core_emit.hexa:8030/:8043) format via the SAME rt_format_float_native + rt_str_parse_float_exact composition, so this gate covers their parser contract too, but B is a REPR_NATIVE round-trip and C is REPR_SHORTEST — both share the identical per-sig format+exact-parse primitive this gate exercises, so 0-diff here transfers. Residual not covered by THIS gate: the design-vs-branch strtod-drop (nm strtod 0/3) requires the actual #else source edits — the gate cannot substitute for implementing them (verdicts.md:23 secondary).

## recommendation
proceed — land float_dtoa_shortest_exact_gate.c now (byteeq-neutral scratch tool, no self/ closure import; build/run on pool, write on mini). Then it becomes the mandatory pre-flip gate: the HEXA_RT_NUM_PARSE_FLOAT_EXACT default-ON flip + the site-A #else conversion + edits B/C are a SEPARATE held PR that must show this gate exit-26 (string_fails=declines=value_diff=0) on all 3 targets + byteeq 3-target GREEN + install smoke + nm strtod 0/3 before merge. Do NOT flip on this gate alone and do NOT flip from a mini/local run.
---

# L2 (axis-① native-serve = hexa_cc.c C-transpile delegate removal)

VERDICT: L2 is genuinely BLOCKED on L1: hexat/hexa_cc.c is still the DEFAULT delegate for `hexa build` and the fallback for `hexa run` on every non-Linux/failure path; removing it requires native own-emit to be default + all-3-target + clang-free, which is exactly L1, and L1 is gated on the live 19.75 GB self-emit memory wall. But a mini-safe, non-blocked L2 PREP exists now — the delegate call-site census (below), which is pure read-only and de-risks the eventual removal to a mechanical edit.

## exact_plan
FINDING (1) — WHERE build/run still routes to the C-transpile delegate vs native own-emit (all cites = origin/main:self/main.hexa unless noted):

hexat = the hexa→C transpiler binary; its C source is self/native/hexa_cc.c (UNTRACKED — `git ls-files` returns ∅; 28,482 lines, regenerated per-run by `hexa cc --regen`). So "no hexa_cc.c" = kill the regen pipeline + cmd_cc bootstrap + the default C-transpile branch, not delete a committed file.

Delegate routes still live:
• DEFAULT `hexa build` (cmd_build): line 3582 `let v2 = resolve_or_bootstrap_hexat()` → 3586 `.c` transpile → clang link. This IS the default backend. The native branch `if __backend == "native"` at 3263-3264 is OPT-IN ONLY (HEXA_BACKEND=native), and even it assembles/links the emitted `.s` with clang (NOT clang-free) — so build never uses own-emit by default and never clang-free.
• `hexa run` non-Linux hosts: 4547-4548 `_run_native_on = (Linux x86_64 || Linux arm64) && HEXA_RUN_CTRANSPILE!=1`. On darwin (all mac CI runners + mini) this is false → straight to the clang `hexa build` subprocess (≈4630+) → hexat/hexa_cc.c.
• `hexa run` Linux native emit/link FAILURE: delegate-fallback is intentional — any own-emit/own-link/ld failure leaves tmpbin absent → falls through to the clang build path. Two native tiers exist: own-link (4569, `--linker=hexa --emit=exec`, clang+binutils-free, x86_64-linux ONLY, opt-in HEXA_LINK_HEXA=1) and emit=obj+system-ld (4608+, x86_64 default-ON / arm64), both fall back to hexat on failure.
• `hexa cc` / `hexa cc --regen`: cmd_cc rebuilds hexat by compiling hexa_cc.c (1758/1763 host_cc) — regen pipeline (≈2187+) regenerates hexa_cc.c itself via hexat transpile of the SSOT modules.
• Bootstrap: resolve_or_bootstrap_hexat() (2629) bootstraps build/hexat from hexa_cc.c via cmd_cc() on a fresh clone. Also consumed at 2096, 2220, 6999, 7025 (cmd_parse + other transpile verbs).
• Shipping: install.sh:524 symlinks self/ next to hexad so `<inst>/self/native/hexa_cc.c` is discoverable — the shipped consumer `hexa build` depends on the delegate being present.

FINDING (2) — What must be true for L2 to flip:
(a) own-emit native path becomes the DEFAULT backend for `hexa build` (not HEXA_BACKEND=native opt-in); (b) end-to-end on all 3 targets — today run hardcodes x86_64-linux-gnu, arm64 is partial (own-link is x86-only; own ELF writer is Linux-only → darwin needs a Mach-O own writer, a separate round); (c) native `hexa build` becomes clang-free (today the native branch still clang-assembles the .s); (d) the delegate-FALLBACK is removable — i.e. native covers 100% of the release corpus so hexat is never needed — which requires the memory campaign (aprime_cc self-host is 19.75 GB RSS today; community pods cgroup-cap at 8 GB → OOM); (e) merge under byteeq 3-target GREEN + shipping smoke; (f) install.sh stops symlinking/relying on self/native/hexa_cc.c.

FINDING (3) — L1 dependency + non-blocked prep:
BLOCKED-on-L1: L1 own-emit is measured END-TO-END WORKING (aprime_cc self-emits the 52-file/68,260-line closure → valid 6.87 MB ELF .o, exit 0, no leak; perf walls 765s→~78s via #4798/#4802). The remaining L1 wall is MEMORY: peak 19.75 GB RSS, confirmed M2 map-backed-struct representation floor (~1 KB/node, all IR carriers simultaneously resident; codegen/LIR +7.17 GB, ast_to_hir/HIR +5.52 GB) — active frontier (#4809 plan, #4812 census r1 GRADED, round-2 interning lever pending). Until own-emit is default + all-3-target + viable-RAM, the C-transpile delegate cannot be deleted → L2 is strictly downstream of L1.
NON-BLOCKED PREP (mini-safe, read-only, do NOW): the delegate call-site census above IS the prep — freeze the exact removal set {cmd_build default branch 3467+/3582-3586, cmd_cc 1704+ & hexa_cc.c regen ≈2187-2323, resolve_or_bootstrap_hexat 2629 bootstrap, v2 consumers 2096/2220/6999/7025, install.sh:524 self/native/hexa_cc.c symlink} so that when L1 lands, L2 is a mechanical, well-scoped deletion + default-backend flip rather than an archaeology dig. No build/measure needed.

## risk
Release-integrity risk: hexa_cc.c/hexat is the DEFAULT user-facing `hexa build` path and the universal `hexa run` fallback (all darwin + all native-failure cases). Deleting it before native own-emit is default + all-3-target-GREEN + shipping-smoke would break the used release for a self-host gate — the CLAUDE.md top guardrail (release-integrity > self-host progress) forbids this. Guard: L2 removal must land only AFTER L1's native-default flip passes byteeq 3-target + install.sh consumer smoke, and the delegate-fallback must be the LAST thing removed (keep it until native proves 100% corpus coverage incl. the @lazy niche + darwin Mach-O own-writer). Second risk: hexa_cc.c is untracked/generated, so a naive `rm` is meaningless — L2 must remove the REGEN pipeline + cmd_cc, else the file just regenerates. Prep census itself is zero-risk (read-only).

## recommendation
blocked-on-L1 for the flip; proceed-now on the read-only prep. Do NOT attempt L2 removal this cycle — native own-emit is opt-in on build, x86_64-linux-only clang-free on run, and gated on the 19.75 GB memory campaign. Instead: (1) land the delegate call-site census as the L2 removal-set SSOT (state/hexa-own/L2_own_static_integration.md is currently 0 bytes — populate it with the sites above); (2) track the L1 gates it waits on (memory round-2 interning under host RAM, native-default build flip, darwin Mach-O own-writer, arm64 own-link) as explicit L2 preconditions. All mini-safe, no build/commit required for the analysis itself.