//
//  AudioView.swift
//  
//
//  Created by Mike Nibeck on 12/31/25.
//

import SwiftUI

struct AudioView: View {
    // TARDISManager is a singleton and @Observable. 
    // Accessing properties in the body will automatically subscribe to changes.
    private var manager = TARDISManager.shared
    
    var body: some View {
        NavigationStack {
            List(manager.availableSounds, id: \.self) { sound in
                HStack {
                    Text(sound.friendlyName)
                    Spacer()
                    if manager.currentlyPlayingSound == sound {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.red)
                    } else {
                        Image(systemName: "play")
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle()) // Makes the entire row tappable
                .onTapGesture {
                    manager.playSound(sound: sound)
                }
            }
            .navigationTitle("Audio")
            .refreshable {
                manager.fetchSounds()
            }
        }
    }
}

#Preview {
    AudioView()
}
