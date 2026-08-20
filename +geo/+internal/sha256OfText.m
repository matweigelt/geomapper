function h = sha256OfText(txt)
%SHA256OFTEXT  SHA-256 of a char vector, as lowercase hex.
%
%   SYNTAX
%     h = GEO.INTERNAL.SHA256OFTEXT(TXT)
%
%   DESCRIPTION
%     Used by the transfer manifest so a truncated or altered file is a
%     legible message at the top of the runner log rather than a
%     mysterious test failure discovered rounds later, and by GEO.CACHE
%     to key a parsed coastline.
%
%     IT LIVES IN +geo/+internal BECAUSE GEO.CACHE NEEDS IT. It sat in
%     tools/ for eleven checkpoints, which meant a toolbox installed
%     without tools/ - that is, every installed toolbox - raised
%     "Undefined function 'sha256OfText'" the first time anything drew a
%     coastline (finding PV-127). The harness now calls the package's
%     copy rather than the package borrowing the harness's, because the
%     shipped code is the side that must stand alone.
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
%   ACCURACY
%     Exact, and verified against the NIST vectors for "" and "abc" in
%     TestStage0_instruments rather than against itself. A hash checked
%     only for self-consistency would agree with its own mistakes.
%
%     THE FALLBACK IS NOT SHA-256 AND SAYS SO IN ITS OWN RETURN VALUE.
%     Under -nojvm it returns "weak:<hex>", an FNV-1a checksum, so a
%     caller comparing two digests still gets a correct answer and a
%     caller printing one cannot mistake it for the strong instrument.
%     It is a change-detector, not a cryptographic one.
%
%   ERRORS
%     MATLAB:validation:UnableToConvert - txt is not convertible to
%                                         (1,:) char
%     (nothing else; the JVM path is guarded rather than caught)
%
%   EXAMPLE
%     geo.internal.sha256OfText(fileread('README.md'))
%
%   See also GEO.CACHE, MAKEMANIFEST, RUNGEOMAPTESTS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

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
