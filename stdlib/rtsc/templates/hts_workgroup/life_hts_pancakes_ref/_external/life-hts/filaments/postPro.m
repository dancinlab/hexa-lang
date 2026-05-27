clear all
nbTest = 29;
testname = cell(nbTest,1);

%testname{1} = 'tape_model';

%{
testname{1} = 'cond_mat_3D_super_I_mm_0p8';
testname{2} = 'cond_mat_2D_super_I_mm_0p8';
testname{3} = 'cond_mat_2D_super_I_mm_0p4';
testname{4} = 'cond_mat_2D_super_I_mm_1p0';
testname{5} = 'cond_mat_3D_super_I_mm_1p2';
testname{6} = 'cond_mat_3D_super_I_mm_0p6';
testname{7} = 'cond_mat_2D_super_I_mm_0p6';
testname{8} = 'cond_mat_2D_super_I_mm_0p8_sharing';
testname{9} = 'cond_mat_3D_super_I_mm_0p8_sharing';
%}
%%{
testname{10} = 'cond_mat_2D_copper_transverse_mm_0p8_newGeo';
testname{11} = 'cond_mat_3D_copper_transverse_mm_0p8_newGeo';
testname{12} = 'cond_mat_2D_super_I_mm_0p6_sharing_newGeo2';
testname{13} = 'cond_mat_3D_super_I_mm_0p8_sharing_newGeo2';
testname{14} = 'cond_mat_2D_super_I_mm_0p8_sharing_newGeo2';

testname{15} = 'cond_mat_test_structured';
testname{16} = 'cond_mat_test_structured_prisms';
testname{17} = 'cond_mat_test_unstructured';
%}
testname{18} = 'cond_mat_new_2D_1p2_super';
testname{19} = 'cond_mat_new_3D_structured_tetra_1p0_super';
testname{20} = 'cond_mat_new_2D_0p6_super';
testname{21} = 'fil_3D_1p5_condMat_structured';
testname{22} = 'cond_mat_new_2D_0p6_super_test';
testname{23} = 'fil_3D_1p0_condMat_structured';
testname{24} = 'cond_mat_new_3D_structured_prisms_1p3_super_new';
testname{25} = 'fil_3D_1p1_condMat_structured_prisms';
testname{26} = 'fil_3D_0p8_condMat_structured';
testname{27} = 'cond_mat_new_2D_0p8_super';
testname{28} = 'cond_mat_new_2D_1p0_super_I1p1';
testname{29} = 'fil_3D_0p8_condMat_structured_2';
%%{
testname{1} = 'transverse_2D_1p0';
testname{2} = 'transverse_3D_1p0';
%testname{1} = 'cond_mat_3D_copper_mm_0p8';
%testname{2} = 'cond_mat_2D_copper_mm_0p8';
testname{3} = 'cond_mat_3D_copper_transverse_mm_0p8';
testname{4} = 'cond_mat_3D_copper_transverse_mm_0p4';
testname{5} = 'cond_mat_2D_copper_transverse_mm_0p8';
testname{6} = 'cond_mat_2D_copper_transverse_mm_0p4';
testname{7} = 'cond_mat_2D_copper_transverse_mm_0p2';
testname{8} = 'cond_mat_3D_super_transverse_mm_0p8';
testname{9} = 'cond_mat_3D_super_transverse_mm_0p8';
%}

%{
testname{2} = 'twist_CORC_pitch30mm_80Imax';
testname{3} = 'twist_CORC_pitch55mm_80Imax';
testname{4} = 'twist_CORC_pitch88mm_80Imax';
testname{5} = 'twist_CORC_pitch183mm_80Imax';
testname{6} = 'twist_CORC_pitch500mm_80Imax';
testname{7} = 'twist_CORC_pitch55mm_80Imax_3D_test';
testname{8} = 'twist_CORC_pitch55mm_80Imax_coarse';
testname{9} = 'twist_CORC_pitchInf_80Imax_2D_test';
testname{10} = 'twist_CORC_pitchInf_80Imax_3D_test';
testname{11} = 'twist_CORC_pitchInf_80Imax_2D';
%}
%{
testname{1} = 'cond_mat_2D';
testname{2} = 'cond_mat_3D';
testname{3} = 'cond_mat_2D_fine';
testname{4} = 'cond_mat_2D_fine_test';
testname{5} = 'cond_mat_2D_coarse';
testname{6} = 'cond_mat_3D_coarse';
%}
%{
testname{2} = 'tapes_11_2nd';
testname{3} = 'tapes_11_3rd';
testname{4} = 'tapes_11_11th';
testname{5} = 'tapes_11_min';
%}
%{
testname{1} = 'full_sequential_h';
testname{2} = 'full_sequential_coupled';
testname{3} = 'full_sequential_a';
testname{4} = 'full_sequential_ta';
%}

%}


