//
//  ScenesView.swift
//  
//
//  Created by Mike Nibeck on 12/31/25.
//

import SwiftUI

struct ScenesView: View {
    private var manager = TARDISManager.shared
    
    var body: some View {
        NavigationStack {
            List(manager.availableScenes) { scene in
                VStack(alignment: .leading) {
                    HStack {
                        Text(scene.name)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "play.circle")
                            .foregroundStyle(.secondary)
                    }
                    Text(scene.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    manager.playScene(named: scene.name)
                }
            }
            .navigationTitle("Scenes")
            .refreshable {
                manager.fetchScenes()
            }
            .onAppear {
                manager.fetchScenes()
            }
        }
    }
    
}

#Preview {
    ScenesView()
}
