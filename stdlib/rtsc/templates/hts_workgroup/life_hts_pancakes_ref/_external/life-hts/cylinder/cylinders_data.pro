// ---- Geometry parameters ----
DefineConstant[
changeGeometry = {0, Choices{0,1}, Name "Input/1Geometry/1Show geometry?"},
R_inf = {0.1, Visible changeGeometry, Name "Input/1Geometry/Outer radius (m)"}, // Outer shell radius [m]
R_air = {0.07, Max R_inf, Visible changeGeometry, Name "Input/1Geometry/Inner radius (m)"}, // Inner shell radius [m]
W = {0.025, Max R_air/2, Visible changeGeometry, Name "Input/1Geometry/Cylinder diameter (m)"}, // Diameter of the cylinders [m]
H_super = {0.005, Max R_air/2, Visible changeGeometry, Name "Input/1Geometry/Bottom cylinder height (m)"}, // Height of the bottom cylinder [m]
H_ferro = {0.005, Max R_air/2, Visible changeGeometry, Name "Input/1Geometry/Top cylinder height (m)"}, // Height of the top cylinder [m]
meshLayerWidth = {0.005} // Width of the control mesh layer around the cylinder
];

// ---- Mesh parameters ----
DefineConstant [meshMult = {4, Name "Input/2Mesh/1Mesh size multiplier (-)"}]; // Multiplier [-] of a default mesh size distribution

// ---- Constant definition for regions ----
AIR = 1;
AIR_OUT = 2000;
SURF_SHELL = 3000;
CUT1 = 9000;
ARBITRARY_POINT = 11000;
SURF_SYM = 13000;
SURF_SYM_MAT = 13500;
SURF_OUT = 14000;
SUPER = 2;
FERRO = 3;
BND_OMEGA_C = 25000;
BND_OMEGA_C_SIDE = 26000;
