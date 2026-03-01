import Foundation
import SwiftUI
import Observation
import TARDISAPIClient
import OpenAPIRuntime
import OpenAPIURLSession

@MainActor
@Observable
class TARDISManager {

    // Create a SINGLETON instance of the TARDIS Manager. Everyone will use this single instace to effect change
    static let shared = TARDISManager()
    
    // MARK: - Configuration
    /// Using direct IP address to avoid mDNS resolution delays
    /// If your TARDIS's IP changes, update this line
    private static let defaultServerURL = "http://192.168.1.245"
    
    /// Alternative: Use mDNS (may show warnings but works if IP changes)
    // private static let defaultServerURL = "http://tardis.local"
    
    // Enum representing the physical sections of LEDs on the TARDIS
    enum LEDSection: String, CaseIterable, Sendable {
        case topLight = "Top Light"
        case frontWindow = "Front Windows"
        case leftWindow = "Left Windows"
        case rightWindow = "Right Windows"
        case rearWindow = "Rear Windows"
        case frontPoliceSign = "Front Police"
        case leftPoliceSign = "Left Police"
        case rearPoliceSign = "Rear Police"
        case rightPoliceSign = "Right Police"
        case all = "All"
    }
    
    var sections: [Components.Schemas.LEDSection] = []
    var availableSounds: [AudioFile] = []
    var availableScenes: [AnimatedScene] = []
    var currentlyPlayingSound: AudioFile?
    var sectionColors: [LEDSection: Color] = [:]
    var modelOpacity: Float = 0.0
    
    // Store the current animation task to allow cancellation
    private var fadeTask: Task<Void, Never>?
    
    private let client: Client
    
    private init(serverURL: String = defaultServerURL) {
        print("🔌 Connecting to TARDIS at: \(serverURL)")
        
        self.client = Client(
            serverURL: URL(string: serverURL)!,
            transport: URLSessionTransport()
        )
        
        // Initialize section colors with defaults
        for section in LEDSection.allCases where section != .all {
            sectionColors[section] = .black
        }
        
        // Initial fetch
        fetchSections()
        fetchSounds()
        fetchScenes()
    }
    
    func fetchSections() {
        guard sections.isEmpty else {
            return
        }
        Task {
            do {
                let response = try await client.get_led_sections_api_led_sections_get()
                switch response {
                case .ok(let okResponse):
                    switch okResponse.body {
                    case .json(let fetchedSections):
                        self.sections = fetchedSections
                        print("Successfully fetched \(sections.count) LED sections")
                    }
                case .undocumented(let statusCode, _):
                    print("Failed to fetch sections: Undocumented status code \(statusCode)")
                }
            } catch {
                print("Failed to fetch LED sections: \(error)")
            }
        }
    }
    
    func fetchSounds() {
        // If sounds have already been fetched, skip the API call.
        guard availableSounds.isEmpty else {
            return
        }

        Task {
            do {
                let response = try await client.get_sounds_api_sounds_get()
            
                switch response {
                case .ok(let okResponse):
                    switch okResponse.body {
                    case .json(let sounds):
                        // Map the generated API types to our AudioFile struct.
                        self.availableSounds = sounds.map { sound in
                            AudioFile(
                                friendlyName: sound.friendlyName,
                                fileName: sound.fileName
                            )
                        }
                        print("Successfully fetched \(self.availableSounds.count) sounds")
                    }
                case .undocumented(let statusCode, _):
                    print("Failed to fetch sounds: Undocumented status code \(statusCode)")
                }
            } catch {
                print("Failed to fetch sounds: \(error)")
            }
        }
    }
    
    func fetchScenes() {
        guard availableScenes.isEmpty else {
            return
        }
        Task {
            do {
                let response = try await client.get_scenes_api_scenes_get()
                switch response {
                case .ok(let okResponse):
                    switch okResponse.body {
                    case .json(let sceneList):
                        // Map the generated SceneList to our local Scene struct.
                        self.availableScenes = sceneList.scenes.map { scene in
                            AnimatedScene(
                                name: scene.name,
                                description: scene.description
                            )
                        }
                        print("Successfully fetched \(self.availableScenes.count) scenes")
                    }
                case .undocumented(let statusCode, _):
                    print("Failed to fetch scenes: Undocumented status code \(statusCode)")
                }
            } catch {
                print("Failed to fetch scenes: \(error)")
            }
        }
    }
    
