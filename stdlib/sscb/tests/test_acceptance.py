"""
SSCB mk1 — ACCEPTANCE checklist as pytest scaffold.

Source-of-truth: module/engineering_pack/README.md §8.1 (T-1..T-10) +
§11 (A-1..A-10). Every test maps 1:1 to a checklist line; bench-only items
skip with a reason citing the required equipment.

Auto-runnable subset (5 items): A-2, A-3, A-8, A-9, A-10.
Bench-only subset (15 items): T-1..T-10, A-1, A-4..A-7.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
ENGPACK = ROOT / "module/engineering_pack/README.md"


# ---------------------------------------------------------------------------
# §8.1 — T-1..T-10 (qualification tests, all bench-only)
# ---------------------------------------------------------------------------

@pytest.mark.bench
@pytest.mark.parametrize("test_id, equipment", [
    ("T-1  Rds(on)",          "curve tracer / SMU @ Vgs=15 V, Id=100 mA"),
    ("T-2  short-circuit",    "5 kA pulsed source + IGBT shorting jig + Pearson 110A"),
    ("T-3  dv/dt overshoot",  "Tektronix MSO64 + N2791A diff probe (≥ 500 MHz)"),
    ("T-4  Tj rise",          "PT1000 + FLIR A615 thermal imager + 1 h soak fixture"),
    ("T-5  TDDB lifetime",    "Vgs=15 V / Tj=150 °C 1000 h thermal chamber"),
    ("T-6  surge",            "8 kV / 500 A IEC 61000-4-5 generator (Class 4)"),
    ("T-7  thermal cycle",    "-40↔+125 °C 1000-cycle chamber (JEDEC JESD22-A104)"),
    ("T-8  vibration",        "10-500 Hz 10 g 3-axis shaker (IEC 60068-2-6)"),
    ("T-9  EMC",              "EMC chamber (CISPR 32 Class B, radiated + conducted)"),
    ("T-10 certification",    "UL 489B + KC official lab submission"),
])
def test_qualification_t_series(test_id, equipment):
    pytest.skip(f"{test_id}: requires bench — {equipment}")


# ---------------------------------------------------------------------------
# §11 — A-1..A-10
# ---------------------------------------------------------------------------

@pytest.mark.bench
def test_a1_t_series_all_pass():
    pytest.skip(
        "A-1: requires T-1..T-10 PASS each with N≥30 samples — full lab cycle"
    )


@pytest.mark.auto
def test_a2_bom_under_ceiling():
    """A-2: §9 BOM procurement cost ≤ $35 @ 1 k volume."""
    rc = subprocess.run(
        [sys.executable, str(ROOT / "verify/bom_lattice.py")],
        capture_output=True, text=True,
    )
    assert rc.returncode == 0, (
        f"verify/bom_lattice.py FAIL — stdout:\n{rc.stdout}\nstderr:\n{rc.stderr}"
    )


@pytest.mark.auto
def test_a3_schedule_within_budget():
    """A-3: §10 12-month gantt complete within ±10 %.

    The schedule itself (which is what mk1 tests at design time) is the
    Python `SCHEDULE` table in §7. We assert that table totals ≤ 12 months
    via the §7 verifier — A-3's "delivered within ±10 %" half is bench/PM
    state and cannot be auto-checked here.
    """
    rc = subprocess.run(
        [sys.executable, str(ROOT / "verify/sscb_verify.py")],
        capture_output=True, text=True,
    )
    assert rc.returncode == 0, (
        f"verify/sscb_verify.py FAIL — stdout:\n{rc.stdout}\nstderr:\n{rc.stderr}"
    )
    assert "[PASS] §7.10 MPW schedule" in rc.stdout


@pytest.mark.bench
def test_a4_ul_certificate():
    pytest.skip("A-4: requires UL 489B issued certificate")


@pytest.mark.bench
def test_a5_kc_certificate():
    pytest.skip("A-5: requires KC breaker issued certificate")


@pytest.mark.bench
def test_a6_pilot_run_and_beta_distribution():
    pytest.skip(
        "A-6: requires 100 EA pilot run + distribution to 3 beta customers"
    )


@pytest.mark.bench
def test_a7_beta_field_test():
    pytest.skip(
        "A-7: requires 3-month no-fault field test from 3 beta customers"
    )


@pytest.mark.auto
def test_a8_python_verify_10_of_10():
    """A-8: §12 appendix Python verify 10/10 PASS (source-synchronized)."""
    rc = subprocess.run(
        [sys.executable, str(ROOT / "verify/sscb_verify.py")],
        capture_output=True, text=True,
    )
    assert rc.returncode == 0, rc.stdout
    m = re.search(r"(\d+)/(\d+) PASS", rc.stdout)
    assert m, "no '<n>/<m> PASS' line found in verify output"
    passed, total = int(m.group(1)), int(m.group(2))
    assert passed == total == 10, f"expected 10/10 PASS, got {passed}/{total}"


@pytest.mark.auto
def test_a9_v1_tag_or_freeze_marker():
    """A-9: drawing/BOM/firmware v1.0 tag + repo freeze.

    Acceptable: a git tag matching v1.0* OR sscb-mk1-* exists in the repo.
    Pre-release runs may legitimately have neither — skip with reason then.
    """
    try:
        out = subprocess.check_output(
            ["git", "-C", str(ROOT), "tag", "--list"],
            text=True, stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        pytest.skip("A-9: git not available or not a git repo")
        return
    tags = [t.strip() for t in out.splitlines() if t.strip()]
    if not any(re.match(r"^(v1\.|sscb-mk1-|hexa-sscb-mk1|mk1-v\d)", t) for t in tags):
        pytest.skip(
            f"A-9: no v1.0 / mk1-v* / sscb-mk1-* tag yet (tags: {tags or 'none'}) — "
            f"create with `git tag -a mk1-v1.0 -m 'mk1 freeze'` once design v1.0 lands"
        )


@pytest.mark.auto
def test_a10_handoff_signoff_placeholder():
    """A-10: tech-transfer document signoff.

    Acceptable: a `doc/handoff/signoff_*.md` (or .txt) file exists.
    Otherwise skip with the path the tech-transfer recipient should write to.
    """
    handoff_dir = ROOT / "doc/handoff"
    if not handoff_dir.exists():
        pytest.skip(
            f"A-10: no handoff signoff yet — recipient should land "
            f"`{handoff_dir.relative_to(ROOT)}/signoff_<name>_<date>.md`"
        )
        return
    signoffs = list(handoff_dir.glob("signoff_*.md")) + list(
        handoff_dir.glob("signoff_*.txt")
    )
    assert signoffs, (
        f"A-10: doc/handoff/ exists but contains no signoff_*.{{md,txt}} file"
    )


# ---------------------------------------------------------------------------
# Sanity: the source checklist still references all 20 items.
# ---------------------------------------------------------------------------

@pytest.mark.auto
def test_source_checklist_complete():
    """Guard against silent edits — the engineering_pack must still list
    every T- and A- item this scaffold mirrors. If a checklist line is
    deleted or renamed upstream, this test surfaces the drift before CI
    accidentally green-lights an unverified release."""
    text = ENGPACK.read_text(encoding="utf-8")
    for n in range(1, 11):
        assert f"T-{n} " in text or f"T-{n}\t" in text, (
            f"engineering_pack §8.1 missing T-{n}"
        )
        assert f"A-{n} " in text or f"A-{n}\t" in text, (
            f"engineering_pack §11 missing A-{n}"
        )
