function n = makeManifest(root)
%MAKEMANIFEST  Regenerate MANIFEST.txt over the whole tree.
%
%   DESCRIPTION
%     Under Tier B the entire tree ships as one artefact per round, never a
%     partial file set. The manifest lists every shipped path with a line
%     count and a content hash; the runner verifies the tree against it
%     BEFORE running anything. This converts a transfer loss from a
%     mysterious test failure discovered rounds later into a legible
%     message at the top of the log.
%
%     Under Tier A the manifest is still generated - it then guards only
%     the download, not the run.
%
%   SYNTAX
%     n = makeManifest()
%     n = makeManifest(root)
%
%   INPUTS
%     root  (1,:) char  [geoMapRoot()]  Tree root.
%
%   OUTPUTS
%     n     (1,1) double  Number of files listed.
%
%   ERRORS
%     Input:
%       geo:makeManifest:NoSuchRoot - root is not a directory
%
%   EXAMPLE
%     makeManifest();
%
%   See also RUNGEOMAPTESTS, SHA256OFTEXT.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)
%   PROVISIONAL: not verified until its first green run.

arguments
    root (1,:) char = geoMapRoot()
end
if ~isfolder(root)
    error('geo:makeManifest:NoSuchRoot', ...
        'Not a directory: %s', root);
end

pats = {'*.m', '*.md', '*.py', '*.json', '*.xml', '*.prj'};
files = strings(0);
for i = 1:numel(pats)
    d = dir(fullfile(root, '**', pats{i}));
    for k = 1:numel(d)
        if d(k).isdir, continue, end
        rel = erase(fullfile(d(k).folder, d(k).name), [root filesep]);
        rel = strrep(rel, filesep, '/');
        if startsWith(rel, ".git") || contains(rel, "__pycache__")
            continue
        end
        files(end+1) = string(rel); %#ok<AGROW>
    end
end
files = unique(files);
files(files == "MANIFEST.txt") = [];

lines = strings(numel(files), 1);
for i = 1:numel(files)
    txt = fileread(fullfile(root, files(i)));
    lines(i) = sprintf('%s\t%d\t%s', files(i), ...
        numel(splitlines(txt)), sha256OfText(txt));
end

hdr = [ ...
    "# geoMap v2 transfer manifest"
    "# path<TAB>lines<TAB>sha256"
    "# Verified by rungeoMapTests BEFORE any test runs."
    "# Regenerate with makeManifest after every change."
    "# generated " + string(datetime("now"))];

fid = fopen(fullfile(root, 'MANIFEST.txt'), 'w');
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', hdr);
fprintf(fid, '%s\n', lines);
n = numel(files);
fprintf('MANIFEST.txt written: %d files\n', n);
end
