Function{
    // Output directory name (.txt only, .pos are not put there)
    DefineConstant [resDirectory = StrCat["../",name,"/res/"]];
    DefineConstant [outputDirectory = StrCat[resDirectory,testname]];
    // Filenames - On domains
    DefineConstant [infoIterationFile   = StrCat[outputDirectory,"/iteration.txt"]];
    DefineConstant [infoResidualFile    = StrCat[outputDirectory,"/residual.txt"]];
    DefineConstant [outputPower         = StrCat[outputDirectory,"/power.txt"]];
    DefineConstant [outputRevPower = StrCat[outputDirectory,"/rev.txt"]];
    DefineConstant [outputIrrevPower = StrCat[outputDirectory,"/irrev.txt"]];
    DefineConstant [outputAppliedField  = StrCat[outputDirectory,"/appliedField.txt"]];
    DefineConstant [outputMagnetization = StrCat[outputDirectory,"/avgMagn.txt"]];
    DefineConstant [outputMagnetization2 = StrCat[outputDirectory,"/avgMagn2.txt"]];
    // Filenames - On lines
    DefineConstant [outputCurrent = StrCat[outputDirectory,"/jLine.txt"]];
    DefineConstant [outputMagInduction1 = StrCat[outputDirectory,"/bLine1.txt"]];
    DefineConstant [outputMagInduction2 = StrCat[outputDirectory,"/bLine2.txt"]];
    DefineConstant [outputMagInduction3 = StrCat[outputDirectory,"/bLine3.txt"]];
    DefineConstant [outputMagInduction4 = StrCat[outputDirectory,"/bLine4.txt"]];
    DefineConstant [outputMagField1 = StrCat[outputDirectory,"/hLine1.txt"]];
    DefineConstant [aPosterioriFile = StrCat[outputDirectory,"/posteriori.txt"]];

    If(Flag_variable_dt_max == 1)
        dt_max_t[] = dt_max_var[];
    Else
        dt_max_t[] = dt_max;
    EndIf
}

Macro RelaxationFactors
    // Initialize parameters
    Evaluate[$mult = 1.5625];
    Evaluate[$relaxFactor = 0.4096 ]; // Starting relaxation factor
    Evaluate[$decreasing = 0]; // Start by increasing the factor
    Evaluate[$relaxTestNb = 0]; Evaluate[$maxRelaxTestNb = 6];
    // Try with the initial relaxation factor (save in x_Opt in case of...)
    AddVector[A, 1, 'x_Prev', $relaxFactor, 'Delta_x', 'x_Opt']; Evaluate[$factor_Opt = $relaxFactor];
    CopySolution['x_Opt', A]; Generate[A]; GetResidual[A, $res];
    //Print[{$relaxFactor, $res}, Format "   Initial factor: %g (res: %g)"];
    // Loop until residual does no longer decrease
    Evaluate[$mightBeImproved = 1]; Evaluate[$relaxFactor = $mult*$relaxFactor ];
    While[$mightBeImproved == 1 && $relaxTestNb < $maxRelaxTestNb]{
        Evaluate[$res_prev = $res];
        AddVector[A, 1, 'x_Prev', $relaxFactor, 'Delta_x', 'x_New'];
        CopySolution['x_New', A];
        Generate[A]; GetResidual[A, $res];
        // If residual decreases
        Test[$res < $res_prev]{
            //Print[{$relaxFactor, $res, $res_prev}, Format "   It has decreased with factor: %g (res: %g, previous: %g)"];
            CopySolution[A,'x_Opt']; Evaluate[$factor_Opt = $relaxFactor];
            Evaluate[$relaxFactor = $relaxFactor * $mult];
            Test[$decreasing == 1]{Evaluate[$mightBeImproved = 1];}
        }
        // otherwise
        {
            //Print[{$relaxFactor, $res, $res_prev}, Format "   It has NOT decreased with factor: %g (res: %g, previous: %g)"];
            // If just starting (first residual test)
            Test[$relaxTestNb <= 1 || $decreasing == 1]{
                Evaluate[$decreasing = 1];
                Test[$relaxTestNb == 1]{
                    Evaluate[$relaxFactor = $relaxFactor / $mult];
                }
                {
                    Evaluate[$relaxFactor = $relaxFactor / ($mult*$mult)];
                }
            }
            // otherwise
            {
                Evaluate[$mightBeImproved = 0];
            }
        }
        Evaluate[$relaxTestNb = $relaxTestNb + 1];
    }
    CopySolution['x_Opt',A]; // Take the optimal solution
    Evaluate[$relaxFactor = $factor_Opt];
    Generate[A];
    GetResidual[A, $res];
