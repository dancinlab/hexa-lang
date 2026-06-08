# HEXA-FLAME-FAST — log

## 2026-06-08 — domain registered (after the ~3x campaign + an honest correction)

User pushed back (correctly) on an earlier overstatement that "compiling the whole flame step = months-long
engine rewrite → flame becomes PyTorch → loses no-LLVM/byte-exact identity." That was WRONG. hexa already
native-compiles (no LLVM); whole-step fusion is a kernel-authoring task; compiling preserves byte-exactness
with a fixed accumulation order (FF-GN-PARALLEL #2931 + FF-EPILOGUE #2928 proved it). The whole-step
megakernel (#2924) was blocked by a HARDWARE fact — FP64 too big to fit one cooperative wave at batch=1
(occupancy), NOT by an engine-rewrite cost or identity loss.

So the genuinely-untested lever = the SAME whole-step fusion at TF32/BF16 (fits occupancy) + batch>1 (fills
SMs). The three levers were only ever tested SEPARATELY (#2924 fusion-FP64, #2917 precision, #2913 batch);
combining them is new. Registered FAST-1 (occupancy probe) -> FAST-2 (fused TF32 megakernel) -> FAST-3 (+batch,
the decisive ~3x test) -> FAST-4 (opt-in wiring, identity guard) -> FAST-5 (vs-PyTorch if FAST-3 wins). GPU 0
at registration; NOT attempted. flame's FP64 byte-exact identity is the protected default; FAST is opt-in/additive.
Related: commons g85 (~3x cap = host-glue idle) + reference_megastep_research + F-FUSION-FF-DUTYCYCLE.
