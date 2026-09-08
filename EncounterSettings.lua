local ADDON, ns = ...
local L = ns.L

local db
local lastEncounter

local function say(fmt, ...)
    print("|cff80c0ff" .. ADDON .. "|r " .. fmt:format(...))
end

local function raidSettingsActive()
    local _, instanceType = IsInInstance()
    return GetCVarBool("RAIDsettingsEnabled") and (instanceType == "raid" or instanceType == "pvp")
end

local function raidTwin(cvar)
    if cvar:lower():find("^graphics") then
        return "raidGraphics" .. cvar:sub(9)
    end
    return "RAID" .. cvar
end

local function baseOfTwin(cvar)
    local lower = cvar:lower()
    if lower:find("^raidgraphics") then
        return "graphics" .. cvar:sub(13)
    elseif lower:find("^raid") then
        return cvar:sub(5)
    end
end

local function targetCVar(cvar)
    if raidSettingsActive() then
        local twin = raidTwin(cvar)
        if GetCVar(twin) ~= nil then
            return twin
        end
    end
    return cvar
end

local function settingKey(settings, cvar)
    for key in pairs(settings) do
        if key:lower() == cvar:lower() then
            return key
        end
    end
    return cvar
end

local function restore()
    local active = db.active
    if not active then
        return
    end
    db.active = nil
    for cvar, saved in pairs(active) do
        if GetCVar(cvar) ~= saved.applied then
            say(L.CHANGED_DURING_ENCOUNTER, cvar, tostring(GetCVar(cvar)))
        else
            local ok, success = pcall(SetCVar, cvar, saved.original)
            if ok and success then
                say(L.RESTORED, cvar, saved.original)
            else
                if not ok then
                    say(L.RESTORE_FAILED, cvar, tostring(success))
                else
                    say(L.RESTORE_REFUSED, cvar)
                end
                db.active = db.active or {}
                db.active[cvar] = saved
            end
        end
    end
end

local function apply(settings)
    restore()
    local active = db.active or {}
    db.active = active
    for cvar, value in pairs(settings) do
        local target = targetCVar(cvar)
        local original = GetCVar(target)
        if original == nil then
            say(L.UNKNOWN_CVAR_SKIPPED, target)
        else
            local ok, success = pcall(SetCVar, target, value)
            if not ok then
                say(L.SET_FAILED, target, tostring(success))
            elseif not success then
                say(L.SET_REFUSED, target, value)
            else
                local saved = active[target] or { original = original }
                saved.applied = GetCVar(target)
                active[target] = saved
                say(L.SET, target, saved.applied, saved.original)
            end
        end
    end
    if next(active) == nil then
        db.active = nil
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= ADDON then
            return
        end
        EncounterSettingsDB = EncounterSettingsDB or {}
        db = EncounterSettingsDB
        db.encounters = db.encounters or {}
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not C_InstanceEncounter.IsEncounterInProgress() then
            restore()
        end
    elseif event == "ENCOUNTER_START" then
        if not IsInInstance() then
            return
        end
        local id, name = ...
        lastEncounter = { id = id, name = name }
        local encounter = db.encounters[id]
        if encounter then
            encounter.name = name
            apply(encounter.settings)
        end
    elseif event == "ENCOUNTER_END" then
        restore()
    end
end)

local function label(id)
    local encounter = db.encounters[id]
    local name = encounter and encounter.name ~= "" and encounter.name
        or lastEncounter and lastEncounter.id == id and lastEncounter.name
        or ""
    return ("%d %s"):format(id, name)
end

local function setSetting(id, cvar, value)
    local base = baseOfTwin(cvar)
    if base and GetCVar(base) ~= nil then
        say(L.USE_BASE_NAME, base)
        return
    end
    if GetCVar(cvar) == nil then
        say(L.UNKNOWN_CVAR, cvar)
        return
    end
    local _, _, _, _, _, isSecure, isReadOnly = C_CVar.GetCVarInfo(cvar)
    if isReadOnly then
        say(L.READ_ONLY, cvar)
        return
    end
    if isSecure then
        say(L.SECURE, cvar)
        return
    end
    local encounter = db.encounters[id]
    if not encounter then
        encounter = { name = "", settings = {} }
        db.encounters[id] = encounter
    end
    if lastEncounter and lastEncounter.id == id then
        encounter.name = lastEncounter.name
    end
    local key = settingKey(encounter.settings, cvar)
    encounter.settings[key] = value
    say(L.WILL_SET, label(id), key, value)
end

local function removeSetting(id, cvar)
    local encounter = db.encounters[id]
    local key = encounter and settingKey(encounter.settings, cvar)
    if not key or encounter.settings[key] == nil then
        say(L.NOT_SET, cvar, label(id))
        return
    end
    encounter.settings[key] = nil
    say(L.REMOVED, label(id), key)
    if next(encounter.settings) == nil then
        db.encounters[id] = nil
    end
end

local function clearEncounter(id)
    if not db.encounters[id] then
        say(L.NOTHING_SET, label(id))
        return
    end
    say(L.CLEARED, label(id))
    db.encounters[id] = nil
end

local function status()
    say(L.RAID_SETTINGS, raidSettingsActive() and L.IN_EFFECT or L.NOT_IN_EFFECT)
    for cvar, saved in pairs(db.active or {}) do
        say(L.ACTIVE, cvar, saved.applied, saved.original)
    end
    for id, encounter in pairs(db.encounters) do
        local parts = {}
        for cvar, value in pairs(encounter.settings) do
            parts[#parts + 1] = cvar .. " = " .. value
        end
        say("%s: %s", label(id), table.concat(parts, ", "))
    end
    say(L.USAGE, lastEncounter and ("%d %s"):format(lastEncounter.id, lastEncounter.name) or L.NONE_YET)
end

SLASH_ENCOUNTERSETTINGS1 = "/es"
SLASH_ENCOUNTERSETTINGS2 = "/encountersettings"
SlashCmdList.ENCOUNTERSETTINGS = function(msg)
    local verb, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    local id, args = rest:match("^(%d+)%s*(.-)$")
    if id then
        id = tonumber(id)
    else
        id = lastEncounter and lastEncounter.id
        args = rest
    end
    local cvar, value = args:match("^(%S*)%s*(.-)$")
    if verb == "" then
        status()
    elseif not id then
        say(L.NO_BOSS_YET, verb)
    elseif verb == "set" and value ~= "" then
        setSetting(id, cvar, value)
    elseif verb == "unset" and cvar ~= "" then
        removeSetting(id, cvar)
    elseif verb == "clear" and cvar == "" then
        clearEncounter(id)
    else
        status()
    end
end
