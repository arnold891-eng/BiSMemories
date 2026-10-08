--[[
  BiSMemories :: Core/Journal.lua - the album, in game.

      /memories journal         open it (also /memories album)

  WHAT THIS IS AND IS NOT. Arn asked for the album inside the addon, reading the Screenshots
  folder. The reading is not possible and never will be, on any client:

    * no addon can list a directory. There is no API for "what files are in Screenshots". The
      only reason this addon knows a picture exists is that IT called Screenshot() and wrote the
      filename down from the clock.
    * a texture loads from Interface\ and from BLP or TGA. A .jpg sitting in the client's
      Screenshots folder cannot be drawn on a frame at all. That is why album.html exists: a
      browser can open those files and the game cannot.

  So this is the journal, not the album: what happened, in words, with the filename beside each
  entry so a picture on disk can be matched to the night it came from. The pictures stay with the
  companion. Nobody should have to be told this twice, hence the length of this comment.

  AND ON THIS CLIENT IT IS TODAY ONLY. The Forever beta hands back no saved variables, so the log
  starts empty at every login. The window is honest about that rather than looking broken - see
  the empty line at the bottom of Refresh. If the client is ever fixed, this same window becomes
  a real history with nothing else to change.
]]
local ADDON, ns = ...
local T, M = ns.T, ns.M
local J = {}
ns.J = J

local ROWS = 12                 -- how many fit; the wheel moves a page of them
local GAP = 3 * 60 * 60         -- seconds of quiet that end a raid night (same rule as the album)
-- TALL ENOUGH FOR WHAT IS IN IT. 300 was right for twelve rows and a footer; the copy box and its
-- label went in underneath and printed straight through the last two memories (3 Oct 2026, Arn's
-- screenshot). Twelve rows end 270 below the top, the box and its label want about 70 from the
-- bottom, and the arithmetic has to be written down or the next thing added lands on top again.
local W, H = 440, 348

local function when(at)
  if not at or at == 0 then return "?" end
  return date and date("%d %b %H:%M", at) or tostring(at)
end

--- Where the album page is, as far as this addon can honestly say.
---
--- The tail is certain - every WoW install puts an addon in the same place relative to its own
--- version folder. The head is not knowable from in game, so it is whatever the player told us
--- with `/memories wow`, and until they do, the line says plainly which bit is missing.
local TAIL = [[Interface\AddOns\BiSMemories\Album\BiSMemories-Album.html]]

function J.AlbumPath()
    local d = ns.DB and ns.DB()
    local root = type(d) == "table" and d.wowPath or nil
    if type(root) ~= "string" or root == "" then return TAIL end
    return (root:gsub("[\\/]+$", "")) .. "\\" .. TAIL
end

--- True when the path above is the whole thing rather than the tail.
function J.AlbumPathWhole()
    local d = ns.DB and ns.DB()
    local root = type(d) == "table" and d.wowPath or nil
    return type(root) == "string" and root ~= ""
end

