"""
SSCB mk1 — pytest configuration.

Most acceptance items in module/engineering_pack/README.md §11 require physical
bench equipment (oscilloscope, IGBT shorting jig, climate chamber, ESD gun,
UL/KC certification labs). Those items are marked as `bench`; the auto-runnable
items (BOM cost roll-up, schedule, Python verifier, tag/signoff placeholders)
are marked `auto`.

Run all:
    pytest tests/ -v

Run only auto-checks:
    pytest tests/ -v -m auto

Skip bench items by default but show them in the report:
    pytest tests/ -v -m "auto or bench"
"""
from __future__ import annotations

import pytest


def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "auto: acceptance check that runs without bench equipment",
    )
    config.addinivalue_line(
        "markers",
        "bench: acceptance check that requires bench equipment "
        "(oscilloscope / climate chamber / certification lab)",
    )
