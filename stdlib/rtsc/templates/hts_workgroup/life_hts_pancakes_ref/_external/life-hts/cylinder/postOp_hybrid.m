nbTest = 20;
testname = cell(nbTest,1);
% Coarse
testname{1} = 'cylinders_mm4_n20_ha';
testname{2} = 'cylinders_mm4_n20_hb';
testname{3} = 'cylinders_mm4_n20_aj';
testname{4} = 'cylinders_mm4_n20_h';
testname{5} = 'cylinders_mm4_n20_a';
% Medium
testname{6} = 'cylinders_mm2_n20_ha';
testname{7} = 'cylinders_mm2_n20_hb';
testname{8} = 'cylinders_mm2_n20_aj';
testname{9} = 'cylinders_mm2_n20_h';
testname{10} = 'cylinders_mm2_n20_a';
% Fine
testname{11} = 'cylinders_mm1_n20_ha';
testname{12} = 'cylinders_mm1_n20_hb';
testname{13} = 'cylinders_mm1_n20_aj';
testname{14} = 'cylinders_mm1_n20_h';
testname{15} = 'cylinders_mm1_n20_a';

testname{16} = 'cylinders_mm4_n20_ha_120ts';
testname{17} = 'cylinders_mm4_n20_hb_120ts';
testname{18} = 'cylinders_mm4_n20_aj_120ts';
testname{19} = 'cylinders_mm4_n20_h_120ts';
testname{20} = 'cylinders_mm4_n20_a_120ts';
mu0 = 4*pi*1e-7;
savedPoints = 500;%200;
iterationInfo = cell(nbTest,1);
residualInfo = cell(nbTest,1);
time = cell(nbTest,1);
appliedField = cell(nbTest,1);
b1 = cell(nbTest,1);
b2 = cell(nbTest,1);
b3 = cell(nbTest,1);
j = cell(nbTest,1);
avgMagn = cell(nbTest,1);
avgbz = cell(nbTest,1);
power = cell(nbTest,1);
%
%
for res=1:20%nbTest
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
    outputMagInduction3 = ['res/',testname{res},'/bLine3.txt'];
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
    tmp5 = load(outputMagInduction3);
    gridPoints1 = tmp1(1+(0:savedPoints-1)*length(time{res}),3:4);
    gridPoints2 = tmp3(1+(0:savedPoints-1)*length(time{res}),3:4);
    gridPoints3 = tmp5(1+(0:savedPoints-1)*length(time{res}),3:4);
    b1{res} = zeros(length(time{res}), savedPoints, 3);
    b2{res} = zeros(length(time{res}), savedPoints, 3);
    b3{res} = zeros(length(time{res}), savedPoints, 3);
    %h1{res} = zeros(length(time{res}), savedPoints, 3);
    j{res} = zeros(length(time{res}), savedPoints, 3);
    %%{
    for k=1:savedPoints
        b1{res}(:,k,:) = tmp1(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
        j{res}(:,k,:) = tmp4(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
        %h1{res}(:,k,:) = tmp5(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
        b2{res}(:,k,:) = tmp3(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
        b3{res}(:,k,:) = tmp5(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
    end
    %}
    fprintf('%d is done\n', res);
end

%%
clear dissPower
DOFs = [784 972 674 767 600    2669 3326 2360 2636 2119   9914 12447 8890 9847 8000];

for test = 1:20%nbTest
    dissPower(test) = trapz(power{test}(:,1), power{test}(:,5));
end
10e4*dissPower

%dissPower(1:5) = dissPower(16:20);
%dissPower(11:15) = dissPower(11:15) - 0.0027;

%ref = 0.5*(dissPower(11)+dissPower(12));

figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [15 5 30 20]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
plot(dissPower(1:5:15), 'g-', 'linewidth', 2);
plot(dissPower(2:5:15), 'r-', 'linewidth', 2);
plot(dissPower(3:5:15), 'k-', 'linewidth', 2);
plot(dissPower(4:5:15), 'b-', 'linewidth', 2);
plot(dissPower(5:5:15), 'm-', 'linewidth', 2);
plot(ref*ones(2,1));
grid on

%%
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/convCylinders.txt','w');
fprintf(fileName, 'dofsHA powerHA dofsHB powerHB dofsAJ powerAJ dofsH powerH dofsA powerA\n');
for r = 0:2
    fprintf(fileName, '%g %g %g %g %g %g %g %g %g %g\n', ...
        DOFs(1+5*r), 100*(dissPower(1+5*r)-ref)/ref, ...
        DOFs(2+5*r), 100*(dissPower(2+5*r)-ref)/ref, ...
        DOFs(3+5*r), 100*(dissPower(3+5*r)-ref)/ref, ...
        DOFs(4+5*r), 100*(dissPower(4+5*r)-ref)/ref, ...
        DOFs(5+5*r), 100*(dissPower(5+5*r)-ref)/ref);
end
fclose(fileName);

%%
incr = 0;
powerID = 5;
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [15 5 30 20]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
hold on
%plot(power{incr+1}(:,1), power{incr+1}(:,powerID), 'g-', 'linewidth', 2);
plot(power{incr+2}(:,1), power{incr+2}(:,powerID), 'r-', 'linewidth', 2);
%plot(power{incr+3}(:,1), power{incr+3}(:,powerID), 'k-', 'linewidth', 2);
plot(power{incr+4}(:,1), power{incr+4}(:,powerID), 'b-', 'linewidth', 2);
%plot(power{incr+5}(:,1), power{incr+5}(:,powerID), 'm-', 'linewidth', 2);
%plot(power{6}(:,1), power{6}(:,5), 'k-', 'linewidth', 2);
%plot(power{13}(:,1), power{13}(:,5), 'b-', 'linewidth', 2);
%plot(power{14}(:,1), power{14}(:,5), 'r-', 'linewidth', 2);
%plot(power{16}(:,1), power{16}(:,5), 'g-', 'linewidth', 2);
%plot(power{17}(:,1), power{17}(:,5), 'm-', 'linewidth', 2);
%plot(unit*power{4}(:,1), (power{4}(:,5))*sin(theta(4)), 'm-', 'linewidth', 2);
%plot(unit*power{5}(:,1), (power{5}(:,5))*sin(theta(5)), 'c-', 'linewidth', 1);
%plot(unit*power{6}(:,1), (power{6}(:,5))*sin(theta(6)), 'k-', 'linewidth', 3);

grid on

%%
plotField = b1;
incr = 10;
test = 1;
comp = 2;
t = 241;
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [25 5 30 25]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
%for t=1:length(time{1})
    %plot(gridPoints1(:,1), b1{6}(100,:,comp), 'k', 'linewidth', 2);
    plot(gridPoints1(:,1), 0.5*(plotField{incr+1}(t+2,:,comp)+plotField{incr+1}(t+1,:,comp)), 'b', 'linewidth', 2);
    hold on
    plot(gridPoints1(:,1), plotField{incr+2}(t,:,comp), 'r', 'linewidth', 2);
    plot(gridPoints1(:,1), plotField{incr+3}(t,:,comp), 'k', 'linewidth', 2);
    plot(gridPoints1(:,1), plotField{incr+4}(t,:,comp), 'm', 'linewidth', 2);
    plot(gridPoints1(:,1), plotField{incr+5}(t,:,comp), 'c', 'linewidth', 2);
    %plot(gridPoints1(:,1), j{12}(76,:,comp), 'm', 'linewidth', 2);
    %plot(gridPoints1(:,1), j{10}(51,:,comp), 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), j{10}(101,:,comp), 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), -b1{test+2}(t,:,comp), 'g', 'linewidth', 2);
    %plot(gridPoints1(:,1), -b1{test+3}(t,:,comp), 'm', 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{test}(t,:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{test+1}(t,:,2), 'color', [0.49, 0.376, 0.627], 'linewidth', 2);
    hold off
    %xlim([0, 12.5]);
    %ylim([-0.5, 2.5]);
%    pause(0.05);
%end
%plot(1000*gridPoints1(:,1), b1{2}(21,:,3), 'color', [0.745, 0.29, 0.282], 'linewidth', 3);
%plot(1000*gridPoints1(:,1), b1{3}(41,:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 3);
hold off
grid on

%% b1
incr = 5;
comp = 1;
t = 121;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b1_x_lastStep.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b1{incr+1}(t,r,comp)+b1{incr+1}(t+1,r,comp)), ...
        b1{incr+2}(t,r,comp), b1{incr+3}(t,r,comp), ...
        b1{incr+4}(t,r,comp), b1{incr+5}(t,r,comp));
end
fclose(fileName);

t = 61;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b1_x_midStep.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, b1{incr+1}(t,r,comp), ...
        b1{incr+2}(t,r,comp), b1{incr+3}(t,r,comp), ...
        b1{incr+4}(t,r,comp), b1{incr+5}(t,r,comp));
end
fclose(fileName);

comp = 2;
t = 121;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b1_y_lastStep.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b1{incr+1}(t,r,comp)+b1{incr+1}(t+1,r,comp)), ...
        b1{incr+2}(t,r,comp), b1{incr+3}(t,r,comp), ...
        b1{incr+4}(t,r,comp), b1{incr+5}(t,r,comp));