Return

Macro CustomIterativeLoop
    Evaluate[$relaxFactor = 1];
    Generate[A];
    GetResidual[A, $res0]; // Residual for the initial guess
    Evaluate[ $res = $res0 ];
    Evaluate[ $iter = -1 ];
    Evaluate[ $convCrit = 100 ];
    Evaluate[ $cycleSuspected = 0 ];
    Test[economInfo == 0]{
        Print[{$TimeStep, $DTime, $Time}, Format "%g %g %g", File infoIterationFile];
    }
    //Evaluate[$startSaving = 0];
    // ----- Enter the iterative loop (hand-made) -----
    While[$convCrit > 1 && $res / $res0 <= 1e10 && $iter < iter_max]{
        Test[$iter == 10]{Evaluate[$cycleSuspected = 1];}
        // Save previous solution
        CopySolution[A,'x_Prev'];
        Evaluate[$res_last = $res];
        // Get the increment Delta_x
        Evaluate[$relaxFactor = 1];
        Generate[A];
        Solve[A]; Evaluate[ $syscount = $syscount + 1 ];
        CopySolution[A,'x_New'];
        AddVector[A, 1, 'x_New', -1, 'x_Prev', 'Delta_x'];
        // Test several factors
        Test[$cycleSuspected == 1]{
            Call RelaxationFactors;
        }
        {
            Generate[A];
            GetResidual[A, $res];
            Evaluate[$factor_Opt = 1];
        }
        // For debug: saves all iterations
        Test[$iter == 2000]{Evaluate[$startSaving = 1];}
        Test[$startSaving == 1]{SaveSolution[A];}
        // Evaluate new indicators and update counters
        Evaluate[ $indicAirOld = $indicAir,
                  $indicFerroOld = $indicFerro,
                  $indicSuperOld = $indicSuper];
        PostOperation[MagDyn_energy];
        GetNormSolution[A, $normSol];
        Evaluate[ $iter = $iter + 1 ];
        Test[economInfo == 0]{
            Print[{$iter, $factor_Opt, $res, $res / $res0, $indicAir, $indicFerro, $indicSuper},
                Format "%g %g %14.12e %14.12e %14.12e %14.12e %14.12e", File infoResidualFile];
        }
        // Compute convergence criterion
        Evaluate[ $relChangeAir = Abs[($indicAirOld - $indicAir)/((Abs[$indicAirOld]>1e-10)?$indicAirOld:1e-10)],
                  $relChangeFerro = (Abs[$indicFerroOld]>1e-8) ? (Abs[($indicFerroOld - $indicFerro)/((Abs[$indicFerroOld]>1e-6)?$indicFerroOld:1e-6)]):1e-10,
                  $relChangeSuper = Abs[($indicSuperOld - $indicSuper)/((Abs[$indicSuperOld]>1e-7 || $iter < 10)?$indicSuperOld:1e-7)] ];
        Test[IsThereFerro == 1 && IsThereSuper == 1]{
            Evaluate[$convCrit = Max[$relChangeAir,
                Max[$relChangeFerro, $relChangeSuper]]/tol_energy];
        }
        Test[IsThereFerro == 1 && IsThereSuper == 0]{
            Evaluate[$convCrit = Max[$relChangeAir,$relChangeFerro]/tol_energy];
        }
        Test[IsThereFerro == 0 && IsThereSuper == 1]{
            Evaluate[$convCrit = Max[$relChangeAir,$relChangeSuper]/tol_energy];
        }
        Test[IsThereFerro == 0 && IsThereSuper == 0]{
            Evaluate[$convCrit = $relChangeAir/tol_energy];
        }
        Test[ !($convCrit >= 1e99) && !($convCrit < 1e99)] // Detect NaN
        {
            Evaluate[ $res = 1e99 ];
            Break[];
        }
        Test[Flag_LinearProblem == 1]{
            Evaluate[ $res = 1e-99 ];
            Break[];
        }
    }
