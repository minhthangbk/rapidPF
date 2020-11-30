function [mpc_opf, om, copy_buses_local, mpopt] = prepare_case_file(mpc, names)
% PREPARE_CASE_FILE 
%
%   `[mpc_opf, om, copy_buses_local, mpopt] = prepare_case_file(mpc, names))`
%
%   _Prepares the splitted case file to such that MATPOWER opf functions and methodes can be applied_
%
%   INPUT:  - mpc splitted case files
%           - names names of mpc struct fields
%   OUTPUT: - mpc_opf cleaned up matpower casefile (deleted generators) in MATPOWER internal numering
%           - om MATPOWER optimization model of mpc_opf
%           - copy_buses_local local copy buses
%           - mpopt MATPOWER optimization parameters

    [GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, GEN_STATUS, PMAX, PMIN, ...
            MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN, PC1, PC2, QC1MIN, QC1MAX, ...
            QC2MIN, QC2MAX, RAMP_AGC, RAMP_10, RAMP_30, RAMP_Q, APF] = idx_gen;
    
    mpc = ext2int(mpc);
    copy_buses_local = mpc.(names.copy_buses.local);
    copy_bus_types = get_bus_types(mpc.bus, copy_buses_local);
    %% turn off generators at copy nodes
    for i = 1:length(copy_bus_types)
        if copy_bus_types(i) == 2 || copy_bus_types(i) == 3
            % get correct generator row in mpc.gen field 
            gen_entry = find_generator_gen_entry(mpc, copy_buses_local(i));
            % turn off corresponding generator
            mpc.gen(gen_entry, GEN_STATUS) = 0;
        end
    end
    
    %% check whether there is still a generator left that is switched on
    assert(sum(mpc.gen(:, GEN_STATUS)) ~= 0, 'All generators in subsystem are switched off') 
    
    %% we changed the case file after it was switched to internal indexing
    % we need to account for that
    % ??? option in line 40 safer??? 
    mpc.order.state = 'e';
    % mpc = int2ext(mpc);
    %% return values
    [mpc_opf, mpopt] = opf_args(mpc);
    mpc_opf = ext2int(mpc_opf);
    om = opf_setup(mpc_opf, mpopt);
end

function types = get_bus_types(bus, buses)
    [PQ, PV, REF, NONE, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM, ...
        VA, BASE_KV, ZONE, VMAX, VMIN, LAM_P, LAM_Q, MU_VMAX, MU_VMIN] = idx_bus;
    types = bus(buses, BUS_TYPE);
end