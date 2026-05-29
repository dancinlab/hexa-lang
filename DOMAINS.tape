# DOMAINS.tape — domain roster + connection graph (cross-domain g67 + cross-project g68)
# Roster rows (`@domain NAME := "path"`) are AUTHORITATIVE for the /domain CLI;
# every other line (@V · @link · #) is ignored by the roster parser, so the
# connection graph below rides along without disturbing `domain list`.
# Connection carrier (g3 minimal): @link <from> --<verb>--> <to>   # <evidence>
# Carries the cross-project reuse-lattice / star-hub relationship graph (stdlib
# provides[] catalog dropped — hexa-lsp / `hexa atlas lookup` is the live
# stdlib discovery surface).
@V := "domains" :: index

# --- roster (nodes) ---
@domain RUNTIME := "./RUNTIME.md"
@domain CLOUD := "./CLOUD.md"

# --- cross-domain edges (intra-repo · g67) ---
@link TECS-L --reuses--> OEIS    # 7 provenance links (A000203/A000005/A000010/A008683 builtins + A001065/A001157/A001158 folds) · closes TECS-L F11 + OEIS O5 · PR #1138 · OEIS/docs/o5-tecs-crosslink.md · .verdicts/oeis-tecs-crosslink/crosslink.txt

# --- cross-project edges (cross-repo star · g68) ---
@link demiurge --uses--> stdlib/material/magnet      # current_loop_offaxis (RTSC + ANTIMATTER Ioffe-Pritchard trap) · PR #168
@link demiurge --uses--> stdlib/material/supercon     # McMillan Tc · Allen-Dynes · WHH · BCS gap ratio (RTSC V2/V3) · PR #745
@link demiurge --uses--> stdlib/rtsc/templates       # Wheeler on-axis B verifier + getdp solenoid templates · commit 3b33c26 · ANTIMATTER #168
@link demiurge --uses--> stdlib/antimatter           # 16 fns (penning_* · pair_threshold_* · ioffe_* · h1s2s · cyclotron_cool_* · recomb_3body_* · rel_*) + tool/verify_cli · PRs #157·158·159·162·164·166·168
@link demiurge --uses--> stdlib/cern                 # plasma-wakefield cold-linear fns · PR #1007 · demiurge CERN.md
@link demiurge --uses--> compiler/atlas              # embedded.gen.hexa verified-atom registry (bidirectional fold-back) · 22+ atoms from ANTIMATTER alone
@link anima    --uses--> compiler/atlas              # verified-atom registry (bidirectional peer) · embedded.gen.hexa SSOT + atlas CLI
@link phanes   --uses--> compiler/atlas              # verified-atom registry (bidirectional peer) · hexa kick auto-fold
@link phanes   --uses--> hexa-kick                   # OUROBOROS discovery engine (server-side hexa kick driver) · phanes DESIGN.log.md L93/L102/L196 · CHANGELOG t_downstream_discipline
@link VERIFY-KIT --uses--> stdlib/consciousness/iit4 # iit4_faithful_phi (small-N exact MIP-EI Φ · n<=8) + _from_mi + build_mi_matrix · folded from anima HEXAD/LIFE H_278 · .verdicts/verify-kit-iit-promote/v5_1.txt

# --- candidate cross-project edges (proposed/draft · stdlib families with no recorded consumer edge yet) ---
# @link <consumer> --uses--> stdlib/bio     # bio-kernel fns exist · no recorded from-hexa edge yet
# @link <consumer> --uses--> stdlib/chem    # stdlib/chem family · no recorded from-hexa edge yet
# @link <consumer> --uses--> stdlib/<other> # alloc · aura · aws · booksim · bot · brain · cert · ... — provides exist, downstream edges pending
@domain UNSHADOW := "domains/UNSHADOW.md"
@domain HEXA-BUILDFLOOR := "./HEXA-BUILDFLOOR.md"
@domain HEXA-CC-ZERO := "./HEXA-CC-ZERO.md"