Return


Macro CustomIterativeLoopNoRelax
    // Compute first solution guess and residual at step $TimeStep
    Generate[A];
    Test[$startSaving == 1]{SaveSolution[A];} // For debug: saves all iterations
    Solve[A]; Evaluate[ $syscount = $syscount + 1 ];
    //Print[A];
    Test[$startSaving == 1]{SaveSolution[A];} // For debug: saves all iterations
    Generate[A]; GetResidual[A, $res0];
    GetNormSolution[A, $normSol];
    Evaluate[ $res = $res0 ];
    Evaluate[ $iter = 0 ];
    Evaluate[ $convCrit = 1e99 ];
    PostOperation[MagDyn_energy];
    Test[economInfo == 0]{
        Print[{$TimeStep, $DTime, $Time}, Format "%g %g %g", File infoIterationFile];
        Print[{$iter, $res, $res / $res0, $indicAir, $indicFerro, $indicSuper},
            Format "%g %14.12e %14.12e %14.12e %14.12e %14.12e", File infoResidualFile];
    }
    Test[Flag_LinearProblem == 1]{
        Evaluate[ $convCrit = 0.1 ];
    }
    // ----- Enter the iterative loop (hand-made) -----
    Test[convergenceCriterion == 0 || convergenceCriterion == 1]{
        While[$convCrit > 1 && $res / $res0 <= 1e10 && $iter < iter_max]{
            Solve[A]; Evaluate[ $syscount = $syscount + 1 ];
            Generate[A]; GetResidual[A, $res];
            Test[$startSaving == 1]{SaveSolution[A];} // For debug: saves all iterations
            GetNormSolution[A, $normSol];
            Evaluate[ $iter = $iter + 1 ];
            Evaluate[ $indicAirOld = $indicAir,
                      $indicFerroOld = $indicFerro,
                      $indicSuperOld = $indicSuper];
            PostOperation[MagDyn_energy];
            Test[economInfo == 0]{
                Print[{$iter, $res, $res / $res0, $indicAir, $indicFerro, $indicSuper},
                    Format "%g %14.12e %14.12e %14.12e %14.12e %14.12e", File infoResidualFile];
            }
            // Evaluate the convergence indicator
            Test[convergenceCriterion == 0]{ // The most reliable criterion. Threshold value: attention!! (not always ok)
                Evaluate[ $relChangeAir = Abs[($indicAirOld - $indicAir)/((Abs[$indicAirOld]>1e-10)?$indicAirOld:1e-10)],
                          $relChangeFerro = (Abs[$indicFerroOld]>1e-8) ? (Abs[($indicFerroOld - $indicFerro)/((Abs[$indicFerroOld]>1e-5)?$indicFerroOld:1e-2)]):1e-10,
                          $relChangeSuper = Abs[($indicSuperOld - $indicSuper)/((Abs[$indicSuperOld]>1e-7 || $iter < 10)?$indicSuperOld:1e-7)] ];
                Test[IsThereFerro == 1 && IsThereSuper == 1]{
                    Evaluate[$convCrit = Max[$relChangeAir,
                        Max[$relChangeFerro, $relChangeSuper]]/tol_energy];
                }
                Test[IsThereFerro == 1 && IsThereSuper == 0]{
                    Evaluate[$convCrit = Max[$relChangeAir,$relChangeFerro]/tol_energy];
                }
                Test[IsThereFerro == 0 && IsThereSuper == 1]{
                    Evaluate[$convCrit = Max[$relChangeAir,$relChangeSuper]/tol_energy];
                }
                Test[IsThereFerro == 0 && IsThereSuper == 0]{
                    Evaluate[$convCrit = $relChangeAir/tol_energy];
                }
            }
            Test[convergenceCriterion == 1]{ // Not reliable. Do not use.
                Evaluate[ $convCrit = $res/tol_abs ];
            }

        }
    }
    Test[convergenceCriterion == 2]{ // Just for tests. Do not use this.
        IterativeLoop {
            NbrMaxIteration iter_max+1 ; RelaxationFactor 1 ; Criterion tol_incr ;
            Operation {
                GenerateJac[A] ; SolveJac[A] ;
                Evaluate[ $syscount = $syscount + 1 ]; GetNormIncrement[A, $normIncr];
                Generate[A];
                GetResidual[A, $res];
                PostOperation[MagDyn_energy];
                Evaluate[ $iter = $iter + 1 ];
                Print[{$iter, $res, $res / $res0, $normSol, $indicAir, $indicFerro, $indicSuper},
                    Format "%g %14.12e %14.12e %14.12e %14.12e %14.12e %14.12e", File infoResidualFile];
                GetNormSolution[A, $normSol];
            }
        }
    }
