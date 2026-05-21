Function {
    mu0 = Pi*4e-7; // [H/m]
    nu0 = 1.0/mu0; // [m/H]
    DefineConstant[ec, jc, n]; // Parameters that must be defined for Superconductor
    DefineConstant[mur0, m0]; // Parameters that must be defined for Anhysteretic Ferro
    DefineConstant[Delta]; // Parameters for the thin-shell formulation
    // ----------------------------------------------------------------------------
    // -------------------------- CONSTITUTIVE LAWS -------------------------------
    // ----------------------------------------------------------------------------
    DefineFunction[mu, nu, dbdh, dhdb, rho, sigma, djde, dedj];
    // ------- Ferromagnetic (anhysteretic) material constitutive law -------
    // Permeability
    epsMu = 1e-15; // To prevent division by 0 in mu [A/m]
    mu_anhyModel[] = mu0 * ( 1.0 + 1.0 / ( 1/(mur0-1) + Norm[$1]/m0 ) );
    dbdh_anhyModel[] = ($iter > 10) ? ((1.0/$relaxFactor) * (mu0 * (1.0 + (1.0/(1/(mur0-1)+Norm[$1]/m0))#1 ) * TensorDiag[1, 1, 1]
                - mu0/m0 * (#1)^2 * 1/(Norm[$1]+epsMu) * SquDyadicProduct[$1])) :
                (mu0 * ( 1.0 + 1.0 / ( 1/(mur0-1) + Norm[$1]/m0 ) ) * TensorDiag[1, 1, 1]); // Hybrid lin. technique
    // Reluctivity
    epsNu = 1e-10; // To prevent division by 0 in nu [T]
    nu_anhyModel[] = 1/2 * ( (Norm[$1]+epsNu)#1 /mu0 - (mur0*m0/(mur0-1))#2
        + ( (#2 - #1/mu0)^2 + 4*m0*#1/((mur0-1)*mu0) )^(1/2) ) * 1/#1;
    dhdb_anhyModel[] = (1.0/$relaxFactor) *
        (1.0 / (2*(Norm[$1]+epsNu)#1)
            * (#1/mu0 - (mur0*m0/(mur0-1))#2
                + (( (#2 - #1/mu0)^2 + 4*m0*#1/((mur0-1)*mu0) )^(1/2))#3 ) * TensorDiag[1, 1, 1]
        + 1.0 / (2 * (#1)^3) * ( #2 - #3
            + #1/(#3*mu0) * ( (2-mur0)/(mur0-1) * m0 + #1/mu0 ) ) * SquDyadicProduct[$1]);

    // ------- Superconductor constitutive law -------
    ec = 1e-4;
    If(Flag_jcb == 1)
        jcb[] = jc/(1 + Norm[$1]/b0);
    Else
        jcb[] = jc;///(1 + $1);
    EndIf
    If(Flag_nb == 1)
        nb[] = n1 + (n0-n1)/(1 + Norm[$1]/b0);
    Else
        nb[] = n;///(1 + $1);
    EndIf
    // Power law e(j) = rho(j) * j, with rho(j) = ec/jc * (|j|/jc)^(n-1)
    rho_power[] = ec / jcb[$2] * (Min[($TimeStep<-1)?1.5*jcb[$2]:1e99, Norm[$1]]/jcb[$2])^(nb[$2] - 1);
    dedj_power[] = (1.0/$relaxFactor) *
      (ec / jcb[$2] * (Min[($TimeStep<-1)?1.5*jcb[$2]:1e99, Norm[$1]]/jcb[$2])^(nb[$2]#7 - 1) * TensorDiag[1, 1, 1] +
       ec / jcb[$2]^3 * (#7 - 1) * (Min[($TimeStep<-1)?1.5*jcb[$2]:1e99, Norm[$1]]/jcb[$2])^(#7 - 3) * SquDyadicProduct[$1]);
    // Power law j(e) = sigma(e) * e, with sigma(e) = jc/ec^(1/n) * |e|^((1-n)/n)
    epsSigma = 1e-8; // Importance of the linear part for a-formulation [-]
    epsSigma2 = 1e-15; // To prevent division by 0 in sigma [-]
    sigma_power[] = jcb[$2] / ec * 1.0 / ( epsSigma + ( Norm[$1]/ec )^((nb[$2]-1.0)/nb[$2]) );
    djde_power[] = ($iter > -1) ? ((1.0/$relaxFactor) *
        ( jcb[$2] / ec * (1.0 / (epsSigma + ( (Norm[$1]/ec)#3 )^((nb[$2]#7-1.0)/#7) ))#4 * TensorDiag[1, 1, 1]
        + jcb[$2]/ec^3 * (1.0-#7)/#7 * (#4)^(2) * 1/((#3)^((#7+1.0)/#7) + epsSigma2 ) * SquDyadicProduct[$1]))
            : (jcb[$2] / ec * 1.0 / ( epsSigma + ( Norm[$1]/ec )^((nb[$2]#7-1.0)/#7) ) * TensorDiag[1, 1, 1] );
    sigmae[] = sigma[$1,$2] * $1;

    // Power law thin-shell (TS) model
    rho_powerTS[] = (ec / (jc) ) *( Norm[($1-$2)/Delta] / (jc) )^(n - 1);
    dedj_powerTS[] =
					ec / jc * (  Norm[($1-$2)/Delta] / (jc) )^(n - 1) +
					ec / jc^3 * (n - 1) * (  Norm[($1-$2)/Delta] / (jc) )^(n - 3) * Norm[(($1-$2)/Delta)]^2;

    // ------- Copper constitutive law -------
    sigma_copper[] = 58e6; // [S/m]
    rho_copper[] = 1./sigma_copper[]; //1e-2*1.81e-10;//

    // ------- Using built-in functions for the power-law model -------
    rho_power_built_in[] = RhoPowerLaw[Norm[$1], jcb[$2], nb[$2]]{ec};
    drhodj_timesj_power_built_in[] = DRhoDJTimesJPowerLaw[$1, jcb[$2], nb[$2]]{ec};
    dedj_power_built_in[] = DEDJPowerLaw[$1, jcb[$2], nb[$2]]{ec};
}

// Predefined regions
Function{
    Flag_LinearProblem = (IsThereSuper == 1 || IsThereFerro == 1) ? 0 : 1;
    // ------- Predefined names for Groups (automatically filled below) -------
    // Air
    mu[Air] = mu0;
    nu[Air] = nu0;
    // Copper
    rho[Copper] = rho_copper[];
    sigma[Copper] = sigma_copper[];
    mu[Copper] = mu0;
    nu[Copper] = nu0;
    // Super (HTS with power law)
    rho[Super] = rho_power[$1,$2];
    dedj[Super] = dedj_power[$1,$2];
    sigma[Super] = sigma_power[$1,$2];
    djde[Super] = djde_power[$1,$2];
    mu[Super] = mu0;
    nu[Super] = nu0;
    // Ferro (soft anhysteretic ferromagnetic material)
    mu[Ferro] = mu_anhyModel[$1];
    dbdh[Ferro] = dbdh_anhyModel[$1];
    nu[Ferro] = nu_anhyModel[$1];
    dhdb[Ferro] = dhdb_anhyModel[$1];
}
