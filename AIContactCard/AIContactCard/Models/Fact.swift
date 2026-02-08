//
//  Fact.swift
//  AIContactCard
//

import Foundation
import SwiftData

@Model
class Fact {
    var id: UUID = UUID()
    var category: String
    var content: String
    var rawTranscript: String = ""
    var createdAt: Date = Date()

    var person: Person?

    init(category: String, content: String) {
        self.category = category
        self.content = content
    }
}
