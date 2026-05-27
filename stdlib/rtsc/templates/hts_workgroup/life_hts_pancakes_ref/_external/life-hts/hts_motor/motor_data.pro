// Preset choice of problem resolution
DefineConstant[preset = {1, Highlight "Blue",
      Choices{
        1="Motor with rotation (a-formulation)",
        2="Torque vs. starting angle (a-formulation)",
        3="Supercondutor magnetization (coupled formulation)",
        4="Superconductor with imposed current (coupled formulation)"},
      Name "Input/3Problem/0Preset problem" },
  nonlinferro = {0, Choices{0,1}, Name "Input/4Material Properties/3Nonlinear ferromagnet?"},
  expMode = {0, Choices{0,1}, Name "Input/3Problem/1Allow changes?"}];
// ---- Geometry parameters ----
DefineConstant[
A0deg = {(preset >= 3) ? 0 : -18, ReadOnly !expMode, Name "Input/1Geometry/Rotor initial position (deg)"}
];
// Geometric dimensions
p = 5; // Number of pole pairs
// Radii
R1 = 0.16; // Inner boundary radius
R2 = 0.20; // End of rotor iron region
R3 = 0.218;
eps = 0.002;
R4 = 0.229;
R5 = 0.24;
R6 = 0.275;
Rext = 1;
If(preset < 3)
    jcw = 0.013; // Width of superconducting regions
ElseIf(preset == 3)
    jcw = 0.008;
Else
    jcw = 0.0002; // Width of superconducting regions
EndIf
// Anglar positions (in radians)
A5 = 2*Pi/p;
A1 = A5/8;
A2 = 3*A5/8;
A3 = 5*A5/8;
A4 = 7*A5/8;

A0 = A0deg*Pi/180; // Initial position of rotor

Tair = 1.5*Pi/180; // Angular space between two conductors in stator (radians)
Tpole = A5/6 - Tair; // Angular space of a pole in stator

thickness = 0.33; // Out-of-plane thickness (used for torque computation only)

// ---- Mesh parameters ----
DefineConstant [meshMult = {6, Name "Input/2Mesh/1Mesh size multiplier (-)"}]; // Multiplier [-] of a default mesh size distribution


// ---- Constant definition for regions ----
ROTOR_AIR = 1000;
ROTOR_IRON = 1100;
ROTOR_MAGNET = 2000;
CUT = 3000;
ROTOR_MAGNET_BND = 4000;
ROTOR_MAGNET_BND_SIDE = 5000;
ROTOR_BND_IN = 6000;
ROTOR_BND_A0 = 7000;
ROTOR_BND_A5 = 8000;
ROTOR_BND_MOVING_BAND = 9000;

STATOR_AIR = 10000;
STATOR_AIR_GAP = 15000;
STATOR_IRON = 20000;
STATOR_INDUCTOR = 30000;
STATOR_INDUCTOR_BND = 40000;
STATOR_BND_OUT = 50000;
STATOR_BND_T0 = 60000;
STATOR_BND_T13 = 70000;
STATOR_BND_MOVING_BAND = 80000;
