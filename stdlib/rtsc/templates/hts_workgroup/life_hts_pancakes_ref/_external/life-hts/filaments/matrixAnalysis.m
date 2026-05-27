% Clear all variables
clear mat_A;
clear sol_A;
clear vec_A;
% Get matrices and vectors for analysis
file_mat_A;
file_vec_A;
file_sol_A;


A = mat_A;
x = sol_A;
b = vec_A;

figure;
spy(A)

%%

x_new = A\b;

figure
plot(x);
hold on 
plot(x_new);
