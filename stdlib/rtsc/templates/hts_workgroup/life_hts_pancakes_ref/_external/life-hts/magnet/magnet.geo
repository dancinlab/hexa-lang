SetFactory("OpenCASCADE");
// Include cross data
Include "magnet_data.pro";

// Air
Sphere(1000) = {0, 0, 0, air_r, -Pi/2, Pi/2, Pi/4};

// HTS bulk
Cylinder(2000) = {bulk_r + air_space/2, bulk_r + air_space/2, -bulk_h/2, 0, 0, bulk_h, bulk_r};
volBulk = BooleanIntersection{ Volume{1000}; }{ Volume{2000}; Delete;};

// Coil
Block(3000) = {2*bulk_r+air_space/2+space, 0, bulk_h/2-coil_h, coil_t_tot, bulk_r + air_space/2, coil_h};
Cylinder(4000) = {bulk_r + air_space/2, bulk_r + air_space/2, bulk_h/2-coil_h, 0, 0, coil_h, bulk_r+space+coil_t_tot, Pi/4};
Cylinder(5000) = {bulk_r + air_space/2, bulk_r + air_space/2, bulk_h/2-coil_h, 0, 0, coil_h, bulk_r+space, Pi/4};
volCoilCyl = BooleanDifference{ Volume{4000}; Delete;}{ Volume{5000}; Delete;};
volCoil = BooleanUnion{ Volume{volCoilCyl}; Delete;}{ Volume{3000}; Delete;};

// Iron
Block(6000) = {0, 0, -bulk_h/2-bulk_h-space_i, 2*bulk_r + air_space, bulk_r + air_space/2, bulk_h};
Cylinder(7000) = {bulk_r + air_space/2, bulk_r + air_space/2, -bulk_h/2-bulk_h-space_i, 0, 0, bulk_h, bulk_r+air_space/2, Pi/4};
volIronRec = BooleanIntersection{ Volume{1000}; }{ Volume{6000}; Delete;};
volIron = BooleanUnion{ Volume{7000}; Delete;}{ Volume{volIronRec}; Delete;};

// Cuts for coil (h or coupled formulation)
cutChoice = 0; // Keep this! (other one not stable)
If(cutChoice == 1)
    zcut1 = bulk_h/2;
    Rectangle(8000) = {0,0,zcut1, 2*bulk_r+air_space/2+space+coil_t_tot/2, 2*bulk_r+air_space/4+space+coil_t_tot/4};
    cutTmp = BooleanIntersection{ Surface{8000}; Delete;}{ Volume{1000};};
    bndCoil = Abs(Boundary{Volume{volCoil};});
    bndBulk = Abs(Boundary{Volume{volBulk};});
    cut = BooleanDifference{ Surface{cutTmp}; Delete;}{Surface{bndCoil()}; Surface{bndBulk()}; Delete;};
    zcut2 = -bulk_h/3;
Else
    zcut2 = 0;
    Rectangle(10000) = {2*bulk_r+air_space/2+1.1*space,-1e-4,zcut2, air_r, air_r};
    cutTmp = BooleanIntersection{ Surface{10000}; Delete;}{ Volume{1000};};
    cut = BooleanDifference{ Surface{cutTmp}; Delete;}{Volume{volCoil};};
EndIf
Rectangle(9000) = {0,0,zcut2, 2*bulk_r+air_space/2+space+coil_t_tot/2, 2*bulk_r+air_space/4+space+coil_t_tot/4};
cut2Tmp = BooleanIntersection{ Surface{9000}; Delete;}{ Volume{1000};};
cut2 = BooleanDifference{ Surface{cut2Tmp}; Delete;}{Volume{volCoil}; Volume{volBulk};};



// Remove volumes from air
volAirTmp = BooleanDifference{ Volume{1000}; Delete;}{ Volume{volBulk}; Volume{volCoil}; Volume{volIron}; };

// Cut domains with fragments
volumes = BooleanFragments{ Volume{volAirTmp}; Delete;}{Volume{volCoil}; Volume{volBulk}; Volume{volIron}; Surface{cut}; Surface{cut2}; Delete;};

