# stdlib/freecad/bipv.py — phase κ-33 (P-⑨ start) — FreeCAD parametric
# BIPV producer for demiurge `component + synthesize`.
#
# SSOT location: ~/core/hexa-lang/stdlib/freecad/bipv.py
# (D61 / g_demiurge_pointer_only — no cockpit/scripts/ footprint)
# Migrated from cockpit/scripts/bipv_freecad.py in D114 Phase C
# (D61 violator closure — restored the documented 2026-05-20 plan
# that was deleted from demiurge but never landed in hexa-lang).
#
# Invoked by Swift's FreeCADBIPVProducer via:
#   /Applications/FreeCAD.app/Contents/Resources/bin/freecadcmd \
#       <this-script> --pass <output_dir>
#
# Builds a 5-layer building-integrated photovoltaic (BIPV) module —
# Glass (3.2mm) / PV cells 8x8 (0.2mm) / Frame (8mm) / Sink (12mm) /
# Mount (18mm), 1000x1000mm footprint — using FreeCAD's `Part`
# kernel (OpenCascade) as a real parametric CAD model. Writes:
#   <output_dir>/bipv_freecad_v1.step   — parametric, CAD-interchange
#   <output_dir>/bipv_freecad_v1.brep   — native OpenCascade B-Rep
#   <output_dir>/bipv_freecad_v1.stl    — triangulated mesh (RealityKit
#                                          ingest path; FreeCAD ships
#                                          no glTF/USDZ exporter)
#   <output_dir>/bipv_freecad_v1.meta.json — dims, layer table, units
#
# HONESTY (g3 — non-negotiable):
#   • The geometry is *parametric* (real OpenCascade B-Rep solids),
#     NOT a measured BIPV module. measurement_gate stays GATE_OPEN.
#   • Layer dimensions match ComponentGeometry.bipv5Layer (Swift
#     SSOT) — kept in lockstep by the constants at the top. If those
#     drift, ComponentEmitter.swift's check should reject the artifact.
#   • Thermal / structural / optical verdicts are NOT provided here —
#     those are separate gates (gmsh + Elmer / Code_Aster downstream).
#
# Layer dimensions must mirror
# cockpit/Sources/DemiurgeCore/Models/ComponentGeometry.swift::bipv5Layer.

import json
import os
import sys
import traceback



# --- Constants (mirror ComponentGeometry.bipv5Layer; mm) -----------------
GEOMETRY_ID = "bipv_freecad_v1"
WIDTH_MM = 1000.0
DEPTH_MM = 1000.0

LAYERS = [
    # (name, plain_name, material, thickness_mm, color_hex,
    #  render_kind, opacity)
    ("Glass Face",              "유리 표면",        "tempered glass",
     3.2,  "#A8D8E8", "slab",        0.32),
    ("PV Cells",                "태양전지 셀",      "monocrystalline silicon",
     0.2,  "#1B2A6B", "cell_grid",   1.00),
    ("Corrosion-Proof Frame",   "부식 방지 프레임", "anodized aluminium",
     8.0,  "#9AA0A6", "frame_border",1.00),
    ("Thermal Sink",            "방열판",           "finned aluminium plate",
     12.0, "#FF9500", "finned_sink", 1.00),
    ("Structural Mount",        "구조 마운트",      "galvanised steel",
     18.0, "#555555", "mount_base",  1.00),
]


def total_thickness_mm():
    return sum(l[3] for l in LAYERS)


def layer_center_y(index):
    """Match ComponentGeometry.layerCenterY — top→bottom stack centred
    on origin; index 0 is the top layer."""
    top = total_thickness_mm() / 2.0
    for i in range(index):
        top -= LAYERS[i][3]
    return top - LAYERS[index][3] / 2.0


# --- FreeCAD modules -----------------------------------------------------
import FreeCAD  # noqa: E402
import Part     # noqa: E402
from FreeCAD import Vector  # noqa: E402


def make_box(name, w, t, d, cx, cy, cz, doc):
    """Axis-aligned solid box centred at (cx, cy, cz) with extents
    (w, t, d) along (X, Y, Z). Returns the Feature object."""
    shape = Part.makeBox(w, t, d, Vector(cx - w / 2.0,
                                         cy - t / 2.0,
                                         cz - d / 2.0))
    feat = doc.addObject("Part::Feature", name)
    feat.Shape = shape
    return feat


def slab_boxes(layer, cy):
    """Single full-footprint slab (Glass)."""
    _, _, _, t, _, _, _ = layer
    return [("Slab", WIDTH_MM, t, DEPTH_MM, 0.0, cy, 0.0)]


def cell_grid_boxes(layer, cy):
    """8x8 PV cell grid inset 92% of footprint, 86% pitch utilisation."""
    _, _, _, t, _, _, _ = layer
    n = 8
    area = WIDTH_MM * 0.92
    pitch = area / n
    cell = pitch * 0.86
    boxes = []
    for i in range(n):
        for j in range(n):
            cx = -area / 2.0 + pitch * (i + 0.5)
            cz = -area / 2.0 + pitch * (j + 0.5)
            boxes.append((f"Cell_{i}_{j}", cell, t, cell, cx, cy, cz))
    return boxes


