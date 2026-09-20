--[[
  BiSMemories :: Core/Memories.lua - the camera, and the note of why it fired.

  A screenshot on its own is a file called WoWScrnShot_091826_204431.jpg. A year later nobody knows
  what it was. So every shot this addon takes is written down beside it: what happened, where, at
  what level, who was in the group -- and the filename stem the client will have used, so a picture
  can be matched to its moment without guessing.

  WHY IT WORKS ON WOW FOREVER. Nothing here reads a number the client hides. Forever makes health,
  auras, cooldowns and stats secret while the secure lockdown is on, and never fires the combat log
  (measured 17 Sep 2026, _bisdev/docs/forever-secret-values.md) -- but zone, level, loot lines,
  roster and `Screenshot()` are all plainly readable, in combat and out. That is why this addon was
  Forever-first: it asks the client only for things the client still tells anyone.

  Every event is registered through pcall. A client that has never heard of ACHIEVEMENT_EARNED must
  not take the file down with it -- the two clients this TOC claims are ten expansions apart.
]]
local ADDON, ns = ...

local M = {}
ns.M = M

-- What is worth a photograph. Each is a switch in the DB, and `/memories off boss` turns one off.
local TRIGGERS = {
  { key = "levelup",     label = "levelling up",          on = true },
  { key = "boss",        label = "a boss dying",          on = true },
  { key = "loot",        label = "rare loot",             on = true },
  { key = "achievement", label = "an achievement",        on = true },
  { key = "death",       label = "your own death",        on = true },
  { key = "duel",        label = "winning a duel",        on = true },
  { key = "zone",        label = "a zone you have never seen", on = true },
  { key = "exalted",     label = "going exalted",         on = true },
  { key = "candid",      label = "one candid a week",     on = true },
}
M.TRIGGERS = TRIGGERS

local DEFAULTS = {
  sound = true,       -- a click, so you know it fired (the client only clicks for PrintScreen)
  gap = 8,            -- seconds between shots, so one loot burst is not forty pictures
  delay = 0.6,        -- let the client finish drawing the moment (the ding, the corpse, the loot)
  keep = 250,         -- entries in the log; the pictures themselves are never touched
  candidEvery = 7 * 24 * 60 * 60,   -- a week, in seconds
  candidWindow = 45 * 60,           -- taken at a random moment inside this much play, not on login
  lootQuality = 4,    -- 4 = epic. 3 = rare, if you want more of them
}
for _, t in ipairs(TRIGGERS) do DEFAULTS[t.key] = t.on end
for k, v in pairs(DEFAULTS) do ns.DEFAULTS[k] = v end

local function db() return ns.DB() end

-- The client plays its camera click for the PrintScreen key, not for Screenshot() -- so a shot
-- taken by an addon is silent, and silence is indistinguishable from "it did not work". We make
-- our own, from SOUND KIT IDS ONLY: on the modern engine (WoW Forever) PlaySoundFile with a game
-- file path plays nothing AND reports success, which cost an evening in BiSGamba on 17 Sep 2026.
-- PlaySound(id) answers true or false there and is the honest way to ask.
local CLICK = { 1115, 8959, 850, 839 }     -- first one this client admits to, then remembered
local clickId

local function click()
  if not db().sound or not PlaySound then return false end
  local channel = "Master"
  if clickId then
    local ok, willPlay = pcall(PlaySound, clickId, channel)
    return ok and willPlay ~= false
  end
  for _, id in ipairs(CLICK) do
    local ok, willPlay = pcall(PlaySound, id, channel)
    if ok and willPlay ~= false then
      clickId = id
      return true
    end
  end
  clickId = false
  return false
end

--- The name the client will give the file it is about to write: WoWScrnShot_MMDDYY_HHMMSS.
--- Worked out at the moment of capture, not when the trigger fired, or it names the wrong second.
local function shotStem()
  local stamp = date and date("%m%d%y_%H%M%S") or tostring(time and time() or 0)
  return "WoWScrnShot_" .. stamp
end

local function where()
  local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "?"
  local sub = (GetSubZoneText and GetSubZoneText()) or ""
  if sub ~= "" and sub ~= zone then return zone .. " - " .. sub end
  return zone
end