mu0 = 4*pi*1e-7;
savedPoints = 200;%200;
savedPointsFiber = 300;
iterationInfo = cell(nbTest,1);
residualInfo = cell(nbTest,1);
time = cell(nbTest,1);
appliedField = cell(nbTest,1);
b1 = cell(nbTest,1);
b2 = cell(nbTest,1);
b2_sin = cell(nbTest,1);
j = cell(nbTest,1);
avgMagn = cell(nbTest,1);
avgbz = cell(nbTest,1);
power = cell(nbTest,1);
%
%%
for res=3:nbTest
    infoIterationFile = ['res/',testname{res},'/iteration.txt'];
    infoResidualFile = ['res/',testname{res},'/residual.txt'];
    outputAppliedField = ['res/',testname{res},'/appliedField.txt'];
    outputMagnetization = ['res/',testname{res},'/avgMagn.txt'];
    outputbavg = ['res/',testname{res},'/avgb.txt'];
    %outputCurrent = ['res/jLine.txt'];
    outputCurrent = ['res/',testname{res},'/jLine.txt'];
    %outputMagInduction1 = ['res/bLine.txt'];
    outputMagInduction1 = ['res/',testname{res},'/bLine1.txt'];
    outputMagField1 = ['res/',testname{res},'/hLine1.txt'];
    outputMagInduction2 = ['res/',testname{res},'/bLine2.txt'];
    outputMagInduction2_sin = ['res/',testname{res},'/bLine2_sin.txt'];
    outputPower = ['res/',testname{res},'/power.txt'];
    outputRev = ['res/',testname{res},'/rev.txt'];
    outputIrrev = ['res/',testname{res},'/irrev.txt'];

    % Info on simulation
    iterationInfo{res} = load(infoIterationFile);
    residualInfo{res} = load(infoResidualFile);
    totalLinearSystems = length(residualInfo);
    % Physical results
    %%{
    if(exist(outputPower, 'file') == 2)
        power{res} = load(outputPower);
    end
    tmp = dlmread(outputAppliedField,'', 1, 0);
    time{res} = tmp(:,1);
    tmp = dlmread(outputAppliedField,'', 1, 0);
    appliedField{res} = tmp(:,2);

    %time{res} = power{res}(:,1);

    %rev{res} = load(outputRev);
    %irrev{res} = load(outputIrrev);
    %%{
    tmp1 = load(outputMagInduction1);
    tmp5 = load(outputMagField1);
    tmp4 = load(outputCurrent);
    tmp3 = load(outputMagInduction2);
    gridPoints1 = tmp5(1+(0:savedPoints-1)*length(time{res}),3:4);
    gridPoints2 = tmp3(1+(0:savedPoints-1)*length(time{res}),3:4);
    b1{res} = zeros(length(time{res}), savedPoints, 3);
    b2{res} = zeros(length(time{res}), savedPoints, 3);
    b2_sin{res} = zeros(length(time{res}), savedPoints, 3);
    h1{res} = zeros(length(time{res}), savedPoints, 3);
    j{res} = zeros(length(time{res}), savedPoints, 3);
    %%{
    for k=1:savedPoints
        b1{res}(:,k,:) = tmp1(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
        if(res>15)
            %j{res}(:,k,:) = tmp4(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
        end
        %h1{res}(:,k,:) = tmp5(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
        b2{res}(:,k,:) = tmp3(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
    end
    %}
    %{
    if(size(tmp4,1) == (savedPoints+1)*length(time{res}))
        for k=1:savedPoints
            %j{res}(:,k,:) = tmp4(1+(k-1)*length(time{res}):k*length(time{res}), 8);
        end
    else
        for t=1:length(time{res})-1
            b1{res}(t+1,:,:) = tmp1(1+(t-1)+(t-1)*savedPoints:t*savedPoints+(t-1), 6:8);
            b2{res}(t+1,:,:) = tmp3(1+(t-1)+(t-1)*savedPoints:t*savedPoints+(t-1), 6:8);
            j{res}(t+1,:,:) = tmp4(1+(t-1)+(t-1)*savedPoints:t*savedPoints+(t-1), 8);
        end
    end
    %}
    %{
    if(exist(outputMagnetization, 'file') == 2)
        tmp = load(outputMagnetization);
        avgMagn{res} = tmp(:,2:4);
    end
    if(exist(outputbavg, 'file') == 2)
        tmp = load(outputbavg);
        if(size(tmp,2) == 4)
            avgbz{res} = tmp(:,3);
        end
    end
    %}
    %tmp8 = load(outputMagInduction2_sin);
    %for k=1:savedPoints
    %    b2_sin{res}(:,k,:) = tmp8(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
    %end
    
    fprintf('%d is done\n', res);
end

%%
p = 0.1*1e-2;
h_3D = p/6;
id = 5;
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [15 5 30 20]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
%plot(1e3*power{1}(:,1), 1e-3*power{1}(:,id)./h_3D, 'b--', 'linewidth', 2);
%plot(1e3*power{2}(:,1), 1e-3*power{2}(:,id), 'color', [0 0.5 0.5], 'linewidth', 2);
%plot(1e3*power{1}(:,1), 1e-3*200*power{1}(:,id+1)./h_3D, 'r--', 'linewidth', 2);
%plot(1e3*power{2}(:,1), 1e-3*200*power{2}(:,id+1), '-', 'color', [1 0.5 0], 'linewidth', 2);
%plot(power{3}(:,1), power{3}(:,id), 'g-', 'linewidth', 2);
%plot(power{4}(:,1), power{4}(:,id), 'm-', 'linewidth', 2);
%plot(power{4}(:,1), power{4}(:,id)./h_3D, 'm-', 'linewidth', 2);
%plot(power{5}(:,1), power{5}(:,id)./h_3D, 'k-', 'linewidth', 2);
%plot(power{6}(:,1), power{6}(:,id)./h_3D, 'k-', 'linewidth', 2);
%plot(power{7}(:,1), power{7}(:,id), 'm-', 'linewidth', 2);
%plot(power{8}(:,1), power{8}(:,id), 'r-', 'linewidth', 2);
%plot(power{8}(:,1), 10*power{8}(:,id+1), 'r--', 'linewidth', 2);

%plot(power{9}(:,1), power{9}(:,id)./h_3D, 'k-', 'linewidth', 2);
%plot(power{9}(:,1), 10*power{9}(:,id+1)./h_3D, 'k--', 'linewidth', 2);

%plot(1000*power{10}(:,1), 1e-3*power{10}(:,id), 'g--', 'linewidth', 2);
%plot(power{10}(:,1), 0.25^2*100*1e3*power{10}(:,id+1), 'm', 'linewidth', 2);
%plot(power{11}(:,1), 0.25^2*1e3*power{11}(:,id+1)./h_3D, 'r', 'linewidth', 2);

%plot(power{15}(:,1), power{15}(:,id), 'r-', 'linewidth', 2);
%plot(power{16}(:,1), power{16}(:,id), 'b-', 'linewidth', 2);
%plot(power{17}(:,1), power{17}(:,id), 'k-', 'linewidth', 2);

%plot(1000*power{12}(:,1), 1e0*power{12}(:,id), 'g-', 'linewidth', 2);
%plot(1000*power{12}(:,1), 1e0*power{12}(:,id+1), 'm-', 'linewidth', 2);

%plot(1000*power{11}(:,1), 1e-3*power{11}(:,id)./h_3D, 'color', [0 0.5 0.5], 'linewidth', 1);
%plot(1000*power{11}(:,1), 1e-3*power{11}(:,id+1)./h_3D, 'color', [1 0.5 0], 'linewidth', 1);

%plot(1000*power{14}(:,1), 1e0*power{14}(:,id), '-', 'color', [0 0.5 0.5], 'linewidth', 1);
%plot(1000*power{14}(:,1), 1e0*power{14}(:,id+1), '-', 'color', [1 0.5 0], 'linewidth', 1);

%plot(1000*power{13}(:,1), 1e0*power{13}(:,id)./h_3D, 'color', [0 0.5 0.5], 'linewidth', 2);
%plot(1000*power{13}(:,1), 1e0*power{13}(:,id+1)./h_3D, 'color', [1 0.5 0], 'linewidth', 2);

%plot(1000*power{18}(:,1), 1e0*power{18}(:,id), '-', 'color', [0 0.5 0.5], 'linewidth', 1);
%plot(1000*power{18}(:,1), 1e0*power{18}(:,id+1), '-', 'color', [1 0.5 0], 'linewidth', 1);

%plot(1000*power{19}(:,1), 1e0*power{19}(:,id)./h_3D, '-', 'color', [0 0.5 0.5], 'linewidth', 1);
%plot(1000*power{19}(:,1), 1e0*power{19}(:,id+1)./h_3D, '-', 'color', [1 0.5 0], 'linewidth', 1);

%plot(1000*power{20}(:,1), 1e0*power{20}(:,id), '-', 'color', [0 0.5 0.5], 'linewidth', 2);
%plot(1000*power{20}(:,1), 1e0*power{20}(:,id+1), '-', 'color', [1 0.5 0], 'linewidth', 2);

plot(1000*power{21}(:,1), 1e0*power{21}(:,id)./h_3D, '--', 'color', [0 0.5 0.5], 'linewidth', 1);
plot(1000*power{21}(:,1), 1e0*power{21}(:,id+1)./h_3D, '--', 'color', [1 0.5 0], 'linewidth', 1);

plot(1000*power{22}(:,1), 1e0*power{22}(:,id), '-', 'color', [0 0.5 0.5], 'linewidth', 2);
plot(1000*power{22}(:,1), 1e0*power{22}(:,id+1), '-', 'color', [1 0.5 0], 'linewidth', 2);

plot(1000*power{27}(:,1), 1e0*power{27}(:,id), '-', 'color', [1 0.5 0.5], 'linewidth', 1);
plot(1000*power{27}(:,1), 1e0*power{27}(:,id+1), '-', 'color', [0 0.5 0], 'linewidth', 1);

%plot(1000*power{23}(:,1), 1e0*power{23}(:,id)./h_3D, '.-', 'color', [0 0.5 0.5], 'linewidth', 1);
%plot(1000*power{23}(:,1), 1e0*power{23}(:,id+1)./h_3D, '.-', 'color', [1 0.5 0], 'linewidth', 1);

%plot(1000*power{24}(:,1), 1e0*power{24}(:,id)./h_3D, '-', 'color', [0 0.5 0.5], 'linewidth', 1);
%plot(1000*power{24}(:,1), 1e0*power{24}(:,id+1)./h_3D, '-', 'color', [1 0.5 0], 'linewidth', 1);

plot(1000*power{25}(:,1), 1e0*power{25}(:,id)./h_3D, '-', 'color', [0.1 0.3 0.5], 'linewidth', 2);
plot(1000*power{25}(:,1), 1e0*power{25}(:,id+1)./h_3D, '-', 'color', [1 0.3 0.1], 'linewidth', 2);

plot(1000*power{26}(:,1), 1e0*power{26}(:,id)./h_3D, '--', 'color', [0 0.5 0.5], 'linewidth', 2);
plot(1000*power{26}(:,1), 1e0*power{26}(:,id+1)./h_3D, '--', 'color', [1 0.5 0], 'linewidth', 2);

%plot(1000*power{28}(:,1), 1e0*power{28}(:,id), '-', 'color', [1 0.5 0.5], 'linewidth', 1);
%plot(1000*power{28}(:,1), 1e0*power{28}(:,id+1), '-', 'color', [0 0.5 0], 'linewidth', 1);

plot(1000*power{29}(:,1), 1e0*power{29}(:,id)./h_3D, '--', 'color', [0 0.5 0.5], 'linewidth', 2);
plot(1000*power{29}(:,1), 1e0*power{29}(:,id+1)./h_3D, '--', 'color', [1 0.5 0], 'linewidth', 2);

%plot(power{7}(:,1), power{7}(:,id), 'g-', 'linewidth', 2);
%plot(power{8}(:,1), power{8}(:,id-1), 'c-', 'linewidth', 2);
%plot(power{5}(:,1), power{5}(:,id), 'm', 'linewidth', 1);
%plot(power{6}(:,1), power{6}(:,id)./h_3D, 'b', 'linewidth', 1);
grid on
%leg = legend('2D','3D','Location','north');
%set(leg,'Interpreter','latex')
%set(leg,'FontSize',22)
ylabel('Inst. power (kW/m)','Interpreter','latex','FontSize',22);
xlabel('Time (ms)','Interpreter','latex','FontSize',22);

%%

ti = 2;
comp = 2;
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [15 5 30 20]);
set(gca, 'fontsize',22);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
hold on
%plot(1000*gridPoints1(:,1), b2{1}(ti,:,comp) , 'r', 'linewidth', 2);
%plot(1000*gridPoints1(:,1), b2{1}(ti,:,3) , '--r', 'linewidth', 2);

%plot(gridPoints1(:,1), j{2}(ti,:) , 'r', 'linewidth', 2);
%plot(gridPoints1(:,1), j{3}(ti,:) , 'g', 'linewidth', 1);

%plot(1e6*gridPoints1(:,1), b2{14}(ti,:,2) , '--b', 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), b2{14}(ti,:,3) , '--r', 'linewidth', 2);

%plot(1e6*gridPoints1(:,1), b2{13}(ti,:,comp) , 'color', [0 0.5 0.5], 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), b2{13}(ti,:,3) , 'color', [1 0.5 0], 'linewidth', 2);

%plot(1e6*gridPoints1(:,1), b2{19}(ti,:,2) , '--b', 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), b2{19}(ti,:,3) , '--r', 'linewidth', 2);

%plot(1e6*gridPoints1(:,1), b2{18}(ti,:,comp) , 'color', [0 0.5 0.5], 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), b2{18}(ti,:,3) , 'color', [1 0.5 0], 'linewidth', 2);

%plot(1e6*gridPoints1(:,1), b2{22}(30,:,2) , '-b', 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), b2{22}(30,:,3) , '-r', 'linewidth', 2);

%plot(1e6*gridPoints1(:,1), b2{26}(30,:,2) , '--b', 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), b2{26}(30,:,3) , '--r', 'linewidth', 2);

