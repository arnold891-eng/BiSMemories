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

-- SOMEBODY ELSE'S PURPLE IS NOT A MEMORY. CHAT_MSG_LOOT carries the whole raid's, and Arn watched
-- it fire on every epic in a 25-man: "otherwise it takes for all purple loot". Mine at the
-- threshold, anyone's legendary - an orange dropping is the room's memory, not just the winner's.
--
-- The client's own strings decide whose it is, so this works in a language nobody here reads.
_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
H.ok(M.LootIsMine("You receive loot: |Hitem:QUALITY4|h[Thunderfury]|h."), "my own loot line is mine")
H.ok(not M.LootIsMine("Kingkroo receives loot: |Hitem:QUALITY4|h[Thunderfury]|h."), "somebody else's is not")
H.ok(M.LootIsMine("You receive item: |Hitem:QUALITY4|h[Thing]|h."), "and a pushed item is mine too")
H.ok(M.LootWorthy("You receive loot: |Hitem:QUALITY4|h[Thunderfury]|h.") ~= nil, "my epic is worth one")
H.ok(M.LootWorthy("Kingkroo receives loot: |Hitem:QUALITY4|h[Thunderfury]|h.") == nil,
     "a raider's epic is not - that was one picture every few seconds")
H.ok(M.LootWorthy("Kingkroo receives loot: |Hitem:QUALITY5|h[Sulfuras]|h.") ~= nil,
     "but a legendary is, whoever won it")

-- a translated client: the word for "you" is not "You", and the pattern still has to hold
_G.LOOT_ITEM_SELF = "Du erhaeltst Beute: %s."
_G.LOOT_ITEM_SELF_MULTIPLE, _G.LOOT_ITEM_PUSHED_SELF = nil, nil
H.ok(M.LootIsMine("Du erhaeltst Beute: |Hitem:QUALITY4|h[Ding]|h."),
     "whose loot it is comes from the client's strings, not from the word 'You'")
_G.LOOT_ITEM_SELF = "You receive loot: %s."
_G.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
_G.LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
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
H.eq(M.DuelWon("Kumlust Surname has defeated Dps1 in a duel"), "Dps1", "a duel win is read from the client's own sentence")
H.ok(M.DuelWon("Dps1 has defeated Kumlust Surname in a duel") == nil, "losing is not a memory")
H.ok(M.DuelWon("Kumlust Surname says hello") == nil, "and neither is chatter")
H.ok(M.DuelWon("You feel rested.") == nil, "and an ordinary system line does not throw")

_G.DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel"
_G.DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel"
H.eq(M.DuelWon("Kumlust Surname has defeated Dps1 in a duel"), "Dps1", "the positional form reads the same")
H.ok(M.DuelWon("Dps1 has defeated Kumlust Surname in a duel") == nil, "and losing still is not a memory")
-- the retreat line names the LOSER first: the order table is what keeps the winner straight
H.eq(M.DuelWon("Dps1 has fled from Kumlust Surname in a duel"), "Dps1", "a fled duel names the winner by argument, not by position")
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

