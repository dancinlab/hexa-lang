// solenoid_axisym.geo — parametric axisymmetric finite solenoid for
// getdp_hts.py. Placeholders ($NAME) are substituted by the Python
// producer before invoking gmsh. Domain layout:
//
//   r=0 (axis)              r=R_out
//   +------+----+-----+------+   <- z=+H_out
//   |      |    |     |      |
//   | air  | -- |coil | air  |
//   |      | -- |     |      |
//   |      | -- |     |      |
//   +------+----+-----+------+   <- z=-H_out
//   ↑axis  r=r_in r=r_out
//
// Coordinate convention: getdp axisym pairs gmsh x→r, gmsh y→z. Uses
// OpenCASCADE + BooleanFragments to robustly stitch the coil rectangle
// into the air box (avoids classical-kernel edge-recovery failures
// when two surfaces share an interior boundary).

SetFactory("OpenCASCADE");

R_OUT  = $R_OUT;
H_OUT  = $H_OUT;
R_IN   = $R_IN;
R_OUTC = $R_OUTC;
H_COIL = $H_COIL;
LC_AIR  = $LC_AIR;
LC_COIL = $LC_COIL;

// Half-plane rectangles (r ≥ 0). OCC `Rectangle` returns a surface tag.
air_full = news;
Rectangle(air_full) = {0, -H_OUT, 0, R_OUT, 2*H_OUT};
coil = news;
Rectangle(coil) = {R_IN, -H_COIL/2, 0, R_OUTC-R_IN, H_COIL};

// Fragment the air rectangle around the coil so the two surfaces share
// a conforming boundary mesh. After Fragments, the two surfaces are
// returned in `frag[]` (air piece first, coil piece next).
frag[] = BooleanFragments{ Surface{air_full}; Delete; }{ Surface{coil}; Delete; };

// `frag[]` carries the rebuilt surface tags. With OCC, fragments are
// ordered by their bounding-box centroid; the coil sits inside the air
// box, so the larger surface is air, the smaller is coil.
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
// (x=0); the far boundary is everything else on the outer rectangle.
axis_curves[] = Curve In BoundingBox { -1e-6, -H_OUT-1, -1e-6,
                                        1e-6,  H_OUT+1,  1e-6 };
all_outer[]   = Curve In BoundingBox { -1e-6, -H_OUT-1e-6, -1e-6,
                                        R_OUT+1e-6, H_OUT+1e-6, 1e-6 };
// FAR_BND = outer minus axis (no MultiSet-difference in .geo, so we
// physically tag just the three non-axis sides explicitly by box).
bot_curves[] = Curve In BoundingBox { -1e-6, -H_OUT-1e-6, -1e-6,
                                       R_OUT+1e-6, -H_OUT+1e-6, 1e-6 };
top_curves[] = Curve In BoundingBox { -1e-6,  H_OUT-1e-6, -1e-6,
                                       R_OUT+1e-6,  H_OUT+1e-6, 1e-6 };
rgt_curves[] = Curve In BoundingBox { R_OUT-1e-6, -H_OUT-1e-6, -1e-6,
                                      R_OUT+1e-6,  H_OUT+1e-6, 1e-6 };

Physical Curve("AXIS",    3000) = axis_curves[];
Physical Curve("FAR_BND", 4000) = { bot_curves[], top_curves[], rgt_curves[] };

// Mesh sizing — coarser air, finer coil.
MeshSize { PointsOf{ Surface { AIR_TAG  }; } } = LC_AIR;
MeshSize { PointsOf{ Surface { COIL_TAG }; } } = LC_COIL;

Mesh.Algorithm = 5;        // Delaunay — robust with OCC fragments
Mesh.ElementOrder = 1;
