# SwiftUI Observable Architecture: TARDIS Fade-In Walkthrough

This document explains the "Unidirectional Data Flow" and the lifecycle of an event in the TARDIS Reality app, specifically focusing on how the "Master On/Off" switch triggers a 3D animation.

## The Architecture Lifecycle

### 1. The Interaction (The View Layer)
The user interacts with the UI in `ControlPanelView.swift`. The Toggle is bound to the ViewModel's state using the `$` prefix, which creates a two-way binding.

```swift
// ControlPanelView.swift
Toggle("On/Off", isOn: $viewModel.allOnOff)
```

**Observation**: When the toggle is flipped, SwiftUI directly updates the `allOnOff` property inside the `TardisViewModel`.

### 2. The Logic Trigger (The ViewModel Layer)
The ViewModel acts as the command center. It doesn't know how to perform 3D animations, but it knows *when* they should happen.

```swift
// HomeView.swift (TardisViewModel)
var allOnOff: Bool = false {
    didSet {
        if allOnOff {
            TARDISManager.shared.fadeIn(duration: 2.0)
        } else {
            TARDISManager.shared.fadeOut(duration: 2.0)
        }
    }
}
```

**Observation**: The `didSet` observer detects the change and calls the appropriate method on the `TARDISManager` singleton.

### 3. The Source of Truth (The Model/Manager Layer)
The `TARDISManager` is the "Source of Truth" for the app's state. It is marked with `@Observable`, which allows SwiftUI to track its properties.

```swift
// TARDISManager.swift
@Observable
class TARDISManager {
    var modelOpacity: Float = 0.0

    func fadeIn(duration: Double) {
        withAnimation(.easeInOut(duration: duration)) {
            self.modelOpacity = 1.0
        }
    }
}
```

**Observation**: When `withAnimation` is used, SwiftUI interpolates the `modelOpacity` value over time (e.g., 0.0 -> 0.1 -> 0.2 ... -> 1.0).

### 4. Automatic Notification (The "Magic")
Because `Tardis3DView` reads the `modelOpacity` (via the ViewModel proxy), SwiftUI automatically creates a dependency.

*   **Dependency Chain**: `RealityView` -> `viewModel.modelOpacity` -> `TARDISManager.shared.modelOpacity`.

As the animation changes the value in the Manager, SwiftUI **automatically notifies** the `Tardis3DView` that it needs to refresh.

### 5. RealityKit Update (The Hardware Layer)
In RealityKit, we apply these changes inside the `update` block of the `RealityView`.

```swift
// HomeView.swift (Tardis3DView)
update: { content in
    // This runs every time modelOpacity changes during the animation!
    if let rootEntity = anchor.children.first(where: { $0.name == "TARDIS" }) {
        let opacityComp = OpacityComponent(opacity: viewModel.modelOpacity)
        rootEntity.components.set(opacityComp)
    }
}
```

**Observation**: During the 2-second animation, this `update` block runs roughly 60 times per second, applying the latest opacity to the 3D entity, resulting in a smooth fade.

## Key Design Principles
1.  **Separation of Concerns**: Views handle UI, ViewModels handle logic, Managers handle data/state.
2.  **Reactive Flow**: Data flows down (Manager -> View), and actions flow up (View -> Manager).
3.  **Automatic Observation**: Using `@Observable` removes the need for manual "refresh" calls or messy notification observers.