--- Remember where WoW is, so the box holds a path a browser will take. Returns what was stored.
---
--- Deliberately not validated beyond trimming: an addon cannot check that a folder exists, and
--- refusing a path we cannot verify would be refusing the only thing the player knows better
--- than we do.
function J.SetWow(path)
    local d = ns.DB and ns.DB()
    if type(d) ~= "table" then return nil end
    if type(path) ~= "string" or path:gsub("%s", "") == "" then
        d.wowPath = nil
    else
        d.wowPath = (path:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[\\/]+$", ""))
    end
    if J.frame and J.frame:IsShown() then J.Refresh() end
    return d.wowPath
end

--- One entry as a row: when, why, what. WHERE AND WHO ARE IN THE TOOLTIP (6 Oct 2026). The row
--- used to carry the zone and ", with 4" too, and a real one - a death in "Blackrock Depths - The
--- Grim Guzzler", whose detail IS that zone - needed 531 px of a 416 px row; the client cut it
--- with "...". The night's heading already names the place, and a count is a caption: one row,
--- one label, the rest on hover. The chat listing (Slash.lua) keeps the long form - chat wraps.
function J.Line(e)
  if type(e) ~= "table" then return "" end
  return ("%s  %s  %s"):format(
    T.text("muted", when(e.at)),
    T.text("accent", e.reason or "?"),
    tostring(e.detail or ""))
end

--- What hovering a row says: where, who with, which picture on disk. Returns the lines, so a test
--- can ask without a tooltip.
function J.TipLines(e)
  if type(e) ~= "table" then return {} end
  local out = { tostring(e.zone or "?") }
  if type(e.with) == "table" and #e.with > 0 then out[#out + 1] = "with " .. #e.with end
  if e.file then out[#out + 1] = tostring(e.file) end
  return out
end

function J.Tip(owner, e)
  if not (GameTooltip and type(e) == "table") then return end
  local lines = J.TipLines(e)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(lines[1])
  for i = 2, #lines do GameTooltip:AddLine(T.text("muted", lines[i])) end
  GameTooltip:Show()
end

--- The log as LINES: a heading for each raid night, then that night's memories under it.
---
--- Same rule as the album page, deliberately - one log, one idea of what a night is. A night is a
--- run with no three-hour gap in it, so one that starts at eight and ends at twenty to one is one
--- night and not two days. It is titled by the zone its BOSSES died in, falling back to wherever
--- most of it happened, and dated by when it STARTED.
function J.Lines()
  local log = M.Log()
  local out, cur = {}, nil
  for i = 1, #log do
    local e = log[i]
    local at = tonumber(e.at) or 0
    -- the log is newest first, so each entry is OLDER than the one before it
    if not cur or (cur.oldest - at) > GAP then
      cur = { newest = at, oldest = at, bosses = 0, bossZone = nil, anyZone = e.zone }
      out[#out + 1] = { head = cur }
    end
    cur.oldest = at
    cur.anyZone = cur.anyZone or e.zone
    if e.reason == "boss" then
      cur.bosses = cur.bosses + 1
      cur.bossZone = cur.bossZone or e.zone
    end
    out[#out + 1] = { entry = e }
  end
  return out
end

--- A night's heading, as one line of text.
function J.Head(h)
  if type(h) ~= "table" then return "" end
  local where = h.bossZone or h.anyZone or "somewhere"
  local day = (date and h.oldest > 0) and date("%a %d %b", h.oldest) or "?"
  local from = (date and h.oldest > 0) and date("%H:%M", h.oldest) or "?"
  local to = (date and h.newest > 0) and date("%H:%M", h.newest) or "?"
  local span = (from == to) and from or (from .. "-" .. to)
  local kills = h.bosses > 0 and ("  " .. h.bosses .. (h.bosses == 1 and " boss" or " bosses")) or ""
  return T.text("accent", where) .. T.text("muted", ("  %s  %s%s"):format(day, span, kills))
end

local function build()
  if J.frame then return J.frame end

  local f = CreateFrame("Frame", "BiSMemoriesJournal", UIParent)
  f:SetSize(W, H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.82)

  local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  head:SetPoint("TOPLEFT", 12, -10)
  head:SetText(T.text("accent", "BiS> Memories"))

  -- ONE LABEL IN THE BAR, and the count is part of that label rather than a second string
  -- printing through it. Two FontStrings in one header did exactly that, twice, in another addon.
  f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.count:SetPoint("TOPRIGHT", -34, -12)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() J.Hide() end)

  f.rows, f.hits = {}, {}
  for i = 1, ROWS do
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 12, -34 - (i - 1) * 20)
    fs:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    f.rows[i] = fs
    -- the hover patch for the row's tooltip. A child under the mouse would swallow the window's
    -- drag, so it hands the drag on; the wheel is not enabled here, so it falls through to f.
    local hit = CreateFrame("Button", nil, f)
    hit:SetPoint("TOPLEFT", 12, -32 - (i - 1) * 20)
    hit:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    hit:SetHeight(20)
    hit:RegisterForDrag("LeftButton")
    hit:SetScript("OnDragStart", function() f:StartMoving() end)
    hit:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    hit:SetScript("OnEnter", function(self) J.Tip(self, self.entry) end)
    hit:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f.hits[i] = hit
  end

  -- WHERE THE ALBUM IS, IN A BOX YOU CAN COPY (3 Oct 2026). Arn, having gone looking for it:
  -- the pictures live in a page on disk and nothing in game ever said where. A font string cannot
  -- be copied, so this is an EditBox - the same trick every export string in every addon uses -
  -- and clicking it selects the lot, ready for Ctrl+C.
  --
  -- NO ADDON CAN KNOW ITS OWN FULL PATH. There is no API for the install directory and none for
  -- the flavour folder either: GetBuildInfo gives a version, not a place. So the part that is
  -- ALWAYS true is shown by default, and `/memories wow <folder>` makes it absolute and keeps it.
  -- That is also why the folder is not written down anywhere here - `_classic_beta_` is today's
  -- name and will not be the name at launch, and a guess that goes stale is worse than a line that
  -- tells the truth.
  f.pathLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.pathLabel:SetPoint("BOTTOMLEFT", 12, 50)
  f.pathLabel:SetJustifyH("LEFT")

  f.pathBox = CreateFrame("EditBox", nil, f)
  f.pathBox:SetPoint("BOTTOMLEFT", 12, 28)
  f.pathBox:SetPoint("RIGHT", f, "RIGHT", -12, 0)
  f.pathBox:SetHeight(18)
  f.pathBox:SetAutoFocus(false)
  f.pathBox:SetFontObject("GameFontHighlightSmall")
  f.pathBox:SetTextInsets(4, 4, 0, 0)
  local boxBG = f.pathBox:CreateTexture(nil, "BACKGROUND")
  boxBG:SetAllPoints()
  boxBG:SetColorTexture(1, 1, 1, 0.07)
  -- select on click, and again whenever focus arrives: a player who clicks it wants all of it
  f.pathBox:SetScript("OnMouseUp", function(self) self:HighlightText() self:SetFocus() end)
  f.pathBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  f.pathBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  -- typing in it must not change the answer: whatever is typed, the path comes back
  f.pathBox:SetScript("OnEnterPressed", function(self) self:SetText(J.AlbumPath()) self:HighlightText() end)

  f.foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.foot:SetPoint("BOTTOMLEFT", 12, 10)
  f.foot:SetPoint("RIGHT", f, "RIGHT", -12, 0)
  f.foot:SetJustifyH("LEFT")

  -- the wheel walks the list, because a scrollbar is a lot of frame for twelve lines
  f:EnableMouseWheel(true)
  f:SetScript("OnMouseWheel", function(_, delta) J.Scroll(-delta) end)

  -- Escape closes it, the way every other window in the game does
  if UISpecialFrames then table.insert(UISpecialFrames, "BiSMemoriesJournal") end

  f:Hide()
  J.frame = f
  return f
end

--- Move by `by` rows, clamped. Returns where it landed, so a test can ask.
function J.Scroll(by)
  local most = math.max(0, #J.Lines() - ROWS)
  J.offset = math.max(0, math.min(most, (J.offset or 0) + (by or 0)))
  if J.frame and J.frame:IsShown() then J.Refresh() end
  return J.offset
end

function J.Refresh()
  local f = build()
  local lines = J.Lines()
  local n = #M.Log()
  J.offset = math.max(0, math.min(math.max(0, #lines - ROWS), J.offset or 0))

  f.count:SetText(T.text("muted", n == 0 and "" or (n .. " kept")))

  for i = 1, ROWS do
    -- NEWEST FIRST: the log is kept newest-first already (Memories.lua inserts at 1), so the
    -- offset counts down the page rather than up from the end
    local l = lines[i + J.offset]
    f.hits[i].entry = l and l.entry or nil
    if not l then f.rows[i]:SetText("")
    elseif l.head then f.rows[i]:SetText(J.Head(l.head))
    else f.rows[i]:SetText(J.Line(l.entry)) end
  end

  -- the copy box, every refresh, so `/memories wow` shows up without reopening the window
  f.pathBox:SetText(J.AlbumPath())
  f.pathBox:SetCursorPosition(0)
  -- SHORT ENOUGH TO FIT ON THE BAR. The first wording ran off the right edge of a 440 wide window
  -- and was cut mid-word; the long explanation belongs in /memories path, which has a whole chat
  -- frame to use.
  f.pathLabel:SetText(T.text("muted", J.AlbumPathWhole()
    and "the album page - click it, then Ctrl+C"
    or "the album page - inside your WoW folder. /memories wow <folder> for the whole path"))

  if n == 0 then
    f.foot:SetText(T.text("muted",
      "nothing yet today. It fires on levels, bosses, rare loot, achievements and dying."))
  elseif #lines > ROWS then
    f.foot:SetText(T.text("muted", ("%d of %d kept - wheel to scroll")
      :format(math.min(n, J.offset + ROWS), n)))
  else
    f.foot:SetText(T.text("muted", "the pictures are in your Screenshots folder"))
  end
  return true, n
end

function J.Show()
  local f = build()
  J.Refresh()
  f:Show()
  return true
end

function J.Hide()
  if J.frame then J.frame:Hide() end
  return true
end

function J.Toggle()
  if J.frame and J.frame:IsShown() then return J.Hide() end
  return J.Show()
end

--- Called when a memory lands, so an open window does not go stale while you play.
function J.Touch()
  if J.frame and J.frame:IsShown() then J.Refresh() end
end