def frame_border_boxes(layer, cy):
    """4-side perimeter frame, bar = 9% min(W,D), hollow centre."""
    _, _, _, t, _, _, _ = layer
    w, d = WIDTH_MM, DEPTH_MM
    bar = min(w, d) * 0.09
    inner_d = d - 2.0 * bar
    return [
        ("Frame_FrontBar", w,   t, bar,     0.0,           cy, (d - bar) / 2.0),
        ("Frame_RearBar",  w,   t, bar,     0.0,           cy, -(d - bar) / 2.0),
        ("Frame_RightBar", bar, t, inner_d, (w - bar) / 2.0,  cy, 0.0),
        ("Frame_LeftBar",  bar, t, inner_d, -(w - bar) / 2.0, cy, 0.0),
    ]


def finned_sink_boxes(layer, cy):
    """Thin base plate + 15 fins, base = 28% of thickness."""
    _, _, _, t, _, _, _ = layer
    w, d = WIDTH_MM, DEPTH_MM
    base_t = t * 0.28
    fin_t = t - base_t
    # base plate (sits at the bottom of the layer's slot)
    base_cy = cy + (base_t - t) / 2.0
    boxes = [("Sink_Base", w, base_t, d, 0.0, base_cy, 0.0)]
    count = 15
    span = w * 0.94
    pitch = span / count
    fin = pitch * 0.5
    fin_cy = cy + base_t / 2.0
    for i in range(count):
        cx = -span / 2.0 + pitch * (i + 0.5)
        boxes.append((f"Sink_Fin_{i}", fin, fin_t, d * 0.9,
                      cx, fin_cy, 0.0))
    return boxes


def mount_base_boxes(layer, cy):
    """Base plate (50% of thickness, 82% of footprint) + 4 corner brackets."""
    _, _, _, t, _, _, _ = layer
    w, d = WIDTH_MM, DEPTH_MM
    base_t = t * 0.5
    base_cy = cy + (base_t - t) / 2.0
    boxes = [("Mount_Base", w * 0.82, base_t, d * 0.82,
              0.0, base_cy, 0.0)]
    br = min(w, d) * 0.16
    ox = w * 0.41
    oz = d * 0.41
    for sx, sz, label in [(1, 1, "PP"), (-1, 1, "NP"),
                          (1, -1, "PN"), (-1, -1, "NN")]:
        boxes.append((f"Mount_Bracket_{label}", br, t, br,
                      ox * sx, cy, oz * sz))
    return boxes


RENDER_DISPATCH = {
    "slab":         slab_boxes,
    "cell_grid":    cell_grid_boxes,
    "frame_border": frame_border_boxes,
    "finned_sink":  finned_sink_boxes,
    "mount_base":   mount_base_boxes,
}


def build_layer_compound(layer, index, doc):
    """Construct the union of all detail boxes for one layer and
    return one Part::Feature carrying the compound shape."""
    name = layer[0]
    render = layer[5]
    cy = layer_center_y(index)
    boxes = RENDER_DISPATCH[render](layer, cy)
    shapes = []
    for (bname, w, t, d, cx, by, cz) in boxes:
        shapes.append(Part.makeBox(w, t, d,
                                   Vector(cx - w / 2.0,
                                          by - t / 2.0,
                                          cz - d / 2.0)))
    if not shapes:
        return None
    compound = shapes[0] if len(shapes) == 1 else Part.makeCompound(shapes)
    feat_name = f"Layer_{index}_{render}".replace(" ", "_")
    feat = doc.addObject("Part::Feature", feat_name)
    feat.Shape = compound
    return feat


def export_step(features, path):
    """Export a list of Part::Feature objects to STEP AP214."""
    shapes = [f.Shape for f in features if f is not None]
    if not shapes:
        return False
    compound = Part.makeCompound(shapes)
    compound.exportStep(path)
    return os.path.exists(path) and os.path.getsize(path) > 0


def export_brep(features, path):
    shapes = [f.Shape for f in features if f is not None]
    if not shapes:
        return False
    compound = Part.makeCompound(shapes)
    compound.exportBrep(path)
    return os.path.exists(path) and os.path.getsize(path) > 0


def export_stl(features, path):
    """Triangulate the compound and write an ASCII STL.

    Mesh module ships with FreeCAD; the tessellate() call uses a
    0.5mm linear deflection (fine enough for 0.2mm PV cell features
    yet not exploding triangle count for the 1m slab faces)."""
    import Mesh
    shapes = [f.Shape for f in features if f is not None]
    if not shapes:
        return False
    compound = Part.makeCompound(shapes)
    # tessellate returns (vertices, triangle_indices)
    verts, tris = compound.tessellate(0.5)
    mesh = Mesh.Mesh()
    mesh_data = []
    for (a, b, c) in tris:
        mesh_data.append([verts[a], verts[b], verts[c]])
    # Mesh expects flat list of (v1,v2,v3) per triangle
    flat_facets = []
    for tri in mesh_data:
        flat_facets.append(tri[0])
        flat_facets.append(tri[1])
        flat_facets.append(tri[2])
    mesh.addFacets(flat_facets)
    mesh.write(path)
    return os.path.exists(path) and os.path.getsize(path) > 0


