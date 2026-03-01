//
//  LightAction.swift
//  TARDIS-Reality
//
//  Created by Mike Nibeck on 2/28/26.
//
import SwiftUI

// MARK: - Light Control Actions
enum LightAction {
    case turnOn(section: TARDISManager.LEDSection, immediate: Bool)
    case turnOff(section: TARDISManager.LEDSection, immediate: Bool)
    case setColor(section: TARDISManager.LEDSection, color: Color)
    case powerOn
    case powerOff
}
