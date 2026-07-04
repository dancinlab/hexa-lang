# vehicle(b) #4497 e2e — aiden 2026-07-03T15:59:02Z · 75a4c3724 feat(own-lint b): HEXA_OWN_LINT=1 hexa build advisory — aprime HX3012 on the shipping path

## build rc=0 · hexat=2770440 · aprime_cc=MISSING

## case1 positive (HEXA_OWN_LINT=1 · expect HX3012 + rc=0 + byte-id)
rc=0 hx3012_count=0
  [own-lint] advisory unavailable: aprime_cc not found — build it: bash tool/build_aprime.sh -o build/aprime_cc (build continues)
flagOFF rc=0 warn_own=0 byteid=DIFF

## case2 negative (plain file · expect 0 HX3012)
rc=0 hx3012_count=0

## case3 degrade (aprime_cc renamed · expect 1 advisory-unavailable + rc=0)
rc=0 unavailable=1
  [own-lint] advisory unavailable: aprime_cc not found — build it: bash tool/build_aprime.sh -o build/aprime_cc (build continues)

## case4 divergence-control (corpus file · build must succeed)
rc=0 (advisory lines=1)

DONE 2026-07-03T17:01:03Z

## phase2 — aprime_cc 빌드 후 양성 재검 + byteid 통제군 (2026-07-03T17:05:01Z)
aprime build rc=0 size=2881232
case1-retry rc=0 hx3012_count=2
  [own-lint] advisory diagnostics (aprime frontend · rc ignored · build continues):
HexaWarn [HX3012] self/test/test_own_lint_hx3012.hexa:18:13-14
    explain: hexa explain HX3012
byteid flagON-vs-OFF=DIFF · control OFF-vs-OFF=DIFF
PHASE2-DONE 2026-07-03T17:05:52Z
