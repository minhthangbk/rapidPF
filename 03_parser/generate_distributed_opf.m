function problem = generate_distributed_opf(mpc, names, problem_type)
% generate_distributed_opf
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
    % extract Data from casefile
    [N_regions, N_buses_in_regions, N_copy_buses_in_regions, ~] = get_relevant_information(mpc, names);
    [costs,  inequalities, equalities, xx0, grads, Jacs, Hessians, states, dims, lbs, ubs] = deal(cell(N_regions,1));
    connection_table = mpc.(names.consensus);
    % set up the Ai's

    % create local power flow problems
    fprintf('\n\n');
    for i = 1:N_regions
        fprintf('Creating power flow problem for system %i...', i);
        [cost, inequality, equality, x0, grad, eq_jac, ineq_jac, Hessian, state, dim, lb, ub] = build_local_opf(mpc.(names.split){i}, names, num2str(i));
        % combine Jacobians of inequalities and equalities in single Jacobian
        Jac = @(x)[eq_jac(x), ineq_jac(x)]';
        [costs{i},  inequalities{i}, equalities{i}, xx0{i}, grads{i}, Jacs{i}, Hessians{i}, states{i}, dims{i}, lbs{i}, ubs{i}] = deal(cost, inequality, equality, x0, grad, Jac, Hessian, state, dim, lb, ub);
        fprintf('done.\n')
    end
    
    N_generators_in_regions = struct_for_N_generators(dims);
    consensus_matrices = create_consensus_matrices_opf(connection_table, N_buses_in_regions, N_generators_in_regions);
    %% generate output for Aladin
    problem.locFuns.ffi = costs;
    problem.locFuns.ggi = equalities;
    problem.locFuns.hhi = inequalities;
    
    problem.locFuns.dims = dims;
    
    problem.sens.gg = grads;
    problem.sens.JJac = Jacs;
    problem.sens.HH = Hessians;

    problem.zz0 = xx0;
    problem.AA  = consensus_matrices;
    
    problem.state = states;
    
    problem.llbx = lbs;
    problem.uubx = ubs;
end

function N_generators = struct_for_N_generators(dims)
    n = numel(dims);
    N_generators = zeros(n, 1);
    for i = 1:n
        N_generators(i) = dims{i}.n.gen;
    end
end
    


