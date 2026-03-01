import SwiftUI
import Observation

// MARK: - Improved ViewModel
@Observable
class ImprovedTardisViewModel {
    
    // MARK: - Published State
    var modelScale: Double = 0.6
    var modelColor: Color = .blue
    var powerOnOff: Bool = false
    
    // Single source of truth for all light sections
    private var lightSections: [TARDISManager.LEDSection: LightSection] = [:]
    
    var modelOpacity: Float {
        TARDISManager.shared.modelOpacity
    }
    
    // MARK: - Computed Properties for UI Binding
    var topLightOnOff: Bool {
        get { lightSections[.topLight]?.isOn ?? false }
        set { handleLightAction(.turnOn(section: .topLight, immediate: true)) }
    }
    
    var topLightColor: Color {
        get { lightSections[.topLight]?.color ?? .black }
        set { handleLightAction(.setColor(section: .topLight, color: newValue)) }
    }
    
    // Add similar computed properties for other sections...
    
    // MARK: - Initialization
    init() {
        initializeLightSections()
    }
    
    private func initializeLightSections() {
        let allSections: [TARDISManager.LEDSection] = [
            .topLight, .frontWindow, .leftWindow, .rightWindow, .rearWindow,
            .frontPoliceSign, .leftPoliceSign, .rearPoliceSign, .rightPoliceSign
        ]
        
        for section in allSections {
            lightSections[section] = LightSection(
                id: section,
                isOn: false,
                color: .white
            )
        }
    }
    
    // MARK: - Action Handler (Single Point of Control)
    private func handleLightAction(_ action: LightAction) {
        switch action {
        case .turnOn(let section, let immediate):
            updateLightSection(section) { section in
                section.isOn = true
            }
            
            if immediate {
                TARDISManager.shared.turnOn(section: section)
                TARDISManager.shared.setLightColor(for: section, color: lightSections[section]?.color ?? .white)
            } else {
                startFadeIn(for: section)
            }
            
        case .turnOff(let section, let immediate):
            updateLightSection(section) { section in
                section.isOn = false
            }
            
            if immediate {
                TARDISManager.shared.turnOff(section: section)
            }
            
        case .setColor(let section, let color):
            updateLightSection(section) { lightSection in
                lightSection.color = color
            }
            
            // Only update hardware if light is currently on and not fading
            if let lightSection = lightSections[section], 
               lightSection.isOn && !lightSection.isFading {
                TARDISManager.shared.setLightColor(for: section, color: color)
            }
            
        case .powerOn:
            powerOnOff = true
            handlePowerOn()
            
        case .powerOff:
            powerOnOff = false
            handlePowerOff()
        }
    }
    
    // MARK: - Private Helpers
    private func updateLightSection(_ section: TARDISManager.LEDSection, 
                                  _ update: (inout LightSection) -> Void) {
        guard var lightSection = lightSections[section] else { return }
        update(&lightSection)
        lightSections[section] = lightSection
    }
    
    private func startFadeIn(for section: TARDISManager.LEDSection) {
        updateLightSection(section) { $0.isFading = true }
        
        let targetColor = lightSections[section]?.color ?? .white
        TARDISManager.shared.fadeLED(section: section, color: targetColor, duration: 3.0)
        
        // Mark fade as complete after duration
        Task {
            try await Task.sleep(nanoseconds: UInt64(3.0 * 1_000_000_000))
            await MainActor.run {
                updateLightSection(section) { $0.isFading = false }
            }
        }
    }
    
    private func handlePowerOn() {
        // Fade 3D model
        TARDISManager.shared.fadeIn(duration: 2.0)
        
        // Turn on all sections with fade
        let allSections: [TARDISManager.LEDSection] = [
            .topLight, .frontWindow, .leftWindow, .rightWindow, .rearWindow,
            .frontPoliceSign, .leftPoliceSign, .rearPoliceSign, .rightPoliceSign
        ]
        
        for section in allSections {
            handleLightAction(.turnOn(section: section, immediate: false))
        }
    }
    
    private func handlePowerOff() {
        // Fade 3D model and LEDs
        TARDISManager.shared.fadeOut(duration: 2.0)
        TARDISManager.shared.fadeLED(color: .black, duration: 3.0)
        
        // Update internal state
        for section in lightSections.keys {
            updateLightSection(section) { 
                $0.isOn = false
                $0.isFading = false
            }
        }
    }
    
    // MARK: - Public Interface
    func togglePower() {
        handleLightAction(powerOnOff ? .powerOff : .powerOn)
    }
    
    func toggleLight(_ section: TARDISManager.LEDSection) {
        let isCurrentlyOn = lightSections[section]?.isOn ?? false
        if isCurrentlyOn {
            handleLightAction(.turnOff(section: section, immediate: true))
        } else {
            handleLightAction(.turnOn(section: section, immediate: true))
        }
    }
    
    func setLightColor(_ section: TARDISManager.LEDSection, color: Color) {
        handleLightAction(.setColor(section: section, color: color))
    }
    
    func runTest() async {
        await TARDISManager.shared.runTest()
    }
}

// MARK: - Extended Computed Properties
extension ImprovedTardisViewModel {
    var frontWindowOnOff: Bool {
        get { lightSections[.frontWindow]?.isOn ?? false }
        set { 
            if newValue {
                handleLightAction(.turnOn(section: .frontWindow, immediate: true))
            } else {
                handleLightAction(.turnOff(section: .frontWindow, immediate: true))
            }
        }
    }
    
    var frontWindowColor: Color {
        get { lightSections[.frontWindow]?.color ?? .black }
        set { handleLightAction(.setColor(section: .frontWindow, color: newValue)) }
    }
    
    // Add similar properties for all other sections...
    // (leftWindow, rightWindow, rearWindow, frontPoliceSign, etc.)
}
