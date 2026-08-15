function h = sha256OfText(txt)
%SHA256OFTEXT  SHA-256 of a char vector, as lowercase hex.
%
%   DESCRIPTION
%     Used by the transfer manifest so a truncated or altered file is a
%     legible message at the top of the runner log rather than a
%     mysterious test failure discovered rounds later.
%
%     Uses the JVM's MessageDigest, which is present in desktop MATLAB.
%     Where the JVM is unavailable (-nojvm), falls back to a weaker
%     checksum AND says so in the returned string, so a weaker instrument
%     can never be mistaken for the strong one.
%
%   INPUTS
%     txt  (1,:) char   File contents.
%
%   OUTPUTS
%     h    (1,1) string  64 hex characters, or "weak:<n>" on fallback.
%
%   EXAMPLE
%     sha256OfText(fileread('README.md'))
%
%   See also MAKEMANIFEST, RUNGEOMAPTESTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 13-Aug-2026 | Claude Opus 5 (Anthropic)
%   PROVISIONAL: not verified until its first green run.

arguments
    txt (1,:) char
end

if usejava('jvm')
    md = java.security.MessageDigest.getInstance('SHA-256');
    if isempty(txt)
        % uint8('') is 1x0 and reaches Java as null, so digest(null)
        % throws NullPointerException. digest() with no argument is
        % the hash of the empty input, which is what we want. Found by
        % the NIST empty-string vector; no static check could see it
        % (finding PV-017).
        b = md.digest();
    else
        b = md.digest(uint8(txt));
    end
    h = string(lower(reshape(dec2hex(typecast(b, 'uint8'), 2)', 1, [])));
else
    % Deliberately labelled: a fallback that looks like the real thing is
    % worse than one that announces itself.
    v = double(txt);
    acc = uint64(1469598103934665603);
    for i = 1:numel(v)
        acc = bitxor(acc, uint64(v(i)));
        acc = acc * uint64(1099511628211);
    end
    h = "weak:" + string(dec2hex(acc));
end
end
