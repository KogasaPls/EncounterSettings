# EncounterSettings

Changes CVars when a boss encounter starts and puts them back when it ends.

```
/es set 3420 graphicsParticleDensity 0    hide particle effects on Sszorak (encounter 3420)
/es unset 3420 graphicsParticleDensity    clear that setting
/es clear 3420                            clear every setting for Sszorak
/es set graphicsParticleDensity 0         leave out the ID to use the last boss you pulled
/es                                       show all settings and the ID of the last boss you pulled
```

After a wipe the settings stay applied until the next pull, a kill, a reload, or leaving the instance, so a progression night reconfigures graphics once rather than every pull. Any CVar the client lets you change will work. Inside a raid with 'Raid & Battleground' settings enabled, the `RAID` twin of a CVar is used instead (`raidGraphicsParticleDensity` for `graphicsParticleDensity`, `RAIDfarclip` for `farclip`), so configure the base name. Two useful ones:

- `graphicsParticleDensity`: 0 (disabled) to 5 (ultra)
- `graphicsViewDistance`: 0 to 9, shown as 1 to 10 in the options panel

The wiki's [complete list of console variables](https://warcraft.wiki.gg/wiki/Console_variables/Complete_list) has the other graphics settings.

## Development

`luajit test.lua` runs the tests against a stubbed client and `luacheck .` lints. Tags of the form `vX.Y.Z` are packaged and published by the BigWigs packager.
