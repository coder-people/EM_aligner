function [mL] = solve_slab(rc, pm, nfirst, nlast, rctarget, opts)
% solve a slab (range of z-coordinates) within collection rc using point matches in point-match
% collection pm.
% the slab is delimited by nfirst and nlast, which are z-values. nlast is not included.
% For example usage see "solve_slab_01.m" under the "test_scripts" folder
%
% Author: Khaled Khairy
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cs     = nlast-nfirst + 1;
sh     = 0;     % this is core overlap. Actual overlap is this number + 2;

%% configure solver using defaults if opts is not provided
if ~isempty(opts)
    opts.min_tiles = 2; % minimum number of tiles that constitute a cluster to be solved. Below this, no modification happens
    opts.degree = 2;    % 1 = affine, 2 = second order polynomial, maximum is 3
    opts.outlier_lambda = 1e3;  % large numbers result in fewer tiles excluded
    opts.lambda = 1e2;
    opts.edge_lambda = 1e4;
    opts.solver = 'backslash';
end


%% get the list of zvalues and section ids within the z range between nfirst and nlast (inclusive)
urlChar = sprintf('%s/owner/%s/project/%s/stack/%s/sectionData', ...
    rc.baseURL, rc.owner, rc.project, rc.stack);
j = webread(urlChar);
sectionId = {j(:).sectionId};
z         = [j(:).z];
indx = find(z>=nfirst & z<=nlast);
[z, I]         = sort(z(indx));        % determine the zvalues (this is also the spatial order)
sectionId = sectionId(indx);% determine the sectionId list we will work with
sectionId = sectionId(I);


%% Determine chuncks
v = 1:numel(z);
[Y,X]=ndgrid(1:(cs-sh):(numel(v)-cs+1),0:cs-1);
chnks = X+Y;
chnks = [chnks(:,1) chnks(:,end)];
chnks(end) = numel(z);


%% Calculate solution for each chunck. This is designed so that in the future each process of chunch solution can be distributed independently
collection = cell(size(chnks,1),1);
zfirst = zeros(size(chnks,1),1);
zlast  = zeros(size(chnks,1),1);
for ix = 1:size(chnks,1)
    disp('------------- solving ----------');
    zfirst(ix) = str2double(sectionId{chnks(ix,1)});
    zlast(ix)  = str2double(sectionId{chnks(ix,2)});
    disp([zfirst(ix) zlast(ix)]);
    [L, ~, ~] = load_point_matches(zfirst(ix), zlast(ix), rc, pm);
    %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %     %% The solver can only handle clusters of tiles that are sufficiently connected
    %     %  Orphan tiles are not allowed, nor tiles with too few point matches
    %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [L_vec, ntiles] = reduce_to_connected_components(L);
    L_vec(ntiles<10) = [];
    
    %% Solve: Provide the collection of connected components and they will each be individually solved
    [mL, err1, R1] = solve_clusters(L_vec, opts);   % solves individual clusters and reassembles them into one
    %%%% ingest into Renderer database
    %     cd(dir_temp);    save(collection{ix}, 'mL', 'rc', 'pm', 'opts', 'chnks', 'sectionId', 'z');
    if ~isempty(rctarget)
        ingest_section_into_renderer_database_overwrite(mL,rctarget, rc, pwd);
        disp('Ingesting:');
        disp(rctarget);
    end
end