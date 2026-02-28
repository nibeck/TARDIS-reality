//
//  AudioFile.swift
//  TARDIS-Reality
//
//  Represents an audio file available on the TARDIS
//

import Foundation

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
