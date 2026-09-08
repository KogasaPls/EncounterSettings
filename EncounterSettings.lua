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

local function restore(keep)
    local active = db.active
    if not active then
        return
    end
    local count, lastCVar, lastValue = 0, nil, nil
    for cvar, saved in pairs(active) do
        if not (keep and keep[cvar]) then
            if GetCVar(cvar) ~= saved.applied then
                say(L.CHANGED_DURING_ENCOUNTER, cvar, tostring(GetCVar(cvar)))
                active[cvar] = nil
            else
                local ok, success = pcall(SetCVar, cvar, saved.original)
                if ok and success then
                    count, lastCVar, lastValue = count + 1, cvar, saved.original
                    active[cvar] = nil
                elseif not ok then
                    say(L.RESTORE_FAILED, cvar, tostring(success))
                else
                    say(L.RESTORE_REFUSED, cvar)
                end
            end
        end
    end
    if next(active) == nil then
        db.active = nil
    end
    if count == 1 then
        say(L.RESTORED, lastCVar, lastValue)
    elseif count > 1 then
        say(L.RESTORED_MANY, count)
    end
end

local function apply(settings)
    local wanted = {}
    for cvar, value in pairs(settings) do
        wanted[targetCVar(cvar)] = value
    end
    restore(wanted)
    local active = db.active or {}
    db.active = active
    local count, lastCVar, lastSaved = 0, nil, nil
    for target, value in pairs(wanted) do
        local live = GetCVar(target)
        local saved = active[target]
        if saved and live ~= saved.applied then
            saved = nil
        end
        if not (saved and saved.value == value) then
            if live == nil then
                say(L.UNKNOWN_CVAR_SKIPPED, target)
            else
                local ok, success = pcall(SetCVar, target, value)
                if not ok then
                    say(L.SET_FAILED, target, tostring(success))
                elseif not success then
                    say(L.SET_REFUSED, target, value)
                else
                    saved = saved or { original = live }
                    saved.value = value
                    saved.applied = GetCVar(target)
                    active[target] = saved
                    count, lastCVar, lastSaved = count + 1, target, saved
                end
            end
        end
    end
    if count == 1 then
        say(L.SET, lastCVar, lastSaved.applied, lastSaved.original)
    elseif count > 1 then
        say(L.SET_MANY, count)
    end
    if next(active) == nil then
        db.active = nil
    end
end

local function asString(value)
    if type(value) == "number" then
        return tostring(value)
    end
    if type(value) == "string" then
        return value
    end
end

local function sanitize()
    local encounters = type(db.encounters) == "table" and db.encounters or {}
    db.encounters = encounters
    for id, encounter in pairs(encounters) do
        if type(id) ~= "number" or type(encounter) ~= "table" or type(encounter.settings) ~= "table" then
            encounters[id] = nil
        else
            encounter.name = asString(encounter.name) or ""
            for cvar, value in pairs(encounter.settings) do
                encounter.settings[cvar] = type(cvar) == "string" and asString(value) or nil
            end
        end
    end
    local active = type(db.active) == "table" and db.active or nil
    db.active = active
    for cvar, saved in pairs(active or {}) do
        if type(cvar) == "string" and type(saved) == "table" then
            saved.original, saved.applied, saved.value =
                asString(saved.original), asString(saved.applied), asString(saved.value)
        end
        if type(cvar) ~= "string" or type(saved) ~= "table" or not saved.original or not saved.applied then
            active[cvar] = nil
        end
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
        if type(EncounterSettingsDB) ~= "table" then
            EncounterSettingsDB = {}
        end
        db = EncounterSettingsDB
        sanitize()
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
        else
            restore()
        end
    elseif event == "ENCOUNTER_END" then
        local _, _, _, _, success = ...
        if success ~= 0 then
            restore()
        end
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
    if cvar:lower() == "graphicsquality" then
        say(L.PRESET, cvar)
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

local function help()
    say(L.HELP_SET)
    say(L.HELP_UNSET)
    say(L.HELP_CLEAR)
    say(L.HELP_ID)
end

local function status()
    local raidState = raidSettingsActive() and L.RAID_ACTIVE
        or GetCVarBool("RAIDsettingsEnabled") and L.RAID_INACTIVE
        or L.RAID_DISABLED
    say(L.STATUS_RAID, raidState)
    say(L.STATUS_LAST_BOSS, lastEncounter and label(lastEncounter.id) or L.NONE_YET)
    if next(db.encounters) == nil then
        say(L.STATUS_EMPTY)
    end
    local ids = {}
    for id in pairs(db.encounters) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local cvars = {}
        for cvar in pairs(db.encounters[id].settings) do
            cvars[#cvars + 1] = cvar
        end
        table.sort(cvars)
        say(#cvars == 1 and L.ENCOUNTER_HEADER_ONE or L.ENCOUNTER_HEADER, label(id), #cvars)
        for _, cvar in ipairs(cvars) do
            say(L.SETTING_LINE, cvar, db.encounters[id].settings[cvar])
        end
    end
    for cvar, saved in pairs(db.active or {}) do
        say(L.ACTIVE, cvar, saved.applied, saved.original)
    end
    say(L.HELP_HINT)
end

SLASH_ENCOUNTERSETTINGS1 = "/es"
SLASH_ENCOUNTERSETTINGS2 = "/encountersettings"
SlashCmdList.ENCOUNTERSETTINGS = function(msg)
    local verb, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    verb = verb:lower()
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
    elseif verb == "help" then
        help()
    elseif not id then
        say(L.NO_BOSS_YET, verb)
    elseif verb == "set" and value ~= "" then
        setSetting(id, cvar, value)
    elseif verb == "unset" and cvar ~= "" then
        removeSetting(id, cvar)
    elseif verb == "clear" and cvar == "" then
        clearEncounter(id)
    else
        help()
    end
end