def write_meta(path, exports_written):
    layer_meta = []
    for idx, l in enumerate(LAYERS):
        layer_meta.append({
            "name": l[0],
            "plain_name": l[1],
            "material": l[2],
            "thickness_mm": l[3],
            "color_hex": l[4],
            "render": l[5],
            "opacity": l[6],
            "center_y_mm": layer_center_y(idx),
        })
    meta = {
        "geometry_id": GEOMETRY_ID,
        "producer": "freecad",
        "freecad_version": list(FreeCAD.Version()),
        "units": "millimetres",
        "width_mm": WIDTH_MM,
        "depth_mm": DEPTH_MM,
        "total_thickness_mm": total_thickness_mm(),
        "layer_count": len(LAYERS),
        "layers": layer_meta,
        "exports": exports_written,
        "honest_gap": [
            "Parametric (OpenCascade B-Rep) geometry — NOT a measured "
            "BIPV module. measurement_gate = GATE_OPEN (g3).",
            "Layer dimensions are plausible (mirror Swift "
            "ComponentGeometry.bipv5Layer SSOT) — not pulled from a "
            "datasheet, not validated against a physical part.",
            "Thermal / structural / optical verdicts are NOT included "
            "— those are downstream gates (gmsh + Elmer / Code_Aster).",
        ],
    }
    with open(path, "w") as f:
        json.dump(meta, f, indent=2, sort_keys=True)
    return os.path.exists(path) and os.path.getsize(path) > 0


def main(argv):
    # FreeCAD's `freecadcmd` injects -P --pythonpath flags before our
    # script, so trailing user args sit at the end of sys.argv. The
    # caller wraps the output_dir after `--` to be explicit. We accept
    # either form: last positional arg is the output directory.
    output_dir = None
    for a in reversed(argv):
        if a and not a.startswith("-") and a != argv[0]:
            output_dir = a
            break
    if not output_dir:
        sys.stderr.write("bipv_freecad: missing <output_dir> argv\n")
        sys.exit(2)
    os.makedirs(output_dir, exist_ok=True)

    sys.stderr.write(
        f"bipv_freecad: FreeCAD={FreeCAD.Version()[:3]} "
        f"output_dir={output_dir}\n")

    doc = FreeCAD.newDocument("BIPV")
    features = []
    for idx, layer in enumerate(LAYERS):
        feat = build_layer_compound(layer, idx, doc)
        if feat is not None:
            features.append(feat)
    doc.recompute()

    exports = {}
    step_path = os.path.join(output_dir, f"{GEOMETRY_ID}.step")
    brep_path = os.path.join(output_dir, f"{GEOMETRY_ID}.brep")
    stl_path  = os.path.join(output_dir, f"{GEOMETRY_ID}.stl")
    meta_path = os.path.join(output_dir, f"{GEOMETRY_ID}.meta.json")

    if export_step(features, step_path):
        exports["step"] = f"{GEOMETRY_ID}.step"
        sys.stderr.write(f"bipv_freecad: wrote {step_path}\n")
    if export_brep(features, brep_path):
        exports["brep"] = f"{GEOMETRY_ID}.brep"
        sys.stderr.write(f"bipv_freecad: wrote {brep_path}\n")
    if export_stl(features, stl_path):
        exports["stl"] = f"{GEOMETRY_ID}.stl"
        sys.stderr.write(f"bipv_freecad: wrote {stl_path}\n")
    if write_meta(meta_path, exports):
        sys.stderr.write(f"bipv_freecad: wrote {meta_path}\n")

    FreeCAD.closeDocument(doc.Name)

    # Write a one-line summary to stderr (FreeCAD claims stdout for
    # its own chatter, but the lines we care about reliably appear on
    # stderr — the Swift caller sniffs the merged output stream).
    summary = {
        "ok": bool(exports),
        "geometry_id": GEOMETRY_ID,
        "exports": exports,
        "freecad_version": list(FreeCAD.Version())[:3],
        "layer_count": len(LAYERS),
        "total_thickness_mm": total_thickness_mm(),
    }
    sys.stderr.write("BIPV_FREECAD_RESULT "
                     + json.dumps(summary, sort_keys=True) + "\n")
    sys.stderr.flush()
    sys.exit(0 if exports else 3)


# FreeCAD's `freecadcmd` runs the script with __name__ set to the
# script's stem (not "__main__"), so we cannot guard on __main__ —
# we run the main entry unconditionally on module import.
try:
    main(sys.argv)
except SystemExit:
    raise
except Exception as exc:
    sys.stderr.write("bipv_freecad: fatal — "
                     f"{type(exc).__name__}: {exc}\n")
    traceback.print_exc(file=sys.stderr)
    sys.exit(4)
