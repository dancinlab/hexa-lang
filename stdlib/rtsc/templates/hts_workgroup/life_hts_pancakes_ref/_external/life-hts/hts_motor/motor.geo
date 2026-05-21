// Include cross data
Include "motor_data.pro";

// Mesh size
pR1 = meshMult*0.0007;
Solver.AutoShowLastStep = 1;
Mesh.Algorithm = 6;
Geometry.CopyMeshingMethod = 1;

fact_trans = Mesh.CharacteristicLengthFactor ;

// --- Rotor ---
// Periodic boundaries
sinA = Sin(A0); cosA = Cos(A0);
pntA0[]+=newp; Point(newp)={R1*cosA, R1*sinA, 0, pR1};
pntA0[]+=newp; Point(newp)={R2*cosA, R2*sinA, 0, pR1};
pntA0[]+=newp; Point(newp)={(R3-2*eps)*cosA, (R3-2*eps)*sinA, 0, pR1};
For k In {0:#pntA0[]-2}
    linA0[]+=newl; Line(newl) = {pntA0[k], pntA0[k+1]};
EndFor
Transfinite Line{linA0[0]} = Ceil[(R2-R1)/pR1/fact_trans] ;
Transfinite Line{linA0[1]} = Ceil[(R3-R2)/pR1/fact_trans] ;
For k In {0:#linA0[]-1}
    linA5[] += Rotate {{0, 0, 1}, {0, 0, 0}, A5} { Duplicata{Line{linA0[k]};} };
EndFor
// Inner circular boundary
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A1} { Point{pntA0[0]}; };
cirR1[]+=lin[1];
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A3-A1} { Point{lin[0]}; };
cirR1[]+=lin[1];
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A5-A3} { Point{lin[0]}; };
cirR1[]+=lin[1];
surfint[]=cirR1[{0,1,2}];
// Outer circular rotor "boundary"
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A5} { Point{pntA0[2]}; };
cirR3_eps[]+=lin[1];
// Inner circular curves
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A1} { Point{pntA0[1]}; };
cirR2[]+=lin[1];
pntA1[] += lin[0];
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A2-A1} { Point{lin[0]}; };
cirR2[]+=lin[1];
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A3-A2} { Point{lin[0]}; };
cirR2[]+=lin[1];
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A4-A3} { Point{lin[0]}; };
cirR2[]+=lin[1];
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A5-A4} { Point{lin[0]}; };
cirR2[]+=lin[1];
// Cuts
linA1[] += Rotate {{0, 0, 1}, {0, 0, 0}, A1} { Duplicata{Line{linA0[0]};} };
linA3[] += Rotate {{0, 0, 1}, {0, 0, 0}, A3} { Duplicata{Line{linA0[0]};} };
// Magnet boundaries
pntR2jcw[]+=newp; Point(newp)={(R2+jcw)*Cos[A1+A0], (R2+jcw)*Sin[A1+A0], 0, pR1};
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A2-A1} { Point{pntR2jcw[0]}; };
cirR2jcw[]+=lin[1];
pMagnet[] += Rotate {{0, 0, 1}, {0, 0, 0}, A3-A2} { Duplicata{Point{lin[0]};} };
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A4-A3} { Point{pMagnet[0]}; };
cirR2jcw[]+=lin[1];
linA1[] += newl; Line(newl) = {pntA1[0], pntR2jcw[0]};
linA2[] += Rotate {{0, 0, 1}, {0, 0, 0}, A2-A1} { Duplicata{Line{linA1[1]};} };
linA3[] += Rotate {{0, 0, 1}, {0, 0, 0}, A3-A2} { Duplicata{Line{linA2[0]};} };
linA4[] += Rotate {{0, 0, 1}, {0, 0, 0}, A4-A3} { Duplicata{Line{linA3[1]};} };
// Iron surfaces
Line Loop(newll) = {linA0[0], cirR2[0], -linA1[0], -cirR1[0]};
sironrotor[]+=news; Plane Surface(news) = {newll-1};
Line Loop(newll) = {linA1[0], cirR2[{1,2}], -linA3[0], -cirR1[1]};
sironrotor[]+=news; Plane Surface(news) = {newll-1};
Line Loop(newll) = {linA3[0], cirR2[{3,4}], -linA5[0], -cirR1[2]};
sironrotor[]+=news; Plane Surface(news) = {newll-1};
// Air surface
Line Loop(newll) = {linA0[1], cirR3_eps[0], -linA5[1], -cirR2[4], linA4[0], -cirR2jcw[1], -linA3[1], -cirR2[2], linA2[0], -cirR2jcw[0], -linA1[1], -cirR2[0]};
sairrotor[]+=news; Plane Surface(news) = {newll-1};

