// ---- Geometry parameters ----
R_box = 0.05;
r_wire = 0.01;
h_wire = 0.005;
w_wire = 1e-6;


// ---- Mesh parameters ----
DefineConstant [meshMult = 5]; // Multiplier [-] of a default mesh size distribution

// ---- Formulation definitions (dummy values) ----
h_formulation = 2;
a_formulation = 6;
coupled_formulation = 5;
ta_formulation = 7;


// ---- Constant definitions ----
AIR = 1000;
AIR_OUT = 1200;
CUT = 9000;
ARBITRARY_POINT = 11000;
SURF_SYM = 13000;
SURF_SYM_MAT1 = 15000;
SURF_SYM_MAT2 = 16000;
SURF_OUT = 140000000;
WIRE = 23000;
BND_WIRE = 25000;
BND_WIRE_SIDE = 26000;
EDGE_1 = 11001;
EDGE_2 = 11002;

SURF_SHELL = 3000;
SHELL = 4000;
SHELL_DOWN = 5000;
SHELL_UP = 6000;
THICK_CUT = SURF_OUT+1; // Fix me! It will be different depending on the other physical IDs
