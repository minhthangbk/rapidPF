function [cost, ineq, eq, x0, pf, bus_specifications, Jac, grad_cost, Hessian, state, dims] = generate_local_power_flow_problem(mpc, names, postfix, problem_type)
% generate_local_power_flow_problem
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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% The following code (implicitly) assumes that the copy buses are
%%% always at the end of the bus numbering.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% There is currently an inconsistency between the set up of the power
%%% flow equations:
%%%     'create power flow equations for all nodes stored in
%%%     buses_local',
%%% and the bus specifications:
%%%     'create bus specifications and remove copy buses'.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    buses_core = mpc.(names.regions.global);
    N_core = numel(buses_core);
    buses_local = 1:N_core;
    copy_buses_local = mpc.(names.copy_buses.local);
    N_copy = numel(copy_buses_local);
    Ybus = makeYbus(ext2int(mpc));
    
    [Vang_core, Vmag_core, Pnet_core, Qnet_core] = create_state(postfix, N_core);
    [Vang_copy, Vmag_copy, Pnet_copy, Qnet_copy] = create_state(strcat(postfix, '_copy'), N_copy);
    
    Vang = [Vang_core; Vang_copy];
    Vmag = [Vmag_core; Vmag_copy];
    Pnet = Pnet_core;
    Qnet = Qnet_core;
    P_ = [Pnet_core; Pnet_copy];
    Q_ = [Qnet_core; Qnet_copy];
    
    state = stack_state(Vang, Vmag, Pnet, Qnet);
    %% power flow equations
    entries_pf = build_entries(N_core, N_copy, true);
    pf_p = @(x)create_power_flow_equation_for_p(x(entries_pf{1}), x(entries_pf{2}), x(entries_pf{3}), x(entries_pf{4}), Ybus, buses_local);
    pf_q = @(x)create_power_flow_equation_for_q(x(entries_pf{1}), x(entries_pf{2}), x(entries_pf{3}), x(entries_pf{4}), Ybus, buses_local);
    %% optimal power flow cost functions
    %--- probably not needed because lagranian multipliers are not needed
    %from MATPOWER, only objective function needs to be copied ---%
    nb   = size(mpc.bus, 1);    %% number of buses
    nl   = size(mpc.branch, 1); %% number of branches
    ng   = size(mpc.gen, 1);    %% number of dispatchable injections
%    if size(mpc.bus,2) < MU_VMIN
%        mpc.bus = [mpc.bus zeros(nb, MU_VMIN-size(mpc.bus,2)) ];
%    end
%    if size(mpc.gen,2) < MU_QMIN
%        mpc.gen = [ mpc.gen zeros(ng, MU_QMIN-size(mpc.gen,2)) ];
%    end
%    if size(mpc.branch,2) < MU_ANGMAX
%        mpc.branch = [ mpc.branch zeros(nl, MU_ANGMAX-size(mpc.branch,2)) ];
%    end

% for MATPOWER OPF ...
%    [mpc_opf, mpopt] = opf_args(mpc); % only respect most simple opf formulation so far
%    mpc_opf = ext2int(mpc_opf, mpopt);
%    om = opf_setup(mpc_opf, mpopt);

%    f_fcn = @(x)opf_costfcn(x, om);
    opf_p = @(x) create_opf_cost_functions_for_p(x(entries_pf{3}), mpc.gencost, mpc, copy_buses_local);
    %% optimal power flow inequalities
%    not useful, as I first thougth that power limits are written as inequalities    
%    ineq_p = @(x) create_opf_ineqs(x(entries_pf{3}), mpc.gen); 
    %% bus specifications
    entries_bus_specs = build_entries(N_core, N_copy, false);
    bus_specifications = @(x)create_bus_specifications(x(entries_bus_specs{1}), x(entries_bus_specs{2}), x(entries_bus_specs{3}), x(entries_bus_specs{4}), mpc, copy_buses_local);
    %% initial condition
    [Vang0, Vmag0, Pnet0, Qnet0] = create_initial_condition(mpc, copy_buses_local);
    x0 = stack_state(Vang0, Vmag0, Pnet0, Qnet0);
    %% sensitivities
    Jac_pf  = @(x)jacobian_power_flow(x(entries_pf{1}), x(entries_pf{2}), x(entries_pf{3}), x(entries_pf{4}), Ybus, copy_buses_local);
    Jac_bus = jacobian_bus_specifications(mpc, copy_buses_local);
    Jac_g_ls    = @(x)[Jac_pf(x); Jac_bus];
    %% sensitivities opf
    gradient_costs = @(x) create_opf_cost_gradient_for_p(x(entries_pf{3}), mpc.gencost);
    hessian_costs = @(x) create_hessian_for_cost_p(x(entries_pf{3}), mpc.gencost);
    % hess_ineq_p = @(x) zeros(length(mpc.gen{:, 1}), length(mpc.gen{:, 1}));
    %% check sizes
    has_correct_size(x0, 4*N_core + 2*N_copy);
    has_correct_size(pf_p(x0), N_core);
    has_correct_size(pf_q(x0), N_core);
    has_correct_size(bus_specifications(x0), 2*N_core);
    %% generate return values
    if strcmp(problem_type,'feasibility')
        cost = @(x) opf_p(x);
        grad_cost = @(x)gradient_costs(x);
        % grad_cost = @(x) zeros(4*N_core + 2*N_copy, 1);
        % TODO modify for OPF -> add second derivative of f
        Hessian = @(x, kappa, rho)jacobian_num(@(y)[Jac_pf(y); Jac_bus]'*kappa, x,  4*N_core + 2*N_copy, 4*N_core+ 2*N_copy);
        % cost = @(x) opf_p(x);
        ineq = @(x) [];
        eq = @(x)[ pf_p(x); pf_q(x); bus_specifications(x) ];
        pf = @(x)[ pf_p(x); pf_q(x) ];
        % TODO modify to gradient of cost (and later of h)
        Jac = Jac_g_ls;
        dims.eq = 4*N_core;
        dims.ineq = []; 
       % dims.ineq = length(mpc.gencost(:, 1));
    elseif strcmp(problem_type,'least-squares')
        g_ls    =  @(x)[pf_p(x); pf_q(x); bus_specifications(x)];
        grad_cost = @(x)(2*Jac_g_ls(x)'* g_ls(x));
        Hessian =  @(x,kappa, rho)(2*Jac_g_ls(x)'*Jac_g_ls(x));%@(x,kappa, rho)(2*Jac_g_ls(x)'*Jac_g_ls(x)); %@(x, kappa, rho)jacobian_num(@(y)(grad_cost(y)), x, 4*N_core + 2*N_copy, 4*N_core + 2*N_copy);
        cost = @(x)(g_ls(x)'*g_ls(x));
        ineq = @(x)[];
        eq = @(x)[];
        pf = @(x)[ pf_p(x); pf_q(x) ];
        Jac = @(x)[];
        dims.eq = [];
        dims.ineq = [];
    end
end

function entries = build_entries(N_core, N_copy, with_core)
    if with_core
        N = N_copy;
    else
        N = 0;
    end
        
    entries = cell(4, 1);
    dummy = { 1:N+N_core, 1:N+N_core, 1:N_core, 1:N_core };
    nums = kron([N_core + N_copy; N_core], ones(2, 1));
    nums_cum = [0 ; cumsum(nums)];
    for i = 1:4
        entries{i} = dummy{i} + nums_cum(i);
    end
end