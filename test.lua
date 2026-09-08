local ADDON = "EncounterSettings"
local dir = arg[0]:match("^(.*)/[^/]*$") or "."

local rawformat = string.format
string.format = function(fmt, ...)
    for i = 1, select("#", ...) do
        assert(select(i, ...) ~= nil, "nil argument " .. i .. " for format " .. fmt)
    end
    return rawformat(fmt, ...)
end

local function joined(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    return table.concat(parts, " ")
end

local function tocFiles()
    local files = {}
    for line in io.lines(dir .. "/" .. ADDON .. ".toc") do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:find("^#") then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    return files
end

local function newClient()
    local client = {
        cvars = {
            graphicsParticleDensity = "4",
            raidGraphicsParticleDensity = "3",
            RAIDsettingsEnabled = "1",
            graphicsQuality = "7",
            RAIDgraphicsQuality = "4",
            particleDensity = "60",
            RAIDparticleDensity = "40",
            ffxDeath = "1",
        },
        instanceType = "raid",
        encounterInProgress = false,
        normalizeNumbers = false,
        rejectWrites = {},
        flags = {},
        writes = 0,
        failOnWrite = nil,
        frames = {},
        output = {},
    }

    function client:install()
        local function key(name)
            for k in pairs(self.cvars) do
                if k:lower() == name:lower() then
                    return k
                end
            end
        end
        _G.GetCVar = function(name)
            local k = key(name)
            return k and self.cvars[k]
        end
        _G.SetCVar = function(name, value)
            local k = key(name)
            if not k or self.rejectWrites[k] then
                return false
            end
            self.writes = self.writes + 1
            if self.writes == self.failOnWrite then
                error("SetCVar refused " .. k)
            end
            if self.normalizeNumbers and tonumber(value) then
                value = tostring(tonumber(value))
            end
            self.cvars[k] = value
            return true
        end
        _G.C_CVar = {
            GetCVarInfo = function(name)
                local k = key(name)
                if not k then
                    return nil
                end
                local flags = self.flags[k] or {}
                return self.cvars[k], self.cvars[k], false, false, false, flags.secure or false, flags.readOnly or false
            end,
        }
        _G.GetCVarBool = function(name)
            return GetCVar(name) == "1"
        end
        _G.IsInInstance = function()
            return self.instanceType ~= "none", self.instanceType
        end
        _G.C_InstanceEncounter = {
            IsEncounterInProgress = function()
                return self.encounterInProgress
            end,
        }
        _G.SlashCmdList = {}
        _G.print = function(...)
            table.insert(self.output, joined(...))
        end
        _G.CreateFrame = function()
            local frame = { events = {} }
            function frame:RegisterEvent(event)
                self.events[event] = true
            end
            function frame:SetScript(_, handler)
                self.handler = handler
            end
            table.insert(client.frames, frame)
            return frame
        end
    end

    function client:fire(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] and frame.handler then
                frame.handler(frame, event, ...)
            end
        end
    end

    function client:login()
        self.frames = {}
        self:install()
        local ns = {}
        for _, file in ipairs(tocFiles()) do
            assert(loadfile(dir .. "/" .. file))(ADDON, ns)
        end
        self:fire("ADDON_LOADED", ADDON)
        self:fire("PLAYER_ENTERING_WORLD", true, false)
    end

    function client:pullStart(id, name)
        self:fire("ENCOUNTER_START", id, name or "Boss", 16, 20)
    end
    function client:pullEnd(id)
        self:fire("ENCOUNTER_END", id, "Boss", 16, 20, 0)
    end
    function client:slash(msg)
        SlashCmdList.ENCOUNTERSETTINGS(msg)
    end
    function client:lastOutput()
        return self.output[#self.output]
    end
    function client:count(text)
        local n = 0
        for _, line in ipairs(self.output) do
            if line:find(text, 1, true) then
                n = n + 1
            end
        end
        return n
    end

    return client
end

local function configuredClient()
    local c = newClient()
    c:login()
    c:slash("set 3132 graphicsParticleDensity 0")
    c:slash("set 3132 ffxDeath 0")
    return c
end

local tests = {}
local function test(name, fn)
    table.insert(tests, { name = name, fn = fn })
end
local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what, tostring(expected), tostring(actual)), 2)
    end
