local ADDON = ...

local db
local lastEncounter

local function say(fmt, ...)
    print("|cff80c0ff" .. ADDON .. "|r " .. fmt:format(...))
end

local function raidSettingsActive()
    local _, instanceType = IsInInstance()
    return GetCVarBool("RAIDsettingsEnabled") and (instanceType == "raid" or instanceType == "pvp")
end

local function targetCVar(cvar)
    if raidSettingsActive() and cvar:lower():find("^graphics") then
        return "raidGraphics" .. cvar:sub(9)
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
        if GetCVar(cvar) == saved.applied then
            SetCVar(cvar, saved.original)
            say("restored %s to %s", cvar, saved.original)
        else
            say("%s was changed during the encounter, leaving it at %s", cvar, tostring(GetCVar(cvar)))
        end
    end
end

local function apply(settings)
    restore()
    local active = {}
    db.active = active
    for cvar, value in pairs(settings) do
        local target = targetCVar(cvar)
        local original = GetCVar(target)
        if original == nil then
            say("%s is not a known cvar, skipping it", target)
        else
            local ok, success = pcall(SetCVar, target, value)
            if not ok then
                say("could not set %s: %s", target, tostring(success))
            elseif not success then
                say("the client refused to set %s to %s", target, value)
            else
                active[target] = { original = original, applied = GetCVar(target) }
                say("set %s to %s (was %s)", target, active[target].applied, original)
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
    if cvar:lower():find("^raidgraphics") then
        say(
            "set %s instead; the raidGraphics version is used on its own whenever raid graphics settings are in effect",
            "graphics" .. cvar:sub(13)
        )
        return
    end
    if GetCVar(cvar) == nil then
        say("%s is not a known cvar", cvar)
        return
    end
    local _, _, _, _, _, isSecure, isReadOnly = C_CVar.GetCVarInfo(cvar)
    if isReadOnly then
        say("%s is read-only", cvar)
        return
    end
    if isSecure then
        say("%s is a secure cvar and cannot be changed in combat", cvar)
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
    say("%s: %s will be set to %s", label(id), key, value)
end

local function removeSetting(id, cvar)
    local encounter = db.encounters[id]
    local key = encounter and settingKey(encounter.settings, cvar)
    if not key or encounter.settings[key] == nil then
        say("%s is not set for %s", cvar, label(id))
        return
    end
    encounter.settings[key] = nil
    say("%s: removed %s", label(id), key)
    if next(encounter.settings) == nil then
        db.encounters[id] = nil
    end
end

local function clearEncounter(id)
    if not db.encounters[id] then
        say("nothing is set for %s", label(id))
        return
    end
    say("%s: cleared", label(id))
    db.encounters[id] = nil
end

local function status()
    say("raid graphics settings are %s here", raidSettingsActive() and "in effect" or "not in effect")
    for cvar, saved in pairs(db.active or {}) do
        say("active: %s = %s, will go back to %s", cvar, saved.applied, saved.original)
    end
    for id, encounter in pairs(db.encounters) do
        local parts = {}
        for cvar, value in pairs(encounter.settings) do
            parts[#parts + 1] = cvar .. " = " .. value
        end
        say("%s: %s", label(id), table.concat(parts, ", "))
    end
    say(
        "usage: /es set [encounterID] <cvar> <value>, /es unset [encounterID] <cvar>, /es clear [encounterID]; leave out the id to use the last boss pulled (%s)",
        lastEncounter and ("%d %s"):format(lastEncounter.id, lastEncounter.name) or "none yet"
    )
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
        say("no boss pulled yet, so give the encounter id after %s", verb)
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
