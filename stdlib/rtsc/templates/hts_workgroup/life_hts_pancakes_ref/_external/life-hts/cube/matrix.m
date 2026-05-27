clear all

file_mat_A;
file_vec_A;

%

A = mat_A;
b = vec_A;

%%
x = A\b;


%%
iterations = [4057 3937 2955 3147 1124 1108 1104 2225]';
totaltime = 60*[180+42 60+33 120+33 60+48 50 39 60+29 120+15]';
dofs = [35532 12172 29010 26964 32045 15776 20821 36019]';

tperIt = totaltime./iterations;
tperItDof = tperIt./dofs;



tcheck = [
    11.474 14.047 14.855
    2.315 3.301 3.709
    7.358 9.361 10.391
    4.828 6.270 6.759
    3.728 5.702 6.236
    4.828 6.080 6.668
    8.761 11.443 11.843
    8.748 12.043 12.482];

tperItCheck = tcheck(:,3) - tcheck(:,1);
tperItCheckSolveGen = tcheck(:,2) - tcheck(:,1);
tperItCheckPostOp = tcheck(:,3) - tcheck(:,2);


%fprintf("h-phi\t iteration: %g s\t generate+solve: %g s\n", 3.709 - 2.315, 8.883 - 7.893);
%fprintf("h-a\t iteration: %g s\t generate+solve: %g s\n", 6.236 - 3.728, 5.702 - 3.728);
