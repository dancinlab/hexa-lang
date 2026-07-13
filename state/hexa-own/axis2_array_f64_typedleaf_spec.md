# f64 typed-leaf spec v2 — float-param ABI crux resolved

**GO pick: C-shim (option 3).** The hexa seed takes `xbits:int` (GP reg in every ABI); a 3-line C shim does the `xmm0/d0 → GP` crossing via union bitcast. This is correct on all 3 targets today, needs zero codegen changes, removes the arm64 wall from this unit's critical path, and keeps the leaves position-independent. The whitelist route is deferred as a separate Route-C fp-param track.

---

## 1. x86_64 whitelist route — analyzed, then rejected for this unit

**Sufficiency is conditional, not automatic.** Adding `hexa_arr_f64_push`/`hexa_arr_f64_box` to the `fname ==` list is sufficient **iff** the whitelist is consulted at *both* sides:

- **Definition side (the one that matters here):** the seed's prologue must classify `x:float` → xmm0 and *normalize at entry*: `movq r, xmm0` (`66 REX.W 0F 7E /r`, e.g. `movq rax, xmm0` = `66 48 0F 7E C0`) into x's normal GP/stack home, plus materialize the FLOAT tag word to synthesize the HexaVal pair the body expects. The existing hxlcl Route-C def-side path presumably does this (hxlcl_fmod is whitelisted and native-emitted), but the pasted facts only confirm `_x86_arg_reg_sse` gating — which reads like **call-site** arg classification. If the def-side fp binding doesn't exist, the whitelist edit is NOT sufficient and you'd be building it.
- **hexa call sites:** any hexa→hexa call to a whitelisted fn must do the reverse `movq xmm0, r` (`66 REX.W 0F 6E /r`). Asymmetric coverage = silent garbage, the worst failure mode.

**The coupled contract, if this route is ever taken:** normalize-at-entry is mandatory. The prologue does the xmm→GP move; after the prologue, `x` is indistinguishable from a default-ABI param, so `__hx_f64_bits(x)` compiles to the *same* tag-swap lowering regardless of whitelist membership. Never make the leaf's lowering conditional on where the param landed — that's the fragility trap the earlier design fell into. On the attribute question: `@c_abi` on the fn decl is the right long-term shape (self-documenting, no name coupling), but it's a parser+HIR+codegen plumb; for 2 names the fname list is the established 표준. Moot for this unit since the shim wins.

## 2. arm64 verdict — WALL for the whitelist route, MOOT under the shim

Confirmed facts show only a SIMD-class variadic *return* to d0 and a va-fp whitelist — no general fp *param* classifier. Building one means an AAPCS64 NSRN counter (fp args v0..v7, §6.4), d-reg param binding, and entry normalization `fmov xN, dN` (`0x9E66_0000` base; reverse `fmov dN, xN` = `0x9E67_0000`). That is a genuine new mechanism-family, matching the recorded measured ABI wall (rfc061 cross-target: "잔여=arm64 fp-ABI"). **Verdict: WALL** — under the whitelist route this unit would be forced into a per-target flip (x86_64 ON, arm64 stays C behind the f64 guard). Under the shim route the wall never engages: **GO on all 3 targets**, and the arm64 fp-param classifier stays a deferred Route-C item.

## 3. C-shim — the GO approach

```c
HexaVal hexa_arr_f64_push(HexaVal v, double x) {
    union { double d; long long i; } u; u.d = x;
    return hexa_arr_f64_push_bits(v, u.i);
}
```
(same 3-line shape for `hexa_arr_f64_box` if it takes a raw `double`)

The hexa seed is `pub fn hexa_arr_f64_push_bits(v:HexaVal, xbits:int) -> HexaVal` — every param is GP-class in both the default hexa ABI and SysV/AAPCS64, exactly the regime where the i64 sibling already works. The HexaVal first param and HexaVal return are GP pairs in both ABIs (proven by `hexa_arr_i64_push`), so the *only* ABI-sensitive element — the double — is bitcast by the system C compiler, which is correct by construction on x86_64-linux, arm64-linux, and arm64-darwin.

**Weighing:** cost is one ~3-line C carrier fn remaining in the U-floor instead of zero — but the full dispatcher *body* still moves to hexa, so the net C reduction is nearly identical. In exchange: no codegen surface touched (zero byteeq risk from the compiler side), no per-target divergence, no coupled leaf/whitelist contract to police, no dependency on confirming whether the x86 def-side fp binding actually exists. The C substrate is a reducible RUNTIME-PORT target, not a purity gate — a shim that later evaporates when the Route-C fp-param classifier lands (both targets) is exactly the sanctioned shape. Whitelist-purity buys ~3 LOC of C at the price of an arm64 wall and a fragile contract. **Shim wins.**

## 4. Final leaf list

The bitcast at the C boundary moves into the shim's union, so the seed needs **no SSE-touching leaves at all**:

- **`__hx_f64_bits(x:float) -> int`** — keep, but redefined as a pure **tag-swap** (payload passthrough, INT tag): under the default ABI the payload is already in a GP reg, so this is a payload-copy + tag-word write on both native backends, and a union/memcpy in gen2 C. Needed for hexa-side callers that hold an `x:float` and enter the bits-based seed directly.
- **`__hx_bits_f64(b:int) -> float`** — keep, the reverse tag-swap; used on the get/box side to produce a FLOAT HexaVal from loaded bits. If `__hx_make_val(TAG_FLOAT, b)` is already exposed at hexa level it can be the implementation (or alias) — keep the named leaves for intent clarity.
- **Reuse `store64`/`load64`** for the buffer writes/reads — the seed stores `xbits` directly; no float op ever executes inside the seed.
- **Dropped from the earlier design:** any leaf whose lowering depends on param location (the xmm0-reading variant of `__hx_f64_bits`). Both leaves are target-independent and whitelist-independent.

## 5. Staging + gates

- **PR-1 — leaves, guard-OFF:** add `__hx_f64_bits`/`__hx_bits_f64` tag-swap lowerings to both native backends + gen2 C. No callers yet. Gate: **gen3≡gen4 byteeq fixpoint** + 3-target byteeq GREEN (compiler changed, emitted output for existing programs must be byte-identical).
- **PR-2 — seed + shim, default-OFF:** land `hexa_arr_f64_push_bits` (hexa) + the C shim behind the established `HEXA_RT_*`-style f64 guard; old C dispatcher body remains the default arm. Gates: byteeq 3-target GREEN, f64-array unit tests on **both** backends (release_build AND aprime_cc — aprime-only = false-green per standing feedback), guard-ON A/B on at least one Linux x86_64 pool host.
- **PR-3 — flip:** default-ON **all 3 targets simultaneously** — no per-target flip needed, since the shim is target-uniform. Gates: regular-CI byteeq 3-target GREEN + install.sh consumer smoke GREEN.
- **arm64 verdict on record:** WALL for the native fp-param route (AAPCS64 d-reg classifier = the mechanism-family to build), explicitly deferred to the Route-C cross-target track; this unit ships 3-target via the shim and does not block on it.
