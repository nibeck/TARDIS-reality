@Observable
class TardisViewModel {
    // MARK: - 3D Model Configuration Properties
    /**
     * These properties control the basic appearance and behavior of the 3D model display.
     * They are separate from the lighting system to maintain clear separation of concerns.
     */
    
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

    // MARK: - Power State Coordination System
    /**
     * isUpdatingFromPowerSwitch: Critical flag for preventing feedback loops.
     * 
     * This flag ensures that when the master power switch triggers changes,
     * the individual light section updates don't cause conflicting hardware commands.
     * Without this flag, turning on power would cause:
     * 1. Master switch triggers fade-in commands
     * 2. Individual sections receive state updates
     * 3. Individual sections trigger immediate-on commands
     * 4. Hardware receives conflicting fade AND immediate commands
     * 
     * The flag creates a communication protocol between the master switch
     * and individual sections, ensuring coordinated behavior.
     */
    private var isUpdatingFromPowerSwitch: Bool = false

    // MARK: - Master Power Control System
    /**
     * powerOnOff: The master switch that controls the entire TARDIS lighting system.
     * 
     * This property orchestrates complex state transitions involving:
     * - 3D model fade effects (visual feedback)
     * - Hardware LED fade commands (physical lighting)
     * - Individual section state synchronization
     * - UI control state updates
     * 
     * Power On Sequence:
     * 1. Start 3D model fade-in animation (2 seconds)
     * 2. Set coordination flag to prevent feedback loops
     * 3. Update all individual section toggles (triggers fade commands)
     * 4. Update UI color picker states to show target colors
     * 5. Clear coordination flag
     * 
     * Power Off Sequence:
     * 1. Start 3D model fade-out animation (2 seconds)
     * 2. Start global LED fade-out (3 seconds, creates smooth transition)
     * 3. Update individual section states with coordination flag
     * 
     * This design ensures smooth, coordinated transitions that look professional
     * and avoid jarring instant on/off behavior.
     */
    var powerOnOff: Bool = false {
        didSet {
            if powerOnOff {
                // Fade 3d Model in
                TARDISManager.shared.fadeIn(duration: 2.0)
                
                // Set flag to indicate programmatic updates are happening
                isUpdatingFromPowerSwitch = true

                // Update all individual toggles to match the master switch
                // This will trigger the individual didSet handlers which will handle both:
                // 1. The LED fade commands
                // 2. The UI color state updates
                topLightOnOff = powerOnOff
                frontWindowOnOff = powerOnOff
                leftWindowOnOff = powerOnOff
                rightWindowOnOff = powerOnOff
                rearWindowOnOff = powerOnOff
                frontPoliceSignOnOff = powerOnOff
                leftPoliceSignOnOff = powerOnOff
                rearPoliceSignOnOff = powerOnOff
                rightPoliceSignOnOff = powerOnOff

                // Clear flag after updating all toggles
                isUpdatingFromPowerSwitch = false
            } else {
                // Fade 3d model out
                TARDISManager.shared.fadeOut(duration: 2.0)
                // Fade all LEDs out immediately (global fade)
                TARDISManager.shared.fadeLED(color: Color.black, duration: 3.0)
                
                // Set flag to indicate programmatic updates are happening
                isUpdatingFromPowerSwitch = true

                // Update all individual toggles to match the master switch
                topLightOnOff = powerOnOff
                frontWindowOnOff = powerOnOff
                leftWindowOnOff = powerOnOff
                rightWindowOnOff = powerOnOff
                rearWindowOnOff = powerOnOff
                frontPoliceSignOnOff = powerOnOff
                leftPoliceSignOnOff = powerOnOff
                rearPoliceSignOnOff = powerOnOff
                rightPoliceSignOnOff = powerOnOff

                // Clear flag after updating all toggles
                isUpdatingFromPowerSwitch = false
            }
        }
    }

    // MARK: - Individual Light Section Control System
    /**
     * The following section contains individual control properties for each physical lighting
     * component of the TARDIS. Each section follows a consistent pattern that provides:
     * 
     * - Toggle control (on/off state)
     * - Color selection (with real-time hardware updates)
     * - Coordinated behavior with the master power switch
     * - Smooth fade effects vs. immediate response based on context
     * 
     * Architecture Pattern for Each Section:
     * 1. OnOff Property: Boolean toggle with sophisticated didSet logic
     * 2. Color Property: Computed property backed by TARDISManager state
     * 
     * The didSet handlers implement context-aware behavior:
     * - Master Power Switch Context: Triggers smooth fade effects
     * - Direct User Control: Provides immediate response
     * - Power-off Protection: Prevents interference during global fade-out
     * 
     * This dual-mode behavior creates an intuitive user experience where
     * the master power switch creates dramatic lighting effects, while
     * individual controls provide precise, immediate feedback.
     */

