# complexity-integration-triad — paper status

@title: 📄 Structure Beyond Density (complexity-integration-triad)
@goal: Show that a structural invariant predicts integration/ruggedness after density is held fixed — across three substrates, with two honest negatives.

- [x] draft v1 — full body, now 10 sections incl. Discussion + Worked examples
- [x] figures complete — fig01 F3 spine, fig02 density sweep, fig03 pipeline (pure pgfplots/TikZ; all render)
- [ ] figures: fal.ai cover (prompt ready at `figures/_prompts/cover.txt`; render on a connected/imagine host)
- [x] references — 9 real entries (Edwards-Anderson, Toulouse, Binder-Young, Tononi, Oizumi, Lempel-Ziv, Mac Lane, Hatcher, Bianconi); all carry DOI/URL
- [ ] lint pass (`/paper lint .`) — run on a host with the linter reachable
- [x] compile clean — `make figures && make` rc=0 with pdflatex + pgfplots (verified on a texlive host 2026-06-01)
- [x] page count ≥10 — `make pages` reports 10
- [ ] arxiv submit ready (`/paper arxiv-prep .`)
