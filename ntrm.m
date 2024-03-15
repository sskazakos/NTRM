function NetworkTheoryResilienceMetric = ntrm(source_file, sample_size)
%%  Network Theory Resilience Metric (NTRM)

%   This code samples cascade scenarios from a MATPOWER case file, then
%   runs the AC Cascading Failure Model (AC-CFM) code, for all the
%   resulting cases. Then, a set of network science metrics for the network
%   under study are derived, using MATLAB and BCT functions. The following
%   parameters are calculated:
% 
%       - Degree centrality of each node (bus)
%       - Eigenvecor centrality of each node (bus)
%       - Betweenness centrality of each node (bus)
%       - Closeness centrality of each node (bus)
%       - Clustering coefficient of each node (bus)
%       - Self-admittance of each bus
%       - Edge betweenness centrality for each edge (branch)
%       - [Degree of node(i) * Degree of node(j)] for each edge (branch)
%       - Total load shedding each branch causes in all scenarios
%       - Total amount of times each branch contributed to a cascade
% 
%   Prerequisites:
%       - Matlab R2020b or later (but may work with earlier versions)
%       - Matpower 7.1 or later
%           https://matpower.org/
%           https://github.com/MATPOWER/matpower
%       - AC-CFM and its prerequisites
%           https://github.com/mnoebels/AC-CFM, Reference: Noebels, M.,
%           Preece, R., Panteli, M. "AC Cascading Failure Model for
%           Resilience Analysis in Power Networks." IEEE Systems Journal (2020).
%       - Brain Connectivity Toolbox (BCT)
%           https://sites.google.com/site/bctnet/home, Reference: Rubinov M,
%           Sporns O, "Complex network measures of brain connectivity:
%           Uses and interpretations", (2010) NeuroImage 52:1059-69.

%   The authors would like to thank Mathaios Panteli for valuable discussions
%   and support. This work was supported by the Engineering and Physical
%   Sciences Research Council [EP/W034204/1]

%   NTRM
%   Copyright (c) 2023-2024, Mahdi Amouzadi, Spyros Skarvelis-Kazakos, Istvan Kiss
%   This file is part of NTRM.
%   Covered by the 3-clause BSD License (see LICENSE file for details).

%   ***********************************************************************
%%  LICENSE INFORMATION:

%   BSD 3-Clause License
%
%   Copyright (c) 2023-2024, University of Sussex and individual
%   contributors (Mahdi Amouzadi, Spyros Skarvelis-Kazakos, Istvan Kiss)
%   All rights reserved.
%
%   Redistribution and use in source and binary forms, with or without
%   modification, are permitted provided that the following conditions are
%   met:
% 
%   1. Redistributions of source code must retain the above copyright
%      notice, this list of conditions and the following disclaimer.
% 
%   2. Redistributions in binary form must reproduce the above copyright
%      notice, this list of conditions and the following disclaimer in the
%      documentation and/or other materials provided with the distribution.
% 
%   3. Neither the name of the copyright holder nor the names of its
%      contributors may be used to endorse or promote products derived from
%      this software without specific prior written permission.
% 
%   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
%   IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
%   TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
%   PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
%   HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
%   LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
%   DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
%   THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
%   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
%   OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%
%   ***********************************************************************

%% Initialisation

    source_file = 'case39.m'; % specify the desired MATPOWER case
    % Define the minimum number of initial failures. This is used in the
    % scenario generation, to define the complete set of scenarios that
    % will be generated.
    fail_min = 3;

%% Removing existing content in TempTestCase.m then copying the desired MATPOWER case and pasting it back to TempTestCase

    % This is to remove all content of a temporary .m file 
    file_name = 'TempTestCase.m'; %specify the name of the temporary .m file
    fileID = fopen(file_name,'w');
    fprintf(fileID,'');
    fclose(fileID);

    % This is to copy all the content of specified case into TempTestCase
    destination_file = file_name;
    fileID = fopen(source_file,'r');
    content = fread(fileID);
    fclose(fileID);
    fileID = fopen(destination_file,'w');
    fwrite(fileID,content);
    fclose(fileID);
    
%% Loading and conditioning the case file

    mpc = loadcase('TempTestCase');
    
    % OPTIONAL: Remove any branches? Note that if multiple branches are
    % removed, the index changes every time a branch is removed.
    mpc.branch(3,:) = [];
    mpc.branch(5,:) = [];
    
    %%%%%%%%%%%%%%
    
    n_bus = size(mpc.bus,1);%Number of buses
    n_branch = size(mpc.branch,1);%Number of branches

%% Deriving the scenarios

    scen_all = [];
    fprintf('Working out scenario list...\n');

    % The following parallel for loop creates all the possible scenarios
    % with the defined number of initial failures
    parfor k = 0:fail_min
        combos = nchoosek(1:n_branch, k);
        for i = 1:size(combos,1)
            b = zeros(1,n_branch);
            b(combos(i,:)) = 1;
            scen_all = [scen_all;b]; %all scenarios with the defined failures
        end
    end
    fprintf('Scenario list generated, now running cascade model...\n');

    % Taking only X (= sample_size) samples from all the scenarios.
    % If the full list of scenarios is required, then this should be:
    %   scen_rand = scen_all
    % (NOTE: In large networks this may take A LONG TIME to compute)
    scen_rand = [scen_all(1:sample_size,:); scen_all(end-(sample_size-1):end,:)];  

 %% Initialising cascade model
    
    % load default AC-CFM settings
    settings = get_default_settings();
    % enable(1)/disable(0) verbose AC-CFM output – just for testing
    settings.verbose = 0;

    % derive the set of initial contingencies
    parfor i = 1:size(scen_rand,1)
        initial_contingency_ = [];
        for j = 1:size(scen_rand,2) 
            if scen_rand(i,j) == 1
               initial_contingency_ = [initial_contingency_;j];
            end
        end
        initial_contingency{i,:} = initial_contingency_;
    end
    
