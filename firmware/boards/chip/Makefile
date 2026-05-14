# hexa-chip — top-level Makefile aggregating verify / tests / selftest.
#
# Mirrors hexa-sscb's runnable surface convention (see ~/core/hexa-sscb
# for reference): a doc-first repo with thin Make-aggregated entry points
# that delegate to .hexa scripts under verify/ and tests/.
#
# Usage:
#   make verify          # run every verify/*.hexa check
#   make verify-quiet    # one-line per check
#   make verify-json     # machine-readable JSON
#   make verbs           # run all 29 per-verb sandboxes
#   make tests           # run every tests/test_*.hexa
#   make selftest        # CLI selftest (29-verb directory sweep)
#   make all             # verify + verbs + tests + selftest
#   make ci              # alias for `all`, exit non-zero on first FAIL
#   make list            # list registered checks + tests
#   make clean           # nothing to clean (spec-first); no-op
#
# Prerequisite:
#   /Users/ghost/.hx/bin/hexa interpreter (= hexa run)
#   No external Python / Node / Make recipes — pure stdlib hexa.

HEXA      := hexa
ROOT      := $(shell pwd)
CLI       := verify/cli.hexa
VERBS     := verify/verb_runner.hexa
TESTS     := tests/run_tests.hexa
SELFTEST  := cli/hexa-chip.hexa
CHIPVCLI  := chip-verify/cli.hexa

.PHONY: all ci verify verify-quiet verify-json verbs verbs-json tests tests-json \
        chip-verify chip-verify-list chip-verify-inventory chip-verify-json \
        selftest list clean help install mk2-check

help:
	@echo "hexa-chip — top-level targets"
	@echo "  make verify         — run every verify/*.hexa check (incl. chip-verify bridge)"
	@echo "  make verify-quiet   — one-line summary per check"
	@echo "  make verify-json    — JSON output"
	@echo "  make verbs          — run all 29 per-verb sandboxes"
	@echo "  make tests          — run every tests/test_*.hexa"
	@echo "  make chip-verify    — Wave J — run chip-verify aggregate (22 empirical scripts)"
	@echo "  make chip-verify-list      — list the 22 registered chip-verify scripts"
	@echo "  make chip-verify-inventory — assert chip-verify inventory invariant"
	@echo "  make chip-verify-json      — chip-verify aggregate as JSON"
	@echo "  make selftest       — CLI dispatcher selftest (29-verb sweep)"
	@echo "  make all            — verify + verbs + tests + chip-verify + selftest"
	@echo "  make ci             — alias for all (CI entry point) + mk2-check"
	@echo "  make list           — list registered verify checks + tests"
	@echo "  make install        — hx install into /Users/ghost/.hx/bin/hexa-chip"
	@echo "  make mk2-check      — run 5 Mk.II/meta-domain verify scripts (Wave H CI)"

verify:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(CLI)

verify-quiet:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(CLI) --quiet

verify-json:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(CLI) --json

verbs:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(VERBS)

verbs-json:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(VERBS) --json

tests:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(TESTS)

tests-json:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(TESTS) --json

selftest:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(SELFTEST) selftest

chip-verify:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(CHIPVCLI) report

chip-verify-list:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(CHIPVCLI) list

chip-verify-inventory:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(CHIPVCLI) inventory

chip-verify-json:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(CHIPVCLI) report --json

all: verify verbs tests chip-verify selftest

ci: all mk2-check

# Wave H — Mk.II auto-trigger CI aggregator. Runs the five non-hexa verify
# scripts (Python stdlib only) used by .github/workflows/mk2-verify.yml.
# Exit code = union of the five script return codes (first non-zero wins;
# Make's default -e behaviour). Intentionally separate from `make verify`
# (which runs hexa-side checks) so the GitHub Actions runner doesn't need
# the hexa interpreter installed.
mk2-check:
	@echo "── mk2-check: terafab/verify_terafab.py"
	@python3 terafab/verify_terafab.py
	@echo "── mk2-check: terafab/cross_doc_audit.py"
	@python3 terafab/cross_doc_audit.py
	@echo "── mk2-check: exynos/verify_exynos.py"
	@python3 exynos/verify_exynos.py
	@echo "── mk2-check: verify_catalog.py"
	@python3 verify_catalog.py
	@echo "── mk2-check: tests/test_terafab_meta.py"
	@python3 -m unittest tests.test_terafab_meta
	@echo "── mk2-check: PASS"

list:
	@HEXA_CHIP_ROOT=$(ROOT) $(HEXA) run $(CLI) --list
	@echo ""
	@echo "tests/ discovered:"
	@ls -1 tests/test_*.hexa 2>/dev/null | sed 's/^/  /'

install:
	@hx install $(ROOT) --entry cli/hexa-chip.hexa --as hexa-chip

clean:
	@echo "hexa-chip is spec-first — no build artifacts to clean."