    func playScene(named sceneName: String) {
        Task {
            do {
                _ = try await client.play_scene_api_scenes__scene_name__play_post(
                    path: .init(scene_name: sceneName)
                )
                print("Playing scene: \(sceneName)")
            } catch {
                print("Failed to play scene \(sceneName): \(error)")
            }
        }
    }

    /// Update the internal color state without triggering LED API calls
    /// This is useful when we want the UI to reflect a color change during an ongoing fade animation
    private func updateColorState(for section: LEDSection, color: Color) {
        if section == .all {
            for s in LEDSection.allCases where s != .all {
                sectionColors[s] = color
            }
        } else {
            sectionColors[section] = color
        }
    }
    
    /// Public wrapper for updating color state during fade operations
    func setColorStateForFade(for section: LEDSection, color: Color) {
        updateColorState(for: section, color: color)
    }
    
    /// Generic function to set the color of a specific LED section
    func setLightColor(for section: LEDSection, color: Color) {
        // Optimistically update the state for UI here.
        // Doing this inside the function ensures the UI updates instantly
        // regardless of whether this is called from a Test, a Button, or elsewhere.
        if section == .all {
            for s in LEDSection.allCases where s != .all {
                sectionColors[s] = color
            }
        } else {
            sectionColors[section] = color
        }
        
        Task {
            let components = color.rgbComponents
            
            if section == .all {
                // Loop through all sections except 'all' to simulate a batch update
                for s in LEDSection.allCases where s != .all {
                    do {
                        let body = Components.Schemas.SetColorRequest(
                            color: .init(
                                r: components.r,
                                g: components.g,
                                b: components.b
                            ),
                            section: s.rawValue
                        )
                        
                        _ = try await client.set_color_api_led_color_post(
                            body: .json(body)
                        )
                        print("Successfully set \(s.rawValue) color to \(components)")
                    } catch {
                        print("Failed to set \(s.rawValue) color: \(error)")
                    }
                }
            } else {
                do {
                    let body = Components.Schemas.SetColorRequest(
                        color: .init(
                            r: components.r,
                            g: components.g,
                            b: components.b
                        ),
                        section: section.rawValue
                    )
                    
                    //Call API to set actual LED lights
                    _ = try await client.set_color_api_led_color_post(
                        body: .json(body)
                    )
                    print("Successfully set \(section.rawValue) color to \(components)")
                } catch {
                    print("Failed to set \(section.rawValue) color: \(error)")
                }
            }
        }
    }
    
    func turnOn(section: LEDSection? = nil) {
        Task {
            do {
                // Treat .all as nil (all sections) for the turn on request if the API supports nil for all
                let sectionValue = (section == .all) ? nil : section?.rawValue
                
                let body = Components.Schemas.TurnOnRequest(
                    section: sectionValue
                )
                
                _ = try await client.turn_on_api_led_on_post(body: .json(body))
                
                print("Turned on LEDs for \(sectionValue ?? "all sections")")
            } catch {
                print("Failed to turn on LEDs: \(error)")
            }
        }
    }
    
    func fadeLED(section: LEDSection? = nil, color: Color? = nil, duration: Double = 1.0) {
        Task {
            do {
                // Treat .all as nil (all sections) for the fade request
                let sectionValue = (section == .all) ? nil : section?.rawValue
                
                var colorComponents: Components.Schemas.Color? = nil
                if let color = color {
                     let components = color.rgbComponents
                     colorComponents = .init(r: components.r, g: components.g, b: components.b)
                }

                let body = Components.Schemas.FadeRequest(
                    color: colorComponents,
                    duration: duration,
                    section: sectionValue
                )
                
                _ = try await client.fade_api_led_fade_post(body: .json(body))
                
                print("Faded LEDs for \(sectionValue ?? "all sections")")
            } catch {
                print("Failed to fade LEDs: \(error)")
            }
        }
    }

