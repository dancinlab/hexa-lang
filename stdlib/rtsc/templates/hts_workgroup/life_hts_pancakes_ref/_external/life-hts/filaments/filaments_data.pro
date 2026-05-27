// Important parameters
geoFactor = 1e-2;

DefineConstant[
  ThreeD = {0, Choices{0,1}, Highlight "LightYellow",
    Name "Input/1Geometry/0Three-dimensional model"},
  Preset = {2, Highlight "Blue",
    Choices{
      //0="None",
      //1="1 round filament (AK benchmark)",
      2="6 round filaments",
      //3="36 round filaments (GE benchmark)",
      //4="1 rectangular tape",
      //5="2 rectangular tapes",
      6="single layer CORC cable",
      7="TEST"},
    Name "Input/1Geometry/0Preset configuration" },
  TwistPitch = {(Preset == 3) ? 12 : (Preset == 2 || Preset == 7) ? 0.1*geoFactor : (Preset == 6) ? 0.055 : 4,
    Name "Input/1Geometry/Twist pitch [mm]"},
  PitchInGeo = 1,
  ConductingMatrix = {1, Choices{0,1},
    Name "Input/4Materials/Conducting matrix?"}
];

DefineConstant [meshMult = {4*0.25, Name "Input/2Mesh/1Mesh size multiplier (-)"}]; // Multiplier [-] of a default mesh size distribution

Flag_TA = 1*ThreeD && (Preset == 6);

AutomaticCutGeneration = 1 * (Preset != 6); // CAREFUL HERE IF USING THE GUI

StructuredFilaments = 1; // For round filaments only.

DefineConstant[
NumLayers = {
  (Preset == 3) ? 3 : ((Preset == 7) ? 2 :
  1),
  ReadOnly !Preset,
  Name "Input/1Geometry/Layers"},
AirRadius = {(Preset == 2 || Preset == 7) ? 0.04*geoFactor : (Preset == 6) ? 0.01 : 1, ReadOnly !Preset,
  Name "Input/1Geometry/Radius of air domain [mm]"},
InfRadius = {(Preset == 2 || Preset == 7) ? 0.05*geoFactor : (Preset == 6) ? 0.015 : 1.4, ReadOnly !Preset,
  Name "Input/1Geometry/Radius of infinite air domain [mm]"}
];
For i In {1:NumLayers}
  DefineConstant[
    NumFilaments~{i} = {
      (Preset == 3 && i == 1) ? 6 :
      (Preset == 3 && i == 2) ? 12 :
      (Preset == 3 && i == 3) ? 18 :
      (Preset == 7 && i == 1) ? 1 :
      (Preset == 7 && i == 2) ? 6 :
      (Preset == 2) ? 6 :
      (Preset == 6) ? 3 :
      (Preset == 5) ? 2 :
      (Preset == 1 || Preset == 4) ? 1 :
      2 * i,
      Min 1, Max 100, Step 1,
      Name Sprintf["Input/1Geometry/{Layer %g/Filaments", i]}
  ];
EndFor

