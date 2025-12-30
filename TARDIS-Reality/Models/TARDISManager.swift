import Foundation
import SwiftUI
import Observation
import TARDISAPIClient
import OpenAPIRuntime
import OpenAPIURLSession

@MainActor
@Observable
class TARDISManager {
    static let shared = TARDISManager()
    
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
    
    func setTopLightColor(_ color: Color) {
        Task {
            let components = color.rgbComponents
            let body = Components.Schemas.Color(
                r: components.r,
                g: components.g,
                b: components.b
            )
            do {
                _ = try await client.set_color_api_led_color_post(body: .json(body))
                print("Successfully set LED color to \(components)")
            } catch {
                print("Failed to set LED color: \(error)")
            }
        }
    }
    
    // Future API methods can be added here
    // func turnOn() { ... }
    // func playSound(name: String) { ... }
}
