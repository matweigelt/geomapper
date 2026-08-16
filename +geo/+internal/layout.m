function varargout = layout(command, varargin)
%GEO.INTERNAL.LAYOUT  One resize manager per figure, for L3 elements.
%
%   SYNTAX
%     id    = GEO.INTERNAL.LAYOUT("register", AX, KIND, UPDATEFCN)
%             GEO.INTERNAL.LAYOUT("setRect", AX, KIND, RECTPT)
%             GEO.INTERNAL.LAYOUT("setData", AX, KIND, VALUE)
%     value = GEO.INTERNAL.LAYOUT("data", AX, KIND)
%     rects = GEO.INTERNAL.LAYOUT("rects", AX)
%     rects = GEO.INTERNAL.LAYOUT("rects", AX, EXCEPTKIND)
%             GEO.INTERNAL.LAYOUT("update", FIG)
%             GEO.INTERNAL.LAYOUT("remove", AX, KIND)
%             GEO.INTERNAL.LAYOUT("clear", FIG)
%     n     = GEO.INTERNAL.LAYOUT("count", FIG)
%     k     = GEO.INTERNAL.LAYOUT("kinds", FIG)
%
%   DESCRIPTION
%     Replaces five v1 plumbing functions - `geoChainCallback`,
%     `geoAttachResizeCallback`, `geoRegisterInsetRect`,
%     `geoGetOtherInsetRects` and the per-element resize callbacks - with
%     one registry per figure and one listener.
%
%     A LISTENER, NOT A CHAINED SizeChangedFcn, and this is the whole
%     point of the rewrite. v1 attached each element by capturing the
%     figure's existing `SizeChangedFcn` into a new closure that called
%     it first. Five failure modes followed, all of them real:
%
%       - the chain could not be enumerated, detached or de-duplicated,
%         because it existed only as nested closures;
%       - anyone setting `SizeChangedFcn` directly - another toolbox, or
%         a user - detached every element at once, silently;
%       - a bare `catch` swallowed exceptions from earlier links with no
%         identifier and no warning, so a broken element disabled an
%         arbitrary number of older ones and nothing said so;
%       - the newest link sat OUTSIDE that catch, so if it threw, MATLAB
%         disabled the figure's callback and took the whole chain with
%         it;
%       - a legacy char callback matched neither branch and was dropped.
%
%     One `addlistener` has none of these properties. Listeners compose
%     by construction: adding one never removes another, and a third
%     party setting `SizeChangedFcn` does not detach it.
%
%     STATE LIVES IN ONE RESERVED FIELD, `fig.UserData.geoMapLayout`.
%     Not `appdata`: defect F15, and the Stage 0 audit rejects
%     `setappdata`/`getappdata` anywhere in +geo. UserData that is
%     already a non-struct is an error rather than a silent overwrite -
%     it is somebody's data.
%
%     REGISTERING THE SAME KIND TWICE REPLACES, NEVER DUPLICATES. That
%     is what makes a second `geo.basemap` call on one axes an update
%     rather than a second frame drawn over the first, and it is
%     asserted by a constant handle count rather than described.
%
%     EVERY UPDATE RUNS IN ITS OWN TRY/CATCH AND WARNS. An element that
%     throws during a resize is reported by identifier, once, and the
%     remaining elements still update. Silence here was v1's worst
%     property: a map that stopped responding to resize looked exactly
%     like a map that had nothing registered.
%
%   INPUTS
%     command  (1,1) string  One of the verbs above.
%     Remaining inputs depend on the command:
%       ax         (1,1) matlab.graphics.axis.Axes
%       kind       (1,1) string   Element name, e.g. "frame". Unique per
%                                 axes; re-registering replaces.
%       updateFcn  (1,1) function_handle  Called as updateFcn(ax).
%       rectPt     (1,4) double   [x y w h] in FIGURE POINTS, the
%                                 element's on-screen footprint.
%       fig        (1,1) matlab.ui.Figure
%
%   OUTPUTS
%     id     (1,1) string   "<kind>#<axes address>", stable for the life
%                           of the axes.
%     value  any          Whatever the element last stored: its own
%                         handles, so that a redraw deletes what it
%                         drew rather than searching for it. []
%                         before the first setData.
%     rects  (N,4) double   Footprints registered by OTHER elements in
%                           the same figure, for collision avoidance. An
%                           element never sees its own.
%     n      (1,1) double   How many entries the figure holds.
%     k      (1,:) string   Their kinds, in registration order.
%
%   ACCURACY
%     No numerical claim. Rectangles are stored and returned in figure
%     points exactly as given; this function does no unit conversion,
%     because a rectangle whose units changed on the way through a
%     registry is the kind of error that only shows up on a second
%     monitor.
%
%   ERRORS
%     geo:layout:BadCommand      - unknown verb; the message lists them
%     geo:layout:UserDataInUse   - fig.UserData holds a non-struct
%     geo:layout:NotRegistered   - setRect or remove for an unknown kind
%     geo:layout:DeletedAxes     - the axes given has been deleted
%
%   WARNINGS
%     geo:layout:UpdateFailed    - an element's update function threw
%                                  during a resize; named, not swallowed
%
%   EXAMPLE
%     f = figure; ax = axes(Parent = f);
%     geo.internal.layout("register", ax, "frame", @(a) disp(a.Position));
%     geo.internal.layout("update", f);
%
%   LIMITATIONS
%     One registry per FIGURE, keyed by axes and kind, so two axes in one
%     figure each get their own "frame" entry but two figures never share
%     one. Elements are updated in registration order, which is the order
%     they were drawn; nothing here resolves a genuine layout conflict
%     between two elements that both want the same corner - that is
%     GEO.INTERNAL.AVOIDRECTCOLLISIONS' job, and it is greedy.
%
%   See also GEO.INTERNAL.AVOIDRECTCOLLISIONS, GEO.BASEMAP, GEO.FRAME.
%
%   ---------------------------------------------------------------------
%   geoMap v2.0 | 16-Aug-2026 | Claude Opus 5 (Anthropic)

