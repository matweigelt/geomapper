function [lon, lat] = pairCoordinates(lon, lat, errId)
%GEO.INTERNAL.PAIRCOORDINATES  Match two coordinate arrays, meshgridding.
%
%   SYNTAX
%     [LON, LAT] = GEO.INTERNAL.PAIRCOORDINATES(LON, LAT, ERRID)
%
%   DESCRIPTION
%     Accepts either two arrays of the same size, or a ROW of longitudes
%     with a COLUMN of latitudes, which it expands into a full grid. The
%     convenience matters because the alternative is an NDGRID at every
%     call site, and a caller who forgets one gets a silently wrong answer
%     rather than an error: two vectors of different lengths would
%     broadcast into a shape nobody wanted.
%
%     THE ROW/COLUMN RULE IS DELIBERATE AND ASYMMETRIC. Row longitude with
%     column latitude produces an array whose first dimension is latitude,
%     matching GEO.GRID's canonical Z orientation, so a projected grid can
%     be handed straight to SURF beside its Z. The reverse pairing (column
%     lon, row lat) is NOT accepted, because accepting both would make the
%     output orientation depend on the input in a way no caller could
%     predict from the documentation.
%
%     THE IDENTIFIER IS THE CALLER'S, passed in full. A shared validator
%     raising geo:internal:... would send a reader to a function they have
%     never called (finding PV-049).
%
%   INPUTS
%     lon    double     Degrees East.
%     lat    double     Degrees North.
%     errId  (1,:) char The COMPLETE identifier to raise, written out at
%                       the call site, e.g. 'geo:project:SizeMismatch'.
%
%   OUTPUTS
%     lon, lat  double  The same size as each other.
%
%   ACCURACY
%     No numerical claim; it only reshapes.
%
%   ERRORS
%     Raises whatever identifier its caller supplies, and documents none
%     of its own. The identifiers it can produce are documented on the
%     public functions that pass them in.
%
%   EXAMPLE
%     [lo, la] = geo.internal.pairCoordinates(-180:180, (-90:90).', ...
%                                             'geo:project:SizeMismatch');
%
%   LIMITATIONS
%     Scalar expansion is left to MATLAB: a scalar with an array is the
%     same size after implicit expansion, so this function passes it
%     through untouched and the arithmetic downstream does the work.
%
%   See also GEO.PROJECT, GEO.SCALEFACTORS.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 15-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    lon double
    lat double
    errId (1,:) char
end

if isequal(size(lon), size(lat)) || isscalar(lon) || isscalar(lat)
    return
end
if isrow(lon) && iscolumn(lat)
    [lon, lat] = meshgrid(lon, lat);
    return
end
error(errId, ...
    ['lon is %s and lat is %s. They must be the same size, or a ROW of ' ...
     'longitudes with a COLUMN of latitudes to be meshgridded. The ' ...
     'reverse pairing is not accepted: allowing both would make the ' ...
     'output orientation depend on the input unpredictably.'], ...
    mat2str(size(lon)), mat2str(size(lat)));
end