Return


// ----------------------------------------------------------------------------
// --------------------------- RESOLUTION -------------------------------------
// ----------------------------------------------------------------------------
Resolution {
    { Name MagDyn;
        System {
            If(formulation == h_formulation)
                {Name A; NameOfFormulation MagDyn_htot;}
            ElseIf(formulation == h_formulation+1)
                {Name A; NameOfFormulation MagDyn_htot_full;}
            ElseIf(formulation == h_formulation+2)
                {Name A; NameOfFormulation MagDyn_htot_links;}
            ElseIf(formulation == a_formulation)
                {Name A; NameOfFormulation MagDyn_avtot;}
            ElseIf(formulation == coupled_formulation)
                {Name A; NameOfFormulation MagDyn_coupled;}
            ElseIf(formulation == ta_formulation)
                {Name A; NameOfFormulation MagDyn_ta;}
            ElseIf(formulation == h_phi_ts_formulation)
                {Name A; NameOfFormulation MagDyn_hphits;}
            EndIf
        }
        Operation {
            //SetGlobalSolverOptions["-petsc_prealloc_full 200"]; // prealloc for "global functions" (groupsOfEdges,...): total size by default
            // Create directory to store result files
            CreateDirectory[resDirectory];
            CreateDirectory[outputDirectory]; // For .txt ouput files
            DeleteFile[outputPower]; // Start from a new file
            DeleteFile[infoIterationFile]; // Start from a new file
            DeleteFile[infoResidualFile]; // Start from a new file
            // Initialize the solution (initial condition)
            Evaluate[ $startSaving = saveAll ]; // If put to 1, saves all iterations
            SetTime[ timeStart ];
            SetDTime[ dt ];
            SetTimeStep[ 0 ];
            Evaluate[ $iter = 0 ];
            Evaluate[ $elapsedCTI = 0 ]; // Number of control time instants already treated
            If(Flag_MB == 1)
                InitMovingBand2D[MB] ;
                MeshMovingBand2D[MB] ;
            EndIf
            InitSolution[A];
            SaveSolution[A];
            // Count the number of solved linear systems
            Evaluate[ $syscount = 0 ];
            // Will save only a few time steps
            Evaluate[ $fileCreated = 0 ];
            Evaluate[ $saved = 1 ];
            // Initialize variable
            Evaluate[$normIncr = 1e99]; Evaluate[$Voltage = 0]; Evaluate[$Current = 0];
            Evaluate[$indicAir = 0]; Evaluate[$indicSuper = 0]; Evaluate[$indicFerro = 0];
            // Initialize relaxation factors
            Evaluate[ $relaxFactor = 1 ];
            // Set the extrapolation order for the initial iterate
            SetExtrapolationOrder[ extrapolationOrder ];
            // ----- Enter implicit Euler time integration loop (hand-made) -----
            // Avoid too close steps at the end. Stop the simulation if the step becomes ridiculously small
            While[$Time < timeFinalSimu - 1e-5 && $DTime > 1e-10 && $DTime > dt/50000] {
                SetTime[ $Time + $DTime ]; // Time instant at which we are looking for the solution
                If(Flag_MB == 1 && Flag_rotating == 1)
                    ChangeOfCoordinates[ NodesOf[Rotor_Moving], RotatePZ[delta_theta[]]];
                    MeshMovingBand2D[MB] ;
                EndIf
                // Make sure all CTI are exactly chosen
                Evaluate[ $isCTI = 0 ];
                If(Flag_CTI == 1)
                    Test[$Time >= AtIndex[$elapsedCTI]{List[controlTimeInstants]} - 1e-6 ]{
                        Evaluate[ $isCTI = 1, $prevDTime = $DTime ];
                        SetDTime[ AtIndex[$elapsedCTI]{List[controlTimeInstants]} - $Time + $DTime ];
                        SetTime[ AtIndex[$elapsedCTI]{List[controlTimeInstants]} ]; // To compute exactly at the asked time instant
                    }
                EndIf

                SetTimeStep[ $TimeStep + 1 ];
                // ----- Enter custom iterative loop -----
                //Generate[A];
                //Test[$TimeStep == 7]{Evaluate[ $startSaving = 1];}
                Test[tryrelaxationfactors == 1]{
                    // With relaxation factors
                    Call CustomIterativeLoop;
                }
                {
                    // Without relaxation factors
                    Call CustomIterativeLoopNoRelax;
                }
                //Break[];
                // ----- End custom iterative loop ----- (it has not necessarily converged)
                // If converged... (case $res0 == 0 if "exact" solution directly found )
                Test[ $iter < iter_max && ($res / $res0 <= 1e10 || $res0 == 0)]{
                    // Save the solution of few time steps (small correction to avoid bad rounding)
                    Test[ saveAllSteps==1 || $Time >= $saved * writeInterval - 1e-6 || $Time + $DTime >= timeFinalSimu]{
                        SaveSolution[A];
                        If(saveAllStepsSeparately)
                            Print[{$TimeStep}, Format "%g"];
                            PostOperation[saveSeparately];
                        EndIf
                        If(realTimeSolution)
                            PostOperation[MagDyn];
                        EndIf
                        If(realTimeInfo)
                            PostOperation[Info];
                        EndIf
                        Print[{$Time, $indicAir, $indicFerro, $indicSuper, $indicDissSuper, $indicDissLin, $Voltage, $Current},
                            Format "%g %14.12e %14.12e %14.12e %14.12e %14.12e %14.12e %14.12e", File outputPower];
                        Print[{$Time, $indicSuper}, Format "Time %g saved."];
                        Evaluate[$saved = $saved + 1];
                    }
                    // Increase the step if we converged sufficiently "fast" (and not a control time instant)
                    Test[ $iter < iter_max / 4 && $DTime < dt_max_t[] && $isCTI == 0 ]{
                        Evaluate[ $dt_new = Min[$DTime * 2, dt_max_t[]] ];
                        Print[{$dt_new}, Format "*** Fast convergence: increasing time step to %g"];
                        SetDTime[$dt_new];
                    }
                    // Consider the previous time step if control time instant and increment $elapsedCTI
                    Test[ $isCTI == 1 ]{
                        Evaluate[ $elapsedCTI = $elapsedCTI + 1 ];
                        SetDTime[ $prevDTime ];
                    }
                }
                // ...otherwise, reduce the time step and try again
                {
                    // Replace the rotor at its previous position
                    If(Flag_MB == 1 && Flag_rotating == 1)
                        ChangeOfCoordinates[ NodesOf[Rotor_Moving], RotatePZ[-delta_theta[]]];
                    EndIf
                    Evaluate[ $dt_new = $DTime / 2 ];
                    Print[{$iter, $dt_new},
                        Format "*** Non convergence (iter %g): recomputing with reduced step %g"];
                    RemoveLastSolution[A];
                    SetTime[$Time - $DTime];
                    SetTimeStep[$TimeStep - 1];
                    SetDTime[$dt_new];
                }
            } // ----- End time loop -----
            // Print information about the resolution and the nonlinear iterations
            Print[{$syscount}, Format "Total number of linear systems solved: %g"];
            //Print[A];
        }
    }
}