    func turnOff(section: LEDSection? = nil) {
        Task {
            do {
                let sectionValue = (section == .all) ? nil : section?.rawValue
                
                let body = Components.Schemas.TurnOffRequest(
                    section: sectionValue
                )
                
                _ = try await client.turn_off_api_led_off_post(body: .json(body))
                
                // Set the specific section(s) to black in our internal state
                if let section = section {
                    if section == .all {
                   //     self.fadeOut(duration: 3)
                        self.setLightColor(for: .all, color: .black)
                    } else {
                   //     self.fadeOut(duration: 3)
                        self.setLightColor(for: section, color: .black)
                    }
                } else {
                    // Default to all if nil
                    self.setLightColor(for: .all, color: .black)
                }
                
                print("Turned off LEDs for \(sectionValue ?? "all sections")")
            } catch {
                print("Failed to turn off LEDs: \(error)")
            }
        }
    }
    
    func playSound(sound: AudioFile) {
        // If the sound is already playing, stop it.
        if currentlyPlayingSound == sound {
            stopSound()
            return
        }
        
        // Optimistically update UI
        self.currentlyPlayingSound = sound
        
        Task {
            do {
                _ = try await client.play_sound_api_play_sound__file_name__post(
                    path: .init(file_name: sound.fileName)
                )
                print("Playing sound: \(sound.friendlyName)")
            } catch {
                print("Failed to play sound: \(error)")
                self.currentlyPlayingSound = nil
            }
        }
    }
    
    func stopSound() {
        self.currentlyPlayingSound = nil
        
        Task {
            do {
                _ = try await client.stop_sound_api_stop_sound_post()
                print("Stopped playback")
            } catch {
                print("Failed to stop playback: \(error)")
            }
        }
    }
    
    func fadeIn(duration: Double = 1.0) {
        print("Starting Manual Fade In over \(duration) seconds...")
        fadeTask?.cancel()
        
        fadeTask = Task {
            let fps: Double = 60
            let totalSteps = Int(duration * fps)
            let interval = 1.0 / fps
            
            for step in 0...totalSteps {
                if Task.isCancelled { return }
                
                let progress = Float(step) / Float(totalSteps)
                self.modelOpacity = progress
                
                // 1 billion nanoseconds = 1 second
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            self.modelOpacity = 1.0
        }
    }
    
    func fadeOut(duration: Double = 1.0) {
        print("Starting Manual Fade Out over \(duration) seconds...")
        fadeTask?.cancel()
        
        fadeTask = Task {
            let fps: Double = 60
            let totalSteps = Int(duration * fps)
            let interval = 1.0 / fps
            
            for step in 0...totalSteps {
                if Task.isCancelled { return }
                
                // Fade from current opacity to 0
                let startOpacity = self.modelOpacity
                let progress = Float(step) / Float(totalSteps)
                self.modelOpacity = startOpacity * (1.0 - progress)
                
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            self.modelOpacity = 0.0
        }
    }

    func runTest() async {
        print("Running test")
        do {
           
            print("Test 1 - Multi color")
            setLightColor(for: LEDSection.frontWindow, color: Color.red)
            setLightColor(for: LEDSection.leftWindow, color: Color.blue)
            setLightColor(for: LEDSection.rearWindow, color: Color.green)
            setLightColor(for: LEDSection.rightWindow, color: Color.yellow)

            setLightColor(for: LEDSection.frontPoliceSign, color: Color.red)
            setLightColor(for: LEDSection.leftPoliceSign, color: Color.blue)
            setLightColor(for: LEDSection.rearPoliceSign, color: Color.green)
            setLightColor(for: LEDSection.rightPoliceSign, color: Color.yellow)
            
            setLightColor(for: LEDSection.topLight, color: Color.white)
            
        } 
    }
}
