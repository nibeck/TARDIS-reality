//
//  LightSection.swift
//  TARDIS-Reality
//
//  Created by Mike Nibeck on 2/28/26.
//
import SwiftUI

struct LightSection {
    let id: TARDISManager.LEDSection
    var isOn: Bool
    var color: Color
    var isFading: Bool = false
    
    var displayColor: Color {
        isOn ? color : .black
    }
}