    // MARK: - Top Light Section
    /**
     * Controls the beacon light at the top of the TARDIS.
     * This is typically the most prominent light element and often
     * represents the "power status" of the time machine.
     */
    var topLightOnOff: Bool = false {
        didSet {
            if topLightOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .topLight, color: .white, duration: 1.0)
                    TARDISManager.shared.setColorStateForFade(for: .topLight, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .topLight)
                    topLightColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .topLight)
                }
            }
        }
    }
    /**
     * topLightColor: Computed property providing real-time color control.
     * 
     * Get: Retrieves current color from TARDISManager's central state
     * Set: Triggers immediate hardware update via TARDISManager
     * 
     * This pattern ensures the UI always reflects actual hardware state
     * while providing seamless color updates during user interaction.
     */
    var topLightColor: Color {
        get { TARDISManager.shared.sectionColors[.topLight] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .topLight, color: newValue) }
    }

    // MARK: - Window Lighting Sections
    /**
     * The four window sections provide ambient lighting around the TARDIS.
     * These lights create the characteristic glow effect and can be controlled
     * individually for complex lighting scenes or synchronized for dramatic effects.
     */

    // Front Window Section
    var frontWindowOnOff: Bool = false {
        didSet {
            if frontWindowOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .frontWindow, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .frontWindow, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .frontWindow)
                    frontWindowColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .frontWindow)
                }
            }
        }
    }
    var frontWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.frontWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .frontWindow, color: newValue) }
    }
    
    // Left Window Section
    var leftWindowOnOff: Bool = false {
        didSet {
            if leftWindowOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .leftWindow, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .leftWindow, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .leftWindow)
                    leftWindowColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .leftWindow)
                }
            }
        }
    }
    var leftWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.leftWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .leftWindow, color: newValue) }
    }
    
    // Right Window Section  
    var rightWindowOnOff: Bool = false {
        didSet {
            if rightWindowOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .rightWindow, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .rightWindow, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .rightWindow)
                    rightWindowColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .rightWindow)
                }
            }
        }
    }
    var rightWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.rightWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rightWindow, color: newValue) }
    }
    
    // Rear Window Section
    var rearWindowOnOff: Bool = false {
        didSet {
            if rearWindowOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .rearWindow, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .rearWindow, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .rearWindow)
                    rearWindowColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .rearWindow)
                }
            }
        }
    }
    var rearWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.rearWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rearWindow, color: newValue) }
    }
      
    // MARK: - Police Sign Lighting Sections
    /**
     * The four police sign lights illuminate the "POLICE BOX" signage on each side.
     * These lights are essential for the authentic TARDIS appearance and provide
     * accent lighting that can be used for status indication or dramatic effects.
     */

    // Front Police Sign Section
    var frontPoliceSignOnOff: Bool = false {
        didSet {
            if frontPoliceSignOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .frontPoliceSign, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .frontPoliceSign, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .frontPoliceSign)
                    frontPoliceSignColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .frontPoliceSign)
                }
            }
        }
    }
    var frontPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.frontPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .frontPoliceSign, color: newValue) }
    }
    
    // Left Police Sign Section
    var leftPoliceSignOnOff: Bool = false {
        didSet {
            if leftPoliceSignOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .leftPoliceSign, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .leftPoliceSign, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .leftPoliceSign)
                    leftPoliceSignColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .leftPoliceSign)
                }
            }
        }
    }
    var leftPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.leftPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .leftPoliceSign, color: newValue) }
    }
    
    // Rear Police Sign Section
    var rearPoliceSignOnOff: Bool = false {
        didSet {
            if rearPoliceSignOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .rearPoliceSign, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .rearPoliceSign, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .rearPoliceSign)
                    rearPoliceSignColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .rearPoliceSign)
                }
            }
        }
    }
    var rearPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.rearPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rearPoliceSign, color: newValue) }
    }
    
    // Right Police Sign Section
    var rightPoliceSignOnOff: Bool = false {
        didSet {
            if rightPoliceSignOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .rightPoliceSign, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .rightPoliceSign, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .rightPoliceSign)
                    rightPoliceSignColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .rightPoliceSign)
                }
            }
        }
    }
    var rightPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.rightPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rightPoliceSign, color: newValue) }
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