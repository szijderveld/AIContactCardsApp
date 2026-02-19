//
//  CreditBanner.swift
//  AIContactCard
//

import SwiftUI

struct CreditBanner: View {
    @Environment(CreditManager.self) private var creditManager
    @AppStorage("useBYOK") private var useBYOK = false

    var body: some View {
        if useBYOK {
            EmptyView()
        } else if creditManager.balance == 0 {
            NavigationLink(destination: CreditsView()) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("No credits remaining")
                        .fontWeight(.medium)
                    Spacer()
                    Text("Buy Credits")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.red.gradient, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)
        } else if creditManager.isLow {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                Text("\(creditManager.balance) credits remaining")
                    .fontWeight(.medium)
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
    }
}

#Preview {
    NavigationStack {
        VStack {
            CreditBanner()
            Spacer()
        }
    }
    .environment(CreditManager())
}
