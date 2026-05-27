Function{
     // Superconductor parameters
    DefineConstant [jcb_law = 1];
    Flag_jcb = jcb_law;
    If(Flag_jcb == 1)
        // Kim-like model, parameters from K. Thakur, SUST, 2011 (fit using data from Z. Jiang, SUST, 2011)
        b0 = 0.04265; // [T]
        k_jcb = 0.29515; // [-]
        alpha_jcb = 0.7; // [-]
    EndIf
    If(Flag_jcb == 1)
        DefineConstant [jc = {2.8e10*fill_factor, Name "Input/3Material Properties/2jc (Am⁻²)"}]; // Critical current density [A/m2]
        DefineConstant [n = {38, Name "Input/3Material Properties/1n (-)"}]; // Superconductor exponent (n) value [-]
    Else
        DefineConstant [jc = {2.5e10*fill_factor, Name "Input/3Material Properties/2jc (Am⁻²)"}]; // Critical current density [A/m2]
        DefineConstant [n = {25, Name "Input/3Material Properties/1n (-)"}]; // Superconductor exponent (n) value [-]
    EndIf

    // Excitation
    DefineConstant [Imax = 11]; // [A], benchmark
    //DefineConstant [Imax = 28]; // [A], second benchmark

    DefineConstant [f = 50]; // Frequency of imposed current intensity [Hz]
    DefineConstant [timeStart = 0]; // Initial time [s]
    DefineConstant [timeFinal = 1.0/f]; // Final time for source definition [s]
    DefineConstant [timeFinalSimu = 1.0/f]; // Final time of simulation [s]

    // Numerical parameters
    DefineConstant [nbStepsPerPeriod = {600, Highlight "LightBlue", Name "Input/5Method/Number of time step per period (-)"}]; // Number of time steps over one period [-], choice of 600 for accurate results and consistent comparison
    DefineConstant [dt = 1/(nbStepsPerPeriod*f)]; // Time step (initial if adaptive)[s]
    DefineConstant [writeInterval = dt/10000]; // Time interval between two successive output file saves [s]
    DefineConstant [dt_max = dt]; 
    DefineConstant [iter_max = {60, Highlight "LightBlue", Name "Input/5Method/Max number of iteration (-)"}]; // Maximum number of nonlinear iterations
    normal_vector[] = Vector[0.,1.,0.]; // normal direction of the tape
    normal_vector_tape[] = Vector[0.,1.,0.]; // normal direction of the tape (useful for jcb evaluation)

    len_tape = 1/100; // length of the tape [m], dummy value for computing the voltage drop in tapes. useful for FW post-pro

    Flag_WallTime = 1; // Display the wall time

    // Sine source field
    controlTimeInstants = {dt,0.25/f:timeFinalSimu:0.25/f};
    I[] = Imax * Sin[2.0 * Pi * f * $Time];

    mu0 = Pi*4e-7; // [H/m]
    mu[Air] = mu0;
    mu[Super] = mu0;
    nu[] = 1/mu0; // for t-a formulation
    ec = 1e-4;
    If(Flag_jcb == 1)
        jcb[] = jc/(1 + Sqrt[k_jcb^2 * (Norm[$1 - SquDyadicProduct[normal_vector_tape[]] * $1])^2 + (normal_vector_tape[] * $1)^2]/b0)^alpha_jcb; // anisotropic Kim model
        jcb_TS[] = jc/(1 + Sqrt[k_jcb^2 * SquNorm[$1] + SquNorm[$2]]/b0)^alpha_jcb;
    Else
        jcb[] = jc;
        jcb_TS[] = jc;
    EndIf

    rho_power_built_in[] = RhoPowerLaw[Norm[$1], jcb[$2], n]{ec};
    drhodj_timesj_power_built_in[] = DRhoDJTimesJPowerLaw[$1, jcb[$2], n]{ec};

    rho_power_TS_built_in[] = RhoPowerLaw[Norm[($1-$2)/Delta], jcb_TS[mu[]*($1+$2)/2, $3], n]{ec};
    drhodj_timesj_power_TS_built_in[] = DRhoDJTimesJPowerLawTS2D[Norm[($1-$2)/Delta], jcb_TS[mu[]*($1+$2)/2, $3], n]{ec};
}