// Recover volumes (only one choice is OK)
If(cutChoice == 1)
    all_vol() = Volume In BoundingBox {-1e-5, -1e-5, -air_r-1e-5, air_r+1e-4, air_r+1e-4, 2*air_r+1e-4};
    all_wo_extAir() = Volume In BoundingBox {-1e-5, -1e-5, -bulk_h/2-bulk_h-space_i-1e-5, 2*bulk_r+air_space/2+space+coil_t_tot+1e-4, 2*bulk_r+air_space/2+space+coil_t_tot+1e-4, 3*bulk_h };
    all_vol() -= all_wo_extAir();
    vol_air1 = all_vol();

    iron_bulk_inAir() = Volume In BoundingBox {-1e-5, -1e-5, -bulk_h/2-bulk_h-space_i-1e-5, 2*bulk_r+air_space/2+space+1e-4, 2*bulk_r+air_space/2+space+1e-4, 3*bulk_h };
    all_wo_extAir() -= iron_bulk_inAir();
    vol_coil = all_wo_extAir();

    bulk_inAir() = Volume In BoundingBox {-1e-5, -1e-5, -bulk_h/2-space_i-1e-5, 2*bulk_r+air_space/2+space+1e-4, 2*bulk_r+air_space/2+space+1e-4, 2*bulk_h };
    iron_bulk_inAir() -= bulk_inAir();
    vol_iron = iron_bulk_inAir();

    vol_bulk = Volume In BoundingBox {-1e-5, -1e-5, -bulk_h/2-space_i-1e-5, 2*bulk_r+air_space/2+1e-4, 2*bulk_r+air_space/2+1e-4, 2*bulk_h };
    bulk_inAir() -= volBulk;
    vol_air2 = bulk_inAir();
Else
    all_vol() = Volume In BoundingBox {-1e-5, -1e-5, -air_r-1e-5, air_r+1e-4, air_r+1e-4, air_r+1e-4};
    vol_air1 = Volume In BoundingBox {-1e-5, -1e-5, -1e-5, air_r+1e-4, air_r+1e-4, air_r+1e-4};
    all_mat() = Volume In BoundingBox {-1e-5, -1e-5, -bulk_h/2-bulk_h-space_i-1e-5, 2*bulk_r+air_space/2+space+coil_t_tot+1e-4, 2*bulk_r+air_space/2+space+coil_t_tot+1e-4, 3*bulk_h };
    all_vol() -= all_mat();
    vol_air2 = all_vol();

    iron_bulk() = Volume In BoundingBox {-1e-5, -1e-5, -bulk_h/2-bulk_h-space_i-1e-5, 2*bulk_r+air_space/2+space+1e-4, 2*bulk_r+air_space/2+space+1e-4, 3*bulk_h };
    all_mat() -= iron_bulk();
    vol_coil = all_mat();

    bulk() = Volume In BoundingBox {-1e-5, -1e-5, -bulk_h/2-space_i-1e-5, 2*bulk_r+air_space/2+space+1e-4, 2*bulk_r+air_space/2+space+1e-4, 2*bulk_h };
    iron_bulk() -= bulk();
    vol_iron = iron_bulk();

    vol_bulk = Volume In BoundingBox {-1e-5, -1e-5, -bulk_h/2-space_i-1e-5, 2*bulk_r+air_space/2+1e-4, 2*bulk_r+air_space/2+1e-4, 2*bulk_h };
    iron_air2() = Volume In BoundingBox {-1e-5, -1e-5, -air_r-1e-5, air_r+1e-4, air_r+1e-4, 1e-4};
    iron_air2() -= vol_iron();
    vol_air2 = iron_air2();

EndIf

// Recover surfaces
bndBulk = Abs(Boundary{Volume{vol_bulk};});
bndBulkSym = Surface In BoundingBox {1e-5, 1e-5, -bulk_h/2-1e-5, 2*bulk_r+1e-4, 2*bulk_r+1e-4, 1.1*bulk_h };
bndBulk() -= bndBulkSym();

bndCoil = Abs(Boundary{Volume{vol_coil};});
bndCoilSym1 = Surface In BoundingBox {2*bulk_r+air_space/2, -1e-3, bulk_h/2-coil_h-space, 2*bulk_r+air_space/2+coil_t_tot*1.3, 1e-3, bulk_h/2-coil_h-space+coil_h*1.3 };
bndCoilSym2 = Surface In BoundingBox {0.029, 0.029, -0.023, 0.047, 0.047, 0.0089}; // BE CAREFUL HERE
bndCoil() -= bndCoilSym1(); bndCoil() -= bndCoilSym2();

bndIron = Abs(Boundary{Volume{vol_iron};});
bndIronSym1 = Surface In BoundingBox {-1e-4, -1e-4, -bulk_h/2-iron_h-space-1e-3, 2*bulk_r + air_space+1e-3, 1e-3, 0};
bndIronSym2 = Surface In BoundingBox {-1e-4, -1e-4, -bulk_h/2-iron_h-space-1e-3, 0.03, 0.03, 0}; // BE CAREFUL HERE
bndIron() -= bndIronSym1(); bndIron() -= bndIronSym2();