%plot(1e6*gridPoints1(:,1), -b2{23}(30,:,2) , '--b', 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), -b2{23}(30,:,3) , '--r', 'linewidth', 2);

%plot(1e6*gridPoints1(:,1), b2{25}(30,:,2) , '--b', 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), b2{25}(30,:,3) , '--r', 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), j{19}(ti,:,2) , '--b', 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), j{19}(ti,:,3) , '--r', 'linewidth', 2);

%plot(1e6*gridPoints1(:,1), j{18}(ti,:,2) , 'color', [0 0.5 0.5], 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), j{18}(ti,:,3) , 'color', [1 0.5 0], 'linewidth', 2);

%plot(1000*gridPoints2(:,1), b2{8}(ti,:,comp) , 'k', 'linewidth', 2);
%plot(1000*gridPoints2(:,1), b2{8}(ti,:,3) , '--k', 'linewidth', 2);

%plot(1000*gridPoints2(:,1), b2{4}(ti,:,2) , 'm', 'linewidth', 2);
%plot(1000*gridPoints2(:,1), b2{4}(ti,:,3) , '--m', 'linewidth', 2);

%plot(1000*gridPoints2(:,1), -b2{9}(ti,:,2) , 'r', 'linewidth', 2);
%plot(1000*gridPoints2(:,1), -b2{9}(ti,:,3) , '--r', 'linewidth', 2);

plot(1e6*gridPoints2(:,1), b2{1}(ti,:,1) , 'b', 'linewidth', 2);
plot(1e6*gridPoints2(:,1), b2{1}(ti,:,2) , 'r', 'linewidth', 2);
plot(1e6*gridPoints2(:,1), b2{1}(ti,:,3) , 'k', 'linewidth', 2);

%plot(1e6*gridPoints2(:,1), b2_sin{1}(ti,:,1) , 'b', 'linewidth', 1);
%plot(1e6*gridPoints2(:,1), b2_sin{1}(ti,:,2) , 'r', 'linewidth', 1);
%plot(1e6*gridPoints2(:,1), b2_sin{1}(ti,:,3) , 'k', 'linewidth', 1);

plot(1e6*gridPoints2(:,1), b2{2}(ti,:,1) , '--b', 'linewidth', 2);
plot(1e6*gridPoints2(:,1), b2{2}(ti,:,2) , '--r', 'linewidth', 2);
plot(1e6*gridPoints2(:,1), b2{2}(ti,:,3) , '--k', 'linewidth', 2);
%plot(1e6*gridPoints1(:,1), b2{3}(ti,:,2) , 'g', 'linewidth', 2);
%plot(1e6*gridPoints2(:,1), b2{4}(ti,:,2) , 'r', 'linewidth', 2);

%plot(1000*gridPoints2(:,1), b2{4}(ti,:,3) , 'r', 'linewidth', 2);
%plot(1000*gridPoints2(:,1), b2{6}(ti,:,2) , 'm', 'linewidth', 2);
%plot(1000*gridPoints2(:,1), b2{6}(ti,:,3) , 'm', 'linewidth', 2);

plot(10*[6.3 6.3], [-1, 1], 'color', [0.7 0.7 0.7], 'linewidth', 2);
plot(10*[13.3 13.3], [-1, 1], 'color', [0.7 0.7 0.7], 'linewidth', 2);
plot(10*[15.5 15.5], [-1, 1], 'color', [0.7 0.7 0.7], 'linewidth', 2);


ylim([-0.1, 0.2]);
%leg = legend('3D $b_y$', '3D $b_z$', '2D $b_y$', '2D $b_z$','Location','northeast');
%set(leg,'Interpreter','latex')
%set(leg,'FontSize',22)
ylabel('Flux density (T)','Interpreter','latex','FontSize',22);
xlabel('Position $x$ (mm)','Interpreter','latex','FontSize',22);
grid on 

%%
%{
ti = 30;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/verifB_super_fine.txt','w');
fprintf(fileName, 'r by_3D bz_3D by_2D bz_2D\n');
for r = 1:savedPoints
    fprintf(fileName, '%g %g %g %g %g\n', ...
        1e6*gridPoints1(r,1), b2{26}(ti,r,2), ...
        b2{26}(ti,r,3), b2{22}(ti,r,2), b2{22}(ti,r,3));
end
fclose(fileName);
%}

%{
ti = 2;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/transverse_b_line_verif.txt','w');
fprintf(fileName, 'r bx_3D by_3D bz_3D bx_2D by_2D bz_2D\n');
for r = 1:savedPoints
    fprintf(fileName, '%g %g %g %g %g %g %g\n', ...
        1e6*gridPoints1(r,1), b2{2}(ti,r,1), b2{2}(ti,r,2), ...
        b2{2}(ti,r,3), b2{1}(ti,r,1), b2{1}(ti,r,2), b2{1}(ti,r,3));
end
fclose(fileName);
%}

%{
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/filament_AC_losses.txt','w');
fprintf(fileName, 't hts_3D_coarse copper_3D_coarse hts_2D_coarse copper_2D_coarse hts_3D_fine copper_3D_fine hts_2D_fine copper_2D_fine\n');
for r = 1:length(power{21}(:,1))
    fprintf(fileName, '%g %g %g %g %g %g %g %g %g\n', ...
        power{21}(r,1), ...
        1e3*power{21}(r,5)./h_3D, 1e3*power{21}(r,6)./h_3D, ...
        1e3*power{27}(r,5), 1e3*power{27}(r,6), ...
        1e3*power{25}(r,5)./h_3D, 1e3*power{25}(r,6)./h_3D, ...
        1e3*power{22}(r,5), 1e3*power{22}(r,6));
end
fclose(fileName);
%}

%{
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/filament_AC_losses_fine.txt','w');
fprintf(fileName, 't hts_3D_fine copper_3D_fine\n');
for r = 1:length(power{29}(:,1))
    fprintf(fileName, '%g %g %g\n', ...
        power{29}(r,1), ...
        1e3*power{29}(r,5)./h_3D, 1e3*power{29}(r,6)./h_3D);
end
fclose(fileName);
%}

