Include "filaments_data.pro";

For i In {1:NumLayers}
  DefineConstant[
    LayerRadius~{i} = {
      (Preset == 3 && i == 1) ? 0.13 :
      (Preset == 3 && i == 2) ? 0.25 :
      (Preset == 3 && i == 3) ? 0.39 :
      (Preset == 5) ? 0.1 :
      (Preset == 2) ? 2.8*FilamentRadius :
      (Preset == 1 || Preset == 4) ? 0 :
      i * MatrixRadius / (NumLayers + 1),
      Min FilamentRadius, Max MatrixRadius, Step 1e-2, ReadOnly Preset,
      Name Sprintf["Input/1Geometry/{Layer %g/Radius [mm]", i]},
    StartAngleFilament~{i} = { (Preset == 5) ? Pi/2 : 0,
      Min 0, Max 2*Pi, Step 2*Pi/100, ReadOnly Preset,
      Name Sprintf["Input/1Geometry/{Layer %g/Starting angle [rad]", i]}
  ];
EndFor

phys_fil = {};
phys_fil_top = {};
phys_fil_bot = {};

Geometry.ExtrudeSplinePoints = 20;
Geometry.Points = 0;
sf[] = {}; // surfaces of all filaments
llf_0[] = {}; // line loops of bottom filament intersects
llf_1[] = {}; // line loops of top filament intersects
For i In {1:NumLayers}
  For j In {1:NumFilaments~{i}}
    theta = j * 2*Pi / NumFilaments~{i} + StartAngleFilament~{i};
    xr = LayerRadius~{i} * mm * Cos[theta];
    yr = LayerRadius~{i} * mm * Sin[theta];
    If(!FilamentShape)
      p0 = newp; Point(p0) = {xr, yr, 0, LcFilament*mm};
      p1 = newp; Point(p1) = {xr+FilamentRadius*mm, yr, 0, LcFilament*mm};
      p2 = newp; Point(p2) = {xr, yr+FilamentRadius*mm, 0, LcFilament*mm};
      p3 = newp; Point(p3) = {xr-FilamentRadius*mm, yr, 0, LcFilament*mm};
      p4 = newp; Point(p4) = {xr, yr-FilamentRadius*mm, 0, LcFilament*mm};
      l1 = newl; Circle(l1) = {p1, p0, p2};
      l2 = newl; Circle(l2) = {p2, p0, p3};
      l3 = newl; Circle(l3) = {p3, p0, p4};
      l4 = newl; Circle(l4) = {p4, p0, p1};
    Else
      p1 = newp; Point(p1) = {xr-FilamentWidth/2*mm, yr-FilamentThickness/2*mm, 0, LcFilament*mm};
      p2 = newp; Point(p2) = {xr+FilamentWidth/2*mm, yr-FilamentThickness/2*mm, 0, LcFilament*mm};
      p3 = newp; Point(p3) = {xr+FilamentWidth/2*mm, yr+FilamentThickness/2*mm, 0, LcFilament*mm};
      p4 = newp; Point(p4) = {xr-FilamentWidth/2*mm, yr+FilamentThickness/2*mm, 0, LcFilament*mm};
      l1 = newl; Line(l1) = {p1, p2};
      l2 = newl; Line(l2) = {p2, p3};
      l3 = newl; Line(l3) = {p3, p4};
      l4 = newl; Line(l4) = {p4, p1};
    EndIf
    ll1 = newll; Line Loop(ll1) = {l1, l2, l3, l4};
    s1 = news; Plane Surface(s1) = {ll1};
    If(FilamentShape && FilamentMeshTransfinite)
      nw = (FilamentWidth / LcFilament) + 1;
      nt = ((FilamentThickness / LcFilament) + 1) * FilamentMeshTransfiniteAniso;
      Transfinite Line{l1, l3} = nw Using Bump 0.5;
      Transfinite Line{l2, l4} = nt;
      Transfinite Surface{s1};
      If(!ThreeD)
        Recombine Surface{s1};
      EndIf
    EndIf
    llf_0[] += ll1;
    If(ThreeD && TwistFraction)
      Physical Surface(Sprintf("Filament bottom boundary (%g in layer %g)", j, i),
        BND_FILAMENT + 1000 * i + j) = {s1}; // bottom
      phys_fil_bot += BND_FILAMENT + 1000 * i + j;
      splits = (4 * TwistFraction) < 1 ? 1 : 4 * TwistFraction; // heuristics
      v[] = {};
      s[] = {};
      tmp[] = {s1};
      For k In {1:splits}
        h = TwistPitch*mm / splits * TwistFraction;
        N = h / (LcFilament*mm) / FilamentMeshAniso;
        tmp[] = Extrude {{0,0,h}, {0,0,1}, {0,0,0}, 2*Pi / splits * TwistFraction} {
          Surface{ tmp[0] }; Layers{N};
        };
        v[] += tmp[1];
        s[] += tmp[{2:5}];
      EndFor
      Physical Surface(Sprintf("Filament top boundary (%g in layer %g)", j, i),
        BND_FILAMENT + 1100 * i + j) = tmp[0]; // top
      phys_fil_top += BND_FILAMENT + 1100 * i + j;
      Physical Surface(Sprintf("Filament lateral boundary (%g in layer %g)", j, i),
        BND_FILAMENT + 1200 * i + j) = s[]; // sides
      Physical Volume(Sprintf("Filament volume (%g in layer %g)", j, i),
        FILAMENT + 1000 * i + j) = v[];
      phys_fil += FILAMENT + 1000 * i + j;
      sf[] += s[];
      ll2 = newll; Line Loop(ll2) = Boundary{ Surface{tmp[0]}; };
      llf_1[] += ll2;
    Else
      Physical Line(Sprintf("Filament lateral boundary (%g in layer %g)", j, i),
        BND_FILAMENT + 1200 * i + j) = {l1, l2, l3, l4};
      Physical Surface(Sprintf("Filament volume (%g in layer %g)", j, i),
        FILAMENT + 1000 * i + j) = s1;
    EndIf
  EndFor
