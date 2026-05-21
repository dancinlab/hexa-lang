Include "tape_data.pro";


line = (preset == 4 || preset == 5);
// Mesh size
R = W_tape/2; // Radius

DefineConstant [LcTape = 2*R/numElementsTape]; // Mesh size in cylinder [m]
DefineConstant [LcLayer = LcTape*2]; // Mesh size in the region close to the cylinder [m]
DefineConstant [LcAir = meshMult*0.001*3]; // Mesh size in air shell [m]
DefineConstant [LcInf = meshMult*0.001*3]; // Mesh size in external air shell [m]

// Shells definition
Point(100) = {0, 0, 0, LcTape};
Point(2) = {0, -R_inf, 0, LcInf};
Point(4) = {R_inf, 0, 0, LcInf};
Point(6) = {0, R_inf, 0, LcInf};
Point(8) = {-R_inf, 0, 0, LcInf};
Circle(2) = {2, 100, 4};
Circle(4) = {4, 100, 6};
Circle(6) = {6, 100, 8};
Circle(8) = {8, 100, 2};

If(line==1)
    Point(10) = {-R, 0, 0, LcTape};
    Point(11) = {R, 0, 0, LcTape};
    Line(10) = {10,11};
    Transfinite Line(10) = numElementsTape Using Progression 1;
    Line Loop(30) = {2, 4, 6, 8}; // Outer boundary
    Plane Surface(2) = {30};
    Curve{10} In Surface{2};
    Physical Surface("Air", AIR) = {2};
    Physical Line("Exterior boundary", SURF_OUT) = {2, 4, 6, 8};
    If (preset != 5)
        Physical Line("Conducting domain", MATERIAL) = {10};
        Physical Line("Conducting domain boundary", BND_MATERIAL) = {10};
    EndIf
    Physical Point("Left edge", EDGE_1) = {10};
    Physical Point("Right edge", EDGE_2) = {11};
    Physical Point("Arbitrary Point", ARBITRARY_POINT) = {2};
    // Empty regions
    Physical Surface("Spherical shell", AIR_OUT) = {};
    Physical Line("Symmetry line", SURF_SYM) = {};
    Physical Line("Shells common line", SURF_SHELL) = {};
    Physical Line("Symmetry line material", SURF_SYM_MAT) = {};
    Physical Line("Cut", CUT) = {};
    Physical Line("Positive side of bnds", BND_MATERIAL_SIDE) = {};
    Color Blue {Surface{2};}
    If (preset==5) // h-phi-TS-formulation
        Physical Line("Shell", SHELL) = {10};
        Solver.AutoMesh = 0;
        Geometry.AutoCoherence = 0;
        Mesh 2;
        Save "tape.msh";
        // Creates cracked geometry (allows discontinuities of the tangential field)
        Plugin(Crack).Dimension = 1;
        Plugin(Crack).PhysicalGroup = SHELL;
        Plugin(Crack).OpenBoundaryPhysicalGroup = 0;
        Plugin(Crack).Run;
        Physical Line("Shell_Down", SHELL_DOWN) = {10};
        Physical Line("Shell_Up", SHELL_UP) = {11};
        Save "tape.msh";
        // Computes the thick cuts required for the H-phi formulation
        Plugin(HomologyComputation).DomainPhysicalGroups= Sprintf("%g",AIR);
        Plugin(HomologyComputation).SubdomainPhysicalGroups= "";
        Plugin(HomologyComputation).ReductionImmunePhysicalGroups= "";
        Plugin(HomologyComputation).DimensionOfChainsToSave= "1";
        Plugin(HomologyComputation).Filename= StrCat[CurrentDir,"Homology"];
        Plugin(HomologyComputation).ComputeHomology=0;
        Plugin(HomologyComputation).ComputeCohomology=1;
        Plugin(HomologyComputation).CreatePostProcessingViews=1;
        Plugin(HomologyComputation).Run;
        Save "tape.msh";
    EndIf
Else
    Point(10) = {-R, -H_tape/2, 0, LcTape};
    Point(11) = {R, -H_tape/2, 0, LcTape};
    Point(12) = {R, H_tape/2, 0, LcTape};
    Point(13) = {-R, H_tape/2, 0, LcTape};
    Line(10) = {10,11};
    Line(11) = {11,12};
    Line(12) = {12,13};
    Line(13) = {13,10};
    Transfinite Line(10) = numElementsTape Using Progression 1;
    Transfinite Line(12) = numElementsTape Using Progression 1;
    Line Loop(20) = {10,11,12,13};
    Plane Surface(20) = {20};
    Transfinite Surface(20);
    Recombine Surface(20);
    //Line(101) = {11,4};
    //Line(102) = {13,8};
    Line Loop(30) = {2, 4, 6, 8};
    Plane Surface(30) = {30, 20};
    //Line Loop(31) = {-102,-12,-11,101,4,6};
    //Plane Surface(31) = {31};
    Physical Surface("Air", AIR) = {30};
    Physical Line("Exterior boundary", SURF_OUT) = {2, 4, 6, 8};
    Physical Surface("Conducting domain", MATERIAL) = {20};
    Physical Line("Conducting domain boundary", BND_MATERIAL) = {10,11,12,13};
    Physical Point("Left edge", EDGE_1) = {10};
    Physical Point("Right edge", EDGE_2) = {11};
    Physical Point("Arbitrary Point", ARBITRARY_POINT) = {11};
    Physical Line("Cut", CUT) = {};
    Physical Line("Positive side of bnds", BND_MATERIAL_SIDE) = {};
    // Empty regions
    Physical Surface("Spherical shell", AIR_OUT) = {};
    Physical Line("Symmetry line", SURF_SYM) = {};
    Physical Line("Shells common line", SURF_SHELL) = {};
    Physical Line("Symmetry line material", SURF_SYM_MAT) = {};
    Color Blue {Surface{30};}
EndIf
Hide { Point{ Point '*' }; }

Cohomology(1) {{AIR}, {}};
