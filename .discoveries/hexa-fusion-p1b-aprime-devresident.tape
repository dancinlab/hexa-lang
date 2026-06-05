@discovery := "P1B-a' device-glue non-determinism re-classifies the byte-eq wall" :: hexa-fusion

id    = "F-FUSION-P1B-APRIME-DEVRESIDENT"
seed  = "P1B (#2777) attributed own-mega vs own-eager max|Δ|=8.882e-16 to host↔device erf
         (eager glue ran on HOST). P1B-a' makes the eager glue DEVICE-RESIDENT (CUDA erf both
         sides, separate launches, env HEXA_EAGER_DEVRESIDENT) to test option (b): both arms
         share CUDA erf ⇒ max|Δ|=0 capstone."
verdict-tier-target = "🟢 byte-eq max|Δ|=0  OR  🔴 closed-negative residual"
verdict = "🔴 CLOSED-NEGATIVE (byte-eq) + 🟢 (util +2.49pp). FALSIFIED, but NOT for the
           predicted erf reason."

finding = "The device-resident GLUE path is RUN-TO-RUN NON-DETERMINISTIC (~7.1e-6 first_ce
           jitter, single forward, fixed weight seeds). Determinism ladder (x3 each, verbatim):
           host forward Δ=0 · +device own-GEMM Δ=0 · +device glue ≈7e-6. The erf gap is clean
           and deterministic (host vs device erf |Δ|=9.3e-13 ≈1 ULP) and is MASKED by the glue
           non-determinism. Re-classifies the byte-eq blocker: thought = irreducible deterministic
           erf ULP; actual = a FIXABLE device-glue race (groupnorm/gelu/moe/residual/embedding
           share _forge_stream() — missing sync / atomic-order reduction / uninit output-padding
           read). max|Δ|=0 is impossible until the glue race is closed."

next-cycle-claim = "F-FUSION-DEVGLUE-DETERMINISM: instrument each device glue kernel (groupnorm,
                    moe-router, residual, gelu, embedding) for run-to-run reproducibility in
                    isolation to pin WHICH kernel carries the ~7e-6 race; fix (explicit sync /
                    deterministic reduction / zero output padding); re-test byte-eq once the
                    device forward is reproducible. THEN the erf ULP (9.3e-13) becomes the
                    observable residual and the P1B-a' capstone is re-runnable."
