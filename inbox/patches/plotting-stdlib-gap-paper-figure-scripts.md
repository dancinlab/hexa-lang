# plotting — no charting / figure-rendering stdlib; downstream figure scripts cannot leave Python

> **Status:** open — filed 2026-05-22 by sidecar during the `.py` / `.sh` → `.hexa` migration.

**From:** sidecar (downstream consumer)
**Sister files:** sidecar `skills/paper/template/figures/_scripts/*.py` · `skills/paper/samples/sample-nb-bcs-absorbed/figures/_scripts/*.py`

## Problem (one concept)

hexa has no plotting / charting facility — no equivalent of matplotlib (line / bar / scatter, axes, PDF/PNG figure export). `stdlib/` carries numeric / tensor modules but nothing that rasterizes or vector-renders a figure.

## Symptom (downstream)

sidecar's `skills/paper` plugin scaffolds arxiv-style LaTeX papers. Each paper carries figure-generation scripts under `figures/_scripts/` — currently matplotlib `.py` (bar chart, Tc landscape, gap-ratio landscape, a minimal example). The wider sidecar migration moved every hook + skill script from `.py` / `.sh` to `.hexa`, but these 4 figure scripts have no migration target: there is no hexa way to produce a `.pdf` / `.png` plot.

They are therefore **intentionally left as `.py`** — the only sidecar files not migrated. They are user-facing LaTeX-paper figure examples (shipped inside the `paper` skill's template + sample), not sidecar infrastructure, so the `.py` residue is contained and harmless. But it does mean a hexa-native paper-figure pipeline is not yet possible.

## Ask

A plotting facility in hexa stdlib would let figure-generation go hexa-native. Not urgent — recorded so the gap is visible. Possible shapes, in rough order of effort:

1. A thin vector-figure emitter — `stdlib/plot.hexa` producing TikZ / PGFPlots source (LaTeX-native; no rasterizer needed, integrates with the paper pipeline directly).
2. An SVG emitter (`plot_svg`) — portable, convertible to PDF downstream.
3. A full raster backend (matplotlib-class) — large; likely out of scope for hexa's no-GC native posture.

Option 1 (TikZ/PGFPlots source generation) is the natural fit for the `paper` use case and is mostly string-building — no graphics runtime required.

## Related

- `regex-stdlib-gap-sidecar-hook-ports.md` — same migration; regex + XML stdlib gaps.
