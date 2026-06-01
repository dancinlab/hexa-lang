@disc flame_mitosis := "MITOSIS 구조 성장 — expert cell division stays BOUNDED" :: discovery [closed]
  id           = "flame-mitosis"
  seed         = "model grows by CELL DIVISION (expert split E->E+1) instead of fixed arch; 분열 후 BOUND 유지"
  falsifier    = "after a division the model stays bounded/stable (FINITE · CONTINUOUS · DESCEND)"
  method       = "hexa run stdlib/flame/clm_mitosis.hexa — split expert 0 into a child at step 13 (E 4->5), descent smoke"
  division_op  = "weight-copy parent expert conv slot -> fresh packed slot + tiny ±1e-4 perturb; router child row = parent row, both child+parent logit bias -= ln2 so each child gate ~= p_parent/2 (Σexp conserved); Adam moments reset for the two divided cells"
  verdict_tier = "🟢 numerical"
  verdict      = ".verdicts/flame-mitosis/bound.txt"
  finding      = "BOUND holds: FINITE=1 · CONTINUOUS=1 (|jump|=1.48e-7, output preserved to ~7 dp) · DESCEND=1 (CE 0.0218->2.92e-4 on grown 5-expert arch). ln2 router-bias split makes division near-output-invariant."