end

test("sets every cvar configured for a listed encounter and restores them afterwards", function()
    local c = configuredClient()
    c:pullStart(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "0", "particle density during the pull")
    eq(c.cvars.ffxDeath, "0", "ffxDeath during the pull")
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "particle density after the pull")
    eq(c.cvars.ffxDeath, "1", "ffxDeath after the pull")
end)

test("applies only the settings configured for that encounter", function()
    local c = configuredClient()
    c:slash("set 3133 ffxDeath 0")
    c:pullStart(3133)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "particle density during the other pull")
    eq(c.cvars.ffxDeath, "0", "ffxDeath during the other pull")
    c:pullEnd(3133)
    eq(c.cvars.ffxDeath, "1", "ffxDeath after the other pull")
end)

test("leaves unlisted encounters alone", function()
    local c = configuredClient()
    c:pullStart(1)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "during the pull")
    eq(c.cvars.ffxDeath, "1", "ffxDeath during the pull")
    c:pullEnd(1)
end)

test("does nothing outside instances", function()
    local c = configuredClient()
    c.instanceType = "none"
    c:pullStart(3132)
    eq(c.cvars.graphicsParticleDensity, "4", "base cvar during a world encounter")
    eq(c.cvars.raidGraphicsParticleDensity, "3", "raid cvar during a world encounter")
    eq(c.cvars.ffxDeath, "1", "ffxDeath during a world encounter")
    c:pullEnd(3132)
    eq(c.cvars.ffxDeath, "1", "ffxDeath after a world encounter")
end)

test("uses the base graphics cvar when raid settings are off", function()
    local c = configuredClient()
    c.cvars.RAIDsettingsEnabled = "0"
    c:pullStart(3132)
    eq(c.cvars.graphicsParticleDensity, "0", "base cvar during the pull")
    eq(c.cvars.raidGraphicsParticleDensity, "3", "raid cvar during the pull")
    c:pullEnd(3132)
    eq(c.cvars.graphicsParticleDensity, "4", "base cvar after the pull")
end)

test("uses the base graphics cvar in a dungeon even with raid settings on", function()
    local c = configuredClient()
    c.instanceType = "party"
    c:pullStart(3132)
    eq(c.cvars.graphicsParticleDensity, "0", "base cvar during the pull")
    eq(c.cvars.raidGraphicsParticleDensity, "3", "raid cvar during the pull")
    c:pullEnd(3132)
    eq(c.cvars.graphicsParticleDensity, "4", "base cvar after the pull")
end)

test("restores on the next login when the session ended mid-pull", function()
    local c = configuredClient()
    c:pullStart(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "0", "during the pull")
    c:login()
    eq(c.cvars.raidGraphicsParticleDensity, "3", "particle density after logging back in")
    eq(c.cvars.ffxDeath, "1", "ffxDeath after logging back in")
    c:pullStart(3132)
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "after the next pull")
end)

test("keeps the override across a reload during the pull", function()
    local c = configuredClient()
    c:pullStart(3132)
    c.encounterInProgress = true
    c:login()
    eq(c.cvars.raidGraphicsParticleDensity, "0", "after reloading mid-pull")
    c.encounterInProgress = false
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "after the pull")
end)

test("keeps the saved values when ENCOUNTER_START fires twice", function()
    local c = configuredClient()
    c:pullStart(3132)
    c:pullStart(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "0", "during the pull")
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "particle density after the pull")
    eq(c.cvars.ffxDeath, "1", "ffxDeath after the pull")
end)

