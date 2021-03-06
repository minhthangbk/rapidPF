function [xsol, xsol_stacked, mpc_sol, loggX] = solve_distributed_problem_with_admm_cplex(mpc, problem, names, params) 
% solve_distributed_problem_with_aladin
%
%   `copy the declaration of the function in here (leave the ticks unchanged)`
%
%   _describe what the function does in the following line_
%
%   # Markdown formatting is supported
%   Equations are possible to, e.g $a^2 + b^2 = c^2$.
%   So are lists:
%   - item 1
%   - item 2
%   ```matlab
%   function y = square(x)
%       x^2
%   end
%   ```
%   See also: [run_case_file_splitter](run_case_file_splitter.md)
%    params.max_iter = params.max_iter;
%    params.tol = 1e-6;
%    params.rou = params.rho;


    [sol, violation, iter, loggX] = run_ADMM_cplex(problem, params);
    xsol = vertcat(sol{:});
    [xsol, xsol_stacked] = deal_solution(xsol, mpc, names); 
   
    %% numerical solution back to matpower casefile
    elapsed_time  =  NaN;
    alg           =  'ADMM';
    mpc_sol       =  back_to_mpc(mpc, xsol, elapsed_time, iter, alg);
end