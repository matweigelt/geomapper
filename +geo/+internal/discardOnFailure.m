function discardOnFailure(figH, created)
%DISCARDONFAILURE  Delete a figure this toolbox created and did not finish.
%
%   SYNTAX
%     GEO.INTERNAL.DISCARDONFAILURE(FIGH, CREATED)
%
%   DESCRIPTION
%     Called from the catch block of every function that may create a
%     figure and then fail part way through drawing into it. It deletes
%     the figure if and only if this toolbox created it, and is silent
%     when the caller supplied the axes.
%
%     WHY THE RULE NEEDED A FUNCTION RATHER THAN FOUR LINES TWICE.
%     GEO.BASEMAP creates the figure; GEO.MAP climbs a fourteen-rung
%     ladder into it and can fail on any rung. Both must discard, both
%     must discard only what they made, and the condition is one fact
%     (CODING_GUIDE R1). Written out at each site it would be right
%     twice and then wrong once - which is not a guess: the same shape
%     of duplication is what made v1's two data-map fronts disagree
%     about their padding.
%
%     THE DEFECT IT CLOSES (PV-149). A green 516-point run left four
%     visible figures open on the target machine. All four came from one
%     test, which asserts that GEO.MAP raises geo:map:MissingField when
%     an element is given options but no data. GEO.MAP created the
%     figure in its first rung, threw on a later one, and nothing owned
%     the figure it had already made. Two of the four had a full
%     graticule and coastline; two had only the basemap surface, because
%     Polygons and Stipple sit lower on the ladder than Graticule does.
%     The half-drawn pair is what a reader sees as an "unfinished" plot -
%     it is not unfinished, it is abandoned.
%
%     WHY THE SUITE WAS GREEN ANYWAY. Every gate the runner applies
%     reads results, warnings, filters, budgets, coverage or sources.
%     None of them looked at the graphics root, so leaked figures were
%     invisible to all of them - VALIDATION_GUIDE Part 10, a test that
%     changes the machine it measures. FIGURECENSUSPLUGIN now reads it,
%     which is the second gate reading something the first does not.
%
%     WHY DELETE AND NOT CLOSE. CLOSE runs CloseRequestFcn, which a
%     caller may have replaced and which may refuse. Discarding a
%     half-built figure during error unwinding must not be refusable and
%     must not run user code, so this is DELETE.
%
%   INPUTS
%     figH     (1,1) matlab.ui.Figure  The figure to consider. May
%                                      already be deleted; that is not an
%                                      error.
%     created  (1,1) logical           True when this toolbox created
%                                      FIGH, false when the caller
%                                      supplied the axes it lives in.
%
%   OUTPUTS
%     (none)
%
%   ACCURACY
%     Not applicable: no numerical claim. The behavioural claim - a
%     failed front leaves the figure count unchanged - is asserted in
%     TestE1_map and measured for the whole suite by FIGURECENSUSPLUGIN.
%
%   ERRORS
%     (none raised; it runs during error unwinding and must not add a
%     second error to the one already in flight)
%
%   EXAMPLE
%     try
%         drawEverything(figH);
%     catch err
%         geo.internal.discardOnFailure(figH, created);
%         rethrow(err);
%     end
%
%   LIMITATIONS
%     It cannot know about a figure the caller created and handed over
%     expecting this toolbox to own it. CREATED is passed in rather than
%     guessed precisely because that distinction is not readable from the
%     figure itself.
%
%   See also GEO.BASEMAP, GEO.MAP, FIGURECENSUSPLUGIN.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 22-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    figH (1,1) matlab.ui.Figure
    created (1,1) logical
end

if created && isgraphics(figH, 'figure')
    delete(figH);
end
end
