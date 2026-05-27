# docs/notes — INDEX

> Triage pass 2026-05-19 (rfc043-hexa-torch). `docs/notes/` holds
> escalations / observations / session-logs (distinct from
> `archive/patches/`, which are actionable downstream bug/feature
> requests). After this pass the directory is split into:
>
> - **2 still-actionable notes** — left in place at `docs/notes/`,
>   listed below. Each describes an open issue/gap that still needs work.
> - **47 stale-historical notes** — moved to `docs/notes/archive/`
>   (46 `.md` session records + 1 `.n6` harvest artifact). These are
>   completed session logs whose content is resolved or superseded
>   (interpreter retirement closed per `@D g_interp_deprecated`; the
>   qrng/qmirror/sim-universe absorption RFCs 044/045/046 LANDED; the
>   2026-05-11..05-14 dated notes are append-only audit trail not
>   updated as state evolves). Nothing was deleted — archival move only.

## Still-actionable notes (2)

| File | What's open |
|---|---|
| `2026-05-19-hexa-arch-rfc006-yosys-handoff.md` | Item ② of the hexa-arch handoff: implement rfc_006 §4 Yosys modules in `stdlib/yosys/` (`rtlil`, `read_verilog`, `passes`, `liberty`, `abc_map`, `write_verilog`, `yosys`). Today `stdlib/yosys/` is **scaffold only** — 7 `.hexa.stub` + README; the rfc_006 §5 measured gate (SKY130 synthesis of comb `router_d{4,6}.v`) is OPEN, so "Yosys absorbed" is not yet claimable. (Item ① booksim push and item ③ g3 correction are done.) |
| `phanes-stdlib-net-os-thread-concurrency-roadmap-62.md` | Resolved-ssot for option (a) — `socket_set_nonblock` + `socket_select` landed in `stdlib/net/socket.hexa`. But the note documents the still-open **roadmap-62** ceiling: option (b), true OS-thread workers in `concurrent_serve::run()`, requires a runtime threading-model RFC and is not yet done. `concurrent_serve` remains logical-only concurrency until then. Kept actionable as the standing pointer to that unfinished roadmap item. |

## Archived (47)

Moved to `docs/notes/archive/` — see that directory. Breakdown:

- **44** dated session records `2026-05-11-*` .. `2026-05-14-*` (`.md`) —
  hexa-lang absorption work, wilson↔hexa-lang closure, atlas/n6
  absorption phases, drill spine + variants, nexus full-purge, and
  inter-repo absorption plans. All pre-date the interpreter retirement
  and the 044/045/046 absorption landings; none are consumed by any
  tool.
- **1** `.n6` artifact — `2026-05-14-anima-engine-harvest-candidates.n6`
  (engine docstring harvest companion).
- **2** resolved/closed 2026-05-19 notes:
  - `2026-05-19-rtl-dsl-scope-decision.md` — resolved-ssot (Option B:
    RTL DSL ownership moved to hexa-chip; deprecation marker landed).
  - `2026-05-19-shared-worktree-hazard-yosys-drop.md` — audit trail of
    a recovered shared-worktree incident; the dropped yosys scaffold
    was re-landed, no open action.
  - `phanes-stdlib-net-server-serve-idle-socket-deadlock.md` —
    resolved-ssot (`server_serve` rewritten as a select-guarded accept
    loop; idle sockets reaped).

## Sunset

Once the inbox itself sunsets (per `INBOX.md` §Sunset — at stage 3
fixpoint), `docs/notes/archive/` can be moved wholesale to
`docs/sessions/` or a similar archival location. The 2 actionable
notes graduate to closure (or to `archive/patches/`) before then.
