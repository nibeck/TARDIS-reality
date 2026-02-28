//
//  AnimatedScene.swift
//  TARDIS-Reality
//
//  Represents a lighting scene available on the TARDIS
//

import Foundation

/// Represents a lighting scene available on the TARDIS
struct AnimatedScene: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let description: String
}