test("keeps a value the user set during the pull and restores the rest", function()
    local c = configuredClient()
    c:pullStart(3132)
    c.cvars.raidGraphicsParticleDensity = "5"
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "5", "user's value after the pull")
    eq(c.cvars.ffxDeath, "1", "ffxDeath after the pull")
    c:pullStart(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "0", "during the next pull")
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "5", "after the next pull")
end)

test("restores the cvar it changed even if raid settings were toggled mid-pull", function()
    local c = configuredClient()
    c:pullStart(3132)
    c.cvars.RAIDsettingsEnabled = "0"
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "raid cvar after the pull")
    eq(c.cvars.graphicsParticleDensity, "4", "base cvar after the pull")
end)

test("still restores when the client normalizes the value it wrote", function()
    local c = newClient()
    c.normalizeNumbers = true
    c:login()
    c:slash("set 3132 graphicsParticleDensity 0.0")
    c:pullStart(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "0", "during the pull")
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "after the pull")
end)

test("skips a configured cvar the client no longer knows and applies the rest", function()
    local c = configuredClient()
    EncounterSettingsDB.encounters[3132].settings.removedInSomePatch = "1"
    c:pullStart(3132)
    eq(c.cvars.removedInSomePatch, nil, "unknown cvar during the pull")
    eq(c.cvars.ffxDeath, "0", "ffxDeath during the pull")
    c:pullEnd(3132)
    eq(c.cvars.ffxDeath, "1", "ffxDeath after the pull")
end)

test("uses the last seen encounter when no id is given", function()
    local c = newClient()
    c:login()
    c:pullStart(3132, "Araz")
    c:pullEnd(3132)
    c:slash("set ffxDeath 0")
    assert(c:lastOutput():find("Araz", 1, true), "reply names the encounter")
    c:pullStart(3132)
    eq(c.cvars.ffxDeath, "0", "during the next pull")
    c:pullEnd(3132)
end)

test("refuses a setting without an id before any encounter was seen", function()
    local c = newClient()
    c:login()
    c:slash("set ffxDeath 0")
    eq(next(EncounterSettingsDB.encounters), nil, "encounters after the refused command")
end)

test("unset removes one setting, and drops the encounter once none are left", function()
    local c = configuredClient()
    c:slash("unset 3132 ffxDeath")
    c:pullStart(3132)
    eq(c.cvars.ffxDeath, "1", "ffxDeath during the pull")
    eq(c.cvars.raidGraphicsParticleDensity, "0", "particle density during the pull")
    c:pullEnd(3132)
    c:slash("unset 3132 graphicsParticleDensity")
    eq(EncounterSettingsDB.encounters[3132], nil, "encounter entry after removing its last setting")
end)

test("rejects an unknown cvar", function()
    local c = newClient()
    c:login()
    c:slash("set 3132 notACVar 1")
    eq(EncounterSettingsDB.encounters[3132], nil, "encounter entry after the rejected command")
end)

test("rejects raidGraphics names in favour of the base name", function()
    local c = newClient()
    c:login()
    c:slash("set 3132 raidGraphicsParticleDensity 0")
    eq(EncounterSettingsDB.encounters[3132], nil, "encounter entry after the rejected command")
    assert(c:lastOutput():find("graphicsParticleDensity", 1, true), "reply names the base cvar")
end)

test("remembers settings across logins", function()
    local c = configuredClient()
    c:login()
    c:pullStart(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "0", "particle density after relogging")
    eq(c.cvars.ffxDeath, "0", "ffxDeath after relogging")
    c:pullEnd(3132)
end)

test("status lists each encounter with its settings", function()
    local c = configuredClient()
    c:slash("")
    local listed = false
    for _, line in ipairs(c.output) do
        if
            line:find("3132", 1, true)
            and line:find("ffxDeath = 0", 1, true)
            and line:find("graphicsParticleDensity = 0", 1, true)
        then
            listed = true
        end
    end
    assert(listed, "status output lists encounter 3132 with both settings")
end)

