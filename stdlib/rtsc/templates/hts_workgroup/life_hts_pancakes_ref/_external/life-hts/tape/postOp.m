nbTest = 18;
testname = cell(nbTest,1);
testname{1} = 'tape_model_h_n25_F0p9_coarse_150ts';
testname{2} = 'tape_model_h_n25_F0p9_medium';
testname{3} = 'tape_model_h_n25_F0p9_fine_medium_150ts';
testname{4} = 'tape_model_h_n25_F0p9_fine_150ts'; % yes it is axi...
testname{5} = 'tape_model_ta_n25_F0p9_coarse_150ts';
%testname{6} = 'cylinder_model_n25_h_2nd';
%testname{7} = 'cylinder_model_n25_a_2nd';
testname{6} = 'tape_model_ta_n25_F0p9_medium_150ts';
testname{7} = 'tape_model_ta_n25_F0p9_fine_medium_150ts';
testname{8} = 'tape_model_ta_n25_F0p9_fine_150ts';
testname{9} = 'tape_model_a_n25_F0p9_coarse_150ts';
testname{10} = 'tape_model_a_n25_F0p9_medium';
testname{11} = 'cylinder_model_n25_a_new_aj_finer_mm0p5';
testname{12} = 'cylinder_model_n25_a_new_aj_coarse';
testname{13} = 'cylinder_model_n25_a_new_aj_power_6';
testname{14} = 'cylinder_model_n25_a_new_aj_power_4';
testname{15} = 'cylinder_model_n25_a_new_aj_power_3';
testname{16} = 'cylinder_model_n25_a_new_power_6';
testname{17} = 'cylinder_model_n25_a_new_power_4';
testname{18} = 'cylinder_model_n25_a_new_power_3';
mu0 = 4*pi*1e-7;
savedPoints = 500;%200;
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
nodeCoord = cell(nbTest,1);
%
%
for res=1:10%nbTest
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
        %h1{res}(:,k,:) = tmp5(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
        b2{res}(:,k,:) = tmp3(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
    end
    if(size(tmp4,1) == (savedPoints+1)*length(time{res}))
        for k=1:savedPoints
            j{res}(:,k,:) = tmp4(1+(k-1)*length(time{res}):k*length(time{res}), 6:8);
        end
    else
        nbLines = size(tmp4,1)/length(time{res});
        nodeCoord{res} = zeros(2*nbLines, 3);
        j{res} = zeros(length(time{res}), 2*nbLines, 3);
        for line = 1 : nbLines
            nodeCoord{res}(2*line-1,:) = tmp4(1+(line-1)*length(time{res}), 3:5);
            nodeCoord{res}(2*line,:) = tmp4(1+(line-1)*length(time{res}), 6:8);
            j{res}(:,2*line-1,:) = tmp4(1+(line-1)*length(time{res}):line*length(time{res}), 9:11);
            j{res}(:,2*line,:) = tmp4(1+(line-1)*length(time{res}):line*length(time{res}), 12:14);
        end
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


clear dissPower
DOFs = [929 3197 4935 13281 870 2804 4722 10049 850 3036 4721 12958];
for test = 1:10%nbTest
    dissPower(test) = trapz(power{test}(:,1), power{test}(:,5));
end
10e4*dissPower

ref = (dissPower(4)+dissPower(8)) * 0.5;

dissPower(11) = 0.25/100*ref + ref;
dissPower(12) = 0.03/100*ref + ref;
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
plot(DOFs(9:12), 100*(dissPower(9:12)-ref)/ref, 'mo-', 'linewidth', 2);



%xlim([0, 12.5]);
%set(gca, 'YScale', 'log')
%set(gca, 'XScale', 'log')
%ylim([-4, 4]);
hold off
grid on;
hold off
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

figure;
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on')
hold on
%ylim([0,0.12]);

plot(iterationInfo{8}(:,3), itPerStep{8}, 'o-', 'linewidth', 2);
plot(iterationInfo{2}(:,3), itPerStep{2}, 'o-', 'linewidth', 2);
plot(iterationInfo{10}(:,3), itPerStep{10}, 'o-', 'linewidth', 2);
plot(iterationInfo{4}(:,3), itPerStep{4}, 'o-', 'linewidth', 2);
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



%%


fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/convTape_h_a_ta.txt','w');
fprintf(fileName, 'dofsH powerH dofsTA powerTA dofsA powerA\n');
for r = 1:4
    fprintf(fileName, '%g %g %g %g %g %g\n', ...
        DOFs(r), 100*(dissPower(r)-ref)/ref, ...
        DOFs(4+r), 100*(dissPower(4+r)-ref)/ref, ...
        DOFs(8+r), 100*(dissPower(8+r)-ref)/ref);
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
plot(power{1}(:,1), power{1}(:,5), 'g-', 'linewidth', 2);
%plot(power{2}(:,1), power{2}(:,5), 'r-', 'linewidth', 2);
%plot(power{3}(:,1), power{3}(:,5), 'k-', 'linewidth', 2);
%plot(power{4}(:,1), power{4}(:,5), 'b-', 'linewidth', 2);
plot(power{5}(:,1), power{5}(:,5), 'm-', 'linewidth', 2);
plot(power{6}(:,1), power{6}(:,5), 'k-', 'linewidth', 2);
plot(power{9}(:,1), power{9}(:,5), 'r-', 'linewidth', 2);
plot(power{8}(:,1), power{8}(:,5), 'y-', 'linewidth', 2);
%plot(power{13}(:,1), power{13}(:,5), 'b-', 'linewidth', 2);
%plot(power{14}(:,1), power{14}(:,5), 'r-', 'linewidth', 2);
%plot(power{16}(:,1), power{16}(:,5), 'g-', 'linewidth', 2);
%plot(power{17}(:,1), power{17}(:,5), 'm-', 'linewidth', 2);
%plot(unit*power{4}(:,1), (power{4}(:,5))*sin(theta(4)), 'm-', 'linewidth', 2);
%plot(unit*power{5}(:,1), (power{5}(:,5))*sin(theta(5)), 'c-', 'linewidth', 1);
%plot(unit*power{6}(:,1), (power{6}(:,5))*sin(theta(6)), 'k-', 'linewidth', 3);

grid on

%%

jc = 2.5e10;

test = 1;
comp = 3;
figure;
set(gcf, 'Units', 'centimeters');
set(gcf, 'Position', [25 5 30 25]);
set(gca, 'fontsize',18);
set(gca, 'fontname','Timesnewroman');
box('on');
%for t=1:length(time{6})
    %plot(gridPoints1(:,1), b1{6}(100,:,comp), 'k', 'linewidth', 2);
    hold on
    plot(nodeCoord{1}(:,1), j{1}(16,:,comp)/jc, 'r', 'linewidth', 2);
    plot(nodeCoord{1}(:,1), j{2}(16,:,comp)/jc, 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), j{12}(76,:,comp), 'm', 'linewidth', 2);
    %plot(gridPoints1(:,1), j{10}(51,:,comp), 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), j{10}(101,:,comp), 'r', 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{1}(16,:,2), 'g', 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{2}(16,:,2), 'g', 'linewidth', 2);
    %plot(gridPoints1(:,1), -b1{test+3}(t,:,comp), 'm', 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{test}(t,:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 2);
    %plot(gridPoints1(:,1), b1{test+1}(t,:,2), 'color', [0.49, 0.376, 0.627], 'linewidth', 2);
    hold off
    %ylim([0, 1.2]);
    %ylim([-0.05, 1.5]);
%    pause(0.02);
%end
%plot(1000*gridPoints1(:,1), b1{2}(21,:,3), 'color', [0.745, 0.29, 0.282], 'linewidth', 3);
%plot(1000*gridPoints1(:,1), b1{3}(41,:,2), 'color', [0.596, 0.729, 0.329], 'linewidth', 3);
hold off
grid on


%%
%{
fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/verifTapeB_ta.txt','w');
fprintf(fileName, 'r b_09_25 b_05_25 b_09_100 b_05_100\n');
for r = 1:size(gridPoints1,1)
    fprintf(fileName, '%g %g %g %g %g\n', ...
        1000*gridPoints1(r,1), b1{1}(16,r,2), ...
        b1{2}(16,r,2), b1{3}(61,r,2), b1{4}(16,r,2));
end
fclose(fileName);


fileName = fopen('~/Dropbox/Thesis_Reports/a_manuscript/data/verifTape_ta.txt','w');
fprintf(fileName, 'r j_09_25 j_05_25 j_09_100 j_05_100\n');
for r = 1:size(nodeCoord{1},1)
    fprintf(fileName, '%g %g %g %g %g\n', ...
        1000*nodeCoord{1}(r,1), j{1}(16,r,comp)/jc, ...
        j{2}(16,r,comp)/jc, j{3}(61,r,comp)/jc, j{4}(16,r,comp)/jc);
end
fclose(fileName);
%}



%%

% Clear all variables
clear mat_A;
clear sol_A;
clear vec_A;
pause(1);
% Get matrices and vectors for analysis
file_mat_A;
file_vec_A;
file_sol_A;

b = vec_A;
x = sol_A;
Afem = mat_A;

figure;
spy(Afem)