end
fclose(fileName);

t = 61;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b1_y_midStep.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, b1{incr+1}(t,r,comp), ...
        b1{incr+2}(t,r,comp), b1{incr+3}(t,r,comp), ...
        b1{incr+4}(t,r,comp), b1{incr+5}(t,r,comp));
end
fclose(fileName);

%% b2
incr = 5;
comp = 1;
t = 121;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b2_x_lastStep.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b2{incr+1}(t,r,comp)+b2{incr+1}(t+1,r,comp)), ...
        b2{incr+2}(t,r,comp), b2{incr+3}(t,r,comp), ...
        b2{incr+4}(t,r,comp), b2{incr+5}(t,r,comp));
end
fclose(fileName);

t = 61;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b2_x_midStep.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, b2{incr+1}(t,r,comp), ...
        b2{incr+2}(t,r,comp), b2{incr+3}(t,r,comp), ...
        b2{incr+4}(t,r,comp), b2{incr+5}(t,r,comp));
end
fclose(fileName);

comp = 2;
t = 121;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b2_y_lastStep.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b2{incr+1}(t,r,comp)+b2{incr+1}(t+1,r,comp)), ...
        b2{incr+2}(t,r,comp), b2{incr+3}(t,r,comp), ...
        b2{incr+4}(t,r,comp), b2{incr+5}(t,r,comp));
