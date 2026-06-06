# discovery: hexa-fusion-sm90-wgmma-parity
# id: F-FUSION-SM90-WGMMA-PARITY
# seed: native sm_90(a) H100 own-GEMM forge parity vs cuBLAS (~340 TFLOP/s).
#       NOT an impossibility verdict — the silicon demonstrably reaches peak via
#       wgmma+TMA (cuBLAS proves it); the residual is a known CUTLASS layout builder.
# verdict-tier-target: 🟢 numerical (bit-correct rel-RMS<=3e-3 → own GFLOP/s + ratio vs cuBLAS)
#
# === STATE (2026-06-06, after the GMMA::Layout pass — SWIZZLE SOLVED, BIT-CORRECT) ===
#   ladder: 30.4x (parent WMMA2 software-TF32)
#         → 29.4x (mma.sync cuBLAS-mainloop, bit-exact #2805)  [mma.sync CEILING — ruled out]
#         → wgmma.mma_async + TMA FEASIBLE on sm_90a (#2808): builds + runs, f16 probe correct.
#         → wgmma bit-correctness BLOCKED (#2812): rel-RMS 1.309, >2300-config sweep nothing<1.36.
#         → **SOLVED (2026-06-06, F-FUSION-SM90-WGMMA-GMMA-LAYOUT):** the real CUTLASS GMMA
#           INTER core-matrix layout makes wgmma TF32 BIT-EXACT.
#           ROOT CAUSE: a wgmma core matrix is 8 ROWS x 16 BYTES = for TF32 (4B) 8x4 ELEMENTS,
#           NOT the 8x8 K-strip the prior sweep assumed. That 8-vs-4 IS defects (1)+(2).
#           W2 single-tile rel-RMS = 0.000e+00 · W3 full 2048^3 rel-RMS = 0.000e+00 (after the
#           fence.proxy.async.shared::cta ordering fix — wgmma reads shared via async proxy).
#
# === CLOSED-NEGATIVE (ruled out, do not re-attempt) ===
#   - mma.sync reaching parity (29x ceiling, deterministic)
#   - plain row/col-major + descriptor LBO/SBO offset + epilogue-permutation swizzle (>2300 sweep)
#   - the 8x8 K-core assumption (the actual TF32 core is 8x4 — this WAS the layout bug)
#
# === MILESTONES (W-ladder, this pass) ===
#   W1  GMMA::Layout B-core-matrix builder       DONE — built, 8x4 TF32 INTER core layout.
#   W2  single-tile identity verify (GATE)       DONE — rel-RMS 0.000e+00 (SWIZZLE SOLVED ★).
#   W3  full wgmma GEMM bit-correct (GATE)        DONE — rel-RMS 0.000e+00 @2048^3 (proxy-fence fix).
#   W4  sm_90 parity measure                     DONE (honest) — own 20.2 TFLOP/s 2048^3,
#                                                  cuBLAS-TF32 357.5, ratio 17.67x, PARITY=NO.
#   W5  pipeline tune                            NARROWED — wide-N TN=128 → 38.0 TFLOP/s (9.35x),
#                                                  bit-exact. TN=256 slower (reg/occupancy).
#
# === OPEN — the one named residual ===
#   PARITY (strict <=1.3x): needs the full warp-specialized TMA multi-stage CUTLASS mainloop
#     (cp.async.bulk.tensor producer + wgmma consumer, deep software pipeline). Multi-session
#     build. It is a LATENCY-HIDING residual — NOT the layout (W2 solved) and NOT correctness
#     (W3 bit-exact 2048^3). The own-GEMM is now provably CORRECT on sm_90a; the gap is pure perf.
#
# === ARTIFACTS ===
#   kit (new): self/native/wgmma/wgmma_tf32_gmma.cu (W1/W2), wgmma_tf32_gemm2048.cu (W3/W4),
#              wgmma_tf32_gemm_w5.cu (W5 TN=128), wgmma_tf32_gemm_w5b.cu (W5 TN=256), gmma_run.sh
#   kit (prior): self/native/wgmma/{wgmma_tf32_decode,_bdecode,_full,_swz}.cu + sweep_fast.sh
#   verdict: .verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-GMMA-LAYOUT.txt
#   PRs: #2805 · #2808 (MERGED) · #2812 · #2815 (consolidation) · <this PR> (GMMA layout)
#   handoffs: 2e4438a7 reply chain
#
# next-cycle claim: W5+ warp-specialized TMA multi-stage mainloop toward strict parity.
#   The layout + correctness are SOLVED; the remaining work is a pure pipeline-engineering
#   perf climb (9.35x → <=1.3x), gated on a fresh multi-session GPU budget.

