//
//  Entry.swift
//  AIContactCard
//

import Foundation
import SwiftData

@Model
class Entry {
    var id: UUID = UUID()
    var transcript: String
    var createdAt: Date = Date()

    init(transcript: String) {
        self.transcript = transcript
    }
}
