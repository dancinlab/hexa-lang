// Include cross data
Include "tape_data.pro";

// Interactive settings
R = W_tape/2; // Radius
// Mesh size
numElementsTape = Floor[0.5*400/meshMult];

DefineConstant [LcCyl = R/numElementsTape]; // Mesh size in cylinder [m]
DefineConstant [LcLayer = LcCyl*2]; // Mesh size in the region close to the cylinder [m]
DefineConstant [LcAir = meshMult*0.003]; // Mesh size in air shell [m]
DefineConstant [LcInf = meshMult*0.003]; // Mesh size in external air shell [m]

// Shells definition
Point(100) = {0, 0, 0, LcCyl};
Point(1) = {0, -R_air, 0, LcAir};
Point(2) = {0, -R_inf, 0, LcInf};
Point(3) = {R_air, 0, 0, LcAir};
Point(4) = {R_inf, 0, 0, LcInf};
Point(5) = {0, R_air, 0, LcAir};
Point(6) = {0, R_inf, 0, LcInf};
Point(7) = {-R_air, 0, 0, LcAir};
Point(8) = {-R_inf, 0, 0, LcInf};
Circle(1) = {1, 100, 3};
Circle(2) = {2, 100, 4};
Circle(3) = {3, 100, 5};
Circle(4) = {4, 100, 6};
Circle(5) = {5, 100, 7};
Circle(6) = {6, 100, 8};
Circle(7) = {7, 100, 1};
Circle(8) = {8, 100, 2};


// Tape definition
Point(11) = {0, -H_tape/2, 0, LcCyl};
Point(12) = {R, -H_tape/2, 0, LcCyl};
Point(13) = {R, H_tape/2, 0, LcCyl};
Point(14) = {0, H_tape/2, 0, LcCyl};
Point(15) = {-R, H_tape/2, 0, LcCyl};
Point(16) = {-R, -H_tape/2, 0, LcCyl};

Line(11) = {11, 12};
Line(12) = {12, 13};
Line(13) = {13, 14};
Line(14) = {14, 15};
Line(15) = {15, 16};
Line(16) = {16, 11};

// Transition layer for mesh
Point(17) = {0, -H_tape/2-meshLayerWidthTape, 0, LcLayer};
Point(30) = {R, -H_tape/2-meshLayerWidthTape, 0, LcLayer};
Point(18) = {R+meshLayerWidthTape, -H_tape/2-meshLayerWidthTape, 0, LcLayer};
Point(31) = {R+meshLayerWidthTape, -H_tape/2, 0, LcLayer};
Point(32) = {R+meshLayerWidthTape, H_tape/2, 0, LcLayer};
Point(19) = {R+meshLayerWidthTape, H_tape/2+meshLayerWidthTape, 0, LcLayer};
Point(33) = {R, H_tape/2+meshLayerWidthTape, 0, LcLayer};
Point(20) = {0, H_tape/2+meshLayerWidthTape, 0, LcLayer};
Point(34) = {-R, H_tape/2+meshLayerWidthTape, 0, LcLayer};
Point(21) = {-R-meshLayerWidthTape, H_tape/2+meshLayerWidthTape, 0, LcLayer};
Point(35) = {-R-meshLayerWidthTape, H_tape/2, 0, LcLayer};
Point(36) = {-R-meshLayerWidthTape, -H_tape/2, 0, LcLayer};
Point(22) = {-R-meshLayerWidthTape, -H_tape/2-meshLayerWidthTape, 0, LcLayer};
Point(37) = {-R, -H_tape/2-meshLayerWidthTape, 0, LcLayer};

Line(17) = {17, 30};
Line(30) = {30, 18};
Line(18) = {18, 31};
Line(31) = {31, 32};
Line(32) = {32, 19};
Line(19) = {19, 33};
Line(33) = {33, 20};
Line(20) = {20, 34};
Line(34) = {34, 21};
Line(21) = {21, 35};
Line(35) = {35, 36};
Line(36) = {36, 22};
Line(22) = {22, 37};
Line(37) = {37, 17};

Line(50) = {30, 12};
Line(51) = {31, 12};
Line(52) = {32, 13};
Line(53) = {33, 13};
Line(55) = {34, 15};
Line(56) = {35, 15};
Line(57) = {36, 16};
Line(58) = {37, 16};

// Cut
Line(100) = {14, 20};
Line(101) = {20, 5};
Line(102) = {5, 6};

// Symmetric of the cut
Line(300) = {11, 17};
Line(301) = {17, 1};
Line(302) = {1, 2};

// Dummy line for meshing
Line(200) = {11, 14};

// Physical entities
Line Loop(30) = {2, 4, -102, -3, -1, 302}; // Outer shell 1
Plane Surface(30) = {30};
Line Loop(31) = {-7, -5, 102, 6, 8, -302}; // Outer shell 2
Plane Surface(31) = {31};

