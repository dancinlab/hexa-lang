
// ---- Geometry parameters ----
DefineConstant[
R_inf = {0.1, Name "Input/1Geometry/Outer radius (m)", Closed 1}, // Outer shell radius [m]
R_air = {0.05, Max R_inf, Name "Input/1Geometry/Inner radius (m)"}, // Inner shell radius [m]
W_tape = {4e-3, Max R_air/2, Name "Input/1Geometry/Cylinder diameter (m)"}, // Width of the tape [m]
H_tape = {1e-6, Max R_air/2, Name "Input/1Geometry/Bottom cylinder height (m)"}, // Height of the tape [m]
W_turn = {4.4e-3, Max R_air/2, Name "Input/1Geometry/Width of one turn (m)"}, // Width of the turn [m]
H_turn = {293e-6, Max R_air/2, Name "Input/1Geometry/Height of one turn (m)"}, // Height of the turn [m]
meshLayerWidthTape = {0.001} // Width of the control mesh layer around the cylinder
];

DefineConstant [recomb_mesh = {1, Choices{0,1}, Name "Input/2Mesh/1Recombine mesh ?"}]; // USE 1 TO AVOID DIVERGENCE.

// ---- Mesh parameters ----
DefineConstant [meshMult = {4, Name "Input/2Mesh/2Mesh size multiplier (-)"}]; // Multiplier [-] of a default mesh size distribution
DefineConstant [singleElement_bulk_height = {1, Choices{0,1}, Name "Input/2Mesh/5Use single element layer per bulk ? (-)"}]; // for smsts
DefineConstant [N_ele_bis = {1, Name "Input/2Mesh/3Number of hidden elements in TS formulation (-)"}];
DefineConstant [numElementsTapeWidth = {50, Name "Input/2Mesh/4Number of elements along tape width (-)"}];

// ---- Problem parameters ----
d_btw_tapes = H_turn; // distance between tapes [m]

DefineConstant [num_pancakes = {5, Name "Input/1Geometry/Number of pancakes"}]; // number of pancakes

DefineConstant [num_tapes = {100, Name "Input/1Geometry/Total number of tapes"}]; // number of tapes per pancake

DefineConstant [num_analyzed_tapes = {7, Name "Input/1Geometry/Number of analyzed tapes"}]; // number of tapes to analyze, for smsts

DefineConstant [num_blocks = 12]; // number of blocks in Vanilla homogenization

DefineConstant [num_elements_per_block = 1]; // number of elements per block in Vanilla homogenization (use 1 to avoid incorrect results)

DefineConstant [full_h_form = 0]; // full h instead of h-phi for reference computation (and Vanilla homogenization)

DefineConstant [check_power_conv = 1]; // print power estimate at each NR iteration (set to 0 for efficient resolution)

DefineConstant [Flag_compute_voltage = 1]; // Compute the voltage in formulations ... ? (always 1 for fw)

j_nb_samples = 50; // samples per tape for post-pro to compute R2 on J distrib

// User can choose the analyzed-tapes in practice (btwn 1 and num_tapes)
analyzed_tapeID_1 = 1; // first one must always be 1
If(num_analyzed_tapes == 5 && num_tapes == 100) // Wang 2022
    analyzed_tapeID_2 = 70;
    analyzed_tapeID_3 = 91;
    analyzed_tapeID_4 = 98;
ElseIf(num_analyzed_tapes == 7 && num_tapes == 100) // Berrospe 2021
    analyzed_tapeID_2 = 25;
    analyzed_tapeID_3 = 66;
    analyzed_tapeID_4 = 88;
    analyzed_tapeID_5 = 96;
    analyzed_tapeID_6 = 99;
ElseIf(num_analyzed_tapes == 11 && num_tapes == 100) // Berrospe 2021
    analyzed_tapeID_2 = 12;
    analyzed_tapeID_3 = 25;
    analyzed_tapeID_4 = 39;
    analyzed_tapeID_5 = 53;
    analyzed_tapeID_6 = 66;
    analyzed_tapeID_7 = 77;
    analyzed_tapeID_8 = 88;
    analyzed_tapeID_9 = 96;
    analyzed_tapeID_10 = 99;