--- A value you may actually USE, or nil when the client is hiding it.
---
--- SOME ANSWERS ON THIS CLIENT ARE SECRET: they can be handed to a FontString and the client will
--- paint them, but READING one - arithmetic, comparison, `..`, tostring, even asking whether it is
--- truthy - is refused, and the refusal is an error, not a nil. `ShouldUnitIdentityBeSecret` and
--- `ShouldUnitStatsBeSecret` are both in this client's API list, so a NAME and a LEVEL are both
--- things it can decide to hide.
---
--- It matters more here than anywhere else in this addon, because memories are taken WHILE
--- FIGHTING - a boss dying, dying yourself - which is exactly when the client hides the most. An
--- unguarded read throws inside the camera at the one moment worth a picture, and a secret that
--- got through would be written into the log and on into saved variables.
---
--- NOT YET MEASURED on this client: whether names and levels actually do go secret. The guard
--- costs nothing when they do not, and ForeverAuras 0.1.114 checks unit names exactly this way.
local function plain(v)
  if v == nil then return nil end
  if issecretvalue then
    local asked, yes = pcall(issecretvalue, v)
    if asked and yes then return nil end
  end
  return v
end

--- Everyone who was there. A memory of a first kill is worth more with the names on it - and the
--- roster is NOT simply plain on this client, whatever the old comment here claimed.
local function party()
  local names = {}
  local n = plain(GetNumGroupMembers and GetNumGroupMembers()) or 0
  local raid = IsInRaid and IsInRaid()
  for i = 1, n do
    local unit = (raid and "raid" or "party") .. i
    if UnitExists and UnitExists(unit) and UnitName then
      local who = plain(UnitName(unit))
      if who then names[#names + 1] = who end
    end
  end
  return names
end

M.log = nil            -- set from the DB on login; kept here so tests can read it directly

local lastShot = 0

--- Take one, and write down why. Returns the entry, or nil and the reason it did not.
function M.Shoot(reason, detail)
  local d = db()
  if d[reason] == false then return nil, "off" end
  local now = (GetTime and GetTime()) or 0
  if lastShot > 0 and (now - lastShot) < (d.gap or 8) then return nil, "too soon" end
  lastShot = now

  local entry = {
    reason = reason,
    detail = detail,
    zone = where(),
    level = plain(UnitLevel and UnitLevel("player")) or 0,
    at = (time and time()) or 0,
    with = party(),
  }

  local function capture()
    entry.file = shotStem()
    if Screenshot then pcall(Screenshot) end
    click()
  end
  if C_Timer and C_Timer.After and (d.delay or 0) > 0 then
    C_Timer.After(d.delay, capture)
  else
    capture()
  end

  local log = M.Log()
  table.insert(log, 1, entry)
  for i = #log, (d.keep or 250) + 1, -1 do log[i] = nil end
  -- an open journal follows along rather than going stale behind you
  if ns.J and ns.J.Touch then ns.J.Touch() end
  return entry
end

--- The log, created on first use. Kept in the DB so it survives a logout: the point of the addon
--- is the note beside the picture, and a note that dies with the session is no note at all.
function M.Log()
  local d = db()
  d.log = type(d.log) == "table" and d.log or {}
  M.log = d.log
  return d.log
end

---------------------------------------------------------------------- triggers --

--- Is this loot line worth a picture? The item's own quality decides, so the threshold is one
--- setting rather than a list of item names nobody will maintain.
function M.LootWorthy(msg)
  if type(msg) ~= "string" then return nil end
  local link = msg:match("|c%x+|Hitem:.-|h%[.-%]|h|r") or msg:match("|Hitem:.-|h%[.-%]|h")
  if not link then return nil end
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not getInfo then return nil end
  local ok, _, _, quality = pcall(getInfo, link)
  if not ok or type(quality) ~= "number" then return nil end
  if quality < (db().lootQuality or 4) then return nil end
  return link, quality
end

---------------------------------------------------------------- the candid --
--
-- One unposed picture a week. Everything else in this addon fires on a moment you already know is
-- worth keeping -- the ding, the kill, the drop. This one fires when nothing in particular is
-- happening, which is the half of a year in a game that nobody ever photographs: standing in a
-- bank, halfway across a zone, waiting on a summon.
--
-- Deliberately NOT on login: that would be the same loading screen fifty-two times. It picks a
-- random moment inside the next stretch of play instead.

--- Is a week up? Split out so the suite can drive a year in a millisecond.
function M.CandidDue(now)
  local d = db()
  if not d.candid then return false end
  now = now or (time and time()) or 0
  local last = tonumber(d.candidLast) or 0
  if last == 0 then return true end
  return (now - last) >= (d.candidEvery or (7 * 24 * 60 * 60))
end

--- Book this session's candid, if one is owed. Returns the delay it chose, or nil.
function M.ArmCandid()
  local d = db()
  if M.candidArmed or not M.CandidDue() then return nil end
  local window = d.candidWindow or (45 * 60)
  local wait = math.random(60, math.max(120, window))
  M.candidArmed = true
  local function fire()
    local e = M.Shoot("candid", "just a week going by")
    if e then
      d.candidLast = (time and time()) or 0
      M.candidArmed = false
    elseif C_Timer and C_Timer.After then
      C_Timer.After(30, fire)          -- refused by the gap: the moment can wait half a minute
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(wait, fire)
  else
    fire()
  end
  return wait
end

--------------------------------------------------------------------- the rest --

--- A zone this character has never been photographed in. The very first zone the addon ever sees
--- is only remembered, not shot: otherwise installing it somewhere you have lived for a year
--- produces a picture of your own bank.
function M.NewZone(name)
  if not name or name == "" then return nil end
  local d = db()
  d.zones = type(d.zones) == "table" and d.zones or {}
  if d.zones[name] then return nil end
  local first = next(d.zones) == nil
  d.zones[name] = true
  if first then return nil end
  return name
end

--- The client's own sentence, turned into a Lua pattern.
---
--- Two shapes exist and BOTH are real: "%s has defeated %s in a duel" on TBC, and
--- "%1$s has defeated %2$s in a duel" on WoW Forever (seen in game 18 Sep 2026). The positional
--- form is not decoration -- it lets a translator swap the order of the names -- and a builder
--- that only knows %s turns %1$s into %1, which Lua reads as a capture back-reference and throws
--- "invalid capture index" on every system message the client prints.
---
--- Returns the pattern and, for each capture in reading order, which ARGUMENT it is: so
--- "%2$s has fled from %1$s" still tells us the winner is the second name in the sentence.
local patternCache = {}
function M.Pattern(fmt)
  if type(fmt) ~= "string" then return nil end
  if patternCache[fmt] then return patternCache[fmt][1], patternCache[fmt][2] end
  local order, n = {}, 0
  local body = fmt:gsub("%%(%d)%$s", function(idx)
    n = n + 1
    order[n] = tonumber(idx)
    return "\1"
  end)
  if n == 0 then
    body = body:gsub("%%s", function()
      n = n + 1
      order[n] = n
      return "\1"
    end)
  end
  body = body:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")   -- escape the magic, % included
  body = body:gsub("\1", "(.+)")
  local pat = "^" .. body .. "$"
  patternCache[fmt] = { pat, order }
  return pat, order
end

--- Did the player just win a duel? The client's own sentence decides, so it stays right in any
--- language and in either placeholder style.
function M.DuelWon(msg)
  if type(msg) ~= "string" then return nil end
  local me = UnitName and UnitName("player")
  if not me then return nil end
  for _, fmt in ipairs({ _G.DUEL_WINNER_KNOCKOUT, _G.DUEL_WINNER_RETREAT }) do
    local pat, order = M.Pattern(fmt)
    if pat then
      local caps = { msg:match(pat) }
      if #caps > 0 then
        local args = {}
        for i, cap in ipairs(caps) do args[order[i] or i] = cap end
        if args[1] == me then return args[2] or "a duel" end
      end
    end
  end
  return nil
end

--- Exalted. The standing's own name comes from the client (FACTION_STANDING_LABEL8), so this does
--- not hard-code the English word.
function M.WentExalted(msg)
  if type(msg) ~= "string" then return nil end
  local exalted = _G.FACTION_STANDING_LABEL8
  if type(exalted) ~= "string" or not msg:find(exalted, 1, true) then return nil end
  return msg
end

local EVENTS = {
  "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED",     -- the old name and the modern one
  "BOSS_KILL", "ENCOUNTER_END",
  "CHAT_MSG_LOOT", "ACHIEVEMENT_EARNED", "PLAYER_DEAD",
  "ZONE_CHANGED_NEW_AREA", "CHAT_MSG_SYSTEM", "CHAT_MSG_COMBAT_FACTION_CHANGE",
  "PLAYER_ENTERING_WORLD",
  "SCREENSHOT_SUCCEEDED", "SCREENSHOT_FAILED",
}
M.EVENTS = EVENTS

------------------------------------------------------------------- breadcrumbs --

-- WHAT IT HEARD, AND WHAT IT DECIDED. 19 Sep 2026: an album with one picture in it, and no way to
-- tell the two explanations apart - "nothing worth remembering happened" and "the event never
-- arrived". The saved variables held the answer by accident (no `zones` key at all, so
-- ZONE_CHANGED_NEW_AREA had never once fired), but reading that needs a file and a person who
-- knows what is missing.
--
-- So the camera keeps a note of every event it hears and the verdict it returned. Session only,
-- deliberately: this answers "is it working NOW", and a persisted list would just be one more
-- thing to migrate. Same trick as BiSProbe's phase breadcrumbs, which found the forbidden action
-- in one reload.
M.heard = {}          -- event name -> how many times this session
M.recent = {}         -- newest first: { event, why, at }
M.RECENT_KEEP = 20