%{
fileName = fopen('~/Dropbox/Thesis_Reports/Compumag2022_posters/verifACloss_transverse2.txt','w');
fprintf(fileName, 't 3D 2D\n');
for r = 1:length(power{10}(:,1))
    fprintf(fileName, '%g %g %g\n', ...
        power{10}(r,1), 0.25^2*1e3*power{11}(r,6)./h_3D, ...
        0.25^2*100*1e3*power{10}(r,6));
end
fclose(fileName);
%}


%%

savedPointsFiber = 306;

jc = 7e9;
test = 16;
clear bFiber jFiber;
bFiber = zeros(length(time{test}), savedPointsFiber, 3);
jFiber = zeros(length(time{test}), savedPointsFiber, 3);
outputMagInduction1 = ['res/',testname{test},'/bLine1.txt'];
outputCurrent = ['res/',testname{test},'/jLine.txt'];
tmp1 = load(outputMagInduction1);
tmp4 = load(outputCurrent);
for k=1:savedPointsFiber
        bFiber(:,k,:) = tmp1(1+(k-1)*length(time{test}):k*length(time{test}), 6:8);
        jFiber(:,k,:) = tmp4(1+(k-1)*length(time{test}):k*length(time{test}), 6:8);
end
pts = tmp4(1+(0:savedPointsFiber-1)*length(time{test}),3:5);