# ============================================================================
# === UPDATE 2026-06-06 — W6 async-pipe (50.7) + W7 dual-consumer-WG CLOSED-NEG
# ============================================================================
# W6 (#2833): cp.async async-pipe ring = 50.7 TFLOP/s bit-exact (rel_rms 0) = 8.39x off
#   cuBLAS-TF32 (+33% over 38.0; ~11.5% of gap closed). NST 2..5 saturates → ring depth
#   not the wall. single-consumer-WG warp-spec = 35.0 (starves TC at TM=64).
#
# W7 dual-consumer-WG warp-spec (MODE 3 gemm_ws2, TM=128: 1 cp.async producer WG + 2
#   consumer WGs each wgmma over its 64-row band x SHARED B tile). H100 sm_90a, vast
#   39651872 DESTROYED leak 0, nvcc 12.5.82. verdict F-FUSION-SM90-WGMMA-W7.txt.
#   RESULT: BIT-EXACT (rel_rms 0, S=2048/4096, NST=2..5) but SLOWER = 32.0 (13.2x).
#   W7 hypothesis FALSIFIED. ROOT CAUSE (on-pod occupancy calc): 128-thread cp.async
#   producer WG @ TM=128 is REGISTER-bound to 1 blk/SM (90 regs * 384 = 34560/CTA;
#   2 CTAs=69120 > 65536 regs/SM) -> 256 compute-thr/SM vs apipe 4*128=512. NOT smem
#   bound (24KB << 233KB/SM). More consumer WGs cannot win w/ a full-WG cp.async producer.
#
# === NAMED RESIDUAL (W8, next-cycle) ===
#   TMA-driven production: cp.async.bulk.tensor + 1 elected producer thread (freeing 127)
#   so warp-spec keeps FULL occupancy — how cuBLAS reaches sm_90a peak. Bring-over the W6
#   TMA kit self/native/wgmma/wgmma_tma_gemm.cu. Frontier kernel = W6 async-pipe (50.7, 8.39x).
#   STOP = honest occupancy/production-engine wall, NOT impossibility. cuBLAS=roofline.

# ============================================================================
# === UPDATE 2026-06-06 — W8 TMA-PRODUCER dual-consumer-WG = BIG-PROGRESS LIFT
# ============================================================================
# W8 (MODE 4 gemm_ws_tma): the W7-diagnosed fix LANDED. Replace the 128-thread cp.async
#   producer WG with a HARDWARE TMA producer driven by ONE elected thread (thread 0 issues
#   cp.async.bulk.tensor.2d for the A-band 128x8 + B 8x128 into an NST ring, mbarrier
#   expect_tx tracks tx-complete). The other 255 threads are BOTH consumer warpgroups; they
#   cooperatively permute the TMA-landed row-major tiles -> the W1/W2 gmma INTER 8x4 layout
#   (SAME mk/gmma_phys/WG descriptors — only the production engine changed), then each WG
#   wgmma's its 64-row band x the SHARED B tile. H100 sm_90a, vast 39701877 DESTROYED leak 0,
#   nvcc 12.6. verdict F-FUSION-SM90-WGMMA-W8.txt.
#   RESULT: BIT-EXACT (rel_rms 0, S=2048..8192, NST=2..4). own 50.7 -> 66.5 TFLOP/s @4096 (+31%);
#     69.6 @8192. ratio 8.39x -> 6.44x. ~26% of the parity gap closed. PARITY=NO.
#   OCCUPANCY (the W8 success proxy, on-pod): 1 CTA/SM (W7) -> 2 CTA/SM (W8) = 512 vs 384
#     compute-thr/SM. ws_tma 120 regs * 256 thr = 30720/CTA -> 2 CTAs = 61440 < 65536 regs/SM.
#     The TMA producer freed the WG AND shrank the CTA 384->256 thr -> doubled resident CTAs.
#   APPLES (same pod S=4096): MODE1 apipe 50.8 (8.54x, 4 CTA/SM) | MODE3 ws2 32.0 (13.67x, 1
#     CTA/SM) | MODE4 ws_tma 66.4 (6.45x, 2 CTA/SM). The dual-consumer-WG geometry W7 wanted
#     FINALLY pays off once the producer stops eating a full WG + register-evicting the 2nd CTA.
#
# === NAMED RESIDUAL (W9, next-cycle) — the remaining 6.44x is COMPUTE/MAINLOOP-bound ===
#   (1) SWIZZLED TMA (CU_TENSOR_MAP_SWIZZLE_128B): tile lands wgmma-readable -> ELIMINATE the
#       per-K-step cooperative Araw/Braw->gmma permute (+2 __syncthreads) cuBLAS never pays.
#       HIGHEST-value lever on the residual.
#   (2) deeper-TK accumulator double-buffer to overlap wgmma latency (currently wait_group 0 / step).
#   (3) wider N-tile m64n256k8 to amortize B-load + raise arithmetic intensity.
#   Frontier kernel = W8 gemm_ws_tma (66.5, 6.44x, 2 CTA/SM). cuBLAS=roofline, no superiority claim.

