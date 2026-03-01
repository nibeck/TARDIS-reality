# TardisViewModel Refactor To-Do

Updating `TardisViewModel` to use `LightAction` enum + single action handler pattern from `ImprovedTardisViewModel`.

## Steps

- [X] Move `LightSection` struct and `LightAction` enum to `Data/Models/` (separate files)
- [X] Extract `TardisViewModel` out of `Tardis3DView.swift` into `Core/CoreModels/TardisViewModel.swift`
- [ ] Add private `lightSections` dictionary `[TARDISManager.LEDSection: LightSection]` to `TardisViewModel` to replace individual stored properties
- [ ] Add `initializeLightSections()` method and call it from `init()` — sets all 9 sections to `isOn: false`, `color: .white`
- [ ] Remove `isUpdatingFromPowerSwitch` flag — this is replaced by the action handler pattern
- [ ] Add private `handleLightAction(_ action: LightAction)` as the single point of control for all light changes
- [ ] Add private `updateLightSection()` helper that safely mutates entries in the `lightSections` dictionary
- [ ] Add private `startFadeIn(for section:)` helper to replace the fade logic currently inside each `didSet`
- [ ] Add private `handlePowerOn()` and `handlePowerOff()` to replace the `powerOnOff` `didSet` block
- [ ] Replace all 9 individual `OnOff` stored properties (`topLightOnOff`, `frontWindowOnOff`, etc.) with computed properties backed by `lightSections` dictionary
- [ ] Replace all 9 individual color stored properties with computed properties backed by `lightSections` dictionary
- [ ] Add public interface methods: `togglePower()`, `toggleLight(_ section:)`, `setLightColor(_ section:, color:)`
- [ ] Delete `ImprovedTardisViewModel.swift` once `TardisViewModel` is fully updated

## Notes

- Steps are ordered — structure first, then replace internals, then clean up
- The biggest win is removing `isUpdatingFromPowerSwitch` (step 4) — once `handleLightAction` exists, context is explicit via the action enum
- `LightSection` and `LightAction` are data types and belong in `Data/Models/` regardless of the refactor progress
