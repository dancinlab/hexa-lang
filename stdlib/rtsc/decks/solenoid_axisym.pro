// ============================================================================
//  solenoid_axisym.pro — 2-D axisymmetric magnetostatic coil
//  (GetDP · linear A-φ formulation · formulation id = magstat_a_linear)
//  FUSION gate (e) F5 promote · HEXA-PORT P2 parity-oracle FEM half.
// ----------------------------------------------------------------------------
//  Canonical home: stdlib/rtsc/decks/ (hexa-lang code-home per CLAUDE.md @D d3).
//  Closed-form parity oracle: tool/verify_cli.hexa _solenoid_axis_bz(NI,a,b,h)
//    (μ₀·J/2)·h·ln[(b+√(b²+(h/2)²))/(a+√(a²+(h/2)²))], J=NI/((b−a)h)
//  Reference coil (HEXA-PORT P2, FUSION (e) anchor):
//    NI=2e6, a=0.50, b=0.70, h=1.20  →  B_z(0)=1.48265 T.
//  The FEM is a VALID parity oracle ONLY when on-axis B_z agrees with the
//  closed form (mesh-converged). VALIDATED on ubu-1 getdp 3.5.0 with the
//  .geo VALIDATED defaults (R_OUT=7, LC_AIR=0.10, LC_COIL=0.008, ~33k
//  nodes):  FEM B_z(0) = 1.4817 T  vs  closed-form 1.48265 T  →  Δ=-0.064%.
//  Refinement to ~61k nodes → 1.4783 T (Δ=-0.30%) — mesh-converged within
//  ≤0.3%, well inside the "few %" parity-oracle target.
//
//  Smaller (Lorenz) baseline (M318 cross-check, demiurge agent 2026-05-21):
//    N=120, I=100, a=0.030, b=0.055, h=0.200  →  closed-form 0.06931 T,
//    FEM 0.06842 T  →  Δ=-1.40%  (same deck, smaller LC).
//
//  Read-back: the on-axis B_z at z=0 is row 101 (0-indexed: 100) of the
//  bmag_axis.txt OnLine sweep (200 samples over z∈[-Z_SWEEP,+Z_SWEEP]),
//  last column = |B|. The OnPoint at (0,0,0) is degenerate (axis-edge
//  vertex) — use the OnLine sweep.
//
//  HONEST SCOPE (commons g3): linear, μ_r = 1 everywhere. Vacuum/air field
//  of a prescribed engineering current density only. HTS critical-state
//  (Jc(B,T,θ)), quench, ramp-loss and 3-D end effects NOT captured. For
//  HTS-grade physics the H-formulation track (multi-week) supersedes.
//
//  COORDINATE CONVENTION (GetDP axisymmetric):  gmsh x → r,  gmsh y → z.
//  The VolAxiSqu Jacobian carries the 2π·r measure appropriate for A_φ
//  and is regular on the symmetry axis r=0 via the u = r·A_φ substitution.
//
//  PHYSICAL-GROUP CONTRACT (the .geo MUST tag exactly these):
//    Physical Surface "AIR"     → 1000   (vacuum/air, μ_r = 1)
//    Physical Surface "COIL"    → 2000   (winding cross-section, J_φ source)
//    Physical Curve   "AXIS"    → 3000   (r = 0 symmetry line, Dirichlet A=0)
//    Physical Curve   "FAR_BND" → 4000   (truncation boundary, Dirichlet A=0)
//
//  PARAMETERS (override on the command line, e.g.
//      getdp solenoid_axisym.pro -setnumber NI 2e6 -setnumber R_IN 0.50 ...
// ============================================================================

DefineConstant[
  // Total ampere-turns NI [A-turns] (the closed-form input, single source of
  // truth). J_φ = NI / A_coil where A_coil = (R_OUTC-R_IN)*H_COIL is read
  // back from the .geo parameters below so the deck and mesh stay coupled.
  NI        = { 2.0e6,  Name "Coil/Ampere-turns NI [A]"         },
  // Coil winding-window geometry — must match the .geo. Defaults = BIG ref.
  R_IN      = { 0.50,   Name "Coil/Inner radius a [m]"          },
  R_OUTC    = { 0.70,   Name "Coil/Outer radius b [m]"          },
  H_COIL    = { 1.20,   Name "Coil/Axial height h [m]"          },
  // Axial sweep half-length for the on-axis B(z) post-op line [m].
  Z_SWEEP   = { 1.5,    Name "Post/Axial sweep half-length [m]" },
  // Output directory for the Print[] tables (Format Table → plain text).
  OUT_DIR   = { ".",    Name "Post/Output directory"            }
];

Group {
  Air    = Region[ 1000 ];
  Coil   = Region[ 2000 ];
  Axis   = Region[ 3000 ];
  FarBnd = Region[ 4000 ];
  Domain = Region[ { Air, Coil } ];
}