linairrotor[]  = CombinedBoundary{Surface{sairrotor[]};};
linironrotor[]  = CombinedBoundary{Surface{sironrotor[]};};
// Magnet surfaces
Line Loop(newll) = {linA1[1], cirR2jcw[0], -linA2[0], -cirR2[1]};
smagnetrotor1[]+=news; Plane Surface(news) = {newll-1};
linMagnet1[] = Boundary{Surface{smagnetrotor1[]};};
Line Loop(newll) = {linA3[1], cirR2jcw[1], -linA4[0], -cirR2[3]};
smagnetrotor2[]+=news; Plane Surface(news) = {newll-1};
linMagnet2[] = Boundary{Surface{smagnetrotor2[]};};
// Moving band
Transfinite Line{cirR3_eps[0]} = 2*Pi/p*R3/pR1 ;
lineMBrotor[]=cirR3_eps[];
For k In {1:p-1}
    lineMBrotoraux[]+=Rotate {{0, 0, 1}, {0, 0, 0}, k*A5} { Duplicata{Line{lineMBrotor[]};} };
EndFor
// Mesh refinement
If(preset == 4)
    factor = 0.1;
    Transfinite Line{cirR2[1]} = R2*(A2-A1)/(factor*pR1) ;
    Transfinite Line{cirR2jcw[0]} = R2*(A2-A1)/(factor*pR1) ;
    Transfinite Line{cirR2[3]} = R2*(A4-A3)/(factor*pR1) ;
    Transfinite Line{cirR2jcw[1]} = R2*(A4-A3)/(factor*pR1) ;
    Recombine Surface(smagnetrotor1);
    Recombine Surface(smagnetrotor2);
ElseIf(preset == 3)
    Characteristic Length{PointsOf{Surface{smagnetrotor1[]};}} = 0.7*pR1;
    Characteristic Length{PointsOf{Surface{smagnetrotor2[]};}} = 0.7*pR1;
EndIf
// --- Physical regions ---
Physical Surface("Rotor air",ROTOR_AIR) = {sairrotor[]};
Physical Surface("Rotor iron",ROTOR_IRON) = {sironrotor[]};
Physical Surface("Rotor super magnet 1",ROTOR_MAGNET) = {smagnetrotor1};
Physical Surface("Rotor super magnet 2",ROTOR_MAGNET+1) = {smagnetrotor2};
Physical Line("Cut magnet 1", CUT) = {linA1[0]};
Physical Line("Cut magnet 2", CUT+1) = {linA3[0]};
Physical Line("Boundary magnet 1", ROTOR_MAGNET_BND) = {linMagnet1[]};
Physical Line("Boundary magnet 2", ROTOR_MAGNET_BND+1) = {linMagnet2[]};
Physical Line("Boundary magnet 1 side", ROTOR_MAGNET_BND_SIDE) = {linA1[1]};
Physical Line("Boundary magnet 2 side", ROTOR_MAGNET_BND_SIDE+1) = {linA3[1]};
Physical Line("Rotor inner boundary", ROTOR_BND_IN) = {surfint[]};
Physical Line("Rotor radial boundary (master)", ROTOR_BND_A0) = {linA0[0], linA0[1]};
Physical Line("Rotor radial boundary (slave)", ROTOR_BND_A5) = {linA5[0], linA5[1]};
Physical Line("Rotor moving band boundary 1", ROTOR_BND_MOVING_BAND)  = {lineMBrotor[]};
For k In {1:p-1}
  Physical Line(Sprintf("Rotor moving band boundary %g",k+1), ROTOR_BND_MOVING_BAND+k)  = {lineMBrotoraux[k-1]};