# ============================================================================
# === UPDATE 2026-06-06 — W9 SWIZZLED-TMA = CLOSED-NEG (naive) + mechanism PROVEN
# ============================================================================
# W9 (MODE 5 gemm_ws_tma_sw): attack the W8-named residual — the per-K-step cooperative
#   Araw/Braw->gmma permute (+__syncthreads) cuBLAS never pays. Use CU_TENSOR_MAP_SWIZZLE_128B
#   so the bulk copy LANDS the tile wgmma-readable; wgmma matrix descriptor swizzle-mode=1.
#   H100 sm_90a, vast 39704602 DESTROYED leak 0, nvcc 12.6. verdict F-FUSION-SM90-WGMMA-W9.txt.
#
#   ENCODE CONSTRAINT (closed sub-finding): cuTensorMapEncodeTiled+swizzle REQUIRES the
#     CONTIGUOUS box dim == swizzle atom width (32 f32 = 128B). A (contig=K) OK; B (contig=N=128
#     =512B) FAILS r=1. FIX (landed): B = 4 side-by-side 32-N swizzled atoms (box {32,32}).
#
#   MECHANISM CONFIRMED (SASS, the W9 goal): gemm_ws_tma (MODE4) STS=28 BAR.SYNC=3 vs
#     gemm_ws_tma_sw (MODE5) STS=0 BAR.SYNC=2 -> the 28-store cooperative permute is GONE +
#     one __syncthreads dropped. Occupancy PRESERVED at 2 CTA/SM (512 thr/SM).
#
#   BIT-EXACT GATE FAILED (the wall, g5): rel_rms FLOOR = 1.392 across ~100 descriptor configs
#     (lbo{16..1024} x sbo{16..2048} x kstep{0,1}); lbo INERT; kstep=1 faults. NO config <=3e-3.
#     => NO perf number (g5). own GFLOP/s UNCHANGED; W8 66.9/6.41x frontier KEPT (no regression).
#
#   ROOT CAUSE — MEASURED SWIZZLE LAW (recoverable): a direct shared dump of a 128B-landed
#     8x32-f32 atom shows the swizzle is NOT g_phys=g XOR r but g XOR ((r+1)&7):
#       row0 mask1 row1 mask2 row2 mask3 row3 mask4 row4 mask5 row5 mask6 row6 mask7 row7 mask0.
#     TWO-LAYER mismatch: (1) TMA swizzle = g XOR ((r+1)&7) not g XOR r; (2) it must STILL compose
#     with the 8x4 INTER core packing (gmma_phys) the wgmma descriptor expects. One linear
#     lbo/sbo constant can't express both -> naive path DETERMINISTICALLY RULED OUT.
#
# === NAMED RESIDUAL (W10, next-cycle) — compose the MEASURED swizzle with gmma_phys ===
#   The swizzle constant is now in hand (g XOR ((r+1)&7)). W10: (a) compose it with gmma_phys
#   to derive the EXACT shared layout the wgmma swizzle-mode-1 descriptor needs, (b) make TMA
#   land that (or emit into shared at it) — the CUTLASS GMMA::Layout derivation with the
#   on-pod-measured constant. Frontier kernel UNTIL W10 = W8 gemm_ws_tma (66.9, 6.41x, 2 CTA/SM,
#   bit-exact). cuBLAS=roofline, no superiority claim.

