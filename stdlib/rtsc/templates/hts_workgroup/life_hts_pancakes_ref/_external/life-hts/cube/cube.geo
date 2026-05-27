SetFactory("OpenCASCADE");

Include "cube_data.pro";

DefineConstant [ LcCube = meshMult*0.0003 ]; // Mesh size in cylinder [m]
DefineConstant [ LcAir = meshMult*0.005 ]; // Mesh size in cylinder [m]

Box(1) = {0, 0, 0, a/2, a/2, a/2};
Sphere(2) = {0, 0, 0, R_inf, 0, Pi/2, Pi/2};
BooleanFragments{ Volume{1}; Delete; }{ Volume{2}; Delete; }

Characteristic Length{ PointsOf{ Volume{2}; } } = LcAir;
Characteristic Length{ PointsOf{ Volume{1}; } } = LcCube;

f_c() = Abs(Boundary{ Volume{1}; });
f_s() = Abs(Boundary{ Volume{2}; });

Transfinite Surface {f_c()};
Recombine Surface {f_c()};
Transfinite Volume {1};

Physical Volume("Material", MATERIAL) = {1};
Physical Volume("Air", AIR) = {2};
Physical Surface("Boundary material", BND_MATERIAL) = {f_c(1), f_c(3), f_c(5)};
Physical Surface("Boundary air", SURF_OUT) = {f_s(0)};
Physical Surface("Symmetry h x n = 0", SURF_SYM_ht0) = {f_s(2)};
Physical Surface("Symmetry b . n = 0", SURF_SYM_bn0) = {f_s(1), f_s(3)};
Physical Surface("Symmetry h x n = 0, material", SURF_SYM_MAT_ht0) = {f_c(4)};
Physical Surface("Symmetry b . n = 0, material", SURF_SYM_MAT_bn0) = {f_c(2), f_c(0)};
