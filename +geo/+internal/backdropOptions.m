function names = backdropOptions()
%GEO.INTERNAL.BACKDROPOPTIONS  The options a data-map front owns itself.
%
%   SYNTAX
%     names = GEO.INTERNAL.BACKDROPOPTIONS()
%
%   DESCRIPTION
%     The one list of option names GEO.TRACKMAP and GEO.POINTMAP keep
%     rather than forward.
%
%     WHY IT IS A FUNCTION AND NOT A LITERAL IN EACH FRONT. The two
%     fronts must own EXACTLY the same set, because they hand it to the
%     same resolver. Written twice it would be right twice and then
%     wrong once - which is not a guess about the future: v1's
%     geoImagescTrack and geoImagescPoints each carried their own extent
%     options and disagreed about the pad. A list in two places is a
%     list that will differ.
%
%   INPUTS
%     (none)
%
%   OUTPUTS
%     names  (1,:) string  Option names owned by the data-map fronts.
%
%   ACCURACY
%     Exact: it is a list of names.
%
%   ERRORS
%     (none raised)
%
%   EXAMPLE
%     [own, rest] = geo.internal.splitOptions(varargin, ...
%         geo.internal.backdropOptions());
%
%   LIMITATIONS
%     Adding a name here gives it to both fronts, which is the point. An
%     option that genuinely belongs to only one does not go in this list.
%
%   See also GEO.INTERNAL.MAPBACKDROP, GEO.TRACKMAP, GEO.POINTMAP.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 20-Aug-2026 | Claude Opus 5 (Anthropic)

names = ["Pad" "Region" "LonLimit" "LatLimit" ...
         "Background" "BackgroundResolution"];
end