# ============================================================================
# === UPDATE 2026-06-06 — W10 COMPOSED-DECODE = BIG-PROGRESS LIFT (beats W8)
# ============================================================================
# W10 (gemm_w10, MODE 4 of wgmma_tf32_w10.cu): compose the SWIZZLE_128B law with gmma_phys
#   so the consumer reads the swizzled-TMA tile in wgmma order PERMUTE-FREE. H100 sm_90a,
#   vast 39707146 DESTROYED leak 0, nvcc 12.6 driver 560.35.05. verdict F-...-W10.txt.
#
#   GROUND-TRUTH RE-MEASURE (MODE2 A-dump + MODE3 B-dump, unique-id, full 128x32 & 32x32 box):
#     CORRECTED the W9 handoff — the FP32 SWIZZLE_128B law is the TEXTBOOK g XOR (r&7), NOT
#     g XOR ((r+1)&7) (W9's (r+1)&7 was a partial-8-row-probe artifact). Row-preserving,
#     atom-major. A: granule pg holds global (pg XOR pr); B (contig=N): same on the N-granule.
#
#   COMPOSED DECODE (proven bit-exact): read gmma_phys(m,k) FROM swizzled slot
#     A: atom*256 + (m&7)*32 + ((k>>2)^(m&7))*4 + (k&3)
#     B: atomN*1024 + k*32 + ((nn>>2)^(k&7))*4 + (nn&3)
#   A pure index composition (no transpose, no Braw row-major scratch). SWIZZLE_128B TMA lands
#   A/B directly; one indexed shared->shared copy emits the gmma INTER band; wgmma reads it.
#
#   SINGLE-TILE GATES (the W10 GATE, before any big run, g5): MODE0 pure decode rel_rms 0.000e+00
#     exact 4096/4096; MODE1 composed-decode->wgmma rel_rms 0.000e+00 exact 4096/4096. PASS.
#
#   FULL GEMM (gemm_w10): KEY = gmma scratch is a SINGLE shared buffer (NOT NST-ring-staged) ->
#     smem 131KB->98KB/CTA -> 2 CTA/SM restored (was 1). NST=2, all rel_rms 0.000e+00:
#       S=2048 own 64.4 cuBLAS 344.9 ratio 5.35x
#       S=4096 own 70.7 cuBLAS 430.8 ratio 6.09x  ★ (stable 70.7-70.9 x3)
#       S=8192 own 75.5 cuBLAS 445.1 ratio 5.90x
#     APPLES same-pod S=4096: W8 66.9 (6.43x) -> W10 70.7 (6.09x) = +5.7%, ~6.3% of gap closed.
#
#   IN-PLACE swizzle-descriptor (gemm_w10_inplace, MODE5) = CLOSED-NEGATIVE: the wgmma HW
#     swizzle-mode-1 descriptor does NOT decode the atom-major SWIZZLE_128B TMA tile (floor
#     1.392 across ~40 lbo/sbo/boff; lbo inert) = a 3rd interaction (HW de-swizzle core layout
#     != TMA atom stacking). Software composed decode required; in-place path RULED OUT.
#
# === NAMED RESIDUAL (W11, next-cycle) ===
#   The W10 decode is still a software shared->shared index copy per K-slab (the ~5.7% lift).
#   Remaining 6.09x to parity = (a) the decode copy (HW in-place RULED OUT; needs a wgmma operand
#   layout matching the TMA atom stacking directly), + (b) deeper warp-spec multi-stage pipeline
#   (NST>2 currently regresses occupancy). Frontier kernel = W10 gemm_w10 (70.7, 6.09x, 2 CTA/SM,
#   bit-exact). cuBLAS=roofline, no superiority claim.