-- WHAT IT HEARD (19 Sep 2026). Arn: "the album in the addon folder is not updating" - and the
-- album was right, there was one memory in six hours. An album with one picture has two
-- explanations, "nothing worth remembering happened" and "the event never arrived", and they look
-- identical from outside. The saved variables held the answer by accident: no `zones` key at all,
-- so ZONE_CHANGED_NEW_AREA had never once fired. This makes that readable in game instead.
do
  M.heard, M.recent = {}, {}
  M.OnEvent("PLAYER_ENTERING_WORLD")
  M.OnEvent("SOME_EVENT_FROM_2036")
  H.eq(M.heard["PLAYER_ENTERING_WORLD"], 1, "an event it hears is counted")
  M.OnEvent("PLAYER_ENTERING_WORLD")
  H.eq(M.heard["PLAYER_ENTERING_WORLD"], 2, "and counted again the second time")
  H.eq(M.recent[1].event, "PLAYER_ENTERING_WORLD", "the newest is first")
  H.ok(M.recent[1].why ~= "TOOK ONE", "and carries the verdict, not just the name")

  -- the useful half: what has NOT arrived
  local quiet = {}
  for _, e in ipairs(M.Unheard()) do quiet[e] = true end
  H.ok(quiet["ZONE_CHANGED_NEW_AREA"], "an event that never arrived is named")
  H.ok(not quiet["PLAYER_ENTERING_WORLD"], "one that did is not")

  -- a real memory says so. The clock has to move: the camera holds an 8 second gap between
  -- shots, and an earlier check in this file has just used one.
  M.heard, M.recent = {}, {}
  clock = clock + 100
  _G.BiSMemoriesDB.levelup = true
  M.OnEvent("PLAYER_LEVEL_UP", 40)
  H.eq(M.recent[1].why, "TOOK ONE", "taking a picture is what the breadcrumb says")

  -- THE SAME THING TWICE RUNNING IS ONE LINE. Fifteen loot lines in a quiet evening printed six
  -- identical rows in game and pushed everything else off the top (Arn's screenshot, 19 Sep).
  M.heard, M.recent = {}, {}
  for _ = 1, 6 do M.OnEvent("CHAT_MSG_LOOT", "you loot something dull") end
  H.eq(#M.recent, 1, "six of the same in a row is one line")
  H.eq(M.recent[1].n, 6, "with the count on it")
  H.eq(M.heard["CHAT_MSG_LOOT"], 6, "and all six still counted")
  M.OnEvent("PLAYER_ENTERING_WORLD")
  M.OnEvent("CHAT_MSG_LOOT", "you loot something dull")
  H.eq(#M.recent, 3, "something else in between starts a new line")

  -- and the list is capped, so a long session cannot grow it without end
  M.recent = {}
  for i = 1, M.RECENT_KEEP + 10 do
    M.OnEvent(i % 2 == 0 and "SOME_EVENT_FROM_2036" or "ANOTHER_FROM_2036")
  end
  H.eq(#M.recent, M.RECENT_KEEP, "the last few, not every event since login")
end

-- THE CLIENT THAT LOSES THE ACCOUNT FILE (Forever beta, measured 19 Sep 2026). It writes
-- BiSMemoriesDB perfectly and hands back nothing at the next login - two zone memories went that
-- way between one save and the next. The per-character file is a different file in a different
-- folder and it survives; BiSHealing proved that the same afternoon. So: write both, and at login
-- take whichever came back.
do
  _G.BiSMemoriesDB = { log = { { at = 1, file = "WoWScrnShot_1", reason = "zone", detail = "Mulgore" } } }
  _G.BiSMemoriesCharDB = nil
  fire("PLAYER_LOGOUT")
  H.ok(type(_G.BiSMemoriesCharDB) == "table" and _G.BiSMemoriesCharDB.log[1].detail == "Mulgore",
       "logging out writes the per-character copy")
  H.ok(not rawequal(_G.BiSMemoriesCharDB, _G.BiSMemoriesDB),
       "and it is a SEPARATE table - an alias would be one file saved and one lost")

  local kept = _G.BiSMemoriesCharDB
  _G.BiSMemoriesDB = nil                      -- the client loses the account-wide one
  _G.BiSMemoriesCharDB = kept
  fire("ADDON_LOADED", "BiSMemories")
  H.ok(NS.rescued == true, "the next login notices")
  H.eq(M.Log()[1].detail, "Mulgore", "and the memory is still there")

  -- a client that keeps both is left alone
  _G.BiSMemoriesDB = { log = { { at = 2, file = "WoWScrnShot_2", reason = "zone", detail = "Barrens" } } }
  _G.BiSMemoriesCharDB = kept
  fire("ADDON_LOADED", "BiSMemories")
  H.ok(NS.rescued == false and M.Log()[1].detail == "Barrens",
       "a client that hands back both changes nothing")
end

-- THE JOURNAL. Arn asked for the album in the addon, reading the Screenshots folder. The reading
-- half is impossible - no addon can list a directory, and a .jpg outside Interface\ cannot be
-- drawn - so this is the words half, and these tests hold it to that: what happened, newest
-- first, and honest when there is nothing.
do
  local J = NS.J
  H.ok(J ~= nil, "there is a journal")

  local log = M.Log()
  for i = #log, 1, -1 do log[i] = nil end

  -- EMPTY IS A STATE, not a bug. On this client the log starts empty at every login, so the
  -- window people see most often is this one, and it has to say why rather than look broken.
  J.Show()
  H.ok(J.frame:IsShown(), "it opens")
  H.ok(strip(J.frame.foot._text):find("nothing yet"), "and an empty log says so in words")
  H.eq(J.frame.rows[1]._text, "", "with no stale row left behind")

  -- twenty memories, newest first
  for i = 1, 20 do
    table.insert(log, 1, { at = 1000 + i, reason = "zone", detail = "place " .. i,
                           zone = "Mulgore", with = {}, file = "WoWScrnShot_" .. i })
  end
  J.Refresh()
  H.ok(strip(J.frame.rows[1]._text):find("place 20"), "the newest is at the top")
  H.ok(strip(J.frame.rows[2]._text):find("place 19"), "and the one before it is under it")
  H.ok(strip(J.frame.foot._text):find("1%-12 of 20"), "the footer counts the page")

  -- the wheel walks it, and stops at the ends rather than running off
  H.eq(J.Scroll(3), 3, "the wheel moves down the list")
  H.ok(strip(J.frame.rows[1]._text):find("place 17"), "and the page follows")
  H.eq(J.Scroll(-99), 0, "it will not go above the newest")
  H.eq(J.Scroll(99), 8, "nor past the oldest - 20 entries, 12 rows")

  -- A MEMORY LANDING WHILE IT IS OPEN pulls it forward. Through M.Shoot, the path the game
  -- actually takes - calling J.Touch() by hand here proved only that Touch works, and passed
  -- happily with the hook in Memories.lua deleted. The wiring is the thing being claimed.
  J.Scroll(-99)
  local d = NS.DB()
  d.levelup, d.gap = true, 0        -- M.Shoot refuses if the trigger is off or the gap is unmet
  H.ok(M.Shoot("levelup", "level 19") ~= nil, "the memory is actually taken")
  H.ok(strip(J.frame.rows[1]._text):find("level 19"),
       "a new memory appears without reopening", strip(J.frame.rows[1]._text))

  J.Hide()
  H.ok(not J.frame:IsShown(), "and it closes")
end

-- THE ALBUM PAGE SHIPS. It is not Lua and the suite cannot run it, but it CAN check the two
-- things that would make it useless without anyone noticing: that the files are still there to
-- be zipped, and that the page still carries the folder picker it is built around. A shipped
-- file that quietly stops shipping looks exactly like a file that was never there.
do
  local page = bytes(HERE .. "/../Album/BiSMemories-Album.html")
  H.ok(page ~= nil, "the album page is in the addon folder, to be shipped")
  H.ok(page and page:find("webkitdirectory", 1, true) ~= nil,
       "and it still has the folder picker it is built around")
  H.ok(page and page:find("entryAround", 1, true) ~= nil,
       "and reads the notes by walking braces, not by splitting on a comma")
  H.ok(page and page:find("function sessions(", 1, true) ~= nil,
       "and groups by raid night, not by calendar day - a night that ends after midnight is one night")
  H.ok(page and page:find("http", 1, true) == nil or not page:find("src=\"http", 1, true),
       "nothing is fetched from the internet: it must work offline")
  H.ok(bytes(HERE .. "/../Album/README.txt") ~= nil, "with the instructions beside it")
end

-- A MEMORY TAKEN WHILE THE CLIENT IS HIDING THINGS. Boss kills and deaths fire IN COMBAT, which
-- is exactly when this client turns answers into secret values - and a secret is not a nil, it is
-- a value that ERRORS the moment anything reads it. Unguarded, the camera would throw at the one
-- moment worth a picture, and anything that got through would be written into saved variables.
--
-- The mock cannot be a real secret (Lua has no hook for truthiness), but it can error on the
-- reads that matter - concat, compare, tostring - which is what the client does and what the
-- unguarded code would have done.
do
  local secretMeta = {
    __concat = function() error("secret value: refused", 0) end,
    __eq = function() error("secret value: refused", 0) end,
    __lt = function() error("secret value: refused", 0) end,
    __tostring = function() error("secret value: refused", 0) end,
  }
  local function secret() return setmetatable({}, secretMeta) end
  local realLevel, realName, realSecret = _G.UnitLevel, _G.UnitName, _G.issecretvalue
  local realNum, realExists = _G.GetNumGroupMembers, _G.UnitExists
  _G.UnitLevel = function() return secret() end
  _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end
  -- A PARTY OF THREE, so the roster half is actually walked: one name the client will say, two it
  -- will not. With no group at all this test looked green while the names guard was deleted.
  _G.GetNumGroupMembers = function() return 3 end
  _G.UnitExists = function() return true end
  _G.UnitName = function(u) return u == "party1" and "Kumlance" or secret() end

  local d = NS.DB()
  d.boss, d.gap = true, 0
  local took, err = pcall(M.Shoot, "boss", "a first kill")
  H.ok(took, "a memory taken while the client is hiding things does not throw", tostring(err))

  local e = M.Log()[1]
  H.ok(e ~= nil and e.level == 0, "a level it cannot read is written down as 0, not as a secret")
  H.ok(e ~= nil and type(e.with) == "table", "and the roster is still a list")
  for _, who in ipairs((e or {}).with or {}) do
    H.ok(type(who) == "string", "every name kept is a real string, never a secret", tostring(who))
  end

  H.ok(#((M.Log()[1] or {}).with or {}) == 1,
       "the one name it would say is kept, the two it hid are dropped",
       #((M.Log()[1] or {}).with or {}))
  _G.UnitLevel, _G.UnitName, _G.issecretvalue = realLevel, realName, realSecret
  _G.GetNumGroupMembers, _G.UnitExists = realNum, realExists
end

H.report()
