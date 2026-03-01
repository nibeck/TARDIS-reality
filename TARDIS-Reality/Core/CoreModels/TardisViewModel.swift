//
//  TardisViewModel.swift
//  TARDIS-Reality
//
//  Created by Mike Nibeck on 2/28/26.
//
import SwiftUI
import Observation

@Observable
class TardisViewModel {
    // MARK: - 3D Model Configuration Properties
    /**
     * modelScale: Represents the initial/default scale for the 3D model.
     * Note: The actual zoom behavior uses local state in Tardis3DView to prevent
     * gesture interference with the UI controls. This value serves as a reference
     * point and could be used for reset functionality.
     */
    var modelScale: Double = 0.6
    /**
     * modelColor: Controls the base color of the TARDIS structure itself.
     * This affects the main body/shell color but not the lighting elements,
     * maintaining the classic blue TARDIS appearance by default.
     */
    var modelColor: Color = .blue
    /**
     * modelOpacity: Computed property that retrieves opacity from TARDISManager.
     * This enables fade-in/fade-out effects for the entire 3D model during
     * power transitions and special effects. The computed property pattern
     * ensures the UI always reflects the current hardware state.
     */
    var modelOpacity: Float {
        TARDISManager.shared.modelOpacity
    }

    private var lightSections: [TARDISManager.LEDSection: LightSection] = [:]

    // MARK: - Initialisation

    init() {
        initializeLightSections()
    }

    private func initializeLightSections() {
        let allSections: [TARDISManager.LEDSection] = [
            .topLight,
            .frontWindow, .leftWindow, .rightWindow, .rearWindow,
            .frontPoliceSign, .leftPoliceSign, .rearPoliceSign, .rightPoliceSign
        ]
        for section in allSections {
            lightSections[section] = LightSection(id: section, isOn: false, color: .white)
        }
    }

    // MARK: - Light Action Handler

    private func handleLightAction(_ action: LightAction) {
        switch action {
        case .turnOn(let section, let immediate):
            if immediate {
                TARDISManager.shared.turnOn(section: section)
                updateLightSection(section, isOn: true, color: lightSections[section]?.color ?? .white)
            } else {
                startFadeIn(for: section)
            }

        case .turnOff(let section, let immediate):
            if immediate {
                TARDISManager.shared.turnOff(section: section)
                updateLightSection(section, isOn: false)
            }
            // non-immediate off is handled globally by handlePowerOff via fadeLED

        case .setColor(let section, let color):
            TARDISManager.shared.setLightColor(for: section, color: color)
            updateLightSection(section, color: color)

        case .powerOn:
            handlePowerOn()

        case .powerOff:
            handlePowerOff()
        }
    }

    private func updateLightSection(_ section: TARDISManager.LEDSection, isOn: Bool? = nil, color: Color? = nil) {
        guard var entry = lightSections[section] else { return }
        if let isOn { entry.isOn = isOn }
        if let color { entry.color = color }
        lightSections[section] = entry
    }

    private func startFadeIn(for section: TARDISManager.LEDSection) {
        let color = lightSections[section]?.color ?? .white
        TARDISManager.shared.fadeLED(section: section, color: color, duration: 1.0)
        TARDISManager.shared.setColorStateForFade(for: section, color: color)
        updateLightSection(section, isOn: true)
    }

    private func handlePowerOn() {
        TARDISManager.shared.fadeIn(duration: 2.0)
        for section in lightSections.keys {
            handleLightAction(.turnOn(section: section, immediate: false))
        }
    }

    private func handlePowerOff() {
        TARDISManager.shared.fadeOut(duration: 2.0)
        TARDISManager.shared.fadeLED(color: .black, duration: 3.0)
        for section in lightSections.keys {
            updateLightSection(section, isOn: false)
        }
    }

    // MARK: - Master Power Control System
    // Master switch — delegates to handlePowerOn() / handlePowerOff() via handleLightAction.
    var powerOnOff: Bool = false {
        didSet {
            handleLightAction(powerOnOff ? .powerOn : .powerOff)
        }
    }