# ============================================================================
# === UPDATE 2026-06-06 — W11 LEVER-1 (128x256 tile) = CLOSED-NEGATIVE (occupancy-coupled)
# ============================================================================
# W11 (gemm_w11_t256 MODE6 + gemm_w11_pp MODE7 of wgmma_tf32_w11.cu): apply the research-named
#   top levers on the W10 composed-decode frontier. H100 sm_90a, vast 39717398 DESTROYED leak 0,
#   nvcc 12.6 driver 580.159.03. verdict F-...-W11.txt. ALL configs rel_rms 0.000e+00 (bit-exact).
#
#   SINGLE-TILE GATES (g5, before any perf): W10 MODE0 + MODE1 rel_rms 0 PASS (composed law intact).
#   SAME-BINARY BASELINE (apples, this pod): W10 gemm_w10 MODE4 @4096 NST2 = 70.6 TFLOP/s, 6.12x,
#     2 CTA/SM (matches the W10 #2847 frontier 70.7/6.09x re-measured).
#
#   LEVER 1 — 128x256 output tile (cudaforfun ladder #1, named +34%): REGRESSED.
#     smem 98KB -> 147KB/CTA -> OCCUPANCY 2 -> 1 CTA/SM. own (all < the 70.6 baseline):
#       S=4096 NST2 65.5 (6.59x)  NST3 66.4 (6.44x, best)  S=2048 63.4  S=8192 68.8
#     The +34% FP16 reuse gain does NOT transfer: on this TF32 kernel the halved residency
#     (256 vs 512 compute-thr/SM) dominates the accumulator-reuse win. -6.0% vs frontier.
#   LEVER 3 — 128x256 + ping-pong epilogue overlap (named +27%): ALSO below frontier.
#     S=4096 NST2 64.5 (6.65x) NST3 66.3 (6.44x). Cannot return the smem the bigger tile spent;
#     occupancy-gated by lever 1, flat-to-below MODE6.
#
#   RULED-OUT AXIS (deterministic closed-negative): the "larger output tile" lever is NOT free in
#     isolation on TF32 — it is OCCUPANCY-COUPLED. Tile-alone (2->1 CTA/SM) regresses; the litscan's
#     own coupling (Q2 step5 = "tile 128x256 + 2 consumer warpgroups", never tile-alone; Q4 the
#     register/stage choice fights the one-wave residency) is CONFIRMED BY MEASUREMENT. Bit-exact
#     throughout (the composed decode is intact — the regression is pure occupancy, not numerics).
#
#   DECISION (W11 hard rules): a lever regressed -> KEEP the W10 70.7 frontier, NO regression shipped.
#     Frontier kernel UNCHANGED = W10 gemm_w10 (70.7, 6.09x, 2 CTA/SM, bit-exact). cuBLAS=roofline.
#
# === NAMED RESIDUAL (W12, next-cycle) ===
#   128x256 is correct + bit-exact but occupancy-bound. To make lever 1 pay off, BOTH are needed:
#   (a) lever 2 — warp-spec setmaxnreg (producer 40 / consumer 232) so consumer WGs free registers;
#       the single TMA-producer thread already exists, promote to a dedicated producer warpgroup.
#   (b) shrink the 128x256 smem under the 114KB/CTA ceiling for 2 CTA/SM — the decode scratch
#       (2 A-bands + 4 B-blocks) is the swing; the W10-named "eliminate the software decode copy"
#       (a wgmma operand layout matching the TMA atom stacking; HW in-place RULED OUT in W10, so a
#       layout-emit not a descriptor) removes the gmma scratch. Only with BOTH does 128x256 hold
#       2 CTA/SM and the +34% reuse become visible. Tile-alone is closed-negative (W11 verdict).

# === W12 — the COUPLED LEVER tested + CLOSED-NEGATIVE (#2851, 2026-06-06) ===
#   native sm_90a H100 (vast 39719243, ssh8, DESTROYED leak 0). nvcc 12.6 V12.6.77, driver 580.95.05.
#   Same-binary baseline: W10 MODE4 @4096 = 70.3 (6.10x, 2 CTA/SM, smem 98KB). Gates rel_rms 0.
#
#   (b) MODE10 — per-K8-sub decode (shrink the W10 full-slab decode scratch 48KB -> 12KB):
#     smem 147KB -> 108.0KB/CTA -> 2 CTA/SM RESTORED (the W11-pinned occupancy gate MET, 108<114).
#     BUT own COLLAPSES: S4096 NST2 26.1 (16.66x), NST3 26.0 (1 CTA/SM), S2048 18.8, S8192 26.7.
#     rel_rms 0 throughout (bit-exact). ptxas C7511 = wgmma serialized (insufficient regs). The
#     sub-tile decode forces a __syncthreads + fresh 6-buffer decode PER K8 sub-step (4x the
#     full-slab sync/decode) -> serializes decode<->MMA. Occupancy was NEVER the W10 wall;
#     decode/MMA OVERLAP is, and the scratch-shrink directly destroys it. -63% vs frontier.
#
#   (a) MODE9 — separate producer WG + setmaxnreg 40/232 + sub-decode: UNREALIZABLE.
#     ptxas C7507 IGNORES setmaxnreg (the 128x256 tile's d0..d3 = 128 accum regs/thr force min
#     regs, asymmetry cannot be granted). RUN DEADLOCKED (timeout -k5 90 -> exit 124 both NST).
#     The register-realloc the litscan needs to hide the bigger-tile cost is DENIED by that same
#     bigger tile's accumulator footprint. 90s timeout guard prevented any pod hang (storm-safe).
#
#   RULED-OUT AXIS (deterministic closed-negative, TWO grounds): the litscan tile<->warp-spec
#     coupling does NOT close on the W10 TF32 composed-decode kernel. (1) smem CAN meet the ceiling
#     (108KB, 2 CTA/SM) but only via a decode-serialization costing ~2.7x more than the occupancy
#     win; (2) the warp-spec register realloc that would hide it is ungrantable under the bigger
#     tile's accumulator regs. The 128x256 output tile is a DEAD AXIS for this kernel.
#
#   DECISION (W12 hard rules): both levers regressed/unrealizable -> KEEP W10 70.7 frontier,
#     NO regression shipped. Frontier kernel UNCHANGED = W10 gemm_w10 (70.7, 6.09x, 2 CTA/SM,
#     bit-exact). cuBLAS-TF32 = ROOFLINE, no superiority claim.
#   verdict .verdicts/hexa-fusion/F-FUSION-SM90-WGMMA-W12.txt. kernel self/native/wgmma/wgmma_tf32_w12.cu.
#
# === NAMED RESIDUAL (post-W12) ===
#   Axis-1 (forge TF32 wgmma parity via bigger tile) is CLOSED-NEGATIVE through W12. Remaining
#   parity levers are NOT tile/occupancy: (i) the W5-class perf-only warp-spec TMA pipeline (deep
#   async producer ring overlapping the decode itself, not just register split) so decode is hidden
#   WITHOUT shrinking the scratch; (ii) precision-axis (the campaign-closed lever: FP16/BF16 wgmma
#   where the litscan ladder was actually measured, vs this TF32 kernel). Both are separate axes;
#   the 128x256 output-tile axis is exhausted.

