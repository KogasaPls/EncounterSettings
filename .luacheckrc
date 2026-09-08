std = "lua51"
codes = true
self = false
max_line_length = false
exclude_files = { ".release" }

globals = {
    "EncounterSettingsDB",
    "SlashCmdList",
    "SLASH_ENCOUNTERSETTINGS1",
    "SLASH_ENCOUNTERSETTINGS2",
}

read_globals = {
    "C_CVar",
    "C_InstanceEncounter",
    "CreateFrame",
    "GetCVar",
    "GetCVarBool",
    "IsInInstance",
    "SetCVar",
}

files["test.lua"] = {
    globals = {
        "C_CVar",
        "C_InstanceEncounter",
        "CreateFrame",
        "GetCVar",
        "GetCVarBool",
        "IsInInstance",
        "SetCVar",
        "SlashCmdList",
        "print",
    },
}
