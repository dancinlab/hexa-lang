clear all
nbTest = 18;
testname = cell(nbTest,1);

testname{1} = 'cylinder_test_a';
testname{2} = 'cylinder_test_h';
testname{3} = 'cylinder_test_a_picard';

testname{4} = 'cylinder_test_h_FM';
testname{5} = 'cylinder_test_a_FM';

testname{6} = 'cylinder_test_h_new';

%
mu0 = 4*pi*1e-7;
savedPoints = 300;%200;
iterationInfo = cell(nbTest,1);
residualInfo = cell(nbTest,1);
time = cell(nbTest,1);
appliedField = cell(nbTest,1);
b1 = cell(nbTest,1);
b2 = cell(nbTest,1);
j = cell(nbTest,1);
avgMagn = cell(nbTest,1);
avgbz = cell(nbTest,1);
power = cell(nbTest,1);
%
%%
for res=1:6%nbTest
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
    outputPower = ['res/',testname{res},'/power.txt'];
    outputRev = ['res/',testname{res},'/rev.txt'];
    outputIrrev = ['res/',testname{res},'/irrev.txt'];

    % Info on simulation
    iterationInfo{res} = load(infoIterationFile);
    residualInfo{res} = load(infoResidualFile);
    totalLinearSystems = length(residualInfo);
    % Physical results
    tmp = dlmread(outputAppliedField,'', 1, 0);
    time{res} = tmp(:,1);
    tmp = dlmread(outputAppliedField,'', 1, 0);
    appliedField{res} = tmp(:,2);
    %%{
    if(exist(outputPower, 'file') == 2)
        power{res} = load(outputPower);
    end
    %time{res} = power{res}(:,1);

    %rev{res} = load(outputRev);
    %irrev{res} = load(outputIrrev);
    %%{
    tmp1 = load(outputMagInduction1);
    %tmp5 = load(outputMagField1);
    tmp4 = load(outputCurrent);
    tmp3 = load(outputMagInduction2);
    gridPoints1 = tmp1(1+(0:savedPoints-1)*length(time{res}),3:4);
    gridPoints2 = tmp3(1+(0:savedPoints-1)*length(time{res}),3:4);
    b1{res} = zeros(length(time{res}), savedPoints, 3);
    %h1{res} = zeros(length(time{res}), savedPoints, 3);
    j{res} = zeros(length(time{res}), savedPoints, 3);
    %%{
    for k=1:savedPoints
        b1{res}(:,k,:) = tmp1(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
        %j{res}(:,k,:) = tmp4(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
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
    
    fprintf('%d is done\n', res);
end




%%


%%
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [15 5 30 20]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
plot(residualInfo{1}(:,1), residualInfo{1}(:,2), 'k-', 'linewidth', 2);
%plot(residualInfo{2}(1:32,1), residualInfo{2}(1:32,2), 'b-', 'linewidth', 2);
%plot(residualInfo{3}(1:51,1), residualInfo{3}(1:51,2), 'g-', 'linewidth', 2);
plot(residualInfo{4}(164:264,1), residualInfo{4}(164:264,2), 'g-', 'linewidth', 2);
plot(residualInfo{5}(1:3,1), residualInfo{5}(1:3,2), 'y-', 'linewidth', 2);

plot(residualInfo{6}(1:20,1), residualInfo{6}(1:20,2), 'b-', 'linewidth', 2);

grid on
set(gca, 'yscale', 'log');
%%
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [15 5 30 20]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
plot(residualInfo{1}(:,1), residualInfo{1}(:,6), 'k-', 'linewidth', 2);
%plot(residualInfo{2}(1:32,1), residualInfo{2}(1:32,6), 'b-', 'linewidth', 2);
%plot(residualInfo{3}(1:51,1), residualInfo{3}(1:51,6), 'g-', 'linewidth', 2);
plot(residualInfo{4}(164:264,1), abs(residualInfo{4}(164:264,5)), 'g-', 'linewidth', 2);
plot(residualInfo{5}(1:3,1), residualInfo{5}(1:3,5), 'y-', 'linewidth', 2);

plot(residualInfo{6}(1:20,1), residualInfo{6}(1:20,6), 'b-', 'linewidth', 2);

grid on
set(gca, 'yscale', 'log');


%%

fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/firstObservations_cycles_HTS.txt','w');
fprintf(fileName, 'it residual power\n');
for te = 1:80
    fprintf(fileName, '%g %g %g\n', ...
        residualInfo{1}(te,1), residualInfo{1}(te,2), residualInfo{1}(te,6));
end
fclose(fileName);
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/firstObservations_convergence_HTS.txt','w');
fprintf(fileName, 'it residual power\n');
for te = 1:20
    fprintf(fileName, '%g %g %g\n', ...
        residualInfo{6}(te,1), residualInfo{6}(te,2), residualInfo{6}(te,6));
end
fclose(fileName);