Function {
  mu0     = 4 * Pi * 1e-7;       // vacuum permeability [H/m]
  nu[All] = 1 / mu0;             // reluctivity ν = 1/μ ; μ_r = 1 (linear)

  // Engineering azimuthal current density  J_φ = NI / A_coil  [A/m²].
  // A_coil = (R_OUTC - R_IN) * H_COIL — must match the .geo winding window.
  // For the Form1P (perpendicular-edge) axisymmetric A-φ formulation the
  // source is a VECTOR whose component perpendicular to the (r,z) mesh
  // plane (here the gmsh-z slot) carries the azimuthal current; a scalar
  // would yield a zero RHS because the test function {a} is a perp form.
  js[Coil] = Vector[ 0, 0, NI / ((R_OUTC - R_IN) * H_COIL) ];
}

Constraint {
  { Name a_BC; Type Assign;
    Case {
      // Dirichlet A_φ = 0 on the far boundary (proxy for infinity).
      { Region FarBnd; Value 0; }
      // Dirichlet A_φ = 0 on the symmetry axis r=0: a regular on-axis
      // B-field requires the vector potential to vanish there. VolAxiSqu's
      // u = r·A_φ substitution implies this analytically; pinning it
      // explicitly stabilises Form1P node DOFs against drift along r=0.
      { Region Axis; Value 0; }
    }
  }
}

Jacobian {
  { Name Vol; Case { { Region All; Jacobian VolAxiSqu; } } }  // 2π·r volume
  { Name Sur; Case { { Region All; Jacobian SurAxi;    } } }  // 2π·r surface
}

Integration {
  { Name I1;
    Case { { Type Gauss;
      Case {
        { GeoElement Triangle; NumberOfPoints 4; }
        { GeoElement Line;     NumberOfPoints 4; }
      } } } }
}

FunctionSpace {
  { Name H_a; Type Form1P;     // perpendicular 1-form → axisymmetric A_φ
    BasisFunction {
      { Name se; NameOfCoef ae; Function BF_PerpendicularEdge;
        // Support must include the 1-D boundary regions so the Dirichlet
        // constraint can pin their nodes; otherwise the constrained DOFs
        // never enter the system and the boundary value is silently ignored.
        Support Region[ { Domain, FarBnd, Axis } ];
        Entity NodesOf[ All ]; }
    }
    Constraint {
      { NameOfCoef ae; EntityType NodesOf; NameOfConstraint a_BC; }
    }
  }
}

Formulation {
  { Name Magstat_a; Type FemEquation;
    Quantity {
      { Name a; Type Local; NameOfSpace H_a; }
    }
    Equation {
      // curl-curl stiffness:  ∫ ν (∇×A)·(∇×A')
      Integral { [ nu[] * Dof{d a}, {d a} ];
                 In Domain; Jacobian Vol; Integration I1; }
      // source coupling:  -∫ J·A'   (sign per GetDP A-φ convention)
      Integral { [ -js[], {a} ];
                 In Coil; Jacobian Vol; Integration I1; }
    }
  }
}

Resolution {
  { Name MagStat;
    System { { Name Sys_Mag; NameOfFormulation Magstat_a; } }
    Operation {
      InitSolution[ Sys_Mag ];
      Generate[ Sys_Mag ];
      Solve[ Sys_Mag ];
      SaveSolution[ Sys_Mag ];
      PostOperation[ MagStat ];
    }
  }
}

PostProcessing {
  { Name MagStat; NameOfFormulation Magstat_a;
    Quantity {
      { Name b;    Value { Local { [ {d a} ];        In Domain; Jacobian Vol; } } }
      { Name bmag; Value { Local { [ Norm[{d a}] ];  In Domain; Jacobian Vol; } } }
      { Name bz;   Value { Local { [ CompZ[{d a}] ]; In Domain; Jacobian Vol; } } }
      { Name az;   Value { Local { [ CompZ[{a}] ];   In Domain; Jacobian Vol; } } }
      // Stored magnetic energy  W = 0.5 ∫ ν |B|² dV   →   L = 2W / I²
      { Name Wmag;
        Value { Integral { [ 0.5 * nu[] * SquNorm[{d a}] ];
                In Domain; Jacobian Vol; Integration I1; } } }
    }
  }
}

PostOperation {
  { Name MagStat; NameOfPostProcessing MagStat;
    Operation {
      // |B| at the coil/axis center (r=0, z=0).
      Print[ bmag, OnPoint {0, 0, 0},
             File StrCat[OUT_DIR, "/bmag_center.txt"], Format Table ];
      // Signed Bz at the center.
      Print[ bz, OnPoint {0, 0, 0},
             File StrCat[OUT_DIR, "/bz_center.txt"], Format Table ];
      // |B| swept along the axis z ∈ [-Z_SWEEP, +Z_SWEEP], 200 samples.
      Print[ bmag, OnLine { {0, -Z_SWEEP, 0} {0, Z_SWEEP, 0} } {200},
             File StrCat[OUT_DIR, "/bmag_axis.txt"], Format Table ];
      // Total stored energy (→ inductance L = 2W/I²).
      Print[ Wmag[Domain], OnGlobal,
             File StrCat[OUT_DIR, "/stored_energy.txt"], Format Table ];
    }
  }
}
