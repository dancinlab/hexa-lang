SetFactory("OpenCASCADE");
// Include cross data
Include "ringTape_data.pro";
Mesh.Algorithm = 6;
//Geometry.CopyMeshingMethod = 1;

line = 1;

// Geometrical and meshing parameters
DefineConstant [LcWire = meshMult*0.0003]; // Mesh size in cylinder [m]
DefineConstant [LcAir = meshMult*0.002]; // Mesh size in cylinder [m]
sphere() += newv; Sphere(newv) = {0, 0, 0, R_box};

f_s() = Boundary{Volume{sphere()};};
l_s() = Boundary{Surface{f_s()};};
p_s() = PointsOf{Line{l_s()};};
Characteristic Length{p_s()} = LcAir;

pt0 = newp; Point(newp) = {0,0,-h_wire/2,LcAir};
pt1 = newp; Point(newp) = {r_wire,0,-h_wire/2,LcWire};
pt2 = newp; Point(newp) = {0,r_wire,-h_wire/2,LcWire};
pt3 = newp; Point(newp) = {-r_wire,0,-h_wire/2,LcWire};
pt4 = newp; Point(newp) = {0,-r_wire,-h_wire/2,LcWire};

cir1 = newl; Circle(newl) = {pt1, pt0, pt2};
cir2 = newl; Circle(newl) = {pt2, pt0, pt3};
cir3 = newl; Circle(newl) = {pt3, pt0, pt4};
cir4 = newl; Circle(newl) = {pt4, pt0, pt1};


tmp1[] = Extrude {0, 0, h_wire}{Line{cir1,cir2,cir3,cir4}; Layers{2*Floor(meshMult)};};

edgeBottom() = Line In BoundingBox {-1e-5-r_wire, -1e-5-r_wire, -1e-5-h_wire/2, 1e-5+r_wire, 1e-5+r_wire, 1e-5-h_wire/2};
edgeTop() = Line In BoundingBox {-1e-5-r_wire, -1e-5-r_wire, -1e-5+h_wire/2, 1e-5+r_wire, 1e-5+r_wire, 1e-5+h_wire/2};

tape() = Surface In BoundingBox {-1e-5-r_wire, -1e-5-r_wire, -1e-5-h_wire/2, 1e-5+r_wire, 1e-5+r_wire, 1e-5+h_wire/2};

Surface{tape()} In Volume{sphere(0)};


Physical Volume("Air", AIR) = {sphere()};
Physical Surface("Surface out", SURF_OUT) = {f_s(0)};
Physical Surface("Wire", WIRE) = {tape()};
Physical Surface("Material boundary", BND_WIRE) = {tape()};
Physical Curve("Positive lateral edge", EDGE_1) = {edgeTop()};
Physical Curve("Negative lateral edge", EDGE_2) = {edgeBottom()};
//Physical Line("Cut", CUT) = {cirR1};
Physical Point("Arbitrary point", ARBITRARY_POINT) = {pt0};
