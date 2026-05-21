// pancake_axisym.geo — parametric axisymmetric pancake (flat-spiral) coil
// for getdp_hts.py. Placeholders ($NAME) are substituted by the Python
// producer before invoking gmsh.
//
// Honest scope: 2-D axisym + linear μ_r=1 + procedural — see RTSC.md §4.3.
//
// Pancake vs solenoid geometry difference:
//   - Solenoid: axially-extended cylindrical winding. Cross-section is a
//     TALL thin rectangle (large axial H_COIL, small radial R_OUTC-R_IN).
//     B-field principally along z; turns stack axially.
//   - Pancake : flat spiral wound radially in the (r,z) plane at ~z≈0.
//     Cross-section is a WIDE thin rectangle (small axial H_COIL ~ a few mm,
//     large radial winding span R_OUTC-R_IN ~ tens to hundreds of mm).
//     Turns stack radially; field on axis peaks at z=0 with rapid falloff.
//   The .geo file shape is the same axisymmetric rectangle topology, only
//   the aspect ratio changes — which is why the same solenoid_axisym.pro
//   (Form1P A-φ, axis Dirichlet, VolAxiSqu) is reusable verbatim.
//
//   r=0 (axis)                      r=R_OUT
//   +------+---------------+---------+   <- z=+H_OUT
//   |      |               |         |
//   | air  | pancake coil  |  air    |
//   |      |==== flat ===  |         |    (H_COIL is small;
//   |      |               |         |     R_OUTC-R_IN is large)
//   +------+---------------+---------+   <- z=-H_OUT
//   ↑axis  r=R_IN          r=R_OUTC
//
// Coordinate convention: getdp axisym pairs gmsh x→r, gmsh y→z. Uses
// OpenCASCADE + BooleanFragments to robustly stitch the coil rectangle
// into the air box (avoids gmsh classical-kernel edge-recovery failures
// — see RTSC.md §4.2.2 finding #2).
//
// Same Physical tags as solenoid_axisym.geo:
//   AIR=1000 · COIL=2000 · AXIS=3000 · FAR_BND=4000

SetFactory("OpenCASCADE");

R_OUT  = $R_OUT;
H_OUT  = $H_OUT;
R_IN   = $R_IN;
R_OUTC = $R_OUTC;
H_COIL = $H_COIL;
LC_AIR  = $LC_AIR;
LC_COIL = $LC_COIL;

// Half-plane rectangles (r ≥ 0). OCC `Rectangle` returns a surface tag.
// For a pancake, H_COIL is small (axial thickness) and R_OUTC-R_IN is
// large (radial winding span). The coil rectangle is centered at z=0.
air_full = news;
Rectangle(air_full) = {0, -H_OUT, 0, R_OUT, 2*H_OUT};
coil = news;
Rectangle(coil) = {R_IN, -H_COIL/2, 0, R_OUTC-R_IN, H_COIL};

// Fragment the air rectangle around the coil so the two surfaces share
// a conforming boundary mesh. After Fragments, the two surfaces are
// returned in `frag[]`.
frag[] = BooleanFragments{ Surface{air_full}; Delete; }{ Surface{coil}; Delete; };

// `frag[]` carries the rebuilt surface tags. The larger surface (by mass)
// is air, the smaller is coil. Disambiguate by area rather than relying
// on ordering (OCC fragment order varies by aspect ratio).
m1 = Mass Surface { frag[0] };
m2 = Mass Surface { frag[1] };
If (m1 >= m2)
  AIR_TAG  = frag[0];
  COIL_TAG = frag[1];
Else
  AIR_TAG  = frag[1];
  COIL_TAG = frag[0];
EndIf

Physical Surface("AIR",  1000) = { AIR_TAG  };
Physical Surface("COIL", 2000) = { COIL_TAG };

// Boundary curves of the unioned domain. The axis is the r=0 line
// (x=0); FAR_BND is the three non-axis outer sides (bottom/top/right).
axis_curves[] = Curve In BoundingBox { -1e-6, -H_OUT-1, -1e-6,
                                        1e-6,  H_OUT+1,  1e-6 };
bot_curves[] = Curve In BoundingBox { -1e-6, -H_OUT-1e-6, -1e-6,
                                       R_OUT+1e-6, -H_OUT+1e-6, 1e-6 };
top_curves[] = Curve In BoundingBox { -1e-6,  H_OUT-1e-6, -1e-6,
                                       R_OUT+1e-6,  H_OUT+1e-6, 1e-6 };
rgt_curves[] = Curve In BoundingBox { R_OUT-1e-6, -H_OUT-1e-6, -1e-6,
                                      R_OUT+1e-6,  H_OUT+1e-6, 1e-6 };

Physical Curve("AXIS",    3000) = axis_curves[];
Physical Curve("FAR_BND", 4000) = { bot_curves[], top_curves[], rgt_curves[] };

// Mesh sizing — coarser air, finer coil. The coil characteristic length
// should resolve the small axial H_COIL (typically LC_COIL ≲ H_COIL/4).
MeshSize { PointsOf{ Surface { AIR_TAG  }; } } = LC_AIR;
MeshSize { PointsOf{ Surface { COIL_TAG }; } } = LC_COIL;

Mesh.Algorithm = 5;        // Delaunay — robust with OCC fragments
Mesh.ElementOrder = 1;