end
fclose(fileName);

t = 61;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b2_y_midStep.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, b2{incr+1}(t,r,comp), ...
        b2{incr+2}(t,r,comp), b2{incr+3}(t,r,comp), ...
        b2{incr+4}(t,r,comp), b2{incr+5}(t,r,comp));
end
fclose(fileName);


%%
incr = 5;
test = 1;
comp = 3;
t = 121;
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [25 5 30 25]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
%for t=1:length(time{1})
    %plot(gridPoints1(:,1), b1{6}(100,:,comp), 'k', 'linewidth', 2);
    plot(gridPoints1(:,1), 0.5*(j{incr+1}(t,:,comp)+j{incr+1}(t+1,:,comp)), 'b', 'linewidth', 2);
    hold on
    plot(gridPoints1(:,1), j{incr+2}(t,:,comp), 'r', 'linewidth', 2);
    plot(gridPoints1(:,1), j{incr+3}(t,:,comp), 'k', 'linewidth', 2);
    plot(gridPoints1(:,1), j{incr+4}(t,:,comp), 'm', 'linewidth', 2);
    plot(gridPoints1(:,1), j{incr+5}(t,:,comp), 'c', 'linewidth', 2);
    
    %plot(gridPoints1(:,1), j{12}(76,:,comp), 'm', 'linewidth', 2);
    %plot(gridPoints1(:,1), j{10}(51,:,comp), 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), j{10}(101,:,comp), 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), -b1{test+2}(t,:,comp), 'g', 'linewidth', 2);
    %plot(gridPoints1(:,1), -b1{test+3}(t,:,comp), 'm', 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{test}(t,:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{test+1}(t,:,2), 'color', [0.49, 0.376, 0.627], 'linewidth', 2);
    hold off
    %xlim([0, 12.5]);
    %ylim([-0.5, 2.5]);
%    pause(0.05);
%end
%plot(1000*gridPoints1(:,1), b1{2}(21,:,3), 'color', [0.745, 0.29, 0.282], 'linewidth', 3);
%plot(1000*gridPoints1(:,1), b1{3}(41,:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 3);
hold off
grid on
%%
jc = 3e8;
incr = 5;
comp = 3;
t = 121;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_j_lastStep.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(j{incr+1}(t,r,comp)+j{incr+1}(t+1,r,comp))/jc, ...
        j{incr+2}(t,r,comp)/jc, j{incr+3}(t,r,comp)/jc, ...
        j{incr+4}(t,r,comp)/jc, j{incr+5}(t,r,comp)/jc);
end
fclose(fileName);

t = 61;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_j_midStep.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, j{incr+1}(t,r,comp)/jc, ...
        j{incr+2}(t,r,comp)/jc, j{incr+3}(t,r,comp)/jc, ...
        j{incr+4}(t,r,comp)/jc, j{incr+5}(t,r,comp)/jc);
