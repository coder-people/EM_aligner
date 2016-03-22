function [obj, errAb, mL, invalid_similarity, invalid_translation] = get_rigid_approximation(obj, solver)
%% calculates an approximation to a rigid transformation using the combination
% [1] Similarity constained
% [2] Rescaling
% [3] Translation only
% This function depends on the "solver" utility functions
% Author: Khaled Khairy Janelia Research Campus (HHMI) 2015
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

lsq_options.L2              = [];
lsq_options.U2              = [];
lsq_options.A               = [];
lsq_options.b               = [];
lsq_options.B               = [];
lsq_options.d               = [];
lsq_options.tB              = [];
lsq_options.td              = [];
lsq_options.W               = [];
lsq_options.dw              = [];


lsq_options.solver          = 'backslash';%'gmres';%'cgs';%'backslash';%;%'tfqmr';%'pcg';%'bicgstab';%''symmlq';%minres';%'lsqlin';% ;%'lsqr';%'bicgstab' bicg tfqmr backslash
lsq_options.constraint      = 'similarity';%'explicit';% 'trivial';%
lsq_options.constraint_only = 1;
lsq_options.pdegree         = 1;
lsq_options.lidfix          = 1;
lsq_options.tfix            = numel(obj.tiles);

lsq_options.verbose         = 0;
lsq_options.debug           = 0;

lsq_options.ilu_droptol     = 1e-16;
lsq_options.use_ilu         = 1;
lsq_options.ilu_type        = 'ilutp';%'crout'; %'nofill';%%;
lsq_options.ilu_udiag       = 1;
lsq_options.restart         = 10;
lsq_options.tol             = 1e-16;
lsq_options.maxit           = 10000;

if nargin>1
   lsq_options.solver       = solver;
end


[mL,err, R,A, b, B, d, W, K, Lm, xout, L2, U2, tB, td, invalid_similarity] = alignTEM_solver(obj, [], lsq_options);


%% %% adjust scale--- mL
mtiles = mL.tiles;
parfor ix = 1:numel(mL.tiles)
    %disp([ix mL.tiles(ix).tform.T(1) mL.tiles(ix).tform.T(5)]);
    %imshow(get_warped_image(mL.tiles(ix)));
    t = mL.tiles(ix);
    [U S V] = svd(t.tform.T(1:2, 1:2));
    T = U * [1 0; 0 1] * V';
    t.tform.T(1:2,1:2) = T;
    %t.tform.T([3 6]) = t.tform.T([3 6]) * 1/S;
    mtiles(ix) = t;
    %imshow(get_warped_image(t));title(num2str(ix));
    %pause(1);
end
mL.tiles = mtiles;
%% transform point matches in order to translate
M = mL.pm.M;
adj = mL.pm.adj;
for pix = 1:size(M,1) % loop over point matches
    %%%%%transform points for the first of the two tiles
    pm = M{pix,1};
    T = mL.tiles(adj(pix,1)).tform.T;
    pmt = pm*T(1:2,1:2);
    M{pix,1}(:) = pmt;
    %%%%%%%%%%%transform points for the second of the two tiles
    pm = M{pix,2};
    T = mL.tiles(adj(pix,2)).tform.T;
    pmt = pm*T(1:2,1:2);
    M{pix,2} = pmt;
end
mL.pm.M = M;
mL.pm.adj = adj;
%% fit for translation only
% Important: To do translation only we need to specify "no constraints", we
% need to specify the tiles to fix and the polynomial degree should be zero
%%%%%%%%%%%%%%%%%%%%%
mL = update_adjacency(mL);
mL = update_XY(mL);
lsq_options.solver          = 'backslash';%
lsq_options.constraint      = 'none';%'explicit';%'similarity';% 'trivial';%
lsq_options.pdegree         = 0;  %
lsq_options.constraint_only = 0;
lsq_options.lidfix          = 1;
lsq_options.tfix            = numel(obj.tiles);
lsq_options.constrain_edges = 0;

[mL2,errAb,R, At, bt, B, d, W, Kt, Lmt, xout, L2, U2, tB, td, invalid_translation] = alignTEM_solver(mL, [], lsq_options);
errAb = norm(At*xout-bt);
obj.tiles = mL2.tiles;  % only tile transformations are changed (not point-match information)











