local _, ns = ...

local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
ns.L = L

L.RESTORED = "restored %s to %s"
L.RESTORED_MANY = "%d settings were restored"
L.RESTORE_FAILED = "could not restore %s: %s"
L.RESTORE_REFUSED = "the client refused to restore %s"
L.CHANGED_DURING_ENCOUNTER = "%s was changed during the encounter, leaving it at %s"
L.UNKNOWN_CVAR_SKIPPED = "%s is not a known cvar, skipping it"
L.SET_FAILED = "could not set %s: %s"
L.SET_REFUSED = "the client refused to set %s to %s"
L.SET = "set %s to %s (was %s)"
L.SET_MANY = "%d settings were applied"
L.USE_BASE_NAME = "set %s instead; its RAID twin is used on its own whenever raid graphics settings are in effect"
L.PRESET = "%s is a preset that only the options panel can apply; set the individual settings instead"
L.UNKNOWN_CVAR = "%s is not a known cvar"
L.READ_ONLY = "%s is read-only"
L.SECURE = "%s is a secure cvar and cannot be changed in combat"
L.WILL_SET = "%s: %s will be set to %s"
L.NOT_SET = "%s is not set for %s"
L.REMOVED = "%s: removed %s"
L.NOTHING_SET = "nothing is set for %s"
L.CLEARED = "%s: cleared"
L.STATUS_RAID = "raid graphics settings: %s"
L.STATUS_LAST_BOSS = "last boss pulled: %s"
L.STATUS_EMPTY = "no settings configured"
L.RAID_ACTIVE = "active"
L.RAID_INACTIVE = "enabled, inactive"
L.RAID_DISABLED = "disabled"
L.ENCOUNTER_LINE = "%s: %s"
L.SETTING = "%s = %s"
L.ACTIVE = "active: %s = %s (will go back to %s)"
L.HELP_HINT = "/es help for commands"
L.HELP_SET = "/es set [id] <cvar> <value>"
L.HELP_UNSET = "/es unset [id] <cvar>"
L.HELP_CLEAR = "/es clear [id]"
L.HELP_ID = "id defaults to the last boss pulled"
L.NONE_YET = "none yet"
L.NO_BOSS_YET = "no boss pulled yet; include the encounter id"
