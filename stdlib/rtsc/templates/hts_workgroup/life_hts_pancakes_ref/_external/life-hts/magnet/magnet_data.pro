
// ---- Geometry parameters ----
mm = 0.001;

bulk_h = 17.7*mm; // [m]
bulk_r = 30*mm/2; // [m]

coil_h = 30*mm; //
coil_r = 27*mm; //

air_space = 4*mm; // TO CHECK!
space = 4*mm; // TO CHECK!

coil_d = 2*bulk_r+space; //
coil_isol = 0.2*mm; //
coil_l = (space+bulk_r)*2+0.25*2*Pi*(bulk_r+space); //
coil_middle = 0; //
coil_N = 55.5; //
coil_tape = 0.22*mm; //
coil_t_tot = (coil_N*coil_tape+(coil_N-1)*coil_isol); //
coil_tape_sur = coil_tape*coil_h; //
coil_cross = coil_h*coil_t_tot; //
coil_V = Pi*(bulk_r+space+coil_t_tot)^2*coil_h-Pi*(bulk_r+space)^2*coil_h; //


air_a = .4; // [m]
air_r = 10*coil_r; // [m]

iron_h = bulk_h; //
iron_r = bulk_r; //

/*
ge_C = 0.001*5; // [F]
ge_L = ge_L_coil+ge_L_al; //
ge_L_al = 4[uH]; //
ge_L_coil = 5.0349E-5[H]; //
ge_R_al = 4[mohm]; //
ge_Uc0 = 1000[V]; //
HTS_h = bulk_h; //
HTS_tt = coil_tape; //
*/
B0 = 1.3; // [T]
Bmax = 10; // [T]
Imax = 2000; // [A]

mu0 = Pi*4e-7;
Jmax = Imax/(coil_tape*coil_h); //
Msat = 1.6/mu0; //
muf = 1200; //
P1 = 1.171*10^(-17); //
P2 = 4.49; //
P3 = 3.84*10^(10); //
P4 = 1.14; //
P5 = 50; //
P6 = 6.428; //
P7 = 0.4531; //
pl_alpha = 4.6*10^8; // [A/m^2] "Normal purity of HTS"
pl_B_B0 = .5; // [T]
pl_B_Ec0 = 1e-4; //
pl_B_Jc0 = 500e6; // [A/m^2]
pl_B_n0 = 21; //
pl_B_n1 = 5; //
pl_Ec = 1e-4; // "Power law"
pl_Jc0 = 100e6; // [A/m^2] "Power law"
pl_n = 21; // "Power law"
pl_n1 = 5; //
RRR = 50; //
q0 = 1.553*10^(-8)/RRR; //
Rho_coil = 1/6e7; //[S/m]
shift = 1e-4; // [m]
silver_h = bulk_h; //
silver_tt = coil_tape; //
study_Nt = 500; //
study_T = 0.1; // [s]
study_dt = study_T/study_Nt; //
study_f = 1/study_T; //
T_LN2 = 77.36; // [K]
T_peak = 0.002; // [s]
Tc_YBCO = 92; // [K]
air_space = 4*mm; //
middle_x1 = (bulk_r+air_space/2); //
middle_x2 = -(bulk_r+air_space/2); //
middle_x3 = -(bulk_r+air_space/2); //
middle_x4 = (bulk_r+air_space/2); //
middle_y1 = (bulk_r+air_space/2); //
middle_y2 = (bulk_r+air_space/2); //
middle_y3 = -(bulk_r+air_space/2); //
middle_y4 = -(bulk_r+air_space/2); //
space_i = 2*mm; //


// ---- Formulation ----
DefineConstant [
  preset = {1,  Name "Input/5Method/0Preset formulation", Choices {
      1="h-formulation",
      2="a-formulation",
      3="h-a-formulation (only super in h)",
      4="h-phi-a-formulation (only iron in a)",
      5="h-formulation with spurious conductivity in air",
      6="a-formulation with spurious conductivity in air",
      7="h-formulation but with inversed law for ferromagnet",
      8="a-formulation but with inversed law for super"}
  }
];

// ---- Mesh parameters ----
DefineConstant [meshMult = 0.8]; // Multiplier [-] of a default mesh size distribution

// ---- Constant definition for regions ----
AIR = 1000;
BULK = 3000;
IRON = 2000;
COIL = 4000;
CUT = 5000;
ONE_SIDE_OF_CUT = 5100;
ARBITRARY_POINT = 5200;
SURF_SYM = 5500;
SURF_OUT = 5700;
BND_BULK_IN = 14000;
BND_BULK_SYM = 15000;
BND_IRON_IN = 14500;
BND_IRON_SYM = 15500;
BND_COIL_IN = 16000;
BND_COIL_SYM = 17000;
