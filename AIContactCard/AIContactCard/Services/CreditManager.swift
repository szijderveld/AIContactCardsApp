//
//  CreditManager.swift
//  AIContactCard
//

import Foundation

@Observable
class CreditManager {
    private let balanceKey = "creditBalance"
    private let hasGrantedFreeCreditsKey = "hasGrantedFreeCredits"

    var balance: Int {
        get { UserDefaults.standard.integer(forKey: balanceKey) }
        set { UserDefaults.standard.set(newValue, forKey: balanceKey) }
    }

    var hasCredits: Bool { balance > 0 }
    var isLow: Bool { balance > 0 && balance <= 5 }

    func consume() -> Bool {
        guard balance > 0 else { return false }
        balance -= 1
        return true
    }

    func add(_ amount: Int) {
        balance += amount
    }

    func grantFreeCreditsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: hasGrantedFreeCreditsKey) else { return }
        UserDefaults.standard.set(true, forKey: hasGrantedFreeCreditsKey)
        add(50)
    }
}