arguments
    command (1,1) string
end
arguments (Repeating)
    varargin
end

varargout = cell(1, max(nargout, 0));
switch command
    case "register"
        [ax, kind, fcn] = deal(varargin{1:3});
        out = doRegister(ax, string(kind), fcn);
        if nargout > 0, varargout{1} = out; end
    case "setRect"
        doSetRect(varargin{1}, string(varargin{2}), varargin{3});
    case "setData"
        doSetData(varargin{1}, string(varargin{2}), varargin{3});
    case "data"
        varargout{1} = doData(varargin{1}, string(varargin{2}));
    case "rects"
        except = "";
        if numel(varargin) >= 2, except = string(varargin{2}); end
        varargout{1} = doRects(varargin{1}, except);
    case "update"
        doUpdate(varargin{1});
    case "remove"
        doRemove(varargin{1}, string(varargin{2}));
    case "clear"
        doClear(varargin{1});
    case "count"
        varargout{1} = numel(store(varargin{1}).Entries);
    case "kinds"
        varargout{1} = [store(varargin{1}).Entries.Kind];
    otherwise
        error('geo:layout:BadCommand', ...
            ['"%s" is not a layout command. Known: register, setRect, ' ...
             'setData, data, rects, update, remove, clear, count, ' ...
             'kinds.'], command);
end
end

% ======================================================================
function S = store(fig)
%STORE  The registry for a figure, created empty on first use.
fig = figureOf(fig);
u = fig.UserData;
if isempty(u)
    u = struct();
elseif ~isstruct(u)
    error('geo:layout:UserDataInUse', ...
        ['This figure''s UserData holds a %s, and the layout manager ' ...
         'needs the reserved field UserData.geoMapLayout. It is not ' ...
         'overwritten, because it is somebody''s data. Move it into a ' ...
         'struct field, or draw into a different figure.'], class(u));
end
if ~isfield(u, 'geoMapLayout')
    u.geoMapLayout = struct( ...
        'Entries', emptyEntry(), ...
        'Listener', event.listener.empty);
    fig.UserData = u;
end
S = fig.UserData.geoMapLayout;
end

function setStore(fig, S)
%SETSTORE  Write the registry back, touching nothing else in UserData.
fig = figureOf(fig);
u = fig.UserData;
if isempty(u), u = struct(); end
u.geoMapLayout = S;
fig.UserData = u;
end

function e = emptyEntry()
%EMPTYENTRY  The entry shape, in one place so the fields cannot drift.
e = struct('Kind', {}, 'Axes', {}, 'Update', {}, 'Rect', {}, 'Data', {});
end

function doSetData(ax, kind, value)
%DOSETDATA  Keep an element's own handles and state beside its entry.
%   THIS IS WHY NOTHING NEEDS FINDOBJ. An element that redraws must find
%   what it drew last time. v1 rediscovered objects by tag, which the
%   Stage 0 audit bans (§2.7): a tag search finds whatever else happens
%   to carry that tag, including another toolbox's. Here the handles
%   never left the registry, so there is nothing to find.
fig = figureOf(ax);
S = store(fig);
k = findEntry(S, ax, kind);
if isempty(k)
    error('geo:layout:NotRegistered', ...
        ['"%s" has no entry on these axes, so its state has nowhere ' ...
         'to go. Register it first.'], kind);
end
S.Entries(k).Data = value;
setStore(fig, S);
end

function value = doData(ax, kind)
%DODATA  An element's stored state, or [] if it has never registered.
%   Empty rather than an error, so a first call and a redraw take the
%   same path and the idempotent branch is not a special case.
value = [];
if ~isvalid(ax)
    return
