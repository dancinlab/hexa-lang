nbTest = 18;
testname = cell(nbTest,1);


testname{1} = 'cylinder_model_n25_h_ts200';
testname{2} = 'cylinder_model_n25_a_ts200';
testname{3} = 'cylinder_model_n25_h_nonAxi';
testname{4} = 'cylinder_model_n25_a_nonAxi'; % yes it is axi...
testname{5} = 'cylinder_model_n25_h_fine';
testname{6} = 'cylinder_model_n25_h_new';
testname{7} = 'cylinder_model_n25_a_new';
%testname{6} = 'cylinder_model_n25_h_2nd';
%testname{7} = 'cylinder_model_n25_a_2nd';
testname{8} = 'cylinder_model_n25_a_new_smallerEpsilon';
testname{9} = 'cylinder_model_n25_a_new_aj';
testname{10} = 'cylinder_model_n25_a_new_aj_fine';
testname{11} = 'cylinder_model_n25_a_new_aj_finer_mm0p5';
testname{12} = 'cylinder_model_n25_a_new_aj_coarse';
testname{13} = 'cylinder_model_n25_a_new_aj_power_6';
testname{14} = 'cylinder_model_n25_a_new_aj_power_4';
testname{15} = 'cylinder_model_n25_a_new_aj_power_3';
testname{16} = 'cylinder_model_n25_a_new_power_6';
testname{17} = 'cylinder_model_n25_a_new_power_4';
testname{18} = 'cylinder_model_n25_a_new_power_3';

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
for res=1:1%nbTest
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
        j{res}(:,k,:) = tmp4(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
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
test = 1;
interval = 101:200;
W = 12e-3;
H = 1e-6;
a = 10e-3;
jc = 3e10;
I = sum(j{1}, 2) * W/savedPoints * H;
javgrel = I/(W*H*jc);
F = 0.9;
%norris = ((1-F) * log(1-F) + (1+F) * log(1+F) - F^2) * (W*H*jc)^2*4e-7*pi/pi
%norrisCylinder = (jc*pi*a^2)^2 * mu0 / pi * ((1-F)*log(1-F) + (2-F)*F/2)
dissPower = trapz(time{test}(interval), power{test}(interval,5))
dissPowerGlobal = -trapz(time{test}(interval), power{test}(interval,6))
%dissPowerGlobal2 = -trapz(time{test}(interval), power{test}(interval,7).*power{test}(interval,8))


%%



%DOFs = [7029 4421 2775 1797 6729 4217 2623 1673];
for test = 1:17%nbTest
    dissPower(test) = trapz(power{test}(:,1), power{test}(:,5));
end
dissPower
%ref = (dissPower(1)+dissPower(5)) * 0.5;
%%

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

%%

    dofsAJ = 1e4*[0.1295
    0.1806
    0.2877
    0.4950
    1.0797
    4.2310];
    powerAJ = [3.3942
    2.7421
    2.0688
    1.4261
    1.0984
    0.6915];

    fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/convBulk_aj.txt','w');
fprintf(fileName, 'dofsAJ powerAJ\n');
for r = 1:length(dofsAJ)
    fprintf(fileName, '%g %g\n', ...
        dofsAJ(r,1), powerAJ(r,1));
end
fclose(fileName);

%%


figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [15 5 30 20]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
%plot(power{1}(:,1), power{1}(:,5), 'g-', 'linewidth', 2);
%plot(power{2}(:,1), power{2}(:,5), 'r-', 'linewidth', 2);
%plot(power{3}(:,1), power{3}(:,5), 'k-', 'linewidth', 2);
%plot(power{4}(:,1), power{4}(:,5), 'b-', 'linewidth', 2);
%plot(power{5}(:,1), power{5}(:,5), 'm-', 'linewidth', 2);
plot(power{6}(:,1), power{6}(:,5), 'k-', 'linewidth', 2);
plot(power{13}(:,1), power{13}(:,5), 'b-', 'linewidth', 2);
plot(power{14}(:,1), power{14}(:,5), 'r-', 'linewidth', 2);
plot(power{16}(:,1), power{16}(:,5), 'g-', 'linewidth', 2);
plot(power{17}(:,1), power{17}(:,5), 'm-', 'linewidth', 2);
%plot(unit*power{4}(:,1), (power{4}(:,5))*sin(theta(4)), 'm-', 'linewidth', 2);
%plot(unit*power{5}(:,1), (power{5}(:,5))*sin(theta(5)), 'c-', 'linewidth', 1);
%plot(unit*power{6}(:,1), (power{6}(:,5))*sin(theta(6)), 'k-', 'linewidth', 3);

grid on

%%
test = 1;
comp = 2;
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [25 5 30 25]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
%for t=1:length(time{6})
    %plot(gridPoints1(:,1), b1{6}(100,:,comp), 'k', 'linewidth', 2);
    hold on
    plot(gridPoints1(:,1), b2{11}(150,:,comp), 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), j{12}(76,:,comp), 'm', 'linewidth', 2);
    %plot(gridPoints1(:,1), j{10}(51,:,comp), 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), j{10}(101,:,comp), 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), -b1{test+2}(t,:,comp), 'g', 'linewidth', 2);
    %plot(gridPoints1(:,1), -b1{test+3}(t,:,comp), 'm', 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{test}(t,:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{test+1}(t,:,2), 'color', [0.49, 0.376, 0.627], 'linewidth', 2);
    hold off
    %xlim([0, 12.5]);
    %ylim([-0.05, 1.5]);
%    pause(0.02);
%end
%plot(1000*gridPoints1(:,1), b1{2}(21,:,3), 'color', [0.745, 0.29, 0.282], 'linewidth', 3);
%plot(1000*gridPoints1(:,1), b1{3}(41,:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 3);
hold off
grid on


%%



fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/verifBulkB_aj.txt','w');
fprintf(fileName, 'r t1 t2 t3\n');
for r = 1:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, b2{11}(51,r,2), b2{11}(101,r,2), 0.5*(b2{11}(150,r,2)+b2{11}(151,r,2)));
end
fclose(fileName);




%%

a = 0.807;
b = 0.837;

c = abs(a-b)/max(a,b)


