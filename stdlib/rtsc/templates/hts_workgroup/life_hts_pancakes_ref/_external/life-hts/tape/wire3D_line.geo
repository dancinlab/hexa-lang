SetFactory("OpenCASCADE");
// Include cross data
Include "wire3D_data.pro";
Mesh.Algorithm = 6;
Geometry.CopyMeshingMethod = 1;

line = 1;

// Geometrical and meshing parameters
DefineConstant [LcWire = meshMult*0.0003]; // Mesh size in cylinder [m]
DefineConstant [LcAir = meshMult*0.002]; // Mesh size in cylinder [m]
sphere[] += newv; Sphere(newv) = {0, 0, 0, R_box, -Pi/2, Pi/2, Pi/2};

f_s() = Boundary{Volume{sphere[0]};};
l_s() = Boundary{Surface{f_s()};};
p_s() = PointsOf{Line{l_s()};};
Characteristic Length{p_s()} = LcAir;

pntR0 = newp; Point(newp) = {0,0,0,LcAir};
pntR1[] += newp; Point(newp) = {R_wire-r_wire,0,0,LcWire};
pntR2[] += newp; Point(newp) = {R_wire+r_wire,0,0,LcWire};
pntR2[] += newp; Point(newp) = {0,R_wire+r_wire,0,LcWire};
pntR1[] += newp; Point(newp) = {0,R_wire-r_wire,0,LcWire};

cirR1 = newl; Circle(newl) = {pntR1[1], pntR0, pntR1[0]};
cirR2 = newl; Circle(newl) = {pntR2[0], pntR0, pntR2[1]};
linA0 = newl; Line(newl) = {pntR1[0], pntR2[0]};
linA1 = newl; Line(newl) = {pntR2[1], pntR1[1]};
lwire = newll; Line Loop(newll) = {cirR1, linA0, cirR2, linA1};
swire[] += news; Plane Surface(news) = {lwire};

If(line == 0)
    linCutA0 = newl; Line(newl) = {pntR1[1], pntR0};
    linCutA1 = newl; Line(newl) = {pntR0, pntR1[0]};
    lcut = newll; Line Loop(newll) = {linCutA1, linCutA0, -cirR1};
    scut[] += news; Plane Surface(news) = {lcut};

    //Recombine Surface(swire[0]);

    tmp[] = Extrude {0,0,-w_wire}{Surface{swire[0]}; Layers{1}; Recombine;};
    vwire = tmp[1];
    swire[] += tmp[0];
    swire[] += tmp[{2:5}];
    //vair = BooleanUnion{ Volume{sphere}; Delete;}{ Volume{sphere[1]}; Delete;};
    vair = BooleanDifference{ Volume{sphere}; Delete;}{ Volume{vwire};};
    vair = BooleanFragments{ Volume{sphere}; Delete;}{ Surface{scut};};

    f_s() = Boundary{Volume{vair};};
    l_s() = Boundary{Surface{f_s()};};
    p_s() = PointsOf{Line{l_s()};};

    Physical Volume("Wire", WIRE) = {vwire};
    Physical Volume("Air", AIR) = {vair};
    Physical Surface("Surface out", SURF_OUT) = {f_s(0)};
    Physical Surface("Surface symmetry", SURF_SYM) = {f_s(1), f_s(2)};
    Physical Surface("Positive electrode", SURF_SYM_MAT1) = {tmp[3]};
    Physical Surface("Negative electrode", SURF_SYM_MAT2) = {tmp[5]};
    Physical Curve("Positive lateral edge", EDGE_1) = {tmp[2]};
    Physical Curve("Negative lateral edge", EDGE_2) = {tmp[4]}; // Or inverted with above?
    Physical Surface("Cut", CUT) = {scut[0]};
    Physical Surface("Material boundary", BND_WIRE) = {swire[0], tmp[0], tmp[2], tmp[4] };
    Physical Surface("Material boundary side", BND_WIRE_SIDE) = {swire[0]};//{tmp[2]};
    Physical Point("Arbitrary point", ARBITRARY_POINT) = {pntR0};

    // For quadrangles in tape (pyramids cannot be meshed on both sides for now)
    /*Physical Surface("Wire", WIRE) = {swire[0]};
    Physical Volume("Air", AIR) = {vair, vwire};
    Physical Surface("Surface out", SURF_OUT) = {f_s(0)};
    Physical Surface("Surface symmetry", SURF_SYM) = {f_s(1), f_s(2), tmp[3], tmp[5]};
    Physical Curve("Positive electrode", SURF_SYM_MAT1) = {linA0};
    Physical Curve("Negative electrode", SURF_SYM_MAT2) = {linA1};
    Physical Curve("Positive lateral edge", EDGE_1) = {cirR1};
    Physical Curve("Negative lateral edge", EDGE_2) = {cirR2};
    Physical Surface("Cut", CUT) = {scut[0]};
    Physical Surface("Material boundary", BND_WIRE) = {swire[0] };
    Physical Surface("Material boundary side", BND_WIRE_SIDE) = {cirR1};//{tmp[2]};
    Physical Point("Arbitrary point", ARBITRARY_POINT) = {pntR0};*/
Else
    vair = BooleanFragments{ Volume{sphere}; Delete;}{ Surface{swire[0]}; Delete;};
    f_s() = Boundary{Volume{vair};};
    l_s() = Boundary{Surface{f_s()};};
    p_s() = PointsOf{Line{l_s()};};

    Physical Surface("Wire", WIRE) = {swire};
    Physical Volume("Air", AIR) = {sphere};
    Physical Surface("Surface out", SURF_OUT) = {f_s(0)};
    Physical Surface("Surface symmetry", SURF_SYM) = {f_s(1), f_s(2)};
    Physical Curve("Positive electrode", SURF_SYM_MAT1) = {linA0};
    Physical Curve("Negative electrode", SURF_SYM_MAT2) = {linA1};
    Physical Curve("Positive lateral edge", EDGE_1) = {cirR1};
    Physical Curve("Negative lateral edge", EDGE_2) = {cirR2};
    Physical Line("Cut", CUT) = {cirR1};
    Physical Surface("Material boundary", BND_WIRE) = {swire};
    Physical Surface("Material boundary side", BND_WIRE_SIDE) = {cirR1};
    Physical Point("Arbitrary point", ARBITRARY_POINT) = {pntR0};
EndIf