EndFor

For i In {0 : (ThreeD && TwistFraction) ? 0 : 0}
  z = i*TwistPitch*mm * TwistFraction;
  phi = 0*i*2*Pi*TwistFraction;
  p0~{i} = newp; Point(p0~{i}) = {0, 0, z, LcMatrix*mm};
  p1~{i} = newp; Point(p1~{i}) = {MatrixRadius*mm*Cos[phi], MatrixRadius*mm*Sin[phi], z, LcMatrix*mm};
  p2~{i} = newp; Point(p2~{i}) = {MatrixRadius*mm*Cos[phi+Pi/2], MatrixRadius*mm*Sin[phi+Pi/2], z, LcMatrix*mm};
  p3~{i} = newp; Point(p3~{i}) = {MatrixRadius*mm*Cos[phi+Pi], MatrixRadius*mm*Sin[phi+Pi], z, LcMatrix*mm};
  p4~{i} = newp; Point(p4~{i}) = {MatrixRadius*mm*Cos[phi+3*Pi/2], MatrixRadius*mm*Sin[phi+3*Pi/2], z, LcMatrix*mm};
  l1~{i} = newl; Circle(l1~{i}) = {p1~{i}, p0~{i}, p2~{i}};
  l2~{i} = newl; Circle(l2~{i}) = {p2~{i}, p0~{i}, p3~{i}};
  l3~{i} = newl; Circle(l3~{i}) = {p3~{i}, p0~{i}, p4~{i}};
  l4~{i} = newl; Circle(l4~{i}) = {p4~{i}, p0~{i}, p1~{i}};
  ll1~{i} = newll; Line Loop(ll1~{i}) = {l1~{i}, l2~{i}, l3~{i}, l4~{i}};
  s1~{i} = news; Plane Surface(s1~{i}) = {ll1~{i}, llf~{i}[]};

  p11~{i} = newp; Point(p11~{i}) = {AirRadius*mm, 0, z, LcAir*mm};
  p12~{i} = newp; Point(p12~{i}) = {0, AirRadius*mm, z, LcAir*mm};
  p13~{i} = newp; Point(p13~{i}) = {-AirRadius*mm, 0, z, LcAir*mm};
  p14~{i} = newp; Point(p14~{i}) = {0, -AirRadius*mm, z, LcAir*mm};
  l11~{i} = newl; Circle(l11~{i}) = {p11~{i}, p0~{i}, p12~{i}};
  l12~{i} = newl; Circle(l12~{i}) = {p12~{i}, p0~{i}, p13~{i}};
  l13~{i} = newl; Circle(l13~{i}) = {p13~{i}, p0~{i}, p14~{i}};
  l14~{i} = newl; Circle(l14~{i}) = {p14~{i}, p0~{i}, p11~{i}};
  ll11~{i} = newll; Line Loop(ll11~{i}) = {l11~{i}, l12~{i}, l13~{i}, l14~{i}};
  s11~{i} = news; Plane Surface(s11~{i}) = {ll11~{i}, ll1~{i}};

  p111~{i} = newp; Point(p111~{i}) = {InfRadius*mm, 0, z, LcAir*mm};
  p112~{i} = newp; Point(p112~{i}) = {0, InfRadius*mm, z, LcAir*mm};
  p113~{i} = newp; Point(p113~{i}) = {-InfRadius*mm, 0, z, LcAir*mm};
  p114~{i} = newp; Point(p114~{i}) = {0, -InfRadius*mm, z, LcAir*mm};
  l111~{i} = newl; Circle(l111~{i}) = {p111~{i}, p0~{i}, p112~{i}};
  l112~{i} = newl; Circle(l112~{i}) = {p112~{i}, p0~{i}, p113~{i}};
  l113~{i} = newl; Circle(l113~{i}) = {p113~{i}, p0~{i}, p114~{i}};
  l114~{i} = newl; Circle(l114~{i}) = {p114~{i}, p0~{i}, p111~{i}};
  ll111~{i} = newll; Line Loop(ll111~{i}) = {l111~{i}, l112~{i}, l113~{i}, l114~{i}};
  s111~{i} = news; Plane Surface(s111~{i}) = {ll111~{i}, ll11~{i}};