test("clear removes every setting for an encounter", function()
    local c = configuredClient()
    c:slash("set 3133 ffxDeath 0")
    c:slash("clear 3132")
    eq(EncounterSettingsDB.encounters[3132], nil, "cleared encounter entry")
    c:pullStart(3133)
    eq(c.cvars.ffxDeath, "0", "other encounter still applies")
    c:pullEnd(3133)
end)

test("unset and clear use the last seen encounter when no id is given", function()
    local c = configuredClient()
    c:pullStart(3132, "Araz")
    c:pullEnd(3132)
    c:slash("unset ffxDeath")
    eq(EncounterSettingsDB.encounters[3132].settings.ffxDeath, nil, "ffxDeath after unset")
    c:slash("clear")
    eq(EncounterSettingsDB.encounters[3132], nil, "encounter entry after clear")
end)

test("matches cvar names regardless of case", function()
    local c = newClient()
    c:login()
    c:slash("set 3132 graphicsparticledensity 0")
    c:slash("set 3132 GraphicsParticleDensity 0")
    local count = 0
    for _ in pairs(EncounterSettingsDB.encounters[3132].settings) do
        count = count + 1
    end
    eq(count, 1, "settings stored for the two spellings")
    c:pullStart(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "0", "raid twin during the pull")
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "raid twin after the pull")
    c:slash("unset 3132 GRAPHICSPARTICLEDENSITY")
    eq(EncounterSettingsDB.encounters[3132], nil, "encounter entry after unset in another case")
end)

test("refuses secure and read-only cvars", function()
    local c = newClient()
    c.cvars.secureThing = "1"
    c.flags.secureThing = { secure = true }
    c.cvars.lockedThing = "1"
    c.flags.lockedThing = { readOnly = true }
    c:login()
    c:slash("set 3132 secureThing 0")
    c:slash("set 3132 lockedThing 0")
    eq(EncounterSettingsDB.encounters[3132], nil, "encounter entry after refused commands")
end)

test("reports a write the client rejects instead of tracking it", function()
    local c = configuredClient()
    c.rejectWrites.ffxDeath = true
    c:pullStart(3132)
    eq(c.cvars.ffxDeath, "1", "rejected cvar during the pull")
    eq(c.cvars.raidGraphicsParticleDensity, "0", "other cvar during the pull")
    assert(EncounterSettingsDB.active.ffxDeath == nil, "rejected cvar is not tracked")
    eq(c:count("the client refused to set ffxDeath to 0"), 1, "refusal lines")
    eq(c:count("set raidGraphicsParticleDensity to 0 (was 3)"), 1, "single success reported in full")
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "other cvar after the pull")
end)

test("restores cvars applied before a later write throws", function()
    local c = configuredClient()
    c.failOnWrite = 2
    c:pullStart(3132)
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "particle density after the pull")
    eq(c.cvars.ffxDeath, "1", "ffxDeath after the pull")
end)

test("uses the RAID twin of a non-graphics cvar when raid settings apply", function()
    local c = newClient()
    c:login()
    c:slash("set 3132 particleDensity 10")
    c:pullStart(3132)
    eq(c.cvars.RAIDparticleDensity, "10", "RAID twin during the pull")
    eq(c.cvars.particleDensity, "60", "base cvar during the pull")
    c:pullEnd(3132)
    eq(c.cvars.RAIDparticleDensity, "40", "RAID twin after the pull")
    c.instanceType = "party"
    c:pullStart(3132)
    eq(c.cvars.particleDensity, "10", "base cvar during a dungeon pull")
    c:pullEnd(3132)
    eq(c.cvars.particleDensity, "60", "base cvar after a dungeon pull")
end)

