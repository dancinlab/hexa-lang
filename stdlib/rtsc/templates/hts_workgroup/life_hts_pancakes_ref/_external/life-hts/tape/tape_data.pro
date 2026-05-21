// Preset choice of formulation
DefineConstant[preset = {1, Highlight "Blue",
  Choices{
    1="h-formulation",
    2="a-formulation (large steps)",
    3="a-formulation (small steps)",
    4="t-a-formulation",
    5="h-phi-ts-formulation"},
  Name "Input/5Method/0Preset formulation" },
  expMode = {0, Choices{0,1}, Name "Input/5Method/1Allow changes?"}];

// ---- Geometry parameters ----
DefineConstant[
R_inf = {0.06, Name "Input/1Geometry/Outer radius (m)", Closed 1}, // Outer shell radius [m]
R_air = {0.04, Max R_inf, Name "Input/1Geometry/Inner radius (m)"}, // Inner shell radius [m]
W_tape = {12e-3, Max R_air/2, Name "Input/1Geometry/Cylinder diameter (m)"}, // Width of the tape [m]
H_tape = {1e-6, Max R_air/2, Name "Input/1Geometry/Bottom cylinder height (m)"}, // Height of the tape [m]
meshLayerWidthTape = {0.001} // Width of the control mesh layer around the cylinder
];

// ---- Mesh parameters ----
DefineConstant [meshMult = {4, Name "Input/2Mesh/1Mesh size multiplier (-)"}]; // Multiplier [-] of a default mesh size distribution
DefineConstant [elementMult = 10];

numElementsTape = Floor[elementMult*0.1*200/meshMult];
N_ele = 1; // Number of virtual elemnets in the h_phi_ts_formulation
Delta = H_tape/(N_ele); // Virtual elements size

// ---- Constant definition for regions ----
AIR = 1000;
AIR_OUT = 2000;
SURF_SHELL = 3000;
SHELL = 4000;
SHELL_DOWN = 5000;
SHELL_UP = 6000;
CUT = 9000;
ARBITRARY_POINT = 11000;
EDGE_1 = 11001;
EDGE_2 = 11002;
SURF_SYM = 13000;
SURF_SYM_MAT = 13500;
SURF_OUT = 14000000;
MATERIAL = 23000;
BND_MATERIAL = 25000;
BND_MATERIAL_SIDE = 26000;
THICK_CUT = SURF_OUT+1; // Fix me! It will be different depending on the other physical IDs
