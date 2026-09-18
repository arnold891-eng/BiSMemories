--[[
  BiSMemories :: Core/Slash.lua - /memories.

      /memories                 the last ten, newest first
      /memories all             everything kept
      /memories now [note]      take one right now, with an optional note
      /memories on|off <thing>  levelup, boss, loot, achievement, death, duel
      /memories loot <2-5>      the quality worth a picture: 4 is epic, 3 is rare
      /memories gap <seconds>   the least time between two shots
      /memories sound           the click on or off
      /memories clear           forget the notes (never touches the pictures)
      /memories status          what is on, and where the pictures live

  Reading it back matters as much as taking it: the note names the file the client wrote, so a
  picture in Screenshots\ can be matched to the night it came from.
]]
local ADDON, ns = ...
local T, M = ns.T, ns.M

local function db() return ns.DB() end

local function when(at)
  if not at or at == 0 then return "?" end
  return date and date("%d %b %H:%M", at) or tostring(at)
end

local function line(e)
  local who = (e.with and #e.with > 0) and (", with " .. #e.with) or ""
  return ("%s  %s  %s%s%s"):format(
    T.text("muted", when(e.at)),
    T.text("accent", e.reason or "?"),
    tostring(e.detail or ""),
    T.text("muted", "  " .. tostring(e.zone or "?") .. who),
    e.file and T.text("muted", "  " .. e.file) or "")
end

local function list(n)
  local log = M.Log()
  if #log == 0 then
    ns.Print("nothing yet. It fires on: %s", T.text("muted", "levelling, bosses, rare loot, achievements, dying"))
    return
  end
  ns.Print("%d memory(s):", #log)
  for i = 1, math.min(n or 10, #log) do
    DEFAULT_CHAT_FRAME:AddMessage("   " .. line(log[i]))
  end
  if n and #log > n then ns.Print("...and %d more - %s", #log - n, T.text("muted", "/memories all")) end
end

local function status()
  local d = db()
  local on = {}
  for _, t in ipairs(M.TRIGGERS) do
    on[#on + 1] = (d[t.key] and T.text("good", t.key) or T.text("muted", t.key))
  end
  ns.Print("version %s - %s", ns.VERSION, table.concat(on, " "))
  ns.Print("loot from quality %d, at most one shot every %ds, %d note(s) kept",
    d.lootQuality or 4, d.gap or 8, #M.Log())
  local last = tonumber(d.candidLast) or 0
  if d.candid then
    ns.Print("candid: %s", last == 0 and T.text("muted", "none yet - one is due this week")
      or T.text("muted", "last one " .. when(last)))
  end
  ns.Print("the pictures are in %s", T.text("muted", "World of Warcraft\\<client>\\Screenshots"))
end

local function set(key, on)
  local d = db()
  for _, t in ipairs(M.TRIGGERS) do
    if t.key == key then
      d[key] = on and true or false
      ns.Print("%s: %s", t.label, on and T.text("good", "on") or T.text("warn", "off"))
      return true
    end
  end
  ns.Print("no such thing as %s - try: levelup, boss, loot, achievement, death, duel", tostring(key))
  return false
end

function ns.Slash(input)
  local cmd, rest = tostring(input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")

  if cmd == "" then
    list(10)

  elseif cmd == "all" then
    list(nil)

  elseif cmd == "now" then
    local e, why = M.Shoot("manual", rest ~= "" and rest or "asked for it")
    if e then ns.Print("saying cheese - %s", T.text("muted", e.zone))
    else ns.Print("not this time (%s)", tostring(why)) end

  elseif cmd == "on" or cmd == "off" then
    set(rest, cmd == "on")

  elseif cmd == "loot" then
    local q = tonumber(rest)
    if q and q >= 0 and q <= 5 then
      db().lootQuality = q
      ns.Print("loot worth a picture: quality %d and up", q)
    else
      ns.Print("a number 0-5, where 4 is epic and 3 is rare")
    end

  elseif cmd == "gap" then
    local s = tonumber(rest)
    if s and s >= 0 then
      db().gap = s
      ns.Print("at most one shot every %ds", s)
    else
      ns.Print("seconds, please - %s", T.text("muted", "/memories gap 8"))
    end

  elseif cmd == "sound" then
    local d = db()
    d.sound = not d.sound
    ns.Print("the click is %s", d.sound and T.text("good", "on") or T.text("warn", "off"))

  elseif cmd == "clear" then
    local n = #M.Log()
    db().log = {}
    M.Log()
    ns.Print("forgot %d note(s). The pictures are still where they were.", n)

  elseif cmd == "status" then
    status()

  else
    ns.Print("%s", T.text("muted",
      "/memories · all · now [note] · on|off <thing> · loot <2-5> · gap <secs> · sound · clear · status"))
  end
end