local function breadcrumb(event, entry, why)
  M.heard[event] = (M.heard[event] or 0) + 1
  local verdict = entry and "TOOK ONE" or (why or "ignored")
  -- The same thing twice running is one line with a count. Fifteen loot lines in a quiet evening
  -- printed six identical rows and pushed everything else off the top, which is how a diagnostic
  -- stops being read.
  local top = M.recent[1]
  if top and top.event == event and top.why == verdict then
    top.n = (top.n or 1) + 1
    top.at = (time and time()) or top.at
    return
  end
  table.insert(M.recent, 1, {
    event = event,
    why = verdict,
    n = 1,
    at = (time and time()) or 0,
  })
  for i = #M.recent, M.RECENT_KEEP + 1, -1 do M.recent[i] = nil end
end

--- Every event the camera registered for that has NOT arrived once this session. The useful half:
--- a name on this list is either an event this client does not send, or a thing that simply has
--- not happened yet - and knowing which is which is a question for the person, not the addon.
function M.Unheard()
  local out = {}
  for _, e in ipairs(EVENTS) do
    if not M.heard[e] then out[#out + 1] = e end
  end
  return out
end

--- One event, turned into a memory or ignored. Split out from the frame so the suite can drive it
--- with no client at all.
function M.OnEvent(event, ...)
  local entry, why = M.Decide(event, ...)
  breadcrumb(event, entry, why)
  return entry, why
end

--- The decision itself, with no note-keeping in it.
function M.Decide(event, ...)
  if event == "PLAYER_LEVEL_UP" or event == "PLAYER_LEVEL_CHANGED" then
    local lvl = select(1, ...)
    return M.Shoot("levelup", "level " .. tostring(lvl or (UnitLevel and UnitLevel("player")) or "?"))

  elseif event == "BOSS_KILL" then
    local _, name = ...
    return M.Shoot("boss", tostring(name or "a boss"))

  elseif event == "ENCOUNTER_END" then
    local _, name, _, _, success = ...
    if success ~= 1 and success ~= true then return nil, "wipe" end   -- a wipe is not a memory
    return M.Shoot("boss", tostring(name or "an encounter"))

  elseif event == "CHAT_MSG_LOOT" then
    local msg = select(1, ...)
    local link = M.LootWorthy(msg)
    if not link then return nil, "not worthy" end
    return M.Shoot("loot", link)

  elseif event == "ACHIEVEMENT_EARNED" then
    local id = select(1, ...)
    local name
    if GetAchievementInfo then
      local ok, _, title = pcall(GetAchievementInfo, id)
      if ok then name = title end
    end
    return M.Shoot("achievement", tostring(name or id or "?"))

  elseif event == "PLAYER_DEAD" then
    return M.Shoot("death", where())

  elseif event == "ZONE_CHANGED_NEW_AREA" then
    local zone = M.NewZone((GetRealZoneText and GetRealZoneText()) or nil)
    if not zone then return nil, "been here" end
    return M.Shoot("zone", zone)

  elseif event == "CHAT_MSG_SYSTEM" then
    local loser = M.DuelWon(select(1, ...))
    if not loser then return nil, "not a duel win" end
    return M.Shoot("duel", "beat " .. tostring(loser))

  elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
    local line = M.WentExalted(select(1, ...))
    if not line then return nil, "not exalted" end
    return M.Shoot("exalted", line)

  elseif event == "PLAYER_ENTERING_WORLD" then
    M.ArmCandid()                     -- a week up? book a moment somewhere in this session
    return nil, "candid considered"

  elseif event == "SCREENSHOT_SUCCEEDED" or event == "SCREENSHOT_FAILED" then
    local entry = M.Log()[1]
    if entry then entry.shot = (event == "SCREENSHOT_SUCCEEDED") end
    return nil, "noted"
  end
  return nil, "ignored"
end

function M.Start()
  if M.frame then return M.frame end
  local f = CreateFrame("Frame")
  for _, e in ipairs(EVENTS) do
    pcall(f.RegisterEvent, f, e)     -- ten expansions apart: an unknown event must not abort
  end
  f:SetScript("OnEvent", function(_, event, ...) M.OnEvent(event, ...) end)
  M.frame = f
  M.Log()
  return f
end
