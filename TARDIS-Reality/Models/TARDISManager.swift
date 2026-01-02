import Foundation
import SwiftUI
import Observation
import TARDISAPIClient
import OpenAPIRuntime
import OpenAPIURLSession

/// Represents an audio file available on the TARDIS
struct AudioFile: Identifiable, Hashable, Sendable {
    let id = UUID()
    let friendlyName: String
    let fileName: String
    
    // Custom equality based on fileName to maintain state across fetches
    static func == (lhs: AudioFile, rhs: AudioFile) -> Bool {
        return lhs.fileName == rhs.fileName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(fileName)
    }
}

/// Represents a lighting scene available on the TARDIS
struct Scene: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let description: String
}

@MainActor
@Observable
class TARDISManager {

    static let shared = TARDISManager()
    
    // Enum representing the physical sections of LEDs on the TARDIS
    enum LEDSection: String, CaseIterable, Sendable {
        case topLight = "Top Light"
        case frontWindow = "Front Windows"
        case leftWindow = "Left Windows"
        case rightWindow = "Right Windows"
        case rearWindow = "Rear Windows"
        case all = "All"
    }
    
    var sections: [Components.Schemas.LEDSection] = []
    var availableSounds: [AudioFile] = []
    var availableScenes: [Scene] = []
    var currentlyPlayingSound: AudioFile?
    
    private let client: Client
    
    private init(serverURL: String = "http://192.168.1.161") {
        self.client = Client(
            serverURL: URL(string: serverURL)!,
            transport: URLSessionTransport()
        )
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
        Task {
            do {
                let response = try await client.get_scenes_api_scenes_get()
                switch response {
                case .ok(let okResponse):
                    switch okResponse.body {
                    case .json(let json):
                        // Parse the OpenAPIValueContainer to extract scenes
                        // We must cast the value to `OpenAPIValue` (an enum) to switch on it.
                        if let value = json.value as? OpenAPIValue, 
                           case .object(let object) = value,
                           let scenesValue = object["scenes"],
                           case .array(let scenesArray) = scenesValue {
                            
                            self.availableScenes = scenesArray.compactMap { sceneValue -> Scene? in
                                guard case .object(let sceneDict) = sceneValue,
                                      let nameValue = sceneDict["name"],
                                      case .string(let name) = nameValue,
                                      let descriptionValue = sceneDict["description"],
                                      case .string(let description) = descriptionValue else {
                                    return nil
                                }
                                return Scene(name: name, description: description)
                            }
                            print("Successfully fetched \(self.availableScenes.count) scenes")
                        } else {
                            print("Failed to parse scenes: Unexpected structure or types")
                        }
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

    /// Generic function to set the color of a specific LED section
    func setLightColor(for section: LEDSection, color: Color) {
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

    func turnOff(section: LEDSection? = nil) {
        Task {
            do {
                let sectionValue = (section == .all) ? nil : section?.rawValue
                
                let body = Components.Schemas.TurnOffRequest(
                    section: sectionValue
                )
                
                _ = try await client.turn_off_api_led_off_post(body: .json(body))
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
}
