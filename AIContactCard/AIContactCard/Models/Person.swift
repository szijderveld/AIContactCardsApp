//
//  Person.swift
//  AIContactCard
//

import Foundation
import SwiftData

@Model
class Person {
    var id: UUID = UUID()
    var name: String
    var aliases: [String] = []
    var contactIdentifier: String? = nil
    var summary: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade)
    var facts: [Fact] = []

    init(name: String) {
        self.name = name
    }
}
