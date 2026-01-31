//
//  AnimationView.swift
//  TARDIS-Reality
//
//  Created by Mike Nibeck on 1/16/26.
//

import SwiftUI

struct AnimationView: View {
    @State private var firstFadeColor: Color = .blue
    @State private var secondFadeColor: Color = .purple
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // First Control Set
                HStack {
                    ColorPicker("Select Color", selection: $firstFadeColor)
                        .labelsHidden()
                    
                    Text("Fade Color 1")
                    
                    Spacer()
                    
                    Button("Fade To Color") {
                        // Triggers a fade to the selected color on all sections
                        TARDISManager.shared.fadeLED(section: .all, color: firstFadeColor, duration: 2.0)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
                
                // Second Control Set
                HStack {
                    ColorPicker("Select Color", selection: $secondFadeColor)
                        .labelsHidden()
                    
                    Text("Fade Color 2")
                    
                    Spacer()
                    
                    Button("Fade To Color") {
                        // Triggers a fade to the selected color on all sections
                        TARDISManager.shared.fadeLED(section: .all, color: secondFadeColor, duration: 2.0)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
            }
            .padding()
        }
    }
}

#Preview {
    AnimationView()
}