EndFor



If(ThreeD && TwistFraction)
/*
  l1 = newl; Line(l1) = {p1_0, p1_1};
  l2 = newl; Line(l2) = {p2_0, p2_1};
  l3 = newl; Line(l3) = {p3_0, p3_1};
  l4 = newl; Line(l4) = {p4_0, p4_1};
  ll1 = newll; Line Loop(ll1) = {l1_0, l2, -l1_1, -l1};
  s1 = news; Ruled Surface(s1) = {ll1};
  ll2 = newll; Line Loop(ll2) = {l2_0, l3, -l2_1, -l2};
  s2 = news; Ruled Surface(s2) = {ll2};
  ll3 = newll; Line Loop(ll3) = {l3_0, l4, -l3_1, -l3};
  s3 = news; Ruled Surface(s3) = {ll3};
  ll4 = newll; Line Loop(ll4) = {l4_0, l1, -l4_1, -l4};
  s4 = news; Ruled Surface(s4) = {ll4};
  sl1 = newsl; Surface Loop(sl1) = {s1, s2, s3, s4, s1_0, s1_1, sf[]};
  v1 = newv; Volume(v1) = {sl1};
*/
  tmp[0] = s1_0;
  vi[] = {};
  si[] = {};
  nbLateralSurfaces = 4 + 6*4;
  For k In {1:splits}
    h = TwistPitch*mm / splits * TwistFraction;
    N = h / (LcFilament*mm) / FilamentMeshAniso;
    tmp[] = Extrude {{0,0,h}, {0,0,1}, {0,0,0}, 2*Pi / splits * TwistFraction} {
      Surface{ tmp[0] }; Layers{N};
    };
    vi[] += tmp[1];
    si[] += tmp[{2:1+4}];
  EndFor
  Physical Volume("Matrix", MATRIX) = vi[];
  Physical Surface("Matrix lateral boundary",  BND_MATRIX) = {si[]};
  Physical Surface("Matrix bottom boundary", BND_MATRIX + 1) = {s1_0};
  Physical Surface("Matrix top boundary", BND_MATRIX + 2) = {tmp[0]};
