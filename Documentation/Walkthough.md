This is a SwiftUI + RealityKit iOS app that renders a 3D TARDIS and controls real‑world TARDIS hardware (LEDs, sounds, scenes) via an OpenAPI client. The UI is a split layout: a persistent 3D view on top and a tabbed control surface below.

**How it’s structured**
- App entry: TARDIS-Reality/TARDIS_RealityApp.swift boots TardisContentView.
- Root UI: TARDIS-Reality/TARDISContentView.swift builds the two‑pane layout: Tardis3DView (top) + TabView (bottom).
- 3D rendering: TARDIS-Reality/Views/HomeView.swift defines Tardis3DView and a local TardisViewModel.
- Backend/API bridge: TARDIS-Reality/Models/TARDISManager.swift is a singleton that talks to the hardware API (http://tardis.local) via the generated TARDISAPIClient.
- Feature tabs:
  - TARDIS-Reality/Views/ControlPanelView.swift toggles LEDs and colors per section.
  - TARDIS-Reality/Views/ScenesView.swift lists and plays lighting scenes.
  - TARDIS-Reality/Views/AudioView.swift lists and plays sounds.
  - TARDIS-Reality/Views/SettingsView.swift is mostly static right now.
  - TARDIS-Reality/Views/AnimationView.swift is a placeholder.

**Core data flow**
- TARDISManager is @Observable, so any SwiftUI view reading its properties updates automatically.
- TardisViewModel is local state for UI toggles and model controls. It forwards changes to TARDISManager (turn on/off, set color, fade opacity).
- Tardis3DView renders a RealityKit model and updates materials each frame using values from the view model, while opacity is pulled from TARDISManager.shared.modelOpacity.
- API calls are kicked off in TARDISManager.init and in view lifecycle events (e.g., ScenesView.onAppear).

**3D model handling**
- Tardis3DView loads an entity named "TARDIS" (from your bundled USD asset) and builds a part name → Entity map so it can recolor specific meshes.
- It updates materials on named parts (e.g., "Front_Windows_Mesh", "PoliceSignLight_Front") based on view model colors.
- A timer spins the model; drag rotates and pinch zooms. Background is Space-Background from assets.

**LEDs, sounds, scenes**
- LED sections are represented by TARDISManager.LEDSection.
- Color updates call set_color_api_led_color_post with RGB derived from TARDIS-Reality/Extensions/Color+Extensions.swift.
- Sounds/scenes are fetched and mapped into local structs, then triggered by tap.

**Notable behaviors**
- TARDISManager optimistically updates UI state before API responses for snappy feedback.
- The “All” power switch in TardisViewModel propagates to every section and triggers fadeIn/fadeOut on the 3D model.
- SettingsView includes a test button wired for future use.