EndFor


// --- Stator ---
// Periodic boundaries
sinA = Sin(0); cosA = Cos(0);
pntT0[]+=newp; Point(newp)={(R3-eps)*cosA, (R3-eps)*sinA, 0, pR1};
pntT0[]+=newp; Point(newp)={R3*cosA, R3*sinA, 0, pR1};
pntT0[]+=newp; Point(newp)={R4*cosA, R4*sinA, 0, pR1};
pntT0[]+=newp; Point(newp)={R5*cosA, R5*sinA, 0, pR1};
pntT0[]+=newp; Point(newp)={R6*cosA, R6*sinA, 0, pR1};
For k In {0:#pntT0[]-2}
    linT0[]+=newl; Line(newl) = {pntT0[k], pntT0[k+1]};
EndFor
Transfinite Line{linT0[0]} = Ceil[(eps)/pR1/fact_trans] ;
Transfinite Line{linT0[1]} = Ceil[(R4-R3)/pR1/fact_trans] ;
Transfinite Line{linT0[2]} = Ceil[(R5-R4)/pR1/fact_trans] ;
Transfinite Line{linT0[3]} = Ceil[(R6-R5)/pR1/fact_trans] ;
For k In {0:#linT0[]-1}
    linT13[] += Rotate {{0, 0, 1}, {0, 0, 0}, A5} { Duplicata{Line{linT0[k]};} };
EndFor
// One-arc circular boundaries
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A5} { Point{pntT0[0]}; };
cirR3eps[]+=lin[1];
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A5} { Point{pntT0[3]}; };
cirR5[]+=lin[1];
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, A5} { Point{pntT0[4]}; };
cirR6[]+=lin[1];
// Three-phase inductors region
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, Tair/2} { Point{pntT0[1]}; };
cirR3[]+=lin[1];
For k In {0:4}
    lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, Tpole} { Point{lin[0]}; };
    cirR3[]+=lin[1];
    lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, Tair} { Point{lin[0]}; };
    cirR3[]+=lin[1];
EndFor
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, Tpole} { Point{lin[0]}; };
cirR3[]+=lin[1];
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, Tair/2} { Point{lin[0]}; };
cirR3[]+=lin[1];
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, Tair/2} { Point{pntT0[2]}; };
cirR4[]+=lin[1];
For k In {0:4}
    lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, Tpole} { Point{lin[0]}; };
    cirR4[]+=lin[1];
    lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, Tair} { Point{lin[0]}; };
    cirR4[]+=lin[1];
EndFor
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, Tpole} { Point{lin[0]}; };
cirR4[]+=lin[1];
lin[] = Extrude {{0, 0, 1}, {0, 0, 0}, Tair/2} { Point{lin[0]}; };
cirR4[]+=lin[1];
linR34[] += linT0[1];
linR34[] += Rotate {{0, 0, 1}, {0, 0, 0}, Tair/2} { Duplicata{Line{linR34[0]};} };
For k In {0:4}
    linR34[] += Rotate {{0, 0, 1}, {0, 0, 0}, Tpole} { Duplicata{Line{linR34[1+2*k]};} };
    linR34[] += Rotate {{0, 0, 1}, {0, 0, 0}, Tair} { Duplicata{Line{linR34[2+2*k]};} };
EndFor
linR34[] += Rotate {{0, 0, 1}, {0, 0, 0}, Tpole} { Duplicata{Line{linR34[11]};} };
// Moving band
Transfinite Line{cirR3eps[0]} = 2*Pi/p*R3/pR1 ;
lineMBstator[]=cirR3eps[];
For k In {1:p-1}
  lineMBstatoraux[]+=Rotate {{0, 0, 1}, {0, 0, 0}, k*A5} { Duplicata{Line{lineMBstator[]};} };
