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
local W, H = 440, 300

local function when(at)
  if not at or at == 0 then return "?" end
  return date and date("%d %b %H:%M", at) or tostring(at)
end

--- One entry as a line of text. Deliberately the same shape as the chat listing in Slash.lua -
--- two formatters that drift are two things to fix when a field is added.
function J.Line(e)
  if type(e) ~= "table" then return "" end
  local who = (type(e.with) == "table" and #e.with > 0) and (", with " .. #e.with) or ""
  return ("%s  %s  %s%s"):format(
    T.text("muted", when(e.at)),
    T.text("accent", e.reason or "?"),
    tostring(e.detail or ""),
    T.text("muted", "  " .. tostring(e.zone or "?") .. who))
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

  f.rows = {}
  for i = 1, ROWS do
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 12, -34 - (i - 1) * 20)
    fs:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    f.rows[i] = fs
  end

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
  local log = M.Log()
  local most = math.max(0, #log - ROWS)
  J.offset = math.max(0, math.min(most, (J.offset or 0) + (by or 0)))
  if J.frame and J.frame:IsShown() then J.Refresh() end
  return J.offset
end

function J.Refresh()
  local f = build()
  local log = M.Log()
  local n = #log
  J.offset = math.max(0, math.min(math.max(0, n - ROWS), J.offset or 0))

  f.count:SetText(T.text("muted", n == 0 and "" or (n .. " kept")))

  for i = 1, ROWS do
    -- NEWEST FIRST: the log is kept newest-first already (Memories.lua inserts at 1), so the
    -- offset counts down the page rather than up from the end
    local e = log[i + J.offset]
    f.rows[i]:SetText(e and J.Line(e) or "")
  end

  if n == 0 then
    f.foot:SetText(T.text("muted",
      "nothing yet today. It fires on levelling, bosses, rare loot, achievements and dying."))
  elseif n > ROWS then
    f.foot:SetText(T.text("muted", ("%d-%d of %d - wheel to scroll")
      :format(J.offset + 1, math.min(n, J.offset + ROWS), n)))
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