bndGamma = Abs(CombinedBoundary{Volume{vol_bulk}; Volume{vol_air1}; Volume{vol_air2}; Volume{vol_coil}; Volume{vol_iron};});
bndGammaSym1 = Surface In BoundingBox {-1e-4, -1e-4, -air_r-1e-4, air_r+1e-4, 1e-4, air_r+1e-4};
bndGammaSym2 = Surface In BoundingBox {-1e-4, -1e-4, -air_r-1e-4, air_r-1e-4, air_r+1e-4, air_r+1e-4};
bndAll() = bndGamma();
bndGamma() -= bndGammaSym1(); bndGamma() -= bndGammaSym2();
bndAll() -= bndGamma();
// One point for fixing the constant phi
lowestPoint = Point In BoundingBox {-1e-5, -1e-5, -air_r-1e-5, 1e-5, 1e-5, -air_r+1e-5};

// Mesh size
pall() = Point In BoundingBox {-1e-5, -1e-5, -air_r-1e-5, air_r+1e-4, air_r+1e-4, 2*air_r+1e-4};
Characteristic Length{pall()} = 50*1e-3*meshMult;
pcenter() = Point In BoundingBox {-1e-5, -1e-5, -bulk_h/2-bulk_h-space_i-1e-5, 2*bulk_r+air_space/2+space+coil_t_tot+1e-4, 2*bulk_r+air_space/2+space+coil_t_tot+1e-4, 3*bulk_h };
Characteristic Length{pcenter()} = 5e-3*meshMult;
Characteristic Length{PointsOf{ Volume{vol_bulk}; }} = 2e-3*meshMult;
Characteristic Length{PointsOf{ Volume{vol_iron}; }} = 3.5e-3*meshMult;

// Physical volumes
Physical Volume("Air", AIR) = {vol_air1, vol_air2};
Physical Volume("Coil", COIL) = {vol_coil};
Physical Volume("Iron", IRON) = {vol_iron};
Physical Volume("Bulk", BULK) = {vol_bulk};

Physical Surface("Cut", CUT) = {cut}; // Not used if cohomology
//Physical Surface("One side of cut", ONE_SIDE_OF_CUT) = {10021, 10024}; // Not used if cohomology
one_side_of_cut() = Surface In BoundingBox {2*bulk_r+air_space/2+space+1e-5, -1e-5, -1e-5, 2*bulk_r+air_space/2+space+coil_t_tot+1e-5, 1e-1, bulk_h+1e-5};
Physical Surface("One side of cut", ONE_SIDE_OF_CUT) = {one_side_of_cut()}; //{10004, 10010}; // Not used if cohomology
//Physical Surface("One side of cut", ONE_SIDE_OF_CUT) = {9019, 9020}; // Not used if cohomology


Physical Point("Arbitrary point", ARBITRARY_POINT) = {lowestPoint()};
Physical Surface("Bnd bulk in domain", BND_BULK_IN) = {bndBulk()};
Physical Surface("Bnd bulk symmetry", BND_BULK_SYM) = {bndBulkSym()};
Physical Surface("Bnd coil in domain", BND_COIL_IN) = {bndCoil()};
Physical Surface("Bnd coil symmetry", BND_COIL_SYM) = {bndCoilSym1(), bndCoilSym2()};
Physical Surface("Bnd iron in domain", BND_IRON_IN) = {bndIron()};
Physical Surface("Bnd iron symmetry", BND_IRON_SYM) = {bndIronSym1(), bndIronSym2()};
Physical Surface("Bnd symmetry", SURF_SYM) = {bndAll()};
Physical Surface("Bnd exterior", SURF_OUT) = {bndGamma()};

// Not used if manual cut
/*
If(preset == 1)
    Cohomology(1) {{AIR, IRON}, {}}; // Cut for source magnetic field (h-formulation) in Omega_h_OmegaCC
ElseIf(preset == 4)
    Cohomology(1) {{AIR}, {}}; // Cut for source magnetic field (h-a-formulation, only iron in a) in Omega_h_Omeg
EndIf
*/
/* this is OCC version dependent
Show "*";
Hide {
Point{32,33,36,43,53};
Curve{52,53,54,57,60,63,64,65,66,73,87,88,89,90,91};
Surface{9000,10000,10001,10002,10003,10013,10014,10015};
Volume{2003,2004};
}
*/
//+
Show "*";
//+
//Hide {
//  Point{30}; Point{31}; Curve{51}; Curve{54}; Curve{75}; Curve{97}; Curve{55}; Point{34}; Point{41}; Point{51}; Curve{45}; Curve{46}; Curve{47}; Curve{50}; Curve{53}; Curve{56}; Curve{57}; Curve{58}; Curve{59}; Curve{66}; Curve{79}; Curve{80}; Curve{81}; Curve{82}; Curve{83}; Surface{9000}; Surface{10000}; Surface{10001}; Surface{10002}; Surface{10003}; Surface{10012}; Surface{10013}; Surface{10014}; Volume{2003}; Volume{2004};
//}
