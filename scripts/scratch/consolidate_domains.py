import json, os, re, glob

# 1) collect domain snapshots (root + domains/, has @goal, not *.log.md)
files = sorted(set(glob.glob("*.md") + glob.glob("domains/*.md")))
domains = []
for f in files:
    if f.endswith(".log.md"): continue
    txt = open(f, encoding="utf-8", errors="replace").read()
    m = re.search(r'^@goal:\s*(.+)$', txt, re.M)
    if not m: continue
    goal = m.group(1).strip()
    title = None
    mt = re.search(r'^@title:\s*(.+)$', txt, re.M)
    if mt: title = mt.group(1).strip()
    done = re.findall(r'^- \[x\]\s*(.+)$', txt, re.M)
    openm = re.findall(r'^- \[ \]\s*(.+)$', txt, re.M)
    name = os.path.splitext(os.path.basename(f))[0]
    status = "✅ DONE" if not openm else f"🔵 {len(done)}/{len(done)+len(openm)}"
    # final-form: keep OPEN milestones (remaining); done-history retired with logs.
    # trim each open line to keep the registry readable; full detail lived in the logs.
    def trim(s, n=240):
        s = s.strip()
        return s if len(s) <= n else s[:n].rstrip() + " …"
    remaining = " · ".join(trim(o, 200) for o in openm) if openm else "—"
    domains.append({"name": name, "src": f, "title": title, "goal": goal,
                    "done": len(done), "open": len(openm), "status": status,
                    "remaining": remaining})

# active first (open>0), then done; each group name-sorted
domains.sort(key=lambda d: (d["open"]==0, d["name"]))

# 2) build the architecture domains section (table)
rows = [[d["name"], d["status"], d["goal"], d["remaining"]] for d in domains]
section = {
  "id": "domains",
  "title": "Domains — final-form registry (도메인 SSOT; *.md·*.log.md·*.tape·DOMAINS.tape retired 2026-06-17)",
  "blocks": [
    {"type": "prose", "text": "Each domain's FINAL FORM only — `@goal` + current status + remaining (`- [ ]`) work. The append-only milestone history (`- [x]` done-log + `*.log.md`/`*.tape` step logs) is RETIRED; this JSON is now the single domain record (md 단일화, c4). Status `✅ DONE` = no open milestones; `🔵 d/t` = d-of-t milestones done. Counts/history live in CHANGELOG.md + git."},
    {"type": "prose", "text": "**%d domains** consolidated (%d active · %d done)." % (len(domains), sum(1 for d in domains if d["open"]), sum(1 for d in domains if not d["open"]))},
    {"type": "table",
     "columns": ["Domain", "Status", "@goal (final)", "Remaining (open)"],
     "rows": rows}
  ]
}

arch = json.load(open("ARCHITECTURE.json", encoding="utf-8"))
arch["sections"] = [s for s in arch["sections"] if s.get("id") != "domains"]
arch["sections"].append(section)
json.dump(arch, open("ARCHITECTURE.json","w",encoding="utf-8"), ensure_ascii=False, indent=2)
print("domains consolidated:", len(domains))
print("active:", sum(1 for d in domains if d["open"]), "done:", sum(1 for d in domains if not d["open"]))
# validate JSON re-parses
json.load(open("ARCHITECTURE.json", encoding="utf-8"))
print("ARCHITECTURE.json valid JSON ✓")