# ============================================================================
# === UPDATE 2026-06-06 — W13 DEEP ASYNC DECODE RING = CLOSED-NEGATIVE (axis exhausted)
# ============================================================================
# W13 (gemm_w13, MODE 6 of wgmma_tf32_w13.cu): attack residual (b) of the W10 handoff — the
#   deeper warp-spec multi-stage pipeline. W12 (#2851) root-caused the wall as decode<->MMA
#   OVERLAP (NOT occupancy): the 128x256 output-tile axis is DEAD; shrinking the W10 decode
#   scratch restores 2 CTA/SM but SERIALIZES decode<->MMA. W13 is the OPPOSITE: KEEP the W10
#   decode-copy (W12 proved removal kills it) and DEEPEN the gmma decode ring NSTG-deep so
#   decode(N+1) writes a DIFFERENT band while wgmma(N) reads band N — a producer-ahead software
#   pipeline that HIDES the decode latency behind the prior wgmma.
#   H100 sm_90a, vast 39725711 DESTROYED leak 0, nvcc 12.6 driver 560.35.03 (apples to W10).
#   verdict F-FUSION-SM90-WGMMA-W13.txt.
#
#   SINGLE-TILE GATES (reused W10 decode law): MODE0 rel_rms 0.000e+00 exact 4096/4096;
#     MODE1 composed-decode->wgmma rel_rms 0.000e+00 exact 4096/4096. PASS.
#   APPLES BASELINE (same binary, same pod): W10 gemm_w10 MODE4 NST=2 @4096 = 70.7 TFLOP/s,
#     2 CTA/SM, 6.10x, rel_rms 0 — the frontier re-confirmed exactly on this pod.
#
#   NSTG SWEEP (all NSTG>=2 BIT-EXACT rel_rms 0.000e+00; gate before every perf number):
#     NSTG  smem/CTA  CTA/SM  own@4096  ratio   vs W10 70.7
#      1    96.0KB     2      FAIL(1.198e-2)  --  (degenerate: producer-ahead decode RACES the
#                                                  consumer at depth 1 — proves the overlap is
#                                                  REAL; not a valid config)
#      2   128.0KB     1      51.9      8.36x   -26.6% REGRESSION
#      3   160.0KB     1      51.9      8.37x   -26.6% REGRESSION
#      4   192.0KB     1      51.6      8.29x   -27.0% REGRESSION
#     confirm @2048 own 48.3 (7.16x) | @8192 own 54.6 (8.36x) — all 1 CTA/SM; deeper = flat.
#
#   THE EXACT WALL (closed-negative, deterministic): the gmma decode band is 32KB. W10 fits
#     exactly ONE band at 96KB/CTA -> 2 CTA/SM (H100 228KB/SM: 2x96=192 fits, 2x128=256 does
#     NOT). The SECOND band the overlap REQUIRES (NSTG=2) costs 32KB -> 128KB/CTA -> occupancy
#     HALVES to 1 CTA/SM, and the ~26% occupancy loss SWAMPS the decode-hiding gain (51.9 vs
#     70.7). 2 CTA/SM and decode/MMA overlap are MUTUALLY EXCLUSIVE for this 128x128 FP32-scratch
#     TF32 kernel — the SAME wall W12 hit from the other side (W12 serializes to hold 2 CTA/SM;
#     W13 overlaps but loses 2 CTA/SM). No NSTG both holds 2 CTA/SM and overlaps.
#
# === AXIS EXHAUSTED ===
#   The TF32 async-pipeline-depth axis is CLOSED. W10 gemm_w10 (70.7, 6.09x, 2 CTA/SM, bit-exact)
#   is the TF32 SUMMIT and is KEPT (no regression shipped). The ONLY remaining axis to close the
#   6.09x gap is the PRECISION change (FP16/BF16 wgmma — doubles tensor-core throughput AND a
#   16-bit gmma band is 16KB, potentially fitting 2 bands at 2 CTA/SM), a SEPARATE dtype campaign
#   with its own non-bit-exact (FP16 accumulation) gate. RECOMMEND STOP on the TF32 perf axis.
#   cuBLAS-TF32 = roofline throughout; no superiority claim.

