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
L.RAID_SETTINGS = "raid graphics settings are %s here"
L.IN_EFFECT = "in effect"
L.NOT_IN_EFFECT = "not in effect"
L.ENCOUNTER_LINE = "%s: %s"
L.SETTING = "%s = %s"
L.ACTIVE = "active: %s = %s, will go back to %s"
L.USAGE =
    "usage: /es set [encounterID] <cvar> <value>, /es unset [encounterID] <cvar>, /es clear [encounterID]; leave out the id to use the last boss pulled (%s)"
L.NONE_YET = "none yet"
L.NO_BOSS_YET = "no boss pulled yet, so give the encounter id after %s"
