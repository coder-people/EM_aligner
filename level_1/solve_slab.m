function [mL, pm_mx, err, R] = solve_slab(rc, pm, nfirst, nlast, rctarget, opts)
% solve a slab (range of z-coordinates) within collection rc using point matches in point-match
% collection pm.
% the slab is delimited by nfirst and nlast, which are z-values. nlast is not included.
% For example usage see "test_solve_slab_01.m" under the "test_scripts" folder
% pm_mx is a point-match count correlation matrix: useful for spotting missing point-matches or
% excessive cross-layer correlation to generate point matches.
%
% Author: Khaled Khairy
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
verbose = 1;
if ~isfield(opts, 'nbrs'), opts.nbrs = 2;end
if ~isfield(opts, 'min_points'), opts.min_points = 5;end
if ~isfield(opts, 'xs_weight'), opts.xs_weight = 1;end
if ~isfield(opts, 'stvec_flag'), opts.stvec_flag = 0;end  % when set to zero, solver will perform rigid transformation to get a starting value
if ~isfield(opts, 'translate_to_origin'), opts.translate_to_origin = 1;end
cs     = nlast-nfirst + 1;
sh     = 0;     % this is core overlap. Actual overlap is this number + 2;

%% configure solver using defaults if opts is not provided
if isempty(opts)
    opts.min_tiles = 2; % minimum number of tiles that constitute a cluster to be solved. Below this, no modification happens
    opts.degree = 1;    % 1 = affine, 2 = second order polynomial, maximum is 3
    opts.outlier_lambda = 1e3;  % large numbers result in fewer tiles excluded
    opts.lambda = 1e2;
    opts.edge_lambda = 1e4;
    opts.solver = 'backslash';
end

if verbose, disp(opts);end

%% get the list of zvalues and section ids within the z range between nfirst and nlast (inclusive)
urlChar = sprintf('%s/owner/%s/project/%s/stack/%s/sectionData', ...
    rc.baseURL, rc.owner, rc.project, rc.stack);
j = webread(urlChar);
sectionId = {j(:).sectionId};
z         = [j(:).z];
indx = find(z>=nfirst & z<=nlast);
sectionId = sectionId(indx);% determine the sectionId list we will work with
z         = z(indx);        % determine the zvalues (this is also the spatial order)
[z, ia] = sort(z);
% sectionId = sectionId(ia);

%% Determine chuncks
v = 1:numel(z);
[Y,X]=ndgrid(1:(cs-sh):(numel(v)-cs+1),0:cs-1);
chnks = X+Y;
chnks = [chnks(:,1) chnks(:,end)];
chnks(end) = numel(z);

if verbose, disp('Chuncks: ');disp(chnks);end

%% Calculate solution for each chunck. This is designed so that in the future each process of chunch solution can be distributed independently
collection = cell(size(chnks,1),1);
zfirst = zeros(size(chnks,1),1);
zlast  = zeros(size(chnks,1),1);
err = {};
pm_mx = {};  % stores the poin-match count correlation matrix
for ix = 1:size(chnks,1)
    disp('------------- solving ----------');
    zfirst(ix) = z(chnks(ix,1));%str2double(sectionId{chnks(ix,1)});%%str2double(sectionId{chnks(ix,1)});
    zlast(ix)  = z(chnks(ix,2));%str2double(sectionId{chnks(ix,2)});%str2double(sectionId{chnks(ix,2)});
    disp([zfirst(ix) zlast(ix)]);
    [L, ~, ~, pm_mx{ix}] = load_point_matches(zfirst(ix), zlast(ix), rc, pm, opts.nbrs, opts.min_points, opts.xs_weight); % disp(pm_mx{ix});
    %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %     %% The solver can only handle clusters of tiles that are sufficiently connected
    %     %  Orphan tiles are not allowed, nor tiles with too few point matches
    %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [L_vec, ntiles] = reduce_to_connected_components(L);
    L_vec(ntiles<10) = [];
    
    %% Solve: Provide the collection of connected components and they will each be individually solved
    [mL, err{ix}, R{ix}] = solve_clusters(L_vec, opts, opts.stvec_flag);   % solves individual clusters and reassembles them into one
    %%%% ingest into Renderer database
    %     cd(dir_temp);    save(collection{ix}, 'mL', 'rc', 'pm', 'opts', 'chnks', 'sectionId', 'z');
    if ~isempty(rctarget)
        %%%%%%%%%%%%% SOSI ----- code to check validity of tile collection goes here
        
        
        
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        ingest_section_into_renderer_database(mL,rctarget, rc, pwd, opts.translate_to_origin);
        if verbose, disp('Ingesting:'); disp(rctarget);end
    end
end


