geoFactor = 1e-2;
p = 0.1*geoFactor;
h = p/6;
z = [pts(1:51,3)' pts(1:51,3)'+pts(51,3) pts(1:51,3)'+2*pts(51,3) ...
    pts(1:51,3)'+3*pts(51,3) pts(1:51,3)'+4*pts(51,3) pts(1:51,3)'+5*pts(51,3)]; % 0:p/299:p;
t = 6;
cp = 1;
FilamentRadius = 0.0035*geoFactor;
LayerRadius_1 = 2.8*FilamentRadius;
r_sample = LayerRadius_1+FilamentRadius*0.8;
alpha = 2*pi/p;
theta0 = 0*pi/50;

x = @(z) r_sample * cos(alpha*z+theta0);
y = @(z) r_sample * sin(alpha*z+theta0);
xi_1 = @(z) x(z)*cos(alpha*z)+y(z)*sin(alpha*z);
xi_2 = @(z) -x(z)*sin(alpha*z)+y(z)*cos(alpha*z);
Jtrans = @(z) [cos(alpha*z) sin(alpha*z) 0
    -sin(alpha*z) cos(alpha*z) 0
    -alpha*y(z) alpha*x(z) 1]; 

Jinv = @(z) [cos(alpha*z) sin(alpha*z) alpha*xi_2(z)
    -sin(alpha*z) cos(alpha*z) -alpha*xi_1(z)
    0 0 1];


clear b1_xi j_yCst_xi j_xi
for i=1:savedPointsFiber
    b_tmp = permute(bFiber,[3 1 2]);
    j_tmp = permute(jFiber,[3 1 2]);
    b1_xi(:,i,:) = permute(Jtrans(z(i)) * b_tmp(:,:,i),[3 2 1]);
    b_yCst_xi(i,:) = Jtrans(z(i)) * [0 1 0]';
    j_xi(:,i,:) = permute(Jinv(z(i)) * j_tmp(:,:,i),[3 2 1]);
    %b_yCst_xi(i,:) = Jinv(z(i)) * [0 1 0]';
end

%


figure;
subplot(211);
title('Unstructured')
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [20*test-10 15 20 35]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on

plot(z,bFiber(t,:,cp), 'r-', 'linewidth', 1);
plot(z,bFiber(t,:,cp+1), 'b-', 'linewidth', 1);
plot(z,bFiber(t,:,cp+2), 'k-', 'linewidth', 1);

plot(z,b1_xi(t,:,cp), 'r-', 'linewidth', 2);
plot(z,b1_xi(t,:,cp+1), 'b-', 'linewidth', 2);
plot(z,b1_xi(t,:,cp+2), 'k-', 'linewidth', 2);

%plot(z,b_yCst_xi(:,cp), 'r-', 'linewidth', 1);
%plot(z,b_yCst_xi(:,cp+1), 'b-', 'linewidth', 1);
%plot(z,b_yCst_xi(:,cp+2), 'k-', 'linewidth', 1);
%{
pt_2D = 64;
b_cos = [b2{1}(t,pt_2D,1)
    b2{1}(t,pt_2D,2)
    b2{1}(t,pt_2D,3)];
b_sin = [b2_sin{1}(t,pt_2D,1)
b2_sin{1}(t,pt_2D,2)
    b2_sin{1}(t,pt_2D,3)];

b_cos_xi = Jtrans(0) * b_cos;
b_sin_xi = Jtrans(0) * b_sin;



for i=1:savedPointsFiber
    b_xi_2D = [b_cos_xi(1)*cos(alpha*z(i))+b_sin_xi(1)*sin(alpha*z(i))
        b_cos_xi(2)*cos(alpha*z(i))+b_sin_xi(2)*sin(alpha*z(i))
        b_cos_xi(3)*cos(alpha*z(i))+b_sin_xi(3)*sin(alpha*z(i))];
    b_x_2D(:,i) = Jinv(z(i))' * b_xi_2D;
end

mult = 1.05;
plot(z,mult*(b_cos_xi(1)*cos(alpha*z)+b_sin_xi(1)*sin(alpha*z)), 'r--', 'linewidth', 2);
plot(z,mult*(b_cos_xi(2)*cos(alpha*z)+b_sin_xi(2)*sin(alpha*z)), 'b--', 'linewidth', 2);
plot(z,mult*(b_cos_xi(3)*cos(alpha*z)+b_sin_xi(3)*sin(alpha*z)), 'k--', 'linewidth', 2);

plot(z,mult*b_x_2D(1,:), 'r--', 'linewidth', 2);
plot(z,mult*b_x_2D(2,:), 'b--', 'linewidth', 2);
plot(z,mult*b_x_2D(3,:), 'k--', 'linewidth', 2);
%}

%plot(z,0.1+0.1*cos(2*alpha*z), 'm-', 'linewidth', 2);
%plot(z,0.2*cos(alpha*z)+0.05*cos(3*alpha*z), 'm-', 'linewidth', 2);
%plot(gridPoints1(:,1), -b1{2}(t,:,cp), 'k-.', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{3}(t,:,cp), 'r-', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{4}(t,:,cp), 'k-', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{5}(t,:,cp), 'm', 'linewidth', 1);
%plot(gridPoints1(:,1), b1{6}(t,:,cp), 'b', 'linewidth', 1);
grid on
ylabel('Flux density (T)','Interpreter','latex','FontSize',22);
%ylim([-0.1, 0.12]);
%
%figure;
subplot(212);

set(gcf, 'Units', 'centimeters');
%set(gcf, 'Position', [20*test-10 0 20 15]);
set(gca, 'fontsize',18);

set(gca, 'fontname','Timesnewroman');
box('on');
hold on



%plot(z,b1{1}(t,:,cp), 'r-', 'linewidth', 1);
%plot(z,b1{1}(t,:,cp+1), 'b-', 'linewidth', 1);
%plot(z,b1{1}(t,:,cp+2), 'k-', 'linewidth', 1);

%plot(z,jFiber(t,:,cp), 'r-', 'linewidth', 1);
%plot(z,jFiber(t,:,cp+1), 'b-', 'linewidth', 1);
%plot(z,jFiber(t,:,cp+2), 'k-', 'linewidth', 1);

plot(z,j_xi(t,:,cp), 'r-', 'linewidth', 2);
plot(z,j_xi(t,:,cp+1), 'b-', 'linewidth', 2);
plot(z,j_xi(t,:,cp+2), 'k-', 'linewidth', 2);

%plot(z,sqrt(j_xi(t,:,cp).^2+j_xi(t,:,cp+1).^2+j_xi(t,:,cp+2).^2), 'm--', 'linewidth', 2);

%plot(z,b_yCst_xi(:,cp), 'r-', 'linewidth', 1);
%plot(z,b_yCst_xi(:,cp+1), 'b-', 'linewidth', 1);
%plot(z,b_yCst_xi(:,cp+2), 'k-', 'linewidth', 1);

%plot(z,0.18*cos(alpha*z), 'm-', 'linewidth', 2);
%plot(z,0.14*cos(alpha*z), 'k-', 'linewidth', 2);
%plot(z,0.1+0.1*cos(2*alpha*z), 'm-', 'linewidth', 2);


%plot(z,1.4e8*cos(alpha*(z+0.004))-2.4e7*cos(3*alpha*(z+0.004)), 'm-', 'linewidth', 2);


%plot(gridPoints1(:,1), -b1{2}(t,:,cp), 'k-.', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{3}(t,:,cp), 'r-', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{4}(t,:,cp), 'k-', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{5}(t,:,cp), 'm', 'linewidth', 1);
%plot(gridPoints1(:,1), b1{6}(t,:,cp), 'b', 'linewidth', 1);
ylim([-8e9, 8e9]);
ylabel('Current density (A/m2)','Interpreter','latex','FontSize',22);
grid on


%%

%{
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/filament_verif_helicoidal_3D.txt','w');
fprintf(fileName, 'z bx by bz bxi1 bxi2 bxi3 jx jy jz jxi1 jxi2 jxi3 \n');
for r = 1:savedPointsFiber
    fprintf(fileName, '%g %g %g %g %g %g %g %g %g %g %g %g %g\n', ...
        1000*z(r), bFiber(t,r,cp), bFiber(t,r,cp+1), bFiber(t,r,cp+2), ...
        b1_xi(t,r,cp), b1_xi(t,r,cp+1), b1_xi(t,r,cp+2), ...
        jFiber(t,r,cp)/jc, jFiber(t,r,cp+1)/jc, jFiber(t,r,cp+2)/jc, ...
        j_xi(t,r,cp)/jc, j_xi(t,r,cp+1)/jc, j_xi(t,r,cp+2)/jc);
end
fclose(fileName);
%}

t = 2;
%{
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/filament_verif_helicoidal_3D_transverse.txt','w');
fprintf(fileName, 'z bx by bz bxi1 bxi2 bxi3 bx_2D by_2D bz_2D bxi1_2D bxi2_2D bxi3_2D\n');
for r = 1:savedPointsFiber
    fprintf(fileName, '%g %g %g %g %g %g %g %g %g %g %g %g %g\n', ...
        1000*z(r), bFiber(t,r,cp), bFiber(t,r,cp+1), bFiber(t,r,cp+2), ...
        b1_xi(t,r,cp), b1_xi(t,r,cp+1), b1_xi(t,r,cp+2), ...
        mult*b_x_2D(1,r), mult*b_x_2D(2,r), mult*b_x_2D(3,r), ...
        mult*(b_cos_xi(1)*cos(alpha*z(r))+b_sin_xi(1)*sin(alpha*z(r))), ...
        mult*(b_cos_xi(2)*cos(alpha*z(r))+b_sin_xi(2)*sin(alpha*z(r))), ...
        mult*(b_cos_xi(3)*cos(alpha*z(r))+b_sin_xi(3)*sin(alpha*z(r))));
end
fclose(fileName);
%}

t = 6;
%{
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/filament_helicoidal_3D_transverse_super.txt','w');
fprintf(fileName, 'z bx by bz bxi1 bxi2 bxi3 jx jy jz jxi1 jxi2 jxi3 \n');
for r = 1:savedPointsFiber
    fprintf(fileName, '%g %g %g %g %g %g %g %g %g %g %g %g %g\n', ...
        1000*z(r), bFiber(t,r,cp), bFiber(t,r,cp+1), bFiber(t,r,cp+2), ...
        b1_xi(t,r,cp), b1_xi(t,r,cp+1), b1_xi(t,r,cp+2), ...
        jFiber(t,r,cp)/jc, jFiber(t,r,cp+1)/jc, jFiber(t,r,cp+2)/jc, ...
        j_xi(t,r,cp)/jc, j_xi(t,r,cp+1)/jc, j_xi(t,r,cp+2)/jc);
end
fclose(fileName);
%}

%%

ft_j_xi = fft(j_xi(t,:,cp+2));
ft_b_xi_1 = fft(b1_xi(t,:,1));
ft_b_xi_2 = fft(b1_xi(t,:,2));
ft_b_xi_3 = fft(b1_xi(t,:,3));

Y_1 = ft_b_xi_1;
Y_2 = ft_b_xi_2;
Y_3 = ft_b_xi_3;

L = 306;
T = 0.1;
Fs = L/0.1;
P2_1 = abs(Y_1/L);
P1_1 = P2_1(1:L/2+1);
P1_1(2:end-1) = 2*P1_1(2:end-1);

P2_2 = abs(Y_2/L);
P1_2 = P2_2(1:L/2+1);
P1_2(2:end-1) = 2*P1_2(2:end-1);

P2_3 = abs(Y_3/L);
P1_3 = P2_3(1:L/2+1);
P1_3(2:end-1) = 2*P1_3(2:end-1);

f = Fs*(0:(L/2))/L;

figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [20*test-10 15 20 15]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
plot(f, P1_1, 'r-', 'linewidth', 2);
plot(f, P1_2, 'g-', 'linewidth', 2);
plot(f, P1_3, 'b-', 'linewidth', 2);
grid on
%%


fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/filament_helicoidal_3D_transverse_super_fft.txt','w');
fprintf(fileName, 'k b1k b2k b3k\n');
for r = 1:20
    fprintf(fileName, '%g %g %g %g\n', ...
        r-1, P1_1(r), P1_2(r), P1_3(r));
end
fclose(fileName);


%%
for ti=1:size(b2{4},1)
    flux(ti) = trapz(gridPoints2(:,1), b2{4}(ti,:,2),2);
    if ti==2
        dflux(ti-1) = (flux(ti)-flux(ti-1))/(power{4}(ti-1,1));     
    elseif ti>2
        dflux(ti-1) = (flux(ti)-flux(ti-1))/(power{4}(ti-1,1)-power{4}(ti-2,1));
    end
end
%%
clear V_n I_n_1
V_n = power{2}(:,7);
I_n = power{2}(:,8);
n=length(V_n);
I_n_1(1) = 0;
I_n_1(2:n+1) = I_n;
%I_n_1 = I_n_1';

VI_corrected = V_n .* ( I_n+I_n_1(1:n)' )./2;




%% ABSTRACT COMPUMAG

LayerRadius_1 = 0.00514;

wantedTheta = 47;
2*pi*LayerRadius_1*tan((90-wantedTheta)/180 * pi);

%
pitch = [0.02, 0.03, 0.055, 0.088, 0.188, 0.5];
theta = atan(pitch/(2*pi*LayerRadius_1));
test = 1;
unit = 1;
V = power{1}(:,7); 
I = power{1}(:,8);
id = 4;
id2 = 8;
%
%V2 = power{2}(:,7); 
%I2 = power{2}(:,8);
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [15 5 30 20]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
%plot(time{1}, javgrel, '-o', 'linewidth', 2);
%plot(time{1}(2:length(time{1})), (power{1}(:,3)+power{1}(:,5)-power{1}(:,4)), '-o', 'linewidth', 2);
%plot(power{1}(:,5), 'b-o', 'linewidth', 2);

%plot(time{1}(2:length(time{1})), cumsum(power{1}(:,5)), 'b-o', 'linewidth', 2);
%plot(unit*power{1}(:,1), cumsum(power{1}(:,id)), '-', 'linewidth', 2);
%plot(unit*power{1}(:,1), (power{1}(:,2)), '-', 'linewidth', 2);
%%{
%plot(unit*power{1}(:,1), (power{1}(:,5))*sin(theta(1)), 'k-', 'linewidth', 2);
%plot(unit*power{2}(:,1), (power{2}(:,5))*sin(theta(2)), 'r-', 'linewidth', 2);
plot(unit*power{3}(:,1), (power{3}(:,5))*sin(theta(3)), 'g-', 'linewidth', 2);
%plot(unit*power{4}(:,1), (power{4}(:,5))*sin(theta(4)), 'm-', 'linewidth', 2);
%plot(unit*power{5}(:,1), (power{5}(:,5))*sin(theta(5)), 'c-', 'linewidth', 1);
%plot(unit*power{6}(:,1), (power{6}(:,5))*sin(theta(6)), 'k-', 'linewidth', 3);
%}
plot(unit*power{7}(:,1), (power{7}(:,5)/0.01*sin(theta(3))), 'r-', 'linewidth', 2);
%plot(unit*power{9}(:,1), (power{9}(:,5))/0.02795*sin(theta(3)), 'r-', 'linewidth', 3);
plot(unit*power{10}(:,1), (power{10}(:,5))/0.005, 'k-', 'linewidth', 2);
%plot(unit*power{11}(:,1), (power{11}(:,5)), 'o-', 'linewidth', 2);
plot(unit*power{9}(:,1), (power{9}(:,5)), 'y-', 'linewidth', 2);

%plot(unit*power{10}(:,1), (power{10}(:,8)), 'k-', 'linewidth', 2);
%plot(unit*power{11}(:,1), (power{11}(:,8)), 'o-', 'linewidth', 1);

%{
plot(unit*power{1}(:,1), (power{1}(:,5)), 'k-', 'linewidth', 2);
plot(unit*power{2}(:,1), (power{2}(:,5)), 'r-', 'linewidth', 2);
plot(unit*power{3}(:,1), (power{3}(:,5)), 'g-', 'linewidth', 2);
plot(unit*power{4}(:,1), (power{4}(:,5)), 'm-', 'linewidth', 2);
plot(unit*power{5}(:,1), (power{5}(:,5)), 'c-', 'linewidth', 1);
plot(unit*power{6}(:,1), (power{6}(:,5)), 'y-', 'linewidth', 1);
%}

%plot(unit*power{2}(:,1), 0.1*(power{2}(:,6)), 'r--', 'linewidth', 2);
%plot(unit*power{3}(:,1), 0.1*(power{3}(:,5)), 'g-', 'linewidth', 2);
%plot(unit*power{3}(:,1), 0.1*(power{3}(:,6)), 'g--', 'linewidth', 2);
%plot(unit*power{4}(:,1), 0.1*(power{4}(:,5)), 'm-', 'linewidth', 2);
%plot(unit*power{4}(:,1), 0.1*(power{4}(:,6)), 'm--', 'linewidth', 2);
%}
%plot(unit*power{5}(:,1), 0.1*(power{3}(:,5)), 'g-', 'linewidth', 2);
%plot(unit*power{5}(:,1), (power{5}(:,6)), 'k--', 'linewidth', 2);
%plot(unit*power{6}(:,1), 0.1*(power{6}(:,6)), 'm--', 'linewidth', 2);
%plot(unit*power{8}(:,1), (power{8}(:,6)), 'k-', 'linewidth', 2);
%plot(unit*power{9}(:,1), 0.05*(power{9}(:,6)), 'm-', 'linewidth', 2);
%plot(unit*power{2}(:,1), (power{2}(:,4)), 'g--', 'linewidth', 2);
%plot(mu0*avgMagn{1}(:,2), 'linewidth', 2);
%plot(unit*power{3}(:,1), cumsum(power{3}(:,id)), '-', 'linewidth', 2);
%plot(unit*power{3}(:,1), cumsum(power{3}(:,6)), '-', 'linewidth', 2);
%plot(unit*power{4}(:,1), cumsum(power{4}(:,id)), '-', 'linewidth', 2);
%plot(unit*power{4}(:,1), cumsum(power{4}(:,6)), '-', 'linewidth', 2);
%plot(unit*power{2}(:,1), power{2}(:,id), 'k-', 'linewidth', 2);
%plot(unit*power{3}(:,1), power{3}(:,id), 'g-', 'linewidth', 2);
%plot(unit*power{4}(:,1), power{4}(:,id), 'm-', 'linewidth', 2);
%plot(unit*power{1}(:,1), -power{1}(:,7).*power{1}(:,8), '--', 'linewidth', 2);
%plot(unit*power{2}(:,1), -cumsum(power{2}(:,7).*power{2}(:,8)), 'k--', 'linewidth', 2);
%plot(unit*power{4}(:,1), -0.125*cumsum(power{4}(:,7).*power{4}(:,8)), 'g--', 'linewidth', 2);
%plot(unit*power{2}(:,1), -cumsum(VI_corrected), 'r--', 'linewidth', 2);
%plot(unit*power{4}(:,1), power{4}(:,id)', 'r--', 'linewidth', 2);
%plot(1000*power{4}(:,1), power{4}(:,7)-dflux', 'r-', 'linewidth', 2);
%leg = legend('$h$', '$h$-$a$', '$a$', '$t$-$a$', '$t$-$a$ corrected','Location','northwest');
%set(leg,'Interpreter','latex')
%set(leg,'FontSize',22)
%ylabel('"Voltage" [V]','Interpreter','latex','FontSize',22);
%xlabel('Time [ms]','Interpreter','latex','FontSize',22);
grid on

%plot(time{test+12}(2:length(time{test+12})), cumsum(power{test+12}(:,5)), 'k-o', 'linewidth', 2);
%plot(time{1}(2:length(time{1})), 1/0.01*V, '-o', 'linewidth', 2);
%plot(time{1}(2:length(time{1})), 1/0.01*V2, '-', 'linewidth', 2);
%plot(time{1}(2:length(time{1})), 0.03*I, 'r-o', 'linewidth', 2);
%plot(time{1}(2:length(time{1})), cumsum(-I.*V), 'k-o', 'linewidth', 2);
%plot(time{1}(2:length(time{1})), cumsum(-I2.*V2), 'b-o', 'linewidth', 2);
grid on 

%%
nb = 6;
loss = cell(nb,1);
for i = 1:nb
    loss{i} = trapz(power{i}(:,1), power{i}(:,5))*sin(theta(i));
end

%{
fileName = fopen('~/Dropbox/Thesis_Reports/Abstract_COMPUMAG2021/data/totalLoss.txt','w');
fprintf(fileName, 'theta totalLoss\n');
for te = 1:6
    fprintf(fileName, '%g %g\n', ...
        90-180*theta(te)/pi, loss{te});
end
fclose(fileName);
%}

%%
%{
test = 6;
fileName = fopen('~/Dropbox/Thesis_Reports/Abstract_COMPUMAG2021/data/ACloss_500mm_80Imax.txt','w');
fprintf(fileName, 'time powerHTS\n');
for te = 1:length(power{test}(:,test))
    fprintf(fileName, '%g %g\n', ...
        power{test}(te,1), power{test}(te,5)*sin(theta(test)));
end
fclose(fileName);
%}


%%
sum(-power{1}(:,7).*power{1}(:,8))
sum(power{1}(:,id))

%%
theta = atan2(gridPoints2(:,2),gridPoints2(:,1));
bx = b2{1}(:,:,1);
by = b2{1}(:,:,2);
bn = bx'.*cos(theta) + by'.*sin(theta);
%
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [5 5 40 20]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
%hold on
test=1;

%plot(gridPoints1(:,1), b1{1}(3,:,2), 'color', [0.29, 0.494, 0.737], 'linewidth', 3);
%for t=1:length(time{1})
hold on
    plot(theta, bn(:,2:2:9), 'linewidth', 1);
    %plot(gridPoints1(:,1), b2{test}(41,:,2), 'b', 'linewidth', 1);
    %plot(gridPoints1(:,1), b2{test}(61,:,2), 'g', 'linewidth', 1);
    %plot(gridPoints1(:,1), b2{test+2}(6,:,2), 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), b2{test+2}(11,:,2), 'b', 'linewidth', 2);
    %plot(gridPoints1(:,1), b2{test+2}(16,:,2), 'g', 'linewidth', 2);

    hold on
    %plot(gridPoints1(:,1), b1{test+4}(t,:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 2);
    hold off
    %ylim([-12,12]);
%    pause(0.02)
%end
    %plot(gridPoints1(:,1), b1{6}(length(time{6}),:,2), 'color', [0.745, 0.29, 0.282], 'linewidth', 3);
%plot(gridPoints1(:,1), b1{7}(length(time{7}),:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 3);
%plot(gridPoints1(:,1), b1{8}(length(time{8}),:,2), 'color', [0.49, 0.376, 0.627], 'linewidth', 3);
hold off
%xlim([0.00,6]);
hold off
grid on;
hold off

%%
test = 1;
interval = 101:200;
W = 12e-3;
H = 1e-6;
a = 10e-3;
jc = 2.5e10;
I = sum(j{1}, 2) * W/savedPoints * H;
javgrel = I/(W*H*jc);
F = 0.9;
norris = ((1-F) * log(1-F) + (1+F) * log(1+F) - F^2) * (W*H*jc)^2*4e-7*pi/pi
%norrisCylinder = (jc*pi*a^2)^2 * mu0 / pi * ((1-F)*log(1-F) + (2-F)*F/2)
dissPower = trapz(time{test}(interval), power{test}(interval,5))
dissPowerGlobal = -trapz(time{test}(interval), power{test}(interval,6))
%dissPowerGlobal2 = -trapz(time{test}(interval), power{test}(interval,7).*power{test}(interval,8))


%%



DOFs = [7029 4421 2775 1797 6729 4217 2623 1673];
for test = 1:nbTest
    dissPower(test) = trapz(time{test}(interval), power{test}(interval,5));
end

ref = (dissPower(1)+dissPower(5)) * 0.5;

figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [25 5 30 25]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
plot(DOFs(1:4), 100*(dissPower(1:4)-ref)/ref, 'ro-', 'linewidth', 2);
plot(DOFs(5:8), 100*(dissPower(5:8)-ref)/ref, 'go-', 'linewidth', 2);

%xlim([0, 12.5]);
%set(gca, 'YScale', 'log')
%set(gca, 'XScale', 'log')
%ylim([-4, 4]);
hold off
grid on;
hold off

%{
fileName = fopen('~/Dropbox/Applications/ShareLaTex/Thesis_Reports/data/convTape.txt','w');
fprintf(fileName, 'dofsH powerH dofsA powerA\n');
for te = 1:4
    fprintf(fileName, '%g %g %g %g\n', ...
        DOFs(te), 100*(dissPower(te)-ref)/ref, ...
        DOFs(4+te), 100*(dissPower(te+4)-ref)/ref);
end
fclose(fileName);
%}



%%
%%{
fileName = fopen('~/Dropbox/Applications/ShareLaTex/Thesis_Reports/data/verifBulkB_a.txt','w');
fprintf(fileName, 'r t1 t2 t3\n');
for r = 1:5:2000
    fprintf(fileName, '%g %g %g %g\n', ...
        1000*gridPoints1(r,1), b2{3}(6,r,2), ...
        b2{3}(11,r,2), b2{3}(16,r,2));
end
fclose(fileName);
%}


%%
hnorm = (h1{1}(:,:,1).^2 + h1{1}(:,:,2).^2 + h1{1}(:,:,3).^2).^(1/2);
bnorm = (b1{1}(:,:,1).^2 + b1{1}(:,:,2).^2 + b1{1}(:,:,3).^2).^(1/2);


htob = [    0 0
    16 0.2396734
    28.4524706 0.4005216
    50.5964426 0.7516608
    89.974612 1.3188504
    160 1.6699861
    284.5247056 1.8758628
    505.9644256 2.0244918
    899.7461203 2.1171384
    1600 2.1852604
    2845.2470561 2.2303584
    5059.6442563 2.2577813
    8997.461203 2.2784831
    16000 2.2969536
    28452.4705606 2.3128066
    47961.6039073 2.3373225];


figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [15 5 30 20]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
%hold on
test=1;
nu0 = 1/mu0;
pt = 80;
hold on
%plot(gridPoints1(:,1), b1{1}(3,:,2), 'color', [0.29, 0.494, 0.737], 'linewidth', 3);
%for t=25:25%length(time{1})
    %plot(gridPoints1(:,1), j{4}(6,:)/2.5e10, 'color', [0.29, 0.494, 0.737], 'linewidth', 3);
    %plot(gridPoints1(:,1), j{1}(3,:)/2.5e10, 'color', [0.29, 0.494, 0.737], 'linewidth', 3);
    %plot(gridPoints1(:,1), j{2}(3,:)/2.5e10, 'color', 'r', 'linewidth', 3);
    %plot(gridPoints1(:,1), j{6}(4,:)/2.5e10, 'color', [0.29, 0.494, 0.737], 'linewidth', 3);
    %plot(gridPoints1(:,1), j{7}(4,:)/2.5e10, 'color', [0.29, 0.494, 0.737], 'linewidth', 3);

%    hold on
%    plot(gridPoints1(:,1), j{test+3}(t,:)/2.5e10, 'color', [0.745, 0.29, 0.282], 'linewidth', 2);
%    plot(gridPoints1(:,1), j{test}(t,:)/2.5e10, 'color', [0.596, 0.729, 0.329], 'linewidth', 2);
%    plot(gridPoints1(:,1), j{test+1}(t,:)/2.5e10, 'color', [0.49, 0.376, 0.627], 'linewidth', 2);
%    plot(gridPoints1(:,1), j{6}(t+1,:)/2.5e10, 'color', [0.49, 0.376, 0.627], 'linewidth', 2);
%    hold off
    %ylim([0, 1.2]);
%    pause(0.05)
%end
t = 4;
    %plot(gridPoints1(:,1), b1{6}(length(time{6}),:,2), 'color', [0.745, 0.29, 0.282], 'linewidth', 3);
%plot(gridPoints1(:,1), b1{1}(t,:,2), 'linewidth', 2);
%plot(time{1}, b1{1}(:,pt,2), 'k', 'linewidth', 2);
%plot(time{2}, b1{2}(:,pt,2), 'r', 'linewidth', 2);
%plot(time{3}, -b1{3}(:,pt,2), 'g', 'linewidth', 2);
%plot(time{4}, -b1{4}(:,pt,2), 'm', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{1}(t,:,3), 'b', 'linewidth', 2);
%plot(htob(:,1), htob(:,2), 'r', 'linewidth', 2);
%plot(hnorm(:,100), bnorm(:,100), 'b', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{2}(t,:,2), 'b', 'linewidth', 2);
%{
plot(gridPoints1(:,1), b1{5}(t,:,2), 'k', 'linewidth', 2);
plot(gridPoints1(:,1), -b1{6}(t,:,2), 'r', 'linewidth', 2);
plot(gridPoints1(:,1), -b1{7}(t,:,2), 'g', 'linewidth', 2);
plot(gridPoints1(:,1), b1{5}(t,:,3), 'k--', 'linewidth', 2);
plot(gridPoints1(:,1), -b1{6}(t,:,3), 'r--', 'linewidth', 2);
plot(gridPoints1(:,1), -b1{7}(t,:,3), 'g--', 'linewidth', 2);
%}
plot(gridPoints1(:,1), b1{5}(t,:,3), 'k', 'linewidth', 2);
plot(gridPoints1(:,1), -b1{6}(t,:,3), 'g', 'linewidth', 2);
plot(gridPoints1(:,1), b1{8}(t,:,3), 'k--', 'linewidth', 2);
plot(gridPoints1(:,1), -b1{9}(t,:,3), 'g--', 'linewidth', 2);
%plot(gridPoints1(:,1), -b1{3}(t,:,2), 'm', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{5}(t,:,2), 'k', 'linewidth', 2);
%plot(gridPoints1(:,1), (b1{1}(t,:,1)-b2{1}(t,:,1)), 'b', 'linewidth', 2);
%plot(gridPoints1(:,1), b2{1}(t,:,1), 'b--', 'linewidth', 2);
%plot(gridPoints1(:,1), b2{4}(t,:,2), 'r', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{4}(t,:,2), 'm--', 'linewidth', 2);
%plot(gridPoints1(:,1), b2{4}(t,:,2), 'm', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{6}(t,:,2), 'r', 'linewidth', 2);
%plot(gridPoints1(:,1), b1{7}(t,:,2), 'b', 'linewidth', 2);
hold off
%xlim([0.00,6]);
hold off
grid on;
hold off


%leg = legend('Normal $b$', 'Jump of tangential $b$','Location','north');
%set(leg,'Interpreter','latex')
%set(leg,'FontSize',22)

%%
%{
fileName = fopen('~/Dropbox/Thesis_Reports/data/bar_ha_stability.txt','w');
fprintf(fileName, 'r bn_11_ferro bn_11_super bn_12_ferro bn_12_super\n');
for r = 1:200
    fprintf(fileName, '%g %g %g %g %g\n', ...
        1000*gridPoints1(r,1), b1{1}(t,r,2), b2{1}(t,r,2),...
        b1{4}(t,r,2), b2{4}(t,r,2));
end
fclose(fileName);
%}


%%
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [25 5 20 15]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
%plot(mu0*appliedField{1}, mu0*avgMagn{1}(:,2), 'linewidth', 2);
plot(mu0*appliedField{5}(1:length(time{5})), 2*mu0*avgMagn{5}(:,2), 'linewidth', 2);
%plot(mu0*appliedField{3}, mu0*avgMagn{3}(:,2), 'linewidth', 2);
hold off
%xlim([0.00,12.5]);
%ylim([-0.05,0.05]);
hold off
grid on;
hold off



%%
test = 5;
comp = 2;
if(length(time{test})==301)
    t1=101;
    t2=201;
    t3=301;
elseif(length(time{test})==151)
    t1=51;
    t2=101;
    t3=151;
else
    t1=26;
    t2=51;
    t3=76;
end
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [25 5 30 25]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
for t=1:25%length(time{3})
    plot(gridPoints1(:,1), b1{test}(t,:,comp), 'k', 'linewidth', 2);
    hold on
    plot(gridPoints1(:,1), -b1{test+1}(t,:,comp), 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), -b1{test+2}(t,:,comp), 'g', 'linewidth', 2);
    %plot(gridPoints1(:,1), -b1{test+3}(t,:,comp), 'm', 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{test}(t,:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{test+1}(t,:,2), 'color', [0.49, 0.376, 0.627], 'linewidth', 2);
    hold off
    %xlim([0, 12.5]);
    %ylim([-0.05, 0.05]);
    pause(0.1);
end
%plot(1000*gridPoints1(:,1), b1{2}(21,:,3), 'color', [0.745, 0.29, 0.282], 'linewidth', 3);
%plot(1000*gridPoints1(:,1), b1{3}(41,:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 3);
hold off

%xlim([0.00,12.5]);
%ylim([-0.05,0.05]);
hold off
grid on;
hold off


%%
%{
fileName = fopen('~/Dropbox/Applications/ShareLaTex/Thesis_Reports/data/verifTapeB_a.txt','w');
fprintf(fileName, 'r b_09_25 b_05_25 b_09_100 b_05_100\n');
for r = 1:5:2000
    fprintf(fileName, '%g %g %g %g %g\n', ...
        1000*gridPoints1(r,1), b1{5}(7,r,2), ...
        b1{4}(7,r,2), b1{7}(4,r,2), b1{6}(4,r,2));
end
fclose(fileName);
%}



%%
indicPower = zeros(nbTest, 1);
for test=1:nbTest
    indicPower(test) = trapz(time{test}(2:length(time{test})), power{test}(:,5));
end

dofs = [1609 1609 2252 2252 3514 3514 6042 6043 13217 13217 51688 51688 ...
    1116 1116 1557 1557 2480 2480 4267 4267 9308 9308 36474 36474];


ref10 = 0.5*(indicPower(24)+indicPower(12));
ref20 = 0.5*(indicPower(23)+indicPower(11));
%ref20 = ref10;%0.5*(indicPower(23)+indicPower(11));


figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [25 5 30 25]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
plot(dofs(1:2:11), 100*(indicPower(1:2:11)-ref10)/ref10, 'ro-', 'linewidth', 2);
plot(dofs(2:2:12), 100*(indicPower(2:2:12)-ref10)/ref10, 'go-', 'linewidth', 2);
plot(dofs(13:2:23), 100*(indicPower(13:2:23)-ref10)/ref10, 'bo-','linewidth', 2);
plot(dofs(14:2:24), 100*(indicPower(14:2:24)-ref10)/ref10, 'ko-', 'linewidth', 2);
%plot(dofs(24), 100*(indicPower(25)-ref10)/ref10, 'ko-', 'linewidth', 2);
%{
plot(dofs(1:2:9), indicPower(27:2:35), 'ro-', 'linewidth', 2);
plot(dofs(2:2:10), indicPower(28:2:36), 'go-', 'linewidth', 2);
plot(dofs(13:2:21), indicPower(37:2:45), 'bo-','linewidth', 2);
plot(dofs(14:2:22), indicPower(38:2:46), 'ko-', 'linewidth', 2);
%}
%xlim([0, 12.5]);
%set(gca, 'YScale', 'log')
%set(gca, 'XScale', 'log')
ylim([-4, 4]);
hold off
grid on;
hold off

%{
fileName = fopen('~/Dropbox/Applications/ShareLaTex/Thesis_Reports/data/convBulk.txt','w');
fprintf(fileName, 'dofsH powerH dofsA powerA\n');
for te = 0:5
    fprintf(fileName, '%g %g %g %g\n', ...
        dofs(2+2*te), 100*(indicPower(2+2*te)-ref10)/ref10, ...
        dofs(14+2*te), 100*(indicPower(14+2*te)-ref10)/ref10);
end
fclose(fileName);
%}


%%
%indicPower = zeros(nbTest, 1);
for test=7:nbTest
    indicPower(test) = trapz(time{test}(2:length(time{test})), power{test}(:,5));
end

%%
ref10 = 0.5*(indicPower(5)+indicPower(10));

dofs = [1609 2252 3514 6042 13217 51688 ...
    1116 1557 2480 4267 9308 36474];

figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [25 5 30 25]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
plot(dofs(1:5), 100*(indicPower(1:5)-ref10)/ref10, 'ro-', 'linewidth', 2);
plot(dofs(7:11), 100*(indicPower(7:11)-ref10)/ref10, 'go-', 'linewidth', 2);
%plot(dofs(7:11), 100*(indicPower(13:17)-ref10)/ref10, 'ko-', 'linewidth', 2);
%plot(dofs(24), 100*(indicPower(25)-ref10)/ref10, 'ko-', 'linewidth', 2);
%{
plot(dofs(1:2:9), indicPower(27:2:35), 'ro-', 'linewidth', 2);
plot(dofs(2:2:10), indicPower(28:2:36), 'go-', 'linewidth', 2);
plot(dofs(13:2:21), indicPower(37:2:45), 'bo-','linewidth', 2);
plot(dofs(14:2:22), indicPower(38:2:46), 'ko-', 'linewidth', 2);
%}
%xlim([0, 12.5]);
%set(gca, 'YScale', 'log')
%set(gca, 'XScale', 'log')
%ylim([-4, 4]);
hold off
grid on;
hold off


%%
ti = 10;
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [15 5 30 20]);
set(gca, 'fontsize',22);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
t = 2;
tFine = (t-1)*30+2;
hold on
%plot(gridPoints1(:,1), j{1}(ti,:) , 'b', 'linewidth', 2);
%plot(gridPoints1(:,1), j{2}(ti,:) , 'r', 'linewidth', 2);
%plot(gridPoints1(:,1), j{3}(ti,:) , 'g', 'linewidth', 1);
plot(1000*gridPoints2(:,1), b2{1}(ti,:,3) , 'b', 'linewidth', 2);
plot(1000*gridPoints2(:,1), b2{2}(ti,:,3) , 'k', 'linewidth', 2);
%plot(1000*gridPoints1(:,1), b2{3}(ti,:,2) , 'g', 'linewidth', 2);
plot(1000*gridPoints2(:,1), b2{4}(ti,:,3) , 'r', 'linewidth', 2);
xlim([0, 6]);
%leg = legend('$h$', '$h$-$a$', '$a$', '$t$-$a$','Location','north');
set(leg,'Interpreter','latex')
set(leg,'FontSize',22)
ylabel('$b\cdot \hat y$ [T]','Interpreter','latex','FontSize',22);
xlabel('Position from center of tape [mm]','Interpreter','latex','FontSize',22);
grid on 


%%
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [25 5 30 25]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
plot(residualInfo{5}(:,2))
set(gca, 'YScale', 'log')
grid on;
hold off

%%

clear V_n I_n_1
V_n = power{1}(:,7);
I_n = power{1}(:,8);
n=length(V_n);
I_n_1(1) = 0;
I_n_1(2:n+1) = I_n;
V_n_1(1) = 0;
V_n_1(2:n+1) = V_n;
%I_n_1 = I_n_1';

VI_corrected = V_n .* ( I_n+I_n_1(1:n)' )./2;
VI_corrected_2 = ( V_n+V_n_1(1:n)' )./2 .* ( I_n+I_n_1(1:n)' )./2;

%indicPower = trapz(time{1}(2:length(time{1})), power{1}(:,5));


figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [25 5 30 25]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
plot(power{1}(:,1),-cumsum(V_n.*I_n)-cumsum(power{1}(:,2)), '-' , 'color', [1 0 0], 'linewidth', 2);
plot(power{1}(:,1),-cumsum(VI_corrected)-cumsum(power{1}(:,2)), '-', 'color', [0 1 0], 'linewidth', 2);
plot(power{1}(:,1),-cumsum(VI_corrected_2)-cumsum(power{1}(:,2)), '-', 'color', [0 0.5 0], 'linewidth', 2);
plot(power{1}(:,1),cumsum(power{1}(:,6))-cumsum(power{1}(:,2)), '-', 'color', [0 0 1], 'linewidth', 2);
plot(power{1}(:,1),cumsum(power{1}(:,2)), '-', 'color', [0 0 1], 'linewidth', 2);
%set(gca, 'YScale', 'log')
grid on;
hold off









%%