DefineConstant[
  MatrixRadius = {(Preset == 3) ? 0.5 :
      (Preset == 2 || Preset == 7) ? 0.0155*geoFactor :
      (Preset == 6) ? 0.006 :
      0.56419,
    Name "Input/1Geometry/Radius of conductive matrix [mm]"},
  FilamentShape = {(Preset == 4 || Preset == 5) ? 1 : (Preset == 6) ? 2 : 0,
    Choices{0="Round", 1="Rectangular", 2="Rounded"},
    Name "Input/1Geometry/Filament shape"},
  FilamentRadius = {
    (Preset == 3) ? 0.036 :
    (Preset == 1) ? 0.5 :
    (Preset == 2 || Preset == 7) ? 0.0035*geoFactor :
    0.1784,
    Name "Input/1Geometry/Filement radius [mm]", Visible !FilamentShape},
  FilamentWidth = {(Preset == 6) ? 5.205188e-3 : 0.75,
    Name "Input/1Geometry/Filament width [mm]", Visible (FilamentShape==1)},
  //FilamentGap = {0.0005,
    //Name "Input/1Geometry/Filament air gap [mm]", Visible (FilamentShape==2)},
  FilamentThickness = {(Preset == 6) ? 1e-6 : 0.05,
    Name "Input/1Geometry/Filament thickness [mm]", Visible FilamentShape},
  TwistFraction = {
    (Preset == 3) ? 0.075 :
    (Preset == 2 || Preset == 7) ? 1/6 :
    (Preset == 6) ? 1/6 :
    (Preset == 1) ? 0.01 :
    1/4,
    Min 1/16, Max 2, Step 1/4,
    Name "Input/1Geometry/Twist fraction in model"},
  LcFilament = {(Preset == 3) ? 0.015 : (Preset == 2 || Preset == 7) ? meshMult*0.001*geoFactor: (Preset == 6) ? ((Flag_TA == 0) ? meshMult*0.0002 : meshMult*0.0006): 0.05,
    Name "Input/2Mesh/Size on filaments [mm]", Closed 1},
  FilamentMeshAniso = {(Preset == 3) ? 5 : 1.5, Min 1, Max 5, Step 1,
    Name "Input/2Mesh/Anisotropy of filament mesh along filament"},
  FilamentMeshTransfinite = {1, Choices{0,1},
    Name "Input/2Mesh/Use regular mesh in rectangular filaments"},
  FilamentMeshTransfiniteAniso = {5,
    Name "Input/2Mesh/Anisotropy of regular mesh in rectangular filaments"},
  LcMatrix = {(Preset == 2 || Preset == 7) ? meshMult*0.002*geoFactor : (Preset == 6) ? meshMult*0.0005 : 0.1,
    Name "Input/2Mesh/Size on matrix boundary [mm]"},
  LcAir = {(Preset == 2 || Preset == 7) ? meshMult*0.01*geoFactor : (Preset == 6) ? meshMult*0.002 : 0.2,
    Name "Input/2Mesh/Size on air boundary [mm]"}
];

For i In {1:NumLayers}
  DefineConstant[
    LayerRadius~{i} = {
      (Preset == 3 && i == 1) ? 0.13 :
      (Preset == 3 && i == 2) ? 0.25 :
      (Preset == 3 && i == 3) ? 0.39 :
      (Preset == 7 && i == 1) ? 0 :
      (Preset == 7 && i == 2) ? 2.8*FilamentRadius :
      (Preset == 6) ? 0.00514 :
      (Preset == 5) ? 0.1 :
      (Preset == 2 || Preset == 7) ? 2.8*FilamentRadius :
      (Preset == 1 || Preset == 4) ? 0 :
      i * MatrixRadius / (NumLayers + 1),
      Min FilamentRadius, Max MatrixRadius, Step 1e-2,
      Name Sprintf["Input/1Geometry/{Layer %g/Radius [mm]", i]},
    StartAngleFilament~{i} = { (Preset == 5) ? Pi/2 : 0,
      Min 0, Max 2*Pi, Step 2*Pi/100,
      Name Sprintf["Input/1Geometry/{Layer %g/Starting angle [rad]", i]}
  ];
EndFor


//delta = FilamentGap / LayerRadius_1;
//beta = (2*Pi - delta*3)/6; // Half aperture of tapes in radian
theta_tape = Atan[TwistPitch/(2*Pi*LayerRadius_1)];
w_true = FilamentWidth;
w_2D = w_true/Sin[theta_tape];
beta = w_2D/LayerRadius_1;
TapeWidth = 2*beta*LayerRadius_1;
theta_tape_compl = Pi/2 - theta_tape;

Scaling = 1e3; // geometrical scaling
mm = 1e-3 * Scaling;

// i = layer, j = filament in layer
ARBITRARY_POINT = 10000;
FILAMENT = 30000; // + 1000 * i + j
BND_FILAMENT = 20000; // + 1000 * i + j for bottom
                      // + 1100 * i + j for top
                      // + 1200 * i + j for sides
MATRIX = 300000;
BND_MATRIX = 200000;
AIR = 310001;
BND_AIR = 210001;
INF = 320001;
BND_INF = 220001;
INF_LAT = 230001;
TMP_MATRIX = 1000;
TMP_AIR = 2000;
TMP_INF = 3000;
