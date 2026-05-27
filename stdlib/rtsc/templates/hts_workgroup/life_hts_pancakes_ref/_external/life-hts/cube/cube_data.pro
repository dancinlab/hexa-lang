// ---- Geometry parameters ----
a = 0.01; // Cube side [m]
R_inf = 0.025; // Outer shell radius [m]

// ---- Mesh parameters ----
DefineConstant [meshMult = 2]; // Multiplier [-] of a default mesh size distribution
// Choose 1.1 for the same mesh than in the article

// ---- Constant definition for regions ----
AIR = 1000;
SURF_SYM_bn0 = 13000;
SURF_SYM_MAT_bn0 = 13500;
SURF_SYM_ht0 = 13100;
SURF_SYM_MAT_ht0 = 13600;
SURF_OUT = 14000;
MATERIAL = 23000;
BND_MATERIAL = 25000;