EndFor
// Air surfaces
Line Loop(newll) = {-cirR3eps[0], linT0[0], cirR3[{0:12:1}], -linT13[0]};
sairstator[]+=news; Plane Surface(news) = {newll-1};
Line Loop(newll) = {cirR5[0], -linT13[2], -cirR4[{12:0:-1}], linT0[2]};
sairstator[]+=news; Plane Surface(news) = {newll-1};
Line Loop(newll) = {linT0[1], cirR4[0], -linR34[1], -cirR3[0]};
sairstator[]+=news; Plane Surface(news) = {newll-1};
For k In {1:5}
    Line Loop(newll) = {linR34[{2*k}], cirR4[2*k], -linR34[{2*k+1}], -cirR3[2*k]};
    sairstator[]+=news; Plane Surface(news) = {newll-1};
EndFor
Line Loop(newll) = {linR34[12], cirR4[12], -linT13[1], -cirR3[12]};
sairstator[]+=news; Plane Surface(news) = {newll-1};
// Iron surface
Line Loop(newll) = {linT0[3], cirR6[0], -linT13[3], -cirR5[0]};
sironstator[]+=news; Plane Surface(news) = {newll-1};
linairstator[]  = CombinedBoundary{Surface{sairstator[]};};
linironstator[]  = CombinedBoundary{Surface{sironstator[]};};

// Inductors surfaces
For k In {0:5}
    Line Loop(newll) = {linR34[{1+2*k}], cirR4[{2*k+1}], -linR34[{2*k+2}], -cirR3[{2*k+1}]};
    sinductorstator[]+=news; Plane Surface(news) = {newll-1};
EndFor
linInductor[] = Boundary{Surface{sinductorstator[]};};

// --- Physical regions ---
Physical Surface("Stator air",STATOR_AIR) = {sairstator[{1:#sairstator[]-1:1}]};
Physical Surface("Stator air gap",STATOR_AIR_GAP) = {sairstator[0]};
Physical Surface("Stator iron",STATOR_IRON) = {sironstator[]};

Physical Surface("Stator B+",STATOR_INDUCTOR) = {sinductorstator[0]};
Physical Surface("Stator A-",STATOR_INDUCTOR+1) = {sinductorstator[1]};
Physical Surface("Stator C+",STATOR_INDUCTOR+2) = {sinductorstator[2]};
Physical Surface("Stator B-",STATOR_INDUCTOR+3) = {sinductorstator[3]};
Physical Surface("Stator A+",STATOR_INDUCTOR+4) = {sinductorstator[4]};
Physical Surface("Stator C-",STATOR_INDUCTOR+5) = {sinductorstator[5]};
Physical Line("Boundary inductors", STATOR_INDUCTOR_BND) = {linInductor[]};

Physical Line("Stator outer boundary", STATOR_BND_OUT) = {cirR6[0]};
Physical Line("Stator radial boundary (master)", STATOR_BND_T0) = {linT0[{0:3:1}]};
Physical Line("Stator radial boundary (slave)", STATOR_BND_T13) = {linT13[{0:3:1}]};
Physical Line("Stator moving band boundary 1", STATOR_BND_MOVING_BAND)  = {lineMBstator[]};
For k In {1:p-1}
  Physical Line(Sprintf("Stator moving band boundary %g",k+1), STATOR_BND_MOVING_BAND+k)  = {lineMBstatoraux[k-1]};
EndFor



// For nice visualisation only
Color SkyBlue {Surface{sairrotor[]};}
Color SkyBlue {Surface{sairstator[]};}
Color SteelBlue {Surface{sironrotor[]};}
Color SteelBlue {Surface{sironstator[]};}
Color Purple {Surface{smagnetrotor1[]};}
Color Purple {Surface{smagnetrotor2[]};}
Color Orange {Surface{sinductorstator[{0,3}]};}
Color Red {Surface{sinductorstator[{1,4}]};}
Color Orchid {Surface{sinductorstator[{2,5}]};}
Hide { Point{ Point '*' }; }
// /*
Hide { Line{ Line '*' }; }
Show { Line{ lineMBrotoraux[] }; }
Show { Line{ lineMBstatoraux[] }; }
Show { Line{ linairrotor[] }; }
Show { Line{ linairstator[] }; }
Show { Line{ linironrotor[] }; }
Show { Line{ linironstator[] }; }
// */
