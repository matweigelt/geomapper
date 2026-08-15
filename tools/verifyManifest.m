function [ok, report] = verifyManifest(root)
%VERIFYMANIFEST  Check a tree against its transfer manifest.
%
%   DESCRIPTION
%     Extracted from the runner so that a fault-injection test can prove it
%     FIRES on a broken tree and is SILENT on a healthy one. A check
%     without a fixture proving it fires is not a check.
%
%   INPUTS
%     root    (1,:) char   Tree root containing MANIFEST.txt.
%
%   OUTPUTS
%     ok      (1,1) logical  True only if every listed file is present and
%                            matches on both line count and hash.
%     report  (1,1) string   Human-readable result, named files on failure.
%
%   EXAMPLE
%     [ok, msg] = verifyManifest(geoMapRoot());
%
%   See also MAKEMANIFEST, RUNGEOMAPTESTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)
%   PROVISIONAL: not verified until its first green run.

mf = fullfile(root, 'MANIFEST.txt');
if exist(mf, 'file') ~= 2
    ok = false;
    report = sprintf(['MANIFEST.txt not found. Run makeManifest first. ' ...
        'Without it, a transfer loss becomes a mysterious test failure ' ...
        'discovered rounds later instead of a message at the top of ' ...
        'this log.']);
    return
end
txt = string(splitlines(strtrim(fileread(mf))));
txt(txt == "" | startsWith(txt, "#")) = [];
missingFiles = strings(0);
altered = strings(0);
for i = 1:numel(txt)
    parts = split(txt(i), sprintf('\t'));
    if numel(parts) < 3, continue, end
    rel = parts(1); nLines = str2double(parts(2)); h = parts(3);
    f = fullfile(root, rel);
    if exist(f, 'file') ~= 2
        missingFiles(end+1) = rel; %#ok<AGROW>
        continue
    end
    [thisLines, thisHash] = fileFingerprint(f);
    if thisLines ~= nLines || thisHash ~= h
        altered(end+1) = sprintf('%s (lines %d vs %d)', rel, thisLines, nLines); %#ok<AGROW>
    end
end
ok = isempty(missingFiles) && isempty(altered);
if ok
    report = sprintf('verified: %d files match MANIFEST.txt', numel(txt));
else
    report = sprintf(['MISMATCH. missing: %s | altered: %s\n' ...
        '           Stop and re-ship the tree; do not diagnose test\n' ...
        '           failures against a tree that is not the one shipped.'], ...
        localTernary(isempty(missingFiles), '(none)', strjoin(missingFiles, ', ')), ...
        localTernary(isempty(altered), '(none)', strjoin(altered, ', ')));
end
end

function [n, h] = fileFingerprint(f)
txt = fileread(f);
n = numel(splitlines(txt));
h = sha256OfText(txt);
end

function out = localTernary(c, a, b)
if c, out = a; else, out = b; end
end