end
S = store(figureOf(ax));
k = findEntry(S, ax, kind);
if ~isempty(k)
    value = S.Entries(k).Data;
end
end

function fig = figureOf(h)
%FIGUREOF  The figure owning a handle, without rediscovering anything.
if ~isvalid(h)
    error('geo:layout:DeletedAxes', ...
        'The axes or figure given has been deleted.');
end
if isa(h, 'matlab.ui.Figure')
    fig = h;
    return
end
fig = ancestor(h, 'figure');
end

function id = doRegister(ax, kind, fcn)
%DOREGISTER  Add or REPLACE an entry, and arm the listener once.
fig = figureOf(ax);
S = store(fig);
k = findEntry(S, ax, kind);
entry = struct('Kind', kind, 'Axes', ax, 'Update', fcn, ...
    'Rect', zeros(0, 4), 'Data', []);
if isempty(k)
    if isempty(S.Entries)
        S.Entries = entry;
    else
        S.Entries(end + 1) = entry;
    end
else
    % A REDRAW KEEPS ITS FOOTPRINT AND ITS STATE. Losing them here
    % would make the second call to an element behave differently
    % from the first, which is the opposite of idempotent.
    entry.Rect = S.Entries(k).Rect;
    entry.Data = S.Entries(k).Data;
    S.Entries(k) = entry;
end

% One listener per figure, armed on first registration. Re-arming would
% double every update, which is the duplication v1 could not detect.
if isempty(S.Listener) || ~isvalid(S.Listener)
    S.Listener = addlistener(fig, 'SizeChanged', ...
        @(src, ~) geo.internal.layout("update", src));
end
setStore(fig, S);
id = kind + "#" + string(sprintf('%.0f', double(ax)));
end

function k = findEntry(S, ax, kind)
%FINDENTRY  Index of the (axes, kind) entry, or empty.
k = [];
for i = 1:numel(S.Entries)
    if S.Entries(i).Kind == kind && S.Entries(i).Axes == ax
        k = i;
        return
    end
end
end

function doSetRect(ax, kind, rectPt)
%DOSETRECT  Publish an element's on-screen footprint, in points.
fig = figureOf(ax);
S = store(fig);
k = findEntry(S, ax, kind);
if isempty(k)
    error('geo:layout:NotRegistered', ...
        ['"%s" has no entry on these axes, so its footprint has ' ...
         'nowhere to go. Register it before publishing a rectangle.'], ...
        kind);
end
S.Entries(k).Rect = reshape(double(rectPt), 1, 4);
setStore(fig, S);
end

function rects = doRects(ax, exceptKind)
%DORECTS  Footprints of the OTHER elements in this figure.
%   Its own is excluded so that an element does not dodge the rectangle
%   it published last time and walk away from its own corner.
S = store(figureOf(ax));
n = numel(S.Entries);
rects = zeros(n, 4);
m = 0;
for i = 1:n
    e = S.Entries(i);
    if isempty(e.Rect) || (exceptKind ~= "" && e.Kind == exceptKind)
        continue
    end
    m = m + 1;
    rects(m, :) = e.Rect;
end
rects = rects(1:m, :);
end

function doUpdate(fig)
%DOUPDATE  Run every live element's update, each isolated from the rest.
fig = figureOf(fig);
S = store(fig);
alive = true(1, numel(S.Entries));
for i = 1:numel(S.Entries)
    e = S.Entries(i);
    if ~isvalid(e.Axes)
        alive(i) = false;               % the axes went; drop the entry
        continue
    end
    try
        e.Update(e.Axes);
    catch ME
        % NAMED, NOT SWALLOWED. v1's bare catch made a broken element
        % indistinguishable from an absent one.
        warning('geo:layout:UpdateFailed', ...
            ['The "%s" element failed to update on resize: %s (%s). ' ...
             'The other elements still updated.'], ...
            e.Kind, ME.message, ME.identifier);
    end
end
if ~all(alive)
    S = store(fig);                     % re-read: an update may have set it
    S.Entries = S.Entries(alive);
    setStore(fig, S);
end
end

function doRemove(ax, kind)
%DOREMOVE  Detach one element. v1 had no way to do this at all.
fig = figureOf(ax);
S = store(fig);
k = findEntry(S, ax, kind);
if isempty(k)
    error('geo:layout:NotRegistered', ...
        '"%s" has no entry on these axes, so there is nothing to remove.', ...
        kind);
end
S.Entries(k) = [];
setStore(fig, S);
end

function doClear(fig)
%DOCLEAR  Forget everything and disarm, leaving the rest of UserData.
fig = figureOf(fig);
S = store(fig);
if ~isempty(S.Listener) && isvalid(S.Listener)
    delete(S.Listener);
end
S.Entries = emptyEntry();
S.Listener = event.listener.empty;
setStore(fig, S);
end