    // MARK: - Top Light Section
    var topLightOnOff: Bool {
        get { lightSections[.topLight]?.isOn ?? false }
        set { handleLightAction(newValue ? .turnOn(section: .topLight, immediate: true) : .turnOff(section: .topLight, immediate: true)) }
    }
    var topLightColor: Color {
        get { lightSections[.topLight]?.color ?? .white }
        set { handleLightAction(.setColor(section: .topLight, color: newValue)) }
    }
    // MARK: - Window Lighting Sections
    var frontWindowOnOff: Bool {
        get { lightSections[.frontWindow]?.isOn ?? false }
        set { handleLightAction(newValue ? .turnOn(section: .frontWindow, immediate: true) : .turnOff(section: .frontWindow, immediate: true)) }
    }
    var frontWindowColor: Color {
        get { lightSections[.frontWindow]?.color ?? .white }
        set { handleLightAction(.setColor(section: .frontWindow, color: newValue)) }
    }
    var leftWindowOnOff: Bool {
        get { lightSections[.leftWindow]?.isOn ?? false }
        set { handleLightAction(newValue ? .turnOn(section: .leftWindow, immediate: true) : .turnOff(section: .leftWindow, immediate: true)) }
    }
    var leftWindowColor: Color {
        get { lightSections[.leftWindow]?.color ?? .white }
        set { handleLightAction(.setColor(section: .leftWindow, color: newValue)) }
    }
    var rightWindowOnOff: Bool {
        get { lightSections[.rightWindow]?.isOn ?? false }
        set { handleLightAction(newValue ? .turnOn(section: .rightWindow, immediate: true) : .turnOff(section: .rightWindow, immediate: true)) }
    }
    var rightWindowColor: Color {
        get { lightSections[.rightWindow]?.color ?? .white }
        set { handleLightAction(.setColor(section: .rightWindow, color: newValue)) }
    }
    var rearWindowOnOff: Bool {
        get { lightSections[.rearWindow]?.isOn ?? false }
        set { handleLightAction(newValue ? .turnOn(section: .rearWindow, immediate: true) : .turnOff(section: .rearWindow, immediate: true)) }
    }
    var rearWindowColor: Color {
        get { lightSections[.rearWindow]?.color ?? .white }
        set { handleLightAction(.setColor(section: .rearWindow, color: newValue)) }
    }
    // MARK: - Police Sign Lighting Sections
    var frontPoliceSignOnOff: Bool {
        get { lightSections[.frontPoliceSign]?.isOn ?? false }
        set { handleLightAction(newValue ? .turnOn(section: .frontPoliceSign, immediate: true) : .turnOff(section: .frontPoliceSign, immediate: true)) }
    }
    var frontPoliceSignColor: Color {
        get { lightSections[.frontPoliceSign]?.color ?? .white }
        set { handleLightAction(.setColor(section: .frontPoliceSign, color: newValue)) }
    }
    
    var leftPoliceSignOnOff: Bool {
        get { lightSections[.leftPoliceSign]?.isOn ?? false }
        set { handleLightAction(newValue ? .turnOn(section: .leftPoliceSign, immediate: true) : .turnOff(section: .leftPoliceSign, immediate: true)) }
    }
    var leftPoliceSignColor: Color {
        get { lightSections[.leftPoliceSign]?.color ?? .white }
        set { handleLightAction(.setColor(section: .leftPoliceSign, color: newValue)) }
    }
    
    var rearPoliceSignOnOff: Bool {
        get { lightSections[.rearPoliceSign]?.isOn ?? false }
        set { handleLightAction(newValue ? .turnOn(section: .rearPoliceSign, immediate: true) : .turnOff(section: .rearPoliceSign, immediate: true)) }
    }
    var rearPoliceSignColor: Color {
        get { lightSections[.rearPoliceSign]?.color ?? .white }
        set { handleLightAction(.setColor(section: .rearPoliceSign, color: newValue)) }
    }
    var rightPoliceSignOnOff: Bool {
        get { lightSections[.rightPoliceSign]?.isOn ?? false }
        set { handleLightAction(newValue ? .turnOn(section: .rightPoliceSign, immediate: true) : .turnOff(section: .rightPoliceSign, immediate: true)) }
    }
    var rightPoliceSignColor: Color {
        get { lightSections[.rightPoliceSign]?.color ?? .white }
        set { handleLightAction(.setColor(section: .rightPoliceSign, color: newValue)) }
    }
    
    // MARK: - Public Interface

    func togglePower() {
        powerOnOff.toggle()
    }

    func toggleLight(_ section: TARDISManager.LEDSection) {
        let isCurrentlyOn = lightSections[section]?.isOn ?? false
        handleLightAction(isCurrentlyOn ? .turnOff(section: section, immediate: true) : .turnOn(section: section, immediate: true))
    }

    func setLightColor(_ section: TARDISManager.LEDSection, color: Color) {
        handleLightAction(.setColor(section: section, color: color))
    }

    // MARK: - Testing and Development
    /**
     * runTest: Development function for testing hardware connectivity and lighting effects.
     * This function delegates to TARDISManager's test routine, which typically:
     * - Cycles through different colors on all sections
     * - Verifies hardware communication
     * - Demonstrates the full range of lighting capabilities
     * 
     * Useful for:
     * - Hardware debugging
     * - Demonstrating lighting capabilities
     * - Verifying network connectivity to TARDIS hardware
     */
    func runTest() async {
        await TARDISManager.shared.runTest()
    }
}