test("rejects RAID names in favour of the base name", function()
    local c = newClient()
    c:login()
    c:slash("set 3132 RAIDparticleDensity 10")
    eq(EncounterSettingsDB.encounters[3132], nil, "encounter entry after the rejected command")
    assert(c:lastOutput():find("particleDensity", 1, true), "reply names the base cvar")
    c:slash("set 3132 RAIDsettingsEnabled 0")
    assert(EncounterSettingsDB.encounters[3132], "a RAID-prefixed cvar with no base twin is accepted")
end)

test("keeps restoring the other cvars when one restore throws, and retries it at the next chance", function()
    local c = configuredClient()
    c:pullStart(3132)
    c.failOnWrite = 3
    c:pullEnd(3132)
    local pending = 0
    for _ in pairs(EncounterSettingsDB.active) do
        pending = pending + 1
    end
    eq(pending, 1, "cvars still pending after the failed restore")
    local restored = (c.cvars.raidGraphicsParticleDensity == "3" and 1 or 0) + (c.cvars.ffxDeath == "1" and 1 or 0)
    eq(restored, 1, "cvars restored despite the failure")
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "particle density after the retry")
    eq(c.cvars.ffxDeath, "1", "ffxDeath after the retry")
    eq(EncounterSettingsDB.active, nil, "pending cvars after the retry")
end)

test("a pull that starts while a restore is still pending keeps the true original", function()
    local c = configuredClient()
    c:pullStart(3132)
    c.failOnWrite = 3
    c:pullEnd(3132)
    c.failOnWrite = 5
    c:pullStart(3132)
    c:pullEnd(3132)
    eq(c.cvars.raidGraphicsParticleDensity, "3", "particle density after the second pull")
    eq(c.cvars.ffxDeath, "1", "ffxDeath after the second pull")
end)

test("drops malformed saved variables at load and coerces numbers to strings", function()
    local c = newClient()
    c.cvars.raidGraphicsParticleDensity = "0"
    _G.EncounterSettingsDB = {
        encounters = {
            ["3132"] = { name = "text key", settings = { ffxDeath = "0" } },
            [3133] = { settings = { ffxDeath = 0, [7] = "0", broken = true } },
            [3134] = "junk",
            [3135] = { name = "no settings" },
        },
        active = {
            raidGraphicsParticleDensity = { original = 3, applied = "0" },
            ffxDeath = { original = "1" },
            junk = 5,
        },
    }
    c:login()
    eq(c.cvars.raidGraphicsParticleDensity, "3", "particle density after login")
    eq(EncounterSettingsDB.active, nil, "pending cvars after login")
    eq(EncounterSettingsDB.encounters["3132"], nil, "string-keyed encounter")
    eq(EncounterSettingsDB.encounters[3134], nil, "non-table encounter")
    eq(EncounterSettingsDB.encounters[3135], nil, "encounter without settings")
    eq(EncounterSettingsDB.encounters[3133].name, "", "missing name")
    eq(EncounterSettingsDB.encounters[3133].settings.ffxDeath, "0", "numeric value coerced")
    eq(EncounterSettingsDB.encounters[3133].settings[7], nil, "numeric cvar key")
    eq(EncounterSettingsDB.encounters[3133].settings.broken, nil, "boolean value")
    c:slash("")
    c:pullStart(3133)
    eq(c.cvars.ffxDeath, "0", "ffxDeath during the pull")
    c:pullEnd(3133)
end)

test("accepts verbs in any case", function()
    local c = newClient()
    c:login()
    c:slash("SET 3132 ffxDeath 0")
    eq(EncounterSettingsDB.encounters[3132].settings.ffxDeath, "0", "setting after SET")
    c:slash("Unset 3132 ffxDeath")
    eq(EncounterSettingsDB.encounters[3132], nil, "encounter entry after Unset")
end)

test("reports a single applied or restored setting in full", function()
    local c = newClient()
    c:login()
    c:slash("set 3132 graphicsParticleDensity 0")
    c:pullStart(3132)
    eq(c:count("set raidGraphicsParticleDensity to 0 (was 3)"), 1, "apply line")
    eq(c:count("settings were applied"), 0, "apply count line")
    c:pullEnd(3132)
    eq(c:count("restored raidGraphicsParticleDensity to 3"), 1, "restore line")
    eq(c:count("settings were restored"), 0, "restore count line")
end)

