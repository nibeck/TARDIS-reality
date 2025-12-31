import Foundation
import SwiftUI
import Observation
import TARDISAPIClient
import OpenAPIRuntime
import OpenAPIURLSession

// TODO: API structure. JSON body or query params for Section value


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
    
    private let client: Client
    
    init(serverURL: String = "http://192.168.1.161") {
        self.client = Client(
            serverURL: URL(string: serverURL)!,
            transport: URLSessionTransport()
        )
        // Initial fetch
        fetchSections()
    }
    
    func fetchSections() {
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
                default:
                    print("Failed to fetch sections: Unexpected response")
                }
            } catch {
                print("Failed to fetch LED sections: \(error)")
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
                
                // 'section' is part of the JSON body here
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
                // Treat .all as nil (all sections) for the turn on request if the API supports nil for all
                let sectionValue = (section == .all) ? nil : section?.rawValue
                
                // Attempt to reuse TurnOnRequest if the schema is the same.
                // If the compiler errors here, Cmd+Click 'turn_on_api_led_off_post' to see the expected input type.
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
    
    // Future API methods can be added here
    // func playSound(name: String) { ... }
}
