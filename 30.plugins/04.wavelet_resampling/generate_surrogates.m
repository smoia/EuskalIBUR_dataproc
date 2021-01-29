function generate_surrogates(infile,mask,Nsurr,outfolder,prefix)
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

if nargin < 2
	disp('Missing required infile and mask!')
	disp()
	disp('This script generates surrogate volumes for a certain input. Enjoy a good sleep!')
	disp('')
	disp('Required arg:')
	disp('   - input: the input files')
	disp('   - mask: the mask used to constrain the surrogate')
	disp('Optional arg (in order):')
	disp('   - Nsurr: Number of surrogates to output')
	disp('       - Def: 1000')
	disp('   - outfolder: folder where to place the surrogates')
	disp('       - Def: same as file basename')
	disp('   - prefix: the prefix to give to the surrogate')
	disp('       - Def: same as file basename')
	return
end

if infile == 'help'
	disp('This script generates surrogate volumes for a certain input. Enjoy a good sleep!')
	disp('')
	disp('Required arg:')
	disp('   - input: the input files')
	disp('   - mask: the mask used to constrain the surrogate')
	disp('Optional arg (in order):')
	disp('   - Nsurr: Number of surrogates to output')
	disp('       - Def: 1000')
	disp('   - outfolder: folder where to place the surrogates')
	disp('       - Def: same as file basename')
	disp('   - prefix: the prefix to give to the surrogate')
	disp('       - Def: same as file basename')
	return
end

if nargin < 3
	Nsurr = 1000
end
if nargin < 4
    outfolder = sPath
else
    mkdir(outfolder)
end
if nargin < 5
    prefix = sFilename
end

Nsurr = str2double(Nsurr);
dimresamp = [1 1 0];
adjust = 1;
[sPath, sFilename, sExt] = fileparts(infile);

for i=0:(Nsurr-1)
    Vsurr = strcat(outfolder,'/',sprintf('%s_Surr_%03i.nii.gz',prefix,i));
    fprintf('Computing surrogate %03i/%03i\n',i,(Nsurr-1));
    getsurrogate_nifti(input,mask,Vsurr,dimresamp,adjust);
end
