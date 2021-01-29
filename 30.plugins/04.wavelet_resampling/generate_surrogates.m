function generate_surrogates(input,mask,varoptin)

% This script generates surrogate volumes for a certain input. Enjoy a good sleep!
%
% Required arg:
%    - input: the input files
%    - mask: the mask used to constrain the surrogate
% Optional arg (in order):
%    - Nsurr: Number of surrogates to output
%        - Def: 1000
%    - outfolder: folder where to place the surrogates
%        - Def: same as file basename
%    - prefix: the prefix to give to the surrogate
%        - Def: same as file basename

% Setting defaults for the varoptin
optvar = {1000, '', ''};

% Reading the varoptin
numvarin = length(varoptin);

% Reading optional arguments
if numvarin >= 1
    optvar(1:numvarin) = varoptin;
end

% Finally starting with variables
[Nsurr,outfolder,prefix] = optvar{:};

Nsurr = str2double(Nsurr);
dimresamp = [1 1 0];
adjust = 1;
[sPath, sFilename, sExt] = fileparts(input);

if outfolder ~= ''
    mkdir(outfolder)
else
    outfolder = sPath
end

if prefix == ''
    prefix = sFilename
end

for i=0:(Nsurr-1)
    Vsurr = strcat(outfolder,'/',sprintf('%s_Surr_%03i.nii.gz',prefix,i));
    fprintf('Computing surrogate %03i/%03i\n',i,(Nsurr-1));
    getsurrogate_nifti(input,mask,Vsurr,dimresamp,adjust);
end