Line Loop(40) = {1, 3, -101, -33, -19, -32, -31, -18, -30, -17, 301}; // Inner shell, air 1
Plane Surface(40) = {40};
Line Loop(41) = {-37, -22, -36, -35, -21, -34, -20, 101, 5, 7, -301}; // Inner shell, air 2
Plane Surface(41) = {41};

Line Loop(50) = {17, 50, -11, 300}; // Transition layer for mesh 1
Plane Surface(50) = {50};
Line Loop(51) = {-50, 30, 18, 51}; // Transition layer for mesh 2
Plane Surface(51) = {51};
Line Loop(52) = {-51, 31, 52, -12}; // Transition layer for mesh 3
Plane Surface(52) = {52};
Line Loop(53) = {32, 19, 53, -52}; // Transition layer for mesh 4
Plane Surface(53) = {53};
Line Loop(54) = {-53, 33, -100, -13}; // Transition layer for mesh 5
Plane Surface(54) = {54};
Line Loop(55) = {100, 20, 55, -14}; // Transition layer for mesh 6
Plane Surface(55) = {55};
Line Loop(56) = {-55, 34, 21, 56}; // Transition layer for mesh 7
Plane Surface(56) = {56};
Line Loop(57) = {-15, -56, 35, 57}; // Transition layer for mesh 8
Plane Surface(57) = {57};
Line Loop(58) = {-57, 36, 22, 58}; // Transition layer for mesh 9
Plane Surface(58) = {58};
Line Loop(59) = {-300, -16, -58, 37}; // Transition layer for mesh 10
Plane Surface(59) = {59};

Line Loop(60) = {11, 12, 13, -200}; // Tape Right
Line Loop(70) = {200, 14, 15, 16}; // Tape Left
Plane Surface(60) = {60};
Plane Surface(70) = {70};



numElementsTape = Floor[0.5*400/meshMult];
Transfinite Line(14) = numElementsTape Using Progression 1;
Transfinite Line(16) = numElementsTape Using Progression 1;
Transfinite Line(13) = numElementsTape Using Progression 1;
Transfinite Line(11) = numElementsTape Using Progression 1;


Transfinite Surface(60);
Recombine Surface(60);
Transfinite Surface(70);
Recombine Surface(70);
/*
numElements = 20;
prog = 1.3;
Transfinite Line(50) = numElements Using Progression 1/prog;
Transfinite Line(53) = numElements Using Progression 1/prog;
Transfinite Line(100) = numElements Using Progression prog;
Transfinite Line(55) = numElements Using Progression 1/prog;
Transfinite Line(58) = numElements Using Progression 1/prog;
Transfinite Line(300) = numElements Using Progression prog;
Transfinite Line(18) = numElements Using Progression 1/prog;
Transfinite Line(32) = numElements Using Progression prog;
Transfinite Line(21) = numElements Using Progression 1/prog;
Transfinite Line(36) = numElements Using Progression prog;
numElementsTape = 2;
Transfinite Line(31) = numElementsTape Using Progression 1;
Transfinite Line(12) = numElementsTape Using Progression 1;
Transfinite Line(200) = numElementsTape Using Progression 1;
Transfinite Line(15) = numElementsTape Using Progression 1;
Transfinite Line(35) = numElementsTape Using Progression 1;


Transfinite Surface(50);
Recombine Surface(50);
Transfinite Surface(51);
Recombine Surface(51);
Transfinite Surface(52);
Recombine Surface(52);
Transfinite Surface(53);
Recombine Surface(53);
Transfinite Surface(54);
Recombine Surface(54);
Transfinite Surface(55);
Recombine Surface(55);
Transfinite Surface(56);
Recombine Surface(56);
Transfinite Surface(57);
Recombine Surface(57);
Transfinite Surface(58);
Recombine Surface(58);
Transfinite Surface(59);
Recombine Surface(59);
*/
Physical Surface("Air", AIR) = {40, 41, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59};
Physical Surface("Spherical shell", AIR_OUT) = {30, 31};
Physical Surface("Cylinder", MATERIAL) = {60, 70};
Physical Line("Exterior boundary", SURF_OUT) = {2, 4, 6, 8};
Physical Line("Symmetry line", SURF_SYM) = {};
Physical Line("Conducting domain boundary", BND_MATERIAL) = {11, 12, 13, 14, 15, 16};
Physical Line("Shells common line", SURF_SHELL) = {1, 3, 5, 7};
Physical Line("Symmetry line material", SURF_SYM_MAT) = {};
Physical Line("Cut", CUT) = {100, 101, 102};
Physical Line("Positive side of bnds", BND_MATERIAL_SIDE) = {13};
Physical Point("Arbitrary Point", ARBITRARY_POINT) = {2};


//Mesh.Algorithm = 1;

// End
