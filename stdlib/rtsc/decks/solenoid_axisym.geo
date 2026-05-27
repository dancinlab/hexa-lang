// ============================================================================
//  solenoid_axisym.geo — 2-D axisymmetric finite-SOLENOID geometry (Gmsh/OCC)
//  FUSION gate (e) F5 promote · HEXA-PORT P2 parity-oracle reference coil.
// ----------------------------------------------------------------------------
//  Canonical home: stdlib/rtsc/decks/ (hexa-lang code-home per CLAUDE.md @D d3).
//  Defaults = HEXA-PORT P2 reference coil (a=0.50, b=0.70, h=1.20).
//
//  A solenoid in axisymmetric (r,z) cross-section is a TALL, NARROW (or here
//  STOCKY) rectangle centred on z=0. We embed it in a 1-D-large air box
//  that is the far-field truncation boundary (Dirichlet A=0).
//
//          r=0 (axis)              r=R_OUT
//          +------+----+------+   <- z=+H_OUT
//          | air  | || | air  |   <- z=+H_COIL/2
//          |      | || |      |
//          |      |coil|      |
//          |      | || |      |
//          | air  | || | air  |   <- z=-H_COIL/2
//          +------+----+------+   <- z=-H_OUT
//          ^axis  r=R_IN
//                   r=R_OUTC
//
//  Coordinate convention: gmsh x → r, gmsh y → z  (matches the .pro).
//
//  NOTE on J_φ: winding-window area  A_coil = (R_OUTC - R_IN) * H_COIL.
//  The .pro computes J_φ = NI / A_coil directly from the SAME R_IN/R_OUTC
//  /H_COIL parameters, so the deck and mesh stay coupled automatically.
//
//  PHYSICAL-GROUP CONTRACT (must match solenoid_axisym.pro):
//    Physical Surface "AIR"     → 1000
//    Physical Surface "COIL"    → 2000
//    Physical Curve   "AXIS"    → 3000
//    Physical Curve   "FAR_BND" → 4000
// ============================================================================

SetFactory("OpenCASCADE");

// ---- parameters (override via gmsh -setnumber ...) -------------------------
// Defaults = HEXA-PORT P2 reference (NI=2e6, a=0.50, b=0.70, h=1.20).
// VALIDATED defaults (HEXA-PORT P2 parity, ubu-1 getdp 3.5.0):
//   Mesh ~33k nodes (R_OUT=7, LC_AIR=0.10, LC_COIL=0.008)
//     → FEM B_z(0) = 1.4817 T  vs  closed-form 1.48265 T  →  Δ = -0.064%
//   Refinement to ~61k nodes → 1.4783 T (Δ = -0.30%); residual is
//   finite-far-field + mesh-quadrature; the FEM is mesh-converged within
//   a few-tenths-of-a-percent — the "few %" parity oracle target met.
DefineConstant[
  R_IN    = 0.50,    // winding inner radius a [m]
  R_OUTC  = 0.70,    // winding outer radius b [m]
  H_COIL  = 1.20,    // winding axial height h [m]
  R_OUT   = 7.00,    // far-field box outer radius [m]  (~10x coil OR)
  H_OUT   = 8.40,    // far-field box half-height  [m]  (~7x H_COIL)
  LC_AIR  = 0.10,    // mesh size in air  [m]
  LC_COIL = 0.008    // mesh size in coil [m]   (~ (b-a)/25 — 25 layers across)
];

// ---- half-plane rectangles (r ≥ 0) -----------------------------------------
air_full = news;
Rectangle(air_full) = {0, -H_OUT, 0, R_OUT, 2*H_OUT};
coil = news;
Rectangle(coil) = {R_IN, -H_COIL/2, 0, R_OUTC - R_IN, H_COIL};

// ---- fragment air around coil → conforming shared boundary -----------------
frag[] = BooleanFragments{ Surface{air_full}; Delete; }{ Surface{coil}; Delete; };

// ---- identify which fragment is air vs coil (larger area = air) ------------
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

// ---- boundary curves --------------------------------------------------------
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

// ---- mesh sizing ------------------------------------------------------------
MeshSize { PointsOf{ Surface { AIR_TAG  }; } } = LC_AIR;
MeshSize { PointsOf{ Surface { COIL_TAG }; } } = LC_COIL;

Mesh.Algorithm     = 5;   // Delaunay — robust with OCC fragments
Mesh.ElementOrder  = 1;