end
fclose(fileName);


%% Time step evolution
%%
zeroIndices = cell(nbTest, 1); % Iterations that have converged
itPerStep = cell(nbTest, 1);
for i=1:10
    zeroIndices{i} = find(residualInfo{i}(:,1) == 0);
    itPerStep{i}(1) = 0;
    for ts=1:size(zeroIndices{i},1)-1
        itPerStep{i}(1+ts) = zeroIndices{i}(ts+1)-zeroIndices{i}(ts);
    end
end

usefulIterations = cell(nbTest, 1); % Iterations that have converged
for i=1:10
    useit = 1;
    for it=1:size(iterationInfo{i},1)-1
        if(iterationInfo{i}(it,1) ~= iterationInfo{i}(it+1,1))
            usefulIterations{i}(useit,:) = iterationInfo{i}(it,:);
            useit = useit + 1;
        end
    end
    it = it + 1;
    usefulIterations{i}(useit,:) = iterationInfo{i}(it,:);
end

incr = 5;
figure;
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on')
hold on
%ylim([0,0.12]);

plot(iterationInfo{incr+1}(:,3), itPerStep{incr+1}, 'r-', 'linewidth', 2);
plot(iterationInfo{incr+2}(:,3), itPerStep{incr+2}, 'b-', 'linewidth', 2);
plot(iterationInfo{incr+3}(:,3), itPerStep{incr+3}, 'k-', 'linewidth', 2);
plot(iterationInfo{incr+4}(:,3), itPerStep{incr+4}, 'm-', 'linewidth', 2);
plot(iterationInfo{incr+5}(:,3), itPerStep{incr+5}, 'y-', 'linewidth', 2);
%plot(usefulIterations{2}(:,3), usefulIterations{2}(:,2), 'ko-', 'linewidth', 2);
%plot(usefulIterations{3}(:,3), usefulIterations{3}(:,2), 'go-', 'linewidth', 2);
%plot(usefulIterations{4}(:,3), usefulIterations{4}(:,2), 'r', 'linewidth', 2);
%plot(usefulIterations{5}(:,3), usefulIterations{5}(:,2), 'y', 'linewidth', 2);
%plot(usefulIterations{6}(:,3), usefulIterations{6}(:,2), 'm', 'linewidth', 2);
%plot(usefulIterations{7}(:,3), usefulIterations{7}(:,2), 'b', 'linewidth', 2);

%{
plot(usefulIterations{19}(:,3), usefulIterations{19}(:,2), 'bo-', 'linewidth', 2);
plot(usefulIterations{20}(:,3), usefulIterations{20}(:,2), 'ko-', 'linewidth', 2);
plot(usefulIterations{21}(:,3), usefulIterations{21}(:,2), 'go-', 'linewidth', 2);
plot(usefulIterations{22}(:,3), usefulIterations{22}(:,2), 'r', 'linewidth', 2);
plot(usefulIterations{23}(:,3), usefulIterations{23}(:,2), 'y', 'linewidth', 2);
plot(usefulIterations{24}(:,3), usefulIterations{24}(:,2), 'm', 'linewidth', 2);
%}
grid on;
%xlabel('Time [s]','Interpreter','latex','FontSize',20);
%ylabel('Adapted time step [s]','Interpreter','latex','FontSize',20);
%leg = legend('$a=2.7e-6$', '$a=2.7e-5$', '$a=2.7e-4$', '$a=2.7e-3$',...
%    'Location','northeast');
%set(leg,'Interpreter','latex')
hold off



