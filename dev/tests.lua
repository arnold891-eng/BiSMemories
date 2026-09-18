-- BiSMemories headless suite (made by _bisdev/new-addon.sh). Run from the addon root:
--   lua5.1 dev/tests.lua        or, from the AddOns folder: _bisdev/check.sh BiSMemories
local HERE = (arg and arg[0] or ""):match("^(.*)[/\\]") or "."
local H = dofile(HERE .. "/kit.lua")   -- Nebbinator's strict harness (dev/harness.lua), verbatim
local ROOT = os.getenv("BISMEMORIES") or (HERE .. "/..")
local FILES = H.TOC(ROOT, "BiSMemories.toc")

-- every global this addon may create; anything else is a leak and a red test
local ALLOWED = {
    BiSMemoriesDB = true, SLASH_BISMEMORIES1 = true,
    HARNESS = true, print = true, BiSTheme = true, LibBiSComm = true, SLASH_BISCOMM1 = true,
}
local function Load()
    local before = {}
    for k in pairs(_G) do before[k] = true end
    local NS = {}
    for _, rel in ipairs(FILES) do
        local chunk, err = loadfile(ROOT .. "/" .. rel)
        if not chunk then error("load " .. rel .. ": " .. tostring(err), 0) end
        chunk("BiSMemories", NS)
    end
    H.leaked = {}
    for k in pairs(_G) do
        if not before[k] and not ALLOWED[k] then H.leaked[#H.leaked + 1] = tostring(k) end
    end
    table.sort(H.leaked)
    return NS
end
local TOC_VERSION
do
    local fh = assert(io.open(ROOT .. "/BiSMemories.toc", "r"))
    for line in fh:lines() do TOC_VERSION = TOC_VERSION or line:match("^## Version:%s*(%S+)") end
    fh:close()
end
_G.GetAddOnMetadata = function(_, key) return key == "Version" and TOC_VERSION or nil end
local function fire(event, ...)
    for _, fr in ipairs(H.frames) do
        if fr._events[event] and fr._scripts.OnEvent then fr._scripts.OnEvent(fr, event, ...) end
    end
end
local function bytes(p) local fh = io.open(p, "rb") if not fh then return nil end local s = fh:read("*a") fh:close() return s end
local function strip(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local said = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) said[#said + 1] = strip(m) end }

--------------------------------------------------------------------
H.section("load")
local NS = Load()
H.eq(#H.leaked, 0, "no accidental globals", table.concat(H.leaked, ", "))
H.eq(NS.VERSION, TOC_VERSION, "version is the TOC's")
fire("ADDON_LOADED", "BiSMemories")
H.ok(type(_G.BiSMemoriesDB) == "table" and _G.BiSMemoriesDB.comm == true, "SavedVariables shaped with defaults on first load")

H.section("embedded libs are canon (drift fences)")
H.eq(_G.LibBiSComm.MINOR, 6, "LibBiSComm minor 6")
local function listed(rel) for _, f in ipairs(FILES) do if f == rel then return true end end return false end
H.ok(listed("Libs/BiSTheme/Console.lua"), "TOC lists the Console embed")
H.ok(listed("Libs/LibBiSComm-1.0/LibBiSComm-1.0.lua"), "TOC lists the comm embed")
do
    local canon = bytes((os.getenv("BISTHEME") or (ROOT .. "/../BiSTheme")) .. "/Console.lua")
    if canon then H.ok(bytes(ROOT .. "/Libs/BiSTheme/Console.lua") == canon, "Console.lua byte-identical to canon")
    else H.say("  (note) no canon BiSTheme beside the checkout - bytes fence skipped") end
    local lib = bytes((os.getenv("BISDEV") or (ROOT .. "/../_bisdev")) .. "/LibBiSComm-1.0/LibBiSComm-1.0.lua")
    if lib then H.ok(bytes(ROOT .. "/Libs/LibBiSComm-1.0/LibBiSComm-1.0.lua") == lib, "LibBiSComm byte-identical to _bisdev")
    else H.say("  (note) no _bisdev beside the checkout - lib bytes fence skipped") end
end

H.section("the shared BiS channel")
local lib = _G.LibBiSComm
H.ok(lib._booted and lib:Enabled(), "comm booted and on")
H.eq(lib.addons.BiSMemories, TOC_VERSION, "registered with the TOC version")

H.section("the camera")
-- The client's own screenshot call is the one thing this addon cannot fake, so the suite counts it.
local shots, kits, files = 0, 0, 0
_G.Screenshot = function() shots = shots + 1 end
_G.PlaySound = function() kits = kits + 1 return true end
_G.PlaySoundFile = function() files = files + 1 end
_G.UnitLevel = function() return 42 end
_G.GetRealZoneText = function() return "Blackrock Depths" end
_G.GetSubZoneText = function() return "The Grim Guzzler" end
_G.GetNumGroupMembers = function() return 0 end
_G.IsInRaid = function() return false end
_G.UnitExists = function() return false end
local M = NS.M
local clock = 1000
_G.GetTime = function() return clock end
local timers = {}
_G.C_Timer = { After = function(d, fn) timers[#timers + 1] = fn end }
local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end

local e = M.Shoot("levelup", "level 42")
H.ok(e ~= nil, "a trigger makes an entry")
H.eq(e.zone, "Blackrock Depths - The Grim Guzzler", "the note says where")
H.eq(e.level, 42, "and at what level")
H.eq(shots, 0, "the shutter waits for the client to finish drawing the moment")
runTimers()
H.eq(shots, 1, "then it fires once")
H.ok(e.file and e.file:find("^WoWScrnShot_"), "and names the file the client will have written", tostring(e.file))

-- The click we make ourselves, because the client only clicks for the PrintScreen key. Sound KITS
-- only: a game file by path is silent on the modern engine and still reports success.
H.ok(kits > 0, "a shot clicks, so silence never means 'did it work?'")
H.eq(files, 0, "and never through a file path, which lies on the modern engine")
clock = clock + 100
kits = 0
_G.BiSMemoriesDB.sound = false
M.Shoot("manual", "quiet")
runTimers()
H.eq(kits, 0, "the click can be switched off")
_G.BiSMemoriesDB.sound = true

-- A loot burst is one memory, not forty pictures.
local blocked, why = M.Shoot("levelup", "again")
H.ok(blocked == nil and why == "too soon", "a second shot inside the gap is refused", tostring(why))
clock = clock + 100
H.ok(M.Shoot("levelup", "later") ~= nil, "and allowed once the gap has passed")

H.section("what is worth a photograph")
_G.GetItemInfo = function(link)
    local q = tonumber(link:match("QUALITY(%d)")) or 1
    return "Item", link, q
end
H.ok(M.LootWorthy("You receive loot: |Hitem:QUALITY4|h[Thunderfury]|h") ~= nil, "epic loot is")
H.ok(M.LootWorthy("You receive loot: |Hitem:QUALITY2|h[Bent Stick]|h") == nil, "a green is not")
H.ok(M.LootWorthy("Kumlust says hello") == nil, "a line with no item is not")
_G.BiSMemoriesDB.lootQuality = 2
H.ok(M.LootWorthy("You receive loot: |Hitem:QUALITY2|h[Bent Stick]|h") ~= nil, "unless you lower the bar")
_G.BiSMemoriesDB.lootQuality = 4

-- A wipe is not a memory: ENCOUNTER_END fires either way and the fifth argument is the difference.
clock = clock + 100
H.ok(M.OnEvent("ENCOUNTER_END", 1, "Nefarian", 1, 40, 0) == nil, "a wipe takes no picture")
H.ok(M.OnEvent("ENCOUNTER_END", 1, "Nefarian", 1, 40, 1) ~= nil, "a kill does")

-- A switch that is off means no picture, however good the moment.
clock = clock + 100
_G.BiSMemoriesDB.death = false
H.ok(M.OnEvent("PLAYER_DEAD") == nil, "a trigger turned off stays off")
_G.BiSMemoriesDB.death = true

H.section("the log")
clock = clock + 100
_G.BiSMemoriesDB.keep = 3
for i = 1, 5 do
    clock = clock + 100
    M.Shoot("manual", "note " .. i)
end
H.eq(#M.Log(), 3, "the log is capped")
H.eq(M.Log()[1].detail, "note 5", "newest first")
H.ok(rawequal(M.Log(), _G.BiSMemoriesDB.log), "and lives in SavedVariables, so it survives a logout")
_G.BiSMemoriesDB.keep = 250

H.section("/memories")
H.ok(type(_G.SlashCmdList.BISMEMORIES) == "function", "slash registered")
H.eq(_G.SLASH_BISMEMORIES1, "/memories", "as /memories")
said = {}
_G.SlashCmdList.BISMEMORIES("status")
local blob = table.concat(said, " | ")
H.ok(blob:find(TOC_VERSION, 1, true), "status carries the version", blob)
said = {}
_G.SlashCmdList.BISMEMORIES("off boss")
H.eq(_G.BiSMemoriesDB.boss, false, "a trigger can be switched off by name")
_G.SlashCmdList.BISMEMORIES("on boss")
H.eq(_G.BiSMemoriesDB.boss, true, "and back on")
_G.SlashCmdList.BISMEMORIES("clear")
H.eq(#M.Log(), 0, "clear forgets the notes")
said = {}
_G.SlashCmdList.BISMEMORIES("")
H.ok(table.concat(said, " "):find("nothing yet", 1, true), "and says so plainly")

H.section("zones, duels and exalted")
_G.BiSMemoriesDB.zones = nil
H.ok(M.NewZone("Elwynn Forest") == nil, "the first zone it ever sees is remembered, not shot")
H.ok(M.NewZone("Westfall") == "Westfall", "the next new one is a memory")
H.ok(M.NewZone("Westfall") == nil, "and only the first time")

_G.UnitName = function(u) return u == "player" and "Kumlust Surname" or "Someone" end
-- TBC writes "%s has defeated %s"; WoW Forever writes "%1$s has defeated %2$s" (seen in game,
-- 18 Sep 2026) so a translator can swap the names round. A builder that knows only %s turns %1$s
-- into %1, which Lua reads as a capture back-reference: "invalid capture index" on EVERY system
-- message the client prints, including "You feel rested."
_G.DUEL_WINNER_KNOCKOUT = "%s has defeated %s in a duel"
_G.DUEL_WINNER_RETREAT = "%s has fled from %s in a duel"
H.eq(M.DuelWon("Kumlust Surname has defeated Frankadank in a duel"), "Frankadank", "a duel win is read from the client's own sentence")
H.ok(M.DuelWon("Frankadank has defeated Kumlust Surname in a duel") == nil, "losing is not a memory")
H.ok(M.DuelWon("Kumlust Surname says hello") == nil, "and neither is chatter")
H.ok(M.DuelWon("You feel rested.") == nil, "and an ordinary system line does not throw")

_G.DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel"
_G.DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel"
H.eq(M.DuelWon("Kumlust Surname has defeated Frankadank in a duel"), "Frankadank", "the positional form reads the same")
H.ok(M.DuelWon("Frankadank has defeated Kumlust Surname in a duel") == nil, "and losing still is not a memory")
-- the retreat line names the LOSER first: the order table is what keeps the winner straight
H.eq(M.DuelWon("Frankadank has fled from Kumlust Surname in a duel"), "Frankadank", "a fled duel names the winner by argument, not by position")
H.ok(M.DuelWon("You feel rested.") == nil, "and still nothing throws")

_G.FACTION_STANDING_LABEL8 = "Exalted"
H.ok(M.WentExalted("You are now Exalted with Argent Dawn.") ~= nil, "exalted is caught")
H.ok(M.WentExalted("You are now Revered with Argent Dawn.") == nil, "revered is not")

H.section("the candid, one a week")
local d = _G.BiSMemoriesDB
d.candidLast = nil
H.ok(M.CandidDue(1000000) == true, "never taken one: due")
d.candidLast = 1000000
H.ok(M.CandidDue(1000000 + 60) == false, "taken today: not due")
H.ok(M.CandidDue(1000000 + 8 * 24 * 60 * 60) == true, "a week later: due again")
d.candid = false
H.ok(M.CandidDue(1000000 + 8 * 24 * 60 * 60) == false, "switched off: never due")
d.candid = true

-- it must NOT fire on login: that would be the same loading screen fifty-two times a year
d.candidLast = nil
M.candidArmed = false
clock = clock + 100
shots = 0
local wait = M.ArmCandid()
H.ok(wait and wait >= 60, "the candid is booked for later in the session, not now", tostring(wait))
H.eq(shots, 0, "so nothing is taken at the loading screen")
runTimers()
H.ok(shots > 0, "and it lands when its moment comes")
H.ok((d.candidLast or 0) > 0, "the week is marked, so it happens once")

-- Ten expansions apart: an event this client has never heard of must not take the file down.
H.ok(M.OnEvent("SOME_EVENT_FROM_2036") == nil, "an unknown event is ignored, not an error")

H.section("the off switch survives a logout")
lib:SetEnabled(false)
fire("PLAYER_LOGOUT")
H.eq(_G.BiSMemoriesDB.comm, false, "off is saved")
lib:SetEnabled(true)
fire("PLAYER_LOGOUT")
H.eq(_G.BiSMemoriesDB.comm, true, "on is saved")

H.report()