# ============================================================================
# === UPDATE 2026-06-06 — W14 PRECISION AXIS: FP16/BF16 wgmma own-GEMM (NEW dtype sub-ladder)
# ============================================================================
# W14 (wgmma_f16_w14.cu): the user-opted-into SEPARATE dtype campaign opened after W13 closed
#   the TF32 async-pipeline axis. Port the W10 composed-swizzle-decode own-GEMM to 16-bit
#   operands + f32 accumulate. H100 sm_90a, vast 39729157 DESTROYED leak 0, nvcc 12.6
#   driver 560.35.03 (EXACT apples to W10/W13). verdict F-...-W14-FP16.txt.
#
#   GATE CHANGE (g5, STATED): NOT bit-exact-vs-FP64 (a 16-bit operand + f32 accum is a
#     different numeric). Gate = precision-appropriate rel_rms <= 1e-2 vs SAME-DTYPE oracle
#     (f16/bf16 operands; cuBLAS-FP16/BF16 via cublasGemmEx CUDA_R_16F + COMPUTE_32F = the
#     same f32 accumulate). cuBLAS comparison SAME-DTYPE (cuBLAS-FP16, NOT cuBLAS-TF32),
#     roofline, NO superiority claim. TF32 summit (W10 70.7, 6.09x) STAYS the TF32 frontier.
#
#   f16 GMMA LAYOUT RE-DERIVED (differs from TF32 8x4): f16/bf16 wgmma is .k16 with an 8-row x
#     8-K-elem core (8*8*2B = 128B). gmma_phys16(s,k)=((strip*KCORES+kcore)*64)+(s&7)*8+(k&7),
#     KCORES=K_TILE/8. SWIZZLE_128B granule = 8 f16 (16B); ON-GPU MODE2/3 dump MEASURED the law
#     = TEXTBOOK g XOR (r&7), row-preserving, atom-major (512 f16/atom). Composed decode:
#       A: atom*512 + (m&7)*64 + ((k>>3)^(m&7))*8 + (k&7)
#       B: k*64 + ((n>>3)^(k&7))*8 + (n&7)
#
#   GATES (g5, before any big run): MODE0 f16 decode rel_rms 0.000e+00 exact 8192/8192;
#     MODE1 f16 wgmma rel_rms 0.000e+00 exact 4096/4096; MODE7 bf16 wgmma rel_rms 0.000e+00. PASS.
#
#   FULL GEMM (rel_rms 0.000e+00 at every S, both dtypes — far inside the 1e-2 same-dtype gate):
#     F16 gemm_f16_w14 NST=2 (96.0 KB/CTA -> 2 CTA/SM):
#       S=2048 own 66.5 cuBLAS-FP16 644.3 ratio 9.69x
#       S=4096 own 71.6 cuBLAS-FP16 827.2 ratio 11.55x ★ f16 frontier
#       S=8192 own 76.4 cuBLAS-FP16 857.9 ratio 11.22x
#     BF16 gemm_bf16_w14 NST=2: own 71.1 @4096 (11.48x), 76.1 @8192. cuBLAS-BF16 816.1 @4096.
#     PARITY-vs-FP16 = NO. own ~71-76 TFLOP/s ≈ TF32 W10 ABSOLUTE, but cuBLAS-FP16 roofline
#     DOUBLED (827 vs cuBLAS-TF32 431) -> same-dtype ratio WIDENED (11.5x vs TF32 6.09x).
#
#   W13 OVERLAP THESIS REFUTED (deterministic closed-negative): "16-bit band = 16 KB -> 2 bands
#     at 2 CTA/SM reopens the overlap" is FALSE for .k16. A natural f16 K-slab is 64-wide (one
#     128B atom), so the decode band holds 2x K-elements -> 32 KB = SAME KB as TF32. NO 16-KB
#     band. MODE6 ring bit-exact but every 2nd-band config -> 1 CTA/SM -> regress (50.9 @4096,
#     -29%). Identical to the W13 TF32 occupancy wall, NOT reopened.
#
# === NAMED RESIDUAL (W15-precision, next-cycle) ===
#   To exploit the 16-bit 2x TC the OWN kernel must escape the software decode: an f16 wgmma
#   HW-swizzle-descriptor in-place read (W10 MODE5 was a TF32 closed-neg; f16 re-derivation
#   unexplored), OR a 32-K half-atom slab so the band IS 16 KB (half the wgmma per decode).
#   Either is a fresh sub-axis. Frontier (this dtype): gemm_f16_w14 71.6 @4096, 2 CTA/SM,
#   bit-exact-vs-same-dtype. cuBLAS-FP16 = roofline. TF32 W10 70.7/6.09x untouched.