%% Running cascade model

    result = accfm_branch_scenarios(mpc, initial_contingency, settings);
  
%% Processing the cascade modelling results

    % set up the arrays that will receive the cascade count and shedding
    cascade_branchNumber = zeros(size(scen_rand,1),n_branch);
    totalLoadShedding = zeros(size(scen_rand,1),n_branch);
    num_cascade=zeros(size(scen_rand,1),1);
    
    % tally up the cascade count and shedding
    for i = 1:size(scen_rand,1)
        if result.contingency(i) >= 1 %if a cascade is developed
           for j = 1:size(scen_rand,2)
               if scen_rand(i,j) == 1
                    cascade_branchNumber(i,j) = 1;  %save in a matrix the which buses caused the cascade
                    totalLoadShedding(i,j) = result.lost_load_final(i); 
               end
           end
           num_cascade = num_cascade + 1;%count the total number of cascades
        end
    end
    
    % output the final values for load shedding
    totalloadshedding_branch = zeros(n_branch,1);
    totalloadshedding_branch = transpose(sum(totalLoadShedding,1)); %shows how much loaded shedding each branch causes in all scenarios 
    % output the final values for the cascade count
    cascade_branchNumber_total = zeros(1,n_branch);
    cascade_branchNumber_total = transpose(sum(cascade_branchNumber,1));%shows how many times each branch contributed to a failure

%%  Developing the graph

    % initialise the arrays for the graph and self-admittance calculation
    A = zeros(n_bus,n_bus);
    self_admittance = zeros(size(mpc.bus,1),1);

    % calculate the adjacency matrix A and the self-admittance matrix
    for i = 1:size(mpc.branch,1)
        A(mpc.branch(i,1),mpc.branch(i,2)) = 1;
        A(mpc.branch(i,2),mpc.branch(i,1)) = 1;
        self_admittance(mpc.branch(i,1)) = self_admittance(mpc.branch(i,1)) + 1/mpc.branch(i,4);
        self_admittance(mpc.branch(i,2)) = self_admittance(mpc.branch(i,2)) + 1/mpc.branch(i,4);
    end

    % derive and plot the graph B
    B = graph(A);
    plot(B)
    
    % calculate the network science and electrical parameters FOR THE NODES:
    % - Degree centrality
    % - Eigenvector centrality
    % - Betweenness centrality
    % - Closeness centrality
    % - Clustering coefficient
    % - Self-admittance
    cen_de = zeros(size(mpc.branch,1),3);
    cen_de(1:size(mpc.bus(:,1)),1) = mpc.bus(:,1); % bus list
    cen_de(:,2) = mpc.branch(:,1); % branch bus from
    cen_de(:,3) = mpc.branch(:,2); % branch bus to
    cen_de(1:size(mpc.bus(:,1)),4) = centrality(B,'degree');
    cen_de(1:size(mpc.bus(:,1)),5) = centrality(B,'eigenvector');
    cen_de(1:size(mpc.bus(:,1)),6) = centrality(B,'betweenness');
    cen_de(1:size(mpc.bus(:,1)),7) = centrality(B,'closeness');
    cen_de(1:size(mpc.bus(:,1)),8) = clustering_coef_bu(A);
    cen_de(1:size(mpc.bus(:,1)),9) = self_admittance;
    
    % calculate the network science parameters FOR THE BRANCHES
    % (note that this requires the Brain Connectivity Toolbox):
    % - Edge betweenness centrality
    % - Degree of node(i) * Degree of node(j)
    EBC = edge_betweenness_bin(A);
    for i = 1:size(mpc.branch(:,1))
        cen_de(i:size(mpc.branch(:,1)),10) = cen_de(mpc.branch(i,1),4) * cen_de(mpc.branch(i,2),4);
        cen_de(i:size(mpc.branch(:,1)),11) = EBC(mpc.branch(i,1),mpc.branch(i,2));
    end
    
%% Return results
    NetworkTheoryResilienceMetric.BusList = cen_de(1:size(mpc.bus(:,1)),1);
    NetworkTheoryResilienceMetric.BranchBusFrom = cen_de(:,2);
    NetworkTheoryResilienceMetric.BranchBusTo = cen_de(:,3);
    NetworkTheoryResilienceMetric.DegreeCentrality = cen_de(1:size(mpc.bus(:,1)),4);
    NetworkTheoryResilienceMetric.EigenvectorCentrality = cen_de(1:size(mpc.bus(:,1)),5);
    NetworkTheoryResilienceMetric.BetweennessCentrality = cen_de(1:size(mpc.bus(:,1)),6);
    NetworkTheoryResilienceMetric.ClosenessCentrality = cen_de(1:size(mpc.bus(:,1)),7);
    NetworkTheoryResilienceMetric.ClusteringCoefficient = cen_de(1:size(mpc.bus(:,1)),8);
    NetworkTheoryResilienceMetric.SelfAdmittance = cen_de(1:size(mpc.bus(:,1)),9);
    NetworkTheoryResilienceMetric.node_i_node_j = cen_de(1:size(mpc.branch(:,1)),10);
    NetworkTheoryResilienceMetric.EdgeBetweennessCentrality = cen_de(1:size(mpc.branch(:,1)),11);
    NetworkTheoryResilienceMetric.TotalCascades = cascade_branchNumber_total;
    NetworkTheoryResilienceMetric.TotalShedding = totalloadshedding_branch;
    
    