%% FINE

%% b1
incr = 10;
comp = 1;
t = 241;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b1_x_lastStep_fine.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b1{incr+1}(t+2,r,comp)+b1{incr+1}(t+1,r,comp)), ...
        b1{incr+2}(t,r,comp), b1{incr+3}(t,r,comp), ...
        b1{incr+4}(t,r,comp), b1{incr+5}(t,r,comp));
end
fclose(fileName);

t = 121;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b1_x_midStep_fine.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b1{incr+1}(t,r,comp)+b1{incr+1}(t+1,r,comp)), ...
        b1{incr+2}(t,r,comp), b1{incr+3}(t,r,comp), ...
        b1{incr+4}(t,r,comp), b1{incr+5}(t,r,comp));
end
fclose(fileName);

comp = 2;
t = 241;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b1_y_lastStep_fine.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b1{incr+1}(t,r,comp)+b1{incr+1}(t+1,r,comp)), ...
        b1{incr+2}(t,r,comp), b1{incr+3}(t,r,comp), ...
        b1{incr+4}(t,r,comp), b1{incr+5}(t,r,comp));
end
fclose(fileName);

t = 121;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b1_y_midStep_fine.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b1{incr+1}(t,r,comp)+b1{incr+1}(t+1,r,comp)), ...
        b1{incr+2}(t,r,comp), b1{incr+3}(t,r,comp), ...
        b1{incr+4}(t,r,comp), b1{incr+5}(t,r,comp));
end
fclose(fileName);

%% b2
incr = 10;
comp = 1;
t = 241;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b2_x_lastStep_fine.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b2{incr+1}(t+2,r,comp)+b2{incr+1}(t+1,r,comp)), ...
        b2{incr+2}(t,r,comp), b2{incr+3}(t,r,comp), ...
        b2{incr+4}(t,r,comp), b2{incr+5}(t,r,comp));
end
fclose(fileName);

t = 121;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b2_x_midStep_fine.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b2{incr+1}(t,r,comp)+b2{incr+1}(t+1,r,comp)), ...
        b2{incr+2}(t,r,comp), b2{incr+3}(t,r,comp), ...
        b2{incr+4}(t,r,comp), b2{incr+5}(t,r,comp));
end
fclose(fileName);

comp = 2;
t = 241;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b2_y_lastStep_fine.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b2{incr+1}(t+2,r,comp)+b2{incr+1}(t+1,r,comp)), ...
        b2{incr+2}(t,r,comp), b2{incr+3}(t,r,comp), ...
        b2{incr+4}(t,r,comp), b2{incr+5}(t,r,comp));
end
fclose(fileName);

t = 121;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_b2_y_midStep_fine.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(b2{incr+1}(t,r,comp)+b2{incr+1}(t+1,r,comp)), ...
        b2{incr+2}(t,r,comp), b2{incr+3}(t,r,comp), ...
        b2{incr+4}(t,r,comp), b2{incr+5}(t,r,comp));
end
fclose(fileName);
%%
jc = 3e8;
incr = 10;
comp = 3;
t = 241;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_j_lastStep_fine.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(j{incr+1}(t+2,r,comp)+j{incr+1}(t+1,r,comp))/jc, ...
        j{incr+2}(t,r,comp)/jc, j{incr+3}(t,r,comp)/jc, ...
        j{incr+4}(t,r,comp)/jc, j{incr+5}(t,r,comp)/jc);
end
fclose(fileName);

t = 121;
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/cylinders_j_midStep_fine.txt','w');
fprintf(fileName, 'r ha hb aj h a\n');
for r = 1:2:length(gridPoints1(:,1))
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        gridPoints1(r,1)*1e3, 0.5*(j{incr+1}(t,r,comp)+j{incr+1}(t+1,r,comp))/jc, ...
        j{incr+2}(t,r,comp)/jc, j{incr+3}(t,r,comp)/jc, ...
        j{incr+4}(t,r,comp)/jc, j{incr+5}(t,r,comp)/jc);
end
fclose(fileName);


