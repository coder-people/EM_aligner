%% experiment with intensity correction
rc.stack          = 'four_tile_montage';
rc.owner          ='flyTEM';
rc.project        = 'test_warp_field';
rc.service_host   = '10.40.3.162:8080';
rc.baseURL        = ['http://' rc.service_host '/render-ws/v1'];
rc.verbose        = 0;

clear pm;
ix = 1;
pm(ix).server = 'http://10.40.3.162:8080/render-ws/v1';
pm(ix).owner = 'flyTEM';
pm(ix).match_collection = 'FAFB_pm_7';%'v12_dmesh';% %'FAFB_pm_4'; % %'v12_dmesh';%'v12_dmesh';%'v12_dmesh';%

dir_scratch = '/scratch/khairyk/';

%% configure point match fetching
opts.nbrs = 2;
opts.min_points = 3;
opts.max_points = inf;
opts.filter_point_matches = 1;
% configure point-match filter
opts.pmopts.NumRandomSamplingsMethod = 'Desired confidence';
opts.pmopts.MaximumRandomSamples = 5000;
opts.pmopts.DesiredConfidence = 99.9;
opts.pmopts.PixelDistanceThreshold = 1;

z = 1;
L = get_section_point_matches(rc, z, dir_scratch, opts, pm);

% [z] = get_section_ids(rc);
%L = Msection(rc,z);
[Wbox, bbox, url] = get_section_bounds_renderer(rc, z);


%% Render
sb1 = Wbox(4)+1;
sb2 = Wbox(3)+1;
IM = {};
parfor ix = 1:numel(L.tiles)
    I = zeros( sb1, sb2);
    im = get_image(L.tiles(ix));
    r1 = L.tiles(ix).minX-Wbox(2)+1;
    r2 = r1+size(im,2)+1;%L.tiles(ix).minX + L.tiles(ix).maxX-Wbox(1);
    c1 = L.tiles(ix).minY-Wbox(1)+1;
    c2 = c1 + size(im,1)+1;%L.tiles(ix).minY + L.tiles(ix).maxY-Wbox(2);
    I(c1+1:c2-1,r1+1:r2-1) = mat2gray(im);
    I = I(1:sb1, 1:sb2);
    IM{ix} = I;
    
end

I = zeros(sb1, sb2);
for ix = 1:numel(IM)
    im = IM{ix}; 
    indx = im>0.0;
   I(indx) = im(indx);
end
imshow(I);