ElseIf(num_analyzed_tapes == 16 && num_tapes == 100) // new here to gain some confidence on results
    analyzed_tapeID_2 = 8;
    analyzed_tapeID_3 = 16;
    analyzed_tapeID_4 = 24;
    analyzed_tapeID_5 = 32;
    analyzed_tapeID_6 = 40;
    analyzed_tapeID_7 = 48;
    analyzed_tapeID_8 = 56;
    analyzed_tapeID_9 = 64;
    analyzed_tapeID_10 = 72;
    analyzed_tapeID_11 = 80;
    analyzed_tapeID_12 = 88;
    analyzed_tapeID_13 = 92;
    analyzed_tapeID_14 = 96;
    analyzed_tapeID_15 = 99;
ElseIf(num_analyzed_tapes == 17 && num_tapes == 100) // Berrospe-like
    analyzed_tapeID_2 = 2;
    analyzed_tapeID_3 = 24;
    analyzed_tapeID_4 = 25;
    analyzed_tapeID_5 = 26;
    analyzed_tapeID_6 = 65;
    analyzed_tapeID_7 = 66;
    analyzed_tapeID_8 = 67;
    analyzed_tapeID_9 = 87;
    analyzed_tapeID_10 = 88;
    analyzed_tapeID_11 = 89;
    analyzed_tapeID_12 = 95;
    analyzed_tapeID_13 = 96;
    analyzed_tapeID_14 = 97;
    analyzed_tapeID_15 = 98;
    analyzed_tapeID_16 = 99;
Else // default: arrange the tapes equidistantly as a fct of num_analyzed_tapes
    For i In {2:num_analyzed_tapes-1}
        analyzed_tapeID~{i} = 1 + (num_tapes-1) * (i-1) / (num_analyzed_tapes-1);
    EndFor
EndIf
analyzed_tapeID~{num_analyzed_tapes} = num_tapes; // last one must always be num_tapes

height_stack = d_btw_tapes * (num_tapes-1); // total height of the stack of tapes

// ---- Constant definition for regions ----
AIR = 10000;
BULK = 15000;
BULK_OFFSET = 2; // Offset for the bulk regions (to avoid overlapping with the other physical IDs)
BND_BULK = 20000;
LEFT_SURFACE_BULK = 25000; // used in the smsts geometry for helping construct the cuts
RIGHT_SURFACE_BULK = 30000; // used in the smsts geometry for helping construct the cuts

ALL_BULKS = 35000; // contains all the bulks (useful in .geo file for creating cuts thin shells)
ALL_BULKS2 = 38000;

BND_AIR_SURPANCAKE_NO_TOP = 40000; // used in the smsts geometry for helping construct the cuts
BND_AIR_SURPANCAKE_TOP = 40100; // used in the smsts geometry for helping construct the cuts
BND_AIR_SURPANCAKE_RIGHT = 40200; // used in the smsts geometry for helping construct the cuts
BND_AIR_BOTTOM_NO_PANCAKE = 40300; // used in the smsts geometry for helping construct the cuts
BND_AIR_LEFT_NO_PANCAKE = 40400; // used in the smsts geometry for helping construct the cuts

TS = 45000;
TS_OFFSET = 2;
TS_DOWN = 50000;
TS_UP = 60000;
TS_EDGE_LEFT = 70000;
TS_EDGE_RIGHT = 80000;
TS_FULL = 90000; // contains TS_DOWN and TS_UP

ARBITRARY_POINT = 150000; // for setting phi=0 at some point

COMMON_BND_OMEGAC_PANCAKE_HOM = 250000;

SURF_SYM_BOT = 500000;
SURF_SYM_LEFT = 550000;

SURF_OUT = 600000;
If(num_analyzed_tapes < num_tapes) // default
    THICK_CUT = SURF_OUT+5*(num_analyzed_tapes-1)*num_pancakes+2*num_analyzed_tapes*num_pancakes+1; // It will be different depending on the other physical IDs
Else // reference model: no cuts related to source domains
    THICK_CUT = SURF_OUT+2*num_analyzed_tapes*num_pancakes+1;
EndIf
THICK_CUT = THICK_CUT+num_analyzed_tapes*num_pancakes;
CUT_SOURCE = SURF_OUT+4*(num_analyzed_tapes-1)*num_pancakes+1; // It will be different depending on the other physical IDs

// for reference model h-phi full
TAPE = 45000;
TAPE_OFFSET = 2;
TAPE_EDGE_DOWN = 50000;
TAPE_EDGE_RIGHT = 60000;
TAPE_EDGE_UP = 70000;
TAPE_EDGE_LEFT = 80000;
TAPE_BND = 90000;
