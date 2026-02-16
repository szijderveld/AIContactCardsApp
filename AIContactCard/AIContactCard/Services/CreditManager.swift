//
//  CreditManager.swift
//  AIContactCard
//

import Foundation
import StoreKit

enum StoreError: Error, LocalizedError {
    case failedVerification
    var errorDescription: String? { "Transaction verification failed." }
}

@Observable
class CreditManager {
    private let balanceKey = "creditBalance"
    private let hasGrantedFreeCreditsKey = "hasGrantedFreeCredits"

    static let creditProducts: [String: Int] = [
        "com.szijderveld.AIContactCard.credits.100": 100,
        "com.szijderveld.AIContactCard.credits.600": 600,
        "com.szijderveld.AIContactCard.credits.1500": 1500,
        "com.szijderveld.AIContactCard.credits.4000": 4000
    ]

    static let productIDs: Set<String> = Set(creditProducts.keys)

    // MARK: - Balance

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

    // MARK: - StoreKit

    var products: [Product] = []
    var isLoadingProducts = false
    var isPurchasing = false
    var purchaseError: String?

    private var transactionListener: Task<Void, Never>?

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                let credits = creditsForProduct(product)
                add(credits)
                await transaction.finish()

            case .userCancelled:
                break

            case .pending:
                purchaseError = "Purchase is pending approval."

            @unknown default:
                purchaseError = "Unknown purchase result."
            }
        } catch let error as StoreError {
            purchaseError = error.localizedDescription
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func creditsForProduct(_ product: Product) -> Int {
        Self.creditProducts[product.id] ?? 0
    }

    func startListening() {
        transactionListener = Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    if let credits = Self.creditProducts[transaction.productID] {
                        await MainActor.run {
                            self.add(credits)
                        }
                    }
                    await transaction.finish()
                } catch {
                    // Unverified transaction — skip
                }
            }
        }
    }

    func stopListening() {
        transactionListener?.cancel()
        transactionListener = nil
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }
}