// ----------------------------------------------------------------------------
// --------------------------- POST-OPERATION ---------------------------------
// ----------------------------------------------------------------------------
// Operations useful for convergence criterion
PostOperation {
    // Extracting energetic quantities
    { Name MagDyn_energy ;
        If(formulation == h_formulation)
            NameOfPostProcessing MagDyn_htot ; LastTimeStepOnly 1 ;
        ElseIf(formulation == h_formulation+1)
            NameOfPostProcessing MagDyn_htot_full ; LastTimeStepOnly 1 ;
        ElseIf(formulation == h_formulation+2)
            NameOfPostProcessing MagDyn_htot_links ; LastTimeStepOnly 1 ;
        ElseIf(formulation == a_formulation)
            NameOfPostProcessing MagDyn_avtot ; LastTimeStepOnly 1 ;
        ElseIf(formulation == coupled_formulation)
            NameOfPostProcessing MagDyn_coupled ; LastTimeStepOnly 1 ;
        ElseIf(formulation == ta_formulation)
            NameOfPostProcessing MagDyn_ta ; LastTimeStepOnly 1 ;
        ElseIf(formulation == h_phi_ts_formulation)
            NameOfPostProcessing MagDyn_hphits ; LastTimeStepOnly 1 ;
        EndIf
        Operation{
            Print[ power[Air], OnGlobal, Format Table, StoreInVariable $indicAir, File "res/dummy.txt"];
            Print[ power[MagnAnhyDomain], OnGlobal, Format Table, StoreInVariable $indicFerro, File > "res/dummy.txt" ];
            Print[ power[NonLinOmegaC], OnGlobal, Format Table, StoreInVariable $indicSuper, File > "res/dummy.txt" ];
            Print[ dissPower[NonLinOmegaC], OnGlobal, Format Table, StoreInVariable $indicDissSuper, File > "res/dummy.txt" ];
            Print[ dissPower[LinOmegaC], OnGlobal, Format Table, StoreInVariable $indicDissLin, File > "res/dummy.txt" ];

            If(formulation == h_formulation || (formulation == h_formulation+1 && k_max==0) || formulation == coupled_formulation || formulation == h_phi_ts_formulation)
                Print[ dissPowerGlobal, OnRegion Cuts, Format Table, StoreInVariable $indicDissGlobal, File > "res/dummy.txt" ];
                Print[ V, OnRegion Cuts, Format Table, StoreInVariable $Voltage, File > "res/dummy.txt" ];
                Print[ I, OnRegion Cuts, Format Table, StoreInVariable $Current, File > "res/dummy.txt" ];
            ElseIf(formulation == a_formulation)
                Print[ dissPowerGlobal, OnRegion OmegaC, Format Table, StoreInVariable $indicDissGlobal, File > "res/dummy.txt" ];
                Print[ U, OnRegion OmegaC, Format Table, StoreInVariable $Voltage, File > "res/dummy.txt" ];
                Print[ I, OnRegion OmegaC, Format Table, StoreInVariable $Current, File > "res/dummy.txt" ];
            ElseIf(formulation == ta_formulation)
                Print[ dissPowerGlobal, OnRegion PositiveEdges, Format Table, StoreInVariable $indicDissGlobal, File > "res/dummy.txt" ];
                Print[ V, OnRegion PositiveEdges, Format Table, StoreInVariable $Voltage, File > "res/dummy.txt" ];
                Print[ I, OnRegion PositiveEdges, Format Table, StoreInVariable $Current, File > "res/dummy.txt" ];
            EndIf
        }
    }
    // Save the steps separately (if needed)
    { Name saveSeparately ;
        If(formulation == h_formulation)
            NameOfPostProcessing MagDyn_htot ;
        ElseIf(formulation == h_formulation+1)
            NameOfPostProcessing MagDyn_htot_full ;
        ElseIf(formulation == h_formulation+2)
            NameOfPostProcessing MagDyn_htot_links ;
        ElseIf(formulation == a_formulation)
            NameOfPostProcessing MagDyn_avtot ;
        ElseIf(formulation == coupled_formulation)
            NameOfPostProcessing MagDyn_coupled ;
        ElseIf(formulation == ta_formulation)
            NameOfPostProcessing MagDyn_ta ;
        ElseIf(formulation == h_phi_ts_formulation)
            NameOfPostProcessing MagDyn_hphits ;
        EndIf
        Operation{
            Print[ b, OnElementsOf Omega, File "res/tmp_b", Format Gmsh,
                LastTimeStepOnly, AppendTimeStepToFileName] ;
        }
    }
}
