// ---- Geometry parameters ----
DefineConstant[
R_inf = {0.1, Name "Input/1Geometry/Outer radius (m)", Closed 1}, // Outer shell radius [m]
R_air = {0.07, Max R_inf, Name "Input/1Geometry/Inner radius (m)"}, // Inner shell radius [m]
W = {0.025, Max R_air/2, Name "Input/1Geometry/Cylinder diameter (m)"}, // Diameter of the cylinder [m]
H_cylinder = {0.01, Max R_air/2, Name "Input/1Geometry/Cylinder height (m)"}, // Height of the cylinder [m]
meshLayerWidth = {0.005} // Width of the control mesh layer around the cylinder
];
// ---- Mesh parameters ----
DefineConstant [meshMult = {4, Name "Input/2Mesh/1Mesh size multiplier (-)"}]; // Multiplier [-] of a default mesh size distribution

// ---- Formulation definitions (dummy values) ----
h_formulation = 2;
a_formulation = 6;
coupled_formulation = 5;

// ---- Constant definition for regions ----
AIR = 10000000;
AIR_OUT = 2000;
SURF_SHELL = 3000;
CUT = 9000;
ARBITRARY_POINT = 11000;
SURF_SYM = 13000;
SURF_SYM_MAT = 13500;
SURF_OUT = 14000;
MATERIAL = 23000;
BND_MATERIAL = 25000;
BND_MATERIAL_SIDE = 26000;