/*
  l11 = newl; Line(l11) = {p11_0, p11_1};
  l12 = newl; Line(l12) = {p12_0, p12_1};
  l13 = newl; Line(l13) = {p13_0, p13_1};
  l14 = newl; Line(l14) = {p14_0, p14_1};
  ll11 = newll; Line Loop(ll11) = {l11_0, l12, -l11_1, -l11};
  s11 = news; Ruled Surface(s11) = {ll11};
  ll12 = newll; Line Loop(ll12) = {l12_0, l13, -l12_1, -l12};
  s12 = news; Ruled Surface(s12) = {ll12};
  ll13 = newll; Line Loop(ll13) = {l13_0, l14, -l13_1, -l13};
  s13 = news; Ruled Surface(s13) = {ll13};
  ll14 = newll; Line Loop(ll14) = {l14_0, l11, -l14_1, -l14};
  s14 = news; Ruled Surface(s14) = {ll14};
  sl11 = newsl; Surface Loop(sl11) = {s11, s12, s13, s14, s11_0, s11_1, s1, s2, s3, s4};
  v11 = newv; Volume(v11) = {sl11};
  */
  tmp[0] = s11_0;
  v11[] = {};
  s11[] = {};
  For k In {1:splits}
    h = TwistPitch*mm / splits * TwistFraction;
    N = h / (LcFilament*mm) / FilamentMeshAniso;
    tmp[] = Extrude {{0,0,h}, {0,0,1}, {0,0,0}, 2*Pi / splits * TwistFraction} {
      Surface{ tmp[0] }; Layers{N};
    };
    v11[] += tmp[1];
    s11[] += tmp[{2:1+4}];
  EndFor
  Physical Volume("Air", AIR) = v11[];
  Physical Surface("Air lateral boundary", BND_AIR) = {s11[]};
  Physical Surface("Air bottom boundary", BND_AIR + 1) = {s11_0};
  Physical Surface("Air top boundary", BND_AIR + 2) = {tmp[0]};
  /*
  l111 = newl; Line(l111) = {p111_0, p111_1};
  l112 = newl; Line(l112) = {p112_0, p112_1};
  l113 = newl; Line(l113) = {p113_0, p113_1};
  l114 = newl; Line(l114) = {p114_0, p114_1};
  ll111 = newll; Line Loop(ll111) = {l111_0, l112, -l111_1, -l111};
  s111 = news; Ruled Surface(s111) = {ll111};
  ll112 = newll; Line Loop(ll112) = {l112_0, l113, -l112_1, -l112};
  s112 = news; Ruled Surface(s112) = {ll112};
  ll113 = newll; Line Loop(ll113) = {l113_0, l114, -l113_1, -l113};
  s113 = news; Ruled Surface(s113) = {ll113};
  ll114 = newll; Line Loop(ll114) = {l114_0, l111, -l114_1, -l114};
  s114 = news; Ruled Surface(s114) = {ll114};
  sl111 = newsl; Surface Loop(sl111) = {s111, s112, s113, s114, s111_0, s111_1, s11, s12, s13, s14};
  v111 = newv; Volume(v111) = {sl111};
  */
  tmp[0] = s111_0;
  v111[] = {};
  s111[] = {};
  For k In {1:splits}
    h = TwistPitch*mm / splits * TwistFraction;
    N = h / (LcFilament*mm) / FilamentMeshAniso;
    tmp[] = Extrude {{0,0,h}, {0,0,1}, {0,0,0}, 2*Pi / splits * TwistFraction} {
      Surface{ tmp[0] }; Layers{N};
    };
    v111[] += tmp[1];
    s111[] += tmp[{2:1+4}];
  EndFor
  Physical Point("Arbitrary Point", ARBITRARY_POINT) = p111_0[];
  Physical Volume("Infinity", INF) = v111[];
  Physical Surface("Infinity lateral boundary", BND_INF) = {s111[]};
  Physical Surface("Infinity bottom boundary", BND_INF + 1) = {s111_0};
  Physical Surface("Infinity top boundary", BND_INF + 2) = {tmp[0]};
Else
  Physical Surface("Matrix", MATRIX) = s1_0;
  Physical Line("Matrix lateral boundary",  BND_MATRIX) = {l1_0, l2_0, l3_0, l4_0};
  Physical Surface("Air", AIR) = s11_0;
  Physical Line("Air lateral boundary", BND_AIR) = {l11_0, l12_0, l13_0, l14_0};
  Physical Point("Arbitrary Point", ARBITRARY_POINT) = p111_0[];
  Physical Surface("Infinity", INF) = s111_0;
  Physical Line("Infinity lateral boundary", BND_INF) = {l111_0, l112_0, l113_0, l114_0};
EndIf


// Cohomology computation for the H-Phi formulation
If(ConductingMatrix)
  Cohomology(1) {{AIR,INF}, {}};
Else
  Cohomology(1) {{AIR,INF,MATRIX}, {}};
EndIf

General.ExpertMode = 1; // Don't complain for hybrid structured/unstructured mesh
Mesh.Algorithm = 6; // Use Frontal 2D algorithm
Mesh.Optimize = 1; // Optimize 3D tet mesh
