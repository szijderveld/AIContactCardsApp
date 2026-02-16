//
//  CreditsView.swift
//  AIContactCard
//

import SwiftUI
import StoreKit

struct CreditsView: View {
    @Environment(CreditManager.self) private var creditManager

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("\(creditManager.balance)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("credits remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            Section {
                if creditManager.isLoadingProducts {
                    HStack {
                        Spacer()
                        ProgressView("Loading products…")
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } else if creditManager.products.isEmpty {
                    VStack(spacing: 12) {
                        Text("Could not load products.")
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await creditManager.loadProducts() }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    ForEach(creditManager.products, id: \.id) { product in
                        CreditPackRow(
                            product: product,
                            credits: creditManager.creditsForProduct(product),
                            isBestValue: product.id == "com.szijderveld.AIContactCard.credits.4000"
                        ) {
                            Task { await creditManager.purchase(product) }
                        }
                    }
                }
            } header: {
                Text("Credit Packs")
            } footer: {
                Text("Credits are used for AI-powered contact extraction and queries. Each action costs 1 credit.")
            }

            if let error = creditManager.purchaseError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Credits")
        .overlay {
            if creditManager.isPurchasing {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView("Purchasing…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - CreditPackRow

private struct CreditPackRow: View {
    let product: Product
    let credits: Int
    let isBestValue: Bool
    let onPurchase: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(credits) Credits")
                        .font(.headline)
                    if isBestValue {
                        Text("Best Value")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green, in: Capsule())
                    }
                }
                Text(pricePerCredit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onPurchase) {
                Text(product.displayPrice)
                    .font(.subheadline.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var pricePerCredit: String {
        let price = NSDecimalNumber(decimal: product.price).doubleValue
        let per = price / Double(credits)
        return String(format: "$%.3f / credit", per)
    }
}

#Preview {
    NavigationStack {
        CreditsView()
    }
    .environment(CreditManager())
}
