// Include cross data
Include "cylinders_data.pro";

// Interactive settings
R = W/2; // Radius
// Mesh size
LcSupra = meshMult*0.0003; // Mesh size in superconductor [m]
LcFerro = meshMult*0.0003; // Mesh size in ferro [m]
LcLayer = meshMult*0.0003; // Mesh size close to the cylinders [m]
LcAir = meshMult*0.005; // Mesh size in air shell [m]
LcInf = meshMult*0.005; // Mesh size in external air shell [m]

minLc = LcSupra > LcFerro ? LcFerro : LcSupra;

// Distance from the symmetry axis
epsSym = 0; // Must be zero !

// Rectangles definition
Point(1) = {0+epsSym, -H_super/2, 0, LcSupra};
Point(2) = {R+epsSym, -H_super/2, 0, LcSupra};
Point(3) = {R+epsSym, H_super/2, 0, minLc};
Point(4) = {0+epsSym, H_super/2, 0, minLc};
Point(100) = {0+epsSym, 0, 0, LcSupra};
Point(30) = {R+epsSym, H_super/2 + H_ferro, 0, LcFerro};
Point(31) = {0+epsSym, H_super/2 + H_ferro, 0, LcFerro};

Line(1) = {1, 2};
Line(2) = {2, 3};
Line(3) = {3, 4};
Line(4) = {4, 100};
Line(5) = {100, 1};
Line(8765) = {4, 1};

Line(30) = {3, 30};
Line(31) = {30, 31};
Line(32) = {4, 31};

// Control layer definition
Point(50) = {0+epsSym, - H_super/2 - meshLayerWidth, 0, LcLayer};
Point(51) = {R+epsSym + meshLayerWidth, - H_super/2 - meshLayerWidth, 0, LcLayer};
Point(52) = {R+epsSym + meshLayerWidth, H_super/2 + H_ferro + meshLayerWidth, 0, LcLayer};
Point(53) = {0+epsSym, H_super/2 + H_ferro + meshLayerWidth, 0, LcLayer};

Line(50) = {1, 50};
Line(51) = {50, 51};
Line(52) = {51, 52};
Line(53) = {52, 53};
Line(54) = {31, 53};

// Shells definition
Point(5) = {0+epsSym, -R_air, 0, LcAir};
Point(6) = {0+epsSym, -R_inf, 0, LcInf};
Point(7) = {R_air+epsSym, 0, 0, LcAir};
Point(8) = {R_inf+epsSym, 0, 0, LcInf};
Point(9) = {0+epsSym, R_air, 0, LcAir};
Point(10) = {0+epsSym, R_inf, 0, LcInf};

Circle(6) = {5, 100, 7};
Circle(7) = {6, 100, 8};
Circle(8) = {7, 100, 9};
Circle(9) = {8, 100, 10};
Line(10) = {9, 10};
Line(11) = {53, 9};
Line(12) = {50, 5};
Line(13) = {5, 6};

// Physical entities
Line Loop(30) = {13, 7, 9, -10, -8, -6}; // Outer shell
Plane Surface(40) = {30};
Line Loop(31) = {12, 6, 8, -11, -53, -52, -51}; // Air
Plane Surface(41) = {31};
Line Loop(35) = {50, 51, 52, 53, -54, -31, -30, -2, -1}; // Air refined
Plane Surface(45) = {35};
Line Loop(32) = {1, 2, 3, 8765}; // Lower cylinder
Plane Surface(42) = {32};
Line Loop(33) = {-3, 30, 31, -32}; // Upper cylinder
Plane Surface(43) = {33};
//Transfinite Surface(42);
//Recombine Surface(42);
//Transfinite Surface(43);
//Recombine Surface(43);


Physical Surface("Air", AIR) = {41, 45};
Physical Surface("Spherical shell", AIR_OUT) = {40};
Physical Surface("Superconductor", SUPER) = {42};
Physical Surface("Ferromagnetic material", FERRO) = {43};
Physical Line("Exterior boundary", SURF_OUT) = {7, 9};
Physical Line("Symmetry line", SURF_SYM) = {10,11,54,32,50,12,13};
Physical Line("Conducting domain boundary", BND_OMEGA_C) = {1, 2, 3};
Physical Line("Shells common line", SURF_SHELL) = {6, 8};
Physical Line("Symmetry line -  super", SURF_SYM_MAT) = {8765};
//Physical Line("Symmetry line -  ferro and air", LINE_SYM_FERRO_AIR) = {10,11,54,32,50,12,13};
Physical Line("Cut", CUT1) = {32, 54, 11, 10};
Physical Line("Boundary Omega_C side", BND_OMEGA_C_SIDE) = {3};
Physical Point("Point for fixing potentials", ARBITRARY_POINT) = {4};



// Some colors
Color SkyBlue {Surface{41, 45, 40};} // Air + Air inf
Color SteelBlue {Surface{43};}
Color Purple {Surface{42};} // Cylinder

linair[]  = CombinedBoundary{Surface{40,41,45};};
lincyl1[]  = CombinedBoundary{Surface{42};};
lincyl2[]  = CombinedBoundary{Surface{43};};

Hide { Point{ Point '*' }; }
Hide { Line{ Line '*' }; }
Show { Line{ linair[] }; }
Show { Line{ lincyl1[] }; }
Show { Line{ lincyl2[] }; }


// End