test("reports two or more applied or restored settings as a count", function()
    local c = configuredClient()
    c:pullStart(3132)
    eq(c:count("2 settings were applied"), 1, "apply count line")
    eq(c:count("set raidGraphicsParticleDensity to"), 0, "per-cvar apply lines")
    eq(c:count("set ffxDeath to"), 0, "per-cvar apply lines")
    c:pullEnd(3132)
    eq(c:count("2 settings were restored"), 1, "restore count line")
    eq(c:count("restored raidGraphicsParticleDensity to"), 0, "per-cvar restore lines")
end)

test("refuses the graphics quality presets", function()
    local c = newClient()
    c:login()
    c:slash("set 3132 graphicsQuality 1")
    eq(EncounterSettingsDB.encounters[3132], nil, "encounter entry after the preset")
    assert(c:lastOutput():find("preset", 1, true), "reply explains it is a preset")
    c:slash("set 3132 raidGraphicsQuality 1")
    eq(EncounterSettingsDB.encounters[3132], nil, "encounter entry after the raid preset")
end)

test("help lists one command per line, and a malformed command prints help", function()
    local c = newClient()
    c:login()
    c:slash("help")
    eq(c:count("/es set [id] <cvar> <value>"), 1, "set line")
    eq(c:count("/es unset [id] <cvar>"), 1, "unset line")
    eq(c:count("/es clear [id]"), 1, "clear line")
    eq(c:count("raid graphics settings"), 0, "status lines in help")
    c:slash("bogus 3132 ffxDeath 0")
    eq(c:count("/es set [id] <cvar> <value>"), 2, "set line after a malformed command")
end)

test("status shows state in short lines and points at help", function()
    local c = configuredClient()
    c:pullStart(3132, "Araz")
    c:pullEnd(3132)
    c.output = {}
    c:slash("")
    eq(c:count("raid graphics settings: active"), 1, "raid line")
    eq(c:count("last boss pulled: 3132 Araz"), 1, "last boss line")
    eq(c:count("/es help for commands"), 1, "help pointer")
    eq(c:count("/es set [id] <cvar> <value>"), 0, "usage lines in status")
    for _, line in ipairs(c.output) do
        assert(#line < 120, "line too long: " .. line)
    end
end)

test("status distinguishes raid settings in effect, enabled elsewhere, and disabled", function()
    local c = newClient()
    c:login()
    c:slash("")
    eq(c:count("raid graphics settings: active"), 1, "in a raid with the option on")
    c.instanceType = "party"
    c:slash("")
    eq(c:count("raid graphics settings: enabled but currently inactive"), 1, "in a dungeon with the option on")
    c.cvars.RAIDsettingsEnabled = "0"
    c:slash("")
    eq(c:count("raid graphics settings: disabled"), 1, "with the option off")
end)

test("every locale key the addon uses is defined in enUS", function()
    local ns = {}
    assert(loadfile(dir .. "/Locales/enUS.lua"))(ADDON, ns)
    local file = assert(io.open(dir .. "/" .. ADDON .. ".lua"))
    local source = file:read("*a")
    file:close()
    for key in source:gmatch("%f[%w_]L%.([%w_]+)") do
        assert(rawget(ns.L, key) ~= nil, "missing locale key " .. key)
    end
end)

local failed = 0
for _, t in ipairs(tests) do
    _G.EncounterSettingsDB = nil
    local ok, err = pcall(t.fn)
    if ok then
        io.write("ok    ", t.name, "\n")
    else
        failed = failed + 1
        io.write("FAIL  ", t.name, "\n      ", tostring(err), "\n")
    end
end
io.write(string.format("%d tests, %d failed\n", #tests, failed))
os.exit(failed == 0 and 0 or 1)
