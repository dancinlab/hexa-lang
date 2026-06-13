# hexa run import resolver argv0 before stdlib root

> Materialized from cross-repo handoff `bb8e3382` (from demiurge, 1780276896) per demiurge @D d8
> (vast/cloud finding -> hexa-lang/inbox/patches so `hexa cloud` absorbs upstream).

hexa run/build import resolver: install_dir_from_argv0() is pushed onto the module search roots BEFORE HEXA_STDLIB_ROOT is read (self/main.hexa ~L3558), so from a non-hexa-lang cwd (e.g. demiurge) 'hexa kick'/'hexa drill' fail with 'module not found: compiler/_cli_args/parse' unless HEXA_LANG=<hexa-lang> is exported. Fix: read HEXA_STDLIB_ROOT/HEXA_LANG into the root list BEFORE the install-dir fallback. Blocks /hexa-loop discover (kick) from any campaign repo.

---
source: sidecar handoff `bb8e3382` (demiurge -> hexa-lang) · status: open (awaiting hexa-lang absorb)