# ============================================================================
# === UPDATE 2026-06-06 — W15 DESCRIPTOR-DIRECT = CLOSED-NEGATIVE (research #2854 FALSIFIED)
# ============================================================================
# W15 (gemm_w15/probe_desc/probe_localize of wgmma_tf32_w15.cu): the research-#2854 breakthrough
#   — feed wgmma DIRECTLY from the SWIZZLE_128B-TMA tile via the corrected GMMA descriptor
#   (layout_type_=1, SBO=1024B, base_offset_=phase) and DELETE the W10 32KB software decode band,
#   expecting the W11 single-tile differential to reach rel-RMS 0 — is FALSIFIED BY MEASUREMENT.
#   H100 sm_90a, vast 39738178 DESTROYED leak 0, nvcc 12.6.77 driver 560.35.05 (W10-apples).
#   verdict F-...-W15.txt.
#
#   MODE2 oracle: landed SWIZZLE_128B = g_phys = g XOR (r&7) (TEXTBOOK), atom-major (atom a@a*256).
#   MODE6 localizer: composed_rel=0.000 (W10 composed-decode wgmma BIT-EXACT) but desc_rel=1.107
#     (layout_type_=1 in-place read UNCORRELATED) -> defect isolated to TMA-swizzle↔wgmma-swizzle.
#   MODE9 3200-cfg in-process sweep (swm·sbo·boff·lbo): FLOOR rel_rms 1.000 @ swm=1 sbo=1024 boff=2.
#     base_offset_ DID move it 1.107->1.000 (phase axis real) but NO config reaches 0.
#   MODE4 full GEMM desc-direct: rel_rms 1.392 (= the W9/W10 in-place floor) -> GATE FAIL, NO perf.
#
#   SMEM — the decode band IS removable (the one mechanical positive): W15 desc-direct NST=2 =
#     64.0 KB/CTA vs W10 NST=2 96.0 KB/CTA = a 32 KB DROP, 2 CTA/SM held. But UNUSABLE (read not
#     bit-exact, g5 forbids perf). W10 frontier re-measured same-pod: 71.0 TFLOP/s, 6.06x, rel 0.
#
#   FINDING (closed-negative, precise): the 3 named field fixes are necessary-DIRECTION-correct
#     (best basin IS swm=1/sbo=1024; base_offset_ moves the residual) but INSUFFICIENT. The
#     research's load-bearing claim "TMA-SWIZZLE_128B ≡ wgmma GMMA Swizzle<3,4,3> BY CONSTRUCTION"
#     does NOT hold for our hand-rolled cuTensorMapEncodeTiled box (atom-major stacking ≠ the
#     CuTe tile_to_shape(Layout_K_SW128_Atom) canonical byte pattern). The research conflated
#     "TMA lands a 128B-swizzled tile" with "TMA lands the EXACT canonical atom" — equivalence
#     holds only when the SMEM layout is BUILT from the atom and the TMA from THAT layout.
#
#   THE W11-W14 "EXHAUSTED" VERDICTS STAND: the exhaustion was NOT merely a descriptor bug —
#     the descriptor-direct alternative is itself blocked by the same swizzle-interaction wall,
#     now measured at 3200-config resolution. Frontier UNCHANGED = W10 gemm_w10 (70.7, 6.09x,
#     2 CTA/SM, bit-exact). cuBLAS=roofline, parity-seeking, NO superiority claim.
#
# === NAMED RESIDUAL (W16, next-cycle) ===
#   The 32KB decode-band removal is the prize and is REAL — but needs the canonical atom MATCHED:
#   (a) re-encode A/B in GLOBAL so SWIZZLE_128B TMA lands the canonical Layout_K_SW128_Atom byte
#       pattern (then the field-fix applies), OR (b) port make_gmma_desc's EXACT LBO/SBO FOR THE
#       atom-major layout (a different descriptor than the canonical one). Both = net-new kernel
#       structure, NOT a field sweep. Until one is bit-exact, W10 composed software decode is the
#       frontier. (Other reopened levers — 128x256 / deep-ring / warp-spec setmaxnreg / persistent
#       -collective / split-K / FP16-reopen — all remain occupancy-gated behind decode removal.)
# ============================================================================
